#!/bin/bash

# **** sections ****
#
# @line.ps1
# @line.text
# @line.info
# @edit.content
# @edit.ps1
# @textarea
# @textarea.buffer
# @textarea.render
# @widget.clear
# @widget.mark
# @edit.bell
# @edit.insert
# @edit.delete
# @edit.cursor
# @edit.word
# @edit.exec
# @edit.accept
# @history
# @history.widget
# @history.isearch
# @comp
# @bind
# @bind.bind
#
# Current ble/canvas/panel configuration
#   0 command-line
# 1 Additional input field
#   2 infobar

## @bleopt edit_bell
##   A colon-separated list of fields to control the behavior of the bell in
##   line editing.
##
##   @opt vbell
##     When this is specified, the visible bell (vbell) is enabled for the edit
##     bell.  The message is shown in the position specified by "bleopt
##     vbell_align"
##
##   @opt abell
##     When this is specified, the audible bell (abell) is enabled for the edit
##     bell.  The event is notified by printing BEL to the terminal.
##
##   @opt visual
##     When this is specified, the visual bell in the GNU Screen style is
##     enabled for the edit bell.  The event is notified by flashing the screen
##     by DECSCNM.
##
bleopt/declare -v edit_bell 'abell'
bleopt/declare -v edit_vbell '[obsolute: use edit_bell=vbell]'
bleopt/declare -v edit_abell '[obsolute: use edit_bell=abell]'
function bleopt/obsolete:edit_vbell { return 0; }
function bleopt/obsolete:edit_abell { return 0; }
function bleopt/check:edit_vbell {
  if [[ $value ]]; then
    ble/opts#append-unique bleopt_edit_bell vbell
  else
    ble/opts#remove bleopt_edit_bell vbell
  fi
  value=$bleopt_edit_vbell
}
function bleopt/check:edit_abell {
  if [[ $value ]]; then
    ble/opts#append-unique bleopt_edit_bell abell
  else
    ble/opts#remove bleopt_edit_bell abell
  fi
  value=$bleopt_edit_abell
}

## @bleopt history_lazyload
## bleopt_history_lazyload=1
##   After ble-attach, the history is read the first time it is needed.
## bleopt_history_lazyload=
##   Read history at ble-attach.
##
## history -s doesn't work as expected in versions below bash-3.1, so
## Regardless of the value of this option, the history will be read at the time of ble-attach.
bleopt/declare -v history_lazyload 1

## @bleopt delete_selection_mode
##   Set what to do with the selection range when inserting characters.
## bleopt_delete_selection_mode=1 (default)
##   Replaces the contents of the selection with new characters.
## bleopt_delete_selection_mode=
##   Cancels the selection and inserts new characters at the current position.
bleopt/declare -v delete_selection_mode 1

## @bleopt indent_offset
##   Specifies the shell indentation width. Default is 4.
bleopt/declare -n indent_offset 4

## @bleopt indent_tabs
##   Specifies whether to use tabs for indentation.
##   If you specify 0, only spaces will be used for indentation.
##   Otherwise use tabs for indentation.
bleopt/declare -n indent_tabs 1

## @bleopt undo_point
##   Sets the cursor position immediately after undo/redo execution.
##
##   undo_point=beg
##     Move to the beginning of the range changed by undo/redo.
##   undo_point=end
##     Move to the end of the range changed by undo/redo.
##   undo_point=first
##     Move to the position where the string was first recorded.
##   undo_point=last
##     Moves to the last recorded position of that string.
##   undo_point=near
##     It behaves as "last" when undoing, and "first" when redoing.
##   undo_point=auto, undo_point=, or any other value
##     Behaves as "near" in emacs editing mode. In vi editing mode
##     Behave as beg.
##
bleopt/declare -v undo_point auto

## @bleopt edit_forced_textmap
##   When set to 1, forces placement calculation before rectangle selection.
##   When set to 0, use placement information if available,
##   When there is no placement information, it falls back to rectangular selection using logical rows and logical columns.
##
bleopt/declare -n edit_forced_textmap 1

## @bleopt edit_magic_expand
##   @opt sabbrev
##     Perform the sabbrev expansion on magic-space.
##
##   @opt history
##     These enable the corresponding expansions on accept-line.  The history
##     expansion is equivalent to the shell's history expansion and performed
##     when "history" is specified here, or the shell option `set -H` (or `set
##     -o histexpand`) is specified.
##
##   @opt alias
##     Expand the alias on the left-hand side of the current cursor.
##
##   @opt autocd
##     Expand the directory name on the left-hand side of the current cursor,
##     when the current context is in the place where a command name appears.
##
##   @opt <user-defined-expansion>
##     Perform the expansion defined by the shell function named
##     "ble/complete/expand:<user-defined-expansion>".
##
bleopt/declare -v edit_magic_expand history:sabbrev
function bleopt/check:edit_magic_expand {
  local expand_types expand_type exit=0
  ble/string#split expand_types : "$value"
  for expand_type in "${expand_types[@]}"; do
    case $expand_type in
    (''|history|sabbrev) ;;
    (*)
      if ! ble/is-function ble/complete/expand:"$expand_type"; then
        ble/util/print "bleopt edit_magic_expand: '$value': Unrecognized expansion type '$expand_type'." >&2
        exit=1
      fi ;;
    esac
  done

  return "$exit"
}

## @bleopt edit_magaic_opts
##   @opt inline-sabbrev-no-insert
##
bleopt/declare -v edit_magic_opts ''

## @bleopt edit_magic_accept
##   @opt <options-for-bleopt-edit_magic_expand>
##     All options that can be specified to "bleopt edit_magic_expand" can be
##     specified to "bleopt edit_magic_accept" too.  These enable the
##     corresponding expansions on accept-line.
##
##   @opt history-inline
##     By default, the result of the history expansion is not applied to the
##     command line, but it is printed in the form "[ble: expand] <expanded
##     command>" mimicking the behavior of Bash/Readline.  When this option is
##     specified, the result of the history expansion replaces the content of
##     the command line.
##   @opt verify
##     When any expansion (except for the history expansion) is performed and
##     the command line is changed, we update the change in the command line.
##     We cancel accept-line and let the user continue to edit the command
##     line.  This is similar to "shopt -s histverify" for the shell's history
##     expansions.  For the history expansion, "shopt -s histverify" is
##     referenced instead.
##   @opt verify-syntax
##     If this option is specified, when any expansions change the command, the
##     syntax check for the resulting command is performed.  If the expanded
##     result is not a complete shell command, the command execution is
##     canceled so the user can modify the expanded command.  This implies
##     "history-inline".
##
bleopt/declare -v edit_magic_accept 'verify-syntax'
function bleopt/check:edit_magic_accept {
  local expand_types expand_type exit=0
  ble/string#split expand_types : "$value"
  for expand_type in "${expand_types[@]}"; do
    case $expand_type in
    (''|history|sabbrev|history-inline|verify|verify-syntax) ;;
    (*)
      if ! ble/is-function ble/complete/expand:"$expand_type"; then
        ble/util/print "bleopt edit_magic_accept: '$value': Unrecognized expansion type '$expand_type'." >&2
        exit=1
      fi ;;
    esac
  done

  return "$exit"
}

function ble/edit/use-textmap {
  ble/textmap#is-up-to-date && return 0
  ((bleopt_edit_forced_textmap)) || return 1
  ble/widget/.update-textmap
  return 0
}

## @bleopt edit_line_type
##   Specify the interpretation of the line when performing operations such as moving to the beginning or end of the line.
##   When "logical" is set, it is interpreted in logical lines.
##   In other words, the operation is performed using the beginning and end of the line separated by the newline character in the editing string.
##   When "graphical" is set, it is interpreted as a display line.
##   In other words, operations are performed using the beginning and end of the current line in the terminal.
bleopt/declare -n edit_line_type logical
function bleopt/check:edit_line_type {
  if [[ $value != logical && $value != graphical ]]; then
    ble/util/print "bleopt edit_line_type: Unexpected value '$value'. 'logical' or 'graphical' is expected." >&2
    return 1
  fi
}

function ble/edit/performs-on-graphical-line {
  [[ $bleopt_edit_line_type == graphical ]] || return 1
  ble/textmap#is-up-to-date && return 0
  ((bleopt_edit_forced_textmap)) || return 1
  ble/widget/.update-textmap
  return 0
}

bleopt/declare -n info_display top
function bleopt/check:info_display {
  case $value in
  (top)
    [[ $_ble_canvas_panel_vfill == 4 ]] && return 0
    _ble_canvas_panel_vfill=4
    [[ $_ble_attached ]] && ble/canvas/panel/clear
    return 0 ;;
  (bottom)
    [[ $_ble_canvas_panel_vfill == 2 ]] && return 0
    _ble_canvas_panel_vfill=2
    [[ $_ble_attached ]] && ble/canvas/panel/clear
    return 0 ;;
  (*)
    ble/util/print "bleopt: Invalid value for 'info_display': $value"
    return 1 ;;
  esac
}

## prompt options
bleopt/declare -v prompt_ps1_final ''
bleopt/declare -v prompt_ps1_transient ''
bleopt/declare -v prompt_rps1 ''
bleopt/declare -v prompt_rps1_final ''
bleopt/declare -v prompt_rps1_transient ''
bleopt/declare -v prompt_xterm_title  ''
bleopt/declare -v prompt_screen_title ''
bleopt/declare -v prompt_term_status  ''
# obsoleted options
bleopt/declare -o rps1 prompt_rps1
bleopt/declare -o rps1_transient prompt_rps1_transient

bleopt/declare -v prompt_eol_mark $'\e[94m[ble: EOF]\e[m'
bleopt/declare -v prompt_ruler ''

bleopt/declare -v prompt_status_line  ''
bleopt/declare -n prompt_status_align $'justify=\r'
ble/color/defface prompt_status_line fg=231,bg=240

bleopt/declare -v prompt_command_changes_layout ''

function bleopt/check:prompt_status_align {
  case $value in
  (left|right|center|justify|justify=?*)
    ble/prompt/unit#clear _ble_prompt_status hash
    return 0 ;;
  (*)
    ble/util/print "bleopt prompt_status_align: unsupported value: '$value'" >&2
    return 1 ;;
  esac
}

## @bleopt internal_exec_type (internal use)
##   Specifies how the command is executed.
##
##   internal_exec_type=exec [obsolete]
##     Run within a function (removed)
##   internal_exec_type=gexec
##     Run in global context (new method)
##
## Requirement: The function ble-edit/exec:$bleopt_internal_exec_type/process is defined.
bleopt/declare -n internal_exec_type gexec
function bleopt/check:internal_exec_type {
  if ! ble/is-function "ble-edit/exec:$value/process"; then
    ble/util/print "bleopt: Invalid value internal_exec_type='$value'. A function 'ble-edit/exec:$value/process' is not defined." >&2
    return 1
  fi
}

bleopt/declare -v internal_exec_int_trace ''

## @bleopt internal_suppress_bash_output (internal use)
##   Specifies whether to suppress the output of bash itself.
## bleopt_internal_suppress_bash_output=1
##   Suppress. Bash error messages are displayed with visible-bell.
## bleopt_internal_suppress_bash_output=
##   Not suppressed. All bash messages are printed to the terminal.
##   This is a debug setting. Flickering may occur due to bash output control.
##   bash-3 cannot capture C-d with this configuration.
bleopt/declare -v internal_suppress_bash_output 1

## @bleopt internal_ignoreeof_trap (internal use)
##   Used when using bash-3.0. Message used to capture C-d.
##   This will need to match your bash configuration.
bleopt/declare -n internal_ignoreeof_trap 'Use "exit" to leave the shell.'

## @bleopt allow_exit_with_jobs
##   When this variable is set to an empty string,
##   The shell will not exit from ble/widget/exit when jobs remain.
##   When this variable is set to something other than an empty string,
##   Even if there are jobs, exit will be executed when the conditions are met.
## If there are stopped jobs, or if you run shopt -s checkjobs and there are running jobs,
##   Exits the shell when exit is called from the same widget twice in a row.
##   Otherwise always exit the shell.
##   The default value is an empty string.
bleopt/declare -v allow_exit_with_jobs ''

## @bleopt history_share
##   When this variable is set to an empty string, the history will be shared.
bleopt/declare -v history_share ''


## @bleopt accept_line_threshold
##   Controls the behavior of the edit function accept-single-line-or-newline in single-line mode.
##   When this variable is a negative integer, the command will always be executed.
##   When this variable is 0, if there is user input, insert a line break and enter multiline mode.
##   For a positive integer n, insert a newline and enter multiline mode when there are more than n outstanding user inputs.
bleopt/declare -v accept_line_threshold 5

bleopt/declare -v exec_restore_pipestatus ''

bleopt/declare -v edit_marker $'\e[94m[ble: %s]\e[m'
bleopt/declare -v edit_marker_error $'\e[91m[ble: %s]\e[m'

## @fn ble/edit/marker#get msg opts
##   @param[in] msg
##     string shown in the mark
##   @param[in,opt] opts
##     A colon-separated list of the following options:
##
##     @opt bare
##       Do not enclose within `edit_marker` and `edit_marker_error` ([ble: %s]
##       by default).
##
##     @opt error
##       Use `edit_marker_error` instead of `edit_marker` as the default
##       format.
##
##     @opt non-empty
##       When `edit_marker` or `edit_marker_error` produces the empty result,
##       use the default value `[ble: %s]` instead of omitting the marker.
##
##   @var[out] ret
function ble/edit/marker#get {
  local msg=$1 opts=${2-}
  ret=$msg
  if [[ :$opts: != *:bare:* ]]; then
    if [[ :$opts: == *:error:* ]]; then
      ble/util/sprintf ret "$bleopt_edit_marker_error" "$ret"
    else
      ble/util/sprintf ret "$bleopt_edit_marker" "$ret"
    fi
  fi
  if [[ ! $ret && $msg && :$opts: == *:non-empty:* ]]; then
    if [[ :$opts: == *:error:* ]]; then
      ret=$'\e[91m[ble: '$msg$']\e[m'
    else
      ret=$'\e[94m[ble: '$msg$']\e[m'
    fi
  fi
  [[ $ret ]]
}

## @fn ble/edit/marker#instantiate msg config
##   @param[in] msg
##     string shown in the mark
##   @param[in,opt] opts
##     See the description of ble/edit/marker#get.
##   @var[out] ret
function ble/edit/marker#instantiate {
  ble/edit/marker#get "$@"
  if [[ $ret ]]; then
    ret=${ret%$'\e[m'}$'\e[m'
    x=0 y=0 g=0 LINES=1 ble/canvas/trace "$ret" confine:truncate
  fi
  [[ $ret ]]
}

function ble/edit/marker#declare-config {
  local name=$1 value=$2 opts=$3
  if [[ :$opts: == *:error:* ]]; then
    value=$'\e[91m[ble: '$value$']\e[m'
  else
    value=$'\e[94m[ble: '$value$']\e[m'
  fi
  bleopt/declare -v "$name" "$value"
}

## @fn ble/edit/marker#get-config config_name
##   @param[in] config
##      bleopt config name
##   @var[out] ret
function ble/edit/marker#get-config {
  bleopt/default "$1"
  local default_value=$ret
  local current_ref=bleopt_$1
  local current_value=${!current_ref}

  ret=$current_value
  if [[ $current_value == "$default_value" ]]; then
    if ble/string#match "$current_value" $'^\e\[94m\[ble: (.*)]\e\[m$'; then
      ble/util/sprintf ret "$bleopt_edit_marker" "${BASH_REMATCH[1]}"
    elif ble/string#match "$current_value" $'^\e\[91m\[ble: (.*)\]\e\[m$'; then
      ble/util/sprintf ret "$bleopt_edit_marker_error" "${BASH_REMATCH[1]}"
    fi
  fi
  [[ $ret ]]
}

function ble/edit/marker#instantiate-config {
  ble/edit/marker#get-config "$1" &&
    ret=${ret%$'\e[m'}$'\e[m' &&
    x=0 y=0 g=0 LINES=1 ble/canvas/trace "$ret" confine:truncate
  [[ $ret ]]
}

## @bleopt exec_errexit_mark
##   Specify the format of the mark to be displayed when the exit status is non-zero.
##   When this variable is empty, no exit status will be displayed.
ble/edit/marker#declare-config exec_errexit_mark 'exit %d' error

ble/edit/marker#declare-config exec_elapsed_mark 'elapsed %s (CPU %s%%)'
bleopt/declare -v exec_elapsed_enabled 'usr+sys>=10000'

ble/edit/marker#declare-config exec_exit_mark 'exit'

## @bleopt line_limit_length
##   Specifies the upper limit on the number of characters on the command line during bulk insert.
##   A value less than 0 indicates no limit on the number of characters.
bleopt/declare -v line_limit_length 10000

## @bleopt line_limit_type
##   Specify the behavior when the number of characters is exceeded in bulk insertion.
bleopt/declare -v line_limit_type none

# 
#------------------------------------------------------------------------------
# **** Application ****

_ble_app_render_mode=panel
_ble_app_winsize=()
function ble/application/.set-up-render-mode {
  [[ $1 == "$_ble_app_render_mode" ]] && return 0
  case $1 in
  (panel)
    ble/term/leave-altscr
    ble/canvas/panel/invalidate ;;
  (forms:*)
    ble/term/enter-altscr
    ble/util/buffer "$_ble_term_clear"
    ble/util/buffer $'\e[H'
    _ble_canvas_x=0 _ble_canvas_y=0 ;;
  (*)
    ble/util/print "ble/edit: unrecognized render mode '$1'."
    return 1 ;;
  esac
}
function ble/application/push-render-mode {
  ble/application/.set-up-render-mode "$1" || return 1
  ble/array#unshift _ble_app_render_mode "$1"
}
function ble/application/pop-render-mode {
  [[ ${_ble_app_render_mode[1]} ]] || return 1
  ble/application/.set-up-render-mode "${_ble_app_render_mode[1]}"
  ble/array#shift _ble_app_render_mode
}
function ble/application/render {
  # If there is already an unprocessed winch, ble/application/onwinch from the beginning
  # Redraw via. In any case, start again from ble/application/onwinch
  # ble/application/render is called, so exit immediately after onwinch.
  # Good.
  #
  # Note: If ble/application/onwinch is also delayed in this context,
  # Eventually ble/application/onwinch is called somewhere further outside.
  # There is no problem because it is already planned.
  if [[ $_ble_app_onwinch_Deferred ]]; then
    ble/application/onwinch
    return "$?"
  fi

  local _ble_app_onwinch_Suppress=1
  {
    local render=$_ble_app_render_mode
    case $render in
    (panel)
      local _ble_prompt_update=owner
      ble/prompt/update
      ble/canvas/panel/render ;;
    (forms:*)
      ble/forms/render "${render#*:}" ;; # NYI
    esac
    _ble_app_winsize=("$COLUMNS" "$LINES")
    ble/util/buffer.flush
  }
  ble/util/unlocal _ble_app_onwinch_Suppress

  if [[ $_ble_app_onwinch_Deferred ]]; then
    ble/application/onwinch
  fi
}
blehook idle_after_task!=ble/application/render

## @fn ble/application/onwinch/panel.process-redraw-here
##   @arr[in] _ble_app_winsize
##   @var[in] LINES COLUMNS
function ble/application/onwinch/panel.process-redraw-here {
  local old_w=${_ble_app_winsize[0]}

  local -a DRAW_BUFF=()

  # The problem of reducing the number of lines due to text reflowing is when the terminal width increases.
  # Only. So only when the terminal width increases, how many lines will exist after expansion?
  # is determined, and the drawing start position is determined based on it.
  if ((COLUMNS>old_w)); then
    # When you are in the bottom panel, it is not obvious where to return with DECRC. Also reflow the destination
    # There is a possibility that the
    # possibility, etc. The worst case is that the destination is also reflowed and moved up, so
    # Assuming this, we will use the coordinates returned by DECRC to make a determination.
    ble/canvas/panel/goto-top-dock.draw

    local i npanel=${#_ble_canvas_panel_class[@]}
    local y0=0
    local nchar=0
    for ((i=0;i<npanel;i++)); do
      ((_ble_canvas_panel_height[i])) || continue
      ((_ble_canvas_y<=y0)) && break

      if ! ble/function#try "${_ble_canvas_panel_class[i]}#panel::moveReflowInf" "$i" "$_ble_canvas_x" "$((_ble_canvas_y-y0))"; then
        if ((_ble_canvas_y-y0<_ble_canvas_panel_height[i])); then
          ((nchar+=(_ble_canvas_y-y0)*(old_w-1)+_ble_canvas_x))
        else
          ((nchar+=(_ble_canvas_panel_height[i]*(old_w-1))))
        fi
      fi

      ((y0+=_ble_canvas_panel_height[i]))
    done
    ((_ble_canvas_y>=y0)) &&
      ((nchar+=(_ble_canvas_y-y0)*(old_w-1)*_ble_canvas_x))

    local new_y_min=$(((nchar-1)/COLUMNS))
    ((_ble_canvas_y>new_y_min)) &&
      _ble_canvas_y=$new_y_min
  fi

  ble/canvas/panel#goto.draw 0 0 0
  ble/canvas/bflush.draw

  return 0
}

_ble_app_onwinch_Suppress=
_ble_app_onwinch_Deferred=
function ble/application/onwinch {
  if [[ $_ble_app_onwinch_Suppress || $_ble_decode_hook_Processing == body || $_ble_decode_hook_Processing == prologue ]]; then
    # Note #D1762: If you update the drawing while another process is running, it will result in half-finished data.
    # The process will be executed and the data will be destroyed, so please process it later.
    #
    # When ble_decode_hook_body=1, EPILOGUE will always be called later, so at that time
    # ble/application/render is called. Among them_ble_app_onwinch_Deferred
    # is checked and this function is called again. _ble_app_onwinch_Suppress=1
    # In this case, I expect the check to run at the end of ble/application/render.
    _ble_app_onwinch_Deferred=1
    return 0
  fi

  local _ble_app_onwinch_Suppress=1
  _ble_app_onwinch_Deferred=

  _ble_textmap_cols=
  # It seems that the WINCH that arrived during processing will be lost. For devices that notify continuous size changes,
  # The final size of the WINCH was missed while the intermediate size of the WINCH was being processed, and the display was distorted.
  # Manaru. As a countermeasure, check if the size has changed during processing when drawing is finished.
  # Ru.

  local old_size= i
  for ((i=0;i<20;i++)); do
    # Wait for next WINCH and trigger checkwinsize in subshell.
    (ble/util/msleep 50)
    # COLUMNS/LINES are not updated inside trap string / bind -x in Bash 5.2
    # explicitly call ble/term/update-winsize.
    if ble/util/is-running-in-subshell || ((50200<=_ble_bash&&_ble_bash<50300)); then
      ble/term/update-winsize
    fi

    # If the trap is in progress, jobs will accumulate due to a bug in bash, so deal with them one by one.
    ble/util/joblist.check ignore-volatile-jobs
    local size=$LINES:$COLUMNS
    [[ $size == "$old_size" ]] && break
    old_size=$size

    local render=$_ble_app_render_mode
    case $render in
    (panel)
      case $bleopt_canvas_winch_action in
      (clear)
        # Erase everything and redraw from the top
        _ble_prompt_trim_opwd=
        ble/util/buffer "$_ble_term_clear" ;;
      (redraw-here)
        ble/application/onwinch/panel.process-redraw-here ;;
      (redraw-prev)
        # Go back and redraw assuming the previous starting relative position has not changed
        local -a DRAW_BUFF=()
        ble/canvas/panel#goto.draw 0 0 0
        ble/canvas/bflush.draw ;;
      (redraw-safe) ;;
      esac
      # Including re-securing the height.
      ble/canvas/panel/invalidate height ;;

    (forms:*)
      ble/forms/invalidate "${render#*:}" ;; # NYI
    esac

    ble/application/render
  done
  ble/util/unlocal _ble_app_onwinch_Suppress

  if [[ $_ble_app_onwinch_Deferred ]]; then
    ble/application/onwinch
  fi
}

# canvas.sh settings

_ble_canvas_panel_focus=0
_ble_canvas_panel_class=(ble/textarea ble/textarea ble/edit/info ble/edit/visible-bell ble/prompt/status)
_ble_canvas_panel_height=(1 0 0 0 0)
_ble_canvas_panel_vfill=4

_ble_edit_command_layout_level=0
function ble/edit/enter-command-layout {
  ((_ble_edit_command_layout_level++==0)) || return 0

  # Temporarily clear info and status.
  ble/edit/info#collapse "$_ble_edit_info_panel"
  ble/edit/visible-bell#collapse
  ble/prompt/status#collapse
}
function ble/edit/leave-command-layout {
  ((_ble_edit_command_layout_level>0&&
      --_ble_edit_command_layout_level==0)) || return 0

  # Display the suppressed info again. Delete the content that was temporarily displayed.
  # Display the contents of default.
  blehook/invoke info_reveal
  ble/edit/info/default
}
function ble/edit/clear-command-layout {
  ((_ble_edit_command_layout_level>0)) || return 0
  _ble_edit_command_layout_level=1
  ble/edit/leave-command-layout
}
function ble/edit/is-command-layout {
  ((_ble_edit_command_layout_level>0))
}

# 
#------------------------------------------------------------------------------
# **** ble/prompt/status ****                                    @prompt.status

_ble_prompt_status_panel=4
_ble_prompt_status_dirty=
_ble_prompt_status_data=()
_ble_prompt_status_bbox=()

# Note: It is designed on the assumption that the height is either 0 or 1. Display more rows
# If you want to display this, you will need to make adjustments when calculating _ble_prompt_status_data.

function ble/prompt/status#panel::invalidate {
  _ble_prompt_status_dirty=1
}
function ble/prompt/status#panel::render {
  [[ $_ble_prompt_status_dirty ]] || return 0
  _ble_prompt_status_dirty=

  # If there is no display content, exit without doing anything (assuming the height has already been adjusted)
  local index=$1
  local height; ble/prompt/status#panel::getHeight "$index"
  [[ ${height#*:} == 1 ]] || return 0

  local -a DRAW_BUFF=()

  # If the heights do not match, try requesting relocation.
  # If the height cannot be obtained, give up.
  height=$3
  if ((height!=1)); then
    ble/canvas/panel/reallocate-height.draw
    ble/canvas/bflush.draw
    height=${_ble_canvas_panel_height[index]}
    ((height==0)) && return 0
  fi

  local esc=${_ble_prompt_status_data[10]}
  if [[ $esc ]]; then
    local prox=${_ble_prompt_status_data[11]}
    local proy=${_ble_prompt_status_data[12]}
    ble/canvas/panel#goto.draw "$_ble_prompt_status_panel"
    ble/canvas/panel#put.draw "$_ble_prompt_status_panel" "$esc" "$prox" "$proy"
  else
    ble/canvas/panel#clear.draw "$_ble_prompt_status_panel"
  fi
  ble/canvas/bflush.draw
}
function ble/prompt/status#panel::getHeight {
  if ble/edit/is-command-layout || [[ ! ${_ble_prompt_status_data[10]} ]]; then
    height=0:0
  else
    height=0:1
  fi
}
function ble/prompt/status#panel::onHeightChange {
  ble/prompt/status#panel::invalidate
}
function ble/prompt/status#collapse {
  local -a DRAW_BUFF=()
  ble/canvas/panel#set-height.draw "$_ble_prompt_status_panel" 0
  ble/canvas/bflush.draw
}

# 
#------------------------------------------------------------------------------
# **** ble/edit/visible-bell ****                                  @panel.vbell

_ble_edit_vbell_panel=3

## @var _ble_edit_vbell_state[0] message
## @var _ble_edit_vbell_state[1] opts
## @var _ble_edit_vbell_state[2] dirty
## @var _ble_edit_vbell_state[3] sgr
## @var _ble_edit_vbell_state[4] esc
## @var _ble_edit_vbell_state[5] esc_cols
## @var _ble_edit_vbell_state[6] esc_width
_ble_edit_vbell_state=('' '' 0)

function ble/edit/visible-bell#panel::getHeight {
  if [[ ${_ble_edit_vbell_state[0]} ]]; then
    height=0:1
  else
    height=0:0
  fi
}
function ble/edit/visible-bell#panel::invalidate {
  (($1!=_ble_edit_vbell_panel)) && return 0
  _ble_edit_vbell_state[2]=1
}
function ble/edit/visible-bell#panel::render {
  (($1!=_ble_edit_vbell_panel)) && return 0
  ble/edit/is-command-layout && return 0
  ((_ble_edit_vbell_state[2]==1)) || return 0

  local message=${_ble_edit_vbell_state[0]}

  local -a DRAW_BUFF=()
  if [[ ! $message ]]; then
    ble/canvas/panel#set-height.draw "$_ble_edit_vbell_panel" 0
  else
    ble/canvas/panel/reallocate-height.draw
    local panel_height=${_ble_canvas_panel_height[$1]}
    if ((panel_height>=1)); then
      local ret
      ble/canvas/panel/save-position; local pos=$ret
      ble/canvas/put.draw "$_ble_term_sgr0"
      ble/canvas/panel#clear.draw "$_ble_edit_vbell_panel"
      ble/canvas/panel#goto.draw "$_ble_edit_vbell_panel"

      local lines=1 cols=${COLUMNS:-80}
      ((_ble_term_xenl||COLUMNS--))
      if ((cols!=_ble_edit_vbell_state[5])); then
        local x=0 y=0 ret= sgr0= sgr1=
        ble/canvas/trace-text "$message" nonewline:external-sgr
        _ble_edit_vbell_state[4]=$ret
        _ble_edit_vbell_state[5]=$cols
        _ble_edit_vbell_state[6]=$x
      fi

      local sgr=${_ble_edit_vbell_state[3]}
      local esc=${_ble_edit_vbell_state[4]}
      local esc_w=${_ble_edit_vbell_state[6]}

      local margin=$((cols-esc_w))
      case :$bleopt_vbell_align: in
      (*:left:*) margin=0;;
      (*:center:*) ((margin/=2)) ;;
      (*:right:*) ;;
      esac

      ble/canvas/put.draw "$_ble_term_cr"
      ((margin>0)) && ble/canvas/put-cuf.draw "$margin"
      ble/canvas/put.draw "$sgr$esc"
      ((_ble_canvas_x=margin+esc_w))
      ble/canvas/panel/load-position.draw "$pos"
    fi
  fi
  ble/canvas/bflush.draw
  _ble_edit_vbell_state[2]=0
}

function ble/edit/visible-bell#collapse {
  if ble/is-function ble/util/idle.push; then
    ble/util/idle.cancel ble/edit/visible-bell/.async-1.idle
    ble/util/idle.cancel ble/edit/visible-bell/.async-2.idle
  fi
  _ble_edit_vbell_state=('' '' 0)
  local -a DRAW_BUFF=()
  ble/canvas/panel#set-height.draw "$_ble_edit_vbell_panel" 0
  ble/canvas/bflush.draw
}

## @fn ble/edit/visible-bell/.show face
##   @param[in] face
##     Specifies the face name to use in showing the visible bell.
function ble/edit/visible-bell/.show {
  [[ ${_ble_edit_vbell_state[0]} ]] || return 0

  local ret
  ble/color/face2sgr "$1"; local sgr=$ret

  if [[ $sgr != "${_ble_edit_vbell_state[2]}" ]]; then
    _ble_edit_vbell_state[2]=1 # invalidate
    _ble_edit_vbell_state[3]=$sgr
  fi
  ble/edit/visible-bell#panel::render "$_ble_edit_vbell_panel"
  ble/util/buffer.flush
}
function ble/edit/visible-bell/.clear {
  ble/edit/visible-bell#collapse
  ble/util/buffer.flush
}

## @fn ble/edit/visible-bell message [opts]
##   @param[in] message
##   @param[in,opt] opts
##     @opt persistent
function ble/edit/visible-bell {
  # Check whether the visible-bell in the panel is supported in the current
  # context.
  [[ $_ble_attached ]] || return 1
  ble/util/is-running-in-subshell && return 1
  ble/is-function ble/util/idle.push || return 1
  ble/util/is-running-in-idle && return 1

  local message=$1 opts=$2
  if [[ ! $message ]]; then
    ble/edit/visible-bell/.clear
    return 0
  fi

  ble/util/idle.cancel ble/edit/visible-bell/.async-1.idle
  ble/util/idle.cancel ble/edit/visible-bell/.async-2.idle
  _ble_edit_vbell_state=("$message" "$opts" 1)
  ble/edit/visible-bell/.show vbell_flash
  ble/util/idle.push --sleep=50 ble/edit/visible-bell/.async-1.idle
  return 0
}

function ble/edit/visible-bell/.async-1.idle {
  ble/edit/visible-bell/.show vbell
  if [[ :${_ble_edit_vbell_state[1]}: != *:persistent:* ]]; then
    local msec=$((bleopt_vbell_duration))
    ble/util/idle.push --sleep="$msec" ble/edit/visible-bell/.async-2.idle
  fi
  return 0
}

function ble/edit/visible-bell/.async-2.idle {
  ble/edit/visible-bell/.clear
  return 0
}

# 
#------------------------------------------------------------------------------
# **** prompt ****                                                    @line.ps1

## @var _ble_prompt_version
##   Variable to increment every time the prompt is updated with ble/prompt/update
_ble_prompt_hash=
_ble_prompt_version=0

function ble/prompt/.escape-control-characters {
  ret=$1

  local ctrl=$'\001-\037\177'
  case $_ble_util_locale_encoding in
  (UTF-8) ctrl=$ctrl$'\302\200-\302\237' ;;
  (C)     ctrl=$ctrl$'\200-\237' ;;
  esac

  local LC_ALL= LC_COLLATE=C glob_ctrl=[$ctrl]
  [[ $ret == *$glob_ctrl* ]] || return 0

  local out= head tail=$ret cs
  while head=${tail%%$glob_ctrl*}; [[ $head != "$tail" ]]; do
    ble/util/s2c "${tail:${#head}:1}"
    ble/unicode/GraphemeCluster/.get-ascii-rep "$ret" # -> cs
    out=$out$head$'\e[9807m'$cs$'\e[9807m'
    tail=${tail#*$glob_ctrl}
  done
  ret=$out$tail
}
ble/function#suppress-stderr ble/prompt/.escape-control-characters # LC_COLLATE

## @fn ble/prompt/.initialize-constant ps defeval [opts]
##   @param ps
##     Specifies the prompt sequence to use for initialization.
##   @param defeval
##     Specifies the command used for initialization. Store the result in ret.
##   @param[opt] opts
##     A colon-separated list of options. When escape is specified,
##     Escapes control characters included in the expansion result.
function ble/prompt/.initialize-constant {
  local _ble_local_ps=$1
  local _ble_local_defeval=$2
  local _ble_local_opts=$3
  if ((_ble_bash>=40400)); then
    ret=${_ble_local_ps@P}
  else
    builtin eval -- "$_ble_local_defeval"
  fi

  if [[ $_ble_local_opts == *:escape:* ]]; then
    if ((_ble_bash>=50200)); then
      # bash-5.2 or higher, bash performs escape, but processing such as reversal is not performed.
      # ble.sh side if control characters are included.
      # Process with .
      if [[ $ret == *\^['A'-'Z[\]^_?']* ]]; then
        builtin eval -- "$_ble_local_defeval"
        ble/prompt/.escape-control-characters "$ret"
      elif [[ $ret == *$'\t'* ]]; then
        ble/prompt/.escape-control-characters "$ret"
      fi
    else
      ble/prompt/.escape-control-characters "$_ble_prompt_const_s"
    fi
  fi
}

## called by ble-edit/initialize
function ble/prompt/initialize {
  local ret

  # hostname
  ble/prompt/.initialize-constant '\H' 'ret=${HOSTNAME:-$_ble_base_env_HOSTNAME}' escape
  _ble_prompt_const_H=$ret
  if local rex='^[0-9]+(\.[0-9]){3}$'; [[ $_ble_prompt_const_H =~ $rex ]]; then
    # Do not omit in case of IPv4 format
    _ble_prompt_const_h=$_ble_prompt_const_H
  else
    _ble_prompt_const_h=${_ble_prompt_const_H%%.*}
  fi

  # tty basename
  ble/prompt/.initialize-constant '\l' 'ble/util/assign ret "ble/bin/tty 2>/dev/null";ret=${ret##*/}'
  _ble_prompt_const_l=$ret

  # command name
  ble/prompt/.initialize-constant '\s' 'ret=${0##*/}' escape
  _ble_prompt_const_s=$ret

  # user
  ble/prompt/.initialize-constant '\u' 'ret=${USER:-$_ble_base_env_USER}' escape
  _ble_prompt_const_u=$ret

  # bash versions
  ble/util/sprintf _ble_prompt_const_v '%d.%d' "${BASH_VERSINFO[0]}" "${BASH_VERSINFO[1]}"
  ble/util/sprintf _ble_prompt_const_V '%d.%d.%d' "${BASH_VERSINFO[0]}" "${BASH_VERSINFO[1]}" "${BASH_VERSINFO[2]}"

  # uid
  if [[ $EUID -eq 0 ]]; then
    _ble_prompt_const_root='#'
  else
    _ble_prompt_const_root='$'
  fi

  if ble/base/is-msys; then
    # Follow msys64/etc/bash.bashrc
    if ble/bin#has id getent; then
      local id getent
      ble/util/assign id 'id -G'
      ble/util/assign getent 'getent -w group S-1-16-12288'
      ble/string#split getent : "$getent"
      [[ " $id " == *" ${getent[1]} "* ]] &&
        _ble_prompt_const_root='#'
    fi
  elif [[ $OSTYPE == cygwin* ]]; then
    local windir=/cygdrive/c/Windows
    if [[ $WINDIR == [a-zA-Z]:\\* ]]; then
      local bsl='\' sl=/
      local c=${WINDIR::1} path=${WINDIR:3}
      if ble/string#isupper "$c"; then
        if ((_ble_bash>=40000)); then
          c=${c,?}
        else
          local ret
          ble/util/s2c "$c"
          ble/util/c2s "$((ret+32))"
          c=$ret
        fi
      fi
      windir=/cygdrive/$c/${path//"$bsl"/"$sl"}
    fi

    if [[ -e $windir && -w $windir ]]; then
      _ble_prompt_const_root='#'
    fi
  fi
}

## @arr PREFIX_data
##   The unit of data displayed in the prompt.
##   It has a function to manage dependencies on other data.
##
##   @var PREFIX_data[0]    version
##     Holds the number of times the prompt information has been updated.
##   @var PREFIX_data[1]    hashref
##   @var PREFIX_data[2]    hash
##     Variable used for dependency tracking.
##
## @fn ble/prompt/unit#update TYPE PREFIX ARGS...
##   Update data while tracking dependencies.
##
##   @fn[in] ble/prompt/unit:TYPE/update
##     Update the data. Returns 0 if the data has changed.
##     Returns 1 otherwise.
##
##     @var[in]     prompt_unit
##     @var[in,out] prompt_unit_changed
##     @var[in]     prompt_unit_expired
##     @var[in,out] prompt_hashref_dep
##     @var[in,out] prompt_hashref_var
##
##   @var[in,opt]  prompt_hashref_base
##
##   @var[in] prompt_unit
##     This is a variable that is set when ble/prompt/unit:PREFIX/update is called nested.
##     Preserves the parent prompt's PREFIX.
##     Update the following variables in the caller to track dependencies between prompts:
##
##     @var[ref,opt] prompt_hashref_dep
##
function ble/prompt/unit#update {
  local unit=$1

  local prompt_unit_changed=
  local prompt_unit_expired=

  local ohashref=${unit}_data[1]; ohashref=${!ohashref-}
  if [[ ! $ohashref ]]; then
    prompt_unit_expired=1
  else
    ble/prompt/unit#update/.update-dependencies "$ohashref"
    local ohash=${unit}_data[2]; ohash=${!ohash}
    builtin eval -- "local nhash=\"$ohashref\"" 2>/dev/null
    [[ $nhash != "$ohash" ]] && prompt_unit_expired=1
  fi

  if [[ $prompt_unit_expired ]]; then
    local prompt_unit=$unit
    local prompt_hashref_dep= # Inter-prompt dependencies
    local prompt_hashref_var= # Dependency on variables

    ble/prompt/unit:"$unit"/update "$unit" &&
      ((prompt_unit_changed=1,${unit}_data[0]++))

    local hashref=${prompt_hashref_base-'$_ble_prompt_version'}:$prompt_hashref_dep:$prompt_hashref_var
    builtin eval -- "${unit}_data[1]=\$hashref"
    builtin eval -- "${unit}_data[2]=\"$hashref\"" 2>/dev/null
    ble/util/unlocal prompt_unit prompt_hashref_dep
  fi

  # Update caller prompt_hashref_dep (dependency registration)
  if [[ $prompt_unit ]]; then
    local ref1='$'$unit'_data'
    [[ ,$prompt_hashref_dep, != *,"$ref1",* ]] &&
      prompt_hashref_dep=$prompt_hashref_dep${prompt_hashref_dep:+,}$ref1
  fi
  [[ $prompt_unit_changed ]]
}
function ble/prompt/unit#update/.update-dependencies {
  local ohashref=$1
  local otree=${ohashref#*:}; otree=${otree%%:*}
  if [[ $otree ]]; then
    ble/string#split otree , "$otree"

    if [[ ! $ble_prompt_unit_processing ]]; then
      local ble_prompt_unit_processing=1
      "${_ble_util_set_declare[@]//NAME/ble_prompt_unit_mark}" # WA #D1570 checked
    elif ble/set#contains ble_prompt_unit_mark "$unit"; then
      ble/util/print "ble/prompt: FATAL: detected cyclic dependency ($unit required by $ble_prompt_unit_parent)" >&"$_ble_util_fd_tui_stderr"
      return 1
    fi
    local ble_prompt_unit_parent=$unit
    ble/set#add ble_prompt_unit_mark "$unit"

    local prompt_unit= # Do not register dependencies
    local child
    for child in "${otree[@]}"; do
      [[ $child == '$'?*'_data' ]] || continue
      child=${child:1:${#child}-6}
      ble/is-function ble/prompt/unit:"$child"/update &&
        ble/prompt/unit#update "$child"
    done

    ble/set#remove ble_prompt_unit_mark "$unit"
  fi
}
function ble/prompt/unit#clear {
  local prefix=$1
  builtin eval -- "${prefix}_data[2]="
}

function ble/prompt/unit/assign {
  local var=$1 value=$2
  [[ $value == "${!var}" ]] && return 1
  prompt_unit_changed=1
  builtin eval -- "$var=\$value"
}

## @fn ble/prompt/unit/add-hash hashref
##   Specifies the shell word used to detect prompt updates.
function ble/prompt/unit/add-hash {
  [[ $prompt_unit && ,$prompt_hashref_var, != *,"$1",* ]] &&
    prompt_hashref_var=$prompt_hashref_var${prompt_hashref_var:+,}$1
  return 0
}

## @var _ble_prompt_ps1_data
## @var _ble_prompt_rps1_data
## @var _ble_prompt_status_data
## @var _ble_prompt_xterm_title_data
## @var _ble_prompt_screen_title_data
## @var _ble_prompt_term_status_data
##   Cache the information of the constructed prompt.
##
##   @var PREFIX_data[3..5] x y g
##     Represents the cursor position and drawing attributes when the prompt finishes displaying.
##   @var PREFIX_data[6..7] lc lg
##     When bleopt_internal_suppress_bash_output=,
##     Represents the characters on the left side and their drawing attributes when the prompt is finished displaying.
##     This value is not used otherwise.
##   @var PREFIX_data[8]    ps1out (esc)
##     A string containing the control sequence to output to display the prompt.
##   @var PREFIX_data[9]    trace_hash
##     A string in the format COLUMNS:ps1esc.
##     Stores ps1out before adjustment.
##     Used to omit ps1out calculation (trace).
##
##   @var PREFIX_data[10...] tailored
##     Data obtained by processing the results of ps1out.
##     Since processing may be re-executed later, it is managed in a unified manner.
##
_ble_prompt_ps1_dirty=
_ble_prompt_ps1_data=(0 '' '' 0 0 0 32 0 '' '')
_ble_prompt_ps1_bbox=()
_ble_prompt_rps1_dirty=
_ble_prompt_rps1_data=()
_ble_prompt_rps1_gbox=()
_ble_prompt_rps1_shown=

_ble_prompt_xterm_title_dirty=
_ble_prompt_xterm_title_data=()
_ble_prompt_screen_title_dirty=
_ble_prompt_screen_title_data=()
_ble_prompt_term_status_dirty=
_ble_prompt_term_status_data=()

## @fn ble/prompt/print text
##   A function to call during prompt construction.
##   Outputs the specified string, escaping it for later evaluation.
##   @param[in] text
##     Specifies the string to be escaped.
##   @var[out]  DRAW_BUFF[]
##     This is the output destination array.
function ble/prompt/print {
  local ret=$1
  [[ $prompt_noesc ]] ||
    ble/string#escape-characters "$ret" '\$"`'
  ble/canvas/put.draw "$ret"
}

## @fn ble/prompt/process-prompt-string prompt_string
##   A function to call during prompt construction.
##   Processes the specified argument by interpreting it in a format similar to PS1.
##   @param[in] prompt_string
##   @arr[in,out] DRAW_BUFF
function ble/prompt/process-prompt-string {
  local ps1=$1
  local i=0 iN=${#ps1}
  local rex_letters='^[^\]+|\\$'
  while ((i<iN)); do
    local tail=${ps1:i}
    if [[ $tail == '\'?* ]]; then
      ble/prompt/.process-backslash
    elif [[ $tail =~ $rex_letters ]]; then
      ble/canvas/put.draw "$BASH_REMATCH"
      ((i+=${#BASH_REMATCH}))
    else
      # ? It shouldn't come here.
      ble/canvas/put.draw "${tail::1}"
      ((i++))
    fi
  done
}
## @fn ble/prompt/.process-backslash
##   @var[in]     tail
##   @arr[in.out] DRAW_BUFF
function ble/prompt/.process-backslash {
  ((i+=2))

  # next character after \\
  local c=${tail:1:1} pat='][#!$\'
  if [[ $c == ["$pat"] ]]; then
    case $c in
    (\[) ble/canvas/put.draw $'\001' ;; # \[ \] outputs an appropriate identification string for post-processing.
    (\]) ble/canvas/put.draw $'\002' ;;
    ('#') # Command number (actually, some things don't go into history...)
      ble/prompt/unit/add-hash '$_ble_edit_CMD'
      ble/canvas/put.draw "$_ble_edit_CMD" ;;
    (\!) # Edit line history number
      local count
      ble/history/get-count -v count
      ble/canvas/put.draw "$((count+1))" ;;
    ('$') # # or $
      ble/prompt/print "$_ble_prompt_const_root" ;;
    (\\)
      # '\\' escapes the next character when evaluated within "" after being printed as '\'.
      # For example, '\\$' becomes '\$' and then expands to '$'. '\\\\' similarly becomes '\'.
      ble/canvas/put.draw '\' ;;
    esac
  elif ble/is-function ble/prompt/backslash:"$c"; then
    ble/function#try ble/prompt/backslash:"$c"
  elif ble/is-function ble-edit/prompt/backslash:"$c"; then # deprecated name
    ble/function#try ble-edit/prompt/backslash:"$c"
  else
    # Other characters are output as is.
    # - '\"' '\`' is output as is and then evaluated within "" to become '"' '`'.
    # - In other cases, even if '\?' is output as is and then evaluated within "", it will remain as '\?' etc.
    ble/canvas/put.draw "\\$c"
  fi
}

## @fn[custom] ble/prompt/backslash:*
##   Defines the backslash sequence to use within prompt PS1.
##   Internally ble/canvas/put.draw escaped_text or
##   using ble/prompt/print unescaped_text
##   Add the sequence expansion results.
##
##   @exit
##     Succeeds when the corresponding string is output.
##     If it returns an exit status other than 0,
##     the sequence is considered not to have been processed,
##     The caller writes \c (the c: character) instead.
##
function ble/prompt/backslash:0 { # octal representation
  local rex='^\\[0-7]{1,3}'
  if [[ $tail =~ $rex ]]; then
    local seq=${BASH_REMATCH[0]}
    ((i+=${#seq}-2))
    builtin eval "c=\$'$seq'"
  fi
  ble/prompt/print "$c"
  return 0
}
function ble/prompt/backslash:1 { ble/prompt/backslash:0; }
function ble/prompt/backslash:2 { ble/prompt/backslash:0; }
function ble/prompt/backslash:3 { ble/prompt/backslash:0; }
function ble/prompt/backslash:4 { ble/prompt/backslash:0; }
function ble/prompt/backslash:5 { ble/prompt/backslash:0; }
function ble/prompt/backslash:6 { ble/prompt/backslash:0; }
function ble/prompt/backslash:7 { ble/prompt/backslash:0; }
function ble/prompt/backslash:a { # 0 BEL
  ble/canvas/put.draw ""
  return 0
}
function ble/prompt/backslash:e {
  ble/canvas/put.draw $'\e'
  return 0
}
function ble/prompt/backslash:n {
  ble/canvas/put.draw $'\n'
  return 0
}
function ble/prompt/backslash:r {
  ble/canvas/put.draw "$_ble_term_cr"
  return 0
}

_ble_prompt_cache_vars=(
  prompt_cache_d
  prompt_cache_t
  prompt_cache_A
  prompt_cache_T
  prompt_cache_at
  prompt_cache_j
  prompt_cache_wd
)

function ble/prompt/backslash:d { # ? date
  [[ $prompt_cache_d ]] || ble/util/strftime -v prompt_cache_d '%a %b %d'
  ble/prompt/print "$prompt_cache_d"
  return 0
}
function ble/prompt/backslash:t { # 8 time
  [[ $prompt_cache_t ]] || ble/util/strftime -v prompt_cache_t '%H:%M:%S'
  ble/prompt/print "$prompt_cache_t"
  return 0
}
function ble/prompt/backslash:A { # 5 time
  [[ $prompt_cache_A ]] || ble/util/strftime -v prompt_cache_A '%H:%M'
  ble/prompt/print "$prompt_cache_A"
  return 0
}
function ble/prompt/backslash:T { # 8 time
  [[ $prompt_cache_T ]] || ble/util/strftime -v prompt_cache_T '%I:%M:%S'
  ble/prompt/print "$prompt_cache_T"
  return 0
}
function ble/prompt/backslash:@ { # ? Time
  [[ $prompt_cache_at ]] || ble/util/strftime -v prompt_cache_at '%I:%M %p'
  ble/prompt/print "$prompt_cache_at"
  return 0
}
function ble/prompt/backslash:D {
  local rex='^\\D\{([^{}]*)\}' cache_D
  if [[ $tail =~ $rex ]]; then
    ble/util/strftime -v cache_D "${BASH_REMATCH[1]}"
    ble/prompt/print "$cache_D"
    ((i+=${#BASH_REMATCH}-2))
  else
    ble/prompt/print "\\$c"
  fi
  return 0
}
function ble/prompt/backslash:h { # = hostname
  ble/prompt/print "$_ble_prompt_const_h"
  return 0
}
function ble/prompt/backslash:H { # = hostname
  ble/prompt/print "$_ble_prompt_const_H"
  return 0
}
function ble/prompt/backslash:j { #   number of jobs
  if [[ ! $prompt_cache_j ]]; then
    local joblist
    ble/util/joblist
    prompt_cache_j=${#joblist[@]}
  fi
  ble/canvas/put.draw "$prompt_cache_j"
  return 0
}
function ble/prompt/backslash:l { #   tty basename
  ble/prompt/print "$_ble_prompt_const_l"
  return 0
}
function ble/prompt/backslash:s { # 4 "bash"
  ble/prompt/print "$_ble_prompt_const_s"
  return 0
}
function ble/prompt/backslash:u { # = username
  ble/prompt/print "$_ble_prompt_const_u"
  return 0
}
function ble/prompt/backslash:v { # = bash version %d.%d
  ble/prompt/print "$_ble_prompt_const_v"
  return 0
}
function ble/prompt/backslash:V { # = bash version %d.%d.%d
  ble/prompt/print "$_ble_prompt_const_V"
  return 0
}
function ble/prompt/backslash:w { # PWD
  ble/prompt/unit/add-hash '$PWD'
  ble/prompt/.update-working-directory
  local ret
  ble/prompt/.escape-control-characters "$prompt_cache_wd"
  ble/prompt/print "$ret"
  return 0
}
function ble/prompt/backslash:W { # PWD reduction
  ble/prompt/unit/add-hash '$PWD'
  if [[ ! ${PWD//'/'} ]]; then
    ble/prompt/print "$PWD"
  else
    ble/prompt/.update-working-directory
    local ret
    ble/prompt/.escape-control-characters "${prompt_cache_wd##*/}"
    ble/prompt/print "$ret"
  fi
  return 0
}

# \q{name} (ble.sh extension)
function ble/prompt/backslash:q {
  local rex='^\{([^{}]*)\}'
  if [[ ${tail:2} =~ $rex ]]; then
    local rematch=$BASH_REMATCH
    ((i+=${#rematch}))
    local word; ble/string#split-words word "${BASH_REMATCH[1]}"
    if [[ $word ]] && ble/is-function ble/prompt/backslash:"$word"; then
      ble/util/joblist.check
      ble/prompt/backslash:"${word[@]}"; local ext=$?
      ble/util/joblist.check ignore-volatile-jobs
      return "$?"
    else
      if [[ ! $word ]]; then
        ble/term/visible-bell "ble/prompt: invalid sequence \\q$rematch"
      elif ! ble/is-function ble/prompt/backslash:"$word"; then
        ble/term/visible-bell "ble/prompt: undefined named sequence \\q{$word}"
      fi
      ble/prompt/print "\\q$BASH_REMATCH"
      return 2
    fi
  else
    ble/prompt/print "\\$c"
  fi
  return 0
}
function ble/prompt/backslash:g {
  local rex='^\{([^{}]*)\}'
  if [[ ${tail:2} =~ $rex ]]; then
    ((i+=${#BASH_REMATCH}))
    local ret
    ble/color/spec2g "${BASH_REMATCH[1]}"
    ble/color/g2sgr-ansi "$ret"
    ble/prompt/print "$ret"
  else
    ble/prompt/print "\\$c"
  fi
  return 0
}
function ble/prompt/backslash:position {
  ((_ble_textmap_dbeg>=0)) && ble/widget/.update-textmap
  local fmt=${1:-'(%s,%s)'} pos
  ble/prompt/unit/add-hash '${_ble_textmap_pos[_ble_edit_ind]}'
  ble/string#split-words pos "${_ble_textmap_pos[_ble_edit_ind]}"
  ble/util/sprintf pos "$fmt" "$((pos[1]+1))" "$((pos[0]+1))"
  ble/prompt/print "$pos"
}
function ble/prompt/backslash:row {
  ((_ble_textmap_dbeg>=0)) && ble/widget/.update-textmap
  local pos
  ble/prompt/unit/add-hash '${_ble_textmap_pos[_ble_edit_ind]}'
  ble/string#split-words pos "${_ble_textmap_pos[_ble_edit_ind]}"
  ble/prompt/print "$((pos[1]+1))"
}
function ble/prompt/backslash:column {
  ((_ble_textmap_dbeg>=0)) && ble/widget/.update-textmap
  local pos
  ble/prompt/unit/add-hash '${_ble_textmap_pos[_ble_edit_ind]}'
  ble/string#split-words pos "${_ble_textmap_pos[_ble_edit_ind]}"
  ble/prompt/print "$((pos[0]+1))"
}
function ble/prompt/backslash:point {
  ble/prompt/unit/add-hash '$_ble_edit_ind'
  ble/prompt/print "$_ble_edit_ind"
}
function ble/prompt/backslash:mark {
  ble/prompt/unit/add-hash '$_ble_edit_mark'
  ble/prompt/print "$_ble_edit_mark"
}
function ble/prompt/backslash:history-index {
  ble/prompt/unit/add-hash '$_ble_history_INDEX'
  ble/canvas/put.draw "$((_ble_history_INDEX+1))"
}
function ble/prompt/backslash:history-percentile {
  ble/prompt/unit/add-hash '$_ble_history_INDEX'
  ble/prompt/unit/add-hash '$_ble_history_COUNT'
  local index=$_ble_history_INDEX
  local count=$_ble_history_COUNT
  ((count||count++))
  ble/canvas/put.draw "$((index*100/count))%"
}

## @fn ble/prompt/.update-working-directory
##   @var[in,out] prompt_cache_wd
function ble/prompt/.update-working-directory {
  [[ $prompt_cache_wd ]] && return 0

  if [[ ! ${PWD//'/'} ]]; then
    prompt_cache_wd=$PWD
    return 0
  fi

  local head= body=${PWD%/}
  if [[ $body == "$HOME" ]]; then
    prompt_cache_wd='~'
    return 0
  elif [[ $body == "$HOME"/* ]]; then
    head='~/'
    body=${body#"$HOME"/}
  fi

  if [[ $PROMPT_DIRTRIM ]]; then
    local dirtrim=$((PROMPT_DIRTRIM))
    local pat='[^/]'
    local count=${body//$pat}
    if ((${#count}>=dirtrim)); then
      local ret
      ble/string#repeat '/*' "$dirtrim"
      local omit=${body%$ret}
      ((${#omit}>3)) &&
        body=...${body:${#omit}}
    fi
  fi

  prompt_cache_wd=$head$body
}

function ble/prompt/.escape/check-double-quotation {
  if [[ $tail == '"'* ]]; then
    if [[ ! $nest ]]; then
      out=$out'\"'
      tail=${tail:1}
    else
      out=$out'"'
      tail=${tail:1}
      nest=\"$nest
      ble/prompt/.escape/update-rex_skip
    fi
    return 0
  else
    return 1
  fi
}
function ble/prompt/.escape/check-command-substitution {
  if [[ $tail == '$('* ]]; then
    out=$out'$('
    tail=${tail:2}
    nest=')'$nest
    ble/prompt/.escape/update-rex_skip
    return 0
  else
    return 1
  fi
}
function ble/prompt/.escape/check-parameter-expansion {
  if [[ $tail == '${'* ]]; then
    out=$out'${'
    tail=${tail:2}
    nest='}'$nest
    ble/prompt/.escape/update-rex_skip
    return 0
  else
    return 1
  fi
}
function ble/prompt/.escape/check-incomplete-quotation {
  if [[ $tail == '`'* ]]; then
    local rex='^`([^\`]|\\.)*\\$'
    [[ $tail =~ $rex ]] && tail=$tail'\'
    out=$out$tail'`'
    tail=
    return 0
  elif [[ $nest == ['})']* && $tail == \'* ]]; then
    out=$out$tail$q
    tail=
    return 0
  elif [[ $nest == ['})']* && $tail == \$\'* ]]; then
    local rex='^\$'$q'([^\'$q']|\\.)*\\$'
    [[ $tail =~ $rex ]] && tail=$tail'\'
    out=$out$tail$q
    tail=
    return 0
  elif [[ $tail == '\' ]]; then
    out=$out'\\'
    tail=
    return 0
  else
    return 1
  fi
}
function ble/prompt/.escape/update-rex_skip {
  if [[ $nest == \)* ]]; then
    rex_skip=$rex_skip_paren
  elif [[ $nest == \}* ]]; then
    rex_skip=$rex_skip_brace
  else
    rex_skip=$rex_skip_dquot
  fi
}
function ble/prompt/.escape {
  local tail=$1 out= nest=

  # Escape only the " in the ground sentence.

  local q=\'
  local rex_bq='`([^\`]|\\.)*`'
  local rex_sq=$q'[^'$q']*'$q'|\$'$q'([^\'$q']|\\.)*'$q

  local rex_skip
  local rex_skip_dquot='^([^\"$`]|'$rex_bq'|\\.)+'
  local rex_skip_brace='^([^\"$`'$q'}]|'$rex_bq'|'$rex_sq'|\\.)+'
  local rex_skip_paren='^([^\"$`'$q'()]|'$rex_bq'|'$rex_sq'|\\.)+'
  ble/prompt/.escape/update-rex_skip

  while [[ $tail ]]; do
    if [[ $tail =~ $rex_skip ]]; then
      out=$out$BASH_REMATCH
      tail=${tail:${#BASH_REMATCH}}
    elif [[ $nest == ['})"']* && $tail == "${nest::1}"* ]]; then
      out=$out${nest::1}
      tail=${tail:1}
      nest=${nest:1}
      ble/prompt/.escape/update-rex_skip
    elif [[ $nest == \)* && $tail == \(* ]]; then
      out=$out'('
      tail=${tail:1}
      nest=')'$nest
    elif ble/prompt/.escape/check-double-quotation; then
      continue
    elif ble/prompt/.escape/check-command-substitution; then
      continue
    elif ble/prompt/.escape/check-parameter-expansion; then
      continue
    elif ble/prompt/.escape/check-incomplete-quotation; then
      continue
    else
      out=$out${tail::1}
      tail=${tail:1}
    fi
  done
  ret=$out$nest
}
## @fn ble/prompt/.get-keymap-for-current-mode
##   @var[out] keymap
function ble/prompt/.get-keymap-for-current-mode {
  ble/prompt/unit/add-hash '$_ble_decode_keymap,${_ble_decode_keymap_stack[*]}'
  ble/decode/keymap/get-major-keymap
}

function ble/prompt/.uses-builtin-prompt-expansion {
  ((_ble_bash>=40400)) || return 1

  local ps=$1
  local chars_safe_esc='][0-7aenrdtAT@DhHjlsuvV!$\wW'
  [[ ( $OSTYPE == cygwin || $OSTYPE == msys ) && $_ble_prompt_const_root == '#' ]] &&
    chars_safe_esc=${chars_safe_esc//'$'} # Note: In cygwin, \$ is processed using a method unique to ble.sh.

  [[ $ps == *'\'[!"$chars_safe_esc"]* ]] && return 1

  local glob_ctrl=$'[\001-\037\177]'
  [[ $ps == *'\'[wW]* && $PWD == *$glob_ctrl* ]] && return 1
  [[ $ps == *'\s'* && $_ble_prompt_const_s == *$'\e'* ]] && return 1
  [[ $ps == *'\u'* && $_ble_prompt_const_u == *$'\e'* ]] && return 1
  [[ $ps == *'\h'* && $_ble_prompt_const_h == *$'\e'* ]] && return 1
  [[ $ps == *'\H'* && $_ble_prompt_const_H == *$'\e'* ]] && return 1

  return 0
}

## @fn ble/prompt/.instantiate ps opts [x0 y0 g0 lc0 lg0 esc0 trace_hash0]
##
##   @var[out] x y g
##     Specifies the starting point for drawing the prompt.
##     Returns the position after drawing the prompt.
##   @var[out] lc lg
##     When bleopt_internal_suppress_bash_output=,
##     Specifies the character code to the left of the drawing starting point.
##     Returns the character code to the left of the drawing end point if known.
##   @var[out] esc
##     Returns a string to draw the prompt.
##   @var[out] trace_hash
##
##   @var[in,out] x1 x2 y1 y2
##     When measure-bbox is specified for opts.
##   @var[in,out] "${_ble_prompt_cache_vars[@]}"
##   @var[in,out] prompt_rows prompt_cols
##
function ble/prompt/.instantiate {
  trace_hash= esc= x=0 y=0 g=0 lc=32 lg=0
  local ps=$1 opts=$2 x0=$3 y0=$4 g0=$5 lc0=$6 lg0=$7 esc0=$8 trace_hash0=$9
  [[ ! $ps ]] && return 0

  local expanded=
  if ble/prompt/.uses-builtin-prompt-expansion "$ps"; then
    [[ $ps == *'\'[wW]* ]] && ble/prompt/unit/add-hash '$PWD'
    ble-edit/exec/eval-with-setexit 'expanded=${ps@P}' pipestatus
  else
    # Deployment settings
    local prompt_noesc=
    shopt -q promptvars &>/dev/null || prompt_noesc=1

    # 1. Process \c included in PS1
    local -a DRAW_BUFF=()
    ble/prompt/process-prompt-string "$ps"
    local processed; ble/canvas/sflush.draw -v processed

    # 2. Escape \\ and " contained in PS1,
    #   eval and perform various shell expansions.
    if [[ ! $prompt_noesc ]]; then
      local ret
      ble/prompt/.escape "$processed"; local escaped=$ret
      expanded=${trace_hash0#*:} # Note: This is the default value when the next line fails
      ble-edit/exec/eval-with-setexit "expanded=\"$escaped\"" pipestatus
    else
      expanded=$processed
    fi
  fi

  if [[ :$opts: == *:show-mode-in-prompt:* ]]; then
    if ble/util/rlvar#test show-mode-in-prompt; then
      local keymap; ble/prompt/.get-keymap-for-current-mode

      # Note: plain In bash-4.3, there is no *-mode-string setting item yet,
      #   vi-ins-mode-string is '+', vi-cmd-mode-string is ':',
      #   emacs-mode-string is displayed corresponding to '@'. bash-4.4 in ble.sh
      #   We will use the same default values as below.
      local ret=
      case $keymap in
      (vi_imap)      ble/util/rlvar#read vi-ins-mode-string '(ins)' ;; # Note: '+' in bash-4.3
      (vi_[noxs]map) ble/util/rlvar#read vi-cmd-mode-string '(cmd)' ;; # Note: ':' in bash-4.3
      (emacs)        ble/util/rlvar#read emacs-mode-string  '@'     ;;
      esac
      [[ $ret ]] && expanded=$ret$expanded
    fi
  fi

  # 3. Configure output to terminal
  if [[ :$opts: == *:no-trace:* ]]; then
    # Note: Prompt strings such as "ESC k ... ESC \" do not need to be traced.
    x=0 y=0 g=0 lc=32 lg=0
    esc=$expanded
  elif
    local ret g0=0
    if ble/string#match ":$opts:" ':g0=([^:]+):'; then
      ((g0=BASH_REMATCH[1]))
    elif ble/string#match ":$opts:" ':face0=([^:]+):'; then
      ble/color/face2g "${BASH_REMATCH[1]}" && g0=$ret
    fi
    local rows=${prompt_rows:-${LINES:-25}}
    local cols=${prompt_cols:-${COLUMNS:-80}}
    local color=$_ble_color_g2sgr_version
    local bleopt=$bleopt_char_width_mode,$bleopt_char_width_version,$bleopt_emoji_version,$bleopt_emoji_opts
    trace_hash=$opts#$rows,$cols,$color,$g0#$bleopt#$expanded
    [[ $trace_hash != "$trace_hash0" ]]
  then
    local trace_opts=$opts:prompt
    [[ $bleopt_internal_suppress_bash_output ]] || trace_opts=$trace_opts:left-char
    x=0 y=0 g=0 lc=32 lg=0
    local ret
    LINES=$rows COLUMNS=$cols ble/canvas/trace "$expanded" "$trace_opts"; local traced=$ret
    ((lc<0&&(lc=0)))
    esc=$traced
    return 0
  else
    x=$x0 y=$y0 g=$g0 lc=$lc0 lg=$lg0
    esc=$esc0
    return 2
  fi
}

## @fn ble/prompt/unit:{section}/clear prefix type
##   Request recalculation of prompt contents.
##   If it matches the previous content, the additional processing will be omitted.
##
##   @param[in,opt] type
##     hash ... hash clear (recalculate prompt contents)
##     tail ... tail information deletion (re-execute additional processing after prompt content calculation)
##     draw ... dirty settings (redraw prompt contents)
##     all ... Clear all (recalculate all)
##
function ble/prompt/unit:{section}/clear {
  local prefix=$1 type=${2:-hash:draw}
  [[ :$type: == *:hash:* ]] &&
    builtin eval -- "${prefix}_data[2]="
  [[ :$type: == *:tail:* ]] &&
    builtin eval -- "${prefix}_data=(\"\${${prefix}_data[@]::10}\")"
  [[ :$type: == *:draw:* ]] &&
    builtin eval -- "${prefix}_dirty=1"
  [[ :$type: == *:all:* ]] &&
    builtin eval -- "${prefix}_data=(\"\${${prefix}_data[0]}\")"
  return 0
}

function ble/prompt/unit:{section}/get {
  local ref=${1}_data[8]; ret=${!ref}
}

## @fn ble/prompt/unit:{section}/update prefix ps opts
##   @param[in] prefix
##   @param[in] ps
##   @param[in] opts
## Colon-separated trace options.
##
##     show-mode-in-prompt
##       Appends the current mode name.
##
##     no-trace
##       Without converting or measuring using ble/canvas/trace,
##       Process only the prompt string.
##       This is used to analyze content that is not output to the terminal, such as control strings.
##
##   @param[in] prompt_rows prompt_cols
function ble/prompt/unit:{section}/update {
  local prefix=$1 ps=$2 opts=$3

  # Load variables
  local -a vars; vars=(data dirty)
  [[ :$opts: == *:measure-bbox:* ]] && ble/array#push vars bbox
  [[ :$opts: == *:measure-gbox:* ]] && ble/array#push vars gbox
  local "${vars[@]/%/=}" # WA #D1570 checked
  ble/util/restore-vars "${prefix}_" "${vars[@]}"

  local has_changed=
  if [[ $prompt_unit_expired ]]; then
    local original_esc=${data[8]}:${data[9]}:${data[10]} # esc:trace_hash:tailor

    if [[ $ps ]]; then
      # load
      [[ :$opts: == *:measure-bbox:* ]] &&
        local x1=${bbox[0]} y1=${bbox[1]} x2=${bbox[2]} y2=${bbox[3]}
      [[ :$opts: == *:measure-gbox:* ]] &&
        local gx1=${gbox[0]} gy1=${gbox[1]} gx2=${gbox[2]} gy2=${gbox[3]}

      local trace_hash esc x y g lc lg
      ble/prompt/.instantiate "$ps" "$opts" "${data[@]:3:7}"
      data=("${data[0]:-0}" '' '' "$x" "$y" "$g" "$lc" "$lg" "$esc" "$trace_hash" "${data[@]:10}")

      # store
      [[ :$opts: == *:measure-bbox:* ]] &&
        bbox=("$x1" "$y1" "$x2" "$y2")
      [[ :$opts: == *:measure-gbox:* ]] &&
        gbox=("$gx1" "$gy1" "$gx2" "$gy2")
    else
      data=("${data[0]:-0}" '' '' 0 0 0 32 0 '' '' "${data[@]:10}")
      [[ :$opts: == *:measure-bbox:* ]] && bbox=()
      [[ :$opts: == *:measure-gbox:* ]] && gbox=()
    fi

    [[ ${data[8]}:${data[9]}:${data[10]} != "$original_esc" ]] && has_changed=1
  fi

  [[ $has_changed ]] && ((dirty=1))

  # Save variables
  ble/util/save-vars "${prefix}_" "${vars[@]}"

  [[ $has_changed ]]
}

#----------------------------------------------------------
# Definitions of prompt sections

function ble/prompt/unit:_ble_prompt_ps1/update {
  ble/prompt/unit/add-hash '$prompt_ps1'
  ble/prompt/unit:{section}/update _ble_prompt_ps1 "$prompt_ps1" show-mode-in-prompt:measure-bbox
}

function ble/prompt/unit:_ble_prompt_rps1/update {
  ble/prompt/unit/add-hash '$prompt_rps1'
  ble/prompt/unit/add-hash '$_ble_prompt_ps1_data'
  local cols=${COLUMNS-80}
  local ps1x=${_ble_prompt_ps1_data[3]}
  local ps1y=${_ble_prompt_ps1_data[4]}
  local prompt_rows=$((ps1y+1)) prompt_cols=$cols
  ble/prompt/unit:{section}/update _ble_prompt_rps1 "$prompt_rps1" confine:relative:right:measure-gbox || return 1

  local esc=${_ble_prompt_rps1_data[8]} width=
  if [[ $esc ]]; then
    ((width=_ble_prompt_rps1_gbox[2]-_ble_prompt_rps1_gbox[0]))
    ((width&&20+width<cols&&ps1x+10+width<cols)) || esc= width=
  fi
  _ble_prompt_rps1_data[10]=$esc
  _ble_prompt_rps1_data[11]=$width
  return 0
}

function  ble/prompt/unit:_ble_prompt_xterm_title/update {
  ble/prompt/unit/add-hash '$bleopt_prompt_xterm_title'
  local prompt_rows=1
  ble/prompt/unit:{section}/update _ble_prompt_xterm_title "$bleopt_prompt_xterm_title" confine:no-trace || return 1

  local esc=${_ble_prompt_xterm_title_data[8]}
  [[ $esc ]] && esc=$'\e]0;'${esc//[! -~]/'#'}$'\a'
  _ble_prompt_xterm_title_data[10]=$esc
  return 0
}

function ble/prompt/unit:_ble_prompt_screen_title/update {
  ble/prompt/unit/add-hash '$bleopt_prompt_screen_title'
  local prompt_rows=1
  ble/prompt/unit:{section}/update _ble_prompt_screen_title "$bleopt_prompt_screen_title" confine:no-trace || return 1

  local esc=${_ble_prompt_screen_title_data[8]}
  [[ $esc ]] && esc=$'\ek'${esc//[! -~]/'#'}$'\e\\'
  _ble_prompt_screen_title_data[10]=$esc
  return 0
}

function ble/prompt/unit:_ble_prompt_term_status/update {
  ble/prompt/unit/add-hash '$bleopt_prompt_term_status'
  local prompt_rows=1
  ble/prompt/unit:{section}/update _ble_prompt_term_status "$bleopt_prompt_term_status" confine:no-trace || return 1

  local esc=${_ble_prompt_term_status_data[8]}
  if [[ $esc ]]; then
    esc=$_ble_term_tsl${esc//[! -~]/'#'}$_ble_term_fsl
  else
    # Clear status line when non-empty string becomes empty string
    esc=$_ble_term_dsl
  fi
  _ble_prompt_term_status_data[10]=$esc
  return 0
}

function ble/prompt/unit:_ble_prompt_status/update {
  ble/prompt/unit/add-hash '$bleopt_prompt_status_align'
  ble/prompt/unit/add-hash '$bleopt_prompt_status_line'
  ble/prompt/unit/add-hash '$((_ble_faces[_ble_faces__prompt_status_line]))'
  local ps=$bleopt_prompt_status_line
  local cols=$COLUMNS; ((_ble_term_xenl||cols--))
  local trace_opts=confine:relative:measure-bbox:noscrc:face0=prompt_status_line
  local rex='^justify(=[^:]+)?$'
  [[ $bleopt_prompt_status_align =~ $rex ]] &&
    trace_opts=$trace_opts:$BASH_REMATCH

  local prompt_rows=1 prompt_cols=$cols
  ble/prompt/unit:{section}/update _ble_prompt_status "$ps" "$trace_opts" || return 1

  # tailor
  local esc=${_ble_prompt_status_data[8]}
  if [[ $ps && $esc ]]; then
    local x=${_ble_prompt_status_data[3]}
    local y=${_ble_prompt_status_data[4]}
    local x1=${_ble_prompt_status_bbox[0]}
    local x2=${_ble_prompt_status_bbox[2]}

    local -a DRAW_BUFF=()

    # background color
    local ret
    ble/color/face2g prompt_status_line; local g0=$ret
    ble/color/g2sgr "$g0"; local sgr=$ret
    if ((g0==0||_ble_term_bce)); then
      ble/canvas/put.draw "$sgr$_ble_term_el$_ble_term_sgr0"
    else
      ble/string#reserve-prototype "$cols"
      ble/canvas/put.draw "$sgr${_ble_string_prototype::cols}"
      ble/canvas/put-cub.draw "$cols"
      ble/canvas/put.draw "$_ble_term_sgr0"
    fi

    # bleopt prompt_status_align
    local xshift=0
    case $bleopt_prompt_status_align in
    (center) ((xshift=cols/2-(x2+x1)/2)) ;;
    (right)  ((xshift=cols-x2)) ;;
    esac
    if ((xshift>0)); then
      ((x+=xshift))
      ble/canvas/put-cuf.draw "$xshift"
    fi

    ble/canvas/put.draw "$esc"
    ble/canvas/sflush.draw -v esc

    _ble_prompt_status_data[10]=$esc
    _ble_prompt_status_data[11]=$x
    _ble_prompt_status_data[12]=$y
  else
    _ble_prompt_status_data[10]=
    _ble_prompt_status_data[11]=
    _ble_prompt_status_data[12]=
  fi

  return 0
}

#----------------------------------------------------------
# Update prompts for textarea

# process TMOUT
if ble/is-function ble/util/idle.push; then
  _ble_prompt_timeout_task=
  _ble_prompt_timeout_lineno=
  function ble/prompt/timeout/process {
    ble/util/idle.suspend # Suspend task in case exit fails

    ble/edit/marker#instantiate 'auto-logout' non-empty
    local msg="$ret timed out waiting for input"
    # Note (#D2217): In calling ble/builtin/exit, we set
    # "_ble_builtin_exit_processing=1" to skip checking the remaining jobs.
    ble/widget/.internal-print-command '
      ble/util/print "$msg"
      _ble_builtin_exit_processing=1 ble/builtin/exit 0' pre-flush
    return 1 # When exit fails
  } >&"$_ble_util_fd_tui_stdout" 2>&"$_ble_util_fd_tui_stderr"
  function ble/prompt/timeout/check {
    [[ $_ble_edit_lineno == "$_ble_prompt_timeout_lineno" ]] && return 0
    _ble_prompt_timeout_lineno=$_ble_edit_lineno

    if [[ ${TMOUT:-} =~ ^[0-9]+ ]] && ((BASH_REMATCH>0)); then
      if [[ ! $_ble_prompt_timeout_task ]]; then
        ble/util/idle.push -Z 'ble/prompt/timeout/process'
        _ble_prompt_timeout_task=$_ble_util_idle_lasttask
      fi
      ble/util/idle#sleep "$_ble_prompt_timeout_task" "$((BASH_REMATCH*1000))"
    elif [[ $_ble_prompt_timeout_task ]]; then
      ble/util/idle#suspend "$_ble_prompt_timeout_task"
    fi
  }
else
  function ble/prompt/timeout/check { return 0; }
fi

function ble/prompt/update/.has-prompt_command {
  [[ ${_ble_edit_PROMPT_COMMAND[*]} == *[!$_ble_term_IFS]* ]]
}
function ble/prompt/update/.eval-prompt_command {
  ((${#PROMPT_COMMAND[@]})) || return 0
  local _ble_local_command _ble_edit_exec_TRAPDEBUG_adjusted=1
  ble-edit/exec:gexec/.TRAPDEBUG/restore filter
  for _ble_local_command in "${PROMPT_COMMAND[@]}"; do
    [[ $_ble_local_command ]] || continue
    # Note: Evaluate within the function as a countermeasure when something like return is written.
    ble-edit/exec/eval-with-setexit "$_ble_local_command" pipestatus:DEBUG
  done
  _ble_edit_exec_gexec__TRAPDEBUG_adjust
}
## @fn ble/prompt/update opts
##   Build the prompt from _ble_edit_PS1.
##   @param[in] opts
##     A colon-separated list of options.
##
##     leave ... Indicates that this is the last display before going to the next line.
##               When this is specified, processing such as transient prompt will be executed.
##
##   @var[in,out] _ble_prompt_update_dirty
##   @var[in,out] _ble_prompt_rps1_enabled
##
##   @var[in]  _ble_edit_PS1
##     Specifies the content of the prompt that is constructed.
##   @var[out] _ble_prompt_ps1_data
##     Stores information about the constructed prompt.
_ble_prompt_update=
_ble_prompt_update_dirty=
_ble_prompt_rps1_enabled=
function ble/prompt/update {
  local opts=:$1: dirty=

  local count; ble/history/get-count
  local version=$COLUMNS:$_ble_edit_lineno:$count
  if [[ :$opts: == *:check-dirty:* && $_ble_prompt_update == owner ]]; then
    if [[ $_ble_prompt_update_dirty && :$opts: != *:leave:* && $_ble_prompt_hash == "$version" ]]; then
      [[ $_ble_prompt_update_dirty == dirty ]]; local ext=$?
      _ble_prompt_update_dirty=done
      return "$ext"
    fi
  fi

  ble/prompt/timeout/check

  _ble_prompt_rps1_enabled=

  # Update PS1 in PROMPT_COMMAND / PRECMD
  if ((_ble_textarea_panel==0)); then # Do not run PROMPT_COMMAND for auxiliary prompts
    # Note #D1778: history count in version is not used to update PROMPT_COMMAND.
    if [[ ${_ble_prompt_hash%:*} != "${version%:*}" && $opts != *:leave:* ]]; then
      ble-edit/exec:gexec/invoke-hook-with-setexit internal_PRECMD
      if ble/prompt/update/.has-prompt_command || blehook/has-hook PRECMD; then
        # #D1750 When PROMPT_COMMAND and PRECMD output something, the display is distorted.
        # Clear. To avoid blinking, set it to off by default.
        if [[ $bleopt_prompt_command_changes_layout ]]; then
          ble/edit/enter-command-layout # #D1800 pair=leave-command-layout
          local -a DRAW_BUFF=()
          ble/canvas/panel#goto.draw 0 0 0 sgr0
          ble/canvas/bflush.draw
          ble/util/buffer.flush
        fi

        ((_ble_edit_attached)) && ble-edit/restore-PS1
        ble-edit/exec:gexec/invoke-hook-with-setexit PRECMD
        ble/prompt/update/.eval-prompt_command
        ((_ble_edit_attached)) && ble-edit/adjust-PS1

        if [[ $bleopt_prompt_command_changes_layout ]]; then
          ble/edit/leave-command-layout # #D1800 pair=enter-command-layout
        fi
      fi
    fi
  fi

  local prompt_opts=
  local prompt_ps1=$_ble_edit_PS1
  local prompt_rps1=$bleopt_prompt_rps1
  if [[ $opts == *:leave:* ]]; then
    local ps1f=$bleopt_prompt_ps1_final
    local rps1f=$bleopt_prompt_rps1_final
    local ps1t=$bleopt_prompt_ps1_transient
    [[ :$ps1t: == *:trim:* || :$ps1t: == *:same-dir:* && $PWD != $_ble_prompt_trim_opwd ]] && ps1t=
    if [[ $ps1f || $rps1f || $ps1t ]]; then
      prompt_opts=$prompt_opts:leave-rewrite
      [[ $ps1f || $ps1t ]] && prompt_ps1=$ps1f
      [[ $rps1f ]] && prompt_rps1=$rps1f
      ble/textarea#invalidate
    fi
  fi

  if [[ :$prompt_opts: == *:leave-rewrite:* || $_ble_prompt_hash != "$version" ]]; then
    _ble_prompt_hash=$version
    ((_ble_prompt_version++))
  fi

  # initialize variables
  ble/history/update-position
  local prompt_hashref_base='$_ble_prompt_version'
  local prompt_rows=${LINES:-25}
  local prompt_cols=${COLUMNS:-80}
  local "${_ble_prompt_cache_vars[@]/%/=}" # WA #D1570 checked
  # clear the list for cyclic dependency detection
  local ble_prompt_unit_processing=1
  "${_ble_util_set_declare[@]//NAME/ble_prompt_unit_mark}" # disable=#D1570
  local prompt_unit=

  ble/prompt/unit#update _ble_prompt_ps1 && dirty=1

  # Conditions for disabling auxiliary prompts
  # * Invalid except when _ble_textarea_panel==0 #D1027
  # * Also disabled at first prompt
  # * #D1392: Disabled in mc (Midnight Commander)
  if [[ _ble_textarea_panel -ne 0 || $ble_attach_first_prompt || $MC_SID == $$ ]]; then
    [[ $dirty ]]
    return "$?"
  fi

  # bleopt prompt_rps1
  if [[ :$opts: == *:leave:* && ! $rps1f && $bleopt_prompt_rps1_transient ]]; then
    # Cleared by prompt_rps1_transient (retains previous magnitude)
    [[ ${_ble_prompt_rps1_data[10]} ]] && dirty=1 _ble_prompt_rps1_enabled=erase

  else
    [[ $prompt_rps1 || ${_ble_prompt_rps1_data[10]} ]] &&
      ble/prompt/unit#update _ble_prompt_rps1 && dirty=1
    [[ ${_ble_prompt_rps1_data[10]} ]] && _ble_prompt_rps1_enabled=1
  fi

  # bleopt prompt_xterm_title
  case ${_ble_term_TERM:-$TERM:-} in
  (sun*|minix*|eterm*) ;; # black list
  (*)
    [[ $bleopt_prompt_xterm_title || ${_ble_prompt_xterm_title_data[10]} ]] &&
      ble/prompt/unit#update _ble_prompt_xterm_title && dirty=1 ;;
  esac

  # bleopt prompt_screen_title
  case ${_ble_term_TERM:-$TERM:-} in
  (screen:*|tmux:*|contra:*|screen.*|screen-*)
    [[ $bleopt_prompt_screen_title || ${_ble_prompt_screen_title_data[10]} ]] &&
      ble/prompt/unit#update _ble_prompt_screen_title && dirty=1 ;;
  esac

  # bleopt prompt_term_status
  if [[ $_ble_term_tsl && $_ble_term_fsl ]]; then
    [[ $bleopt_prompt_term_status || ${_ble_prompt_term_status_data[10]} ]] &&
      ble/prompt/unit#update _ble_prompt_term_status && dirty=1
  fi

  # bleopt prompt_status_line
  [[ $bleopt_prompt_status_line || ${_ble_prompt_status_data[10]} ]] &&
    ble/prompt/unit#update _ble_prompt_status && dirty=1

  [[ $dirty ]] && _ble_prompt_update_dirty=dirty
  [[ $dirty ]]
}
function ble/prompt/clear {
  _ble_prompt_hash=
  ble/textarea#invalidate
}

#----------------------------------------------------------
# Postexec prompts

_ble_prompt_ruler=('' '' 0)

function ble/prompt/print-ruler.draw {
  [[ $bleopt_prompt_ruler ]] || return 0

  local command=$1 opts=$2 cols=$COLUMNS
  local rex_eval_prefix='(([!{]|time|if|then|elif|while|until|do|exec|eval|command|env|nice|nohup|xargs|sudo)[[:blank:]]+)?'
  local rex_clear_command='(tput[[:blank:]]+)?(clear|reset)'
  local rex=$'(^|[\n;&|(])[[:blank:]]*'$rex_eval_prefix$rex_clear_command'([ \t\n;&|)]|$)'
  [[ $command =~ $rex ]] && return 0

  if [[ :$opts: == *:keep-info:* ]]; then
    ble/canvas/panel#increase-height.draw "$_ble_textarea_panel" 1
    ble/canvas/panel#goto.draw "$_ble_textarea_panel" 0 0
    ((_ble_canvas_panel_height[_ble_textarea_panel]--))
  fi

  if [[ $bleopt_prompt_ruler == empty-line ]]; then
    ble/canvas/put.draw $'\n'
  else
    if [[ $bleopt_prompt_ruler != "${_ble_prompt_ruler[0]}" ]]; then
      if [[ $bleopt_prompt_ruler ]]; then
        local ret= x=0 y=0 g=0 x1=0 x2=0 y1=0 y2=0
        LINES=1 COLUMNS=$cols ble/canvas/trace "$bleopt_prompt_ruler" truncate:measure-bbox
        _ble_prompt_ruler=("$bleopt_prompt_ruler" "$ret" "$x2")
        if ((!_ble_prompt_ruler[2])); then
          _ble_prompt_ruler[1]=${_ble_prompt_ruler[1]}' '
          ((_ble_prompt_ruler[2]++))
        fi
      else
        _ble_prompt_ruler=('' '' 0)
      fi
    fi

    local w=${_ble_prompt_ruler[2]}
    local repeat=$((cols/w))
    ble/string#repeat "${_ble_prompt_ruler[1]}" "$repeat"
    ble/canvas/put.draw "$ret"
    ble/string#repeat ' ' "$((cols-repeat*w))"
    ble/canvas/put.draw "$ret"
    ((_ble_term_xenl)) && ble/canvas/put.draw $'\n'
  fi
}
function ble/prompt/print-ruler.buff {
  local -a DRAW_BUFF=()
  ble/prompt/print-ruler.draw "$@"
  ble/canvas/bflush.draw
}

# 
#------------------------------------------------------------------------------
# **** information pane ****                                         @line.info

## @fn ble/edit/info/.initialize-size
##   @var[out] cols lines
function ble/edit/info/.initialize-size {
  local ret
  ble/canvas/panel/layout/.get-available-height "$_ble_edit_info_panel"
  cols=${COLUMNS-80} lines=$ret
}

_ble_edit_info_panel=2
_ble_edit_info=(0 0 "")
_ble_edit_info_invalidated=

function ble/edit/info#panel::getHeight {
  (($1!=_ble_edit_info_panel)) && return 0
  if ble/edit/is-command-layout || [[ ! ${_ble_edit_info[2]} ]]; then
    height=0:0
  else
    height=1:$((_ble_edit_info[1]+1))
  fi
}
function ble/edit/info#panel::invalidate {
  (($1!=_ble_edit_info_panel)) && return 0
  _ble_edit_info_invalidated=1
}
function ble/edit/info#panel::render {
  (($1!=_ble_edit_info_panel)) && return 0
  ble/edit/is-command-layout && return 0
  [[ $_ble_edit_info_invalidated ]] || return 0

  local x=${_ble_edit_info[0]} y=${_ble_edit_info[1]} content=${_ble_edit_info[2]}
  local -a DRAW_BUFF=()
  if [[ ! $content ]]; then
    ble/canvas/panel#set-height.draw "$_ble_edit_info_panel" 0
  else
    ble/canvas/panel/reallocate-height.draw
    if ((y<_ble_canvas_panel_height[$1])); then
      ble/canvas/panel#clear.draw "$_ble_edit_info_panel"
      ble/canvas/panel#goto.draw "$_ble_edit_info_panel"
      ble/canvas/put.draw "$content"
      ((_ble_canvas_y+=y,_ble_canvas_x=x))
    else
      # If there is not enough display area, erase the content (originally, construct-content
      # It should be set at a height that can be secured. If that doesn't work, use the previous
      # Possible reasons include the size of the terminal changing after construct-content. )
      _ble_edit_info=(0 0 "")
      ble/canvas/panel#set-height.draw "$_ble_edit_info_panel" 0
    fi
  fi
  ble/canvas/bflush.draw
  _ble_edit_info_invalidated=
}
## @fn ble/edit/info#collapse
##   Temporarily hide (corresponds to old ble/edit/info/hide).
function ble/edit/info#collapse {
  local panel=${1-$_ble_prompt_info_panel}
  ((panel!=_ble_edit_info_panel)) && return 0

  local -a DRAW_BUFF=()
  ble/canvas/panel#set-height.draw "$panel" 0
  ble/canvas/bflush.draw
  _ble_edit_info_invalidated=1
}

## @fn ble/edit/info/.construct-content type text
##   @var[out] x y
##   @var[out] content
function ble/edit/info/.construct-content {
  local cols lines
  ble/edit/info/.initialize-size
  x=0 y=0 content=

  local type=$1 text=$2
  case $1 in
  (clear) ;;
  (ansi|esc)
    local trace_opts=truncate
    [[ $bleopt_info_display == bottom ]] && trace_opts=$trace_opts:noscrc
    [[ $1 == esc ]] && trace_opts=$trace_opts:terminfo
    local ret= g=0
    LINES=$lines ble/canvas/trace "$text" "$trace_opts"
    content=$ret ;;
  (text)
    local ret
    ble/canvas/trace-text "$text"
    content=$ret ;;
  (store)
    x=$2 y=$3 content=$4
    # If it does not fit within the current height, measure again.
    ((y<lines)) || ble/edit/info/.construct-content esc "$content" ;;
  (*)
    ble/util/print "usage: ble/edit/info/.construct-content type text" >&2 ;;
  esac
}

function ble/edit/info/.rendering-enabled {
  # Note: We basically want to render the info panel after attaching.  However,
  # even if ble.sh has not yet attached, we allow rendering the info panel
  # through ble/edit/info/immediate-show while initialization.  To avoid
  # outputting messages in non-interactive sessions, we check whether
  # $_ble_util_fd_tui_stderr is connected to a TTY.
  [[ $_ble_attached || -t $_ble_util_fd_tui_stderr ]] || return 1

  [[ $_ble_app_render_mode == panel ]]
}

## @fn ble/edit/info/.render-content x y content [opts]
##   @param[in] x y content
function ble/edit/info/.render-content {
  local x=$1 y=$2 content=$3 opts=$4

  # Set invalidate only when new content is set.
  if [[ $content != "${_ble_edit_info[2]}" ]]; then
    _ble_edit_info=("$x" "$y" "$content")
    _ble_edit_info_invalidated=1
  fi

  [[ :$opts: == *:defer:* ]] && return 0
  ble/edit/info/.rendering-enabled || return 0
  ble/edit/info#panel::render "$_ble_edit_info_panel"
}

_ble_edit_info_default=(0 0 "")
_ble_edit_info_scene=default

## @fn ble/edit/info/show type text
##
##   @param[in] type
##
##     Specify one of the following.
##
##     text, ansi, esc, store
##
##   @param[in] text
##
##     When type=text, the argument text contains the string to display.
##     Control characters such as line breaks are replaced with alternative representations.
##     When type=ansi, the argument text specifies a string containing ANSI control sequences.
##     When type=esc, the text argument specifies a string containing the current terminal control sequence.
##
##     About these strings
##     Strings that extend beyond the screen are automatically truncated.
##
function ble/edit/info/show {
  local type=$1 text=$2
  if [[ $text ]]; then
    local x y content=
    ble/edit/info/.construct-content "$@"
    ble/edit/info/.render-content "$x" "$y" "$content"
    ble/util/buffer.flush
    _ble_edit_info_scene=show
  else
    ble/edit/info/default
  fi
}
function ble/edit/info/set-default {
  local type=$1 text=$2
  local x y content
  ble/edit/info/.construct-content "$type" "$text"
  _ble_edit_info_default=("$x" "$y" "$content")
  [[ $_ble_edit_info_scene == default ]] &&
    ble/edit/info/.render-content "${_ble_edit_info_default[@]}" defer
}
function ble/edit/info/default {
  _ble_edit_info_scene=default
  if (($#)); then
    ble/edit/info/set-default "$@"
  else
    ble/edit/info/.render-content "${_ble_edit_info_default[@]}" defer
  fi
  return 0
}

function ble/edit/info/clear {
  _ble_edit_info_scene=clear
  ble/edit/info/.render-content 0 0 ""
}

function ble/edit/info/immediate-clear {
  if ble/edit/info/.rendering-enabled; then
    local ret; ble/canvas/panel/save-position; local pos=$ret
    ble/edit/info/clear
    ble/canvas/panel/load-position "$pos"
    ble/util/buffer.flush
  else
    ble/edit/info/clear
  fi
}
function ble/edit/info/immediate-show {
  if ble/edit/info/.rendering-enabled; then
    local ret; ble/canvas/panel/save-position; local pos=$ret
    ble/edit/info/show "$@"
    ble/canvas/panel/load-position "$pos"
    ble/util/buffer.flush
  else
    ble/edit/info/show "$@"
  fi
}
function ble/edit/info/immediate-default {
  if ble/edit/info/.rendering-enabled; then
    local ret; ble/canvas/panel/save-position; local pos=$ret
    ble/edit/info/default
    ble/edit/info/.render-content "${_ble_edit_info_default[@]}"
    ble/canvas/panel/load-position "$pos"
    ble/util/buffer.flush
  else
    ble/edit/info/default
  fi
}

# 
#------------------------------------------------------------------------------
# **** edit ****                                                  @edit.content

_ble_edit_VARNAMES=(
  _ble_edit_str
  _ble_edit_ind
  _ble_edit_mark
  _ble_edit_mark_active
  _ble_edit_overwrite_mode
  _ble_edit_line_disabled
  _ble_edit_arg
  _ble_edit_dirty_draw_beg
  _ble_edit_dirty_draw_end
  _ble_edit_dirty_draw_end0
  _ble_edit_dirty_syntax_beg
  _ble_edit_dirty_syntax_end
  _ble_edit_dirty_syntax_end0
  _ble_edit_dirty_observer
  _ble_edit_kill_index
  _ble_edit_kill_ring
  _ble_edit_kill_type)

# The current editing state is expressed by the following variables.
_ble_edit_str=
_ble_edit_ind=0
_ble_edit_mark=0
_ble_edit_mark_active=
_ble_edit_overwrite_mode=
_ble_edit_line_disabled=
_ble_edit_arg=

# The following can be shared as a whole if multiple edited strings match.
_ble_edit_kill_index=0
_ble_edit_kill_ring=()
_ble_edit_kill_type=()

# _ble_edit_str is changed through the following function.
# To track the scope of changes.
function ble-edit/content/replace {
  local beg=$1 end=$2
  local ins=$3 reason=${4:-edit}

  # cf. Note#1
  _ble_edit_str="${_ble_edit_str::beg}""$ins""${_ble_edit_str:end}"
  ble-edit/content/.update-dirty-range "$beg" "$((beg+${#ins}))" "$end" "$reason"
#%if !release
  # Note: Due to some bug, a strange value is entered in _ble_edit_ind and an error occurs, so
  #   Correct the error here. Assuming that the value of _ble_edit_ind when this function is called is
  #   Use the value before executing replace. In the caller of this function,
  #   It is necessary to update _ble_edit_ind after calling this function.
  # Note: This bug is probably resolved with #D0411, but we will wait and see.
  ble/util/assert \
    '((0<=_ble_edit_dirty_syntax_beg&&_ble_edit_dirty_syntax_end<=${#_ble_edit_str}))' \
    "0 <= beg=$_ble_edit_dirty_syntax_beg <= end=$_ble_edit_dirty_syntax_end <= len=${#_ble_edit_str}; beg=$beg, end=$end, ins(${#ins})=$ins" ||
    {
      _ble_edit_dirty_syntax_beg=0
      _ble_edit_dirty_syntax_end=${#_ble_edit_str}
      _ble_edit_dirty_syntax_end0=0
      local olen=$((${#_ble_edit_str}-${#ins}+end-beg))
      ((olen<0&&(olen=0),
        _ble_edit_ind>olen&&(_ble_edit_ind=olen),
        _ble_edit_mark>olen&&(_ble_edit_mark=olen)))
    }
#%end
}
function ble-edit/content/reset {
  local str=$1 reason=${2:-edit}
  local beg=0 end=${#str} end0=${#_ble_edit_str}
  _ble_edit_str=$str
  ble-edit/content/.update-dirty-range "$beg" "$end" "$end0" "$reason"
#%if !release
  ble/util/assert \
    '((0<=_ble_edit_dirty_syntax_beg&&_ble_edit_dirty_syntax_end<=${#_ble_edit_str}))' \
    "0 <= beg=$_ble_edit_dirty_syntax_beg <= end=$_ble_edit_dirty_syntax_end <= len=${#_ble_edit_str}; str(${#str})=$str" ||
    {
      _ble_edit_dirty_syntax_beg=0
      _ble_edit_dirty_syntax_end=${#_ble_edit_str}
      _ble_edit_dirty_syntax_end0=0
    }
#%end
}
function ble-edit/content/reset-and-check-dirty {
  local str=$1 reason=${2:-edit}
  [[ $_ble_edit_str == "$str" ]] && return 0

  local ret pref suff
  ble/string#common-prefix "$_ble_edit_str" "$str"; pref=$ret
  local dmin=${#pref}
  ble/string#common-suffix "${_ble_edit_str:dmin}" "${str:dmin}"; suff=$ret
  local dmax0=$((${#_ble_edit_str}-${#suff})) dmax=$((${#str}-${#suff}))

  _ble_edit_str=$str
  ble-edit/content/.update-dirty-range "$dmin" "$dmax" "$dmax0" "$reason"
}
## @fn ble-edit/content/replace-limited beg end insert opts
##   Insert with the limit of bleopt_line_limit_type.
##   The actual inserted string is stored in insert.
##
##   @param[in] beg end insert
##   @param[in] opts
##     nobell ... Do not ring the bell when nothing is inserted or deleted.
##
##   @var[out] insert
##
function ble-edit/content/replace-limited {
  insert=$3
  if [[ $bleopt_line_limit_type == discard ]]; then
    local ibeg=$1 iend=$2 opts=:$4:
    local limit=$((bleopt_line_limit_length))
    if ((limit)); then
      local inslimit=$((limit-${#_ble_edit_str}+(iend-ibeg)))
      ((inslimit<iend-ibeg&&(inslimit=iend-ibeg)))
      ((${#insert}>inslimit)) && insert=${insert::inslimit}
      if [[ ! $insert ]] && ((ibeg==iend)); then
        [[ $opts == *:nobell:* ]] ||
          ble/widget/.bell "ble: reached line_limit_length=$limit"
        return 1
      fi
    fi
  fi
  ble-edit/content/replace "$1" "$2" "$insert"
}
function ble-edit/content/check-limit {
  local opts=:${1:-truncate:editor}:
  if [[ $opts == *:${bleopt_line_limit_type:-none}:* ]]; then
    local limit=$((bleopt_line_limit_length))
    if ((limit>0&&${#_ble_edit_str}>limit)); then
      local ble_edit_line_limit=$limit
      ble-decode-key "$_ble_decode_KCODE_LINE_LIMIT"
    fi
  fi
}
function ble/widget/__line_limit__ {
  local editor=ble/widget/${1:-edit-and-execute-command.impl}
  local limit=$ble_edit_line_limit
  case ${bleopt_line_limit_type:-none} in
  (editor)
    local content=$_ble_edit_str
    ble-edit/content/reset "# reached line_limit_length=$limit"
    _ble_edit_ind=0 _ble_edit_mark=0
    "$editor" "$content"
    (($?==127)) &&
      ble-edit/content/reset "${content::limit}"
    return 1 ;;
  (truncate|*)
    ble-edit/content/replace "$limit" "${#_ble_edit_str}" ''
    ((_ble_edit_ind>limit&&(_ble_edit_ind=limit)))
    ((_ble_edit_mark>limit&&(_ble_edit_mark=limit)))
    return 1 ;;
  esac
  return 0
}

_ble_edit_dirty_draw_beg=-1
_ble_edit_dirty_draw_end=-1
_ble_edit_dirty_draw_end0=-1

_ble_edit_dirty_syntax_beg=0
_ble_edit_dirty_syntax_end=0
_ble_edit_dirty_syntax_end0=1

_ble_edit_dirty_observer=()
## @fn ble-edit/content/.update-dirty-range beg end end0 [reason]
##  @param[in] beg end end0
##    Specify the change range.
##  @param[in] reason
## Specify a string that represents the reason for the change.
function ble-edit/content/.update-dirty-range {
  ble/dirty-range#update --prefix=_ble_edit_dirty_draw_ "${@:1:3}"
  ble/dirty-range#update --prefix=_ble_edit_dirty_syntax_ "${@:1:3}"
  ble/textmap#update-dirty-range "${@:1:3}"

  local obs
  for obs in "${_ble_edit_dirty_observer[@]}"; do "$obs" "$@"; done
}

function ble-edit/content/update-syntax {
  if ble/util/import/is-loaded "$_ble_base/lib/core-syntax.sh"; then
    local beg end end0
    ble/dirty-range#load --prefix=_ble_edit_dirty_syntax_
    if ((beg>=0)); then
      ble/dirty-range#clear --prefix=_ble_edit_dirty_syntax_
      ble/syntax/parse "$_ble_edit_str" '' "$beg" "$end" "$end0"
    fi
  fi
}

## @fn ble-edit/content/bolp
##   Determines whether the cursor is currently at the end of the line.
function ble-edit/content/eolp {
  local pos=${1:-$_ble_edit_ind}
  ((pos==${#_ble_edit_str})) || [[ ${_ble_edit_str:pos:1} == $'\n' ]]
}
## @fn ble-edit/content/bolp
##   Determines whether the cursor is currently at the beginning of the line.
function ble-edit/content/bolp {
  local pos=${1:-$_ble_edit_ind}
  ((pos<=0)) || [[ ${_ble_edit_str:pos-1:1} == $'\n' ]]
}
## @fn ble-edit/content/find-logical-eol [index [offset]]
##   Returns the ending position of the next line offset lines from position index in _ble_edit_str.
##
##   @var[out] ret
##     If offset is 0, returns the end of the line containing position index.
##     Returns ${#_ble_edit_str} if offset is positive and there is no row following offset.
##
function ble-edit/content/find-logical-eol {
  local index=${1:-$_ble_edit_ind} offset=${2:-0}
  if ((offset>0)); then
    local text=${_ble_edit_str:index}
    local rex=$'^([^\n]*\n){0,'$((offset-1))$'}([^\n]*\n)?[^\n]*'
    [[ $text =~ $rex ]]
    ((ret=index+${#BASH_REMATCH}))
    [[ ${BASH_REMATCH[2]} ]]
  elif ((offset<0)); then
    local text=${_ble_edit_str::index}
    local rex=$'(\n[^\n]*){0,'$((-offset-1))$'}(\n[^\n]*)?$'
    [[ $text =~ $rex ]]
    if [[ $BASH_REMATCH ]]; then
      ((ret=index-${#BASH_REMATCH}))
      [[ ${BASH_REMATCH[2]} ]]
    else
      ble-edit/content/find-logical-eol "$index" 0
      return 1
    fi
  else
    local text=${_ble_edit_str:index}
    text=${text%%$'\n'*}
    ((ret=index+${#text}))
    return 0
  fi
}
## @fn ble-edit/content/find-logical-bol [index [offset]]
##   Returns the first position of the next line offset lines from position index in _ble_edit_str.
##
##   @var[out] ret
##     If offset is 0, returns the beginning of the line containing position index.
##     If offset is positive and there is no next line by offset, returns the beginning of the last line.
##     In particular, returns the beginning of the current line if there is no next line.
##
function ble-edit/content/find-logical-bol {
  local index=${1:-$_ble_edit_ind} offset=${2:-0}
  if ((offset>0)); then
    local rex=$'^([^\n]*\n){0,'$((offset-1))$'}([^\n]*\n)?'
    [[ ${_ble_edit_str:index} =~ $rex ]]
    if [[ $BASH_REMATCH ]]; then
      ((ret=index+${#BASH_REMATCH}))
      [[ ${BASH_REMATCH[2]} ]]
    else
      ble-edit/content/find-logical-bol "$index" 0
      return 1
    fi
  elif ((offset<0)); then
    ble-edit/content/find-logical-eol "$index" "$offset"; local ext=$?
    ble-edit/content/find-logical-bol "$ret" 0
    return "$ext"
  else
    local text=${_ble_edit_str::index}
    text=${text##*$'\n'}
    ((ret=index-${#text}))
    return 0
  fi
}
## @fn ble-edit/content/find-non-space index
##   Finds the first non-blank character after the specified position.
##   @param[in] index
##   @var[out] ret
function ble-edit/content/find-non-space {
  local bol=$1
  local rex=$'^[ \t]*'; [[ ${_ble_edit_str:bol} =~ $rex ]]
  ret=$((bol+${#BASH_REMATCH}))
}


## @fn ble-edit/content/is-single-line
function ble-edit/content/is-single-line {
  [[ $_ble_edit_str != *$'\n'* ]]
}

## @var _ble_edit_arg
##   Retains input arguments. Indicates one of the following conditions.
##   /^$/
##     Indicates that no argument has been input.
##   /^\+$/
##     universal-argument (M-C-u) Indicates that it has just started.
##     Then type - or interpret the number as an argument.
##   /^([0-9]+|-[0-9]*)$/
##     Indicates that the argument is being input.
##     Interprets the next number you enter as an argument.
##   /^\+([0-9]+|-[0-9]*)$/
##     Indicates that argument input has been completed.
##     The next number is not interpreted as an argument.

## @fn ble-edit/content/get-arg
##   @var[out] arg
function ble-edit/content/get-arg {
  local default_value=$1
  local value=$_ble_edit_arg
  _ble_edit_arg=

  if [[ $value == +* ]]; then
    if [[ $value == + ]]; then
      arg=4
      return 0
    fi
    value=${value#+}
  fi

  if [[ $value == -* ]]; then
    if [[ $value == - ]]; then
      arg=-1
    else
      arg=$((-10#0${value#-}))
    fi
  else
    if [[ $value ]]; then
      arg=$((10#0$value))
    else
      arg=$default_value
    fi
  fi
}
function ble-edit/content/clear-arg {
  _ble_edit_arg=
}
function ble-edit/content/toggle-arg {
  if [[ $_ble_edit_arg == + ]]; then
    _ble_edit_arg=
  elif [[ $_ble_edit_arg && $_ble_edit_arg != +* ]]; then
    _ble_edit_arg=+$_ble_edit_arg
  else
    _ble_edit_arg=+
  fi
}

function ble/keymap:generic/get-arg {
  if [[ $_ble_decode_keymap == vi_[noxs]map ]]; then
    local ARG FLAG REG
    ble/keymap:vi/get-arg "$1"
    arg=$ARG
  else
    ble-edit/content/get-arg "$1"
  fi
}
function ble/keymap:generic/clear-arg {
  if [[ $_ble_decode_keymap == vi_[noxs]map ]]; then
    ble/keymap:vi/clear-arg
  else
    ble-edit/content/clear-arg
  fi
}

## @fn ble/widget/append-arg [opts]
## @fn ble/widget/append-arg-or widget [opts]
##   @param[in] widget
##   @param[in,opt] opts
##     enter-menu
##       When a completion menu is displayed, enter the menu and then make a menu selection.
##       Even unqualified numbers are always treated as arguments.
##     nobell
##       Don't ring a bell when there is no corresponding item after entering the completion menu.
##
function ble/widget/append-arg-or {
  # Enter menu with argument immediately after ble/widget/complete (when menu is displayed)
  ble/function#try ble/widget/complete/.select-menu-with-arg "${2-}" && return 0

  local n=${#KEYS[@]}; ((n&&n--))
  local code=$((KEYS[n]&_ble_decode_MaskChar))
  ((code==0)) && return 1
  local ret; ble/util/c2s "$code"; local ch=$ret
  if
    if [[ $_ble_edit_arg == + ]]; then
      [[ $ch == [-0-9] ]] && _ble_edit_arg=
    elif [[ $_ble_edit_arg == +* ]]; then
      builtin false
    elif [[ $_ble_edit_arg ]]; then
      [[ $ch == [0-9] ]]
    else
      ((KEYS[n]&_ble_decode_MaskFlag))
    fi
  then
    ble/decode/widget/skip-lastwidget
    _ble_edit_arg=$_ble_edit_arg$ch
  else
    ble/widget/"$1"
  fi
}
function ble/widget/append-arg {
  ble/widget/append-arg-or self-insert "$@"
}
function ble/widget/universal-arg {
  ble/decode/widget/skip-lastwidget
  ble-edit/content/toggle-arg
}

## @fn ble-edit/content/prepend-kill-ring string kill_type
function ble-edit/content/prepend-kill-ring {
  _ble_edit_kill_index=0
  local otext=${_ble_edit_kill_ring[0]-} ntext=$1
  local otype=${_ble_edit_kill_type[0]-} ntype=$2
  if [[ $otype == L || $ntype == L ]]; then
    ntext=${ntext%$'\n'}$'\n'
    otext=${otext%$'\n'}$'\n'
    _ble_edit_kill_ring[0]=$ntext$otext
    _ble_edit_kill_type[0]=L
  elif [[ $otype == B:* ]]; then
    if [[ $ntype != B:* ]]; then
      ntext=${ntext%$'\n'}$'\n'
      local ret; ble/string#count-char "$ntext" $'\n'
      ble/string#repeat '0 ' "$ret"
      ntype=B:${ret%' '}
    fi
    _ble_edit_kill_ring[0]=$ntext$otext
    _ble_edit_kill_type[0]="B:${ntype#B:} ${otype#B:}"
  else
    _ble_edit_kill_ring[0]=$ntext$otext
    _ble_edit_kill_type[0]=$otype
  fi
}
## @fn ble-edit/content/append-kill-ring string kill_type
function ble-edit/content/append-kill-ring {
  _ble_edit_kill_index=0
  local otext=${_ble_edit_kill_ring[0]-} ntext=$1
  local otype=${_ble_edit_kill_type[0]-} ntype=$2
  if [[ $otype == L || $ntype == L ]]; then
    ntext=${ntext%$'\n'}$'\n'
    otext=${otext%$'\n'}$'\n'
    _ble_edit_kill_ring[0]=$otext$ntext
    _ble_edit_kill_type[0]=L
  elif [[ $otype == B:* ]]; then
    if [[ $ntype != B:* ]]; then
      ntext=${ntext%$'\n'}$'\n'
      local ret; ble/string#count-char "$ntext" $'\n'
      ble/string#repeat '0 ' "$ret"
      ntype=B:${ret%' '}
    fi
    _ble_edit_kill_ring[0]=$otext$ntext
    _ble_edit_kill_type[0]="B:${otype#B:} ${ntype#B:}"
  else
    _ble_edit_kill_ring[0]=$otext$ntext
    _ble_edit_kill_type[0]=$otype
  fi
}

## @fn ble-edit/content/push-kill-ring string kill_type [direction]
##   @param[in] string kill_type
##
##   @param[in,opt] direction
##     If STRING is a part of the current command-line string, the
##     directionality can be specified to determine whether STRING should be
##     appended or prepended to the kill ring.  The values "forward" or
##     "backward" mean that STRING is located in the forward/backward
##     directions from the current cursor position.  The value has the form
##     <int>:<int>, it is interpreted as the range of STRING in the current
##     command line.
##
function ble-edit/content/push-kill-ring {
  if ((${#_ble_edit_kill_ring[@]})) && [[ ${LASTWIDGET#ble/widget/} == kill-* || ${LASTWIDGET#ble/widget/} == copy-* ]]; then
    local proc=
    local name; ble/string#split-words name "${WIDGET#ble/widget/}"
    if [[ $3 == backward || $name == kill-backward-* || $name == copy-backward-* ]]; then
      proc=ble-edit/content/prepend-kill-ring
    elif [[ $3 == forward || $name == kill-forward-* || $name == copy-forward-* ]]; then
      proc=ble-edit/content/append-kill-ring
    elif [[ $name == kill-region* || $name == copy-region* ]]; then
      proc=
    elif [[ $3 == [0-9]*:[0-9]* ]] && ((${3##*:}<=_ble_edit_ind)); then
      proc=ble-edit/content/prepend-kill-ring
    else
      proc=ble-edit/content/append-kill-ring
    fi

    if [[ $proc ]]; then
      "$proc" "$1" "$2"
      return "$?"
    fi
  fi

  _ble_edit_kill_index=0
  ble/array#unshift _ble_edit_kill_ring "$1"
  ble/array#unshift _ble_edit_kill_type "$2"
}


# 
#------------------------------------------------------------------------------
# **** saved variables such as (PS1/LINENO) ****                      @edit.ps1
#
# Internal use variables
## @var _ble_edit_LINENO
##   Holds the value of LINENO.
##   This is the total number of lines processed/cancelled on the command line.
## @var _ble_edit_CMD
##   The variable referred to as \# in the prompt.
##   Keeps the actual number of command executions.
##   Increased after PS0 evaluation.
## @var _ble_edit_PS1
## @var _ble_edit_IFS
## @var _ble_edit_IGNOREEOF_adjusted
## @var _ble_edit_IGNOREEOF
## @arr _ble_edit_READLINE

_ble_edit_PS1_adjusted=
_ble_edit_PS1='\s-\v\$ '
_ble_edit_PROMPT_COMMAND=
function ble-edit/adjust-PS1 {
  [[ $_ble_edit_PS1_adjusted ]] && return 0
  _ble_edit_PS1_adjusted=1
  _ble_edit_PS1=$PS1
  if [[ $bleopt_internal_suppress_bash_output ]]; then
    # Note #D1772: Prompt displayed if ble.sh crashes while processing. In the current situation
    # I don't think something like this has ever happened, and I can confirm that it would work if it actually happened.
    # I haven't set it yet, but I'll set it just in case.
    PS1='[ble: press RET to continue]'
  else
    # If suppress_bash_output is not executed, the bash prompt will be displayed.
    # Leave PS1 empty to avoid this.
    PS1=
  fi

  if ble/is-array PROMPT_COMMAND; then
    ble/idict#copy _ble_edit_PROMPT_COMMAND PROMPT_COMMAND
  else
    ble/variable#copy-state PROMPT_COMMAND _ble_edit_PROMPT_COMMAND
  fi
  builtin unset -v PROMPT_COMMAND
}
function ble-edit/restore-PS1 {
  [[ $_ble_edit_PS1_adjusted ]] || return 1
  _ble_edit_PS1_adjusted=
  PS1=$_ble_edit_PS1
  if ble/is-array _ble_edit_PROMPT_COMMAND; then
    ble/idict#copy PROMPT_COMMAND _ble_edit_PROMPT_COMMAND
  else
    ble/variable#copy-state _ble_edit_PROMPT_COMMAND PROMPT_COMMAND
  fi
}

_ble_edit_IGNOREEOF_adjusted=
_ble_edit_IGNOREEOF=
function ble-edit/adjust-IGNOREEOF {
  [[ $_ble_edit_IGNOREEOF_adjusted ]] && return 0
  _ble_edit_IGNOREEOF_adjusted=1

  if [[ ${IGNOREEOF+set} ]]; then
    _ble_edit_IGNOREEOF=$IGNOREEOF
  else
    builtin unset -v _ble_edit_IGNOREEOF
  fi
  if ((_ble_bash>=40000)); then
    builtin unset -v IGNOREEOF
  else
    IGNOREEOF=9999
  fi
}
function ble-edit/restore-IGNOREEOF {
  [[ $_ble_edit_IGNOREEOF_adjusted ]] || return 1
  _ble_edit_IGNOREEOF_adjusted=

  if [[ ${_ble_edit_IGNOREEOF+set} ]]; then
    IGNOREEOF=$_ble_edit_IGNOREEOF
  else
    builtin unset -v IGNOREEOF
  fi
}

_ble_edit_READLINE=()
function ble-edit/adjust-READLINE {
  [[ $_ble_edit_READLINE ]] && return 0
  _ble_edit_READLINE=1
  ble/variable#copy-state READLINE_LINE  '_ble_edit_READLINE[1]'
  ble/variable#copy-state READLINE_POINT '_ble_edit_READLINE[2]'
  ble/variable#copy-state READLINE_MARK  '_ble_edit_READLINE[3]'
}
function ble-edit/restore-READLINE {
  [[ $_ble_edit_READLINE ]] || return 0
  _ble_edit_READLINE=
  ble/variable#copy-state '_ble_edit_READLINE[1]' READLINE_LINE
  ble/variable#copy-state '_ble_edit_READLINE[2]' READLINE_POINT
  ble/variable#copy-state '_ble_edit_READLINE[3]' READLINE_MARK
}

## @fn ble-edit/eval-IGNOREEOF
##   @var[out] ret
function ble-edit/eval-IGNOREEOF {
  local value=
  if [[ $_ble_edit_IGNOREEOF_adjusted ]]; then
    value=${_ble_edit_IGNOREEOF-0}
  else
    value=${IGNOREEOF-0}
  fi

  if [[ $value && ! ${value//[0-9]} ]]; then
    # Positive integers are interpreted as decimal numbers
    ret=$((10#0$value))
  else
    # Negative integers, empty strings, etc.
    ret=10
  fi
}

function ble/variable#load-user-state/variable:PS1 {
  __ble_var_set=${_ble_edit_PS1+set}
  __ble_var_val=("${_ble_edit_exec_PS1[@]}")
  ble/variable#get-attr -v __ble_var_att PS1
}
function ble/variable#load-user-state/variable:PROMPT_COMMAND {
  if ble/is-array _ble_edit_PROMPT_COMMAND; then
    __ble_var_set=set
    ble/idict#copy __ble_var_val _ble_edit_PROMPT_COMMAND
  else
    __ble_var_set=${_ble_edit_PROMPT_COMMAND+set}
    ble/variable#copy-state _ble_edit_PROMPT_COMMAND __ble_var_val
  fi
  ble/variable#get-attr -v __ble_var_att _ble_edit_PROMPT_COMMAND
}
function ble/variable#load-user-state/variable:IGNOREEOF {
  __ble_var_set=${_ble_edit_IGNOREEOF+set}
  __ble_var_val=${_ble_edit_IGNOREEOF-}
  ble/variable#get-attr -v __ble_var_att _ble_edit_exec_IGNOREEOF
}

bleopt/declare -n canvas_winch_action redraw-here

function ble-edit/attach/TRAPWINCH {
  # It doesn't matter if it's not currently in the forefront.
  ((_ble_edit_attached)) && [[ $_ble_term_state == internal ]] &&
    ! ble/edit/is-command-layout && ! ble/util/is-running-in-subshell ||
      return 0
  ble/application/onwinch 2>&"$_ble_util_fd_tui_stderr"
}

## called by ble-edit/attach
_ble_edit_attached=0
function ble-edit/attach/.attach {
  ((_ble_edit_attached)) && return 0
  _ble_edit_attached=1

  if [[ ! ${_ble_edit_LINENO+set} ]]; then
    _ble_edit_LINENO=${BASH_LINENO[${#BASH_LINENO[@]}-1]}
    ((_ble_edit_LINENO<0)) && _ble_edit_LINENO=0

    # When _ble_edit_CMD is empty or less than _ble_edit_LINENO, we update it.
    ((_ble_edit_CMD<=_ble_edit_LINENO+1)) && ((_ble_edit_CMD=_ble_edit_LINENO+1))
  fi

  ble/builtin/trap/install-hook WINCH readline
  blehook internal_WINCH!=ble-edit/attach/TRAPWINCH

  ble-edit/adjust-PS1
  ble-edit/adjust-READLINE
  ble-edit/adjust-IGNOREEOF
  [[ $bleopt_internal_exec_type == exec ]] && _ble_edit_IFS=$IFS
}

function ble-edit/attach/.detach {
  ((!_ble_edit_attached)) && return 0
  ble-edit/restore-PS1
  ble-edit/restore-READLINE
  ble-edit/restore-IGNOREEOF
  [[ $bleopt_internal_exec_type == exec ]] && IFS=$_ble_edit_IFS
  _ble_edit_attached=0
}


# 
#------------------------------------------------------------------------------
# **** textarea ****                                                  @textarea

_ble_textarea_VARNAMES=(
  _ble_textarea_buffer
  _ble_textarea_bufferName

  _ble_textarea_cur
  _ble_textarea_panel
  _ble_textarea_scroll
  _ble_textarea_scroll_new
  _ble_textarea_gendx
  _ble_textarea_gendy

  _ble_textarea_invalidated
  _ble_textarea_version
  _ble_textarea_caret_state
  _ble_textarea_cache
  _ble_textarea_render_defer)

_ble_textarea_local_VARNAMES=()

## @fn ble/textarea#panel::getHeight
##   @var[out] height
function ble/textarea#panel::getHeight {
  if [[ $1 == "$_ble_textarea_panel" ]]; then
    local min=$((_ble_prompt_ps1_data[4]+1)) max=$((_ble_textmap_endy+1))
    ((min<max&&min++))
    height=$min:$max
  else
    height=0:${_ble_canvas_panel_height[$1]}
  fi
}
function ble/textarea#panel::onHeightChange {
  [[ $1 == "$_ble_textarea_panel" ]] || return 1

  if [[ ! $ble_textarea_render_flag ]]; then
    ble/textarea#invalidate
  fi
}
function ble/textarea#panel::invalidate {
  if (($1==_ble_textarea_panel)); then
    ble/textarea#invalidate
  fi
}
function ble/textarea#panel::render {
  if (($1==_ble_textarea_panel)); then
    ble/textarea#render
  fi
}
## @fn ble/textarea#panel::moveReflowInf ipanel x y
##   (x,y) The previous contents of this panel are the lowest after text reflowing due to terminal resizing.
##   However, it returns the number of characters to be used exclusively.
##
##   @param[in] x y
##     Specifies the relative position of the cursor position from the top left of the panel (before changing the terminal size).
##
##   @arr[in] _ble_app_winsize
##     The width and height of the terminal before changing the terminal size (more precisely, at the time of the last application/render)
##     hold.
##   @var[in] LINES COLUMNS
##     Retains the width and height of the terminal after resizing it.
##   @var[ref] nchar
##     Specifies the minimum position (after terminal resizing) of this panel's upper left border. (terminal
##     When the cursor position (before resizing) was within this panel, after resizing the terminal
##     Returns the minimum position of the cursor. Otherwise, the terminal size of the lower right border of the panel.
##     Returns the modified minimum position.
##
function ble/textarea#panel::moveReflowInf {
  local ipanel=$1 x=$2 y=$3

  # When the right prompt is displayed, it is supposed to be aligned to the right, so it is reflow unsafe.
  [[ $_ble_prompt_rps1_shown ]] && return 1

  # Reflow may also occur when prompt PS1 is touching the right edge of the terminal.
  # Since it is reflow unsafe, you can exit with return 1.
  ((_ble_prompt_ps1_bbox[2]>=_ble_app_winsize[0])) && return 1

  local height=${_ble_canvas_panel_height[ipanel]}
  local proy=${_ble_prompt_ps1_data[4]}

  # Note: In the current implementation, the part after the prompt where you are actually entering the command is
  # It is safe to assume that we do not know whether there is a line break or whether automatic wrapping is occurring.
  # It is assumed that it will be tilted to the side and reflow. Even if there is actually a line break, the editing process
  # If wrapping occurs even once, the possibility of terminal reflow occurring can be eliminated.
  # Also, reflow occurs when filling in blanks due to lack of ECH etc.
  # There is a possibility. For other reasons, I don't know.

  local newline= reflow= offset=
  if ((y<=proy)); then
    # If the last line of the prompt or inside the prompt (the cursor is inside the prompt)
    # It is a mystery whether it is possible for this to happen, but if you are in
    # It is assumed that their relative positions are maintained.
    ((newline=y,reflow=0,offset=x))
  elif ((y<height)); then
    # It is a mystery whether it is possible for the cursor to be inside the prompt, but if it is inside
    # Assuming that no reflow occurs, it is assumed that the relative position from the top left will be maintained.
    ((newline=proy,reflow=y-proy,offset=x))
  else
    # If the cursor is not in this panel, the proy line in this panel will simply have a line break.
    # I think that after that it can be broken by reflow.
    ((newline=proy,reflow=height-proy,offset=0))
  fi
  ((newline)) && ((nchar=(nchar/COLUMNS+newline)*COLUMNS))
  ((nchar+=reflow*(_ble_app_winsize[0]-1)+offset))

  return 0
}

# **** textarea.buffer ****                                    @textarea.buffer

_ble_textarea_buffer=()
_ble_textarea_bufferName=

## @fn lc lg; ble/textarea#update-text-buffer; cx cy lc lg
##
##   @param[in ] text edit string
##   @var  [in,out] umin umax
##     umin,umax returns the character index of the range that needs to be redrawn.
##
##   @var[in] _ble_textmap_*
##     Requests that placement information is up-to-date.
##
function ble/textarea#update-text-buffer {
  local iN=${#text}

  local beg end end0
  ble/dirty-range#load --prefix=_ble_edit_dirty_draw_
  ble/dirty-range#clear --prefix=_ble_edit_dirty_draw_

  # highlight -> HIGHLIGHT_BUFF
  local HIGHLIGHT_BUFF HIGHLIGHT_UMIN HIGHLIGHT_UMAX
  ble/highlight/layer/update "$text" '' "$beg" "$end" "$end0"
  ble/urange#update "$HIGHLIGHT_UMIN" "$HIGHLIGHT_UMAX"

  # Applying change characters
  if ((${#_ble_textmap_ichg[@]})); then
    local ichg g ret
    builtin eval "_ble_textarea_buffer=(\"\${$HIGHLIGHT_BUFF[@]}\")"
    HIGHLIGHT_BUFF=_ble_textarea_buffer
    for ichg in "${_ble_textmap_ichg[@]}"; do
      ble/highlight/layer/getg "$ichg"
      ble/color/g2sgr "$g"
      _ble_textarea_buffer[ichg]=$ret${_ble_textmap_glyph[ichg]}
    done
  fi

  _ble_textarea_bufferName=$HIGHLIGHT_BUFF
}
## @fn ble/textarea#update-left-char index
##   update lc, lg.
##
##   @param[in] index
##     cursor index
##   @param[out] lc lg
##     Returns the code and gflag of the character to the left of the cursor.
##     If the cursor is at the beginning, write to the left of the start position of the edit string (the last character of the prompt).
##
##   lc, lg are the characters output by bash when bleopt_internal_suppress_bash_output=
##   represents its attributes. If READLINE_LINE is empty, you will be logged out immediately when you press C-d.
##   or an error message may appear. For that reason READLINE_LINE
##   I want to set a string of finite length to , but then it appears on the screen.
##   Therefore, in ble.sh, the same character as the character at the current cursor position is displayed in READLINE_LINE.
##   By setting it to , there is no visual problem even if bash outputs characters.
##
##   When cx==0, the character to the right of the current cursor position is set to READLINE_LINE.
##   Set READLINE_POINT=0. When cx>0, the character to the left of the current cursor position is
##   Set READLINE_LINE and READLINE_POINT=(number of bytes of left character).
##   (Note that READLINE_POINT is a byte offset, not a number of characters.)
##
function ble/textarea#update-left-char {
  local index=$1
  if [[ $bleopt_internal_suppress_bash_output ]]; then
    lc=32 lg=0
    return 0
  fi

  # If index==0, the value at the right edge of the prompt
  if ((index==0)); then
    lc=${_ble_prompt_ps1_data[6]}
    lg=${_ble_prompt_ps1_data[7]}
    return 0
  fi

  local cx cy
  ble/textmap#getxy.cur --prefix=c "$index"

  local lcs ret
  if ((cx==0)); then
    # next character
    if ((index==iN)); then
      # Blank if there is no next character
      ret=32
    else
      lcs=${_ble_textmap_glyph[index]}
      ble/util/s2c "$lcs"
    fi

    # Leave blank if next line break
    local g; ble/highlight/layer/getg "$index"; lg=$g
    ((lc=ret==10?32:ret))
  else
    # previous character
    lcs=${_ble_textmap_glyph[index-1]}
    ble/util/s2c "${lcs:${#lcs}-1}"
    local g; ble/highlight/layer/getg "$((index-1))"; lg=$g
    ((lc=ret))
  fi
}
## @fn ble/textarea#slice-text-buffer [beg [end]]
##   @var[out] ret
function ble/textarea#slice-text-buffer {
  ble/textmap#assert-up-to-date
  local iN=$_ble_textmap_length
  local i1=${1:-0} i2=${2:-$iN}
  ((i1<0&&(i1+=iN,i1<0&&(i1=0)),
    i2<0&&(i2+=iN)))
  if ((i1<i2&&i1<iN)); then
    local g
    ble/highlight/layer/getg "$i1"
    ble/color/g2sgr "$g"
    IFS= builtin eval "ret=\"\$ret\${$_ble_textarea_bufferName[*]:i1:i2-i1}\""

    if [[ $_ble_textarea_bufferName == _ble_textarea_buffer ]]; then
      # Note #D1745: Automatic line breaks are encoded with \r. Last and \npreceding
      # Automatic wrapping (\r) is converted to \n, and other \r are deleted.
      local out= rex_nl=$'^(\e\\[[ -?]*[@-~]|\e[ -/]+[@-~]|[\x0E\x0F])*'$_ble_term_nl # disable=#D1440 (LC_COLLATE=C is set)
      while [[ $ret == *"$_ble_term_cr"* ]]; do
        out=$out${ret%%"$_ble_term_cr"*}
        ret=${ret#*"$_ble_term_cr"}
        if ble/string#match-safe "$ret" "$rex_nl"; then
          # If there is a real line break next, insert a line break to display it as a double line break.
          out=$out$_ble_term_nl
        elif [[ ! $ret ]]; then
          # When there is an automatic wrap at the end, if you are at the real end, it will be forced to auto wrap with a blank.
          # Remove white space after wrapping occurs. Otherwise, place it on an explicit line break.
          # exchange. This will break the line, but otherwise the terminal's coordinate system will
          # It can't be helped because the math will be broken.
          if ((i2==iN)); then
            out=$out' '$_ble_term_cr${_ble_term_ech//'%d'/1}
          else
            out=$out$_ble_term_nl
          fi
        fi
      done
      ret=$out$ret
    fi
  else
    ret=
  fi
}

# 
# **** textarea.render ****                                    @textarea.render

#
# global variable
#

## @arr _ble_textarea_cur
##     Stores information about the caret position (the cursor presented to the user) and the characters at that location.
##   _ble_textarea_cur[0] x Holds the y coordinate of the caret drawing position.
##   _ble_textarea_cur[1] y Holds the y-coordinate of the caret drawing position.
##   _ble_textarea_cur[2] lc
##     Holds the character code of the character to the left of the caret position as an integer.
##     If the caret is in the leftmost column, it retains the characters on the right.
##   _ble_textarea_cur[3] lg
##     Holds the SGR flag to the left of the caret position.
##     Holds the SGR flag applied to the character on the right if the caret is in the leftmost column.
_ble_textarea_cur=(0 0 32 0)

_ble_textarea_panel=0
_ble_textarea_scroll=
_ble_textarea_scroll_new=
_ble_textarea_gendx=0
_ble_textarea_gendy=0

#
# display function
#

## @var _ble_textarea_invalidated
##   Records that a complete redraw (including prompts) was requested.
##   Empty string before a full redraw is requested, and has a value of 1 after.
_ble_textarea_invalidated=1

function ble/textarea#invalidate {
  if [[ $1 == str || $1 == partial ]]; then
    ((_ble_textarea_version++))
  else
    _ble_textarea_invalidated=1
  fi
  return 0
}

## @fn ble/textarea#render/.erase-forward-line.draw opts
##   @var[in] x cols
##   @var[out] DRAW_BUFF
function ble/textarea#render/.erase-forward-line.draw {
  local eraser=$_ble_term_sgr0$_ble_term_el
  if [[ :$render_opts: == *:relative:* ]]; then
    local width=$((cols-x))
    if ((width==0)); then
      eraser=
    elif [[ $_ble_term_ech ]]; then
      eraser=$_ble_term_sgr0${_ble_term_ech//'%d'/$width}
    else
      ble/string#reserve-prototype "$width"
      eraser=$_ble_term_sgr0${_ble_string_prototype::width}${_ble_term_cub//'%d'/$width}
    fi
  fi
  ble/canvas/put.draw "$eraser"
}

## @fn ble/textarea#render/.determine-scroll
##   Determines the new display height and scroll position.
##   Assume it is called from ble/textarea#render.
##
##   @var[in,out] scroll
##     Specifies the current scroll amount. Specify the adjusted scroll amount.
##   @var[in,out] height
##     Specifies the current display height. Returns the display height after repositioning.
##   @var[in,out] umin umax
##     Limits the drawing range to the visible area and returns it.
##   @var[out] DRAW_BUFF
##
##   @var[in] cols
##   @var[in] begx begy endx endy cx cy
##     Specify the display coordinates of the beginning, end, and current cursor position of the edit string, respectively.
##
function ble/textarea#render/.determine-scroll {
  local nline=$((endy+1))

  # Request height of panel. After this, it should become height <= nline.
  if ((height!=nline)); then
    ble/canvas/panel/reallocate-height.draw
    height=${_ble_canvas_panel_height[_ble_textarea_panel]}
  fi

  if ((height<nline)); then
    ((scroll<=nline-height)) || ((scroll=nline-height))

    local rheight=$((height-begy)) rnline=$((nline-begy)) rcy=$((cy-begy))
    local margin=$((rheight>=6&&rnline>rheight+2?2:1))
    local smin smax
    ((smin=rcy-rheight+margin,
      smin>nline-height&&(smin=nline-height),
      smax=rcy-margin,
      smax<0&&(smax=0)))
    if ((scroll>smax)); then
      scroll=$smax
    elif ((scroll<smin)); then
      scroll=$smin
    fi

    # Limit [umin, umax] by display range.
    #
    # Note: When scroll == 0, the display starts from the first line.
    #   When scroll > 0, only ... is displayed on the first line of the display,
    #   Display from the second display line.
    #
    local wmin=0 wmax index
    if ((scroll)); then
      ble/textmap#get-index-at 0 "$((scroll+begy+1))"; wmin=$index
    fi
    ble/textmap#get-index-at "$cols" "$((scroll+height-1))"; wmax=$index
    ((umin<umax)) &&
      ((umin<wmin&&(umin=wmin),
        umax>wmax&&(umax=wmax)))
  else
    # Note: height == nline
    scroll=
    if ! ble/util/assert '((height==nline))'; then
      ble/canvas/panel#set-height.draw "$_ble_textarea_panel" "$nline"
      height=$nline
    fi
  fi
}
## @fn ble/textarea#render/.perform-scroll new_scroll
##
##   @var[out] DRAW_BUFF
##     The output destination for the sequence that performs scrolling.
##
##   @var[in] height cols render_opts
##   @var[in] begx begy
##
function ble/textarea#render/.perform-scroll {
  local new_scroll=$1
  if ((new_scroll!=_ble_textarea_scroll)); then
    local scry=$((begy+1))
    local scrh=$((height-scry))

    # Deleting and inserting rows and determining new area [fmin, fmax]
    local fmin fmax index
    if ((_ble_textarea_scroll>new_scroll)); then
      local shift=$((_ble_textarea_scroll-new_scroll))
      local draw_shift=$((shift<scrh?shift:scrh))
      ble/canvas/panel#goto.draw "$_ble_textarea_panel" 0 "$((height-draw_shift))"
      ble/canvas/put-dl.draw "$draw_shift" panel
      ble/canvas/panel#goto.draw "$_ble_textarea_panel" 0 "$scry"
      ble/canvas/put-il.draw "$draw_shift" panel

      if ((new_scroll==0)); then
        fmin=0
      else
        ble/textmap#get-index-at 0 "$((scry+new_scroll))"; fmin=$index
      fi
      ble/textmap#get-index-at "$cols" "$((scry+new_scroll+draw_shift-1))"; fmax=$index
    else
      local shift=$((new_scroll-_ble_textarea_scroll))
      local draw_shift=$((shift<scrh?shift:scrh))
      ble/canvas/panel#goto.draw "$_ble_textarea_panel" 0 "$scry"
      ble/canvas/put-dl.draw "$draw_shift" panel
      ble/canvas/panel#goto.draw "$_ble_textarea_panel" 0 "$((height-draw_shift))"
      ble/canvas/put-il.draw "$draw_shift" panel

      ble/textmap#get-index-at 0 "$((new_scroll+height-draw_shift))"; fmin=$index
      ble/textmap#get-index-at "$cols" "$((new_scroll+height-1))"; fmax=$index
    fi

    # Fill the newly appeared range [fmin, fmax]
    if ((fmin<fmax)); then
      local fmaxx fmaxy fminx fminy
      ble/textmap#getxy.out --prefix=fmin "$fmin"
      ble/textmap#getxy.out --prefix=fmax "$fmax"

      ble/canvas/panel#goto.draw "$_ble_textarea_panel" "$fminx" "$((fminy-new_scroll))"
      ((new_scroll==0)) &&
        x=$fminx ble/textarea#render/.erase-forward-line.draw # Erase ...
      local ret; ble/textarea#slice-text-buffer "$fmin" "$fmax"
      ble/canvas/put.draw "$ret"
      ((_ble_canvas_x=fmaxx,
        _ble_canvas_y+=fmaxy-fminy))

      ((umin<umax)) &&
        ((fmin<=umin&&umin<fmax&&(umin=fmax),
          fmin<umax&&umax<=fmax&&(umax=fmin)))
    fi

    _ble_textarea_scroll=$new_scroll

    ble/textarea#render/.show-scroll-at-first-line
  fi
}
## @fn ble/textarea#render/.show-scroll-at-first-line
##   Displaying "(line 3) ..." etc. when scrolling
##
##   @var[in] _ble_textarea_scroll
##   @var[in] cols render_opts
##   @var[in,out] DRAW_BUFF _ble_canvas_x _ble_canvas_y
##
function ble/textarea#render/.show-scroll-at-first-line {
  if ((_ble_textarea_scroll!=0)); then
    ble/canvas/panel#goto.draw "$_ble_textarea_panel" "$begx" "$begy"
    local scroll_status="(line $((_ble_textarea_scroll+2))) ..."
    scroll_status=${scroll_status::cols-1-begx}
    x=$begx ble/textarea#render/.erase-forward-line.draw
    ble/canvas/put.draw "$eraser$_ble_term_bold$scroll_status$_ble_term_sgr0"
    ((_ble_canvas_x+=${#scroll_status}))
  fi
}

## @fn ble/textarea#render/.erase-rprompt
##   @var[in] cols
##     Specifies cols after decreasing it by the width of rps1.
function ble/textarea#render/.erase-rprompt {
  [[ $_ble_prompt_rps1_shown ]] || return 0
  _ble_prompt_rps1_shown=
  local rps1_height=${_ble_prompt_rps1_gbox[3]}
  local -a DRAW_BUFF=()
  local y=0
  for ((y=0;y<rps1_height;y++)); do
    ble/canvas/panel#goto.draw "$_ble_textarea_panel" "$((cols+1))" "$y" sgr0
    ble/canvas/put.draw "$_ble_term_el"
  done
  ble/canvas/bflush.draw
}
## @fn ble/textarea#render/.cleanup-trailing-spaces-after-newline
##   When rps1_transient, remove unnecessary whitespace at the end of the line before going to the next line.
##   @var[in] text
##   @var[in] _ble_textmap_pos
##   @var[out] DRAW_BUFF
function ble/textarea#render/.cleanup-trailing-spaces-after-newline {
  local -a buffer; ble/string#split-lines buffer "$text"
  local line index=0 pos
  for line in "${buffer[@]}"; do
    ((index+=${#line}))
    ble/string#split-words pos "${_ble_textmap_pos[index]}"
    ble/canvas/panel#goto.draw "$_ble_textarea_panel" "${pos[0]}" "${pos[1]}" sgr0
    ble/canvas/put.draw "$_ble_term_el"
    ((index++))
  done
  _ble_prompt_rps1_shown=
}

## @fn ble/textarea#render/.show-control-string prefix [force]
function ble/textarea#render/.show-control-string {
  local ref_dirty=${1}_dirty ref_output=${1}_data[10] force=$2
  [[ $force || ${!ref_dirty} ]] || return 0
  ble/canvas/put.draw "${!ref_output}"
  builtin eval -- "$ref_dirty="
  return 0
}
## @fn ble/textarea#render/.show-prompt [force]
function ble/textarea#render/.show-prompt {
  [[ $1 || $_ble_prompt_ps1_dirty ]] || return 0
  local esc=${_ble_prompt_ps1_data[8]}
  local prox=${_ble_prompt_ps1_data[3]}
  local proy=${_ble_prompt_ps1_data[4]}
  ble/canvas/panel#goto.draw "$_ble_textarea_panel"
  ble/canvas/panel#put.draw "$_ble_textarea_panel" "$esc" "$prox" "$proy"
  _ble_prompt_ps1_dirty=
}
## @fn ble/textarea#render/.show-rprompt [force]
##   @var[in] cols
function ble/textarea#render/.show-rprompt {
  [[ $1 || $_ble_prompt_rps1_dirty ]] || return 0
  local rps1out=${_ble_prompt_rps1_data[8]}$_ble_term_sgr0$_ble_term_cr
  local rps1x=0
  local rps1y=${_ble_prompt_rps1_data[4]}
  # Note: cols is the right edge of the textmap, not the right edge of the screen.
  ble/canvas/panel#goto.draw "$_ble_textarea_panel" 0 0
  ble/canvas/panel#put.draw "$_ble_textarea_panel" "$rps1out" "$rps1x" "$rps1y"
  _ble_prompt_rps1_dirty=
  _ble_prompt_rps1_shown=1
}

## @fn ble/textarea#render/.trim-prompt
##   @var[ref] DRAW_BUFF
function ble/textarea#render/.trim-prompt {
  local ps1f=$bleopt_prompt_ps1_final
  local ps1t=$bleopt_prompt_ps1_transient
  if [[ ! $ps1f && :$ps1t: == *:trim:* ]]; then
    [[ :$ps1t: == *:same-dir:* && $PWD != $_ble_prompt_trim_opwd ]] && return 0
    local y=${_ble_prompt_ps1_data[4]}
    if ((y)); then
      ble/canvas/panel#goto.draw "$_ble_textarea_panel" 0 0
      ble/canvas/panel#increase-height.draw "$_ble_textarea_panel" "$((-y))" shift
      ((_ble_textarea_gendy-=y))
    fi
  fi
}

## @fn ble/textarea#focus
##   Moves the terminal cursor to the current position of the prompt/edit string.
function ble/textarea#focus {
  local -a DRAW_BUFF=()
  ble/canvas/panel#goto.draw "$_ble_textarea_panel" "${_ble_textarea_cur[0]}" "${_ble_textarea_cur[1]}"
  ble/canvas/bflush.draw
}

## @fn ble/textarea#render opts
##   Update the prompt/edit string display for ble/util/buffer.
##   Post-condition: Move to cursor position (x y) = (_ble_textarea_cur[0] _ble_textarea_cur[1])
##   Post-condition: Redraw the edited string part
##
##   @param[in] opts
##     leave
##       Clears rps1 when bleopt prompt_rps1_transient is a non-empty string.
##     update
##       Force redraw. For example, use this when updating coloring asynchronously.
##
##   @var _ble_textarea_caret_state := inds ':' mark ':' mark_active ':' line_disabled ':' overwrite_mode
##     This is a variable used in ble/textarea#render.
##     Records information about the cursor position and point position of the currently displayed content.
##
_ble_textarea_caret_state=::
_ble_textarea_version=0
function ble/textarea#render {
  local opts=$1
  local ble_textarea_render_flag=1 # Reference from ble/textarea#panel::onHeightChange
  local caret_state=$_ble_textarea_version:$_ble_edit_ind:$_ble_edit_mark:$_ble_edit_mark_active:$_ble_edit_line_disabled:$_ble_edit_overwrite_mode

  local dirty=
  if ble/prompt/update "check-dirty:$opts"; then
    dirty=1
  elif ((_ble_edit_dirty_draw_beg>=0)); then
    dirty=1
  elif [[ $_ble_textarea_invalidated ]]; then
    dirty=1
  elif [[ $_ble_textarea_caret_state != "$caret_state" ]]; then
    dirty=1
  elif [[ $_ble_textarea_scroll != "$_ble_textarea_scroll_new" ]]; then
    dirty=1
  elif [[ :$opts: == *:leave:* || :$opts: == *:update:* ]]; then
    dirty=1
  fi

  if [[ ! $dirty ]]; then
    ble/textarea#focus
    return 0
  fi

  #-------------------
  # Calculation of drawing contents (placement information, colored strings)

  local cols=${COLUMNS-80}

  local subprompt_enabled=
  ((_ble_textarea_panel==0)) && subprompt_enabled=1
  local rps1_enabled=$_ble_prompt_rps1_enabled
  local rps1_width=${_ble_prompt_rps1_data[11]}
  if [[ $rps1_enabled ]]; then
    ((cols-=rps1_width+1,_ble_term_xenl||cols--))
    if [[ $rps1_enabled == erase ]]; then
      ble/textarea#render/.erase-rprompt
      rps1_enabled=
    fi
  fi

  # Building an edit
  local text=$_ble_edit_str index=$_ble_edit_ind
  local iN=${#text}
  ((index<0?(index=0):(index>iN&&(index=iN))))

  local umin=-1 umax=-1
  local x=${_ble_prompt_ps1_data[3]}
  local y=${_ble_prompt_ps1_data[4]}

  # Update placement information
  local render_opts=
  [[ $rps1_enabled ]] && render_opts=relative
  COLUMNS=$cols ble/textmap#update "$text" "$render_opts" # [ref] x y
  ble/urange#update "$_ble_textmap_umin" "$_ble_textmap_umax" # [ref] umin umax
  ble/urange#clear --prefix=_ble_textmap_

  # Coloring update
  if [[ :$opts: == *:leave:* ]]; then
    local _ble_complete_menu_active= # suppress layer:menu_filter
    local _ble_edit_mark_active= # suppress layer:region
    local _ble_edit_overwrite_mode= # suppress layer:overwrite_mode
  fi
  local DMIN=$_ble_edit_dirty_draw_beg
  ble-edit/content/update-syntax
  ble/textarea#update-text-buffer # [in] text index [ref] lc lg;

  local lc=32 lg=0
  [[ $bleopt_internal_suppress_bash_output ]] ||
    ble/textarea#update-left-char "$index"

  #-------------------
  # Determining the drawing area and scrolling

  local -a DRAW_BUFF=()

  # 1 Determining the drawing area
  local begx=$_ble_textmap_begx begy=$_ble_textmap_begy
  local endx=$_ble_textmap_endx endy=$_ble_textmap_endy
  local cx cy
  ble/textmap#getxy.cur --prefix=c "$index" # → cx cy

  local cols=$_ble_textmap_cols
  local height=${_ble_canvas_panel_height[_ble_textarea_panel]}
  local scroll=${_ble_textarea_scroll_new:-$_ble_textarea_scroll}
  ble/textarea#render/.determine-scroll # update: height scroll umin umax

  local gend gendx gendy
  if [[ $scroll ]]; then
    ble/textmap#get-index-at "$cols" "$((height+scroll-1))"; gend=$index
    ble/textmap#getxy.out --prefix=gend "$gend"
    ((gendy-=scroll))
  else
    gend=$iN gendx=$endx gendy=$endy
  fi
  _ble_textarea_gendx=$gendx _ble_textarea_gendy=$gendy

  #-------------------
  # output

  # 2 Display contents
  local ret esc_line= esc_line_set=
  if [[ ! $_ble_textarea_invalidated ]]; then
    # For partial updates

    [[ ! $rps1_enabled && $_ble_prompt_rps1_shown || $rps1_enabled && $_ble_prompt_rps1_dirty ]] &&
      ble/textarea#render/.cleanup-trailing-spaces-after-newline

    # scroll
    ble/textarea#render/.perform-scroll "$scroll" # update: umin umax
    _ble_textarea_scroll_new=$_ble_textarea_scroll

    # Display any updates to the prompt
    [[ $rps1_enabled ]] && ble/textarea#render/.show-rprompt
    ble/textarea#render/.show-prompt
    if [[ $subprompt_enabled ]]; then
      ble/textarea#render/.show-control-string _ble_prompt_xterm_title
      ble/textarea#render/.show-control-string _ble_prompt_screen_title
      ble/textarea#render/.show-control-string _ble_prompt_term_status
    fi

    # When drawing part of the edited string
    if ((umin<umax)); then
      local uminx uminy umaxx umaxy
      ble/textmap#getxy.out --prefix=umin "$umin"
      ble/textmap#getxy.out --prefix=umax "$umax"

      ble/canvas/panel#goto.draw "$_ble_textarea_panel" "$uminx" "$((uminy-_ble_textarea_scroll))"
      ble/textarea#slice-text-buffer "$umin" "$umax"
      ble/canvas/panel#put.draw "$_ble_textarea_panel" "$ret" "$umaxx" "$((umaxy-_ble_textarea_scroll))"
    fi

    if ((DMIN>=0)); then
      local endY=$((endy-_ble_textarea_scroll))
      if ((endY<height)); then
        if [[ :$render_opts: == *:relative:* ]]; then
          ble/canvas/panel#goto.draw "$_ble_textarea_panel" "$endx" "$endY"
          x=$endx ble/textarea#render/.erase-forward-line.draw
          ble/canvas/panel#clear-after.draw "$_ble_textarea_panel" 0 "$((endY+1))"
        else
          ble/canvas/panel#clear-after.draw "$_ble_textarea_panel" "$endx" "$endY"
        fi
      fi
    fi
  else
    # Overall update
    ble/canvas/panel#clear.draw "$_ble_textarea_panel"
    _ble_prompt_rps1_shown=

    # prompt drawing
    [[ $rps1_enabled ]] && ble/textarea#render/.show-rprompt force
    ble/textarea#render/.show-prompt force
    if [[ $subprompt_enabled ]]; then
      ble/textarea#render/.show-control-string _ble_prompt_xterm_title  force
      ble/textarea#render/.show-control-string _ble_prompt_screen_title force
      ble/textarea#render/.show-control-string _ble_prompt_term_status  force
    fi

    # Whole drawing
    _ble_textarea_scroll=$scroll
    _ble_textarea_scroll_new=$_ble_textarea_scroll
    if [[ ! $_ble_textarea_scroll ]]; then
      ble/textarea#slice-text-buffer # → ret
      esc_line=$ret esc_line_set=1
      ble/canvas/panel#put.draw "$_ble_textarea_panel" "$ret" "$_ble_textarea_gendx" "$_ble_textarea_gendy"
    else
      ble/textarea#render/.show-scroll-at-first-line

      local gbeg=0
      if ((_ble_textarea_scroll)); then
        ble/textmap#get-index-at 0 "$((_ble_textarea_scroll+begy+1))"; gbeg=$index
      fi

      local gbegx gbegy
      ble/textmap#getxy.out --prefix=gbeg "$gbeg"
      ((gbegy-=_ble_textarea_scroll))

      ble/canvas/panel#goto.draw "$_ble_textarea_panel" "$gbegx" "$gbegy"
      ((_ble_textarea_scroll==0)) &&
        x=$gbegx ble/textarea#render/.erase-forward-line.draw # Erase ...

      ble/textarea#slice-text-buffer "$gbeg" "$gend"
      ble/canvas/panel#put.draw "$_ble_textarea_panel" "$ret" "$_ble_textarea_gendx" "$_ble_textarea_gendy"
    fi
  fi

  # 3 move
  local gcx=$cx gcy=$((cy-_ble_textarea_scroll))
  ble/canvas/panel#goto.draw "$_ble_textarea_panel" "$gcx" "$gcy"

  [[ :$opts: == *:leave:* ]] && ble/textarea#render/.trim-prompt
  ble/canvas/bflush.draw

  # 4 Record information for later use
  _ble_textarea_cur=("$gcx" "$gcy" "$lc" "$lg")
  _ble_textarea_invalidated= _ble_textarea_caret_state=$caret_state

  if [[ ! $bleopt_internal_suppress_bash_output ]]; then
    if [[ ! $esc_line_set ]]; then
      if [[ ! $_ble_textarea_scroll ]]; then
        ble/textarea#slice-text-buffer
        esc_line=$ret
      else
        local _ble_canvas_x=$begx _ble_canvas_y=$begy
        DRAW_BUFF=()

        ble/textarea#render/.show-scroll-at-first-line

        local gbeg=0
        if ((_ble_textarea_scroll)); then
          ble/textmap#get-index-at 0 "$((_ble_textarea_scroll+begy+1))"; gbeg=$index
        fi
        local gbegx gbegy
        ble/textmap#getxy.out --prefix=gbeg "$gbeg"
        ((gbegy-=_ble_textarea_scroll))

        ble/canvas/panel#goto.draw "$_ble_textarea_panel" "$gbegx" "$gbegy"
        ((_ble_textarea_scroll==0)) &&
          x=$gbegx ble/textarea#render/.erase-forward-line.draw # Erase ...
        ble/textarea#slice-text-buffer "$gbeg" "$gend"
        ble/canvas/put.draw "$ret"

        ble/canvas/sflush.draw -v esc_line
      fi
    fi

    local esc=${_ble_prompt_ps1_data[8]}
    esc=${_ble_prompt_xterm_title_data[10]}$esc
    esc=${_ble_prompt_screen_title_data[10]}$esc
    esc=${_ble_prompt_term_status_data[10]}$esc
    _ble_textarea_cache=(
      "$esc$esc_line"
      "${_ble_textarea_cur[@]}"
      "$_ble_textarea_gendx" "$_ble_textarea_gendy")
  fi
}
function ble/textarea#redraw {
  ble/textarea#invalidate
  ble/textarea#render
}

## @arr _ble_textarea_cache
##   This is a cache of the currently displayed content.
## The value is set in ble/textarea#render.
##   ble/textarea#redraw-cache performs redrawing based on this information.
## _ble_textarea_cache[0]: Display content
## _ble_textarea_cache[1]: curx cursor position x
## _ble_textarea_cache[2]: cury cursor position y
## _ble_textarea_cache[3]: curlc Character code of character at cursor position
## _ble_textarea_cache[4]: curlg SGR flag of character at cursor position
## _ble_textarea_cache[5]: gendx display end position x
## _ble_textarea_cache[6]: gendy display end position y
_ble_textarea_cache=()

function ble/textarea#redraw-cache {
  if [[ ! $_ble_textarea_scroll && ${_ble_textarea_cache[0]+set} ]]; then
    local -a d; d=("${_ble_textarea_cache[@]}")

    local -a DRAW_BUFF=()

    ble/canvas/panel#clear.draw "$_ble_textarea_panel"
    ble/canvas/panel#goto.draw "$_ble_textarea_panel"
    ble/canvas/put.draw "${d[0]}"
    ble/canvas/panel#report-cursor-position "$_ble_textarea_panel" "${d[5]}" "${d[6]}"
    _ble_textarea_gendx=${d[5]}
    _ble_textarea_gendy=${d[6]}

    _ble_textarea_cur=("${d[@]:1:4}")
    ble/canvas/panel#goto.draw "$_ble_textarea_panel" "${_ble_textarea_cur[0]}" "${_ble_textarea_cur[1]}"
    ble/canvas/bflush.draw
  else
    ble/textarea#redraw
  fi
}

## @fn ble/textarea#adjust-for-bash-bind
##   Correct the display position of the prompt/edit string.
##
##   @remarks
##   This function is intended to be called from a bind -x function.
##   It is not intended to be called from a function that is executed as a normal command.
##   Since PS1= etc. are set internally, prompt information is lost.
##   Also, change the values of global variables such as READLINE_LINE and READLINE_POINT.
##
## 2018-03-19
##   Apparently, when using stty -echo, even if a value is set for READLINE_LINE,
##   Bash doesn't seem to output anything.
##   Therefore, simply set a character to FEADLINE_LINE.
##
function ble/textarea#adjust-for-bash-bind {
  ble-edit/adjust-PS1
  if [[ $bleopt_internal_suppress_bash_output ]]; then
    READLINE_LINE=$'\n' READLINE_POINT=0 READLINE_MARK=0
  else
    # Hide the prompt that bash displays
    # (overwrites the character to the left of the current cursor again)
    local -a DRAW_BUFF=()
    local ret lc=${_ble_textarea_cur[2]} lg=${_ble_textarea_cur[3]}
    ble/util/c2s "$lc"
    READLINE_LINE=$ret READLINE_MARK=0
    if ((_ble_textarea_cur[0]==0)); then
      READLINE_POINT=0
    else
      ble/util/c2w "$lc"
      ((ret>0)) && ble/canvas/put-cub.draw "$ret"
      ble/util/c2bc "$lc"
      READLINE_POINT=$ret
    fi

    ble/color/g2sgr "$lg"
    ble/canvas/put.draw "$ret"

    # 2018-03-19 When using stty -echo, Bash does not output anything, so no adjustment is necessary.
    #ble/canvas/bflush.draw
  fi
}

function ble/textarea#save-state {
  local prefix=$1
  local -a vars=()

  # _ble_prompt_ps1_data
  ble/array#push vars _ble_edit_PS1 _ble_prompt_ps1_data

  # _ble_edit_*
  ble/array#push vars "${_ble_edit_VARNAMES[@]}"

  # _ble_textmap_*
  ble/array#push vars "${_ble_textmap_VARNAMES[@]}"

  # _ble_highlight_layer_*
  ble/array#push vars _ble_highlight_layer_list
  local layer names
  for layer in "${_ble_highlight_layer_list[@]}"; do
    local _ble_local_script='
      if [[ ${_ble_highlight_layer_LAYER_VARNAMES[@]-} ]]; then
        ble/array#push vars "${_ble_highlight_layer_LAYER_VARNAMES[@]}"
      else
        ble/array#push vars "${!_ble_highlight_layer_LAYER_@}"
      fi'
    builtin eval -- "${_ble_local_script//LAYER/$layer}"
  done

  # _ble_textarea_*
  ble/array#push vars "${_ble_textarea_VARNAMES[@]}"

  # _ble_syntax_*
  ble/array#push vars "${_ble_syntax_VARNAMES[@]}"

  # user-defined local variables
  ble/array#push vars "${_ble_textarea_local_VARNAMES[@]}"

  builtin eval -- "${prefix}_VARNAMES=(\"\${vars[@]}\")"
  ble/util/save-vars "$prefix" "${vars[@]}"
}
function ble/textarea#restore-state {
  local prefix=$1
  if builtin eval "[[ \$prefix && \${${prefix}_VARNAMES+set} ]]"; then
    builtin eval "ble/util/restore-vars $prefix \"\${${prefix}_VARNAMES[@]}\""
  else
    ble/util/print "ble/textarea#restore-state: unknown prefix '$prefix'." >&2
    return 1
  fi
}
function ble/textarea#clear-state {
  local prefix=$1
  if [[ $prefix ]]; then
    local vars=${prefix}_VARNAMES
    builtin eval "builtin unset -v \"\${$vars[@]/#/$prefix}\" $vars"
  else
    ble/util/print "ble/textarea#restore-state: unknown prefix '$prefix'." >&2
    return 1
  fi
}

# Asynchronous update

_ble_textarea_render_defer=
function ble/textarea#render-defer.idle {
  ble/util/idle.wait-user-input
  [[ $_ble_textarea_render_defer ]] || return 0

  local ble_textarea_render_defer_running=1
  ble/util/buffer.flush
  _ble_textarea_render_defer=
  blehook/invoke textarea_render_defer
  ble/textarea#render update

  [[ $_ble_textarea_render_defer ]] &&
    ble/util/idle.continue
  return 0
}
ble/function#try ble/util/idle.push-background ble/textarea#render-defer.idle

# 
#------------------------------------------------------------------------------

function ble/widget/.update-textmap {
  # Reproducing the width when rps1 is present
  local cols=${COLUMNS:-80} render_opts=
  if [[ $_ble_prompt_rps1_enabled ]]; then
    local rps1_width=${_ble_prompt_rps1_data[11]}
    render_opts=relative
    ((cols-=rps1_width+1,_ble_term_xenl||cols--))
  fi

  local x=$_ble_textmap_begx y=$_ble_textmap_begy
  COLUMNS=$cols ble/textmap#update "$_ble_edit_str" "$render_opts"
}
function ble/widget/do-lowercase-version {
  local n=${#KEYS[@]}; ((n&&n--))
  local flag=$((KEYS[n]&_ble_decode_MaskFlag))
  local char=$((KEYS[n]&_ble_decode_MaskChar))
  if ((65<=char&&char<=90)); then
    ble/decode/widget/redispatch-by-keys "$((flag|char+32))" "${KEYS[@]:1}"
  else
    return 125
  fi
}

# 
# **** redraw, clear-screen, etc ****                             @widget.clear

function ble/widget/redraw-line {
  ble-edit/content/clear-arg
  ble/textarea#invalidate
}
function ble/widget/clear-screen {
  ble-edit/content/clear-arg
  ble/edit/enter-command-layout # #D1800 pair=leave-command-layout
  _ble_prompt_trim_opwd=
  ble/textarea#invalidate
  local -a DRAW_BUFF=()
  ble/canvas/panel/goto-top-dock.draw
  ble/canvas/bflush.draw
  ble/util/buffer "$_ble_term_clear"
  _ble_canvas_x=0 _ble_canvas_y=0
  ble/term/visible-bell/cancel-erasure
  ble/edit/leave-command-layout # #D1800 pair=enter-command-layout
}
function ble/widget/clear-display {
  ble/util/buffer $'\e[3J'
  ble/widget/clear-screen
}

function ble/edit/display-version/git-rev-parse {
  ret=
  local git_base opts=$2
  case $1 in
  (.)       git_base=$PWD ;;
  (./*)     git_base=$PWD/${1#./} ;;
  (..|../*) git_base=$PWD/$1 ;;
  (*)       git_base=$1 ;;
  esac

  "${_ble_util_set_declare[@]//NAME/visited}" # WA #D1570 checked
  until [[ -s $git_base/HEAD || -s $git_base/.git/HEAD ]]; do
    # guard for cyclic refs
    ble/set#contains visited "$git_base" && return 1
    ble/set#add visited "$git_base"

    # submodule?
    if [[ -f $git_base/.git ]]; then
      local content
      ble/util/mapfile content < "$git_base/.git"
      if ble/string#match "$content" '^gitdir: (.*)'; then
        git_base=$git_base/${BASH_REMATCH[1]}
        continue
      fi
    fi

    # parent directory?
    if [[ :$opts: == *:parent:* && $git_base == */* ]]; then
      git_base=${git_base%/*}
      continue
    fi

    break
  done
  [[ -s $git_base/HEAD ]] || git_base=$git_base/.git

  local head=$git_base/HEAD
  if [[ -f $head ]]; then
    local content
    ble/util/mapfile content < "$head"
    if ble/string#match "$content" '^ref: (.*)$'; then
      head=$git_base/${BASH_REMATCH[1]}
      ble/util/mapfile content < "$head"
    fi
    if ble/string#match "$content" '^[a-f0-9]+$'; then
      content=${content::8}
    fi
    ret=$content
    [[ $ret ]]
    return "$?"
  fi
  return 1
}
function ble/edit/display-version/git-hash-object {
  local file=$1 size
  if ! ble/util/assign size 'ble/bin/wc -c "$file" 2>/dev/null'; then
    ret='error'
    return 1
  fi
  ble/string#split-words size "$size"

  if ble/bin#has git; then
    ble/util/assign ret 'git hash-object "$file"'
    ret="hash:$ret, $size bytes"
  elif ble/bin#has sha1sum; then
    local _ble_local_tmpfile; ble/util/assign/mktmp
    { printf 'blob %d\0' "$size"; ble/bin/cat "$file"; } >| "$_ble_local_tmpfile"
    blob_data=$_ble_local_tmpfile ble/util/assign ret 'sha1sum "$blob_data"'
    ble/util/assign/rmtmp

    ble/string#split-words ret "$ret"
    ret="sha1:$ret, $size bytes"
  elif ble/bin#has cksum; then
    ble/util/assign-words ret 'cksum "$file"'
    ble/util/sprintf ret 'cksum:%08x, %d bytes' "$ret" "$size"
  else
    ret=size:$size
  fi
}
function ble/edit/display-version/add-line {
  lines[iline++]=$1
}
function ble/edit/display-version/check:bash-completion {
  [[ ${BASH_COMPLETION_VERSINFO[0]-} ]] || return 1

  local patch=${BASH_COMPLETION_VERSINFO[2]-}
  local version=${BASH_COMPLETION_VERSINFO[0]}.${BASH_COMPLETION_VERSINFO[1]:-y}${patch:+.$patch}
  local source lineno ret
  if ble/function#get-source-and-lineno _init_completion; then
    if ble/edit/display-version/git-rev-parse "${source%/*}"; then
      version=$sgrV$version+$ret$sgr0
    elif ble/edit/display-version/git-hash-object "$source"; then
      version="$sgrV$version$sgr0 ($ret)"
    fi
  fi
  ble/edit/display-version/add-line "${sgrF}bash-completion$sgr0, version $version$label_noarch"
}
function ble/edit/display-version/check:bash-preexec {
  local source lineno ret
  ble/function#get-source-and-lineno __bp_preexec_invoke_exec || return 1

  local version="${source/#$HOME/~}$label_noarch"
  if ble/edit/display-version/git-rev-parse "${source%/*}"; then
    version="version $sgrV+$ret$sgr0$label_noarch"
  elif ble/edit/display-version/git-hash-object "$source"; then
    version="($ret)$label_noarch"
  fi

  local file=${source##*/}
  if [[ $file == bash-preexec.sh || $file == bash-preexec.bash ]]; then
    file=
  else
    file=" ($file)"
  fi

  local integ_label=$label_integration_off
  ble/util/import/is-loaded contrib/integration/bash-preexec && integ_label=$label_integration
  ble/edit/display-version/add-line "${sgrF}bash-preexec$sgr0$file, $version$integ_label"
}
function ble/edit/display-version/check:fzf {
  # fzf-key-bindings
  local source lineno ret
  if ble/function#get-source-and-lineno __fzf_select__; then
    local version="${source/#$HOME/~}$label_noarch"
    if ble/edit/display-version/git-rev-parse "${source%/*}" parent; then
      version="version $sgrV+$ret$sgr0$label_noarch"
    elif ble/edit/display-version/git-hash-object "$source"; then
      version="($ret)$label_noarch"
    fi

    local integ= integ_label=$label_integration_off
    ble/util/import/is-loaded integration/fzf-key-bindings &&
      integ=1 integ_label=$label_integration

    ble/edit/display-version/add-line "${sgrC}fzf$sgr0 ${sgrF}key-bindings$sgr0, $version$integ_label"
    [[ $integ ]] || ble/edit/display-version/add-line "$label_warning: fzf integration \"integration/fzf-key-bindings\" is not activated."
  fi

  # fzf-completion
  if ble/function#get-source-and-lineno __fzf_orig_completion; then
    local version="${source/#$HOME/~}$label_noarch"
    if ble/edit/display-version/git-rev-parse "${source%/*}" parent; then
      version="version $sgrV+$ret$sgr0$label_noarch"
    elif ble/edit/display-version/git-hash-object "$source"; then
      version="($ret)$label_noarch"
    fi

    local integ= integ_label=$label_integration_off
    ble/util/import/is-loaded integration/fzf-completion &&
      integ=1 integ_label=$label_integration

    ble/edit/display-version/add-line "${sgrC}fzf$sgr0 ${sgrF}completion$sgr0, $version$integ_label"
    [[ $integ ]] || ble/edit/display-version/add-line "$label_warning: fzf integration \"integration/fzf-completion\" is not activated."
  fi
}
function ble/edit/display-version/check:starship {
  local source lineno
  ble/function#get-source-and-lineno starship_precmd || return 1

  # get starship path
  local starship sed_script='s/^[[:blank:]]*PS1="\$(\(.\{1,\}\) prompt .*)";\{0,1\}$/\1/p'
  ble/util/assign-array starship 'declare -f starship_precmd | ble/bin/sed -n "$sed_script"'
  if ! ble/bin#has "$starship"; then
    { builtin eval -- "starship=$starship" && ble/bin#has "$starship"; } ||
      { starship=starship; ble/bin#has "$starship"; } || return 1
  fi

  local awk_script='
    sub(/^starship /, "") { version = $0; next; }
    sub(/^branch:/, "") { gsub(/['"$_ble_term_blank"']/, "_"); if ($0 != "") version = version "-" $0; next; }
    sub(/^commit_hash:/, "") { gsub(/['"$_ble_term_blank"']/, "_"); if ($0 != "") version = version "+" $0; next; }
    sub(/^build_time:/, "") { build_time = $0; }
    sub(/^build_env:/, "") { build_env = $0; }
    END {
      if (version != "") {
        print version;
        print build_env, build_time
      }
    }
  '
  local version=
  ble/util/assign-array version '"$starship" --version | ble/bin/awk "$awk_script"'
  [[ $version ]] || return 1

  local ret; ble/string#trim "${version[1]}"; local build=$ret
  ble/edit/display-version/add-line "${sgrF}starship${sgr0}, version $sgrV$version$sgr0${build:+ ($build)}"
}
function ble/edit/display-version/check:bash-it {
  [[ ${BASH_IT-} ]] && ble/is-function bash-it || return 1

  local version= ret
  if ble/edit/display-version/git-rev-parse "$BASH_IT"; then
    version="version $sgrV+$ret$sgr0$label_noarch"
  elif ble/edit/display-version/git-hash-object "$BASH_IT/bash_it.sh"; then
    version="($ret)$label_noarch"
  else
    version="(bash-it version)"
  fi

  # list enabled modules
  local modules=
  if ble/is-function _bash-it-component-item-is-enabled; then
    local category subdir suffix
    for category in aliases:alias completion plugins:plugin; do
      local subdir=${category%:*} suffix=${category#*:} list
      list=()
      local file name
      for file in "$BASH_IT/$subdir/available"/*.*.bash; do
        name=${file##*/}
        name=${name%."$suffix"*.bash}
        _bash-it-component-item-is-enabled "$suffix" "$name" && ble/array#push list "$name"
      done
      modules="$modules, $suffix(${list[*]})"
    done
  fi
  ble/edit/display-version/add-line "${sgrF}bash-it$sgr0${theme:+ ($theme)}, $version$modules"
}
function ble/edit/display-version/check:oh-my-bash {
  local source lineno ret version=
  if [[ ${OMB_VERSINFO-set} ]] && ble/function#get-source-and-lineno _omb_module_require; then
    version=${OMB_VERSINFO[0]}.${OMB_VERSINFO[1]}.${OMB_VERSINFO[2]}
    if ble/edit/display-version/git-rev-parse "${source%/*}"; then
      version="version $sgrV$version+$ret$sgr0$label_noarch"
    elif ble/edit/display-version/git-hash-object "$source"; then
      version="version $sgrV$version$sgr0 ($ret)$label_noarch"
    else
      version="version $sgrV$version$sgr0$label_noarch"
    fi
  elif [[ ${OSH_CUSTOM-set} ]] && ble/function#get-source-and-lineno is_plugin; then
    # old version of oh-my-bash
    version="${source/#$HOME/~}$label_noarch"
    if ble/edit/display-version/git-rev-parse "${source%/*}" parent; then
      version="version $sgrV+$ret$sgr0$label_noarch"
    elif ble/edit/display-version/git-hash-object "$source"; then
      version="($ret)$label_noarch"
    fi
  fi

  if [[ $version ]]; then
    local theme=${OMB_THEME-${OSH_THEME-}}
    local modules="aliases(${aliases[*]}), completions(${completions[*]}), plugins(${plugins[*]})"
    ble/edit/display-version/add-line "${sgrF}oh-my-bash$sgr0${theme:+ ($theme)}, $version, $modules"
  fi
}
function ble/edit/display-version/check:sbp {
  local source lineno ret
  ble/function#get-source-and-lineno _sbp_set_prompt || return 1

  local version="${source/#$HOME/~}$label_noarch"
  if ble/edit/display-version/git-rev-parse "${source%/*}"; then
    version="version $sgrV+$ret$sgr0$label_noarch"
  elif ble/edit/display-version/git-hash-object "$source"; then
    version="($ret)$label_noarch"
  fi

  local hooks="hooks(${settings_hooks[*]-${SBP_HOOKS[*]}})"
  local left="left(${settings_segments_left[*]-${SBP_SEGMENTS_LEFT[*]}})"
  local right="right(${settings_segments_right[*]-${RBP_SEGMENTS_RIGHT[*]}})"
  local modules="$hooks, $left, $right"
  ble/edit/display-version/add-line "${sgrF}sbp$sgr0, $version, $modules"
}
function ble/edit/display-version/check:gitstatus {
  local source lineno ret
  ble/function#get-source-and-lineno gitstatus_query || return 1

  local version="${source/#$HOME/~}$label_noarch"
  if ble/edit/display-version/git-rev-parse "${source%/*}"; then
    version="version $sgrV+$ret$sgr0$label_noarch"
  elif ble/edit/display-version/git-hash-object "$source"; then
    version="($ret)$label_noarch"
  fi

  ble/edit/display-version/add-line "${sgrF}romkatv/gitstatus$sgr0, $version"
}
function ble/edit/display-version/check:zoxide {
  ble/is-function __zoxide_hook || return 1

  local path=
  ble/bin#get-path zoxide || return 1

  local version=
  ble/util/assign-array version '\command zoxide --version'
  [[ $version ]] || return 1
  version=${version#zoxide }
  version=${version#v}

  local integ_label=$label_integration_off
  ble/util/import/is-loaded contrib/integration/zoxide && integ_label=$label_integration
  ble/edit/display-version/add-line "${sgrF}zoxide${sgr0}, version $sgrV$version$sgr0 ($path)$integ_label"
}
function ble/edit/display-version/check:atuin {
  # Atuin supported Bash in 7b5c3d543, where `_atuin_precmd` was defined.  The
  # function name has been changed to `__atuin_precmd` in commit 31653ed99.
  ble/is-function _atuin_precmd || ble/is-function __atuin_precmd || return 1

  local path=
  ble/bin#get-path atuin || return 1

  local version=
  ble/util/assign-array version '\command atuin --version'
  [[ $version ]] || return 1
  version=${version#atuin }
  version=${version#v}

  ble/edit/display-version/add-line "${sgrF}atuin${sgr0}, version $sgrV$version$sgr0 ($path)"
}
function ble/widget/display-shell-version {
  ble-edit/content/clear-arg

  local set shopt
  [[ $_ble_bash_options_adjusted ]] || ble/base/.adjust-bash-options set shopt

  local sgrC= sgrF= sgrV= sgrA= sgr2= sgr0= bold=
  local quote_word_opts=quote-empty
  if [[ -t 1 ]]; then
    bold=$_ble_term_bold
    sgr0=$_ble_term_sgr0
    ble/color/face2sgr command_file; sgrC=$ret
    ble/color/face2sgr command_function; sgrF=$ret
    ble/color/face2sgr syntax_expr; sgrV=$ret
    ble/color/face2sgr varname_readonly; sgrA=$ret
    ble/color/face2sgr syntax_varname; sgr2=$ret
    ble/color/face2sgr syntax_quoted; local sgr3=$ret
    ble/color/face2sgr syntax_escape; local sgr4=$ret
    quote_word_opts=$quote_word_opts:sgrq=$sgr3:sgre=$sgr4:sgr0=$sgr0
  fi
  local label_noarch=" (${sgrA}noarch$sgr0)"
  local label_integration=" $_ble_term_bold(integration: on)$sgr0"
  local label_integration_off=" $_ble_term_bold(integration: off)$sgr0"
  local label_warning="${bold}WARNING$sgr0"

  local os_release=
  if [[ -s /etc/os-release ]]; then
    ble/util/assign os_release '(
      builtin unset -v PRETTY_NAME NAME VERSION
      source /etc/os-release
      ble/util/print "${PRETTY_NAME:-${NAME:+$NAME${VERSION:+ $VERSION}}}")' 2>/dev/null
  fi
  if [[ ! $os_release && -s /etc/release ]]; then
    local ret
    ble/util/mapfile ret < /etc/release
    ble/string#trim "$ret"
    os_release=$ret
  fi

  local lines="${sgrC}GNU bash$sgr0, version $sgrV$BASH_VERSION$sgr0 ($sgrA$MACHTYPE$sgr0)${os_release:+ [$os_release]}" iline=1
  local ble_build_info="${_ble_base_build_git_version/#git version/git}, $_ble_base_build_make_version, $_ble_base_build_gawk_version"
  lines[iline++]="${sgrF}ble.sh$sgr0, version $sgrV$BLE_VERSION$sgr0$label_noarch [$ble_build_info]"

  ble/edit/display-version/check:bash-completion
  ble/edit/display-version/check:fzf
  ble/edit/display-version/check:bash-preexec
  ble/edit/display-version/check:starship
  ble/edit/display-version/check:bash-it
  ble/edit/display-version/check:oh-my-bash
  ble/edit/display-version/check:sbp
  ble/edit/display-version/check:gitstatus
  ble/edit/display-version/check:zoxide
  ble/edit/display-version/check:atuin

  # locale
  local q=\'
  local ret='(unset)'
  local var line=${bold}locale$sgr0:
  for var in _ble_bash_LANG "${!_ble_bash_LC_@}" LANG "${!LC_@}"; do
    case $var in
    (LC_ALL|LC_COLLATE) continue ;;
    (LANG|LC_CTYPE|LC_MESSAGES|LC_NUMERIC|LC_TIME)
      [[ ${_ble_bash_LC_ALL-} ]] && continue ;;
    esac
    [[ ${!var+set} ]] || continue
    ble/string#quote-word "${!var}" "$quote_word_opts"
    line="$line $sgr2${var#_ble_bash_}$sgrV=$sgr0$ret"
  done
  lines[iline++]=$line

  # terminal
  ret='(unset)'
  [[ ${TERM+set} ]] && ble/string#quote-word "$TERM" "$quote_word_opts"
  local i line="${bold}terminal$sgr0: ${sgr2}TERM$sgrV=$sgr0$ret"
  line="$line ${sgr2}wcwidth$sgrV=$sgr0$bleopt_char_width_version-$bleopt_char_width_mode${bleopt_emoji_width:+/$bleopt_emoji_version-$bleopt_emoji_width+$bleopt_emoji_opts}"
  [[ ${MC_SID-} ]] && line="$line, ${sgrC}mc$sgr0 (${sgrV}MC_SID:$MC_SID$sgr0)"
  for i in "${!_ble_term_DA2R[@]}"; do
    line="$line, $sgrC${_ble_term_TERM[i]-unknown}$sgr0 ($sgrV${_ble_term_DA2R[i]}$sgr0)"
  done
  lines[iline++]=$line

  # shell options
  if ble/bin#freeze-utility-path diff && [[ -x $BASH ]]; then
    local _ble_local_tmpfile
    ble/util/assign/mktmp; local tmpfile1=$_ble_local_tmpfile
    ble/util/assign/mktmp; local tmpfile2=$_ble_local_tmpfile

    "$BASH" --norc --noprofile  -ic 'shopt -po; shopt' >| "$tmpfile1"
    { shopt -po; shopt; } >| "$tmpfile2"
    local diff awk_script='/^[-+].*[[:blank:]]on$/ {print $1} /^[-+]set -o .*$/ {print substr($0,1,1) $3}' IFS=$' \t\n'
    ble/util/assign-words diff 'ble/bin/diff -bwu "$tmpfile1" "$tmpfile2" | ble/bin/awk "$awk_script"'
    line="${bold}options$sgr0: ${diff[*]}"

    _ble_local_tmpfile=$tmpfile2 ble/util/assign/rmtmp
    _ble_local_tmpfile=$tmpfile1 ble/util/assign/rmtmp
  else
    line="${bold}options$sgr0: ${sgr2}SHELLOPTS$sgrV=$sgr0$SHELLOPTS"
    ((_ble_bash>=40100)) && line="$line, ${sgr2}BASHOPTS$sgrV=$sgr0$BASHOPTS"
  fi
  lines[iline++]=$line

  ble/widget/print "${lines[@]}"

  [[ $_ble_bash_options_adjusted ]] || ble/base/.restore-bash-options set shopt
}
function ble/widget/readline-dump-functions {
  ble-edit/content/clear-arg
  local ret
  ble/util/assign ret 'ble/builtin/bind -P'
  ble/widget/print "$ret"
}
function ble/widget/readline-dump-macros {
  ble-edit/content/clear-arg
  local ret
  ble/util/assign ret 'ble/builtin/bind -S'
  ble/widget/print "$ret"
}
function ble/widget/readline-dump-variables {
  ble-edit/content/clear-arg
  local ret
  ble/util/assign ret 'ble/builtin/bind -V'
  ble/widget/print "$ret"
}
function ble/widget/re-read-init-file {
  ble-edit/content/clear-arg

  local inputrc=$INPUTRC
  [[ $inputrc && -e $inputrc ]] || inputrc=~/.inputrc
  [[ -e $inputrc ]] || return 0
  ble/decode/read-inputrc "$inputrc"

  # Note: Return to "default" after reading #D1038
  _ble_builtin_bind_keymap=
}

_ble_edit_rlfunc_history=()
_ble_edit_rlfunc_history_edit=()
_ble_edit_rlfunc_history_dirt=()
_ble_edit_rlfunc_history_index=0
function ble/widget/execute-named-command/accept.hook {
  local ret rlfunc error=
  ble/string#split-words rlfunc "$1"
  if ble/util/assign error 'ble/builtin/bind/rlfunc2widget "$_ble_decode_keymap" "$rlfunc" 2>&1'; then
    ble/decode/widget/dispatch "$ret" "${rlfunc[@]:1}"
  elif [[ $error ]]; then
    ble/widget/bell "$error"
  fi
}
function ble/widget/execute-named-command {
  # If we are already in async-read-mode, execute-named-command is disabled.
  [[ $_ble_edit_async_read_prefix ]] && return 1

  ble/edit/async-read-mode 'ble/widget/execute-named-command/accept.hook'
  _ble_edit_async_read_before_widget=ble/edit/async-read-mode/empty-cancel.hook
  ble/history/set-prefix _ble_edit_rlfunc
  _ble_edit_PS1='!'
  _ble_syntax_lang=edit.named-command
  _ble_highlight_layer_list=(plain syntax region overwrite_mode)
  return 147
}

ble/util/autoload "$_ble_base/contrib/syntax/edit.named-command.bash" \
  ble/syntax:edit.named-command/initialize-ctx

# **** mark, kill, copy ****                                       @widget.mark

function ble/widget/overwrite-mode {
  ble-edit/content/clear-arg
  if [[ $_ble_edit_overwrite_mode ]]; then
    _ble_edit_overwrite_mode=
  else
    _ble_edit_overwrite_mode=1
  fi
}

function ble/widget/set-mark {
  ble-edit/content/clear-arg
  _ble_edit_mark=$_ble_edit_ind
  _ble_edit_mark_active=1
}
function ble/widget/kill-forward-text {
  ble-edit/content/clear-arg
  ((_ble_edit_ind>=${#_ble_edit_str})) && return 0
  ble-edit/content/push-kill-ring "${_ble_edit_str:_ble_edit_ind}" '' forward
  ble-edit/content/replace "$_ble_edit_ind" "${#_ble_edit_str}" ''
  ((_ble_edit_mark>_ble_edit_ind&&(_ble_edit_mark=_ble_edit_ind)))
}
function ble/widget/kill-backward-text {
  ble-edit/content/clear-arg
  ((_ble_edit_ind==0)) && return 0
  ble-edit/content/push-kill-ring "${_ble_edit_str::_ble_edit_ind}" '' backward
  ble-edit/content/replace 0 "$_ble_edit_ind" ''
  ((_ble_edit_mark=_ble_edit_mark<=_ble_edit_ind?0:_ble_edit_mark-_ble_edit_ind))
  _ble_edit_ind=0
}
function ble/widget/exchange-point-and-mark {
  ble-edit/content/clear-arg
  local m=$_ble_edit_mark p=$_ble_edit_ind
  _ble_edit_ind=$m _ble_edit_mark=$p
}

function ble/widget/@marked {
  local index=$_ble_edit_ind
  ble/decode/widget/dispatch "$@"
  if ((_ble_edit_ind!=index)); then
    _ble_edit_mark=$index
    _ble_edit_mark_active=S
    ble/decode/keymap/push selection
  fi
}

function ble/widget/selection/exit-default {
  ble/decode/keymap/pop
  ble/decode/widget/redispatch
  local ext=$?
  [[ $_ble_edit_mark_active == S && $_ble_decode_keymap != selection ]] &&
    _ble_edit_mark_active=
  return "$ext"
}

function ble-decode/keymap:selection/bind-shift {
  local marked=${1:+$1 }

  ble-decode/keymap:safe/.bind 'S-C-f'     "${marked}forward-char"
  ble-decode/keymap:safe/.bind 'S-right'   "${marked}forward-char"
  ble-decode/keymap:safe/.bind 'S-C-b'     "${marked}backward-char"
  ble-decode/keymap:safe/.bind 'S-left'    "${marked}backward-char"

  ble-decode/keymap:safe/.bind 'S-C-right' "${marked}forward-cword"
  ble-decode/keymap:safe/.bind 'M-F'       "${marked}forward-cword"
  ble-decode/keymap:safe/.bind 'M-S-f'     "${marked}forward-cword"
  ble-decode/keymap:safe/.bind 'S-C-left'  "${marked}backward-cword"
  ble-decode/keymap:safe/.bind 'M-B'       "${marked}backward-cword"
  ble-decode/keymap:safe/.bind 'M-S-b'     "${marked}backward-cword"

  ble-decode/keymap:safe/.bind 'M-S-right' "${marked}forward-sword"
  ble-decode/keymap:safe/.bind 'M-S-left'  "${marked}backward-sword"

  ble-decode/keymap:safe/.bind 'S-C-a'     "${marked}beginning-of-line"
  ble-decode/keymap:safe/.bind 'S-home'    "${marked}beginning-of-line"
  ble-decode/keymap:safe/.bind 'S-C-e'     "${marked}end-of-line"
  ble-decode/keymap:safe/.bind 'S-end'     "${marked}end-of-line"

  ble-decode/keymap:safe/.bind 'S-C-p'     "${marked}backward-line"
  ble-decode/keymap:safe/.bind 'S-up'      "${marked}backward-line"
  ble-decode/keymap:safe/.bind 'S-C-n'     "${marked}forward-line"
  ble-decode/keymap:safe/.bind 'S-down'    "${marked}forward-line"

  ble-decode/keymap:safe/.bind 'S-C-home'  "${marked}beginning-of-text"
  ble-decode/keymap:safe/.bind 'S-C-end'   "${marked}end-of-text"

  ble-decode/keymap:safe/.bind 'M-S-m'     "${marked}non-space-beginning-of-line"
  ble-decode/keymap:safe/.bind 'M-M'       "${marked}non-space-beginning-of-line"
}

function ble-decode/keymap:selection/define {
  ble-bind -f __default__ 'selection/exit-default'
  ble-bind -f __line_limit__ nop
  ble-decode/keymap:selection/bind-shift
}

## @fn ble/widget/.process-range-argument P0 P1; p0 p1 len ?
##   @param[in] P0 Specifies the endpoint of the range.
##   @param[in] P1 Specifies the endpoint of another range.
##   @param[out] p0 Returns the starting point of the range.
##   @param[out] p1 Returns the end point of the range.
##   @param[out] len Returns the length of the range.
##   @param[out] $?
##     Successful completion if the range has a finite length.
##     Returns 1 if the range is empty.
function ble/widget/.process-range-argument {
  p0=$1 p1=$2 len=${#_ble_edit_str}
  local pt
  ((
    p0>len?(p0=len):p0<0&&(p0=0),
    p1>len?(p1=len):p0<0&&(p1=0),
    p1<p0&&(pt=p1,p1=p0,p0=pt),
    (len=p1-p0)>0
  ))
}
## @fn ble/widget/.delete-range P0 P1 [opts]
function ble/widget/.delete-range {
  local p0 p1 len
  ble/widget/.process-range-argument "${@:1:2}" || return 1

  # delete
  if ((len)); then
    ble-edit/content/replace "$p0" "$p1" ''
    ((
      _ble_edit_ind>p1? (_ble_edit_ind-=len):
      _ble_edit_ind>p0&&(_ble_edit_ind=p0),
      _ble_edit_mark>p1? (_ble_edit_mark-=len):
      _ble_edit_mark>p0&&(_ble_edit_mark=p0)
    ))
  fi
  return 0
}
## @fn ble/widget/.kill-range P0 P1 [opts [kill_type]]
function ble/widget/.kill-range {
  local p0 p1 len
  ble/widget/.process-range-argument "${@:1:2}" || return 1

  # copy
  ble-edit/content/push-kill-ring "${_ble_edit_str:p0:len}" "$4" "$p0:$p1"

  # delete
  if ((len)); then
    ble-edit/content/replace "$p0" "$p1" ''
    ((
      _ble_edit_ind>p1? (_ble_edit_ind-=len):
      _ble_edit_ind>p0&&(_ble_edit_ind=p0),
      _ble_edit_mark>p1? (_ble_edit_mark-=len):
      _ble_edit_mark>p0&&(_ble_edit_mark=p0)
    ))
  fi
  return 0
}
## @fn ble/widget/.copy-range P0 P1 [opts [kill_type]]
function ble/widget/.copy-range {
  local p0 p1 len
  ble/widget/.process-range-argument "${@:1:2}" || return 1

  # copy
  ble-edit/content/push-kill-ring "${_ble_edit_str:p0:len}" "$4" "$p0:$p1"
}
## @fn ble/widget/.replace-range P0 P1 string
function ble/widget/.replace-range {
  local p0 p1 len
  ble/widget/.process-range-argument "${@:1:2}"
  local insert; ble-edit/content/replace-limited "$p0" "$p1" "$3"
  local inslen=${#insert} delta
  ((delta=inslen-len)) &&
    ((_ble_edit_ind>p1?(_ble_edit_ind+=delta):
      _ble_edit_ind>=p0&&(_ble_edit_ind=p0+inslen),
      _ble_edit_mark>p1?(_ble_edit_mark+=delta):
      _ble_edit_mark>p0&&(_ble_edit_mark=p0)))
  return 0
}
## @widget delete-region
##   Delete the area.
function ble/widget/delete-region {
  ble-edit/content/clear-arg
  ble/widget/.delete-range "$_ble_edit_mark" "$_ble_edit_ind"
  _ble_edit_mark_active=
}
## @widget kill-region
##   Cut out the area.
function ble/widget/kill-region {
  ble-edit/content/clear-arg
  ble/widget/.kill-range "$_ble_edit_mark" "$_ble_edit_ind"
  _ble_edit_mark_active=
}
## @widget copy-region
##   Transfer the area.
function ble/widget/copy-region {
  ble-edit/content/clear-arg
  ble/widget/.copy-range "$_ble_edit_mark" "$_ble_edit_ind"
  _ble_edit_mark_active=
}
## @widget delete-region-or widget
##   Delete the area when mark is active.
##   Executes the edit function widget at other times.
##   @param[in] widget
function ble/widget/delete-region-or {
  if [[ $_ble_edit_mark_active ]]; then
    ble/widget/delete-region
  else
    ble/decode/widget/dispatch "$@"
  fi
}
## @widget kill-region-or widget
##   Cuts the area when mark is active.
##   Executes the edit function widget at other times.
##   @param[in] widget
function ble/widget/kill-region-or {
  if [[ $_ble_edit_mark_active ]]; then
    ble/widget/kill-region
  else
    ble/decode/widget/dispatch "$@"
  fi
}
## @widget copy-region-or widget
##   Transcribes the area when mark is active.
##   Executes the edit function widget at other times.
##   @param[in] widget
function ble/widget/copy-region-or {
  if [[ $_ble_edit_mark_active ]]; then
    ble/widget/copy-region
  else
    ble/decode/widget/dispatch "$@"
  fi
}

## @widget yank
function ble/widget/yank {
  local arg; ble-edit/content/get-arg 1

  local nkill=${#_ble_edit_kill_ring[@]}
  if ((nkill==0)); then
    ble/widget/.bell 'no strings in kill-ring'
    _ble_edit_yank_index=
    return 1
  fi

  local index=$_ble_edit_kill_index
  local delta=$((arg-1))
  if ((delta)); then
    ((index=(index+delta)%nkill,
      index=(index+nkill)%nkill))
    _ble_edit_kill_index=$index
  fi

  local insert=${_ble_edit_kill_ring[index]}
  _ble_edit_yank_index=$index
  if [[ $insert ]]; then
    ble-edit/content/replace-limited "$_ble_edit_ind" "$_ble_edit_ind" "$insert"
    ((_ble_edit_mark=_ble_edit_ind,
      _ble_edit_ind+=${#insert}))
    _ble_edit_mark_active=
  fi
}

_ble_edit_yank_index=
function ble/edit/yankpop.impl {
  local arg=$1
  local nkill=${#_ble_edit_kill_ring[@]}
  ((_ble_edit_yank_index=(_ble_edit_yank_index+arg)%nkill,
    _ble_edit_yank_index=(_ble_edit_yank_index+nkill)%nkill))
  local insert=${_ble_edit_kill_ring[_ble_edit_yank_index]}
  ble-edit/content/replace-limited "$_ble_edit_mark" "$_ble_edit_ind" "$insert"
  ((_ble_edit_ind=_ble_edit_mark+${#insert}))
}
function ble/widget/yank-pop {
  local opts=$1
  local arg; ble-edit/content/get-arg 1
  if ! [[ $_ble_edit_yank_index && ${LASTWIDGET%%' '*} == ble/widget/yank ]]; then
    ble/widget/.bell
    return 1
  fi

  [[ :$opts: == *:backward:* ]] && ((arg=-arg))

  ble/edit/yankpop.impl "$arg"
  _ble_edit_mark_active=insert
  ble/decode/keymap/push yankpop
}
function ble/widget/yankpop/next {
  local arg; ble-edit/content/get-arg 1
  ble/edit/yankpop.impl "$arg"
}
function ble/widget/yankpop/prev {
  local arg; ble-edit/content/get-arg 1
  ble/edit/yankpop.impl "$((-arg))"
}
function ble/widget/yankpop/exit {
  ble/decode/keymap/pop
  _ble_edit_mark_active=
}
function ble/widget/yankpop/cancel {
  ble-edit/content/replace "$_ble_edit_mark" "$_ble_edit_ind" ''
  _ble_edit_ind=$_ble_edit_mark
  ble/widget/yankpop/exit
}
function ble/widget/yankpop/exit-default {
  ble/widget/yankpop/exit
  ble/decode/widget/redispatch
}
function ble-decode/keymap:yankpop/define {
  ble-decode/keymap:safe/bind-arg yankpop/exit-default
  ble-bind -f __default__ 'yankpop/exit-default'
  ble-bind -f __line_limit__ nop
  ble-bind -f 'C-g'       'yankpop/cancel'
  ble-bind -f 'C-x C-g'   'yankpop/cancel'
  ble-bind -f 'C-M-g'     'yankpop/cancel'
  ble-bind -f 'M-y'       'yankpop/next'
  ble-bind -f 'M-S-y'     'yankpop/prev'
  ble-bind -f 'M-Y'       'yankpop/prev'
}

# **** bell ****                                                     @edit.bell

_ble_term_DECSCNM_state=

function ble/widget/.bell {
  [[ :$bleopt_edit_bell: == *:vbell:* ]] && ble/term/visible-bell "$1"
  [[ :$bleopt_edit_bell: == *:abell:* ]] && ble/term/audible-bell

  if [[ :$bleopt_edit_bell: == *:visual:* ]]; then
    ble/util/buffer $'\e[?5h'
    ble/util/buffer.flush
    _ble_term_DECSCNM_state=1
    if ble/is-function ble/util/idle.push; then
      ble/util/idle.push --sleep=50 ble/widget/.bell/.clear-DECSCNM
    else
      ble/util/msleep 50
      ble/widget/.bell/.clear-DECSCNM
    fi
  fi

  return 0
}

function ble/widget/.bell/.clear-DECSCNM {
  [[ $_ble_term_DECSCNM_state ]] || return "$?"
  _ble_term_DECSCNM_state=
  ble/util/buffer $'\e[?5l'
  ble/util/buffer.flush
}

# blehook/declare widget_bell (defined in def.sh)
function ble/widget/bell {
  ble-edit/content/clear-arg
  _ble_edit_mark_active=
  _ble_edit_arg=
  blehook/invoke widget_bell
  ble/widget/.bell "$1"
}

function ble/widget/nop { return 0; }

# **** insert ****                                                 @edit.insert

function ble/widget/insert-string {
  local IFS=$_ble_term_IFS
  local content="$*"
  local arg; ble-edit/content/get-arg 1
  if ((arg<0)); then
    ble/widget/.bell "negative repetition number $arg"
    return 1
  elif ((arg==0)); then
    return 0
  elif ((arg>1)); then
    local ret; ble/string#repeat "$content" "$arg"; content=$ret
  fi
  ble/widget/.insert-string "$content"
}
function ble/widget/.insert-string {
  local insert=$1
  [[ $insert ]] || return 1

  ble-edit/content/replace-limited "$_ble_edit_ind" "$_ble_edit_ind" "$insert"
  local dx=${#insert}
  ((
    _ble_edit_mark>_ble_edit_ind&&(_ble_edit_mark+=dx),
    _ble_edit_ind+=dx
  ))
  _ble_edit_mark_active=
}

function ble/edit/get-clipboard {
  builtin unset -f "$FUNCNAME"

  # One can find various ways to get the clipboard content in Ref. [1].
  # [1] https://stackoverflow.com/questions/5130968
  if [[ -c /dev/clipboard ]]; then
    # Cygwin and MSYS2 has a character device "/dev/clipboard".
    function ble/edit/get-clipboard { ble/util/readfile clipboard /dev/clipboard; }
  elif ble/base/is-wsl && ble/bin#freeze-utility-path powershell.exe; then
    # WSL system may use "powershell.exe" if it exists
    function ble/edit/get-clipboard { ble/util/assign clipboard 'ble/bin/powershell.exe -command Get-Clipboard 2>/dev/null'; }
  elif ble/bin#freeze-utility-path pbpaste; then
    # macOS seems to have "pbpaste" command.
    function ble/edit/get-clipboard { ble/util/assign clipboard 'ble/bin/pbpaste 2>/dev/null'; }
  elif ble/bin#freeze-utility-path xclip; then
    # Linux with X Window system may also have the "xlip" command.
    function ble/edit/get-clipboard { ble/util/assign clipboard 'ble/bin/xclip -selection clipboard -o 2>/dev/null'; }
  elif ble/bin#freeze-utility-path xsel; then
    # Linux with X Window system may have the "xsel" command.
    function ble/edit/get-clipboard { ble/util/assign clipboard 'ble/bin/xsel --clipboard --output 2>/dev/null'; }
  elif ble/bin#freeze-utility-path wxpaste; then
    # wmaker-utils had "wxpaste", but it seems to have failed in recent versions
    # of Linux?
    # [2] https://askubuntu.com/questions/110347
    function ble/edit/get-clipboard { ble/util/assign clipboard 'ble/bin/wxpaste 2>/dev/null'; }
  elif ble/bin#freeze-utility-path xcb; then
    # The xcb command seems to extract the cut buffer in the present xterm.
    # [3] https://askubuntu.com/questions/237942
    function ble/edit/get-clipboard { ble/util/assign clipboard 'ble/bin/xcb -p 0 2>/dev/null'; }
  elif [[ ${TMUX-} && ${TMUX_PANE-} ]] && ble/bin#freeze-utility-path tmux; then
    # Tmux seems to have a similar mechanism of the paste buffer as GNU screen
    # [4], though Ref. [4] describes the solution for the opposite purpose of
    # setting the buffer.  The way to extract the content of the buffer using a
    # command is described in Ref. [5].
    #
    # [4] https://stackoverflow.com/questions/35509163
    # [5] https://unix.stackexchange.com/questions/15715
    function ble/edit/get-clipboard { ble/util/assign clipboard 'ble/bin/tmux save-buffer - 2>/dev/null'; }
  elif [[ ${STY-} && ${WINDOW-} ]] && ble/bin#freeze-utility-path screen; then
    # If we are inside GNU Screen, we might try to read a text from the
    # bufferfile for the paste buffer [6-8].  The default location of the
    # bufferfile seems to be "/tmp/screen-exchange", though a user might
    # configure it to another directory.  The user can press [C-a >] to save the
    # current paste buffer content to "/tmp/screen-exchange".  Then, one can read
    # its content using "ble/edit/get-clipboard".
    #
    # [6] https://www.gnu.org/software/screen/manual/html_node/Screen-Exchange.html
    # [7] https://superuser.com/questions/183051
    # [8] https://qiita.com/k_ui/items/d0ae1e7b4d553830ccb9
    function ble/edit/get-clipboard { ble/util/readfile clipboard /tmp/screen-exchange; }
  else
    function ble/edit/get-clipboard { return 1; }
  fi
  ble/edit/get-clipboard "$@"
}

function ble/widget/paste-from-clipboard {
  local clipboard
  if ble/edit/get-clipboard; then
    ble/widget/insert-string "$clipboard"
    return 0
  else
    ble/widget/.bell
    return 1
  fi
}

## @fn ble/widget/insert-arg.impl beg end index delta nth
##   @param[in] beg end
##     Specify the replacement range.
##   @param[in] index
##     Specify the starting history number.
##   @param[in] delta
##     Specify the (minimum) amount of movement.
##   @param[in] nth
##     Specify word specifiers such as '$', '^', n, etc.
##
##   @var _ble_edit_lastarg_index
##     This is the history number of the last argument inserted.
##   @var _ble_edit_lastarg_delta
##     This is the amount of movement when it was last inserted.
##     Used to determine the direction of movement when repeatedly called.
##   @var _ble_edit_lastarg_nth
##     The word specifier when inserted last.
##
_ble_edit_lastarg_index=
_ble_edit_lastarg_delta=
_ble_edit_lastarg_nth=
function ble/widget/insert-arg.impl {
  local beg=$1 end=$2 index=$3 delta=$4 nth=$5
  ((delta)) || delta=1

  ble/history/initialize
  local hit= lastarg=
  local decl=$(
    local original=${_ble_edit_str:beg:end-beg}
    local count=; ((delta>0)) && count=_ble_history_COUNT
    while ((1)); do
      # index = next history index to check
      if ((delta>0)); then
        ((index+1>=count)) && break
        ((index+=delta,delta=1))
        ((index>=count&&(index=count-1)))
      else
        ((index-1<0)) && break
        ((index+=delta,delta=-1))
        ((index<0&&(index=0)))
      fi

      local entry; ble/history/get-edited-entry "$index"
      builtin history -s -- "$entry"
      local ret
      if ble/edit/histexpand '!!:'"$nth" && [[ $ret != "$original" ]]; then
        hit=1 lastarg=$ret
        ble/util/declare-print-definitions hit lastarg
        break
      fi
    done
    _ble_edit_lastarg_index=$index
    _ble_edit_lastarg_delta=$delta
    _ble_edit_lastarg_nth=$nth
    ble/util/declare-print-definitions \
      _ble_edit_lastarg_index \
      _ble_edit_lastarg_delta \
      _ble_edit_lastarg_nth
  )
  builtin eval -- "$decl"

  if [[ $hit ]]; then
    local insert; ble-edit/content/replace-limited "$beg" "$end" "$lastarg"
    ((_ble_edit_mark=beg,_ble_edit_ind=beg+${#insert}))
    return 0
  else
    ble/widget/.bell
    return 1
  fi
}
function ble/widget/insert-nth-argument {
  ble/history/initialize
  local arg; ble-edit/content/get-arg '^'
  local beg=$_ble_edit_ind end=$_ble_edit_ind
  local index=$_ble_history_INDEX
  local delta=-1 nth=$arg
  ble/widget/insert-arg.impl "$beg" "$end" "$index" "$delta" "$nth"
}
function ble/widget/insert-last-argument {
  ble/history/initialize
  local arg; ble-edit/content/get-arg '$'
  local beg=$_ble_edit_ind end=$_ble_edit_ind
  local index=$_ble_history_INDEX
  local delta=-1 nth=$arg
  ble/widget/insert-arg.impl "$beg" "$end" "$index" "$delta" "$nth" || return "$?"
  _ble_edit_mark_active=insert
  ble/decode/keymap/push lastarg
}
function ble/widget/lastarg/next {
  local arg; ble-edit/content/get-arg 1
  local beg=$_ble_edit_mark
  local end=$_ble_edit_ind
  local index=$_ble_edit_lastarg_index

  local delta
  if [[ $arg ]]; then
    delta=$((-arg))
  else
    ((delta=_ble_edit_lastarg_delta>=0?1:-1))
  fi

  local nth=$_ble_edit_lastarg_nth
  ble/widget/insert-arg.impl "$beg" "$end" "$index" "$delta" "$nth"
}
function ble/widget/lastarg/exit {
  ble/decode/keymap/pop
  _ble_edit_mark_active=
}
function ble/widget/lastarg/cancel {
  ble-edit/content/replace "$_ble_edit_mark" "$_ble_edit_ind" ''
  _ble_edit_ind=$_ble_edit_mark
  ble/widget/lastarg/exit
}
function ble/widget/lastarg/exit-default {
  ble/widget/lastarg/exit
  ble/decode/widget/redispatch
}
function ble/highlight/layer:region/mark:insert/get-face {
  face=region_insert
}

function ble-decode/keymap:lastarg/define {
  ble-decode/keymap:safe/bind-arg lastarg/exit-default

  ble-bind -f __default__ 'lastarg/exit-default'
  ble-bind -f __line_limit__ nop
  ble-bind -f 'C-g'       'lastarg/cancel'
  ble-bind -f 'C-x C-g'   'lastarg/cancel'
  ble-bind -f 'C-M-g'     'lastarg/cancel'
  ble-bind -f 'M-.'       'lastarg/next'
  ble-bind -f 'M-_'       'lastarg/next'
}

## @widget self-insert
##   Insert characters.
##
##   @var[in] _ble_edit_arg
##     Specify the number of repetitions.
##
##   @var[in] ble_widget_self_insert_opts
##     Specifies a colon-separated list of settings.
##
##     nolineext does not extend line length in overwrite mode.
##     If the line length is insufficient, cancel the operation.
## Assume insertion using vi.sh's r and gr.
##

function ble/widget/self-insert/.get-code {
  if ((${#KEYS[@]})); then
    code=${KEYS[${#KEYS[@]}-1]}
    local flag=$((code&_ble_decode_MaskFlag))
    local char=$((code&_ble_decode_MaskChar))
    if ((flag==0&&char<_ble_decode_FunctionKeyBase)); then
      code=$char
      return 0
    elif ((flag==_ble_decode_Ctrl&&(char==63||91<=char&&char<=122)&&(char&0x1F)!=0)); then
      ((char=char==63?127:char&0x1F))
      code=$char
      return 0
    fi
  fi

  if ((${#CHARS[@]})); then
    code=${CHARS[${#CHARS[@]}-1]}
    return 0
  fi

  code=0
  return 1
}

function ble/widget/self-insert {
  local code; ble/widget/self-insert/.get-code
  ((code==0)) && return 0

  # Note: Bash 3.0 has a problem handling ^? (DEL), so
  #   Just ignore it like ^@ (NUL) #D1093
  ((code==127&&_ble_bash<30100)) && return 0

  local ibeg=$_ble_edit_ind iend=$_ble_edit_ind
  local ret ins; ble/util/c2s "$code"; ins=$ret

  local arg; ble-edit/content/get-arg 1
  if ((arg<0)); then
    ble/widget/.bell "negative repetition number $arg"
    return 1
  elif ((arg==0)) || [[ ! $ins ]]; then
    arg=0 ins=
  elif ((arg>1)); then
    ble/string#repeat "$ins" "$arg"; ins=$ret
  fi
  # Note: arg is not necessarily the number of characters in ins at this point.
  #   If there is no corresponding character in the current LC_CTYPE, it will be converted to \uXXXX etc.

  if [[ $bleopt_delete_selection_mode && $_ble_edit_mark_active ]]; then
    # Replace selection.
    ((_ble_edit_mark<_ble_edit_ind?(ibeg=_ble_edit_mark):(iend=_ble_edit_mark),
      _ble_edit_ind=ibeg))
    ((arg==0&&ibeg==iend)) && return 0
  elif [[ $_ble_edit_overwrite_mode ]] && ((code!=10&&code!=9)); then
    ((arg==0)) && return 0

    local removed_width
    if [[ $_ble_edit_overwrite_mode == R ]]; then
      local removed_text=${_ble_edit_str:ibeg:arg}
      removed_text=${removed_text%%[$'\n\t']*}
      removed_width=${#removed_text}
      ((iend+=removed_width))
    else
      # When in overwrite mode, replaces existing characters considering Unicode character width.
      # *Even if there is no corresponding character in the current LC_CTYPE, to prevent unintended behavior,
      #   Delete with the character width assumed to be compatible.
      # TODO: TAB is treated as "^I" in c2w-edit, but it actually depends on the current column.
      # Should I calculate it?
      local ret w; ble/util/c2w-edit "$code"; w=$((arg*ret))

      local iN=${#_ble_edit_str}
      for ((removed_width=0;removed_width<w&&iend<iN;iend++)); do
        local c1 w1
        ble/util/s2c "${_ble_edit_str:iend:1}"; c1=$ret
        [[ $c1 == 0 || $c1 == 10 || $c1 == 9 ]] && break
        ble/util/c2w-edit "$c1"; w1=$ret
        ((removed_width+=w1))
      done

      ((removed_width>w)) && ins=$ins${_ble_string_prototype::removed_width-w}
    fi

    # This is a variable set with r gr in vi.sh
    if [[ :$ble_widget_self_insert_opts: == *:nolineext:* ]]; then
      if ((removed_width<arg)); then
        ble/widget/.bell
        return 0
      fi
    fi
  fi

  # Command line character limit
  local insert; ble-edit/content/replace-limited "$ibeg" "$iend" "$ins"
  ((_ble_edit_ind+=${#insert},
    _ble_edit_mark>ibeg&&(
      _ble_edit_mark<iend?(
        _ble_edit_mark=_ble_edit_ind
      ):(
        _ble_edit_mark+=${#insert}-(iend-ibeg)))))
  _ble_edit_mark_active=
  return 0
}

function ble/widget/batch-insert.progress {
  ((index%${1:-257}==0&&N>=2000)) || return 1
  local ble_batch_insert_index=$index
  local ble_batch_insert_count=$N
  builtin eval -- "$_ble_decode_show_progress_hook"
}
function ble/widget/batch-insert {
  local -a chars; chars=("${KEYS[@]}")

  local -a KEYS=()
  local index=0 N=${#chars[@]}
  if [[ $_ble_edit_overwrite_mode ]]; then
    while ((index<N&&_ble_edit_ind<${#_ble_edit_str})); do
      KEYS=${chars[index]} ble/widget/self-insert
      ((index++))
    done
    ((index<N)) || return 0
  fi

  # Command line character limit
  if [[ $bleopt_line_limit_type == discard ]]; then
    local limit=$((bleopt_line_limit_length))
    if ((limit&&${#_ble_edit_str}+N-index>=limit)); then
      chars=("${chars[@]::limit-${#_ble_edit_str}}")
      N=${#chars[@]}
      ((index<N)) || { ble/widget/.bell; return 1; }
    fi
  fi

  while ((index<N)) && [[ $_ble_edit_arg || $_ble_edit_mark_active ]]; do
    KEYS=${chars[index]} ble/widget/self-insert
    ((index++))
    ble/widget/batch-insert.progress
  done

  if ((index<N)); then
    # Unset NUL and convert in batch
    local index0=$index ret ins
    for ((;index<N;index++)); do
      ((chars[index])) || builtin unset -v 'chars[index]'
      ble/widget/batch-insert.progress 2357
    done
    ble/util/chars2s "${chars[@]:index0}"; ins=$ret
    ble/widget/insert-string "$ins"
  fi

  ble-edit/content/check-limit truncate
}

# quoted insert
function ble/widget/quoted-insert-char.hook {
  ble/widget/self-insert
}
function ble/widget/quoted-insert-char {
  _ble_edit_mark_active=
  _ble_decode_char__hook=ble/widget/quoted-insert-char.hook
  return 147
}
function ble/widget/quoted-insert.hook {
  local flag=$((KEYS[0]&_ble_decode_MaskFlag))
  local char=$((KEYS[0]&_ble_decode_MaskChar))
  if ((flag==0&&char<_ble_decode_FunctionKeyBase)); then
    ble/widget/self-insert
  elif ((flag==_ble_decode_Ctrl&&(char==63||91<=char&&char<=122)&&(char&0x1F)!=0)); then
    # C-x (other than C-@) converts and inserts control characters.
    ((char=char==63?127:char&0x1F))
    local -a KEYS; KEYS=("$char")
    ble/widget/self-insert
  else
    if ((${#CHARS[@]}==0)); then
      local ret
      ble/decode/keys2chars "${KEYS[@]}"
      local -a CHARS; CHARS=("${ret[@]}")
    fi
    local -a KEYS; KEYS=("${CHARS[@]}")
    ble/widget/batch-insert
  fi
}
function ble/widget/quoted-insert {
  _ble_edit_mark_active=
  _ble_decode_key__hook=ble/widget/quoted-insert.hook
  return 147
}

_ble_edit_bracketed_paste=()
_ble_edit_bracketed_paste_proc=
_ble_edit_bracketed_paste_count=0
function ble/widget/bracketed-paste {
  ble-edit/content/clear-arg
  if [[ ${TERM%%-*} == eterm ]]; then
    # Note (#D2087): Only \e[200~ (paste_begin) is accepted as input in eterm.
    # \e[201~ (paste_end) doesn't come (Emacs 28.2). this is inside
    # This occurs even if bracketed-paste is not enabled. as a result
    # It gets stuck in bracketed-paste mode and becomes visually unresponsive. Measures and
    # It does not enter bracketed-paste mode inside eterm.
    return 0
  fi
  _ble_edit_mark_active=
  _ble_edit_bracketed_paste=()
  _ble_edit_bracketed_paste_count=0
  _ble_edit_bracketed_paste_proc=ble/widget/bracketed-paste.proc
  _ble_decode_char__hook=ble/widget/bracketed-paste.hook
  return 147
}
function ble/widget/bracketed-paste.hook/check-end {
  local is_end= chars=
  if ((_ble_edit_bracketed_paste_count>=5)); then
    IFS=: builtin eval '_ble_edit_bracketed_paste=("${_ble_edit_bracketed_paste[*]}")'
    chars=:$_ble_edit_bracketed_paste
    if [[ $chars == *:50:48:49:126 ]]; then
      if [[ $chars == *:27:91:50:48:49:126 ]]; then # ESC [ 2 0 1 ~
        chars=${chars%:27:91:50:48:49:126} is_end=1
      elif [[ $chars == *:155:50:48:49:126 ]]; then # CSI 2 0 1 ~
        chars=${chars%:155:50:48:49:126} is_end=1
      fi
    fi
  fi

  [[ $is_end ]] || return 1

  _ble_decode_char__hook=
  chars=:${chars//:/::}:
  chars=${chars//:13::10:/:10:} # CR LF -> LF
  chars=${chars//:13:/:10:} # CR -> LF
  ble/string#split-words chars "${chars//:/ }"

  local proc=$_ble_edit_bracketed_paste_proc
  _ble_edit_bracketed_paste_proc=
  [[ $proc ]] && builtin eval -- "$proc \"\${chars[@]}\""
  return 0
}
function ble/widget/bracketed-paste.hook {
  ((_ble_edit_bracketed_paste_count%1000==0)) &&
    IFS=: builtin eval '_ble_edit_bracketed_paste=("${_ble_edit_bracketed_paste[*]}")' # contract

  _ble_edit_bracketed_paste[_ble_edit_bracketed_paste_count++]=$1
  (($1==126)) && ble/widget/bracketed-paste.hook/check-end && return 0

  # Extract the next character in ble-decode-char and process it here as much as possible.
  if ((!_ble_debug_keylog_enabled)) && [[ ! $_ble_decode_keylog_chars_enabled ]]; then
    local char
    while ble/decode/char-hook/next-char; do
      _ble_edit_bracketed_paste[_ble_edit_bracketed_paste_count++]=$char
      ((char==126)) && ble/widget/bracketed-paste.hook/check-end && return 0
    done
  fi

  _ble_decode_char__hook=ble/widget/bracketed-paste.hook
  return 147
}
function ble/widget/bracketed-paste.proc {
  local -a KEYS; KEYS=("$@")
  ble/widget/batch-insert
}


function ble/widget/transpose-chars {
  local arg; ble-edit/content/get-arg ''
  if ((arg==0)); then
    [[ ! $arg ]] && ble-edit/content/eolp &&
      ((_ble_edit_ind>0&&_ble_edit_ind--))
    arg=1
  fi

  local p q r
  if ((arg>0)); then
    ((p=_ble_edit_ind-1,
      q=_ble_edit_ind,
      r=_ble_edit_ind+arg))
  else # arg<0
    ((p=_ble_edit_ind-1+arg,
      q=_ble_edit_ind,
      r=_ble_edit_ind+1))
  fi

  if ((p<0||${#_ble_edit_str}<r)); then
    ((_ble_edit_ind=arg<0?0:${#_ble_edit_str}))
    ble/widget/.bell
    return 1
  fi

  local a=${_ble_edit_str:p:q-p}
  local b=${_ble_edit_str:q:r-q}
  ble-edit/content/replace "$p" "$r" "$b$a"
  ((_ble_edit_ind+=arg))
  return 0
}

# 
# **** delete-char ****                                            @edit.delete

function ble/widget/.delete-backward-char {
  local a=${1:-1}
  if ((_ble_edit_ind-a<0)); then
    return 1
  fi

  local ins=
  if [[ $_ble_edit_overwrite_mode ]]; then
    local next=${_ble_edit_str:_ble_edit_ind:1}
    if [[ $next && $next != [$'\n\t'] ]]; then
      if [[ $_ble_edit_overwrite_mode == R ]]; then
        local w=$a
      else
        local w=0 ret i
        for ((i=0;i<a;i++)); do
          ble/util/s2c "${_ble_edit_str:_ble_edit_ind-a+i:1}"
          # TODO: TAB is treated as "^I" in c2w-edit, but it is actually
          # Should I calculate accordingly?
          ble/util/c2w-edit "$ret"
          ((w+=ret))
        done
      fi
      if ((w)); then
        local ret; ble/string#repeat ' ' "$w"; ins=$ret
        ((_ble_edit_mark>=_ble_edit_ind&&(_ble_edit_mark+=w)))
      fi
    fi
  fi

  ble-edit/content/replace "$((_ble_edit_ind-a))" "$_ble_edit_ind" "$ins"
  ((_ble_edit_ind-=a,
    _ble_edit_ind+a<_ble_edit_mark?(_ble_edit_mark-=a):
    _ble_edit_ind<_ble_edit_mark&&(_ble_edit_mark=_ble_edit_ind)))
  return 0
}

function ble/widget/.delete-char {
  local a=${1:-1}
  if ((a>0)); then
    # delete-forward-char
    if ((${#_ble_edit_str}<_ble_edit_ind+a)); then
      return 1
    else
      ble-edit/content/replace "$_ble_edit_ind" "$((_ble_edit_ind+a))" ''
    fi
  elif ((a<0)); then
    # delete-backward-char
    ble/widget/.delete-backward-char "$((-a))"; return "$?"
  else
    # delete-forward-backward-char
    if ((${#_ble_edit_str}==0)); then
      return 1
    elif ((_ble_edit_ind<${#_ble_edit_str})); then
      ble-edit/content/replace "$_ble_edit_ind" "$((_ble_edit_ind+1))" ''
    else
      _ble_edit_ind=${#_ble_edit_str}
      ble/widget/.delete-backward-char 1; return "$?"
    fi
  fi

  ((_ble_edit_mark>_ble_edit_ind&&_ble_edit_mark--))
  return 0
}
function ble/widget/delete-forward-char {
  local arg; ble-edit/content/get-arg 1
  ((arg==0)) && return 0
  ble/widget/.delete-char "$arg" || ble/widget/.bell
}
function ble/widget/delete-backward-char {
  local arg; ble-edit/content/get-arg 1
  ((arg==0)) && return 0

  # keymap/vi.sh (white widget)
  [[ $_ble_decode_keymap == vi_imap ]] && ble/keymap:vi/undo/add more

  ble/widget/.delete-char "$((-arg))" || ble/widget/.bell

  # keymap/vi.sh (white widget)
  [[ $_ble_decode_keymap == vi_imap ]] && ble/keymap:vi/undo/add more
}

_ble_edit_exit_count=0
function ble/widget/exit {
  ble-edit/content/clear-arg

  if [[ $WIDGET == "$LASTWIDGET" ]]; then
    ((_ble_edit_exit_count++))
  else
    _ble_edit_exit_count=1
  fi

  local ret; ble-edit/eval-IGNOREEOF
  if ((_ble_edit_exit_count<=ret)); then
    local remain=$((ret-_ble_edit_exit_count+1))
    ble/widget/.bell 'IGNOREEOF'
    ble/widget/print "IGNOREEOF($remain): Use \"exit\" to leave the shell."
    return 0
  fi

  local opts=$1
  ((_ble_bash>=40000)) && shopt -q checkjobs &>/dev/null && opts=$opts:checkjobs

  if [[ $bleopt_allow_exit_with_jobs ]]; then
    local ret
    if ble/util/assign ret 'compgen -A stopped -- ""' 2>/dev/null; [[ $ret ]]; then
      opts=$opts:twice
    elif [[ :$opts: == *:checkjobs:* ]]; then
      if ble/util/assign ret 'compgen -A running -- ""' 2>/dev/null; [[ $ret ]]; then
        opts=$opts:twice
      fi
    else
      opts=$opts:force
    fi
  fi

  if ! [[ :$opts: == *:force:* || :$opts: == *:twice:* && _ble_edit_exit_count -ge 2 ]]; then
    # If job remains
    local joblist
    ble/util/joblist
    if ((${#joblist[@]})); then
      ble/widget/.bell "exit: There are remaining jobs."
      local q=\' Q="'\''" message=
      if [[ :$opts: == *:twice:* ]]; then
        message='There are remaining jobs. Input the same key to exit the shell anyway.'
      else
        message='There are remaining jobs. Use "exit" to leave the shell.'
      fi
      local ret
      ble/edit/marker#instantiate "$message" non-empty
      ble/widget/internal-command "ble/util/print '${ret//$q/$Q}'; jobs"
      return "$?"
    fi
  elif [[ :$opts: == *:checkjobs:* ]]; then
    local joblist
    ble/util/joblist
    ((${#joblist[@]})) && printf '%s\n' "${#joblist[@]}"
  fi

  #_ble_edit_detach_flag=exit

  #ble/term/visible-bell ' Bye!! ' # When you issue vbell at the end, a temporary file remains
  _ble_edit_line_disabled=1 ble/textarea#render

  # Note: When bleopt_syntax_debug=1, info is set in ble/textarea#render, so
  #   This must come after ble/textarea#render.
  ble/edit/enter-command-layout # #D1800 pair=leave-command-layout

  local -a DRAW_BUFF=()
  ble/canvas/panel#goto.draw "$_ble_textarea_panel" "$_ble_textarea_gendx" "$_ble_textarea_gendy"
  ble/canvas/bflush.draw
  ble/edit/marker#instantiate-config exec_exit_mark
  ble/util/buffer.print "$ret"
  ble/util/buffer.flush

  # Note: Even if jobs are remaining, we forcibly terminate the session.
  # Note (#D2217): To properly handle the redirections in the EXIT trap, we
  # here use ble/builtin/exit instead of the raw "builtin exit 0". We here set
  # _ble_builtin_exit_processing=1 to skip checking the remaining jobs.
  _ble_builtin_exit_processing=1 ble/builtin/exit 0
  ble/edit/leave-command-layout # #D1800 pair=enter-command-layout
  return 1
}
function ble/widget/delete-forward-char-or-exit {
  if [[ $_ble_edit_str ]]; then
    ble/widget/delete-forward-char
  else
    ble/widget/exit
  fi
}
function ble/widget/delete-forward-backward-char {
  ble-edit/content/clear-arg
  ble/widget/.delete-char 0 || ble/widget/.bell
}
function ble/widget/delete-forward-char-or-list {
  local right=${_ble_edit_str:_ble_edit_ind}
  if [[ ! $right || $right == $'\n'* ]]; then
    ble/widget/complete show_menu
  else
    ble/widget/delete-forward-char
  fi
}

function ble/widget/delete-horizontal-space {
  local arg; ble-edit/content/get-arg ''

  local b=0 rex=$'[ \t]+$'
  [[ ${_ble_edit_str::_ble_edit_ind} =~ $rex ]] &&
    b=${#BASH_REMATCH}

  local a=0 rex=$'^[ \t]+'
  [[ ! $arg && ${_ble_edit_str:_ble_edit_ind} =~ $rex ]] &&
    a=${#BASH_REMATCH}

  ble/widget/.delete-range "$((_ble_edit_ind-b))" "$((_ble_edit_ind+a))"
}

# 
# **** cursor move ****                                            @edit.cursor

function ble/widget/.forward-char {
  ((_ble_edit_ind+=${1:-1}))
  if ((_ble_edit_ind>${#_ble_edit_str})); then
    _ble_edit_ind=${#_ble_edit_str}
    return 1
  elif ((_ble_edit_ind<0)); then
    _ble_edit_ind=0
    return 1
  fi
}
function ble/widget/forward-char {
  local arg; ble-edit/content/get-arg 1
  ((arg==0)) && return 0
  ble/widget/.forward-char "$arg" || ble/widget/.bell
}
function ble/widget/backward-char {
  local arg; ble-edit/content/get-arg 1
  ((arg==0)) && return 0
  ble/widget/.forward-char "$((-arg))" || ble/widget/.bell
}

_ble_edit_character_search_arg=
function ble/widget/character-search-forward {
  local arg; ble-edit/content/get-arg 1
  _ble_edit_character_search_arg=$arg
  _ble_edit_mark_active=
  _ble_decode_char__hook=ble/widget/character-search.hook
}
function ble/widget/character-search-backward {
  local arg; ble-edit/content/get-arg 1
  ((_ble_edit_character_search_arg=-arg))
  _ble_edit_mark_active=
  _ble_decode_char__hook=ble/widget/character-search.hook
}
function ble/widget/character-search.hook {
  local char=${KEYS[0]}
  local ret; ble/util/c2s "${KEYS[0]}"; local c=$ret
  [[ $c ]] || return 1 # Note: Ignored when C-@
  local arg=$_ble_edit_character_search_arg
  if ((arg>0)); then
    local right=${_ble_edit_str:_ble_edit_ind+1}
    if ble/string#index-of "$right" "$c" "$arg"; then
      ((_ble_edit_ind=_ble_edit_ind+1+ret))
    elif ble/string#last-index-of "$right" "$c"; then
      ble/widget/.bell "${arg}th character not found"
      ((_ble_edit_ind=_ble_edit_ind+1+ret))
    else
      ble/widget/.bell 'character not found'
      return 1
    fi
  elif ((arg<0)); then
    local left=${_ble_edit_str::_ble_edit_ind}
    if ble/string#last-index-of "$left" "$c" "$((-arg))"; then
      _ble_edit_ind=$ret
    elif ble/string#index-of "$left" "$c"; then
      ble/widget/.bell "$((-arg))th last character not found"
      _ble_edit_ind=$ret
    else
      ble/widget/.bell 'character not found'
      return 1
    fi
  fi
  return 0
}

## @fn ble/widget/.locate-forward-byte delta
##   @param[in] delta
##   @var[in,out] index
function ble/widget/.locate-forward-byte {
  local delta=$1 ret
  if ((delta==0)); then
    return 0
  elif ((delta>0)); then
    local right=${_ble_edit_str:index:delta}
    local rlen=${#right}
    ble/util/strlen "$right"; local rsz=$ret
    if ((delta>=rsz)); then
      ((index+=rlen))
      ((delta==rsz)); return "$?"
    else
      # dichotomy
      while ((delta&&rlen>=2)); do
        local mlen=$((rlen/2))
        local m=${right::mlen}
        ble/util/strlen "$m"; local msz=$ret
        if ((delta>=msz)); then
          right=${right:mlen}
          ((index+=mlen,
            rlen-=mlen,
            delta-=msz))
          ((rlen>delta)) &&
            right=${right::delta} rlen=$delta
        else
          right=$m rlen=$mlen
        fi
      done
      ((delta&&rlen&&index++))
      return 0
    fi
  elif ((delta<0)); then
    ((delta=-delta))
    local left=${_ble_edit_str::index}
    local llen=${#left}
    ((llen>delta)) && left=${left:llen-delta} llen=$delta
    ble/util/strlen "$left"; local lsz=$ret
    if ((delta>=lsz)); then
      ((index-=llen))
      ((delta==lsz)); return "$?"
    else
      # dichotomy
      while ((delta&&llen>=2)); do
        local mlen=$((llen/2))
        local m=${left:llen-mlen}
        ble/util/strlen "$m"; local msz=$ret
        if ((delta>=msz)); then
          left=${left::llen-mlen}
          ((index-=mlen,
            llen-=mlen,
            delta-=msz))
          ((llen>delta)) &&
            left=${left:llen-delta} llen=$delta
        else
          left=$m llen=$mlen
        fi
      done
      ((delta&&llen&&index--))
      return 0
    fi
  fi
}
function ble/widget/forward-byte {
  local arg; ble-edit/content/get-arg 1
  ((arg==0)) && return 0
  local index=$_ble_edit_ind
  ble/widget/.locate-forward-byte "$arg" || ble/widget/.bell
  _ble_edit_ind=$index
}
function ble/widget/backward-byte {
  local arg; ble-edit/content/get-arg 1
  ((arg==0)) && return 0
  local index=$_ble_edit_ind
  ble/widget/.locate-forward-byte "$((-arg))" || ble/widget/.bell
  _ble_edit_ind=$index
}

function ble/widget/end-of-text {
  local arg; ble-edit/content/get-arg ''
  if [[ $arg ]]; then
    if ((arg>=10)); then
      _ble_edit_ind=0
    else
      ((arg<0&&(arg=0)))
      local index=$(((19-2*arg)*${#_ble_edit_str}/20))
      local ret; ble-edit/content/find-logical-bol "$index"
      _ble_edit_ind=$ret
    fi
  else
    _ble_edit_ind=${#_ble_edit_str}
  fi
}
function ble/widget/beginning-of-text {
  local arg; ble-edit/content/get-arg ''
  if [[ $arg ]]; then
    if ((arg>=10)); then
      _ble_edit_ind=${#_ble_edit_str}
    else
      ((arg<0&&(arg=0)))
      local index=$(((2*arg+1)*${#_ble_edit_str}/20))
      local ret; ble-edit/content/find-logical-bol "$index"
      _ble_edit_ind=$ret
    fi
  else
    _ble_edit_ind=0
  fi
}

function ble/widget/beginning-of-logical-line {
  local arg; ble-edit/content/get-arg 1
  local ret; ble-edit/content/find-logical-bol "$_ble_edit_ind" "$((arg-1))"
  _ble_edit_ind=$ret
}
function ble/widget/end-of-logical-line {
  local arg; ble-edit/content/get-arg 1
  local ret; ble-edit/content/find-logical-eol "$_ble_edit_ind" "$((arg-1))"
  _ble_edit_ind=$ret
}

## @widget kill-backward-logical-line
##
##   Delete up to the beginning of the current line.
##   If you are already at the beginning of the line, delete the previous line feed.
##   If argument arg is given, delete to the end of the line before arg.
##
function ble/widget/kill-backward-logical-line {
  local arg; ble-edit/content/get-arg ''
  if [[ $arg ]]; then
    local ret; ble-edit/content/find-logical-eol "$_ble_edit_ind" "$((-arg))"; local index=$ret
    if ((arg>0)); then
      if ((_ble_edit_ind<=index)); then
        index=0
      else
        ble/string#count-char "${_ble_edit_str:index:_ble_edit_ind-index}" $'\n'
        ((ret<arg)) && index=0
      fi
      [[ $flag_beg ]] && index=0
    fi
    ret=$index
  else
    local ret; ble-edit/content/find-logical-bol
    # If called with no arguments when at the beginning of a line, the previous line break will be deleted.
    ((0<ret&&ret==_ble_edit_ind&&ret--))
  fi
  ble/widget/.kill-range "$ret" "$_ble_edit_ind"
}
## @widget kill-forward-logical-line
##
##   Delete up to the end of the current line.
##   If you are already at the end of the line, delete the newline immediately after it.
##   If argument arg is given, delete up to the beginning of the line following arg.
##
function ble/widget/kill-forward-logical-line {
  local arg; ble-edit/content/get-arg ''
  if [[ $arg ]]; then
    local ret; ble-edit/content/find-logical-bol "$_ble_edit_ind" "$arg"; local index=$ret
    if ((arg>0)); then
      if ((index<=_ble_edit_ind)); then
        index=${#_ble_edit_str}
      else
        ble/string#count-char "${_ble_edit_str:_ble_edit_ind:index-_ble_edit_ind}" $'\n'
        ((ret<arg)) && index=${#_ble_edit_str}
      fi
    fi
    ret=$index
  else
    local ret; ble-edit/content/find-logical-eol
    # If you call it without arguments when you are at the end of a line, the line break immediately after it will be deleted.
    ((ret<${#_ble_edit_str}&&_ble_edit_ind==ret&&ret++))
  fi
  ble/widget/.kill-range "$_ble_edit_ind" "$ret"
}
function ble/widget/kill-logical-line {
  local arg; ble-edit/content/get-arg 0
  local bofs=0 eofs=0 bol=0 eol=${#_ble_edit_str}
  ((arg>0?(eofs=arg-1):(arg<0&&(bofs=arg+1))))
  ble-edit/content/find-logical-bol "$_ble_edit_ind" "$bofs" && local bol=$ret
  ble-edit/content/find-logical-eol "$_ble_edit_ind" "$eofs" && local eol=$ret
  [[ ${_ble_edit_str:eol:1} == $'\n' ]] && ((eol++))
  ((bol<eol)) && ble/widget/.kill-range "$bol" "$eol"
}

## @fn ble/widget/forward-history-line.impl arg opts
function ble/widget/forward-history-line.impl {
  local arg=$1 opts=$2
  ((arg==0)) && return 0

  if ((arg>0)); then
    if [[ ! $_ble_history_prefix && ! $_ble_history_load_done ]]; then
      # The next item does not exist because the history has not been loaded yet.
      _ble_edit_ind=${#_ble_edit_str}
      ble/widget/.bell 'end of history'
      return 1
    fi
  fi

  # Handle "history_default_point" in this function instead of using the
  # handling by "ble-edit/history/goto"
  local point_opts point point_x
  if ((arg>0)); then
    opts=$opts:linewise:forward
  else
    opts=$opts:linewise:backward
  fi
  ble-edit/history/goto/.prepare-point "$opts"

  local rest=$((arg>0?arg:-arg))

  ble/history/initialize
  local index=$_ble_history_INDEX

  local expr_next='--index>=0'
  if ((arg>0)); then
    local count=$_ble_history_COUNT
    expr_next="++index<=$count"
  fi

  while ((expr_next)); do
    if ((--rest<=0)); then
      ble-edit/history/goto "$index" point=none
      ble-edit/history/goto/.set-point 0
      return 0
    fi

    local entry; ble/history/get-edited-entry "$index"
    if [[ $entry == *$'\n'* ]]; then
      local ret; ble/string#count-char "$entry" $'\n'
      if ((rest<=ret)); then
        ble-edit/history/goto "$index" point=none
        ble-edit/history/goto/.set-point "$rest"
        return 0
      fi
      ((rest-=ret))
    fi
  done

  if ((arg>0)); then
    ble-edit/history/goto "$count" point=none
    _ble_edit_ind=${#_ble_edit_str}
    ble/widget/.bell 'end of history'
  else
    ble-edit/history/goto 0 point=none
    _ble_edit_ind=0
    ble/widget/.bell 'beginning of history'
  fi
  return 0
}

## @fn ble/widget/forward-logical-line.impl arg opts
##
##   @param arg
##     Specify an integer representing the amount of movement.
##   @param opts
##     Specify options separated by colons.
##
function ble/widget/forward-logical-line.impl {
  local arg=$1 opts=$2
  ((arg==0)) && return 0

  # Pre-check
  local ind=$_ble_edit_ind
  if ((arg>0)); then
    ((ind<${#_ble_edit_str})) || return 1
  else
    ((ind>0)) || return 1
  fi

  local ret; ble-edit/content/find-logical-bol "$ind" "$arg"; local bol2=$ret
  if ((arg>0)); then
    if ((ind<bol2)); then
      ble/string#count-char "${_ble_edit_str:ind:bol2-ind}" $'\n'
      ((arg-=ret))
    fi
  else
    if ((ind>bol2)); then
      ble/string#count-char "${_ble_edit_str:bol2:ind-bol2}" $'\n'
      ((arg+=ret))
    fi
  fi

  # If a move predecessor is found within the same history item
  if ((arg==0)); then
    # Move back to the same column as before.
    ble-edit/content/find-logical-bol "$ind" ; local bol1=$ret
    ble-edit/content/find-logical-eol "$bol2"; local eol2=$ret
    local dst=$((bol2+ind-bol1))
    ((_ble_edit_ind=dst<eol2?dst:eol2))
    return 0
  fi

  # When moving history items
  if [[ :$opts: == *:history:* && ! $_ble_edit_mark_active ]]; then
    ble/widget/forward-history-line.impl "$arg" logical
    return "$?"
  fi

  # Move as far as you can
  if ((arg>0)); then
    ble-edit/content/find-logical-eol "$bol2"
  else
    ret=$bol2
  fi
  _ble_edit_ind=$ret

  # bell if there is no movement predecessor
  if ((arg>0)); then
    ble/widget/.bell 'end of string'
  else
    ble/widget/.bell 'beginning of string'
  fi

  return 0
}
function ble/widget/forward-logical-line {
  local opts=$1
  local arg; ble-edit/content/get-arg 1
  ble/widget/forward-logical-line.impl "$arg" "$opts"
}
function ble/widget/backward-logical-line {
  local opts=$1
  local arg; ble-edit/content/get-arg 1
  ble/widget/forward-logical-line.impl "$((-arg))" "$opts"
}

## @fn ble-edit/content/find-graphical-eol [index [offset]]
##   @var[out] ret
function ble-edit/content/find-graphical-eol {
  local axis=${1:-$_ble_edit_ind} arg=${2:-0}
  local x y index
  ble/textmap#getxy.cur "$axis"
  ble/textmap#get-index-at 0 "$((y+arg+1))"
  if ((index>0)); then
    local ax ay
    ble/textmap#getxy.cur --prefix=a "$index"
    ((ay>y+arg&&index--))
  fi
  ret=$index
}

function ble/widget/beginning-of-graphical-line {
  ble/textmap#is-up-to-date || ble/widget/.update-textmap
  local arg; ble-edit/content/get-arg 1
  local x y index
  ble/textmap#getxy.cur "$_ble_edit_ind"
  ble/textmap#get-index-at 0 "$((y+arg-1))"
  _ble_edit_ind=$index
}
function ble/widget/end-of-graphical-line {
  ble/textmap#is-up-to-date || ble/widget/.update-textmap
  local arg; ble-edit/content/get-arg 1
  local ret; ble-edit/content/find-graphical-eol "$_ble_edit_ind" "$((arg-1))"
  _ble_edit_ind=$ret
}

## @widget kill-backward-graphical-line
##   Delete up to the beginning of the current line.
##   If the character is already at the beginning of the display line, the previous character is deleted.
##   If argument arg is given, delete up to the end of the displayed line before arg line.
function ble/widget/kill-backward-graphical-line {
  ble/textmap#is-up-to-date || ble/widget/.update-textmap
  local arg; ble-edit/content/get-arg ''
  if [[ ! $arg ]]; then
    local x y index
    ble/textmap#getxy.cur "$_ble_edit_ind"
    ble/textmap#get-index-at 0 "$y"
    ((index==_ble_edit_ind&&index>0&&index--))
    ble/widget/.kill-range "$index" "$_ble_edit_ind"
  else
    local ret; ble-edit/content/find-graphical-eol "$_ble_edit_ind" "$((-arg))"
    ble/widget/.kill-range "$ret" "$_ble_edit_ind"
  fi
}
## @widget kill-forward-graphical-line
##   Delete the current line up to the end of the displayed line.
## If you are already at the end of the displayed line (before the last character on the line when wrapping), delete the character immediately after.
##   If the argument arg is given, delete up to the beginning of the displayed line after the arg line.
function ble/widget/kill-forward-graphical-line {
  ble/textmap#is-up-to-date || ble/widget/.update-textmap
  local arg; ble-edit/content/get-arg ''
  local x y index ax ay
  ble/textmap#getxy.cur "$_ble_edit_ind"
  ble/textmap#get-index-at 0 "$((y+${arg:-1}))"
  if [[ ! $arg ]] && ((_ble_edit_ind<index-1)); then
    # When there are no arguments and before the end of the line,
    # Erases only to the end of the line before it, not to the beginning of the line.
    ble/textmap#getxy.cur --prefix=a "$index"
    ((ay>y&&index--))
  fi
  ble/widget/.kill-range "$_ble_edit_ind" "$index"
}
## @widget kill-graphical-line
##   Delete the currently displayed line.
function ble/widget/kill-graphical-line {
  ble/textmap#is-up-to-date || ble/widget/.update-textmap
  local arg; ble-edit/content/get-arg 0
  local bofs=0 eofs=0
  ((arg>0?(eofs=arg-1):(arg<0&&(bofs=arg+1))))
  local x y index ax ay
  ble/textmap#getxy.cur "$_ble_edit_ind"
  ble/textmap#get-index-at 0 "$((y+bofs))"  ; local bol=$index
  ble/textmap#get-index-at 0 "$((y+eofs+1))"; local eol=$index
  ((bol<eol)) && ble/widget/.kill-range "$bol" "$eol"
}

function ble/widget/forward-graphical-line.impl {
  ble/textmap#is-up-to-date || ble/widget/.update-textmap
  local arg=$1 opts=$2
  ((arg==0)) && return 0

  local old_edit_ind=$_ble_edit_ind
  local x y index ax ay
  ble/textmap#getxy.cur "$_ble_edit_ind"
  ble/textmap#get-index-at "$x" "$((y+arg))"
  ble/textmap#getxy.cur --prefix=a "$index"
  ((arg-=ay-y))

  # When the movement is completed within the current history item
  if ((arg==0)); then
    _ble_edit_ind=$index
    return 0
  fi

  # When moving history items
  if [[ :$opts: == *:history:* && ! $_ble_edit_mark_active ]]; then
    ble/widget/forward-history-line.impl "$arg" graphical
    return "$?"
  fi

  if ((arg>0)); then
    _ble_edit_ind=${#_ble_edit_str}
    ble/widget/.bell 'end of string'
  else
    _ble_edit_ind=0
    ble/widget/.bell 'beginning of string'
  fi
  return 0
}

function ble/widget/forward-graphical-line {
  local opts=$1
  local arg; ble-edit/content/get-arg 1
  ble/widget/forward-graphical-line.impl "$arg" "$opts"
}
function ble/widget/backward-graphical-line {
  local opts=$1
  local arg; ble-edit/content/get-arg 1
  ble/widget/forward-graphical-line.impl "$((-arg))" "$opts"
}

function ble/widget/beginning-of-line {
  if ble/edit/performs-on-graphical-line; then
    ble/widget/beginning-of-graphical-line
  else
    ble/widget/beginning-of-logical-line
  fi
}
function ble/widget/non-space-beginning-of-line {
  local old=$_ble_edit_ind
  ble/widget/beginning-of-logical-line
  local bol=$_ble_edit_ind ret=
  ble-edit/content/find-non-space "$bol"
  [[ $ret == $old ]] && ret=$bol # toggle
  _ble_edit_ind=$ret
  return 0
}
function ble/widget/end-of-line {
  if ble/edit/performs-on-graphical-line; then
    ble/widget/end-of-graphical-line
  else
    ble/widget/end-of-logical-line
  fi
}
function ble/widget/kill-backward-line {
  if ble/edit/performs-on-graphical-line; then
    ble/widget/kill-backward-graphical-line
  else
    ble/widget/kill-backward-logical-line
  fi
}
function ble/widget/kill-forward-line {
  if ble/edit/performs-on-graphical-line; then
    ble/widget/kill-forward-graphical-line
  else
    ble/widget/kill-forward-logical-line
  fi
}
function ble/widget/kill-line {
  if ble/edit/performs-on-graphical-line; then
    ble/widget/kill-graphical-line
  else
    ble/widget/kill-logical-line
  fi
}
function ble/widget/forward-line {
  if ble/edit/use-textmap; then
    ble/widget/forward-graphical-line "$@"
  else
    ble/widget/forward-logical-line "$@"
  fi
}
function ble/widget/backward-line {
  if ble/edit/use-textmap; then
    ble/widget/backward-graphical-line "$@"
  else
    ble/widget/backward-logical-line "$@"
  fi
}

# 
# **** word location ****                                            @edit.word

## @fn ble/edit/word:eword/setup
## @fn ble/edit/word:cword/setup
## @fn ble/edit/word:uword/setup
## @fn ble/edit/word:sword/setup
## @fn ble/edit/word:fword/setup
##   @var[out] word_class word_set word_sep
function ble/edit/word:eword/setup {
  word_class=set2 word_set='a-zA-Z0-9' word_sep="$_ble_term_IFS"
}
function ble/edit/word:cword/setup {
  word_class=set2 word_set='_a-zA-Z0-9' word_sep="$_ble_term_IFS"
}
function ble/edit/word:uword/setup {
  word_class=set word_sep="$_ble_term_IFS" word_set="^$word_sep"
}
function ble/edit/word:sword/setup {
  word_class=set word_sep=$'|&;()<> \t\n' word_set="^$word_sep"
}
function ble/edit/word:fword/setup {
  word_class=set word_sep="/$_ble_term_IFS" word_set="^$word_sep"
}

## @fn ble/edit/word/skip-backward set
## @fn ble/edit/word/skip-forward set
##   @param[in] set
##     A set of characters to find.
##   @var[ref] x
##     A position to start searching is specified.  The resulting position is
##     returned.  If the search fails, the value is unmodified.
##   @return
##     This function succeeds when the current position is moved. Or otherwise,
##     it fails.
function ble/edit/word/skip-backward {
  local set=$1 head=${_ble_edit_str::x}
  head=${head##*[$set]}
  ((x-=${#head},${#head}))
}
function ble/edit/word/skip-forward {
  local set=$1 tail=${_ble_edit_str:x}
  tail=${tail%%[$set]*}
  ((x+=${#tail},${#tail}))
}

## @fn ble/edit/word/class:set2/find-*
##   This set of functions define the word class `set'.
##
##   @var[ref] x
##   @return
##     The same as ble/edit/word/skip-backward.
##
##   @var[in] word_type
##     Fixed to "set"
##   @var[in] word_set
##     A set of characters that consists in words.
##   @var[in] word_sep
##     A set of characters that are not a part of words.
##
function ble/edit/word/class:set/find-backward-word {
  ble/edit/word/skip-backward "$word_set"
}
function ble/edit/word/class:set/find-backward-space {
  ble/edit/word/skip-backward "$word_sep"
}
function ble/edit/word/class:set/find-forward-word {
  ble/edit/word/skip-forward "$word_set"
}
function ble/edit/word/class:set/find-forward-space {
  ble/edit/word/skip-forward "$word_sep"
}

## @fn ble/edit/word/class:set2/find-*
##   This set of functions define the word class `set2'.  These functions
##   handles two types of words.  The primary type of words consist of a
##   specific set of non-space characters specified by `word_set'.  The
##   secondary type of words consist of the other non-space characters.  The
##   secondary type of words are defined by a set of characters that are not
##   contained in neither `word_set` nor `word_sep`.
##
##   @var[ref] x
##   @return
##     The same as ble/edit/word/skip-backward.
##
##   @var[in] word_type
##     Fixed to "set2"
##   @var[in] word_set
##     A set of characters in the primary type of words.  This set needs to be
##     a positive set, i.e., not starting with ! or ^ for the negative
##     character sets.
##   @var[in] word_sep
##     A set of characters that are not in any words.  This set needs to be a
##     positive set.
##
function ble/edit/word/class:set2/find-backward-word {
  ble/edit/word/skip-backward "!$word_sep"
}
function ble/edit/word/class:set2/find-backward-space {
  case ${_ble_edit_str::x} in
  (*[$word_sep]) return 1 ;;
  (*[$word_set]) ble/edit/word/skip-backward "!$word_set" ;;
  (*?) ble/edit/word/skip-backward "$word_set$word_sep" ;;
  esac
}
function ble/edit/word/class:set2/find-forward-word {
  ble/edit/word/skip-forward "!$word_sep"
}
function ble/edit/word/class:set2/find-forward-space {
  case ${_ble_edit_str:x} in
  ([$word_sep]*) return 1 ;;
  ([$word_set]*) ble/edit/word/skip-forward "!$word_set" ;;
  (?*) ble/edit/word/skip-forward "$word_set$word_sep" ;;
  esac
}

## @fn ble/edit/word/locate-backward x arg
##   Identify the range of words on the left.
##   @param[in] x arg
##   @var[in] word_set word_sep
##   @var[out] a b c
##
##   |---|www|---|
##   a   b   c   x
##
function ble/edit/word/locate-backward {
  local x=${1:-$_ble_edit_ind} arg=${2:-1}
  while ((arg--)); do
    ble/edit/word/class:"$word_class"/find-backward-word; c=$x
    ble/edit/word/class:"$word_class"/find-backward-space; b=$x
  done
  ble/edit/word/class:"$word_class"/find-backward-word; a=$x
}
## @fn ble/edit/word/locate-forward x arg
##   Identify the range of words on the right.
##   @param[in] x arg
##   @var[in] word_set word_sep
##   @var[out] s t u
##
##   |---|www|---|
##   x   s   t   u
##
function ble/edit/word/locate-forward {
  local x=${1:-$_ble_edit_ind} arg=${2:-1}
  while ((arg--)); do
    ble/edit/word/class:"$word_class"/find-forward-word; s=$x
    ble/edit/word/class:"$word_class"/find-forward-space; t=$x
  done
  ble/edit/word/class:"$word_class"/find-forward-word; u=$x
}

## @fn ble/edit/word/forward-range arg
## @fn ble/edit/word/backward-range arg
## @fn ble/edit/word/current-range arg
##   @var[in,out] x y
function ble/edit/word/forward-range {
  local arg=$1; ((arg)) || arg=1
  if ((arg<0)); then
    ble/edit/word/backward-range "$((-arg))"
    return "$?"
  fi
  local s t u; ble/edit/word/locate-forward "$x" "$arg"; y=$t
}
function ble/edit/word/backward-range {
  local arg=$1; ((arg)) || arg=1
  if ((arg<0)); then
    ble/edit/word/forward-range "$((-arg))"
    return "$?"
  fi
  local a b c; ble/edit/word/locate-backward "$x" "$arg"; y=$b
}
function ble/edit/word/current-range {
  local arg=$1; ((arg)) || arg=1
  if ((arg>0)); then
    local a b c; ble/edit/word/locate-backward "$x"
    local s t u; ble/edit/word/locate-forward "$a" "$arg"
    ((y=a,x<t&&(x=t)))
  elif ((arg<0)); then
    local s t u; ble/edit/word/locate-forward "$x"
    local a b c; ble/edit/word/locate-backward "$u" "$((-arg))"
    ((b<x&&(x=b),y=u))
  fi
  return 0
}

## @fn ble/widget/word.impl type direction operator
function ble/widget/word.impl {
  local operator=$1 direction=$2 wtype=$3

  local arg; ble-edit/content/get-arg 1
  local word_class word_set word_sep; ble/edit/word:"$wtype"/setup

  local x=$_ble_edit_ind y=$_ble_edit_ind
  ble/function#try ble/edit/word/"$direction"-range "$arg"
  if ((x==y)); then
    ble/widget/.bell
    return 1
  fi

  case $operator in
  (goto) _ble_edit_ind=$y ;;

  (delete)
    # keymap/vi.sh (editing function registered in white list)
    [[ $_ble_decode_keymap == vi_imap && $direction == backward ]] &&
      ble/keymap:vi/undo/add more

    ble/widget/.delete-range "$x" "$y"

    # keymap/vi.sh (editing function registered in white list)
    [[ $_ble_decode_keymap == vi_imap && $direction == backward ]] &&
      ble/keymap:vi/undo/add more ;;

  (kill)   ble/widget/.kill-range "$x" "$y" ;;
  (copy)   ble/widget/.copy-range "$x" "$y" ;;
  (*)      ble/widget/.bell; return 1 ;;
  esac
}

function ble/widget/transpose-words.impl1 {
  local wtype=$1 arg=$2
  local word_class word_set word_sep; ble/edit/word:"$wtype"/setup
  if ((arg==0)); then
    local x=$_ble_edit_ind
    ble/edit/word/class:"$word_class"/find-forward-word
    ble/edit/word/class:"$word_class"/find-forward-space; local e1=$x
    ble/edit/word/class:"$word_class"/find-backward-space; local b1=$x
    local x=$_ble_edit_mark
    ble/edit/word/class:"$word_class"/find-forward-word
    ble/edit/word/class:"$word_class"/find-forward-space; local e2=$x
    ble/edit/word/class:"$word_class"/find-backward-space; local b2=$x
  else
    local x=$_ble_edit_ind
    ble/edit/word/class:"$word_class"/find-backward-word
    ble/edit/word/class:"$word_class"/find-backward-space; local b1=$x
    ble/edit/word/class:"$word_class"/find-forward-space; local e1=$x
    if ((arg>0)); then
      x=$e1
      ble/edit/word/class:"$word_class"/find-forward-word; local b2=$x
      while ble/edit/word/class:"$word_class"/find-forward-space || return 1; ((--arg>0)); do
        ble/edit/word/class:"$word_class"/find-forward-word
      done; local e2=$x
    else
      x=$b1
      ble/edit/word/class:"$word_class"/find-backward-word; local e2=$x
      while ble/edit/word/class:"$word_class"/find-backward-space || return 1; ((++arg<0)); do
        ble/edit/word/class:"$word_class"/find-backward-word
      done; local b2=$x
    fi
  fi

  ((b1>b2)) && local b1=$b2 e1=$e2 b2=$b1 e2=$e1
  ((b1<e1&&e1<=b2&&b2<e2)) || return 1

  local word1=${_ble_edit_str:b1:e1-b1}
  local word2=${_ble_edit_str:b2:e2-b2}
  local sep=${_ble_edit_str:e1:b2-e1}
  ble/widget/.replace-range "$b1" "$e2" "$word2$sep$word1"
  _ble_edit_ind=$e2
}
function ble/widget/transpose-words.impl {
  local wtype=$1 arg; ble-edit/content/get-arg 1
  ble/widget/transpose-words.impl1 "$wtype" "$arg" && return 0
  ble/widget/.bell
  return 1
}

## @fn ble/widget/filter-word.impl xword filter
## keymap: safe vi_nmap
function ble/widget/filter-word.impl {
  local xword=$1 filter=$2

  local arg; ble/keymap:generic/get-arg 1

  local word_class word_set word_sep; ble/edit/word:"$xword"/setup
  local x=$_ble_edit_ind s t u
  ble/edit/word/locate-forward "$x" "$arg"
  if ((x==t)); then
    ble/widget/.bell
    [[ $_ble_decode_keymap == vi_nmap ]] &&
      ble/keymap:vi/adjust-command-mode
    return 1
  fi

  local word=${_ble_edit_str:x:t-x}
  "$filter" "$word"
  [[ $word != $ret ]] &&
    ble-edit/content/replace "$x" "$t" "$ret"

  if [[ $_ble_decode_keymap == vi_nmap ]]; then
    ble/keymap:vi/mark/set-previous-edit-area "$x" "$t"
    ble/keymap:vi/repeat/record
    ble/keymap:vi/adjust-command-mode
  fi
  _ble_edit_ind=$t
}

#%define 2
function ble/widget/forward-XWORD  { ble/widget/word.impl goto forward  XWORD; }
function ble/widget/backward-XWORD { ble/widget/word.impl goto backward XWORD; }
#%define 1
function ble/widget/OPERATOR-forward-XWORD  { ble/widget/word.impl OPERATOR forward  XWORD; }
function ble/widget/OPERATOR-backward-XWORD { ble/widget/word.impl OPERATOR backward XWORD; }
function ble/widget/OPERATOR-XWORD          { ble/widget/word.impl OPERATOR current  XWORD; }
#%end
#%expand 1.r/OPERATOR/delete/
#%expand 1.r/OPERATOR/kill/
#%expand 1.r/OPERATOR/copy/
function ble/widget/capitalize-XWORD { ble/widget/filter-word.impl XWORD ble/string#capitalize; }
function ble/widget/downcase-XWORD   { ble/widget/filter-word.impl XWORD ble/string#tolower; }
function ble/widget/upcase-XWORD     { ble/widget/filter-word.impl XWORD ble/string#toupper; }
function ble/widget/transpose-XWORDs { ble/widget/transpose-words.impl XWORD; }
#%end
#%expand 2.r/XWORD/eword/
#%expand 2.r/XWORD/cword/
#%expand 2.r/XWORD/uword/
#%expand 2.r/XWORD/sword/
#%expand 2.r/XWORD/fword/

function ble/widget/zap-to-char.hook {
  local code ret char
  ble/widget/self-insert/.get-code
  ble/util/c2s "$code"
  char=$ret

  # search nth occurrence of `char` and send it to the kill ring
  local arg; ble-edit/content/get-arg 1
  if ((arg>=0)); then
    ((arg==0)) && arg=1
    if ble/string#index-of "${_ble_edit_str:_ble_edit_ind}" "$char" "$arg"; then
      ble/widget/.kill-range "$_ble_edit_ind" "$((_ble_edit_ind+ret+${#char}))"
      return "$?"
    fi
  else
    if ble/string#last-index-of "${_ble_edit_str::_ble_edit_ind}" "$char" "$((-arg))"; then
      ble/widget/.kill-range "$ret" "$_ble_edit_ind"
      return "$?"
    fi
  fi

  if ((arg>0)); then
    if ((arg==-1)); then
      ble/widget/.bell "last char '$char' not found"
    else
      ble/widget/.bell "$((-arg))th last char '$char' not found"
    fi
  else
    if ((arg==1)); then
      ble/widget/.bell "next char '$char' not found"
    else
      ble/widget/.bell "$arg-th next char '$char' not found"
    fi
  fi

  return 0
}
function ble/widget/zap-to-char {
  _ble_edit_mark_active=
  _ble_decode_key__hook=ble/widget/zap-to-char.hook
  return 147
}

#------------------------------------------------------------------------------
# **** ble-edit/exec ****                                            @edit.exec

_ble_edit_exec_lines=()
_ble_edit_exec_lastexit=0
_ble_edit_exec_lastarg=$BASH
_ble_edit_exec_lastparams=()
_ble_edit_exec_BASH_COMMAND=$BASH
_ble_edit_exec_PIPESTATUS=()
function ble-edit/exec/register {
  local command=$1
  if [[ $command != *[!"$_ble_term_IFS"]* ]]; then
    ble/edit/leave-command-layout
    return 1
  fi
  local command_id=$((_ble_edit_CMD++)) # Exposed to blehook exec_register
  local lineno=$((_ble_edit_LINENO+1))  # Exposed to blehook exec_register
  ble/array#push _ble_edit_exec_lines "$command_id,$lineno:$command"
  blehook/invoke exec_register "$command"
}
function ble-edit/exec/has-pending-commands {
  ((${#_ble_edit_exec_lines[@]}))
}

## @fn ble-edit/exec/.setexit lastarg
##   Set parameters $? and $_
function ble-edit/exec/.setexit {
  return "$_ble_edit_exec_lastexit"
}
## @fn ble-edit/exec/compose-PIPESTATUS-reproducer
##   @var[out] ret
##     A string of dummy command that can be evaluated to reset PIPESTATUS is
##     stored in variable "ret".
##
##   @exit It fails when an additional trick is not necessary (i.e., when
##     PIPESTATUS has only one element or when "bleopt exec_restore_pipestatus"
##     is disabled), and `ret` is set to empty.  Otherwise, it succeeds.
function ble-edit/exec/compose-PIPESTATUS-reproducer {
  ret=
  [[ $bleopt_exec_restore_pipestatus ]] && ((${#_ble_edit_exec_PIPESTATUS[@]} >= 2)) || return 1
  local i pipe=
  for ((i=0;i<${#_ble_edit_exec_PIPESTATUS[@]};i++)); do
    pipe=$pipe'| (builtin exit '${_ble_edit_exec_PIPESTATUS[i]}')'
  done
  ret=${pipe:2}
  return 0
}
## @fn  ble-edit/exec/eval-with-setexit command [opts]
##   This function evaluates a command with $?, $_, BLE_PIPESTATUS, LINE, and
##   BASH_COMMAND, (and aditionally PIPESTATUS when "bleopt
##   exec_restore_pipestatus" is enabled) being restored.
##   @param[in] command
##     The command to execute.
##   @param[in,opt] opts
##     @opt pipestatus
##       If this is specified and "bleopt exec_restore_pipestatus" is enabeld,
##       PIPESTATUS is reconstructed.
##     @opt DEBUG
##       If this is specified, the user's DEBUG trap is enabled while executing
##       the command.
function  ble-edit/exec/eval-with-setexit {
  # Note #D1772: We set "_ble_edit_exec_TRAPDEBUG_enabled=1" as a local
  # variable to work around a bug in 4.4..5.2.  Ideally, we want to specify it
  # through tempenv the same as LINENO and BASH_COMMAND, but bash-4.4..5.2 (at
  # least) has a bug that "builtin eval" makes tempenvs invisible from inside
  # of the DEBUG trap.
  local debug_insert=
  [[ :$2: == *:DEBUG:* ]] &&
    debug_insert='; local _ble_edit_exec_TRAPDEBUG_enabled=1'

  local ret= q=\' Q="'\''"
  [[ :$2: == *:pipestatus:* ]] &&
    ble-edit/exec/compose-PIPESTATUS-reproducer

  local _ble_local_script='
    local -a BLE_PIPESTATUS
    BLE_PIPESTATUS=("${_ble_edit_exec_PIPESTATUS[@]}")'$debug_insert'
    ble-edit/exec/.setexit "$_ble_edit_exec_lastarg"'${ret:+"; $ret"}'
    LINENO=${_ble_edit_LINENO:-${BASH_LINENO[${#BASH_LINENO[@]}-1]}} \
      BASH_COMMAND=$_ble_edit_exec_BASH_COMMAND \
      builtin eval -- '$q${1//$q/$Q}$q
  ble/util/unlocal debug_insert ret q Q
  builtin eval -- "$_ble_local_script"
}
ble/function#trace ble-edit/exec/eval-with-setexit

## @fn ble-edit/exec/.adjust-eol
##   Adjust the end of the sentence.
_ble_prompt_eol_mark=('' '' 0)
function ble-edit/exec/.adjust-eol {
  # bleopt prompt_eol_mark
  local cols=${COLUMNS:-80}
  local -a DRAW_BUFF=()
  if [[ $bleopt_prompt_eol_mark ]]; then
    if [[ $bleopt_prompt_eol_mark != "${_ble_prompt_eol_mark[0]}" ]]; then
      if [[ $bleopt_prompt_eol_mark ]]; then
        local ret= x=0 y=0 g=0 x1=0 x2=0 y1=0 y2=0
        LINES=1 COLUMNS=80 ble/canvas/trace "$bleopt_prompt_eol_mark" truncate:measure-bbox
        _ble_prompt_eol_mark=("$bleopt_prompt_eol_mark" "$ret" "$x2")
      else
        _ble_prompt_eol_mark=('' '' 0)
      fi
    fi

    local eol_mark=${_ble_prompt_eol_mark[1]}
    # Note #D1458: You should have moved to panel 0 with panel/render before executing the command.
    #   Therefore, it should be OK to use SC/RC without being in bottom-dock.
    ble/canvas/put.draw "$_ble_term_sgr0$_ble_term_sc"
    local width=${_ble_prompt_eol_mark[2]} limit=$cols
    [[ $_ble_term_rc ]] || ((limit--))
    if ((width>limit)); then
      local x=0 y=0 g=0
      LINES=1 COLUMNS=$limit ble/canvas/trace.draw "$bleopt_prompt_eol_mark" truncate
      width=$x
    else
      ble/canvas/put.draw "$eol_mark"
    fi
    [[ $_ble_term_rc ]] || ble/canvas/put-cub.draw "$width"
    ble/canvas/put.draw "$_ble_term_sgr0$_ble_term_rc"
  fi

  # EOL adjustment
  local advance=$((_ble_term_xenl?cols-2:cols-3))
  if [[ $_ble_term_TERM == cygwin:* ]]; then
    # Note (#D1144): For some reason, the destination is not displayed in the Cygwin console.
    #   A CUF that is exactly cols+1 column does not move a single character.
    #   It is okay for the cols column or cols + 2nd column onwards.
    #   I have no choice but to move forward slowly and carefully.
    while ((advance)); do
      ble/canvas/put-cuf.draw "$((advance-advance/2))"
      ((advance/=2))
    done
  else
    ble/canvas/put-cuf.draw "$advance"
  fi
  ble/canvas/put.draw "  $_ble_term_cr$_ble_term_el"
  ble/canvas/bflush.draw
}

_ble_prompt_ps10_data=()
function ble/prompt/unit:_ble_prompt_ps10/update {
  ble/prompt/unit:{section}/update _ble_prompt_ps10 "$PS0" ''
}

function ble-edit/exec/print-PS0 {
  if [[ $PS0 ]]; then
    local version=$COLUMNS,$_ble_edit_lineno,$_ble_history_count,$_ble_edit_CMD
    local prompt_hashref_base='$version'
    local prompt_rows=${LINES:-25}
    local prompt_cols=${COLUMNS:-80}
    local "${_ble_prompt_cache_vars[@]/%/=}" # WA #D1570 checked
    ble/prompt/unit#update _ble_prompt_ps10
    local ret; ble/prompt/unit:{section}/get _ble_prompt_ps10
    ble/util/put "$ret"
  fi
}

_ble_builtin_exit_processing=
function ble/builtin/exit/.read-arguments {
  [[ ! $_ble_attached || $_ble_edit_exec_inside_userspace ]] &&
    ble/base/adjust-BASH_REMATCH
  while (($#)); do
    local arg=$1; shift
    if [[ $arg == --help ]]; then
      opt_flags=${opt_flags}H
    elif local rex='^[-+]?[0-9]+$'; [[ $arg =~ $rex ]]; then
      ble/array#push opt_args "$arg"
    else
      ble/util/print "exit: unrecognized argument '$arg'" >&2
      opt_flags=${opt_flags}E
    fi
  done
  if ((${#opt_args[@]}>=2)); then
    ble/util/print "exit: too many arguments" >&2
    opt_flags=${opt_flags}E
  fi
  [[ ! $_ble_attached || $_ble_edit_exec_inside_userspace ]] &&
    ble/base/restore-BASH_REMATCH
}
function ble/builtin/exit {
  local ext=$?

  # Whether trap processing is currently being executed in the same (sub)shell
  local trap_processing=$_ble_builtin_trap_processing
  [[ $_ble_builtin_trap_processing == "${BASH_SUBSHELL:-0}"/* ]] || trap_processing=

  # Note (#D22XX): In bash < 4.0, "_ble_builtin_trap_processing" may be set by
  # the user input [C-d] through SIGUSR1.  In this case, we clear
  # "trap_processing" since we want to process ble/builtin/exit normally.
  ((_ble_bash<40000)) &&
    [[ $trap_processing && " ${FUNCNAME[*]} " == *' ble-edit/io/TRAPUSR1 '* ]] &&
    [[ ${_ble_builtin_trap_sig_name[${trap_processing##*/}]} == SIGUSR1 ]] &&
    trap_processing=

  if [[ ! $trap_processing ]] && { ble/util/is-running-in-subshell || [[ $_ble_decode_bind_state == none ]]; }; then
    (($#)) || set -- "$ext"
    builtin exit "$@"
    return "$?" # Failure may occur due to incorrect specification of options.
  fi

  local set shopt; ble/base/.adjust-bash-options set shopt
  local opt_flags=
  local -a opt_args=()
  ble/builtin/exit/.read-arguments "$@"
  if [[ $opt_flags == *[EH]* ]]; then
    [[ $opt_flags == *H* ]] && builtin exit --help
    ble/base/.restore-bash-options set shopt
    return 2
  fi
  ((${#opt_args[@]})) || ble/array#push opt_args "$ext"

  if [[ $trap_processing ]]; then
    # Note #D1782: When processing inside a trap, exit is processed on the trap side. Na
    # Therefore, exit is postponed and returns to the original caller. This allows for fine-grained movements.
    # Differences can be a problem. For example, time was being measured with time in trap.
    # In this case, the time measurement is not stopped and the result is output.
    shopt -s extdebug
    _ble_edit_exec_TRAPDEBUG_EXIT=$opt_args
    ble-edit/exec:gexec/.TRAPDEBUG/trap
    return 0
  fi

  if [[ ! $_ble_builtin_exit_processing ]]; then
    # Completion confirmation and [ble: exit] output

    local joblist
    ble/util/joblist
    if ((${#joblist[@]})); then
      local ret
      while
        local cancel_reason=
        if ble/util/assign ret 'compgen -A stopped -- ""' 2>/dev/null; [[ $ret ]]; then
          cancel_reason='stopped jobs'
        elif [[ :$opts: == *:checkjobs:* ]]; then
          if ble/util/assign ret 'compgen -A running -- ""' 2>/dev/null; [[ $ret ]]; then
            cancel_reason='running jobs'
          fi
        fi
        [[ $cancel_reason ]]
      do
        jobs
        ble/builtin/read -ep "\e[38;5;12m[ble: There are $cancel_reason]\e[m Leave the shell anyway? [yes/No] " ret
        case $ret in
        ([yY]|[yY][eE][sS]) break ;;
        ([nN]|[nN][oO]|'')
          ble/base/.restore-bash-options set shopt
          return 0 ;;
        esac
      done
    fi
    local ret
    ble/edit/marker#instantiate-config exec_exit_mark &&
      ble/util/print "$ret" >&2
  fi

  # Note #D1765: "{ time { exit 2>/dev/tty; } } 2>/dev/null" in Bash 4.4..5.1
  #   Output the time measurement result to 2>/dev/tty instead of 2>/dev/null for
  #   There is a bug that causes this. Therefore, the time used to measure ble/exec/time is
  #   The output is displayed on the screen. I have no choice but to use the output of time as an empty TIMEFORMAT.
  #   suppressed by In 4.3 and earlier, when you execute exit, the outer time is also measured.
  #   Everything was canceled, so even if I squeezed time, it reverted to the behavior before 4.3.
  #   It's just that, so I won't worry about it.
  # Note #D1765: In the experiment at hand, the problem occurs if only local TIMEFORMAT= is specified.
  #   I didn't do it, but when I actually implemented it in ble.sh, I found that I didn't specify global TIMEFORMAT.
  #   Since it could not be suppressed if it was not, global TIMEFORMAT was temporarily rewritten.
  if ((40400<=_ble_bash&&_ble_bash<50200)); then
    # Saving TIMEFORMAT values
    local global_TIMEFORMAT local_TIMEFORMAT
    ble/util/assign global_TIMEFORMAT 'ble/util/print-global-definitions TIMEFORMAT'
    if [[ $global_TIMEFORMAT == 'declare TIMEFORMAT; builtin unset -v TIMEFORMAT' ]]; then
      global_TIMEFORMAT='declare -g TIMEFORMAT=$'\''\nreal\t%3lR\nuser\t%3lU\nsys %3lS'\'
    else
      global_TIMEFORMAT="declare -g ${global_TIMEFORMAT#declare }"
    fi
    ble/variable#copy-state TIMEFORMAT local_TIMEFORMAT

    declare -g TIMEFORMAT=
    TIMEFORMAT=
  fi

  ble/base/.restore-bash-options set shopt
  _ble_builtin_exit_processing=1
  ble/fd#alloc _ble_builtin_exit_stdout '>&1' # Restore stdin/stdout with EXIT trap
  ble/fd#alloc _ble_builtin_exit_stderr '>&2'
  builtin exit "${opt_args[@]}" &>/dev/null
  builtin exit "${opt_args[@]}" &>/dev/null

  # If exit fails, return to the original state as much as possible
  _ble_builtin_exit_processing=
  ble/fd#close _ble_builtin_exit_stdout
  ble/fd#close _ble_builtin_exit_stderr
  if ((40400<=_ble_bash&&_ble_bash<50200)); then
    builtin eval -- "$global_TIMEFORMAT"
    ble/variable#copy-state local_TIMEFORMAT TIMEFORMAT
  fi
  return 1 # It seems to be 1 if exit was not possible.
}

function exit {
  builtin eval -- "$_ble_bash_POSIXLY_CORRECT_local_adjust"
  ble/builtin/exit "$@"
  builtin eval -- "$_ble_bash_POSIXLY_CORRECT_local_return"
}

# start time - end time - end

# Measurement with time Command
_ble_exec_time_TIMEFILE=$_ble_base_run/$$.exec.time
_ble_exec_time_TIMEFORMAT=
_ble_exec_time_tot=
_ble_exec_time_usr=
_ble_exec_time_sys=
function ble/exec/time#adjust-TIMEFORMAT {
  if [[ ${TIMEFORMAT+set} ]]; then
    _ble_exec_time_TIMEFORMAT=$TIMEFORMAT
  else
    builtin unset -v _ble_exec_time_TIMEFORMAT
  fi
  TIMEFORMAT='%R %U %S'
}
function ble/exec/time#restore-TIMEFORMAT {
  if [[ ${_ble_exec_time_TIMEFORMAT+set} ]]; then
    TIMEFORMAT=$_ble_exec_time_TIMEFORMAT
  else
    builtin unset -v 'TIMEFORMAT[0]'
  fi
  local tot usr sys dummy
  while IFS=' ' ble/bash/read tot usr sys dummy; do
    # If there is a redirection error, an error message will be mixed in.
    ble/string#match "$tot" '^[0-9.ms]+$' && break
  done < "$_ble_exec_time_TIMEFILE"
  ((_ble_exec_time_tot=10#0${tot//[!0-9]}))
  ((_ble_exec_time_usr=10#0${usr//[!0-9]}))
  ((_ble_exec_time_sys=10#0${sys//[!0-9]}))
}

_ble_exec_time_TIMES=$_ble_base_run/$$.exec.times
_ble_exec_time_usr_self=
_ble_exec_time_sys_self=
function ble/exec/time/times.parse-time {
  local rex='^([0-9]+m)?([0-9]*)([^0-9ms][0-9]{3})?s?$'
  [[ $1 =~ $rex ]] || return 1
  local min=$((10#0${BASH_REMATCH[1]%m}))
  local sec=$((10#0${BASH_REMATCH[2]}))
  local msc=$((10#0${BASH_REMATCH[3]#?}))
  ((ret=(min*60+sec)*1000+msc))
  return 0
}
function ble/exec/time/times.start {
  builtin times >| "$_ble_exec_time_TIMES"
}
function ble/exec/time/times.end {
  builtin times >> "$_ble_exec_time_TIMES"
  local times
  ble/util/readfile times "$_ble_exec_time_TIMES"
  ble/string#split-words times "$times"

  _ble_exec_time_usr_self=
  _ble_exec_time_sys_self=
  local ret= t1 t2
  ble/exec/time/times.parse-time "${times[0]}" && t1=$ret &&
    ble/exec/time/times.parse-time "${times[4]}" && t2=$ret &&
    ((_ble_exec_time_usr_self=t2>t1?t2-t1:0,
      _ble_exec_time_usr_self>_ble_exec_time_usr&&(
        _ble_exec_time_usr_self=_ble_exec_time_usr)))
  ble/exec/time/times.parse-time "${times[1]}" && t1=$ret &&
    ble/exec/time/times.parse-time "${times[5]}" && t2=$ret &&
    ((_ble_exec_time_sys_self=t2>t1?t2-t1:0,
      _ble_exec_time_sys_self>_ble_exec_time_sys&&(
        _ble_exec_time_sys_self=_ble_exec_time_sys)))
  return 0
}
function ble/exec/time#mark-enabled {
  # Note: Variables that can be referenced from exec_elapsed_enabled
  local real=$_ble_exec_time_tot
  local usr=$_ble_exec_time_usr usr_self=$_ble_exec_time_usr_self
  local sys=$_ble_exec_time_sys sys_self=$_ble_exec_time_sys_self
  local usr_child=$((usr-usr_self))
  local sys_child=$((sys-sys_self))
  local cpu=$((real>0?(usr+sys)*100/real:0))
  ((bleopt_exec_elapsed_enabled))
}

_ble_exec_time_beg=
_ble_exec_time_end=
_ble_exec_time_ata=
function ble/exec/time#start {
  # Initialized on first call

  if ((_ble_bash>=50000)); then
    _ble_exec_time_EPOCHREALTIME_delay=0
    _ble_exec_time_EPOCHREALTIME_beg=
    _ble_exec_time_EPOCHREALTIME_end=
    function ble/exec/time#start {
      # EPOCHREALTIME has high precision, so you can directly use it to measure accurately.
      # Write in prologue/epilogue
      ble/exec/time/times.start
      _ble_exec_time_EPOCHREALTIME_beg=
      _ble_exec_time_EPOCHREALTIME_end=
    }
    function ble/exec/time#end {
      local beg=${_ble_exec_time_EPOCHREALTIME_beg//[!0-9]}
      local end=${_ble_exec_time_EPOCHREALTIME_end//[!0-9]}
      ((beg+=delay,beg>end)) && beg=$end
      _ble_exec_time_beg=$beg
      _ble_exec_time_end=$end
      _ble_exec_time_ata=$((end-beg))
      _ble_exec_time_LINENO=$_ble_edit_LINENO
      ble/exec/time/times.end
    }

    function ble/exec/time#calibrate.restore-lastarg {
      # Note: The time after reading EPOCHREALTIME is important, so we do not
      # have to mimic the processing prior to this.
      _ble_exec_time_EPOCHREALTIME_beg=$EPOCHREALTIME
      return "$_ble_edit_exec_lastexit"
    }
    function ble/exec/time#calibrate.save-lastarg {
      _ble_exec_time_EPOCHREALTIME_end=$EPOCHREALTIME
      ble/exec/time#adjust-TIMEFORMAT
      # Note: The time until reading EPOCHREALTIME is important, so we do not
      # have to mimic the rest procesing in _ble_edit_exec_gexec__save_lastarg.
    }
    function ble/exec/time#calibrate {
      local _ble_edit_exec_lastexit=0
      local _ble_edit_exec_lastarg=hello
      local _ble_exec_time_EPOCHREALTIME_beg=
      local _ble_exec_time_EPOCHREALTIME_end=
      local _ble_exec_time_tot=
      local _ble_exec_time_usr=
      local _ble_exec_time_sys=
      local TIMEFORMAT=

      # create a script
      local script1='ble/exec/time#calibrate.restore-lastarg "$_ble_edit_exec_lastarg"'
      local script2='{ ble/exec/time#calibrate.save-lastarg; } 4>&1 5>&2 &>/dev/null'
      local script=$script1$_ble_term_nl$script2$_ble_term_nl

      # make a histogram
      local -a hist=()
      local i
      for i in {00..99}; do
        # This invocation mimics the actual setup for the command execution in
        # ble-edit/exec:gexec.
        { time LINENO=$i builtin eval -- "$script" 0<&"$_ble_util_fd_cmd_stdin" 1>&"$_ble_util_fd_cmd_stdout" 2>&"$_ble_util_fd_cmd_stderr"; } 2>| "$_ble_exec_time_TIMEFILE"
        ble/exec/time#restore-TIMEFORMAT
        local beg=${_ble_exec_time_EPOCHREALTIME_beg//[!0-9]}
        local end=${_ble_exec_time_EPOCHREALTIME_end//[!0-9]}
        ((hist[end-beg]++))
      done

      # calculate weighted average
      local -a keys; keys=("${!hist[@]}")
      keys=("${keys[@]::(${#keys[@]}+1)/2}") # Remove outliers
      local s=0 n=0 t
      for t in "${keys[@]}"; do ((s+=t*hist[t],n+=hist[t])); done
      ((_ble_exec_time_EPOCHREALTIME_delay=s/n))
    }
    ble/exec/time#calibrate
    builtin unset -f ble/exec/time#calibrate
    builtin unset -f ble/exec/time#calibrate.restore-lastarg
    builtin unset -f ble/exec/time#calibrate.save-lastarg

  else
    _ble_exec_time_CLOCK_base=0
    _ble_exec_time_CLOCK_beg=
    _ble_exec_time_CLOCK_end=
    function ble/exec/time#end.adjust {
      # Cross-legged alignment
      ((_ble_exec_time_beg<prev_end)) && _ble_exec_time_beg=$prev_end
      local delta=$((_ble_exec_time_end-_ble_exec_time_beg))
      if ((delta<_ble_exec_time_ata)); then
        _ble_exec_time_end=$((_ble_exec_time_beg+_ble_exec_time_ata))
      else
        _ble_exec_time_beg=$((_ble_exec_time_end-_ble_exec_time_ata))
      fi
      _ble_exec_time_LINENO=$_ble_edit_LINENO
    }

    function ble/exec/time#start {
      ble/exec/time/times.start
      _ble_exec_time_CLOCK_beg=
      _ble_exec_time_CLOCK_end=
      local ret; ble/util/clock
      _ble_exec_time_CLOCK_beg=$ret
    }
    function ble/exec/time#end {
      local ret; ble/util/clock
      _ble_exec_time_CLOCK_end=$ret
      local prev_end=$_ble_exec_time_end
      _ble_exec_time_beg=$((_ble_exec_time_CLOCK_base+_ble_exec_time_CLOCK_beg*1000))
      _ble_exec_time_end=$((_ble_exec_time_CLOCK_base+_ble_exec_time_CLOCK_end*1000))
      _ble_exec_time_ata=$((_ble_exec_time_tot*1000))
      ble/exec/time#end.adjust
      ble/exec/time/times.end
    }

    case $_ble_util_clock_type in
    (printf) ;;
    (uptime|SECONDS)
      # These origins are not unix epochs, so correct them.
      local ret
      ble/util/time; _ble_exec_time_CLOCK_base=${ret}000000
      ble/util/clock
      ((_ble_exec_time_CLOCK_base-=ret*1000)) ;;
    (date)
      # If you are going to use a file command anyway, use one with more precision.
      if ble/util/assign ret 'ble/bin/date +%6N' 2>/dev/null && ble/string#match "$ret" '^[0-9]+$'; then
        function ble/exec/time#start {
          ble/exec/time/times.start
          _ble_exec_time_CLOCK_beg=
          _ble_exec_time_CLOCK_end=
          ble/util/assign _ble_exec_time_CLOCK_beg 'ble/bin/date +%s%6N'
        }
        function ble/exec/time#end {
          ble/util/assign _ble_exec_time_CLOCK_end 'ble/bin/date +%s%6N'
          local prev_end=$_ble_exec_time_end
          _ble_exec_time_beg=$_ble_exec_time_CLOCK_beg
          _ble_exec_time_end=$_ble_exec_time_CLOCK_end
          _ble_exec_time_ata=$((_ble_exec_time_tot*1000))
          ble/exec/time#end.adjust
          ble/exec/time/times.end
        }
      fi ;;
    esac
  fi

  ble/exec/time#start
}

function ble/exec/time#format-elapsed-time {
  ret=$_ble_exec_time_ata
  if ((ret%1000!=0&&ret<1000)); then
    ret="${ret}us"
  elif ((ret%1000!=0&&ret<1000*100)); then
    ret="${ret::${#ret}-3}.${ret:${#ret}-3:2}ms"
  elif ((ret/=1000,ret<1000)); then
    ret="${ret}ms"
  elif ((ret<1000*1000)); then
    ret="${ret::${#ret}-3}.${ret:${#ret}-3}s"
  elif ((ret/=1000,ret<3600*100)); then # ret [s]
    local min
    ((min=ret/60,ret%=60))
    if ((min<100)); then
      ret="${min}m${ret}s"
    else
      ret="$((min/60))h$((min%60))m${ret}s"
    fi
  else
    local hour
    ((ret/=60,hour=ret/60,ret%=60))
    ret="$((hour/24))d$((hour%24))h${ret}m"
  fi
}

## @fn ble-edit/exec:$bleopt_internal_exec_type/process
##   Executes the specified command.
##   @param[in,out] _ble_edit_exec_lines
##     Specifies an array of commands to run. Delete the executed command or substitute an empty string.
##   @return
##     If the return value is 0, it means that the terminal (ble-edit/bind/.tail) was also processed.
##     In other words, we expect it to exit from _ble_decode_hook as is.
## In other cases, it indicates that no termination processing has been performed.

#--------------------------------------
# bleopt_internal_exec_type = gexec
#--------------------------------------

_ble_edit_exec_TRAPDEBUG_enabled=
_ble_edit_exec_TRAPDEBUG_INT=
_ble_edit_exec_TRAPDEBUG_EXIT=
_ble_edit_exec_inside_begin=
_ble_edit_exec_inside_prologue=
_ble_edit_exec_inside_userspace=
ble/builtin/trap/sig#reserve DEBUG override-builtin-signal:user-trap-in-postproc

## @fn ble-edit/exec:gexec/.TRAPDEBUG/trap [opts]
##   @param[in] opts
##     filter
##       Force DEBUG trap filter explicitly (even without special handling of TRAPDEBUG)
##       Indicates what to do. PROMPT_COMMAND processing, etc.
##       Specify this to run DEBUG trap for the
function ble-edit/exec:gexec/.TRAPDEBUG/trap {
  # Note #D1772: Originally, I wanted to trap user trap directly when $_ble_attached.
  #   However, in that case, you would have to call the ble.sh functions (especially _ble_decode_hook) immediately after ble-attach.
  #   Since it is not possible to prevent unintended DEBUG traps from firing, use TRAPDEBUG instead.
  #   I will select DEBUG.
  # Note #D1772: Even in the case of TRAPDEBUG for command execution, still
  #   Run user trap via TRAPDEBUG to exclude ble-edit/exec:gexec/.*
  #   I decided to do it. If a user wants to refer to FUNCNAME, BASH_SOURCE, etc. from DEBUG trap,
  #   If there is a user, the user trap will be set to trap directly by default when executing a command.
  #   It's okay.
  local trap_command
  ble/builtin/trap/install-hook/.compose-trap_command "$_ble_builtin_trap_DEBUG"
  builtin eval -- "builtin $trap_command"

  # Note: Below is the code to conditionally trap user trap directly.
  # if [[ $_ble_attached && _ble_edit_exec_TRAPDEBUG_INT || :$1: == *:filter:* ]]; then
  #   builtin trap -- 'ble-edit/exec:gexec/.TRAPDEBUG "$*"; builtin eval -- "${_ble_builtin_trap_postproc[1000]}"' DEBUG
  # else
  #   local user_trap=${_ble_builtin_trap_handlers[_ble_builtin_trap_DEBUG]}
  #   builtin trap -- "$user_trap" DEBUG
  # fi
}

_ble_edit_exec_TRAPDEBUG_adjusted=
# Note: Under bash-3.1, declare -ft cannot be added to functions with special function names.
function _ble_edit_exec_gexec__TRAPDEBUG_adjust {
  builtin trap - DEBUG
  _ble_edit_exec_TRAPDEBUG_adjusted=1
}
ble/function#trace _ble_edit_exec_gexec__TRAPDEBUG_adjust
function ble-edit/exec:gexec/.TRAPDEBUG/restore {
  _ble_edit_exec_TRAPDEBUG_adjusted=
  local opts=$1
  if ble/builtin/trap/user-handler#has "$_ble_builtin_trap_DEBUG"; then
    ble-edit/exec:gexec/.TRAPDEBUG/trap "$opts"
  fi
}

function ble-edit/exec:gexec/.TRAPDEBUG/.filter {
  [[ $_ble_edit_exec_TRAPDEBUG_enabled || ! $_ble_attached ]] || return 1
  [[ ${_ble_builtin_trap_inside-} ]] && return 1
  [[ $_ble_trap_bash_command != *ble-edit/exec:gexec/.* ]] || return 1

  # PROMPT_COMMAND execution
  if [[ ${FUNCNAME[2]-} == 'ble-edit/exec/eval-with-setexit' ]]; then
    case $_ble_trap_bash_command in
    ('ble-edit/exec/.setexit '*) return 1 ;;
    ('LINENO='*' BASH_COMMAND='*' builtin eval -- '*) return 1 ;;
    esac
  fi

  return 0
}
_ble_trap_builtin_handler_DEBUG_filter=ble-edit/exec:gexec/.TRAPDEBUG/.filter

## @fn ble-edit/exec:gexec/.TRAPDEBUG
##   @var[in] BLE_TRAP_FUNCNAME
##   @var[in] BLE_TRAP_LINENO
##   @var[in] _ble_trap_args
##   @var[in] _ble_trap_bash_command
##   @var[in] _ble_trap_lastarg
##   @var[in] _ble_trap_lastexit
##   @var[in] _ble_trap_sig
##   @var[in,out] _ble_builtin_trap_postproc[_ble_trap_sig]
function ble-edit/exec:gexec/.TRAPDEBUG {
  if [[ $_ble_edit_exec_TRAPDEBUG_EXIT ]]; then
    # Handle EXIT (#D1782)
    #   When calling exit while processing another trap with ble/builtin/trap/.handler
    #   Processing is adjusted using DEBUG trap. Because it interferes with the original trap operation
    #   _ble_builtin_trap_processing and _ble_trap_done for the original trap,
    #   _ble_trap_lastarg (ble/builtin/trap/invoke) and _ble_local_ext
    #   Rewrite (blehook/invoke) etc.
    #
    #   Assumption: When _ble_edit_exec_TRAPDEBUG_EXIT is set, extdebug is also set.
    #   Assume that

    # Skip up to a certain level (in the first place, it is an exit, so the user's DEBUG
    # There is no need to process traps either).
    local flag_clear= flag_exit= postproc=

    # Note: Here, we want to read and rewrite the one-upper-level
    # "_ble_builtin_trap_processing".  We remove the slot in
    # ble/builtin/trap/.handler for DEBUG and reveal the slot defined in the
    # upper call of ble/builtin/trap/.handler for another signal.
    ble/util/unlocal _ble_builtin_trap_processing
    if [[ ! $_ble_builtin_trap_processing ]] || ((${#BLE_TRAP_FUNCNAME[*]}==0)); then
      # I shouldn't have come here originally.
      flag_clear=2
      flag_exit=$_ble_edit_exec_TRAPDEBUG_EXIT
    else
      # Originally extdebug should be set, so when extdebug is not set
      # There is no need to deal with this, but just in case, we also define the behavior when extdebug is not set.
      # Leave it.
      case " ${BLE_TRAP_FUNCNAME[*]} " in
      (' ble/builtin/trap/invoke.sandbox ble/builtin/trap/invoke '*)

        # Rewrite variables declared for the other signal
        ble/util/unlocal _ble_trap_lastarg               # declared in ble/builtin/trap/.handler for DEBUG
        _ble_trap_done=exit                              # declared in ble/builtin/trap/invoke for the other signal
        _ble_trap_lastarg=$_ble_edit_exec_TRAPDEBUG_EXIT # declared in ble/builtin/trap/invoke for the other signal

        postproc='ble/util/setexit 2'
        shopt -q extdebug || postproc='return 0' ;;
      (' blehook/invoke.sandbox blehook/invoke ble/builtin/trap/.handler '*)

        # Rewrite variables declared for the other signal (Note: the local
        # _ble_builtin_trap_processing is already removed above).
        # The following is declared in "blehook/invoke" for the other signal.
        _ble_local_ext=$_ble_edit_exec_TRAPDEBUG_EXIT
        # The following is declared in "ble/builtin/trap/.handler" for the other signal.
        _ble_builtin_trap_processing=${_ble_builtin_trap_processing%%/*}/exit:$_ble_edit_exec_TRAPDEBUG_EXIT

        postproc='ble/util/setexit 2'
        shopt -q extdebug || postproc='return 0' ;;
      (' ble/builtin/trap/invoke '* | ' blehook/invoke '*)
        # To make sure to release the trap DEBUG here, after calling sandbox
        # At least one command required. Currently, return is always at the end of both invokes.
        # It should be okay since it is running now.
        flag_clear=1 ;;
      (' ble/builtin/trap/.handler '* | ' ble-edit/exec:gexec/.TRAPDEBUG '*)
        # It wasn't supposed to come here. Clear only the DEBUG trap without touching extdebug.
        flag_clear=2 ;;
      (*)
        # trap handler Skips all internal processing and returns to the caller.
        postproc='ble/util/setexit 2'
        shopt -q extdebug || postproc='return 128' ;;
      esac
    fi

    if [[ $flag_clear ]]; then
      [[ $flag_clear == 2 ]] || shopt -u extdebug
      _ble_edit_exec_TRAPDEBUG_EXIT=
      if ! ble/builtin/trap/user-handler#has "$_ble_trap_sig"; then
        postproc="builtin trap - DEBUG${postproc:+;$postproc}"
      fi
      if [[ $flag_exit ]]; then
        builtin exit "$flag_exit"
      fi
    fi

    _ble_builtin_trap_postproc[_ble_trap_sig]=$postproc
    return 126 # skip user hooks/traps

  elif [[ $_ble_edit_exec_TRAPDEBUG_INT ]]; then
    # Handle INT

    # Run user DEBUG trap in the sandbox
    ble/util/setexit "$_ble_trap_lastexit" "$_ble_trap_lastarg"
    BASH_COMMAND=$_ble_trap_bash_command LINENO=$BLE_TRAP_LINENO \
      ble/builtin/trap/invoke "$_ble_trap_sig" "${_ble_trap_args[@]}"

    # Handle INT
    local depth=${#BLE_TRAP_FUNCNAME[*]}
    if ((depth>=1)) && ! ble/string#match "${BLE_TRAP_FUNCNAME[*]}" '^ble-edit/exec:gexec/\.|(^| )ble/builtin/trap/\.handler'; then
      # When you are inside a function but not inside ble-edit/exec:gexec/.
      if [[ ${bleopt_internal_exec_int_trace-} ]]; then
        local source=${_ble_term_setaf[5]}${BLE_TRAP_SOURCE[0]}
        local sep=${_ble_term_setaf[6]}:
        local lineno=${_ble_term_setaf[2]}${BLE_TRAP_LINENO[0]}
        local func=${_ble_term_setaf[6]}' ('${_ble_term_setaf[4]}${BLE_TRAP_FUNCNAME[0]}${1:+ $1}${_ble_term_setaf[6]}')'
        ble/util/print "${_ble_term_setaf[9]}[SIGINT]$_ble_term_sgr0 $source$sep$lineno$func$_ble_term_sgr0" >&"$_ble_util_fd_tui_stderr"
      fi
      _ble_builtin_trap_postproc[_ble_trap_sig]="{ return $_ble_edit_exec_TRAPDEBUG_INT || break; } &>/dev/null"
    elif ((depth==0)) && ! ble/string#match "$_ble_trap_bash_command" '^ble-edit/exec:gexec/\.'; then
      # Outermost and not a ble-edit/exec:gexec/. function
      if [[ ${bleopt_internal_exec_int_trace-} ]]; then
        local source=${_ble_term_setaf[5]}global
        local sep=${_ble_term_setaf[6]}:
        ble/util/print "${_ble_term_setaf[9]}[SIGINT]$_ble_term_sgr0 $source$sep$_ble_term_sgr0 $_ble_trap_bash_command" >&"$_ble_util_fd_tui_stderr"
      fi
      _ble_builtin_trap_postproc[_ble_trap_sig]="break &>/dev/null"
    fi

    return 126 # skip user hooks/traps

  elif ! ble/builtin/trap/user-handler#has "$_ble_trap_sig"; then
    # If there is no user DEBUG trap and INT is not being processed, delete DEBUG.
    # Good [Note: builtin trap - DEBUG doesn't work here]
    _ble_builtin_trap_postproc[_ble_trap_sig]='builtin trap -- - DEBUG'
    return 126 # skip user hooks/traps
  fi

  return 0
}
blehook internal_DEBUG!=ble-edit/exec:gexec/.TRAPDEBUG

_ble_builtin_trap_DEBUG_userTrapInitialized=
function ble/builtin/trap:DEBUG {
  _ble_builtin_trap_DEBUG_userTrapInitialized=1
  # Note (#D1155): New ble/builtin/trap DEBUG while executing user command
  # If set, the builtin trap DEBUG will be set.
  if [[ $1 != - && ( $_ble_edit_exec_TRAPDEBUG_enabled || ! $_ble_attached ) ]]; then
    ble-edit/exec:gexec/.TRAPDEBUG/trap
  fi
}

## @fn _ble_builtin_trap_DEBUG__initialize
##   Read the DEBUG trap set by the user at some point.
##
## DEBUG trap is basically disabled inside ble.sh. However, PROMPT_COMMAND
## It is temporarily enabled during evaluation. DEBUG with ble/builtin/trap is a function input.
## Parents, etc. are not taken into consideration.
##
## Note: Function names are required by POSIX only in bash-3.1 and below, when special characters are not included.
##   This is because declare -ft cannot be executed for function names that include.
##
## Note: If you source ble.sh first, in most cases it will work correctly via trap:DEBUG above.
##   It works in most cases because a trap string is registered.
##
##   However, in bash-5.0 or below, first source ble.sh, perform prompt-attach, and then
##   If PROMPT_COMMAND is rewritten, in PROMPT_COMMAND
##   DEBUG trap is disabled for processes executed after attach-from-PROMPT_COMMAND
## It will be executed in a formatted state. This sets DEBUG trap in PROMPT_COMMAND.
##   The operation is inconsistent with the one enabled.
##
## Note: If you source ble.sh after setting DEBUG trap first, then
##   DEBUG trap is also enabled for internal processing of ble.sh immediately after loading.
##   Be careful about things. Again at the first user input or DA2 response from the terminal, etc.
##   Reading DEBUG traps
##
##   - If the rcfile name is neither .bashrc nor .profile nor .bash_profile
##     (This may be because bash currently has no way to determine whether you are inside the rcfile.
##     Therefore, it is necessary to determine whether it is an rcfile based only on the file name and line number.
##     (derived from)
##
##   - Manually read bashrc from the command line using source -- ~/.bashrc etc.
##     (This is due to a Bash restriction that source does not inherit DEBUG trap.)
##     coming)
##
##   - Source another file from rcfile and run ble.sh from that file.
##     When sourced. Or when sourcing ble.sh from within a function (also DEBUG
##     (Due to Bash's limitations on trap inheritance)
##
##   - For bash-3.1 or below (this is the function name of a function that can be appended with trace using declare -ft)
##     )
function _ble_builtin_trap_DEBUG__initialize {
  if [[ $_ble_builtin_trap_DEBUG_userTrapInitialized ]]; then
    # Note: If user trap is already set by ble/builtin/trap:DEBUG etc.
    # If it is, it will not be read again (even if it is read, you will only see TRAPDEBUG).
    builtin eval -- "function $FUNCNAME { return 0; }"
    return 0
  elif [[ $1 == force ]] || ble/function/is-global-trace-context; then
    _ble_builtin_trap_DEBUG_userTrapInitialized=1
    builtin eval -- "function $FUNCNAME { return 0; }"

    # Note: ble/util/assign does not inherit DEBUG, so output it with trap -p on the spot.
    local _ble_local_tmpfile; ble/util/assign/mktmp
    builtin trap -p DEBUG >| "$_ble_local_tmpfile"
    local content; ble/util/readfile content "$_ble_local_tmpfile"
    ble/util/assign/rmtmp

    # DEBUG traps set by ble.sh are ignored.
    case ${content#"trap -- '"} in
    (ble-edit/exec:gexec/.TRAPDEBUG*|ble/builtin/trap/.handler*) ;; # ble-0.4
    (ble-edit/exec:exec/.eval-TRAPDEBUG*|ble-edit/exec:gexec/.eval-TRAPDEBUG*) ;; # ble-0.2
    (.ble-edit/exec:exec/eval-TRAPDEBUG*|.ble-edit/exec:gexec/eval-TRAPDEBUG*) ;; # ble-0.1
    (*) builtin eval -- "$content" ;; # Let ble/builtin/trap handle it
    esac
    return 0
  fi
}
ble/function#trace _ble_builtin_trap_DEBUG__initialize
_ble_builtin_trap_DEBUG__initialize

function ble-edit/exec:gexec/.TRAPINT {
  # Do not execute interrupt processing when there is a user trap
  local ret; ble/builtin/trap/sig#resolve INT
  ble/builtin/trap/user-handler#has "$ret" && return 0

  local ext=130
  ((_ble_bash>=40300)) || ext=128 # bash-4.2 and below is 128
  if [[ $_ble_attached ]]; then
    if [[ ${bleopt_internal_exec_int_trace-} ]]; then
      ble/util/print "$_ble_term_bold^C$_ble_term_sgr0" >&"$_ble_util_fd_tui_stderr"
    fi
    _ble_edit_exec_TRAPDEBUG_INT=$ext
    ble-edit/exec:gexec/.TRAPDEBUG/trap
  else
    _ble_builtin_trap_postproc="{ return $ext || break; } 2>&$_ble_util_fd_tui_stderr"
  fi
}
function ble-edit/exec:gexec/.TRAPINT/reset {
  blehook internal_INT-='ble-edit/exec:gexec/.TRAPINT'
}
function ble-edit/exec:gexec/invoke-hook-with-setexit {
  local -a __ble_exec_hook_args
  __ble_exec_hook_args=("$@")

  # We do not specify opt "pipestatus" to "ble-edit/exec/eval-with-setexit"
  # because PIPESTATUS is not propagated to hooks anyway.  One can always
  # access BLE_PIPESTATUS instead.
  ble-edit/exec/eval-with-setexit 'blehook/invoke "${__ble_exec_hook_args[@]}"'
} >&"$_ble_util_fd_tui_stdout" 2>&"$_ble_util_fd_tui_stderr"

function ble-edit/exec:gexec/.TRAPERR {
  if [[ $_ble_attached ]]; then
    [[ $_ble_edit_exec_inside_userspace ]] || return 126
    [[ $_ble_trap_bash_command != *'return "$_ble_edit_exec_lastexit"'* ]] || return 126
  fi
  return 0
}
blehook internal_ERR!='ble-edit/exec:gexec/.TRAPERR'

# ble-edit/exec:gexec/TERM
#
# Note #D1287: Bash automatically creates TERM-specific keys when TERM is changed midway through.
#   Bind. This prevents ble.sh from reading the key.
#   Mau. Here, we detect bind by bash and execute rebind. Incidentally
#   If you force a reload, the command execution may fail there.
#   You should rebind after ble/term/enter.
_ble_edit_exec_TERM=
function ble-edit/exec:gexec/TERM/is-dirty {
  [[ $TERM != "$_ble_edit_exec_TERM" ]] && return 0
  local bindp
  ble/util/assign bindp 'builtin bind -p'
  [[ $bindp != "$_ble_decode_bind_bindp" ]]
}
function ble-edit/exec:gexec/TERM/leave {
  _ble_edit_exec_TERM=$TERM
}
function ble-edit/exec:gexec/TERM/enter {
  if [[ $_ble_decode_bind_state != none ]] && ble-edit/exec:gexec/TERM/is-dirty; then
    # Note: Including recording and restoring the original binding instead of ble/decode/readline/rebind.
    # and try again.
    ble/edit/info/immediate-show text 'ble: TERM has changed. rebinding...'
    ble/decode/detach
    if ! ble/decode/attach; then
      ble-detach
      ble-edit/bind/.check-detach && return 1
    fi
    ble/edit/info/immediate-default
  fi
}

## @fn ble-edit/exec:gexec/.begin
## @fn ble-edit/exec:gexec/.end
##   Adjust settings such as terminal and input/output for command execution.
##   Also configure traps for DEBUG and INT.
##   DEBUG settings can only be canceled at the top level, so
##   When actually using it, you need to do the following.
##
##     ble-edit/exec:gexec/.begin
##
##     command execution
##
##     builtin trap -- - DEBUG
##     ble-edit/exec:gexec/.end
##
function ble-edit/exec:gexec/.begin {
  _ble_edit_exec_inside_begin=1
  local IFS=$_ble_term_IFS
  _ble_edit_exec_PWD=$PWD
  ble-edit/exec:gexec/TERM/leave
  ble/term/leave
  ble-edit/bind/stdout.on
  ble/util/buffer.flush

  # for C-c
  ble/builtin/trap/install-hook INT # For some reason it doesn't take effect unless I run it again.
  blehook internal_INT!='ble-edit/exec:gexec/.TRAPINT'
  ble-edit/exec:gexec/.TRAPDEBUG/restore
}
function ble-edit/exec:gexec/.end {
  _ble_edit_exec_inside_begin=
  local IFS=$_ble_term_IFS

  # Note: builtin trap -- - DEBUG doesn't work here for some reason.
  #   Execute outside just before calling ble-edit/exec:gexec/.end.
  ble-edit/exec:gexec/.TRAPINT/reset
  builtin trap -- - DEBUG

  blehook/invoke exec_end
  [[ $PWD != "$_ble_edit_exec_PWD" ]] && blehook/invoke CHPWD
  ble/util/joblist.flush >&"$_ble_util_fd_tui_stderr"
  ble/util/notify-broken-locale
  ble-edit/bind/.check-detach && return 0
  ble/term/enter
  ble-edit/exec:gexec/TERM/enter || return 0 # When rebind fails, exit without .tail
  ble/util/c2w:auto/check
  ble/edit/clear-command-layout
  [[ $1 == restore ]] && return 0 # Note: When .end failed in the previous call #D1170
  ble-edit/bind/.tail # flush will be called here
}

## @fn ble-edit/exec:gexec/.prologue command command_id
##   @param[in] command
##     The next command to run. Record in _ble_edit_exec_BASH_COMMAND.
function ble-edit/exec:gexec/.prologue {
  _ble_edit_exec_inside_prologue=1
  local IFS=$_ble_term_IFS
  _ble_edit_exec_BASH_COMMAND=$1
  _ble_edit_exec_command_id=$2
  BLE_COMMAND_ID=$2
  BLE_PIPESTATUS=("${_ble_edit_exec_PIPESTATUS[@]}")

  _ble_edit_exec_BASH_COMMAND_eval=$_ble_edit_exec_BASH_COMMAND
  local ret
  ble-edit/exec/compose-PIPESTATUS-reproducer &&
    _ble_edit_exec_BASH_COMMAND_eval="$ret; $_ble_edit_exec_BASH_COMMAND_eval"

  ble-edit/restore-PS1
  ble-edit/restore-READLINE
  ble-edit/restore-IGNOREEOF
  builtin unset -v HISTCMD; ble/history/get-count -v HISTCMD

  _ble_edit_exec_TRAPDEBUG_INT=
  ble/util/joblist.clear
  ble-edit/exec:gexec/invoke-hook-with-setexit internal_PREEXEC "$_ble_edit_exec_BASH_COMMAND"
  ble-edit/exec:gexec/invoke-hook-with-setexit PREEXEC "$_ble_edit_exec_BASH_COMMAND"
  ble-edit/exec/print-PS0 >&"$_ble_util_fd_tui_stdout" 2>&"$_ble_util_fd_tui_stderr"

  ble/exec/time#start
  ble/base/restore-BASH_REMATCH
}

## @fn ble-edit/exec:gexec/.restore-lastarg lastarg
##   @param[dummy] lastarg
##     This argument is to be referenced by the following command with $_, so this function itself should not be used.
##     Yes.
function ble-edit/exec:gexec/.restore-lastarg {
  ble/base/restore-bash-options
  ble/base/restore-builtin-wrappers
  ble/base/restore-POSIXLY_CORRECT

  # Note: The function cannot be called after this point. However, you can call functions up to one time, so
  # There should be no problem if you just use _ble_edit_exec_gexec__save_lastarg.
  builtin eval -- "$_ble_bash_FUNCNEST_restore"
  _ble_edit_exec_TRAPDEBUG_enabled=1
  _ble_edit_exec_inside_userspace=1
  _ble_exec_time_EPOCHREALTIME_beg=$EPOCHREALTIME
  return "$_ble_edit_exec_lastexit" # set $?
} &>/dev/null # set -x solution #D0930
## @fn ble-edit/exec:gexec/.save-lastarg (original name)
## @fn _ble_edit_exec_gexec__save_lastarg params...
##   @param[in] params...
##     specify the positional parameters of the outer context.
function _ble_edit_exec_gexec__save_lastarg {
  _ble_exec_time_EPOCHREALTIME_end=$EPOCHREALTIME \
    _ble_edit_exec_lastexit=$? \
    _ble_edit_exec_lastarg=$_ \
    _ble_edit_exec_PIPESTATUS=("${PIPESTATUS[@]}") \
    _ble_edit_exec_lastparams=("$@")

  # Note: When ble-attach by a new ble.sh session is forced inside the user
  # space, the adjustments for the editor mode is unnecessary.  Rather, it
  # would wrongly saves the file descriptors for the editor space as those for
  # the user space and causes a loss of the user's file descriptors.
  [[ $_ble_edit_exec_inside_userspace ]] || return "$_ble_edit_exec_lastexit"

  _ble_edit_exec_inside_userspace=
  _ble_edit_exec_TRAPDEBUG_enabled=

  # Note: Before any other function calls. FUNCNEST is effective at least
  # Since FUNCNEST=1, the function can be called at any time if it is single. So this function
  # There is no problem in calling .save-lastarg itself.
  builtin eval -- "$_ble_bash_FUNCNEST_adjust"
  builtin eval -- "$_ble_bash_POSIXLY_CORRECT_adjust"
  ble/base/adjust-bash-options
  ble/exec/time#adjust-TIMEFORMAT

  # Note: We here update the file descriptors for the user commands.  The file
  # descriptors may be changed by the `exec` builtin.  Note that stdout (1) and
  # stderr (2) are redirected to /dev/null to suppress "set -x" messages in
  # this context.  Instead, we use 4 and 5 because stdout and stderr are copied
  # to 4 and 5, respectively, by the caller.
  ble/fd/save-external-standard-streams 0 4 5

  return "$_ble_edit_exec_lastexit"
}
function ble/variable#load-user-state/variable:_ {
  __ble_var_set=set
  __ble_var_val=$_ble_edit_exec_lastarg
  __ble_var_att=
}
function ble/variable#load-user-state/variable:PIPESTATUS {
  __ble_var_set=set
  __ble_var_val=("${_ble_edit_exec_PIPESTATUS[@]}")
  __ble_var_att=a
}

## @fn ble-edit/exec:gexec/.epilogue (original name)
## @fn _ble_edit_exec_gexec__epilogue
function _ble_edit_exec_gexec__epilogue {
  # Note: $_ cannot be read unless it is in the same eval, so it is not read here.
  _ble_exec_time_EPOCHREALTIME_end=${_ble_exec_time_EPOCHREALTIME_end:-$EPOCHREALTIME} \
    _ble_edit_exec_lastexit=$?

  [[ $_ble_edit_exec_inside_prologue ]] || return 0

  _ble_edit_exec_inside_userspace=
  _ble_edit_exec_TRAPDEBUG_enabled=
  # Note: Before any other function call
  builtin eval -- "$_ble_bash_FUNCNEST_adjust"
  builtin eval -- "$_ble_bash_POSIXLY_CORRECT_adjust"
  ble/base/adjust-builtin-wrappers
  if [[ $_ble_edit_exec_TRAPDEBUG_INT ]]; then
    if ((_ble_edit_exec_lastexit==0)); then
      _ble_edit_exec_lastexit=$_ble_edit_exec_TRAPDEBUG_INT
    fi
    _ble_edit_exec_TRAPDEBUG_INT=
  fi

  local IFS=$_ble_term_IFS
  # Note: builtin trap -- - DEBUG doesn't work here for some reason
  builtin trap -- - DEBUG

  ble/base/adjust-bash-options
  ble/base/adjust-BASH_REMATCH
  ble-edit/adjust-IGNOREEOF
  ble-edit/adjust-READLINE
  ble/exec/time#restore-TIMEFORMAT
  ble/exec/time#end
  ble/util/reset-keymap-of-editing-mode
  ble-edit/exec/.adjust-eol
  _ble_edit_exec_inside_prologue=

  ble/util/buffer.flush
  ble-edit/exec:gexec/invoke-hook-with-setexit POSTEXEC "$_ble_edit_exec_BASH_COMMAND"

  local msg=
  if ((_ble_edit_exec_lastexit)); then
    # ERREXEC processing
    ble-edit/exec:gexec/invoke-hook-with-setexit ERREXEC "$_ble_edit_exec_BASH_COMMAND"
    if local ret; ble/edit/marker#get-config exec_errexit_mark; then
      ble/util/sprintf ret "$ret" "$_ble_edit_exec_lastexit"
      msg=$ret
    fi
  fi

  # This needs to be performed after POSTEXEC and ERREXEC because the user
  # hooks might want to access PS1 and PROMPT_COMMAND.
  ble-edit/adjust-PS1

  if ble/exec/time#mark-enabled; then
    if local ret; ble/edit/marker#get-config exec_elapsed_mark; then
      local format=$ret

      # ata
      ble/exec/time#format-elapsed-time; local ata=$ret

      # cpu
      local cpu='--.-'
      if ((_ble_exec_time_tot)); then
        cpu=$(((_ble_exec_time_usr+_ble_exec_time_sys)*1000/_ble_exec_time_tot))
        cpu=$((cpu/10)).$((cpu%10))
      fi

      local ret
      ble/util/sprintf ret "$format" "$ata" "$cpu"
      msg=$msg$ret
      ble/string#ltrim "$_ble_edit_exec_BASH_COMMAND"
      msg="$msg $ret"
    fi
  fi

  local ret
  ble/edit/marker#instantiate "$msg" bare && ble/util/buffer.print "$ret"

  # bleopt prompt_ruler
  local -a DRAW_BUFF=()
  ble/prompt/print-ruler.draw "$_ble_edit_exec_BASH_COMMAND"
  ble/canvas/bflush.draw
}
function ble-edit/exec:gexec/.setup {
  # Set the command to _ble_decode_bind_hook to evaluate it globally.
  #
  # *If the command entered by the user is evaluated within the function instead of globally
  #   The declared variable becomes command local.
  #   For simple variables that are not arrays, I managed to confuse them by overwriting declare, but
  #   Special syntax such as declare -a arr=(a b c) cannot be overwritten.
  #   For this reason, for example, an array declared in source will be corrupted.
  #
  ((${#_ble_edit_exec_lines[@]})) || [[ ! $_ble_edit_exec_TRAPDEBUG_adjusted ]] || return 1

  local buff='_ble_decode_bind_hook=' ibuff=1

  if [[ ! $_ble_edit_exec_TRAPDEBUG_adjusted ]]; then
    # Note #D1772: For some reason, when using prompt attach under bash-3.1, it is executed on the outermost side.
    #   Even if it is, it is executed in attach-from-PROMPT_COMMAND, so
    #   Explicitly specify force to read DEBUG trap.
    buff[ibuff++]='_ble_builtin_trap_DEBUG__initialize force'
    buff[ibuff++]=_ble_edit_exec_gexec__TRAPDEBUG_adjust
  fi

  local count=${#_ble_edit_exec_lines[@]}
  if ((count)); then
    ble/util/buffer.flush

    local q=\' Q="'\''" cmd cmd_id lineno
    buff[ibuff++]=ble-edit/exec:gexec/.begin
    for cmd in "${_ble_edit_exec_lines[@]}"; do
      cmd_id=${cmd%%,*} cmd=${cmd#*,}
      lineno=${cmd%%:*} cmd=${cmd#*:}
      buff[ibuff++]="ble-edit/exec:gexec/.prologue '${cmd//$q/$Q}' $cmd_id"
      # Note #D1823: Use tempenv to overwrite LINENO without unsetting it.
      # Note #D1823: There is a bug in Bash that causes tempenv to disappear with "builtin eval".
      #   Call eval directly without builtin. adjust-builtin-wrappers
      #   (restore-builtin-wrappers is executed in .restore-lastarg in eval)
      #   ), so if there is a failure to adjust the status after the previous command execution, etc.
      #   There should be no problem as long as there is no.
      # Note #D0465: Put restore-lastarg and the actual command in the same eval
      #   This is to suppress the output when using set -v. Immediately after restoring set -v in prologue
      #   If you do not execute the command as is afterwards, useless output will be produced.
      # Note: $_ble_edit_exec_lastarg in restore-lastarg is used to set $_
      #   It is something.
      # Note #D1824, #D2108: To avoid vanishing tempenv bug about LINENO
      #   I intentionally use eval instead of builtin eval.
      buff[ibuff++]='{ time LINENO='$lineno' eval -- "ble-edit/exec:gexec/.restore-lastarg \"\$_ble_edit_exec_lastarg\"'
      buff[ibuff++]='$_ble_edit_exec_BASH_COMMAND_eval'
      # Note #D0465: The actual command and save-lastarg are placed in the same eval
      #   This is because $_ will be lost if it is not in the same eval (especially when exiting eval).
      #   (It becomes the final argument of eval when
      buff[ibuff++]='{ _ble_edit_exec_gexec__save_lastarg \"\$@\"; } 4>&1 5>&2 &>/dev/null' # Note: &>/dev/null is set -x workaround #D0930
      buff[ibuff++]='" 0<&"$_ble_util_fd_cmd_stdin" 1>&"$_ble_util_fd_cmd_stdout" 2>&"$_ble_util_fd_cmd_stderr"; } 2>| "$_ble_exec_time_TIMEFILE"'
      buff[ibuff++]='{ _ble_edit_exec_gexec__epilogue; } 3>&2 &>/dev/null'

      # *If you write $cmd directly, when you insert something that is grammatically broken
      #   The following line will not be executed.
    done
    _ble_edit_exec_lines=()

    # Note: Currently it is processed via _ble_decode_bind_hook so there is no problem, but
    #   builtin trap - When using INT DEBUG, it will not work unless it is the outermost (here)
    buff[ibuff++]=_ble_edit_exec_gexec__TRAPDEBUG_adjust
    buff[ibuff++]=ble-edit/exec:gexec/.end
  fi

  if ((ibuff>=2)); then
    IFS=$'\n' builtin eval '_ble_decode_bind_hook="${buff[*]}"'
  fi

  # ble-edit/bind/.tail is delayed when executing commands
  ((count>=1)); return "$?"
}

function ble-edit/exec:gexec/process {
  ble-edit/exec:gexec/.setup
  return "$?"
}
function ble-edit/exec:gexec/restore-state {
  # For when epilogue/end is not called due to syntax error etc. #D1170
  [[ $_ble_edit_exec_inside_prologue ]] && _ble_edit_exec_gexec__epilogue 3>&2 &>/dev/null
  [[ $_ble_edit_exec_inside_begin ]] && ble-edit/exec:gexec/.end restore
}

# **** accept-line ****                                            @edit.accept

: "${_ble_edit_lineno:=0}"
_ble_prompt_trim_opwd=

## @fn ble/edit/.relocate-textarea [opts]
## @fn ble/edit/.allocate-textarea [opts]
##   textarea Moves to a new panel area for drawing. This is relocate-textarea.
##   Performs final drawing of the textarea before moving to a new area.
##   insert-textarea does not update the previous area.
##
##   @param[in,opt] opts
##
##   @remarks ble/edit/enter-command-layout if keep-info is not specified
##   is called once. If keep-info is specified
##   It does not change the hierarchy of ble/edit/enter-command-layout.
##
function ble/edit/.relocate-textarea {
  ble/textarea#render leave
  ble/edit/.allocate-textarea "$1"
}
function ble/edit/.allocate-textarea {
  local opts=$1
  local -a DRAW_BUFF=()
  if [[ :$opts: == *:keep-info:* && $_ble_textarea_panel == 0 ]] &&
       ! ble/util/joblist.has-events
  then
    # Insert a line while displaying info and discard the contents of panel 0 so far out of range
    local textarea_height=${_ble_canvas_panel_height[_ble_textarea_panel]}
    ble/canvas/panel#increase-height.draw "$_ble_textarea_panel" 1
    ble/canvas/panel#goto.draw "$_ble_textarea_panel" 0 "$textarea_height" sgr0
    ble/canvas/bflush.draw
  else
    ble/edit/enter-command-layout # #D1800 checked=ble/edit/.relocate-textarea

    # new drawing area
    ble/canvas/panel#goto.draw "$_ble_textarea_panel" "$_ble_textarea_gendx" "$_ble_textarea_gendy" sgr0
    ble/canvas/put.draw "$_ble_term_nl"
    ble/canvas/bflush.draw
    ble/util/joblist.bflush

    # Balance the hierarchy when using keep-info
    [[ :$opts: == *:keep-info:* ]] && ble/edit/leave-command-layout
  fi

  # Initializing drawing area information
  ((_ble_edit_lineno++))
  _ble_prompt_trim_opwd=$PWD
  ble/textarea#invalidate
  _ble_canvas_x=0 _ble_canvas_y=0
  _ble_textarea_gendx=0 _ble_textarea_gendy=0
  _ble_canvas_panel_height[_ble_textarea_panel]=1
}
## @fn ble/widget/.hide-current-line [opts]
##   @param[in] opts
##     a colon-separated list of the following fields:
##
##     keep-header
##       keep the multiline prompt displayed in the terminal except
##       for the last line.
##
function ble/widget/.hide-current-line {
  local opts=$1 y_erase=0
  [[ :$opts: == *:keep-header:* ]] && y_erase=${_ble_prompt_ps1_data[4]}
  local -a DRAW_BUFF=()
  if ((y_erase)); then
    ble/canvas/panel#clear-after.draw "$_ble_textarea_panel" 0 "$y_erase"
  else
    ble/canvas/panel#clear.draw "$_ble_textarea_panel"
  fi
  ble/canvas/panel#goto.draw "$_ble_textarea_panel" 0 "$y_erase"
  ble/canvas/bflush.draw
  ble/textarea#invalidate
  _ble_canvas_x=0 _ble_canvas_y=$y_erase
  _ble_textarea_gendx=0 _ble_textarea_gendy=$y_erase
  ((_ble_canvas_panel_height[_ble_textarea_panel]=1+y_erase))
}

function ble/widget/.newline/clear-content {
  # Show cursor.
  # For when the cursor is erased with layer:overwrite.
  [[ $_ble_edit_overwrite_mode ]] &&
    ble/term/cursor-state/reveal

  # Initialize row contents
  ble-edit/content/reset '' newline
  _ble_edit_ind=0
  _ble_edit_mark=0
  _ble_edit_mark_active=
  _ble_edit_overwrite_mode=
}

## @fn ble/widget/.newline opts
##   @param[in] opts
##     Colon-separated options.
##     keep-info
##       Leave info visible.
##       (However, menu-complete must be cleared.)
function ble/widget/.newline {
  local opts=$1
  _ble_edit_mark_active=

  # (for lib/core-complete.sh layer:menu_filter)
  if [[ $_ble_complete_menu_active ]]; then
    [[ $_ble_highlight_layer_menu_filter_beg ]] &&
      ble/textarea#invalidate str # (#D0995)
  fi

  # Final draw of current prompt & move to next line
  ble/edit/.allocate-textarea "$opts" # #D1800 checked=.newline

  # update LINENO
  local ret; ble/string#count-char "$_ble_edit_str" $'\n'
  ((_ble_edit_LINENO+=1+ret))

  ble/history/onleave.fire
  ble/widget/.newline/clear-content
}

function ble/widget/discard-line {
  ble-edit/content/clear-arg
  [[ $bleopt_history_share ]] && ble/builtin/history/option:n
  _ble_edit_line_disabled=1 ble/textarea#render leave
  ble/widget/.newline keep-info
  ble/history/revert-edits
  ble/textarea#render
}

function ble/edit/histexpand/run {
  local shopt=$-
  set -H
  ble/builtin/history/option:p "$command"; local ext=$?
  [[ $shopt == *H* ]] || set +H
  return "$ext"
}
function ble/edit/histexpand/.impl {
  ble/edit/histexpand/run 2>/dev/null; local ext=$?
  ((ext)) && ble/util/print "$command"
  ble/util/put :
  return "$ext"
}

## @fn ble/edit/histexpand str
##   @var[out] ret
function ble/edit/histexpand {
  local command=$1
  if [[ ! ${command//[ 	]} ]]; then
    ret=$command
    return 0
  elif ble/util/assign ret 'ble/edit/histexpand/.impl'; then
    ret=${ret%$_ble_term_nl:}
    return 0
  else
    ret=$command
    return 1
  fi
}

_ble_edit_integration_mc_precmd_stop=
function ble/widget/accept-line/.is-mc-init {
  [[ $MC_SID == $$ ]] && ((_ble_edit_LINENO<=5)) || return 1

  # Note #D2062: Before mc-4.8.29, it was only necessary to check whether the first line was incomplete.
  ((_ble_edit_LINENO==0)) && return 0

  # Note #D2062: MC-4.8.29 and later sends a multi-line initialization script. especially
  # The 4th line sends C-j in an incomplete state, so it is executed in an incomplete state and an error occurs.
  # It will be. If the state is incomplete, it is converted to insert a new line instead of executing the command.
  #
  # ---- mc initialization input script example ----
  #  mc_print_command_buffer () { printf "%s\\n" "$READLINE_LINE" >&13; }
  #  bind -x '"\e_":"mc_print_command_buffer"'
  #  bind -x '"\e+":"echo $BASH_VERSINFO:$READLINE_POINT >&18"'
  #  PROMPT_COMMAND=${PROMPT_COMMAND:+$PROMPT_COMMAND
  #  }'pwd>&16;kill -STOP $$'
  # PS1='\u@\h:\w\$ '
  # -------------------------------------
  if [[ $_ble_edit_str == *'PROMPT_COMMAND=${PROMPT_COMMAND:+$PROMPT_COMMAND'* ]]; then
    if ble/string#match "$_ble_edit_str" 'pwd>&[0-9]+;kill -STOP \$\$'; then
      _ble_edit_integration_mc_precmd_stop=1
      ble/edit/info/set-default clear
    fi
    return 0
  fi

  # Note #D2062: mc-4.8.29 uses C-o C-o to send M-_ M-+ just before returning to the mc screen.
  # Extract the current state. Record the state of the last screen at this time, and then press C-o again.
  # restore it when it was However, when used with ble.sh, this restoration is not possible.
  # I can't. Just before sending the content in M-+ ble/textarea#redraw &
  # This can be avoided by running ble/util/buffer.flush. Rewrite the binding of M-+.
  if ble/string#match "$_ble_edit_str" 'bind -x '\''"\\e\+":"([^"'\'']+)"'\'''; then
    function ble/widget/.mc_exec_command {
      ble/textarea#redraw
      ble/util/buffer.flush
      builtin eval -- "$1"
    }
    local str=${_ble_edit_str//"$BASH_REMATCH"/"ble-bind -f M-+ '.mc_exec_command '\''${BASH_REMATCH[1]}'\'''"} &&
      [[ $str != "$_ble_edit_str" ]] &&
      ble-edit/content/reset-and-check-dirty "$str"
  fi

  return 1
}

function ble/widget/accept-line {
  ble/decode/widget/keymap-dispatch "$@"
}

## @fn ble/widget/default/accept-line/.prepare-verify new_str new_ind
##   @var[in] old_str old_ind
function ble/widget/default/accept-line/.prepare-verify {
  local new_str=$1 new_ind=$2
  ble-edit/content/reset-and-check-dirty "$old_str"
  _ble_edit_ind=$old_ind
  _ble_edit_line_disabled=1 ble/edit/.relocate-textarea keep-info
  ble-edit/content/reset-and-check-dirty "$new_str"
  _ble_edit_ind=$new_ind
  _ble_edit_mark=0
  _ble_edit_mark_active=
  return 0
}
function ble/widget/default/accept-line {
  # Insert line break when grammatically incomplete
  # Note: mc (midnight commander) writes commands that include line breaks #D1392
  if [[ :$1: == *:syntax:* ]] || ble/widget/accept-line/.is-mc-init; then
    ble-edit/content/update-syntax
    if ! ble/syntax:bash/is-complete; then
      ble/widget/newline
      return "$?"
    fi
  fi

  ble-edit/content/clear-arg
  local command=$_ble_edit_str

  if [[ ! ${command//["$_ble_term_IFS"]} ]]; then
    [[ $bleopt_history_share ]] &&
      ble/builtin/history/option:n
    ble/textarea#render leave
    ble/widget/.newline keep-info
    ble/prompt/print-ruler.buff '' keep-info
    ble/textarea#render
    ble/util/buffer.flush
    return 0
  fi

  local is_line_expanded=
  local orig_str=$_ble_edit_str orig_ind=$_ble_edit_ind

  # Static abbreviation expansion
  local expand_opts=$bleopt_edit_magic_accept
  if [[ :$expand_opts: == *:sabbrev:* ]]; then
    local old_str=$_ble_edit_str old_ind=$_ble_edit_ind
    if ble/complete/sabbrev/expand; then
      if [[ :$expand_opts: == *:verify:* ]]; then
        ble/widget/default/accept-line/.prepare-verify "$_ble_edit_str" "$_ble_edit_ind"
        return 0
      fi
      command=$_ble_edit_str
      is_line_expanded=1
    elif (($?==147)); then
      return 147 # We entered menu-complete
    fi
  fi

  # Alias expansion
  local expand_types expand_type
  ble/string#split expand_types : "$expand_opts"
  for expand_type in "${expand_types[@]}"; do
    case $expand_type in
    (''|sabbrev|history|history-inline|verify|verify-syntax) ;;
    (*)
      local old_str=$_ble_edit_str old_ind=$_ble_edit_ind
      if ble/function#try ble/complete/expand:"$expand_type" accept; then
        if [[ :$expand_opts: == *:verify:* ]]; then
          ble/widget/default/accept-line/.prepare-verify "$_ble_edit_str" "$_ble_edit_ind"
          return 0
        fi
        command=$_ble_edit_str
        is_line_expanded=1
      fi ;;
    esac
  done

  # History expansion
  if [[ -o histexpand || :$expand_opts: == *:history:* ]]; then
    local old_str=$_ble_edit_str old_ind=$_ble_edit_ind
    if local ret; ble/edit/histexpand "$command"; then
      local expanded=$ret
    else
      ble/widget/.internal-print-command \
        'ble/edit/histexpand/run 1>/dev/null' pre-flush # show error message
      shopt -q histreedit &>/dev/null || ble/widget/.newline/clear-content
      return "$?"
    fi

    if [[ $expanded != "$command" ]]; then
      if shopt -q histverify &>/dev/null; then
        ble/widget/default/accept-line/.prepare-verify "$expanded" "${#expanded}"
        return 0
      fi

      is_line_expanded=1
      command=$expanded
      if [[ :$expand_opts: == *:history-inline:* ]]; then
        ble-edit/content/reset-and-check-dirty "$command"
        _ble_edit_ind=${#command}
      fi
    fi
  fi

  if [[ $is_line_expanded && :$expand_opts: == *:verify-syntax:* ]]; then
    if [[ $command != "$_ble_edit_str" ]]; then
      ble-edit/content/reset-and-check-dirty "$command"
      _ble_edit_ind=${#command}
    fi
    ble-edit/content/update-syntax
    if ! ble/syntax:bash/is-complete; then
      local old_str=$orig_str old_ind=$orig_ind
      ble/widget/default/accept-line/.prepare-verify "$_ble_edit_str" "$_ble_edit_ind"
      return 0
    fi
  fi

  # Note (#D220x): we need to render the textarea before
  # "ble-edit/exec/register" and "ble/history/add" because they increment \#
  # and \!, respectively, in the prompt.  However, we want to process
  # "ble/widget/.newline" after them because we want to keep the text content
  # (_ble_edit_str) so that histdb hooking into ADDHISTORY in ble/history/add
  # can reference the text content.
  ble/textarea#render leave

  # Register execution
  ble-edit/exec/register "$command"

  # Add edit string to history
  ble/history/add "$command"

  local show_expanded
  [[ $command != "$_ble_edit_str" ]] && show_expanded=1
  ble/widget/.newline # #D1800 register
  if [[ $show_expanded ]]; then
    local ret
    ble/edit/marker#instantiate 'expand' non-empty
    ble/util/buffer.print "$ret $command"
  fi
}

function ble/widget/accept-and-next {
  ble-edit/content/clear-arg
  ble/history/initialize
  local index=$_ble_history_INDEX
  local count=$_ble_history_COUNT

  if ((index+1<count)); then
    local HISTINDEX_NEXT=$((index+1)) # to be modified in accept-line
    ble/widget/accept-line
    ble-edit/history/goto "$HISTINDEX_NEXT"
  else
    local content=$_ble_edit_str
    ble/widget/accept-line

    count=$_ble_history_COUNT
    if ((count)); then
      local entry; ble/history/get-entry "$((count-1))"
      if [[ $entry == "$content" ]]; then
        ble-edit/history/goto "$((count-1))"
      fi
    fi

    [[ $_ble_edit_str != "$content" ]] &&
      ble-edit/content/reset "$content"
  fi
}
function ble/widget/newline {
  ble/decode/widget/keymap-dispatch "$@"
}
function ble/widget/default/newline {
  local -a KEYS=(10)
  ble/widget/self-insert
}
function ble/widget/tab-insert {
  local -a KEYS=(9)
  ble/widget/self-insert
}
function ble-edit/is-single-complete-line {
  ble-edit/content/is-single-line || return 1
  [[ $_ble_edit_str ]] && ble/decode/has-input &&
    ((0<=bleopt_accept_line_threshold&&bleopt_accept_line_threshold<=_ble_decode_input_count+ble_decode_char_rest)) &&
    return 1
  if shopt -q cmdhist &>/dev/null; then
    ble-edit/content/update-syntax
    ble/syntax:bash/is-complete || return 1
  fi
  return 0
}
function ble/widget/accept-single-line-or {
  ble/decode/widget/keymap-dispatch "$@"
}
function ble/widget/default/accept-single-line-or {
  if ble-edit/is-single-complete-line; then
    ble/widget/accept-line
  else
    ble/widget/"$@"
  fi
}
function ble/widget/accept-single-line-or-newline {
  ble/widget/accept-single-line-or newline
}
function ble/widget/edit-and-execute-command.editor {
  ret=${bleopt_editor:-${VISUAL:-${EDITOR-}}}
  [[ $ret ]] && return 0

  local -a editors=()
  if [[ :$opts: == *:vi:* ]] && ble/bin#has vim; then
    editors=(vim vi emacs nano)
  elif [[ :$opts: == *:emacs:* ]]; then
    editors=(emacs nano vim vi)
  else
    editors=(emacs vim nano vi)
  fi

  for ret in "${editors[@]}"; do
    ble/bin#has "$ret" && return 0
  done

  ret=vi
  return 1
}
## @fn ble/widget/edit-and-execute-command.edit content opts
##   @var[in] content
##   @var[in] opts
##     When no-newline is not specified, enter-command-layout is executed internally.
##     Assume that ble-edit/exec/register is executed subsequently.
##   @var[out] ret
function ble/widget/edit-and-execute-command.edit {
  local content=$1 opts=:$2:

  local file=$_ble_base_run/$$.blesh-fc.bash
  ble/util/print "$content" >| "$file"

  ble/widget/edit-and-execute-command.editor; local editor=$ret

  if [[ :$opts: != *:no-newline:* ]]; then
    _ble_edit_line_disabled=1 ble/textarea#render leave
    ble/widget/.newline # #D1800 (exec/register at caller)
  fi

  ble/term/leave
  builtin eval -- "$editor"' "$file"'; local ext=$?
  ble/term/enter

  if ((ext)); then
    ret=
    ble/widget/.bell
    return 127
  fi

  ble/util/readfile ret "$file"
  return 0
}
function ble/widget/edit-and-execute-command.impl {
  local ret=
  ble/widget/edit-and-execute-command.edit "$1" "$2"
  local command=$ret

  ble/string#match "$command" $'[\n]+$' &&
    command=${command::${#command}-${#BASH_REMATCH}}
  if [[ $command != *[!"$_ble_term_IFS"]* ]]; then
    ble/edit/leave-command-layout
    ble/widget/.bell
    return 1
  fi

  # Note: Based on accept-line
  ble/edit/marker#instantiate 'fc' non-empty
  ble/util/buffer.print "$ret $command"
  ble-edit/exec/register "$command"
  ble/history/add "$command"
}
function ble/widget/edit-and-execute-command {
  ble-edit/content/clear-arg
  ble/widget/edit-and-execute-command.impl "$_ble_edit_str" "$1"
}

function ble/widget/insert-comment/.remove-comment {
  local comment_begin=$1
  ret=

  [[ $comment_begin ]] || return 1
  ble/string#escape-for-extended-regex "$comment_begin"; local rex_comment_begin=$ret
  local rex1=$'([ \t]*'$rex_comment_begin$')[^\n]*(\n|$)|[ \t]+(\n|$)|\n'
  local rex=$'^('$rex1')*$'; [[ $_ble_edit_str =~ $rex ]] || return 1

  local tail=$_ble_edit_str out=
  while [[ $tail && $tail =~ ^$rex1 ]]; do
    local rematch1=${BASH_REMATCH[1]}
    if [[ $rematch1 ]]; then
      out=$out${rematch1%?}${BASH_REMATCH:${#rematch1}}
    else
      out=$out$BASH_REMATCH
    fi
    tail=${tail:${#BASH_REMATCH}}
  done

  [[ $tail ]] && return 1

  ret=$out
}
function ble/widget/insert-comment/.insert {
  local arg=$1
  local ret; ble/util/rlvar#read comment-begin '#'
  local comment_begin=${ret::1}
  local text=
  if [[ $arg ]] && ble/widget/insert-comment/.remove-comment "$comment_begin"; then
    text=$ret
  else
    text=$comment_begin${_ble_edit_str//$'\n'/$'\n'"$comment_begin"}
  fi
  ble-edit/content/reset-and-check-dirty "$text"
}
function ble/widget/insert-comment {
  local arg; ble-edit/content/get-arg ''
  ble/widget/insert-comment/.insert "$arg"
  ble/widget/accept-line
}

function ble-edit/content/expand-command-name.proc {
  if ((tchild>=0)); then
    ble/syntax/tree-enumerate-children \
      ble-edit/content/expand-command-name.proc
  elif [[ $wtype && ! ${wtype//[0-9]} ]] && ((wtype==_ble_ctx_CMDI)); then
    local word=${_ble_edit_str:wbegin:wlen}
    local ret
    "$_ble_expand_command_name_map" "$word" && [[ $ret != "$word" ]] || return 0
    changed=1
    ble/widget/.replace-range "$wbegin" "$((wbegin+wlen))" "$ret"
  fi
}
function ble-edit/content/expand-command-name {
  local _ble_expand_command_name_map=$1
  ble-edit/content/update-syntax
  local iN= changed=
  ble/syntax/tree-enumerate ble-edit/content/expand-command-name.proc
  [[ $changed ]] && _ble_edit_mark_active=
}

function ble/widget/alias-expand-line {
  ble-edit/content/clear-arg
  ble-edit/content/expand-command-name 'ble/alias#expand'
}

function ble/widget/tilde-expand {
  ble-edit/content/clear-arg
  ble-edit/content/update-syntax
  local len=${#_ble_edit_str}
  local i=$len j=$len
  while ((--i>=0)); do
    ((_ble_syntax_attr[i])) || continue
    if ((_ble_syntax_attr[i]==_ble_attr_TILDE)); then
      local word=${_ble_edit_str:i:j-i}
      builtin eval "local path=$word"
      [[ $path != "$word" ]] &&
        ble/widget/.replace-range "$i" "$j" "$path"
    fi
    j=$i
  done
}

_ble_edit_shell_expand_ExpandWtype=()
function ble/widget/shell-expand-line.initialize {
  function ble/widget/shell-expand-line.initialize { return 0; }
  _ble_edit_shell_expand_ExpandWtype[_ble_ctx_CMDI]=1
  _ble_edit_shell_expand_ExpandWtype[_ble_ctx_ARGI]=1
  _ble_edit_shell_expand_ExpandWtype[_ble_ctx_ARGEI]=1
  _ble_edit_shell_expand_ExpandWtype[_ble_ctx_ARGVI]=1
  _ble_edit_shell_expand_ExpandWtype[_ble_ctx_RDRF]=1
  _ble_edit_shell_expand_ExpandWtype[_ble_ctx_RDRD]=1
  _ble_edit_shell_expand_ExpandWtype[_ble_ctx_RDRS]=1
  _ble_edit_shell_expand_ExpandWtype[_ble_ctx_VALI]=1
  _ble_edit_shell_expand_ExpandWtype[_ble_ctx_CONDI]=1
}
## @fn ble/widget/shell-expand-line.expand-word
##   @var[in] wtype
##   @var[out] ret flags
function ble/widget/shell-expand-line.expand-word {
  local word=$1

  # Unknown wtypes are not processed.
  ble/widget/shell-expand-line.initialize
  if [[ ! ${_ble_edit_shell_expand_ExpandWtype[wtype]} ]]; then
    ret=$word
    return 0
  fi

  # word expansion
  ret=$word; [[ $ret == '~'* ]] && ret='\'$word
  ble/syntax:bash/simple-word/eval "$ret" noglob
  if [[ $word != $ret || ${#ret[@]} -ne 1 ]]; then
    [[ $opts == *:quote:* ]] && flags=${flags}q
    return 0
  fi

  # Alias expansion
  if ((wtype==_ble_ctx_CMDI)); then
    ble/alias#expand "$word"
    [[ $word != $ret ]] && return 0
  fi

  ret=$word
}
function ble/widget/shell-expand-line.proc {
  [[ $wtype ]] || return 0

  # Inside for non-word structures (e.g. < file or [[ arg ]])
  if [[ ${wtype//[0-9]} ]]; then
    ble/syntax/tree-enumerate-children ble/widget/shell-expand-line.proc
    return 0
  fi

  local word=${_ble_edit_str:wbegin:wlen}

  # Applies to array elements when assigning an array
  local rex='^[_a-zA-Z][_a-zA-Z0-9]*=+?\('
  if ((wtype==_ble_attr_VAR)) && [[ $word =~ $rex ]]; then
    ble/syntax/tree-enumerate-children ble/widget/shell-expand-line.proc
    return 0
  fi

  local flags=
  local -a ret=() words=()
  ble/widget/shell-expand-line.expand-word "$word"
  words=("${ret[@]}")
  [[ ${#words[@]} -eq 1 && $word == "$ret" ]] && return 0

  if ((wtype==_ble_ctx_RDRF||wtype==_ble_ctx_RDRD||wtype==_ble_ctx_RDRS)); then
    local IFS=$_ble_term_IFS
    words=("${words[*]}")
  fi

  local q=\' Q="'\''" specialchars='\ ["'\''`$|&;<>()*?!^{,}'
  local w index=0 out=
  for w in "${words[@]}"; do
    ((index++)) && out=$out' '
    [[ $flags == *q* && $w == *["$specialchars"]* ]] && w=$q${w//$q/$Q}$q
    out=$out$w
  done

  changed=1
  ble/widget/.replace-range "$wbegin" "$((wbegin+wlen))" "$out"
}
## @widget shell-expand-line opts
##   @param[in] opts
##     Colon-separated options.
##     quote So that the behavior is the same as when executed directly,
##           Quote the expansion results appropriately.
function ble/widget/shell-expand-line {
  local opts=:$1:
  ble-edit/content/clear-arg
  ble/widget/history-expand-line
  ble-edit/content/update-syntax
  local iN= changed=
  ble/syntax/tree-enumerate ble/widget/shell-expand-line.proc
  [[ $changed ]] && _ble_edit_mark_active=
}

# 
#------------------------------------------------------------------------------
# **** ble-edit/undo ****                                            @edit.undo

## @var _ble_edit_undo_hindex=
##   History item number of information held by the current _ble_edit_undo.
##   Initially, it is an empty string, indicating that it is not any history item.
##

_ble_edit_undo=()
_ble_edit_undo_index=0
_ble_edit_undo_history=()
_ble_edit_undo_hindex=
ble/array#push _ble_textarea_local_VARNAMES \
               _ble_edit_undo \
               _ble_edit_undo_index \
               _ble_edit_undo_history \
               _ble_edit_undo_hindex
function ble-edit/undo/.check-hindex {
  local hindex; ble/history/get-index -v hindex
  [[ $_ble_edit_undo_hindex == "$hindex" ]] && return 0

  # save
  if [[ $_ble_edit_undo_hindex ]]; then
    local uindex=${_ble_edit_undo_index:-${#_ble_edit_undo[@]}}
    local ret; ble/string#quote-words "$uindex" "${_ble_edit_undo[@]}"
    _ble_edit_undo_history[_ble_edit_undo_hindex]=$ret
  fi

  # load
  if [[ ${_ble_edit_undo_history[hindex]} ]]; then
    local data; builtin eval -- "data=(${_ble_edit_undo_history[hindex]})"
    _ble_edit_undo=("${data[@]:1}")
    _ble_edit_undo_index=${data[0]}
  else
    _ble_edit_undo=()
    _ble_edit_undo_index=0
  fi
  _ble_edit_undo_hindex=$hindex
}
function ble-edit/undo/clear-all {
  _ble_edit_undo=()
  _ble_edit_undo_index=0
  _ble_edit_undo_history=()
  _ble_edit_undo_hindex=
}
function ble-edit/undo/history-change.hook {
  local kind=$1; shift
  case $kind in
  (delete)
    ble/builtin/history/array#delete-hindex _ble_edit_undo_history "$@"
    _ble_edit_undo_hindex= ;;
  (clear)
    ble-edit/undo/clear-all ;;
  (insert)
    ble/builtin/history/array#insert-range _ble_edit_undo_history "$@"
    local beg=$1 len=$2
    [[ $_ble_edit_undo_hindex ]] &&
      ((_ble_edit_undo_hindex>=beg)) &&
      ((_ble_edit_undo_hindex+=len)) ;;
  esac
}
blehook history_change!=ble-edit/undo/history-change.hook

## @fn ble-edit/undo/.get-current-state
##   @var[out] str ind
function ble-edit/undo/.get-current-state {
  if ((_ble_edit_undo_index==0)); then
    str=
    if [[ $_ble_history_prefix || $_ble_history_load_done ]]; then
      local index; ble/history/get-index
      ble/history/get-entry -v str "$index"
    fi
    ind=${#entry}
  else
    local entry=${_ble_edit_undo[_ble_edit_undo_index-1]}
    str=${entry#*:} ind=${entry%%:*}
  fi
}

function ble-edit/undo/add {
  ble-edit/undo/.check-hindex

  local str ind; ble-edit/undo/.get-current-state
  if [[ $_ble_edit_str != "$str" ]]; then
    # add a new entry
    _ble_edit_undo[_ble_edit_undo_index++]=$_ble_edit_ind:$_ble_edit_str
    if ((${#_ble_edit_undo[@]}>_ble_edit_undo_index)); then
      # clear redo history on change of the command line
      _ble_edit_undo=("${_ble_edit_undo[@]::_ble_edit_undo_index}")
    fi
  elif ((_ble_edit_undo_index>0&&_ble_edit_ind!=${ind##*,})); then
    # update the latest position in the existing entry
    _ble_edit_undo[_ble_edit_undo_index-1]=${ind%%,*},$_ble_edit_ind:$_ble_edit_str
  fi
}
## @fn ble-edit/undo/.load [opts]
##   @var[in] opts
##     @opt redo
function ble-edit/undo/.load {
  # resolve the default policy for the cursor position
  local point=$bleopt_undo_point
  case $point in
  (beg|end|first|last|near) ;;
  (auto|*)
    if local keymap; ble/decode/keymap/get-major-keymap; [[ $keymap == vi_[noxs]map ]]; then
      point=near
    else
      point=beg
    fi ;;
  esac
  if [[ $point == near ]]; then
    if [[ :$1: == *:redo:* ]]; then
      point=first
    else
      point=last
    fi
  fi

  local str ind; ble-edit/undo/.get-current-state
  if [[ $point == end || $point == beg ]]; then

    # Note: Regardless of the actual editing process, around the current position _ble_edit_ind
    #   The "change range" will be determined only from the character strings before and after the change.
    local old=$_ble_edit_str new=$str ret
    if [[ $bleopt_undo_point == end ]]; then
      ble/string#common-suffix "${old:_ble_edit_ind}" "$new"; local s1=${#ret}
      local old=${old::${#old}-s1} new=${new::${#new}-s1}
      ble/string#common-prefix "${old::_ble_edit_ind}" "$new"; local p1=${#ret}
      local old=${old:p1} new=${new:p1}
      ble/string#common-suffix "$old" "$new"; local s2=${#ret}
      local old=${old::${#old}-s2} new=${new::${#new}-s2}
      ble/string#common-prefix "$old" "$new"; local p2=${#ret}
    else
      ble/string#common-prefix "${old::_ble_edit_ind}" "$new"; local p1=${#ret}
      local old=${old:p1} new=${new:p1}
      ble/string#common-suffix "${old:_ble_edit_ind-p1}" "$new"; local s1=${#ret}
      local old=${old::${#old}-s1} new=${new::${#new}-s1}
      ble/string#common-prefix "$old" "$new"; local p2=${#ret}
      local old=${old:p2} new=${new:p2}
      ble/string#common-suffix "$old" "$new"; local s2=${#ret}
    fi

    local beg=$((p1+p2)) end0=$((${#_ble_edit_str}-s1-s2)) end=$((${#str}-s1-s2))
    ble-edit/content/replace "$beg" "$end0" "${str:beg:end-beg}"

    if [[ $bleopt_undo_point == end ]]; then
      ind=$end
      if ((beg<end)); then
        local keymap
        ble/decode/keymap/get-major-keymap
        [[ $keymap == vi_nmap ]] && ((end--))
      fi
    else
      ind=$beg
    fi
  else
    if [[ $point == first ]]; then
      ind=${ind%%,*}
    else
      ind=${ind##*,}
    fi
    ble-edit/content/reset-and-check-dirty "$str"
  fi

  _ble_edit_ind=$ind
  return 0
}
function ble-edit/undo/undo {
  local arg=${1:-1}
  ble-edit/undo/.check-hindex
  ble-edit/undo/add # Record any changes since the last add/load
  ((_ble_edit_undo_index)) || return 1
  ((_ble_edit_undo_index-=arg))
  ((_ble_edit_undo_index<0&&(_ble_edit_undo_index=0)))
  ble-edit/undo/.load
}
function ble-edit/undo/redo {
  local arg=${1:-1}
  ble-edit/undo/.check-hindex
  ble-edit/undo/add # Record any changes since the last add/load
  local ucount=${#_ble_edit_undo[@]}
  ((_ble_edit_undo_index<ucount)) || return 1
  ((_ble_edit_undo_index+=arg))
  ((_ble_edit_undo_index>=ucount&&(_ble_edit_undo_index=ucount)))
  ble-edit/undo/.load redo
}
function ble-edit/undo/revert {
  ble-edit/undo/.check-hindex
  ble-edit/undo/add # Record any changes since the last add/load
  ((_ble_edit_undo_index)) || return 1
  ((_ble_edit_undo_index=0))
  ble-edit/undo/.load
}
function ble-edit/undo/revert-toggle {
  local arg=${1:-1}
  ((arg%2==0)) && return 0
  ble-edit/undo/.check-hindex
  ble-edit/undo/add # Record any changes since the last add/load
  if ((_ble_edit_undo_index)); then
    ((_ble_edit_undo_index=0))
    ble-edit/undo/.load
  elif ((${#_ble_edit_undo[@]})); then
    ((_ble_edit_undo_index=${#_ble_edit_undo[@]}))
    ble-edit/undo/.load redo
  else
    return 1
  fi
}

# Note: The following three functions are designed to be called in the "emacs"
# and "vi_imap" keymaps.  In the actual code, these need to be called under the
# name "emacs/*" and "vi_imap/*" to suppress unwanted "undo" registration.
function ble/widget/undo {
  local arg; ble-edit/content/get-arg 1
  ble-edit/undo/undo "$arg" || ble/widget/.bell 'no more older undo history'
}
function ble/widget/redo {
  local arg; ble-edit/content/get-arg 1
  ble-edit/undo/redo "$arg" || ble/widget/.bell 'no more recent undo history'
}
function ble/widget/revert {
  local arg; ble-edit/content/clear-arg
  ble-edit/undo/revert
}

# 
#------------------------------------------------------------------------------
# **** ble-edit/keyboard-macro ****                                 @edit.macro

_ble_edit_kbdmacro_record=
_ble_edit_kbdmacro_last=()
_ble_edit_kbdmacro_onplay=
function ble/widget/start-keyboard-macro {
  ble/keymap:generic/clear-arg
  [[ $_ble_edit_kbdmacro_onplay ]] && return 0 # Ignored during playback
  if ! ble/decode/charlog#start kbd-macro; then
    if [[ $_ble_decode_keylog_chars_enabled == kbd-macro ]]; then
      ble/widget/.bell 'kbd-macro: recording is already started'
    else
      ble/widget/.bell 'kbd-macro: the logging system is currently busy'
    fi
    return 1
  fi

  _ble_edit_kbdmacro_record=1
  if [[ $_ble_decode_keymap == emacs ]]; then
    ble/keymap:emacs/update-mode-indicator
  elif [[ $_ble_decode_keymap == vi_nmap ]]; then
    ble/keymap:vi/adjust-command-mode
  fi
  return 0
}
function ble/widget/end-keyboard-macro {
  ble/keymap:generic/clear-arg
  [[ $_ble_edit_kbdmacro_onplay ]] && return 0 # Ignored during playback
  if [[ $_ble_decode_keylog_chars_enabled != kbd-macro ]]; then
    ble/widget/.bell 'kbd-macro: recording is not running'
    return 1
  fi
  _ble_edit_kbdmacro_record=

  ble/decode/charlog#end-exclusive-depth1
  _ble_edit_kbdmacro_last=("${ret[@]}")
  if [[ $_ble_decode_keymap == emacs ]]; then
    ble/keymap:emacs/update-mode-indicator
  elif [[ $_ble_decode_keymap == vi_nmap ]]; then
    ble/keymap:vi/adjust-command-mode
  fi
  return 0
}
function ble/widget/call-keyboard-macro {
  local arg; ble-edit/content/get-arg 1
  ble/keymap:generic/clear-arg
  ((arg>0)) || return 1
  [[ $_ble_edit_kbdmacro_onplay ]] && return 0 # Ignored during playback

  local _ble_edit_kbdmacro_onplay=1
  if ((arg==1)); then
    ble/widget/.MACRO "${_ble_edit_kbdmacro_last[@]}"
  else
    local -a chars=()
    while ((arg-->0)); do
      ble/array#push chars "${_ble_edit_kbdmacro_last[@]}"
    done
    ble/widget/.MACRO "${chars[@]}"
  fi
  [[ $_ble_decode_keymap == vi_nmap ]] &&
    ble/keymap:vi/adjust-command-mode
}
function ble/widget/print-keyboard-macro {
  ble/keymap:generic/clear-arg
  local ret; ble/decode/charlog#encode "${_ble_edit_kbdmacro_last[@]}"
  ble/edit/info/show text "kbd-macro: $ret"
  [[ $_ble_decode_keymap == vi_nmap ]] &&
    ble/keymap:vi/adjust-command-mode
  return 0
}

# 
#------------------------------------------------------------------------------
# **** history ****                                                    @history

bleopt/declare -v history_default_point 'auto'
function bleopt/check:history_default_point {
  case $value in
  (begin|end|near|far|preserve|auto) return 0 ;;
  (beginning-of-line|end-of-line|preserve-column) return 0 ;;
  (beginning-of-logical-line|end-of-logical-line|preserve-logical-column) return 0 ;;
  (beginning-of-graphical-line|end-of-graphical-line|preserve-graphical-column) return 0;;
  (*)
    ble/util/print "bleopt: Unrecognized value history_default_point='$value'." >&2
    return 1
  esac
}

bleopt/declare -o history_preserve_point history_default_point
function bleopt/check:history_preserve_point {
  case $value in
  (begin|end|near|far|preserve|auto) ;;
  (beginning-of-line|end-of-line|preserve-column) ;;
  (beginning-of-logical-line|end-of-logical-line|preserve-logical-column) ;;
  (beginning-of-graphical-line|end-of-graphical-line|preserve-graphical-column) ;;
  ('') value=end ;;
  (*) value=preserve ;;
  esac
  bleopt/declare/.check-renamed-option history_preserve_point history_default_point
}

## @fn ble-edit/history/goto index [opts]
##   @param[in] index
##   @param[in,opt] opts
##     @opt point=POINT ... When this is specified, the cursor position after
##       the history movement is placed based on POINT instead of "bleopt
##       history_default_point".
##     @opt point=none ... When this is specified, the cursor position is set
##       to 0 instead of placing at the position specified by "bleopt
##       history_default_point".
##     @opt linewise ... When this is specified, the cursor position
##       arrangement specified by "point" is converted to a linewise version.
##       In particular, "begin", "end", "near", and "far" are affected.
function ble-edit/history/goto {
  ble/history/initialize

  local histlen=$_ble_history_COUNT
  local index0=$_ble_history_INDEX
  local index1=$1

  ((index0==index1)) && return 0

  if ((index1>histlen)); then
    index1=$histlen
    ble/widget/.bell
  elif ((index1<0)); then
    index1=0
    ble/widget/.bell
  fi

  ((index0==index1)) && return 0

  if [[ $bleopt_history_share && ! $_ble_history_prefix && $_ble_decode_keymap != isearch ]]; then
    # Note: If the history information is rewritten by history/goto in the middle of isearch, something strange will happen.
    #   isearch does not read using history_share.
    #   On the other hand, nsearch and lastarg refer to past history items, but
    #   It never calls ble-edit/history/goto.
    if ((index0==histlen||index1==histlen)); then
      ble/builtin/history/option:n
      local histlen2=$_ble_history_COUNT
      if ((histlen!=histlen2)); then
        ble/textarea#invalidate
        ble-edit/history/goto "$((index1==histlen?histlen:index1))" "$2"
        return "$?"
      fi
    fi
  fi

  # store
  ble/history/set-edited-entry "$index0" "$_ble_edit_str"
  ble/history/onleave.fire

  local opts=$2
  if ((index1>=index0)); then
    opts=$opts:forward
  else
    opts=$opts:backward
  fi
  local point point_x point_opts
  ble-edit/history/goto/.prepare-point "$opts"

  # restore
  ble/history/set-index "$index1"
  local entry; ble/history/get-edited-entry -v entry "$index1"
  ble-edit/content/reset "$entry" history

  _ble_edit_ind=0
  _ble_edit_mark=0
  _ble_edit_mark_active=
  ble-edit/history/goto/.set-point
}

## @fn ble-edit/history/goto/.prepare-point opts
##   @param[in] opts
##   @bleopt history_default_point
##   @bleopt edit_line_type
##   @var[out] point point_x point_opts
function ble-edit/history/goto/.prepare-point {
  point_opts=$1
  point_x=

  local ret
  ble/opts#extract-last-optarg "$point_opts" point
  [[ $ret ]] || ret=$bleopt_history_default_point
  point=$ret

  if [[ $point == auto ]]; then
    ble/opts#extract-last-optarg "$point_opts" default-point
    if [[ $ret ]]; then
      point=$ret
    else
      point=end
    fi
  fi

  case $point in
  (near)
    if [[ :$point_opts: == *:backward:* ]]; then
      # The last time I went back
      point=end
    else
      # The first time I moved on
      point=begin
    fi ;;
  (far)
    # The opposite of near. Continuous history movement becomes easier.
    if [[ :$point_opts: == *:backward:* ]]; then
      point=begin
    else
      point=end
    fi ;;
  esac

  if [[ :$point_opts: == *:linewise:* ]]; then
    case $point in
    (begin) point=beginning-of-line ;;
    (end) point=end-of-line ;;
    (preserve) point=preserve-column ;;
    esac
  fi
  case $point in
  (end-of-line|beginning-of-line|preserve-column)
    local prefix
    if [[ :$point_opts: == *:graphical:* ]]; then
      prefix=graphical
    elif [[ :$point_opts: == *:logical:* ]]; then
      prefix=logical
    elif [[ $bleopt_edit_line_type == graphical ]]; then
      prefix=graphical
    else
      prefix=logical
    fi
    point=${point%-*}-$prefix-${point##*-} ;;
  esac

  # record column position
  case $point in
  (preserve)
    point_x=$_ble_edit_ind ;;
  (preserve-logical-column)
    point_x=${_ble_edit_str::_ble_edit_ind}
    point_x=${point_x##*$'\n'}
    point_x=${#point_x} ;;
  (preserve-graphical-column)
    ble/textmap#is-up-to-date || ble/widget/.update-textmap
    local x y
    ble/textmap#getxy.cur "$_ble_edit_ind"
    point_x=$x ;;
  (beginning-of-logical-line)
    point=preserve-logical-column
    point_x=0 ;;
  (beginning-of-graphical-line)
    point=preserve-graphical-column
    point_x=0 ;;
  esac
}

## @fn ble-edit/history/goto/.set-point [delta]
##   @param[in] delta
##   @var[in] point point_x point_opts
##
##   @var[in] _ble_edit_str
##   @var[ref] _ble_edit_ind
function ble-edit/history/goto/.set-point {
  local delta=${1:-0} ret

  case $point in
  (begin)
    _ble_edit_ind=0 ;;
  (end)
    _ble_edit_ind=${#_ble_edit_str} ;;
  (end-of-logical-line)
    if [[ :$point_opts: == *:backward:* ]]; then
      # When going back, the end of the last line
      ble-edit/content/find-logical-eol "${#_ble_edit_str}" "$((-delta))"
    else
      # When advanced, the end of the first line
      ble-edit/content/find-logical-eol 0 "$delta"
    fi
    _ble_edit_ind=$ret ;;
  (end-of-graphical-line)
    ble/textmap#is-up-to-date || ble/widget/.update-textmap
    if [[ :$point_opts: == *:backward:* ]]; then
      ble-edit/content/find-graphical-eol "${#_ble_edit_str}" "$((-delta))"
    else
      ble-edit/content/find-graphical-eol "$index" "$delta"
    fi
    _ble_edit_ind=$ret ;;
  (preserve)
    _ble_edit_ind=$point_x
    if ((_ble_edit_ind>${#_ble_edit_str})); then
      _ble_edit_ind=${#_ble_edit_str}
    fi ;;
  (preserve-logical-column)
    if [[ :$point_opts: == *:backward:* ]]; then
      ble-edit/content/find-logical-bol 0 "$delta"; local beg=$ret
    else
      ble-edit/content/find-logical-bol "${#_ble_edit_str}" "$((-delta))"; local beg=$ret
    fi
    _ble_edit_ind=$beg
    if ((point_x)); then
      ((_ble_edit_ind+=point_x))
      ble-edit/content/find-logical-eol "$beg"
      ((_ble_edit_ind>ret)) && _ble_edit_ind=$ret
    fi ;;
  (preserve-graphical-column)
    ble/textmap#is-up-to-date || ble/widget/.update-textmap
    if [[ :$point_opts: == *:backward:* ]]; then
      local x y
      ble/textmap#getxy.cur "${#_ble_edit_str}"
      ((y-=delta))
    else
      local y=$delta
    fi
    local index
    ble/textmap#get-index-at "$point_x" "$y"
    _ble_edit_ind=$index ;;
  esac
}

function ble-edit/history/history-message.hook {
  ((_ble_edit_attached)) || return 1
  local message=$1
  if [[ $message ]]; then
    ble/edit/info/immediate-show text "$message"
  else
    ble/edit/info/immediate-default
  fi
}
blehook history_message!=ble-edit/history/history-message.hook

# 
#------------------------------------------------------------------------------
# **** basic history widgets ****                               @history.widget

function ble/widget/history-next {
  if [[ $_ble_history_prefix || $_ble_history_load_done ]]; then
    local arg; ble-edit/content/get-arg 1
    ble/history/initialize
    ble-edit/history/goto "$((_ble_history_INDEX+arg))"
  else
    ble-edit/content/clear-arg
    ble/widget/.bell
  fi
}
function ble/widget/history-prev {
  local arg; ble-edit/content/get-arg 1
  ble/history/initialize
  ble-edit/history/goto "$((_ble_history_INDEX-arg))"
}
function ble/widget/history-beginning {
  ble-edit/content/clear-arg
  ble-edit/history/goto 0
}
function ble/widget/history-end {
  ble-edit/content/clear-arg
  if [[ $_ble_history_prefix || $_ble_history_load_done ]]; then
    ble/history/initialize
    ble-edit/history/goto "$_ble_history_COUNT"
  else
    ble/widget/.bell
  fi
}
function ble/widget/history-goto {
  local arg; ble-edit/content-get-arg 1
  if ((--arg<0)); then
    ble/history/initialize
    ((arg+=_ble_history_COUNT))
  fi
  ble-edit/history/goto "$arg"
}

## @widget history-expand-line
##   @exit Succeeds when expansion occurs. It will fail at other times.
function ble/widget/history-expand-line {
  ble-edit/content/clear-arg
  local ret
  ble/edit/histexpand "$_ble_edit_str" || return 1
  local expanded=$ret
  [[ $_ble_edit_str == "$expanded" ]] && return 1

  ble-edit/content/reset-and-check-dirty "$expanded"
  _ble_edit_ind=${#expanded}
  _ble_edit_mark=0
  _ble_edit_mark_active=
  return 0
}
function ble/widget/history-and-alias-expand-line {
  ble/widget/history-expand-line
  ble/widget/alias-expand-line
}
## @widget history-expand-backward-line
##   @exit Succeeds when expansion occurs. It will fail at other times.
function ble/widget/history-expand-backward-line {
  ble-edit/content/clear-arg
  local prevline=${_ble_edit_str::_ble_edit_ind} ret
  ble/edit/histexpand "$prevline" || return 1
  local expanded=$ret
  [[ $prevline == "$expanded" ]] && return 1

  local ret
  ble/string#common-prefix "$prevline" "$expanded"; local dmin=${#ret}

  local insert; ble-edit/content/replace-limited "$dmin" "$_ble_edit_ind" "${expanded:dmin}"
  ((_ble_edit_ind=dmin+${#insert}))
  _ble_edit_mark=0
  _ble_edit_mark_active=
  return 0
}
## @widget magic-space
##   Performs history expansion and static abbreviation expansion, then inserts whitespace.
function ble/widget/magic-space/.expand {
  local type=$bleopt_edit_magic_expand
  local opts=$bleopt_edit_magic_opts

  # (1) history expansion
  if [[ :$type: == *:history:* ]]; then
    ble/widget/history-expand-backward-line && return 0
  fi

  # (2) sabbrev expansion
  if [[ :$type: == *:sabbrev:* ]]; then
    ble/complete/sabbrev/expand type-status; local ext=$?
    if ((ext==0||32<=ext&&ext<=126)); then
      ((ext==105)) && # 105 = 'i' (inline sabbrev)
        [[ :$opts: == *:inline-sabbrev-no-insert:* ]] &&
        opt_noinsert=1
      return 0
    elif ((ext==147)); then
      return 147 # When entering menu completion
    fi
  fi

  # (3) Other expansions (including alias, autocd, and custom expansions)
  local expand_typess expand_types
  ble/string#split expand_typess : "$type"
  for expand_types in "${expand_typess[@]}"; do
    case $expand_types in
    (history|sabbrev|'') ;;
    (*) ble/function#try ble/complete/expand:"$expand_types" ;;
    esac
  done

  return 1
}
function ble/widget/magic-space {
  # keymap/vi.sh
  [[ $_ble_decode_keymap == vi_imap ]] &&
    local oind=$_ble_edit_ind ostr=$_ble_edit_str

  local arg; ble-edit/content/get-arg ''

  local opt_noinsert=
  ble/widget/magic-space/.expand; local ext=$?
  ((ext==147)) && return "$ext"

  # keymap/vi.sh
  if [[ $_ble_decode_keymap == vi_imap && $ostr != "$_ble_edit_str" ]]; then
    _ble_edit_ind=$oind _ble_edit_str=$ostr ble/keymap:vi/undo/add more
    ble/keymap:vi/undo/add more
  fi

  if [[ ! $opt_noinsert ]]; then
    local -a KEYS=(32)
    _ble_edit_arg=$arg
    ble/widget/self-insert
  fi
}
function ble/widget/magic-slash {
  ble/complete/sabbrev/expand wordwise:pattern='~*':strip-slash
  (($?==147)) && return 147 #For example, when entering menu completion in sabbrev/expand.

  local -a KEYS=(47) # /
  ble/widget/self-insert
}

# 
#------------------------------------------------------------------------------
# **** basic search functions ****                              @history.search

function ble/highlight/layer:region/mark:search/get-face { face=region_match; }

## @fn ble-edit/isearch/search/.match str rex
##   @var[in] flag_icase
##   @var[out] BASH_REMATCH
function ble-edit/isearch/search/.match {
  if [[ $flag_icase ]]; then
    shopt -s nocasematch
    [[ $1 =~ $2 ]]; local ext=$?
    shopt -u nocasematch
    return "$ext"
  fi

  [[ $1 =~ $2 ]]
}

## @fn ble-edit/isearch/search/.index str needle
##   @var[in] flag_icase
##   @var[out] beg end
function ble-edit/isearch/search/.index {
  local target=${1:$3} needle=$2
  if [[ $flag_icase ]]; then
    local ret
    ble/string#tolower "$target"; target=$ret
    ble/string#tolower "$needle"; needle=$ret
  fi
  local suffix=${target#*"$needle"}
  [[ $target != "$suffix" ]] || return 1
  ((end=${#1}-${#suffix}))
  ((beg=end-${#needle}))
  return 0
}

## @fn ble-edit/isearch/search/.last-index str needle
##   @var[in] flag_icase
##   @var[out] beg end
function ble-edit/isearch/search/.last-index {
  local target=$1 needle=$2
  if [[ $flag_icase ]]; then
    local ret
    ble/string#tolower "$target"; target=$ret
    ble/string#tolower "$needle"; needle=$ret
  fi
  local prefix=${target%"$needle"*}
  [[ $target != "$prefix" ]] || return 1
  beg=${#prefix}
  end=$((beg+${#needle}))
  return 0
}

## @fn ble-edit/isearch/search needle opts ; beg end
##   @param[in] needle
##
##   @param[in] opts
##     Colon-separated options.
##
##     + ... search forward (default)
##     - ...search backward. Matches anything whose ending position is before the current position.
##     B ... Search backward. Matches anything whose starting position is before the current position.
##     extend
##       When specified, an attempt will be made to extend the match at the current position.
##       If not specified, a new match that does not overlap with the current match range will be attempted.
##     regex
##       Attempts to match by regular expression.
##     ignore-case
##       Search is case insensitive.
##     allow_empty
##       Allows an empty match (a zero-length match) to occur at the current position.
##       By default, when there is an empty match, the search is performed again from the next position.
##
##   @var[out] beg end
##     Returns the beginning and end of the matching range when the search target is found.
##
##   @exit
##     Returns 0 when the search target is found.
##     Returns 1 otherwise.
function ble-edit/isearch/search {
  local needle=$1 opts=$2
  beg= end=
  [[ :$opts: != *:regex:* ]]; local has_regex=$?
  [[ :$opts: != *:extend:* ]]; local has_extend=$?
  local flag_icase=
  [[ :$opts: == *:ignore-case:* ]] && flag_icase=1

  local flag_empty_retry=
  if [[ :$opts: == *:-:* ]]; then
    local start=$((has_extend?_ble_edit_mark+1:_ble_edit_ind))

    if ((has_regex)); then
      ble-edit/isearch/.shift-backward-references
      local rex="^.*($needle)" padding=$((${#_ble_edit_str}-start))
      ((padding)) && rex="$rex.{$padding}"
      if ble-edit/isearch/search/.match "$_ble_edit_str" "$rex"; then
        local rematch1=${BASH_REMATCH[1]}
        if [[ $rematch1 || $BASH_REMATCH == "$_ble_edit_str" || :$opts: == *:allow_empty:* ]]; then
          ((end=${#BASH_REMATCH}-padding,
            beg=end-${#rematch1}))
          return 0
        else
          flag_empty_retry=1
        fi
      fi
    else
      if [[ $needle ]]; then
        ble-edit/isearch/search/.last-index "${_ble_edit_str::start}" "$needle" && return 0
      else
        if [[ :$opts: == *:allow_empty:* ]] || ((--start>=0)); then
          ((beg=end=start))
          return 0
        fi
      fi
    fi
  elif [[ :$opts: == *:B:* ]]; then
    local start=$((has_extend?_ble_edit_ind:_ble_edit_ind-1))
    ((start<0)) && return 1

    if ((has_regex)); then
      ble-edit/isearch/.shift-backward-references
      local rex="^.{0,$start}($needle)"
      ((start==0)) && rex="^($needle)"
      if ble-edit/isearch/search/.match "$_ble_edit_str" "$rex"; then
        local rematch1=${BASH_REMATCH[1]}
        if [[ $rematch1 || :$opts: == *:allow_empty:* ]]; then
          ((end=${#BASH_REMATCH},
            beg=end-${#rematch1}))
          return 0
        else
          flag_empty_retry=1
        fi
      fi
    else
      if [[ $needle ]]; then
        ble-edit/isearch/search/.last-index "${_ble_edit_str::start+${#needle}}" "$needle" && return 0
      else
        if [[ :$opts: == *:allow_empty:* ]] && ((--start>=0)); then
          ((beg=end=start))
          return 0
        fi
      fi
    fi
  else
    local start=$((has_extend?_ble_edit_mark:_ble_edit_ind))
    if ((has_regex)); then
      ble-edit/isearch/.shift-backward-references
      local rex="($needle).*\$"
      ((start)) && rex=".{$start}$rex"
      if ble-edit/isearch/search/.match "$_ble_edit_str" "$rex"; then
        local rematch1=${BASH_REMATCH[1]}
        if [[ $rematch1 || :$opts: == *:allow_empty:* ]]; then
          ((beg=${#_ble_edit_str}-${#BASH_REMATCH}+start))
          ((end=beg+${#rematch1}))
          return 0
        else
          flag_empty_retry=1
        fi
      fi
    else
      if [[ $needle ]]; then
        ble-edit/isearch/search/.index "$_ble_edit_str" "$needle" "$start" && return 0
      else
        if [[ :$opts: == *:allow_empty:* ]] || ((++start<=${#_ble_edit_str})); then
          ((beg=end=start))
          return 0
        fi
      fi
    fi
  fi

  # (When matching regular expression) Match again for empty match of current location
  if [[ $flag_empty_retry ]]; then
    if [[ :$opts: == *:[-B]:* ]]; then
      if ((--start>=0)); then
        local mark=$_ble_edit_mark; ((mark&&mark--))
        local ind=$_ble_edit_ind; ((ind&&ind--))
        opts=$opts:allow_empty
        _ble_edit_mark=$mark _ble_edit_ind=$ind ble-edit/isearch/search "$needle" "$opts"
        return 0
      fi
    else
      if ((++start<=${#_ble_edit_str})); then
        local mark=$_ble_edit_mark; ((mark<${#_ble_edit_str}&&mark++))
        local ind=$_ble_edit_ind; ((ind<${#_ble_edit_str}&&ind++))
        opts=$opts:allow_empty
        _ble_edit_mark=$mark _ble_edit_ind=$ind ble-edit/isearch/search "$needle" "$opts"
        return 0
      fi
    fi
  fi
  return 1
}
## @fn ble-edit/isearch/.shift-backward-references
##   @var[in,out] needle
##     Specify the regular expression to process.
##     Returns a regular expression with back references replaced.
function ble-edit/isearch/.shift-backward-references {
    # Increment the number of backward references by 1.
    # bash regular expressions do not support backreferences with more than 2 digits, so
    # Just shift \1 - \8 to \2-\9 (it becomes a problem when \9 exists, but it can't be helped).
    local rex_cc='\[[@][^]@]+[@]\]' # [:blank:] [=a=] [.a.] etc.
    local rex_bracket_expr='\[\^?]?('${rex_cc//@/:}'|'${rex_cc//@/=}'|'${rex_cc//@/.}'|[^][]|\[[^]:=.])*\[?\]'
    local rex='^('$rex_bracket_expr'|\\[^1-8])*\\[1-8]'
    local buff=
    while [[ $needle =~ $rex ]]; do
      local mlen=${#BASH_REMATCH}
      buff=$buff${BASH_REMATCH::mlen-1}$((10#0${BASH_REMATCH:mlen-1}+1))
      needle=${needle:mlen}
    done
    needle=$buff$needle
}

# 
#------------------------------------------------------------------------------
# **** incremental search ****                                 @history.isearch

## @var _ble_edit_isearch_str
##   matched string
## @var _ble_edit_isearch_dir
##   Current/previous search method
## @arr _ble_edit_isearch_arr[]
##   Record the process of incremental search.
##   Each element has the form ind:dir:beg:end:needle.
##   ind represents the history item number. dir represents the direction of history search.
##   beg and end represent the matching start and end positions, respectively.
##   Corresponds exactly to _ble_edit_ind and _ble_edit_mark.
##   needle represents the string used in the search.
## @var _ble_edit_isearch_old
##   String used in previous search
_ble_edit_isearch_opts=
_ble_edit_isearch_str=
_ble_edit_isearch_dir=-
_ble_edit_isearch_arr=()
_ble_edit_isearch_old=

## @fn ble-edit/isearch/status/append-progress-bar pos count
##   @var[in,out] text
function ble-edit/isearch/status/append-progress-bar {
  ble/util/is-unicode-output || return 1
  local pos=$1 count=$2 dir=$3
  [[ :$dir: == *:-:* || :$dir: == *:backward:* ]] && ((pos=count-1-pos))
  local ret; ble/string#create-unicode-progress-bar "$pos" "$count" 5
  text=$text$' \e[1;38;5;69;48;5;253m'$ret$'\e[m '
}

## @fn ble-edit/isearch/.show-status-with-progress.fib [pos]
##   @param[in,opt] pos
##     Specifies the current search position during a search.
##     View the progress of the search.
##
##   @var[in] fib_ntask
##     Specifies the current number of queues.
##
##   @var[in] _ble_edit_isearch_str
##   @var[in] _ble_edit_isearch_dir
##   @var[in] _ble_edit_isearch_arr
##     A variable that holds the current search state.
##
function ble-edit/isearch/.show-status-with-progress.fib {
  # output
  local ll rr
  if [[ $_ble_edit_isearch_dir == - ]]; then
    # Emacs workaround: Cannot write '<<' or "<<".
    ll=\<\< rr="  "
  else
    ll="  " rr=">>"
  fi
  local index; ble/history/get-index
  local histIndex='!'$((index+1))
  local text="(${#_ble_edit_isearch_arr[@]}: $ll $histIndex $rr) \`$_ble_edit_isearch_str'"

  if [[ $1 ]]; then
    local pos=$1
    local count; ble/history/get-count
    text=$text' searching...'
    ble-edit/isearch/status/append-progress-bar "$pos" "$count" "$_ble_edit_isearch_dir"
    local percentage=$((count?pos*1000/count:1000))
    text=$text" @$pos ($((percentage/10)).$((percentage%10))%)"
  fi
  ((fib_ntask)) && text="$text *$fib_ntask"

  ble/edit/info/show ansi "$text"
}

## @fn ble-edit/isearch/.show-status.fib
##   @var[in] fib_ntask
function ble-edit/isearch/.show-status.fib {
  ble-edit/isearch/.show-status-with-progress.fib
}
function ble-edit/isearch/show-status {
  local fib_ntask=${#_ble_util_fiberchain[@]}
  ble-edit/isearch/.show-status.fib
}
function ble-edit/isearch/erase-status {
  ble/edit/info/default
}
function ble-edit/isearch/.set-region {
  local beg=$1 end=$2
  if ((beg<end)); then
    if [[ $_ble_edit_isearch_dir == - ]]; then
      _ble_edit_ind=$beg
      _ble_edit_mark=$end
    else
      _ble_edit_ind=$end
      _ble_edit_mark=$beg
    fi
    _ble_edit_mark_active=search
  elif ((beg==end)); then
    _ble_edit_ind=$beg
    _ble_edit_mark=$beg
    _ble_edit_mark_active=
  else
    _ble_edit_mark_active=
  fi
}
## @fn ble-edit/isearch/.push-isearch-array
##   Save the current isearch information to the array _ble_edit_isearch_arr.
##
##   If the information you are about to register is the same as the current information, nothing will be done.
##   If the information you are about to register is at the top of the array,
##   Interprets this as unwinding the search and deletes the top element of the array.
##   Otherwise, add the current information to the array.
##   @var[in] ind beg end needle
##     Information about isearch that you are about to register.
function ble-edit/isearch/.push-isearch-array {
  local hash=$beg:$end:$needle

  # [... A | B] -> A (delete A from _ble_edit_isearch_arr) becomes [... | A].
  local ilast=$((${#_ble_edit_isearch_arr[@]}-1))
  if ((ilast>=0)) && [[ ${_ble_edit_isearch_arr[ilast]} == "$ind:"[-+]":$hash" ]]; then
    builtin unset -v "_ble_edit_isearch_arr[$ilast]"
    return 0
  fi

  local oind; ble/history/get-index -v oind
  local obeg=$_ble_edit_ind oend=$_ble_edit_mark
  [[ $_ble_edit_mark_active ]] || oend=$obeg
  ((obeg>oend)) && local obeg=$oend oend=$obeg
  local oneedle=$_ble_edit_isearch_str
  local ohash=$obeg:$oend:$oneedle

  # When you get [... A | B] -> B (do nothing), it becomes [... A | B].
  [[ $ind == "$oind" && $hash == "$ohash" ]] && return 0

  # [... A | B] -> C (move B to _ble_edit_isearch_arr) becomes [... A B | C].
  ble/array#push _ble_edit_isearch_arr "$oind:$_ble_edit_isearch_dir:$ohash"
}
## @fn ble-edit/isearch/.goto-match.fib
##   @var[in] fib_ntask
function ble-edit/isearch/.goto-match.fib {
  local ind=$1 beg=$2 end=$3 needle=$4

  # Save to search history (using variable ind beg end needle)
  ble-edit/isearch/.push-isearch-array

  # update status
  _ble_edit_isearch_str=$needle
  [[ $needle ]] && _ble_edit_isearch_old=$needle
  local oind; ble/history/get-index -v oind
  ((oind!=ind)) && ble-edit/history/goto "$ind"
  ble-edit/isearch/.set-region "$beg" "$end"

  # isearch display
  ble-edit/isearch/.show-status.fib
  ble/textarea#redraw
}

# ---- isearch fibers ---------------------------------------------------------

## @fn ble-edit/isearch/.next.fib opts [needle]
##   @param[in] opts
##     A colon-separated list.
##     append
##       Continues the previous search with a new needle.
##     forward
##       Change the search direction to forward.
##     backward
##       Change the search direction backwards.
##     ignore-case
##       It is not case sensitive.
function ble-edit/isearch/.next.fib {
  local opts=$1
  if [[ ! $fib_suspend ]]; then
    if [[ :$opts: == *:forward:* || :$opts: == *:backward:* ]]; then
      if [[ :$opts: == *:forward:* ]]; then
        _ble_edit_isearch_dir=+
      else
        _ble_edit_isearch_dir=-
      fi
    fi

    # Match at another position in the current line
    local needle=${2-$_ble_edit_isearch_str}
    local beg= end= search_opts=$_ble_edit_isearch_dir
    if [[ :$opts: == *:append:* ]]; then
      search_opts=$search_opts:extend
      # Note: The current item is processed here, so
      #   Do not specify append for .next-history.fib #D1025
      ble/path#remove opts append
    fi
    [[ :$opts: == *:ignore-case:* ]] &&
      search_opts=$search_opts:ignore-case
    if [[ $needle ]] && ble-edit/isearch/search "$needle" "$search_opts"; then
      local ind; ble/history/get-index -v ind
      ble-edit/isearch/.goto-match.fib "$ind" "$beg" "$end" "$needle"
      return 0
    fi
  fi
  ble-edit/isearch/.next-history.fib "$opts" "$needle"
}

## @fn ble-edit/isearch/.next-history.fib [opts [needle]]
##
##   @param[in,opt] opts
##     A colon-separated list.
##     append
##       The current history item will be searched.
##     ignore-case
##       It is not case sensitive.
##
##   @param[in,opt] needle
##     Explicitly specify what to search for when starting a new search.
##     Specify the string to search for in needle.
##
##   @var[in,out] fib_suspend
##     When interrupted, data for restarting is stored in this variable.
##     When restarting, restore the contents of this variable at the time of interruption and call this function.
##     If this variable is empty, start a new search.
##   @var[in] _ble_edit_isearch_str
##     Specifies the last matching search string.
##     This is the search target used when the search target is not explicitly specified.
##
##   @var[in] _ble_edit_isearch_dir
##     Specifies the current search direction.
##   @var[in] PREFIX_history_edit[]
##   @var[in,out] isearch_time
##
function ble-edit/isearch/.next-history.fib {
  local opts=$1
  if [[ $fib_suspend ]]; then
    # resume the previous search
    local needle=${fib_suspend#*:} isAdd=
    local index start; builtin eval -- "${fib_suspend%%:*}"
    fib_suspend=
  else
    # initialize new search
    local needle=${2-$_ble_edit_isearch_str} isAdd=
    [[ :$opts: == *:append:* ]] && isAdd=1
    ble/history/initialize
    local start=$_ble_history_INDEX
    local index=$start
  fi

  if ((!isAdd)); then
    if [[ $_ble_edit_isearch_dir == - ]]; then
      ((index--))
    else
      ((index++))
    fi
  fi

  # search
  local isearch_progress_callback=ble-edit/isearch/.show-status-with-progress.fib
  local isearch_opts=stop_check:progress
  [[ :$opts: == *:ignore-case:* ]] && isearch_opts=$isearch_opts:ignore-case
  if [[ $_ble_edit_isearch_dir == - ]]; then
    ble/history/isearch-backward-blockwise "$isearch_opts"
  else
    ble/history/isearch-forward "$isearch_opts"
  fi
  local ext=$?

  if ((ext==0)); then
    # If found

    # Get match range beg-end
    local str; ble/history/get-edited-entry -v str "$index"
    if [[ $needle ]]; then
      local ndl=$needle
      if [[ :$opts: == *:ignore-case:* ]]; then
        local ret
        ble/string#tolower "$str"; str=$ret
        ble/string#tolower "$ndl"; ndl=$ret
      fi

      if [[ $_ble_edit_isearch_dir == - ]]; then
        local prefix=${str%"$ndl"*}
      else
        local prefix=${str%%"$ndl"*}
      fi
      local beg=${#prefix} end=$((${#prefix}+${#ndl}))
    else
      local beg=${#str} end=${#str}
    fi

    ble-edit/isearch/.goto-match.fib "$index" "$beg" "$end" "$needle"
  elif ((ext==148)); then
    # If interrupted
    fib_suspend="index=$index start=$start:$needle"
    return 0
  else
    # If not found
    ble/widget/.bell "isearch: \`$needle' not found"
    return 0
  fi
}

function ble-edit/isearch/forward.fib {
  if [[ ! $_ble_edit_isearch_str ]]; then
    ble-edit/isearch/.next.fib "$_ble_edit_isearch_opts:forward" "$_ble_edit_isearch_old"
  else
    ble-edit/isearch/.next.fib "$_ble_edit_isearch_opts:forward"
  fi
}
function ble-edit/isearch/backward.fib {
  if [[ ! $_ble_edit_isearch_str ]]; then
    ble-edit/isearch/.next.fib "$_ble_edit_isearch_opts:backward" "$_ble_edit_isearch_old"
  else
    ble-edit/isearch/.next.fib "$_ble_edit_isearch_opts:backward"
  fi
}
function ble-edit/isearch/self-insert.fib {
  local needle=
  if [[ ! $fib_suspend ]]; then
    local code=$1
    ((code==0)) && return 0
    local ret; ble/util/c2s "$code"
    needle=$_ble_edit_isearch_str$ret
  fi
  ble-edit/isearch/.next.fib "$_ble_edit_isearch_opts:append" "$needle"
}
function ble-edit/isearch/insert-string.fib {
  local needle=
  [[ ! $fib_suspend ]] &&
    needle=$_ble_edit_isearch_str$1
  ble-edit/isearch/.next.fib "$_ble_edit_isearch_opts:append" "$needle"
}
function ble-edit/isearch/history-forward.fib {
  _ble_edit_isearch_dir=+
  ble-edit/isearch/.next-history.fib "$_ble_edit_isearch_opts"
}
function ble-edit/isearch/history-backward.fib {
  _ble_edit_isearch_dir=-
  ble-edit/isearch/.next-history.fib "$_ble_edit_isearch_opts"
}
function ble-edit/isearch/history-self-insert.fib {
  local needle=
  if [[ ! $fib_suspend ]]; then
    local code=$1
    ((code==0)) && return 0
    local ret; ble/util/c2s "$code"
    needle=$_ble_edit_isearch_str$ret
  fi
  ble-edit/isearch/.next-history.fib "$_ble_edit_isearch_opts:append" "$needle"
}

function ble-edit/isearch/prev {
  local sz=${#_ble_edit_isearch_arr[@]}
  ((sz==0)) && return 0

  local ilast=$((sz-1))
  local top=${_ble_edit_isearch_arr[ilast]}
  builtin unset -v '_ble_edit_isearch_arr[ilast]'

  local ind dir beg end
  ind=${top%%:*}; top=${top#*:}
  dir=${top%%:*}; top=${top#*:}
  beg=${top%%:*}; top=${top#*:}
  end=${top%%:*}; top=${top#*:}

  _ble_edit_isearch_dir=$dir
  ble-edit/history/goto "$ind"
  ble-edit/isearch/.set-region "$beg" "$end"
  _ble_edit_isearch_str=$top
  [[ $top ]] && _ble_edit_isearch_old=$top

  # isearch display
  ble-edit/isearch/show-status
}

function ble-edit/isearch/process {
  local isearch_time=0
  ble/util/fiberchain#resume
  ble-edit/isearch/show-status
}
function ble/widget/isearch/forward {
  ble/util/fiberchain#push forward
  ble-edit/isearch/process
}
function ble/widget/isearch/backward {
  ble/util/fiberchain#push backward
  ble-edit/isearch/process
}
function ble/widget/isearch/self-insert {
  local code; ble/widget/self-insert/.get-code
  ((code==0)) && return 0
  ble/util/fiberchain#push "self-insert $code"
  ble-edit/isearch/process
}
function ble/widget/isearch/history-forward {
  ble/util/fiberchain#push history-forward
  ble-edit/isearch/process
}
function ble/widget/isearch/history-backward {
  ble/util/fiberchain#push history-backward
  ble-edit/isearch/process
}
function ble/widget/isearch/history-self-insert {
  local code; ble/widget/self-insert/.get-code
  ((code==0)) && return 0
  ble/util/fiberchain#push "history-self-insert $code"
  ble-edit/isearch/process
}
function ble/widget/isearch/prev {
  local nque
  if ((nque=${#_ble_util_fiberchain[@]})); then
    local ret; ble/array#pop _ble_util_fiberchain
    ble-edit/isearch/process
  else
    ble-edit/isearch/prev
  fi
}

function ble/widget/isearch/.restore-mark-state {
  local old_mark_active=${_ble_edit_isearch_save[3]}
  if [[ $old_mark_active ]]; then
    local index; ble/history/get-index
    if ((index==_ble_edit_isearch_save[0])); then
      _ble_edit_mark=${_ble_edit_isearch_save[2]}
      if [[ $old_mark_active != S ]] || ((_ble_edit_ind==_ble_edit_isearch_save[1])); then
        _ble_edit_mark_active=$old_mark_active
      fi
    fi
  fi
}
function ble/widget/isearch/exit.impl {
  ble/decode/keymap/pop
  _ble_edit_isearch_arr=()
  _ble_edit_isearch_dir=
  _ble_edit_isearch_str=
  ble-edit/isearch/erase-status
}
function ble/widget/isearch/exit-with-region {
  ble/widget/isearch/exit.impl
  if [[ $_ble_edit_mark_active ]]; then
    _ble_edit_mark_active=S
    ble/decode/keymap/push selection
  fi
}
function ble/widget/isearch/exit {
  ble/widget/isearch/exit.impl

  _ble_edit_mark_active=
  ble/widget/isearch/.restore-mark-state
}
function ble/widget/isearch/cancel {
  if ((${#_ble_util_fiberchain[@]})); then
    ble/util/fiberchain#clear
    ble-edit/isearch/show-status # Delete only progress
  else
    if ((${#_ble_edit_isearch_arr[@]})); then
      local step
      ble/string#split step : "${_ble_edit_isearch_arr[0]}"
      ble-edit/history/goto "${step[0]}" point=none
    fi

    ble/widget/isearch/exit.impl
    _ble_edit_ind=${_ble_edit_isearch_save[1]}
    _ble_edit_mark=${_ble_edit_isearch_save[2]}
    _ble_edit_mark_active=${_ble_edit_isearch_save[3]}
  fi
}
function ble/widget/isearch/exit-default {
  ble/widget/isearch/exit-with-region
  ble/decode/widget/redispatch
}
function ble/widget/isearch/accept-line {
  if ((${#_ble_util_fiberchain[@]})); then
    ble/widget/.bell "isearch: now searching..."
  else
    ble/widget/isearch/exit
    ble-decode-key 13 # RET
  fi
}
function ble/widget/isearch/exit-delete-forward-char {
  ble/widget/isearch/exit
  ble/widget/delete-forward-char
}

## @fn ble/widget/history-isearch.impl opts
function ble/widget/history-isearch.impl {
  local opts=$1
  ble/keymap:generic/clear-arg
  ble/decode/keymap/push isearch
  ble/util/fiberchain#initialize ble-edit/isearch

  local index; ble/history/get-index
  _ble_edit_isearch_save=("$index" "$_ble_edit_ind" "$_ble_edit_mark" "$_ble_edit_mark_active")

  _ble_edit_isearch_opts=
  ble/util/rlvar#test search-ignore-case 0 &&
    _ble_edit_isearch_opts=ignore-case

  if [[ :$opts: == *:forward:* ]]; then
    _ble_edit_isearch_dir=+
  else
    _ble_edit_isearch_dir=-
  fi
  _ble_edit_isearch_arr=()
  _ble_edit_mark=$_ble_edit_ind
  ble-edit/isearch/show-status
}
function ble/widget/history-isearch-backward {
  ble/widget/history-isearch.impl backward
}
function ble/widget/history-isearch-forward {
  ble/widget/history-isearch.impl forward
}

function ble-decode/keymap:isearch/define {
  ble-bind -f __defchar__ isearch/self-insert
  ble-bind -f __line_limit__ nop

  ble-bind -f C-r         isearch/backward
  ble-bind -f C-s         isearch/forward
  ble-bind -f 'C-?'       isearch/prev
  ble-bind -f 'DEL'       isearch/prev
  ble-bind -f 'C-h'       isearch/prev
  ble-bind -f 'BS'        isearch/prev

  ble-bind -f __default__ isearch/exit-default
  ble-bind -f 'C-g'       isearch/cancel
  ble-bind -f 'C-x C-g'   isearch/cancel
  ble-bind -f 'C-M-g'     isearch/cancel
  ble-bind -f C-m         isearch/exit
  ble-bind -f RET         isearch/exit
  ble-bind -f C-j         isearch/accept-line
  ble-bind -f C-RET       isearch/accept-line
}

# 
#------------------------------------------------------------------------------
# **** non-incremental-search ****                             @history.nsearch

## @var _ble_edit_nsearch_needle
##   Holds the string to be searched for.
## @var _ble_edit_nsearch_input
##   Retains the last user-entered search target.
## @var _ble_edit_nsearch_opts
##   Holds options that control search behavior.
## @arr _ble_edit_nsearch_loadctx
##   When loading history items as part of the current command line
##   Set _ble_edit_nsearch_loadctx[0]=beg. _ble_edit_nsearch_loadctx[1]
##   is the string on the left side of the replacement range, _ble_edit_nsearch_loadctx[1] is the string on the right side of the replacement range.
##   Holds a string.
## @arr _ble_edit_nsearch_stack[]
##   Records each search match.
##   Each element has the format "direction,index,ind,mark:line".
##   Records the direction of the previous search and the state before the search.
##   index is the search history position, ind and mark are the cursor position and mark position.
##   line is the edit string.
## @var _ble_edit_nsearch_match
##   Maintains which history number the currently displayed line content corresponds to.
##   nsearch Corresponds to the starting position or the last matching position.
## @var _ble_edit_nsearch_index
##   Represents the last searched position.
##   If the search matches, it is the same as _ble_edit_nsearch_match.
## @var _ble_edit_nsearch_prev
##   Last search string
_ble_edit_nsearch_input=
_ble_edit_nsearch_needle=
_ble_edit_nsearch_index0=
_ble_edit_nsearch_opts=
_ble_edit_nsearch_loadctx=
_ble_edit_nsearch_stack=()
_ble_edit_nsearch_match=
_ble_edit_nsearch_index=
_ble_edit_nsearch_prev=

function ble/highlight/layer:region/mark:nsearch/get-face {
  face=(region_match)
  [[ ${_ble_edit_nsearch_loadctx[2]-} ]] &&
    ble/array#push face region_insert
}
function ble/highlight/layer:region/mark:nsearch/get-selection {
  local beg=$_ble_edit_mark
  local end=$((_ble_edit_mark+${#_ble_edit_nsearch_needle}))
  selection=("$beg" "$end")

  local suffix=${_ble_edit_nsearch_loadctx[2]-}
  [[ $suffix ]] && ble/array#push selection "$end" "$((${#_ble_edit_str}-${#suffix}))"
}

## @fn ble-edit/nsearch/.show-status.fib [pos_progress]
##   @var[in] fib_ntask
function ble-edit/nsearch/.show-status.fib {
  [[ :$_ble_edit_nsearch_opts: == *:hide-status:* ]] && return 0

  local ll=\<\< rr=">>" # Note: Emacs workaround: Cannot write '<<' or "<<".
  local match=$_ble_edit_nsearch_match index0=$_ble_edit_nsearch_index0
  if ((match>index0)); then
    ll="  "
  elif ((match<index0)); then
    rr="  "
  fi

  local sindex='!'$((_ble_edit_nsearch_match+1))
  local nmatch=${#_ble_edit_nsearch_stack[@]}
  local needle=$_ble_edit_nsearch_needle
  local text="(nsearch#$nmatch: $ll $sindex $rr) \`$needle'"

  if [[ $1 ]]; then
    local pos=$1
    local count; ble/history/get-count
    text=$text' searching...'
    ble-edit/isearch/status/append-progress-bar "$pos" "$count" "$_ble_edit_nsearch_opts"
    local percentage=$((count?pos*1000/count:1000))
    text=$text" @$pos ($((percentage/10)).$((percentage%10))%)"
  fi

  local ntask=$fib_ntask
  ((ntask)) && text="$text *$ntask"

  ble/edit/info/show ansi "$text"
}
function ble-edit/nsearch/show-status {
  local fib_ntask=${#_ble_util_fiberchain[@]}
  ble-edit/nsearch/.show-status.fib
}
function ble-edit/nsearch/erase-status {
  ble/edit/info/default
}

#@ToDo backward/forward backward is fixed, but is that okay?
function ble-edit/nsearch/.goto-match {
  local index=$1 opts=$2
  local direction=backward
  [[ :$opts: == *:forward:* ]] && direction=forward
  local needle=$_ble_edit_nsearch_needle
  local old_match=$_ble_edit_nsearch_match
  ble/array#push _ble_edit_nsearch_stack "$direction,$old_match,$_ble_edit_ind,$_ble_edit_mark:$_ble_edit_str"

  local left= line= right=
  if [[ ! $index ]]; then
    ble/history/get-index
    line=$_ble_edit_str
  elif [[ $_ble_edit_nsearch_loadctx ]]; then
    left=${_ble_edit_nsearch_loadctx[1]-}
    right=${_ble_edit_nsearch_loadctx[2]-}

    local old_index; ble/history/get-index -v old_index
    if ((index!=old_index)); then
      local line; ble/history/get-edited-entry -v line "$index"
      ble-edit/content/reset-and-check-dirty "$left$line$right"
    fi
  else
    ble-edit/history/goto "$index" point=none
    line=$_ble_edit_str
  fi

  # Determining the match range
  local s=$line n=$needle
  if [[ :$opts: == *:ignore-case:* ]]; then
    local ret
    ble/string#tolower "$s"; s=$ret
    ble/string#tolower "$n"; n=$ret
  fi
  local prefix=${s%%"$n"*}
  local beg=${#prefix}
  local end=$((beg+${#needle}))

  _ble_edit_nsearch_match=$index
  _ble_edit_nsearch_index=$index
  _ble_edit_mark=$beg
  local is_end_marker= ret=
  ble/opts#extract-last-optarg "$opts" point
  case $ret in
  (begin)       _ble_edit_ind=0 ;;
  (end)         _ble_edit_ind=${#line} is_end_marker=1 ;;
  (match-begin) _ble_edit_ind=$beg ;;
  (match-end|*) _ble_edit_ind=$end is_end_marker=1 ;;
  esac

  local left_len=${#left}
  ((_ble_edit_mark+=left_len,_ble_edit_ind+=left_len))

  # When inside vi_nmap, place the cursor on the last character of the match range
  if [[ $is_end_marker ]] && ((_ble_edit_ind)); then
    if local ret; ble/decode/keymap/get-parent; [[ $ret == vi_[noxs]map ]]; then
      ble-edit/content/bolp || ((_ble_edit_ind--))
    fi
  fi

  if ((beg!=end)) || [[ ${_ble_edit_nsearch_loadctx[2]-} ]]; then
    _ble_edit_mark_active=nsearch
  else
    _ble_edit_mark_active=
  fi
}

function ble-edit/nsearch/.search.fib {
  local opts=$1
  local opt_forward=
  [[ :$opts: == *:forward:* ]] && opt_forward=1

  # If the direction is opposite to the previous match, return to the state before the previous match.
  # Note: stack[0] is used to record the current line, not the match result.
  #   We will return the state only when nstack >= 2.
  local nstack=${#_ble_edit_nsearch_stack[@]}
  if ((nstack>=2)); then
    local record_type=${_ble_edit_nsearch_stack[nstack-1]%%,*}
    if
      if [[ $opt_forward ]]; then
        [[ $record_type == backward ]]
      else
        [[ $record_type == forward ]]
      fi
    then
      local ret; ble/array#pop _ble_edit_nsearch_stack
      local record line=${ret#*:}
      ble/string#split record , "${ret%%:*}"

      if [[ $_ble_edit_nsearch_loadctx ]]; then
        ble-edit/content/reset-and-check-dirty "$line"
      else
        ble-edit/history/goto "${record[1]}" point=none
      fi
      _ble_edit_nsearch_match=${record[1]}
      _ble_edit_nsearch_index=${record[1]}
      _ble_edit_ind=${record[2]}
      _ble_edit_mark=${record[3]}
      if ((_ble_edit_mark!=_ble_edit_ind)); then
        _ble_edit_mark_active=nsearch
      else
        _ble_edit_mark_active=
      fi
      ble-edit/nsearch/.show-status.fib
      ble/textarea#redraw
      fib_suspend=
      return 0
    fi
  fi

  # Performing a search
  local index start opt_resume=
  if [[ $fib_suspend ]]; then
    opt_resume=1
    builtin eval -- "$fib_suspend"
    fib_suspend=
  else
    local index=$_ble_edit_nsearch_index
    if ((nstack==1)); then
      # Initialize the search start position when the search direction is reversed
      local index0=$_ble_edit_nsearch_index0
      ((opt_forward?index<index0:index>index0)) &&
        index=$index0
    fi
    local start=$index
  fi
  local needle=$_ble_edit_nsearch_needle
  if
    if [[ $opt_forward ]]; then
      local count; ble/history/get-count
      [[ $opt_resume ]] || ((++index))
      ((index<=count))
    else
      [[ $opt_resume ]] || ((--index))
      ((index>=0))
    fi
  then
    local isearch_time=$fib_clock
    local isearch_progress_callback=ble-edit/nsearch/.show-status.fib
    local isearch_opts=stop_check:progress
    [[ :$opts: != *:substr:* ]] && isearch_opts=$isearch_opts:head
    [[ :$opts: == *:ignore-case:* ]] && isearch_opts=$isearch_opts:ignore-case
    if [[ $opt_forward ]]; then
      ble/history/isearch-forward "$isearch_opts"; local ext=$?
    else
      ble/history/isearch-backward-blockwise "$isearch_opts"; local ext=$?
    fi
    fib_clock=$isearch_time
  else
    local ext=1
  fi

  # rewrite
  if ((ext==0)); then
    ble-edit/nsearch/.goto-match "$index" "$opts"
    ble-edit/nsearch/.show-status.fib
    ble/textarea#redraw
  elif ((ext==148)); then
    fib_suspend="index=$index start=$start"
    return 148
  else
    ble/widget/.bell "ble.sh: nsearch: '$needle' not found"
    ble-edit/nsearch/.show-status.fib
    if [[ $opt_forward ]]; then
      local count; ble/history/get-count
      ((_ble_edit_nsearch_index=count-1))
    else
      ((_ble_edit_nsearch_index=0))
    fi
    return "$ext"
  fi
}
function ble-edit/nsearch/forward.fib {
  ble-edit/nsearch/.search.fib "$_ble_edit_nsearch_opts:forward"
}
function ble-edit/nsearch/backward.fib {
  ble-edit/nsearch/.search.fib "$_ble_edit_nsearch_opts:backward"
}

## @fn ble-edit/nsearch/.test str ndl opts
##   Determines whether the specified strings match.
function ble-edit/nsearch/.test {
  local str=$1 ndl=$2 opts=$3
  [[ :$opts: == *:ignore-case:* ]] &&
    shopt -s nocasematch
  if [[ :$opts: == *:substr:* ]]; then
    [[ $str == *"$ndl"* ]]
  else
    [[ $str == "$ndl"* ]]
  fi; local ext=$?
  shopt -u nocasematch
  return "$ext"
}

## @fn ble-edit/nsearch/action:load-command/initialize
##   @arr[out] _ble_edit_nsearch_loadctx
##   @exit
function ble-edit/nsearch/action:load-command/initialize {
  [[ $_ble_syntax_lang == bash ]] || return 1

  ble-edit/content/update-syntax

  local pos=$_ble_edit_ind
  ble/string#match "${_ble_edit_str:pos}" $'^[ \t]+[^ \t\n]' &&
    ((pos+=${#BASH_REMATCH}-1))
  local comp_cword comp_words comp_line comp_point tree_words
  if ble/syntax:bash/extract-command "$pos" treeinfo && ((${#tree_words[@]})); then
    # Retrieve the location of the first word (the command name)
    local wend=${tree_words[0]%:*} nofs=${tree_words[0]#*:}
    ble/string#split-words node "${_ble_syntax_tree[wend-1]}"
    local wlen=${node[nofs+1]}
    local wbeg=$((wlen<0?wlen:wend-wlen))

    local beg=$wbeg end=${tree_words[${#tree_words[@]}-1]%:*}
    ble/string#match "${_ble_edit_str:end}" $'^[ \t]+($|\n)' &&
      ((end+=${#BASH_REMATCH}))
    if ((_ble_edit_ind<=end)) || { ble/string#match "${_ble_edit_str:end:_ble_edit_ind-end}" $'^[[:blank:]\n]+$' && end=$_ble_edit_ind; }; then
      if ((beg>=0&&beg<end)); then
        ((_ble_edit_ind<beg)) && _ble_edit_ind=$beg
        _ble_edit_nsearch_loadctx=("$beg" "${_ble_edit_str::beg}" "${_ble_edit_str:end}")
        return 0
      fi
    fi
  fi

  # If the current cursor position is a location where we expect a new command
  # name, we directly load a command in the current position.
  local ret stat
  if ble/syntax/completion-context/.search-last-istat "$_ble_edit_ind" &&
     ble/string#match "${_ble_edit_str:ret:_ble_edit_ind-ret}" '^[[:blank:]]*$'
  then
    ble/string#split-words stat "${_ble_syntax_stat[ret]}"
    if [[ ${_ble_syntax_completion_context_check_prefix[stat[0]]} == next-command ]]; then
      _ble_edit_nsearch_loadctx=("$_ble_edit_ind" "${_ble_edit_str::_ble_edit_ind}" "${_ble_edit_str:_ble_edit_ind}")
      return 0
    fi
  fi

  return 1
}

## @widget history-search opts
##   @param[in] opts
##
##     forward Search forward
##     backward Search backwards
##     substr performs a partial match
## input User input of search string
##     again Use the search string previously entered by the user
##
##     empty=EMPTY
##       Specify the behavior when starting a search with an empty string.
##       previous-search Search using previous search string [default]
##       empty-search Search with empty string.
##       hide-status Empty string search. Hide nsearch state.
##       history-move Move history item. Move to the beginning of the command line.
##       emulate-readline Mimics the behavior of Readline. Set hide-status and point=end.
##
##     action=ACTION
##       Specify the behavior when a string is found.
##       goto Go to found history item [default]
##       load Replaces the current history item with the command string found.
##       load-line Replaces the current line.
##       load-command Replaces the current command according to the syntax.
##       insert Inserts at the current position.
##       insert-line Inserts a new line at the current position.
##
##     point=POINT
##       Specifies the cursor position when the string is found.
##       begin Move to the beginning of the command line.
##       end Move to the end of the command line.
##       match-begin Move to the beginning of the match range.
##       match-end Move to the end of the match range.
##
##     hide-status
##       Does not display current search status.
##
##     immediate-accept
##       Executes the command immediately upon successful completion of nsearch.
##
function ble/widget/history-search {
  local opts=$1

  # initialize variables

  _ble_edit_nsearch_loadctx=('')
  local ret
  ble/opts#extract-last-optarg "$opts" action
  local action=$ret
  case $action in
  (load)
    _ble_edit_nsearch_loadctx=(0 '' '') ;;
  (load-line)
    ble-edit/content/find-logical-bol "$_ble_edit_ind" 0; local beg=$ret
    ble-edit/content/find-logical-eol "$_ble_edit_ind" 0; local end=$ret
    _ble_edit_nsearch_loadctx=("$beg" "${_ble_edit_str::beg}" "${_ble_edit_str:end}") ;;
  (load-command)
    ble-edit/nsearch/action:load-command/initialize ||
      _ble_edit_nsearch_loadctx=(0 '' '') ;;
  (insert)
    _ble_edit_nsearch_loadctx=("$_ble_edit_ind" "${_ble_edit_str::_ble_edit_ind}" "${_ble_edit_str:_ble_edit_ind}") ;;
  (insert-line)
    local left=${_ble_edit_str::_ble_edit_ind}
    ble-edit/content/bolp || left=$left$'\n'
    local right=${_ble_edit_str:_ble_edit_ind}
    ble-edit/content/eolp || right=$'\n'$right
    _ble_edit_nsearch_loadctx=("$_ble_edit_ind" "$left" "$right") ;;
  esac

  local needle
  if [[ :$opts: == *:input:* || :$opts: == *:again:* && ! $_ble_edit_nsearch_input ]]; then
    ble/builtin/read -ep "nsearch> " needle || return 1
    _ble_edit_nsearch_input=$needle
  elif [[ :$opts: == *:again:* ]]; then
    needle=$_ble_edit_nsearch_input
  else
    local len=$_ble_edit_ind
    if [[ $_ble_decode_keymap == vi_[noxs]map ]]; then
      # When inside vi_nmap, include the character currently under the cursor in the search string
      ble-edit/content/eolp || ((len++))
    fi
    needle=${_ble_edit_str::len}
    [[ ${_ble_edit_nsearch_loadctx[0]} ]] &&
      needle=${needle:_ble_edit_nsearch_loadctx[0]}
  fi
  _ble_edit_nsearch_needle=$needle

  # Performs a different operation when the search string is empty
  if [[ ! $_ble_edit_nsearch_needle ]]; then
    local empty=empty-search
    ble/opts#extract-last-optarg "$opts" empty && empty=$ret
    case $empty in
    (history-move)
      if [[ :$opts: == *:forward:* ]]; then
        ble/widget/history-next
      else
        ble/widget/history-prev
      fi && _ble_edit_ind=0
      return "$?" ;;
    (hide-status)
      opts=$opts:hide-status ;;
    (emulate-readline)
      opts=hide-status:point=end:immediate-accept:$opts ;;
    (previous-search)
      _ble_edit_nsearch_needle=$_ble_edit_nsearch_prev ;;
    esac
  fi
  _ble_edit_nsearch_prev=$_ble_edit_nsearch_needle

  ble/keymap:generic/clear-arg

  # When neither ignore-case nor match-case is specified, readline's
  # See search-ignore-case.
  [[ :$opts: != *:ignore-case:* && :$opts: != *:match-case:* ]] &&
    ble/util/rlvar#test search-ignore-case 0 &&
    opts=$opts:ignore-case

  _ble_edit_nsearch_stack=()
  local index; ble/history/get-index
  _ble_edit_nsearch_index0=$index
  _ble_edit_nsearch_opts=$opts
  ble/path#remove _ble_edit_nsearch_opts forward
  ble/path#remove _ble_edit_nsearch_opts backward
  _ble_edit_nsearch_match=$index
  _ble_edit_nsearch_index=$index
  _ble_edit_mark_active=
  ble/decode/keymap/push nsearch

  # If the current history position matches, record it so that you can come back.
  if ble-edit/nsearch/.test "$_ble_edit_str" "$_ble_edit_nsearch_needle" "$opts"; then
    ble-edit/nsearch/.goto-match '' "$opts"
  fi

  # start search
  ble/util/fiberchain#initialize ble-edit/nsearch
  if [[ :$opts: == *:forward:* ]]; then
    ble/util/fiberchain#push forward
  else
    ble/util/fiberchain#push backward
  fi
  ble/util/fiberchain#resume
}
function ble/widget/history-nsearch-backward {
  ble/widget/history-search "input:substr:backward:$1"
}
function ble/widget/history-nsearch-forward {
  ble/widget/history-search "input:substr:forward:$1"
}
function ble/widget/history-nsearch-backward-again {
  ble/widget/history-search "again:substr:backward:$1"
}
function ble/widget/history-nsearch-forward-again {
  ble/widget/history-search "again:substr:forward:$1"
}
function ble/widget/history-search-backward {
  ble/widget/history-search "backward:$1"
}
function ble/widget/history-search-forward {
  ble/widget/history-search "forward:$1"
}
function ble/widget/history-substring-search-backward {
  ble/widget/history-search "substr:backward:$1"
}
function ble/widget/history-substring-search-forward {
  ble/widget/history-search "substr:forward:$1"
}

function ble/widget/nsearch/forward {
  local ntask=${#_ble_util_fiberchain[@]}
  if ((ntask>=1)) && [[ ${_ble_util_fiberchain[ntask-1]%%:*} == backward ]]; then
    # Cancel last backward search
    local ret; ble/array#pop _ble_util_fiberchain
  else
    ble/util/fiberchain#push forward
  fi
  ble/util/fiberchain#resume
}
function ble/widget/nsearch/backward {
  local ntask=${#_ble_util_fiberchain[@]}
  if ((ntask>=1)) && [[ ${_ble_util_fiberchain[ntask-1]%%:*} == forward ]]; then
    # Cancel last backward search
    local ret; ble/array#pop _ble_util_fiberchain
  else
    ble/util/fiberchain#push backward
  fi
  ble/util/fiberchain#resume
}
function ble/widget/nsearch/.exit {
  ble/decode/keymap/pop
  _ble_edit_mark_active=
  ble-edit/nsearch/erase-status
}
function ble/widget/nsearch/exit {
  if [[ :$_ble_edit_nsearch_opts: == *:immediate-accept:* ]]; then
    ble/widget/nsearch/accept-line
  else
    ble/widget/nsearch/.exit
  fi
}
function ble/widget/nsearch/exit-default {
  ble/widget/nsearch/.exit
  ble/decode/widget/redispatch
}
function ble/widget/nsearch/cancel {
  if ((${#_ble_util_fiberchain[@]})); then
    ble/util/fiberchain#clear
    ble-edit/nsearch/show-status
  else
    ble/widget/nsearch/.exit
    local record=${_ble_edit_nsearch_stack[0]}
    if [[ $record ]]; then
      local line=${record#*:}
      ble/string#split record , "${record%%:*}"
      if [[ $_ble_edit_nsearch_loadctx ]]; then
        ble-edit/content/reset-and-check-dirty "$line"
      else
        ble-edit/history/goto "$_ble_edit_nsearch_index0" point=none
      fi
      _ble_edit_ind=${record[2]}
      _ble_edit_mark=${record[3]}
    fi
  fi
}
function ble/widget/nsearch/accept-line {
  if ((${#_ble_util_fiberchain[@]})); then
    ble/widget/.bell "nsearch: now searching..."
  else
    ble/widget/nsearch/.exit
    ble-decode-key 13 # RET
  fi
}

function ble-decode/keymap:nsearch/define {
  ble-bind -f __default__ nsearch/exit-default
  ble-bind -f __line_limit__ nop

  ble-bind -f 'C-g'       nsearch/cancel
  ble-bind -f 'C-x C-g'   nsearch/cancel
  ble-bind -f 'C-M-g'     nsearch/cancel
  ble-bind -f C-m         nsearch/exit
  ble-bind -f RET         nsearch/exit
  ble-bind -f C-j         nsearch/accept-line
  ble-bind -f C-RET       nsearch/accept-line

  ble-bind -f C-r         nsearch/backward
  ble-bind -f C-s         nsearch/forward
  ble-bind -f C-p         nsearch/backward
  ble-bind -f C-n         nsearch/forward
  ble-bind -f up          nsearch/backward
  ble-bind -f down        nsearch/forward
  ble-bind -f prior       nsearch/backward
  ble-bind -f next        nsearch/forward
}

# 
#------------------------------------------------------------------------------
# **** common bindings ****                                          @edit.safe

function ble-decode/keymap:safe/.bind {
  [[ $ble_bind_nometa && $1 == *M-* ]] && return 0
  ble-bind -f "$1" "$2"
}
function ble-decode/keymap:safe/bind-common {
  ble-decode/keymap:safe/.bind insert      'overwrite-mode'

  # ins
  ble-decode/keymap:safe/.bind __batch_char__ 'batch-insert'
  ble-decode/keymap:safe/.bind __defchar__ 'self-insert'
  ble-decode/keymap:safe/.bind 'C-q'       'quoted-insert'
  ble-decode/keymap:safe/.bind 'C-v'       'quoted-insert'
  ble-decode/keymap:safe/.bind 'M-C-m'     'newline'
  ble-decode/keymap:safe/.bind 'M-RET'     'newline'
  ble-decode/keymap:safe/.bind paste_begin 'bracketed-paste'

  # kill
  ble-decode/keymap:safe/.bind 'C-@'       'set-mark'
  ble-decode/keymap:safe/.bind 'C-SP'      'set-mark'
  ble-decode/keymap:safe/.bind 'NUL'       'set-mark'
  ble-decode/keymap:safe/.bind 'M-SP'      'set-mark'
  ble-decode/keymap:safe/.bind 'C-x C-x'   'exchange-point-and-mark'
  ble-decode/keymap:safe/.bind 'C-w'       'kill-region-or kill-backward-uword'
  ble-decode/keymap:safe/.bind 'M-w'       'copy-region-or copy-backward-uword'
  ble-decode/keymap:safe/.bind 'C-y'       'yank'
  ble-decode/keymap:safe/.bind 'M-y'       'yank-pop'
  ble-decode/keymap:safe/.bind 'M-S-y'     'yank-pop backward'
  ble-decode/keymap:safe/.bind 'M-Y'       'yank-pop backward'

  # CUA cut/copy/paste
  ble-decode/keymap:safe/.bind 'S-delete'  'kill-region-or kill-backward-uword'
  ble-decode/keymap:safe/.bind 'C-insert'  'copy-region-or copy-backward-uword'
  ble-decode/keymap:safe/.bind 'S-insert'  'yank'

  # spaces
  ble-decode/keymap:safe/.bind 'M-\'       'delete-horizontal-space'

  ble-decode/keymap:selection/bind-shift @marked

  # charwise operations
  ble-decode/keymap:safe/.bind 'C-f'       'forward-char'
  ble-decode/keymap:safe/.bind 'C-b'       'backward-char'
  ble-decode/keymap:safe/.bind 'right'     'forward-char'
  ble-decode/keymap:safe/.bind 'left'      'backward-char'

  ble-decode/keymap:safe/.bind 'C-d'       'delete-region-or delete-forward-char'
  ble-decode/keymap:safe/.bind 'delete'    'delete-region-or delete-forward-char'
  ble-decode/keymap:safe/.bind 'C-?'       'delete-region-or delete-backward-char'
  ble-decode/keymap:safe/.bind 'DEL'       'delete-region-or delete-backward-char'
  ble-decode/keymap:safe/.bind 'C-h'       'delete-region-or delete-backward-char'
  ble-decode/keymap:safe/.bind 'BS'        'delete-region-or delete-backward-char'
  ble-decode/keymap:safe/.bind 'C-t'       'transpose-chars'

  # wordwise operations
  ble-decode/keymap:safe/.bind 'C-right'   'forward-cword'
  ble-decode/keymap:safe/.bind 'C-left'    'backward-cword'
  ble-decode/keymap:safe/.bind 'M-right'   'forward-sword'
  ble-decode/keymap:safe/.bind 'M-left'    'backward-sword'
  ble-decode/keymap:safe/.bind 'M-d'       'kill-forward-cword'
  ble-decode/keymap:safe/.bind 'M-h'       'kill-backward-cword'
  ble-decode/keymap:safe/.bind 'C-delete'  'delete-forward-cword'
  ble-decode/keymap:safe/.bind 'C-_'       'delete-backward-cword'
  ble-decode/keymap:safe/.bind 'C-DEL'     'delete-backward-cword'
  ble-decode/keymap:safe/.bind 'C-BS'      'delete-backward-cword'
  ble-decode/keymap:safe/.bind 'M-delete'  'copy-forward-sword'
  ble-decode/keymap:safe/.bind 'M-C-?'     'copy-backward-sword'
  ble-decode/keymap:safe/.bind 'M-DEL'     'copy-backward-sword'
  ble-decode/keymap:safe/.bind 'M-C-h'     'copy-backward-sword'
  ble-decode/keymap:safe/.bind 'M-BS'      'copy-backward-sword'

  ble-decode/keymap:safe/.bind 'M-f'       'forward-cword'
  ble-decode/keymap:safe/.bind 'M-b'       'backward-cword'

  ble-decode/keymap:safe/.bind 'M-c'       'capitalize-eword'
  ble-decode/keymap:safe/.bind 'M-l'       'downcase-eword'
  ble-decode/keymap:safe/.bind 'M-u'       'upcase-eword'
  ble-decode/keymap:safe/.bind 'M-t'       'transpose-ewords'

  # linewise operations
  ble-decode/keymap:safe/.bind 'C-a'       'beginning-of-line'
  ble-decode/keymap:safe/.bind 'C-e'       'end-of-line'
  ble-decode/keymap:safe/.bind 'home'      'beginning-of-line'
  ble-decode/keymap:safe/.bind 'end'       'end-of-line'
  ble-decode/keymap:safe/.bind 'M-m'       'non-space-beginning-of-line'
  ble-decode/keymap:safe/.bind 'C-p'       'backward-line' # overwritten by bind-history
  ble-decode/keymap:safe/.bind 'up'        'backward-line' # overwritten by bind-history
  ble-decode/keymap:safe/.bind 'C-n'       'forward-line'  # overwritten by bind-history
  ble-decode/keymap:safe/.bind 'down'      'forward-line'  # overwritten by bind-history
  ble-decode/keymap:safe/.bind 'C-k'       'kill-forward-line'
  ble-decode/keymap:safe/.bind 'C-u'       'kill-backward-line'

  ble-decode/keymap:safe/.bind 'C-home'    'beginning-of-text'
  ble-decode/keymap:safe/.bind 'C-end'     'end-of-text'

  # macros
  ble-decode/keymap:safe/.bind 'C-x ('     'start-keyboard-macro'
  ble-decode/keymap:safe/.bind 'C-x )'     'end-keyboard-macro'
  ble-decode/keymap:safe/.bind 'C-x e'     'call-keyboard-macro'
  ble-decode/keymap:safe/.bind 'C-x P'     'print-keyboard-macro'

  # Note: In vi, C-] is overwritten by sabbrev-expand
  ble-decode/keymap:safe/.bind 'C-]'       'character-search-forward'
  ble-decode/keymap:safe/.bind 'M-C-]'     'character-search-backward'

  ble-decode/keymap:safe/.bind 'M-x'       'execute-named-command'
}
function ble-decode/keymap:safe/bind-history {
  ble-decode/keymap:safe/.bind 'C-r'       'history-isearch-backward'
  ble-decode/keymap:safe/.bind 'C-s'       'history-isearch-forward'
  ble-decode/keymap:safe/.bind 'M-<'       'history-beginning'
  ble-decode/keymap:safe/.bind 'M->'       'history-end'
  ble-decode/keymap:safe/.bind 'C-prior'   'history-beginning'
  ble-decode/keymap:safe/.bind 'C-next'    'history-end'
  ble-decode/keymap:safe/.bind 'C-up'      'history-prev'
  ble-decode/keymap:safe/.bind 'C-down'    'history-next'
  ble-decode/keymap:safe/.bind 'C-p'       'backward-line history'
  ble-decode/keymap:safe/.bind 'up'        'backward-line history'
  ble-decode/keymap:safe/.bind 'C-n'       'forward-line history'
  ble-decode/keymap:safe/.bind 'down'      'forward-line history'
  ble-decode/keymap:safe/.bind 'prior'     'history-search-backward' # bash-5.2
  ble-decode/keymap:safe/.bind 'next'      'history-search-forward'  # bash-5.2
  ble-decode/keymap:safe/.bind 'C-x C-p'   'history-search-backward'
  ble-decode/keymap:safe/.bind 'C-x up'    'history-search-backward'
  ble-decode/keymap:safe/.bind 'C-x C-n'   'history-search-forward'
  ble-decode/keymap:safe/.bind 'C-x down'  'history-search-forward'
  ble-decode/keymap:safe/.bind 'C-x p'     'history-substring-search-backward'
  ble-decode/keymap:safe/.bind 'C-x n'     'history-substring-search-forward'
  ble-decode/keymap:safe/.bind 'C-x <'     'history-nsearch-backward'
  ble-decode/keymap:safe/.bind 'C-x >'     'history-nsearch-forward'
  ble-decode/keymap:safe/.bind 'C-x ,'     'history-nsearch-backward-again'
  ble-decode/keymap:safe/.bind 'C-x .'     'history-nsearch-forward-again'

  ble-decode/keymap:safe/.bind 'M-.'       'insert-last-argument'
  ble-decode/keymap:safe/.bind 'M-_'       'insert-last-argument'
  ble-decode/keymap:safe/.bind 'M-C-y'     'insert-nth-argument'
}
function ble-decode/keymap:safe/bind-complete {
  ble-decode/keymap:safe/.bind 'C-i'       'complete'
  ble-decode/keymap:safe/.bind 'TAB'       'complete'
  ble-decode/keymap:safe/.bind 'M-?'       'complete show_menu'
  ble-decode/keymap:safe/.bind 'M-*'       'complete insert_all'
  ble-decode/keymap:safe/.bind 'M-{'       'complete insert_braces'
  ble-decode/keymap:safe/.bind 'C-TAB'     'menu-complete'
  ble-decode/keymap:safe/.bind 'S-C-i'     'menu-complete backward'
  ble-decode/keymap:safe/.bind 'S-TAB'     'menu-complete backward'
  ble-decode/keymap:safe/.bind 'ac_enter'  'auto-complete-enter'

  ble-decode/keymap:safe/.bind 'M-/'       'complete context=filename'
  ble-decode/keymap:safe/.bind 'M-~'       'complete context=username'
  ble-decode/keymap:safe/.bind 'M-$'       'complete context=variable'
  ble-decode/keymap:safe/.bind 'M-@'       'complete context=hostname'
  ble-decode/keymap:safe/.bind 'M-!'       'complete context=command'
  ble-decode/keymap:safe/.bind 'C-x /'     'complete show_menu:context=filename'
  ble-decode/keymap:safe/.bind 'C-x ~'     'complete show_menu:context=username'
  ble-decode/keymap:safe/.bind 'C-x $'     'complete show_menu:context=variable'
  ble-decode/keymap:safe/.bind 'C-x @'     'complete show_menu:context=hostname'
  ble-decode/keymap:safe/.bind 'C-x !'     'complete show_menu:context=command'

  ble-decode/keymap:safe/.bind "M-'"       'sabbrev-expand'
  ble-decode/keymap:safe/.bind "C-x '"     'sabbrev-expand'
  ble-decode/keymap:safe/.bind 'C-x C-r'   'dabbrev-expand'

  ble-decode/keymap:safe/.bind 'M-g'       'complete context=glob'
  ble-decode/keymap:safe/.bind 'C-x *'     'complete insert_all:context=glob'
  ble-decode/keymap:safe/.bind 'C-x g'     'complete show_menu:context=glob'

  ble-decode/keymap:safe/.bind 'M-C-i'     'complete context=dynamic-history'
  ble-decode/keymap:safe/.bind 'M-TAB'     'complete context=dynamic-history'
}
function ble-decode/keymap:safe/bind-arg {
  local append_arg=append-arg${1:+'-or '}$1

  ble-decode/keymap:safe/.bind M-C-u 'universal-arg'

  ble-decode/keymap:safe/.bind M-- "$append_arg"
  ble-decode/keymap:safe/.bind M-0 "$append_arg"
  ble-decode/keymap:safe/.bind M-1 "$append_arg"
  ble-decode/keymap:safe/.bind M-2 "$append_arg"
  ble-decode/keymap:safe/.bind M-3 "$append_arg"
  ble-decode/keymap:safe/.bind M-4 "$append_arg"
  ble-decode/keymap:safe/.bind M-5 "$append_arg"
  ble-decode/keymap:safe/.bind M-6 "$append_arg"
  ble-decode/keymap:safe/.bind M-7 "$append_arg"
  ble-decode/keymap:safe/.bind M-8 "$append_arg"
  ble-decode/keymap:safe/.bind M-9 "$append_arg"

  ble-decode/keymap:safe/.bind C-- "$append_arg"
  ble-decode/keymap:safe/.bind C-0 "$append_arg"
  ble-decode/keymap:safe/.bind C-1 "$append_arg"
  ble-decode/keymap:safe/.bind C-2 "$append_arg"
  ble-decode/keymap:safe/.bind C-3 "$append_arg"
  ble-decode/keymap:safe/.bind C-4 "$append_arg"
  ble-decode/keymap:safe/.bind C-5 "$append_arg"
  ble-decode/keymap:safe/.bind C-6 "$append_arg"
  ble-decode/keymap:safe/.bind C-7 "$append_arg"
  ble-decode/keymap:safe/.bind C-8 "$append_arg"
  ble-decode/keymap:safe/.bind C-9 "$append_arg"

  ble-decode/keymap:safe/.bind -   "$append_arg"
  ble-decode/keymap:safe/.bind 0   "$append_arg"
  ble-decode/keymap:safe/.bind 1   "$append_arg"
  ble-decode/keymap:safe/.bind 2   "$append_arg"
  ble-decode/keymap:safe/.bind 3   "$append_arg"
  ble-decode/keymap:safe/.bind 4   "$append_arg"
  ble-decode/keymap:safe/.bind 5   "$append_arg"
  ble-decode/keymap:safe/.bind 6   "$append_arg"
  ble-decode/keymap:safe/.bind 7   "$append_arg"
  ble-decode/keymap:safe/.bind 8   "$append_arg"
  ble-decode/keymap:safe/.bind 9   "$append_arg"
}

function ble/widget/safe/__attach__ {
  ble/edit/info/set-default text ''
}
function ble-decode/keymap:safe/define {
  local ble_bind_nometa=
  ble-decode/keymap:safe/bind-common
  ble-decode/keymap:safe/bind-history
  ble-decode/keymap:safe/bind-complete

  ble-bind -f 'C-d'      'delete-region-or delete-forward-char-or-exit'

  ble-bind -f 'SP'       magic-space
  ble-bind -f '/'        magic-slash
  ble-bind -f 'M-^'      history-expand-line

  ble-bind -f __attach__     safe/__attach__
  ble-bind -f __line_limit__ __line_limit__

  ble-bind -f 'C-c'      discard-line
  ble-bind -f 'C-j'      accept-line
  ble-bind -f 'C-RET'    accept-line
  ble-bind -f 'C-m'      accept-single-line-or-newline
  ble-bind -f 'RET'      accept-single-line-or-newline
  ble-bind -f 'C-o'      accept-and-next
  ble-bind -f 'C-x C-e'  edit-and-execute-command
  ble-bind -f 'M-#'      insert-comment
  ble-bind -f 'M-C-e'    shell-expand-line
  ble-bind -f 'M-&'      tilde-expand
  ble-bind -f 'C-g'      bell
  ble-bind -f 'C-x C-g'  bell
  ble-bind -f 'C-M-g'    bell

  ble-bind -f 'C-l'      clear-screen
  ble-bind -f 'C-M-l'    redraw-line

  ble-bind -f 'f1'       command-help
  ble-bind -f 'C-x C-v'  display-shell-version
  ble-bind -c 'C-z'      fg
  ble-bind -f 'M-z'      zap-to-char
}

function ble-edit/bind/load-editing-mode:safe {
  ble/decode/keymap#load safe
}

ble/util/autoload "lib/keymap.emacs.sh" \
                  ble-decode/keymap:emacs/define
ble/util/autoload "lib/keymap.vi.sh" \
                  ble-decode/keymap:vi_{i,n,o,x,s,c}map/define
ble/util/autoload "lib/keymap.vi_digraph.sh" \
                  ble-decode/keymap:vi_digraph/define

function ble/widget/.change-editing-mode {
  [[ $_ble_decode_bind_state == none ]] && return 0
  local mode=$1
  if [[ $bleopt_default_keymap == auto ]]; then
    if [[ ! -o $mode ]]; then
      set -o "$mode"
      ble/decode/reset-default-keymap
      ble/decode/detach
      ble/decode/attach || ble-detach
    fi
  else
    bleopt default_keymap="$mode"
  fi
}
function ble/widget/emacs-editing-mode {
  ble/widget/.change-editing-mode emacs
}
function ble/widget/vi-editing-mode {
  ble/widget/.change-editing-mode vi
}

# 
#------------------------------------------------------------------------------
# **** ble/builtin/read ****                                         @edit.read

_ble_edit_read_accept=
_ble_edit_read_result=
function ble/widget/read/accept {
  if [[ $_ble_edit_async_read_prefix ]]; then
    local prefix=$_ble_edit_async_read_prefix
    local hook=${prefix}_accept_hook; hook=${!hook}
    ble/util/set "${prefix}_accept_hook" ''
    ble/util/set "${prefix}_cancel_hook" ''
    ble/util/set "${prefix}_before_widget" ''

    local ret
    ble/edit/async-read-mode/accept
    [[ ! $hook ]] || "$hook" "$ret"
  else
    _ble_edit_read_accept=1
    _ble_edit_read_result=$_ble_edit_str
    # [[ $_ble_edit_read_result ]] &&
    #   ble/history/add "$_ble_edit_read_result" # Note: Register also with cancel
    ble/decode/keymap/pop
  fi
}
function ble/widget/read/cancel {
  if [[ $_ble_edit_async_read_prefix ]]; then
    local hook=${_ble_edit_async_read_prefix}_cancel_hook
    ble/util/set "${_ble_edit_async_read_prefix}_accept_hook" "${!hook}"
    ble/widget/read/accept
  else
    ble/widget/read/accept
    _ble_edit_read_accept=2
  fi
}
function ble/widget/read/delete-forward-char-or-cancel {
  if [[ $_ble_edit_str ]]; then
    ble/widget/delete-forward-char
  else
    ble/widget/read/cancel
  fi
}

function ble/widget/read/__line_limit__.edit {
  local content=$1
  ble/widget/edit-and-execute-command.edit "$content" no-newline; local ext=$?
  ((ext==127)) && return "$ext"
  ble-edit/content/reset "$ret"
  ble/widget/read/accept
}
function ble/widget/read/__line_limit__ {
  ble/widget/__line_limit__ read/__line_limit__.edit
}
function ble/widget/read/__before_widget__ {
  if [[ $_ble_edit_async_read_prefix ]]; then
    local hook=${_ble_edit_async_read_prefix}_before_widget
    builtin eval -- "${!hook}"
  fi
}

function ble-decode/keymap:read/define {
  local ble_bind_nometa=
  ble-decode/keymap:safe/bind-common
  ble-decode/keymap:safe/bind-history
  # ble-decode/keymap:safe/bind-complete

  ble-bind -f __before_widget__ read/__before_widget__
  ble-bind -f __line_limit__    read/__line_limit__

  ble-bind -f 'C-c' read/cancel
  ble-bind -f 'C-\' read/cancel
  ble-bind -f 'C-m' read/accept
  ble-bind -f 'RET' read/accept
  ble-bind -f 'C-j' read/accept
  ble-bind -f 'C-d' 'delete-region-or read/delete-forward-char-or-cancel'

  # shell functions
  ble-bind -f  'C-g'     bell
  # ble-bind -f  'C-l'     clear-screen
  ble-bind -f  'C-l'     redraw-line
  ble-bind -f  'C-M-l'   redraw-line
  ble-bind -f  'C-x C-v' display-shell-version

  # command-history
  # ble-bind -f 'M-^'      history-expand-line
  # ble-bind -f 'SP'       magic-space
  # ble-bind -f '/'        magic-slash

  # ble-bind -f 'C-[' bell # unbound for "bleopt decode_isolated_esc=auto"
  ble-bind -f 'C-^' bell
}

_ble_edit_read_history=()
_ble_edit_read_history_edit=()
_ble_edit_read_history_dirt=()
_ble_edit_read_history_index=0

function ble/builtin/read/.process-option {
  case $1 in
  (-e) opt_flags=${opt_flags}r ;;
  (-i) opt_default=$2 ;;
  (-p) opt_prompt=$2 ;;
  (-u) opt_fd=$2
       ble/array#push opts_in "$@" ;;
  (-t) opt_timeout=$2 ;;
  (*)  ble/array#push opts "$@" ;;
  esac
}
function ble/builtin/read/.read-arguments {
  local is_normal_args=
  vars=()
  opts=()
  while (($#)); do
    local arg=$1; shift
    if [[ $is_normal_args || $arg != -* ]]; then
      ble/array#push vars "$arg"
    elif [[ $arg == -- ]]; then
      is_normal_args=1
    elif [[ $arg == --* ]]; then
      case $arg in
      (--help)
        opt_flags=${opt_flags}H ;;
      (*)
        ble/util/print "read: unrecognized long option '$arg'" >&2
        opt_flags=${opt_flags}E ;;
      esac
    else
      local i n=${#arg} c
      for ((i=1;i<n;i++)); do
        c=${arg:i:1}
        case ${arg:i} in
        ([adinNptu])
          if (($#)); then
            ble/builtin/read/.process-option -$c "$1"; shift
          else
            ble/util/print "read: missing option argument for '-$c'" >&2
            opt_flags=${opt_flags}E
          fi
          break ;;
        ([adinNptu]*) ble/builtin/read/.process-option -$c "${arg:i+1}"; break ;;
        ([ers]*)      ble/builtin/read/.process-option -$c ;;
        (*)
          ble/util/print "read: unrecognized option '-$c'" >&2
          opt_flags=${opt_flags}E ;;
        esac
      done
    fi
  done
}

function ble/builtin/read/.set-up-textarea {
  # Initialization
  ble/decode/keymap/push read || return 1

  [[ $_ble_edit_read_context == external ]] &&
    _ble_canvas_panel_height[0]=0

  # textarea, info
  if ble/edit/is-command-layout; then
    _ble_textarea_panel=0
  else
    _ble_textarea_panel=1
  fi
  _ble_canvas_panel_focus=$_ble_textarea_panel
  ble/textarea#invalidate
  ble/edit/info/set-default ansi ''

  # edit/prompt
  _ble_edit_PS1=$opt_prompt
  _ble_prompt_ps1_data=(0 '' '' 0 0 0 32 0 "" "")

  # edit
  _ble_edit_dirty_observer=()
  ble/widget/.newline/clear-content
  _ble_edit_arg=
  ble-edit/content/reset "$opt_default" newline
  _ble_edit_ind=${#opt_default}

  # edit/undo
  ble-edit/undo/clear-all

  # edit/history
  ble/history/set-prefix _ble_edit_read_

  # syntax, highlight
  _ble_syntax_lang=text
  _ble_edit_dirty_syntax_end0=1 # force ble/syntax/parse
  _ble_highlight_layer_list=(plain region overwrite_mode disabled)
  return 0
}
function ble/builtin/read/TRAPWINCH {
  local IFS=$_ble_term_IFS
  ble/application/onwinch
}
function ble/builtin/read/.loop {
  # This function is intended to be executed within a subshell.

  set +m # Disable job management

  # Note: It seems that eval cannot protect against failglob inside a subshell.
  #   For that reason, calling visible-bell causes read to terminate.
  #   As a workaround, remove failglob. Since it's inside a subshell, it shouldn't have any effect.
  # ref #D1090
  shopt -u failglob

  # Note: If you are in the middle of an async-read read outside, the behavior of read widgets
  # has been fixed. In this read, the processing of the outer async-read is
  # Disable async-read mode. This is a subshell, so it affects the outside
  # There isn't.
  _ble_edit_async_read_prefix=

  local ret; ble/canvas/panel/save-position; local pos0=$ret
  ble/builtin/read/.set-up-textarea || return 1
  ble/builtin/trap/install-hook WINCH readline
  blehook internal_WINCH=ble/builtin/read/TRAPWINCH

  local ret= timeout=
  if [[ $opt_timeout ]]; then
    ble/util/clock; local start_time=$ret

    # Note: When the time resolution is low, the actual resolution is 1999ms.
    #   It is possible that it is truncated to 1000ms.
    #   Process in the direction that increases the waiting time.
    ((start_time&&(start_time-=_ble_util_clock_reso-1)))

    if [[ $opt_timeout == *.* ]]; then
      local mantissa=${opt_timeout%%.*}
      local fraction=${opt_timeout##*.}000
      ((timeout=mantissa*1000+10#0${fraction::3}))
    else
      ((timeout=opt_timeout*1000))
    fi
    ((timeout<0)) && timeout=
  fi

  ble/application/render

  # Note: Settings to prevent ble-decode-key from interrupting #D0998
  #   Assuming you are not in the ble/encoding:.../is-intermediate state,
  #   I don't think ble-decode-key will be interrupted by this.
  local _ble_decode_input_count=0
  local ble_decode_char_nest=
  local -a _ble_decode_char_buffer=()

  local char=
  local _ble_edit_read_accept=
  local _ble_edit_read_result=
  while [[ ! $_ble_edit_read_accept ]]; do
    local timeout_option=
    if [[ $timeout ]]; then
      if ((_ble_bash>=40000)); then
        local timeout_frac=000$((timeout%1000))
        timeout_option="-t $((timeout/1000)).${timeout_frac:${#timeout_frac}-3}"
      else
        timeout_option="-t $((timeout/1000))"
      fi
    fi

    # read 1 character
    IFS= ble/bash/read -d '' -n 1 $timeout_option char "${opts_in[@]}"; local ext=$?
    if ((ext>128)); then
      # timeout
      #   Note: #D1467 On Cygwin/Linux, the read timeout is 142, but this is system dependent.
      #   As shown in man bash, it is determined whether it is greater than 128.
      _ble_edit_read_accept=142
      break
    fi

    # update timeout
    if [[ $timeout ]]; then
      ble/util/clock; local current_time=$ret
      ((timeout-=current_time-start_time))
      if ((timeout<=0)); then
        # timeout
        _ble_edit_read_accept=142
        break
      fi
      start_time=$current_time
    fi

    # process
    ble/util/s2c "$char"
    ble-decode-char "$ret"
    [[ $_ble_edit_read_accept ]] && break

    # render
    ble/util/is-stdin-ready 0 && continue
    ble-edit/content/check-limit
    ble-decode/.hook/erase-progress
    ble/application/render
  done

  # When you finish typing, delete it or go to the next line.
  if [[ $_ble_edit_read_context == internal ]]; then
    local -a DRAW_BUFF=()
    ble/canvas/panel#set-height.draw "$_ble_textarea_panel" 0
    ble/canvas/panel/load-position.draw "$pos0"
    ble/canvas/bflush.draw
  else
    if ((_ble_edit_read_accept==1)); then
      ble/edit/.relocate-textarea # #D1800 (OK since it is already in external state)
    else
      _ble_edit_line_disabled=1 ble/edit/.relocate-textarea # #D1800 (OK since it is already in external state)
    fi
  fi

  ble/util/buffer.flush
  ble/term/visible-bell/erase

  if ((_ble_edit_read_accept==1)); then
    local q=\' Q="'\''"
    printf %s "__ble_input='${_ble_edit_read_result//$q/$Q}'"
  elif ((_ble_edit_read_accept==142)); then
    # timeout
    return "$ext"
  else
    return 1
  fi
}

function ble/builtin/read/.impl {
  local -a opts=() vars=() opts_in=()
  # opt_flags ... E: error, H: help (--help), r: readline (-e)
  local opt_flags= opt_prompt= opt_default= opt_timeout= opt_fd=0

  # shell variable TMOUT
  local rex1='^[0-9]+(\.[0-9]*)?$|^\.[0-9]+$' rex2='^[0.]+$'
  [[ $TMOUT =~ $rex1 && ! ( $TMOUT =~ $rex2 ) ]] && opt_timeout=$TMOUT

  ble/builtin/read/.read-arguments "$@"
  if [[ $opt_flags == *[HE]* ]]; then
    if [[ $opt_flags == *H* ]]; then
      builtin read --help
    elif [[ $opt_flags == *E* ]]; then
      builtin read --usage 2>&1 1>/dev/null | ble/bin/grep ^read >&2
    fi
    return 2
  fi

  if ! [[ $opt_flags == *r* && -t $opt_fd ]]; then
    # Builtin read except when "-e option is specified and reading from terminal".
    [[ $opt_prompt ]] && ble/array#push opts -p "$opt_prompt"
    [[ $opt_timeout ]] && ble/array#push opts -t "$opt_timeout"
    __ble_args=("${opts[@]}" "${opts_in[@]}" -- "${vars[@]}")
    __ble_command='ble/bash/read "${__ble_args[@]}"'
    return 0
  fi

  ble/decode/keymap#load read
  local result _ble_edit_read_context=$_ble_term_state

  # Note: Leave it empty to avoid duplicate output in subshells.
  ble/util/buffer.flush

  [[ $_ble_edit_read_context == external ]] && ble/term/enter # If you're outside, come in.
  result=$(ble/builtin/read/.loop); local ext=$?
  [[ $_ble_edit_read_context == external ]] && ble/term/leave # return to original state

  # Note: Set-height 1 0 is set when exiting the subshell, so make sure to match.
  [[ $_ble_edit_read_context == internal ]] && ((_ble_canvas_panel_height[1]=0))

  if ((ext==0)); then
    builtin eval -- "$result"
    __ble_args=("${opts[@]}" -- "${vars[@]}")
    __ble_command='ble/bash/read "${__ble_args[@]}" <<< "$__ble_input"'
  fi
  return "$ext"
}

## @fn read [-ers] [-adinNptu arg] [name...]
##
##   Because builtin read -e does not work at all due to ble.sh,
##   Reimplement read -e using the ble.sh framework.
##
function ble/builtin/read {
  if [[ $_ble_decode_bind_state == none ]]; then
    builtin read "$@"
    return "$?"
  fi

  local _ble_local_set _ble_local_shopt
  ble/base/.adjust-bash-options _ble_local_set _ble_local_shopt

  # used by core-complete to cancel progcomp
  [[ $_ble_builtin_read_hook ]] &&
    builtin eval -- "$_ble_builtin_read_hook"

  local __ble_command= __ble_args= __ble_input=
  [[ ! $_ble_attached || $_ble_edit_exec_inside_userspace ]] && ble/base/adjust-BASH_REMATCH
  ble/builtin/read/.impl "$@"; local __ble_ext=$?
  [[ ! $_ble_attached || $_ble_edit_exec_inside_userspace ]] && ble/base/restore-BASH_REMATCH

  ble/base/.restore-bash-options _ble_local_set _ble_local_shopt
  [[ $__ble_command ]] || return "$__ble_ext"
  # Evaluated outside to avoid being covered by local variables
  builtin eval -- "$__ble_command"
}
function read {
  builtin eval -- "$_ble_bash_POSIXLY_CORRECT_local_adjust"
  ble/builtin/read "$@"
  builtin eval -- "$_ble_bash_POSIXLY_CORRECT_local_return"
}

## @fn ble/edit/async-read-mode hook prefix keymap
##   Set up the async-read mode
##   @param[in] hook
##     The name of the callback function called when the edit is complete.
##   @param[in,opt] prefix
##   @param[in,opt] keymap
##
##   @var[out] _ble_edit_async_read_prefix
##     This variable is set to PREFIX.
##   @var[out] PREFIX_accept_hook
##     This variable is set to HOOK.  After setting up the async-read mode by
##     calling ble/edit/async-read-mode, one can dynamically overwrite the
##     variable with a function name.
##   @var[out] PREFIX_cancel_hook
##     This variable is set to an empty string.  After setting up the
##     async-read mode, one can set a callback that is called on the
##     cancellation of the edit.
##   @var[out] PREFIX_before_widget
##     This variable is set to an empty string.  After setting up the
##     async-read mode, one can set a callback that is called before processing
##     any widget from the "read" keymap.  When the value
##     "ble/edit/async-read-mode/empty-cancel.hook" is set, the input can be
##     canceled by pressing [backspace].
##   @var[in] PREFIX_history*
##     These variables store the history of the accepted strings.  After
##     setting up the async-read mode, one may change the history prefix by
##     calling "ble/history/set-prefix <new-prefix>".
##
_ble_edit_async_read_prefix=
_ble_edit_async_read_accept_hook=
_ble_edit_async_read_cancel_hook=
_ble_edit_async_read_before_widget=
_ble_edit_async_read_history=()
_ble_edit_async_read_history_edit=()
_ble_edit_async_read_history_dirt=()
_ble_edit_async_read_history_index=0
function ble/edit/async-read-mode {
  local hook=$1 prefix=${2:-_ble_edit_async_read} keymap=${3:-read}
  ble/util/assert '[[ ! $_ble_edit_async_read_prefix ]]' 'it is already inside the async-read mode.' || return 1
  _ble_edit_async_read_prefix=$prefix

  # Default settings
  ble/util/set "${prefix}_accept_hook" "$hook"
  ble/util/set "${prefix}_cancel_hook" ''

  # record
  if ((_ble_textarea_panel==0)); then
    # Note #D2288: When the current textarea is shown in panel 0, its contents
    # will be visible while editing the text in async-read-mode, so we render
    # the latest state of textarea before switching to the textarea of
    # async-read-mode.
    ble/textarea#render
  else
    # Note #D2288: When the current textarea is already rendered in panel 1,
    # the textarea of async-read-mode will replace it.  To rerender the
    # original textarea after async-read-mode finishes, we perform
    # "ble/textarea#invalidate" so that the invalidated state is saved.
    ble/textarea#invalidate
  fi
  ble/textarea#save-state "$prefix"
  ble/util/save-vars "$prefix" _ble_canvas_panel_focus
  ble/util/set "${prefix}_history_prefix" "$_ble_history_prefix"

  # Initialization
  ble/decode/keymap/push "$keymap"
  ble/edit/info/default text ''

  # set up textarea
  _ble_textarea_panel=1
  _ble_canvas_panel_focus=1
  ble/textarea#invalidate

  # set up edit/prompt
  _ble_edit_PS1=$PS2
  _ble_prompt_ps1_data=(0 '' '' 0 0 0 32 0 '' '')

  # set up edit
  # Note: ble-edit/content/reset is called inside ble/widget/.newline/clear-content.
  # _ble_edit_dirty_observer is called.
  # ble/keymap:vi/mark/shift-by-dirty-range is no longer called
  # must be after _ble_edit_dirty_observer=().
  _ble_edit_dirty_observer=()
  ble/widget/.newline/clear-content
  _ble_edit_arg=

  # set up edit/undo
  ble-edit/undo/clear-all

  # set up edit/history
  ble/history/set-prefix "$prefix"

  # set up syntax, highlight
  _ble_syntax_lang=text
  _ble_edit_dirty_syntax_end0=1 # force ble/syntax/parse
  _ble_highlight_layer_list=(plain region overwrite_mode)
  return 147
}

function ble/edit/async-read-mode/accept {
  local prefix=$_ble_edit_async_read_prefix
  ble/util/assert '[[ $prefix ]]' 'it is not inside the async-read mode.' || return 1

  ret=$_ble_edit_str
  [[ $ret ]] && ble/history/add "$ret" # Note: You can also register by canceling

  # Erase
  local -a DRAW_BUFF=()
  ble/canvas/panel#set-height.draw "$_ble_textarea_panel" 0
  ble/canvas/bflush.draw

  # restoration
  ble/textarea#restore-state "$prefix"
  ble/textarea#clear-state "$prefix"
  ble/util/restore-vars "$prefix" _ble_canvas_panel_focus
  [[ $_ble_edit_overwrite_mode ]] && ble/util/buffer "$_ble_term_civis"
  local old_history_prefix_ref=${prefix}_history_prefix
  ble/history/set-prefix "${!old_history_prefix_ref}"

  ble/decode/keymap/pop
  _ble_edit_async_read_prefix=
}

## @arr _ble_edit_async_read_is_cancel_key
##   A dictionary of keys used to cancel when the command line is empty.
_ble_edit_async_read_is_cancel_key[63|_ble_decode_Ctrl]=1  # C-?
_ble_edit_async_read_is_cancel_key[127]=1                  # DEL
_ble_edit_async_read_is_cancel_key[104|_ble_decode_Ctrl]=1 # C-h
_ble_edit_async_read_is_cancel_key[8]=1                    # BS
function ble/edit/async-read-mode/empty-cancel.hook {
  if [[ ! $_ble_edit_str ]] && ((_ble_edit_async_read_is_cancel_key[KEYS[0]])); then
    ble/widget/read/cancel
    ble/decode/widget/suppress-widget
  fi
}

#------------------------------------------------------------------------------
# **** command-help ****                                          @command-help

## @fn[custom] ble/cmdinfo/help
## @fn[custom] ble/cmdinfo/help:$command
##
##   Define a shell function to display help.
##   Called from ble/widget/command-help.
##   ble/cmdinfo/help:$command is used to display help for the command $command.
##   ble/cmdinfo/help is used to display help for other commands.
##
##   @var[in] command
##   @var[in] type
##     Specify the command name and type (obtained with type -t).
##
##   @var[in] comp_line comp_point comp_words comp_cword
##     Specify the current command line and position, command name/argument, and current argument number.
##
##   @exit[out]
##     Returns 0 when help is finished.
##     Otherwise, it returns non-zero.
##

## @fn ble/widget/command-help/.read-man
##   @var[out] man_content
function ble/widget/command-help/.read-man {
  local -x _ble_local_tmpfile; ble/util/assign/mktmp
  local pager="sh -c 'cat >| \"\$_ble_local_tmpfile\"'"
  MANPAGER=$pager PAGER=$pager MANOPT= man "$@" 2>/dev/null; local ext=$? # 668ms
  ble/util/readfile man_content "$_ble_local_tmpfile" # 80ms
  ble/util/assign/rmtmp
  return "$ext"
}

function ble/widget/command-help/.locate-in-man-bash {
  local command=$1
  local ret rex

  # check if pager is less
  local pager; ble/util/get-pager pager
  local pager_cmd=${pager%%["$_ble_term_IFS"]*}
  [[ ${pager_cmd##*/} == less ]] || return 1

  # awk/gawk
  local awk=ble/bin/awk; ble/bin#has gawk && awk=gawk

  # man bash
  local man_content; ble/widget/command-help/.read-man bash || return 1 # 733ms (3 fork: man, sh, cat)

  # locate line number
  local cmd_awk
  case $command in
  ('function')  cmd_awk='name () compound-command' ;;
  ('until')     cmd_awk=while ;;
  ('command')   cmd_awk='command [' ;;
  ('source')    cmd_awk=. ;;
  ('typeset')   cmd_awk=declare ;;
  ('readarray') cmd_awk=mapfile ;;
  ('[')         cmd_awk=test ;;
  (*)           cmd_awk=$command ;;
  esac
  ble/string#escape-for-awk-regex "$cmd_awk"; local rex_awk=$ret
  rex='\b$'; [[ $awk == gawk && $cmd_awk =~ $rex ]] && rex_awk=$rex_awk'\y'

  local LC_ALL= LC_COLLATE=C 2>/dev/null
  local rex_esc=$'(\e\\[[ -?]*[@-~]||.\b)' cr=$'\r' # disable=#D1440
  local awk_script='{
    gsub(/'"$rex_esc"'/, "");
    if (!par && $0 ~ /^['"$_ble_term_blank"']*'"$rex_awk"'/) { print NR; exit; }
    par = !($0 ~ /^['"$_ble_term_blank"']*$/);
  }'
  local awk_out; ble/util/assign awk_out '"$awk" "$awk_script" 2>/dev/null <<< "$man_content"' || return 1 # 206ms (1 fork)
  local iline=${awk_out%$'\n'}; [[ $iline ]] || return 1

  # show
  ble/string#escape-for-extended-regex "$command"; local rex_ext=$ret
  rex='\b$'; [[ $command =~ $rex ]] && rex_ext=$rex_ext'\b'
  rex='^\b'; [[ $command =~ $rex ]] && rex_ext="($rex_esc|\b)$rex_ext"
  local manpager="$pager -r +'/$rex_ext$cr$((iline-1))g'"
  builtin eval -- "$manpager" <<< "$man_content"; local ext=$? # 1 fork

  ble/util/unlocal LC_COLLATE LC_ALL 2>/dev/null
  return "$ext"
}
function ble/widget/command-help/.show-bash-script {
  local _ble_local_pipeline=$1
  local -x LESS="${LESS:+$LESS }-r" # Note: Tempenv builtin eval disappears due to a bug in Bash, so #D1438
  ble/bin#has source-highlight &&
    _ble_local_pipeline='source-highlight -s sh -f esc | '$_ble_local_pipeline
  builtin eval -- "$_ble_local_pipeline"
}
function ble/widget/command-help/.locate-function-in-source {
  local func=$1 source lineno line
  ble/function#get-source-and-lineno "$func" || return 1
  [[ -f $source && -s $source ]] || return 1 # Does not read pipe etc.

  # check if pager is less
  local pager; ble/util/get-pager pager
  local pager_cmd=${pager%%["$_ble_term_IFS"]*}
  [[ ${pager_cmd##*/} == less ]] || return 1

  # check if the file really contains the function definition
  ble/util/assign line 'ble/bin/sed -n "${lineno}{p;q;}" "$source"'
  [[ $line == *"$func"* ]] || return 1

  ble/widget/command-help/.show-bash-script '"$pager" +"${lineno}g"' < "$source"
}

## @fn ble/widget/command-help.core
##   @var[in] type
##   @var[in] command
##   @var[in] comp_cword comp_words comp_line comp_point
function ble/widget/command-help.core {
  ble/function#try ble/cmdinfo/help:"$command" && return 0
  ble/function#try ble/cmdinfo/help "$command" && return 0

  if [[ $type == builtin || $type == keyword ]]; then
    # Built-in command keywords show man bash
    ble/widget/command-help/.locate-in-man-bash "$command" && return 0
  elif [[ $type == function ]]; then
    ble/widget/command-help/.locate-function-in-source "$command" && return 0

    # Shell functions show definitions
    local def; ble/function#getdef "$command"
    ble/widget/command-help/.show-bash-script ble/util/pager <<< "$def" && return 0
  fi

  if ble/is-function ble/bin/man; then
    MANOPT= ble/bin/man "${command##*/}" 2>/dev/null && return 0
    # Note: $(man "${command##*/}") does not give correct results (especially in Japanese).
    # if local content; ble/util/assign content 'MANOPT= ble/bin/man "${command##*/}" 2>&1' && [[ $content ]]; then
    #   ble/util/print "$content" | ble/util/pager
    #   return 0
    # fi
  fi

  if local content; ble/util/assign content '"$command" --help 2>&1' && [[ $content ]]; then
    ble/util/print "$content" | ble/util/pager
    return 0
  fi

  ble/util/print "ble: help of \`$command' not found" >&2
  return 1
}

## @fn ble/widget/command-help/type.resolve-alias
##   Run in subshell to resolve aliases.
##   Run in a subshell to use unalias for resolution.
##
##   @stdout type:command
##     command is the final command after resolving aliases
##     type is the type of command
##     Nothing is output when resolution fails.
##
function ble/widget/command-help/.type/.resolve-alias {
  local literal=$1 command=$2 type=alias
  local last_literal=$1 last_command=$2

  while
    [[ $command == "$literal" ]] || break # Note: type=alias

    local alias_def
    ble/util/assign alias_def "alias $command"
    builtin unalias "$command"
    builtin eval "alias_def=${alias_def#*=}" # remove quote
    literal=${alias_def%%["$_ble_term_IFS"]*} command= type=
    local ret; ble/syntax:bash/simple-word/safe-eval "$literal" nonull || break # Note: type=
    command=$ret
    ble/util/type type "$command"
    [[ $type ]] || break # Note: type=

    last_literal=$literal
    last_command=$command
    [[ $type == alias ]]
  do ((1)); done

  if [[ ! $type || $type == alias ]]; then
    # - When command matches an alias but is quoted in literal,
    #   Exit the loop with type=alias.
    # - When expanded into a complex command, the first word is not necessarily the command name.
    #   Example: alias which='(alias; declare -f) | /usr/bin/which ...'
    #   At this time, it becomes type= in the middle and exits the loop.
    #
    # In these cases, look for a non-alias name in the previous successful command name.
    literal=$last_literal
    command=$last_command
    builtin unalias "$command" &>/dev/null
    ble/util/type type "$command"
  fi

  local q="'" Q="'\''"
  printf "type='%s'\n" "${type//$q/$Q}"
  printf "literal='%s'\n" "${literal//$q/$Q}"
  printf "command='%s'\n" "${command//$q/$Q}"
  return 0
} 2>/dev/null

## @fn ble/widget/command-help/.type
##   @var[out] type command
function ble/widget/command-help/.type {
  local literal=$1
  type= command=
  local ret; ble/syntax:bash/simple-word/safe-eval "$literal" nonull || return 1; command=$ret
  ble/util/type type "$command"

  # When using alias, resolve with subshell
  if [[ $type == alias ]]; then
    # Note: This has a side effect so is done in a subshell
    builtin eval -- "$(ble/widget/command-help/.type/.resolve-alias "$literal" "$command")" # subshell
  fi

  if [[ $type == keyword && $command != "$literal" ]]; then
    if [[ $command == %* ]] && jobs -- "$command" &>/dev/null; then
      type=jobs
    else
      # Use second option of type -a #D1406
      type=${type[1]}
      [[ $type ]] || return 1
    fi
  fi
}

function ble/widget/command-help.impl {
  local literal=$1
  if [[ ! $literal ]]; then
    ble/widget/.bell
    return 1
  fi

  local type command; ble/widget/command-help/.type "$literal"
  if [[ ! $type ]]; then
    ble/widget/.bell "command \`$command' not found"
    return 1
  fi

  ble/widget/external-command ble/widget/command-help.core
}

function ble/widget/command-help {
  # ToDo: syntax update?
  ble-edit/content/clear-arg
  local comp_cword comp_words comp_line comp_point
  if ble/syntax:bash/extract-command "$_ble_edit_ind"; then
    local cmd=${comp_words[0]}
  else
    local args; ble/string#split-words args "$_ble_edit_str"
    local cmd=${args[0]}
  fi

  ble/widget/command-help.impl "$cmd"
}

# 
#------------------------------------------------------------------------------
# **** ble-edit/bind ****                                                 @bind

function ble-edit/bind/stdout.on { return 0; }
function ble-edit/bind/stdout.off { ble/util/buffer.flush; }
function ble-edit/bind/stdout.finalize { return 0; }

if [[ $bleopt_internal_suppress_bash_output ]]; then
  _ble_edit_io_fname2=$_ble_base_run/$$.stderr

  function ble-edit/bind/stdout.on {
    exec 2>&"$_ble_util_fd_tui_stderr"
  }
  function ble-edit/bind/stdout.off {
    ble/util/buffer.flush
    ble-edit/io/check-stderr
    exec 2>>"$_ble_edit_io_fname2"
  }
  function ble-edit/bind/stdout.finalize {
    ble-edit/bind/stdout.on
    [[ -f $_ble_edit_io_fname2 ]] && >| "$_ble_edit_io_fname2"
  }

  ## @fn ble-edit/io/check-stderr
  ##   Check and display if bash outputs an error to stderr.
  function ble-edit/io/check-stderr {
    local file=${1:-$_ble_edit_io_fname2}

    # if the visible bell function is already defined.
    if ble/is-function ble/term/visible-bell; then
      # checks if "$file" is an ordinary non-empty file
      #   since the $file might be /dev/null depending on the configuration.
      #   If it's a file with content, not a device like /dev/null.
      if [[ -f $file && -s $file ]]; then
        local message= line
        while IFS= ble/bash/read line || [[ $line ]]; do
          # * The head of error messages seems to be ${BASH##*/}.
          #   For example, if you are running from ~/bin/bash-3.1 etc.
          #   An error message such as "bash-3.1: ~" will appear.
          if [[ $line == 'bash: '* || $line == "${BASH##*/}: "* || $line == "ble.sh ("*"): "* ]]; then
            message="$message${message:+; }$line"
          fi
        done < "$file"

        [[ $message ]] && ble/term/visible-bell "$message"
        >| "$file"
      fi
    fi
  }

  # * C-d cannot be detected directly in bash-3.1, bash-3.2, and bash-3.0.
  # If you set IGNOREEOF, when you press C-d,
  #   bash complains to stderr, so it catches it and assumes that C-d was pressed.
  if ((_ble_bash<40000)); then
    function ble-edit/io/TRAPUSR1 {
      [[ $_ble_term_state == internal ]] || return 1
      _ble_decode_bind__uvwflag=
      ble/decode/readline/adjust-uvw

      local FUNCNEST=
      local IFS=$_ble_term_IFS
      local file=$_ble_edit_io_fname2.proc
      if [[ -s $file ]]; then
        local content cmd processed_eof=1
        ble/util/readfile content "$file"
        >| "$file"
        ble/string#split-words content "$content"
        for cmd in "${content[@]}"; do
          case $cmd in
          (eof)
            # C-d
            _ble_decode_hook 4
            builtin eval -- "$_ble_decode_bind_hook"
            processed_eof=1 ;;
          esac
        done

        if [[ $processed_eof ]]; then
          # suppress processing of the subsequent USR1 trap by the user by
          # returning the exit status 126.  This is processed by
          # "ble/builtin/trap/.handler".
          return 126
        fi
      fi
    }
    blehook/declare internal_USR1
    blehook internal_USR1!=ble-edit/io/TRAPUSR1
    ble/builtin/trap/install-hook USR1

    function ble-edit/io/check-ignoreeof-message {
      local line=$1

      # Match messages used in different versions of Bash.
      [[ ( $bleopt_internal_ignoreeof_trap && $line == *$bleopt_internal_ignoreeof_trap* ) ||
           $line == *'Use "exit" to leave the shell.'* ||
           $line == *'Type exit to log out'* ||
           $line == *'Use "exit" to leave the shell.'* ||
           $line == *'Use "exit" to leave the shell.'* ||
           $line == *'Gebruik Kaart na Los Tronk'* ]] && return 0

      # Should I cache the contents of lib/core-edit.ignoreeof-messages.txt?
      [[ $line == *exit* ]] && ble/bin/grep -q -F "$line" "$_ble_base"/lib/core-edit.ignoreeof-messages.txt
    }

    function ble-edit/io/check-ignoreeof-loop {
      local line opts=:$1:
      while IFS= ble/bash/read line; do
        if [[ $line == *[^$_ble_term_IFS]* ]]; then
          ble/util/print "$line" >> "$_ble_edit_io_fname2"
        fi

        if ble-edit/io/check-ignoreeof-message "$line"; then
          ble/util/print eof >> "$_ble_edit_io_fname2.proc"
          kill -USR1 $$
          ble/util/msleep 100 # bash may crash if you send it continuously (it hasn't crashed, but just to be sure)
        fi
      done
    } &>/dev/null

    ble/bin/rm -f "$_ble_edit_io_fname2.pipe"
    if ble/bin/mkfifo "$_ble_edit_io_fname2.pipe" 2>/dev/null; then
      {
        ble-edit/io/check-ignoreeof-loop fifo < "$_ble_edit_io_fname2.pipe" & disown
      } &>/dev/null

      ble/fd#alloc _ble_edit_io_fd2 '> "$_ble_edit_io_fname2.pipe"'

      function ble-edit/bind/stdout.off {
        ble/util/buffer.flush
        ble-edit/io/check-stderr
        exec 2>&"$_ble_edit_io_fd2"
      }
    elif . "$_ble_base/lib/init-msys1.sh"; ble-edit/io:msys1/start-background; then
      function ble-edit/bind/stdout.off {
        ble/util/buffer.flush
        ble-edit/io/check-stderr

        # Note: If you enter all at once, you will get a permission denied error message.
        #   To suppress the message, first do >/dev/null and then connect with another exec.
        #   Must be. When I try to redirect with the same exec I get the following message:
        #   The body is not displayed, but only the newline in the error message is output.
        exec 2>/dev/null
        exec 2>>"$_ble_edit_io_fname2.buff"
      }
    fi
  fi
fi

[[ ${_ble_edit_detach_flag-} != reload ]] &&
  _ble_edit_detach_flag=
function ble-edit/bind/.exit-TRAPRTMAX {
  # Inside the signal handler, stty is set by bash.
  local FUNCNEST=
  ble/base/unload
  builtin exit 0
}

## @fn ble-edit/bind/.check-detach
##
##   @exit Returns 0 if detached. Returns 1 otherwise.
##
function ble-edit/bind/.check-detach {
  if [[ ! -o emacs && ! -o vi ]]; then
    # In fact, the evaluation of eval is interrupted when you do something like set +o emacs, so this cannot be detected.
    # Therefore, it does not seem to be coming here at present.
    local ret
    ble/edit/marker#instantiate 'unsupported' error:non-empty
    ble/util/print "$ret Sorry, ble.sh is supported only with some editing mode (set -o emacs/vi)." >&2
    ble-detach
  fi

  # Pass through when reload & prompt-attach (processing after detach is unnecessary)
  [[ $_ble_edit_detach_flag == prompt-attach ]] && return 1

  if [[ $_ble_edit_detach_flag || ! $_ble_attached ]]; then
    type=$_ble_edit_detach_flag
    _ble_edit_detach_flag=
    #ble/term/visible-bell ' Bye!! '

    local attached=$_ble_attached
    [[ $attached ]] && ble-detach/impl

    if [[ $type == exit ]]; then
      # *This part is currently not in use.
      #   I decided to use trap EXIT to process the exit.
      #   You can call it by directly inputting _ble_edit_detach_flag=exit.
      local ret
      ble/edit/marker#instantiate-config exec_exit_mark &&
        ble-detach/message "$ret"

      # When you exit from bind -x, bash seems to restore stty to its "previous state".
      # If you exit from within the signal handler, you can exit stty in its current state, so do that.
      builtin trap 'ble-edit/bind/.exit-TRAPRTMAX' RTMAX
      kill -RTMAX $$
    else
      local ret
      ble/edit/marker#instantiate 'detached' non-empty
      ble-detach/message \
        ${ret+"$ret"} \
        "Please run \`stty sane' to recover the correct TTY state."

      if ((_ble_bash>=40000)); then
        READLINE_LINE=' stty sane;' READLINE_POINT=11 READLINE_MARK=0
        printf %s "$READLINE_LINE"
      fi
    fi

    if [[ $attached ]]; then
      # When you do ble-detach/impl here, the adjustment is minimal.
      ble/base/restore-BASH_REMATCH
      ble/base/restore-bash-options
      ble/base/restore-builtin-wrappers
      ble/base/restore-POSIXLY_CORRECT
      builtin eval -- "$_ble_bash_FUNCNEST_restore" # The function cannot be called from now on.
    else
      # Note: When it has already been ble-detach/impled (at the time of reload),
      #   Since the state after detach is destroyed by epilogue,
      #   It is necessary to call prologue again.
      #   #D1130 #D1199 #D1223
      ble-edit/exec:"$bleopt_internal_exec_type"/.prologue
      _ble_edit_exec_inside_prologue=
    fi

    return 0
  else
    # Note: When entering here, either -o emacs or -o vi is true. Because,
    #   [[ ! -o emacs && ! -o vi ]] does not come here because ble-detach is called.
    local state=$_ble_decode_bind_state
    if [[ ( $state == emacs || $state == vi ) && ! -o $state ]]; then
      ble/decode/reset-default-keymap
      ble/decode/detach
      if ! ble/decode/attach; then
        ble-detach
        ble-edit/bind/.check-detach # Termination processing again
        return "$?"
      fi
    fi

    return 1
  fi
}

if ((_ble_bash>=40100)); then
  function ble-edit/bind/.head/adjust-bash-rendering {
    # In bash-4.1 and later, the prompt is removed just before the call.
    ble/textarea#redraw-cache
    ble/util/buffer.flush
  }
else
  function ble-edit/bind/.head/adjust-bash-rendering {
    # In bash-3.*, bash-4.0, move to the next line just before the call
    ((_ble_canvas_y++,_ble_canvas_x=0))
    local -a DRAW_BUFF=()
    ble/canvas/panel#goto.draw "$_ble_textarea_panel" "${_ble_textarea_cur[0]}" "${_ble_textarea_cur[1]}"
    ble/canvas/flush.draw
  }
fi

function ble-edit/bind/.head {
  ble-edit/bind/stdout.on
  ble/base/recover-bash-options
  [[ $bleopt_internal_suppress_bash_output ]] ||
    ble-edit/bind/.head/adjust-bash-rendering
}

function ble-edit/bind/.tail-without-draw {
  ble-edit/bind/stdout.off
}

if ((_ble_bash>=40000)); then
  function ble-edit/bind/.tail {
#%if leakvar
ble/debug/leakvar#check $"leakvar" tail.beg
#%end.i
    ble/application/render
    ble/util/idle.do
    ble/textarea#adjust-for-bash-bind # bash-4.0+
#%if leakvar
ble/debug/leakvar#check $"leakvar" tail.end
#%end.i
    ble-edit/bind/stdout.off
  }
else
  function ble-edit/bind/.tail {
    ble/application/render
    ble/util/idle.do
    # In bash-3 there is no way to set READLINE_LINE so it is always 0 width
    ble-edit/bind/stdout.off
  }
fi

## Settings for src/decode.sh
function ble-decode/PROLOGUE {
  ble-edit/exec:gexec/restore-state
  ble-edit/bind/.head
  ble/decode/readline/adjust-uvw
  ble/term/enter
}

## Settings for src/decode.sh
function ble-decode/EPILOGUE {
  if ((_ble_bash>=40000)); then
    # Pasting measures:
    #   If you redraw it every time a large number of characters are entered, it will be extremely slow.
    #   If the next character has already arrived, exit without drawing.
    #   (Redrawing should be done by calling bind on the next character.)
    #   Currently, continuous input is reduced at the _ble_decode_hook stage, so
    #   This function is not called very often.
    #   Note that user input cannot be detected unless you have bash 4.0 or later.
    if ble/decode/has-input && ! ble-edit/exec/has-pending-commands; then
      ble-edit/bind/.tail-without-draw
      return 0
    fi
  fi

  ble-edit/content/check-limit

  # bind/.tail at the end of _ble_decode_bind_hook when command execution is configured
  # is executed.
  ble-edit/exec:"$bleopt_internal_exec_type"/process && return 0

  ble-edit/bind/.tail
  return 0
}

function ble/widget/.internal-print-command {
  local _ble_local_command=$1 _ble_command_opts=$2
  _ble_edit_line_disabled=1 ble/edit/.relocate-textarea # #D1800 pair=leave-command-layout
  [[ :$_ble_command_opts: != *:pre-flush:* ]] || ble/util/buffer.flush
  BASH_COMMAND=$_ble_local_command builtin eval -- "$_ble_local_command"
  ble/edit/leave-command-layout # #D1800 pair=ble/edit/.relocate-textarea
  [[ :$_ble_command_opts: != *:post-flush:* ]] || ble/util/buffer.flush
}

function ble/widget/print {
  ble-edit/content/clear-arg
  local message="$*" lines
  [[ ${message//["$_ble_term_IFS"]} ]] || return 1
  lines=("$@")

  if [[ ! ${_ble_attached-} || ${_ble_edit_exec_inside_begin-} ]]; then
    ble/util/print-lines "${lines[@]}"
  else
    ble/widget/.internal-print-command '
      ble/util/buffer.print-lines "${lines[@]}"
      ble/util/buffer.flush' pre-flush
  fi
}
function ble/widget/internal-command {
  ble-edit/content/clear-arg
  local command=$1
  [[ ${command//[$_ble_term_IFS]} ]] || return 1
  ble/widget/.internal-print-command "$command"
}
function ble/widget/external-command {
  ble-edit/content/clear-arg
  local _ble_local_command=$1
  [[ ${_ble_local_command//[$_ble_term_IFS]} ]] || return 1

  ble/edit/enter-command-layout # #D1800 pair=leave-command-layout
  ble/textarea#invalidate
  local -a DRAW_BUFF=()
  ble/canvas/panel#set-height.draw "$_ble_textarea_panel" 0
  ble/canvas/panel#goto.draw "$_ble_textarea_panel" 0 0 sgr0
  ble/canvas/bflush.draw
  ble/term/leave
  ble/util/buffer.flush
  BASH_COMMAND=$_ble_local_command builtin eval -- "$_ble_local_command"; local ext=$?
  ble/term/enter
  ble/edit/leave-command-layout # #D1800 pair=enter-command-layout
  return "$ext"
}
function ble/widget/execute-command {
  ble-edit/content/clear-arg
  local command=$1
  if [[ $command != *[!"$_ble_term_IFS"]* ]]; then
    # Note: ble/edit/.relocate-textarea is executed even if it is an empty command.
    _ble_edit_line_disabled=1 ble/edit/.relocate-textarea keep-info
    return 1
  fi

  # After all, normal commands should be evaluated in a proper environment.
  _ble_edit_line_disabled=1 ble/edit/.relocate-textarea # #D1800 pair=exec/register
  ble-edit/exec/register "$command"
}

## @fn ble/widget/.SHELL_COMMAND command
##   Process commands registered with ble-bind -c.
function ble/widget/.SHELL_COMMAND { ble/widget/execute-command "$@"; }

## @fn ble/widget/.EDIT_COMMAND command
##   Process commands registered with ble-bind -x.
function ble/widget/.EDIT_COMMAND {
  local command=$1
  local -x READLINE_LINE=$_ble_edit_str
  local -x READLINE_POINT=$_ble_edit_ind
  local -x READLINE_MARK=$_ble_edit_mark
  [[ $_ble_edit_arg ]] &&
    local -x READLINE_ARGUMENT=$_ble_edit_arg
  ble/edit/enter-command-layout # #D1800 pair=leave-command-layout
  ble/widget/.hide-current-line keep-header
  ble-edit/restore-PS1
  ble/term/leave-for-widget
  builtin eval -- "$command"; local ext=$?
  ble/term/enter-for-widget
  ble-edit/adjust-PS1
  ble-edit/content/clear-arg
  ble/edit/leave-command-layout # #D1800 pair=enter-command-layout

  [[ $READLINE_LINE != "$_ble_edit_str" ]] &&
    ble-edit/content/reset-and-check-dirty "$READLINE_LINE"
  ((_ble_edit_ind=READLINE_POINT))
  ((_ble_edit_mark=READLINE_MARK))

  local N=${#_ble_edit_str}
  ((_ble_edit_ind<0?_ble_edit_ind=0:(_ble_edit_ind>N&&(_ble_edit_ind=N))))
  ((_ble_edit_mark<0?_ble_edit_mark=0:(_ble_edit_mark>N&&(_ble_edit_mark=N))))
  if [[ $_ble_decode_keymap == vi_nmap ]]; then
    if [[ $KEYMAP == vi_nmap ]]; then
      # Note: If the command did not change the current keymap, we perform the
      # adjustment for a normal command in vi_nmap.  For example, this exits
      # the single command mode by C-o.  We do not support the shell commands
      # that tries to adjust arguments and registers without exiting the single
      # command mode.  There are already limitations with such a command
      # because we clear the arguments after evaluating the shell command.
      ble/keymap:vi/adjust-command-mode
    else
      # If the current keymap became vi_nmap due to the command, we do not
      # perform extra adjustment for C-o, etc.  We just fix the current cursor
      # position.
      ble/keymap:vi/needs-eol-fix && ((_ble_edit_ind--))
    fi
  fi

  return "$ext"
}

## Settings for ble-decode.sh
function ble-decode/INITIALIZE_DEFMAP {
  local ret
  bleopt/get:default_keymap; local defmap=$ret
  if ble-edit/bind/load-editing-mode "$defmap"; then
    local base_keymap=$defmap
    [[ $defmap == vi ]] && base_keymap=vi_imap
    builtin eval -- "$2=\$base_keymap"
    ble/decode/is-keymap "$base_keymap" && return 0
  fi

  # error message
  ble/edit/marker#instantiate "The definition of the default keymap \"$defmap\" is not found. ble.sh uses \"safe\" keymap instead." error
  local msg=$ret

  ble/edit/enter-command-layout # #D1800 pair=leave-command-layout
  ble/widget/.hide-current-line

  local -a DRAW_BUFF=()
  ble/canvas/put.draw "$_ble_term_cr$_ble_term_el$msg$_ble_term_nl"
  ble/canvas/bflush.draw
  ble/util/buffer.flush
  ble/edit/leave-command-layout # #D1800 pair=enter-command-layout

  # Fallback keymap "safe"
  ble-edit/bind/load-editing-mode safe &&
    ble/decode/keymap#load safe &&
    builtin eval -- "$2=safe" &&
    bleopt_default_keymap=safe
}

function ble-edit/bind/load-editing-mode {
  local name=$1
  if ble/is-function ble-edit/bind/load-editing-mode:"$name"; then
    ble-edit/bind/load-editing-mode:"$name"
  else
    ble/util/import "$_ble_base/lib/keymap.$name.sh"
  fi
}
function ble-edit/bind/clear-keymap-definition-loader {
  builtin unset -f ble-edit/bind/load-editing-mode:safe
  builtin unset -f ble-edit/bind/load-editing-mode:emacs
  builtin unset -f ble-edit/bind/load-editing-mode:vi
}

#------------------------------------------------------------------------------
# **** entry points ****

function ble-edit/initialize {
  ble/prompt/initialize
}
function ble-edit/attach {
  # Attempt to get user DEBUG trap
  _ble_builtin_trap_DEBUG__initialize
  # If user DEBUG trap has been acquired, delete DEBUG trap
  [[ $_ble_builtin_trap_DEBUG_userTrapInitialized ]] &&
    _ble_edit_exec_gexec__TRAPDEBUG_adjust

  ble-edit/attach/.attach
  _ble_canvas_x=0 _ble_canvas_y=0
  ble/util/buffer "$_ble_term_cr"
}
function ble-edit/detach {
  ble-edit/bind/stdout.finalize
  ble-edit/attach/.detach
  ble-edit/exec:gexec/.TRAPDEBUG/restore
}

ble/function#trace ble-edit/attach

#------------------------------------------------------------------------------
# messages

function ble/util/message/handler:edit/append-line {
  local data=${1%$'\n'}; data=${data#$'\n'}
  [[ ${_ble_edit_str##*$'\n'} ]] && data=$'\n'$data
  local len=${#_ble_edit_str}
  ble-edit/content/replace-limited "$len" "$len" "$data" nobell
  _ble_edit_ind=${#_ble_edit_str}
  return 0
}

function ble-append-line {
  local data="${*-}"
  [[ $data ]] || return 0
  builtin eval -- "$_ble_bash_POSIXLY_CORRECT_local_adjust"
  ble/util/message.post "$$" precmd edit/append-line "$data"
  builtin eval -- "$_ble_bash_POSIXLY_CORRECT_local_return"
}
