#!/bin/bash

## @bleopt history_limit_length
##   Specify the maximum number of characters for commands to be registered in the history.
##   Commands longer than this value will not be registered in the history.
bleopt/declare -v history_limit_length 10000

#==============================================================================
# ble/history:bash                                                @history.bash

## @arr _ble_history
##   Preserve command history entries.
##
## @arr _ble_history_edit
## @arr _ble_history_dirt
##   _ble_history_edit Holds edited command history items.
## It corresponds to each item in _ble_history and always has elements with the same number and index.
##   _ble_history_dirt retains whether it has been edited or not.
##   It corresponds to each item in _ble_history and has a value of 1 only for elements that need to be changed.
##
## @var _ble_history_index
##   Number of current history item
##
_ble_history=()
_ble_history_edit=()
_ble_history_dirt=()
_ble_history_index=0

## @var _ble_history_count
##   Total number of current history items
##
## These variables are only used when targeting command history.
##
_ble_history_count=

function ble/builtin/history/is-empty {
  # Note #D1629: Previous implementation (#D1120) used ! builtin history -p '!!'
  #   However, depending on the situation, history -p may reduce the number of history items, so it is not possible to evaluate it in a subshell.
  #   need to be valued. This fork can be omitted when you are already in a subshell.
  #   I was thinking, but even if you are inside a subshell, the history items will change to use the history later.
  #   If you use this method, you will have to start a subshell all the time. teenager
  #   Instead, I decided to change the implementation to check the output of history 1.
  ! ble/util/assign.has-output 'builtin history 1'
}

## @fn ble/builtin/history/.check-timestamp-sigsegv status
##   #D1831: Invalid timestamp in history file (HISTFILE) in Bash 4.4 and below
##   (0x7FFFFFFF+huge unix time pointing after 1900) contains segfault
##   I will. When you actually exit with SIGSEGV, check the history file and print the line number in question.
##   Strengthen.
if ((_ble_bash>=50000)); then
  function ble/builtin/history/.check-timestamp-sigsegv { return 0; }
else
  function ble/builtin/history/.check-timestamp-sigsegv {
    local stat=$1
    ((stat)) || return 0

    local ret=11
    ble/builtin/trap/sig#resolve SIGSEGV
    ((stat==128+ret)) || return 0

    local msg="bash: SIGSEGV: suspicious timestamp in HISTFILE"

    local histfile=${HISTFILE-}
    if [[ -s $histfile ]]; then
      msg="$msg='$histfile'"
      local rex_broken_timestamp='^#[0-9]\{12\}'
      ble/util/assign line 'ble/bin/grep -an "$rex_broken_timestamp" "$histfile"'
      ble/string#split line : "$line"
      [[ $line =~ ^[0-9]+$ ]] && msg="$msg (line $line)"
    fi

    if [[ ${_ble_edit_io_fname2-} ]]; then
      ble/util/print $'\n'"$msg" >> "$_ble_edit_io_fname2"
    else
      ble/util/print "$msg" >&2
    fi
  }
fi

## @fn ble/builtin/history/.dump args...
##   #D1831: Temporarily to detect messages when timestamp contains invalid values.
##   Set LC_MESSAGES and call builtin history. Furthermore, in this situation,
##   In order to avoid the problem of infinite loop in bash-3.2 and below, in bash-3.2 and below,
##   Call via conditional-sync.
if ((_ble_bash<40000)); then
  # Note (#D1831): In bash-3.2 and below, invalid timestamp is included in history.
  #   It becomes an infinite loop, so forcefully terminate it with timeout=3000. However, actually check
  #   As you can see, when called via conditional-sync, it does not become an infinite loop.
  #   It seems to become SIGSEGV before timeout.
  function ble/builtin/history/.dump.proc {
    local LC_ALL= LC_MESSAGES=C 2>/dev/null
    builtin history "${args[@]}"
    ble/util/unlocal LC_ALL LC_MESSAGES 2>/dev/null
  }
  function ble/builtin/history/.dump {
    local -a args; args=("$@")
    ble/util/conditional-sync \
      ble/builtin/history/.dump.proc \
      'builtin true' 100 progressive-weight:timeout=3000:SIGKILL
    local ext=$?
    if ((ext==142)); then
      printf 'ble.sh: timeout: builtin history %s' "$*" >&"$_ble_util_fd_tui_stderr"
      local ret=11
      ble/builtin/trap/sig#resolve SIGSEGV
      ((ext=128+ret))
    fi
    ble/builtin/history/.check-timestamp-sigsegv "$ext"
    return "$ext"
  }
else
  function ble/builtin/history/.dump {
    local LC_ALL= LC_MESSAGES=C 2>/dev/null
    builtin history "$@"
    ble/util/unlocal LC_ALL LC_MESSAGES 2>/dev/null
  }
fi

if ((_ble_bash>=50200)); then
  function ble/builtin/history/.get-min {
    if ((${_ble_trap_sig-0}==_ble_builtin_trap_EXIT)); then
      # Note (#D2153; cf #D2046, #D2118): In Bash >= 5.2, the final TTY state
      # after EXIT is affected by `set_tty_state` by Bash.  When any process in
      # the pipeline is terminated by a signal at the top-level interactive
      # shell, Bash tries to adjust the TTY state by calling "set_tty_state".
      # This even happens when the pipeline is canceled by SIGPIPE.  The
      # following command produces SIGPIPE because "head -1" or "sed 1q"
      # terminates prematurely.  To prevent Bash from changing the TTY state on
      # exit, we intentionally run the following command in a subshell.
      ble/string#split-words min "$(builtin history | ble/bin/sed -n '1{p;q;}')" # subshell
    else
      ble/util/assign-words min 'builtin history | ble/bin/sed -n "1{p;q;}"'
    fi
    min=${min/'*'}
  }
elif ((_ble_bash>=40000)); then
  function ble/builtin/history/.get-min {
    ble/util/assign-words min 'builtin history | ble/bin/sed -n "1{p;q;}"'
    min=${min/'*'}
  }
else
  function ble/builtin/history/.get-min {
    ble/util/assign-words min 'ble/builtin/history/.dump | ble/bin/sed -n "1{p;q;}"'
    min=${min/'*'}
  }
fi
function ble/builtin/history/.get-max {
  ble/util/assign-words max 'builtin history 1'
  max=${max/'*'}
}

#------------------------------------------------------------------------------
# initialize _ble_history                                    @history.bash.load

## @var _ble_history_load_done
_ble_history_load_done=

# @hook history_reset_background (defined in def.sh)
function ble/history:bash/clear-background-load {
  blehook/invoke history_reset_background
}

## @fn ble/history:bash/load
if ((_ble_bash>=40000)); then
  # Depends on the following features available in _ble_bash>=40000
  #   ble/util/is-stdin-ready (via ble/util/idle/IS_IDLE)
  #   ble/util/mapfile

  _ble_history_load_resume=0
  _ble_history_load_bgpid=

  # history > tmp
  ## @fn ble/history:bash/load/.background-initialize
  ##   @var[in] arg_count
  ##   @var[in] load_strategy
  function ble/history:bash/load/.background-initialize {
    if ble/builtin/history/is-empty; then
      # Note: When called from rcfile, history is not loaded, so it is loaded.
      #
      # Note: Initially, I thought it would be more efficient to use history -n in the parent process without having to do it twice.
      #   Since the following problem occurred, I decided to run history -n in the subshell.
      #
      #   Problem 1: Mysterious bashrc delay (memo.txt#D0702)
      #     If you call history -n in the parent shell with shopt -s histappend ,
      #     After exiting bashrc, you will be prompted by Bash itself,
      #     A mysterious delay occurs before input can be accepted.
      #     This especially seems to happen when the number of history items is more than exactly half HISTSIZE.
      #
      #     Just run shopt -u histappend at the moment you call history -n
      #     If you run shopt -s histappend immediately after, the delay disappears, but
      #     When observing the actual operation, histappend is disabled.
      #
      #     As a countermeasure, temporarily increase HISTSIZE, exit bashrc,
      #     I decided to restore HISTSIZE upon first user input.
      #     This seems to resolve the delay.
      #
      #   Problem 2: Problem where the number of history items doubles (memo.txt#D0732)
      #     When I run history -n in the parent shell, I get
      #     If you run shopt -s histappend, the number of history items will double.
      #     It doubles from just before exiting bashrc until it first receives user input.
      #     Readline probably reads the history on its own after exiting bashrc.
      #     On the other hand, with shopt -u histappend, there is no problem as long as the shell is running, but
      #     When I exit the shell, the contents of .bash_history are doubled.
      #
      #     The solution to this is unknown. (It may be possible to do so by playing around with HISTFILE, etc., but I haven't tried it.)
      #
      builtin history -n
    fi
    local HISTTIMEFORMAT=__ble_ext__
    local -x INDEX_FILE=$history_indfile

    local -x opt_source= opt_null=
    if [[ $load_strategy == source ]]; then
      opt_source=1
    elif [[ $load_strategy == mapfile ]]; then
      opt_null=1
    fi

    # from ble/util/writearray
    if [[ ! $_ble_util_writearray_rawbytes ]]; then
      local IFS=$_ble_term_IFS __ble_tmp; __ble_tmp=('\'{2,3}{0..7}{0..7})
      builtin eval "local _ble_util_writearray_rawbytes=\$'${__ble_tmp[*]}'"
    fi
    local -x __ble_rawbytes=$_ble_util_writearray_rawbytes # used by _ble_bin_awk_libES
    local -x fname_stderr=${_ble_edit_io_fname2:-}

    local -x invalid_timestamp_msg='invalid timestamp'
    local histfile=${HISTFILE:-$HOME/.bash_history}
    [[ -s $histfile ]] &&
      invalid_timestamp_msg=$invalid_timestamp_msg". Please check your history file ($histfile)."

    local apos=\'
    # 482ms for 37002 entries
    ble/builtin/history/.dump ${arg_count:+"$arg_count"} | ble/bin/awk -v apos="$apos" -v arg_offset="$arg_offset" -v _ble_bash="$_ble_bash" '
      '"$_ble_bin_awk_libES"'

      BEGIN {
        es_initialize();

        INDEX_FILE = ENVIRON["INDEX_FILE"];
        opt_null = ENVIRON["opt_null"];
        opt_source = ENVIRON["opt_source"];
        if (!opt_null && !opt_source)
          printf("") > INDEX_FILE; # create file

        fname_stderr = ENVIRON["fname_stderr"];
        fname_stderr_count = 0;
        invalid_timestamp_msg = ENVIRON["invalid_timestamp_msg"];

        n = 0;
        hindex = arg_offset;
      }

      function flush_line() {
        if (n < 1) return;

        if (opt_null) {
          if (t ~ /^eval -- \$'"$apos"'([^'"$apos"'\\]|\\.)*'"$apos"'$/)
            t = es_unescape(substr(t, 11, length(t) - 11)); # disable=#D1440 (\c? is unsed)
          printf("%s%c", t, 0);

        } else if (opt_source) {
          if (t ~ /^eval -- \$'"$apos"'([^'"$apos"'\\]|\\.)*'"$apos"'$/)
            t = es_unescape(substr(t, 11, length(t) - 11)); # disable=#D1440 (\c? is unsed)
          gsub(/'"$apos"'/, "'"$apos"'\\'"$apos$apos"'", t);
          print "_ble_history[" hindex "]=" apos t apos;

        } else {
          if (n == 1) {
            if (t ~ /^eval -- \$'"$apos"'([^'"$apos"'\\]|\\.)*'"$apos"'$/)
              print hindex > INDEX_FILE;
          } else {
            gsub(/['"$apos"'\\]/, "\\\\&", t);
            gsub(/\n/, "\\n", t);
            print hindex > INDEX_FILE;
            t = "eval -- $" apos t apos;
          }
          print t;
        }

        hindex++;
        n = 0;
        t = "";
      }

      function check_invalid_timestamp(line) {
        if (line ~ /^ *[0-9]+\*? +.+: invalid timestamp/ && fname_stderr != "") {
          sub(/^ *0*/, "bash: history !", line);
          sub(/: invalid timestamp.*$/, ": " invalid_timestamp_msg, line);
          if (fname_stderr_count++ == 0)
            print "" >> fname_stderr;
          print line >> fname_stderr;
        }
      }

      {
        # Note: In Bash 5.0+, the error message of "invalid timestamp"
        # goes into "stdout" instead of "stderr".
        check_invalid_timestamp($0);
        if (sub(/^ *[0-9]+\*? +(__ble_ext__|\?\?|.+: invalid timestamp)/, "", $0))
          flush_line();
        t = ++n == 1 ? $0 : t "\n" $0;
      }

      END { flush_line(); }
    ' >| "$history_tmpfile.part"
    ble/builtin/history/.check-timestamp-sigsegv "${PIPESTATUS[0]}"
    ble/bin/mv -f "$history_tmpfile.part" "$history_tmpfile"
  }

  ## @fn ble/history:bash/load opts
  ##   @param[in] opts
  ##     async
  ##       Read asynchronously.
  ##     append
  ##       Adds to the currently loaded history information.
  ##     count=NUMBER
  ##       Read only the most recent NUMBER entries.
  function ble/history:bash/load {
    local opts=$1
    local opt_async=; [[ :$opts: == *:async:* ]] && opt_async=1

    local load_strategy=mapfile
    if [[ $OSTYPE == cygwin* || $OSTYPE == msys* ]]; then
      load_strategy=source
    elif ((_ble_bash<50200)); then
      load_strategy=nlfix
    fi

    local arg_count= arg_offset=0 ret
    [[ :$opts: == *:append:* ]] && arg_offset=${#_ble_history[@]}
    ble/opts#extract-last-optarg "$opts" count && arg_count=$ret

    local history_tmpfile=$_ble_base_run/$$.history.load
    local history_indfile=$_ble_base_run/$$.history.multiline-index
    [[ $opt_async || :$opts: == *:init:* ]] || _ble_history_load_resume=0

    [[ ! $opt_async ]] && ((_ble_history_load_resume<6)) &&
      blehook/invoke history_message "loading history ..."
    while ((1)); do
      case $_ble_history_load_resume in

      # 42ms Load history
      (0) # Start history file generation with Background
          if [[ $_ble_history_load_bgpid ]]; then
            builtin kill -9 "$_ble_history_load_bgpid" &>/dev/null
            _ble_history_load_bgpid=
          fi

          >| "$history_tmpfile"
          if [[ $opt_async ]]; then
            _ble_history_load_bgpid=$(ble/util/nohup 'ble/history:bash/load/.background-initialize' print-bgpid)

            function ble/history:bash/load/.background-initialize-completed {
              local history_tmpfile=$_ble_base_run/$$.history.load
              [[ -s $history_tmpfile ]] || ! builtin kill -0 "$_ble_history_load_bgpid"
            } &>/dev/null

            ((_ble_history_load_resume++))
          else
            ble/history:bash/load/.background-initialize
            ((_ble_history_load_resume+=3))
          fi ;;

      # 515ms ble/history:bash/load/.background-initialize wait
      (1) if [[ $opt_async ]] && ble/util/is-running-in-idle; then
            ble/util/idle.wait-condition ble/history:bash/load/.background-initialize-completed
            ((_ble_history_load_resume++))
            return 147
          fi
          ((_ble_history_load_resume++)) ;;

      # Note: Directly (with sync) after starting a background process with async
      #   When called, it will proceed to the next step even if the processing is not completed yet.
      #   Wait for the conditions to be met here (#D0745)
      (2) while ! ble/history:bash/load/.background-initialize-completed; do
            ble/util/msleep 50
            [[ $opt_async ]] && ! ble/util/idle/IS_IDLE && return 148
          done
          ((_ble_history_load_resume++)) ;;

      # 47ms _ble_history initialization (37000 items)
      (3) _ble_history_load_bgpid=
          ((arg_offset==0)) && _ble_history=()
          if [[ $load_strategy == source ]]; then
            # Cygwin #D0701 #D1605
            #   620ms 99000 items @ #D0701
            source -- "$history_tmpfile"
          elif [[ $load_strategy == nlfix ]]; then
            builtin mapfile -O "$arg_offset" -t _ble_history < "$history_tmpfile"
          else
            builtin mapfile -O "$arg_offset" -t -d '' _ble_history < "$history_tmpfile"
          fi
          ble/builtin/history/erasedups/update-base
          ((_ble_history_load_resume++)) ;;

      # 47ms _ble_history_edit initialization (37000 items)
      (4) ((arg_offset==0)) && _ble_history_edit=()
          if [[ $load_strategy == source ]]; then
            # 504ms Cygwin (99000 items)
            _ble_history_edit=("${_ble_history[@]}")
          elif [[ $load_strategy == nlfix ]]; then
            builtin mapfile -O "$arg_offset" -t _ble_history_edit < "$history_tmpfile"
          else
            builtin mapfile -O "$arg_offset" -t -d '' _ble_history_edit < "$history_tmpfile"
          fi
          >| "$history_tmpfile"

          if [[ $load_strategy != nlfix ]]; then
            ((_ble_history_load_resume+=3))
            continue
          else
            ((_ble_history_load_resume++))
          fi ;;

      # 11ms multiple line history correction (107/37000 items)
      (5) local -a indices_to_fix
          ble/util/mapfile indices_to_fix < "$history_indfile"
          local i rex='^eval -- \$'\''([^\'\'']|\\.)*'\''$'
          for i in "${indices_to_fix[@]}"; do
            [[ ${_ble_history[i]} =~ $rex ]] &&
              builtin eval "_ble_history[i]=${_ble_history[i]:8}"
          done
          ((_ble_history_load_resume++)) ;;

      # 11ms multiple line history correction (107/37000 items)
      (6) local -a indices_to_fix
          [[ ${indices_to_fix+set} ]] ||
            ble/util/mapfile indices_to_fix < "$history_indfile"
          local i
          for i in "${indices_to_fix[@]}"; do
            [[ ${_ble_history_edit[i]} =~ $rex ]] &&
              builtin eval "_ble_history_edit[i]=${_ble_history_edit[i]:8}"
          done
          ((_ble_history_load_resume++)) ;;

      (7) [[ $opt_async ]] || blehook/invoke history_message
          ((_ble_history_load_resume++))
          return 0 ;;

      (*) return 1 ;;
      esac

      [[ $opt_async ]] && ! ble/util/idle/IS_IDLE && return 148
    done
  }
  blehook history_reset_background!=_ble_history_load_resume=0
else
  function ble/history:bash/load/.generate-source {
    if ble/builtin/history/is-empty; then
      # When started as rcfile, history is not loaded yet.
      builtin history -n
    fi
    local HISTTIMEFORMAT=__ble_ext__

    # 285ms for 16437 entries
    local apos="'"
    ble/builtin/history/.dump ${arg_count:+"$arg_count"} | ble/bin/awk -v apos="'" '
      BEGIN { n = ""; }

#% # For some reason the timestamp is read as a command
      /^ *[0-9]+\*? +(__ble_ext__|\?\?)#[0-9]/ { next; }

#% # *When read as rcfile, HISTTIMEFORMAT turns into ??.
      /^ *[0-9]+\*? +(__ble_ext__|\?\?|.+: invalid timestamp)/ {
        if (n != "") {
          n = "";
          print "  " apos t apos;
        }

        n = $1; t = "";
        sub(/^ *[0-9]+\*? +(__ble_ext__|\?\?|.+: invalid timestamp)/, "", $0);
      }
      {
        line = $0;
        if (line ~ /^eval -- \$'"$apos"'([^'"$apos"'\\]|\\.)*'"$apos"'$/)
          line = apos substr(line, 9) apos;
        else
          gsub(apos, apos "\\" apos apos, line);

#% # Solution #D1241: Before bash-3.2, ^A, ^? becomes ^A^A, ^A^?
        gsub(/\001/, "'"$apos"'${_ble_term_SOH}'"$apos"'", line);
        gsub(/\177/, "'"$apos"'${_ble_term_DEL}'"$apos"'", line);

#% # Solution #D1270: Disappears when ^M is substituted in MSYS2
        gsub(/\015/, "'"$apos"'${_ble_term_CR}'"$apos"'", line);

        t = t != "" ? t "\n" line : line;
      }
      END {
        if (n != "") {
          n = "";
          print "  " apos t apos;
        }
      }
    '
  }

  function ble/history:bash/load {
    local opts=$1
    local opt_append=
    [[ :$opts: == *:append:* ]] && opt_append=1

    local arg_count= ret
    ble/opts#extract-last-optarg "$opts" count && arg_count=$ret

    blehook/invoke history_message "loading history..."

    # * There is no big difference whether you replace the process or write it to a file.
    #   270ms for 16437 entries (excluding generate-source time)
    # * Process replacement × source does not work in bash-3. Change to eval.
    local result=$(ble/history:bash/load/.generate-source) # subshell
    local IFS=$_ble_term_IFS
    if [[ $opt_append ]]; then
      if ((_ble_bash>=30100)); then
        builtin eval -- "_ble_history+=($result)"
        builtin eval -- "_ble_history_edit+=($result)"
      else
        local -a A; builtin eval -- "A=($result)"
        _ble_history=("${_ble_history[@]}" "${A[@]}")
        _ble_history_edit=("${_ble_history[@]}" "${A[@]}")
      fi
    else
      builtin eval -- "_ble_history=($result)"
      _ble_history_edit=("${_ble_history[@]}")
    fi
    ble/builtin/history/erasedups/update-base
    ble/util/unlocal IFS

    blehook/invoke history_message
  }
fi

function ble/history:bash/initialize {
  [[ $_ble_history_load_done ]] && return 0
  ble/history:bash/load "init:$@"; local ext=$?
  ((ext)) && return "$ext"

  local old_count=$_ble_history_count new_count=${#_ble_history[@]}
  _ble_history_load_done=1
  _ble_history_count=$new_count
  _ble_history_index=$_ble_history_count
  ble/history/.update-position

  # Note: When additionally reading, shift the corresponding data (history_share)
  local delta=$((new_count-old_count))
  ((delta>0)) && blehook/invoke history_change insert "$old_count" "$delta"
}

#------------------------------------------------------------------------------
# Bash history resolve-multiline                            @history.bash.mlfix

if ((_ble_bash>=30100)); then
  # Note: history -s does not work properly in Bash 3.0, so
  # It is currently unclear how to add multi-line history items to builtin history.

  _ble_history_mlfix_done=
  _ble_history_mlfix_resume=0
  _ble_history_mlfix_bgpid=

  ## @fn ble/history:bash/resolve-multiline/.awk reason
  ##
  ##   @param[in] reason
  ##     A string specifying the purpose of the call.
  ##
  ##     resolve ... history reconstruction on initialization
  ##       Parse standard input in the output format of the history command.
  ##       Each line has the form 'number HISTTIMEFORMAT command'.
  ##
  ##     reading from a file with read ... history -r
  ##       Parses standard input in the form of a history file.
  ##       Each line has the form '#%s' or 'command'.
  ##       ble.sh does not support multi-line mode when the first line is '#%s'.
  ##
  ##   @var[in] tmpfile_base
  function ble/history:bash/resolve-multiline/.awk {
    local ret
    ble/util/time
    local -x epoch=$ret

    local -x reason=$1
    local apos=\'
    ble/bin/awk -v apos="$apos" -v _ble_bash="$_ble_bash" '
      BEGIN {
        q = apos;
        Q = apos "\\" apos apos;
        reason = ENVIRON["reason"];
        is_resolve = reason == "resolve";

        TMPBASE = ENVIRON["tmpfile_base"];
        filename_source = TMPBASE ".part";
        if (is_resolve)
          print "builtin history -c" > filename_source

        entry_nline = 0;
        entry_text = "";
        entry_time = "";
        if (_ble_bash >= 40400)
          entry_time = ENVIRON["epoch"];

        command_count = 0;

        multiline_count = 0;
        modification_count = 0;
        read_section_count = 0;
      }
  
      function write_flush(_, i, filename_section, t, c) {
        if (command_count == 0) return;
        if (command_count >= 2 || entry_time) {
          filename_section = TMPBASE "." read_section_count++ ".part";
          for (i = 0; i < command_count; i++) {
            t = command_time[i];
            c = command_text[i];
            if (t) print "#" t > filename_section;
            print c > filename_section;
          }
#% # Note: HISTTIMEFORMAT is specified to enable multi-line reading in bash-4.4.
          print "HISTTIMEFORMAT=%s builtin history -r " filename_section > filename_source;
        } else {
          for (i = 0; i < command_count; i++) {
            c = command_text[i];
            gsub(/'"$apos"'/, Q, c);
            print "builtin history -s -- " q c q > filename_source;
          }
        }
        command_count = 0;
      }
      function write_complex(value) {
        write_flush();
        print "builtin history -s -- " value > filename_source;
      }

      function register_command(cmd) {
        command_time[command_count] = entry_time;
        command_text[command_count] = cmd;
        command_count++;
      }

      function is_escaped_command(cmd) {
        return cmd ~ /^eval -- \$'"$apos"'([^'"$apos"'\\]|\\[\\'"$apos"'nt])*'"$apos"'$/;
      }
      function unescape_command(cmd) {
        cmd = substr(cmd, 11, length(cmd) - 11);
        gsub(/\\\\/, "\\q", cmd);
        gsub(/\\n/, "\n", cmd);
        gsub(/\\t/, "\t", cmd);
        gsub(/\\'"$apos"'/, "'"$apos"'", cmd);
        gsub(/\\q/, "\\", cmd);
        return cmd;
      }
      function register_escaped_command(cmd) {
        multiline_count++;
        modification_count++;
        if (_ble_bash >= 40400) {
          register_command(unescape_command(cmd));
        } else {
          write_complex(substr(cmd, 9));
        }
      }

      function register_multiline_command(cmd) {
        multiline_count++;
        if (_ble_bash >= 40040) {
          register_command(cmd);
        } else {
          gsub(/'"$apos"'/, Q, cmd);
          write_complex(q cmd q);
        }
      }
  
      function flush_entry() {
        if (entry_nline < 1) return;

        if (is_escaped_command(entry_text)) {
          register_escaped_command(entry_text)
        } else if (entry_nline > 1) {
          register_multiline_command(entry_text);
        } else {
          register_command(entry_text);
        }
  
        entry_nline = 0;
        entry_text = "";
      }

      function save_timestamp(line) {
        if (is_resolve) {
          # "history" format
          if (line ~ /^ *[0-9]+\*? +__ble_time_[0-9]*__/) {
            sub(/^ *[0-9]+\*? +__ble_time_/, "", line);
            sub(/__.*$/, "", line);
            entry_time = line;
          }
        } else {
          # "history -w" format
          if (line ~ /^#[0-9]/) {
            sub(/^#/, "", line);
            sub(/[^0-9].*$/, "", line);
            entry_time = line;
          }
        }
      }
  
      {
        if (is_resolve) {
          save_timestamp($0);
          if (sub(/^ *[0-9]+\*? +(__ble_time_[0-9]*__|\?\?|.+: invalid timestamp)/, "", $0))
            flush_entry();
          entry_text = ++entry_nline == 1 ? $0 : entry_text "\n" $0;
        } else {
          if ($0 ~ /^#[0-9]/) {
            save_timestamp($0);
            next;
          } else {
            flush_entry();
            entry_text = $0;
            entry_nline = 1;
          }
        }
      }
  
      END {
        flush_entry();
        write_flush();
        if (is_resolve)
          print "builtin history -a /dev/null" > filename_source
        print "multiline_count=" multiline_count;
        print "modification_count=" modification_count;
      }
    '
  }
  ## @fn ble/history:bash/resolve-multiline/.cleanup
  ##   @var[in] tmpfile_base
  function ble/history:bash/resolve-multiline/.cleanup {
    local file
    for file in "$tmpfile_base".*; do >| "$file"; done
  }
  function ble/history:bash/resolve-multiline/.worker {
    local HISTTIMEFORMAT=__ble_time_%s__
    local -x tmpfile_base=$_ble_base_run/$$.history.mlfix
    local multiline_count=0 modification_count=0
    builtin eval -- "$(ble/builtin/history/.dump | ble/history:bash/resolve-multiline/.awk resolve 2>/dev/null)"
    if ((modification_count)); then
      ble/bin/mv -f "$tmpfile_base.part" "$tmpfile_base.sh"
    else
      ble/util/print : >| "$tmpfile_base.sh"
    fi
  }
  function ble/history:bash/resolve-multiline/.is-HISTSIZE-unlimited {
    [[ ${HISTSIZE+set} ]] || return 1

    # Note: When the value of HISTSIZE does not match a number, it seems that
    # historical bash has consistently treated it as unlimited history size.
    # When it matches a number, the history size is limited to the specified
    # value in Bash <= 4.2.  In Bash >= 4.3, the interpretatiion of negative
    # numbers (in 32-bit representation) has been changed to mean the unlimited
    # history size.
    ble/string#match "$HISTSIZE" '^[[:space:]]([-+]?[0-9]+)[[:space:]]*$' || return 0
    local histsize=$((BASH_REMATCH[1]))
    ((_ble_bash>=40300&&(histize&0x10000000)))
  }
  function ble/history:bash/resolve-multiline/.load {
    local tmpfile_base=$_ble_base_run/$$.history.mlfix

    # Note: We skip setting HISTSIZE= when it already means the unlimited
    # history size in case HISTSIZE is marked as "readonly."
    ble/history:bash/resolve-multiline/.is-HISTSIZE-unlimited || local HISTSIZE=

    local HISTCONTROL= HISTIGNORE=
    source -- "$tmpfile_base.sh"
    ble/history:bash/resolve-multiline/.cleanup
  }

  ## @fn ble/history:bash/resolve-multiline opts
  ##   @param[in] opts
  ##     async
  ##       Read asynchronously.
  function ble/history:bash/resolve-multiline.impl {
    local opts=$1
    local opt_async=; [[ :$opts: == *:async:* ]] && opt_async=1

    local history_tmpfile=$_ble_base_run/$$.history.mlfix.sh
    [[ $opt_async || :$opts: == *:init:* ]] || _ble_history_mlfix_resume=0

    [[ ! $opt_async ]] && ((_ble_history_mlfix_resume<=4)) &&
      blehook/invoke history_message "resolving multiline history ..."
    while ((1)); do
      case $_ble_history_mlfix_resume in

      (0) if [[ $opt_async ]] && ble/builtin/history/is-empty; then
            # Note: Do not use resolve-multiline in bashrc.
            #   Try again after bash has read the history.
            ble/util/idle.wait-user-input
            ((_ble_history_mlfix_resume++))
            return 147
          fi
          ((_ble_history_mlfix_resume++)) ;;

      (1) # Start history file generation with Background
        if [[ $_ble_history_mlfix_bgpid ]]; then
          builtin kill -9 "$_ble_history_mlfix_bgpid" &>/dev/null
          _ble_history_mlfix_bgpid=
        fi

        >| "$history_tmpfile"
        if [[ $opt_async ]]; then
          _ble_history_mlfix_bgpid=$(ble/util/nohup 'ble/history:bash/resolve-multiline/.worker' print-bgpid)

          function ble/history:bash/resolve-multiline/.worker-completed {
            local history_tmpfile=$_ble_base_run/$$.history.mlfix.sh
            [[ -s $history_tmpfile ]] || ! builtin kill -0 "$_ble_history_mlfix_bgpid"
          } &>/dev/null

          ((_ble_history_mlfix_resume++))
        else
          ble/history:bash/resolve-multiline/.worker
          ((_ble_history_mlfix_resume+=3))
        fi ;;

      (2) if [[ $opt_async ]] && ble/util/is-running-in-idle; then
            ble/util/idle.wait-condition ble/history:bash/resolve-multiline/.worker-completed
            ((_ble_history_mlfix_resume++))
            return 147
          fi
          ((_ble_history_mlfix_resume++)) ;;

      # Note: Directly (with sync) after starting a background process with async
      #   When called, it will proceed to the next step even if the processing is not completed yet.
      #   Wait for the conditions to be met here (#D0745)
      (3) while ! ble/history:bash/resolve-multiline/.worker-completed; do
            ble/util/msleep 50
            [[ $opt_async ]] && ! ble/util/idle/IS_IDLE && return 148
          done
          ((_ble_history_mlfix_resume++)) ;;

      # 80ms history reconstruction (47000 items)
      (4) _ble_history_mlfix_bgpid=
          ble/history:bash/resolve-multiline/.load
          [[ $opt_async ]] || blehook/invoke history_message
          ((_ble_history_mlfix_resume++))
          return 0 ;;

      (*) return 1 ;;
      esac

      [[ $opt_async ]] && ! ble/util/idle/IS_IDLE && return 148
    done
  }

  function ble/history:bash/resolve-multiline {
    [[ $_ble_history_mlfix_done ]] && return 0
    if [[ $1 == sync ]]; then
      ((_ble_bash>=40000)) && [[ $BASHPID != $$ ]] && return 0
      ble/builtin/history/is-empty && return 0
    fi

    ble/history:bash/resolve-multiline.impl "$@"; local ext=$?
    ((ext)) && return "$ext"
    _ble_history_mlfix_done=1
    return 0
  }
  ((_ble_bash>=40000)) &&
    ble/util/idle.push 'ble/history:bash/resolve-multiline async'

  blehook history_reset_background!=_ble_history_mlfix_resume=0

  function ble/history:bash/resolve-multiline/readfile {
    local filename=$1
    local -x tmpfile_base=$_ble_base_run/$$.history.read
    ble/history:bash/resolve-multiline/.awk read < "$filename" &>/dev/null
    source -- "$tmpfile_base.part"
    ble/history:bash/resolve-multiline/.cleanup
  }
else
  function ble/history:bash/resolve-multiline/readfile { builtin history -r "$filename"; }
  function ble/history:bash/resolve-multiline { return 0; }
fi

# Note: Multi-line commands should be converted to eval -- $''
#   I want to write it, so I'll handle it myself.
function ble/history:bash/unload.hook {
  ble/util/is-running-in-subshell && return 0
  if shopt -q histappend &>/dev/null; then
    ble/builtin/history -a
  else
    ble/builtin/history -w
  fi
}
blehook unload!=ble/history:bash/unload.hook

function ble/history:bash/reset {
  if ((_ble_bash>=40000)); then
    _ble_history_load_done=
    ble/history:bash/clear-background-load
    ble/util/idle.push 'ble/history:bash/initialize async'
  elif ((_ble_bash>=30100)) && [[ $bleopt_history_lazyload ]]; then
    _ble_history_load_done=
  else
    # * History-load is performed with attach instead of initialize.
    #   Between detach and attach
    #   Because there may be entries added.
    # * In bash-3.0, history -s only replaces recent history items, so
    #   You must process all history items yourself.
    #   In other words, it must be loaded from the beginning.
    ble/history:bash/initialize
  fi
}


#------------------------------------------------------------------------------
# ble/builtin/history                                     @history.bash.builtin

function ble/builtin/history/.touch-histfile {
  local touch=$_ble_base_run/$$.history.touch
  >| "$touch"
}

# in def.sh
# @hook history_change

# Note: #D1126 Once replaced, it cannot be returned. Do not initialize twice.
if [[ ! ${_ble_builtin_history_initialized+set} ]]; then
  _ble_builtin_history_initialized=
  _ble_builtin_history_histnew_count=0
  _ble_builtin_history_histapp_count=0
  ## @var _ble_builtin_history_wskip
  ##   This is a variable that manages the number of lines in the history that have already been written to the file.
  ## @var _ble_builtin_history_prevmax
  ##   Builtin history item number in last ble/builtin/history
  _ble_builtin_history_wskip=0
  _ble_builtin_history_prevmax=0

  ##
  ## The following function records how far it has read for each file.
  ##
  ## @fn ble/builtin/history/.get-rskip file
  ##   @param[in] file
  ##   @var[out] rskip
  ## @fn ble/builtin/history/.set-rskip file value
  ##   @param[in] file
  ## @fn ble/builtin/history/.add-rskip file delta
  ##   @param[in] file
  ##
  builtin eval -- "${_ble_util_gdict_declare//NAME/_ble_builtin_history_rskip_dict}"
  function ble/builtin/history/.get-rskip {
    local file=$1 ret
    ble/gdict#get _ble_builtin_history_rskip_dict "$file"
    rskip=$ret
  }
  function ble/builtin/history/.set-rskip {
    local file=$1
    ble/gdict#set _ble_builtin_history_rskip_dict "$file" "$2"
  }
  function ble/builtin/history/.add-rskip {
    local file=$1 ret
    # Note: Initially we used the format ((dict[\$file]+=$2)), but this
    #   It turned out that shopt -s assoc_expand_once does not work, so
    #   First, calculate it using another variable and then substitute it.
    ble/gdict#get _ble_builtin_history_rskip_dict "$file"
    ((ret+=$2))
    ble/gdict#set _ble_builtin_history_rskip_dict "$file" "$ret"
  }
fi

## @fn ble/builtin/history/.initialize opts
##   @param[in] opts
##     skip0 ... In a state where it cannot be determined that Bash initialization processing (bashrc) has been exited,
## Skip when no history has been loaded.
function ble/builtin/history/.initialize {
  [[ $_ble_builtin_history_initialized ]] && return 0
  local line; ble/util/assign line 'builtin history 1'
  [[ ! $_ble_decode_hook_count && ! $line && :$1: == *:skip0:* ]] && return 1
  _ble_builtin_history_initialized=1

  local histnew=$_ble_base_run/$$.history.new
  >| "$histnew"

  if [[ $line ]]; then
    # Note: #D1126 Save any history items added before loading ble.sh.
    local histini=$_ble_base_run/$$.history.ini
    local histapp=$_ble_base_run/$$.history.app
    HISTTIMEFORMAT=1 builtin history -a "$histini"
    if [[ -s $histini ]]; then
      ble/bin/sed '/^#\([0-9].*\)/{s//    0  __ble_time_\1__/;N;s/\n//;}' "$histini" >> "$histapp"
      >| "$histini"
    fi
  else
    # Force the history to load if it is not loaded
    ble/builtin/history/option:r
  fi

  local histfile=${HISTFILE-} rskip=0
  [[ -e $histfile ]] && ble/util/assign rskip 'ble/bin/wc -l "$histfile" 2>/dev/null'
  ble/string#split-words rskip "$rskip"
  local min; ble/builtin/history/.get-min
  local max; ble/builtin/history/.get-max
  ((max&&max-min+1<rskip&&(rskip=max-min+1)))
  _ble_builtin_history_wskip=$max
  _ble_builtin_history_prevmax=$max
  ble/builtin/history/.set-rskip "$histfile" "$rskip"
  return 0
}
## @fn ble/builtin/history/.delete-range beg end
function ble/builtin/history/.delete-range {
  local beg=$1 end=${2:-$1}
  if ((_ble_bash>=50000&&beg<end)); then
    builtin history -d "$beg-$end"
  else
    local i
    for ((i=end;i>=beg;i--)); do
      builtin history -d "$i"
    done
  fi
}
## @fn ble/builtin/history/.check-uncontrolled-change [filename opts]
##   When history is read outside of ble/builtin/history,
##   Update wskip to exclude it from history -a.
function ble/builtin/history/.check-uncontrolled-change {
  [[ $_ble_decode_bind_state == none ]] && return 0
  local filename=${1-} opts=${2-} prevmax=$_ble_builtin_history_prevmax
  local max; ble/builtin/history/.get-max
  if ((max!=prevmax)); then
    if [[ $filename && :$opts: == *:append:* ]] && ((_ble_builtin_history_wskip<prevmax&&prevmax<max)); then
      # Write the range wskip..prevmax that was last confirmed to have been added under management.
      (
        ble/util/joblist/__suppress__
        ble/builtin/history/.delete-range "$((prevmax+1))" "$max"
        ble/builtin/history/.write "$filename" "$_ble_builtin_history_wskip" append:fetch
      )
    fi
    _ble_builtin_history_wskip=$max
    _ble_builtin_history_prevmax=$max
  fi
}
## @fn ble/builtin/history/.load-recent-entries count
##   Loads the latest count entries from history into the array _ble_history.
function ble/builtin/history/.load-recent-entries {
  [[ $_ble_decode_bind_state == none ]] && return 0

  local delta=$1
  ((delta>0)) || return 0

  if [[ ! $_ble_history_load_done ]]; then
    # If history load is not completed, discard the data being read and return.
    ble/history:bash/clear-background-load
    _ble_history_count=
    return 0
  fi

  # If there are a large number of additional items, completely reinitialize with background
  if ((_ble_bash>=40000&&delta>=10000)); then
    ble/history:bash/reset
    return 0
  fi

  ble/history:bash/load append:count=$delta

  local ocount=$_ble_history_count ncount=${#_ble_history[@]}
  ((_ble_history_index==_ble_history_count)) && _ble_history_index=$ncount
  _ble_history_count=$ncount
  ble/history/.update-position
  blehook/invoke history_change insert "$ocount" "$delta"
}
## @fn ble/builtin/history/.read file [skip [fetch]]
function ble/builtin/history/.read {
  local file=$1 skip=${2:-0} fetch=$3
  local -x histnew=$_ble_base_run/$$.history.new
  if [[ -s $file ]]; then
    local awk_script='
      BEGIN { histnew = ENVIRON["histnew"]; count = 0; }
      NR <= skip { next; }
      { print $0 >> histnew; count++; }
      END {
        print "ble/builtin/history/.set-rskip \"$file\" " NR;
        print "((_ble_builtin_history_histnew_count+=" count "))";
      }'
    ble/util/eval-stdout 'ble/bin/awk -v skip="$skip" "$awk_script" "$file"'
  else
    ble/builtin/history/.set-rskip "$file" 0
  fi
  if [[ ! $fetch && -s $histnew ]]; then
    local nline=$_ble_builtin_history_histnew_count
    ble/history:bash/resolve-multiline/readfile "$histnew"
    >| "$histnew"
    _ble_builtin_history_histnew_count=0
    ble/builtin/history/.load-recent-entries "$nline"
    local max; ble/builtin/history/.get-max
    _ble_builtin_history_wskip=$max
    _ble_builtin_history_prevmax=$max
  fi
}
## @fn ble/builtin/history/.write file [skip [opts]]
function ble/builtin/history/.write {
  local -x file=$1 skip=${2:-0} opts=$3
  local -x histapp=$_ble_base_run/$$.history.app
  declare -p HISTTIMEFORMAT &>/dev/null
  local -x flag_timestamp=$(($?==0))

  local min; ble/builtin/history/.get-min
  local max; ble/builtin/history/.get-max
  ((skip<min-1&&(skip=min-1)))
  local delta=$((max-skip))
  if ((delta>0)); then
    local HISTTIMEFORMAT=__ble_time_%s__
    if [[ :$opts: == *:append:* ]]; then
      ble/builtin/history/.dump "$delta" >> "$histapp"
      ((_ble_builtin_history_histapp_count+=delta))
    else
      ble/builtin/history/.dump "$delta" >| "$histapp"
      _ble_builtin_history_histapp_count=$delta
    fi
  fi

  if [[ ! -e $file ]]; then
    (umask 077; >| "$file")
  elif [[ :$opts: != *:append:* ]]; then
    >| "$file"
  fi

  if [[ :$opts: != *:fetch:* && -s $histapp ]]; then
    local apos=\'
    < "$histapp" ble/bin/awk '
      BEGIN {
        file = ENVIRON["file"];
        flag_timestamp = ENVIRON["flag_timestamp"];
        timestamp = "";
        mode = 0;
      }
      function flush_line() {
        if (!mode) return;
        mode = 0;
        if (text ~ /\n/) {
          gsub(/['"$apos"'\\]/, "\\\\&", text);
          gsub(/\n/, "\\n", text);
          gsub(/\t/, "\\t", text);
          text = "eval -- $'"$apos"'" text "'"$apos"'"
        }

        if (timestamp != "")
          print timestamp >> file;
        print text >> file;
      }

      function extract_timestamp(line) {
        if (!sub(/^ *[0-9]+\*? +__ble_time_/, "", line)) return "";
        if (!sub(/__.*$/, "", line)) return "";
        if (!(line ~ /^[0-9]+$/)) return "";
        return "#" line;
      }

      # Note (#D2163): We match /__ble_time_[0-9]*__/ instead of
      # /__ble_time_[0-9]+__/ because %s in HISTTIMESTAMP can be expanded to an
      # empty string in bash-3.1 of msys1.
      /^ *[0-9]+\*? +(__ble_time_[0-9]*__|\?\?|.+: invalid timestamp)?/ {
        flush_line();

        mode = 1;
        text = "";
        if (flag_timestamp)
          timestamp = extract_timestamp($0);

        sub(/^ *[0-9]+\*? +(__ble_time_[0-9]*__|\?\?|.+: invalid timestamp)?/, "", $0);
      }
      { text = text != "" ? text "\n" $0 : $0; }
      END { flush_line(); }
    '
    ble/builtin/history/.add-rskip "$file" "$_ble_builtin_history_histapp_count"
    >| "$histapp"
    _ble_builtin_history_histapp_count=0
  fi
  _ble_builtin_history_wskip=$max
  _ble_builtin_history_prevmax=$max
}

## @fn ble/builtin/history/array#delete-hindex array_name index...
##   @param[in] index
##     Assume that they are arranged in ascending order and that there are no duplicates.
function ble/builtin/history/array#delete-hindex {
  local array_name=$1; shift
  local script='
    local -a out=()
    local i shift=0
    for i in "${!NAME[@]}"; do
      local delete=
      while (($#)); do
        if [[ $1 == *-* ]]; then
          local b=${1%-*} e=${1#*-}
          ((i<b)) && break
          if ((i<e)); then
            delete=1 # delete
            break
          else
            ((shift+=e-b))
            shift
          fi
        else
          ((i<$1)) && break
          ((i==$1)) && delete=1
          ((shift++))
          shift
        fi
      done
      [[ ! $delete ]] &&
        out[i-shift]=${NAME[i]}
    done
    NAME=()
    for i in "${!out[@]}"; do NAME[i]=${out[i]}; done'
  builtin eval -- "${script//NAME/$array_name}"
}
## @fn ble/builtin/history/array#insert-range array_name beg len
function ble/builtin/history/array#insert-range {
  local array_name=$1 beg=$2 len=$3
  local script='
    local -a out=()
    local i
    for i in "${!NAME[@]}"; do
      out[i<beg?beg:i+len]=${NAME[i]}
    done
    NAME=()
    for i in "${!out[@]}"; do NAME[i]=${out[i]}; done'
  builtin eval -- "${script//NAME/$array_name}"
}
blehook history_change!=ble/builtin/history/change.hook
function ble/builtin/history/change.hook {
  local kind=$1; shift
  case $kind in
  (delete)
    ble/builtin/history/array#delete-hindex _ble_history_dirt "$@" ;;
  (clear)
    _ble_history_dirt=() ;;
  (insert)
    # Note: _ble_history, _ble_history_edit are updated separately.
    ble/builtin/history/array#insert-range _ble_history_dirt "$@" ;;
  esac
}
## @fn ble/builtin/history/option:c
function ble/builtin/history/option:c {
  ble/builtin/history/.initialize skip0 || return "$?"
  builtin history -c
  _ble_builtin_history_wskip=0
  _ble_builtin_history_prevmax=0
  if [[ $_ble_decode_bind_state != none ]]; then
    if [[ $_ble_history_load_done ]]; then
      _ble_history=()
      _ble_history_edit=()
      _ble_history_count=0
      _ble_history_index=0
    else
      # If history load is not completed, discard the data being read and return.
      ble/history:bash/clear-background-load
      _ble_history_count=
    fi
    ble/history/.update-position
    blehook/invoke history_change clear
  fi
}
## @fn ble/builtin/history/option:d index
function ble/builtin/history/option:d {
  ble/builtin/history/.initialize skip0 || return "$?"
  local rex='^(-?[0-9]+)-(-?[0-9]+)$'
  if [[ $1 =~ $rex ]]; then
    local beg=${BASH_REMATCH[1]} end=${BASH_REMATCH[2]}
  else
    local beg=$(($1))
    local end=$beg
  fi
  local min; ble/builtin/history/.get-min
  local max; ble/builtin/history/.get-max
  ((beg<0)) && ((beg+=max+1)); ((beg<min?(beg=min):(beg>max&&(beg=max))))
  ((end<0)) && ((end+=max+1)); ((end<min?(end=min):(end>max&&(end=max))))
  ((beg<=end)) || return 0

  ble/builtin/history/.delete-range "$beg" "$end"
  if ((_ble_builtin_history_wskip>=end)); then
    ((_ble_builtin_history_wskip-=end-beg+1))
  elif ((_ble_builtin_history_wskip>beg-1)); then
    ((_ble_builtin_history_wskip=beg-1))
  fi

  if [[ $_ble_decode_bind_state != none ]]; then
    if [[ $_ble_history_load_done ]]; then
      local N=${#_ble_history[@]}
      local b=$((beg-1+N-max)) e=$((end+N-max))
      blehook/invoke history_change delete "$b-$e"
      if ((_ble_history_index>=e)); then
        ((_ble_history_index-=e-b))
      elif ((_ble_history_index>=b)); then
        _ble_history_index=$b
      fi
      _ble_history=("${_ble_history[@]::b}" "${_ble_history[@]:e}")
      _ble_history_edit=("${_ble_history_edit[@]::b}" "${_ble_history_edit[@]:e}")
      _ble_history_count=${#_ble_history[@]}
    else
      # If history load is not completed, discard the data being read and return.
      ble/history:bash/clear-background-load
      _ble_history_count=
    fi
    ble/history/.update-position
  fi
  local max; ble/builtin/history/.get-max
  _ble_builtin_history_prevmax=$max
}
function ble/builtin/history/.get-histfile {
  histfile=${1:-${HISTFILE-}}
  if [[ ! $histfile ]]; then
    local opt=-a
    [[ ${FUNCNAME[1]} == *:[!:] ]] && opt=-${FUNCNAME[1]##*:}
    if [[ ${1+set} ]]; then
      ble/util/print "ble/builtin/history $opt: the history filename is empty." >&2
    else
      ble/util/print "ble/builtin/history $opt: the history file is not specified." >&2
    fi
    return 1
  fi
}
## @fn ble/builtin/history/option:a [filename]
function ble/builtin/history/option:a {
  ble/builtin/history/.initialize skip0 || return "$?"
  local histfile; ble/builtin/history/.get-histfile "$@" || return "$?"
  ble/builtin/history/.check-uncontrolled-change "$histfile" append
  local rskip; ble/builtin/history/.get-rskip "$histfile"
  ble/builtin/history/.write "$histfile" "$_ble_builtin_history_wskip" append:fetch
  [[ -r $histfile ]] && ble/builtin/history/.read "$histfile" "$rskip" fetch
  ble/builtin/history/.write "$histfile" "$_ble_builtin_history_wskip" append
  builtin history -a /dev/null # Don't write on Bash exit
}
## @fn ble/builtin/history/option:n [filename]
function ble/builtin/history/option:n {
  # Skip if HISTFILE has not been updated
  local histfile; ble/builtin/history/.get-histfile "$@" || return "$?"
  if [[ $histfile == ${HISTFILE-} ]]; then
    local touch=$_ble_base_run/$$.history.touch
    [[ $touch -nt ${HISTFILE-} ]] && return 0
    >| "$touch"
  fi

  ble/builtin/history/.initialize
  local rskip; ble/builtin/history/.get-rskip "$histfile"
  ble/builtin/history/.read "$histfile" "$rskip"
}
## @fn ble/builtin/history/option:w [filename]
function ble/builtin/history/option:w {
  ble/builtin/history/.initialize skip0 || return "$?"
  local histfile; ble/builtin/history/.get-histfile "$@" || return "$?"
  local rskip; ble/builtin/history/.get-rskip "$histfile"
  [[ -r $histfile ]] && ble/builtin/history/.read "$histfile" "$rskip" fetch
  ble/builtin/history/.write "$histfile" 0
  builtin history -a /dev/null # Don't write on Bash exit
}
## @fn ble/builtin/history/option:r [histfile]
function ble/builtin/history/option:r {
  local histfile; ble/builtin/history/.get-histfile "$@" || return "$?"
  ble/builtin/history/.initialize
  ble/builtin/history/.read "$histfile" 0
}
## @fn ble/builtin/history/option:p
##   Workaround for bash-3.0 -- 5.0 bug
##   (See memo.txt #D0233, #D0801, #D1091)
function ble/builtin/history/option:p {
  # Note: auto-complete .search-history-light and
  #   history -p is called via magic-space etc.
  #   If resolve-multiline is synced at that time, it will get caught.
  #   Therefore, I decided not to sync with history -p (#D1121)
  # Note: Background load is not possible in bash-3, so
  #   Initialize when history -p is first called (#D1122)
  ((_ble_bash>=40000)) || ble/builtin/history/is-empty ||
    ble/history:bash/resolve-multiline sync

  # Note: Check if history -p '' reduces history entries,
  #   If the number of history items is decreasing, increase the number of history items and then execute history -p.
  #   I used to evaluate it in a subshell, but then the substitution specifier was not recorded.
  #   :& will not be executed correctly, so switch to this implementation.
  local line1= line2=
  ble/util/assign line1 'HISTTIMEFORMAT= builtin history 1'
  builtin history -p -- '' &>/dev/null
  ble/util/assign line2 'HISTTIMEFORMAT= builtin history 1'
  if [[ $line1 != "$line2" ]]; then
    local rex_head='^[[:blank:]]*[0-9]+\*?[[:blank:]]*'
    [[ $line1 =~ $rex_head ]] &&
      line1=${line1:${#BASH_REMATCH}}

    if ((_ble_bash<30100)); then
      # Note: history -r will display previous history items at the end.
      #   It will no longer be reflected in .bash_history, but
      #   In Bash 3.0, it is written explicitly, so there is no problem.
      local tmp=$_ble_base_run/$$.history.tmp
      printf '%s\n' "$line1" "$line1" >| "$tmp"
      builtin history -r "$tmp"
    else
      builtin history -s -- "$line1"
      builtin history -s -- "$line1"
    fi
  fi

  builtin history -p -- "$@"
}

bleopt/declare -v history_erasedups_limit 0
: "${_ble_history_erasedups_base=}"

function ble/builtin/history/erasedups/update-base {
  if [[ ! ${_ble_history_erasedups_base:-} ]]; then
    _ble_history_erasedups_base=${#_ble_history[@]}
  else
    local value=${#_ble_history[@]}
    ((value<_ble_history_erasedups_base&&(_ble_history_erasedups_base=value)))
  fi
}
## @fn ble/builtin/history/erasedups/.impl-for cmd
## @fn ble/builtin/history/erasedups/.impl-awk cmd
## @fn ble/builtin/history/erasedups/.impl-ranged cmd beg
##   @param[in] cmd
##   @var[in] N
##   @var[in] HISTINDEX_NEXT
##   @var[in] _ble_builtin_history_wskip
##   @arr[out] delete_indices
##   @var[out] shift_histindex_next
##   @var[out] shift_wskip
function ble/builtin/history/erasedups/.impl-for {
  local cmd=$1
  delete_indices=()
  shift_histindex_next=0
  shift_wskip=0

  local i
  for ((i=0;i<N-1;i++)); do
    if [[ ${_ble_history[i]} == "$cmd" ]]; then
      builtin unset -v '_ble_history[i]'
      builtin unset -v '_ble_history_edit[i]'
      ble/array#push delete_indices "$i"
      ((i<_ble_builtin_history_wskip&&shift_wskip++))
      ((i<HISTINDEX_NEXT&&shift_histindex_next++))
    fi
  done
  if ((${#delete_indices[@]})); then
    _ble_history=("${_ble_history[@]}")
    _ble_history_edit=("${_ble_history_edit[@]}")
  fi
}
function ble/builtin/history/erasedups/.impl-awk {
  local cmd=$1
  delete_indices=()
  shift_histindex_next=0
  shift_wskip=0
  ((N)) || return 0

  # select the fastest awk implementation
  local -x erasedups_nlfix_read=
  local awk writearray_options
  if ble/bin/awk0.available; then
    erasedups_nlfix_read=
    writearray_options=(-d '')
    awk=ble/bin/awk0
  else
    erasedups_nlfix_read=1
    writearray_options=(--nlfix)
    if ble/is-function ble/bin/mawk; then
      awk=ble/bin/mawk
    elif ble/is-function ble/bin/gawk; then
      awk=ble/bin/gawk
    else
      ble/builtin/history/erasedups/.impl-for "$@"
      return "$?"
    fi
  fi

  local _ble_local_tmpfile
  ble/util/assign/mktmp; local otmp1=$_ble_local_tmpfile
  ble/util/assign/mktmp; local otmp2=$_ble_local_tmpfile
  ble/util/assign/mktmp; local itmp1=$_ble_local_tmpfile
  ble/util/assign/mktmp; local itmp2=$_ble_local_tmpfile

  # Note: Run in subshell to disable job
  ( ble/util/writearray "${writearray_options[@]}" _ble_history      >| "$itmp1" & local pid1=$!
    ble/util/writearray "${writearray_options[@]}" _ble_history_edit >| "$itmp2"
    wait "$pid1" )

  local -x erasedups_cmd=$cmd
  local -x erasedups_out1=$otmp1
  local -x erasedups_out2=$otmp2
  local -x erasedups_histindex_next=$HISTINDEX_NEXT
  local -x erasedups_wskip=$_ble_builtin_history_wskip
  local awk_script='
    '"$_ble_bin_awk_libES"'
    '"$_ble_bin_awk_libNLFIX"'

    BEGIN {
      NLFIX_READ     = ENVIRON["erasedups_nlfix_read"] != "";
      cmd            = ENVIRON["erasedups_cmd"];
      out1           = ENVIRON["erasedups_out1"];
      out2           = ENVIRON["erasedups_out2"];
      histindex_next = ENVIRON["erasedups_histindex_next"];
      wskip          = ENVIRON["erasedups_wskip"];

      if (NLFIX_READ)
        es_initialize();
      else
        RS = "\0";

      NLFIX_WRITE = _ble_bash < 50200;
      if (NLFIX_WRITE) nlfix_begin();

      hist_index = 0;
      edit_index = 0;
      delete_count = 0;
      shift_histindex_next = 0;
      shift_wskip = 0;
    }

    function process_hist(elem) {
      if (hist_index < N - 1 && elem == cmd) {
        delete_indices[delete_count++] = hist_index;
        delete_table[hist_index] = 1;
        if (hist_index < wskip         ) shift_wskip++;
        if (hist_index < histindex_next) shift_histindex_next++;
      } else {
        if (NLFIX_WRITE)
          nlfix_push(elem, out1);
        else
          printf("%s%c", elem, 0) > out1;
      }
      hist_index++;
    }

    function process_edit(elem) {
      if (delete_count == 0) exit;
      if (NLFIX_WRITE) {
        if (edit_index == 0) {
          nlfix_end(out1);
          nlfix_begin();
        }
        if (!delete_table[edit_index++])
          nlfix_push(elem, out2);
      } else {
        if (!delete_table[edit_index++])
          printf("%s%c", elem, 0) > out2;
      }
    }

    mode == "edit" {
      if (NLFIX_READ) {
        edit[edit_index++] = $0;
      } else {
        process_edit($0);
      }
      next;
    }
    {
      if (NLFIX_READ)
        hist[hist_index++] = $0;
      else
        process_hist($0);
    }

    END {
      if (NLFIX_READ) {
        n = split(hist[hist_index - 1], indices)
        for (i = 1; i <= n; i++) {
          elem = hist[indices[i]];
          if (elem ~ /^\$'\''.*'\''/)
            hist[indices[i]] = es_unescape(substr(elem, 3, length(elem) - 3)); # disable=#D1440 (\c? is unsed)
        }
        n = hist_index - 1;
        hist_index = 0;
        for (i = 0; i < n; i++)
          process_hist(hist[i]);

        n = split(edit[edit_index - 1], indices)
        for (i = 1; i <= n; i++) {
          elem = edit[indices[i]];
          if (elem ~ /^\$'\''.*'\''/)
            edit[indices[i]] = es_unescape(substr(elem, 3, length(elem) - 3)); # disable=#D1440 (\c? is unsed)
        }
        n = edit_index - 1;
        edit_index = 0;
        for (i = 0; i < n; i++)
          process_edit(edit[i]);
      }

      if (NLFIX_WRITE) nlfix_end(out2);

      line = "delete_indices=("
      for (i = 0; i < delete_count; i++) {
        if (i != 0) line = line " ";
        line = line delete_indices[i];
      }
      line = line ")";
      print line;
      print "shift_wskip=" shift_wskip;
      print "shift_histindex_next=" shift_histindex_next;
    }
  '
  local awk_result
  ble/util/assign awk_result '"$awk" -v _ble_bash="$_ble_bash" -v N="$N" "$awk_script" "$itmp1" mode=edit "$itmp2"'
  builtin eval -- "$awk_result"
  if ((${#delete_indices[@]})); then
    if ((_ble_bash<50200)); then
      ble/util/readarray --nlfix _ble_history      < "$otmp1"
      ble/util/readarray --nlfix _ble_history_edit < "$otmp2"
    else
      mapfile -d '' -t _ble_history      < "$otmp1"
      mapfile -d '' -t _ble_history_edit < "$otmp2"
    fi
  fi
  _ble_local_tmpfile=$itmp2 ble/util/assign/rmtmp
  _ble_local_tmpfile=$itmp1 ble/util/assign/rmtmp
  _ble_local_tmpfile=$otmp2 ble/util/assign/rmtmp
  _ble_local_tmpfile=$otmp1 ble/util/assign/rmtmp
}
function ble/builtin/history/erasedups/.impl-ranged {
  local cmd=$1 beg=$2
  delete_indices=()
  shift_histindex_next=0
  shift_wskip=0

  # Note: Since you will run history -d yourself to delete duplicates, remove erasedups.
  # However, since you will not delete only the last matching element yourself, use history -s later.
  # Add ignoredups to prevent extra history items from being added.
  ble/path#remove HISTCONTROL erasedups
  HISTCONTROL=$HISTCONTROL:ignoredups

  local i j=$beg
  for ((i=beg;i<N;i++)); do
    if ((i<N-1)) && [[ ${_ble_history[i]} == "$cmd" ]]; then
      ble/array#push delete_indices "$i"
      ((i<_ble_builtin_history_wskip&&shift_wskip++))
      ((i<HISTINDEX_NEXT&&shift_histindex_next++))
    else
      if ((i!=j)); then
        _ble_history[j]=${_ble_history[i]}
        _ble_history_edit[j]=${_ble_history_edit[i]}
      fi
      ((j++))
    fi
  done
  for ((;j<N;j++)); do
    builtin unset -v '_ble_history[j]'
    builtin unset -v '_ble_history_edit[j]'
  done

  if ((${#delete_indices[@]})); then
    local max; ble/builtin/history/.get-max
    local max_index=$((N-1))
    for ((i=${#delete_indices[@]}-1;i>=0;i--)); do
      builtin history -d "$((delete_indices[i]-max_index+max))"
    done
  fi
}
## @fn ble/builtin/history/erasedups cmd
##   Deletes history entries that match the specified command. After this call history -s
##   I am assuming that you will call. However, the last matching element will not be deleted.
##
##   @var[in,out] HISTCONTROL
##   @exit 9
##     Returns exit status 9 when the only duplicated element is the last element. This
##     When the history is added, no change occurs in the history, so subsequent calls to history -s
##     There is no problem if you skip the extraction and finish the process as is.
function ble/builtin/history/erasedups {
  local cmd=$1

  local beg=0 N=${#_ble_history[@]}
  if [[ $bleopt_history_erasedups_limit ]]; then
    local limit=$((bleopt_history_erasedups_limit))
    if ((limit<=0)); then
      ((beg=_ble_history_erasedups_base+limit))
    else
      ((beg=N-1-limit))
    fi
    ((beg<0)) && beg=0
  fi

  local delete_indices shift_histindex_next shift_wskip
  if ((beg>=N)); then
    ble/path#remove HISTCONTROL erasedups
    return 0
  elif ((beg>0)); then
    ble/builtin/history/erasedups/.impl-ranged "$cmd" "$beg"
  else
    if ((_ble_bash>=40000&&N>=20000)); then
      ble/builtin/history/erasedups/.impl-awk "$cmd"
    else
      ble/builtin/history/erasedups/.impl-for "$cmd"
    fi
  fi

  if ((${#delete_indices[@]})); then
    blehook/invoke history_change delete "${delete_indices[@]}"
    ((_ble_builtin_history_wskip-=shift_wskip))
    [[ ${HISTINDEX_NEXT+set} ]] && ((HISTINDEX_NEXT-=shift_histindex_next))
  else
    # When you just need to ignore the current history/option:s
    ((N)) && [[ ${_ble_history[N-1]} == "$cmd" ]] && return 9
  fi
}

## @fn ble/builtin/history/option:s
function ble/builtin/history/option:s {
  ble/builtin/history/.initialize
  if [[ $_ble_decode_bind_state == none ]]; then
    builtin history -s -- "$@"
    return 0
  fi

  local cmd=$1
  if [[ $HISTIGNORE ]]; then
    local pats pat
    ble/string#split pats : "$HISTIGNORE"
    for pat in "${pats[@]}"; do
      [[ $cmd == $pat ]] && return 0
    done
    # Note: HISTIGNORE will be ignored in subsequent processing. For the command after trimming
    # To prevent it from working again.
    local HISTIGNORE=
  fi

  # Note: for later builtin history -s by ble/builtin/history/erasedups
  # Since erasedups may be removed from time to time, change them to local variables. Also,
  # It is also rewritten internally for the convenience of ignoreboth processing.
  local HISTCONTROL=$HISTCONTROL

  # Note: HISTIGNORE and ignorespace are processed before trim. Because the blank space at the beginning of the line
  # Because I want to give meaning to things like that. ignoredups and erasedups are applied after trim.
  # Ru. This is because I want to compare it with the command actually registered in the history.
  if [[ $HISTCONTROL ]]; then
    [[ :$HISTCONTROL: == *:ignoreboth:* ]] &&
      HISTCONTROL=$HISTCONTROL:ignorespace:ignoredups
    if [[ :$HISTCONTROL: == *:ignorespace:* ]]; then
      [[ $cmd == [' 	']* ]] && return 0
    fi

    if [[ :$HISTCONTROL: == *:strip:* ]]; then
      local ret
      ble/string#rtrim "$cmd"
      ble/string#match "$ret" $'^[ \t]*(\n([ \t]*\n)*)?'
      cmd=${ret:${#BASH_REMATCH}}
      [[ $BASH_REMATCH == *$'\n'* && $cmd == *$'\n'* ]] && cmd=$'\n'$cmd
    fi
  fi

  local use_bash300wa=
  if [[ $_ble_history_load_done ]]; then
    if [[ $HISTCONTROL ]]; then
      if [[ :$HISTCONTROL: == *:ignoredups:* ]]; then
        # Note: In plain Bash, erasedups are not generated when ignoredups are detected.
        # It doesn't seem like there is, so I'll follow suit.
        local lastIndex=$((${#_ble_history[@]}-1))
        ((lastIndex>=0)) && [[ $cmd == "${_ble_history[lastIndex]}" ]] && return 0
      fi
      if [[ :$HISTCONTROL: == *:erasedups:* ]]; then
        ble/builtin/history/erasedups "$cmd"
        (($?==9)) && return 0
      fi
    fi
    local topIndex=${#_ble_history[@]}
    _ble_history[topIndex]=$cmd
    _ble_history_edit[topIndex]=$cmd
    _ble_history_count=$((topIndex+1))
    _ble_history_index=$_ble_history_count

    # When _ble_bash<30100, always pass through here.
    # Because _ble_history_load_done=1 at initialization.
    ((_ble_bash<30100)) && use_bash300wa=1
  else
    if [[ $HISTCONTROL ]]; then
      # If the history has not been initialized yet, pass it to history -s for now.
      # history -s also filters for HISTCONTROL.
      # Since the script does not know whether the item was added with history -s,
      # Clear and recalculate _ble_history_count
      _ble_history_count=
    else
      # If HISTCONTROL is not present, history -s will probably add it.
      # _ble_history_count Update if already obtained.
      [[ $_ble_history_count ]] &&
        ((_ble_history_count++))
    fi
  fi
  ble/history/.update-position

  if [[ $use_bash300wa ]]; then
    # bash < 3.1 workaround
    if [[ $cmd == *$'\n'* ]]; then
      # Note: %q is always of the form $'' if it contains a newline.
      ble/util/sprintf cmd 'eval -- %q' "$cmd"
    fi
    local tmp=$_ble_base_run/$$.history.tmp
    [[ ${HISTFILE-} && ! $bleopt_history_share ]] &&
      ble/util/print "$cmd" >> "${HISTFILE-}"
    ble/util/print "$cmd" >| "$tmp"
    builtin history -r "$tmp"
  else
    ble/history:bash/clear-background-load
    builtin history -s -- "$cmd"
  fi
  local max; ble/builtin/history/.get-max
  _ble_builtin_history_prevmax=$max
}
function ble/builtin/history {
  local set shopt; ble/base/.adjust-bash-options set shopt
  local opt_d= flag_error=
  local opt_c= opt_p= opt_s=
  local opt_a= flags=
  while [[ $1 == -* ]]; do
    local arg=$1; shift
    [[ $arg == -- ]] && break

    if [[ $arg == --help ]]; then
      flags=h$flags
      continue
    fi

    local i n=${#arg}
    for ((i=1;i<n;i++)); do
      local c=${arg:i:1}
      case $c in
      (c) opt_c=1 ;;
      (s) opt_s=1 ;;
      (p) opt_p=1 ;;
      (d)
        if ((!$#)); then
          ble/util/print 'ble/builtin/history: missing option argument for "-d".' >&2
          flag_error=1
        elif ((i+1<n)); then
          opt_d=${arg:i+1}; i=$n
        else
          opt_d=$1; shift
        fi ;;
      ([anwr])
        if [[ $opt_a && $c != $opt_a ]]; then
          ble/util/print 'ble/builtin/history: cannot use more than one of "-anrw".' >&2
          flag_error=1
        elif ((i+1<n)); then
          opt_a=$c
          set -- "${arg:i+1}" "$@"
        else
          opt_a=$c
        fi ;;
      (*)
        ble/util/print "ble/builtin/history: unknown option \"-$c\"." >&2
        flag_error=1 ;;
      esac
    done
  done
  if [[ $flag_error ]]; then
    builtin history --usage 2>&1 1>/dev/null | ble/bin/grep ^history >&2
    ble/base/.restore-bash-options set shopt
    return 2
  fi

  if [[ $flags == *h* ]]; then
    builtin history --help
    local ext=$?
    ble/base/.restore-bash-options set shopt
    return "$ext"
  fi

  [[ ! $_ble_attached || $_ble_edit_exec_inside_userspace ]] &&
    ble/base/adjust-BASH_REMATCH

  # -cdanwr
  local flag_processed=
  if [[ $opt_c ]]; then
    ble/builtin/history/option:c
    flag_processed=1
  fi
  if [[ $opt_s ]]; then
    local IFS=$_ble_term_IFS
    ble/builtin/history/option:s "$*"
    flag_processed=1
  elif [[ $opt_d ]]; then
    ble/builtin/history/option:d "$opt_d"
    flag_processed=1
  elif [[ $opt_a ]]; then
    ble/builtin/history/option:"$opt_a" "$@"
    flag_processed=1
  fi
  if [[ $flag_processed ]]; then
    ble/base/.restore-bash-options set shopt
    return 0
  fi

  # -p
  if [[ $opt_p ]]; then
    ble/builtin/history/option:p "$@"
  else
    builtin history "$@"
  fi; local ext=$?

  [[ ! $_ble_attached || $_ble_edit_exec_inside_userspace ]] &&
    ble/base/restore-BASH_REMATCH
  ble/base/.restore-bash-options set shopt
  return "$ext"
}
function history {
  builtin eval -- "$_ble_bash_POSIXLY_CORRECT_local_adjust"
  ble/builtin/history "$@"
  builtin eval -- "$_ble_bash_POSIXLY_CORRECT_local_return"
}

#==============================================================================
# ble/history                                                          @history

## @var _ble_history_prefix
##
##   Maintains which history is currently targeted.
##   When it is an empty string, the command history is targeted. The following variables are used.
##
##     _ble_history
##     _ble_history_index
##     _ble_history_edit
##     _ble_history_dirt
##
##   When prefix is a non-empty string, the following variables are subject to operation.
##
##     ${prefix}_history
##     ${prefix}_history_index
##     ${prefix}_history_edit
##     ${prefix}_history_dirt
##
##   All functions must handle _ble_history_prefix appropriately.
##
##   Array _ble_history_edit etc. for implementation
##   When defining and processing locally, the following points must be observed.
##
##   - The function itself or a function called from it
##     Must not have side effects on history items.
##
##   Under this requirement, each function can operate without being aware of switching callers.
##
_ble_history_prefix=

function ble/history/set-prefix {
  _ble_history_prefix=$1
  ble/history/.update-position
}

_ble_history_COUNT=
_ble_history_INDEX=
function ble/history/.update-position {
  if [[ $_ble_history_prefix ]]; then
    builtin eval -- "_ble_history_COUNT=\${#${_ble_history_prefix}_history[@]}"
    ((_ble_history_INDEX=${_ble_history_prefix}_history_index))
  else
    # Before history reading is complete
    if [[ ! $_ble_history_load_done ]]; then
      if [[ ! $_ble_history_count ]]; then
        local min max
        ble/builtin/history/.get-min
        ble/builtin/history/.get-max
        ((_ble_history_count=max-min+1))
      fi
      _ble_history_index=$_ble_history_count
    fi

    _ble_history_COUNT=$_ble_history_count
    _ble_history_INDEX=$_ble_history_index
  fi
}
function ble/history/update-position {
  [[ $_ble_history_prefix$_ble_history_load_done ]] ||
    ble/history/.update-position
}

## @hook history_leave (defined in def.sh)

function ble/history/onleave.fire {
  blehook/invoke history_leave "$@"
}

## called by ble-edit/initialize in Bash 3
function ble/history/initialize {
  [[ ! $_ble_history_prefix ]] &&
    ble/history:bash/initialize
}
function ble/history/get-count {
  local _ble_local_var=count
  [[ $1 == -v ]] && { _ble_local_var=$2; shift 2; }
  ble/history/.update-position
  (($_ble_local_var=_ble_history_COUNT))
}
function ble/history/get-index {
  local _ble_local_var=index
  [[ $1 == -v ]] && { _ble_local_var=$2; shift 2; }
  ble/history/.update-position
  (($_ble_local_var=_ble_history_INDEX))
}
function ble/history/set-index {
  _ble_history_INDEX=$1
  ((${_ble_history_prefix:-_ble}_history_index=_ble_history_INDEX))
}
function ble/history/get-entry {
  local _ble_local_var=entry
  [[ $1 == -v ]] && { _ble_local_var=$2; shift 2; }
  if [[ $_ble_history_prefix$_ble_history_load_done ]]; then
    builtin eval -- "$_ble_local_var=\${${_ble_history_prefix:-_ble}_history[\$1]}"
  else
    builtin eval -- "$_ble_local_var="
  fi
}
function ble/history/get-edited-entry {
  local _ble_local_var=entry
  [[ $1 == -v ]] && { _ble_local_var=$2; shift 2; }
  if [[ $_ble_history_prefix$_ble_history_load_done ]]; then
    builtin eval -- "$_ble_local_var=\${${_ble_history_prefix:-_ble}_history_edit[\$1]}"
  else
    builtin eval -- "$_ble_local_var=\$_ble_edit_str"
  fi
}
## @fn ble/history/set-edited-entry index str
function ble/history/set-edited-entry {
  ble/history/initialize
  local index=$1 str=$2
  local code='
    # store
    if [[ ! ${PREFIX_history_edit[index]+set} || ${PREFIX_history_edit[index]} != "$str" ]]; then
      PREFIX_history_edit[index]=$str
      PREFIX_history_dirt[index]=1
    fi'
  builtin eval -- "${code//PREFIX/${_ble_history_prefix:-_ble}}"
}


## @fn ble/history/revert-edits
##   This function reverts the temporary editing of the current history.
function ble/history/revert-edits {
  if [[ $_ble_history_prefix ]]; then
    local code='
      # Return PREFIX_history_edit to unedited state
      local index
      for index in "${!PREFIX_history_dirt[@]}"; do
        PREFIX_history_edit[index]=${PREFIX_history[index]}
      done
      PREFIX_history_dirt=()

      local topIndex=${#PREFIX_history[@]}
      _ble_history_COUNT=$topIndex
      _ble_history_INDEX=$topIndex'
    builtin eval -- "${code//PREFIX/$_ble_history_prefix}"
  else
    if [[ $_ble_history_load_done ]]; then
      # Initialize immediately regardless of registration or non-registration
      _ble_history_index=${#_ble_history[@]}
      ble/history/.update-position

      # Return _ble_history_edit to unedited state
      local index
      for index in "${!_ble_history_dirt[@]}"; do
        _ble_history_edit[index]=${_ble_history[index]}
      done
      _ble_history_dirt=()

      # At the same time, _ble_edit_undo is also initialized.
      ble-edit/undo/clear-all
    fi
  fi
}

## @fn ble/history/.add-command-history command
## @var[in,out] HISTINDEX_NEXT
##   used by ble/widget/accept-and-next to get modified next-entry positions
function ble/history/.add-command-history {
  # Note: For some reason, history off is always set in bind -x in versions below bash-3.2.
  [[ -o history ]] || ((_ble_bash<30200)) || return 1

  # Note: mc (midnight commander) sends initialization script #D1392
  [[ $MC_SID == $$ && $_ble_edit_LINENO -le 2 && ( $1 == *PROMPT_COMMAND=* || $1 == *PS1=* ) ]] && return 1

  if [[ $bleopt_history_share ]]; then
    ble/builtin/history/option:n
    ble/builtin/history/option:s "$1"
    ble/builtin/history/option:a
    ble/builtin/history/.touch-histfile
  else
    ble/builtin/history/option:s "$1"
  fi
}

function ble/history/add {
  local command=$1
  ((bleopt_history_limit_length>0&&${#command}>bleopt_history_limit_length)) && return 1

  ble/history/revert-edits
  if [[ $_ble_history_prefix ]]; then
    local code='
      local topIndex=${#PREFIX_history[@]}
      PREFIX_history[topIndex]=$command
      PREFIX_history_edit[topIndex]=$command
      PREFIX_history_index=$((++topIndex))
      _ble_history_COUNT=$topIndex
      _ble_history_INDEX=$topIndex'
    builtin eval -- "${code//PREFIX/$_ble_history_prefix}"
  else
    blehook/invoke ADDHISTORY "$command" &&
      ble/history/.add-command-history "$command"
  fi
}

#------------------------------------------------------------------------------
# ble/history/search                                            @history.search

## @fn ble/history/isearch-forward opts
## @fn ble/history/isearch-backward opts
## @fn ble/history/isearch-backward-blockwise opts
##
##   backward-search-history-blockwise does blockwise search
##   as a workaround for bash slow array access
##
##   @param[in] opts
##     Colon-separated options.
##
##     regex Performs a search using regular expressions.
##     glob Attempts to match by glob pattern.
##     head Attempts to match the beginning of a fixed string.
##     tail Attempts to match the end of a fixed string.
##     condition Evaluate the predicate command to attempt a match.
##     predicate Attempts to match by calling the predicate function.
##       Specify one of these.
##       If nothing is specified, a partial match of the fixed string will be attempted.
##
##     stop_check
##       Aborts with exit status 148 on user input.
##
##     progress
##       Displays the progress of the search.
##       Calls the function specified in the isearch_progress_callback variable described below.
##
##     backward
##       Optional for internal use.
##       Specify for forward-search-history to specify backward search.
##
##     cyclic
##       When the end of the history is reached, the search continues from the opposite end of the history.
##       Fails when it reaches the element immediately before start without finding a match.
##
##   @var[in] _ble_history_edit
##     Specify the array to be searched and the overall search start position.
##   @var[in] start
##     Specify the overall search start position.
##
##   @var[in] needle
##     Specify the search string.
##
##     If opts is regex or glob,
##     Specify a regular expression or glob pattern, respectively.
##
##     If condition is specified in opts, needle is interpreted as a predicate command.
##     The line contents and history number are set in the variables LINE and INDEX, respectively, and eval is performed.
##
##     If predicate is specified in opts, needle is interpreted as the function name of the predicate function.
##     The specified predicate function is a function that succeeds when the search matches and fails otherwise.
##     The function is called with the row contents and history number specified as the first and second arguments.
##
##   @var[in,out] index
##     Specifies the search starting position for this call.
##     Returns the location found on a successful match.
##     Returns the next position when matching is interrupted (the first position to check when restarting).
##
##   @var[in,out] isearch_time
##
##   @var[in] isearch_progress_callback
##     Specify the name of the function to call when displaying progress.
## The first argument specifies the current search position (history index).
##
##   @exit
##     Returns 0 when found.
##     Returns 1 if not found.
##     Returns 148 when interrupted.
##
function ble/history/.read-isearch-options {
  local opts=$1

  search_type=fixed
  case :$opts: in
  (*:regex:*)     search_type=regex ;;
  (*:glob:*)      search_type=glob  ;;
  (*:head:*)      search_type=head ;;
  (*:tail:*)      search_type=tail ;;
  (*:condition:*) search_type=condition ;;
  (*:predicate:*) search_type=predicate ;;
  esac

  [[ :$opts: != *:stop_check:* ]]; has_stop_check=$?
  [[ :$opts: != *:progress:* ]]; has_progress=$?
  [[ :$opts: != *:backward:* ]]; has_backward=$?
}
function ble/history/isearch-backward-blockwise {
  local opts=$1
  local search_type has_stop_check has_progress has_backward
  ble/history/.read-isearch-options "$opts"

  ble/history/initialize
  if [[ $_ble_history_prefix ]]; then
    local -a _ble_history_edit
    builtin eval "_ble_history_edit=(\"\${${_ble_history_prefix}_history_edit[@]}\")"
  fi

  local isearch_block=1000 # It's fast enough so it's OK to be this big.
  local isearch_quantum=$((isearch_block*2)) # Must be a multiple
  local irest block j i=$index
  index=

  local flag_icase=; [[ :$opts: == *:ignore-case:* ]] && flag_icase=1

  local flag_cycled= range_min range_max
  while ((1)); do
    if ((i<=start)); then
      range_min=0 range_max=$start
    else
      flag_cycled=1
      range_min=$((start+1)) range_max=$i
    fi

    while ((i>=range_min)); do
      ((block=range_max-i,
        block<5&&(block=5),
        block>i+1-range_min&&(block=i+1-range_min),
        irest=isearch_block-isearch_time%isearch_block,
        block>irest&&(block=irest)))

      [[ $flag_icase ]] && shopt -s nocasematch
      case $search_type in
      (regex)     for ((j=i-block;++j<=i;)); do
                    [[ ${_ble_history_edit[j]} =~ $needle ]] && index=$j
                  done ;;
      (glob)      for ((j=i-block;++j<=i;)); do
                    [[ ${_ble_history_edit[j]} == $needle ]] && index=$j
                  done ;;
      (head)      for ((j=i-block;++j<=i;)); do
                    [[ ${_ble_history_edit[j]} == "$needle"* ]] && index=$j
                  done ;;
      (tail)      for ((j=i-block;++j<=i;)); do
                    [[ ${_ble_history_edit[j]} == *"$needle" ]] && index=$j
                  done ;;
      (condition) builtin eval "function ble-edit/isearch/.search-block.proc {
                    local LINE INDEX
                    for ((j=i-block;++j<=i;)); do
                      LINE=\${_ble_history_edit[j]} INDEX=\$j
                      { $needle; } && index=\$j
                    done
                  }"
                  ble-edit/isearch/.search-block.proc ;;
      (predicate) for ((j=i-block;++j<=i;)); do
                    "$needle" "${_ble_history_edit[j]}" "$j" && index=$j
                  done ;;
      (*)         for ((j=i-block;++j<=i;)); do
                    [[ ${_ble_history_edit[j]} == *"$needle"* ]] && index=$j
                  done ;;
      esac
      [[ $flag_icase ]] && shopt -u nocasematch

      ((isearch_time+=block))
      [[ $index ]] && return 0

      ((i-=block))
      if ((has_stop_check&&isearch_time%isearch_block==0)) && ble/decode/has-input; then
        index=$i
        return 148
      elif ((has_progress&&isearch_time%isearch_quantum==0)); then
        "$isearch_progress_callback" "$i"
      fi
    done

    if [[ ! $flag_cycled && :$opts: == *:cyclic:* ]]; then
      ((i=${#_ble_history_edit[@]}-1))
      ((start<i)) || return 1
    else
      return 1
    fi
  done
}
function ble/history/isearch-forward.impl {
  local opts=$1
  local search_type has_stop_check has_progress has_backward
  ble/history/.read-isearch-options "$opts"

  ble/history/initialize
  if [[ $_ble_history_prefix ]]; then
    local -a _ble_history_edit
    builtin eval "_ble_history_edit=(\"\${${_ble_history_prefix}_history_edit[@]}\")"
  fi

  local flag_icase=; [[ :$opts: == *:ignore-case:* ]] && flag_icase=1

  while ((1)); do
    local flag_cycled= expr_cond expr_incr
    if ((has_backward)); then
      if ((index<=start)); then
        expr_cond='index>=0' expr_incr='index--'
      else
        expr_cond='index>start' expr_incr='index--' flag_cycled=1
      fi
    else
      if ((index>=start)); then
        expr_cond="index<${#_ble_history_edit[@]}" expr_incr='index++'
      else
        expr_cond="index<start" expr_incr='index++' flag_cycled=1
      fi
    fi

    [[ $flag_icase ]] && shopt -s nocasematch
    case $search_type in
    (regex)
#%define search_loop
      for ((;expr_cond;expr_incr)); do
        ((isearch_time++,has_stop_check&&isearch_time%100==0)) &&
          ble/decode/has-input && return 148
        @ && return 0
        ((has_progress&&isearch_time%1000==0)) &&
          "$isearch_progress_callback" "$index"
      done ;;
#%end
#%expand search_loop.r/@/[[ ${_ble_history_edit[index]} =~ $needle ]]/
    (glob)
#%expand search_loop.r/@/[[ ${_ble_history_edit[index]} == $needle ]]/
    (head)
#%expand search_loop.r/@/[[ ${_ble_history_edit[index]} == "$needle"* ]]/
    (tail)
#%expand search_loop.r/@/[[ ${_ble_history_edit[index]} == *"$needle" ]]/
    (condition)
#%expand search_loop.r/@/LINE=${_ble_history_edit[index]} INDEX=$index builtin eval -- "$needle"/
    (predicate)
#%expand search_loop.r/@/"$needle" "${_ble_history_edit[index]}" "$index"/
    (*)
#%expand search_loop.r/@/[[ ${_ble_history_edit[index]} == *"$needle"* ]]/
    esac
    [[ $flag_icase ]] && shopt -u nocasematch

    if [[ ! $flag_cycled && :$opts: == *:cyclic:* ]]; then
      if ((has_backward)); then
        ((index=${#_ble_history_edit[@]}-1))
        ((index>start)) || return 1
      else
        ((index=0))
        ((index<start)) || return 1
      fi
    else
      return 1
    fi
  done
}
function ble/history/isearch-forward {
  ble/history/isearch-forward.impl "$1"
}
function ble/history/isearch-backward {
  ble/history/isearch-forward.impl "$1:backward"
}
