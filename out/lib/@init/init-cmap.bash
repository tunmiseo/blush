#!/bin/bash

#
# The following are special keys defined by default in ble-decode.sh
#
# control characters
#
#   TAB  RET
#
#   NUL  SOH  STX  ETX  EOT  ENQ  ACK  BEL
#   BS   HT   LF   VT   FF   CR   SO   SI
#   DLE  DC1  DC2  DC3  DC4  NAK  SYN  ETB
#   CAN  EM   SUB  ESC  FS   GS   RS   US
#
#   SP   DEL
#
#   PAD  HOP  BPH  NBH  IND  NEL  SSA  ESA
#   HTS  HTJ  VTS  PLD  PLU  RI   SS2  SS3
#   DCS  PU1  PU2  STS  CCH  MW   SPA  EPA
#   SOS  SGCI SCI  CSI  ST   OSC  PM   APC
#
# Special characters (internal use)
#
#   @ESC @NUL
#
# special key bindings
#
#   __batch_char__
#   __defchar__
#   __default__
#   __before_widget__
#   __after_widget__
#   __attach__
#   __detach__
#
# modifier key
#
#   shift alter control meta super hyper
#
# When processing a terminal response
#
#   __ignore__
#
# Note: When changing special keys in ble-decode.sh,
# By updating this list, the cache is updated.
#
# 2019-04-15 Added __error__, so keycode needs to be regenerated.
# 2019-05-04 Added mouse and mouse_move experimentally.
# 2019-05-06 Updated because there was a bug related to ble-update.
# 2020-01-31 Added @ESC, @NUL.
# 2020-03-12 Added __line_limit__
# 2020-04-13 Updated due to cmap cache generation bug fix.
# 2020-04-29 Update due to cmap cache generation bug fix (2)
# 2021-07-12 __detach__ added
# 2024-01-21 Update due to addition of _ble_decode_csimap_dict
# 2024-02-07 @ESC, @NUL Update due to code change
# 2024-06-05 Updated with "ble-decode/.hook => _ble_decode_hook"
# 2025-05-03 Add @prefixO for "up" (ESC O A) vs "M-O" (ESC O) in Bash <= 4.4
# 2025-05-04 Add a new key "dsr0" for "ESC [ 0 n"

function ble/init:cmap/initialize-kbd {
  ble/decode/kbd/.set-keycode TAB  9
  ble/decode/kbd/.set-keycode RET  13

  ble/decode/kbd/.set-keycode NUL  0
  ble/decode/kbd/.set-keycode SOH  1
  ble/decode/kbd/.set-keycode STX  2
  ble/decode/kbd/.set-keycode ETX  3
  ble/decode/kbd/.set-keycode EOT  4
  ble/decode/kbd/.set-keycode ENQ  5
  ble/decode/kbd/.set-keycode ACK  6
  ble/decode/kbd/.set-keycode BEL  7
  ble/decode/kbd/.set-keycode BS   8
  ble/decode/kbd/.set-keycode HT   9  # aka TAB
  ble/decode/kbd/.set-keycode LF   10
  ble/decode/kbd/.set-keycode VT   11
  ble/decode/kbd/.set-keycode FF   12
  ble/decode/kbd/.set-keycode CR   13 # aka RET
  ble/decode/kbd/.set-keycode SO   14
  ble/decode/kbd/.set-keycode SI   15

  ble/decode/kbd/.set-keycode DLE  16
  ble/decode/kbd/.set-keycode DC1  17
  ble/decode/kbd/.set-keycode DC2  18
  ble/decode/kbd/.set-keycode DC3  19
  ble/decode/kbd/.set-keycode DC4  20
  ble/decode/kbd/.set-keycode NAK  21
  ble/decode/kbd/.set-keycode SYN  22
  ble/decode/kbd/.set-keycode ETB  23
  ble/decode/kbd/.set-keycode CAN  24
  ble/decode/kbd/.set-keycode EM   25
  ble/decode/kbd/.set-keycode SUB  26
  ble/decode/kbd/.set-keycode ESC  27
  ble/decode/kbd/.set-keycode FS   28
  ble/decode/kbd/.set-keycode GS   29
  ble/decode/kbd/.set-keycode RS   30
  ble/decode/kbd/.set-keycode US   31

  ble/decode/kbd/.set-keycode SP   32
  ble/decode/kbd/.set-keycode DEL  127

  ble/decode/kbd/.set-keycode PAD  128
  ble/decode/kbd/.set-keycode HOP  129
  ble/decode/kbd/.set-keycode BPH  130
  ble/decode/kbd/.set-keycode NBH  131
  ble/decode/kbd/.set-keycode IND  132
  ble/decode/kbd/.set-keycode NEL  133
  ble/decode/kbd/.set-keycode SSA  134
  ble/decode/kbd/.set-keycode ESA  135
  ble/decode/kbd/.set-keycode HTS  136
  ble/decode/kbd/.set-keycode HTJ  137
  ble/decode/kbd/.set-keycode VTS  138
  ble/decode/kbd/.set-keycode PLD  139
  ble/decode/kbd/.set-keycode PLU  140
  ble/decode/kbd/.set-keycode RI   141
  ble/decode/kbd/.set-keycode SS2  142
  ble/decode/kbd/.set-keycode SS3  143

  ble/decode/kbd/.set-keycode DCS  144
  ble/decode/kbd/.set-keycode PU1  145
  ble/decode/kbd/.set-keycode PU2  146
  ble/decode/kbd/.set-keycode STS  147
  ble/decode/kbd/.set-keycode CCH  148
  ble/decode/kbd/.set-keycode MW   149
  ble/decode/kbd/.set-keycode SPA  150
  ble/decode/kbd/.set-keycode EPA  151
  ble/decode/kbd/.set-keycode SOS  152
  ble/decode/kbd/.set-keycode SGCI 153
  ble/decode/kbd/.set-keycode SCI  154
  ble/decode/kbd/.set-keycode CSI  155
  ble/decode/kbd/.set-keycode ST   156
  ble/decode/kbd/.set-keycode OSC  157
  ble/decode/kbd/.set-keycode PM   158
  ble/decode/kbd/.set-keycode APC  159

  ble/decode/kbd/.set-keycode @ESC     "$_ble_decode_IsolatedESC"
  ble/decode/kbd/.set-keycode @NUL     "$_ble_decode_EscapedNUL"
  ble/decode/kbd/.set-keycode @prefixO "$_ble_decode_PrefixO"
  ble/decode/kbd/.set-keycode @timeout "$_ble_decode_Timeout"

  local ret
  ble/decode/kbd/.generate-keycode __batch_char__
  _ble_decode_KCODE_BATCH_CHAR=$ret
  ble/decode/kbd/.generate-keycode __defchar__
  _ble_decode_KCODE_DEFCHAR=$ret
  ble/decode/kbd/.generate-keycode __default__
  _ble_decode_KCODE_DEFAULT=$ret
  ble/decode/kbd/.generate-keycode __before_widget__
  _ble_decode_KCODE_BEFORE_WIDGET=$ret
  ble/decode/kbd/.generate-keycode __after_widget__
  _ble_decode_KCODE_AFTER_WIDGET=$ret
  ble/decode/kbd/.generate-keycode __attach__
  _ble_decode_KCODE_ATTACH=$ret
  ble/decode/kbd/.generate-keycode __detach__
  _ble_decode_KCODE_DETACH=$ret

  ble/decode/kbd/.generate-keycode shift
  _ble_decode_KCODE_SHIFT=$ret
  ble/decode/kbd/.generate-keycode alter
  _ble_decode_KCODE_ALTER=$ret
  ble/decode/kbd/.generate-keycode control
  _ble_decode_KCODE_CONTROL=$ret
  ble/decode/kbd/.generate-keycode meta
  _ble_decode_KCODE_META=$ret
  ble/decode/kbd/.generate-keycode super
  _ble_decode_KCODE_SUPER=$ret
  ble/decode/kbd/.generate-keycode hyper
  _ble_decode_KCODE_HYPER=$ret

  # Note: Keys to ignore. In ble-decode-char
  #   Used when processing notifications etc. from the terminal.
  ble/decode/kbd/.generate-keycode __ignore__
  _ble_decode_KCODE_IGNORE=$ret

  # Note: bleopt decode_error_cseq_discard
  ble/decode/kbd/.generate-keycode __error__
  _ble_decode_KCODE_ERROR=$ret

  # Note: Event when line_limit exceeds the limit
  ble/decode/kbd/.generate-keycode __line_limit__
  _ble_decode_KCODE_LINE_LIMIT=$ret

  # Note: This is a temporary solution and may be changed later.
  ble/decode/kbd/.generate-keycode mouse
  _ble_decode_KCODE_MOUSE=$ret
  ble/decode/kbd/.generate-keycode mouse_move
  _ble_decode_KCODE_MOUSE_MOVE=$ret

  # Note: The following will be referenced in each file again.
  #   Define it here to fix the code.
  ble/decode/kbd/.generate-keycode ac_enter

  # Note: To prevent future inconsistencies, always add new keys at the bottom.
  # You should add it. Otherwise, the code that is already in use will be shifted.
  # It will be. Organizing the order should be done at each major milestone.

  builtin unset -f "$FUNCNAME"
}

function ble/init:cmap/bind-single-csi {
  ble-bind -k "ESC [ $1" "$2"
  ble-bind -k "CSI $1" "$2"
}
function ble/init:cmap/bind-single-ss3 {
  ble-bind -k "ESC O $1" "$2"
  ble-bind -k "SS3 $1" "$2"
}
function ble/init:cmap/bind-keypad-key {
  local Ft=$1 name=$2
  (($3&4)) && ble-bind --csi "$Ft" "$name"
  (($3&1)) && ble/init:cmap/bind-single-ss3 "$Ft" "$name"
  (($3&2)) && ble-bind -k "ESC ? $Ft" "$name"
}

function ble/init:cmap/initialize-keys {
  # Synonyms
  #   paste = S-insert [rxvt]
  #   scroll_up = S-prior [rxvt]
  #   scroll_down = S-next [rxvt]
  #   help = f15 [rxvt]
  #   menu = f16 [rxvt]
  #   print = f16 [xterm]
  #   deleteline = A-delete

  ble/edit/info/immediate-show text "ble/lib/init-cmap.sh: updating key sequences..."

  # pc-style keys
  # # vt52, xterm, rxvt
  # ble-bind --csi '1~' find
  # ble-bind --csi '2~' insert
  # ble-bind --csi '3~' delete # execute
  # ble-bind --csi '4~' select
  # ble-bind --csi '5~' prior
  # ble-bind --csi '6~' next
  # ble-bind --csi '7~' home
  # ble-bind --csi '8~' end

  # # cygwin, screen, rosaterm
  # ble-bind --csi '1~' home
  # ble-bind --csi '2~' insert
  # ble-bind --csi '3~' delete
  # ble-bind --csi '4~' end
  # ble-bind --csi '5~' prior
  # ble-bind --csi '6~' next

  # # vt100 (seems minority)
  # ble-bind --csi '1~' insert
  # ble-bind --csi '2~' home
  # ble-bind --csi '3~' prior
  # ble-bind --csi '4~' delete
  # ble-bind --csi '5~' end
  # ble-bind --csi '6~' next

  # Fixed order
  local ret
  ble/decode/kbd/.generate-keycode insert
  ble/decode/kbd/.generate-keycode home
  ble/decode/kbd/.generate-keycode prior
  ble/decode/kbd/.generate-keycode delete
  ble/decode/kbd/.generate-keycode end
  ble/decode/kbd/.generate-keycode next
  ble/decode/kbd/.generate-keycode find
  ble/decode/kbd/.generate-keycode select

  local kend; ble/util/assign kend 'tput @7 2>/dev/null || tput kend 2>/dev/null'
  if [[ $kend == $'\e[5~' ]]; then
    # vt100
    ble-bind --csi '1~' insert
    ble-bind --csi '2~' home
    ble-bind --csi '3~' prior
    ble-bind --csi '4~' delete
    ble-bind --csi '5~' end
    ble-bind --csi '6~' next
  else
    # Note: openSUSE /etc/inputrc.keys is home/end and find/select
    #   Since we set a keybinding that no one uses because it considers it to be another key,
    #   home/end will be overwritten. There is no other choice, so when TERM=xterm
    #   Only find/select will be treated as an independent key. Now
    #   There may be settings that don't work, but for now openSUSE
    #   I will try giving priority to inputrc.
    #

    # When I look it up, the DEC keyboard prints find/select at the home/end position.
    # has been done. This is why 1~/4~ is home/end on some terminals.
    # This is probably the origin.
    if [[ $kend == $'\e[F' && ( $TERM == xterm || $TERM == xterm-* || $TERM == kvt ) ]]; then
      ble-bind --csi '1~' find
      ble-bind --csi '4~' select
    else
      ble-bind --csi '1~' home
      ble-bind --csi '4~' end
    fi
    ble-bind --csi '2~' insert
    ble-bind --csi '3~' delete
    ble-bind --csi '5~' prior
    ble-bind --csi '6~' next
  fi
  ble-bind --csi '7~' home
  ble-bind --csi '8~' end
  local kdch1; ble/util/assign kdch1 'tput kD 2>/dev/null || tput kdch1 2>/dev/null'
  [[ $kdch1 == $'\x7F' || $TERM == sun* ]] && ble-bind -k 'DEL' delete

  # vt220, xterm, rxvt
  ble-bind --csi '11~' f1
  ble-bind --csi '12~' f2
  ble-bind --csi '13~' f3
  ble-bind --csi '14~' f4
  ble-bind --csi '15~' f5
  ble-bind --csi '17~' f6
  ble-bind --csi '18~' f7
  ble-bind --csi '19~' f8
  ble-bind --csi '20~' f9
  ble-bind --csi '21~' f10
  ble-bind --csi '23~' f11
  ble-bind --csi '24~' f12
  ble-bind --csi '25~' f13
  ble-bind --csi '26~' f14
  ble-bind --csi '28~' f15
  ble-bind --csi '29~' f16
  ble-bind --csi '31~' f17
  ble-bind --csi '32~' f18
  ble-bind --csi '33~' f19
  ble-bind --csi '34~' f20

  ble-bind --csi '200~' paste_begin
  ble-bind --csi '201~' paste_end

  # keypad
  #   vt100, xterm, application mode
  #   ESC ? comes from vt52
  #
  #   Note: Even if you distinguish between kp~ and normal keys, binding will be difficult.
  #   Since there is not much advantage, I will not make a distinction in this setting for the time being.
  #
  # Note: ble/init:cmap/bind-keypad-key third argument is
  #   1: SS3 X, 2: ESC ? X, 4: Sum of CSI X.
  ble/init:cmap/bind-keypad-key 'SP' SP   3 # kpspace
  ble/init:cmap/bind-keypad-key 'A' up    5
  ble/init:cmap/bind-keypad-key 'B' down  5
  ble/init:cmap/bind-keypad-key 'C' right 5
  ble/init:cmap/bind-keypad-key 'D' left  5
  ble/init:cmap/bind-keypad-key 'E' begin 5
  ble/init:cmap/bind-keypad-key 'F' end   5
  ble/init:cmap/bind-keypad-key 'H' home  5
  ble/init:cmap/bind-keypad-key 'I' TAB   3 # kptab (Note: CSI I overlaps with xterm SM(?1004) focus)
  ble/init:cmap/bind-keypad-key 'M' RET   7 # kpent
  ble/init:cmap/bind-keypad-key 'P' f1    5 # kpf1 # Note: Ordinary f1-f4
  ble/init:cmap/bind-keypad-key 'Q' f2    5 # These for kpf2 #
  ble/init:cmap/bind-keypad-key 'R' f3    5 # kpf3 # send sequence
  ble/init:cmap/bind-keypad-key 'S' f4    5 # There is also a kpf4 # terminal.
  ble/init:cmap/bind-keypad-key 'j' '*'   7 # kpmul
  ble/init:cmap/bind-keypad-key 'k' '+'   7 # kpadd
  ble/init:cmap/bind-keypad-key 'l' ','   7 # kpsep
  ble/init:cmap/bind-keypad-key 'm' '-'   7 # kpsub
  ble/init:cmap/bind-keypad-key 'n' '.'   7 # kpdec
  ble/init:cmap/bind-keypad-key 'o' '/'   7 # kpdiv
  ble/init:cmap/bind-keypad-key 'p' '0'   7 # kp0
  ble/init:cmap/bind-keypad-key 'q' '1'   7 # kp1
  ble/init:cmap/bind-keypad-key 'r' '2'   7 # kp2
  ble/init:cmap/bind-keypad-key 's' '3'   7 # kp3
  ble/init:cmap/bind-keypad-key 't' '4'   7 # kp4
  ble/init:cmap/bind-keypad-key 'u' '5'   7 # kp5
  ble/init:cmap/bind-keypad-key 'v' '6'   7 # kp6
  ble/init:cmap/bind-keypad-key 'w' '7'   7 # kp7
  ble/init:cmap/bind-keypad-key 'x' '8'   7 # kp8
  ble/init:cmap/bind-keypad-key 'y' '9'   7 # kp9
  ble/init:cmap/bind-keypad-key 'X' '='   7 # kpeq

  # xterm SM(?1004) Focus In/Out notification
  ble/init:cmap/bind-keypad-key 'I' focus 4 # Note: Do not set 1 (= SS3) as it overlaps with TAB.
  ble/init:cmap/bind-keypad-key 'O' blur  5

  # rxvt
  #   Note: "CSI code @" and "CSI code ^" are specially processed on the main unit side.
  ble/init:cmap/bind-single-csi 'Z'     S-TAB
  ble/init:cmap/bind-single-ss3 'a'     C-up
  ble/init:cmap/bind-single-csi 'a'     S-up
  ble/init:cmap/bind-single-ss3 'b'     C-down
  ble/init:cmap/bind-single-csi 'b'     S-down
  ble/init:cmap/bind-single-ss3 'c'     C-right
  ble/init:cmap/bind-single-csi 'c'     S-right
  ble/init:cmap/bind-single-ss3 'd'     C-left
  ble/init:cmap/bind-single-csi 'd'     S-left
  ble/init:cmap/bind-single-csi '2 $'   S-insert # ECMA-48 violation
  ble/init:cmap/bind-single-csi '3 $'   S-delete # ECMA-48 violation
  ble/init:cmap/bind-single-csi '5 $'   S-prior  # ECMA-48 violation
  ble/init:cmap/bind-single-csi '6 $'   S-next   # ECMA-48 violation
  ble/init:cmap/bind-single-csi '7 $'   S-home   # ECMA-48 violation
  ble/init:cmap/bind-single-csi '8 $'   S-end    # ECMA-48 violation
  ble/init:cmap/bind-single-csi '2 3 $' S-f11    # ECMA-48 violation
  ble/init:cmap/bind-single-csi '2 4 $' S-f12    # ECMA-48 violation
  ble/init:cmap/bind-single-csi '2 5 $' S-f13    # ECMA-48 violation
  ble/init:cmap/bind-single-csi '2 6 $' S-f14    # ECMA-48 violation
  ble/init:cmap/bind-single-csi '2 8 $' S-f15    # ECMA-48 violation
  ble/init:cmap/bind-single-csi '2 9 $' S-f16    # ECMA-48 violation
  ble/init:cmap/bind-single-csi '3 1 $' S-f17    # ECMA-48 violation
  ble/init:cmap/bind-single-csi '3 2 $' S-f18    # ECMA-48 violation
  ble/init:cmap/bind-single-csi '3 3 $' S-f19    # ECMA-48 violation
  ble/init:cmap/bind-single-csi '3 4 $' S-f20    # ECMA-48 violation

  # cygwin specific
  ble/init:cmap/bind-single-csi '[ A' f1
  ble/init:cmap/bind-single-csi '[ B' f2
  ble/init:cmap/bind-single-csi '[ C' f3
  ble/init:cmap/bind-single-csi '[ D' f4
  ble/init:cmap/bind-single-csi '[ E' f5

  # sun specific (Solaris)
  ble/init:cmap/bind-single-csi '2 4 7 z' insert
  ble/init:cmap/bind-single-csi '2 1 4 z' home
  ble/init:cmap/bind-single-csi '2 2 0 z' end
  ble/init:cmap/bind-single-csi '2 2 2 z' prior
  ble/init:cmap/bind-single-csi '2 1 6 z' next
  ble/init:cmap/bind-single-csi '2 2 4 z' f1
  ble/init:cmap/bind-single-csi '2 2 5 z' f2
  ble/init:cmap/bind-single-csi '2 2 6 z' f3
  ble/init:cmap/bind-single-csi '2 2 7 z' f4
  ble/init:cmap/bind-single-csi '2 2 8 z' f5
  ble/init:cmap/bind-single-csi '2 2 9 z' f6
  ble/init:cmap/bind-single-csi '2 3 0 z' f7
  ble/init:cmap/bind-single-csi '2 3 1 z' f8
  ble/init:cmap/bind-single-csi '2 3 2 z' f9
  ble/init:cmap/bind-single-csi '2 3 3 z' f10
  ble/init:cmap/bind-single-csi '2 3 4 z' f11
  ble/init:cmap/bind-single-csi '2 3 5 z' f12
  # ble/init:cmap/bind-single-csi '2 z'     insert # terminfo
  # ble/init:cmap/bind-single-csi '3 z'     delete # terminfo
  # ble/init:cmap/bind-single-csi '1 9 2 z' f11
  # ble/init:cmap/bind-single-csi '1 9 3 z' f12
  ble/init:cmap/bind-single-csi '1 z' find   # from xterm ctlseqs
  ble/init:cmap/bind-single-csi '4 z' select # from xterm ctlseqs

  # Modifier key 'CAN @ ?'
  #
  #   For now, disable modifier keys that start with CAN. Because,
  #   If you apply a sequence starting with CAN (C-x) to a key,
  #   Commands ending in C-x (exchange-point-and-mark) are ambiguous.
  #   As a result, execution is delayed because it is not determined until the next non-@ character.
  #   Also, if you want to input something like @h after C-x C-x, it will be interpreted differently.
  #
  # ble-bind -k "CAN @ S" shift
  # ble-bind -k "CAN @ a" alter
  # ble-bind -k "CAN @ c" control
  # ble-bind -k "CAN @ h" hyper
  # ble-bind -k "CAN @ m" meta
  # ble-bind -k "CAN @ s" super

  # st specific
  ble/init:cmap/bind-single-csi '2 J' S-home
  ble/init:cmap/bind-single-csi 'J' C-end
  ble/init:cmap/bind-single-csi 'K' S-end
  ble/init:cmap/bind-single-csi '4 l' S-insert
  ble/init:cmap/bind-single-csi 'L'   C-insert
  ble/init:cmap/bind-single-csi '4 h' insert
  # ble/init:cmap/bind-single-csi 'M'   C-delete # conflicts with kpent
  ble/init:cmap/bind-single-csi '2 K' S-delete
  ble/init:cmap/bind-single-csi 'P'   delete

  # kitty specific "CSI ... u" sequences
  _ble_decode_csimap_kitty_u=(
    [57358]=capslock [57359]=scrolllock [57360]=numlock [57361]=print [57362]=pause [57363]=menu

    [57376]=f13 [57377]=f14 [57378]=f15 [57379]=f16 [57380]=f17 [57381]=f18 [57382]=f19 [57383]=f20
    [57384]=f21 [57385]=f22 [57386]=f23 [57387]=f24 [57388]=f25 [57389]=f26 [57390]=f27 [57391]=f28
    [57392]=f29 [57393]=f30 [57394]=f31 [57395]=f32 [57396]=f33 [57397]=f34 [57398]=f35

    [57399]=0 [57400]=1 [57401]=2 [57402]=3 [57403]=4 [57404]=5 [57405]=6 [57406]=7 [57407]=8 [57408]=9
    [57409]='.' [57410]='/' [57411]='*' [57412]='-' [57413]='+' [57414]=RET [57415]='=' [57416]=','
    [57417]=left [57418]=right [57419]=up [57420]=down
    [57421]=prior [57422]=next [57423]=home [57424]=end [57425]=insert [57426]=delete [57427]=begin

    [57428]=media_play [57429]=media_pause [57430]=media_play_pause [57431]=media_reverse
    [57432]=media_stop [57433]=media_fast_forward [57434]=media_rewind [57435]=media_track_next
    [57436]=media_track_prev [57437]=media_record [57438]=lower_volume [57439]=raise_volume
    [57440]=mute_volume

    [57441]=lshift [57442]=lcontrol [57443]=lalter [57444]=lsuper [57445]=lhyper [57446]=lmeta
    [57447]=rshift [57448]=rcontrol [57449]=ralter [57450]=rsuper [57451]=rhyper [57452]=rmeta
    [57453]=iso_shift3 [57454]=iso_shift5
  )
  local keyname
  for keyname in "${_ble_decode_csimap_kitty_u[@]}"; do
    ble/decode/kbd/.generate-keycode "$keyname"
  done

  # DSR(0): DSR response for DSR(5) (operating status).
  # Note: This is similar to kpdec described above, but the format of the
  # payload is different from the function-key sequences.
  ble/init:cmap/bind-single-csi '0 n' dsr0

  ble/edit/info/immediate-show text "ble/lib/init-cmap.sh: updating key sequences... done"

  builtin unset -f "$FUNCNAME"
}

## @fn ble/init:cmap/initialize-keys
##   @var[in] dump
##     The filename to write the cache
function ble/init:cmap/initialize {
  ble/edit/info/immediate-show text 'ble.sh: generating "'"$dump"'"...'
  ble/init:cmap/initialize-kbd
  ble/init:cmap/initialize-keys
  local hash='8c5b1b24da756fa6e2fc8e240eece33abfb0290c'
  ble-bind -D | ble/bin/awk -v hash="$hash" '
    {
      sub(/^declare +(-[aAilucnrtxfFgGI]+ +)?/, "");
      sub(/^-- +/, "");
    }
    /^_ble_decode_(cmap|KCODE|csimap|kbd)/ {
      if (!($0 ~ /^_ble_decode_csimap_kitty_u/))
        gsub(/["'\'']/, "");
      print
    }
    END {
      print "_ble_decode_cmap_cache_hash='\''" hash "'\''";
    }
  ' >| "$dump"

  # If ble.sh has not yet attached, we want to clear the processing message.
  [[ $_ble_attached ]] || ble/edit/info/immediate-clear

  builtin unset -f "$FUNCNAME"
}
ble/init:cmap/initialize
