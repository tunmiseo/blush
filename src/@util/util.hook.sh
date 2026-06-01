# -*- mode: sh; mode: sh-bash -*-

#------------------------------------------------------------------------------
# blehook

## @fn blehook/.print
##   @var[in] flags
function blehook/.print {
  (($#)) || return 0

  local out= q=\' Q="'\''" nl=$'\n'
  local sgr0= sgr1= sgr2= sgr3=
  if [[ $flags == *c* ]]; then
    local ret
    ble/color/face2sgr command_function; sgr1=$ret
    ble/color/face2sgr syntax_varname; sgr2=$ret
    ble/color/face2sgr syntax_quoted; sgr3=$ret
    sgr0=$_ble_term_sgr0
    Q=$q$sgr0"\'"$sgr3$q
  fi

  local elem op_assign code='
    if ((${#_ble_hook_h_NAME[@]})); then
      op_assign==
      for elem in "${_ble_hook_h_NAME[@]}"; do
        out="${out}${sgr1}blehook$sgr0 ${sgr2}NAME$sgr0$op_assign${sgr3}$q${elem//$q/$Q}$q$sgr0$nl"
        op_assign=+=
      done
    else
      out="${out}${sgr1}blehook$sgr0 ${sgr2}NAME$sgr0=$nl"
    fi'

  local hookname
  for hookname; do
    ble/is-array "$hookname" || continue
    builtin eval -- "${code//NAME/${hookname#_ble_hook_h_}}"
  done
  ble/util/put "$out"
}
function blehook/.print-help {
  ble/util/print-lines \
    'usage: blehook [NAME[[=|+=|-=|-+=]COMMAND]]...' \
    '    Add or remove hooks. Without arguments, this prints all the existing hooks.' \
    '' \
    '  Options:' \
    '    --help      Print this help.' \
    '    -a, --all   Print all hooks including the internal ones.' \
    '    --color[=always|never|auto]' \
    '                  Change color settings.' \
    '' \
    '  Arguments:' \
    '    NAME            Print the corresponding hooks.' \
    '    NAME=COMMAND    Set hook after removing the existing hooks.' \
    '    NAME+=COMMAND   Add hook.' \
    '    NAME-=COMMAND   Remove hook.' \
    '    NAME!=COMMAND   Add hook if the command is not registered.' \
    '    NAME-+=COMMAND  Append the hook and remove the duplicates.' \
    '    NAME+-=COMMAND  Prepend the hook and remove the duplicates.' \
    '' \
    '  NAME:' \
    '    The hook name.  The characters "@", "*", and "?" may be used as wildcards.' \
    ''
}

## @fn blehook/.read-arguments args...
##   @var[out] flags
function blehook/.read-arguments {
  flags= print=() process=()
  local opt_color=auto
  while (($#)); do
    local arg=$1; shift
    if [[ $arg == -* ]]; then
      case $arg in
      (--help)
        flags=H$flags ;;
      (--color) opt_color=always ;;
      (--color=always|--color=auto|--color=never)
        opt_color=${arg#*=} ;;
      (--color=*)
        ble/util/print "blehook: '${arg#*=}': unrecognized option argument for '--color'." >&2
        flags=E$flags ;;
      (--all) flags=a$flags ;;
      (--*)
        ble/util/print "blehook: unrecognized long option '$arg'." >&2
        flags=E$flags ;;
      (-)
        ble/util/print "blehook: unrecognized argument '$arg'." >&2
        flags=E$flags ;;
      (*)
        local i c
        for ((i=1;i<${#arg};i++)); do
          c=${arg:i:1}
          case $c in
          (a) flags=a$flags ;;
          (*)
            ble/util/print "blehook: unrecognized option '-$c'." >&2
            flags=E$flags ;;
          esac
        done ;;
      esac
    elif [[ $arg =~ $rex1 ]]; then
      if [[ $arg == *[@*?]* ]] || ble/is-array "_ble_hook_h_$arg"; then
        ble/array#push print "$arg"
      else
        ble/util/print "blehook: undefined hook '$arg'." >&2
      fi
    elif [[ $arg =~ $rex2 ]]; then
      local name=${BASH_REMATCH[1]}
      if [[ $name == *[@*?]* ]]; then
        if [[ ${BASH_REMATCH[2]} == :* ]]; then
          ble/util/print "blehook: hook pattern cannot be combined with '${BASH_REMATCH[2]}'." >&2
          flags=E$flags
          continue
        fi
      else
        local var_counter=_ble_hook_c_$name
        if [[ ! ${!var_counter+set} ]]; then
          if [[ ${BASH_REMATCH[2]} == :* ]]; then
            (($var_counter=0))
          else
            ble/util/print "blehook: hook \"$name\" is not defined." >&2
            flags=E$flags
            continue
          fi
        fi
      fi
      ble/array#push process "$arg"
    else
      ble/util/print "blehook: invalid hook spec \"$arg\"" >&2
      flags=E$flags
    fi
  done

  # resolve patterns
  local pat ret out; out=()
  for pat in "${print[@]}"; do
    if [[ $pat == *[@*?]* ]]; then
      bleopt/expand-variable-pattern "_ble_hook_h_$pat"
      ble/array#filter ret ble/is-array
      [[ $pat == *[a-z]* || $flags == *a* ]] ||
        ble/array#remove-by-glob ret '_ble_hook_h_*[a-z]*'
      if ((!${#ret[@]})); then
        ble/util/print "blehook: '$pat': matching hook not found." >&2
        flags=E$flags
        continue
      fi
    else
      ret=("_ble_hook_h_$pat")
    fi
    ble/array#push out "${ret[@]}"
  done
  print=("${out[@]}")

  out=()
  for pat in "${process[@]}"; do
    [[ $pat =~ $rex2 ]]
    local name=${BASH_REMATCH[1]}
    if [[ $name == *[@*?]* ]]; then
      local type=${BASH_REMATCH[3]}
      local value=${BASH_REMATCH[4]}

      bleopt/expand-variable-pattern "_ble_hook_h_$pat"
      ble/array#filter ret ble/is-array
      [[ $pat == *[a-z]* || $flags == *a* ]] ||
        ble/array#remove-by-glob ret '_ble_hook_h_*[a-z]*'
      if ((!${#ret[@]})); then
        ble/util/print "blehook: '$pat': matching hook not found." >&2
        flags=E$flags
        continue
      fi
      ble/array#map-suffix ret "$type$value"
    else
      ret=("_ble_hook_h_$pat")
    fi
    ble/array#push out "${ret[@]}"
  done
  process=("${out[@]}")

  [[ $opt_color == always || $opt_color == auto && -t 1 ]] && flags=c$flags
}

function blehook {
  builtin eval -- "$_ble_bash_POSIXLY_CORRECT_local_adjust"
  local set shopt
  ble/base/adjust-BASH_REMATCH
  ble/base/.adjust-bash-options set shopt
  local LC_ALL= LC_COLLATE=C 2>/dev/null # suppress locale error #D1440

  local flags print process
  local rex1='^([_a-zA-Z@*?][_a-zA-Z0-9@*?]*)$'
  local rex2='^([_a-zA-Z@*?][_a-zA-Z0-9@*?]*)(:?([-+!]|-\+|\+-)?=)(.*)$'
  blehook/.read-arguments "$@"
  if [[ $flags == *[HE]* ]]; then
    if [[ $flags == *H* ]]; then
      [[ $flags == *E* ]] &&
        ble/util/print >&2
      blehook/.print-help
    fi
    [[ $flags != *E* ]]; local ext=$?
    ble/util/unlocal LC_ALL LC_COLLATE 2>/dev/null # suppress locale error #D1440
    ble/base/.restore-bash-options set shopt
    ble/base/restore-BASH_REMATCH
    builtin eval -- "$_ble_bash_POSIXLY_CORRECT_local_leave"
    return "$ext"
  fi

  if ((${#print[@]}==0&&${#process[@]}==0)); then
    print=("${!_ble_hook_h_@}")
    [[ $flags == *a* ]] || ble/array#remove-by-glob print '_ble_hook_h_*[a-z]*'
  fi

  local proc ext=0
  for proc in "${process[@]}"; do
    [[ $proc =~ $rex2 ]]
    local name=${BASH_REMATCH[1]}
    local type=${BASH_REMATCH[3]}
    local value=${BASH_REMATCH[4]}

    local append=$value
    case $type in
    (*-*) # -=, -+=, +-=
      local ret
      ble/array#last-index "$name" "$value"
      if ((ret>=0)); then
        ble/array#remove-at "$name" "$ret"
      elif [[ ${type#:} == '-=' ]]; then
        ext=1
      fi

      if [[ $type != -+ ]]; then
        append=
        [[ $type == +- ]] &&
          ble/array#unshift "$name" "$value"
      fi ;;

    ('!') # !=
      local ret
      ble/array#last-index "$name" "$value"
      ((ret>=0)) && append= ;;

    ('') builtin eval "$name=()" ;; # =
    ('+'|*) ;; # +=
    esac
    [[ $append ]] && ble/array#push "$name" "$append"
  done

  if ((${#print[@]})); then
    blehook/.print "${print[@]}"
  fi

  ble/util/unlocal LC_ALL LC_COLLATE 2>/dev/null # suppress locale error #D1440
  ble/base/.restore-bash-options set shopt
  ble/base/restore-BASH_REMATCH
  ble/util/setexit "$ext"
  builtin eval -- "$_ble_bash_POSIXLY_CORRECT_local_return"
}
blehook/.compatibility-ble-0.3

function blehook/has-hook {
  builtin eval "local count=\${#_ble_hook_h_$1[@]}"
  ((count))
}
## @fn blehook/invoke.sandbox
##   @var[in] _ble_local_hook _ble_local_lastexit _ble_local_lastarg
function blehook/invoke.sandbox {
  if ble/bin#has "$_ble_local_hook"; then
    ble/util/setexit "$_ble_local_lastexit" "$_ble_local_lastarg"
    "$_ble_local_hook" "$@" 2>&3
  else
    ble/util/setexit "$_ble_local_lastexit" "$_ble_local_lastarg"
    builtin eval -- "$_ble_local_hook" 2>&3
  fi
}
function blehook/invoke {
  local _ble_local_lastexit=$? _ble_local_lastarg=$_ FUNCNEST=
  ((_ble_hook_c_$1++))
  local -a _ble_local_hooks
  builtin eval "_ble_local_hooks=(\"\${_ble_hook_h_$1[@]}\")"; shift
  local _ble_local_hook _ble_local_ext=0
  for _ble_local_hook in "${_ble_local_hooks[@]}"; do
    blehook/invoke.sandbox "$@" || _ble_local_ext=$?
  done
  return "$_ble_local_ext"
} 3>&2 2>/dev/null # set -x solution #D0930
function blehook/eval-after-load {
  local hook_name=${1}_load value=$2
  if ((_ble_hook_c_$hook_name)); then
    builtin eval -- "$value"
  else
    blehook "$hook_name+=$value"
  fi
}

#------------------------------------------------------------------------------
# blehook

_ble_builtin_trap_inside=  # Whether ble/builtin/trap is being processed

## @fn ble/builtin/trap/.read-arguments args...
##   @var[out] flags
function ble/builtin/trap/.read-arguments {
  flags= command= sigspecs=()
  while (($#)); do
    local arg=$1; shift
    if [[ $arg == -?* && flags != *A* ]]; then
      if [[ $arg == -- ]]; then
        flags=A$flags
        continue
      elif [[ $arg == --* ]]; then
        case $arg in
        (--help)
          flags=h$flags
          continue ;;
        (*)
          ble/util/print "ble/builtin/trap: unknown long option \"$arg\"." >&2
          flags=E$flags
          continue ;;
        esac
      fi

      local i
      for ((i=1;i<${#arg};i++)); do
        case ${arg:i:1} in
        (l) flags=l$flags ;;
        (p) flags=p$flags ;;
        (P) flags=P$flags ;;
        (*)
          ble/util/print "ble/builtin/trap: unknown option \"-${arg:i:1}\"." >&2
          flags=E$flags ;;
        esac
      done
    else
      if [[ $flags != *[pc]* ]]; then
        command=$arg
        flags=c$flags
      else
        ble/array#push sigspecs "$arg"
      fi
    fi
  done

  if [[ $flags != *[hlpPE]* ]]; then
    if [[ $flags != *c* ]]; then
      flags=p$flags
    elif ((${#sigspecs[@]}==0)); then
      sigspecs=("$command")
      command=-
    fi
  elif [[ $flags == *p* && $flags == *P* ]]; then
    ble/util/print "ble/builtin/trap: cannot specify both -p and -P" >&2
    flags=E${flags//[pP]}
  fi
}

builtin eval -- "${_ble_util_gdict_declare//NAME/_ble_builtin_trap_name2sig}"
_ble_builtin_trap_sig_name=()
_ble_builtin_trap_sig_opts=()
_ble_builtin_trap_sig_base=1000
_ble_builtin_trap_EXIT=
_ble_builtin_trap_DEBUG=
_ble_builtin_trap_RETURN=
_ble_builtin_trap_ERR=
function ble/builtin/trap/sig#register {
  local sig=$1 name=$2
  _ble_builtin_trap_sig_name[sig]=$name
  ble/gdict#set _ble_builtin_trap_name2sig "$name" "$sig"
}
function ble/builtin/trap/sig#reserve {
  local ret
  ble/builtin/trap/sig#resolve "$1" || return 1
  _ble_builtin_trap_sig_opts[ret]=${2:-1}
}
## @fn ble/builtin/trap/sig#resolve sigspec
##   @var[out] ret
function ble/builtin/trap/sig#resolve {
  ble/builtin/trap/sig#init
  if [[ $1 && ! ${1//[0-9]} ]]; then
    ret=$1
    return 0
  else
    ble/gdict#get _ble_builtin_trap_name2sig "$1"
    [[ $ret ]] && return 0

    ble/string#toupper "$1"; local upper=$ret
    ble/gdict#get _ble_builtin_trap_name2sig "$upper" ||
      ble/gdict#get _ble_builtin_trap_name2sig "SIG$upper" ||
      return 1
    ble/gdict#set _ble_builtin_trap_name2sig "$1" "$ret"
    return 0
  fi
}
## @fn ble/builtin/trap/sig#new sig [opts]
##   @param[in,opt] opts
##
##     builtin (internal use)
##       reserve the special handling of the corresponding builtin trap.  Used
##       for DEBUG, RETURN, and ERR.
##
##     override-builtin-signal (internal use)
##       indicates that the builtin trap handler is overridden by ble.sh.  The
##       user traps should be restored on ble-unload.
##
##     user-trap-in-postproc
##       evaluate user traps outside the trap-handler function.  When this is
##       enabled, the last argument $_ is not modified by the user trap
##       handlers because of the limitation of the implementation.
##
function ble/builtin/trap/sig#new {
  local name=$1 opts=$2
  local sig=$((_ble_builtin_trap_$name=_ble_builtin_trap_sig_base++))
  ble/builtin/trap/sig#register "$sig" "$name"
  if [[ :$opts: != *:builtin:* ]]; then
    ble/builtin/trap/sig#reserve "$sig" "$opts"
  fi
}
function ble/builtin/trap/sig#init {
  function ble/builtin/trap/sig#init { return 0; }
  local ret i
  ble/util/assign-words ret 'builtin trap -l' 2>/dev/null
  for ((i=0;i<${#ret[@]};i+=2)); do
    local index=${ret[i]%')'}
    local name=${ret[i+1]}
    ble/builtin/trap/sig#register "$index" "$name"
  done

  _ble_builtin_trap_EXIT=0
  ble/builtin/trap/sig#register "$_ble_builtin_trap_EXIT" EXIT
  ble/builtin/trap/sig#new DEBUG  builtin
  ble/builtin/trap/sig#new RETURN builtin
  ble/builtin/trap/sig#new ERR    builtin
}

_ble_builtin_trap_handlers=()
_ble_builtin_trap_handlers_RETURN=()
## @fn ble/builtin/trap/user-handler#load sig
##   @param[in] sig
##     Specify the trap number.
##   @var[out] _ble_trap_handler
##     Stores user traps.
##   @exit
##     Returns 0 when user trap is set.
function ble/builtin/trap/user-handler#load {
  local sig=$1 name=${_ble_builtin_trap_sig_name[$1]}
  if [[ $name == RETURN ]]; then
    ble/builtin/trap/user-handler#load:RETURN
  else
    _ble_trap_handler=${_ble_builtin_trap_handlers[sig]-}
    [[ ${_ble_builtin_trap_handlers[sig]+set} ]]
  fi
}
## @fn ble/builtin/trap/user-handler#save sig handler
##   Records the handler for the specified trap.
##   @param[in] sig handler
##     Specify the trap number.
##   @var[out] _ble_trap_handler
##     Stores user traps.
##   @exit
##     Returns 0 when user trap is set.
function ble/builtin/trap/user-handler#save {
  local sig=$1 name=${_ble_builtin_trap_sig_name[$1]} handler=$2
  if [[ $name == RETURN ]]; then
    ble/builtin/trap/user-handler#save:RETURN "$handler"
  else
    if [[ $handler == - ]]; then
      builtin unset -v '_ble_builtin_trap_handlers[sig]'
    else
      _ble_builtin_trap_handlers[sig]=$handler
    fi
  fi
  return 0
}
function ble/builtin/trap/user-handler#save:RETURN {
  local handler=$1

  local offset=
  for ((offset=1;offset<${#FUNCNAME[@]};offset++)); do
    case ${FUNCNAME[offset]} in
    (trap | ble/builtin/trap) ;;
    (ble/builtin/trap/user-handler#save) ;;
    (*) break ;;
    esac
  done
  local current_level=$((${#FUNCNAME[@]}-offset))

  local level
  for level in "${!_ble_builtin_trap_handlers_RETURN[@]}"; do
    if ((level>current_level)); then
      builtin unset -v '_ble_builtin_trap_handlers_RETURN[level]'
    fi
  done

  if [[ $handler == - ]]; then
    if [[ $- == *T* ]] || shopt -q extdebug; then
      for ((level=current_level;level>=0;level--)); do
        builtin unset -v '_ble_builtin_trap_handlers_RETURN[level]'
      done
    else
      for ((level=current_level;level>=0;level--,offset++)); do
        builtin unset -v '_ble_builtin_trap_handlers_RETURN[level]'
        ((level)) && ble/function#has-attr "${FUNCNAME[offset]}" t || break
      done
    fi
  else
    _ble_builtin_trap_handlers_RETURN[current_level]=$handler
  fi
  return 0
}
function ble/builtin/trap/user-handler#load:RETURN {
  # Determining the calling context/handler search start function level for this function
  local offset= in_trap=
  for ((offset=1;offset<${#FUNCNAME[@]};offset++)); do
    case ${FUNCNAME[offset]} in
    (trap | ble/builtin/trap) ;;
    (ble/builtin/trap/.handler) ;;
    (ble/builtin/trap/user-handler#load) ;;
    (ble/builtin/trap/user-handler#has) ;;
    (ble/builtin/trap/finalize) ;;
    (ble/builtin/trap/install-hook) ;;
    (ble/builtin/trap/invoke) ;;
    (*) break ;;
    esac
  done
  local search_level=
  if [[ $- == *T* ]] || shopt -q extdebug; then
    search_level=0
  else
    for ((;offset<${#FUNCNAME[@]};offset++)); do
      ble/function#has-attr "${FUNCNAME[offset]}" t || break
    done
    search_level=$((${#FUNCNAME[@]}-offset))
  fi

  # Get handler recorded at maximum index after search_level
  local level found= handler=
  for level in "${!_ble_builtin_trap_handlers_RETURN[@]}"; do
    ((level>=search_level)) || continue
    found=1 handler=${_ble_builtin_trap_handlers_RETURN[level]}
  done

  _ble_trap_handler=$handler
  [[ $found ]]
}
## @fn ble/builtin/trap/user-handler#update:RETURN
##   Call when the function returns to perform inheritance of the RETURN trap to the caller.
##   This function is expected to be called from ble/builtin/trap/.handler.
function ble/builtin/trap/user-handler#update:RETURN {
  # Get the calling context of this function
  local offset=2 # ...assumed to be called directly from ble/builtin/trap/.handler
  local current_level=$((${#FUNCNAME[@]}-offset))
  ((current_level>0)) || return 0

  # Get handler recorded at maximum index after current_level
  local level found= handler=
  for level in "${!_ble_builtin_trap_handlers_RETURN[@]}"; do
    ((level>=current_level)) || continue
    found=1 handler=${_ble_builtin_trap_handlers_RETURN[level]}

    # Handlers recorded at the level itself and lower levels are deleted. Found handler
    # will later be copied one level higher.
    if ((level>=current_level)); then
      builtin unset -v '_ble_builtin_trap_handlers_RETURN[level]'
    fi
  done
  if [[ $found ]]; then
    _ble_builtin_trap_handlers_RETURN[current_level-1]=$handler
  fi
}
function ble/builtin/trap/user-handler#has {
  local _ble_trap_handler
  ble/builtin/trap/user-handler#load "$1"
}
function ble/builtin/trap/user-handler#init {
  local script _ble_builtin_trap_user_handler_init=1
  ble/util/assign script 'builtin trap -p'
  builtin eval -- "$script"
}
function ble/builtin/trap/user-handler/is-internal {
  case $1 in
  ('ble/builtin/trap/'*) return 0 ;; # ble-0.4
  ('ble/base/unload'*|'ble-edit/'*) return 0 ;; # bash-0.3 and earlier
  (*) return 1 ;;
  esac
}

function ble/builtin/trap/finalize {
  _ble_builtin_trap_handlers_reload=()

  local sig unload_opts=$1
  for sig in "${!_ble_builtin_trap_sig_opts[@]}"; do
    local name=${_ble_builtin_trap_sig_name[sig]}
    local opts=${_ble_builtin_trap_sig_opts[sig]}
    [[ $name && :$opts: == *:override-builtin-signal:* ]] || continue

    # Note (#D2021): When restoring settings for reload, use readline.
    # Leave the WINCH alone so as not to destroy the WINCH trap.
    # The original user trap was recorded in _ble_builtin_trap_handlers_reload.
    # and read it later with ble/builtin/trap/install-hook.
    if [[ :$opts: == *:readline:* && :$unload_opts: == *:reload:* ]]; then
      if local _ble_trap_handler; ble/builtin/trap/user-handler#load "$sig"; then
        local q=\' Q="'\''"
        _ble_builtin_trap_handlers_reload[sig]="trap -- '${_ble_trap_handler//$q/$Q}' $name"
      else
        _ble_builtin_trap_handlers_reload[sig]=
      fi
      continue
    fi

    if local _ble_trap_handler; ble/builtin/trap/user-handler#load "$sig"; then
      builtin trap -- "$_ble_trap_handler" "$name"
    else
      builtin trap -- - "$name"
    fi
  done
}
function ble/builtin/trap {
  local set shopt; ble/base/.adjust-bash-options set shopt
  local flags command sigspecs
  ble/builtin/trap/.read-arguments "$@"

  if [[ $flags == *h* ]]; then
    builtin trap --help
    ble/base/.restore-bash-options set shopt
    return 2
  elif [[ $flags == *E* ]]; then
    builtin trap --usage 2>&1 1>/dev/null | ble/bin/grep ^trap >&2
    ble/base/.restore-bash-options set shopt
    return 2
  elif [[ $flags == *l* ]]; then
    builtin trap -l
  fi

  [[ ! $_ble_attached || $_ble_edit_exec_inside_userspace ]] &&
    ble/base/adjust-BASH_REMATCH

  if [[ $flags == *[pP]* ]]; then
    local -a indices=()
    if ((${#sigspecs[@]})); then
      local spec ret
      for spec in "${sigspecs[@]}"; do
        if ! ble/builtin/trap/sig#resolve "$spec"; then
          ble/util/print "ble/builtin/trap: invalid signal specification \"$spec\"." >&2
          continue
        fi
        ble/array#push indices "$ret"
      done
    else
      indices=("${!_ble_builtin_trap_handlers[@]}" "$_ble_builtin_trap_RETURN")
    fi

    local q=\' Q="'\''" index _ble_trap_handler
    for index in "${indices[@]}"; do
      if ble/builtin/trap/user-handler#load "$index"; then
        if [[ $flags == *p* ]]; then
          local n=${_ble_builtin_trap_sig_name[index]}
          _ble_trap_handler="trap -- '${_ble_trap_handler//$q/$Q}' $n"
        fi
        ble/util/print "$_ble_trap_handler"
      fi
    done
  else
    # Ignore ble.sh handlers of the previous session
    [[ $_ble_builtin_trap_user_handler_init ]] &&
      ble/builtin/trap/user-handler/is-internal "$command" &&
      return 0

    local _ble_builtin_trap_inside=1
    local spec ret
    for spec in "${sigspecs[@]}"; do
      if ! ble/builtin/trap/sig#resolve "$spec"; then
        ble/util/print "ble/builtin/trap: invalid signal specification \"$spec\"." >&2
        continue
      fi
      local sig=$ret
      local name=${_ble_builtin_trap_sig_name[sig]}
      ble/builtin/trap/user-handler#save "$sig" "$command"
      [[ $_ble_builtin_trap_user_handler_init ]] && continue

      local trap_command='builtin trap -- "$command" "$spec"'
      local install_opts=${_ble_builtin_trap_sig_opts[sig]}
      if [[ $install_opts ]]; then
        local custom_trap=ble/builtin/trap:$name
        if ble/is-function "$custom_trap"; then
          trap_command='"$custom_trap" "$command" "$spec"'
        elif [[ :$install_opts: == *:readline:* ]] && ! ble/util/is-running-in-subshell; then
          # Note (#D1345 #D1862): In order not to destroy readline intervention, inside the parent shell
          # builtin trap Does not need to be reconfigured.
          trap_command=
        elif [[ $command == - ]]; then
          if [[ :$install_opts: == *:inactive:* ]]; then
            # Note #D1858: For traps simply handled via ble/builtin/trap/.handler.
            # When you want to release a trap, you can just do so.
            trap_command='builtin trap - "$spec"'
          else
            # Note #D1858: Trap is permanently installed for internal processing, so delete trap.
            # I don't. That's why I have to register commands for internal processing again.
            # No (especially if you don't want to run it again in a subshell).
            trap_command=
          fi
        elif [[ :$install_opts: == *:override-builtin-signal:* ]]; then
          # Note #D1862: Even if trap is permanently installed for internal processing, EXIT etc.
          # Like this, there are traps that are not inherited by subshell, so you need to explicitly buildin them every time.
          # Execute trap.
          ble/builtin/trap/install-hook/.compose-trap_command "$sig"
          trap_command="builtin $trap_command"
        else
          # For custom traps registered with ble/builtin/trap/{.register,reserve}
          # does not perform any builtin trap related operations. Regarding control of ignition
          # You should implement it so that ble/builtin/trap/invoke is called at the appropriate place.
          trap_command=
        fi
      fi

      if [[ $trap_command ]]; then
        # Note #D1858: Unless set -E (-o errtrace) is set,
        # trap ERR cannot be deleted. I have no choice but to create an empty command.
        # Let's set it as a trap. Operation when trap ERR is not originally set
        # does not do anything, so there should be no problem with an empty string.
        if [[ $name == ERR && $command == - && $- != *E* ]]; then
          command=
        fi
        builtin eval -- "$trap_command"
      fi
    done
  fi

  [[ ! $_ble_attached || $_ble_edit_exec_inside_userspace ]] &&
    ble/base/restore-BASH_REMATCH
  ble/base/.restore-bash-options set shopt
  return 0
}
function trap {
  builtin eval -- "$_ble_bash_POSIXLY_CORRECT_local_adjust"
  ble/builtin/trap "$@"
  builtin eval -- "$_ble_bash_POSIXLY_CORRECT_local_return"
}
ble/builtin/trap/user-handler#init

function ble/builtin/trap/.TRAPRETURN {
  local IFS=$_ble_term_IFS
  local backtrace=" ${BLE_TRAP_FUNCNAME[*]-} "
  case $backtrace in
  # RETURN is ignored if the caller used the trap to set the RETURN trap. it
  # You can also ignore other trap calls.
  (' trap '* | ' ble/builtin/trap '*) return 126 ;;
  # ble/builtin/trap/.handler Ignores RETURN for internal processing, but
  # In blehook / trap_string which is further called from ble/builtin/trap/.handler
  # Fires RETURN for the function being called.
  (*' ble/builtin/trap/.handler '*)
    case ${backtrace%%' ble/builtin/trap/.handler '*}' ' in
    (' '*' blehook/invoke.sandbox '* | ' '*' ble/builtin/trap/invoke.sandbox '*) ;;
    (*) return 126 ;;
    esac ;;
  # Functions that are called after executing a user command that has not been saved.
  (*' _ble_edit_exec_gexec__save_lastarg ' | ' _ble_edit_exec_gexec__TRAPDEBUG_adjust ') return 126 ;;
  esac
  return 0
}
blehook internal_RETURN!=ble/builtin/trap/.TRAPRETURN

# Record of $?, $_ exclusively for user trap handler.
_ble_builtin_trap_user_lastcmd=
_ble_builtin_trap_user_lastarg=
_ble_builtin_trap_user_lastexit=
## @fn ble/builtin/trap/invoke.sandbox params...
##   @param[in] params...
##   @var[in] _ble_trap_sig
##   @var[in] _ble_trap_handler
##   @var[out] _ble_trap_done
##   @var[in,out] _ble_trap_lastexit _ble_trap_lastarg
function ble/builtin/trap/invoke.sandbox {
  local _ble_trap_count
  for ((_ble_trap_count=0;_ble_trap_count<1;_ble_trap_count++)); do
    local BASH_TRAPSIG=$_ble_trap_sig
    _ble_trap_done=return
    # Note #D1757: If trap handler finishes executing without changing control,
    # When $? $_ is saved. If they are not in the same eval, $_ will overtake the eval.
    # Note that it will be replaced by the final argument of eval when the value is reached.
    ble/util/setexit "$_ble_trap_lastexit" "$_ble_trap_lastarg"
    builtin eval -- "$_ble_trap_handler"$'\n_ble_trap_lastexit=$? _ble_trap_lastarg=$_' 2>&3
    _ble_trap_done=done
    return 0
  done
  _ble_trap_lastexit=$? _ble_trap_lastarg=$_

  # break/continue detection
  if ((_ble_trap_count==0)); then
    _ble_trap_done=break
  else
    _ble_trap_done=continue
  fi
  return 0
}
## @fn ble/builtin/trap/invoke sig params...
##   @param[in] sig
##   @param[in] params...
##   @var[in] ? _
##   @var[in,out] _ble_builtin_trap_postproc[sig]
##   @var[in,out] _ble_builtin_trap_lastarg[sig]
function ble/builtin/trap/invoke {
  local _ble_trap_lastexit=$? _ble_trap_lastarg=$_ _ble_trap_sig=$1; shift
  if [[ ${_ble_trap_sig//[0-9]} ]]; then
    local ret
    ble/builtin/trap/sig#resolve "$_ble_trap_sig" || return 1
    _ble_trap_sig=$ret
    ble/util/unlocal ret
  fi

  local _ble_trap_handler
  ble/builtin/trap/user-handler#load "$_ble_trap_sig"
  [[ $_ble_trap_handler ]] || return 0

  # restore $_ and $? for user trap handlers
  if [[ $_ble_attached && ! $_ble_edit_exec_inside_userspace ]]; then
    if [[ $_ble_builtin_trap_user_lastcmd != $_ble_edit_CMD ]]; then
      _ble_builtin_trap_user_lastcmd=$_ble_edit_CMD
      _ble_builtin_trap_user_lastexit=$_ble_edit_exec_lastexit
      _ble_builtin_trap_user_lastarg=$_ble_edit_exec_lastarg
    fi
    _ble_trap_lastexit=$_ble_builtin_trap_user_lastexit
    _ble_trap_lastarg=$_ble_builtin_trap_user_lastarg
  fi

  local _ble_trap_done=
  ble/builtin/trap/invoke.sandbox "$@"; local ext=$?
  case $_ble_trap_done in
  (done)
    _ble_builtin_trap_lastarg[_ble_trap_sig]=$_ble_trap_lastarg
    _ble_builtin_trap_postproc[_ble_trap_sig]="ble/util/setexit $_ble_trap_lastexit" ;;
  (break | continue)
    _ble_builtin_trap_lastarg[_ble_trap_sig]=$_ble_trap_lastarg
    if ble/string#match "$_ble_trap_lastarg" '^-?[0-9]+$'; then
      _ble_builtin_trap_postproc[_ble_trap_sig]="$_ble_trap_done $_ble_trap_lastarg"
    else
      _ble_builtin_trap_postproc[_ble_trap_sig]=$_ble_trap_done
    fi ;;
  (return)
    # Note #D1757: The lastarg of return itself is no longer available, but if
    # Even if it is executed directly with builtin trap, the function can be extracted with return.
    # Since lastarg is rewritten when the digit is reached, it cannot be retrieved. function at best
    # Set lastarg before the call and set it before return when return fails.
    # I feel like the only option is to keep the state of .
    _ble_builtin_trap_lastarg[_ble_trap_sig]=$ext
    _ble_builtin_trap_postproc[_ble_trap_sig]="return $ext" ;;
  (exit)
    # Note #D1782: Call ble/builtin/exit (edit.sh) in trap handler.
    #   When a trap occurs, instead of immediately exiting bash, process the trap for the time being.
    #   is completed. _ble_trap_done=exit is set by TRAPDEBUG
    #   Ru. Also, the argument originally passed to exit is set to $_ble_trap_lastarg
    #   be done.
    # Note #D1782: Another DEBUG trap is activated among other traps.
    #   call ble/builtin/exit again instead of builtin exit
    #   Start again.
    _ble_builtin_trap_lastarg[_ble_trap_sig]=$_ble_trap_lastarg
    _ble_builtin_trap_postproc[_ble_trap_sig]="ble/builtin/exit $_ble_trap_lastarg" ;;
  esac

  # save $_ and $? for user trap handlers
  if [[ $_ble_attached && ! $_ble_edit_exec_inside_userspace ]]; then
    _ble_builtin_trap_user_lastexit=$_ble_trap_lastexit
    _ble_builtin_trap_user_lastarg=$_ble_trap_lastarg
  fi

  return 0
} 3>&2 2>/dev/null # set -x solution #D0930

## @var _ble_builtin_trap_processing
##   ble/builtin/trap/.handler A local variable that indicates whether it is running or not.
##   It takes one of the following two formats.
##
##   SUBSHELL/SIG
##     SUBSHELL is the depth of the subshell from which the trap processing is performed (
##     BASH_SUBSHELL value). SIG is an integer representing the signal
##     Value.
##
##   SUBSHELL/exit:EXIT
##     EXIT is the exit status passed to ble/builtin/exit, which is the final
##     This is the exit status used for standard exits.
##
_ble_builtin_trap_processing=
_ble_builtin_trap_postproc=()
_ble_builtin_trap_lastarg=()
function ble/builtin/trap/install-hook/.compose-trap_command {
  local sig=$1 name=${_ble_builtin_trap_sig_name[$1]}
  local handler='ble/builtin/trap/.handler SIGNUM "$BASH_COMMAND" "$@"; builtin eval -- "${_ble_builtin_trap_postproc[SIGNUM]}" \# "${_ble_builtin_trap_lastarg[SIGNUM]}"'
  trap_command="trap -- '${handler//SIGNUM/$sig}' $name" # WA #D1738 checked (sig is integer)
}

_ble_trap_builtin_handler_DEBUG_filter=

## @fn ble/builtin/trap/.handler sig bash_command params...
##   @param[in] sig
##     Specifies the signal number
##   @param[in] bash_command
##     Specifies the value of BASH_COMMAND in the original context
##   @param[in] params...
##     Specifies the positional parameters in the original context
##   @var[in] _ble_builtin_trap_depth
##   @var[out] _ble_builtin_trap_xlastarg[_ble_builtin_trap_depth]
##   @var[out] _ble_builtin_trap_xpostproc[_ble_builtin_trap_depth]
function ble/builtin/trap/.handler {
  local _ble_trap_lastexit=$? _ble_trap_lastarg=$_ FUNCNEST= IFS=$_ble_term_IFS
  local _ble_trap_sig=$1 _ble_trap_bash_command=$2
  shift 2

  # Note: In bash-5.2, if WINCH comes during read -t, it fires on the spot and something strange happens.
  #   A lot of things happen. (1) When I try to run ble/util/msleep inside, the outside
  #   The timeout setting is removed, causing the outer read -t to never finish. Special
  #   msleep tries to read from a stream that never terminates, which can lead to deadlocks.
  #   Ru. (2) If you try to use command substitution $() or mapfile in
  #   run_pending_trap (trap.c) was unexpectedly interrupted midway and running_trap
  #   becomes abandoned. WINCH keeps trap processing nested
  #   It becomes impossible to receive.
  if [[ $_ble_bash_read_winch && ${_ble_builtin_trap_sig_name[_ble_trap_sig]} == SIGWINCH ]]; then
    local ret
    ble/string#quote-command "$FUNCNAME" "$_ble_trap_sig" "$_ble_trap_bash_command" "$@"
    _ble_bash_read_winch=$ret$'\n''builtin eval -- "${_ble_builtin_trap_postproc['$_ble_trap_sig']}"'
    return 0
  fi

  # Early filter for frequently called DEBUG (set by edit.sh)
  if ((_ble_trap_sig==_ble_builtin_trap_DEBUG)) &&
       ! builtin eval -- "$_ble_trap_builtin_handler_DEBUG_filter"; then
    _ble_builtin_trap_lastarg[_ble_trap_sig]=${_ble_trap_lastarg//*$_ble_term_nl*}
    _ble_builtin_trap_postproc[_ble_trap_sig]="ble/util/setexit $_ble_trap_lastexit"
    return 0
  fi

  # Adjust trap context
  local _ble_trap_set _ble_trap_shopt; ble/base/.adjust-bash-options _ble_trap_set _ble_trap_shopt
  local _ble_trap_name=${_ble_builtin_trap_sig_name[_ble_trap_sig]#SIG}
  local -a _ble_trap_args; _ble_trap_args=("$@")
  if [[ ! $_ble_trap_bash_command ]] || ((_ble_bash<30200)); then
    # Note: Bash 3.0 and 3.1 have traps, but BASH_COMMAND is not a trap target.
    # is the command currently being executed. _ble_trap_bash_command simply has
    # ble/builtin/trap/.handler is included, so replace it with another appropriate value.
    if [[ $_ble_attached ]]; then
      _ble_trap_bash_command=$_ble_edit_exec_BASH_COMMAND
    else
      ble/util/assign _ble_trap_bash_command 'HISTTIMEFORMAT=__ble_ext__ builtin history 1'
      _ble_trap_bash_command=${_ble_trap_bash_command#*__ble_ext__}
    fi
  fi

  local _ble_builtin_trap_processing=${BASH_SUBSHELL:-0}/$_ble_trap_sig
  _ble_builtin_trap_lastarg[_ble_trap_sig]=$_ble_trap_lastarg
  _ble_builtin_trap_postproc[_ble_trap_sig]="ble/util/setexit $_ble_trap_lastexit"

  # Note #D1782: "builtin exit ... &>/dev/null" in ble/builtin/exit
  #   Undo the redirection. Error originally output by builtin exit
  #   This is a redirect to ignore the EXIT trap that is subsequently called.
  #   This redirection will remain in effect even for
  #   In bash-4.4..5.1, due to a bug, EXIT after returning control to top-level
  #   trap Other processing is executed, so EXIT trap is executed while connected to the tty.
  #   executed). The same thing happens when other traps are called unexpectedly.
  #   It happens. trap handler on stdout/stderr in the context of exit
  #   To execute, connect stdout/stderr back to what was saved.
  if [[ $_ble_builtin_exit_processing ]]; then
    exec 1>&- 1>&"$_ble_builtin_exit_stdout"
    exec 2>&- 2>&"$_ble_builtin_exit_stderr"
  fi

  local BLE_TRAP_FUNCNAME BLE_TRAP_SOURCE BLE_TRAP_LINENO
  BLE_TRAP_FUNCNAME=("${FUNCNAME[@]:1}")
  BLE_TRAP_SOURCE=("${BASH_SOURCE[@]:1}")
  BLE_TRAP_LINENO=("${BASH_LINENO[@]}")
  [[ $_ble_attached ]] &&
    BLE_TRAP_LINENO[${#BASH_LINENO[@]}-1]=$_ble_edit_LINENO

  # ble.sh internal hook
  ble/util/joblist.check
  ble/util/setexit "$_ble_trap_lastexit" "$_ble_trap_lastarg"
  blehook/invoke "internal_$_ble_trap_name"; local internal_ext=$?
  ble/util/joblist.check ignore-volatile-jobs

  if ((internal_ext!=126)); then
    if ! ble/util/is-running-in-subshell; then
      # blehook (only activated in parent shells)
      ble/util/setexit "$_ble_trap_lastexit" "$_ble_trap_lastarg"
      BASH_COMMAND=$_ble_trap_bash_command \
        blehook/invoke "$_ble_trap_name"
      ble/util/joblist.check ignore-volatile-jobs
    fi

    # user hook
    local install_opts=${_ble_builtin_trap_sig_opts[_ble_trap_sig]}
    if [[ :$install_opts: == *:user-trap-in-postproc:* ]]; then
      # Execute user trap outside (Note: user-trap lastarg is not reflected)
      local q=\' Q="'\''" _ble_trap_handler postproc=
      ble/builtin/trap/user-handler#load "$_ble_trap_sig"
      if [[ $_ble_trap_handler == *[!$_ble_term_IFS]* ]]; then
        postproc="ble/util/setexit $_ble_trap_lastexit '${_ble_trap_lastarg//$q/$Q}'"
        postproc=$postproc";LINENO=$BLE_TRAP_LINENO builtin eval -- '${_ble_trap_handler//$q/$Q}'"
      else
        postproc="ble/util/setexit $_ble_trap_lastexit"
      fi
      _ble_builtin_trap_postproc[_ble_trap_sig]=$postproc
    else
      ble/util/setexit "$_ble_trap_lastexit" "$_ble_trap_lastarg"
      BASH_COMMAND=$_ble_trap_bash_command LINENO=$BLE_TRAP_LINENO \
        ble/builtin/trap/invoke "$_ble_trap_sig" "${_ble_trap_args[@]}"
    fi
  fi

  # If exit is requested at some point
  if [[ $_ble_builtin_trap_processing == */exit:* && ${_ble_builtin_trap_postproc[_ble_trap_sig]} != 'ble/builtin/exit '* ]]; then
    _ble_builtin_trap_postproc[_ble_trap_sig]="ble/builtin/exit ${_ble_builtin_trap_processing#*/exit:}"
  fi

  # Note #D1757: Currently, to set $_ after eval is
  # '#' The only option is to pass an extra "$lastarg", so line breaks cannot be included.
  # Rather than setting a halfway value, it is better not to set anything from the beginning. Set here
  # At first glance, it seems that no one uses lastarg, but it is set bare.
  # Since the user trap may refer to it, set it just in case.
  [[ ${_ble_builtin_trap_lastarg[_ble_trap_sig]} == *$'\n'* ]] &&
    _ble_builtin_trap_lastarg[_ble_trap_sig]=

  if ((_ble_trap_sig==_ble_builtin_trap_EXIT)); then
    # Note #D1797: ble/base/unload for EXIT is the lowest possible trap handler.
    # Execute later. It would be a problem if it were deleted without permission, and if another handler uses the ble.sh function.
    # To prevent problems from occurring when
    ble/base/unload EXIT
  elif ((_ble_trap_sig==_ble_builtin_trap_RETURN)); then
    # Note #D1863: Perform inheritance processing to the caller of RETURN trap.
    ble/builtin/trap/user-handler#update:RETURN
  fi

  ble/base/.restore-bash-options _ble_trap_set _ble_trap_shopt
}

## @fn ble/builtin/trap/install-hook sig [opts]
##   @param[in] sig
##     signal name or number
##   @param[in,opt] opts
##     readline A trap handler that is expected to have additional processing by readline.
##              indicates something. If there is already a configured handler
##              does not reconfigure the handler.
##     If no inactive user trap is set, hand from builtin trap.
##              Delete the registration.
function ble/builtin/trap/install-hook {
  local ret opts=${2-}
  ble/builtin/trap/sig#resolve "$1"
  local sig=$ret name=${_ble_builtin_trap_sig_name[ret]}
  ble/builtin/trap/sig#reserve "$sig" "override-builtin-signal:$opts"

  local trap_command; ble/builtin/trap/install-hook/.compose-trap_command "$sig"
  local trap_string; ble/util/assign trap_string "builtin trap -p $name"

  if [[ :$opts: == *:readline:* ]] && ! ble/util/is-running-in-subshell; then
    # Note #D1345: If you use "builtin trap -- WINCH" etc. inside ble.sh
    # readline processing is no longer performed (COLUMNS, LINES are updated)
    # ).
    #
    # About TSTP, TTIN, TTOU, INT, TERM, HUP, QUIT, WINCH in Bash
    # readline has added processing. Once you run builtin trap,
    # The trap_handler set by trap is set, but "after command execution"
    # readline uses a function called rl_maybe_set_sighandler to override
    # Insert readline-specific processing. ble.sh is readline's "command
    # Since "execute" is not used, additional processing by readline disappears.
    #
    # As a countermeasure, if the character string you are about to register is already registered.
    # If it matches, skip calling builtin trap.
    #
    # - Currently, WINCH is the only one that is a problem, so let's try WINCH for now.
    #   Just take measures.
    # - It seems that INT does not become effective (?) if it is set within bind -x unless it is set again.
    #   Builtin trap cannot be omitted even if it is already registered in .
    #
    [[ $trap_command == "$trap_string" ]] && trap_command= trap_string=

    # Note (#D2021): If the original trap is saved when reloading, read it.
    [[ $trap_string ]] || trap_string=${_ble_builtin_trap_handlers_reload[sig]-}
  fi

  [[ ! $trap_command || :$opts: == *:inactive:* && ! $trap_string ]] ||
    builtin eval "builtin $trap_command"; local ext=$?

  local q=\'
  if [[ $trap_string == "trap -- '"* ]] && ! ble/builtin/trap/user-handler/is-internal "${trap_string#*$q}"; then
    # Note: 1000 or more are traps for debugging (DEBUG, RETURN, EXIT), and traps are set by default.
    # The contents of trap_string cannot be trusted because it is not inherited by function calls.
    ((sig<1000)) &&
      # Note: Read configuration only if there is no existing handler. If there are existing settings
      # This means that trap was executed after loading ble.sh. On the other hand, ble.sh
      # If the builtin trap configuration has been changed directly by the user since it was loaded.
      # The results read from the builtin trap are stored in the ble.sh row.
      # You can assume that it is before.
      ! ble/builtin/trap/user-handler#has "$sig" &&
      builtin eval -- ble/builtin/"$trap_string"
  fi

  return "$ext"
}
