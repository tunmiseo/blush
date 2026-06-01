#!/bin/bash

# Generates the following two files according to the current bash version:
#
#   $_ble_base_cache/decode.bind.$_ble_bash.$bleopt_input_encoding.bind
#   $_ble_base_cache/decode.bind.$_ble_bash.$bleopt_input_encoding.unbind
#
# Note: #D1300 Non-terminal characters in macros bound with bind -s are
#   Need to check with decode.sh (ble/decode/nonblocking-read).
#   The current implementation checks 0xC0 and 0xDE.
#   When adding macros, you need to add checks accordingly.
#
# 2025-05-04 Old attaching strategies have been removed in commit 514d177e.
# * In the very initial code, to receive ESC, we have been binding the "-x"
#   hook to all combinations of "ESC ?".  This strategy had problems with
#   "bash_execute_unix_command: cannot find keymap for command", so one needed
#   to convert "ESC [" to another sequence using a readline macro.  To work
#   around the remaining entries in the internal keymap, we also tried to bind
#   all the key combinations that existed before attaching.  In some Bash
#   versions, we also needed to add a workaround for "ESC ESC".
# * Those problems turned out to be able to be evaded by converting ESC using a
#   readline macro.  The first attempt was based on « bind '"\e": "\xC0\x9B"' »
#   to convert ESC to two bytes using the readline macro.
# * We now use a similar method with all the combinations of "ESC ?" to
#   distinguish isolated ESC and prefix ESC.

function ble/init:bind/append {
  local xarg="\"$1\":_ble_decode_hook $2; builtin eval -- \"\$_ble_decode_bind_hook\""
  local rarg=$1 condition=$3${3:+' && '}
  ble/util/print "${condition}builtin bind -x '${xarg//$q/$Q}'" >&3
  ble/util/print "${condition}builtin bind -r '${rarg//$q/$Q}'" >&4
}
function ble/init:bind/append-macro {
  local kseq1=$1 kseq2=$2 condition=$3${3:+' && '}
  local sarg="\"$kseq1\":\"$kseq2\"" rarg=$kseq1
  ble/util/print "${condition}builtin bind    '${sarg//$q/$Q}'" >&3
  ble/util/print "${condition}builtin bind -r '${rarg//$q/$Q}'" >&4
}
function ble/init:bind/bind-s {
  local sarg=$1
  ble/util/print "builtin bind '${sarg//$q/$Q}'" >&3
}

function ble/init:bind/.generate {
  local q=\' Q="'\\''"

  # ENCODING: UTF-8 2-byte code of 0, C-x, and ESC (UTF-8 dependent)
  local altdqs00='\xC0\x80'
  local altdqs24='\xC0\x98'
  local altdqs27='\xC0\x9B'
  # ENCODING: UTF-8 (_ble_decode_IsolatedESC U+07BC)
  local isolated27='\xDE\xBC'
  local prefixO='\xDE\xBA'

  # *Since bash-4.3, the behavior of bind -x seems to be different from before.
  #   Most importantly, it is now possible to bind to objects larger than 3 bytes (but it is not used in ble.sh)

  # * C-@ (0) for some reason bind -x in bash-4.3
  #   bash: bash_execute_unix_command: No keymap for command
  #   bash_execute_unix_command: cannot find keymap for command
  #   It becomes It doesn't work even if you allocate everything to "C-@ *".
  #   bind '"\C-@":""' seems to work, so I translate it to a different representation in UTF-8.
  local esc00=$((40300<=_ble_bash&&_ble_bash<50000))

  # * Crash when directly bind -x to C-x (24).
  #   #D0017 #D0018 #D0057 #D0122 #D0148 #D0391 #D0583 #D1478
  #
  #   [Symptoms]
  #   Problems occur with set -o emacs on all versions of bash-3.0 to bash-4.4 except bash-4.3.
  #   For example, if you type C-x C-b C-b, it will freeze in an infinite loop in bash-3.2.
  #   In bash-4.4, the error message is "No keymap for command".
  #   Any other bash will crash after a few seconds.
  #   This has been fixed in bash-5.0, so no countermeasures are required (#D1163)
  #
  #   [Workaround 1] "C-x ?" Full binding... used in bash-3.0..4.2
  #
  #   Instead of directly binding to C-x, use the two-character combination bind -x '"\C-x?": ...'.
  #
  #   * bash-3.0..4.2: If you do this, aftereffects will remain when you switch to vi.
  #     By adding submap to cmd_xmap[24], \C-x\C-x for \C-x
  #     The command will now be executed. As a countermeasure, directly bind to "\C-x?"
  #     Instead of -x, use a macro to replace "\C-x?" with UTF-8 alternative representation.
  #     I will. (#D1478)
  #
  #   [Countermeasure 2] Reject #D0583
  #   Do something like bind -s '"\C-x": "\xC0\x98"'.
  #   It no longer crashes, but a mysterious delay remains.
  #   The only way to eliminate the delay is to execute countermeasure 1.
  #
  #   [Workaround 3] Single C-x (with \C-x\C-x shadow) ... used in bash-4.4 (#D1478)
  #
  #   First use bind -x '"\C-x\C-x":hook 24' and then remove it with bind -r '\C-x\C-x'
  #   Ru. After this, if you timeout with bind -x '"\C-x":...', the command of "\C-x\C-x"
  #   is executed.
  #
  #   * If you bind to \C-x\C-x even once in bash-3.0..4.2, C-x will no longer timeout.
  #     Therefore, only emacs keymap should be used to implement this measure.
  #
  local bind18XX=0
  if ((40400<=_ble_bash&&_ble_bash<50000)); then
    # Insert a dummy entry in "cmd_xmap"
    ble/util/print "[[ -o emacs ]] && builtin bind 'set keyseq-timeout 1'" >&3
    ble/init:bind/append '\C-x\C-x' 24 '[[ -o emacs ]]' 4>&3
  elif ((_ble_bash<40300)); then
    bind18XX=1
  fi

  # ESC reception method
  #
  # * 2017-10-22 As a new method
  #
  #     bind '"\e":"\e[27;5;91~"'
  #     bind '"\e?":"\xC0\x9B?"'
  #     bind '"\e\e":"\xC0\x9B\e[27;5;91~"'
  #
  #   Register both 1-character and 2-character characters with bind -s and write them to Readline.
  #   One way is to distinguish between single ESCs by determining whether there is a continuation of the ESC.

  # bind1B4FXX 2025-05-03
  #
  # * bind1B4FXX=1: In bash 4.4 and below, when SS3 arrow keys (ESC O A) are received,
  # is-stdin-ready always fails (bash is internally prefetching and processing something).
  #   ), so even if you try to distinguish it from M-O with wait-input, it will not work. isolated ESC
  #   Similarly, register and distinguish between ESC O and ESC ?.
  #
  #   It is assumed that a binding is set to "ESC O".
  local bind1B4FXX=$((40000<=_ble_bash&&_ble_bash<50000))

  # Note: 'set convert-meta on' workaround
  #
  #   When bind 'set convert-meta on', bind -p '"\200": ...' etc.
  #   It overwrites cmd_xmap such as "\C-@".
  #   I am trying to temporarily 'set convert-meta off' at the caller, but
  #   As insurance, bind 128-255 first, then bind 0-127.
  local i
  for i in {128..255} {0..127}; do
    local ret; ble/decode/c2dqs "$i"

    # *
    if ((i==0)); then
      # C-@
      if ((esc00)); then
        ble/init:bind/append-macro '\C-@' "$altdqs00"
      else
        ble/init:bind/append "$ret" "$i"
      fi
    elif ((i==24)); then
      # C-x
      if ((bind18XX)); then
        ble/init:bind/append "$ret" "$i" '[[ ! -o emacs ]]'
      else
        ble/init:bind/append "$ret" "$i"
      fi
    elif ((i==27)); then
      # C-[
      ble/init:bind/append-macro '\e' "$isolated27" # C-[
    else
      # Note: In Bash-5.0, binding with \C-\\ causes strange things #D1162 #D1078
      ((i==28&&_ble_bash>=50000)) && ret='\x1C'
      ble/init:bind/append "$ret" "$i"
    fi

    # # C-@ * for bash-4.3 (2015-02-11) Wasted?
    # ble/init:bind/append "\\C-@$ret" "0 $i"

    # C-x *
    if ((bind18XX)); then
      # In emacs mode, register with the combination "C-x ?".
      # Note: If you use bind -x normally, \C-x in cmd_xmap becomes ambiguous and becomes a single value on vi side.
      # "C-x" doesn't work, so here we receive it through UTF-8 2B display.
      if ((i==0)); then
        ble/init:bind/append-macro "\C-x$ret" "$altdqs24$altdqs00" '[[ -o emacs ]]'
      elif ((i==24)); then
        ble/init:bind/append-macro "\C-x$ret" "$altdqs24$altdqs24" '[[ -o emacs ]]'
      else
        ble/init:bind/append-macro "\C-x$ret" "$altdqs24$ret"      '[[ -o emacs ]]'
      fi
    fi

    # ESC ?
    if ((i==0)); then
      ble/init:bind/append-macro '\e'"$ret" "$altdqs27$altdqs00"
    elif ((bind18XX&&i==24)); then
      ble/init:bind/append-macro '\e'"$ret" "$altdqs27$altdqs24"
    else
      ble/init:bind/append-macro '\e'"$ret" "$altdqs27$ret"
    fi

    # ESC O ?
    if ((bind1B4FXX)); then
      if ((i==0)); then
        ble/init:bind/append-macro '\eO'"$ret" "$altdqs27$prefixO$altdqs00"
      elif ((bind18XX&&i==24)); then
        ble/init:bind/append-macro '\eO'"$ret" "$altdqs27$prefixO$altdqs24"
      else
        ble/init:bind/append-macro '\eO'"$ret" "$altdqs27$prefixO$ret"
      fi
    fi
  done

  ble/function#try ble/encoding:"$bleopt_input_encoding"/generate-binder

  local hash='e69de29bb2d1d6434b8b29ae775ad8c2e48c5391'
  ble/util/print "_ble_decode_bind_cache_hash='$hash'" >&3
}

function ble/init:bind/generate-binder {
  local fbind1=$_ble_base_cache/decode.bind.$_ble_bash.$bleopt_input_encoding.bind
  local fbind2=$_ble_base_cache/decode.bind.$_ble_bash.$bleopt_input_encoding.unbind

  ble/edit/info/show text "ble.sh: updating binders..."

  ble/init:bind/.generate 3>| "$fbind1" 4>| "$fbind2"

  ble/edit/info/immediate-show text "ble.sh: updating binders... done"
}

ble/init:bind/generate-binder
