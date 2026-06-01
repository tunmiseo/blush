#!/bin/bash

# Note: It can be called recursively from within bind (INITIALIZE_DEFMAP), so
# You need to overwrite ble-edit/bind/load-editing-mode:vi first.
ble/is-function ble-edit/bind/load-editing-mode:vi && return 0
function ble-edit/bind/load-editing-mode:vi { return 0; }

# 2020-04-29 force update (rename ble-decode/keymap/.register)
# 2021-01-25 force update (change mapping of C-w and M-w)
# 2021-04-26 force update (rename ble/decode/keymap#.register)
# 2021-09-23 force update (change to nsearch and bind-history)

source -- "$_ble_base/lib/keymap.vi_digraph.sh"

## @bleopt keymap_vi_macro_depth
bleopt/declare -n keymap_vi_macro_depth 64

## @fn ble/keymap:vi/k2c key
##   @var[out] ret
function ble/keymap:vi/k2c {
  local key=$1
  local flag=$((key&_ble_decode_MaskFlag)) char=$((key&_ble_decode_MaskChar))
  if ((flag==0&&(32<=char&&char<_ble_decode_FunctionKeyBase))); then
    ret=$char
    return 0
  elif ((flag==_ble_decode_Ctrl&&63<=char&&char<128&&(char&0x1F)!=0)); then
    ((char=char==63?127:char&0x1F))
    ret=$char
    return 0
  else
    return 1
  fi
}

#------------------------------------------------------------------------------
# utils

## @fn ble/string#index-of-chars text chars [index]
##   Search forward in a string for characters in a character set.
## @fn ble/string#last-index-of-chars text chars [index]
##   Search backwards through a string for characters in a character set.
##
##   @param[in] text
##     Specify the string to search for.
##   @param[in] chars
##     specifies the set of characters to search for
##   @param[in] index
##     Specifies the starting position within text.
##   @var[out] ret
##
function ble/string#index-of-chars {
  local chars=$2 index=${3:-0}
  local text=${1:index}
  local cut=${text%%["$chars"]*}
  if ((${#cut}<${#text})); then
    ((ret=index+${#cut}))
    return 0
  else
    ret=-1
    return 1
  fi
}
function ble/string#last-index-of-chars {
  local text=$1 chars=$2 index=$3
  [[ $index ]] && text=${text::index}
  local cut=${text%["$chars"]*}
  if ((${#cut}<${#text})); then
    ((ret=${#cut}))
    return 0
  else
    ret=-1
    return 1
  fi
}

## @fn ble-edit/content/nonbol-eolp text
##   @var[out] ret
function ble-edit/content/nonbol-eolp {
  local pos=${1:-$_ble_edit_ind}
  ! ble-edit/content/bolp "$pos" && ble-edit/content/eolp "$pos"
}

## @fn ble/keymap:vi/string#encode-rot13 text
##   @var[out] ret
function ble/keymap:vi/string#encode-rot13 {
  local text=$1
  local -a buff=() ch
  for ((i=0;i<${#text};i++)); do
    ch=${text:i:1}
    if ble/string#isupper "$ch"; then
      ch=${_ble_util_string_upper_list%%"$ch"*}
      ch=${_ble_util_string_upper_list:(${#ch}+13)%26:1}
    elif ble/string#islower "$ch"; then
      ch=${_ble_util_string_lower_list%%"$ch"*}
      ch=${_ble_util_string_lower_list:(${#ch}+13)%26:1}
    fi
    ble/array#push buff "$ch"
  done
  IFS= builtin eval 'ret="${buff[*]-}"'
}

#------------------------------------------------------------------------------
# constants

_ble_keymap_vi_REX_WORD=$'[_a-zA-Z0-9]+|[!-/:-@[-`{-~]+|[^ \t\na-zA-Z0-9!-/:-@[-`{-~]+'

#------------------------------------------------------------------------------
# vi_imap/__default__, vi-command/decompose-meta

function ble/widget/vi_imap/__default__ {
  local flag=$((KEYS[0]&_ble_decode_MaskFlag)) code=$((KEYS[0]&_ble_decode_MaskChar))

  # Input M-key with meta-qualification is decomposed into ESC + key
  if ((flag&_ble_decode_Meta)); then
    ble/keymap:vi/imap-repeat/pop

    local esc=27 # ESC
    # local esc=$((_ble_decode_Ctrl|0x5b)) # or C-[
    ((flag&=~_ble_decode_Meta))
    ((flag==_ble_decode_Shft&&0x61<=code&&code<=0x7A&&(flag=0,code-=0x20)))
    ble/decode/widget/redispatch-by-keys "$esc" "$((flag|code))" "${KEYS[@]:1}"
    return 0
  fi

  # Control-qualified characters C-@ - C-\, C-? are inserted back into control characters \000 - \037, \177
  if local ret; ble/keymap:vi/k2c "${KEYS[0]}"; then
    local -a KEYS; KEYS=("$ret")
    ble/widget/self-insert
    return 0
  fi

  return 125
}

function ble/widget/vi-command/decompose-meta {
  local flag=$((KEYS[0]&_ble_decode_MaskFlag)) code=$((KEYS[0]&_ble_decode_MaskChar))

  # Input M-key with meta-qualification is decomposed into ESC + key
  if ((flag&_ble_decode_Meta)); then
    local esc=$((_ble_decode_Ctrl|0x5b)) # C-[ (or esc=27 ESC?)
    ((flag&=~_ble_decode_Meta))
    ((flag==_ble_decode_Shft&&0x61<=code&&code<=0x7A&&(flag=0,code-=0x20)))
    ble/decode/widget/redispatch-by-keys "$esc" "$((flag|code))" "${KEYS[@]:1}"
    return 0
  fi

  return 125
}

function ble/widget/vi_omap/__default__ {
  ble/widget/vi-command/decompose-meta || ble/widget/vi-command/bell
  return 0
}
function ble/widget/vi_omap/cancel {
  ble/keymap:vi/adjust-command-mode
  return 0
}

#------------------------------------------------------------------------------
# repeat

## @var _ble_keymap_vi_irepeat_count
##   Records the arguments specified when entering insert mode.
_ble_keymap_vi_irepeat_count=

## @arr _ble_keymap_vi_irepeat
## If the argument specified when entering insert mode is greater than 1,
##   An array that records the operation so that it can be repeated later.
##
##   Each element has the format keys:widget.
##   keys is a space-separated string of keys (integer values), ie ${KEYS[*]}.
##   widget is the contents of WIDGET that is actually called.
##
_ble_keymap_vi_irepeat=()

ble/array#push _ble_textarea_local_VARNAMES \
               _ble_keymap_vi_irepeat_count \
               _ble_keymap_vi_irepeat

function ble/keymap:vi/imap-repeat/pop {
  local top_index=$((${#_ble_keymap_vi_irepeat[*]}-1))
  ((top_index>=0)) && builtin unset -v '_ble_keymap_vi_irepeat[top_index]'
}
function ble/keymap:vi/imap-repeat/push {
  local IFS=$_ble_term_IFS
  ble/array#push _ble_keymap_vi_irepeat "${KEYS[*]-}:$WIDGET"
}

function ble/keymap:vi/imap-repeat/reset {
  local count=${1-}
  _ble_keymap_vi_irepeat_count=
  _ble_keymap_vi_irepeat=()
  ((count>1)) && _ble_keymap_vi_irepeat_count=$count
}
function ble/keymap:vi/imap-repeat/process {
  if ((_ble_keymap_vi_irepeat_count>1)); then
    local repeat=$_ble_keymap_vi_irepeat_count
    local -a widgets; widgets=("${_ble_keymap_vi_irepeat[@]}")

    local i widget
    for ((i=1;i<repeat;i++)); do
      for widget in "${widgets[@]}"; do
        ble/decode/widget/call "${widget#*:}" ${widget%%:*}
      done
    done
  fi
}

function ble/keymap:vi/imap/invoke-widget {
  local WIDGET=$1
  local -a KEYS; KEYS=("${@:2}")
  ble/keymap:vi/imap-repeat/push
  builtin eval -- "$WIDGET"
}

## @arr _ble_keymap_vi_imap_white_list
##   List of commands that are allowed to repeat when exiting insert mode entered with arguments
_ble_keymap_vi_imap_white_list=(
  self-insert
  batch-insert
  nop
  magic-space magic-slash
  delete-backward-{c,f,s,u}word
  copy{,-forward,-backward}-{c,f,s,u}word
  copy-region{,-or}
  clear-screen
  command-help
  display-shell-version
  redraw-line
)
function ble/keymap:vi/imap/is-command-white {
  if [[ $1 == ble/widget/self-insert ]]; then
    # frequently used command is checked first
    return 0
  elif [[ $1 == ble/widget/* ]]; then
    local IFS=$_ble_term_IFS
    local cmd=${1#ble/widget/}; cmd=${cmd%%["$_ble_term_IFS"]*}
    [[ $cmd == vi_imap/* || " ${_ble_keymap_vi_imap_white_list[*]} " == *" $cmd "*  ]] && return 0
  fi
  return 1
}

function ble/widget/vi_imap/__before_widget__ {
  if ble/keymap:vi/imap/is-command-white "$WIDGET"; then
    ble/keymap:vi/imap-repeat/push
  else
    if ((_ble_keymap_vi_mark_edit_dbeg>=0)); then
      ble/keymap:vi/mark/end-edit-area
      ble/keymap:vi/repeat/record-insert
      ble/keymap:vi/mark/start-edit-area
    fi
    ble/keymap:vi/imap-repeat/reset
  fi
}

# Note: The following widgets need to have the name of the form "vi_imap/*" to
# suppress the invokation of "ble-edit/undo/add".
function ble/widget/vi_imap/undo { ble/widget/undo "$@"; }
function ble/widget/vi_imap/redo { ble/widget/redo "$@"; }
function ble/widget/vi_imap/revert { ble/widget/revert "$@"; }

#------------------------------------------------------------------------------
# vi_imap/complete

function ble/widget/vi_imap/complete {
  ble/keymap:vi/imap-repeat/pop
  ble/keymap:vi/undo/add more
  ble/widget/complete "$@"
}
function ble/widget/vi_imap/menu-complete {
  ble/widget/vi_imap/complete "enter_menu:insert_unique:$@"
}

function ble/widget/vi_nmap/complete {
  # We reset the edit argument for "ble/widget/complete".
  local ARG FLAG REG; ble/keymap:vi/get-arg ''
  _ble_edit_arg=$ARG

  # Note: We adjust the cursor position unless we are at the end of a line.  To
  #   be consistent with Bash's "bash-vi-complete" and "vi-complete", we do not
  #   adjust the cursor position also when the current position is tab or
  #   space.  This behavior seems also natural for the user's perspective,
  #   though it introduces a non-trivial behavioral variation.
  ble-edit/content/eolp ||
    [[ ${_ble_edit_str:_ble_edit_ind:1} == ["$_ble_term_IFS"] ]] ||
    ((_ble_edit_ind++))

  local keymap=$_ble_decode_keymap
  ble/widget/complete "$@"; local ext=$?
  if [[ $_ble_decode_keymap == "$keymap" ]]; then
    if [[ :$1: == *:vi_nmap/insert-mode:* ]]; then
      ble/widget/vi_nmap/.insert-mode
    else
      # Note: We record the editing area `[`] through
      #   "ble/keymap:vi/complete/insert.hook", so we do not need to manually set
      #   up the edit area by calling "ble/keymap:vi/mark/{start,end}-edit-area".
      #   "ble-edit/undo/add" is also called through
      #   "ble/keymap:vi/mark/set-previous-edit-area" called from
      #   "ble/keymap:vi/complete/insert.hook".
      # Note: if "ble/widget/complete" enters another mode such as the
      #   menu-complete mode, we do not try to adjust the state here.  Instead,
      #   we adjust the state in "ble/complete/menu_complete/exit" after the
      #   corresponding "ble/decode/keymap/pop".
      ble-edit/content/bolp || ((_ble_edit_ind--))
      ble/keymap:vi/adjust-command-mode
    fi
  fi
  return "$ext"
}
function ble/widget/vi_nmap/menu-complete {
  ble/widget/vi_nmap/complete "enter_menu:insert_unique:$@"
}
function ble/widget/vi_nmap/complete-insert {
  local original=$1 insert=$2 suffix=$3
  ble-edit/content/eolp || ((_ble_edit_ind++))
  local ind=$_ble_edit_ind
  if ble/widget/complete-insert "$@"; then
    local beg=$((ind-${#original}))
    local end=$((beg+${#insert}+${#suffix}))
    ble/keymap:vi/mark/set-previous-edit-area "$beg" "$end"
  fi
  ble-edit/content/bolp || ((_ble_edit_ind--))
}

function ble/keymap:vi/complete/insert.hook {
  local keymap
  ble/decode/keymap/get-major-keymap
  [[ $keymap == vi_[in]map ]] || return 0

  local q="'" Q="'\''"
  local original=${comp_text:insert_beg:insert_end-insert_beg}
  local WIDGET="ble/widget/complete-insert '${original//$q/$Q}' '${insert//$q/$Q}' '${suffix//$q/$Q}'"

  case $keymap in
  (vi_imap)
    ble/keymap:vi/imap-repeat/push # @var[in] WIDGET
    [[ $_ble_decode_keymap == vi_imap ]] &&
      ble/keymap:vi/undo/add more ;;
  (vi_nmap)
    local beg=$insert_beg end=$((insert_beg+${#insert}+${#suffix}))
    ble/keymap:vi/mark/set-previous-edit-area "$beg" "$end"
    local KEYMAP=vi_nmap ARG= FLAG= REG=
    WIDGET=ble/widget/vi_nmap/${WIDGET#ble/widget/}
    ble/keymap:vi/repeat/record-normal ;; # @var[in] KEYMAP WIDGET ARG FLAG REG
  esac
}
blehook complete_insert!=ble/keymap:vi/complete/insert.hook

function ble-decode/keymap:vi_imap/bind-complete {
  ble-bind -f 'C-i'      'vi_imap/complete'
  ble-bind -f 'TAB'      'vi_imap/complete'
  ble-bind -f 'C-TAB'    'vi_imap/menu-complete'
  ble-bind -f 'S-C-i'    'vi_imap/menu-complete backward'
  ble-bind -f 'S-TAB'    'vi_imap/menu-complete backward'
  ble-bind -f 'ac_enter' 'auto-complete-enter'

  ble-bind -f 'C-x /' 'vi_imap/menu-complete context=filename'
  ble-bind -f 'C-x ~' 'vi_imap/menu-complete context=username'
  ble-bind -f 'C-x $' 'vi_imap/menu-complete context=variable'
  ble-bind -f 'C-x @' 'vi_imap/menu-complete context=hostname'
  ble-bind -f 'C-x !' 'vi_imap/menu-complete context=command'

  ble-bind -f 'C-]'     'sabbrev-expand'
  ble-bind -f 'C-x C-r' 'dabbrev-expand'

  ble-bind -f 'C-x *' 'vi_imap/complete insert_all:context=glob'
  ble-bind -f 'C-x g' 'vi_imap/complete show_menu:context=glob'
}

function ble/widget/vi-rlfunc/vi-complete {
  local key=0
  ((${#KEYS[@]})) && key=${KEYS[${#KEYS[@]}-1]:-0}

  if ((key==0x2a)); then # '*'
    ble/widget/vi_nmap/complete "insert-all:vi_nmap/insert-mode:$@"
  elif ((key==0x3d)); then # '='
    ble/widget/vi_nmap/complete "show-menu:$@"
  elif ((key==0x5c)); then # '\'
    ble/complete/menu/clear
    ble/widget/vi_nmap/complete "vi_nmap/insert-mode:$@"
  else
    # Note: Bash does not enter the insert mode in the other cases, but it
    # seems inconsistent.  We here enter the insert mode also with the other
    # types of completions.  In our implementation, '=' is the only exception,
    # which makes sense because "show-menu" only shows the status in the info
    # panel and doesn't change the command line.  The users who want the Bash
    # behavior that doesn't enter the insert mode should use widget
    # "vi_nmap/complete".
    ble/widget/vi_nmap/complete "vi_nmap/insert-mode:$@"
  fi
}

function ble/widget/vi-rlfunc/bash-vi-complete {
  local key=0
  ((${#KEYS[@]})) && key=${KEYS[${#KEYS[@]}-1]:-0}

  if ((key==0x2a)); then # '*'
    ble/widget/vi_nmap/complete "context=glob:insert-all:vi_nmap/insert-mode:$@"
  elif ((key==0x3d)); then # '='
    ble/widget/vi_nmap/complete "context=glob:show-menu:$@"
  elif ((key==0x5c)); then # '\'
    ble/complete/menu/clear
    ble/widget/vi_nmap/complete "context=glob:vi_nmap/insert-mode:$@"
  else
    # Note: This implementation enters the insert mode in this case.  See the
    # code comment in ble/widget/vi-rlfunc/vi-complete.
    ble/widget/vi_nmap/complete "vi_nmap/insert-mode:$@"
  fi
}

#------------------------------------------------------------------------------
# modes

## @var _ble_keymap_vi_insert_overwrite
##   Overtype character when entering insert mode
_ble_keymap_vi_insert_overwrite=

## @var _ble_keymap_vi_insert_leave
##   Set the function to be executed when exiting insert mode
_ble_keymap_vi_insert_leave=

## @var _ble_keymap_vi_single_command
##   After executing one command in normal mode
##   Represents whether you are in return to original insert mode (C-o).
_ble_keymap_vi_single_command=
_ble_keymap_vi_single_command_overwrite=

ble/array#push _ble_textarea_local_VARNAMES \
               _ble_keymap_vi_insert_overwrite \
               _ble_keymap_vi_insert_leave \
               _ble_keymap_vi_single_command \
               _ble_keymap_vi_single_command_overwrite

## @bleopt keymap_vi_mode_string_nmap
##   Specify the string to display in normal mode.
##   If you specify an empty string, nothing will be displayed.
bleopt/declare -n keymap_vi_mode_string_nmap $'\e[1m~\e[m'
bleopt/declare -o keymap_vi_nmap_name keymap_vi_mode_string_nmap

bleopt/declare -v term_vi_imap ''
bleopt/declare -v term_vi_nmap ''
bleopt/declare -v term_vi_omap ''
bleopt/declare -v term_vi_xmap ''
bleopt/declare -v term_vi_smap ''
bleopt/declare -v term_vi_cmap ''

bleopt/declare -v keymap_vi_imap_cursor ''
bleopt/declare -v keymap_vi_nmap_cursor ''
bleopt/declare -v keymap_vi_omap_cursor ''
bleopt/declare -v keymap_vi_xmap_cursor ''
bleopt/declare -v keymap_vi_smap_cursor ''
bleopt/declare -v keymap_vi_cmap_cursor ''
function ble/keymap:vi/.process-cursor-options {
  local keymap=${FUNCNAME[1]#bleopt/check:keymap_}; keymap=${keymap%_cursor}
  ble-bind -m "$keymap" --cursor "$value"
  local locate=$'\e[32m'$bleopt_source:$bleopt_lineno$'\e[m'
  ble/util/print-lines \
    "bleopt ($locate): The option 'keymap_${keymap}_cursor' has been removed." \
    "  Please use 'ble-bind -m $keymap --cursor $value' instead." >&2
}
function bleopt/check:keymap_vi_imap_cursor { ble/keymap:vi/.process-cursor-options; }
function bleopt/check:keymap_vi_nmap_cursor { ble/keymap:vi/.process-cursor-options; }
function bleopt/check:keymap_vi_omap_cursor { ble/keymap:vi/.process-cursor-options; }
function bleopt/check:keymap_vi_xmap_cursor { ble/keymap:vi/.process-cursor-options; }
function bleopt/check:keymap_vi_smap_cursor { ble/keymap:vi/.process-cursor-options; }
function bleopt/check:keymap_vi_cmap_cursor { ble/keymap:vi/.process-cursor-options; }
function bleopt/obsolete:keymap_vi_imap_cursor { return 0; }
function bleopt/obsolete:keymap_vi_nmap_cursor { return 0; }
function bleopt/obsolete:keymap_vi_omap_cursor { return 0; }
function bleopt/obsolete:keymap_vi_xmap_cursor { return 0; }
function bleopt/obsolete:keymap_vi_smap_cursor { return 0; }
function bleopt/obsolete:keymap_vi_cmap_cursor { return 0; }

bleopt/declare -v keymap_vi_mode_show 1
function bleopt/check:keymap_vi_mode_show {
  local bleopt_keymap_vi_mode_show=$value
  [[ $_ble_attached ]] &&
    ble/keymap:vi/update-mode-indicator
  return 0
}

bleopt/declare -v keymap_vi_mode_update_prompt ''
bleopt/declare -v keymap_vi_mode_name_insert    'INSERT'
bleopt/declare -v keymap_vi_mode_name_replace   'REPLACE'
bleopt/declare -v keymap_vi_mode_name_vreplace  'VREPLACE'
bleopt/declare -v keymap_vi_mode_name_visual    'VISUAL'
bleopt/declare -v keymap_vi_mode_name_select    'SELECT'
bleopt/declare -v keymap_vi_mode_name_linewise  'LINE'
bleopt/declare -v keymap_vi_mode_name_blockwise 'BLOCK'
function bleopt/check:keymap_vi_mode_name_insert    { ble/keymap:vi/update-mode-indicator; }
function bleopt/check:keymap_vi_mode_name_replace   { ble/keymap:vi/update-mode-indicator; }
function bleopt/check:keymap_vi_mode_name_vreplace  { ble/keymap:vi/update-mode-indicator; }
function bleopt/check:keymap_vi_mode_name_visual    { ble/keymap:vi/update-mode-indicator; }
function bleopt/check:keymap_vi_mode_name_select    { ble/keymap:vi/update-mode-indicator; }
function bleopt/check:keymap_vi_mode_name_linewise  { ble/keymap:vi/update-mode-indicator; }
function bleopt/check:keymap_vi_mode_name_blockwise { ble/keymap:vi/update-mode-indicator; }


## @fn ble/keymap:vi/script/get-vi-keymap
##   Get the current vi keymap name (vi_?map).
##   Fails if it is not currently in the vi keymap.
function ble/keymap:vi/script/get-vi-keymap {
  ble/prompt/unit/add-hash '$_ble_decode_keymap,${_ble_decode_keymap_stack[*]}'
  local i=${#_ble_decode_keymap_stack[@]}

  keymap=$_ble_decode_keymap
  while [[ $keymap != vi_?map && $keymap != emacs ]]; do
    ((i--)) || return 1
    keymap=${_ble_decode_keymap_stack[i]}
  done
  [[ $keymap == vi_?map ]]
}

## @fn ble/keymap:vi/script/get-mode
##   @var[out] mode
function ble/keymap:vi/script/get-mode {
  ble/prompt/unit/add-hash '$_ble_decode_keymap,${_ble_decode_keymap_stack[*]}'
  ble/prompt/unit/add-hash '$_ble_keymap_vi_single_command,$_ble_edit_mark_active'

  mode=

  local keymap; ble/keymap:vi/script/get-vi-keymap

  # /[iR^R]?/
  if [[ $_ble_keymap_vi_single_command || $keymap == vi_imap ]]; then
    local overwrite=
    if [[ $keymap == vi_imap ]]; then
      overwrite=$_ble_edit_overwrite_mode
    elif [[ $keymap == vi_[noxs]map ]]; then
      overwrite=$_ble_keymap_vi_single_command_overwrite
    fi
    case $overwrite in
    ('') mode=i ;;
    (R)  mode=R ;;
    (*)  mode=$'\x12' ;; # C-r
    esac
  fi

  # /[nvV^VsS^S]?/
  case $keymap:${_ble_edit_mark_active%+} in
  (vi_xmap:vi_line) mode=$mode'V' ;;
  (vi_xmap:vi_block)mode=$mode$'\x16' ;; # C-v
  (vi_xmap:*)       mode=$mode'v' ;;
  (vi_smap:vi_line) mode=$mode'S' ;;
  (vi_smap:vi_block)mode=$mode$'\x13' ;; # C-s
  (vi_smap:*)       mode=$mode's' ;;
  (vi_[no]map:*)    mode=$mode'n' ;;
  (vi_cmap:*)       mode=$mode'c' ;;
  (vi_imap:*) ;;
  (*:*)             mode=$mode'?' ;;
  esac
}

_ble_keymap_vi_mode_name_dirty=
function ble/keymap:vi/info_reveal.hook {
  [[ $_ble_keymap_vi_mode_name_dirty ]] || return 0
  _ble_keymap_vi_mode_name_dirty=
  ble/keymap:vi/update-mode-indicator
}
blehook info_reveal!=ble/keymap:vi/info_reveal.hook

bleopt/declare -v prompt_vi_mode_indicator '\q{keymap:vi/mode-indicator}'
function bleopt/check:prompt_vi_mode_indicator {
  local bleopt_prompt_vi_mode_indicator=$value
  [[ $_ble_attached ]] && ble/keymap:vi/update-mode-indicator
  return 0
}

_ble_keymap_vi_mode_indicator_data=()
function ble/prompt/unit:_ble_keymap_vi_mode_indicator/update {
  local trace_opts=truncate:relative:noscrc:ansi
  local prompt_rows=1
  local prompt_cols=${COLUMNS:-80}
  ((prompt_cols&&prompt_cols--))
  local "${_ble_prompt_cache_vars[@]/%/=}" # WA #D1570 checked
  ble/prompt/unit:{section}/update _ble_keymap_vi_mode_indicator "$bleopt_prompt_vi_mode_indicator" "$trace_opts"
}

function ble/keymap:vi/update-mode-indicator {
  if [[ ! $_ble_attached ]] || ble/edit/is-command-layout; then
    _ble_keymap_vi_mode_name_dirty=1
    return 0
  fi

  local keymap
  ble/keymap:vi/script/get-vi-keymap || return 0

  if [[ $keymap == vi_imap ]]; then
    ble/util/buffer "$bleopt_term_vi_imap"
  elif [[ $keymap == vi_nmap ]]; then
    ble/util/buffer "$bleopt_term_vi_nmap"
  elif [[ $keymap == vi_xmap ]]; then
    ble/util/buffer "$bleopt_term_vi_xmap"
  elif [[ $keymap == vi_smap ]]; then
    ble/util/buffer "$bleopt_term_vi_smap"
  elif [[ $keymap == vi_omap ]]; then
    ble/util/buffer "$bleopt_term_vi_omap"
  elif [[ $keymap == vi_cmap ]]; then
    ble/edit/info/default text ''
    ble/util/buffer "$bleopt_term_vi_cmap"
    return 0
  fi

  [[ $bleopt_keymap_vi_mode_update_prompt ]] && ble/prompt/clear

  # prompt_vi_mode_indicator
  local prompt_vi_keymap=$keymap
  local version=$COLUMNS,$_ble_edit_lineno,$_ble_history_count,$_ble_edit_CMD
  local prompt_hashref_base='$version'
  ble/prompt/unit#update _ble_keymap_vi_mode_indicator
  local ret; ble/prompt/unit:{section}/get _ble_keymap_vi_mode_indicator; local mode=$ret

  local str=$mode
  if [[ $_ble_keymap_vi_reg_record ]]; then
    str=$str${str:+' '}$'\e[1;31mREC @'$_ble_keymap_vi_reg_record_char$'\e[m'
  elif [[ $_ble_edit_kbdmacro_record ]]; then
    str=$str${str:+' '}$'\e[1;31mREC\e[m'
  fi

  # Note: If the completion menu is activated, we deactivate the menu before
  # updating the mode indicator in the info panel.
  if [[ $_ble_complete_menu_active ]]; then
    ble/complete/menu/clear
  fi

  # Note #D2062: In mc-4.8.29 or later, the mode such as "-- INSERT --" is displayed immediately after the command ends.
  # If you output an indicator, it will be mistaken for a prompt and extracted. How to do it
  # Since there is no mode indicator for imap in mc, do not display it.
  if [[ $_ble_edit_integration_mc_precmd_stop && $keymap == vi_imap ]]; then
    ble/edit/info/clear
  else
    ble/edit/info/default ansi "$str" # 6ms
  fi
}
blehook internal_PRECMD!=ble/keymap:vi/update-mode-indicator

## @fn ble/prompt/backslash:keymap:vi/mode-indicator
##   @var[in,opt] prompt_vi_keymap
##     ble/keymap:vi/script/get-vi-keymap cache
function ble/prompt/backslash:keymap:vi/mode-indicator {
  [[ $bleopt_keymap_vi_mode_show ]] || return 0

  local keymap=${prompt_vi_keymap-}
  if [[ $keymap ]]; then
    ble/prompt/unit/add-hash '$_ble_decode_keymap,${_ble_decode_keymap_stack[*]}'
  else
    ble/keymap:vi/script/get-vi-keymap || return 0
  fi

  local name= show= overwrite=
  ble/prompt/unit/add-hash '$_ble_edit_overwrite_mode,$_ble_keymap_vi_single_command,$_ble_keymap_vi_single_command_overwrite'
  if [[ $keymap == vi_imap ]]; then
    show=1 overwrite=$_ble_edit_overwrite_mode
  elif [[ $_ble_keymap_vi_single_command && ( $keymap == vi_nmap || $keymap == vi_omap ) ]]; then
    show=1 overwrite=$_ble_keymap_vi_single_command_overwrite
  elif [[ $keymap == vi_[xs]map ]]; then
    show=x overwrite=$_ble_keymap_vi_single_command_overwrite
  else
    name=$bleopt_keymap_vi_mode_string_nmap
  fi

  if [[ $show ]]; then
    if [[ $overwrite == R ]]; then
      name=$bleopt_keymap_vi_mode_name_replace
    elif [[ $overwrite ]]; then
      name=$bleopt_keymap_vi_mode_name_vreplace
    else
      name=$bleopt_keymap_vi_mode_name_insert
    fi

    if [[ $_ble_keymap_vi_single_command ]]; then
      local ret; ble/string#tolower "$name"; name="($ret)"
    fi

    if [[ $show == x ]]; then
      ble/prompt/unit/add-hash '${_ble_edit_mark_active%+}'
      local mark_type=${_ble_edit_mark_active%+}
      local visual_name=$bleopt_keymap_vi_mode_name_visual
      [[ $keymap == vi_smap ]] && visual_name=$bleopt_keymap_vi_mode_name_select
      if [[ $mark_type == vi_line ]]; then
        visual_name=$visual_name' '$bleopt_keymap_vi_mode_name_linewise
      elif [[ $mark_type == vi_block ]]; then
        visual_name=$visual_name' '$bleopt_keymap_vi_mode_name_blockwise
      fi

      if [[ $_ble_keymap_vi_single_command ]]; then
        name="$name $visual_name"
      else
        name=$visual_name
      fi
    fi

    name=$'\e[1m-- '$name$' --\e[m'
  fi

  [[ ! $name ]] || ble/prompt/print "$name"
}

function ble/widget/vi_imap/normal-mode.impl {
  local opts=$1

  # finalize insert mode
  ble/keymap:vi/mark/set-local-mark 94 "$_ble_edit_ind" # `^
  ble/keymap:vi/mark/end-edit-area
  [[ :$opts: == *:InsertLeave:* ]] && builtin eval -- "$_ble_keymap_vi_insert_leave"

  # set up normal mode
  _ble_edit_mark_active=
  _ble_edit_overwrite_mode=
  _ble_keymap_vi_insert_leave=
  _ble_keymap_vi_single_command=
  _ble_keymap_vi_single_command_overwrite=
  if [[ :$opts: == *:SingleCommand:* ]]; then
    ble-edit/content/nonbol-eolp && ((_ble_edit_ind--))
  else
    ble-edit/content/bolp || ((_ble_edit_ind--))
  fi
  ble/decode/keymap/push vi_nmap
}
function ble/widget/vi_imap/normal-mode {
  ble-edit/content/clear-arg
  ble/keymap:vi/imap-repeat/pop
  ble/keymap:vi/imap-repeat/process
  ble/keymap:vi/repeat/record-insert
  ble/widget/vi_imap/normal-mode.impl InsertLeave
  ble/keymap:vi/update-mode-indicator
  return 0
}
function ble/widget/vi_imap/normal-mode-without-insert-leave {
  ble-edit/content/clear-arg
  ble/keymap:vi/imap-repeat/pop
  ble/keymap:vi/repeat/record-insert
  ble/widget/vi_imap/normal-mode.impl
  ble/keymap:vi/update-mode-indicator
  return 0
}
function ble/widget/vi_imap/single-command-mode {
  ble-edit/content/clear-arg
  local single_command=1
  local single_command_overwrite=$_ble_edit_overwrite_mode
  ble-edit/content/eolp && _ble_keymap_vi_single_command=2

  ble/keymap:vi/imap-repeat/pop
  ble/widget/vi_imap/normal-mode.impl SingleCommand
  _ble_keymap_vi_single_command=$single_command
  _ble_keymap_vi_single_command_overwrite=$single_command_overwrite
  ble/keymap:vi/update-mode-indicator
  return 0
}

## @fn ble/keymap:vi/needs-eol-fix
##
##   Note: You need to call ble/keymap:vi/adjust-command-mode after using this function.
##     Otherwise, the cursor will be in an impossible position in normal mode.
##
function ble/keymap:vi/needs-eol-fix {
  [[ $_ble_decode_keymap == vi_nmap || $_ble_decode_keymap == vi_omap ]] || return 1
  [[ $_ble_keymap_vi_single_command ]] && return 1
  local index=${1:-$_ble_edit_ind}
  ble-edit/content/nonbol-eolp "$index"
}
function ble/keymap:vi/adjust-command-mode {
  if [[ $_ble_decode_keymap == vi_[xs]map ]]; then
    # Disable trailing expansion when a move command comes.
    # Movement commands should go through here...
    ble/keymap:vi/xmap/remove-eol-extension
  fi

  local kmap_popped=
  if [[ $_ble_decode_keymap == vi_omap ]]; then
    ble/decode/keymap/pop
    kmap_popped=1
  fi

  # Setting/cancelling mark by search
  if [[ $_ble_keymap_vi_search_activate ]]; then
    if [[ $_ble_decode_keymap != vi_[xs]map ]]; then
      _ble_edit_mark_active=$_ble_keymap_vi_search_activate
    fi
    _ble_keymap_vi_search_matched=1
    _ble_keymap_vi_search_activate=
  else
    [[ $_ble_edit_mark_active == vi_search ]] && _ble_edit_mark_active=
    ((_ble_keymap_vi_search_matched)) && _ble_keymap_vi_search_matched=
  fi

  if [[ $_ble_decode_keymap == vi_nmap && $_ble_keymap_vi_single_command ]]; then
    if ((_ble_keymap_vi_single_command==2)); then
      local index=$((_ble_edit_ind+1))
      ble-edit/content/nonbol-eolp "$index" && _ble_edit_ind=$index
    fi
    ble/widget/vi_nmap/.insert-mode 1 "$_ble_keymap_vi_single_command_overwrite" resume
    ble/keymap:vi/repeat/clear-insert
  elif [[ $kmap_popped ]]; then
    ble/keymap:vi/update-mode-indicator
  fi

  return 0
}
function ble/widget/vi-command/bell {
  ble/widget/.bell "$1"
  ble/keymap:vi/adjust-command-mode
  return 0
}

## @fn ble/widget/vi_nmap/.insert-mode [arg [overwrite [opts]]]
##   @param[in] arg
##   @param[in] overwrite
##   @param[in] opts
function ble/widget/vi_nmap/.insert-mode {
  [[ $_ble_decode_keymap == vi_[xs]map ]] && ble/decode/keymap/pop
  [[ $_ble_decode_keymap == vi_omap ]] && ble/decode/keymap/pop
  local arg=$1 overwrite=$2
  ble/keymap:vi/imap-repeat/reset "$arg"
  _ble_edit_mark_active=
  _ble_edit_overwrite_mode=$overwrite
  _ble_keymap_vi_insert_leave=
  _ble_keymap_vi_insert_overwrite=$overwrite
  _ble_keymap_vi_single_command=
  _ble_keymap_vi_single_command_overwrite=
  ble/keymap:vi/search/clear-matched
  ble/decode/keymap/pop
  ble/keymap:vi/update-mode-indicator

  ble/keymap:vi/mark/start-edit-area
  if [[ :$opts: != *:resume:* ]]; then
    ble/keymap:vi/mark/commit-edit-area "$_ble_edit_ind" "$_ble_edit_ind"
  fi
}
function ble/widget/vi_nmap/insert-mode {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi_nmap/.insert-mode "$ARG"
  ble/keymap:vi/repeat/record
  return 0
}
function ble/widget/vi_nmap/append-mode {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  if ! ble-edit/content/eolp; then
    ((_ble_edit_ind++))
  fi
  ble/widget/vi_nmap/.insert-mode "$ARG"
  ble/keymap:vi/repeat/record
  return 0
}
function ble/widget/vi_nmap/append-mode-at-end-of-line {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  local ret; ble-edit/content/find-logical-eol
  _ble_edit_ind=$ret
  ble/widget/vi_nmap/.insert-mode "$ARG"
  ble/keymap:vi/repeat/record
  return 0
}
function ble/widget/vi_nmap/insert-mode-at-beginning-of-line {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  local ret; ble-edit/content/find-logical-bol
  _ble_edit_ind=$ret
  ble/widget/vi_nmap/.insert-mode "$ARG"
  ble/keymap:vi/repeat/record
  return 0
}
function ble/widget/vi_nmap/insert-mode-at-first-non-space {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/first-non-space
  [[ ${_ble_edit_str:_ble_edit_ind:1} == [$' \t'] ]] &&
    ((_ble_edit_ind++)) # Reverse eol correction
  ble/widget/vi_nmap/.insert-mode "$ARG"
  ble/keymap:vi/repeat/record
  return 0
}
# nmap: gi
function ble/widget/vi_nmap/insert-mode-at-previous-point {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  local ret
  ble/keymap:vi/mark/get-local-mark 94 && _ble_edit_ind=$ret
  ble/widget/vi_nmap/.insert-mode "$ARG"
  ble/keymap:vi/repeat/record
  return 0
}
function ble/widget/vi_nmap/replace-mode {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi_nmap/.insert-mode "$ARG" R
  ble/keymap:vi/repeat/record
  return 0
}
function ble/widget/vi_nmap/virtual-replace-mode {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi_nmap/.insert-mode "$ARG" 1
  ble/keymap:vi/repeat/record
  return 0
}
function ble/widget/vi_nmap/accept-line {
  ble/keymap:vi/clear-arg
  ble/widget/vi_nmap/.insert-mode
  ble/keymap:vi/repeat/clear-insert
  [[ $_ble_keymap_vi_reg_record ]] &&
    ble/widget/vi_nmap/record-register
  ble/widget/default/accept-line
}
function ble/widget/vi-command/edit-and-execute-command {
  ble/keymap:vi/clear-arg
  ble/widget/vi_nmap/.insert-mode
  ble/keymap:vi/repeat/clear-insert
  [[ $_ble_keymap_vi_reg_record ]] &&
    ble/widget/vi_nmap/record-register
  ble/widget/edit-and-execute-command vi
}

#------------------------------------------------------------------------------
# args
#
# arg     : 0-9 d y c
# command : dd yy cc [dyc]0 Y S

_ble_keymap_vi_oparg=
_ble_keymap_vi_opfunc=
_ble_keymap_vi_reg=

ble/array#push _ble_textarea_local_VARNAMES \
               _ble_keymap_vi_oparg \
               _ble_keymap_vi_opfunc \
               _ble_keymap_vi_reg

# How to handle _ble_edit_kill_ring in ble/keymap:vi
#
# When _ble_edit_kill_type=L
#   Indicates that it is a line-oriented cut string,
#   You can assume that there is always a newline character at the end of _ble_edit_kill_ring.
#
# When the format is _ble_edit_kill_type=B:*,
#   Indicates that it is a rectangular cut string,
#   _ble_edit_kill_ring is a concatenation of lines separated by line breaks.
#   No newline character is added at the end. If there is a newline character at the end,
#   That means there is a blank line at the end, not an appended newline.
#
#   The second and subsequent characters of _ble_edit_kill_type are numbers separated by spaces,
#   Each number corresponds to a row in _ble_edit_kill_ring.
#   The meaning is the number of spaces to be filled on the right when inserting in the middle of a line to maintain a rectangular shape.
#   Note that this blank padding does not occur when inserting at the end of a line.
#
# _ble_edit_kill_type= (empty string) or otherwise
#   Indicates that it is a normal cut string.
#   _ble_edit_kill_ring is any string.
#
_ble_keymap_vi_register=()
_ble_keymap_vi_register_onplay=

## @fn ble/keymap:vi/clear-arg
function ble/keymap:vi/clear-arg {
  _ble_edit_arg=
  _ble_keymap_vi_oparg=
  _ble_keymap_vi_opfunc=
  _ble_keymap_vi_reg=
}
## @fn ble/keymap:vi/get-arg [default_value]; ARG FLAG REG
##
## About the contents of the argument
##   For vi_nmap, vi_xmap, and vi_smap, FLAG can be assumed to be empty.
##   FLAG is non-empty in vi_omap.
##   Empty by calling get-arg{,-reg}.
##   In other words, when this function is called in vi_omap, it is necessary to return from vi_omap to vi_nmap.
##   This is typically done with ble/keymap:vi/adjust-command-mode.
##
function ble/keymap:vi/get-arg {
  local default_value=$1
  REG=$_ble_keymap_vi_reg
  FLAG=$_ble_keymap_vi_opfunc
  if [[ ! $_ble_edit_arg && ! $_ble_keymap_vi_oparg ]]; then
    ARG=$default_value
  else
    ARG=$((10#0${_ble_edit_arg:-1}*10#0${_ble_keymap_vi_oparg:-1}))
  fi
  ble/keymap:vi/clear-arg
}
## @fn ble/keymap:vi/register#load reg
function ble/keymap:vi/register#load {
  local reg=$1
  if [[ $reg ]] && ((reg!=34)); then
    if [[ $reg == 37 ]]; then # "%
      ble-edit/content/push-kill-ring "$HISTFILE" ''
      return 0
    fi

    local value=${_ble_keymap_vi_register[reg]}
    if [[ $value == */* ]]; then
      ble-edit/content/push-kill-ring "${value#*/}" "${value%%/*}"
      return 0
    else
      ble-edit/content/push-kill-ring
      return 1
    fi
  fi
}
## @fn ble/keymap:vi/register#set reg type content
function ble/keymap:vi/register#set {
  local reg=$1 type=$2 content=$3

  # type = L is a row-oriented value
  # type = B is a rectangular-oriented value
  # type = '' is a character-oriented value
  # type = q is a keyboard macro
  #
  # Note: The type actually recorded is one of the following.
  #  type = L
  #  type = B:*
  #  type = ''

  # In case of addition
  if [[ $reg == +* ]]; then
    local value=${_ble_keymap_vi_register[reg]}
    if [[ $value == */* ]]; then
      local otype=${value%%/*}
      local oring=${value#*/}

      if [[ $otype == L ]]; then
        if [[ $type == q ]]; then
          type=L content=${oring%$'\n'}$content # V + * → V
        else
          type=L content=$oring$content # V + * → V
        fi
      elif [[ $type == L ]]; then
        type=L content=$oring$'\n'$content # C-v + V, v + V → V
      elif [[ $otype == B:* ]]; then
        if [[ $type == B:* ]]; then
          type=$otype' '${type#B:}
          content=$oring$'\n'$content # C-v + C-v → C-v
        elif [[ $type == q ]]; then
          local ret; ble/string#count-char "$content" $'\n'
          ble/string#repeat ' 0' "$ret"
          type=$otype$ret
          content=$oring$$content # C-v + q → C-v
        else
          local ret; ble/string#count-char "$content" $'\n'
          ble/string#repeat ' 0' "$((ret+1))"
          type=$otype$ret
          content=$oring$'\n'$content # C-v + v → C-v
        fi
      else
        type= content=$oring$content # v + C-v, v + v, v + q → v
      fi
    fi
  fi

  [[ $type == L && $content != *$'\n' ]] && content=$content$'\n'

  local suppress_default=
  [[ $type == q ]] && type= suppress_default=1

  if [[ ! $reg ]] || ((reg==34)); then # ""
    # unnamed register
    ble-edit/content/push-kill-ring "$content" "$type"
    return 0
  elif ((reg==58||reg==46||reg==37||reg==126)); then # ": ". "% "~
    # read only register
    ble/widget/.bell "attempted to write on a read-only register #$reg"
    return 1
  elif ((reg==95)); then # "_
    # black hole register
    return 0
  else
    if [[ ! $suppress_default ]]; then
      ble-edit/content/push-kill-ring "$content" "$type"
    fi
    _ble_keymap_vi_register[reg]=$type/$content
    return 0
  fi
}

## @fn ble/keymap:vi/register#set-yank reg type content
##   Register a string in register "0.
##
function ble/keymap:vi/register#set-yank {
  ble/keymap:vi/register#set "$@" || return 1
  local reg=$1 type=$2 content=$3
  if [[ $reg == '' || $reg == 34 ]]; then
    ble/keymap:vi/register#set 48 "$type" "$content" # "0
  fi
}
## @fn ble/keymap:vi/register#set-edit reg type content
##   Register a string in register "1.
##
##   If content contains a line break or a specific WIDGET,
##   Move the contents originally in registers "1 - "8 to registers "2 - "9,
##   Register a new string in register "1.
##   Otherwise, the new string is registered in register "-.
##
_ble_keymap_vi_register_49_widget_list=(
  # %
  ble/widget/vi-command/search-matchpair-or
  ble/widget/vi-command/percentage-line

  # `
  ble/widget/vi-command/goto-mark

  # / ? n N
  ble/widget/vi-command/search-forward
  ble/widget/vi-command/search-backward
  ble/widget/vi-command/search-repeat
  ble/widget/vi-command/search-reverse-repeat

  # ( ) { }
  # ToDo
)
function ble/keymap:vi/register#set-edit {
  ble/keymap:vi/register#set "$@" || return 1
  local reg=$1 type=$2 content=$3
  if [[ $reg == '' || $reg == 34 ]]; then
    local IFS=$_ble_term_IFS
    local widget=${WIDGET%%["$_ble_term_IFS"]*}
    if [[ $content == *$'\n'* || " $widget " == " ${_ble_keymap_vi_register_49_widget_list[*]} " ]]; then
      local n
      for ((n=9;n>=2;n--)); do
        _ble_keymap_vi_register[48+n]=${_ble_keymap_vi_register[48+n-1]}
      done
      ble/keymap:vi/register#set 49 "$type" "$content" # "1
    else
      ble/keymap:vi/register#set 45 "$type" "$content" # "-
    fi
  fi
}

function ble/keymap:vi/register#play {
  local reg=$1 value
  if [[ $reg ]] && ((reg!=34)); then
    value=${_ble_keymap_vi_register[reg]}
    if [[ $value == */* ]]; then
      value=${value#*/}
    else
      value=
      return 1
    fi
  else
    value=$_ble_edit_kill_ring
  fi

  local _ble_keymap_vi_register_onplay=1
  local ret; ble/decode/charlog#decode "$value"
  ble/widget/.MACRO "${ret[@]}"
  return 0
}
function ble/keymap:vi/register#dump {
  local k ret out=
  local value type content
  for k in 34 "${!_ble_keymap_vi_register[@]}"; do
    if ((k==34)); then
      type=$_ble_edit_kill_type
      content=$_ble_edit_kill_ring
    else
      value=${_ble_keymap_vi_register[k]}
      type=${value%%/*} content=${value#*/}
    fi

    ble/util/c2s "$k"; k=$ret
    case $type in
    (L)   type=line ;;
    (B:*) type=block ;;
    (*)   type=char ;;
    esac

    ble/string#escape-for-display "$content" sgr1="$_ble_term_rev":sgr0="$_ble_term_sgr0"
    out=$out'"'$k' ('$type') '$ret$'\n'
  done
  ble/edit/info/show ansi "$out"
  return 0
}
function ble/widget/vi-command:registers { ble/keymap:vi/register#dump; }

function ble/widget/vi-command/append-arg {
  local ret ch=$1
  if [[ ! $ch ]]; then
    local n=${#KEYS[@]}
    local code=$((KEYS[n?n-1:0]&_ble_decode_MaskChar))
    ((code==0)) && return 1
    ble/util/c2s "$code"; ch=$ret
  fi
  ble/util/assert '[[ ! ${ch//[0-9]} ]]'

  # 0
  if [[ $ch == 0 && ! $_ble_edit_arg ]]; then
    ble/widget/vi-command/beginning-of-line
    return "$?"
  fi

  _ble_edit_arg="$_ble_edit_arg$ch"
  return 0
}
function ble/widget/vi-command/register {
  _ble_decode_key__hook="ble/widget/vi-command/register.hook"
}
function ble/widget/vi-command/register.hook {
  local key=$1
  ble/keymap:vi/clear-arg
  local ret
  if ble/keymap:vi/k2c "$key" && local c=$ret; then
    if ((65<=c&&c<91)); then # A-Z
      _ble_keymap_vi_reg=+$((c+32))
      return 0
    elif ((97<=c&&c<123||48<=c&&c<58||c==45||c==58||c==46||c==37||c==35||c==61||c==42||c==43||c==126||c==95||c==47)); then # a-z 0-9 - : . % # = * + ~ _ /
      _ble_keymap_vi_reg=$c
      return 0
    elif ((c==34)); then # ""
      # Note: Vim internally distinguishes between specifying "" and not specifying anything.
      # For example, diw"y. is recorded in "y", but ""diw"y. is recorded in "".
      _ble_keymap_vi_reg=$c
      return 0
    fi
  fi
  ble/widget/vi-command/bell
  return 1
}

_ble_keymap_vi_reg_record=
_ble_keymap_vi_reg_record_char=
_ble_keymap_vi_reg_record_play=0
ble/array#push _ble_textarea_local_VARNAMES \
               _ble_keymap_vi_reg_record \
               _ble_keymap_vi_reg_record_char \
               _ble_keymap_vi_reg_record_play

# nmap q
function ble/widget/vi_nmap/record-register {
  # q contained in the register does nothing during playback
  if [[ $_ble_keymap_vi_register_onplay ]]; then
    ble/keymap:vi/clear-arg
    ble/keymap:vi/adjust-command-mode
    return 0
  fi

  if [[ $_ble_keymap_vi_reg_record ]]; then
    ble/keymap:vi/clear-arg
    local -a ret
    ble/decode/charlog#end-exclusive-depth1
    ble/decode/charlog#encode "${ret[@]}"
    ble/keymap:vi/register#set "$_ble_keymap_vi_reg_record" q "$ret"

    _ble_keymap_vi_reg_record=
    ble/keymap:vi/update-mode-indicator
  else
    _ble_decode_key__hook="ble/widget/vi_nmap/record-register.hook"
  fi
}
function ble/widget/vi_nmap/record-register.hook {
  local key=$1 ret
  ble/keymap:vi/clear-arg

  # check register
  local reg= c=
  if ble/keymap:vi/k2c "$key" && c=$ret; then
    if ((65<=c&&c<91)); then # q{A-Z}
      reg=+$((c+32))
    elif ((48<=c&&c<58||97<=c&&c<123)); then # q{0-9a-z}
      reg=$c
    elif ((c==34)); then # q"
      reg=$c
    fi
  fi
  if [[ ! $reg ]]; then
    ble/widget/vi-command/bell "invalid register key=$key"
    return 1
  fi

  # start logging
  if ! ble/decode/charlog#start vi-macro; then
    ble/widget/.bell 'vi-macro: the logging system is currently busy'
    return 1
  fi

  # update status
  ble/util/c2s "$c"
  _ble_keymap_vi_reg_record=$reg
  _ble_keymap_vi_reg_record_char=$ret
  ble/keymap:vi/update-mode-indicator
  return 0
}
# nmap @
function ble/widget/vi_nmap/play-register {
  _ble_decode_key__hook="ble/widget/vi_nmap/play-register.hook"
}
function ble/widget/vi_nmap/play-register.hook {
  ble/keymap:vi/clear-arg

  local depth=$_ble_keymap_vi_reg_record_play
  if ((depth>=bleopt_keymap_vi_macro_depth)) || ble/util/is-stdin-ready; then
    return 1 # To prevent infinite loops
  fi

  local _ble_keymap_vi_reg_record_play=$((depth+1))
  local key=$1
  local ret
  if ble/keymap:vi/k2c "$key" && local c=$ret; then
    ((65<=c&&c<91)) && ((c+=32)) # A-Z -> a-z
    if ((48<=c&&c<58||97<=c&&c<123)); then # 0-9a-z
      ble/keymap:vi/register#play "$c" && return 0
    fi
  fi
  ble/widget/vi-command/bell
  return 1
}

function ble/widget/vi-command/operator {
  local ret opname=$1

  if [[ $_ble_decode_keymap == vi_[xs]map ]]; then
    local ARG FLAG REG; ble/keymap:vi/get-arg ''
    # *FLAG may be set by the user, but it will be ignored.

    local a=$_ble_edit_ind b=$_ble_edit_mark
    ((a<=b||(a=_ble_edit_mark,b=_ble_edit_ind)))

    ble/widget/vi_xmap/.save-visual-state
    local ble_keymap_vi_mark_active=$_ble_edit_mark_active # used in call-operator-blockwise
    local mark_type=${_ble_edit_mark_active%+}
    ble/widget/vi_xmap/exit

    local ble_keymap_vi_opmode=$mark_type
    if [[ $mark_type == vi_line ]]; then
      ble/keymap:vi/call-operator-linewise "$opname" "$a" "$b" "$ARG" "$REG"
    elif [[ $mark_type == vi_block ]]; then
      ble/keymap:vi/call-operator-blockwise "$opname" "$a" "$b" "$ARG" "$REG"
    else
      local end=$b
      ((end<${#_ble_edit_str}&&end++))
      ble/keymap:vi/call-operator-charwise "$opname" "$a" "$end" "$ARG" "$REG"
    fi; local ext=$?
    ((ext==147)) && return 147
    ((ext)) && ble/widget/.bell
    ble/keymap:vi/adjust-command-mode
    return "$ext"
  elif [[ $_ble_decode_keymap == vi_nmap ]]; then
    ble/decode/keymap/push vi_omap
    _ble_keymap_vi_oparg=$_ble_edit_arg
    _ble_keymap_vi_opfunc=$opname
    _ble_edit_arg=
    ble/keymap:vi/update-mode-indicator

  elif [[ $_ble_decode_keymap == vi_omap ]]; then
    local opname1=${_ble_keymap_vi_opfunc%%:*}
    if [[ $opname == "$opname1" ]]; then
      # Two same operators (yy, dd, cc, etc.) = row-oriented processing
      ble/widget/vi_nmap/linewise-operator "$_ble_keymap_vi_opfunc"
    else
      ble/keymap:vi/clear-arg
      ble/widget/vi-command/bell
      return 1
    fi
  fi
  return 0
}

function ble/widget/vi_nmap/linewise-operator {
  local opname=${1%%:*} opflags=${1#*:}
  local ARG FLAG REG; ble/keymap:vi/get-arg 1 # _ble_edit_arg is consumed here
  if ((ARG==1)) || [[ ${_ble_edit_str:_ble_edit_ind} == *$'\n'* ]]; then
    if [[ :$opflags: == *:vi_char:* || :$opflags: == *:vi_block:* ]]; then
      local beg=$_ble_edit_ind
      local ret; ble-edit/content/find-logical-bol "$beg" "$((ARG-1))"; local end=$ret
      ((beg<=end)) || local beg=$end end=$beg
      if [[ :$opflags: == *:vi_block:* ]]; then
        ble/keymap:vi/call-operator-blockwise "$opname" "$beg" "$end" '' "$REG"
      else
        ble/keymap:vi/call-operator-charwise "$opname" "$beg" "$end" '' "$REG"
      fi
    else
      ble/keymap:vi/call-operator-linewise "$opname" "$_ble_edit_ind" "$_ble_edit_ind:$((ARG-1))" '' "$REG"; local ext=$?
    fi
    if ((ext==0)); then
      ble/keymap:vi/adjust-command-mode
      return 0
    elif ((ext==147)); then
      return 147
    fi
  fi
  ble/widget/vi-command/bell
  return 1
}
# nmap Y
function ble/widget/vi_nmap/copy-current-line {
  ble/widget/vi_nmap/linewise-operator y
}
function ble/widget/vi_nmap/kill-current-line {
  ble/widget/vi_nmap/linewise-operator d
}
# nmap S
function ble/widget/vi_nmap/kill-current-line-and-insert {
  ble/widget/vi_nmap/linewise-operator c
}

# nmap: 0, <home>
function ble/widget/vi-command/beginning-of-line {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  local ret; ble-edit/content/find-logical-bol; local beg=$ret
  ble/widget/vi-command/exclusive-goto.impl "$beg" "$FLAG" "$REG" nobell
}

#------------------------------------------------------------------------------
# Operators

## Operators are defined as functions of the form:
##
## @fn ble/keymap:vi/operator:name a b context [count [reg]]
##
##   @param[in] a b
##     The start and end points of the range. The ending point is guaranteed to be after the starting point.
##     When context is 'line', it is guaranteed to be at the beginning and end of the line, respectively.
##     However, if there is a newline at the end of a line, b points to the beginning of the next line.
##
##   @param[in] context
##     A string representing the range type. Either char, line, or block.
##
##   @param[in] count
##     Arguments for operator operations.
##     This is specified in visual mode.
##
##   @var[in,out] beg end
##     The start and end points of the range. a The same value as b.
##     The range may be expanded for row-oriented operators.
##     At that time, the starting point after expansion is returned to beg.
##
##   @var[out] ble_keymap_vi_operator_index
##     When specifying the cursor position after an operator action,
##     Set a value to this variable inside the operator.
##
##   @exit
##     When the operator function returns an exit status of 147,
##     Represents that operator reads input asynchronously.
##     The operator that returned 147 when the operation actually completed:
##
##     1 Must call ble/keymap:vi/mark/end-edit-area.
##     2 You need to move the cursor to the appropriate position.
##
##
## The operator is currently called in four places:
##
## - ble/widget/vi-command/linewise-range.impl
## - ble/keymap:vi/call-operator
## - ble/keymap:vi/call-operator-charwise
## - ble/keymap:vi/call-operator-linewise
## - ble/keymap:vi/call-operator-blockwise


## @fn ble/keymap:vi/call-operator op beg end type arg reg
## @fn ble/keymap:vi/call-operator-charwise op beg end arg reg
## @fn ble/keymap:vi/call-operator-linewise op beg end arg reg
## @fn ble/keymap:vi/call-operator-blockwise op beg end arg reg
##
##   @var[in] ble_keymap_vi_mark_active
##     Specify $_ble_edit_mark_active before operator action.
##     Used to determine the rectangular area in call-operator-blockwise.
##     $_ble_edit_mark_active is already set when the operator is called.
##     Note that the value has changed after the action.
##
function ble/keymap:vi/call-operator {
  ble/keymap:vi/mark/start-edit-area
  local _ble_keymap_vi_mark_suppress_edit=1
  ble/keymap:vi/operator:"$@"; local ext=$?
  ble/util/unlocal _ble_keymap_vi_mark_suppress_edit
  ble/keymap:vi/mark/end-edit-area
  if ((ext==0)); then
    if ble/is-function ble/keymap:vi/operator:"$1".record; then
      ble/keymap:vi/operator:"$1".record
    else
      ble/keymap:vi/repeat/record
    fi
  fi
  return "$ext"
}
function ble/keymap:vi/call-operator-charwise {
  local ch=$1 beg=$2 end=$3 arg=$4 reg=$5
  ((beg<=end||(beg=$3,end=$2)))
  if ble/is-function ble/keymap:vi/operator:"$ch"; then
    local ble_keymap_vi_operator_index=
    ble/keymap:vi/call-operator "$ch" "$beg" "$end" char "$arg" "$reg"; local ext=$?
    ((ext==147)) && return 147

    local index=${ble_keymap_vi_operator_index:-$beg}
    ble/keymap:vi/needs-eol-fix "$index" && ((index--))
    _ble_edit_ind=$index
    return 0
  else
    return 1
  fi
}
function ble/keymap:vi/call-operator-linewise {
  local ch=$1 a=$2 b=$3 arg=$4 reg=$5 ia=0 ib=0
  [[ $a == *:* ]] && local a=${a%%:*} ia=${a#*:}
  [[ $b == *:* ]] && local b=${b%%:*} ib=${b#*:}
  local ret
  ble-edit/content/find-logical-bol "$a" "$ia"; local beg=$ret
  ble-edit/content/find-logical-eol "$b" "$ib"; local end=$ret

  if ble/is-function ble/keymap:vi/operator:"$ch"; then
    local ble_keymap_vi_operator_index=
    ((end<${#_ble_edit_str}&&end++))
    ble/keymap:vi/call-operator "$ch" "$beg" "$end" line "$arg" "$reg"; local ext=$?
    ((ext==147)) && return 147

    # index
    if [[ $ble_keymap_vi_operator_index ]]; then
      local index=$ble_keymap_vi_operator_index
    else
      ble-edit/content/find-logical-bol "$beg"; beg=$ret # beg may have been changed in operator
      ble-edit/content/find-non-space "$beg"; local index=$ret
    fi
    ble/keymap:vi/needs-eol-fix "$index" && ((index--))
    _ble_edit_ind=$index
    return 0
  else
    return 1
  fi
}
function ble/keymap:vi/call-operator-blockwise {
  local ch=$1 beg=$2 end=$3 arg=$4 reg=$5
  if ble/is-function ble/keymap:vi/operator:"$ch"; then
    local mark_active=${ble_keymap_vi_mark_active:-vi_block}
    local sub_ranges sub_x1 sub_x2
    _ble_edit_mark_active=$mark_active ble/keymap:vi/extract-block "$beg" "$end"
    local nrange=${#sub_ranges[@]}
    ((nrange)) || return 1

    local ble_keymap_vi_operator_index=
    local beg=${sub_ranges[0]}; beg=${beg%%:*}
    local end=${sub_ranges[nrange-1]}; end=${end#*:}; end=${end%%:*}
    ble/keymap:vi/call-operator "$ch" "$beg" "$end" block "$arg" "$reg"
    ((ext==147)) && return 147

    local index=${ble_keymap_vi_operator_index:-$beg}
    ble/keymap:vi/needs-eol-fix "$index" && ((index--))
    _ble_edit_ind=$index
    return 0
  else
    return 1
  fi
}


function ble/keymap:vi/operator:d {
  local context=$3 arg=$4 reg=$5 # beg end overwrites
  if [[ $context == line ]]; then
    ble/keymap:vi/register#set-edit "$reg" L "${_ble_edit_str:beg:end-beg}" || return 1

    # When the last line is deleted, backtrack to the non-blank beginning of the previous line
    if ((end==${#_ble_edit_str}&&beg>0)); then
      # fix start position
      local ret
      ((beg--))
      ble-edit/content/find-logical-bol "$beg"
      ble-edit/content/find-non-space "$ret"
      ble_keymap_vi_operator_index=$ret
    fi

    ble/widget/.delete-range "$beg" "$end"
  elif [[ $context == block ]]; then
    local -a afill=() atext=() arep=()
    local sub shift=0 slpad0=
    local smin smax slpad srpad sfill stext
    for sub in "${sub_ranges[@]}"; do
      stext=${sub#*:*:*:*:*:}
      ble/string#split sub : "$sub"
      smin=${sub[0]} smax=${sub[1]}
      slpad=${sub[2]} srpad=${sub[3]}
      sfill=${sub[4]}

      [[ $slpad0 ]] || slpad0=$slpad # first slpad

      ble/array#push afill "$sfill"
      ble/array#push atext "$stext"
      local ret; ble/string#repeat ' ' "$((slpad+srpad))"
      ble/array#push arep "$((smin+shift)):$((smax+shift)):$ret"
      ((shift+=(slpad+srpad)-(smax-smin)))
    done

    # yank
    IFS=$'\n' builtin eval 'local yank_content="${atext[*]-}"'
    local IFS=$_ble_term_IFS
    local yank_type=B:"${afill[*]-}"
    ble/keymap:vi/register#set-edit "$reg" "$yank_type" "$yank_content" || return 1

    # delete
    local rep
    for rep in "${arep[@]}"; do
      smin=${rep%%:*}; rep=${rep:${#smin}+1}
      smax=${rep%%:*}; rep=${rep:${#smax}+1}
      ble/widget/.replace-range "$smin" "$smax" "$rep"
    done
    ((beg+=slpad)) # fix start position
  else
    if ((beg<end)); then

      if [[ $ble_keymap_vi_opmode != vi_char && ${_ble_edit_str:beg:end-beg} == *$'\n'* ]]; then
        # Exceptional behavior of d: On lines where the start and end points are different character by character,
        #   When there is only blank space before the start point or after the end point, process in a line-oriented manner.
        if local rex=$'(^|\n)([ \t]*)$'; [[ ${_ble_edit_str::beg} =~ $rex ]]; then
          local prefix=${BASH_REMATCH[2]}
          if rex=$'^[ \t]*(\n|$)'; [[ ${_ble_edit_str:end} =~ $rex ]]; then
            local suffix=$BASH_REMATCH
            ((beg-=${#prefix},end+=${#suffix}))
            ble/keymap:vi/operator:d "$beg" "$end" line "$arg" "$reg"
            return "$?"
          fi
        fi
      fi

      ble/keymap:vi/register#set-edit "$reg" '' "${_ble_edit_str:beg:end-beg}" || return 1
      ble/widget/.delete-range "$beg" "$end"
    fi
  fi
  return 0
}
function ble/keymap:vi/operator:c {
  local context=$3 arg=$4 reg=$5 # beg is to be overwritten
  if [[ $context == line ]]; then
    ble/keymap:vi/register#set-edit "$reg" L "${_ble_edit_str:beg:end-beg}" || return 1

    local end2=$end
    ((end2)) && [[ ${_ble_edit_str:end2-1:1} == $'\n' ]] && ((end2--))

    local indent= ret
    ble-edit/content/find-non-space "$beg"; local nol=$ret
    ((beg<nol)) && indent=${_ble_edit_str:beg:nol-beg}

    ble/widget/.replace-range "$beg" "$end2" "$indent"
    ble/widget/vi_nmap/.insert-mode
  elif [[ $context == block ]]; then
    ble/keymap:vi/operator:d "$@" || return 1 # @var beg will be overwritten here

    # Correct the rectangular area shifted by operator:d.
    # Since it is troublesome to recalculate from scratch, we will manipulate sub_ranges directly.
    # Actually block-insert-mode insert is smin of sub_ranges[0] and sub_x1
    # Since only sub_ranges[0] is referenced, you only need to modify sub_ranges[0].
    local sub=${sub_ranges[0]}
    local smin=${sub%%:*} sub=${sub#*:}
    local smax=${sub%%:*} sub=${sub#*:}
    local slpad=${sub%%:*} sub=${sub#*:}
    ((smin+=slpad,smax=smin,slpad=0))
    sub_ranges[0]=$smin:$smax:$slpad:$sub

    ble/widget/vi_xmap/block-insert-mode.impl insert
  else
    local ble_keymap_vi_opmode=vi_char
    ble/keymap:vi/operator:d "$@" || return 1
    ble/widget/vi_nmap/.insert-mode
  fi
  return 0
}
function ble/keymap:vi/operator:y.record { return 0; }
function ble/keymap:vi/operator:y {
  local beg=$1 end=$2 context=$3 arg=$4 reg=$5
  local yank_type= yank_content=
  if [[ $context == line ]]; then
    ble_keymap_vi_operator_index=$_ble_edit_ind # operator:y does not move the current position
    yank_type=L
    yank_content=${_ble_edit_str:beg:end-beg}
  elif [[ $context == block ]]; then
    local sub
    local -a afill=() atext=()
    for sub in "${sub_ranges[@]}"; do
      local sub4=${sub#*:*:*:*:}
      local sfill=${sub4%%:*} stext=${sub4#*:}
      ble/array#push afill "$sfill"
      ble/array#push atext "$stext"
    done

    IFS=$'\n' builtin eval 'local yank_content="${atext[*]-}"'
    local IFS=$_ble_term_IFS
    yank_type=B:"${afill[*]-}"
  else
    yank_type=
    yank_content=${_ble_edit_str:beg:end-beg}
  fi

  ble/keymap:vi/register#set-yank "$reg" "$yank_type" "$yank_content" || return 1
  ble/keymap:vi/mark/commit-edit-area "$beg" "$end"
  return 0
}
function ble/keymap:vi/operator:tr.impl {
  local beg=$1 end=$2 context=$3 filter=$4
  if [[ $context == block ]]; then
    local isub=${#sub_ranges[@]}
    while ((isub--)); do
      ble/string#split sub : "${sub_ranges[isub]}"
      local smin=${sub[0]} smax=${sub[1]}
      local ret; "$filter" "${_ble_edit_str:smin:smax-smin}"
      ble/widget/.replace-range "$smin" "$smax" "$ret"
    done
  else
    local ret; "$filter" "${_ble_edit_str:beg:end-beg}"
    ble/widget/.replace-range "$beg" "$end" "$ret"
  fi
  return 0
}
function ble/keymap:vi/operator:u {
  ble/keymap:vi/operator:tr.impl "$1" "$2" "$3" ble/string#tolower
}
function ble/keymap:vi/operator:U {
  ble/keymap:vi/operator:tr.impl "$1" "$2" "$3" ble/string#toupper
}
function ble/keymap:vi/operator:toggle_case {
  ble/keymap:vi/operator:tr.impl "$1" "$2" "$3" ble/string#toggle-case
}
function ble/keymap:vi/operator:rot13 {
  ble/keymap:vi/operator:tr.impl "$1" "$2" "$3" ble/keymap:vi/string#encode-rot13
}

## @fn ble/keymap:vi/expand-range-for-linewise-operator
##   @var[in,out] beg, end
function ble/keymap:vi/expand-range-for-linewise-operator {
  local ret

  # Heading correction:
  ble-edit/content/find-logical-bol "$beg"; beg=$ret

  # End of line correction:
  #   When advancing a line, if there is an end before the beginning of a non-blank line, that line is ignored.
  #   When backtracking a line, if end (_ble_edit_ind) is at the beginning of the line, that line is ignored.
  #   If the movement is within the same line, that line is included unconditionally.
  ble-edit/content/find-logical-bol "$end"; local bol2=$ret
  ble-edit/content/find-non-space "$bol2"; local nol2=$ret
  if ((beg<bol2&&_ble_edit_ind<=bol2&&end<=nol2)); then
    end=$bol2
  else
    ble-edit/content/find-logical-eol "$end"; end=$ret
    [[ ${_ble_edit_str:end:1} == $'\n' ]] && ((end++))
  fi
}

#--------------------------------------
# Indent operators < >

## @fn ble/keymap:vi/string#increase-indent
##   @var[out] ret
function ble/keymap:vi/string#increase-indent {
  local text=$1 delta=$2
  local space=$' \t' it=${bleopt_tab_width:-$_ble_term_it}
  local arr; ble/string#split-lines arr "$text"
  local -a arr2=()
  local line indent i len x r
  for line in "${arr[@]}"; do
    indent=${line%%[!$space]*}
    line=${line:${#indent}}

    ((x=0))
    if [[ $indent ]]; then
      ((len=${#indent}))
      for ((i=0;i<len;i++)); do
        if [[ ${indent:i:1} == ' ' ]]; then
          ((x++))
        else
          ((x=(x+it)/it*it))
        fi
      done
    fi

    ((x+=delta,x<0&&(x=0)))

    indent=
    if ((x)); then
      if ((bleopt_indent_tabs&&(r=x/it))); then
        ble/string#repeat $'\t' "$r"
        indent=$ret
        ((x%=it))
      fi
      if ((x)); then
        ble/string#repeat ' ' "$x"
        indent=$indent$ret
      fi
    fi

    ble/array#push arr2 "$indent$line"
  done

  IFS=$'\n' builtin eval 'ret="${arr2[*]-}"'
}
## @fn ble/keymap:vi/operator:indent.impl/increase-block-indent width
##   @param[in] width
##   @var[in] sub_ranges
function ble/keymap:vi/operator:indent.impl/increase-block-indent {
  local width=$1
  local isub=${#sub_ranges[@]}
  local sub smin slpad ret
  while ((isub--)); do
    ble/string#split sub : "${sub_ranges[isub]}"
    smin=${sub[0]} slpad=${sub[2]}
    ble/string#repeat ' ' "$((slpad+width))"
    ble/widget/.replace-range "$smin" "$smin" "$ret"
  done
}
## @fn ble/keymap:vi/operator:indent.impl/decrease-graphical-block-indent width
##   @param[in] width
##   @var[in] sub_ranges
function ble/keymap:vi/operator:indent.impl/decrease-graphical-block-indent {
  local width=$1
  local it=${bleopt_tab_width:-$_ble_term_it} cols=$_ble_textmap_cols
  local sub smin slpad ret
  local -a replaces=()
  local isub=${#sub_ranges[@]}
  while ((isub--)); do
    ble/string#split sub : "${sub_ranges[isub]}"
    smin=${sub[0]} slpad=${sub[2]}
    ble-edit/content/find-non-space "$smin"; local nsp=$ret
    ((smin<nsp)) || continue

    local ax ay bx by
    ble/textmap#getxy.out --prefix=a "$smin"
    ble/textmap#getxy.out --prefix=b "$nsp"
    local w=$(((bx-ax)-(by-ay)*cols-width))
    ((w<slpad)) && w=$slpad

    local ins=
    if ((w)); then
      local r
      if ((bleopt_indent_tabs&&(r=(ax+w)/it-ax/it))); then
        ble/string#repeat $'\t' "$r"; ins=$ret
        ((w=(ax+w)%it))
      fi
      if ((w)); then
        ble/string#repeat ' ' "$w"
        ins=$ins$ret
      fi
    fi

    ble/array#push replaces "$smin:$nsp:$ins"
  done

  local rep
  for rep in "${replaces[@]}"; do
    ble/string#split rep : "$rep"
    ble/widget/.replace-range "${rep[@]::3}"
  done
}
## @fn ble/keymap:vi/operator:indent.impl/decrease-logical-block-indent width
##   @param[in] width
##   @var[in] sub_ranges
function ble/keymap:vi/operator:indent.impl/decrease-logical-block-indent {
  # The tab is assumed to have a fixed width it and is deleted.
  local width=$1
  local it=${bleopt_tab_width:-$_ble_term_it}
  local sub smin ret nsp
  local isub=${#sub_ranges[@]}
  while ((isub--)); do
    ble/string#split sub : "${sub_ranges[isub]}"
    smin=${sub[0]}
    ble-edit/content/find-non-space "$smin"; nsp=$ret
    ((smin<nsp)) || continue

    local stext=${_ble_edit_str:smin:nsp-smin}
    local i=0 n=${#stext} c=0 pad=0
    for ((i=0;i<n;i++)); do
      if [[ ${stext:i:1} == $'\t' ]]; then
        ((c+=it))
      else
        ((c++))
      fi
      if ((c>=width)); then
        pad=$((c-width))
        nsp=$((smin+i+1))
        break
      fi
    done

    local padding=
    ((pad)) && { ble/string#repeat ' ' "$pad"; padding=$ret; }
    ble/widget/.replace-range "$smin" "$nsp" "$padding"
  done
}
function ble/keymap:vi/operator:indent.impl {
  local delta=$1 context=$2
  ((delta)) || return 0
  if [[ $context == block ]]; then
    if ((delta>=0)); then
      ble/keymap:vi/operator:indent.impl/increase-block-indent "$delta"
    elif ble/edit/use-textmap; then
      ble/keymap:vi/operator:indent.impl/decrease-graphical-block-indent "$((-delta))"
    else
      ble/keymap:vi/operator:indent.impl/decrease-logical-block-indent "$((-delta))"
    fi
  else
    [[ $context == char ]] && ble/keymap:vi/expand-range-for-linewise-operator
    ((beg<end)) && [[ ${_ble_edit_str:end-1:1} == $'\n' ]] && ((end--))

    local ret
    ble/keymap:vi/string#increase-indent "${_ble_edit_str:beg:end-beg}" "$delta"; local content=$ret
    ble/widget/.replace-range "$beg" "$end" "$content"

    if [[ $context == char ]]; then
      ble-edit/content/find-non-space "$beg"
      ble_keymap_vi_operator_index=$ret
    fi
  fi
  return 0
}
function ble/keymap:vi/operator:indent-left {
  local context=$3 arg=${4:-1}
  ble/keymap:vi/operator:indent.impl "$((-bleopt_indent_offset*arg))" "$context"
}
function ble/keymap:vi/operator:indent-right {
  local context=$3 arg=${4:-1}
  ble/keymap:vi/operator:indent.impl "$((bleopt_indent_offset*arg))" "$context"
}

#--------------------------------------
# Fold operators gq gw

## @fn ble/keymap:vi/string#measure-width text
##   Measures the displayed width of the specified string.
##
##   @param[in] text
##   @var[out] ret
##
##   No wrap-around processing will be performed.
##   No special processing such as tabs or line breaks is performed.
##   The C0 character is treated as two characters.
##   The C1 character is treated as 4 characters.
function ble/keymap:vi/string#measure-width {
  local text=$1 iN=${#1} i=0 s=0
  while ((i<iN)); do
    if ble/util/isprint+ "${text:i}"; then
      ((s+=${#BASH_REMATCH},
        i+=${#BASH_REMATCH}))
    else
      ble/util/s2c "${text:i:1}"
      ble/util/c2w-edit "$ret"
      ((s+=ret,i++))
    fi
  done
  ret=$s
}
## @fn ble/keymap:vi/string#fold/.get-interval text x
##   Calculates the visual width of the spaces between words.
##
##   @param[in] text
##     Specifies a string consisting of spaces and tabs.
##   @param[in] x
##     Specifies the initial position on the screen.
##   @var[out] ret
##
function ble/keymap:vi/string#fold/.get-interval {
  local text=$1 x=$2
  local it=${bleopt_tab_width:-$_ble_term_it}

  local i=0 iN=${#text}
  for ((i=0;i<iN;i++)); do
    if [[ ${text:i:1} == $'\t' ]]; then
      ((x=(x/it+1)*it))
    else
      ((x++))
    fi
  done
  ret=$((x-$2))
}
## @fn ble/keymap:vi/string#fold text [cols]
##   @param[in]     text
##   @param[in,opt] cols [default ${COLUMNS:-80}]
##     Specify the wrapping width.
##     The displayed characters are wrapped so that they fit within cols-1 columns.
##     However, wrapping does not occur in the middle of long words.
##   @var[out] ret
function ble/keymap:vi/string#fold {
  local text=$1
  local cols=${2:-${COLUMNS-80}}
  local sp=$' \t' nl=$'\n'

  # About the intermediate status
  #   @var i The currently processed position in text
  #   @var out Result string determined so far
  #   @var otmp Pending interword space. It is only confirmed when the next word comes.
  #   Display horizontal position after processing @var x $out
  #   @var xtmp Display horizontal position after processing $out$otmp
  #   @var isfirst Whether it is the first regular expression match
  #   @var indent Indent (whitespace inserted immediately after line break)
  #   @var xindent Display horizontal position immediately after inserting indentation
  local i=0 out= otmp= x=0 xtmp=0
  local isfirst=1 indent= xindent=0

  local rex='^([^'$nl$sp']+)|^(['$sp']+)|^.'
  while [[ ${text:i} =~ $rex ]]; do
    ((i+=${#BASH_REMATCH}))
    if [[ ${BASH_REMATCH[1]} ]]; then
      # word
      local word=${BASH_REMATCH[1]}
      ble/keymap:vi/string#measure-width "$word"
      if ((xtmp+ret<cols||xtmp<=xindent)); then
        out=$out$otmp$word
        ((x=xtmp+=ret))
      else
        out=$out$'\n'$indent$word
        ((x=xtmp=xindent+ret))
      fi
      otmp=
    else
      local w=1
      if [[ ${BASH_REMATCH[2]} ]]; then
        [[ $otmp ]] && continue # Ignore spaces immediately after a line break
        # space between words
        otmp=${BASH_REMATCH[2]}
        ble/keymap:vi/string#fold/.get-interval "$otmp" "$x"; w=$ret
        [[ $isfirst ]] && indent=$otmp xindent=$ret # Indent record
      else
        # Line breaks are replaced with spaces. Erase existing blank otmp.
        otmp=' ' w=1
      fi

      if ((x+w<cols)); then
        ((xtmp=x+w))
      else
        ((xtmp=xindent))
        otmp=$'\n'$indent
      fi
    fi
    isfirst=
  done
  ret=$out
}
## @fn ble/keymap:vi/operator:fold/.fold-paragraphwise text [cols]
##   @var[out] ret
function ble/keymap:vi/operator:fold/.fold-paragraphwise {
  local text=$1
  local cols=${2:-${COLUMNS:-80}}

  local nl=$'\n' sp=$' \t'
  local rex_paragraph='^((['$sp']*'$nl')*)(['$sp']*[^'$sp$nl'][^'$nl']*('$nl'|$))+'

  local i=0 out=
  while [[ ${text:i} =~ $rex_paragraph ]]; do
    ((i+=${#BASH_REMATCH}))
    local rematch1=${BASH_REMATCH[1]}
    local len1=${#rematch1}
    local paragraph=${BASH_REMATCH:len1}

    # fold (Actually, you can implement various paragraphwise processes by changing just this part)
    ble/keymap:vi/string#fold "$paragraph" "$cols"
    paragraph=${ret%$'\n'}$'\n'

    out=$out$rematch1$paragraph
  done
  ret=$out${text:i}
}

function ble/keymap:vi/operator:fold.impl {
  local context=$1 opts=$2
  local ret

  [[ $context != line ]] && ble/keymap:vi/expand-range-for-linewise-operator
  local old=${_ble_edit_str:beg:end-beg} oind=$_ble_edit_ind

  local cols=${COLUMNS:-80}; ((cols>80&&(cols=80)))
  ble/keymap:vi/operator:fold/.fold-paragraphwise "$old" "$cols"; local new=$ret
  ble/widget/.replace-range "$beg" "$end" "$new"

  # Corrected cursor position after conversion.
  if [[ :$opts: == *:preserve_point:* ]]; then
    # gw: Move to the character that the cursor was originally on.
    if ((end<=oind)); then
      ble_keymap_vi_operator_index=$((beg+${#new}))
    elif ((beg<oind)); then
      ble/keymap:vi/operator:fold/.fold-paragraphwise "${old::oind-beg}" "$cols"
      ble_keymap_vi_operator_index=$((beg+${#ret}))
    fi
  else
    # gq: Move to the nonblank beginning (gq) of the last line.
    if [[ $new ]]; then
      ble-edit/content/find-logical-bol "$((beg+${#new}-1))"
      ble-edit/content/find-non-space "$ret"
      ble_keymap_vi_operator_index=$ret
    fi
  fi
  return 0
}
function ble/keymap:vi/operator:fold {
  local context=$3
  ble/keymap:vi/operator:fold.impl "$context"
}
function ble/keymap:vi/operator:fold-preserve-point {
  local context=$3
  ble/keymap:vi/operator:fold.impl "$context" preserve_point
}

#--------------------------------------
# Filter operator: !

_ble_keymap_vi_filter_args=()
_ble_keymap_vi_filter_repeat=()

_ble_keymap_vi_filter_history=()
_ble_keymap_vi_filter_history_edit=()
_ble_keymap_vi_filter_history_dirt=()
_ble_keymap_vi_filter_history_index=0

function ble/highlight/layer:region/mark:vi_filter/get-face {
  face=region_target
}
function ble/keymap:vi/operator:filter/.cache-repeat {
  local -a _ble_keymap_vi_repeat _ble_keymap_vi_repeat_irepeat
  ble/keymap:vi/repeat/record-normal
  _ble_keymap_vi_filter_repeat=("${_ble_keymap_vi_repeat[@]}")
}
function ble/keymap:vi/operator:filter/.record-repeat {
  ble/keymap:vi/repeat/record-special && return 0
  local command=$1
  _ble_keymap_vi_repeat=("${_ble_keymap_vi_filter_repeat[@]}")
  _ble_keymap_vi_repeat_irepeat=()
  _ble_keymap_vi_repeat[10]=$command
}
function ble/keymap:vi/operator:filter {
  local context=$3
  [[ $context != line ]] && ble/keymap:vi/expand-range-for-linewise-operator
  _ble_keymap_vi_filter_args=("$beg" "$end" "${@:3}")

  if [[ $_ble_keymap_vi_repeat_invoke ]]; then
    # When repetition is requested by nmap .
    local command=${_ble_keymap_vi_repeat[10]}
    ble/keymap:vi/operator:filter/.hook "$command"
    return "$?"
  else
    # During normal call
    ble/keymap:vi/operator:filter/.cache-repeat
    _ble_edit_ind=$beg
    _ble_edit_mark=$end
    _ble_edit_mark_active=vi_filter
    ble/keymap:vi/async-commandline-mode 'ble/keymap:vi/operator:filter/.hook'
    _ble_edit_PS1='!'
    ble/history/set-prefix _ble_keymap_vi_filter
    _ble_keymap_vi_cmap_before_widget=ble/keymap:vi/commandline/empty-cancel.hook
    _ble_keymap_vi_cmap_cancel_hook=ble/keymap:vi/operator:filter/cancel.hook
    _ble_syntax_lang=bash
    _ble_highlight_layer_list=(plain syntax region overwrite_mode)
    return 147
  fi
}
function ble/keymap:vi/operator:filter/cancel.hook {
  _ble_edit_mark_active= # clear mark:vi_filter
}
function ble/keymap:vi/operator:filter/.hook {
  local command=$1 # Command entered
  if [[ ! $command ]]; then
    ble/widget/vi-command/bell
    return 1
  fi
  local beg=${_ble_keymap_vi_filter_args[0]}
  local end=${_ble_keymap_vi_filter_args[1]}
  local context=${_ble_keymap_vi_filter_args[2]}

  _ble_edit_mark_active= # clear mark:vi_filter

  local old=${_ble_edit_str:beg:end-beg} new
  old=${old%$'\n'}
  if ! ble/util/assign new 'builtin eval -- "$command" <<< "$old" 2>/dev/null'; then
    ble/widget/vi-command/bell
    return 1
  fi
  new=${new%$'\n'}
  ((end<${#_ble_edit_str})) && new=$new$'\n'
  ble/widget/.replace-range "$beg" "$end" "$new"

  _ble_edit_ind=$beg
  if [[ $context == line ]]; then
    ble/widget/vi-command/first-non-space
  else
    ble/keymap:vi/adjust-command-mode
  fi

  ble/keymap:vi/mark/set-previous-edit-area "$beg" "$((beg+${#new}))"
  ble/keymap:vi/operator:filter/.record-repeat "$command"
  return 0
}

#--------------------------------------
# User operator: g@

bleopt/declare -v keymap_vi_operatorfunc ''

function ble/keymap:vi/operator:map {
  local context=$3
  if [[ $bleopt_keymap_vi_operatorfunc ]]; then
    local opfunc=ble/keymap:vi/operator:$bleopt_keymap_vi_operatorfunc
    if ble/is-function "$opfunc"; then
      "$opfunc" "$@"
      return "$?"
    fi
  fi
  return 1
}

#------------------------------------------------------------------------------
# Motions

#--------------------------------------
# Primitive motion

## @fn ble/widget/vi-command/exclusive-range.impl src dst flag reg nobell
## @fn ble/widget/vi-command/exclusive-goto.impl index flag reg nobell
## @fn ble/widget/vi-command/inclusive-goto.impl index flag reg nobell
##
##   @param[in] src, dst
##     Specify the position before movement and the position to move to.
##
##   @param[in] flag
##     Specify the operator name.
##
##   @param[in] reg
##     Specify the register number.
##
##   @param[in] opts
##     Colon-separated options.
##     nobell Does not ring the bell when the position before and after movement is the same.
##     inclusive Indicates that the default behavior for movement is inclusive.
##
function ble/widget/vi-command/exclusive-range.impl {
  local src=$1 dst=$2 flag=$3 reg=$4 opts=$5
  if [[ $flag ]]; then
    local opname=${flag%%:*} opflags=${flag#*:}
    if [[ :$opflags: == *:vi_line:* ]]; then
      local ble_keymap_vi_opmode=vi_line
      ble/keymap:vi/call-operator-linewise "$opname" "$src" "$dst" '' "$reg"; local ext=$?
    elif [[ :$opflags: == *:vi_block:* ]]; then
      local ble_keymap_vi_opmode=vi_line
      ble/keymap:vi/call-operator-blockwise "$opname" "$src" "$dst" '' "$reg"; local ext=$?
    elif [[ :$opflags: == *:vi_char:* ]]; then
      local ble_keymap_vi_opmode=vi_char

      # toggle inclusive/exclusive for rule o_v (omap v)
      if [[ :$opts: == *:inclusive:* ]]; then
        ((src<dst?dst--:(dst<src&&src--)))
      else
        if ((src<=dst)); then
          ((dst<${#_ble_edit_str})) &&
            [[ ${_ble_edit_str:dst:1} != $'\n' ]] &&
            ((dst++))
        else
          ((src<${#_ble_edit_str})) &&
            [[ ${_ble_edit_str:src:1} != $'\n' ]] &&
            ((src++))
        fi
      fi

      ble/keymap:vi/call-operator-charwise "$opname" "$src" "$dst" '' "$reg"; local ext=$?
    else
      local ble_keymap_vi_opmode=
      ble/keymap:vi/call-operator-charwise "$opname" "$src" "$dst" '' "$reg"; local ext=$?
    fi
    ((ext==147)) && return 147
    ((ext)) && ble/widget/.bell
    ble/keymap:vi/adjust-command-mode
    return "$ext"
  else
    ble/keymap:vi/needs-eol-fix "$dst" && ((dst--))
    if ((dst!=_ble_edit_ind)); then
      _ble_edit_ind=$dst
    elif [[ :$opts: != *:nobell:* ]]; then
      ble/widget/vi-command/bell
      return 1
    fi
    ble/keymap:vi/adjust-command-mode
    return 0
  fi
}
function ble/widget/vi-command/exclusive-goto.impl {
  local index=$1 flag=$2 reg=$3 opts=$4
  if [[ $flag ]]; then
    if ble-edit/content/bolp "$index"; then
      local is_linewise=
      if ((_ble_edit_ind<index)); then
        # :help exclusive-linewise rule 1 (only when src<ind)
        ((index--))
        # :help exclusive-linewise rule 2
        rex=$'(^|\n)[ \t]*$'
        [[ ${_ble_edit_str::_ble_edit_ind} =~ $rex ]] &&
          is_linewise=1
      elif ((index<_ble_edit_ind)); then
        # :help exclusive-linewise rule 2 (different conditions)
        ble-edit/content/bolp &&
          is_linewise=1
      fi

      if [[ $is_linewise ]]; then
        ble/widget/vi-command/linewise-goto.impl "$index" "$flag" "$reg"
        return "$?"
      fi
    fi
  fi
  ble/widget/vi-command/exclusive-range.impl "$_ble_edit_ind" "$index" "$flag" "$reg" "$opts"
}
function ble/widget/vi-command/inclusive-goto.impl {
  local index=$1 flag=$2 reg=$3 opts=$4
  if [[ $flag ]]; then
    if ((_ble_edit_ind<=index)); then
      ble-edit/content/eolp "$index" || ((index++))
    else
      ble-edit/content/eolp || ((_ble_edit_ind++))
    fi
  fi
  ble/widget/vi-command/exclusive-range.impl "$_ble_edit_ind" "$index" "$flag" "$reg" "$opts:inclusive"
}

## @fn ble/widget/vi-command/linewise-range.impl p q flag reg opts
## @fn ble/widget/vi-command/linewise-goto.impl index flag reg opts
##
##   @param[in] p, q
##     Specify the start and end positions.
##     If flag is not set, move to q.
##
##   @param[in] index
##     Set the starting position to _ble_edit_ind,
## Specify the destination or end position.
##
##     When it has the form index=indx:linex,
##     The movement destination is linex from the reference position indx.
##     If index=integer, move to the row containing index.
##
##   @param[in] flag
##   @param[in] reg
##
##   @param[in] opts
##     A colon-separated list containing the following fields:
##
##     preserve_column
##     require_multiline
##     goto_bol
##
##     bolx=NUMBER
##       If there is a start of the line where the destination (index, q) is already calculated, specify it here.
##
##     nolx=NUMBER
##       If there is a non-blank start position of the destination line (index, q) that has already been calculated, specify it here.
##
function ble/widget/vi-command/linewise-range.impl {
  local p=$1 q=$2 flag=$3 reg=$4 opts=$5
  local ret
  if [[ $q == *:* ]]; then
    local qbase=${q%%:*} qline=${q#*:}
  else
    local qbase=$q qline=0
  fi

  local bolx=; ble/string#match ":$opts:" ':bolx=([0-9]+):' && bolx=${BASH_REMATCH[1]}
  local nolx=; ble/string#match ":$opts:" ':nolx=([0-9]+):' && nolx=${BASH_REMATCH[1]}

  # When moving (when no operator is set)
  if [[ ! $flag ]]; then
    if [[ ! $nolx ]]; then
      if [[ ! $bolx ]]; then
        ble-edit/content/find-logical-bol "$qbase" "$qline"; bolx=$ret
      fi
      ble-edit/content/find-non-space "$bolx"; nolx=$ret
    fi
    ble-edit/content/nonbol-eolp "$nolx" && ((nolx--))
    _ble_edit_ind=$nolx
    ble/keymap:vi/adjust-command-mode
    return 0
  fi

  local opname=${flag%%:*} opflags=${flag#*:}
  if ! ble/is-function ble/keymap:vi/operator:"$opname"; then
    ble/widget/vi-command/bell
    return 1
  fi

  local bolp bolq=$bolx nolq=$nolx
  ble-edit/content/find-logical-bol "$p"; bolp=$ret
  [[ $bolq ]] || { ble-edit/content/find-logical-bol "$qbase" "$qline"; bolq=$ret; }

  # If you cannot move a single line with jk+-, cancel the operation.
  # Note: When using qline, it is not always possible to get what you want.
  #   Note that line qline does not necessarily exist.
  if [[ :$opts: == *:require_multiline:* ]]; then
    if ((bolq==bolp)); then
      ble/widget/vi-command/bell
      return 1
    fi
  fi

  # operator call
  if [[ :$opflags: == *:vi_char:* || :$opflags: == *:vi_block:* ]]; then
    # Deciding on a destination
    local beg=$p end
    if [[ :$opts: == *:preserve_column:* ]]; then
      local index
      ble/keymap:vi/get-index-of-relative-line "$qbase" "$qline"; end=$index
    elif [[ :$opts: == *:goto_bol:* ]]; then
      end=$bolq
    else
      [[ $nolq ]] || { ble-edit/content/find-non-space "$bolq"; nolq=$ret; }
      end=$nolq
    fi
    ((beg<=end)) || local beg=$end end=$beg

    if [[ :$opflags: == *:vi_block:* ]]; then
      local ble_keymap_vi_opmode=vi_block
      ble/keymap:vi/call-operator "$opname" "$beg" "$end" block '' "$reg"; local ext=$?
    else
      local ble_keymap_vi_opmode=vi_char
      ble/keymap:vi/call-operator "$opname" "$beg" "$end" char '' "$reg"; local ext=$?
    fi
    if ((ext)); then
      ((ext==147)) && return 147
      ble/widget/vi-command/bell
      return "$ext"
    fi
  else
    # Row-oriented processing (default)

    # Beg of the first line and end of the last line
    local beg end
    if ((bolp<=bolq)); then
      ble-edit/content/find-logical-eol "$bolq"; beg=$bolp end=$ret
    else
      ble-edit/content/find-logical-eol "$bolp"; beg=$bolq end=$ret
    fi
    ((end<${#_ble_edit_str}&&end++))

    local ble_keymap_vi_opmode=
    [[ :$opflags: == *:vi_line:* ]] && ble_keymap_vi_opmode=vi_line
    ble/keymap:vi/call-operator "$opname" "$beg" "$end" line '' "$reg"; local ext=$?
    if ((ext)); then
      ((ext==147)) && return 147
      ble/widget/vi-command/bell
      return "$ext"
    fi

    # Move to beginning of range
    local ind=$_ble_edit_ind
    if [[ $opname == [cd] ]]; then
      # These are always first-non-space.
      _ble_edit_ind=$beg
      ble/widget/vi-command/first-non-space
    elif [[ :$opts: == *:preserve_column:* ]]; then # j k
      if ((beg<ind)); then
        ble/string#count-char "${_ble_edit_str:beg:ind-beg}" $'\n'
        ((ret=-ret))
      elif ((ind<beg)); then
        ble/string#count-char "${_ble_edit_str:ind:beg-ind}" $'\n'
      else
        ret=0
      fi

      if ((ret)); then
        local index; ble/keymap:vi/get-index-of-relative-line "$_ble_edit_ind" "$ret"
        ble/keymap:vi/needs-eol-fix "$index" && ((index--))
        _ble_edit_ind=$index
      fi
    elif [[ :$opts: == *:goto_bol:* ]]; then # row-oriented yis
      _ble_edit_ind=$beg
    else # + - gg G L H
      if ((beg==bolq||ind<beg)) || [[ ${_ble_edit_str:beg:ind-beg} == *$'\n'* ]] ; then
        # Move to the beginning of the first non-blank line
        if ((bolq<=bolp)) && [[ $nolq ]]; then
          local nolb=$nolq
        else
          ble-edit/content/find-non-space "$beg"; local nolb=$ret
        fi
        ble-edit/content/nonbol-eolp "$nolb" && ((nolb--))
        ((ind<beg||nolb<ind)) && _ble_edit_ind=$nolb
      fi
    fi
  fi
  ble/keymap:vi/adjust-command-mode
  return 0
}
function ble/widget/vi-command/linewise-goto.impl {
  ble/widget/vi-command/linewise-range.impl "$_ble_edit_ind" "$@"
}

#------------------------------------------------------------------------------
# single char arguments

function ble/keymap:vi/async-read-char.hook {
  local IFS=$_ble_term_IFS
  local command="${*:1:$#-1}" key="${*:$#}"
  if ((key==(_ble_decode_Ctrl|0x6B))); then # C-k
    ble/decode/keymap/push vi_digraph
    _ble_keymap_vi_digraph__hook="$command"
  else
    builtin eval -- "$command $key"
  fi
}

function ble/keymap:vi/async-read-char {
  local IFS=$_ble_term_IFS
  _ble_decode_key__hook="ble/keymap:vi/async-read-char.hook $*"
  return 147
}

#------------------------------------------------------------------------------
# marks

## @arr _ble_keymap_vi_mark_local
##   The subscript is specified by the character code of mark.
##   Each element has the form point:bytes.
## @arr _ble_keymap_vi_mark_global
##   The subscript is specified by the character code of mark.
##   Each element has the form hindex:point:bytes.
_ble_keymap_vi_mark_Offset=32
_ble_keymap_vi_mark_hindex=
_ble_keymap_vi_mark_local=()
_ble_keymap_vi_mark_global=()
_ble_keymap_vi_mark_history=()
_ble_keymap_vi_mark_edit_dbeg=-1
_ble_keymap_vi_mark_edit_dend=-1
_ble_keymap_vi_mark_edit_dend0=-1
ble/array#push _ble_textarea_local_VARNAMES \
               _ble_keymap_vi_mark_hindex \
               _ble_keymap_vi_mark_local \
               _ble_keymap_vi_mark_global \
               _ble_keymap_vi_mark_history \
               _ble_keymap_vi_mark_edit_dbeg \
               _ble_keymap_vi_mark_edit_dend \
               _ble_keymap_vi_mark_edit_dend0

# Correspondence between mark number and usage
#
#
#   1 Internal use. For recording the starting point of rectangle insert mode
#   91 93 `[ and `]. Preserve edit/yank range.
#   96 39 `` and `''. Hold last jump position. 39 is not actually used.
#   60 62 `< and `>. Final visual range.
#

ble/array#push _ble_edit_dirty_observer ble/keymap:vi/mark/shift-by-dirty-range
blehook history_leave!=ble/keymap:vi/mark/history-onleave.hook

## @fn ble/keymap:vi/mark/history-onleave.hook
function ble/keymap:vi/mark/history-onleave.hook {
  if [[ $_ble_decode_keymap == vi_[inoxs]map ]]; then
    ble/keymap:vi/mark/set-local-mark 34 "$_ble_edit_ind" # `"
  fi
}

# If the history is not loaded, register it with _ble_history_index=0.
# Correct the history number when using it for the first time after the history has been loaded.
function ble/keymap:vi/mark/update-mark-history {
  local h; ble/history/get-index -v h
  if [[ ! $_ble_keymap_vi_mark_hindex ]]; then
    _ble_keymap_vi_mark_hindex=$h
  elif ((_ble_keymap_vi_mark_hindex!=h)); then
    local imark value

    # save
    local -a save=()
    for imark in "${!_ble_keymap_vi_mark_local[@]}"; do
      local value=${_ble_keymap_vi_mark_local[imark]}
      ble/array#push save "$imark:$value"
    done
    local IFS=$_ble_term_IFS
    _ble_keymap_vi_mark_history[_ble_keymap_vi_mark_hindex]="${save[*]-}"

    # load
    _ble_keymap_vi_mark_local=()
    local entry
    for entry in ${_ble_keymap_vi_mark_history[h]-}; do
      imark=${entry%%:*} value=${entry#*:}
      _ble_keymap_vi_mark_local[imark]=$value
    done

    _ble_keymap_vi_mark_hindex=$h
  fi
}
blehook history_change!=ble/keymap:vi/mark/history-change.hook
## @fn ble/keymap:vi/mark/history-change.hook 'delete' index...
## @fn ble/keymap:vi/mark/history-change.hook 'clear'
## @fn ble/keymap:vi/mark/history-change.hook 'insert' beg len
##   @param[in] index...
##     Specifies the number of the item to delete. Assume that they are arranged in ascending order and that there are no duplicates.
##   @param[in] beg len
##     Specify the insertion position and number of items to be inserted.
function ble/keymap:vi/mark/history-change.hook {
  local kind=$1; shift
  case $kind in
  (delete)
    # update _ble_keymap_vi_mark_global
    local imark
    for imark in "${!_ble_keymap_vi_mark_global[@]}"; do
      local value=${_ble_keymap_vi_mark_global[imark]}
      local h=${value%%:*} v=${value#*:}
      local idel shift=0
      for idel; do
        if [[ $idel == *-* ]]; then
          local b=${idel%-*} e=${idel#*-}
          ((b<=h&&h<e)) && shift= # delete
          ((h<e)) && break
          ((shift+=e-b))
        else
          ((idel==h)) && shift= # delete
          ((idel>=h)) && break
          ((shift++))
        fi
      done
      [[ $shift ]] &&
        _ble_keymap_vi_mark_global[imark]=$((h-shift)):$v
    done

    # update _ble_keymap_vi_mark_history
    ble/builtin/history/array#delete-hindex _ble_keymap_vi_mark_history "$@"

    # reset _ble_keymap_vi_mark_hindex
    _ble_keymap_vi_mark_hindex= ;;

  (clear)
    _ble_keymap_vi_mark_global=()
    _ble_keymap_vi_mark_history=()
    _ble_keymap_vi_mark_hindex= ;;

  (insert)
    local beg=$1 len=$2

    # update _ble_keymap_vi_mark_global
    local imark
    for imark in "${!_ble_keymap_vi_mark_global[@]}"; do
      local value=${_ble_keymap_vi_mark_global[imark]}

      local h=${value%%:*} v=${value#*:}
      ((h>=beg)) && _ble_keymap_vi_mark_global[imark]=$((h+len)):$v
    done

    # update _ble_keymap_vi_mark_history
    ble/builtin/history/array#insert-range _ble_keymap_vi_mark_history "$@"

    # reset _ble_keymap_vi_mark_hindex
    _ble_keymap_vi_mark_hindex= ;;
  esac
}

function ble/keymap:vi/mark/shift-by-dirty-range {
  local beg=$1 end=$2 end0=$3 reason=$4
  if [[ $4 == edit ]]; then
    ble/dirty-range#update --prefix=_ble_keymap_vi_mark_edit_d "${@:1:3}"
    ble/keymap:vi/xmap/update-dirty-range "$@"

    ble/keymap:vi/mark/update-mark-history
    local shift=$((end-end0))
    local imark
    for imark in "${!_ble_keymap_vi_mark_local[@]}"; do
      local value=${_ble_keymap_vi_mark_local[imark]}
      local index=${value%%:*} rest=${value#*:}
      ((index<beg)) || _ble_keymap_vi_mark_local[imark]=$((index<end0?beg:index+shift)):$rest
    done
    local h; ble/history/get-index -v h
    for imark in "${!_ble_keymap_vi_mark_global[@]}"; do
      local value=${_ble_keymap_vi_mark_global[imark]}
      [[ $value == "$h":* ]] || continue
      local h=${value%%:*}; value=${value:${#h}+1}
      local index=${value%%:*}; value=${value:${#index}+1}
      ((index<beg)) || _ble_keymap_vi_mark_global[imark]=$h:$((index<end0?beg:index+shift)):$value
    done
    ble/keymap:vi/mark/set-local-mark 46 "$beg" # `.
  else
    ble/dirty-range#clear --prefix=_ble_keymap_vi_mark_edit_d
    if [[ $4 == newline && $_ble_decode_keymap != vi_cmap ]]; then
      ble/keymap:vi/mark/set-local-mark 96 0 # ``
    fi
  fi
}
function ble/keymap:vi/mark/set-global-mark {
  local c=$1 index=$2 ret
  ble/keymap:vi/mark/update-mark-history
  ble-edit/content/find-logical-bol "$index"; local bol=$ret
  local h; ble/history/get-index -v h
  _ble_keymap_vi_mark_global[c]=$h:$bol:$((index-bol))
}
function ble/keymap:vi/mark/set-local-mark {
  local c=$1 index=$2 ret
  ble/keymap:vi/mark/update-mark-history
  ble-edit/content/find-logical-bol "$index"; local bol=$ret
  _ble_keymap_vi_mark_local[c]=$bol:$((index-bol))
}
## @fn ble/keymap:vi/mark/get-mark.impl index bytes
##   @param[in] index bytes
##     Specifies the position and column of the beginning of the recorded line.
##   @var[out] ret
##     Returns the corresponding position when the mark is found.
function ble/keymap:vi/mark/get-mark.impl {
  local index=$1 bytes=$2
  local len=${#_ble_edit_str}
  ((index>len&&(index=len)))
  ble-edit/content/find-logical-bol "$index"; index=$ret
  ble-edit/content/find-logical-eol "$index"; local eol=$ret
  ((index+=bytes,index>eol&&(index=eol))) # ToDo: calculate by byte offset
  ret=$index
  return 0
}
## @fn ble/keymap:vi/mark/get-local-mark
##   @param[in] c
##     Specify the mark number (character code).
##   @var[out] ret
##     Returns the corresponding position when the mark is found.
function ble/keymap:vi/mark/get-local-mark {
  local c=$1
  ble/keymap:vi/mark/update-mark-history
  local value=${_ble_keymap_vi_mark_local[c]}
  [[ $value ]] || return 1

  local data
  ble/string#split data : "$value"
  ble/keymap:vi/mark/get-mark.impl "${data[0]}" "${data[1]}" # -> ret
}

# `[ `]
_ble_keymap_vi_mark_suppress_edit=
## @fn ble/keymap:vi/mark/set-previous-edit-area beg end
##   @param[in] beg
##   @param[in] end
function ble/keymap:vi/mark/set-previous-edit-area {
  [[ $_ble_keymap_vi_mark_suppress_edit ]] && return 0
  local beg=$1 end=$2
  ((beg<end)) && ! ble-edit/content/bolp "$end" && ((end--))
  ble/keymap:vi/mark/set-local-mark 91 "$beg" # `[
  ble/keymap:vi/mark/set-local-mark 93 "$end" # `]
  ble/keymap:vi/undo/add
}
function ble/keymap:vi/mark/start-edit-area {
  [[ $_ble_keymap_vi_mark_suppress_edit ]] && return 0
  ble/dirty-range#clear --prefix=_ble_keymap_vi_mark_edit_d
}
function ble/keymap:vi/mark/commit-edit-area {
  local beg=$1 end=$2
  ble/dirty-range#update --prefix=_ble_keymap_vi_mark_edit_d "$beg" "$end" "$end"
}
function ble/keymap:vi/mark/end-edit-area {
  [[ $_ble_keymap_vi_mark_suppress_edit ]] && return 0
  local beg=$_ble_keymap_vi_mark_edit_dbeg
  local end=$_ble_keymap_vi_mark_edit_dend
  ((beg>=0)) && ble/keymap:vi/mark/set-previous-edit-area "$beg" "$end"
}

# ``
function ble/keymap:vi/mark/set-jump {
  # ToDo: jumplist?
  ble/keymap:vi/mark/set-local-mark 96 "$_ble_edit_ind"
}

function ble/widget/vi-command/set-mark {
  _ble_decode_key__hook="ble/widget/vi-command/set-mark.hook"
  return 147
}
function ble/widget/vi-command/set-mark.hook {
  local key=$1
  ble/keymap:vi/clear-arg
  local ret
  if ble/keymap:vi/k2c "$key" && local c=$ret; then
    if ((65<=c&&c<91)); then # A-Z
      ble/keymap:vi/mark/set-global-mark "$c" "$_ble_edit_ind"
      ble/keymap:vi/adjust-command-mode
      return 0
    elif ((97<=c&&c<123||c==91||c==93||c==60||c==62||c==96||c==39)); then # a-z [ ] < > ` '
      ((c==39)) && c=96 # m' is read as m`
      ble/keymap:vi/mark/set-local-mark "$c" "$_ble_edit_ind"
      ble/keymap:vi/adjust-command-mode
      return 0
    fi
  fi
  ble/widget/vi-command/bell
  return 1
}

function ble/widget/vi-command/goto-mark.impl {
  local index=$1 flag=$2 reg=$3 opts=$4
  [[ $flag ]] || ble/keymap:vi/mark/set-jump # ``
  if [[ :$opts: == *:line:* ]]; then
    ble/widget/vi-command/linewise-goto.impl "$index" "$flag" "$reg"
  else
    ble/widget/vi-command/exclusive-goto.impl "$index" "$flag" "$reg" nobell
  fi
}
function ble/widget/vi-command/goto-local-mark.impl {
  local c=$1 opts=$2 ret
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  if ble/keymap:vi/mark/get-local-mark "$c" && local index=$ret; then
    ble/widget/vi-command/goto-mark.impl "$index" "$FLAG" "$REG" "$opts"
  else
    ble/widget/vi-command/bell
    return 1
  fi
}
function ble/widget/vi-command/goto-global-mark.impl {
  local c=$1 opts=$2
  local ARG FLAG REG; ble/keymap:vi/get-arg 1

  ble/keymap:vi/mark/update-mark-history
  local value=${_ble_keymap_vi_mark_global[c]}
  if [[ ! $value ]]; then
    ble/widget/vi-command/bell
    return 1
  fi

  local data
  ble/string#split data : "$value"

  # find a history entry by data[0]
  local index; ble/history/get-index
  if ((index!=data[0])); then
    if [[ $FLAG ]]; then
      ble/widget/vi-command/bell
      return 1
    fi
    ble-edit/history/goto "${data[0]}" point=near
  fi

  # find position by data[1]:data[2]
  local ret
  ble/keymap:vi/mark/get-mark.impl "${data[1]}" "${data[2]}"
  ble/widget/vi-command/goto-mark.impl "$ret" "$FLAG" "$REG" "$opts"
}

function ble/widget/vi-command/goto-mark {
  _ble_decode_key__hook="ble/widget/vi-command/goto-mark.hook ${1:-char}"
  return 147
}
function ble/widget/vi-command/goto-mark.hook {
  local opts=$1 key=$2
  local ret
  if ble/keymap:vi/k2c "$key" && local c=$ret; then
    if ((65<=c&&c<91)); then # A-Z
      ble/widget/vi-command/goto-global-mark.impl "$c" "$opts"
      return "$?"
    elif ((_ble_keymap_vi_mark_Offset<=c)); then
      ((c==39)) && c=96 # `' is replaced with ``
      ble/widget/vi-command/goto-local-mark.impl "$c" "$opts"
      return "$?"
    fi
  fi
  ble/keymap:vi/clear-arg
  ble/widget/vi-command/bell
  return 1
}

function ble/widget/vi-command:marks {
  ble/keymap:vi/mark/update-mark-history

  local -a entries=() # <char>:<hindex>:<bol>:<col>
  local c
  for c in "${!_ble_keymap_vi_mark_local[@]}"; do
    local value=${_ble_keymap_vi_mark_local[c]}
    [[ $value ]] && ble/array#push entries "$c::$value"
  done
  for c in "${!_ble_keymap_vi_mark_global[@]}"; do
    local value=${_ble_keymap_vi_mark_global[c]}
    [[ $value ]] && ble/array#push entries "$c:$value"
  done

  local -a fields=()
  local data ret
  for data in "${entries[@]}"; do
    ble/string#split data : "$data"

    ble/util/c2s-edit "${data[0]}" sgr1=$'\e[9807m':sgr0=$'\e[9807m'; local s=$ret

    # determine the line number and history position
    local line hlabel=
    if [[ ${data[1]} ]]; then
      local entry
      ble/history/get-edited-entry "$index"
      line=$entry
      hlabel=' !'${data[1]}
    else
      line=$_ble_edit_str
    fi
    ble/string#count-char "${line::data[2]}" $'\n'
    ((line=1+ret))

    ble/keymap:vi/mark/get-mark.impl "$line" "${data[3]}"; local ind=$ret

    ble/array#push fields "${data[0]}" "$s" "$line" "${data[3]}" "$ind" "$hlabel"
  done

  if ((${#fields[@]})); then
    local content
    ble/util/sprintf content '%7d %s\t(%3d, %3d) %5d%s\n' "${fields[@]}"
    content=${content%$'\n'}
    local mydbg=1
    ble/edit/info/show ansi "$content"
  fi
  return 0
}

#------------------------------------------------------------------------------
# repeat (nmap .)

## @arr _ble_keymap_vi_repeat
## @arr _ble_keymap_vi_repeat_insert
##
##   _ble_keymap_vi_repeat records previous operation
##   _ble_keymap_vi_repeat_insert when in insert mode,
##   Holds the operation that caused the insertion mode to be entered.
##   This means that when completing insert mode with <C-[> or <C-c>,
##   This is written to _ble_keymap_vi_repeat.
##
##   ${_ble_keymap_vi_repeat[0]} = KEYMAP
##     Keep the kmap at the time of the call.
##   ${_ble_keymap_vi_repeat[1]} = KEYS
##     Holds the sequence of keys used in the call.
##   ${_ble_keymap_vi_repeat[2]} = WIDGET
##     Holds the edited command that was called.
##   ${_ble_keymap_vi_repeat[@]:3:3} = ARG FLAG REG
##     Preserves the qualification state at the time of the call.
##   ${_ble_keymap_vi_repeat[6]} = _ble_keymap_vi_xmap_prev_edit
##     Records the range size and type when using vi_xmap.
##   ${_ble_keymap_vi_repeat[@]:10}
##     Area that each WIDGET can freely use
##
## @arr _ble_keymap_vi_repeat_irepeat
##
##   When entering insert mode by operating _ble_keymap_vi_repeat,
##   This is an array that records the sequence of insert operations performed there.
##   The format is the same as _ble_keymap_vi_irepeat.
##
## @var _ble_keymap_vi_repeat_invoke
## A local variable that holds whether the widget was called via ble/keymap:vi/repeat/invoke.
##   When this variable is non-blank, it indicates a call inside ble/keymap:vi/repeat/invoke.
##
_ble_keymap_vi_repeat=()
_ble_keymap_vi_repeat_insert=()
_ble_keymap_vi_repeat_irepeat=()
_ble_keymap_vi_repeat_invoke=
function ble/keymap:vi/repeat/record-special {
  [[ $_ble_keymap_vi_mark_suppress_edit ]] && return 0

  if [[ $_ble_keymap_vi_repeat_invoke ]]; then
    # If an argument is specified for repeat, use it from now on
    [[ $repeat_arg ]] && _ble_keymap_vi_repeat[3]=$repeat_arg
    # If the register is not recorded, the newly specified register will be used from now on.
    [[ ! ${_ble_keymap_vi_repeat[5]} ]] && _ble_keymap_vi_repeat[5]=$repeat_reg
    return 0
  fi

  return 1
}
function ble/keymap:vi/repeat/record-normal {
  local IFS=$_ble_term_IFS
  local -a repeat; repeat=("$KEYMAP" "${KEYS[*]-}" "$WIDGET" "$ARG" "$FLAG" "$REG" '')
  if [[ $KEYMAP == vi_[xs]map ]]; then
    repeat[6]=$_ble_keymap_vi_xmap_prev_edit
  fi
  if [[ $_ble_decode_keymap == vi_imap ]]; then
    _ble_keymap_vi_repeat_insert=("${repeat[@]}")
  else
    _ble_keymap_vi_repeat=("${repeat[@]}")
    _ble_keymap_vi_repeat_irepeat=()
  fi
}
function ble/keymap:vi/repeat/record {
  ble/keymap:vi/repeat/record-special && return 0
  ble/keymap:vi/repeat/record-normal
}
## @fn ble/keymap:vi/repeat/record-insert
##   When exiting insert mode, the operation that triggered entering insert mode,
##   Records columns for insert operations performed in insert mode.
function ble/keymap:vi/repeat/record-insert {
  ble/keymap:vi/repeat/record-special && return 0
  if [[ ${_ble_keymap_vi_repeat_insert-} ]]; then
    # If the insertion mode entry operation is still valid, it will be recorded regardless of whether there is an insertion operation.
    _ble_keymap_vi_repeat=("${_ble_keymap_vi_repeat_insert[@]}")
    _ble_keymap_vi_repeat_irepeat=("${_ble_keymap_vi_irepeat[@]}")
  elif ((${#_ble_keymap_vi_irepeat[@]})); then
    # If the insertion mode entry operation has been initialized, it will be recorded only when there is an insertion operation.
    local IFS=$_ble_term_IFS
    _ble_keymap_vi_repeat=(vi_nmap "${KEYS[*]-}" ble/widget/vi_nmap/insert-mode 1 '' '')
    _ble_keymap_vi_repeat_irepeat=("${_ble_keymap_vi_irepeat[@]}")
  fi
  ble/keymap:vi/repeat/clear-insert
}
## @fn ble/keymap:vi/repeat/clear-insert
##   When a command not in the white list is executed in insert mode,
##   Initializes the operation that caused insert mode to be entered.
function ble/keymap:vi/repeat/clear-insert {
  _ble_keymap_vi_repeat_insert=()
}

function ble/keymap:vi/repeat/invoke {
  local repeat_arg=$_ble_edit_arg
  local repeat_reg=$_ble_keymap_vi_reg
  local KEYMAP=${_ble_keymap_vi_repeat[0]}
  local -a KEYS; ble/string#split-words KEYS "${_ble_keymap_vi_repeat[1]}"
  local WIDGET=${_ble_keymap_vi_repeat[2]}

  # keymap state restoration
  if [[ $KEYMAP != vi_[onxs]map ]]; then
    ble/widget/vi-command/bell
    return 1
  elif [[ $KEYMAP == vi_omap ]]; then
    ble/decode/keymap/push vi_omap
  elif [[ $KEYMAP == vi_[xs]map ]]; then
    local _ble_keymap_vi_xmap_prev_edit=${_ble_keymap_vi_repeat[6]}
    ble/widget/vi_xmap/.restore-visual-state
    ble/decode/keymap/push "$KEYMAP"
    # Note: In vim, . does not update the area size.
    #   Therefore, we deliberately do not unset _ble_keymap_vi_xmap_prev_edit here.
  fi

  # *The main _ble_keymap_vi_repeat is rewritten with repeat/record only when it is successful.
  _ble_edit_arg=
  _ble_keymap_vi_oparg=${_ble_keymap_vi_repeat[3]}
  _ble_keymap_vi_opfunc=${_ble_keymap_vi_repeat[4]}
  [[ $repeat_arg ]] && _ble_keymap_vi_oparg=$repeat_arg

  # In vim, recorded registers seem to have priority.
  local REG=${_ble_keymap_vi_repeat[5]}
  [[ $REG ]] && _ble_keymap_vi_reg=$REG

  local _ble_keymap_vi_single_command{,_overwrite}= # Single-command-mode persists.
  local _ble_keymap_vi_repeat_invoke=1
  local LASTWIDGET=$_ble_decode_widget_last
  _ble_decode_widget_last=$WIDGET
  builtin eval -- "$WIDGET"

  if [[ $_ble_decode_keymap == vi_imap ]]; then
    ((_ble_keymap_vi_irepeat_count<=1?(_ble_keymap_vi_irepeat_count=2):_ble_keymap_vi_irepeat_count++))
    local -a _ble_keymap_vi_irepeat
    _ble_keymap_vi_irepeat=("${_ble_keymap_vi_repeat_irepeat[@]}")

    ble/array#push _ble_keymap_vi_irepeat '0:ble/widget/dummy' # Note: as normal-mode tries to pop itself.
    ble/widget/vi_imap/normal-mode
  fi
  ble/util/unlocal _ble_keymap_vi_single_command{,_overwrite}
}

# nmap .
function ble/widget/vi_nmap/repeat {
  ble/keymap:vi/repeat/invoke
  ble/keymap:vi/adjust-command-mode
}

#------------------------------------------------------------------------------
# command: [cdy]?[hl]

## @widget vi-command/forward-char [type]
## @widget vi-command/backward-char [type]
##
##   @param[in] type
##     When type=wrap allows moving across multiple lines.
##
function ble/widget/vi-command/forward-char {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1

  local index
  if [[ $1 == wrap ]]; then
    # SP
    if [[ $FLAG || $_ble_decode_keymap == vi_[xs]map ]]; then
      ((index=_ble_edit_ind+ARG,
        index>${#_ble_edit_str}&&(index=${#_ble_edit_str})))
    else
      local nl=$'\n'
      local rex="^([^$nl]$nl?|$nl){0,$ARG}"
      [[ ${_ble_edit_str:_ble_edit_ind} =~ $rex ]]
      ((index=_ble_edit_ind+${#BASH_REMATCH}))
    fi
  else
    local line=${_ble_edit_str:_ble_edit_ind:ARG}
    line=${line%%$'\n'*}
    ((index=_ble_edit_ind+${#line}))
  fi

  ble/widget/vi-command/exclusive-goto.impl "$index" "$FLAG" "$REG"
}

function ble/widget/vi-command/backward-char {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1

  local index
  ((ARG>_ble_edit_ind&&(ARG=_ble_edit_ind)))
  if [[ $1 == wrap ]]; then
    # DEL
    if [[ $FLAG || $_ble_decode_keymap == vi_[xs]map ]]; then
      ((index=_ble_edit_ind-ARG,index<0&&(index=0)))
    else
      local width=$ARG line
      while ((width<=_ble_edit_ind)); do
        line=${_ble_edit_str:_ble_edit_ind-width:width}
        line=${line//[!$'\n']$'\n'/x}
        ((${#line}>=ARG)) && break
        ((width+=ARG-${#line}))
      done
      ((index=_ble_edit_ind-width,index<0&&(index=0)))
    fi
  else
    local line=${_ble_edit_str:_ble_edit_ind-ARG:ARG}
    line=${line##*$'\n'}
    ((index=_ble_edit_ind-${#line}))
  fi

  ble/widget/vi-command/exclusive-goto.impl "$index" "$FLAG" "$REG"
}

# nmap ~
function ble/widget/vi_nmap/forward-char-toggle-case {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  local line=${_ble_edit_str:_ble_edit_ind:ARG}
  line=${line%%$'\n'*}
  local len=${#line}
  if ((len==0)); then
    ble/widget/vi-command/bell
    return 1
  fi

  local index=$((_ble_edit_ind+len))
  local ret; ble/string#toggle-case "${_ble_edit_str:_ble_edit_ind:len}"
  ble/widget/.replace-range "$_ble_edit_ind" "$index" "$ret"
  ble/keymap:vi/mark/set-previous-edit-area "$_ble_edit_ind" "$index"
  ble/keymap:vi/repeat/record
  ble/keymap:vi/needs-eol-fix "$index" && ((index--))
  _ble_edit_ind=$index
  ble/keymap:vi/adjust-command-mode
  return 0
}

#------------------------------------------------------------------------------
# command: [cdy]?[jk]

## @fn ble/widget/vi-command/.history-relative-line offset
##
##   @param[in] offset
##     Specifies the relative number of lines to move. Negative values represent moving forward;
##     A positive value indicates moving later.
##
##   @exit
##     Returns 1 if no movement occurred.
##     otherwise returns 0.
##
function ble/widget/vi-command/.history-relative-line {
  local offset=$1
  ((offset)) || return 0

  # You are at the last line when the history has not been initialized.
  if [[ ! $_ble_history_prefix && ! $_ble_history_load_done ]]; then
    ((offset<0)) || return 1
    ble/history/initialize # to use ble/history/get-index
  fi

  local index histsize
  ble/history/get-index
  ble/history/get-count -v histsize
  local index0=$index

  local ret count=$((offset<0?-offset:offset))
  ((count--))
  while ((count>=0)); do
    if ((offset<0)); then
      ((--index))
      ((index>=0)) || break
    else
      ((++index))
      ((index<=histsize)) || break
    fi
    local entry; ble/history/get-edited-entry "$index"
    ble/string#count-char "$entry" $'\n'; local nline=$((ret+1))
    ((count<nline)) && break
    ((count-=nline))
  done
  ((index!=index0)) || return 1

  if ((index<0)); then
    # reached the beginning of history
    ble-edit/history/goto 0 point=none
    _ble_edit_ind=0
  elif ((index>histsize)); then
    # reached the end of history
    ble-edit/history/goto "$histsize" point=none
    _ble_edit_ind=${#_ble_edit_str}
  else
    ble-edit/history/goto "$index" linewise:default-point=near
  fi
  ble/keymap:vi/needs-eol-fix && ((_ble_edit_ind--))

  return 0
}

## @fn ble/keymap:vi/get-index-of-relative-line p offset
##   Calculates the destination position for row movement preserving columns.
##   @param[in,opt] p
##     Specify the reference position. If an empty string is specified, the current position will be used.
##   @param[in] offset
##     Specify the number of rows to move.
##   @param[out] index
function ble/keymap:vi/get-index-of-relative-line {
  local ind=${1:-$_ble_edit_ind} offset=$2
  if ((offset==0)); then
    index=$ind
    return 0
  fi

  local count=$((offset<0?-offset:offset))
  local ret
  ble-edit/content/find-logical-bol "$ind" 0; local bol1=$ret
  ble-edit/content/find-logical-bol "$ind" "$offset"; local bol2=$ret
  if ble/edit/use-textmap; then
    # Preserve relative display position (x,y) of columns
    local b1x b1y; ble/textmap#getxy.cur --prefix=b1 "$bol1"
    local b2x b2y; ble/textmap#getxy.cur --prefix=b2 "$bol2"

    ble-edit/content/find-logical-eol "$bol2"; local eol2=$ret
    local c1x c1y; ble/textmap#getxy.cur --prefix=c1 "$ind"
    local e2x e2y; ble/textmap#getxy.cur --prefix=e2 "$eol2"

    local x=$c1x y=$((b2y+c1y-b1y))
    ((y>e2y&&(x=e2x,y=e2y)))

    ble/textmap#get-index-at "$x" "$y" # local variable "index" is set here
  else
    # Preserve logical columns
    ble-edit/content/find-logical-eol "$bol2"; local eol2=$ret
    ((index=bol2+ind-bol1,index>eol2&&(index=eol2)))
  fi
}

## @fn ble/widget/vi-command/relative-line.impl offset flag reg opts
## @widget vi-command/forward-line  # nmap j
## @widget vi-command/backward-line # nmap k
##
##   About the operation of movement by j and k. Suppose you want to move a logical line.
##   When placement information is available, the column holds the relative display position (dx,dy) from the beginning of the line.
##   Retain logical columns when there is no placement information.
##
##   When moving to an earlier history item, the column moves to the end of the line.
##   When moving to a later history item, the column moves to the beginning.
##
##   ToDo: Currently, the relative display position at the start of movement is not recorded.
##
##   @param[in] offset flag
##
##   @param[in] opts
##     Specify the following values separated by colons.
##
##     history
##       When it is not possible to move the requested number of lines within the current history item,
##       Move logical lines within history items.
##       However, if flag is present, the history item will not be moved.
##
function ble/widget/vi-command/relative-line.impl {
  local offset=$1 flag=$2 reg=$3 opts=$4
  ((offset==0)) && return 0
  if [[ $flag ]]; then
    ble/widget/vi-command/linewise-goto.impl "$_ble_edit_ind:$offset" "$flag" "$reg" preserve_column:require_multiline
    return "$?"
  fi

  # Determining the number of lines that can currently be moved within a history item
  local count=$((offset<0?-offset:offset)) ret
  if ((offset<0)); then
    ble/string#count-char "${_ble_edit_str::_ble_edit_ind}" $'\n'
  else
    ble/string#count-char "${_ble_edit_str:_ble_edit_ind}" $'\n'
  fi
  local nmove=$((count<ret?count:ret))
  ((count-=nmove))

  # Search within the current history item
  if ((count==0)); then
    local index; ble/keymap:vi/get-index-of-relative-line "$_ble_edit_ind" "$offset"
    ble/keymap:vi/needs-eol-fix "$index" && ((index--))
    _ble_edit_ind=$index
    ble/keymap:vi/adjust-command-mode
    return 0
  fi

  # Move history items by counting the number of lines
  if [[ $_ble_decode_keymap == vi_nmap && :$opts: == *:history:* ]]; then
    if ble/widget/vi-command/.history-relative-line "$((offset>=0?count:-count))" || ((nmove)); then
      ble/keymap:vi/adjust-command-mode
      return 0
    fi
  fi

  ble/widget/vi-command/bell
  return 1
}
function ble/widget/vi-command/forward-line {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/relative-line.impl "$ARG" "$FLAG" "$REG" history
}
function ble/widget/vi-command/backward-line {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/relative-line.impl "$((-ARG))" "$FLAG" "$REG" history
}

## @fn ble/widget/vi-command/graphical-relative-line.impl offset flag reg opts
## @widget vi-command/graphical-forward-line  # nmap gj
## @widget vi-command/graphical-backward-line # nmap gk
##
##   @param[in] offset
##     Relative number of rows to move. Negative values ​​indicate going to the top row. A positive value indicates going to the bottom row.
##   @param[in] flag
##     Specify the operator.
##   @param[in] opts
##     Specify the following options connected by colons.
##
##     history
##
function ble/widget/vi-command/graphical-relative-line.impl {
  local offset=$1 flag=$2 reg=$3 opts=$4
  local index move
  if ble/edit/use-textmap; then
    local x y ax ay
    ble/textmap#getxy.cur "$_ble_edit_ind"
    ((ax=x,ay=y+offset,
      ay<_ble_textmap_begy?(ay=_ble_textmap_begy):
      (ay>_ble_textmap_endy?(ay=_ble_textmap_endy):0)))
    ble/textmap#get-index-at "$ax" "$ay"
    ble/textmap#getxy.cur --prefix=a "$index"
    ((offset-=move=ay-y))
  else
    local ret ind=$_ble_edit_ind
    ble-edit/content/find-logical-bol "$ind" 0; local bol1=$ret
    ble-edit/content/find-logical-bol "$ind" "$offset"; local bol2=$ret
    ble-edit/content/find-logical-eol "$bol2"; local eol2=$ret
    ((index=bol2+ind-bol1,index>eol2&&(index=eol2)))

    if ((index>ind)); then
      ble/string#count-char "${_ble_edit_str:ind:index-ind}" $'\n'
      ((offset+=move=-ret))
    elif ((index<ind)); then
      ble/string#count-char "${_ble_edit_str:index:ind-index}" $'\n'
      ((offset+=move=ret))
    fi
  fi

  if ((offset==0)); then
    ble/widget/vi-command/exclusive-goto.impl "$index" "$flag" "$reg"
    return "$?"
  fi

  if [[ ! $flag && $_ble_decode_keymap == vi_nmap && :$opts: == *:history:* ]]; then
    if ble/widget/vi-command/.history-relative-line "$offset"; then
      ble/keymap:vi/adjust-command-mode
      return 0
    fi
  fi

  # Failed: Operator is not executed but moved.
  ((move)) && ble/widget/vi-command/exclusive-goto.impl "$index"
  ble/widget/vi-command/bell
  return 1
}
function ble/widget/vi-command/graphical-forward-line {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/graphical-relative-line.impl "$ARG" "$FLAG" "$REG"
}
function ble/widget/vi-command/graphical-backward-line {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/graphical-relative-line.impl "$((-ARG))" "$FLAG" "$REG"
}

#------------------------------------------------------------------------------
# command: ^ + - _ $

function ble/widget/vi-command/relative-first-non-space.impl {
  local arg=$1 flag=$2 reg=$3 opts=$4
  local ret ind=$_ble_edit_ind
  ble-edit/content/find-logical-bol "$ind" "$arg"; local bolx=$ret
  ble-edit/content/find-non-space "$bolx"; local nolx=$ret

  # 2017-09-12 I don't know why, but vim seems to behave like this.
  ((_ble_keymap_vi_single_command==2&&_ble_keymap_vi_single_command--))

  if [[ $flag ]]; then
    if [[ :$opts: == *:charwise:* ]]; then
      # command: ^
      ble-edit/content/nonbol-eolp "$nolx" && ((nolx--))
      ble/widget/vi-command/exclusive-goto.impl "$nolx" "$flag" "$reg" nobell
    elif [[ :$opts: == *:multiline:* ]]; then
      # command: + -
      ble/widget/vi-command/linewise-goto.impl "$nolx" "$flag" "$reg" require_multiline:bolx="$bolx":nolx="$nolx"
    else
      # command: _
      ble/widget/vi-command/linewise-goto.impl "$nolx" "$flag" "$reg" bolx="$bolx":nolx="$nolx"
    fi
    return "$?"
  fi

  local count=$((arg<0?-arg:arg)) nmove=0
  if ((count)); then
    local beg end; ((nolx<ind?(beg=nolx,end=ind):(beg=ind,end=nolx)))
    ble/string#count-char "${_ble_edit_str:beg:end-beg}" $'\n'; nmove=$ret
    ((count-=nmove))
  fi

  if ((count==0)); then
    ble/keymap:vi/needs-eol-fix "$nolx" && ((nolx--))
    _ble_edit_ind=$nolx
    ble/keymap:vi/adjust-command-mode
    return 0
  fi

  # Moving history items
  if [[ $_ble_decode_keymap == vi_nmap && :$opts: == *:history:* ]] && ble/widget/vi-command/.history-relative-line "$((arg>=0?count:-count))"; then
    ble/widget/vi-command/first-non-space
  elif ((nmove)); then
    ble/keymap:vi/needs-eol-fix "$nolx" && ((nolx--))
    _ble_edit_ind=$nolx
    ble/keymap:vi/adjust-command-mode
  else
    ble/widget/vi-command/bell
    return 1
  fi
}
# nmap ^
function ble/widget/vi-command/first-non-space {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/relative-first-non-space.impl 0 "$FLAG" "$REG" charwise:history
}
# nmap +
function ble/widget/vi-command/forward-first-non-space {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/relative-first-non-space.impl "$ARG" "$FLAG" "$REG" multiline:history
}
# nmap -
function ble/widget/vi-command/backward-first-non-space {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/relative-first-non-space.impl "$((-ARG))" "$FLAG" "$REG" multiline:history
}
# nmap _
function ble/widget/vi-command/first-non-space-forward {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/relative-first-non-space.impl "$((ARG-1))" "$FLAG" "$REG" history
}
# nmap $
function ble/widget/vi-command/forward-eol {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  if ((ARG>1)) && [[ ${_ble_edit_str:_ble_edit_ind}  != *$'\n'* ]]; then
    ble/widget/vi-command/bell
    return 1
  fi

  local ret index
  ble-edit/content/find-logical-eol "$_ble_edit_ind" "$((ARG-1))"; index=$ret
  ble/keymap:vi/needs-eol-fix "$index" && ((index--))
  ble/widget/vi-command/inclusive-goto.impl "$index" "$FLAG" "$REG" nobell
  [[ $_ble_decode_keymap == vi_[xs]map ]] &&
    ble/keymap:vi/xmap/add-eol-extension # trailing extension
}
# nmap g0 g<home>
function ble/widget/vi-command/beginning-of-graphical-line {
  if ble/edit/use-textmap; then
    local ARG FLAG REG; ble/keymap:vi/get-arg 1
    local x y index
    ble/textmap#getxy.cur "$_ble_edit_ind"
    ble/textmap#get-index-at 0 "$y"
    ble/keymap:vi/needs-eol-fix "$index" && ((index--))
    ble/widget/vi-command/exclusive-goto.impl "$index" "$FLAG" "$REG" nobell
  else
    ble/widget/vi-command/beginning-of-line
  fi
}
# nmap g^
function ble/widget/vi-command/graphical-first-non-space {
  if ble/edit/use-textmap; then
    local ARG FLAG REG; ble/keymap:vi/get-arg 1
    local x y index ret
    ble/textmap#getxy.cur "$_ble_edit_ind"
    ble/textmap#get-index-at 0 "$y"
    ble-edit/content/find-non-space "$index"
    ble/keymap:vi/needs-eol-fix "$ret" && ((ret--))
    ble/widget/vi-command/exclusive-goto.impl "$ret" "$FLAG" "$REG" nobell
  else
    ble/widget/vi-command/first-non-space
  fi
}
# nmap g$ g<end>
function ble/widget/vi-command/graphical-forward-eol {
  if ble/edit/use-textmap; then
    local ARG FLAG REG; ble/keymap:vi/get-arg 1
    local x y index
    ble/textmap#getxy.cur "$_ble_edit_ind"
    ble/textmap#get-index-at "$((_ble_textmap_cols-1))" "$((y+ARG-1))"
    ble/keymap:vi/needs-eol-fix "$index" && ((index--))
    ble/widget/vi-command/inclusive-goto.impl "$index" "$FLAG" "$REG" nobell
  else
    ble/widget/vi-command/forward-eol
  fi
}
# nmap gm
function ble/widget/vi-command/middle-of-graphical-line {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  local index
  if ble/edit/use-textmap; then
    local x y
    ble/textmap#getxy.cur "$_ble_edit_ind"
    ble/textmap#get-index-at "$((_ble_textmap_cols/2))" "$y"
    ble/keymap:vi/needs-eol-fix "$index" && ((index--))
  else
    local ret
    ble-edit/content/find-logical-bol; local bol=$ret
    ble-edit/content/find-logical-eol; local eol=$ret
    ((index=(bol+${COLUMNS:-eol})/2,
      index>eol&&(index=eol),
      bol<eol&&index==eol&&(index--)))
  fi
  ble/widget/vi-command/exclusive-goto.impl "$index" "$FLAG" "$REG" nobell
}
# nmap g_
function ble/widget/vi-command/last-non-space {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  local ret
  ble-edit/content/find-logical-eol "$_ble_edit_ind" "$((ARG-1))"; local index=$ret
  if ((ARG>1)) && [[ ${_ble_edit_str:_ble_edit_ind:index-_ble_edit_ind} != *$'\n'* ]]; then
    # Failure if line movement was supposed to occur but no line was advanced
    ble/widget/vi-command/bell
    return 1
  fi

  local rex=$'([^ \t\n]?[ \t]+|[^ \t\n])$'
  [[ ${_ble_edit_str::index} =~ $rex ]] && ((index-=${#BASH_REMATCH}))
  ble/widget/vi-command/inclusive-goto.impl "$index" "$FLAG" "$REG" nobell

}

#------------------------------------------------------------------------------
# vi_nmap: scroll
#   C-d, C-u, C-e, C-y
#   C-b, prior, C-f, next

_ble_keymap_vi_previous_scroll=
## @fn ble/widget/vi_nmap/scroll.impl opts
##   @arg[in] opts
##     forward
##     backward
function ble/widget/vi_nmap/scroll.impl {
  local opts=$1
  local height=${_ble_canvas_panel_height[_ble_textarea_panel]}

  # adjust arguments
  local ARG FLAG REG; ble/keymap:vi/get-arg "$_ble_keymap_vi_previous_scroll"
  _ble_keymap_vi_previous_scroll=$ARG
  [[ $ARG ]] || ((ARG=height/2))
  [[ :$opts: == *:backward:* ]] && ((ARG=-ARG))

  ble/widget/.update-textmap
  if [[ :$opts: == *:cursor:* ]]; then
    # move
    local x y index ret
    ble/textmap#getxy.cur "$_ble_edit_ind"
    ble/textmap#get-index-at 0 "$((y+ARG))"
    ble-edit/content/find-non-space "$index"
    ble/keymap:vi/needs-eol-fix "$ret" && ((ret--))
    _ble_edit_ind=$ret
    ble/keymap:vi/adjust-command-mode

    ((_ble_textmap_endy<height)) && return 0
    local ax ay
    ble/textmap#getxy.cur --prefix=a "$_ble_edit_ind"
    local max_scroll=$((_ble_textmap_endy+1-height))
    ((_ble_textarea_scroll_new+=ay-y))
    if ((_ble_textarea_scroll_new<0)); then
      _ble_textarea_scroll_new=0
    elif ((_ble_textarea_scroll_new>max_scroll)); then
      _ble_textarea_scroll_new=$max_scroll
    fi
  else
    ((_ble_textmap_endy<height)) && return 0

    local max_scroll=$((_ble_textmap_endy+1-height))
    ((_ble_textarea_scroll_new+=ARG))
    if ((_ble_textarea_scroll_new<0)); then
      _ble_textarea_scroll_new=0
    elif ((_ble_textarea_scroll_new>max_scroll)); then
      _ble_textarea_scroll_new=$max_scroll
    fi

    # ax ay display range
    local ay=$((_ble_textarea_scroll_new+_ble_textmap_begy))
    local by=$((_ble_textarea_scroll_new+height-1))
    ((_ble_textarea_scroll_new&&ay++))

    # cursor range
    ((_ble_textarea_scroll_new!=0&&ay<by&&ay++,
      _ble_textarea_scroll_new!=max_scroll&&ay<by&&by--))
    local x y
    ble/textmap#getxy.cur "$_ble_edit_ind"
    if ((y<ay?(y=ay,1):(y>by?(y=by,1):0))); then
      local index
      ble/textmap#get-index-at "$x" "$y"
      _ble_edit_ind=$index
    fi

    ble/keymap:vi/adjust-command-mode
  fi
}

# nmap C-d
function ble/widget/vi_nmap/forward-line-scroll {
  ble/widget/vi_nmap/scroll.impl forward:cursor
}
# nmap C-u
function ble/widget/vi_nmap/backward-line-scroll {
  ble/widget/vi_nmap/scroll.impl backward:cursor
}
# nmap C-e
function ble/widget/vi_nmap/forward-scroll {
  ble/widget/vi_nmap/scroll.impl forward
}
# nmap C-y
function ble/widget/vi_nmap/backward-scroll {
  ble/widget/vi_nmap/scroll.impl backward
}

# nmap C-f, next
function ble/widget/vi_nmap/pagedown {
  local height=${_ble_canvas_panel_height[_ble_textarea_panel]}

  local ARG FLAG REG; ble/keymap:vi/get-arg 1

  ble/widget/.update-textmap

  # Confirm that you are on a line other than the last line
  local x y
  ble/textmap#getxy.cur "$_ble_edit_ind"
  if ((y==_ble_textmap_endy)); then
    ble/widget/vi-command/bell
    return 1
  fi

  # Decide on your destination
  local vheight=$((height-_ble_textmap_begy-1))
  local ybase=$((_ble_textarea_scroll_new+height-1))
  local y1=$((ybase+(ARG-1)*(vheight-2)))
  local index ret
  ble/textmap#get-index-at 0 "$y1"
  ble-edit/content/bolp "$index" &&
    ble-edit/content/find-non-space "$index"; index=$ret
  _ble_edit_ind=$index

  # Scroll (so that the current position is the second line from the top)
  local max_scroll=$((_ble_textmap_endy+1-height))
  ble/textmap#getxy.cur "$_ble_edit_ind"
  local scroll=$((y<=_ble_textmap_begy+1?0:(y-_ble_textmap_begy-1)))
  ((scroll>max_scroll&&(scroll=max_scroll)))
  _ble_textarea_scroll_new=$scroll
  ble/keymap:vi/adjust-command-mode
}
# nmap C-b, prior
function ble/widget/vi_nmap/pageup {
  local height=${_ble_canvas_panel_height[_ble_textarea_panel]}

  local ARG FLAG REG; ble/keymap:vi/get-arg 1

  ble/widget/.update-textmap

  # Make sure that at least the first line is not displayed
  if ((!_ble_textarea_scroll_new)); then
    ble/widget/vi-command/bell
    return 1
  fi

  # Decide on your destination
  local vheight=$((height-_ble_textmap_begy-1))
  local ybase=$((_ble_textarea_scroll_new+_ble_textmap_begy+1))
  local y1=$((ybase-(ARG-1)*(vheight-2)))
  ((y1<_ble_textmap_begy&&(y1=_ble_textmap_begy)))
  local index ret
  ble/textmap#get-index-at 0 "$y1"
  ble-edit/content/bolp "$index" &&
    ble-edit/content/find-non-space "$index"; index=$ret
  _ble_edit_ind=$index

  # Scroll (so that the current position is the second line from the bottom)
  local x y
  ble/textmap#getxy.cur "$_ble_edit_ind"
  local scroll=$((y-height+2))
  ((scroll<0&&(scroll=0)))
  _ble_textarea_scroll_new=$scroll
  ble/keymap:vi/adjust-command-mode
}

function ble/widget/vi_nmap/scroll-to-center.impl {
  local opts=$1
  ble/widget/.update-textmap
  local height=${_ble_canvas_panel_height[_ble_textarea_panel]}

  local ARG FLAG REG; ble/keymap:vi/get-arg ''
  if [[ ! $ARG && :$opts: == *:pagedown:* ]]; then
    local y1=$((_ble_textarea_scroll_new+height))
    local index
    ble/textmap#get-index-at 0 "$y1"
    ((_ble_edit_ind=index))
  fi

  local ret
  ble-edit/content/find-logical-bol "$_ble_edit_ind"; local bol1=$ret
  if [[ $ARG || :$opts: == *:nol:* ]]; then
    if [[ $ARG ]]; then
      ble-edit/content/find-logical-bol 0 "$((ARG-1))"; local bol2=$ret
    else
      local bol2=$bol1
    fi

    if [[ :$opts: == *:nol:* ]]; then
      # move to beginning of non-blank line
      ble-edit/content/find-non-space "$bol2"
      _ble_edit_ind=$ret
    elif ((bol1!=bol2)); then
      # move to the same relative position within a row

      # dx dy = relative position from the beginning of the line
      local b1x b1y p1x p1y dx dy
      ble/textmap#getxy.cur --prefix=b1 "$bol1"
      ble/textmap#getxy.cur --prefix=p1 "$_ble_edit_ind"
      ((dx=p1x,dy=p1y-b1y))

      # index = index of the same relative position in the destination row bol2
      local b2x b2y p2x p2y index
      ble/textmap#getxy.cur --prefix=b2 "$bol2"
      ((p2x=b2x,p2y=b2y+dy))
      ble/textmap#get-index-at "$p2x" "$p2y"

      if ble-edit/content/find-logical-bol "$index"; ((ret==bol2)); then
        _ble_edit_ind=$index
      else
        # If on a different line, move to the end of the line
        ble-edit/content/find-logical-eol "$bol2"
        _ble_edit_ind=$ret
      fi
    fi
    ble/keymap:vi/needs-eol-fix && ((_ble_edit_ind--))
  fi

  # Calculating scroll amount
  if ((_ble_textmap_endy+1>height)); then
    local max_scroll=$((_ble_textmap_endy+1-height))

    local b1x b1y
    ble/textmap#getxy.cur --prefix=b1 "$bol1"

    local scroll=
    if [[ :$opts: == *:top:* ]]; then
      ((scroll=b1y-(_ble_textmap_begy+2)))
    elif [[ :$opts: == *:bottom:* ]]; then
      ((scroll=b1y-(height-2)))
    else
      local vheight=$((height-_ble_textmap_begy-1))
      ((scroll=b1y-(_ble_textmap_begy+1+vheight/2)))
    fi

    if ((scroll<0)); then
      scroll=0
    elif ((scroll>max_scroll)); then
      scroll=$max_scroll
    fi
    _ble_textarea_scroll_new=$scroll
  fi

  ble/keymap:vi/adjust-command-mode
}

# nmap zz
function ble/widget/vi_nmap/scroll-to-center-and-redraw {
  ble/widget/vi_nmap/scroll-to-center.impl
  ble/widget/redraw-line
}
# nmap zt
function ble/widget/vi_nmap/scroll-to-top-and-redraw {
  ble/widget/vi_nmap/scroll-to-center.impl top
  ble/widget/redraw-line
}
# nmap zb
function ble/widget/vi_nmap/scroll-to-bottom-and-redraw {
  ble/widget/vi_nmap/scroll-to-center.impl bottom
  ble/widget/redraw-line
}
# nmap z.
function ble/widget/vi_nmap/scroll-to-center-non-space-and-redraw {
  ble/widget/vi_nmap/scroll-to-center.impl nol
  ble/widget/redraw-line
}
# nmap z<C-m>
function ble/widget/vi_nmap/scroll-to-top-non-space-and-redraw {
  ble/widget/vi_nmap/scroll-to-center.impl top:nol
  ble/widget/redraw-line
}
# nmap z-
function ble/widget/vi_nmap/scroll-to-bottom-non-space-and-redraw {
  ble/widget/vi_nmap/scroll-to-center.impl bottom:nol
  ble/widget/redraw-line
}
# nmap z+
function ble/widget/vi_nmap/scroll-or-pagedown-and-redraw {
  ble/widget/vi_nmap/scroll-to-center.impl top:nol:pagedown
  ble/widget/redraw-line
}

#------------------------------------------------------------------------------
# command: p P

## @fn ble/widget/vi_nmap/paste.impl/block arg [type]
##
##   @param[in] arg
##     Specifies the number of repetitions for each row to be inserted.
##
##   @param[in] type
##     If you specify graphical, it will be inserted using the placement information.
##     If omitted, placement information will be used if available.
##     If you specify anything else, inserts will be performed based on logical columns.
##
##   @var[in] _ble_edit_kill_ring
##     A list of strings separated by line breaks.
##
##   @var[in] _ble_edit_kill_type == B:*
##     B: Contains a list of space-separated numbers following.
##     Specify as many numbers as there are rows in _ble_edit_kill_ring.
##     The number represents the number of spaces to add after the line.
##
function ble/widget/vi_nmap/paste.impl/block {
  local arg=${1:-1} type=$2
  local graphical=
  if [[ $type ]]; then
    [[ $type == graphical ]] && graphical=1
  else
    ble/edit/use-textmap && graphical=1
  fi

  local ret cols=$_ble_textmap_cols

  local -a afill; ble/string#split-words afill "${_ble_edit_kill_type:2}"
  local atext; ble/string#split-lines atext "$_ble_edit_kill_ring"
  local ntext=${#atext[@]}

  if [[ $graphical ]]; then
    ble-edit/content/find-logical-bol; local bol=$ret
    local bx by x y c
    ble/textmap#getxy.cur --prefix=b "$bol"
    ble/textmap#getxy.cur "$_ble_edit_ind"
    ((y-=by,c=y*cols+x))
  else
    ble-edit/content/find-logical-bol; local bol=$ret
    local c=$((_ble_edit_ind-bol))
  fi

  local -a ins_beg=() ins_end=() ins_text=()
  local i is_newline=
  for ((i=0;i<ntext;i++)); do
    if ((i>0)); then
      ble-edit/content/find-logical-bol "$bol" 1
      if ((bol==ret)); then
        is_newline=1
      else
        bol=$ret
        [[ $graphical ]] && ble/textmap#getxy.cur --prefix=b "$bol"
      fi
    fi

    # insert string
    local text=${atext[i]}
    local fill=$((afill[i]))
    if ((arg>1)); then
      ret=
      ((fill)) && ble/string#repeat ' ' "$fill"
      ble/string#repeat "$text$ret" "$arg"
      text=${ret::${#ret}-fill}
    fi

    # Insertion position and padding
    local index iend=
    if [[ $is_newline ]]; then
      index=${#_ble_edit_str}
      ble/string#repeat ' ' "$c"
      text=$'\n'$ret$text

    elif [[ $graphical ]]; then
      ble-edit/content/find-logical-eol "$bol"; local eol=$ret
      ble/textmap#get-index-at "$x" "$((by+y))"; ((index>eol&&(index=eol)))

      # left padding (when the end of the line is further to the left or there are full-width characters)
      local ax ay ac; ble/textmap#getxy.out --prefix=a "$index"
      ((ay-=by,ac=ay*cols+ax))
      if ((ac<c)); then
        ble/string#repeat ' ' "$((c-ac))"
        text=$ret$text

        # Convert tabs to blanks
        if ((index<eol)) && [[ ${_ble_edit_str:index:1} == $'\t' ]]; then
          local rx ry rc; ble/textmap#getxy.out --prefix=r "$((index+1))"
          ((rc=(ry-by)*cols+rx))
          ble/string#repeat ' ' "$((rc-c))"
          text=$text$ret
          iend=$((index+1))
        fi
      fi

      # right padding (when the end of the line is further to the right)
      if ((index<eol&&fill)); then
        ble/string#repeat ' ' "$fill"
        text=$text$ret
      fi

    else
      ble-edit/content/find-logical-eol "$bol"; local eol=$ret
      local index=$((bol+c))

      if ((index<eol)); then
        if ((fill)); then
          ble/string#repeat ' ' "$fill"
          text=$text$ret
        fi
      elif ((index>eol)); then
        ble/string#repeat ' ' "$((index-eol))"
        text=$ret$text
        index=$eol
      fi
    fi

    ble/array#push ins_beg "$index"
    ble/array#push ins_end "${iend:-$index}"
    ble/array#push ins_text "$text"
  done

  # insert in reverse order
  ble/keymap:vi/mark/start-edit-area
  local i=${#ins_beg[@]}
  while ((i--)); do
    local ibeg=${ins_beg[i]} iend=${ins_end[i]} text=${ins_text[i]}
    ble/widget/.replace-range "$ibeg" "$iend" "$text"
  done
  ble/keymap:vi/mark/end-edit-area
  ble/keymap:vi/repeat/record

  ble/keymap:vi/needs-eol-fix && ((_ble_edit_ind--))
  ble/keymap:vi/adjust-command-mode
}

function ble/widget/vi_nmap/paste.impl {
  local arg=$1 reg=$2 is_after=$3
  if [[ $reg ]]; then
    local _ble_edit_kill_ring _ble_edit_kill_type
    ble/keymap:vi/register#load "$reg"
  fi

  [[ $_ble_edit_kill_ring ]] || return 0
  local ret
  if [[ $_ble_edit_kill_type == L ]]; then
    ble/string#repeat "$_ble_edit_kill_ring" "$arg"
    local content=$ret

    local index dbeg dend
    if ((is_after)); then
      ble-edit/content/find-logical-eol; index=$ret
      if ((index==${#_ble_edit_str})); then
        content=$'\n'${content%$'\n'}
        ((dbeg=index+1,dend=index+${#content}))
      else
        ((index++,dbeg=index,dend=index+${#content}-1))
      fi
    else
      ble-edit/content/find-logical-bol
      ((index=ret,dbeg=index,dend=index+${#content}-1))
    fi

    ble/widget/.replace-range "$index" "$index" "$content"
    _ble_edit_ind=$dbeg
    ble/keymap:vi/mark/set-previous-edit-area "$dbeg" "$dend"
    ble/keymap:vi/repeat/record
    ble/widget/vi-command/first-non-space
  elif [[ $_ble_edit_kill_type == B:* ]]; then
    if ((is_after)) && ! ble-edit/content/eolp; then
      ((_ble_edit_ind++))
    fi
    ble/widget/vi_nmap/paste.impl/block "$arg"
  else
    if ((is_after)) && ! ble-edit/content/eolp; then
      ((_ble_edit_ind++))
    fi
    ble/string#repeat "$_ble_edit_kill_ring" "$arg"
    local beg=$_ble_edit_ind
    ble/widget/.insert-string "$ret"
    local end=$_ble_edit_ind
    ble/keymap:vi/mark/set-previous-edit-area "$beg" "$end"
    ble/keymap:vi/repeat/record
    [[ $_ble_keymap_vi_single_command ]] || ((_ble_edit_ind--))
    ble/keymap:vi/needs-eol-fix && ((_ble_edit_ind--))
    ble/keymap:vi/adjust-command-mode
  fi
  return 0
}

function ble/widget/vi_nmap/paste-after {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi_nmap/paste.impl "$ARG" "$REG" 1
}
function ble/widget/vi_nmap/paste-before {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi_nmap/paste.impl "$ARG" "$REG" 0
}

function ble/widget/vi-rlfunc/paste-from-clipboard {
  ble/keymap:vi/clear-arg

  local clipboard
  if ! ble/edit/get-clipboard; then
    ble/widget/.bell
    return 1
  fi

  local _ble_edit_kill_ring=$clipboard
  local _ble_edit_kill_type=
  ble/widget/vi_nmap/paste.impl 1 '' 1
  return 0
}

#------------------------------------------------------------------------------
# command: x s X C D

# nmap x, <delete>
function ble/widget/vi_nmap/kill-forward-char {
  _ble_keymap_vi_opfunc=d
  ble/widget/vi-command/forward-char
}
# nmap s
function ble/widget/vi_nmap/kill-forward-char-and-insert {
  _ble_keymap_vi_opfunc=c
  ble/widget/vi-command/forward-char
}
# nmap X
function ble/widget/vi_nmap/kill-backward-char {
  _ble_keymap_vi_opfunc=d
  ble/widget/vi-command/backward-char
}
# nmap D
function ble/widget/vi_nmap/kill-forward-line {
  _ble_keymap_vi_opfunc=d
  ble/widget/vi-command/forward-eol
}
# nmap C
function ble/widget/vi_nmap/kill-forward-line-and-insert {
  _ble_keymap_vi_opfunc=c
  ble/widget/vi-command/forward-eol
}

#------------------------------------------------------------------------------
# command: w W b B e E

function ble/widget/vi-command/forward-word.impl {
  local arg=$1 flag=$2 reg=$3 rex_word=$4
  local ifs=$_ble_term_IFS
  if [[ $flag == c && ${_ble_edit_str:_ble_edit_ind:1} != [$ifs] ]]; then
    # Note: cw cW has special behavior.
    #   http://vim-jp.org/vimdoc-ja/change.html#cw
    ble/widget/vi-command/forward-word-end.impl "$arg" "$flag" "$reg" "$rex_word" allow_here
    return "$?"
  fi
  local b=$'[ \t]' n=$'\n'
  local rex="^((($rex_word)$n?|$b+$n?|$n)($b+$n)*$b*){0,$arg}" # Stops at the beginning of a word or a blank line
  [[ ${_ble_edit_str:_ble_edit_ind} =~ $rex ]]
  local index=$((_ble_edit_ind+${#BASH_REMATCH}))
  if [[ $flag ]]; then
    # Special rules for :help word-motions (when the last word passed is at the end of a line)
    local rematch1=${BASH_REMATCH[1]}
    if local rex="$n$b*\$"; [[ $rematch1 =~ $rex ]]; then
      local suffix_len=${#BASH_REMATCH}
      ((suffix_len<${#rematch1})) &&
        ((index-=suffix_len))
    fi
  fi
  ble/widget/vi-command/exclusive-goto.impl "$index" "$flag" "$reg"
}
function ble/widget/vi-command/forward-word-end.impl {
  local arg=$1 flag=$2 reg=$3 rex_word=$4 opts=$5
  local IFS=$_ble_term_IFS
  local rex="^([$IFS]*($rex_word)?){0,$arg}" # Stops at the end of the word. Don't stop at empty lines
  local offset=1; [[ :$opts: == *:allow_here:* ]] && offset=0
  [[ ${_ble_edit_str:_ble_edit_ind+offset} =~ $rex ]]
  local index=$((_ble_edit_ind+offset+${#BASH_REMATCH}-1))
  ((index<_ble_edit_ind&&(index=_ble_edit_ind)))
  [[ ! $flag && $BASH_REMATCH && ${_ble_edit_str:index:1} == [$IFS] ]] && ble/widget/.bell
  ble/widget/vi-command/inclusive-goto.impl "$index" "$flag" "$reg"
}
function ble/widget/vi-command/backward-word.impl {
  local arg=$1 flag=$2 reg=$3 rex_word=$4
  local b=$'[ \t]' n=$'\n'
  local rex="((($rex_word)$n?|$b+$n?|$n)($b+$n)*$b*){0,$arg}\$" # Stops at the beginning of a word or a blank line
  [[ ${_ble_edit_str::_ble_edit_ind} =~ $rex ]]
  local index=$((_ble_edit_ind-${#BASH_REMATCH}))
  ble/widget/vi-command/exclusive-goto.impl "$index" "$flag" "$reg"
}
function ble/widget/vi-command/backward-word-end.impl {
  local arg=$1 flag=$2 reg=$3 rex_word=$4
  local i=$'[ \t\n]' b=$'[ \t]' n=$'\n' w="($rex_word)"
  local rex1="(^|$w$n?|$n)($b+$n)*$b*"
  local rex="($rex1)($rex1){$((arg-1))}($rex_word|$i)\$" # Stops at the end of a word or a blank line
  [[ ${_ble_edit_str::_ble_edit_ind+1} =~ $rex ]]
  local index=$((_ble_edit_ind+1-${#BASH_REMATCH}))
  local rematch3=${BASH_REMATCH[3]} # first ($rex_word)
  [[ $rematch3 ]] && ((index+=${#rematch3}-1))
  ble/widget/vi-command/inclusive-goto.impl "$index" "$flag" "$reg"
}

# motion w
function ble/widget/vi-command/forward-vword {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/forward-word.impl "$ARG" "$FLAG" "$REG" "$_ble_keymap_vi_REX_WORD"
}
# motion e
function ble/widget/vi-command/forward-vword-end {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/forward-word-end.impl "$ARG" "$FLAG" "$REG" "$_ble_keymap_vi_REX_WORD"
}
# motion b
function ble/widget/vi-command/backward-vword {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/backward-word.impl "$ARG" "$FLAG" "$REG" "$_ble_keymap_vi_REX_WORD"
}
# motion ge
function ble/widget/vi-command/backward-vword-end {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/backward-word-end.impl "$ARG" "$FLAG" "$REG" "$_ble_keymap_vi_REX_WORD"
}
# motion W
function ble/widget/vi-command/forward-uword {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/forward-word.impl "$ARG" "$FLAG" "$REG" $'[^ \t\n]+'
}
# motion E
function ble/widget/vi-command/forward-uword-end {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/forward-word-end.impl "$ARG" "$FLAG" "$REG" $'[^ \t\n]+'
}
# motion B
function ble/widget/vi-command/backward-uword {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/backward-word.impl "$ARG" "$FLAG" "$REG" $'[^ \t\n]+'
}
# motion gE
function ble/widget/vi-command/backward-uword-end {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/backward-word-end.impl "$ARG" "$FLAG" "$REG" $'[^ \t\n]+'
}

#------------------------------------------------------------------------------
# command: [cdy]?[|HL] G gg

# nmap |
function ble/widget/vi-command/nth-column {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1

  local ret index
  ble-edit/content/find-logical-bol; local bol=$ret
  ble-edit/content/find-logical-eol; local eol=$ret
  if ble/edit/use-textmap; then
    local bx by; ble/textmap#getxy.cur --prefix=b "$bol" # Note: The first line is bx!=0 at the prompt
    local ex ey; ble/textmap#getxy.cur --prefix=e "$eol"
    local dstx=$((bx+ARG-1)) dsty=$by cols=${COLUMNS:-80}
    ((dsty+=dstx/cols,dstx%=cols))
    ((dsty>ey&&(dsty=ey,dstx=ex)))
    ble/textmap#get-index-at "$dstx" "$dsty" # local variable "index" is set here

    # Note: For some reason, when I run d or c in normal mode, it doesn't go to the end of the line, but
    # Visual mode seems to allow you to go to the end of the line.
    [[ $_ble_decode_keymap != vi_[xs]map ]] &&
      ble-edit/content/nonbol-eolp "$index" && ((index--))
  else
    [[ $_ble_decode_keymap != vi_[xs]map ]] &&
      ble-edit/content/nonbol-eolp "$eol" && ((eol--))
    ((index=bol+ARG-1,index>eol&&(index=eol)))
  fi

  ble/widget/vi-command/exclusive-goto.impl "$index" "$FLAG" "$REG" nobell
}

# nmap H
function ble/widget/vi-command/nth-line {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  [[ $FLAG ]] || ble/keymap:vi/mark/set-jump # ``
  ble/widget/vi-command/linewise-goto.impl "0:$((ARG-1))" "$FLAG" "$REG"
}
# nmap L
function ble/widget/vi-command/nth-last-line {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  [[ $FLAG ]] || ble/keymap:vi/mark/set-jump # ``
  ble/widget/vi-command/linewise-goto.impl "${#_ble_edit_str}:$((-(ARG-1)))" "$FLAG" "$REG"
}

# nmap gg in history
function ble/widget/vi-command/history-beginning {
  local ARG FLAG REG; ble/keymap:vi/get-arg 0
  if [[ $FLAG ]]; then
    if ((ARG)); then
      _ble_keymap_vi_oparg=$ARG
    else
      _ble_keymap_vi_oparg=
    fi
    _ble_keymap_vi_opfunc=$FLAG
    _ble_keymap_vi_reg=$REG
    ble/widget/vi-command/nth-line
    return "$?"
  fi

  if ((ARG)); then
    ble-edit/history/goto "$((ARG-1))"
  else
    ble/widget/history-beginning
  fi
  ble/keymap:vi/needs-eol-fix && ((_ble_edit_ind--))
  ble/keymap:vi/adjust-command-mode
  return 0
}

# nmap G in history
function ble/widget/vi-command/history-end {
  local ARG FLAG REG; ble/keymap:vi/get-arg 0
  if [[ $FLAG ]]; then
    _ble_keymap_vi_opfunc=$FLAG
    _ble_keymap_vi_reg=$REG
    if ((ARG)); then
      _ble_keymap_vi_oparg=$ARG
      ble/widget/vi-command/nth-line
    else
      _ble_keymap_vi_oparg=
      ble/widget/vi-command/nth-last-line
    fi
    return "$?"
  fi

  if ((ARG)); then
    ble-edit/history/goto "$((ARG-1))"
  else
    ble/widget/history-end
  fi
  ble/keymap:vi/needs-eol-fix && ((_ble_edit_ind--))
  ble/keymap:vi/adjust-command-mode
  return 0
}

function ble/widget/vi-command/.history-goto {
  local new_index=$1 old_index
  ble/history/get-index -v old_index
  if ((new_index==old_index)); then
    ble/widget/vi-command/bell 'already on history !'"$new_index"
    return 1
  fi

  local point_opts point point_x
  if ((new_index>old_index)); then
    point_opts=forward
  else
    point_opts=backward
  fi

  ble-edit/history/goto "$new_index"

  # adjust the cursor position
  ble/keymap:vi/needs-eol-fix && ((_ble_edit_ind--))
  ble/keymap:vi/adjust-command-mode
}

function ble/widget/vi-command/history-next {
  if [[ $_ble_history_prefix || $_ble_history_load_done ]]; then
    local ARG FLAG REG; ble/keymap:vi/get-arg 1
    ble/history/initialize
    ble/widget/vi-command/.history-goto "$((_ble_history_INDEX+ARG))"
  else
    ble/keymap:vi/clear-arg
    ble/widget/vi-command/bell
  fi
}
function ble/widget/vi-command/history-prev {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/history/initialize
  ble/widget/vi-command/.history-goto "$((_ble_history_INDEX-ARG))"
}
function ble/widget/vi-command/history-goto {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  if ((--ARG<0)); then
    ble/history/initialize
    ((ARG+=_ble_history_COUNT))
  fi
  ble/widget/vi-command/.history-goto "$ARG"
}

# nmap G
#   Note: In vim G has this behavior, but in blesh it actually
#     This is not used by default since vi-command/history-end is bound.
function ble/widget/vi-command/last-line {
  local ARG FLAG REG; ble/keymap:vi/get-arg 0
  [[ $FLAG ]] || ble/keymap:vi/mark/set-jump # ``
  if ((ARG)); then
    ble/widget/vi-command/linewise-goto.impl "0:$((ARG-1))" "$FLAG" "$REG"
  else
    ble/widget/vi-command/linewise-goto.impl "${#_ble_edit_str}:0" "$FLAG" "$REG"
  fi
}

# nmap C-home / gg
#   Note: The only difference from nth-line (H) is that it is not a jump.
#   Note: In vim, gg also has this behavior, but in blesh, gg is
#     By default it is bound to vi-command/history-beginning.
function ble/widget/vi-command/first-nol {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/linewise-goto.impl "0:$((ARG-1))" "$FLAG" "$REG"
}

# nmap C-end
function ble/widget/vi-command/last-eol {
  local ARG FLAG REG; ble/keymap:vi/get-arg ''
  local ret index
  if [[ $ARG ]]; then
    ble-edit/content/find-logical-eol 0 "$((ARG-1))"; index=$ret
  else
    ble-edit/content/find-logical-eol "${#_ble_edit_str}"; index=$ret
  fi
  ble/keymap:vi/needs-eol-fix "$index" && ((index--))
  ble/widget/vi-command/inclusive-goto.impl "$index" "$FLAG" "$REG" nobell
}

#------------------------------------------------------------------------------
# command: r gr

## @fn ble/widget/vi_nmap/replace-char.impl code [overwrite_mode]
##   @param[in] overwrite_mode
##     Specify how to insert the replacement character.
function ble/widget/vi_nmap/replace-char.impl {
  local key=$1 overwrite_mode=${2:-R}
  _ble_edit_overwrite_mode=

  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  local ret
  if ((key==(_ble_decode_Ctrl|91))); then # C-[
    ble/keymap:vi/adjust-command-mode
    return 27
  elif ! ble/keymap:vi/k2c "$key"; then
    ble/widget/vi-command/bell
    return 1
  fi

  local pos=$_ble_edit_ind

  ble/keymap:vi/mark/start-edit-area
  {
    local -a KEYS; KEYS=("$ret")
    local _ble_edit_arg=$ARG
    local _ble_edit_overwrite_mode=$overwrite_mode
    local ble_widget_self_insert_opts=nolineext
    ble/widget/self-insert
    ble/util/unlocal KEYS
  }
  ble/keymap:vi/mark/end-edit-area
  ble/keymap:vi/repeat/record

  ((pos<_ble_edit_ind&&_ble_edit_ind--))
  ble/keymap:vi/adjust-command-mode
  return 0
}

function ble/widget/vi_nmap/replace-char.hook {
  ble/widget/vi_nmap/replace-char.impl "$1" R
}
function ble/widget/vi_nmap/replace-char {
  _ble_edit_overwrite_mode=R
  ble/keymap:vi/async-read-char ble/widget/vi_nmap/replace-char.hook
}
function ble/widget/vi_nmap/virtual-replace-char.hook {
  ble/widget/vi_nmap/replace-char.impl "$1" 1
}
function ble/widget/vi_nmap/virtual-replace-char {
  _ble_edit_overwrite_mode=1
  ble/keymap:vi/async-read-char ble/widget/vi_nmap/virtual-replace-char.hook
}

#------------------------------------------------------------------------------
# command: J gJ o O

# nmap J
function ble/widget/vi_nmap/connect-line-with-space {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  local ret
  ble-edit/content/find-logical-eol; local eol1=$ret
  ble-edit/content/find-logical-eol "$_ble_edit_ind" "$((ARG<=1?1:ARG-1))"; local eol2=$ret
  ble-edit/content/find-logical-bol "$eol2"; local bol2=$ret
  if ((eol1<eol2)); then
    local text=${_ble_edit_str:eol1:eol2-eol1}
    text=${text//$'\n'/' '}
    ble/widget/.replace-range "$eol1" "$eol2" "$text"
    ble/keymap:vi/mark/set-previous-edit-area "$eol1" "$eol2"
    ble/keymap:vi/repeat/record
    _ble_edit_ind=$((bol2-1))
    ble/keymap:vi/adjust-command-mode
    return 0
  else
    ble/widget/vi-command/bell
    return 1
  fi
}
# nmap gJ
function ble/widget/vi_nmap/connect-line {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  local ret
  ble-edit/content/find-logical-eol; local eol1=$ret
  ble-edit/content/find-logical-eol "$_ble_edit_ind" "$((ARG<=1?1:ARG-1))"; local eol2=$ret
  ble-edit/content/find-logical-bol "$eol2"; local bol2=$ret
  if ((eol1<eol2)); then
    local text=${_ble_edit_str:eol1:bol2-eol1}
    text=${text//$'\n'}
    ble/widget/.replace-range "$eol1" "$bol2" "$text"
    local delta=$((${#text}-(bol2-eol1)))
    ble/keymap:vi/mark/set-previous-edit-area "$eol1" "$((eol2+delta))"
    ble/keymap:vi/repeat/record
    _ble_edit_ind=$((bol2+delta))
    ble/keymap:vi/adjust-command-mode
    return 0
  else
    ble/widget/vi-command/bell
    return 1
  fi
}

function ble/widget/vi_nmap/insert-mode-at-forward-line {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  local ret
  ble-edit/content/find-logical-bol; local bol=$ret
  ble-edit/content/find-logical-eol; local eol=$ret
  ble-edit/content/find-non-space "$bol"; local indent=${_ble_edit_str:bol:ret-bol}
  _ble_edit_ind=$eol
  ble/widget/.insert-string $'\n'"$indent"
  ble/widget/vi_nmap/.insert-mode "$ARG"
  ble/keymap:vi/repeat/record
  return 0
}
function ble/widget/vi_nmap/insert-mode-at-backward-line {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  local ret
  ble-edit/content/find-logical-bol; local bol=$ret
  ble-edit/content/find-non-space "$bol"; local indent=${_ble_edit_str:bol:ret-bol}
  _ble_edit_ind=$bol
  ble/widget/.insert-string "$indent"$'\n'
  _ble_edit_ind=$((bol+${#indent}))
  ble/widget/vi_nmap/.insert-mode "$ARG"
  ble/keymap:vi/repeat/record
  return 0
}

#------------------------------------------------------------------------------
# command: f F t F


## @var _ble_keymap_vi_char_search
##   Records the previous search for ble/widget/vi-command/search-char.impl/core.
_ble_keymap_vi_char_search=

## @fn ble/widget/vi-command/search-char.impl/core opts key|char
##
##   @param[in] opts
##     A string consisting of the following flag characters:
##
##     b Indicates backward search.
##
##     p Indicates to move one character before the found character.
##
##     r Indicates a repeated search.
##       In this case, the first argument is interpreted as the character char.
##       In other cases, the first argument is interpreted as the key code key.
##
##   @param[in] key
##   @param[in] char
##     key specifies the key code to search for.
##     char specifies the character to search for.
##     Which way it is interpreted depends on the opts flag r, which will be explained later.
##
##
function ble/widget/vi-command/search-char.impl/core {
  local opts=$1 key=$2
  local ARG FLAG REG; ble/keymap:vi/get-arg 1

  local ret c
  [[ $opts != *p* ]]; local isprev=$?
  [[ $opts != *r* ]]; local isrepeat=$?
  if ((isrepeat)); then
    c=$key
  elif ((key==(_ble_decode_Ctrl|91))); then # C-[ -> cancel
    return 27
  else
    ble/keymap:vi/k2c "$key" || return 1
    ble/util/c2s "$ret"; local c=$ret
  fi
  [[ $c ]] || return 1

  ((isrepeat)) || _ble_keymap_vi_char_search=$c$opts

  local index
  if [[ $opts == *b* ]]; then
    # backward search
    ble-edit/content/find-logical-bol; local bol=$ret
    local base=$_ble_edit_ind
    ((isrepeat&&isprev&&base--,base>bol)) || return 1
    local line=${_ble_edit_str:bol:base-bol}
    ble/string#last-index-of "$line" "$c" "$ARG"
    ((ret>=0)) || return 1

    ((index=bol+ret,isprev&&index++))
    ble/widget/vi-command/exclusive-goto.impl "$index" "$FLAG" "$REG" nobell
    return "$?"
  else
    # forward search
    ble-edit/content/find-logical-eol; local eol=$ret
    local base=$((_ble_edit_ind+1))
    ((isrepeat&&isprev&&base++,base<eol)) || return 1

    local line=${_ble_edit_str:base:eol-base}
    ble/string#index-of "$line" "$c" "$ARG"
    ((ret>=0)) || return 1

    ((index=base+ret,isprev&&index--))
    ble/widget/vi-command/inclusive-goto.impl "$index" "$FLAG" "$REG" nobell
    return "$?"
  fi
}
function ble/widget/vi-command/search-char.impl {
  if ble/widget/vi-command/search-char.impl/core "$1" "$2"; then
    ble/keymap:vi/adjust-command-mode
    return 0
  else
    ble/widget/vi-command/bell
    return 1
  fi
}

function ble/widget/vi-command/search-forward-char {
  ble/keymap:vi/async-read-char ble/widget/vi-command/search-char.impl f
}
function ble/widget/vi-command/search-forward-char-prev {
  ble/keymap:vi/async-read-char ble/widget/vi-command/search-char.impl fp
}
function ble/widget/vi-command/search-backward-char {
  ble/keymap:vi/async-read-char ble/widget/vi-command/search-char.impl b
}
function ble/widget/vi-command/search-backward-char-prev {
  ble/keymap:vi/async-read-char ble/widget/vi-command/search-char.impl bp
}
function ble/widget/vi-command/search-char-repeat {
  [[ $_ble_keymap_vi_char_search ]] || ble/widget/.bell
  local c=${_ble_keymap_vi_char_search::1} opts=${_ble_keymap_vi_char_search:1}
  ble/widget/vi-command/search-char.impl "r$opts" "$c"
}
function ble/widget/vi-command/search-char-reverse-repeat {
  [[ $_ble_keymap_vi_char_search ]] || ble/widget/.bell
  local c=${_ble_keymap_vi_char_search::1} opts=${_ble_keymap_vi_char_search:1}
  if [[ $opts == *b* ]]; then
    opts=f${opts//b}
  else
    opts=b${opts//f}
  fi
  ble/widget/vi-command/search-char.impl "r$opts" "$c"
}

#------------------------------------------------------------------------------
# command: %

## @fn ble/widget/vi-command/search-matchpair/.search-forward
##   @var[in] _ble_edit_str, ch1, ch2, index
##   @var[out] ret
function ble/widget/vi-command/search-matchpair/.search-forward {
  ble/string#index-of-chars "$_ble_edit_str" "$ch1$ch2" "$((index+1))"
}
function ble/widget/vi-command/search-matchpair/.search-backward {
  ble/string#last-index-of-chars "$_ble_edit_str" "$ch1$ch2" "$index"
}

function ble/widget/vi-command/search-matchpair-or {
  local ARG FLAG REG; ble/keymap:vi/get-arg -1
  if ((ARG>=0)); then
    _ble_keymap_vi_oparg=$ARG
    _ble_keymap_vi_opfunc=$FLAG
    _ble_keymap_vi_reg=$REG
    ble/widget/"$@"
    return "$?"
  fi

  local open='({[' close=')}]'

  local ret
  ble-edit/content/find-logical-eol; local eol=$ret
  if ! ble/string#index-of-chars "${_ble_edit_str::eol}" '(){}[]' "$_ble_edit_ind"; then
    ble/keymap:vi/adjust-command-mode
    return 1
  fi
  local index1=$ret ch1=${_ble_edit_str:ret:1}

  if [[ $ch1 == ["$open"] ]]; then
    local i=${open%%"$ch"*}; i=${#i}
    local ch2=${close:i:1}
    local searcher=ble/widget/vi-command/search-matchpair/.search-forward
  else
    local i=${close%%"$ch"*}; i=${#i}
    local ch2=${open:i:1}
    local searcher=ble/widget/vi-command/search-matchpair/.search-backward
  fi

  local index=$index1 count=1
  while "$searcher"; do
    index=$ret
    if [[ ${_ble_edit_str:ret:1} == "$ch1" ]]; then
      ((++count))
    else
      ((--count==0)) && break
    fi
  done

  if ((count)); then
    ble/keymap:vi/adjust-command-mode
    return 1
  fi

  [[ $FLAG ]] || ble/keymap:vi/mark/set-jump # ``
  ble/widget/vi-command/inclusive-goto.impl "$index" "$FLAG" "$REG" nobell
}

function ble/widget/vi-command/percentage-line {
  local ARG FLAG REG; ble/keymap:vi/get-arg 0
  local ret; ble/string#count-char "$_ble_edit_str" $'\n'; local nline=$((ret+1))
  local iline=$(((ARG*nline+99)/100))
  ble/widget/vi-command/linewise-goto.impl "0:$((iline-1))" "$FLAG" "$REG"
}

#------------------------------------------------------------------------------
# command: go

function ble/widget/vi-command/nth-byte {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ((ARG--))
  local offset=0 text=$_ble_edit_str len=${#_ble_edit_str}
  local left nleft ret
  while ((ARG>0&&len>1)); do
    left=${text::len/2}
    ble/util/strlen "$left"; nleft=$ret
    if ((ARG<nleft)); then
      text=$left
      ((len/=2))
    else
      text=${text:len/2}
      ((offset+=len/2,
        ARG-=nleft,
        len-=len/2))
    fi
  done
  ble/keymap:vi/needs-eol-fix "$offset" && ((offset--))
  ble/widget/vi-command/exclusive-goto.impl "$offset" "$FLAG" "$REG" nobell
}

#------------------------------------------------------------------------------
# text objects

_ble_keymap_vi_text_object=

## @fn ble/keymap:vi/text-object/word.impl      arg flag reg type
## @fn ble/keymap:vi/text-object/quote.impl     arg flag reg type
## @fn ble/keymap:vi/text-object/block.impl     arg flag reg type
## @fn ble/keymap:vi/text-object/tag.impl       arg flag reg type
## @fn ble/keymap:vi/text-object/sentence.impl  arg flag reg type
## @fn ble/keymap:vi/text-object/paragraph.impl arg flag reg type
##
## @exit Returns 0 when processing of the text object is complete.
##


## @fn ble/keymap:vi/text-object/word.extend-forward
##   Note #D0855
##   @var[in] type arg
##   @var[in] rex_word nl space ifs
##   @var[in,out] beg end
##   @var[out] flags
##     A indicates that there is a blank space at the beginning.
##     Z indicates that there is a space at the end.
##     I Indicates that an attempt was made to import the first half of the word.
function ble/keymap:vi/text-object/word.extend-forward {
  local rex

  flags=
  [[ ${_ble_edit_str:beg:1} == ["$ifs"] ]] && flags=${flags}A
  if [[ $_ble_decode_keymap != vi_[xs]map ]]; then
    flags=${flags}I
  elif ((_ble_edit_mark==_ble_edit_ind)); then
    flags=${flags}I
  fi

  local rex_unit
  local W='('$rex_word')' b='['$space']' n=$nl
  if [[ $type == i* ]]; then
    rex_unit='^'$W'|^'$b'+|^'$n
  elif [[ $type == a* ]]; then
    rex_unit='^'$W$b'*|^'$b'+'$W'|^'$b'*'$n'('$b'+'$n')*('$n'|'$b'*'$W')'
  else
    return 1
  fi

  local i rematch=
  for ((i=0;i<arg;i++)); do
    if ((i==0)) && [[ $flags == *I* ]]; then
      # capture word front
      rex='('$rex_word')$|['$space']*['$ifs']$'
      [[ ${_ble_edit_str::beg+1} =~ $rex ]] &&
        ((beg-=${#BASH_REMATCH}-1,end=beg))
    else
      [[ ${_ble_edit_str:end:1} == $'\n' ]] && ((end++))
    fi

    [[ ${_ble_edit_str:end} =~ $rex_unit ]] || return 1
    rematch=$BASH_REMATCH
    ((end+=${#rematch}))

    # Note: The regular expression for aw reads double newlines but backs up.
    [[ $type == a* && $rematch == *$'\n\n' ]] && ((end--))

    # Note: For some reason, Vim only removes the newline on the first match.
    #   By making the line break of the last match exclusive,
    #   It seems like the caller is removing it.
    # Note: aw never matches "non-blank to newline".
    if ((i==0)) && [[ $flags == *I* ]] || ((i==arg-1)); then
      [[ $type == i* && $rematch == *"$nl" ]] && ((end--))
    fi
  done

  [[ ${_ble_edit_str:end-1:1} == *["$ifs"] ]] && flags=${flags}Z

  if [[ $type == a* && $flags != *[AZ]* ]]; then
    # When aw does not include spaces before or after, capture leading spaces
    # Note: In the vim implementation (search.c (current_word))
    #   Exclusive at the beginning of the line also captures leading blanks, but
    #   It's a mystery because it is not normal for aw to be exclusive at the beginning of a line.
    #   oneleft() may fail in the middle of virtual_active(), but
    #   I don't think this condition was added with this situation in mind.
    if rex='['$space']+$'; [[ ${_ble_edit_str::beg} =~ $rex ]]; then
      local p=$((beg-${#BASH_REMATCH}))
      ble-edit/content/bolp "$p" || beg=$p
    fi
  fi

  return 0
}
## @fn ble/keymap:vi/text-object/word.extend-backward
##   Note #D0855
##   @var[in,out] beg
##   @var[in] type arg
##   @var[in] rex_word nl space ifs
function ble/keymap:vi/text-object/word.extend-backward {
  local rex_unit=
  local W='('$rex_word')' b='['$space']' n=$nl
  if [[ $type == i* ]]; then
    rex_unit='('$W'|'$b'+)'$n'?$|'$n'$'
  elif [[ $type == a* ]]; then
    rex_unit=$b'*'$W$n'?$|'$W'?'$b'*('$n'('$b'+'$n')*'$b'*)?('$b$n'?|'$n')$'
  else
    return 1
  fi

  local count=$arg
  while ((count--)); do
    [[ ${_ble_edit_str::beg} =~ $rex_unit ]] || return 1
    ((beg-=${#BASH_REMATCH}))

    # Note: Following vim's behavior
    local match=${BASH_REMATCH%"$nl"}
    if ((beg==0&&${#match}>=2)); then
      if [[ $type == i* ]]; then
        [[ $match == ["$space"]* ]] && beg=1
      elif [[ $type == a* ]]; then
        [[ $match == *[!"$ifs"] ]] && beg=1
      fi
    fi
  done

  return 0
}

function ble/keymap:vi/text-object/word.impl {
  local arg=$1 flag=$2 reg=$3 type=$4
  local space=$' \t' nl=$'\n' ifs=$_ble_term_IFS
  ((arg==0)) && return 0

  local rex_word
  if [[ $type == ?W ]]; then
    rex_word="[^$ifs]+"
  else
    rex_word=$_ble_keymap_vi_REX_WORD
  fi

  local index=$_ble_edit_ind
  if [[ $_ble_decode_keymap == vi_[xs]map ]]; then
    if ((index<_ble_edit_mark)); then
      local beg=$index
      if ble/keymap:vi/text-object/word.extend-backward; then
        _ble_edit_ind=$beg
      else
        _ble_edit_ind=0
        ble/widget/.bell
      fi
      ble/keymap:vi/adjust-command-mode
      return 0
    fi
  fi

  local beg=$index end=$index flags=
  if ! ble/keymap:vi/text-object/word.extend-forward; then
    # Match failure
    index=${#_ble_edit_str}
    ble-edit/content/nonbol-eolp "$index" && ((index--))
    _ble_edit_ind=$index
    ble/widget/vi-command/bell
    return 1
  fi

  if [[ $_ble_decode_keymap == vi_[xs]map ]]; then
    ((end--))
    ble-edit/content/nonbol-eolp "$end" && ((end--))
    ((beg<_ble_edit_mark)) && _ble_edit_mark=$beg
    [[ $_ble_edit_mark_active == vi_line ]] &&
      _ble_edit_mark_active=vi_char
    _ble_edit_ind=$end
    ble/keymap:vi/adjust-command-mode
    return 0
  else
    ble/widget/vi-command/exclusive-range.impl "$beg" "$end" "$flag" "$reg"
  fi
}

## @fn ble/keymap:vi/text-object:quote/is-closing-quote index
##   @var[in] quote
function ble/keymap:vi/text-object:quote/is-closing-quote {
  local index=${1:-$_ble_edit_ind}
  [[ ${_ble_edit_str:index:1} == "$quote" ]] || return 1
  local ret
  ble-edit/content/find-logical-bol "$index"; local bol=$ret
  ble/string#count-char "${_ble_edit_str:bol:_ble_edit_ind-bol}" "$quote"
  ((ret%2==1))
}
## @fn ble/keymap:vi/text-object:quote/.next [index]
##   @var[in] quote
##   @var[out] ret
function ble/keymap:vi/text-object:quote/.next {
  local index=${1:-$((_ble_edit_ind+1))} nl=$'\n'
  local rex="^[^$nl$quote]*$quote"
  [[ ${_ble_edit_str:index} =~ $rex ]] || return 1
  ((ret=index+${#BASH_REMATCH}-1))
  return 0
}
## @fn ble/keymap:vi/text-object:quote/.prev [index]
##   @var[in] quote
##   @var[out] ret
function ble/keymap:vi/text-object:quote/.prev {
  local index=${1:-_ble_edit_ind} nl=$'\n'
  local rex="$quote[^$nl$quote]*\$"
  [[ ${_ble_edit_str::index} =~ $rex ]] || return 1
  ((ret=index-${#BASH_REMATCH}))
  return 0
}
function ble/keymap:vi/text-object/quote.impl {
  local arg=$1 flag=$2 reg=$3 type=$4
  local ret quote=${type:1}
  if [[ $_ble_decode_keymap == vi_[xs]map ]]; then
    if ble/keymap:vi/text-object:quote/.xmap; then
      ble/keymap:vi/adjust-command-mode
      return 0
    else
      ble/widget/vi-command/bell
      return 1
    fi
  fi

  local beg= end=
  if [[ ${_ble_edit_str:_ble_edit_ind:1} == "$quote" ]]; then
    ble-edit/content/find-logical-bol; local bol=$ret
    ble/string#count-char "${_ble_edit_str:bol:_ble_edit_ind-bol}" "$quote"
    if ((ret%2==1)); then
      # current closing quote
      ((end=_ble_edit_ind+1))
      ble/keymap:vi/text-object:quote/.prev && beg=$ret
    else
      ((beg=_ble_edit_ind))
      ble/keymap:vi/text-object:quote/.next && end=$((ret+1))
    fi
  elif ble/keymap:vi/text-object:quote/.prev && beg=$ret; then
    ble/keymap:vi/text-object:quote/.next && end=$((ret+1))
  elif ble/keymap:vi/text-object:quote/.next && beg=$ret; then
    ble/keymap:vi/text-object:quote/.next "$((beg+1))" && end=$((ret+1))
  fi

  if [[ $beg && $end ]]; then
    [[ $type == i* || arg -gt 1 ]] && ((beg++,end--))
    ble/widget/vi-command/exclusive-range.impl "$beg" "$end" "$flag" "$reg"
  else
    ble/widget/vi-command/bell
    return 1
  fi
}
## @fn ble/keymap:vi/text-object:quote/.expand-xmap-range mode
##   @param[in] mode
##   @var[in,out] beg
##   @var[in,out] end
function ble/keymap:vi/text-object:quote/.expand-xmap-range {
  local inclusive=$1
  ((end++))
  if ((inclusive==2)); then
    local rex
    rex=$'^[ \t]+'; [[ ${_ble_edit_str:end} =~ $rex ]] && ((end+=${#BASH_REMATCH}))
  elif ((inclusive==0&&end-beg>2)); then
    ((beg++,end--))
  fi
}
## @fn ble/keymap:vi/text-object:quote/.xmap
##   @var[in] quote
function ble/keymap:vi/text-object:quote/.xmap {
  # Fails if it spans multiple lines
  local min=$_ble_edit_ind max=$_ble_edit_mark
  ((min>max)) && local min=$max max=$min
  [[ ${_ble_edit_str:min:max+1-min} == *$'\n'* ]] && return 1

  local inclusive=0
  if [[ $type == a* ]]; then
    inclusive=2
  elif ((arg>1)); then
    inclusive=1
  fi

  local ret
  if ((_ble_edit_ind==_ble_edit_mark)); then
    ble/keymap:vi/text-object:quote/.prev "$((_ble_edit_ind+1))" ||
      ble/keymap:vi/text-object:quote/.next "$((_ble_edit_ind+1))" || return 1
    if ble/keymap:vi/text-object:quote/is-closing-quote; then
      local end=$ret
      ble/keymap:vi/text-object:quote/.prev "$end" || return 1
      local beg=$ret
    else
      local beg=$ret
      ble/keymap:vi/text-object:quote/.next "$((beg+1))" || return 1
      local end=$ret
    fi
    ble/keymap:vi/text-object:quote/.expand-xmap-range "$inclusive"
    _ble_edit_mark=$beg
    _ble_edit_ind=$((end-1))
    return 0
  elif ((_ble_edit_ind>_ble_edit_mark)); then
    local updates_mark=
    if [[ ${_ble_edit_str:_ble_edit_ind:1} == "$quote" ]]; then
      # When there is " at the current position.
      ble/keymap:vi/text-object:quote/.next "$((_ble_edit_ind+1))" || return 1; local beg=$ret
      if ble/keymap:vi/text-object:quote/.next "$((beg+1))"; then
        local end=$ret
      else
        local end=$beg beg=$_ble_edit_ind
      fi
    else
      # The first right after the current position (the even-numbered " on that line) and the corresponding left"
      ble-edit/content/find-logical-bol; local bol=$ret
      ble/string#count-char "${_ble_edit_str:bol:_ble_edit_ind-bol}" "$quote"
      if ((ret%2==0)); then
        ble/keymap:vi/text-object:quote/.next "$((_ble_edit_ind+1))" || return 1; local beg=$ret
        ble/keymap:vi/text-object:quote/.next "$((beg+1))" || return 1; local end=$ret
      else
        ble/keymap:vi/text-object:quote/.prev "$_ble_edit_ind" || return 1; local beg=$ret
        ble/keymap:vi/text-object:quote/.next "$((_ble_edit_ind+1))" || return 1; local end=$ret
      fi
      local i1=$((_ble_edit_mark?_ble_edit_mark-1:0))
      [[ ${_ble_edit_str:i1:_ble_edit_ind-i1} != *"$quote"* ]] && updates_mark=1
    fi

    ble/keymap:vi/text-object:quote/.expand-xmap-range "$inclusive"
    [[ $updates_mark ]] && _ble_edit_mark=$beg
    _ble_edit_ind=$((end-1))
    return 0
  else
    ble-edit/content/find-logical-bol; local bol=$ret nl=$'\n'
    local rex="^([^$nl$quote]*$quote[^$nl$quote]*$quote)*[^$nl$quote]*$quote"
    [[ ${_ble_edit_str:bol:_ble_edit_ind-bol} =~ $rex ]] || return 1
    local beg=$((bol+${#BASH_REMATCH}-1))
    ble/keymap:vi/text-object:quote/.next "$((beg+1))" || return 1
    local end=$ret

    ble/keymap:vi/text-object:quote/.expand-xmap-range "$inclusive"
    [[ ${_ble_edit_str:_ble_edit_ind:_ble_edit_mark+2-_ble_edit_ind} != *"$quote"* ]] && _ble_edit_mark=$((end-1))
    _ble_edit_ind=$beg
    return 0
  fi
}

## @fn ble/keymap:vi/text-object:block/.prev-matching-lparen [index [depth]]
function ble/keymap:vi/text-object:block/.prev-matching-lparen {
  local index=${1:-$_ble_edit_ind} goal_count=${2:-1}

  local p=$index count=0
  while ble/string#last-index-of-chars "$_ble_edit_str" "$rparen$lparen" "$p"; do
    p=$ret
    if [[ ${_ble_edit_str:ret:1} == "$lparen" ]]; then
      ((++count==goal_count)) && return 0
    else
      ((--count))
    fi
  done
  ret=$count
  return 1
}

## @fn ble/keymap:vi/text-object:block/.next-matching-rparen [index [depth]]
##   @var[out] ret
##     The position of the right paren is stored when the function succeeded.
##     The nesting level of the current context relative to the end of the
##     string is stored when the function failed.
function ble/keymap:vi/text-object:block/.next-matching-rparen {
  local index=${1:-$_ble_edit_ind} goal_count=${2:-1}

  local p=$index count=0
  while ble/string#index-of-chars "$_ble_edit_str" "$rparen$lparen" "$p"; do
    p=$((ret+1))
    if [[ ${_ble_edit_str:ret:1} == "$rparen" ]]; then
      ((++count==goal_count)) && return 0
    else
      ((--count))
    fi
  done
  ret=$count
  return 1
}

## @fn ble/keymap:vi/text-object:block/.next-matching-lparen [index [depth]]
function ble/keymap:vi/text-object:block/.next-matching-lparen {
  local index=${1:-$_ble_edit_ind} goal_count=${2:-1}

  local p=$index count=0
  while ble/string#index-of-chars "$_ble_edit_str" "$rparen$lparen" "$p"; do
    p=$((ret+1))
    if [[ ${_ble_edit_str:ret:1} == "$rparen" ]]; then
      ((++count==goal_count)) && { ret=$count; return 1; }
    else
      ((count+1==goal_count)) && return 0
      ((--count))
    fi
  done
  ret=$count
  return 1
}

## @fn ble/keymap:vi/text-object:block/.expand-one-level p1
##   @var[ref] beg end
function ble/keymap:vi/text-object:block/.expand-one-level {
  local p1=$1 beg1= end1= ret
  ble/keymap:vi/text-object:block/.prev-matching-lparen "$p1" && beg1=$ret
  ble/keymap:vi/text-object:block/.next-matching-rparen "$p1" && end1=$ret
  if [[ $beg1 && $end1 ]]; then
    beg=$beg1 end=$end1
  elif [[ $beg1 || $end1 ]]; then
    return 1
  fi
}

## @fn ble/keymap:vi/text-object:block/.get-outer-range beg end
##   @var[out] outer_beg outer_end
function ble/keymap:vi/text-object:block/.outer-range {
  outer_beg=$1 outer_end=$2
  if [[ $type == i* ]]; then
    case ${_ble_edit_str::outer_beg} in
    (*"$lparen"$'\n') ((outer_beg-=2)) ;;
    (*"$lparen") ((outer_beg--)) ;;
    esac
    case ${_ble_edit_str:outer_end+1} in
    ($'\n'"$rparen"*) ((outer_end+=2)) ;;
    ("$rparen"*) ((outer_end++)) ;;
    esac
  fi
}

## @fn ble/keymap:vi/text-object:block/.search-block min max L R [opts]
##   @var[out] beg end
function ble/keymap:vi/text-object:block/.search-block {
  local ret p1=$1 p2=$2 L=$3 R=$4 opts=$5
  [[ ${_ble_edit_str:p1:1} == "$L" ]] && ((p1++))
  if ble/keymap:vi/text-object:block/.prev-matching-lparen "$p1" "$arg"; then
    # We first attempt to search for "a surrounding pair (...)" at the
    # specified level of $arg.
    beg=$ret
    ble/keymap:vi/text-object:block/.next-matching-rparen "$p1" "$arg" || return 1
    end=$ret

    if [[ :$opts: == *:reject-empty-here:* ]]; then
      ((beg+1<end)) || return 1
    fi

    if [[ :$opts: == *:check-expand:* ]]; then
      # If the new range is essentially identical (or a prefix) to the current
      # selection, we try to capture the range upper by one level.
      local outer_beg outer_end
      ble/keymap:vi/text-object:block/.outer-range "$p1" "$p2"
      if ((outer_beg==beg&&outer_end>=end)); then
        [[ $type == i* ]] && ((p1--))
        ble/keymap:vi/text-object:block/.expand-one-level "$outer_beg" || return 1
      fi
    fi
  elif ((ret<=0&&arg==1)); then
    # When we fail to find "the surrounding pair (...)" at the top level, we
    # next try "the next pair (...)".  This is attempted only when the
    # specified level is arg=1.
    p1=$1
    [[ ${_ble_edit_str:p1:1} == "$R" ]] && ((p1++))
    ble/keymap:vi/text-object:block/.next-matching-lparen "$p1" || return 1
    beg=$ret
    ble/keymap:vi/text-object:block/.next-matching-rparen "$((beg+1))" || return 1
    end=$ret
    # Note: In Vim, ((beg+1<end)) check does not seem to be performed here.
    # See also the next Note in the code comment below.

    if [[ :$opts: == *:check-expand:* ]]; then
      if [[ $type == i* ]]; then
        local outer_end=$p2
        case ${_ble_edit_str:outer_end+1} in
        ($'\n'"$rparen"*) ((outer_end+=2)) ;;
        ("$rparen"*) ((outer_end++)) ;;
        esac
        ((outer_end<end)) || return 1
      fi
    fi
  else
    return 1
  fi
  return 0
}

## @fn ble/keymap:vi/text-object:block/.xmap
##   @var[in] lparen rparen
##   @var[in] arg
function ble/keymap:vi/text-object:block/.xmap {
  if ((_ble_edit_ind==_ble_edit_mark)); then
    local beg end p=$_ble_edit_ind
    ble/keymap:vi/text-object:block/.search-block "$p" "$p" "$lparen" "$rparen" reject-empty-here || return 1

    # Decide the range appropriately depending on i, a
    if [[ $type == i* ]]; then
      # Note: When ((beg + 1 == end)) with "the next pair (...)", the mark and
      # the index is reversed in Vim 9.0.  This might be a bug of Vim because
      # when ((beg + 1 == end)), the text object fails for "the surrounding
      # pair (...)"  but this check seems skipped for "the next pair (...)".
      # Nevertheless, ble.sh follows Vim's behavior.
      ((beg++,end--))
      [[ ${_ble_edit_str:beg:1} == $'\n' ]] && ((beg++))
    fi
    _ble_edit_mark=$beg
    _ble_edit_ind=$end
    return 0
  else
    local min=$_ble_edit_mark max=$_ble_edit_ind
    ((min<max)) || local min=$max max=$min
    ble/keymap:vi/text-object:block/.search-block "$min" "$max" "$rparen" "$lparen" reject-empty-here:check-expand || return 1

    if [[ $type == i* ]]; then
      ((beg++,end--))
      [[ ${_ble_edit_str:beg:1} == $'\n' ]] && ((beg++))
    fi
    _ble_edit_mark=$beg
    _ble_edit_ind=$end
    return 0
  fi
}

function ble/keymap:vi/text-object/block.impl {
  local arg=$1 flag=$2 reg=$3 type=$4
  local ret paren=${type:1} lparen=${type:1:1} rparen=${type:2:1}
  if [[ $_ble_decode_keymap == vi_[xs]map ]]; then
    if ble/keymap:vi/text-object:block/.xmap; then
      ble/keymap:vi/adjust-command-mode
      return 0
    else
      ble/widget/vi-command/bell
      return 1
    fi
  fi

  local beg end p=$_ble_edit_ind
  if ! ble/keymap:vi/text-object:block/.search-block "$p" "$p" "$lparen" "$rparen"; then
    ble/widget/vi-command/bell
    return 1
  fi
  ((end++))

  local linewise=
  if [[ $type == *i* ]]; then
    ((beg++,end--))
    [[ ${_ble_edit_str:beg:1} == $'\n' ]] && ((beg++))
    ((beg<end)) && ble-edit/content/bolp "$end" && ((end--))
    ((beg<end)) && ble-edit/content/bolp "$beg" && ble-edit/content/eolp "$end" && linewise=1
  fi

  if [[ $linewise ]]; then
    ble/widget/vi-command/linewise-range.impl "$beg" "$end" "$flag" "$reg" goto_bol
  else
    ble/widget/vi-command/exclusive-range.impl "$beg" "$end" "$flag" "$reg"
  fi
}

## @fn ble/keymap:vi/text-object:tag/.find-end-tag
##   @var[in] beg
##   @var[out] end
function ble/keymap:vi/text-object:tag/.find-end-tag {
  local ifs=$_ble_term_IFS ret rex

  rex="^<([^$ifs/>!]+)"; [[ ${_ble_edit_str:beg} =~ $rex ]] || return 1
  ble/string#escape-for-extended-regex "${BASH_REMATCH[1]}"; local tagname=$ret
  rex="^</?$tagname([$ifs]+([^>]*[^/])?)?>"

  end=$beg
  local count=0
  while ble/string#index-of-chars "$_ble_edit_str" '<' "$end" && end=$((ret+1)); do
    [[ ${_ble_edit_str:end-1} =~ $rex ]] || continue
    ((end+=${#BASH_REMATCH}-1))

    if [[ ${BASH_REMATCH::2} == '</' ]]; then
      ((--count==0)) && return 0
    else
      ((++count))
    fi
  done
  return 1
}
function ble/keymap:vi/text-object/tag.impl {
  local arg=$1 flag=$2 reg=$3 type=$4
  local ret rex

  local pivot=$_ble_edit_ind ret=$_ble_edit_ind
  if [[ ${_ble_edit_str:ret:1} == '<' ]] || ble/string#last-index-of-chars "${_ble_edit_str::_ble_edit_ind}" '<>'; then
    if rex='^<[^/][^>]*>' && [[ ${_ble_edit_str:ret} =~ $rex ]]; then
      ((pivot=ret+${#BASH_REMATCH}))
    else
      ((pivot=ret+1))
    fi
  fi

  local ifs=$_ble_term_IFS

  local beg=$pivot count=$arg
  rex="<([^$ifs/>!]+([$ifs]+([^>]*[^/])?)?|/[^>]*)>\$"
  while ble/string#last-index-of-chars "${_ble_edit_str::beg}" '>' && beg=$ret; do
    [[ ${_ble_edit_str::beg+1} =~ $rex ]] || continue
    ((beg-=${#BASH_REMATCH}-1))

    if [[ ${BASH_REMATCH::2} == '</' ]]; then
      ((++count))
    else
      if ((--count==0)); then
        if ble/keymap:vi/text-object:tag/.find-end-tag "$beg" && ((_ble_edit_ind<end)); then
          break
        else
          ((count++))
        fi
      fi
    fi
  done
  if ((count)); then
    ble/widget/vi-command/bell
    return 1
  fi

  if [[ $type == i* ]]; then
    rex='^<[^>]*>'; [[ ${_ble_edit_str:beg:end-beg} =~ $rex ]] && ((beg+=${#BASH_REMATCH}))
    rex='<[^>]*>$'; [[ ${_ble_edit_str:beg:end-beg} =~ $rex ]] && ((end-=${#BASH_REMATCH}))
  fi
  if [[ $_ble_decode_keymap == vi_[xs]map ]]; then
    _ble_edit_mark=$beg
    ble/widget/vi-command/exclusive-goto.impl "$end"
  else
    ble/widget/vi-command/exclusive-range.impl "$beg" "$end" "$flag" "$reg"
  fi
}

## @fn ble/keymap:vi/text-object:sentence/.beg
##   @var[out] beg
##   @var[out] is_interval
##   @var[in] lf, ht
function ble/keymap:vi/text-object:sentence/.beg {
  beg= is_interval=
  local pivot=$_ble_edit_ind rex=
  if ble-edit/content/bolp && ble-edit/content/eolp; then
    if rex=$'^\n+[^\n]'; [[ ${_ble_edit_str:pivot} =~ $rex ]]; then
      # If a non-blank line is found in front, the line before it is used as the starting point.
      beg=$((pivot+${#BASH_REMATCH}-2))
    else
      # Start from the end of the previous non-blank line
      if rex=$'\n+$'; [[ ${_ble_edit_str::pivot} =~ $rex ]]; then
        ((pivot-=${#BASH_REMATCH}))
      fi
    fi
  fi
  if [[ ! $beg ]]; then
    rex="^.*((^$lf?|$lf$lf)([ $ht]*)|[.!?][])'\"]*([ $ht$lf]+))"
    if [[ ${_ble_edit_str::pivot+1} =~ $rex ]]; then
      beg=${#BASH_REMATCH}
      if ((pivot<beg)); then
        # pivot < beg means beg == pivot + 1 (match to the end).
        # At this point, pivot is always on a nonempty line or the first line, so it will never match /\n\n/.
        local rematch34=${BASH_REMATCH[3]}${BASH_REMATCH[4]}
        if [[ $rematch34 ]]; then
          # /(^\n\s+|\n\n\s+|[.!?]\s+)$/
          beg=$((pivot+1-${#rematch34})) is_interval=1
        else
          # /^\n$/
          beg=$pivot
        fi
      fi
    else
      beg=0
    fi
  fi
}
## @fn ble/keymap:vi/text-object:sentence/.next {
##   @var[in,out] end
##   @var[in,out] is_interval
##   @var[in] lf, ht
function ble/keymap:vi/text-object:sentence/.next {
  if [[ $is_interval ]]; then
    is_interval=
    local rex=$'[ \t]*((\n[ \t]+)*\n[ \t]*)?'
    [[ ${_ble_edit_str:end} =~ $rex ]]
    local index=$((end+${#BASH_REMATCH}))
    ((end<index)) && [[ ${_ble_edit_str:index-1:1} == $'\n' ]] && ((index--))
    ((end=index))
  else
    is_interval=1
    if local rex=$'^\n+'; [[ ${_ble_edit_str:end} =~ $rex ]]; then
      # Read all consecutive LFs
      ((end+=${#BASH_REMATCH}))
    elif rex="(([.!?][])\"']*)[ $ht$lf]|$lf$lf).*\$"; [[ ${_ble_edit_str:end} =~ $rex ]]; then
      # sentence to next end of sentence
      local rematch2=${BASH_REMATCH[2]}
      end=$((${#_ble_edit_str}-${#BASH_REMATCH}+${#rematch2}))
    else
      # last sentence
      local index=${#_ble_edit_str}
      ((end<index)) && [[ ${_ble_edit_str:index-1:1} == $'\n' ]] && ((index--))
      ((end=index))
    fi
  fi
}
function ble/keymap:vi/text-object/sentence.impl {
  local arg=$1 flag=$2 reg=$3 type=$4
  local lf=$'\n' ht=$'\t'
  local rex

  local beg is_interval
  ble/keymap:vi/text-object:sentence/.beg

  local end=$beg i n=$arg
  [[ $type != i* ]] && ((n*=2))
  for ((i=0;i<n;i++)); do
    ble/keymap:vi/text-object:sentence/.next
  done
  ((beg<end)) && [[ ${_ble_edit_str:end-1:1} == $'\n' ]] && ((end--))

  # If at cannot allocate space forward, it allocates space backwards.
  if [[ $type != i* && ! $is_interval ]]; then
    local ifs=$_ble_term_IFS
    if ((end)) && [[ ${_ble_edit_str:end-1:1} != ["$ifs"] ]]; then
      rex="^.*(^$lf$lf|[.!?][])'\"]*([ $ht$lf]))([ $ht$lf]*)\$"
      if [[ ${_ble_edit_str::beg} =~ $rex ]]; then
        local rematch2=${BASH_REMATCH[2]}
        local rematch3=${BASH_REMATCH[3]}
        ((beg-=${#rematch2}+${#rematch3}))
        [[ ${_ble_edit_str:beg:1} == $'\n' ]] && ((beg++))
      fi
    fi
  fi

  if [[ $_ble_decode_keymap == vi_[xs]map ]]; then
    _ble_edit_mark=$beg
    ble/widget/vi-command/exclusive-goto.impl "$end"
  elif ble-edit/content/bolp "$beg" && [[ ${_ble_edit_str:end:1} == $'\n' ]]; then
    # It becomes linewise from the beginning of the line to before the LF.
    # Note that it is not linewise until the end of _ble_edit_str.
    ble/widget/vi-command/linewise-range.impl "$beg" "$end" "$flag" "$reg" goto_bol
  else
    ble/widget/vi-command/exclusive-range.impl "$beg" "$end" "$flag" "$reg"
  fi
}

function ble/keymap:vi/text-object/paragraph.impl {
  local arg=$1 flag=$2 reg=$3 type=$4
  local rex ret

  local beg= empty_start=
  ble-edit/content/find-logical-bol; local bol=$ret
  ble-edit/content/find-non-space "$bol"; local nol=$ret
  if rex=$'[ \t]*(\n|$)' ble-edit/content/eolp "$nol"; then
    # If the line is empty, move to the first consecutive empty line
    empty_start=1
    rex=$'(^|\n)([ \t]*\n)*$'
    [[ ${_ble_edit_str::bol} =~ $rex ]]
    local rematch1=${BASH_REMATCH[1]} # Note: for bash-3.1 ${#arr[n]} bug
    ((beg=bol-(${#BASH_REMATCH}-${#rematch1})))
  else
    # If it is a non-blank line, move to the beginning of the first non-blank line.
    if rex=$'^(.*\n)?[ \t]*\n'; [[ ${_ble_edit_str::bol} =~ $rex ]]; then
      ((beg=${#BASH_REMATCH}))
    else
      ((beg=0))
    fi
  fi

  local end=$beg
  local rex_empty_line=$'([ \t]*\n|[ \t]+$)' rex_paragraph_line=$'([ \t]*[^ \t\n][^\n]*(\n|$))'
  if [[ $type == i* ]]; then
    rex="$rex_empty_line+|$rex_paragraph_line+"
  elif [[ $empty_start ]]; then
    rex="$rex_empty_line*$rex_paragraph_line+"
  else
    rex="$rex_paragraph_line+$rex_empty_line*"
  fi
  local i
  for ((i=0;i<arg;i++)); do
    if [[ ${_ble_edit_str:end} =~ $rex ]]; then
      ((end+=${#BASH_REMATCH}))
    else
      # For paragraph, error if next not found
      ble/widget/vi-command/bell
      return 1
    fi
  done

  # If there is no trailing blank line in at, take the blank line in backward.
  if [[ $type != i* && ! $empty_start ]]; then
    if rex=$'(^|\n)[ \t]*\n$'; ! [[ ${_ble_edit_str::end} =~ $rex ]]; then
      if rex=$'(^|\n)([ \t]*\n)*$'; [[ ${_ble_edit_str::beg} =~ $rex ]]; then
        local rematch1=${BASH_REMATCH[1]}
        ((beg-=${#BASH_REMATCH}-${#rematch1}))
      fi
    fi
  fi
  ((beg<end)) && [[ ${_ble_edit_str:end-1:1} == $'\n' ]] && ((end--))
  if [[ $_ble_decode_keymap == vi_[xs]map ]]; then
    _ble_edit_mark=$beg
    ble/widget/vi-command/exclusive-goto.impl "$end"
  else
    ble/widget/vi-command/linewise-range.impl "$beg" "$end" "$flag" "$reg"
  fi
}

## @fn ble/keymap:vi/text-object.impl
##
## @exit Returns 0 when processing of the text object is complete.
##
function ble/keymap:vi/text-object.impl {
  local arg=$1 flag=$2 reg=$3 type=$4
  case $type in
  ([ia][wW]) ble/keymap:vi/text-object/word.impl "$arg" "$flag" "$reg" "$type" ;;
  ([ia][\"\'\`]) ble/keymap:vi/text-object/quote.impl "$arg" "$flag" "$reg" "$type" ;;
  ([ia]['b()']) ble/keymap:vi/text-object/block.impl "$arg" "$flag" "$reg" "${type::1}()" ;;
  ([ia]['B{}']) ble/keymap:vi/text-object/block.impl "$arg" "$flag" "$reg" "${type::1}{}" ;;
  ([ia]['<>']) ble/keymap:vi/text-object/block.impl "$arg" "$flag" "$reg" "${type::1}<>" ;;
  ([ia]['][']) ble/keymap:vi/text-object/block.impl "$arg" "$flag" "$reg" "${type::1}[]" ;;
  ([ia]t) ble/keymap:vi/text-object/tag.impl "$arg" "$flag" "$reg" "$type" ;;
  ([ia]s) ble/keymap:vi/text-object/sentence.impl "$arg" "$flag" "$reg" "$type" ;;
  ([ia]p) ble/keymap:vi/text-object/paragraph.impl "$arg" "$flag" "$reg" "$type" ;;
  (*)
    ble/widget/vi-command/bell
    return 1;;
  esac
}

function ble/keymap:vi/text-object.hook {
  local key=$1
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  if ! ble-decode-key/ischar "$key"; then
    ble/widget/vi-command/bell
    return 1
  fi

  local ret; ble/util/c2s "$key"
  local type=$_ble_keymap_vi_text_object$ret
  ble/keymap:vi/text-object.impl "$ARG" "$FLAG" "$REG" "$type"
  return 0
}

function ble/keymap:vi/.attempt-text-object {
  local c=${1:-}
  if [[ ! $c ]]; then
    # If the type is not specified, it is determined from the last key the user
    # input (i or a). This is for the backward compatibility.
    local n=${#KEYS[@]}; ((n&&n--))
    ble-decode-key/ischar "${KEYS[n]}" || return 1
    local ret; ble/util/c2s "${KEYS[n]}"; c=$ret
  fi

  [[ $c == [ia] ]] || return 1

  [[ $_ble_keymap_vi_opfunc || $_ble_decode_keymap == vi_[xs]map ]] || return 1

  _ble_keymap_vi_text_object=$c
  _ble_decode_key__hook=ble/keymap:vi/text-object.hook
  return 0
}

function ble/widget/vi-command/text-object {
  ble/keymap:vi/.attempt-text-object "$@" && return 147
  ble/widget/vi-command/bell
  return 1
}

function ble/widget/vi-command/text-object-outer {
  ble/widget/vi-command/text-object a
}

function ble/widget/vi-command/text-object-inner {
  ble/widget/vi-command/text-object i
}

#------------------------------------------------------------------------------
# Command
#
# map: :cmd

# Default cmap history
_ble_keymap_vi_commandline_history=()
_ble_keymap_vi_commandline_history_edit=()
_ble_keymap_vi_commandline_history_dirt=()
_ble_keymap_vi_commandline_history_index=0

function ble/keymap:vi/commandline/empty-cancel.hook {
  if [[ ! $_ble_edit_str ]] && ((_ble_edit_async_read_is_cancel_key[KEYS[0]])); then
    ble/widget/vi_cmap/cancel
    ble/decode/widget/suppress-widget
  fi
}

function ble/widget/vi-command/commandline {
  ble/keymap:vi/clear-arg
  ble/keymap:vi/async-commandline-mode ble/widget/vi-command/commandline.hook
  _ble_edit_PS1=:
  ble/history/set-prefix _ble_keymap_vi_commandline
  _ble_keymap_vi_cmap_before_widget=ble/keymap:vi/commandline/empty-cancel.hook
  return 147
}
function ble/widget/vi-command/commandline.hook {
  local command
  ble/string#split-words command "$1"
  local cmd=ble/widget/vi-command:"${command[0]}"
  if ble/is-function "$cmd"; then
    "$cmd" "${command[@]:1}"; local ext=$?
  elif ble/util/compgen cmd -A function -- "ble/widget/vi-command:${command[@]}" && ((${#cmd[@]}==1)); then
    "$cmd" "${command[@]:1}"; local ext=$?
  else
    ble/widget/vi-command/bell "unknown command $1"; local ext=1
  fi
  [[ $1 ]] && _ble_keymap_vi_register[58]=/$result # ":
  return "$ext"
}

function ble/widget/vi-command:w {
  local file=
  if [[ $1 ]]; then
    ble/builtin/history -a "$1"
    file=$1
  elif [[ ${HISTFILE-} ]]; then
    ble/builtin/history -a
    file=$HISTFILE
  else
    ble/widget/vi-command/bell 'w: the history filename is empty or not specified'
    return 1
  fi
  local wc
  ble/util/assign-words wc 'ble/bin/wc "$file"'
  ble/edit/info/show text "\"$file\" ${wc[0]}L, ${wc[2]}C written"
  ble/keymap:vi/adjust-command-mode
  return 0
}
function ble/widget/vi-command:q! {
  ble/widget/exit force
  return 1
}
function ble/widget/vi-command:q {
  ble/widget/exit
  ble/keymap:vi/adjust-command-mode # Because it will not end when there is a job.
  return 1
}
function ble/widget/vi-command:wq {
  ble/widget/vi-command:w "$@"
  ble/widget/exit
  ble/keymap:vi/adjust-command-mode
  return 1
}

#------------------------------------------------------------------------------
# Search
#
# map: / ? n N

_ble_keymap_vi_search_obackward=
_ble_keymap_vi_search_ohistory=
_ble_keymap_vi_search_needle=
_ble_keymap_vi_search_activate=
_ble_keymap_vi_search_matched=

_ble_keymap_vi_search_history=()
_ble_keymap_vi_search_history_edit=()
_ble_keymap_vi_search_history_dirt=()
_ble_keymap_vi_search_history_index=0

## @bleopt keymap_vi_search_match_current
##   /, ?, n, N when a non-empty string is set
##   Matches the word under the current cursor.
##   The default value is an empty string, mimicking the behavior of vim.
bleopt/declare -v keymap_vi_search_match_current ''

function ble/highlight/layer:region/mark:vi_search/get-selection {
  ble/highlight/layer:region/mark:vi_char/get-selection
}
function ble/keymap:vi/search/matched {
  [[ $_ble_keymap_vi_search_matched || $_ble_edit_mark_active == vi_search || $_ble_keymap_vi_search_activate ]]
}
function ble/keymap:vi/search/clear-matched {
  _ble_keymap_vi_search_activate=
  _ble_keymap_vi_search_matched=
  [[ $_ble_edit_mark_active == vi_search ]] && _ble_edit_mark_active=
}
## @fn ble/keymap:vi/search/invoke-search needle
##
##   @param[in] needle
##     Specify a regular expression that represents the search pattern.
##
##   @var[out] beg end
##     Returns the match range.
##
##   @exit
##     Successful completion 0 if a match is found. Otherwise, it returns a value other than 0.
##
##   @var[in] opt_optional_next
##     Find a match after or before the current location.
##     When called with vi_omap, it is set when there is a match at the current position.
##     It does not come here when keymap_vi_search_match_current is non-empty.
##
##   @var[in] opt_locate
##     Perform a search that can match the current location.
##     When a matching history item is found by searching backwards through the history,
## Used to identify the first occurrence of that history item.
##
##   @var[in] opt_backward
##     Specify the search direction.
##
function ble/keymap:vi/search/invoke-search {
  local needle=$1
  local dir=+; ((opt_backward)) && dir=B
  local ind=$_ble_edit_ind

  # Search start position
  if ((opt_optional_next)); then
    if ((!opt_backward)); then
      ((_ble_edit_ind<${#_ble_edit_str}&&_ble_edit_ind++))
    fi
  elif ((opt_locate)) || ! ble/keymap:vi/search/matched; then
    # From the state of not matching anything
    if ((opt_locate)) || [[ $bleopt_keymap_vi_search_match_current ]]; then
      # Can match current location
      #   Forward search: @hello → @hello (as is)
      #   Backward search: hell@o → hello@ (shift)
      if ((opt_backward)); then
        ble-edit/content/eolp || ((_ble_edit_ind++))
      fi
    else
      # Don't match current position
      #   Forward search: @hello → h@ello (shift)
      #   Backward search: hell@o → hell@o (as is)
      if ((!opt_backward)); then
        ble-edit/content/eolp || ((_ble_edit_ind++))
      fi
    fi
  else
    # _ble_edit_ind .. When matching _ble_edit_mark[+1]
    if ((!opt_backward)); then
      if [[ $_ble_decode_keymap == vi_[xs]map ]]; then
        # In vi_xmap and vi_smap, _ble_edit_mark is used for another purpose.
        # Since the terminal point information has been lost, try matching again.
        if ble-edit/isearch/search "$@" && ((beg==_ble_edit_ind)); then
          _ble_edit_ind=$end
        else
          ((_ble_edit_ind<${#_ble_edit_str}&&_ble_edit_ind++))
        fi
      else
        ((_ble_edit_ind=_ble_edit_mark))
        ble-edit/content/eolp || ((_ble_edit_ind++))
      fi
    else
      # For second and subsequent matches, search with opts=-.
      dir=-
    fi
  fi

  ble-edit/isearch/search "$needle" "$dir":regex; local ext=$?
  _ble_edit_ind=$ind
  return "$ext"
}

## @fn ble/widget/vi-command/search.core
##
##   @var[in] needle
##   @var[in] opt_backward
##   @var[in] opt_history
##   @var[in] opt_locate
##   @var[in] start
##   @var[in] ntask
##
function ble/widget/vi-command/search.core {
  local beg= end= is_empty_match=
  if ble/keymap:vi/search/invoke-search "$needle"; then
    if ((beg<end)); then
      ble-edit/content/bolp "$end" || ((end--))
      _ble_edit_ind=$beg # eol correction is done last on search.impl side
      [[ $_ble_decode_keymap != vi_[xs]map ]] && _ble_edit_mark=$end
      _ble_keymap_vi_search_activate=vi_search
      return 0
    else
      # In vim, an empty match seems to fail immediately.
      # There is no need to search for more.
      opt_history=
      is_empty_match=1
    fi
  fi

  if ((opt_history)) && [[ $_ble_history_load_done || opt_backward -ne 0 ]]; then
    ble/history/initialize
    local index; ble/history/get-index
    [[ $start ]] || start=$index
    if ((opt_backward)); then
      ((index--))
    else
      ((index++))
    fi

    local _ble_edit_isearch_dir=+; ((opt_backward)) && _ble_edit_isearch_dir=-
    local _ble_edit_isearch_str=$needle
    local isearch_ntask=$ntask
    local isearch_time=0
    local isearch_progress_callback=ble-edit/isearch/.show-status-with-progress.fib
    if ((opt_backward)); then
      ble/history/isearch-backward-blockwise regex:progress
    else
      ble/history/isearch-forward regex:progress
    fi; local r=$?
    ble/edit/info/default

    if ((r==0)); then
      local new_index; ble/history/get-index -v new_index
      [[ $index != "$new_index" ]] &&
        ble-edit/history/goto "$index" point=none
      if ((opt_backward)); then
        local i=${#_ble_edit_str}
        ble/keymap:vi/needs-eol-fix "$i" && ((i--))
        _ble_edit_ind=$i
      else
        _ble_edit_ind=0
      fi

      opt_locate=1 opt_history=0 ble/widget/vi-command/search.core
      return "$?"
    fi
  fi

  if ((!opt_optional_next)); then
    if [[ $is_empty_match ]]; then
      ble/widget/.bell "search: empty match"
    else
      ble/widget/.bell "search: not found"
    fi
    if [[ $_ble_edit_mark_active == vi_search ]]; then
      _ble_keymap_vi_search_activate=vi_search
    fi
  fi
  return 1
}
function ble/widget/vi-command/search.impl {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1

  local opts=$1 needle=$2
  [[ :$opts: != *:repeat:* ]]; local opt_repeat=$? # Search again n N
  [[ :$opts: != *:history:* ]]; local opt_history=$? # Is history search enabled?
  [[ :$opts: != *:-:* ]]; local opt_backward=$? # Reverse direction
  local opt_locate=0
  local opt_optional_next=0
  if ((opt_repeat)); then
    # n N
    if [[ $_ble_keymap_vi_search_needle ]]; then
      needle=$_ble_keymap_vi_search_needle
      ((opt_backward^=_ble_keymap_vi_search_obackward,
        opt_history=_ble_keymap_vi_search_ohistory))
    else
      ble/widget/vi-command/bell 'no previous search'
      return 1
    fi
  else
    # / ? * #
    ble/keymap:vi/search/clear-matched
    if [[ $needle ]]; then
      _ble_keymap_vi_search_needle=$needle
      _ble_keymap_vi_search_obackward=$opt_backward
      _ble_keymap_vi_search_ohistory=$opt_history
    elif [[ $_ble_keymap_vi_search_needle ]]; then
      needle=$_ble_keymap_vi_search_needle
      _ble_keymap_vi_search_obackward=$opt_backward
      _ble_keymap_vi_search_ohistory=$opt_history
    else
      ble/widget/vi-command/bell 'no previous search'
      return 1
    fi
  fi

  local original_ind=$_ble_edit_ind
  if [[ $FLAG || $_ble_decode_keymap == vi_[xs]map ]]; then
    opt_history=0
  else
    local old_hindex; ble/history/get-index -v old_hindex
  fi

  local start= # First history number. Set after the first history read in search.core.
  local ntask=$ARG
  while ((ntask)); do
    ble/widget/vi-command/search.core || break
    ((ntask--))
  done

  if [[ $FLAG ]]; then
    if ((ntask)); then
      # When the search target was not found
      _ble_keymap_vi_search_activate=
      _ble_edit_ind=$original_ind
      ble/keymap:vi/adjust-command-mode
      return 1
    else
      # when found
      if ((_ble_edit_ind==original_index)); then
        # If the range is empty, continue to the next match.
        # If there is no next matching location (if it is itself), it becomes an empty area.
        opt_optional_next=1 ble/widget/vi-command/search.core
      fi
      local index=$_ble_edit_ind

      _ble_keymap_vi_search_activate=
      _ble_edit_ind=$original_ind
      ble/widget/vi-command/exclusive-goto.impl "$index" "$FLAG" "$REG" nobell
    fi
  else
    if ((ntask<ARG)); then
      # Jump within the same history item
      if ((opt_history)); then
        local new_hindex; ble/history/get-index -v new_hindex
        ((new_hindex==old_hindex))
      fi && ble/keymap:vi/mark/set-local-mark 96 "$original_index" # ``

      # line end correction
      if ble/keymap:vi/needs-eol-fix; then
        if ((!opt_backward&&_ble_edit_ind<_ble_edit_mark)); then
          ((_ble_edit_ind++))
        else
          ((_ble_edit_ind--))
        fi
      fi
    fi
    ble/keymap:vi/adjust-command-mode
    return 0
  fi
}
function ble/widget/vi-command/search-forward {
  ble/keymap:vi/async-commandline-mode 'ble/widget/vi-command/search.impl +:history'
  _ble_edit_PS1='/'
  ble/history/set-prefix _ble_keymap_vi_search
  _ble_keymap_vi_cmap_before_widget=ble/keymap:vi/commandline/empty-cancel.hook
  return 147
}
function ble/widget/vi-command/search-backward {
  ble/keymap:vi/async-commandline-mode 'ble/widget/vi-command/search.impl -:history'
  _ble_edit_PS1='?'
  ble/history/set-prefix _ble_keymap_vi_search
  _ble_keymap_vi_cmap_before_widget=ble/keymap:vi/commandline/empty-cancel.hook
  return 147
}
function ble/widget/vi-command/search-repeat {
  ble/widget/vi-command/search.impl repeat:+
}
function ble/widget/vi-command/search-reverse-repeat {
  ble/widget/vi-command/search.impl repeat:-
}

function ble/widget/vi-command/search-word.impl {
  local opts=$1
  local rex=$'^([^[:alnum:]_\n]*)([[:alnum:]_]*)'
  if ! [[ ${_ble_edit_str:_ble_edit_ind} =~ $rex ]]; then
    ble/keymap:vi/clear-arg
    ble/widget/vi-command/bell 'word is not found'
    return 1
  fi

  local end=$((_ble_edit_ind+${#BASH_REMATCH}))
  local word=${BASH_REMATCH[2]}
  if [[ ! ${BASH_REMATCH[1]} ]]; then
    rex=$'[[:alnum:]_]+$'
    [[ ${_ble_edit_str::_ble_edit_ind} =~ $rex ]] &&
      word=$BASH_REMATCH$word
  fi

  # Note: Bash regular expressions use <regex.h>, so
  #   Not necessarily compatible with non-POSIX ERE \<\>.
  #   Also, I don't know if it matches [[:alnum:]_].
  #   Therefore, check if it is applicable and then request that it match the boundary.
  local needle=$word
  rex='\<'$needle; [[ $word =~ $rex ]] && needle=$rex
  rex=$needle'\>'; [[ $word =~ $rex ]] && needle=$rex

  if [[ $opts == backward ]]; then
    ble/widget/vi-command/search.impl -:history "$needle"
  else
    local original_ind=$_ble_edit_ind
    _ble_edit_ind=$((end-1))
    ble/widget/vi-command/search.impl +:history "$needle" && return 0
    _ble_edit_ind=$original_ind
    return 1
  fi
}
# nmap *
function ble/widget/vi-command/search-word-forward {
  ble/widget/vi-command/search-word.impl forward
}
# nmap #
function ble/widget/vi-command/search-word-backward {
  ble/widget/vi-command/search-word.impl backward
}

#------------------------------------------------------------------------------
# command-help

# nmap K
function ble/widget/vi_nmap/command-help {
  ble/keymap:vi/clear-arg
  ble/widget/command-help; local ext=$?
  ble/keymap:vi/adjust-command-mode
  return "$ext"
}
function ble/widget/vi_xmap/command-help.core {
  ble/keymap:vi/clear-arg
  local get_selection=ble/highlight/layer:region/mark:$_ble_edit_mark_active/get-selection
  ble/is-function "$get_selection" || return 1

  local selection
  "$get_selection" || return 1
  ((${#selection[*]}==2)) || return 1

  local comp_cword=0 comp_line=$_ble_edit_str comp_point=$_ble_edit_ind
  local -a comp_words; comp_words=("$cmd")
  local cmd=${_ble_edit_str:selection[0]:selection[1]-selection[0]}
  ble/widget/command-help.impl "$cmd"; local ext=$?
  ble/keymap:vi/adjust-command-mode
  return "$ext"
}
function ble/widget/vi_xmap/command-help {
  if ! ble/widget/vi_xmap/command-help.core; then
    ble/widget/vi-command/bell
    return 1
  fi
}

#------------------------------------------------------------------------------

## @fn ble/keymap:vi/set-up-command-map
##   @var[in] ble_bind_keymap
function ble/keymap:vi/set-up-command-map {
  ble-bind -f 0 vi-command/append-arg
  ble-bind -f 1 vi-command/append-arg
  ble-bind -f 2 vi-command/append-arg
  ble-bind -f 3 vi-command/append-arg
  ble-bind -f 4 vi-command/append-arg
  ble-bind -f 5 vi-command/append-arg
  ble-bind -f 6 vi-command/append-arg
  ble-bind -f 7 vi-command/append-arg
  ble-bind -f 8 vi-command/append-arg
  ble-bind -f 9 vi-command/append-arg
  ble-bind -f y 'vi-command/operator y'
  ble-bind -f d 'vi-command/operator d'
  ble-bind -f c 'vi-command/operator c'
  ble-bind -f '<' 'vi-command/operator indent-left'
  ble-bind -f '>' 'vi-command/operator indent-right'
  ble-bind -f '!' 'vi-command/operator filter'
  ble-bind -f 'g ~' 'vi-command/operator toggle_case'
  ble-bind -f 'g u' 'vi-command/operator u'
  ble-bind -f 'g U' 'vi-command/operator U'
  ble-bind -f 'g ?' 'vi-command/operator rot13'
  ble-bind -f 'g q' 'vi-command/operator fold'
  ble-bind -f 'g w' 'vi-command/operator fold-preserve-point'
  ble-bind -f 'g @' 'vi-command/operator map'
  # ble-bind -f '=' 'vi-command/operator =' # indent (equalprg, ep)
  # ble-bind -f 'z f' 'vi-command/operator f'

  ble-bind -f paste_begin vi-command/bracketed-paste

  ble-bind -f 'home'    vi-command/beginning-of-line
  ble-bind -f '$'       vi-command/forward-eol
  ble-bind -f 'end'     vi-command/forward-eol
  ble-bind -f '^'       vi-command/first-non-space
  ble-bind -f '_'       vi-command/first-non-space-forward
  ble-bind -f '+'       vi-command/forward-first-non-space
  ble-bind -f 'C-m'     vi-command/forward-first-non-space
  ble-bind -f 'RET'     vi-command/forward-first-non-space
  ble-bind -f '-'       vi-command/backward-first-non-space
  ble-bind -f 'g 0'     vi-command/beginning-of-graphical-line
  ble-bind -f 'g home'  vi-command/beginning-of-graphical-line
  ble-bind -f 'g ^'     vi-command/graphical-first-non-space
  ble-bind -f 'g $'     vi-command/graphical-forward-eol
  ble-bind -f 'g end'   vi-command/graphical-forward-eol
  ble-bind -f 'g m'     vi-command/middle-of-graphical-line
  ble-bind -f 'g _'     vi-command/last-non-space

  ble-bind -f h     vi-command/backward-char
  ble-bind -f l     vi-command/forward-char
  ble-bind -f left  vi-command/backward-char
  ble-bind -f right vi-command/forward-char
  ble-bind -f 'C-?' 'vi-command/backward-char wrap'
  ble-bind -f 'DEL' 'vi-command/backward-char wrap'
  ble-bind -f 'C-h' 'vi-command/backward-char wrap'
  ble-bind -f 'BS'  'vi-command/backward-char wrap'
  ble-bind -f SP    'vi-command/forward-char wrap'

  ble-bind -f j     vi-command/forward-line
  ble-bind -f down  vi-command/forward-line
  ble-bind -f C-n   vi-command/forward-line
  ble-bind -f C-j   vi-command/forward-line
  ble-bind -f k     vi-command/backward-line
  ble-bind -f up    vi-command/backward-line
  ble-bind -f C-p   vi-command/backward-line
  ble-bind -f 'g j'    vi-command/graphical-forward-line
  ble-bind -f 'g down' vi-command/graphical-forward-line
  ble-bind -f 'g k'    vi-command/graphical-backward-line
  ble-bind -f 'g up'   vi-command/graphical-backward-line

  ble-bind -f w       vi-command/forward-vword
  ble-bind -f W       vi-command/forward-uword
  ble-bind -f b       vi-command/backward-vword
  ble-bind -f B       vi-command/backward-uword
  ble-bind -f e       vi-command/forward-vword-end
  ble-bind -f E       vi-command/forward-uword-end
  ble-bind -f 'g e'   vi-command/backward-vword-end
  ble-bind -f 'g E'   vi-command/backward-uword-end
  ble-bind -f C-right vi-command/forward-vword
  ble-bind -f S-right vi-command/forward-vword
  ble-bind -f C-left  vi-command/backward-vword
  ble-bind -f S-left  vi-command/backward-vword

  ble-bind -f 'g o'  vi-command/nth-byte
  ble-bind -f '|'    vi-command/nth-column
  ble-bind -f H      vi-command/nth-line
  ble-bind -f L      vi-command/nth-last-line
  ble-bind -f 'g g'  vi-command/history-beginning
  ble-bind -f G      vi-command/history-end
  ble-bind -f C-home vi-command/first-nol
  ble-bind -f C-end  vi-command/last-eol

  ble-bind -f 'f' vi-command/search-forward-char
  ble-bind -f 'F' vi-command/search-backward-char
  ble-bind -f 't' vi-command/search-forward-char-prev
  ble-bind -f 'T' vi-command/search-backward-char-prev
  ble-bind -f ';' vi-command/search-char-repeat
  ble-bind -f ',' vi-command/search-char-reverse-repeat

  ble-bind -f '%' 'vi-command/search-matchpair-or vi-command/percentage-line'

  ble-bind -f 'C-\ C-n' nop

  ble-bind -f ':' vi-command/commandline
  ble-bind -f '/' vi-command/search-forward
  ble-bind -f '?' vi-command/search-backward
  ble-bind -f 'n' vi-command/search-repeat
  ble-bind -f 'N' vi-command/search-reverse-repeat
  ble-bind -f '*' vi-command/search-word-forward
  ble-bind -f '#' vi-command/search-word-backward

  ble-bind -f '`' 'vi-command/goto-mark'
  ble-bind -f \'  'vi-command/goto-mark line'

  # bash
  ble-bind -c 'C-z' fg
}

#------------------------------------------------------------------------------
# Operator pending mode

function ble/widget/vi_omap/operator-rot13-or-search-backward {
  if [[ $_ble_keymap_vi_opfunc == rot13 ]]; then
    # Only when g?? rot13-encode lines
    ble/widget/vi-command/operator rot13
  else
    ble/widget/vi-command/search-backward
  fi
}

# o_v o_V
function ble/widget/vi_omap/switch-visual-mode.impl {
  local new_mode=$1

  local old=$_ble_keymap_vi_opfunc
  [[ $old ]] || return 1

  # clear existing visual-mode
  local new=$old:
  new=${new/:vi_char:/:}
  new=${new/:vi_line:/:}
  new=${new/:vi_block:/:}

  # add new visual-mode
  [[ $new_mode ]] && new=$new:$new_mode

  _ble_keymap_vi_opfunc=$new
}
# omap v
function ble/widget/vi_omap/switch-to-charwise {
  ble/widget/vi_omap/switch-visual-mode.impl vi_char
}
# omap V
function ble/widget/vi_omap/switch-to-linewise {
  ble/widget/vi_omap/switch-visual-mode.impl vi_line
}
# omap <C-v>
function ble/widget/vi_omap/switch-to-blockwise {
  ble/widget/vi_omap/switch-visual-mode.impl vi_block
}

function ble-decode/keymap:vi_omap/define {
  ble/keymap:vi/set-up-command-map

  ble-bind -f __default__ vi_omap/__default__
  ble-bind -f __line_limit__ nop
  ble-bind -f 'ESC' vi_omap/cancel
  ble-bind -f 'C-[' vi_omap/cancel
  ble-bind -f 'C-c' vi_omap/cancel

  ble-bind -f a   vi-command/text-object-outer
  ble-bind -f i   vi-command/text-object-inner

  # Changing range type (vim o_v o_V)
  ble-bind -f v      vi_omap/switch-to-charwise
  ble-bind -f V      vi_omap/switch-to-linewise
  ble-bind -f C-v    vi_omap/switch-to-blockwise
  ble-bind -f C-q    vi_omap/switch-to-blockwise

  # Two-letter operator abbreviation
  ble-bind -f '~' 'vi-command/operator toggle_case'
  ble-bind -f 'u' 'vi-command/operator u'
  ble-bind -f 'U' 'vi-command/operator U'
  ble-bind -f '?' 'vi_omap/operator-rot13-or-search-backward'
  ble-bind -f 'q' 'vi-command/operator fold'
  # Note: w is a forward word. Example: {N}gww is format {N} words
  # Note: @ is not defined in omap. Example: {N}g@@ is bell
}

#------------------------------------------------------------------------------
# Normal mode

# nmap C-d
function ble/widget/vi-command/exit-on-empty-line {
  if [[ $_ble_edit_str ]]; then
    ble/widget/vi_nmap/forward-scroll
    return "$?"
  else
    ble/widget/exit
    ble/keymap:vi/adjust-command-mode # Because it will not end when there is a job.
    return 1
  fi
}

# nmap C-g (show line and column)
function ble/widget/vi-command/show-line-info {
  local index count
  ble/history/get-index -v index
  ble/history/get-count -v count
  local hist_ratio=$(((100*index+count-1)/count))%
  local hist_stat=$'!\e[32m'$index$'\e[m / \e[32m'$count$'\e[m (\e[32m'$hist_ratio$'\e[m)'

  local ret
  ble/string#count-char "$_ble_edit_str" $'\n'; local nline=$((ret+1))
  ble/string#count-char "${_ble_edit_str::_ble_edit_ind}" $'\n'; local iline=$((ret+1))
  local line_ratio=$(((100*iline+nline-1)/nline))%
  local line_stat=$'line \e[34m'$iline$'\e[m / \e[34m'$nline$'\e[m --\e[34m'$line_ratio$'\e[m--'

  ble/edit/info/show ansi "\"$hist_stat\" $line_stat"
  ble/keymap:vi/adjust-command-mode
  return 0
}

# nmap C-c (jobs)
function ble/widget/vi-command/cancel {
  if [[ $_ble_keymap_vi_single_command ]]; then
    _ble_keymap_vi_single_command=
    _ble_keymap_vi_single_command_overwrite=
    ble/keymap:vi/update-mode-indicator
  else
    local joblist; ble/util/joblist
    if ((${#joblist[*]})); then
      ble/array#push joblist $'Type  \e[35m:q!\e[m  and press \e[35m<Enter>\e[m to abandon all \e[31mjobs\e[m and exit Bash'
      IFS=$'\n' builtin eval 'ble/edit/info/show ansi "${joblist[*]}"'
    else
      ble/edit/info/show ansi $'Type  \e[35m:q\e[m  and press \e[35m<Enter>\e[m to exit Bash'
    fi
  fi
  ble/widget/vi-command/bell
  return 0
}

# nmap u, U, C-r
#
#   `[`] is set. Unlike vim, it extracts the range that actually changed.
#   . is not set.
#
bleopt/declare -v keymap_vi_imap_undo ''
_ble_keymap_vi_undo_suppress=
function ble/keymap:vi/undo/add {
  [[ $_ble_keymap_vi_undo_suppress ]] && return 0
  [[ $1 == more && $bleopt_keymap_vi_imap_undo != more ]] && return 0
  ble-edit/undo/add
}
function ble/widget/vi_nmap/undo {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  local _ble_keymap_vi_undo_suppress=1
  ble/keymap:vi/mark/start-edit-area
  if ble-edit/undo/undo "$ARG"; then
    ble/keymap:vi/needs-eol-fix && ((_ble_edit_ind--))
    ble/keymap:vi/mark/end-edit-area
    ble/keymap:vi/adjust-command-mode
  else
    ble/widget/vi-command/bell
    return 1
  fi
}
function ble/widget/vi_nmap/redo {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  local _ble_keymap_vi_undo_suppress=1
  ble/keymap:vi/mark/start-edit-area
  if ble-edit/undo/redo "$ARG"; then
    ble/keymap:vi/needs-eol-fix && ((_ble_edit_ind--))
    ble/keymap:vi/mark/end-edit-area
    ble/keymap:vi/adjust-command-mode
  else
    ble/widget/vi-command/bell
    return 1
  fi
}
function ble/widget/vi_nmap/revert {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  local _ble_keymap_vi_undo_suppress=1
  ble/keymap:vi/mark/start-edit-area
  if ble-edit/undo/revert-toggle "$ARG"; then
    ble/keymap:vi/needs-eol-fix && ((_ble_edit_ind--))
    ble/keymap:vi/mark/end-edit-area
    ble/keymap:vi/adjust-command-mode
  else
    ble/widget/vi-command/bell
    return 1
  fi
}

# nmap C-a, C-x
function ble/widget/vi_nmap/increment.impl {
  local delta=$1
  ((delta==0)) && return 0

  # Determining the range of numbers
  local line=${_ble_edit_str:_ble_edit_ind}
  line=${line%%$'\n'*}
  local rex='^([^0-9]*)[0-9]+'
  if ! [[ $line =~ $rex ]]; then
    # The bell does not ring when you are at the end of the line (meaning an empty line).
    [[ $line ]] && ble/widget/.bell 'number not found'
    ble/keymap:vi/adjust-command-mode
    return 0
  fi
  local rematch1=${BASH_REMATCH[1]}
  local beg=$((_ble_edit_ind+${#rematch1}))
  local end=$((_ble_edit_ind+${#BASH_REMATCH}))
  rex='-?[0-9]*$'; [[ ${_ble_edit_str::beg} =~ $rex ]]
  ((beg-=${#BASH_REMATCH}))

  # Extracting numbers
  local number=${_ble_edit_str:beg:end-beg}
  local abs=${number#-}
  if [[ $abs == 0?* ]]; then
    if [[ $number == -* ]]; then
      number=-$((10#0$abs))
    else
      number=$((10#0$abs))
    fi
  fi

  # Increase/decrease in number
  ((number+=delta))
  if [[ $abs == 0?* ]]; then
    # Zero padding
    local wsign=$((number<0?1:0))
    local zpad=$((wsign+${#abs}-${#number}))
    if ((zpad>0)); then
      local ret; ble/string#repeat 0 "$zpad"
      number=${number::wsign}$ret${number:wsign}
    fi
  fi

  ble/widget/.replace-range "$beg" "$end" "$number"
  ble/keymap:vi/mark/set-previous-edit-area "$beg" "$((beg+${#number}))"
  ble/keymap:vi/repeat/record
  _ble_edit_ind=$((beg+${#number}-1))
  ble/keymap:vi/adjust-command-mode
  return 0
}
function ble/widget/vi_nmap/increment {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi_nmap/increment.impl "$ARG"
}
function ble/widget/vi_nmap/decrement {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi_nmap/increment.impl "$((-ARG))"
}
function ble/widget/vi_nmap/__line_limit__.edit {
  ble/keymap:vi/clear-arg
  ble/widget/vi_nmap/.insert-mode
  ble/keymap:vi/repeat/clear-insert
  ble/widget/edit-and-execute-command.impl "$1"
}
function ble/widget/vi_nmap/__line_limit__ {
  ble/widget/__line_limit__ vi_nmap/__line_limit__.edit
}

function ble-decode/keymap:vi_nmap/define {
  ble/keymap:vi/set-up-command-map

  ble-bind -f __default__    vi-command/decompose-meta
  ble-bind -f __line_limit__ vi_nmap/__line_limit__
  ble-bind -f 'ESC' vi-command/bell
  ble-bind -f 'C-[' vi-command/bell
  ble-bind -f 'C-c' vi-command/cancel

  ble-bind -f a      vi_nmap/append-mode
  ble-bind -f A      vi_nmap/append-mode-at-end-of-line
  ble-bind -f i      vi_nmap/insert-mode
  ble-bind -f insert vi_nmap/insert-mode
  ble-bind -f I      vi_nmap/insert-mode-at-first-non-space
  ble-bind -f 'g I'  vi_nmap/insert-mode-at-beginning-of-line
  ble-bind -f o      vi_nmap/insert-mode-at-forward-line
  ble-bind -f O      vi_nmap/insert-mode-at-backward-line
  ble-bind -f R      vi_nmap/replace-mode
  ble-bind -f 'g R'  vi_nmap/virtual-replace-mode
  ble-bind -f 'g i'  vi_nmap/insert-mode-at-previous-point

  ble-bind -f '~'    vi_nmap/forward-char-toggle-case

  ble-bind -f Y      vi_nmap/copy-current-line
  ble-bind -f S      vi_nmap/kill-current-line-and-insert
  ble-bind -f D      vi_nmap/kill-forward-line
  ble-bind -f C      vi_nmap/kill-forward-line-and-insert

  ble-bind -f p      vi_nmap/paste-after
  ble-bind -f P      vi_nmap/paste-before

  ble-bind -f x      vi_nmap/kill-forward-char
  ble-bind -f s      vi_nmap/kill-forward-char-and-insert
  ble-bind -f X      vi_nmap/kill-backward-char
  ble-bind -f delete vi_nmap/kill-forward-char

  ble-bind -f 'r'    vi_nmap/replace-char
  ble-bind -f 'g r'  vi_nmap/virtual-replace-char # When I try it with vim, this function does not exist.

  ble-bind -f J      vi_nmap/connect-line-with-space
  ble-bind -f 'g J'  vi_nmap/connect-line

  ble-bind -f v      vi_nmap/charwise-visual-mode
  ble-bind -f V      vi_nmap/linewise-visual-mode
  ble-bind -f C-v    vi_nmap/blockwise-visual-mode
  ble-bind -f C-q    vi_nmap/blockwise-visual-mode
  ble-bind -f 'g v'  vi-command/previous-visual-area
  ble-bind -f 'g h'    vi_nmap/charwise-select-mode
  ble-bind -f 'g H'    vi_nmap/linewise-select-mode
  ble-bind -f 'g C-h'  vi_nmap/blockwise-select-mode

  ble-bind -f .      vi_nmap/repeat

  ble-bind -f K      vi_nmap/command-help
  ble-bind -f f1     vi_nmap/command-help

  ble-bind -f 'C-d'   vi_nmap/forward-line-scroll
  ble-bind -f 'C-u'   vi_nmap/backward-line-scroll
  ble-bind -f 'C-e'   vi_nmap/forward-scroll
  ble-bind -f 'C-y'   vi_nmap/backward-scroll
  ble-bind -f 'C-f'   vi_nmap/pagedown
  ble-bind -f 'next'  vi_nmap/pagedown
  ble-bind -f 'C-b'   vi_nmap/pageup
  ble-bind -f 'prior' vi_nmap/pageup
  ble-bind -f 'z t'   vi_nmap/scroll-to-top-and-redraw
  ble-bind -f 'z z'   vi_nmap/scroll-to-center-and-redraw
  ble-bind -f 'z b'   vi_nmap/scroll-to-bottom-and-redraw
  ble-bind -f 'z RET' vi_nmap/scroll-to-top-non-space-and-redraw
  ble-bind -f 'z C-m' vi_nmap/scroll-to-top-non-space-and-redraw
  ble-bind -f 'z +'   vi_nmap/scroll-or-pagedown-and-redraw
  ble-bind -f 'z -'   vi_nmap/scroll-to-bottom-non-space-and-redraw
  ble-bind -f 'z .'   vi_nmap/scroll-to-center-non-space-and-redraw

  ble-bind -f m      vi-command/set-mark
  ble-bind -f '"'    vi-command/register

  ble-bind -f 'C-g' vi-command/show-line-info

  ble-bind -f 'q' vi_nmap/record-register
  ble-bind -f '@' vi_nmap/play-register

  ble-bind -f u   vi_nmap/undo
  ble-bind -f C-r vi_nmap/redo
  ble-bind -f U   vi_nmap/revert

  ble-bind -f C-a vi_nmap/increment
  ble-bind -f C-x vi_nmap/decrement

  ble-bind -f 'Z Z' 'vi-command:q'
  ble-bind -f 'Z Q' 'vi-command:q'

  #----------------------------------------------------------------------------
  # bash

  ble-bind -f 'C-j'      'accept-line'
  ble-bind -f 'C-RET'    'accept-line'
  ble-bind -f 'C-m'      'accept-single-line-or vi-command/forward-first-non-space'
  ble-bind -f 'RET'      'accept-single-line-or vi-command/forward-first-non-space'
  #ble-bind -f 'C-x C-e'  'vi-command/edit-and-execute-command'
  ble-bind -f 'C-l'      'clear-screen'
  ble-bind -f 'C-d'      'vi-command/exit-on-empty-line' # overwrites vi_nmap/forward-scroll
  ble-bind -f 'ac_enter' 'auto-complete-enter'

  # Note #D1256: For Bash vi-command compatibility
  ble-bind -f M-left   'vi-command/backward-vword'
  ble-bind -f M-right  'vi-command/forward-vword'
  ble-bind -f C-delete 'vi-rlfunc/kill-word'
  ble-bind -f '#'      'vi-rlfunc/insert-comment'
  ble-bind -f '&'      'vi_nmap/@edit tilde-expand'

  # ble-bind -f 'C-u' 'vi-rlfunc/unix-line-discard'
  # ble-bind -f 'C-q' 'vi-rlfunc/quoted-insert'
  # ble-bind -f 'C-v' 'vi-rlfunc/quoted-insert'
  # ble-bind -f 'C-d' 'vi-rlfunc/eof-maybe'
  # ble-bind -f '_'   'vi-rlfunc/yank-arg'
}

# For lib/core-decode.vi_nmap-rlfunc.txt

function ble/widget/vi-rlfunc/.is-uppercase {
  local n=${#KEYS[@]}
  local code=$((KEYS[n?n-1:0]&_ble_decode_MaskChar))
  ((0x41<=code&&code<=0x5a))
}

# d or D
function ble/widget/vi-rlfunc/delete-to {
  if ble/widget/vi-rlfunc/.is-uppercase; then
    ble/widget/vi_nmap/kill-forward-line
  else
    ble/widget/vi-command/operator d
  fi
}
# c or C
function ble/widget/vi-rlfunc/change-to {
  if ble/widget/vi-rlfunc/.is-uppercase; then
    ble/widget/vi_nmap/kill-forward-line-and-insert
  else
    ble/widget/vi-command/operator c
  fi
}
# y or Y
function ble/widget/vi-rlfunc/yank-to {
  if ble/widget/vi-rlfunc/.is-uppercase; then
    ble/widget/vi_nmap/copy-current-line
  else
    ble/widget/vi-command/operator y
  fi
}
function ble/widget/vi-rlfunc/char-search {
  local n=${#KEYS[@]}
  local code=$((KEYS[n?n-1:0]&_ble_decode_MaskChar))
  ((code==0)) && return 1
  ble/util/c2s "$code"
  case $ret in
  ('f') ble/widget/vi-command/search-forward-char ;;
  ('F') ble/widget/vi-command/search-backward-char ;;
  ('t') ble/widget/vi-command/search-forward-char-prev ;;
  ('T') ble/widget/vi-command/search-backward-char-prev ;;
  (';') ble/widget/vi-command/search-char-repeat ;;
  (',') ble/widget/vi-command/search-char-reverse-repeat ;;
  (*) return 1 ;;
  esac
}
# w or W
function ble/widget/vi-rlfunc/next-word {
  if ble/widget/vi-rlfunc/.is-uppercase; then
    ble/widget/vi-command/forward-uword
  else
    ble/widget/vi-command/forward-vword
  fi
}
# b or B
function ble/widget/vi-rlfunc/prev-word {
  if ble/widget/vi-rlfunc/.is-uppercase; then
    ble/widget/vi-command/backward-uword
  else
    ble/widget/vi-command/backward-vword
  fi
}
# e or E
function ble/widget/vi-rlfunc/end-word {
  if ble/widget/vi-rlfunc/.is-uppercase; then
    ble/widget/vi-command/forward-uword-end
  else
    ble/widget/vi-command/forward-vword-end
  fi
}
# p or P
function ble/widget/vi-rlfunc/put {
  if ble/widget/vi-rlfunc/.is-uppercase; then
    ble/widget/vi_nmap/paste-before
  else
    ble/widget/vi_nmap/paste-after
  fi
}
# / or ?
function ble/widget/vi-rlfunc/search {
  local n=${#KEYS[@]}
  local code=$((KEYS[n?n-1:0]&_ble_decode_MaskChar))
  if ((code==63)); then
    ble/widget/vi-command/search-backward
  else
    ble/widget/vi-command/search-forward
  fi
}
# n or N
function ble/widget/vi-rlfunc/search-again {
  if ble/widget/vi-rlfunc/.is-uppercase; then
    ble/widget/vi-command/search-reverse-repeat
  else
    ble/widget/vi-command/search-repeat
  fi
}
# s or S
function ble/widget/vi-rlfunc/subst {
  if ble/widget/vi-rlfunc/.is-uppercase; then
    ble/widget/vi_nmap/kill-current-line-and-insert
  else
    ble/widget/vi_nmap/kill-forward-char-and-insert
  fi
}
# rl_nmap C-delete
function ble/widget/vi-rlfunc/kill-word {
  _ble_keymap_vi_opfunc=d
  ble/widget/vi-command/forward-vword-end
}

# rl_nmap -
function ble/widget/vi-rlfunc/backward-delete-char {
  _ble_keymap_vi_opfunc=d
  _ble_keymap_vi_reg=95 # use black-hole register ("_) to discard the text
  ble/widget/vi-command/backward-char
}
function ble/widget/vi-rlfunc/backward-kill-line {
  _ble_keymap_vi_opfunc=d
  ble/widget/vi-command/beginning-of-line
}
function ble/widget/vi-rlfunc/backward-kill-word {
  _ble_keymap_vi_opfunc=d
  ble/widget/vi-command/backward-vword
}
function ble/widget/vi-rlfunc/copy-backward-word {
  # Note: We use vword instead of cword used in the emacs keymap.  This may be
  # replaced with a cword implementation later.
  _ble_keymap_vi_opfunc=y
  ble/widget/vi-command/backward-vword
}
function ble/widget/vi-rlfunc/copy-forward-word {
  # Note: We use vword instead of cword used in the emacs keymap.  This may be
  # replaced with a cword implementation later.
  _ble_keymap_vi_opfunc=y
  ble/widget/vi-command/forward-vword
}

# rl_nmap C-u
function ble/widget/vi-rlfunc/unix-line-discard {
  _ble_keymap_vi_opfunc=d
  ble/widget/vi-command/beginning-of-line
}
# rl_nmap #
function ble/widget/vi-rlfunc/insert-comment {
  local ARG FLAG REG; ble/keymap:vi/get-arg ''
  ble/keymap:vi/mark/start-edit-area
  ble/widget/insert-comment/.insert "$ARG"
  ble/keymap:vi/mark/end-edit-area
  ble/widget/vi_nmap/accept-line
}
# rl_nmap C-v, C-q
function ble/widget/vi-rlfunc/quoted-insert-char.hook {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/keymap:vi/mark/start-edit-area
  _ble_edit_arg=$ARG ble/widget/quoted-insert-char.hook
  ble/keymap:vi/mark/end-edit-area
  ble/keymap:vi/repeat/record
  ble/keymap:vi/adjust-command-mode
  return 0
}
function ble/widget/vi-rlfunc/quoted-insert-char {
  _ble_edit_mark_active=
  _ble_decode_char__hook=ble/widget/vi-rlfunc/quoted-insert-char.hook
  return 147
}
function ble/widget/vi-rlfunc/quoted-insert.hook {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/keymap:vi/mark/start-edit-area
  _ble_edit_arg=$ARG ble/widget/quoted-insert.hook
  ble/keymap:vi/mark/end-edit-area
  ble/keymap:vi/repeat/record
  ble/keymap:vi/adjust-command-mode
  return 0
}
function ble/widget/vi-rlfunc/quoted-insert {
  _ble_edit_mark_active=
  _ble_decode_key__hook=ble/widget/vi-rlfunc/quoted-insert.hook
  return 147
}
# rl_nmap C-d
function ble/widget/vi-rlfunc/eof-maybe {
  if [[ ! $_ble_edit_str ]]; then
    ble/widget/exit
    ble/keymap:vi/adjust-command-mode # Because it will not end when there is a job.
    return 1
  elif ble-edit/is-single-complete-line; then
    ble/widget/vi_nmap/accept-line
  else
    local ARG FLAG REG; ble/keymap:vi/get-arg 1
    ble/keymap:vi/mark/start-edit-area
    _ble_edit_ind=${#_ble_edit_str}
    _ble_edit_arg=$ARG
    ble/widget/self-insert
    ble/keymap:vi/mark/end-edit-area
    ble/keymap:vi/adjust-command-mode
  fi
}
# rl_nmap _
function ble/widget/vi-rlfunc/yank-arg {
  ble/widget/vi_nmap/append-mode
  ble/keymap:vi/imap-repeat/reset
  local -a KEYS; KEYS=(32)
  ble/widget/self-insert
  ble/util/unlocal KEYS
  ble/widget/insert-last-argument
  return "$?"
}

# rlfunc: forward-byte, backward-byte
function ble/widget/vi-command/forward-byte {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  local index=$_ble_edit_ind
  ble/widget/.locate-forward-byte "$ARG" || [[ $FLAG ]] || ble/widget/.bell
  ble/widget/vi-command/exclusive-goto.impl "$index" "$FLAG" "$REG"
}
function ble/widget/vi-command/backward-byte {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  local index=$_ble_edit_ind
  ble/widget/.locate-forward-byte "$((-ARG))" || [[ $FLAG ]] || ble/widget/.bell
  ble/widget/vi-command/exclusive-goto.impl "$index" "$FLAG" "$REG"
}

function ble/widget/vi-command/execute-named-command/accept.hook {
  ble/keymap:vi/update-mode-indicator
  ble/widget/execute-named-command/accept.hook "$1"
}
function ble/widget/vi-command/execute-named-command {
  ble/keymap:vi/async-commandline-mode 'ble/widget/vi-command/execute-named-command/accept.hook'
  _ble_keymap_vi_cmap_before_widget=ble/edit/async-read-mode/empty-cancel.hook
  ble/history/set-prefix _ble_edit_rlfunc
  _ble_edit_PS1='!'
  _ble_syntax_lang=edit.named-command
  _ble_highlight_layer_list=(plain syntax region overwrite_mode)
  return 147
}

# rlfunc: capitalize-word, downcase-word, upcase-word
#%define 2
function ble/widget/vi_nmap/capitalize-XWORD { ble/widget/filter-word.impl XWORD ble/string#capitalize; }
function ble/widget/vi_nmap/downcase-XWORD   { ble/widget/filter-word.impl XWORD ble/string#tolower; }
function ble/widget/vi_nmap/upcase-XWORD     { ble/widget/filter-word.impl XWORD ble/string#toupper; }
#%end
#%expand 2.r/XWORD/eword/
#%expand 2.r/XWORD/cword/
#%expand 2.r/XWORD/uword/
#%expand 2.r/XWORD/sword/
#%expand 2.r/XWORD/fword/

function ble/widget/vi_nmap/@edit {
  ble/keymap:vi/clear-arg
  ble/keymap:vi/repeat/record
  ble/keymap:vi/mark/start-edit-area
  ble/widget/"$@"
  ble/keymap:vi/needs-eol-fix && ((_ble_edit_ind--))
  ble/keymap:vi/mark/end-edit-area
  ble/keymap:vi/adjust-command-mode
}
function ble/widget/vi_nmap/@adjust {
  ble/keymap:vi/clear-arg
  ble/widget/"$@"
  ble/keymap:vi/adjust-command-mode
}
function ble/widget/vi_nmap/@motion {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  local _ble_edit_ind=$_ble_edit_ind _ble_edit_arg=$ARG
  if ble/widget/"$@"; then
    local index=$_ble_edit_ind
    ble/util/unlocal _ble_edit_ind
    ble/widget/vi-command/exclusive-goto.impl "$index" "$FLAG" "$REG" nobell
  else
    ble/keymap:vi/adjust-command-mode
  fi
}

#------------------------------------------------------------------------------
# Visual mode

# The selection type is distinguished by the character string set to _ble_edit_mark_active.
#
#   _ble_edit_mark_active is one of vi_char, vi_line, vi_block
#   Additionally, if tail extension (extending the selection to the end of the line) is set,
#   Add a + at the end, such as vi_char+, vi_line+, vi_block+, etc.

function ble/keymap:vi/xmap/has-eol-extension {
  [[ $_ble_edit_mark_active == *+ ]]
}
function ble/keymap:vi/xmap/add-eol-extension {
  [[ $_ble_edit_mark_active ]] &&
    _ble_edit_mark_active=${_ble_edit_mark_active%+}+
}
function ble/keymap:vi/xmap/remove-eol-extension {
  [[ $_ble_edit_mark_active ]] &&
    _ble_edit_mark_active=${_ble_edit_mark_active%+}
}
function ble/keymap:vi/xmap/switch-type {
  local suffix; [[ $_ble_edit_mark_active == *+ ]] && suffix=+
  _ble_edit_mark_active=$1$suffix
}

#--------------------------------------
# xmap/extract rectangular range

## @fn local p0 q0 lx ly rx ry; ble/keymap:vi/get-graphical-rectangle [index1 [index2]]
## @fn local p0 q0 lx ly rx ry; ble/keymap:vi/get-logical-rectangle   [index1 [index2]]
## @fn local p0 q0 lx ly rx ry; ble/keymap:vi/get-rectangle [index1 [index2]]
## @fn local ret              ; ble/keymap:vi/get-rectangle-height [index1 [index2]]
##
##   @param[in,opt] index1 [=_ble_edit_mark]
##   @param[in,opt] index2 [=_ble_edit_ind]
##
##   @var[out] p0 q0
##   @var[out] lx ly rx ry
##
function ble/keymap:vi/get-graphical-rectangle {
  local p=${1:-$_ble_edit_mark} q=${2:-$_ble_edit_ind}
  local ret
  ble-edit/content/find-logical-bol "$p"; p0=$ret
  ble-edit/content/find-logical-bol "$q"; q0=$ret

  local p0x p0y q0x q0y
  ble/textmap#getxy.out --prefix=p0 "$p0"
  ble/textmap#getxy.out --prefix=q0 "$q0"

  local plx ply qlx qly
  ble/textmap#getxy.cur --prefix=pl "$p"
  ble/textmap#getxy.cur --prefix=ql "$q"

  local prx=$plx pry=$ply qrx=$qlx qry=$qly
  ble-edit/content/eolp "$p" && ((prx++)) || ble/textmap#getxy.out --prefix=pr "$((p+1))"
  ble-edit/content/eolp "$q" && ((qrx++)) || ble/textmap#getxy.out --prefix=qr "$((q+1))"

  ((ply-=p0y,qly-=q0y,pry-=p0y,qry-=q0y,
    (ply<qly||ply==qly&&plx<qlx)?(lx=plx,ly=ply):(lx=qlx,ly=qly),
    (pry>qry||pry==qry&&prx>qrx)?(rx=prx,ry=pry):(rx=qrx,ry=qry)))
}
function ble/keymap:vi/get-logical-rectangle {
  local p=${1:-$_ble_edit_mark} q=${2:-$_ble_edit_ind}
  local ret
  ble-edit/content/find-logical-bol "$p"; p0=$ret
  ble-edit/content/find-logical-bol "$q"; q0=$ret
  ((p-=p0,q-=q0,p<=q)) || local p=$q q=$p
  lx=$p rx=$((q+1)) ly=0 ry=0
}
function ble/keymap:vi/get-rectangle {
  if ble/edit/use-textmap; then
    ble/keymap:vi/get-graphical-rectangle "$@"
  else
    ble/keymap:vi/get-logical-rectangle "$@"
  fi
}
## @fn ble/keymap:vi/get-rectangle-height [index1 [index2]]
##   @var[out] ret
function ble/keymap:vi/get-rectangle-height {
  local p0 q0 lx ly rx ry
  ble/keymap:vi/get-rectangle "$@"
  ble/string#count-char "${_ble_edit_str:p0:q0-p0}" $'\n'
  ((ret++))
  return 0
}


## @fn ble/keymap:vi/extract-graphical-block-by-geometry bol1 bol2 x1:y1 x2:y2 opts
## @fn ble/keymap:vi/extract-logical-block-by-geometry bol1 bol2 c1 c2 opts
##   Extracts a rectangular range based on the specified argument range.
## @fn ble/keymap:vi/extract-graphical-block [index1 [index2 [opts]]]
## @fn ble/keymap:vi/extract-logical-block [index1 [index2 [opts]]]
## @fn ble/keymap:vi/extract-block [index1 [index2 [opts]]]
##   Extracts a rectangular range based on the current position (_ble_edit_ind) and mark (_ble_edit_mark).
##
##   @param[in] bol1 bol2
##     Specify the beginning of two lines.
##   @param[in] x1:y1 x2:y2
##     Specify the two columns relative to the beginning of the line.
##   @param[in] c1 c2
##     Specify the two columns as logical columns.
##
##   @param[in,opt] index1 [$_ble_edit_mark]
##   @param[in,opt] index2 [$_ble_edit_ind]
##     Specifies the character index of the endpoint of the rectangle.
##
##   @param[in,opt] opts
##     Colon-separated flag specifications.
##
##     first_line
##       Get information only about the first row that makes up the rectangle.
##       For other rows, empty information (':::::') is stored in sub_ranges.
##
##     skip_middle
##       Get information only about the first and last rows that make up the rectangle.
##       For other rows, empty information (':::::') is stored in sub_ranges.
##
##   @var[in] _ble_edit_mark_active
##     When performing trailing expansion, specify + at the end of this argument.
##
##   @arr[out] sub_ranges
##     Stores information for each row that makes up the rectangle.
##     Each element has the following format:
##
##     smin:smax:slpad:srpad:sfill:stext
##
##     smin smax
##       Specify the range to emphasize/cut the selection.
##     slpad srpad
##       Specifies the number of blank spaces to fill on the left and right when cutting the selection.
##     sfill
##       Specifies the number of spaces to be padded on the right edge when inserting a rectangle.
##     stext
##       Specifies the string to be read from the selection.
##       When full-width characters, etc. cross the range boundary,
##       The character is replaced with spaces (as many spaces as the range spans).
##   @var[out] sub_x1 sub_x2
##
function ble/keymap:vi/extract-graphical-block-by-geometry {
  local bol1=$1 bol2=$2 x1=$3 x2=$4 y1=0 y2=0 opts=$5
  ((bol1<=bol2||(bol1=$2,bol2=$1)))
  [[ $x1 == *:* ]] && local x1=${x1%%:*} y1=${x1#*:}
  [[ $x2 == *:* ]] && local x2=${x2%%:*} y2=${x2#*:}

  local cols=$_ble_textmap_cols
  local c1=$((cols*y1+x1)) c2=$((cols*y2+x2))
  sub_x1=$c1 sub_x2=$c2

  local ret index lx ly rx ly

  ble-edit/content/find-logical-eol "$bol2"; local eol2=$ret
  local lines; ble/string#split-lines lines "${_ble_edit_str:bol1:eol2-bol1}"

  sub_ranges=()
  local min_sfill=0
  local line bol=$bol1 eol bolx boly
  local c1l c1r c2l c2r
  for line in "${lines[@]}"; do
    ((eol=bol+${#line}))

    if [[ :$opts: == *:first_line:* ]] && ((${#sub_ranges[@]})); then
      ble/array#push sub_ranges :::::
    elif [[ :$opts: == *:skip_middle:* ]] && ((0<${#sub_ranges[@]}&&${#sub_ranges[@]}<${#lines[@]}-1)); then
      ble/array#push sub_ranges :::::
    else
      ble/textmap#getxy.out --prefix=bol "$bol"
      ble/textmap#hit out "$x1" "$((boly+y1))" "$bol" "$eol"
      local smin=$index x1l=$lx y1l=$ly x1r=$rx y1r=$ry
      if ble/keymap:vi/xmap/has-eol-extension; then
        local eolx eoly; ble/textmap#getxy.out --prefix=eol "$eol"
        local smax=$eol x2l=$eolx y2l=$eoly x2r=$eolx y2r=$eoly
      else
        ble/textmap#hit out "$x2" "$((boly+y2))" "$bol" "$eol"
        local smax=$index x2l=$lx y2l=$ly x2r=$rx y2r=$ry
      fi

      local sfill=0 slpad=0 srpad=0
      local stext=${_ble_edit_str:smin:smax-smin}
      if ((smin<smax)); then
        # 1. If a large character straddles the left border c1, convert it to a blank space.
        ((c1l=(y1l-boly)*cols+x1l))
        if ((c1l<c1)); then
          ((slpad=c1-c1l))

          # assert: smin < smax <= eol, so it's not the end of the line
          ble/util/assert '! ble-edit/content/eolp "$smin"'

          ((c1r=(y1r-boly)*cols+x1r))
          ble/util/assert '((c1r>c1))' || ((c1r=c1))
          ble/string#repeat ' ' "$((c1r-c1))"
          stext=$ret${stext:1}
        fi

        # 2. If a large character straddles the right border c2, convert it to a blank space.
        ((c2l=(y2l-boly)*cols+x2l))
        if ((c2l<c2)); then
          if ((smax==eol)); then
            ((sfill=c2-c2l))
          else
            ble/string#repeat ' ' "$((c2-c2l))"
            stext=$stext$ret
            ((smax++))

            ((c2r=(y2r-boly)*cols+x2r))
            ble/util/assert '((c2r>c2))' || ((c2r=c2))
            ((srpad=c2r-c2))
          fi
        elif ((c2l>c2)); then
          # It should come here only when ble/keymap:vi/xmap/has-eol-extension is used.
          ((sfill=c2-c2l,
            sfill<min_sfill&&(min_sfill=sfill)))
        fi
      else
        if ((smin==eol)); then
          # end of line
          ((sfill=c2-c1))
        elif ((c2>c1)); then
          # Both ends of the range are to the left of or within a single character
          ble/string#repeat ' ' "$((c2-c1))"
          stext=$ret${stext:1}
          ((smax++))

          ((c1l=(y1l-boly)*cols+x1l,slpad=c1-c1l))
          ((c1r=(y1r-boly)*cols+x1r,srpad=c1r-c1))
        fi
      fi

      ble/array#push sub_ranges "$smin:$smax:$slpad:$srpad:$sfill:$stext"
    fi

    ((bol=eol+1))
  done

  if ((min_sfill<0)); then
    local isub=${#sub_ranges[@]}
    while ((isub--)); do
      local sub=${sub_ranges[isub]}
      local sub45=${sub#*:*:*:*:}
      local sfill=${sub45%%:*}
      sub_ranges[isub]=${sub::${#sub}-${#sub45}}$((sfill-min_sfill))${sub45:${#sfill}}
    done
  fi
}
function ble/keymap:vi/extract-graphical-block {
  local opts=$3
  local p0 q0 lx ly rx ry
  ble/keymap:vi/get-graphical-rectangle "$@"
  ble/keymap:vi/extract-graphical-block-by-geometry "$p0" "$q0" "$lx:$ly" "$rx:$ry" "$opts"
}
function ble/keymap:vi/extract-logical-block-by-geometry {
  local bol1=$1 bol2=$2 x1=$3 x2=$4 opts=$5
  ((bol1<=bol2||(bol1=$2,bol2=$1)))
  sub_x1=$c1 sub_x2=$c2

  local ret min_sfill=0
  local bol=$bol1 eol smin smax slpad srpad sfill
  sub_ranges=()
  while ((1)); do
    ble-edit/content/find-logical-eol "$bol"; eol=$ret
    slpad=0 srpad=0 sfill=0
    ((smin=bol+x1,smin>eol&&(smin=eol)))
    if ble/keymap:vi/xmap/has-eol-extension; then
      ((smax=eol,
        sfill=bol+x2-eol,
        sfill<min_sfill&&(min_sfill=sfill)))
    else
      ((smax=bol+x2,smax>eol&&(sfill=smax-eol,smax=eol)))
    fi

    local stext=${_ble_edit_str:smin:smax-smin}

    ble/array#push sub_ranges "$smin:$smax:$slpad:$srpad:$sfill:$stext"

    ((bol>=bol2)) && break
    ble-edit/content/find-logical-bol "$bol" 1; bol=$ret
  done

  if ((min_sfill<0)); then
    local isub=${#sub_ranges[@]}
    while ((isub--)); do
      local sub=${sub_ranges[isub]}
      local sub45=${sub#*:*:*:*:}
      local sfill=${sub45%%:*}
      sub_ranges[isub]=${sub::${#sub}-${#sub45}}$((sfill-min_sfill))${sub45:${#sfill}}
    done
  fi
}
function ble/keymap:vi/extract-logical-block {
  local opts=$3
  local p0 q0 lx ly rx ry
  ble/keymap:vi/get-logical-rectangle "$@"
  ble/keymap:vi/extract-logical-block-by-geometry "$p0" "$q0" "$lx" "$rx" "$opts"
}
function ble/keymap:vi/extract-block {
  if ble/edit/use-textmap; then
    ble/keymap:vi/extract-graphical-block "$@"
  else
    ble/keymap:vi/extract-logical-block "$@"
  fi
}

#--------------------------------------
# xmap/selection coloring settings

## @fn ble/highlight/layer:region/mark:vi_char/get-selection
## @fn ble/highlight/layer:region/mark:vi_line/get-selection
## @fn ble/highlight/layer:region/mark:vi_block/get-selection
##   @arr[out] selection
function ble/highlight/layer:region/mark:vi_char/get-selection {
  local rmin rmax
  if ((_ble_edit_mark<_ble_edit_ind)); then
    rmin=$_ble_edit_mark rmax=$_ble_edit_ind
  else
    rmin=$_ble_edit_ind rmax=$_ble_edit_mark
  fi
  ble-edit/content/eolp "$rmax" || ((rmax++))
  selection=("$rmin" "$rmax")
}
function ble/highlight/layer:region/mark:vi_line/get-selection {
  local rmin rmax
  if ((_ble_edit_mark<_ble_edit_ind)); then
    rmin=$_ble_edit_mark rmax=$_ble_edit_ind
  else
    rmin=$_ble_edit_ind rmax=$_ble_edit_mark
  fi
  local ret
  ble-edit/content/find-logical-bol "$rmin"; rmin=$ret
  ble-edit/content/find-logical-eol "$rmax"; rmax=$ret
  selection=("$rmin" "$rmax")
}
function ble/highlight/layer:region/mark:vi_block/get-selection {
  local sub_ranges sub_x1 sub_x2
  ble/keymap:vi/extract-block

  selection=()
  local sub
  for sub in "${sub_ranges[@]}"; do
    ble/string#split sub : "$sub"
    ((sub[0]<sub[1])) || continue
    ble/array#push selection "${sub[0]}" "${sub[1]}"
  done
}
function ble/highlight/layer:region/mark:vi_char+/get-selection {
  ble/highlight/layer:region/mark:vi_char/get-selection
}
function ble/highlight/layer:region/mark:vi_line+/get-selection {
  ble/highlight/layer:region/mark:vi_line/get-selection
}
function ble/highlight/layer:region/mark:vi_block+/get-selection {
  ble/highlight/layer:region/mark:vi_block/get-selection
}

function ble/highlight/layer:region/mark:vi_char/get-face   { [[ $_ble_edit_overwrite_mode ]] && face=region_target; }
function ble/highlight/layer:region/mark:vi_char+/get-face  { ble/highlight/layer:region/mark:vi_char/get-face; }
function ble/highlight/layer:region/mark:vi_line/get-face   { ble/highlight/layer:region/mark:vi_char/get-face; }
function ble/highlight/layer:region/mark:vi_line+/get-face  { ble/highlight/layer:region/mark:vi_char/get-face; }
function ble/highlight/layer:region/mark:vi_block/get-face  { ble/highlight/layer:region/mark:vi_char/get-face; }
function ble/highlight/layer:region/mark:vi_block+/get-face { ble/highlight/layer:region/mark:vi_char/get-face; }


#--------------------------------------
# xmap/previous selection size

_ble_keymap_vi_xmap_prev_edit=vi_char:1:1
ble/array#push _ble_textarea_local_VARNAMES \
               _ble_keymap_vi_xmap_prev_edit
function ble/widget/vi_xmap/.save-visual-state {
  local nline nchar mark_type=${_ble_edit_mark_active%+}
  if [[ $mark_type == vi_block ]]; then
    local p0 q0 lx rx ly ry
    if ble/edit/use-textmap; then
      local cols=$_ble_textmap_cols
      ble/keymap:vi/get-graphical-rectangle
      ((lx+=ly*cols,rx+=ry*cols))
    else
      ble/keymap:vi/get-logical-rectangle
    fi

    nchar=$((rx-lx))

    local ret
    ((p0<=q0)) || local p0=$q0 q0=$p0
    ble/string#count-char "${_ble_edit_str:p0:q0-p0}" $'\n'
    nline=$((ret+1))

  else
    local ret
    local p=$_ble_edit_mark q=$_ble_edit_ind
    ((p<=q)) || local p=$q q=$p
    ble/string#count-char "${_ble_edit_str:p:q-p}" $'\n'
    nline=$((ret+1))

    local base
    if ((nline==1)) && [[ $mark_type != vi_line ]]; then
      base=$p
    else
      ble-edit/content/find-logical-bol "$q"; base=$ret
    fi

    if ble/edit/use-textmap; then
      local cols=$_ble_textmap_cols
      local bx by x y
      ble/textmap#getxy.cur --prefix=b "$base"
      ble/textmap#getxy.cur "$q"
      nchar=$((x-bx+(y-by)*cols+1))
    else
      nchar=$((q-base+1))
    fi
  fi

  _ble_keymap_vi_xmap_prev_edit=$_ble_edit_mark_active:$nchar:$nline
}
function ble/widget/vi_xmap/.restore-visual-state {
  local arg=$1; ((arg>0)) || arg=1
  local prev; ble/string#split prev : "$_ble_keymap_vi_xmap_prev_edit"
  _ble_edit_mark_active=${prev[0]:-vi_char}
  local nchar=${prev[1]:-1}
  local nline=${prev[2]:-1}
  ((nchar<1&&(nchar=1),nline<1&&(nline=1)))

  local is_x_relative=0
  if [[ ${_ble_edit_mark_active%+} == vi_block ]]; then
    ((is_x_relative=1,nchar*=arg,nline*=arg))
  elif [[ ${_ble_edit_mark_active%+} == vi_line ]]; then
    ((nline*=arg,is_x_relative=1,nchar=1))
  else
    ((nline==1?(is_x_relative=1,nchar*=arg):(nline*=arg)))
  fi
  ((nchar--,nline--))

  local index ret
  ble-edit/content/find-logical-bol "$_ble_edit_ind" 0; local b1=$ret
  ble-edit/content/find-logical-bol "$_ble_edit_ind" "$nline"; local b2=$ret
  ble-edit/content/find-logical-eol "$b2"; local e2=$ret
  if ble/keymap:vi/xmap/has-eol-extension; then
    index=$e2
  elif ble/edit/use-textmap; then
    local cols=$_ble_textmap_cols
    local b1x b1y b2x b2y x y
    ble/textmap#getxy.out --prefix=b1 "$b1"
    ble/textmap#getxy.out --prefix=b2 "$b2"
    if ((is_x_relative)); then
      ble/textmap#getxy.out "$_ble_edit_ind"
      local c=$((x+(y-b1y)*cols+nchar))
    else
      local c=$nchar
    fi
    ((y=c/cols,x=c%cols))

    local lx ly rx ry
    ble/textmap#hit out "$x" "$((b2y+y))" "$b2" "$e2"
  else
    local c=$((is_x_relative?_ble_edit_ind-b1+nchar:nchar))
    ((index=b2+c,index>e2&&(index=e2)))
  fi

  _ble_edit_mark=$_ble_edit_ind
  _ble_edit_ind=$index
}

#--------------------------------------
# xmap/previous selection

# mark `< `>
_ble_keymap_vi_xmap_prev_visual=
ble/array#push _ble_textarea_local_VARNAMES \
               _ble_keymap_vi_xmap_prev_visual
function ble/keymap:vi/xmap/set-previous-visual-area {
  local beg end
  local mark_type=${_ble_edit_mark_active%+}
  if [[ $mark_type == vi_block ]]; then
    local sub_ranges sub_x1 sub_x2
    ble/keymap:vi/extract-block
    local nrange=${#sub_ranges[*]}
    ((nrange)) || return 1
    local beg=${sub_ranges[0]%%:*}
    local sub2_slice1=${sub_ranges[nrange-1]#*:}
    local end=${sub2_slice1%%:*}
    ((beg<end)) && ! ble-edit/content/bolp "$end" && ((end--))
  else
    local beg=$_ble_edit_mark end=$_ble_edit_ind
    ((beg<=end)) || local beg=$end end=$beg
    if [[ $mark_type == vi_line ]]; then
      local ret
      ble-edit/content/find-logical-bol "$beg"; beg=$ret
      ble-edit/content/find-logical-eol "$end"; end=$ret
      ble-edit/content/bolp "$end" || ((end--))
    fi
  fi
  _ble_keymap_vi_xmap_prev_visual=$_ble_edit_mark_active
  ble/keymap:vi/mark/set-local-mark 60 "$beg" # `<
  ble/keymap:vi/mark/set-local-mark 62 "$end" # `>
}
# nmap/xmap gv
function ble/widget/vi-command/previous-visual-area {
  local mark=$_ble_keymap_vi_xmap_prev_visual
  local ret beg= end=
  ble/keymap:vi/mark/get-local-mark 60 && beg=$ret # `<
  ble/keymap:vi/mark/get-local-mark 62 && end=$ret # `>
  [[ $beg && $end ]] || return 1

  if [[ $_ble_decode_keymap == vi_[xs]map ]]; then
    ble/keymap:vi/clear-arg
    ble/keymap:vi/xmap/set-previous-visual-area
    _ble_edit_ind=$end
    _ble_edit_mark=$beg
    _ble_edit_mark_active=$mark
    ble/keymap:vi/update-mode-indicator
  else
    ble/keymap:vi/clear-arg
    ble/widget/vi-command/visual-mode.impl vi_xmap "$mark"
    _ble_edit_ind=$end
    _ble_edit_mark=$beg
  fi
  return 0
}

#--------------------------------------
# xmap/mode transition

function ble/widget/vi-command/visual-mode.impl {
  local keymap=$1 visual_type=$2
  local ARG FLAG REG; ble/keymap:vi/get-arg 0
  if [[ $FLAG ]]; then
    ble/widget/vi-command/bell
    return 1
  fi

  _ble_edit_overwrite_mode=
  _ble_edit_mark=$_ble_edit_ind
  _ble_edit_mark_active=$visual_type
  _ble_keymap_vi_xmap_insert_data= # *Cancel if further xmap is entered during rectangle insertion.

  ((ARG)) && ble/widget/vi_xmap/.restore-visual-state "$ARG"

  ble/decode/keymap/push "$keymap"
  ble/keymap:vi/update-mode-indicator
  return 0
}
function ble/widget/vi_nmap/charwise-visual-mode {
  ble/widget/vi-command/visual-mode.impl vi_xmap vi_char
}
function ble/widget/vi_nmap/linewise-visual-mode {
  ble/widget/vi-command/visual-mode.impl vi_xmap vi_line
}
function ble/widget/vi_nmap/blockwise-visual-mode {
  ble/widget/vi-command/visual-mode.impl vi_xmap vi_block
}
function ble/widget/vi_nmap/charwise-select-mode {
  ble/widget/vi-command/visual-mode.impl vi_smap vi_char
}
function ble/widget/vi_nmap/linewise-select-mode {
  ble/widget/vi-command/visual-mode.impl vi_smap vi_line
}
function ble/widget/vi_nmap/blockwise-select-mode {
  ble/widget/vi-command/visual-mode.impl vi_smap vi_block
}

function ble/widget/vi_xmap/exit {
  # Note: xmap operator:c
  #   -> vi_xmap/block-insert-mode.impl
  #   → When called via vi_xmap/cancel,
  #   Since it may have already returned to vi_nmap, process only vi_xmap and vi_smap.
  if [[ $_ble_decode_keymap == vi_[xs]map ]]; then
    ble/keymap:vi/xmap/set-previous-visual-area
    _ble_edit_mark_active=
    ble/decode/keymap/pop
    ble/keymap:vi/update-mode-indicator
    ble/keymap:vi/adjust-command-mode
  fi
  return 0
}
function ble/widget/vi_xmap/cancel {
  # Even if you are in single-command-mode, delete it and move to normal.

  _ble_keymap_vi_single_command=
  _ble_keymap_vi_single_command_overwrite=
  ble-edit/content/nonbol-eolp && ((_ble_edit_ind--))
  ble/widget/vi_xmap/exit
}
function ble/widget/vi_xmap/switch-visual-mode.impl {
  local visual_type=$1
  local ARG FLAG REG; ble/keymap:vi/get-arg 0
  if [[ $FLAG ]]; then
    ble/widget/.bell
    return 1
  fi

  if [[ ${_ble_edit_mark_active%+} == "$visual_type" ]]; then
    ble/widget/vi_xmap/cancel
  else
    ble/keymap:vi/xmap/switch-type "$visual_type"
    ble/keymap:vi/update-mode-indicator
    return 0
  fi

}
# xmap v
function ble/widget/vi_xmap/switch-to-charwise {
  ble/widget/vi_xmap/switch-visual-mode.impl vi_char
}
# xmap V
function ble/widget/vi_xmap/switch-to-linewise {
  ble/widget/vi_xmap/switch-visual-mode.impl vi_line
}
# xmap <C-v>
function ble/widget/vi_xmap/switch-to-blockwise {
  ble/widget/vi_xmap/switch-visual-mode.impl vi_block
}
# xmap <C-g>
function ble/widget/vi_xmap/switch-to-select {
  if [[ $_ble_decode_keymap == vi_xmap ]]; then
    ble/decode/keymap/pop
    ble/decode/keymap/push vi_smap
    ble/keymap:vi/update-mode-indicator
  fi
}
# smap <C-g>
function ble/widget/vi_xmap/switch-to-visual {
  if [[ $_ble_decode_keymap == vi_smap ]]; then
    ble/decode/keymap/pop
    ble/decode/keymap/push vi_xmap
    ble/keymap:vi/update-mode-indicator
  fi
}
# smap <C-v>
function ble/widget/vi_xmap/switch-to-visual-blockwise {
  if [[ $_ble_decode_keymap == vi_smap ]]; then
    ble/decode/keymap/pop
    ble/decode/keymap/push vi_xmap
  fi
  if [[ ${_ble_edit_mark_active%+} != vi_block ]]; then
    ble/widget/vi_xmap/switch-to-blockwise
  else
    xble/keymap:vi/update-mode-indicator
  fi
}

## @bleopt keymap_vi_keymodel
##   Controls the behavior of movement commands in selection mode.
bleopt/declare -v keymap_vi_keymodel ''
function ble/widget/vi_smap/@nomarked {
  [[ ,$bleopt_keymap_vi_keymodel, == *,stopsel,* ]] &&
    ble/widget/vi_xmap/exit
  ble/widget/"$@"
}

#--------------------------------------
# xmap/various commands

function ble/widget/vi_smap/self-insert {
  # Note: This implementation is fine for repeat (nmap .).
  #   KEYS=(...) as it is recorded as vi_smap/self-insert.
  ble/widget/vi-command/operator c
  ble/widget/self-insert
}

# xmap o
function ble/widget/vi_xmap/exchange-points {
  ble/keymap:vi/xmap/remove-eol-extension
  ble/widget/exchange-point-and-mark
  return 0
}
# xmap O
function ble/widget/vi_xmap/exchange-boundaries {
  if [[ ${_ble_edit_mark_active%+} == vi_block ]]; then
    ble/keymap:vi/xmap/remove-eol-extension

    local sub_ranges sub_x1 sub_x2
    ble/keymap:vi/extract-block '' '' skip_middle
    local nline=${#sub_ranges[@]}
    ble/util/assert '((nline))'

    local data1; ble/string#split data1 : "${sub_ranges[0]}"
    local lpos1=${data1[0]} rpos1=$((data1[4]?data1[1]:data1[1]-1))
    if ((nline==1)); then
      local lpos2=$lpos1 rpos2=$rpos1
    else
      local data2; ble/string#split data2 : "${sub_ranges[nline-1]}"
      local lpos2=${data2[0]} rpos2=$((data2[4]?data2[1]:data2[1]-1))
    fi

    # lpos2: swap when rpos2 does not support _ble_edit_ind
    if ! ((lpos2<=_ble_edit_ind&&_ble_edit_ind<=rpos2)); then
      local lpos1=$lpos2 lpos2=$lpos1
      local rpos1=$rpos2 rpos2=$rpos1
    fi

    _ble_edit_mark=$((_ble_edit_mark==lpos1?rpos1:lpos1))
    _ble_edit_ind=$((_ble_edit_ind==lpos2?rpos2:lpos2))
    return 0
  else
    ble/widget/vi_xmap/exchange-points
  fi
}

# xmap r{char}
function ble/widget/vi_xmap/visual-replace-char.hook {
  local key=$1
  _ble_edit_overwrite_mode=
  local ARG FLAG REG; ble/keymap:vi/get-arg 1

  local ret
  if [[ $FLAG ]]; then
    ble/widget/.bell
    return 1
  elif ((key==(_ble_decode_Ctrl|91))); then # C-[ -> cancel
    return 27
  elif ! ble/keymap:vi/k2c "$key"; then
    ble/widget/.bell
    return 1
  fi
  local c=$ret
  ble/util/c2s "$c"; local s=$ret

  local old_mark_active=$_ble_edit_mark_active # save
  local mark_type=${_ble_edit_mark_active%+}
  ble/widget/vi_xmap/.save-visual-state
  ble/widget/vi_xmap/exit # Note: _ble_edit_mark_active will be cleared here
  if [[ $mark_type == vi_block ]]; then
    ble/util/c2w "$c"; local w=$ret
    ((w<=0)) && w=1

    local sub_ranges sub_x1 sub_x2
    _ble_edit_mark_active=$old_mark_active ble/keymap:vi/extract-block
    local n=${#sub_ranges[@]}
    if ((n==0)); then
      ble/widget/.bell
      return 1
    fi

    # create ins
    local width=$((sub_x2-sub_x1))
    local count=$((width/w))
    ble/string#repeat "$s" "$count"; local ins=$ret
    local pad=$((width-count*w))
    if ((pad)); then
      ble/string#repeat ' ' "$pad"; ins=$ins$ret
    fi

    local i=$n sub smin=0
    ble/keymap:vi/mark/start-edit-area
    while ((i--)); do
      ble/string#split sub : "${sub_ranges[i]}"
      local smin=${sub[0]} smax=${sub[1]}
      local slpad=${sub[2]} srpad=${sub[3]} sfill=${sub[4]}

      local ins1=$ins
      ((sfill)) && ins1=${ins1::(width-sfill)/w}
      ((slpad)) && { ble/string#repeat ' ' "$slpad"; ins1=$ret$ins1; }
      ((srpad)) && { ble/string#repeat ' ' "$srpad"; ins1=$ins1$ret; }
      ble/widget/.replace-range "$smin" "$smax" "$ins1"
    done
    local beg=$smin
    ble/keymap:vi/needs-eol-fix "$beg" && ((beg--))
    _ble_edit_ind=$beg
    ble/keymap:vi/mark/end-edit-area
    ble/keymap:vi/repeat/record
  else
    local beg=$_ble_edit_mark end=$_ble_edit_ind
    ((beg<=end)) || local beg=$end end=$beg
    if [[ $mark_type == vi_line ]]; then
      ble-edit/content/find-logical-bol "$beg"; local beg=$ret
      ble-edit/content/find-logical-eol "$end"; local end=$ret
    else
      ble-edit/content/eolp "$end" || ((end++))
    fi

    local ins=${_ble_edit_str:beg:end-beg}
    ins=${ins//[!$'\n']/"$s"}
    ble/widget/.replace-range "$beg" "$end" "$ins"
    ble/keymap:vi/needs-eol-fix "$beg" && ((beg--))
    _ble_edit_ind=$beg
    ble/keymap:vi/mark/set-previous-edit-area "$beg" "$end"
    ble/keymap:vi/repeat/record
  fi
  return 0
}
function ble/widget/vi_xmap/visual-replace-char {
  _ble_edit_overwrite_mode=R
  ble/keymap:vi/async-read-char ble/widget/vi_xmap/visual-replace-char.hook
}

function ble/widget/vi_xmap/linewise-operator.impl {
  local op=$1 opts=$2
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  if [[ $FLAG ]]; then
    ble/widget/.bell 'wrong keymap: operators should not be set in xmap'
    return 1
  fi

  local mark_type=${_ble_edit_mark_active%+}
  local beg=$_ble_edit_mark end=$_ble_edit_ind
  ((beg<=end)) || local beg=$end end=$beg

  local call_operator=
  if [[ :$opts: != *:force_line:* && $mark_type == vi_block ]]; then
    call_operator=ble/keymap:vi/call-operator-blockwise
    _ble_edit_mark_active=vi_block
    [[ :$opts: == *:extend:* ]] && _ble_edit_mark_active=vi_block+
  else
    call_operator=ble/keymap:vi/call-operator-linewise
    _ble_edit_mark_active=vi_line
  fi

  local ble_keymap_vi_mark_active=$_ble_edit_mark_active
  ble/widget/vi_xmap/.save-visual-state
  ble/widget/vi_xmap/exit
  "$call_operator" "$op" "$beg" "$end" "$ARG" "$REG"; local ext=$?
  ((ext==147)) && return 147
  ((ext)) && ble/widget/.bell
  ble/keymap:vi/adjust-command-mode
  return "$ext"
}

# xmap C
function ble/widget/vi_xmap/replace-block-lines { ble/widget/vi_xmap/linewise-operator.impl c extend; }
# xmap D X
function ble/widget/vi_xmap/delete-block-lines { ble/widget/vi_xmap/linewise-operator.impl d extend; }
# xmap R S
function ble/widget/vi_xmap/delete-lines { ble/widget/vi_xmap/linewise-operator.impl d force_line; }
# xmap Y
function ble/widget/vi_xmap/copy-block-or-lines { ble/widget/vi_xmap/linewise-operator.impl y; }

function ble/widget/vi_xmap/connect-line.impl {
  local name=$1
  local ARG FLAG REG; ble/keymap:vi/get-arg 1 # ignored

  local beg=$_ble_edit_mark end=$_ble_edit_ind
  ((beg<=end)) || local beg=$end end=$beg
  local ret; ble/string#count-char "${_ble_edit_str:beg:end-beg}" $'\n'; local nline=$((ret+1))

  ble/widget/vi_xmap/.save-visual-state
  ble/widget/vi_xmap/exit # Note: _ble_edit_mark_active will be cleared here

  _ble_edit_ind=$beg
  _ble_edit_arg=$nline
  _ble_keymap_vi_oparg=
  _ble_keymap_vi_opfunc=
  _ble_keymap_vi_reg=
  ble/widget/"$name"
}
# xmap J
function ble/widget/vi_xmap/connect-line-with-space {
  ble/widget/vi_xmap/connect-line.impl vi_nmap/connect-line-with-space
}
# xmap gJ
function ble/widget/vi_xmap/connect-line {
  ble/widget/vi_xmap/connect-line.impl vi_nmap/connect-line
}

#--------------------------------------
# xmap/rectangle insertion mode

## @var _ble_keymap_vi_xmap_insert_data
##   Holds information about rectangle insertion mode.
##   The format is iline:x1:width:content.
##
##   iline
##     Holds the number of the line being edited.
##   x1
##     Holds the insertion start position in the display column.
##   width
##     Retains the original width of the edit line.
##   nline
##     Holds the number of rows.
##
_ble_keymap_vi_xmap_insert_data=
_ble_keymap_vi_xmap_insert_dbeg=-1
ble/array#push _ble_textarea_local_VARNAMES \
               _ble_keymap_vi_xmap_insert_data \
               _ble_keymap_vi_xmap_insert_dbeg
function ble/keymap:vi/xmap/update-dirty-range {
  [[ $_ble_keymap_vi_insert_leave == ble/widget/vi_xmap/block-insert-mode.onleave ]] &&
    ((_ble_keymap_vi_xmap_insert_dbeg<0||beg<_ble_keymap_vi_xmap_insert_dbeg)) &&
    _ble_keymap_vi_xmap_insert_dbeg=$beg
}

## @fn ble/widget/vi_xmap/block-insert-mode.impl
##   @var[in] sub_ranges sub_x1 sub_x2
function ble/widget/vi_xmap/block-insert-mode.impl {
  local type=$1
  local ARG FLAG REG; ble/keymap:vi/get-arg 1

  local nline=${#sub_ranges[@]}
  ble/util/assert '((nline))'

  local index ins_x
  if [[ $type == append ]]; then
    local sub=${sub_ranges[0]#*:}
    local smax=${sub%%:*}
    index=$smax
    if ble/keymap:vi/xmap/has-eol-extension; then
      ins_x='$'
    else
      ins_x=$sub_x2
    fi
  else
    local sub=${sub_ranges[0]}
    local smin=${sub%%:*}
    index=$smin
    ins_x=$sub_x1
  fi

  ble/widget/vi_xmap/cancel
  _ble_edit_ind=$index
  ble/widget/vi_nmap/.insert-mode "$ARG"
  ble/keymap:vi/repeat/record
  ble/keymap:vi/mark/set-local-mark 1 "$_ble_edit_ind"
  _ble_keymap_vi_xmap_insert_dbeg=-1

  local ret display_width
  ble/string#count-char "${_ble_edit_str::_ble_edit_ind}" $'\n'; local iline=$ret
  ble-edit/content/find-logical-bol; local bol=$ret
  ble-edit/content/find-logical-eol; local eol=$ret
  if ble/edit/use-textmap; then
    local bx by ex ey
    ble/textmap#getxy.out --prefix=b "$bol"
    ble/textmap#getxy.out --prefix=e "$eol"
    ((display_width=ex+_ble_textmap_cols*(ey-by)))
  else
    ((display_width=eol-bol))
  fi
  _ble_keymap_vi_xmap_insert_data=$iline:$ins_x:$display_width:$nline
  _ble_keymap_vi_insert_leave=ble/widget/vi_xmap/block-insert-mode.onleave
  return 0
}
function ble/widget/vi_xmap/block-insert-mode.onleave {
  local data=$_ble_keymap_vi_xmap_insert_data
  [[ $data ]] || continue
  _ble_keymap_vi_xmap_insert_data=

  ble/string#split data : "$data"

  # Is the cursor line the same as the recording line?
  local ret
  ble-edit/content/find-logical-bol; local bol=$ret
  ble/string#count-char "${_ble_edit_str::bol}" $'\n'; ((ret==data[0])) || return 1 # Line number
  ble/keymap:vi/mark/get-local-mark 1 || return 1; local mark=$ret # `[
  ble-edit/content/find-logical-bol "$mark"; ((bol==ret)) || return 1 # Is it the same as record line `[?

  local has_textmap=
  if ble/edit/use-textmap; then
    local cols=$_ble_textmap_cols
    has_textmap=1
  fi

  # Display width variable
  local new_width delta
  ble-edit/content/find-logical-eol; local eol=$ret
  if [[ $has_textmap ]]; then
    local bx by ex ey
    ble/textmap#getxy.out --prefix=b "$bol"
    ble/textmap#getxy.out --prefix=e "$eol"
    ((new_width=ex+cols*(ey-by)))
  else
    ((new_width=eol-bol))
  fi
  ((delta=new_width-data[2]))
  ((delta>0)) || return 1 #Do not process if it shrinks

  # Determining the cutout column
  local x1=${data[1]}
  [[ $x1 == '$' ]] && ((x1=data[2]))
  ((x1>new_width&&(x1=new_width)))
  if ((bol<=_ble_keymap_vi_xmap_insert_dbeg&&_ble_keymap_vi_xmap_insert_dbeg<=eol)); then
    local px py
    if [[ $has_textmap ]]; then
      ble/textmap#getxy.out --prefix=p "$_ble_keymap_vi_xmap_insert_dbeg"
      ((px+=cols*(py-by)))
    else
      ((px=_ble_keymap_vi_xmap_insert_dbeg-bol))
    fi
    ((px>x1&&(x1=px)))
  fi
  local x2=$((x1+delta))

  # Cut out
  local ins= p1 p2
  if [[ $has_textmap ]]; then
    local index lx ly rx ry
    ble/textmap#hit out "$((x1%cols))" "$((by+x1/cols))" "$bol" "$eol"; p1=$index
    ble/textmap#hit out "$((x2%cols))" "$((by+x2/cols))" "$bol" "$eol"; p2=$index
    ((lx+=(ly-by)*cols,rx+=(ry-by)*cols,lx!=rx&&p2++))
  else
    ((p1=bol+x1,p2=bol+x2))
  fi
  ins=${_ble_edit_str:p1:p2-p1}

  # Insert decision
  local -a ins_beg=() ins_text=()
  local iline=1 nline=${data[3]} strlen=${#_ble_edit_str}
  for ((iline=1;iline<nline;iline++)); do
    local index= lpad=
    if ((eol<strlen)); then
      bol=$((eol+1))
      ble-edit/content/find-logical-eol "$bol"; eol=$ret
    else
      bol=$eol lpad=$'\n'
    fi

    if [[ ${data[1]} == '$' ]]; then
      index=$eol
    elif [[ $has_textmap ]]; then
      ble/textmap#getxy.out --prefix=b "$bol"
      ble/textmap#hit out "$((x1%cols))" "$((by+x1/cols))" "$bol" "$eol" # -> index

      local nfill
      if ((index==eol&&(nfill=x1-lx+(ly-by)*cols)>0)); then
        ble/string#repeat ' ' "$nfill"; lpad=$lpad$ret
      fi
    else
      index=$((bol+x1))
      if ((index>eol)); then
        ble/string#repeat ' ' "$((index-eol))"; lpad=$lpad$ret
        ((index=eol))
      fi
    fi

    ble/array#push ins_beg "$index"
    ble/array#push ins_text "$lpad$ins"
  done

  # Insert execution
  local i=${#ins_beg[@]}
  ble/keymap:vi/mark/start-edit-area
  ble/keymap:vi/mark/commit-edit-area "$p1" "$p2"
  while ((i--)); do
    local index=${ins_beg[i]} text=${ins_text[i]}
    ble/widget/.replace-range "$index" "$index" "$text"
  done
  ble/keymap:vi/mark/end-edit-area
  # Note: This edit is recorded via record-insert, so
  # There is no need to explicitly call ble/keymap:vi/repeat/record here.

  # at the beginning of the area
  local index
  if ble/keymap:vi/mark/get-local-mark 60 && index=$ret; then
    ble/widget/vi-command/goto-mark.impl "$index"
  else
    ble-edit/content/find-logical-bol; index=$ret
  fi

  # When you return to normal mode, the cursor will move back one character, so move it forward one character.
  ble-edit/content/eolp || ((index++))
  _ble_edit_ind=$index
  return 0
}
# xmap I
function ble/widget/vi_xmap/insert-mode {
  local mark_type=${_ble_edit_mark_active%+}
  if [[ $mark_type == vi_block ]]; then
    local sub_ranges sub_x1 sub_x2
    ble/keymap:vi/extract-block '' '' first_line
    ble/widget/vi_xmap/block-insert-mode.impl insert
  else
    local ARG FLAG REG; ble/keymap:vi/get-arg 1

    local beg=$_ble_edit_mark end=$_ble_edit_ind
    ((beg<=end)) || local beg=$end end=$beg
    if [[ $mark_type == vi_line ]]; then
      local ret
      ble-edit/content/find-logical-bol "$beg"; beg=$ret
    fi

    ble/widget/vi_xmap/cancel
    _ble_edit_ind=$beg
    ble/widget/vi_nmap/.insert-mode "$ARG"
    ble/keymap:vi/repeat/record
    return 0
  fi
}
# xmap A
function ble/widget/vi_xmap/append-mode {
  local mark_type=${_ble_edit_mark_active%+}
  if [[ $mark_type == vi_block ]]; then
    local sub_ranges sub_x1 sub_x2
    ble/keymap:vi/extract-block '' '' first_line
    ble/widget/vi_xmap/block-insert-mode.impl append
  else
    local ARG FLAG REG; ble/keymap:vi/get-arg 1

    local beg=$_ble_edit_mark end=$_ble_edit_ind
    ((beg<=end)) || local beg=$end end=$beg
    if [[ $mark_type == vi_line ]]; then
      # When line-oriented, start of the last line or in _ble_edit_ind,
      # Move after the next character.
      if ((_ble_edit_mark>_ble_edit_ind)); then
        local ret
        ble-edit/content/find-logical-bol "$end"; end=$ret
      fi
    fi
    ble-edit/content/eolp "$end" || ((end++))

    ble/widget/vi_xmap/cancel
    _ble_edit_ind=$end
    ble/widget/vi_nmap/.insert-mode "$ARG"
    ble/keymap:vi/repeat/record
    return 0
  fi
}

#--------------------------------------
# xmap/paste

# xmap: p, P
function ble/widget/vi_xmap/paste.impl {
  local opts=$1
  [[ :$opts: != *:after:* ]]; local is_after=$?

  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  [[ $REG ]] && ble/keymap:vi/register#load "$REG"

  local mark_type=${_ble_edit_mark_active%+}
  local kill_ring=$_ble_edit_kill_ring
  local kill_type=$_ble_edit_kill_type

  local adjustment=
  if [[ $mark_type == vi_block ]]; then
    if [[ $kill_type == L ]]; then
      # P: When V → C-v, insert immediately after the last line of C-v
      if ((is_after)); then
        local ret; ble/keymap:vi/get-rectangle-height; local nline=$ret
        adjustment=lastline:$nline
      fi
    elif [[ $kill_type == B:* ]]; then
      # C-v → C-v
      is_after=0
    else
      # Simple v → C-v switches to block insert
      is_after=0
      if [[ $kill_ring != *$'\n'* ]]; then
        ((${#kill_ring}>=2)) && adjustment=index:$((${#kill_ring}*ARG-1))
        local ret; ble/keymap:vi/get-rectangle-height; local nline=$ret
        ble/string#repeat "$kill_ring"$'\n' "$nline"; kill_ring=${ret%$'\n'}
        ble/string#repeat '0 ' "$nline"; kill_type=B:${ret% }
      fi
    fi
  elif [[ $mark_type == vi_line ]]; then
    if [[ $kill_type == L ]]; then
      # When V → V
      is_after=0
    elif [[ $kill_type == B:* ]]; then
      # C-v → V pastes lines.
      # When kill_type=B:*, the newline at the end of kill_ring means a blank line, so
      # You need to add $'\n' to prevent blank lines from disappearing.
      is_after=0 kill_type=L kill_ring=$kill_ring$'\n'
    else
      # When v → V, lines are pasted.
      is_after=0 kill_type=L
      [[ $kill_ring == *$'\n' ]] && kill_ring=$kill_ring$'\n'
    fi
  else
    # When v, V, C-v → v
    is_after=0
    [[ $kill_type == L ]] && adjustment=newline
  fi

  ble/keymap:vi/mark/start-edit-area
  local _ble_keymap_vi_mark_suppress_edit=1
  {
    ble/widget/vi-command/operator d; local ext=$? # _ble_edit_kill_{ring,type} is set here
    if [[ $adjustment == newline ]]; then
      local -a KEYS=(10)
      ble/widget/self-insert
    elif [[ $adjustment == lastline:* ]]; then
      local ret
      ble-edit/content/find-logical-bol "$_ble_edit_ind" "$((${adjustment#*:}-1))"
      _ble_edit_ind=$ret
    fi
    local _ble_edit_kill_ring=$kill_ring
    local _ble_edit_kill_type=$kill_type
    ble/widget/vi_nmap/paste.impl "$ARG" '' "$is_after"
    if [[ $adjustment == index:* ]]; then
      local index=$((_ble_edit_ind+${adjustment#*:}))
      ((index>${#_ble_edit_str}&&(index=${#_ble_edit_str})))
      ble/keymap:vi/needs-eol-fix "$index" && ((index--))
      _ble_edit_ind=$index
    fi
  }
  ble/util/unlocal _ble_keymap_vi_mark_suppress_edit
  ble/keymap:vi/mark/end-edit-area
  ble/keymap:vi/repeat/record
  return "$ext"
}
function ble/widget/vi_xmap/paste-after {
  ble/widget/vi_xmap/paste.impl after
}
function ble/widget/vi_xmap/paste-before {
  ble/widget/vi_xmap/paste.impl before
}

#--------------------------------------
# xmap <C-a>, <C-x>, g<C-a>, g<C-x>

## @fn ble/widget/vi_xmap/increment.impl opts
##
##   @param[in] opts
##     Specify the following items separated by colons.
##
##     - increase [default]
##       Increase numbers.
##     - decrease
##       Decrease numbers.
##     - progressive
##       Multiply the increase/decrease amount for the kth number by k times.
##
function ble/widget/vi_xmap/increment.impl {
  local opts=$1
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  if [[ $FLAG ]]; then
    ble/widget/.bell
    return 1
  fi

  local delta=$ARG
  [[ :$opts: == *:decrease:* ]] && ((delta=-delta))
  local progress=0
  [[ :$opts: == *:progressive:* ]] && progress=$delta

  local old_mark_active=$_ble_edit_mark_active # save
  local mark_type=${_ble_edit_mark_active%+}
  ble/widget/vi_xmap/.save-visual-state
  ble/widget/vi_xmap/exit # Note: _ble_edit_mark_active will be cleared here
  if [[ $mark_type == vi_block ]]; then
    local sub_ranges sub_x1 sub_x2
    _ble_edit_mark_active=$old_mark_active ble/keymap:vi/extract-block
    if ((${#sub_ranges[@]}==0)); then
      ble/widget/.bell
      return 1
    fi
  else
    local beg=$_ble_edit_mark end=$_ble_edit_ind
    ((beg<=end)) || local beg=$end end=$beg
    if [[ $mark_type == vi_line ]]; then
      local ret
      ble-edit/content/find-logical-bol "$beg"; local beg=$ret
      ble-edit/content/find-logical-eol "$end"; local end=$ret
    else
      ble-edit/content/eolp "$end" || ((end++))
    fi

    local -a lines
    ble/string#split-lines lines "${_ble_edit_str:beg:end-beg}"

    # sub_ranges generation
    local line index=$beg
    local -a sub_ranges
    for line in "${lines[@]}"; do
      [[ $line ]] && ble/array#push sub_ranges "$index:::::$line"
      ((index+=${#line}+1))
    done

    ((${#sub_ranges[@]})) || return 0
  fi

  local sub rex_number='^([^0-9]*)([0-9]+)' shift=0 dmin=-1 dmax=-1
  for sub in "${sub_ranges[@]}"; do
    local stext=${sub#*:*:*:*:*:}
    [[ $stext =~ $rex_number ]] || continue

    # original number
    local rematch1=${BASH_REMATCH[1]}
    local rematch2=${BASH_REMATCH[2]}
    local offset=${#rematch1} length=${#rematch2}
    local number=$((10#0$rematch2))
    [[ $rematch1 == *- ]] && ((number=-number,offset--,length++))

    # new number
    ((number+=delta,delta+=progress))
    if [[ $rematch2 == 0?* ]]; then
      # Zero padding
      local wsign=$((number<0?1:0))
      local zpad=$((wsign+${#rematch2}-${#number}))
      if ((zpad>0)); then
        local ret; ble/string#repeat 0 "$zpad"
        number=${number::wsign}$ret${number:wsign}
      fi
    fi

    local smin=${sub%%:*}
    local beg=$((shift+smin+offset))
    local end=$((beg+length))
    ble/widget/.replace-range "$beg" "$end" "$number"
    ((shift+=${#number}-length,
      dmin<0&&(dmin=beg),
      dmax=beg+${#number}))
  done
  local beg=${sub_ranges[0]%%:*}
  ble/keymap:vi/needs-eol-fix "$beg" && ((beg--))
  _ble_edit_ind=$beg

  ((dmin>=0)) && ble/keymap:vi/mark/set-previous-edit-area "$dmin" "$dmax"
  ble/keymap:vi/repeat/record
  return 0
}
# xmap <C-a>
function ble/widget/vi_xmap/increment { ble/widget/vi_xmap/increment.impl increase; }
# xmap <C-x>
function ble/widget/vi_xmap/decrement { ble/widget/vi_xmap/increment.impl decrease; }
# xmap g<C-a>
function ble/widget/vi_xmap/progressive-increment { ble/widget/vi_xmap/increment.impl progressive:increase; }
# xmap g<C-x>
function ble/widget/vi_xmap/progressive-decrement { ble/widget/vi_xmap/increment.impl progressive:decrease; }

#--------------------------------------

function ble-decode/keymap:vi_xmap/define {
  ble/keymap:vi/set-up-command-map

  ble-bind -f __default__ vi-command/decompose-meta

  ble-bind -f 'ESC' vi_xmap/exit
  ble-bind -f 'C-[' vi_xmap/exit
  ble-bind -f 'C-c' vi_xmap/cancel

  ble-bind -f '"' vi-command/register

  ble-bind -f a vi-command/text-object-outer
  ble-bind -f i vi-command/text-object-inner

  ble-bind -f 'C-\ C-n' vi_xmap/cancel
  ble-bind -f 'C-\ C-g' vi_xmap/cancel
  ble-bind -f v      vi_xmap/switch-to-charwise
  ble-bind -f V      vi_xmap/switch-to-linewise
  ble-bind -f C-v    vi_xmap/switch-to-blockwise
  ble-bind -f C-q    vi_xmap/switch-to-blockwise
  ble-bind -f 'g v'  vi-command/previous-visual-area
  ble-bind -f C-g    vi_xmap/switch-to-select

  ble-bind -f o vi_xmap/exchange-points
  ble-bind -f O vi_xmap/exchange-boundaries

  ble-bind -f '~' 'vi-command/operator toggle_case'
  ble-bind -f 'u' 'vi-command/operator u'
  ble-bind -f 'U' 'vi-command/operator U'

  ble-bind -f 's' 'vi-command/operator c'
  ble-bind -f 'x'    'vi-command/operator d'
  ble-bind -f delete 'vi-command/operator d'

  ble-bind -f r vi_xmap/visual-replace-char

  ble-bind -f C vi_xmap/replace-block-lines
  ble-bind -f D vi_xmap/delete-block-lines
  ble-bind -f X vi_xmap/delete-block-lines
  ble-bind -f S vi_xmap/delete-lines
  ble-bind -f R vi_xmap/delete-lines
  ble-bind -f Y vi_xmap/copy-block-or-lines
  ble-bind -f J     vi_xmap/connect-line-with-space
  ble-bind -f 'g J' vi_xmap/connect-line

  ble-bind -f I vi_xmap/insert-mode
  ble-bind -f A vi_xmap/append-mode
  ble-bind -f p vi_xmap/paste-after
  ble-bind -f P vi_xmap/paste-before

  ble-bind -f 'C-a'   vi_xmap/increment
  ble-bind -f 'C-x'   vi_xmap/decrement
  ble-bind -f 'g C-a' vi_xmap/progressive-increment
  ble-bind -f 'g C-x' vi_xmap/progressive-decrement

  ble-bind -f f1 vi_xmap/command-help
  ble-bind -f K  vi_xmap/command-help
}

function ble-decode/keymap:vi_smap/define {
  ble-bind -f __default__ vi-command/decompose-meta

  ble-bind -f 'ESC' vi_xmap/exit
  ble-bind -f 'C-[' vi_xmap/exit
  ble-bind -f 'C-c' vi_xmap/cancel

  ble-bind -f 'C-\ C-n' nop
  ble-bind -f 'C-\ C-n' vi_xmap/cancel
  ble-bind -f 'C-\ C-g' vi_xmap/cancel
  ble-bind -f C-v    vi_xmap/switch-to-visual-blockwise
  ble-bind -f C-q    vi_xmap/switch-to-visual-blockwise
  ble-bind -f C-g    vi_xmap/switch-to-visual

  ble-bind -f delete 'vi-command/operator d'
  ble-bind -f 'C-?'  'vi-command/operator d'
  ble-bind -f 'DEL'  'vi-command/operator d'
  ble-bind -f 'C-h'  'vi-command/operator d'
  ble-bind -f 'BS'   'vi-command/operator d'

  #----------------------------------------------------------------------------

  ble-bind -f __defchar__ vi_smap/self-insert
  ble-bind -f paste_begin vi-command/bracketed-paste

  ble-bind -f 'C-a'  vi_xmap/increment
  ble-bind -f 'C-x'  vi_xmap/decrement
  ble-bind -f f1     vi_xmap/command-help
  ble-bind -c 'C-z' fg

  #----------------------------------------------------------------------------
  # motion, etc.

  ble-bind -f home      'vi_smap/@nomarked vi-command/beginning-of-line'
  ble-bind -f end       'vi_smap/@nomarked vi-command/forward-eol'
  ble-bind -f C-m       'vi_smap/@nomarked vi-command/forward-first-non-space'
  ble-bind -f RET       'vi_smap/@nomarked vi-command/forward-first-non-space'
  ble-bind -f S-home    'vi-command/beginning-of-line'
  ble-bind -f S-end     'vi-command/forward-eol'
  ble-bind -f S-C-m     'vi-command/forward-first-non-space'
  ble-bind -f S-RET     'vi-command/forward-first-non-space'

  ble-bind -f C-right   'vi_smap/@nomarked vi-command/forward-vword'
  ble-bind -f C-left    'vi_smap/@nomarked vi-command/backward-vword'
  ble-bind -f S-C-right 'vi-command/forward-vword'
  ble-bind -f S-C-left  'vi-command/backward-vword'

  ble-bind -f left      'vi_smap/@nomarked vi-command/backward-char'
  ble-bind -f right     'vi_smap/@nomarked vi-command/forward-char'
  ble-bind -f 'C-?'     'vi_smap/@nomarked vi-command/backward-char wrap'
  ble-bind -f 'DEL'     'vi_smap/@nomarked vi-command/backward-char wrap'
  ble-bind -f 'C-h'     'vi_smap/@nomarked vi-command/backward-char wrap'
  ble-bind -f 'BS'      'vi_smap/@nomarked vi-command/backward-char wrap'
  ble-bind -f SP        'vi_smap/@nomarked vi-command/forward-char wrap'
  ble-bind -f S-left    'vi-command/backward-char'
  ble-bind -f S-right   'vi-command/forward-char'
  ble-bind -f 'S-C-?'   'vi-command/backward-char wrap'
  ble-bind -f 'S-DEL'   'vi-command/backward-char wrap'
  ble-bind -f 'S-C-h'   'vi-command/backward-char wrap'
  ble-bind -f 'S-BS'    'vi-command/backward-char wrap'
  ble-bind -f S-SP      'vi-command/forward-char wrap'

  ble-bind -f down      'vi_smap/@nomarked vi-command/forward-line'
  ble-bind -f C-n       'vi_smap/@nomarked vi-command/forward-line'
  ble-bind -f C-j       'vi_smap/@nomarked vi-command/forward-line'
  ble-bind -f up        'vi_smap/@nomarked vi-command/backward-line'
  ble-bind -f C-p       'vi_smap/@nomarked vi-command/backward-line'
  ble-bind -f C-home    'vi_smap/@nomarked vi-command/first-nol'
  ble-bind -f C-end     'vi_smap/@nomarked vi-command/last-eol'
  ble-bind -f S-down    'vi-command/forward-line'
  ble-bind -f S-C-n     'vi-command/forward-line'
  ble-bind -f S-C-j     'vi-command/forward-line'
  ble-bind -f S-up      'vi-command/backward-line'
  ble-bind -f S-C-p     'vi-command/backward-line'
  ble-bind -f S-C-home  'vi-command/first-nol'
  ble-bind -f S-C-end   'vi-command/last-eol'
}

#------------------------------------------------------------------------------
# vi_imap

function ble/widget/vi_imap/__attach__ {
  ble/keymap:vi/update-mode-indicator
  return 0
}
function ble/widget/vi_imap/__detach__ {
  ble/edit/info/default clear
  ble/keymap:vi/clear-arg
  ble/keymap:vi/search/clear-matched
  return 0
}
function ble/widget/vi_imap/accept-single-line-or {
  if ble-edit/is-single-complete-line; then
    ble/keymap:vi/imap-repeat/reset
    ble/widget/accept-line
  else
    ble/widget/"$@"
  fi
}
function ble/widget/vi_imap/delete-region-or {
  if [[ $_ble_edit_mark_active ]]; then
    ble/keymap:vi/imap-repeat/reset
    if ((_ble_edit_ind!=_ble_edit_mark)); then
      ble/keymap:vi/undo/add more
      ble/widget/delete-region
      ble/keymap:vi/undo/add more
    fi
  else
    ble/widget/"$@"
  fi
}
function ble/widget/vi_imap/overwrite-mode {
  ble-edit/content/clear-arg
  if [[ $_ble_edit_overwrite_mode ]]; then
    _ble_edit_overwrite_mode=
  else
    _ble_edit_overwrite_mode=${_ble_keymap_vi_insert_overwrite:-R}
  fi
  ble/keymap:vi/update-mode-indicator
  return 0
}

# imap C-w

## @fn ble/widget/vi_imap/.locate-backward-vword
##   Identify the start of the previous word (vword).
##   @var[out] ret
function ble/widget/vi_imap/.locate-backward-word {
  local space=$' \t' nl=$'\n'
  local rex='('$_ble_keymap_vi_REX_WORD')['$space']*$|['$space']+$|'$nl'$'
  [[ ${_ble_edit_str::_ble_edit_ind} =~ $rex ]] || return 1
  ((ret=_ble_edit_ind-${#BASH_REMATCH}))
  return 0
}

function ble/widget/vi_imap/delete-backward-word {
  if local ret; ble/widget/vi_imap/.locate-backward-word; then
    if ((ret!=_ble_edit_ind)); then
      ble/keymap:vi/undo/add more
      ble/widget/.delete-range "$ret" "$_ble_edit_ind"
      ble/keymap:vi/undo/add more
    fi
    return 0
  else
    ble/widget/.bell
    return 1
  fi
}

function ble/widget/vi_imap/kill-backward-word {
  if local ret; ble/widget/vi_imap/.locate-backward-word; then
    if ((ret!=_ble_edit_ind)); then
      ble/keymap:vi/undo/add more
      ble/widget/.kill-range "$ret" "$_ble_edit_ind"
      ble/keymap:vi/undo/add more
    fi
    return 0
  else
    ble/widget/.bell
    return 1
  fi
}

function ble/widget/vi_imap/copy-backward-word {
  if local ret; ble/widget/vi_imap/.locate-backward-word; then
    if ((ret!=_ble_edit_ind)); then
      ble/widget/.copy-range "$ret" "$_ble_edit_ind"
    fi
    return 0
  else
    ble/widget/.bell
    return 1
  fi
}

# imap C-q, C-v
function ble/widget/vi_imap/quoted-insert-char {
  ble/keymap:vi/imap-repeat/pop
  _ble_edit_mark_active=
  _ble_decode_char__hook=ble/widget/vi_imap/quoted-insert-char.hook
  return 147
}
function ble/widget/vi_imap/quoted-insert-char.hook {
  ble/keymap:vi/imap/invoke-widget ble/widget/self-insert "$1"
}
function ble/widget/vi_imap/quoted-insert {
  ble/keymap:vi/imap-repeat/pop
  _ble_edit_mark_active=
  _ble_decode_key__hook=ble/widget/vi_imap/quoted-insert.hook
  return 147
}
function ble/widget/vi_imap/quoted-insert.hook {
  ble/keymap:vi/imap/invoke-widget ble/widget/quoted-insert.hook "$1"
}

# bracketed paste mode

function ble/widget/vi_imap/bracketed-paste {
  ble/keymap:vi/imap-repeat/pop
  ble/widget/bracketed-paste
  _ble_edit_bracketed_paste_proc=ble/widget/vi_imap/bracketed-paste.proc
  return 147
}
function ble/widget/vi_imap/bracketed-paste.proc {
  local WIDGET=ble/widget/batch-insert
  local -a KEYS; KEYS=("$@")
  ble/keymap:vi/imap-repeat/push
  builtin eval -- "$WIDGET"
}

_ble_keymap_vi_bracketed_paste_mark_active=
function ble/widget/vi-command/bracketed-paste {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1 # discard args
  _ble_keymap_vi_bracketed_paste_mark_active=$_ble_edit_mark_active
  _ble_edit_mark_active=
  ble/widget/bracketed-paste
  _ble_edit_bracketed_paste_proc=ble/widget/vi-command/bracketed-paste.proc
  return 147
}
function ble/widget/vi-command/bracketed-paste.proc {
  if [[ $_ble_decode_keymap == vi_nmap ]]; then
    local isbol index=$_ble_edit_ind
    ble-edit/content/bolp && isbol=1
    ble/decode/widget/call-interactively 'ble/widget/vi_nmap/append-mode' 97
    [[ $isbol ]] && ((_ble_edit_ind=index)) # Go back when you are at the beginning of the line

    ble/widget/vi_imap/bracketed-paste.proc "$@"
    ble/keymap:vi/imap/invoke-widget \
      ble/widget/vi_imap/normal-mode "$((_ble_decode_Ctrl|0x5b))"
  elif [[ $_ble_decode_keymap == vi_[xs]map ]]; then
    local _ble_edit_mark_active=$_ble_keymap_vi_bracketed_paste_mark_active
    ble/decode/widget/call-interactively 'ble/widget/vi-command/operator c' 99 || return 1
    ble/widget/vi_imap/bracketed-paste.proc "$@"
    ble/keymap:vi/imap/invoke-widget \
      ble/widget/vi_imap/normal-mode "$((_ble_decode_Ctrl|0x5b))"
  elif [[ $_ble_decode_keymap == vi_omap ]]; then
    ble/widget/vi_omap/cancel
    ble/widget/.bell
    return 1
  else # vi_omap
    ble/widget/.bell
    return 1
  fi
}

#------------------------------------------------------------------------------
# imap: C-k (digraph)

function ble/widget/vi_imap/insert-digraph.hook {
  local -a KEYS; KEYS=("$1")
  ble/widget/self-insert
}

function ble/widget/vi_imap/insert-digraph {
  ble/decode/keymap/push vi_digraph
  _ble_keymap_vi_digraph__hook=ble/widget/vi_imap/insert-digraph.hook
  return 0
}

# imap: CR, LF (newline)
function ble/widget/vi_imap/newline {
  local ret
  ble-edit/content/find-logical-bol; local bol=$ret
  ble-edit/content/find-non-space "$bol"; local nol=$ret
  ble/widget/default/newline
  ((bol<nol)) && ble/widget/.insert-string "${_ble_edit_str:bol:nol-bol}"
  return 0
}

# imap: C-h, DEL
function ble/widget/vi_imap/delete-backward-indent-or {
  local rex=$'(^|\n)([ \t]+)$'
  if [[ ${_ble_edit_str::_ble_edit_ind} =~ $rex ]]; then
    local rematch2=${BASH_REMATCH[2]} # Note: for bash-3.1 ${#arr[n]} bug
    if [[ $rematch2 ]]; then
      ble/keymap:vi/undo/add more
      ble/widget/.delete-range "$((_ble_edit_ind-${#rematch2}))" "$_ble_edit_ind"
      ble/keymap:vi/undo/add more
    fi
    return 0
  else
    ble/widget/"$@"
  fi
}

#------------------------------------------------------------------------------

function ble-decode/keymap:vi_imap/define {
  #----------------------------------------------------------------------------
  # common bindings

  local ble_bind_nometa=1
  ble-decode/keymap:safe/bind-common
  ble-decode/keymap:safe/bind-history

  #----------------------------------------------------------------------------
  # from ble-decode/keymap:safe/define

  ble-bind -f 'C-d'       'delete-region-or delete-forward-char-or-exit'

  ble-bind -f 'SP'        'magic-space'
  ble-bind -f '/'         'magic-slash'

  ble-bind -f 'C-j'       'accept-line'
  ble-bind -f 'C-RET'     'accept-line'
  ble-bind -f 'C-m'       'accept-single-line-or-newline'
  ble-bind -f 'RET'       'accept-single-line-or-newline'
  ble-bind -f 'C-x C-e'   'edit-and-execute-command'
  ble-bind -f 'C-g'       'bell'
  ble-bind -f 'C-x C-g'   'bell'

  ble-bind -f 'C-l'       'clear-screen'

  ble-bind -f 'f1'        'command-help'
  ble-bind -f 'C-x C-v'   'display-shell-version'
  ble-bind -c 'C-z'       'fg'

  # args
  local key
  for key in {,C-}{0..9}; do
    ble-bind -f "$key"    'append-arg'
  done

  #----------------------------------------------------------------------------
  # vi_imap modifications

  ble-bind -f insert      'vi_imap/overwrite-mode'

  # insert
  ble-bind -f 'C-q'       'vi_imap/quoted-insert'
  ble-bind -f 'C-v'       'vi_imap/quoted-insert'
  ble-bind -f paste_begin 'vi_imap/bracketed-paste'

  # charwise operations
  ble-bind -f 'C-?'       'vi_imap/delete-region-or vi_imap/delete-backward-indent-or delete-backward-char'
  ble-bind -f 'DEL'       'vi_imap/delete-region-or vi_imap/delete-backward-indent-or delete-backward-char'
  ble-bind -f 'C-h'       'vi_imap/delete-region-or vi_imap/delete-backward-indent-or delete-backward-char'
  ble-bind -f 'BS'        'vi_imap/delete-region-or vi_imap/delete-backward-indent-or delete-backward-char'

  # wordwise operations
  ble-bind -f 'C-w'       'vi_imap/kill-backward-word'

  # complete
  ble-decode/keymap:vi_imap/bind-complete

  #----------------------------------------------------------------------------
  # shell functions (from keymap emacs-standard)

  ble-bind -f 'C-\' bell
  ble-bind -f 'C-^' bell

  #----------------------------------------------------------------------------
  # vi bindings

  ble-bind -f __attach__        vi_imap/__attach__
  ble-bind -f __detach__        vi_imap/__detach__
  ble-bind -f __default__       vi_imap/__default__
  ble-bind -f __before_widget__ vi_imap/__before_widget__
  ble-bind -f __line_limit__    __line_limit__

  # Note: in the typical shells, [C-c] is used to discard the current line,
  # which is implemented as 'discard-line'.  The choice of ble.sh is to make it
  # consistent with vi, i.e. drop to the normal mode by [C-c]
  ble-bind -f 'ESC' 'vi_imap/normal-mode'
  ble-bind -f 'C-[' 'vi_imap/normal-mode'
  ble-bind -f 'C-c' 'vi_imap/normal-mode-without-insert-leave'

  # Note: in the emacs editing mode, [C-o] has been 'accept-and-next', which
  # might be more useful in the command line.
  ble-bind -f 'C-o' 'vi_imap/single-command-mode'

  # Note: these bindings also conflict with the typical binding in
  # shells. [C-l] can be replaced by ESC or C-c, so we drop it.  [C-k]
  # conflicts with kill-forward-line.  The digraph inputting is only needed
  # when the terminal does not support it, so I think we don't need to support
  # it by default.
  # ble-bind -f 'C-l' vi_imap/normal-mode
  # ble-bind -f 'C-k' vi_imap/insert-digraph
}

## @fn ble-decode/keymap:vi_imap/define-meta-bindings
##   Define key bindings starting with M-.
##   This is a function that can be called by the user.
function ble-decode/keymap:vi_imap/define-meta-bindings {
  local ble_bind_keymap=vi_imap

  #----------------------------------------------------------------------------
  # from ble-decode/keymap:safe/define

  ble-bind -f 'M-^'       'history-expand-line'
  ble-bind -f 'C-M-l'     'redraw-line'
  ble-bind -f 'M-#'       'insert-comment'
  ble-bind -f 'M-C-e'     'shell-expand-line'
  ble-bind -f 'M-&'       'tilde-expand'
  ble-bind -f 'C-M-g'     'bell'
  ble-bind -f 'M-z'       'zap-to-char'

  #----------------------------------------------------------------------------
  # from ble-decode/keymap:safe/bind-common
  # from ble-decode/keymap:selection/bind-shift

  ble-bind -f 'M-C-m'     'newline'
  ble-bind -f 'M-RET'     'newline'
  ble-bind -f 'M-SP'      'set-mark'
  ble-bind -f 'M-w'       'copy-region-or copy-uword'
  ble-bind -f 'M-y'       'yank-pop'
  ble-bind -f 'M-S-y'     'yank-pop backward'
  ble-bind -f 'M-Y'       'yank-pop backward'
  ble-bind -f 'M-\'       'delete-horizontal-space'

  ble-bind -f 'M-right'   'forward-sword'
  ble-bind -f 'M-left'    'backward-sword'
  ble-bind -f 'S-M-right' '@marked forward-sword'
  ble-bind -f 'S-M-left'  '@marked backward-sword'
  ble-bind -f 'M-d'       'kill-forward-cword'
  ble-bind -f 'M-h'       'kill-backward-cword'
  ble-bind -f 'M-delete'  'copy-forward-sword'
  ble-bind -f 'M-C-?'     'copy-backward-sword'
  ble-bind -f 'M-DEL'     'copy-backward-sword'
  ble-bind -f 'M-C-h'     'copy-backward-sword'
  ble-bind -f 'M-BS'      'copy-backward-sword'

  ble-bind -f 'M-f'       'forward-cword'
  ble-bind -f 'M-b'       'backward-cword'
  ble-bind -f 'M-F'       '@marked forward-cword'
  ble-bind -f 'M-B'       '@marked backward-cword'
  ble-bind -f 'M-S-f'     '@marked forward-cword'
  ble-bind -f 'M-S-b'     '@marked backward-cword'
  ble-bind -f 'M-c'       'capitalize-eword'
  ble-bind -f 'M-l'       'downcase-eword'
  ble-bind -f 'M-u'       'upcase-eword'
  ble-bind -f 'M-t'       'transpose-ewords'

  ble-bind -f 'M-m'       'non-space-beginning-of-line'
  ble-bind -f 'M-S-m'     '@marked non-space-beginning-of-line'
  ble-bind -f 'M-M'       '@marked non-space-beginning-of-line'

  ble-bind -f 'M-x'       'vi-command/execute-named-command'

  #----------------------------------------------------------------------------
  # from ble-decode/keymap:safe/bind-history

  ble-bind -f 'M-<'       'history-beginning'
  ble-bind -f 'M->'       'history-end'
  ble-bind -f 'M-.'       'insert-last-argument'
  ble-bind -f 'M-_'       'insert-last-argument'
  ble-bind -f 'M-C-y'     'insert-nth-argument'

  #----------------------------------------------------------------------------
  # from ble-decode/keymap:safe/bind-complete

  ble-bind -f 'M-?'       'complete show_menu'
  ble-bind -f 'M-*'       'complete insert_all'
  ble-bind -f 'M-{'       'complete insert_braces'
  ble-bind -f 'M-/'       'complete context=filename'
  ble-bind -f 'M-~'       'complete context=username'
  ble-bind -f 'M-$'       'complete context=variable'
  ble-bind -f 'M-@'       'complete context=hostname'
  ble-bind -f 'M-!'       'complete context=command'
  ble-bind -f "M-'"       'sabbrev-expand'
  ble-bind -f 'M-g'       'complete context=glob'
  ble-bind -f 'M-C-i'     'complete context=dynamic-history'
  ble-bind -f 'M-TAB'     'complete context=dynamic-history'

  #----------------------------------------------------------------------------
  # from ble-decode/keymap:safe/bind-arg

  ble-bind -f 'M-0'       'append-arg'
  ble-bind -f 'M-1'       'append-arg'
  ble-bind -f 'M-2'       'append-arg'
  ble-bind -f 'M-3'       'append-arg'
  ble-bind -f 'M-4'       'append-arg'
  ble-bind -f 'M-5'       'append-arg'
  ble-bind -f 'M-6'       'append-arg'
  ble-bind -f 'M-7'       'append-arg'
  ble-bind -f 'M-8'       'append-arg'
  ble-bind -f 'M-9'       'append-arg'
}

#------------------------------------------------------------------------------
# vi_cmap

_ble_keymap_vi_cmap_accept_hook=
_ble_keymap_vi_cmap_cancel_hook=
_ble_keymap_vi_cmap_before_widget=

# Default cmap history
_ble_keymap_vi_cmap_history=()
_ble_keymap_vi_cmap_history_edit=()
_ble_keymap_vi_cmap_history_dirt=()
_ble_keymap_vi_cmap_history_index=0

function ble/keymap:vi/async-commandline-mode {
  ble/edit/async-read-mode "$1" _ble_keymap_vi_cmap vi_cmap
  ble/keymap:vi/update-mode-indicator
  return 147
}

function ble/widget/vi_cmap/accept {
  local hook=$_ble_keymap_vi_cmap_accept_hook
  _ble_keymap_vi_cmap_accept_hook=

  local ret
  ble/edit/async-read-mode/accept
  ble/keymap:vi/update-mode-indicator
  if [[ $hook ]]; then
    builtin eval -- "$hook \"\$ret\""
  else
    ble/keymap:vi/adjust-command-mode
    return 0
  fi
}

function ble/widget/vi_cmap/cancel {
  _ble_keymap_vi_cmap_accept_hook=$_ble_keymap_vi_cmap_cancel_hook
  ble/widget/vi_cmap/accept
}

function ble/widget/vi_cmap/__before_widget__ {
  if [[ $_ble_keymap_vi_cmap_before_widget ]]; then
    builtin eval -- "$_ble_keymap_vi_cmap_before_widget"
  fi
}

function ble/widget/vi_cmap/__line_limit__.edit {
  local content=$1
  ble/widget/edit-and-execute-command.edit "$content" no-newline; local ext=$?
  ((ext==127)) && return "$ext"
  ble-edit/content/reset "$ret"
  ble/widget/vi_cmap/accept
}
function ble/widget/vi_cmap/__line_limit__ {
  ble/widget/__line_limit__ vi_cmap/__line_limit__.edit
}

function ble-decode/keymap:vi_cmap/define {
  #----------------------------------------------------------------------------
  # common bindings + modifications

  local ble_bind_nometa=
  ble-decode/keymap:safe/bind-common
  ble-decode/keymap:safe/bind-history
  ble-decode/keymap:safe/bind-complete

  #----------------------------------------------------------------------------

  ble-bind -f __before_widget__ vi_cmap/__before_widget__
  ble-bind -f __line_limit__    vi_cmap/__line_limit__

  # accept/cancel
  ble-bind -f 'ESC'     vi_cmap/cancel
  ble-bind -f 'C-['     vi_cmap/cancel
  ble-bind -f 'C-c'     vi_cmap/cancel
  ble-bind -f 'C-m'     vi_cmap/accept
  ble-bind -f 'RET'     vi_cmap/accept
  ble-bind -f 'C-j'     vi_cmap/accept
  ble-bind -f 'C-g'     bell
  ble-bind -f 'C-x C-g' bell
  ble-bind -f 'C-M-g'   bell

  # shell function
  # ble-bind -f  'C-l'     clear-screen
  ble-bind -f  'C-l'     redraw-line
  ble-bind -f  'C-M-l'   redraw-line
  ble-bind -f  'C-x C-v' display-shell-version

  # command-history
  # ble-bind -f 'M-^'     history-expand-line
  # ble-bind -f 'SP'      magic-space
  # ble-bind -f '/'       magic-slash

  ble-bind -f 'C-\' bell
  ble-bind -f 'C-^' bell
}

#------------------------------------------------------------------------------

function ble-decode/keymap:vi/initialize {
  local fname_keymap_cache=$_ble_base_cache/keymap.vi
  if [[ -s $fname_keymap_cache &&
          $fname_keymap_cache -nt $_ble_base/lib/keymap.vi.sh &&
          $fname_keymap_cache -nt $_ble_base/lib/init-cmap.sh ]]; then
    source -- "$fname_keymap_cache" && return 0
  fi

  ble/edit/info/immediate-show text "ble.sh: updating cache/keymap.vi..."

  {
    ble/decode/keymap#load isearch dump
    ble/decode/keymap#load nsearch dump
    ble/decode/keymap#load vi_imap dump
    ble/decode/keymap#load vi_nmap dump
    ble/decode/keymap#load vi_omap dump
    ble/decode/keymap#load vi_xmap dump
    ble/decode/keymap#load vi_cmap dump
  } 3>| "$fname_keymap_cache"

  ble/edit/info/immediate-show text "ble.sh: updating cache/keymap.vi... done"
}

ble-decode/keymap:vi/initialize
ble_bind_keymap=vi_imap blehook/invoke keymap_load
ble_bind_keymap=vi_imap blehook/invoke keymap_vi_load
return 0
