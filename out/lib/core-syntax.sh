#!/bin/bash

function ble/syntax/util/is-directory {
  local path=$1
  # Note: #D1168 Cygwin is slow in determining paths starting with //
  if [[ ( $OSTYPE == cygwin || $OSTYPE == msys ) && $path == //* ]]; then
    [[ $path == // ]]
  else
    [[ -d $path ]]
  fi
}

## @fn ble/syntax/urange#update prefix p1 p2
## @fn ble/syntax/wrange#update prefix p1 [p2]
##   @param[in]   prefix
##   @param[in]   p1 p2
##   @var[in,out] {prefix}umin {prefix}umax
##
##   Regarding ble/syntax/urange#update,
##   Equivalent to ble/urange#update --prefix=prefix p1 p2.
##   There is no equivalent to ble/syntax/wrange#update.
##
function ble/syntax/urange#update {
  local prefix=$1
  local p1=$2 p2=${3:-$2}
  ((0<=p1&&p1<p2)) || return 1
  (((${prefix}umin<0||${prefix}umin>p1)&&(${prefix}umin=p1),
    (${prefix}umax<0||${prefix}umax<p2)&&(${prefix}umax=p2)))
}
function ble/syntax/wrange#update {
  local prefix=$1
  local p1=$2 p2=${3:-$2}
  ((0<=p1&&p1<=p2)) || return 1
  (((${prefix}umin<0||${prefix}umin>p1)&&(${prefix}umin=p1),
    (${prefix}umax<0||${prefix}umax<p2)&&(${prefix}umax=p2)))
}

## @fn ble/syntax/urange#shift prefix
## @fn ble/syntax/wrange#shift prefix
##   @param[in]   prefix
##   @var[in]     beg end end0 shift
##   @var[in,out] {prefix}umin {prefix}umax
##
##   Regarding ble/syntax/urange#shift,
##   Equivalent to ble/urange#shift --prefix=prefix "$beg" "$end" "$end0" "$shift".
##   There is no equivalent for ble/syntax/wrange#shift.
##
function ble/syntax/urange#shift {
  local prefix=$1
  ((${prefix}umin>=end0?(${prefix}umin+=shift):(
      ${prefix}umin>=beg&&(${prefix}umin=end)),
    ${prefix}umax>end0?(${prefix}umax+=shift):(
      ${prefix}umax>beg&&(${prefix}umax=beg)),
    ${prefix}umin>=${prefix}umax&&
      (${prefix}umin=${prefix}umax=-1)))
}
function ble/syntax/wrange#shift {
  local prefix=$1

  # *About the following inequality signs (while watching the operation)
  # Maybe you should think again.
  ((${prefix}umin>=end0?(${prefix}umin+=shift):(
       ${prefix}umin>beg&&(${prefix}umin=end)),
    ${prefix}umax>=end0?(${prefix}umax+=shift):(
      ${prefix}umax>=beg&&(${prefix}umax=beg)),
    ${prefix}umin==0&&++${prefix}umin,
    ${prefix}umin>${prefix}umax&&
      (${prefix}umin=${prefix}umax=-1)))
}

## @var _ble_syntax_text
##   Holds the string to be parsed.
## @var _ble_syntax_lang
##   Preserves the language to be parsed.
##
## @var _ble_syntax_stat[i]
##   Records the state immediately before attempting to interpret the character #i.
##   Each element has the form "ctx wlen wtype nlen tclen tplen nparam lookahead".
##
##   @var ctx         = int (stat[0])
##     current context.
##   @var wlen        = int (stat[1])
##     The running length of the current shell word.
##   @var wtype       = string (stat[2])
##     Current shell word type.
##   @var nlen        = int (stat[3])
##     The length of time the current nesting continues.
##   @var tclen,tplen = int (stat[4], stat[5])
##     Negative offset of tchild, tprev.
##   @var nparam      = string (stat[6])
##     A string that records general data specific to that nesting level.
##     Used to record heredocument start information.
##     In the future, it may also be used to support `{ .. }` and `do .. done`.
##     If the analysis variable nparam is an empty string, the value "none" is stored.
##   @var lookahead   = int (stat[7])
##     Specify the number of characters to read ahead. Usually 1.
##     The information that affected this _ble_syntax_stat element,
##     Stores the number of characters after the corresponding point. The end of the string also counts as one character.
##
## @var _ble_syntax_nest[inest]
##   Nested information
##   Each element has the form "ctx wlen wtype inest tclen tplen nparam ntype".
##   ctx wbegin inest wtype nparam represents the state when exiting nesting.
##   ntype is a string representing the nesting type.
## nparam retains the nparam value at the nesting level upon return.
##   If the nparam value is an empty string, the string none is stored instead.
##
## @var _ble_syntax_tree[i-1]
##   Holds information about the range (word/nested) that terminates at boundary #i.
##   If multiple hierarchical ranges end at the same location, the information is concatenated and stored.
##   Each element has the form "( wtype wlen tclen tplen wattr )*".
##   Information in the outer range is stored further to the left.
##
##   Reference other _ble_syntax_tree elements using tclen tplen.
##   When referring to a certain position from another position, the leftmost range information is referred to.
##   When referring to itself from a certain position, refer to the range information to the right of the same element.
##
##   wtype (ntype)
##     Preserve range type. When the range is a word, keep the context value as an integer.
##     When the range is a nested range, it becomes a string other than an integer.
##
##   wlen (nlen)
##     Preserve range length. The starting point of the range is i-wlen.
##
##   tclen
##     When greater than or equal to 0, maintains the offset to the end position of the next inner element.
##     Child element information is stored in _ble_syntax_tree[i-1-tclen].
##     Negative value when there are no child elements.
##
##   tplen
##     When greater than or equal to 0, maintains the offset to the previous sibling element.
##     Information about the older brother element is stored in _ble_syntax_tree[i-1-tplen].
##     Since older brother elements never end at the same position, it should always be a positive value.
##     Negative value when there is no older brother element (when you are the eldest son element).
##
##   attr (wattr) or - or --
##     Holds information about word coloring.
##     It has one of the following formats.
##
##     "-"
##       Indicates that the word coloring has not been calculated yet.
##     g
##       Holds drawing attribute values.
##     'm' len ':' attr (',' len ':' attr)*
##       A substring and attribute pair of length len.
##       If '$' is specified as the length len, it means up to the end of the word.
##     'd'
##       It means to delete the drawing attribute.
##
## @var _ble_syntax_TREE_WIDTH
##   Number of fields of one range information stored in _ble_syntax_tree.
##
## @var _ble_syntax_attr[i]
##   Context/attribute information
_ble_syntax_text=
_ble_syntax_stat=()
_ble_syntax_nest=()
_ble_syntax_tree=()
_ble_syntax_attr=()

# Note: "_ble_syntax_lang=bash" is set in core-syntax-def.sh since other
# modules want to overwrite the variable even before module core-syntax is
# loaded.

_ble_syntax_TREE_WIDTH=5

#--------------------------------------
# ble/syntax/tree-enumerate proc
# ble/syntax/tree-enumerate-children proc
# ble/syntax/tree-enumerate-in-range beg end proc

function ble/syntax/tree-enumerate/.add-root-element {
  local wtype=$1 wlen=$2 tclen=$3 tplen=$4

  # Note: wtype is converted in the EndWtype table when stored in words.
  #  See the implementation of ble/syntax:bash/ctx-command/check-word-end.
  [[ ! ${wtype//[0-9]} && ${_ble_syntax_bash_command_EndWtype[wtype]} ]] &&
    wtype=${_ble_syntax_bash_command_EndWtype[wtype]}

  TE_root="$wtype $wlen $tclen $tplen -- $TE_root"
}

## @fn ble/syntax/tree-enumerate/.initialize
##
##   @var[in]  iN
##     Specifies the length of the string, that is, the current parsing end position.
##
##   @var[out] TE_root
##     Adjust and return ${_ble_syntax_tree[iN-1]}.
##     Calculates the value when an unclosed range (word, nest) is closed at the end position.
##
##   @var[out] TE_i
##     Returns the end position of the last range.
##     Returns -1 if no parsing information is available.
##
##   @var[out] TE_nofs
##     Initialize to 0.
##
function ble/syntax/tree-enumerate/.initialize {
  if [[ ! ${_ble_syntax_stat[iN]} ]]; then
    TE_root= TE_i=-1 TE_nofs=0
    return 0
  fi

  local -a stat nest
  ble/string#split-words stat "${_ble_syntax_stat[iN]}"
  local wtype=${stat[2]}
  local wlen=${stat[1]}
  local nlen=${stat[3]} inest
  ((inest=nlen<0?nlen:iN-nlen))
  local tclen=${stat[4]}
  local tplen=${stat[5]}

  TE_root=
  ((iN>0)) && TE_root=${_ble_syntax_tree[iN-1]}

  while
    if ((wlen>=0)); then
      # Add word node to TE_root
      ble/syntax/tree-enumerate/.add-root-element "$wtype" "$wlen" "$tclen" "$tplen"
      tclen=0
    fi
    ((inest>=0))
  do
    ble/util/assert '[[ ${_ble_syntax_nest[inest]} ]]' "$FUNCNAME/FATAL1" || break

    ble/string#split-words nest "${_ble_syntax_nest[inest]}"

    local olen=$((iN-inest))
    tplen=${nest[4]}
    ((tplen>=0&&(tplen+=olen)))

    # Add nested node to TE_root
    ble/syntax/tree-enumerate/.add-root-element "${nest[7]}" "$olen" "$tclen" "$tplen"

    wtype=${nest[2]} wlen=${nest[1]} nlen=${nest[3]} tclen=0 tplen=${nest[5]}
    ((wlen>=0&&(wlen+=olen),
      tplen>=0&&(tplen+=olen),
      nlen>=0&&(nlen+=olen),
      inest=nlen<0?nlen:iN-nlen))

    ble/util/assert '((nlen<0||nlen>olen))' "$FUNCNAME/FATAL2" || break
  done

  if [[ $TE_root ]]; then
    ((TE_i=iN))
  else
    ((TE_i=tclen>=0?iN-tclen:tclen))
  fi
  ((TE_nofs=0))
}

## @fn ble/syntax/tree-enumerate/.impl command...
##   @param[in] command...
##     Specify the command to call for each node.
##   @var[in] iN
##   @var[in] TE_root,TE_i,TE_nofs
function ble/syntax/tree-enumerate/.impl {
  local islast=1
  while ((TE_i>0)); do
    local -a node
    if ((TE_i<iN)); then
      ble/string#split-words node "${_ble_syntax_tree[TE_i-1]}"
    else
      ble/string#split-words node "${TE_root:-${_ble_syntax_tree[iN-1]}}"
    fi

    ble/util/assert '((TE_nofs<${#node[@]}))' "$FUNCNAME(i=$TE_i,iN=$iN,TE_nofs=$TE_nofs,node=${node[*]},command=$@)/FATAL1" || break

    local wtype=${node[TE_nofs]} wlen=${node[TE_nofs+1]} tclen=${node[TE_nofs+2]} tplen=${node[TE_nofs+3]} attr=${node[TE_nofs+4]}
    local wbegin=$((wlen<0?wlen:TE_i-wlen))
    local tchild=$((tclen<0?tclen:TE_i-tclen))
    local tprev=$((tplen<0?tplen:TE_i-tplen))
    "$@"

    ble/util/assert '((tprev<TE_i))' "$FUNCNAME/FATAL2" || break

    ((TE_i=tprev,TE_nofs=0,islast=0))
  done
}

## @var[in] iN
## @var[in] TE_root,TE_i,TE_nofs
## @var[in] tchild
function ble/syntax/tree-enumerate-children {
  ((0<tchild&&tchild<=TE_i)) || return 1
  local TE_nofs=$((TE_i==tchild?TE_nofs+_ble_syntax_TREE_WIDTH:0))
  local TE_i=$tchild
  ble/syntax/tree-enumerate/.impl "$@"
}
function ble/syntax/tree-enumerate-break { ((tprev=-1)); }

## @fn ble/syntax/tree-enumerate command...
##   Based on the current parsing state _ble_syntax_tree,
##   The specified command command...
##   Call each top-level node in order, starting with the last node.
##
##   @param[in] command...
##     Specifies the command to invoke.
##
##     The command uses the following shell variables as input and output.
##     @var[in]     TE_i TE_nofs
##     @var[in]     wtype wbegin wlen attr tchild
##     @var[in,out] tprev
##       To interrupt enumeration, use ble/syntax/tree-enumerate-break
##       Set tprev=-1 by calling .
##
##     If you call ble/syntax/tree-enumerate-children internally,
##     You can also perform operations on nested words.
##
##   @var[in] iN
##     Specify the starting point of the analysis. _ble_syntax_stat must be set.
## If not specified, the end of _ble_syntax_stat will be used.
function ble/syntax/tree-enumerate {
  local TE_root TE_i TE_nofs
  [[ ${iN:+set} ]] || local iN=${#_ble_syntax_text}
  ble/syntax/tree-enumerate/.initialize
  ble/syntax/tree-enumerate/.impl "$@"
}

## @fn ble/syntax/tree-enumerate-in-range beg end proc
##   Enumerates clauses registered within a certain range without following the nested structure.
##   @param[in] beg,end
##   @param[in] proc
##     Specify a function that uses the following variables.
##     @var[in] wtype wlen wbeg wend wattr
##     @var[in] node
##     @var[in] TE_i TE_nofs
function ble/syntax/tree-enumerate-in-range {
  local beg=$1 end=$2
  local proc=$3
  local -a node
  local TE_i TE_nofs
  for ((TE_i=end;TE_i>=beg;TE_i--)); do
    ((TE_i>0)) && [[ ${_ble_syntax_tree[TE_i-1]} ]] || continue
    ble/string#split-words node "${_ble_syntax_tree[TE_i-1]}"
    local flagUpdateNode=
    for ((TE_nofs=0;TE_nofs<${#node[@]};TE_nofs+=_ble_syntax_TREE_WIDTH)); do
      local wtype=${node[TE_nofs]} wlen=${node[TE_nofs+1]} wattr=${node[TE_nofs+4]}
      local wbeg=$((wlen<0?wlen:TE_i-wlen)) wend=$TE_i
      "${@:3}"
    done
  done
}

#--------------------------------------
# ble/syntax/print-status

function ble/syntax/print-status/.graph {
  local char=$1
  if ble/util/isprint+ "$char"; then
    graph="'$char'"
    return 0
  else
    local ret
    ble/util/s2c "$char"; local code=$ret
    if ble/unicode/GraphemeCluster/ControlRepresentation "$code"; then
      graph=$_ble_term_rev$ret$_ble_term_sgr0
    else
      graph="'$char' ($code)"
    fi
  fi
}

## @var[in,out] word
function ble/syntax/print-status/.tree-prepend {
  local j=$1
  local value=$2${tree[j]}
  tree[j]=$value
  ((max_tree_width<${#value}&&(max_tree_width=${#value})))
}

function ble/syntax/print-status/.dump-arrays/.append-attr-char {
  if (($?==0)); then
    attr="${attr}$1"
  else
    attr="${attr} "
  fi
}

## @fn ble/syntax/print-status/ctx#get-text ctx
##   @var[out] ret
function ble/syntax/print-status/ctx#get-text {
  local sgr
  ble/syntax/ctx#get-name "$1"
  ret=${ret#BLE_}
  if [[ ! $ret ]]; then
    ble/color/face2sgr syntax_error
    ret="${ret}CTX$1$_ble_term_sgr0"
  fi
}
## @fn ble/syntax/print-status/word.get-text index
##   Converts the contents of _ble_syntax_tree[index] to a string.
##   @param[in] index
##   @var[out]  word
function ble/syntax/print-status/word.get-text {
  local index=$1
  ble/string#split-words word "${_ble_syntax_tree[index]}"
  local out= ret
  if [[ $word ]]; then
    local nofs=$((${#word[@]}/_ble_syntax_TREE_WIDTH*_ble_syntax_TREE_WIDTH))
    while (((nofs-=_ble_syntax_TREE_WIDTH)>=0)); do
      local axis=$((index+1))

      local wtype=${word[nofs]}
      if [[ $wtype =~ ^[0-9]+$ ]]; then
        ble/syntax/print-status/ctx#get-text "$wtype"; wtype=$ret
      elif [[ $wtype =~ ^n* ]]; then
        # Note: prefix n is added to tree-append during nest-pop.
        wtype=$sgr_quoted\"${wtype:1}\"$_ble_term_sgr0
      else
        wtype=$sgr_error${wtype}$_ble_term_sgr0
      fi

      local b=$((axis-word[nofs+1])) e=$axis
      local sprev=${word[nofs+3]} schild=${word[nofs+2]}
      if ((sprev>=0)); then
        sprev="@$((axis-sprev-1))>"
      else
        sprev=
      fi
      if ((schild>=0)); then
        schild=">@$((axis-schild-1))"
      else
        schild=
      fi

      local wattr=${word[nofs+4]}
      if [[ $wattr != - ]]; then
        wattr="/(wattr=$wattr)"
      else
        wattr=
      fi

      out=" word=$wtype:$sprev$b-$e$schild$wattr$out"
      for ((;b<index;b++)); do
        ble/syntax/print-status/.tree-prepend "$b" '|'
      done
      ble/syntax/print-status/.tree-prepend "$index" '+'
    done
    word=$out
  fi
}
## @fn ble/syntax/print-status/nest.get-text index
##   Make the contents of _ble_syntax_nest[index] a string.
##   @param[in] index
##   @var[out]  nest
function ble/syntax/print-status/nest.get-text {
  local index=$1
  ble/string#split-words nest "${_ble_syntax_nest[index]}"
  if [[ $nest ]]; then
    local ret
    ble/syntax/print-status/ctx#get-text "${nest[0]}"; local nctx=$ret

    local nword=-
    if ((nest[1]>=0)); then
      ble/syntax/print-status/ctx#get-text "${nest[2]}"; local swtype=$ret
      local wbegin=$((index-nest[1]))
      nword="$swtype:$wbegin-"
    fi

    local nnest=-
    ((nest[3]>=0)) && nnest="'${nest[7]}':$((index-nest[3]))-"

    local nchild=-
    if ((nest[4]>=0)); then
      local tchild=$((index-nest[4]))
      nchild='$'$tchild
      if ! ((0<tchild&&tchild<=index)) || [[ ! ${_ble_syntax_tree[tchild-1]} ]]; then
        nchild=$sgr_error$nchild$_ble_term_sgr0
      fi
    fi

    local nprev=-
    if ((nest[5]>=0)); then
      local tprev=$((index-nest[5]))
      nprev='$'$tprev
      if ! ((0<tprev&&tprev<=index)) || [[ ! ${_ble_syntax_tree[tprev-1]} ]]; then
        nprev=$sgr_error$nprev$_ble_term_sgr0
      fi
    fi

    local nparam=${nest[6]}
    if [[ $nparam == none ]]; then
      nparam=
    else
      # Note #D1774: bash-3.0 bug "${var//../$'...'}" leaves $'' quotes.
      #   In order to avoid the problem that occurs, substitute on separate lines.
      nparam=${nparam//$_ble_term_FS/$'\e[7m^\\\e[m'}
      nparam=" nparam=$nparam"
    fi

    nest=" nest=($nctx w=$nword n=$nnest t=$nchild:$nprev$nparam)"
  fi
}
## @fn ble/syntax/print-status/stat.get-text index
##   Converts the contents of _ble_syntax_stat[index] to a string.
##   @param[in] index
##   @var[out]  stat
function ble/syntax/print-status/stat.get-text {
  local index=$1
  ble/string#split-words stat "${_ble_syntax_stat[index]}"
  if [[ $stat ]]; then
    local ret
    ble/syntax/print-status/ctx#get-text "${stat[0]}"; local stat_ctx=$ret

    local stat_word=-
    if ((stat[1]>=0)); then
      ble/syntax/print-status/ctx#get-text "${stat[2]}"; local stat_wtype=$ret
      stat_word="$stat_wtype:$((index-stat[1]))-"
    fi

    local stat_inest=-
    if ((stat[3]>=0)); then
      local inest=$((index-stat[3]))
      stat_inest="@$inest"
      if ((inest<0)) || [[ ! ${_ble_syntax_nest[inest]} ]]; then
        stat_inest=$sgr_error$stat_inest$_ble_term_sgr0
      fi
    fi

    local stat_child=-
    if ((stat[4]>=0)); then
      local tchild=$((index-stat[4]))
      stat_child='$'$tchild
      if ! ((0<tchild&&tchild<=index)) || [[ ! ${_ble_syntax_tree[tchild-1]} ]]; then
        stat_child=$sgr_error$stat_child$_ble_term_sgr0
      fi
    fi

    local stat_prev=-
    if ((stat[5]>=0)); then
      local tprev=$((index-stat[5]))
      stat_prev='$'$tprev
      if ! ((0<tprev&&tprev<=index)) || [[ ! ${_ble_syntax_tree[tprev-1]} ]]; then
        stat_prev=$sgr_error$stat_prev$_ble_term_sgr0
      fi
    fi

    local snparam=${stat[6]}
    if [[ $snparam == none ]]; then
      snparam=
    else
      # Note #D1774: bash-3.0 bug "${var//$'...'}" leaves extra quotes.
      #   In order to avoid this problem, the assignments are made on separate lines.
      snparam=${snparam//"$_ble_term_FS"/$'\e[7m^\\\e[m'}
      snparam=" nparam=$snparam"
    fi

    local stat_lookahead=
    ((stat[7]!=1)) && stat_lookahead=" >>${stat[7]}"
    stat=" stat=($stat_ctx w=$stat_word n=$stat_inest t=$stat_child:$stat_prev$snparam$stat_lookahead)"
  fi
}

## @var[out] resultA
## @var[in]  iN
function ble/syntax/print-status/.dump-arrays {
  local -a tree char line
  tree=()
  char=()
  line=()

  local ret
  ble/color/face2sgr syntax_error; local sgr_error=$ret
  ble/color/face2sgr syntax_quoted; local sgr_quoted=$ret

  local i max_tree_width=0
  for ((i=0;i<=iN;i++)); do
    local attr="  ${_ble_syntax_attr[i]:-|}"
    if ((_ble_syntax_attr_umin<=i&&i<_ble_syntax_attr_umax)); then
      attr="${attr:${#attr}-2:2}*"
    else
      attr="${attr:${#attr}-2:2} "
    fi

    [[ ${_ble_highlight_layer_syntax1_table[i]} ]] && ble/color/g2sgr "${_ble_highlight_layer_syntax1_table[i]}"
    ble/syntax/print-status/.dump-arrays/.append-attr-char "${ret}a${_ble_term_sgr0}"
    [[ ${_ble_highlight_layer_syntax2_table[i]} ]] && ble/color/g2sgr "${_ble_highlight_layer_syntax2_table[i]}"
    ble/syntax/print-status/.dump-arrays/.append-attr-char "${ret}w${_ble_term_sgr0}"
    [[ ${_ble_highlight_layer_syntax3_table[i]} ]] && ble/color/g2sgr "${_ble_highlight_layer_syntax3_table[i]}"
    ble/syntax/print-status/.dump-arrays/.append-attr-char "${ret}e${_ble_term_sgr0}"

    [[ ${_ble_syntax_stat_shift[i]} ]]
    ble/syntax/print-status/.dump-arrays/.append-attr-char s

    local index=000$i
    index=${index:${#index}-3:3}

    local word nest stat
    ble/syntax/print-status/word.get-text "$i"
    ble/syntax/print-status/nest.get-text "$i"
    ble/syntax/print-status/stat.get-text "$i"

    local graph=
    ble/syntax/print-status/.graph "${_ble_syntax_text:i:1}"
    char[i]="$attr $index $graph"
    line[i]=$word$nest$stat
  done

  resultA='_ble_syntax_attr/tree/nest/stat?'$'\n'
  ble/string#reserve-prototype "$max_tree_width"
  for ((i=0;i<=iN;i++)); do
    local t=${tree[i]}${_ble_string_prototype::max_tree_width}
    resultA="$resultA${char[i]} ${t::max_tree_width}${line[i]}"$'\n'
  done
}

## @fn ble/syntax/print-status/.dump-tree/proc1
## @var[out] resultB
## @var[in]  prefix
## @var[in]  nl
function ble/syntax/print-status/.dump-tree/proc1 {
  local tip="| "; tip=${tip:islast:1}
  prefix="$prefix$tip   " ble/syntax/tree-enumerate-children ble/syntax/print-status/.dump-tree/proc1
  resultB="$prefix\_ '${_ble_syntax_text:wbegin:wlen}'$nl$resultB"
}

## @fn ble/syntax/print-status/.dump-tree
## @var[out] resultB
## @var[in]  iN
function ble/syntax/print-status/.dump-tree {
  resultB=

  local nl=$_ble_term_nl
  local prefix=
  ble/syntax/tree-enumerate ble/syntax/print-status/.dump-tree/proc1
}

function ble/syntax/print-status {
  local iN=${#_ble_syntax_text}

  local resultA
  ble/syntax/print-status/.dump-arrays

  local resultB
  ble/syntax/print-status/.dump-tree

  local result=$resultA$resultB
  if [[ $1 == -v && $2 ]]; then
    local "${2%%\[*\]}" && ble/util/upvar "$2" "$result"
  else
    ble/util/print "$result"
  fi
}

function ble/syntax/print-layer-buffer.draw {
  local layer_name=$1
  local -a keys vals
  builtin eval "keys=(\"\${!_ble_highlight_layer_${layer_name}_buff[@]}\")"
  builtin eval "vals=(\"\${_ble_highlight_layer_${layer_name}_buff[@]}\")"

  local ret sgr0=$_ble_term_sgr0
  ble/color/face2sgr command_builtin; local sgr1=$ret
  ble/color/face2sgr syntax_varname; local sgr2=$ret
  ble/color/face2sgr syntax_quoted; local sgr3=$ret
  ble/color/face2sgr syntax_escape; local sgr4=$ret
  local quote_word_opts=quote-empty:sgrq=$sgr3:sgre=$sgr4:sgr0=$_ble_term_sgr0

  ble/canvas/put.draw "${sgr1}buffer${sgr0} ${sgr2}$layer_name${sgr0}=("
  local i count=0
  for ((i=0;i<${#keys[@]};i++)); do
    local key=${keys[i]} val=${vals[i]}
    while ((count++<key)); do
      ((count==1)) || ble/canvas/put.draw ' '
      ble/canvas/put.draw $'\e[91munset\e[m'
    done

    ((count==1)) || ble/canvas/put.draw ' '
    ble/string#quote-word "$val" "$quote_word_opts"
    ble/canvas/put.draw "$ret"
  done
  ble/canvas/put.draw ")$_ble_term_nl"
}

#--------------------------------------

function ble/syntax/parse/serialize-stat {
  ((ilook<=i&&(ilook=i+1)))
  sstat="$ctx $((wbegin<0?wbegin:i-wbegin)) $wtype $((inest<0?inest:i-inest)) $((tchild<0?tchild:i-tchild)) $((tprev<0?tprev:i-tprev)) ${nparam:-none} $((ilook-i))"
}


## @fn ble/syntax/parse/set-lookahead count
##
##   @param[in] count
##     Specify how many characters past the current position are referenced to determine the action. string ends
##     When I confirmed that it was, I realized that I was referring to a single character that could have existed there.
##     Therefore, the end of the string must also be counted as one character.
##   @var[out] i
##   @var[out] ilook
##
##   For example, there is an i in the @ position of "a@bcdx",
##   When you look at the character x and decide to read only up to the point immediately after c,
##   Run set-lookahead 4 to advance i by 2, or
##   Advance i by 2 and then run set-lookahead 2.
##
##   When we finally refer to only the next character of i,
##   There is no need to call set-lookahead.
##
function ble/syntax/parse/set-lookahead {
  ((i+$1>ilook&&(ilook=i+$1)))
}

# Syntax tree management (_ble_syntax_tree)

## @fn ble/syntax/parse/tree-append
## Requirement Must be called after advancing the parse position (requirement: i>=p1+1).
function ble/syntax/parse/tree-append {
  [[ $debug_p1 ]] && ble/util/assert '((i-1>=debug_p1))' "Wrong call of tree-append: Condition violation (p1=$debug_p1 i=$i iN=$iN)."
  local type=$1
  local beg=$2 end=$i
  local len=$((end-beg))
  ((len==0)) && return 0

  local tchild=$3 tprev=$4

  # Child information/brother information
  local ochild=-1 oprev=-1
  ((tchild>=0&&(ochild=i-tchild)))
  ((tprev>=0&&(oprev=i-tprev)))

  [[ $type =~ ^[0-9]+$ ]] && ble/syntax/parse/touch-updated-word "$i"

  # The number of elements added must match _ble_syntax_TREE_WIDTH.
  _ble_syntax_tree[i-1]="$type $len $ochild $oprev - ${_ble_syntax_tree[i-1]}"
}

function ble/syntax/parse/word-push {
  wtype=$1 wbegin=$2 tprev=$tchild tchild=-1
}
## @fn ble/syntax/parse/word-pop
## Requirement Must be called after advancing the parse position (requirement: i>=p1+1).
# Assumption: The next higher level is either the nest-push level or the top level.
#   In this case only, use ble/syntax/parse/nest-reset-tprev to
#   can be restored to its proper value.
function ble/syntax/parse/word-pop {
  ble/syntax/parse/tree-append "$wtype" "$wbegin" "$tchild" "$tprev"
  ((wbegin=-1,wtype=-1,tchild=i))
  ble/syntax/parse/nest-reset-tprev
}
## '[[' dedicated functions:
##   To reverse the order of word-push/word-pop and nest-push.
##   For more information on how it is used, please refer to the place where it is used.
##   *Actually, instead of reading [[ as a command when it is found,
##     I feel like it should be treated specially, but it's a pain, so it's being implemented as it is now.
## Assumption: The last thing placed is a word.
##   In addition, the words to be canceled must be those that were installed in this analysis step.
function ble/syntax/parse/word-cancel {
  local -a word
  ble/string#split-words word "${_ble_syntax_tree[i-1]}"
  local wlen=${word[1]} tplen=${word[3]}
  local wbegin=$((i-wlen))
  tchild=$((tplen<0?tplen:i-tplen))
  ble/array#fill-range _ble_syntax_tree "$wbegin" "$i" ''
}

# Managing nested structures

## @fn ble/syntax/parse/nest-push newctx ntype
##   @param[in] newctx Specifies new ctx.
##   @param[in,opt] ntype Specifies the type of grammar element.
##   @var [in] i Specifies the current position.
##   @var [in out] inest Specifies the location of the parent nest. Returns the new nest position (i).
##   @var [in,out] ctx Specify ctx upon return. Returns new ctx (newctx).
##   @var [in,out] wbegin Specify wbegin at return. Returns new wbegin (-1).
##   @var [in,out] wtype Specify the wtype upon return. Returns new wtype (-1).
##   @var [in,out] tchild Specify tchild upon return. Returns new tchild (-1).
##   @var [in,out] tprev Specify tprev at return. Returns a new tprev (tchild).
##   @var [in,out] nparam Specify nparam at return. Returns a new nparam (empty string).
function ble/syntax/parse/nest-push {
  local wlen=$((wbegin<0?wbegin:i-wbegin))
  local nlen=$((inest<0?inest:i-inest))
  local tclen=$((tchild<0?tchild:i-tchild))
  local tplen=$((tprev<0?tprev:i-tprev))
  _ble_syntax_nest[i]="$ctx $wlen $wtype $nlen $tclen $tplen ${nparam:-none} ${2:-none}"
  ((ctx=$1,inest=i,wbegin=-1,wtype=-1,tprev=tchild,tchild=-1))
  nparam=
}
## @fn ble/syntax/parse/nest-pop
## Requirement Must be called after advancing the parse position (requirement: i>=p1+1).
##   Closes the current nest. Records the current nesting information and restores the next higher nesting information.
##   @var[ out] Restore the nested ctx above ctx.
##   @var[ out] Restore wbegin in the nested hierarchy above wbegin.
##   @var[ out] Restores wtype in the nested hierarchy above wtype.
##   @var[in,out] inest Specifies the nested information to record. Restore inest of the nested hierarchy above.
## @var[in,out] tchild Specifies nesting information to record. Restores the tchild in the nested hierarchy above.
##   @var[in,out] tprev Specifies nested information to record. Restores the tprev of the nested hierarchy above.
##   @var[ out] Restores the nested nparam above nparam.
function ble/syntax/parse/nest-pop {
  ((inest<0)) && return 1

  local -a parentNest
  ble/string#split-words parentNest "${_ble_syntax_nest[inest]}"

  local ntype=${parentNest[7]} nbeg=$inest
  ble/syntax/parse/tree-append "n$ntype" "$nbeg" "$tchild" "$tprev"

  local wlen=${parentNest[1]} nlen=${parentNest[3]} tplen=${parentNest[5]}
  ((ctx=parentNest[0]))
  ((wtype=parentNest[2]))
  ((wbegin=wlen<0?wlen:nbeg-wlen,
    inest=nlen<0?nlen:nbeg-nlen,
    tchild=i,
    tprev=tplen<0?tplen:nbeg-tplen))
  nparam=${parentNest[6]}
  [[ $nparam == none ]] && nparam=
}
function ble/syntax/parse/nest-type {
  local _ble_local_var=ntype
  [[ $1 == -v ]] && _ble_local_var=$2
  if ((inest<0)); then
    builtin eval "$_ble_local_var="
    return 1
  else
    builtin eval "$_ble_local_var=\"\${_ble_syntax_nest[inest]##* }\""
  fi
}
## @fn ble/syntax/parse/nest-ctx
##   @var[out] nctx
function ble/syntax/parse/nest-ctx {
  nctx=
  ((inest>=0)) || return 1
  nctx=${_ble_syntax_nest[inest]%% *}
}
function ble/syntax/parse/nest-reset-tprev {
  if ((inest<0)); then
    tprev=-1
  else
    local -a nest
    ble/string#split-words nest "${_ble_syntax_nest[inest]}"
    local tclen=${nest[4]}
    ((tprev=tclen<0?tclen:inest-tclen))
  fi
}
## @fn ble/syntax/parse/nest-equals
##   Determines whether the current nesting state matches the previous nesting state.
## @var i1 update starting point
## @var i2 update end point
## @var tail_syntax_stat[i-i2] Status before update after i2
## @var _ble_syntax_stat[i] new state
function ble/syntax/parse/nest-equals {
  local parent_inest=$1
  while ((1)); do
    ((parent_inest<i1)) && return 0 # unchanged range or -1
    ((parent_inest<i2)) && return 1 # The range that disappeared due to the change

    local onest=${tail_syntax_nest[parent_inest-i2]}
    local nnest=${_ble_syntax_nest[parent_inest]}
    [[ $onest != "$nnest" ]] && return 1

    ble/string#split-words onest "$onest"
    ble/util/assert \
      '((onest[3]!=0&&onest[3]<=parent_inest))' \
      "invalid nest onest[3]=${onest[3]} parent_inest=$parent_inest text=$text" || return 0
    ((parent_inest=onest[3]<0?onest[3]:(parent_inest-onest[3])))
  done
}

# Attribute value change range

## @var _ble_syntax_attr_umin, _ble_syntax_attr_umax records the range of updated grammar attributes.
## @var _ble_syntax_word_umin, _ble_syntax_word_umax records the range of the starting position of the updated word.
##   For attr, the range is [_ble_syntax_attr_umin, _ble_syntax_attr_umax).
##   For word, the range is [_ble_syntax_word_umin, _ble_syntax_word_umax].
_ble_syntax_attr_umin=-1 _ble_syntax_attr_umax=-1
_ble_syntax_word_umin=-1 _ble_syntax_word_umax=-1
_ble_syntax_word_defer_umin=-1 _ble_syntax_word_defer_umax=-1
function ble/syntax/parse/touch-updated-attr {
  ble/syntax/urange#update _ble_syntax_attr_ "$1" "$(($1+1))"
}
function ble/syntax/parse/touch-updated-word {
  ble/util/assert "(($1>0))" "invalid word position $1"
  ble/syntax/wrange#update _ble_syntax_word_ "$1"
}

#==============================================================================
#
# context value
#

# Context values from lib/core-syntax-ctx.def

# for debug
_ble_syntax_bash_ctx_names=(
)

## @fn ble/syntax/ctx#get-name ctx
##   @param[in] ctx
##   @var[out] ret
function ble/syntax/ctx#get-name {
  ret=${_ble_syntax_bash_ctx_names[$1]#_ble_ctx_}
}

# @var _ble_syntax_context_proc[]
# @var _ble_syntax_context_end[]
#   Grammar elements are finally registered through the above two arrays.
#   (Conversely, if you manipulate the above two arrays, you can perform a different grammar analysis.)
_ble_syntax_context_proc=()
_ble_syntax_context_end=()

#==============================================================================
#
# empty grammar
#
#------------------------------------------------------------------------------

function ble/syntax:text/ctx-unspecified {
  ((_ble_syntax_attr[i]=ctx,i+=${#tail}))
  return 0
}
_ble_syntax_context_proc[_ble_ctx_UNSPECIFIED]=ble/syntax:text/ctx-unspecified

function ble/syntax:text/initialize-ctx { ctx=$_ble_ctx_UNSPECIFIED; }
function ble/syntax:text/initialize-vars { return 0; }

#==============================================================================
#
# Bash Script syntax
#
#------------------------------------------------------------------------------

_ble_syntax_bash_RexSpaces=$'[ \t]+'
_ble_syntax_bash_RexIFSs="[$_ble_term_IFS]+"
_ble_syntax_bash_RexDelimiter="[$_ble_term_IFS;|&<>()]"
_ble_syntax_bash_RexRedirect='((\{[_a-zA-Z][_a-zA-Z0-9]*\}|[0-9]+)?(&?>>?|>[|&]|<[>&]?|<<[-<]?))[ 	]*'

## @var _ble_syntax_bash_chars[]
##   A collection of characters with a specific role. Something to be used in Bracket expression [～].
##   Since it depends on histchars, it is updated when there is a change.
_ble_syntax_bash_chars=()
_ble_syntax_bashc_seed=

function ble/syntax:bash/cclass/update/reorder {
  builtin eval "local a=\"\${$1}\""

  # Sort by safe bracket expression
  [[ $a == *']'* ]] && a="]${a//]}"
  [[ $a == *'-'* ]] && a="${a//-}-"

  builtin eval "$1=\$a"
}

## @fn ble/syntax:bash/cclass/update
##
##   @var[in] _ble_syntax_bash_histc12
##   @var[in,out] _ble_syntax_bashc_seed
##   @var[in,out] _ble_syntax_bash_chars[]
##
##   @exit Exits normally when there is an update.
##     Returns 1 when no update is required.
##
function ble/syntax:bash/cclass/update {
  local seed=$_ble_syntax_bash_histc12
  shopt -q extglob && seed=${seed}x
  [[ $seed == "$_ble_syntax_bashc_seed" ]] && return 1
  _ble_syntax_bashc_seed=$seed

  local key modified=
  if [[ $_ble_syntax_bash_histc12 == '!^' ]]; then
    for key in "${!_ble_syntax_bash_charsDef[@]}"; do
      _ble_syntax_bash_chars[key]=${_ble_syntax_bash_charsDef[key]}
    done
    _ble_syntax_bashc_simple=$_ble_syntax_bash_chars_simpleDef
  else
    modified=1

    local histc1=${_ble_syntax_bash_histc12:0:1}
    local histc2=${_ble_syntax_bash_histc12:1:1}
    for key in "${!_ble_syntax_bash_charsFmt[@]}"; do
      local a=${_ble_syntax_bash_charsFmt[key]}
      a=${a//@h/"$histc1"}
      a=${a//@q/"$histc2"}
      _ble_syntax_bash_chars[key]=$a
    done

    local a=$_ble_syntax_bash_chars_simpleFmt
    a=${a//@h/"$histc1"}
    a=${a//@q/"$histc2"}
    _ble_syntax_bashc_simple=$a
  fi

  if [[ $seed == *x ]]; then
    # extglob: ?() *() +() @() !()
    local extglob='@+!' # *? should already be registered
    _ble_syntax_bash_chars[_ble_ctx_ARGI]=${_ble_syntax_bash_chars[_ble_ctx_ARGI]}$extglob
    _ble_syntax_bash_chars[_ble_ctx_PATN]=${_ble_syntax_bash_chars[_ble_ctx_PATN]}$extglob
    _ble_syntax_bash_chars[_ble_ctx_PWORD]=${_ble_syntax_bash_chars[_ble_ctx_PWORD]}$extglob
    _ble_syntax_bash_chars[_ble_ctx_PWORDE]=${_ble_syntax_bash_chars[_ble_ctx_PWORDE]}$extglob
    _ble_syntax_bash_chars[_ble_ctx_PWORDR]=${_ble_syntax_bash_chars[_ble_ctx_PWORDR]}$extglob
  fi

  if [[ $modified ]]; then
    for key in "${!_ble_syntax_bash_chars[@]}"; do
      ble/syntax:bash/cclass/update/reorder _ble_syntax_bash_chars[key]
    done
    ble/syntax:bash/cclass/update/reorder _ble_syntax_bashc_simple
  fi
  return 0
}

_ble_syntax_bash_charsDef=()
_ble_syntax_bash_charsFmt=()
_ble_syntax_bash_chars_simpleDef=
_ble_syntax_bash_chars_simpleFmt=
function ble/syntax:bash/cclass/initialize {
  local delimiters="$_ble_term_IFS;|&()<>"
  local expansions="\$\"\`\\'"
  local glob='[*?'
  local tilde='~:'

  # _ble_syntax_bash_chars[_ble_ctx_ARGI] is used below
  #   ctx-command (various)
  #   ctx-redirect (_ble_ctx_RDRF, _ble_ctx_RDRD, _ble_ctx_RDRD2, _ble_ctx_RDRS)
  #   ctx-values (_ble_ctx_VALI, _ble_ctx_VALR, _ble_ctx_VALQ)
  #   ctx-conditions (_ble_ctx_CONDI, _ble_ctx_CONDQ)
  # It is also used below
  #   ctx-bracket-expression
  #   ctx-brace-expansion
  #   check-tilde-expansion

  # default values
  _ble_syntax_bash_charsDef[_ble_ctx_ARGI]="$delimiters$expansions$glob{$tilde^!"
  _ble_syntax_bash_charsDef[_ble_ctx_PATN]="$expansions$glob(|)<>{!" # <> is for process replacement.
  _ble_syntax_bash_charsDef[_ble_ctx_QUOT]="\$\"\`\\!"         # The only special meaning in the string "~" is $ ` \ ". +Also ! for history expansion.
  _ble_syntax_bash_charsDef[_ble_ctx_EXPR]="][}()$expansions!" # ()[] to count nesting. } is for ${var:ofs:len}.
  _ble_syntax_bash_charsDef[_ble_ctx_PWORD]="}$expansions$glob!" # Parameter expansion ${～}
  _ble_syntax_bash_charsDef[_ble_ctx_PWORDE]="}$expansions$glob!" # Parameter expansion ${～} error
  _ble_syntax_bash_charsDef[_ble_ctx_PWORDR]="}/$expansions$glob!" # Parameter expansion ${～} Before replacement
  _ble_syntax_bash_charsDef[_ble_ctx_RDRH]="$delimiters$expansions"
  _ble_syntax_bash_charsDef[_ble_ctx_HERE1]="\\\$\`$_ble_term_nl!"

  # templates
  _ble_syntax_bash_charsFmt[_ble_ctx_ARGI]="$delimiters$expansions$glob{$tilde@q@h"
  _ble_syntax_bash_charsFmt[_ble_ctx_PATN]="$expansions$glob(|)<>{@h"
  _ble_syntax_bash_charsFmt[_ble_ctx_QUOT]="\$\"\`\\@h"
  _ble_syntax_bash_charsFmt[_ble_ctx_EXPR]="][}()$expansions@h"
  _ble_syntax_bash_charsFmt[_ble_ctx_PWORD]="}$expansions$glob@h"
  _ble_syntax_bash_charsFmt[_ble_ctx_PWORDE]="}$expansions$glob@h"
  _ble_syntax_bash_charsFmt[_ble_ctx_PWORDR]="}/$expansions$glob@h"
  _ble_syntax_bash_charsFmt[_ble_ctx_RDRH]=${_ble_syntax_bash_charsDef[_ble_ctx_RDRH]}
  _ble_syntax_bash_charsFmt[_ble_ctx_HERE1]="\\\$\`$_ble_term_nl@h"

  _ble_syntax_bash_chars_simpleDef="$delimiters$expansions^!"
  _ble_syntax_bash_chars_simpleFmt="$delimiters$expansions@q@h"

  _ble_syntax_bash_histc12='!^'
  ble/syntax:bash/cclass/update
}

ble/syntax:bash/cclass/initialize

#------------------------------------------------------------------------------
# ble/syntax:bash/simple-word

## @var _ble_syntax_bash_simple_rex_word
## @var _ble_syntax_bash_simple_rex_element
##   Regular expressions representing simple word patterns and their components
##   Since it depends on histchars, it is updated when there is a change.
_ble_syntax_bash_simple_rex_letter=
_ble_syntax_bash_simple_rex_param=
_ble_syntax_bash_simple_rex_bquot=
_ble_syntax_bash_simple_rex_squot=
_ble_syntax_bash_simple_rex_dquot=
_ble_syntax_bash_simple_rex_literal=
_ble_syntax_bash_simple_rex_element=
_ble_syntax_bash_simple_rex_word=
_ble_syntax_bash_simple_rex_open_word=
_ble_syntax_bash_simple_rex_open_dquot=
_ble_syntax_bash_simple_rex_open_squot=
_ble_syntax_bash_simple_rex_incomplete_word1=
_ble_syntax_bash_simple_rex_incomplete_word2=

_ble_syntax_bash_simple_rex_noglob_word1=
_ble_syntax_bash_simple_rex_noglob_word2=

function ble/syntax:bash/simple-word/update {
  local q="'"

  local letter='\[[!^]|[^'${_ble_syntax_bashc_simple}']'
  local param1='\$([-*@#?$!0_]|[1-9][0-9]*|[_a-zA-Z][_a-zA-Z0-9]*)'
  local param2='\$\{(#?[-*@#?$!0]|[#!]?([1-9][0-9]*|[_a-zA-Z][_a-zA-Z0-9]*))\}' # ${!!} ${!$} results in an error. Is it because of history expansion?
  local param=$param1'|'$param2
  local bquot='\\.'
  local squot=$q'[^'$q']*'$q'|\$'$q'([^'$q'\]|\\.)*'$q
  local dquot='\$?"([^'${_ble_syntax_bash_chars[_ble_ctx_QUOT]}']|\\.|'$param')*"'
  _ble_syntax_bash_simple_rex_letter=$letter # 0 groups
  _ble_syntax_bash_simple_rex_param=$param   # 3 groups
  _ble_syntax_bash_simple_rex_bquot=$bquot   # 0 groups
  _ble_syntax_bash_simple_rex_squot=$squot   # 1 groups
  _ble_syntax_bash_simple_rex_dquot=$dquot   # 4 groups

  # @var _ble_syntax_bash_simple_rex_element
  # @var _ble_syntax_bash_simple_rex_word
  _ble_syntax_bash_simple_rex_literal='^('$letter')+$'
  _ble_syntax_bash_simple_rex_element='('$bquot'|'$squot'|'$dquot'|'$param'|'$letter')'
  _ble_syntax_bash_simple_rex_word='^'$_ble_syntax_bash_simple_rex_element'+$'

  # @var _ble_syntax_bash_simple_rex_open_word
  local open_squot=$q'[^'$q']*|\$'$q'([^'$q'\]|\\.)*'
  local open_dquot='\$?"([^'${_ble_syntax_bash_chars[_ble_ctx_QUOT]}']|\\.|'$param')*'
  _ble_syntax_bash_simple_rex_open_word='^('$_ble_syntax_bash_simple_rex_element'*)(\\|'$open_squot'|'$open_dquot')$'
  _ble_syntax_bash_simple_rex_open_squot=$open_squot
  _ble_syntax_bash_simple_rex_open_dquot=$open_dquot

  # @var _ble_syntax_bash_simple_rex_incomplete_word1
  # @var _ble_syntax_bash_simple_rex_incomplete_word2
  local letter1='\[[!^]|[^{'${_ble_syntax_bashc_simple}']'
  local letter2='\[[!^]|[^'${_ble_syntax_bashc_simple}']'
  _ble_syntax_bash_simple_rex_incomplete_word1='^('$bquot'|'$squot'|'$dquot'|'$param'|'$letter1')+'
  _ble_syntax_bash_simple_rex_incomplete_word2='^(('$bquot'|'$squot'|'$dquot'|'$param'|'$letter2')*)(\\|'$open_squot'|'$open_dquot')?$'

  # @var _ble_syntax_bash_simple_rex_noglob_word{1,2}
  local noglob_letter='[^[?*'${_ble_syntax_bashc_simple}']'
  _ble_syntax_bash_simple_rex_noglob_word1='^('$bquot'|'$squot'|'$dquot'|'$noglob_letter')+$'
  _ble_syntax_bash_simple_rex_noglob_word2='^('$bquot'|'$squot'|'$dquot'|'$param'|'$noglob_letter')+$'
}
ble/syntax:bash/simple-word/update

function ble/syntax:bash/simple-word/is-literal {
  [[ $1 =~ $_ble_syntax_bash_simple_rex_literal ]]
}
function ble/syntax:bash/simple-word/is-simple {
  [[ $1 =~ $_ble_syntax_bash_simple_rex_word ]]
}
function ble/syntax:bash/simple-word/is-simple-or-open-simple {
  [[ $1 =~ $_ble_syntax_bash_simple_rex_word || $1 =~ $_ble_syntax_bash_simple_rex_open_word ]]
}
function ble/syntax:bash/simple-word/is-never-word {
  ble/syntax:bash/simple-word/is-simple-or-open-simple && return 1
  local rex=${_ble_syntax_bash_simple_rex_word%'$'}'[ |&;<>()]|^[ |&;<>()]'
  [[ $1 =~ $rex ]]
}
function ble/syntax:bash/simple-word/is-simple-noglob {
  [[ $1 =~ $_ble_syntax_bash_simple_rex_noglob_word1 ]] && return 0
  if [[ $1 =~ $_ble_syntax_bash_simple_rex_noglob_word2 ]]; then
    builtin eval -- "local expanded=$1" 2>/dev/null
    local rex='[*?]|\[.+\]|[*?@+!]\(.*\)'
    [[ $expanded =~ $rex ]] || return 0
  fi
  return 1
}

## @fn ble/syntax:bash/simple-word/evaluate-last-brace-expansion simple_word
##   @param[in] simple_word
##   @var[out] ret simple_ibrace
function ble/syntax:bash/simple-word/evaluate-last-brace-expansion {
  local value=$1
  local bquot=$_ble_syntax_bash_simple_rex_bquot
  local squot=$_ble_syntax_bash_simple_rex_squot
  local dquot=$_ble_syntax_bash_simple_rex_dquot
  local param=$_ble_syntax_bash_simple_rex_param
  local letter='\[[!^]|[^{,}'${_ble_syntax_bashc_simple}']'
  local symbol='[{,}]'

  local rex_range_expansion='^(([-+]?[0-9]+)\.\.\.[-+]?[0-9]+|([a-zA-Z])\.\.[a-zA-Z])(\.\.[-+]?[0-9]+)?$'

  local rex0='^('$bquot'|'$squot'|'$dquot'|'$param'|'$letter')+'
  local stack; stack=()
  local out= comma= index=0 iopen=0 no_brace_length=0
  while [[ $value ]]; do
    if [[ $value =~ $rex0 ]]; then
      local len=${#BASH_REMATCH}
      ((index+=len,no_brace_length+=len))
      out=$out${value::len}
      value=${value:len}
    elif [[ $value == '{'* ]]; then
      ((iopen=++index,no_brace_length=0))
      value=${value:1}
      ble/array#push stack "$comma:$out"
      out= comma=
    elif ((${#stack[@]})) && [[ $value == '}'* ]]; then
      ((++index))
      value=${value:1}
      ble/array#pop stack
      local out0=${ret#*:} comma0=${ret%%:*}
      if [[ $comma ]]; then
        ((iopen=index,no_brace_length=0))
        out=$out0$out
        comma=$comma0
      elif [[ $out =~ $rex_range_expansion ]]; then
        ((iopen=index,no_brace_length=0))
        out=$out0${2#+}$3
        comma=$comma0
      else
        ((++no_brace_length))
        ble/array#push stack "$comma0:$out0" # cancel pop
        out=$out'}'
      fi
    elif ((${#stack[@]})) && [[ $value == ','* ]]; then
      ((iopen=++index,no_brace_length=0))
      value=${value:1}
      out= comma=1
    else
      ((++index,++no_brace_length))
      out=$out${value::1}
      value=${value:1}
    fi
  done

  while ((${#stack[@]})); do
    ble/array#pop stack
    local out0=${ret#*:} comma0=${ret%%:*}
    out=$out0$out
  done

  ret=$out simple_ibrace=$iopen:$((${#out}-no_brace_length))
}

## @fn ble/syntax:bash/simple-word/reconstruct-incomplete-word word
##   Incomplete brace expansion and incomplete quotation closing for word,
##   Perform further brace expansion to get the last word.
##
##   @param[in] word
##     Specify an incomplete word.
##
##   @var[out] ret
##     Closes the incomplete brace expansion and quotation mark for word and returns the result of the brace expansion.
##
##   @var[out] simple_flags
##     Set simple_flags=I on closing quote $"...".
##     Set simple_flags=D when closing quote "...".
##     Set simple_flags=E when closing quote $'...'.
##     Set simple_flags=S when closing quote '...'.
##     Set simple_flags=B when there is an incomplete terminal \.
##
##   @var[out] simple_ibrace=ibrace:jbrace
##     Returns the first position that can be changed without destroying the structure of the brace expansion.
##     ibrace returns the position in word, jbrace returns the position in ret.
##
##   @exit
##     Success occurs when the shell becomes a complete word by expanding braces and closing quotes.
## It will fail otherwise.
##
function ble/syntax:bash/simple-word/reconstruct-incomplete-word {
  local word=$1
  ret= simple_flags= simple_ibrace=0:0

  [[ $word ]] || return 0

  if [[ $word =~ $_ble_syntax_bash_simple_rex_incomplete_word1 ]]; then
    ret=${word::${#BASH_REMATCH}}
    word=${word:${#BASH_REMATCH}}
    [[ $word ]] || return 0
  fi

  if [[ $word =~ $_ble_syntax_bash_simple_rex_incomplete_word2 ]]; then
    local out=$ret

    local m_brace=${BASH_REMATCH[1]}
    local m_quote=${word:${#m_brace}}

    if [[ $m_brace ]]; then
      ble/syntax:bash/simple-word/evaluate-last-brace-expansion "$m_brace"
      simple_ibrace=$((${#out}+${simple_ibrace%:*})):$((${#out}+${simple_ibrace#*:}))
      out=$out$ret
    fi

    if [[ $m_quote ]]; then
      case $m_quote in
      ('$"'*) out=$out$m_quote\" simple_flags=I ;;
      ('"'*)  out=$out$m_quote\" simple_flags=D ;;
      ("$'"*) out=$out$m_quote\' simple_flags=E ;;
      ("'"*)  out=$out$m_quote\' simple_flags=S ;;
      ('\')   simple_flags=B ;;
      (*) return 1 ;;
      esac
    fi

    ret=$out
    return 0
  fi

  return 1
}

## @fn ble/syntax:bash/simple-word/extract-parameter-names word
##   Extracts the parameter name of parameter expansion contained in a simple word.
##   @var[in] word
##   @var[out] ret
function ble/syntax:bash/simple-word/extract-parameter-names {
  ret=()
  local letter=$_ble_syntax_bash_simple_rex_letter
  local bquot=$_ble_syntax_bash_simple_rex_bquot
  local squot=$_ble_syntax_bash_simple_rex_squot
  local dquot=$_ble_syntax_bash_simple_rex_dquot
  local param=$_ble_syntax_bash_simple_rex_param

  local value=$1
  local rex0='^('$letter'|'$bquot'|'$squot')+'
  local rex1='^('$dquot')'
  local rex2='^('$param')'
  while [[ $value ]]; do
    [[ $value =~ $rex0 ]] && value=${value:${#BASH_REMATCH}}
    if [[ $value =~ $rex1 ]]; then
      value=${value:${#BASH_REMATCH}}
      ble/syntax:bash/simple-word/extract-parameter-names/.process-dquot "$BASH_REMATCH"
    fi
    [[ $value =~ $rex2 ]] || break
    value=${value:${#BASH_REMATCH}}
    local var=${BASH_REMATCH[2]}${BASH_REMATCH[3]}
    [[ $var == [_a-zA-Z]* ]] && ble/array#push ret "$var"
  done
}
## @fn ble/syntax:bash/simple-word/extract-parameter-names/.process-dquot match
##   @var[in,out] ret
function ble/syntax:bash/simple-word/extract-parameter-names/.process-dquot {
  local value=$1
  if [[ $value == '$"'*'"' ]]; then
    value=${value:2:${#value}-3}
  elif [[ $value == '"'*'"' ]]; then
    value=${value:1:${#value}-2}
  else
    return 0
  fi

  local rex0='^([^'${_ble_syntax_bash_chars[_ble_ctx_QUOT]}']|\\.)+'
  local rex2='^('$param')'
  while [[ $value ]]; do
    [[ $value =~ $rex0 ]] && value=${value:${#BASH_REMATCH}}
    [[ $value =~ $rex2 ]] || break
    value=${value:${#BASH_REMATCH}}
    local var=${BASH_REMATCH[2]}${BASH_REMATCH[3]}
    [[ $var == [_a-zA-Z]* ]] && ble/array#push ret "$var"
  done
}

function ble/syntax:bash/simple-word/eval/.set-result {
  if [[ $__ble_word_limit ]] && (($#>__ble_word_limit)); then
    set -- "${@::__ble_word_limit}"
  fi
  __ble_ret=("$@")
}
function ble/syntax:bash/simple-word/eval/.print-result {
  if [[ $__ble_word_limit ]] && (($#>__ble_word_limit)); then
    set -- "${@::__ble_word_limit}"
  fi
  if (($#>=1000)) && [[ $OSTYPE != cygwin && $OSTYPE != msys ]]; then
    # If the number of files is small, quote&eval may be a little slower to avoid fork costs.
    # transfer the data to the parent shell. On Cygwin, mapfile/read is unbuffered and slow.
    # Therefore, use quote&eval even if the number of files is slow.

    if ((_ble_bash>=50200)); then
      printf '%s\0' "$@" >| "$__ble_simple_word_tmpfile"
      ble/util/print 'ble/util/readarray -d "" __ble_ret < "$__ble_simple_word_tmpfile"'
      return 0
    elif ((_ble_bash>=40000)); then
      ret=("$@")
      ble/util/writearray --nlfix ret >| "$__ble_simple_word_tmpfile"
      ble/util/print 'ble/util/readarray --nlfix __ble_ret < "$__ble_simple_word_tmpfile"'
      return 0
    fi
  fi

  local ret; ble/string#quote-words "$@"
  ble/util/print "__ble_ret=($ret)"
}
## @fn ble/syntax:bash/simple-word/eval/.eval-set
## @fn ble/syntax:bash/simple-word/eval/.eval-print
##   Evaluate the specified word and set or print the results.
##   @var[in] __ble_simple_word
##     This variable specifies the target word to evalaute.
##   @remarks #D2246: These functions are needed to evaluate the word in a
##     context with the proper positional parameters.  The evaluation of the
##     positional parameter expansions in $__ble_simple_word may cause
##     unexpected "failglob" if the positional parameters of the current
##     context is naively used.  We try to restore the positional parameters of
##     the top-level context and evaluate the word with these positional
##     parameters.
function ble/syntax:bash/simple-word/eval/.eval-set {
  if [[ ${_ble_edit_exec_lastparams[0]+set} ]]; then
    set -- "${_ble_edit_exec_lastparams[@]}"
  else
    set --
  fi
  local ext=0
  builtin eval -- "ble/syntax:bash/simple-word/eval/.set-result $__ble_simple_word" &>/dev/null; ext=$?
  builtin eval : # Note: bash 3.1/3.2 eval bug fix (#D1132)
  return "$ext"
}
function ble/syntax:bash/simple-word/eval/.eval-print {
  if [[ ${_ble_edit_exec_lastparams[0]+set} ]]; then
    set -- "${_ble_edit_exec_lastparams[@]}"
  else
    set --
  fi
  builtin eval -- "ble/syntax:bash/simple-word/eval/.print-result $__ble_simple_word"
}
## @fn ble/syntax:bash/simple-word/eval/.impl word opts
##   @param[in] word
##   @param[in,opt] opts
##   @var[out] __ble_ret
function ble/syntax:bash/simple-word/eval/.impl {
  local __ble_word=$1 __ble_opts=$2 __ble_flags=

  # Restoring global variables
  local -a ret=()
  ble/syntax:bash/simple-word/extract-parameter-names "$__ble_word"
  if ((${#ret[@]})); then
    local __ble_defs
    ble/util/assign __ble_defs 'ble/util/print-global-definitions --hidden-only "${ret[@]}"'
    builtin eval -- "$__ble_defs" &>/dev/null # May be a read-only variable
  fi

  local __ble_word_limit=
  ble/string#match ":$__ble_opts:" ':limit=([^:]*):' &&
    ((__ble_word_limit=BASH_REMATCH[1]))

  # Processing when glob patterns may be included (Note: is-simple-noglob
  # Since the variable is referenced in the judgment, it is necessary to process it after restoring the global variable.
  # (necessary)
  if [[ $- != *f* ]] && ! ble/syntax:bash/simple-word/is-simple-noglob "$1"; then
    if [[ :$__ble_opts: == *:noglob:* ]]; then
      set -f
      __ble_flags=f
    elif ble/util/is-cygwin-slow-glob "$1"; then # Note: #D1168
      if shopt -q failglob &>/dev/null; then
        __ble_ret=()
        return 1
      elif shopt -q nullglob &>/dev/null; then
        __ble_ret=()
        return 0
      else
        # Process with noglob
        set -f
        __ble_flags=f
      fi
    elif [[ :$__ble_opts: == *:stopcheck:* ]]; then
      ble/decode/has-input && return 148
      if ((_ble_bash>=40000)); then
        __ble_flags=s
      elif shopt -q globstar &>/dev/null; then
        # If you can't use conditional-sync, at least use globstar.
        if builtin eval "[[ $__ble_word == *'**'* ]]"; then
          [[ :$__ble_opts: == *:timeout=*:* ]] && return 142
          return 148
        fi
      fi
    fi
  fi

  # Note: If there is no match during failglob, it will not be executed, so use __ble_ret=() in advance.
  #   Also, since an error message will occur, connect to /dev/null.
  __ble_ret=()
  local __ble_simple_word=$__ble_word
  if [[ $__ble_flags == *s* ]]; then
    local __ble_sync_command=ble/syntax:bash/simple-word/eval/.eval-print
    local __ble_sync_opts=progressive-weight
    local __ble_sync_weight=$bleopt_syntax_eval_polling_interval

    # determine timeout
    local __ble_sync_timeout=$_ble_syntax_bash_simple_eval_timeout
    if [[ $_ble_syntax_bash_simple_eval_timeout_carry ]]; then
      __ble_sync_timeout=0
    elif ble/string#match ":$__ble_opts:" ':timeout=([^:]*):'; then
      __ble_sync_timeout=${BASH_REMATCH[1]}
    fi
    [[ $__ble_sync_timeout ]] &&
      __ble_sync_opts=$__ble_sync_opts:timeout=$((__ble_sync_timeout))

    local _ble_local_tmpfile; ble/util/assign/mktmp
    local __ble_simple_word_tmpfile=$_ble_local_tmpfile
    local __ble_script
    ble/util/assign __ble_script 'ble/util/conditional-sync "$__ble_sync_command" "" "$__ble_sync_weight" "$__ble_sync_opts"' &>/dev/null; local ext=$?
    builtin eval -- "$__ble_script"
    ble/util/assign/rmtmp
  else
    ble/syntax:bash/simple-word/eval/.eval-set; local ext=$?
  fi

  [[ $__ble_flags == *f* ]] && set +f
  return "$ext"
}

_ble_syntax_bash_simple_eval_hash=
## @fn ble/syntax:bash/simple-word/eval/.cache-clear
##   @var[in,out] _ble_syntax_bash_simple_eval
function ble/syntax:bash/simple-word/eval/.cache-clear {
  ble/gdict#clear _ble_syntax_bash_simple_eval
  ble/gdict#clear _ble_syntax_bash_simple_eval_full
}
## @fn ble/syntax:bash/simple-word/eval/.cache-update
##   @var[in,out] _ble_syntax_bash_simple_eval
##   @var[in,out] _ble_syntax_bash_simple_eval_hash
function ble/syntax:bash/simple-word/eval/.cache-update {
  local hash=$-:${BASHOPTS-}:$_ble_edit_lineno:$_ble_textarea_version:$PWD
  if [[ $hash != "$_ble_syntax_bash_simple_eval_hash" ]]; then
    _ble_syntax_bash_simple_eval_hash=$hash
    ble/syntax:bash/simple-word/eval/.cache-clear
  fi
}
## @fn ble/syntax:bash/simple-word/eval/.save word ext ret...
##   @var[in] ext
##   @var[in,out] _ble_syntax_bash_simple_eval
function ble/syntax:bash/simple-word/eval/.cache-save {
  ((ext==148||ext==142)) && return 0
  local ret; ble/string#quote-words "$3"
  ble/gdict#set _ble_syntax_bash_simple_eval "$1" "ext=$2 count=$(($#-2)) ret=$ret"
  local ret; ble/string#quote-words "${@:3}"
  ble/gdict#set _ble_syntax_bash_simple_eval_full "$1" "ext=$2 count=$(($#-2)) ret=($ret)"
}
## @fn ble/syntax:bash/simple-word/eval/.cache-load word opts
function ble/syntax:bash/simple-word/eval/.cache-load {
  ext= ret=
  if [[ :$2: == *:single:* ]]; then
    ble/gdict#get _ble_syntax_bash_simple_eval "$1" || return 1
  else
    ble/gdict#get _ble_syntax_bash_simple_eval_full "$1" || return 1
  fi
  builtin eval -- "$ret"
  return 0
}

## @fn ble/syntax:bash/simple-word/eval word opts
##   @param[in] word
##   @param[in,opt] opts
##     Options are separated by colons.
##
##       noglob
##         Suppress pathname expansion.
##
##     Below are options that do not affect the evaluation result (on success).
##
##       single
##         Set only the first expansion result to ret.
##       limit=COUNT
##         Limits the number of words after evaluation to less than or equal to COUNT. This is set by count
##         It also affects the number of words in the expanded result.
##       count
##         Returns the number of words in the expansion result in the variable count.
##       cached
##         Cache the expansion results.
##
##     The following is valid for words that are subject to pathname expansion:
##
##       stopcheck
##         Interrupt on user input.
##       timeout=NUM
##         Valid when stopcheck is specified. Specify timeout.
##       retry-noglob-on-timeout
##         At timeout, try expanding again with noglob.
##       timeout-carry
##         Propagates the timeout to subsequent evals if it occurs.
##
##   @var[in] _ble_syntax_bash_simple_eval_timeout
##     Specifies the default timeout for pathname expansion. An empty string is specified.
##     By default, no timeout occurs when the
##   @var[in,out] _ble_syntax_bash_simple_eval_timeout_carry
##     When this value is set, a timeout will be forced for pathname expansion.
##     Masu. The value is set when timeout-carry is specified in opts.
##
##   @arr[out] ret
##     Returns the expansion result. If it evaluates to multiple words, it will return them all.
##     When single is specified in opts, only the first expansion result is returned.
##   @var[out] count
##     Returns the number of expansion results when count is specified in opts.
##
##   @exit
##     Returns 148 if aborted by user input. cause timeout
##     returns 142. If you fail due to other reasons, e.g. failglob,
##     Returns a non-zero exit status if name expansion fails.
##
_ble_syntax_bash_simple_eval_timeout=
_ble_syntax_bash_simple_eval_timeout_carry=
function ble/syntax:bash/simple-word/eval {
  [[ :$2: != *:count:* ]] && local count
  if [[ :$2: == *:cached:* && :$2: != *:noglob:* ]]; then
    ble/syntax:bash/simple-word/eval/.cache-update
    local ext; ble/syntax:bash/simple-word/eval/.cache-load "$1" "$2" && return "$ext"
  fi

  local __ble_ret
  ble/syntax:bash/simple-word/eval/.impl "$1" "$2"; local ext=$?
  ret=("${__ble_ret[@]}")
  count=${#ret[@]}

  if [[ :$2: == *:cached:* && :$2: != *:noglob:* ]]; then
    ble/syntax:bash/simple-word/eval/.cache-save "$1" "$ext" "${ret[@]}"
  fi
  if ((ext==142)); then
    [[ :$2: == *:timeout-carry:* ]] &&
      _ble_syntax_bash_simple_eval_timeout_carry=1
    if [[ :$2: == *:retry-noglob-on-timeout:* ]]; then
      ble/syntax:bash/simple-word/eval "$1" "$2:noglob"
      return "$?"
    fi
  fi
  return "$ext"
}

## @fn ble/syntax:bash/simple-word/safe-eval word [opts]
##   Evaluate the specified word only when the word is safe and take the first
##   word when the word is expanded to multiple words.
##
##   @param[in,opt] opts
##     A colon-separated list of options.  In addition to the values supported
##     by ble/syntax:bash/simple-word/eval, the following values are available:
##
##     @opt reconstruct
##       Try to reconstruct the full word using
##       ble/syntax:bash/simple-word/reconstruct-incomplete-word when there is
##       no closing quote corresponding to an opening one in the word.
##
##     @opt nonull
##       Fails when no word is generated.  This may happen with e.g. an
##       expansion an empty array "${arr[@]}" or unmatching glob pattern with
##       nullglob.
##
##     The other options are processed by "ble/syntax:bash/simple-word/eval",
##     but if "limit=COUNT" is not specified, the option "limit=1" is added to
##     suppress the number of generated words.
##
##   @arr[out] ret
##
function ble/syntax:bash/simple-word/safe-eval {
  local __ble_opts=$2
  if [[ :$__ble_opts: == *:reconstruct:* ]]; then
    local simple_flags simple_ibrace
    ble/syntax:bash/simple-word/reconstruct-incomplete-word "$1" || return 1
    ble/util/unlocal simple_flags simple_ibrace
  else
    ble/syntax:bash/simple-word/is-simple "$1" || return 1
  fi
  [[ :$__ble_opts: == *:limit=*:* ]] ||
    __ble_opts=$__ble_opts:limit=1

  ble/syntax:bash/simple-word/eval "$1" "$__ble_opts" &&
    { [[ :$__ble_opts: != *:nonull:* ]] || ((${#ret[@]})); }
}

## @fn ble/syntax:bash/simple-word/get-rex_element sep
##   Constructs a regular expression that matches simple word pieces separated by the specified segmentation character (sep).
##   @var[out] rex_element
function ble/syntax:bash/simple-word/get-rex_element {
  local sep=$1
  local param=$_ble_syntax_bash_simple_rex_param
  local bquot=$_ble_syntax_bash_simple_rex_bquot
  local squot=$_ble_syntax_bash_simple_rex_squot
  local dquot=$_ble_syntax_bash_simple_rex_dquot
  local letter1='\[[!^]|[^'$sep$_ble_syntax_bashc_simple']'
  rex_element='('$bquot'|'$squot'|'$dquot'|'$param'|'$letter1')+'
}
## @fn ble/syntax:bash/simple-word/evaluate-path-spec path_spec [sep] [opts]
##   @param[in] path_spec
##   @param[in,opt] sep (default: '/:=')
##   @param[in,opt] opts
##     noglob
##     stopcheck
##     timeout=*
##     timeout-carry
##     cached
##       These are options for simple-word/eval.
##
##     notilde
##       Suppresses tilde expansion during evaluation.
##     after-sep
##       Change the split position after the divider instead of before it.
##     fixlen=LEN
##       Specifies the length of fixed prefixes that are not subject to splitting.
##
##   @arr[out] spec
##   @arr[out] path
##   @arr[out] ret
##     Returns the result of evaluating the entire path_spec.
##     When expanded into multiple paths by path name expansion,
##     This will be an array containing all expansion results.
##
##   Evaluates the specified path_spec in order from the root to the end, separated by the characters included in sep.
##   Add the evaluation target up to each layer to spec and the evaluation result to path.
##   For example, when path_spec='~/a/b',
##     spec=(~ ~/a ~/a/b)
##     path=(/home/user /home/user/a /home/user/a/b)
##   You will get the following result.
##
function ble/syntax:bash/simple-word/evaluate-path-spec {
  local word=$1 sep=${2:-'/:='} opts=$3
  ret=() spec=() path=()
  [[ $word ]] || return 0

  # read options
  local eval_opts=$opts notilde=
  [[ :$opts: == *:notilde:* ]] && notilde=\'\' #Suppressing tilde expansion
  local fixlen
  ble/opts#extract-last-optarg "$opts" fixlen 0

  # compose regular expressions
  local rex_element; ble/syntax:bash/simple-word/get-rex_element "$sep"
  local rex='^['$sep']?'$rex_element'|^['$sep']'
  [[ :$opts: == *:after-sep:* ]] &&
    local rex='^'$rex_element'['$sep']?|^['$sep']'

  local tail=${word:fixlen} s=${word::fixlen} p= ext=0
  while [[ $tail =~ $rex ]]; do
    local rematch=$BASH_REMATCH
    s=$s$rematch
    ble/syntax:bash/simple-word/eval "$notilde$s" "$eval_opts"; ext=$?
    ((ext==148||ext==142)) && return "$ext"
    p=$ret
    tail=${tail:${#rematch}}
    ble/array#push spec "$s"
    ble/array#push path "$p"
  done
  [[ $tail ]] && return 1
  ((ext)) && return "$ext"
  return 0
}

## @fn ble/syntax:bash/simple-word/detect-separated-path word [sep] [opts]
##   Determines whether the specified word is a single path name or a sep-separated path business card.
##   @param[in] word
##   @param[in,opt] sep
##   @param[in] opts
##     noglob
##     stopcheck
##     timeout=*
##     timeout-carry
##     cached
##     url
##     notilde
##   @var[out] ret
##     Returns the set of valid delimiters.
function ble/syntax:bash/simple-word/detect-separated-path {
  local word=$1 sep=${2:-':'} opts=$3
  [[ $word ]] || return 1

  local rex_url='^[a-z]+://'
  [[ :$opts: == *:url:* ]] && ble/string#match-safe "$word" "$rex_url" && return 1

  # read eval options
  local eval_opts=$opts notilde=
  [[ :$opts: == *:notilde:* ]] && notilde=\'\' #Suppressing tilde expansion

  # compose regular expressions
  local rex_element
  ble/syntax:bash/simple-word/get-rex_element /
  local rex='^'$rex_element'/?|^/'

  local tail=$word head=
  while [[ $tail =~ $rex ]]; do
    local rematch=$BASH_REMATCH
    ble/syntax:bash/simple-word/locate-filename/.exists "$notilde$head$rematch"; local ext=$?
    ((ext==148)) && return 148
    ((ext==0)) || break
    head=$head$rematch
    tail=${tail:${#rematch}}
  done

  ret=
  local i
  for ((i=0;i<${#sep};i++)); do
    local sep1=${sep:i:1}
    ble/syntax:bash/simple-word/get-rex_element "$sep1"
    local rex_nocolon='^('$rex_element')?$'
    local rex_hascolon='^('$rex_element')?['$sep1']'
    [[ $head =~ $rex_nocolon && $tail =~ $rex_hascolon ]] && ret=$ret$sep1
  done
  [[ $ret ]]
}

## @fn ble/syntax:bash/simple-word/locate-filename/.exists word opts
##   @param[in] word
##   @param[in] opts
##   @var[in] eval_opts
##   @var[in] rex_url
function ble/syntax:bash/simple-word/locate-filename/.exists {
  local word=$1 ret
  ble/syntax:bash/simple-word/eval "$word" "$eval_opts" || return "$?"
  local path=$ret
  # Note: #D1168 In Cygwin, it is slow to judge paths starting with //, so judge directly by character string.
  if [[ ( $OSTYPE == cygwin || $OSTYPE == msys ) && $path == //* ]]; then
    [[ $path == // ]]
  else
    [[ -e $path || -h $path ]]
  fi || [[ :$opts: == *:url:* ]] && ble/string#match-safe "$path" "$rex_url"
}
## @fn ble/syntax:bash/simple-word/locate-filename word [sep] [opts]
##   @param[in] word
##   @param[in] sep
##   @param[in] opts
##     exists
##       Extracts only valid file names that exist.
##     greedy
##       If a combined path is valid without considering : as a delimiter, that combined path will be used.
##     url
##       Paths starting with [a-z]+:// are unconditionally determined to be valid paths.
##     stopcheck
##       Interrupt potentially time-consuming pathname expansion with user input.
##     timeout=*
##       Specify timeout for stopcheck.
##     timeout-carry
##       Propagates the timeout to subsequent pathname expansion.
##     cached
##       Cache the expanded contents.
##
##   @arr[out] ret
##     Contains an even number of elements. Even index (0, 2, 4, ...) is the start of the range,
##     Odd index (1, 3, 5, ...) is the end of the range.
##
function ble/syntax:bash/simple-word/locate-filename {
  local word=$1 sep=${2:-':='} opts=$3
  ret=0
  [[ $word ]] || return 0

  # prepare evaluator
  local eval_opts=$opts

  # compose regular expressions
  local rex_element; ble/syntax:bash/simple-word/get-rex_element "$sep"
  local rex='^'$rex_element'['$sep']|^['$sep']'
  local rex_url='^[a-z]+://'

  local -a seppos=()
  local tail=$word p=0
  while [[ $tail =~ $rex ]]; do
    ((p+=${#BASH_REMATCH}))
    tail=${tail:${#BASH_REMATCH}}
    ble/array#push seppos "$((p-1))"
  done
  ble/syntax:bash/simple-word/is-simple "$tail" &&
    ble/array#push seppos "$((p+${#tail}))"

  local -a out=()
  for ((i=0;i<${#seppos[@]};i++)); do
    local j0=$i
    [[ :$opts: == *:greedy:* ]] && j0=${#seppos[@]}-1
    local j
    for ((j=j0;j>=i;j--)); do
      local f1=0 f2=${seppos[j]}
      ((i)) && ((f1=seppos[i-1]+1))

      if ((j>i)); then
        # If it can be concatenated to create an existing file name, use that
        ble/syntax:bash/simple-word/locate-filename/.exists "${word:f1:f2-f1}" "$opts"; local ext=$?
        ((ext==148)) && return 148
        if ((ext==0)); then
          ble/array#push out "$f1" "$f2"
          ((i=j))
        fi
      else
        # If the file is not found, register a single interval
        if [[ :$opts: != *:exists:* ]] ||
             { ble/syntax:bash/simple-word/locate-filename/.exists "${word:f1:f2-f1}" "$opts"
               local ext=$?; ((ext==148)) && return 148; ((ext==0)); }; then
          ble/array#push out "$f1" "$f2"
        fi
      fi
    done
  done

  ret=("${out[@]}")
  return 0
}

## @fn ble/syntax:bash/simple-word#break-word word sep
##   Splits a word with the specified divider. No evaluation will be made.
##   Used by progcomp to split words by COMP_WORDBREAKS.
##   For example, for a==b:c\=d, it produces the result ret=(a == b : c=d).
##
##   @param[in] word
##     Assumption: Must be simple-word/is-simple.
##
##   @arr[out] ret
##     Returns an array containing word fragments.
##     The even-numbered elements are strings other than the divider.
##     Odd-numbered elements are strings consisting of dividers.
##
function ble/syntax:bash/simple-word#break-word {
  local word=$1 sep=${2:-':='}
  if [[ ! $word ]]; then
    ret=('')
    return 0
  fi

  sep=${sep//[\"\'\$\`]}

  # compose regular expressions
  local rex_element; ble/syntax:bash/simple-word/get-rex_element "$sep"
  local rex='^('$rex_element')?['$sep']+'

  local -a out=()
  local tail=$word p=0
  while [[ $tail =~ $rex ]]; do
    local rematch1=${BASH_REMATCH[1]}
    ble/array#push out "$rematch1"
    ble/array#push out "${BASH_REMATCH:${#rematch1}}"
    tail=${tail:${#BASH_REMATCH}}
  done
  ble/array#push out "$tail"
  ret=("${out[@]}")
  return 0
}

#------------------------------------------------------------------------------

function ble/syntax:bash/initialize-ctx {
  ctx=$_ble_ctx_CMDX # _ble_ctx_CMDX is the first context in ble/syntax:bash
}

## @fn ble/syntax:bash/initialize-vars
##   @var[in,out] _ble_syntax_bash_histc12
##   @var[in,out] _ble_syntax_bash_histstop
function ble/syntax:bash/initialize-vars {
  # About the interpretation of the shell variable histchars
  #
  # - The first character [default value !] indicates the start of history expansion.
  #   This also applies to ! contained in event specifiers.
  #   However, if the first character of histchars already has a different meaning ([-#?0-9^$%*]),
  #   It seems that those are given priority.
  # - The second character [default value ^] indicates the start of history expansion (replacement).
  #   ^aaa^bbb^ becomes =aaa=bbb=.
  # - The third character [default #] is .bash_history
  #   Used as a delimiter when outputting times.
  #   It doesn't matter here.
  #
  local histc12
  if [[ ${histchars+set} ]]; then
    histc12=${histchars::2}
  else
    histc12='!^'
  fi
  _ble_syntax_bash_histc12=$histc12

  if ble/syntax:bash/cclass/update; then
    ble/syntax:bash/simple-word/update
  fi

  local histstop=$' \t\n='
  shopt -q extglob && histstop="$histstop("
  _ble_syntax_bash_histstop=$histstop
}


#------------------------------------------------------------------------------
# Common lexical match determination

function ble/variable#load-user-state/.print-global-state {
  # This function is a callback for "ble/util/for-global-variables"
  local __ble_set= __ble_val= __ble_att=
  if [[ :$2: == *:unset:* ]]; then
    # This branch is selected when the global variable is hidden by a local
    # readonly variable and its state cannot be accesed.  In this case, so that
    # the default variable highlighting is chosen, we pretend that a scalar
    # variable is set to be a non-empty value.
    __ble_set=unknown
    __ble_val=unknown
    __ble_att=
  else
    __ble_set=${!1+set}
    __ble_val=${!1-}
    ble/variable#get-attr -v __ble_att "$1"

    # Note: We remove the readonly attribute "r" because
    # "ble/util/for-global-variables" uses the readonly attribute to access the
    # global variable so we cannot correctly test the readonly attribute.
    # Anyway, since we know that the global variable is hidden by a local
    # variable, it is natural to consider the global variable is not readonly
    # because a global readonly variable cannot be hidden by a local variable.
    # An exceptional case is the case where the global variable is made
    # readonly using "declare -gr" after it is hidden by a local variable.
    __ble_att=${__ble_att//r}
  fi
  declare -p __ble_set __ble_val __ble_att
}

## @fn ble/variable#load-user-state
##   @var[out] __ble_var_set __ble_var_val __ble_var_att
function ble/variable#load-user-state {
  __ble_var_set= __ble_var_val= __ble_var_att=
  [[ $1 == __ble_* || $1 == _ble_local_* ]] && return 0
  ble/function#try ble/variable#load-user-state/variable:"$1" && return 0

  # special parameters
  if [[ $1 == '?' ]]; then
    __ble_var_set=set
    __ble_var_val=$_ble_edit_exec_lastexit
    __ble_var_att=
    return 0
  elif ble/string#match "$1" '^[1-9][0-9]*$'; then
    # positional parameters
    local __ble_name=$1
    if [[ ${_ble_edit_exec_lastparams[0]+set} ]]; then
      set -- "${_ble_edit_exec_lastparams[@]}"
    else
      set --
    fi
    __ble_var_set=${!__ble_name+set}
    __ble_var_val=${!__ble_name-}
    __ble_var_att=
    return 0
  fi

  # Extract global state. When we support this, we should also consider it in
  # the custom loader ble/variable#load-user-state/variable:"$1".
  if [[ :$2: == *:global:* ]] && ! ble/variable#is-global "$1"; then
    local _ble_highlight_vartype_name=$1
    local __ble_var_state
    ble/util/assign __ble_var_state 'ble/util/for-global-variables ble/variable#load-user-state/.print-global-state "" "$_ble_highlight_vartype_name"'
    if [[ $__ble_var_state ]]; then
      local __ble_set __ble_val __ble_att
      builtin eval -- "$__ble_var_state"
      __ble_var_set=$__ble_set
      __ble_var_val=$__ble_val
      __ble_var_att=$__ble_att
      return 0
    fi
  fi

  __ble_var_set=${!1+set}
  __ble_var_val=${!1-}
  ble/variable#get-attr -v __ble_var_att "$1"
}

## @fn ble/syntax/highlight/vartype varname [opts [tail]]
##   Determine the attribute value according to the type and status of the variable.
##
##   @param[in] varname
##     Specify the variable name to be judged.
##   @param[in,opt] opts
##     Specify options separated by colons.
##
##     readvar ... for a variable that does not exist and "set -u" is specified in the user context
##         Apply error coloring to
##
##     global ... Refers to the status of global variables.
##
##     no-readonly ... Ignore readonly state.
##
##   @param[in,opt] tail
##     Specifies the string that follows the variable name when parsing the inside of the ${var...} format.
##
##   @var[out] ret
##     Returns the attribute value.
##
##   @var[out,opt] lookahead
##     Set only when tail is specified. tail referenced when determining attribute values
##     Returns the number of lookahead characters in.
##
function ble/syntax/highlight/vartype {
  ret=$_ble_attr_VAR
  [[ $bleopt_highlight_variable ]] || return 0

  local __ble_name=$1 __ble_opts=${2-} __ble_tail=${3-}

  local __ble_var_set __ble_var_val __ble_var_att
  ble/variable#load-user-state "$__ble_name" "$__ble_opts"

  if [[ $__ble_var_set || $__ble_var_att == *[aA]* ]]; then
    if [[ $__ble_var_val && :$__ble_opts: == *:expr:* ]] && ! ble/string#match "$__ble_var_val" '^-?[0-9]+(#[_a-zA-Z0-9@]*)?$'; then
      ret=$_ble_attr_VAR_EXPR
    elif [[ $__ble_var_set && $__ble_var_att == *x* ]]; then
      # Note: For arrays, only when the 0th element is set.
      ret=$_ble_attr_VAR_EXPORT
    elif [[ $__ble_var_att == *a* ]]; then
      ret=$_ble_attr_VAR_ARRAY
    elif [[ $__ble_var_att == *A* ]]; then
      ret=$_ble_attr_VAR_HASH
    elif [[ $__ble_var_att == *r* ]]; then
      ret=$_ble_attr_VAR_READONLY
    elif [[ $__ble_var_att == *i* ]]; then
      ret=$_ble_attr_VAR_NUMBER
    elif [[ $__ble_var_att == *[luc]* ]]; then
      ret=$_ble_attr_VAR_TRANSFORM
    elif [[ ! $__ble_var_val ]]; then
      [[ $__ble_tail == :* ]] && lookahead=2
      if [[ $__ble_tail == ':?'* ]]; then
        ret=$_ble_attr_ERR
      else
        ret=$_ble_attr_VAR_EMPTY
      fi
    else
      ret=$_ble_attr_VAR
    fi
  else
    if [[ :$__ble_opts: == *:newvar:* ]]; then
      # assignments var=, var+=
      ret=$_ble_attr_VAR_NEW
      return 0
    elif
      [[ $__ble_tail == :* ]] && lookahead=2
      [[ $__ble_tail == ':?'* || $__ble_tail == '?'* ]]
    then
      ret=$_ble_attr_ERR
      return 0
    fi

    # Checking set -u
    if [[ :$__ble_opts: == *:readvar:* && $_ble_bash_set == *u* ]]; then
      if [[ ! $__ble_tail ]] || {
           [[ $__ble_tail == :* ]] && lookahead=2
           ! ble/string#match "$__ble_tail" '^:?[-+?=]'; }
      then
        ret=$_ble_attr_ERR
        return 0
      fi
    fi

    ret=$_ble_attr_VAR_UNSET
  fi
  return 0
}

function ble/syntax:bash/check-plain-with-escape {
  local rex='^('$1'|\\.)' is_quote=$2
  [[ $tail =~ $rex ]] || return 1
  if [[ $BASH_REMATCH == '\'? &&
          ( ! $is_quote || $BASH_REMATCH == '\'[$'\\`$\n"'] ) ]]; then
    ((_ble_syntax_attr[i]=_ble_attr_QESC))
  else
    ((_ble_syntax_attr[i]=ctx))
  fi
  ((i+=${#BASH_REMATCH}))
  return 0
}

function ble/syntax:bash/check-dollar {
  [[ $tail == '$'* ]] || return 1

  local rex
  if [[ $tail == '${'* ]]; then
    # Note: What is allowed in parameter expansion:
    #   It may switch to a fixed pattern + mathematical formula or character string midway through.
    # Note: Try the character count ${#param} form first (set lookahead even if it fails).
    # Then try the ${param...} and ${!param...} forms.
    #   This determines whether # in ${#...} is the number of characters or $#.
    local rex1='^(\$\{#)([-*@#?$!0]\}?|[1-9][0-9]*\}?|[_a-zA-Z][_a-zA-Z0-9]*[[}]?)'
    local rex2='^(\$\{!?)([-*@#?$!0]|[1-9][0-9]*|[_a-zA-Z][_a-zA-Z0-9]*\[?)'
    if
      [[ $tail =~ $rex1 ]] && {
        [[ ${BASH_REMATCH[2]} == *['[}'] || $BASH_REMATCH == "$tail" ]] ||
          { ble/syntax/parse/set-lookahead "$((${#BASH_REMATCH}+1))"; builtin false; } } ||
        [[ $tail =~ $rex2 ]]
    then
      # <parameter> = [-*@#?-$!0] | [1-9][0-9]* | <varname> | <varname> [ ... ] | <varname> [ <@> ]
      # <@> = * | @
      # ${<parameter>} ${#<parameter>} ${!<parameter>}
      # ${<parameter>:-<word>} ${<parameter>:=<word>} ${<parameter>:+<word>} ${<parameter>:?<word>}
      # ${<parameter>-<word>} ${<parameter>=<word>} ${<parameter>+<word>} ${<parameter>?<word>}
      # ${<parameter>:expr} ${<parameter>:expr:expr} etc
      # ${!head<@>} ${!varname[<@>]}

      # for bash-3.1 ${#arr[n]} bug
      local rematch1=${BASH_REMATCH[1]}
      local rematch2=${BASH_REMATCH[2]}
      local varname=${rematch2%['[}']}

      local ntype='${'
      if ((ctx==_ble_ctx_QUOT)); then
        ntype='"${'
      elif ((ctx==_ble_ctx_PWORD||ctx==_ble_ctx_PWORDE||ctx==_ble_ctx_PWORDR||ctx==_ble_ctx_EXPR)); then
        local ntype2; ble/syntax/parse/nest-type -v ntype2
        [[ $ntype2 == '"${' ]] && ntype='"${'
      fi

      local ret lookahead= tail2=${tail:${#rematch1}+${#varname}}
      ble/syntax/highlight/vartype "$varname" readvar:global "$tail2"; local attr=$ret

      ble/syntax/parse/nest-push "$_ble_ctx_PARAM" "$ntype"
      ((_ble_syntax_attr[i]=ctx,
        i+=${#rematch1},
        _ble_syntax_attr[i]=attr,
        i+=${#varname}))
      [[ $lookahead ]] && ble/syntax/parse/set-lookahead "$lookahead"

      if rex='^\$\{![_a-zA-Z][_a-zA-Z0-9]*[*@]\}?'; [[ $tail =~ $rex ]]; then
        ble/syntax/parse/set-lookahead 2
        if [[ $BASH_REMATCH == *'}' ]]; then
          # When ${!head<@>}, the trailing @* is read individually.
          ((i++,ctx=_ble_ctx_PWORDE))
        fi
      elif [[ $rematch2 == *'[' ]]; then
        ble/syntax/parse/nest-push "$_ble_ctx_EXPR" 'v['
        ((_ble_syntax_attr[i++]=_ble_ctx_EXPR))
      fi
      return 0
    elif ((_ble_bash>=50300)) && [[ $tail == '${'[$' \t\n|']* ]]; then
      ((_ble_syntax_attr[i]=_ble_ctx_PARAM))
      ble/syntax/parse/nest-push "$_ble_ctx_CMDX" 'cmdsub_nofork'
      ((i+=2))
      [[ $tail == '${|'* ]] && ((i++))
      return 0
    else
      ((_ble_syntax_attr[i]=_ble_attr_ERR,i+=2))
      return 0
    fi
  elif [[ $tail == '$(('* ]]; then
    ((_ble_syntax_attr[i]=_ble_ctx_PARAM))
    ble/syntax/parse/nest-push "$_ble_ctx_EXPR" '$(('
    ((i+=3))
    return 0
  elif [[ $tail == '$['* ]]; then
    ((_ble_syntax_attr[i]=_ble_ctx_PARAM))
    ble/syntax/parse/nest-push "$_ble_ctx_EXPR" '$['
    ((i+=2))
    return 0
  elif [[ $tail == '$('* ]]; then
    ((_ble_syntax_attr[i]=_ble_ctx_PARAM))
    ble/syntax/parse/nest-push "$_ble_ctx_CMDX" '$('
    ((i+=2))
    return 0
  elif rex='^\$([-*@#?$!0_]|[1-9]|[_a-zA-Z][_a-zA-Z0-9]*)' && [[ $tail =~ $rex ]]; then
    local rematch=$BASH_REMATCH rematch1=${BASH_REMATCH[1]}
    ((_ble_syntax_attr[i++]=_ble_ctx_PARAM))

    if ((_ble_bash<40200)) && local tail=${tail:1} &&
         ble/syntax:bash/starts-with-histchars && ble/syntax:bash/check-history-expansion; then
      # In bash-4.1 and below, $!", $!a, etc. are subject to history expansion.
      return 0
    else
      local ret; ble/syntax/highlight/vartype "$rematch1" readvar:global
      ((_ble_syntax_attr[i]=ret,i+=${#rematch}-1))
      return 0
    fi
  else
    # if dollar doesn't match any patterns it is treated as a normal character
    ((_ble_syntax_attr[i++]=ctx))
    return 0
  fi
}

function ble/syntax:bash/check-quotes {
  local rex aqdel=$_ble_attr_QDEL aquot=$_ble_ctx_QUOT

  # Interpreted lexically but not removed
  if ((ctx==_ble_ctx_EXPR)) && [[ $tail != \`* ]]; then
    local ntype
    ble/syntax/parse/nest-type
    case $ntype in
    ('${')
      # Any quotes inside ${var:...} are not removed (interpreted lexically).
      # A quote that is not removed is an arithmetic error. Note: "..." in bash >= 5.2
      # and $"..." are allowed.
      if ((_ble_bash<50200)) || [[ $tail == \'* || $tail == \$\'* ]]; then
        ((aqdel=_ble_attr_ERR,aquot=_ble_ctx_EXPR))
      fi ;;
    ('$['|'$(('|expr-paren-ax)
      if [[ $tail == \'* ]] || ((_ble_bash<40400)); then
        ((aqdel=_ble_attr_ERR,aquot=_ble_ctx_EXPR))
      fi ;;
    ('(('|expr-paren|expr-brack)
      if [[ $tail == \'* ]] && ((_ble_bash>=50100)); then
        ((aqdel=_ble_attr_ERR,aquot=_ble_ctx_EXPR))
      fi ;;
    ('a['|'v['|expr-paren-ai|expr-brack-ai)
      if [[ $tail == \'* ]] && ((_ble_bash>=40400)); then
        ((aqdel=_ble_attr_ERR,aquot=_ble_ctx_EXPR))
      fi ;;
    ('"${')
      if ! { [[ $tail == '$'[\'\"]* ]] && shopt -q extquote; }; then
        # In "${var:...}", 〈$'' $""〉 when extquote is set is used as an example.
        # ``quote'' is not removed (interpreted lexically).
        ((aqdel=_ble_attr_ERR,aquot=_ble_ctx_EXPR))
      fi ;;
    # ('d['|expr-paren-di|expr-brack-di) ;; # nop
    esac
  elif ((ctx==_ble_ctx_PWORD||ctx==_ble_ctx_PWORDE||ctx==_ble_ctx_PWORDR)); then
    # $'' $"" in "${var ~}" is not removed when ! shopt -q extquote.
    if [[ $tail == '$'[\'\"]* ]] && ! shopt -q extquote; then
      local ntype
      ble/syntax/parse/nest-type
      if [[ $ntype == '"${' ]]; then
        ((aqdel=ctx,aquot=ctx))
      fi
    fi
  fi

  if rex='^`([^`\]|\\(.|$))*(`?)|^'\''[^'\'']*('\''?)' && [[ $tail =~ $rex ]]; then
    ((_ble_syntax_attr[i]=aqdel,
      _ble_syntax_attr[i+1]=aquot,
      i+=${#BASH_REMATCH},
      _ble_syntax_attr[i-1]=${#BASH_REMATCH[3]}||${#BASH_REMATCH[4]}?aqdel:_ble_attr_ERR))
    return 0
  fi

  if ((ctx!=_ble_ctx_QUOT)); then
    if rex='^(\$?")([^'"${_ble_syntax_bash_chars[_ble_ctx_QUOT]}"']*)("?)' && [[ $tail =~ $rex ]]; then
      local rematch1=${BASH_REMATCH[1]} # for bash-3.1 ${#arr[n]} bug
      if [[ ${BASH_REMATCH[3]} ]]; then
        # If you reach the end
        ((_ble_syntax_attr[i]=aqdel,
          _ble_syntax_attr[i+${#rematch1}]=aquot,
          i+=${#BASH_REMATCH},
          _ble_syntax_attr[i-1]=aqdel))
      else
        # If there is a structure inside
        ble/syntax/parse/nest-push "$_ble_ctx_QUOT"
        if (((ctx==_ble_ctx_PWORD||ctx==_ble_ctx_PWORDE||ctx==_ble_ctx_PWORDR)&&aqdel!=_ble_attr_QDEL)); then
          # For contexts where quote removal is not enabled for _ble_ctx_PWORD (parameter expansion),
          # Only ``$'' is colored with aqdel, and ``...'' is colored normally.
          ((_ble_syntax_attr[i]=aqdel,
            _ble_syntax_attr[i+${#rematch1}-1]=_ble_attr_QDEL,
            _ble_syntax_attr[i+${#rematch1}]=_ble_ctx_QUOT,
            i+=${#BASH_REMATCH}))
        else
          ((_ble_syntax_attr[i]=aqdel,
            _ble_syntax_attr[i+${#rematch1}]=_ble_ctx_QUOT,
            i+=${#BASH_REMATCH}))
        fi
      fi
      return 0
    elif rex='^\$'\''(([^'\''\]|\\(.|$))*)('\''?)' && [[ $tail =~ $rex ]]; then
      ((_ble_syntax_attr[i]=aqdel,i+=2))
      local t=${BASH_REMATCH[1]} rematch4=${BASH_REMATCH[4]}

      local rex='\\[abefnrtvE"'\''\?]|\\[0-7]{1,3}|\\c.|\\x[0-9a-fA-F]{1,2}'
      ((_ble_bash>=40200)) && rex=$rex'|\\u[0-9a-fA-F]{1,4}|\\U[0-9a-fA-F]{1,8}'
      local rex='^([^'\''\]*)('$rex'|(\\.))'
      while [[ $t =~ $rex ]]; do
        local m1=${BASH_REMATCH[1]} m2=${BASH_REMATCH[2]}
        [[ $m1 ]] && ((_ble_syntax_attr[i]=aquot,i+=${#m1}))
        if [[ ${BASH_REMATCH[3]} ]]; then
          ((_ble_syntax_attr[i]=aquot))
        else
          ((_ble_syntax_attr[i]=_ble_attr_QESC))
        fi
        ((i+=${#m2}))
        t=${t:${#BASH_REMATCH}}
      done
      [[ $t ]] && ((_ble_syntax_attr[i]=aquot,i+=${#t}))
      if [[ $rematch4 ]]; then
        ((_ble_syntax_attr[i++]=aqdel))
      else
        ((_ble_syntax_attr[i-1]=_ble_attr_ERR))
      fi
      return 0
    fi
  fi

  return 1
}

function ble/syntax:bash/check-process-subst {
  # process replacement
  if [[ $tail == ['<>']'('* ]]; then
    ble/syntax/parse/nest-push "$_ble_ctx_CMDX" '('
    ((_ble_syntax_attr[i]=_ble_attr_DEL,i+=2))
    return 0
  fi

  return 1
}

function ble/syntax:bash/check-comment {
  # Comment
  if shopt -q interactive_comments; then
    if ((wbegin<0||wbegin==i)) && local rex=$'^#[^\n]*' && [[ $tail =~ $rex ]]; then
      # Just like blank spaces, ctx passes through unchanged (leaving the trailing newline)
      ((_ble_syntax_attr[i]=_ble_attr_COMMENT,
        i+=${#BASH_REMATCH}))
      return 0
    fi
  fi

  return 1
}

function ble/syntax:bash/check-glob {
  [[ $tail == ['[?*@+!()|']* ]] || return 1

  local ntype= force_attr=
  if ((ctx==_ble_ctx_VRHS||ctx==_ble_ctx_ARGVR||ctx==_ble_ctx_ARGER||ctx==_ble_ctx_VALR||ctx==_ble_ctx_RDRS)); then
    force_attr=$ctx
    ntype="glob_attr=$force_attr"
  elif ((ctx==_ble_ctx_FARGX1||ctx==_ble_ctx_FARGI1)); then
    # for [xxx] / for a[xxx]
    force_attr=$_ble_attr_ERR
    ntype="glob_attr=$force_attr"
  elif ((ctx==_ble_ctx_PWORD||ctx==_ble_ctx_PWORDE||ctx==_ble_ctx_PWORDR)); then
    ntype="glob_ctx=$ctx"
  elif ((ctx==_ble_ctx_PATN||ctx==_ble_ctx_BRAX)); then
    ble/syntax/parse/nest-type
    local exit_attr=
    if [[ $ntype == glob_attr=* ]]; then
      force_attr=${ntype#*=}
      exit_attr=$force_attr
    elif ((ctx==_ble_ctx_BRAX)); then
      force_attr=$ctx
      ntype="glob_attr=$force_attr"
    elif ((ctx==_ble_ctx_PATN)); then
      ((exit_attr=_ble_syntax_attr[inest]))

      # When glob_ctx=*, ntype is inherited by children
      [[ $ntype != glob_ctx=* ]] && ntype=
    else
      ntype=
    fi
  elif [[ $1 == assign ]]; then
    # When $1 == assign, it means that it was called at the "[" position of arr[....
    ntype='a['
  fi

  if [[ $tail == ['?*@+!']'('* ]] && shopt -q extglob; then
    ble/syntax/parse/nest-push "$_ble_ctx_PATN" "$ntype"
    ((_ble_syntax_attr[i]=${force_attr:-_ble_attr_GLOB},i+=2))
    return 0
  fi

  # The historical expansion interpretation is stronger.
  local histc1=${_ble_syntax_bash_histc12::1}
  [[ $histc1 && $tail == "$histc1"* ]] && return 1

  if [[ $tail == '['* ]]; then
    if ((ctx==_ble_ctx_BRAX)); then
      # [ or [! in the square bracket expression can be skipped as is.
      ((_ble_syntax_attr[i++]=force_attr))
      [[ $tail == '[!'* ]] && ((i++))
      return 0
    fi

    ble/syntax/parse/nest-push "$_ble_ctx_BRAX" "$ntype"
    ((_ble_syntax_attr[i++]=${force_attr:-_ble_attr_GLOB}))
    [[ $tail == '[!'* ]] && ((i++))
    if [[ ${text:i:1} == ']' ]]; then
      ((_ble_syntax_attr[i++]=${force_attr:-_ble_ctx_BRAX}))
    elif [[ ${text:i:1} == '[' ]]; then
      # Note: To convert to the conditional command [[, read the [[ series at once.
      if [[ ${text:i+1:1} == [:=.] ]]; then
        # Note: When glob bracket expression starts with POSIX brackets,
        # It would be a problem if [[ were grouped together, so I excluded it.
        ble/syntax/parse/set-lookahead 2
      else
        ((_ble_syntax_attr[i++]=${force_attr:-_ble_ctx_BRAX}))
        [[ ${text:i:1} == '!'* ]] && ((i++))
      fi
    fi

    return 0
  elif [[ $tail == ['?*']* ]]; then
    ((_ble_syntax_attr[i++]=${force_attr:-_ble_attr_GLOB}))
    return 0
  elif [[ $tail == ['@+!']* ]]; then
    ((_ble_syntax_attr[i++]=${force_attr:-ctx}))
    return 0
  elif ((ctx==_ble_ctx_PATN||ctx==_ble_ctx_BRAX)); then
    if [[ $tail == '('* ]]; then
      ble/syntax/parse/nest-push "$_ble_ctx_PATN" "$ntype"
      ((_ble_syntax_attr[i++]=${force_attr:-ctx}))
      return 0
    elif [[ $tail == ')'* ]]; then
      if ((ctx==_ble_ctx_PATN)); then
        ((_ble_syntax_attr[i++]=exit_attr))
        ble/syntax/parse/nest-pop
      else
        ((_ble_syntax_attr[i++]=${force_attr:-ctx}))
      fi
      return 0
    elif [[ $tail == '|'* ]]; then
      ((_ble_syntax_attr[i++]=${force_attr:-_ble_attr_GLOB}))
      return 0
    fi
  fi

  return 1
}

_ble_syntax_bash_histexpand_RexWord=
_ble_syntax_bash_histexpand_RexMods=
_ble_syntax_bash_histexpand_RexEventDef=
_ble_syntax_bash_histexpand_RexQuicksubDef=
_ble_syntax_bash_histexpand_RexEventFmt=
_ble_syntax_bash_histexpand_RexQuicksubFmt=
function ble/syntax:bash/check-history-expansion/.initialize {
  local spaces=$_ble_term_IFS nl=$'\n'
  local rex_event='-?[0-9]+|[!#]|[^-$^*%:'$spaces'=?!#;&|<>()]+|\?[^?'$nl']*\??'
  _ble_syntax_bash_histexpand_RexEventDef='^!('$rex_event')'

  local rex_word1='([0-9]+|[$%^])'
  local rex_wordsA=':('$rex_word1'?-'$rex_word1'?|\*|'$rex_word1'\*?)'
  local rex_wordsB='([$%^]?-'$rex_word1'?|\*|[$^%][*-]?)'
  _ble_syntax_bash_histexpand_RexWord='('$rex_wordsA'|'$rex_wordsB')?'

  # *I actually want it to be /s(.)([^\]|\\.)*?\1([^\]|\\.)*?\1/, but *? is not in ERE.
  #   I have no choice so ble/syntax:bash/check-history-expansion/.check-modifiers
  #   Read s?..?..? by repeatedly applying the regular expression.
  local rex_modifier=':[htrepqx]|:[gGa]?&|:[gGa]?s(/([^\/]|\\.)*){0,2}(/|$)'
  _ble_syntax_bash_histexpand_RexMods='('$rex_modifier')*'

  _ble_syntax_bash_histexpand_RexQuicksubDef='\^([^^\]|\\.)*\^([^^\]|\\.)*\^'

  # for histchars
  _ble_syntax_bash_histexpand_RexQuicksubFmt='@A([^@C\]|\\.)*@A([^@C\]|\\.)*@A'
  _ble_syntax_bash_histexpand_RexEventFmt='^@A('$rex_event'|@A)'
}
ble/syntax:bash/check-history-expansion/.initialize

## @fn ble/syntax:bash/check-history-expansion/.initialize-event
##   @var[out] rex_event
function ble/syntax:bash/check-history-expansion/.initialize-event {
  local histc1=${_ble_syntax_bash_histc12::1}
  if [[ $histc1 == '!' ]]; then
    rex_event=$_ble_syntax_bash_histexpand_RexEventDef
  else
    local A="[$histc1]"
    [[ $histc1 == '^' ]] && A='\^'
    rex_event=$_ble_syntax_bash_histexpand_RexEventFmt
    rex_event=${rex_event//@A/"$A"}
  fi
}
## @fn ble/syntax:bash/check-history-expansion/.initialize-quicksub
##   @var[out] rex_quicksub
function ble/syntax:bash/check-history-expansion/.initialize-quicksub {
  local histc2=${_ble_syntax_bash_histc12:1:1}
  if [[ $histc2 == '^' ]]; then
    rex_quicksub=$_ble_syntax_bash_histexpand_RexQuicksubDef
  else
    rex_quicksub=$_ble_syntax_bash_histexpand_RexQuicksubFmt
    rex_quicksub=${rex_quicksub//@A/"[$histc2]"}
    rex_quicksub=${rex_quicksub//@C/"$histc2"}
  fi
}
function ble/syntax:bash/check-history-expansion/.check-modifiers {
  # check simple modifiers
  [[ ${text:i} =~ $_ble_syntax_bash_histexpand_RexMods ]] &&
    ((i+=${#BASH_REMATCH}))

  # check :s?..?..? form modifier
  if local rex='^:[gGa]?s(.)'; [[ ${text:i} =~ $rex ]]; then
    local del=${BASH_REMATCH[1]}
    local A="[$del]" B="[^$del]"
    [[ $del == '^' || $del == ']' ]] && A='\'$del
    [[ $del != '\' ]] && B=$B'|\\.'

    local rex_substitute='^:[gGa]?s('$A'('$B')*){0,2}('$A'|$)'
    if [[ ${text:i} =~ $rex_substitute ]]; then
      ((i+=${#BASH_REMATCH}))
      ble/syntax:bash/check-history-expansion/.check-modifiers
      return 0
    fi
  fi

  # ErrMsg 'unrecognized modifier'
  if [[ ${text:i} == ':'[gGa]* ]]; then
    ((_ble_syntax_attr[i+1]=_ble_attr_ERR,i+=2))
  elif [[ ${text:i} == ':'* ]]; then
    ((_ble_syntax_attr[i]=_ble_attr_ERR,i++))
  fi
}
## @fn ble/syntax:bash/check-history-expansion
##   @var[in] i tail
function ble/syntax:bash/check-history-expansion {
  [[ -o histexpand ]] || return 1

  local histc1=${_ble_syntax_bash_histc12:0:1}
  local histc2=${_ble_syntax_bash_histc12:1:1}
  if [[ $histc1 && $tail == "$histc1"[^"$_ble_syntax_bash_histstop"]* ]]; then

    # "～" Limits the range of possible matches within the string.
    if ((_ble_bash>=40300&&ctx==_ble_ctx_QUOT)); then
      local tail=${tail%%'"'*}
      [[ $tail == '!' ]] && return 1
    fi

    ((_ble_syntax_attr[i]=_ble_attr_HISTX))
    local rex_event
    ble/syntax:bash/check-history-expansion/.initialize-event
    if [[ $tail =~ $rex_event ]]; then
      ((i+=${#BASH_REMATCH}))
    elif [[ $tail == "$histc1"['-:0-9^$%*']* ]]; then
      ((_ble_syntax_attr[i]=_ble_attr_HISTX,i++))
    else
      # ErrMsg 'unrecognized event'
      ((_ble_syntax_attr[i+1]=_ble_attr_ERR,i+=2))
      return 0
    fi

    # word-designator
    [[ ${text:i} =~ $_ble_syntax_bash_histexpand_RexWord ]] &&
      ((i+=${#BASH_REMATCH}))

    ble/syntax:bash/check-history-expansion/.check-modifiers
    return 0
  elif ((i==0)) && [[ $histc2 && $tail == "$histc2"* ]]; then
    ((_ble_syntax_attr[i]=_ble_attr_HISTX))
    local rex_quicksub
    ble/syntax:bash/check-history-expansion/.initialize-quicksub
    if [[ $tail =~ $rex_quicksub ]]; then
      ((i+=${#BASH_REMATCH}))

      ble/syntax:bash/check-history-expansion/.check-modifiers
      return 0
    else
      # to the end
      ((i+=${#tail}))
      return 0
    fi
  fi

  return 1
}
## @fn ble/syntax:bash/starts-with-histchars
##   @var[in] tail
function ble/syntax:bash/starts-with-histchars {
  [[ $_ble_syntax_bash_histc12 && $tail == ["$_ble_syntax_bash_histc12"]* ]]
}

#------------------------------------------------------------------------------
# Context: Various contexts

_ble_syntax_context_proc[_ble_ctx_QUOT]=ble/syntax:bash/ctx-quot
function ble/syntax:bash/ctx-quot {
  # Contents of string
  if ble/syntax:bash/check-plain-with-escape "[^${_ble_syntax_bash_chars[_ble_ctx_QUOT]}]+" 1; then
    return 0
  elif [[ $tail == '"'* ]]; then
    ((_ble_syntax_attr[i]=_ble_attr_QDEL,
      i+=1))
    ble/syntax/parse/nest-pop
    return 0
  elif ble/syntax:bash/check-quotes; then
    return 0
  elif ble/syntax:bash/check-dollar; then
    return 0
  elif ble/syntax:bash/starts-with-histchars; then
    ble/syntax:bash/check-history-expansion ||
      ((_ble_syntax_attr[i]=ctx,i++))
    return 0
  fi

  return 1
}

_ble_syntax_context_proc[_ble_ctx_CASE]=ble/syntax:bash/ctx-case
function ble/syntax:bash/ctx-case {
  if [[ $tail =~ ^$_ble_syntax_bash_RexIFSs ]]; then
    ((_ble_syntax_attr[i]=ctx,i+=${#BASH_REMATCH}))
    return 0
  elif [[ $tail == '('* ]]; then
    ((_ble_syntax_attr[i++]=_ble_attr_GLOB,ctx=_ble_ctx_CPATX))
    return 0
  elif [[ $tail == 'esac'$_ble_syntax_bash_RexDelimiter* || $tail == 'esac' ]]; then
    ((ctx=_ble_ctx_CMDX))
    ble/syntax:bash/ctx-command
  else
    ((ctx=_ble_ctx_CPATX))
    ble/syntax:bash/ctx-command-case-pattern-expect
  fi
}

# Context _ble_ctx_PATN (extglob/case-pattern)
_ble_syntax_context_proc[_ble_ctx_PATN]=ble/syntax:bash/ctx-globpat
_ble_syntax_context_end[_ble_ctx_PATN]=ble/syntax:bash/ctx-globpat.end

## @fn ble/syntax:bash/ctx-globpat/get-stop-chars
##   @var[out] chars
function ble/syntax:bash/ctx-globpat/get-stop-chars {
  chars=${_ble_syntax_bash_chars[_ble_ctx_PATN]}
  local ntype; ble/syntax/parse/nest-type
  if [[ $ntype == glob_ctx=* ]]; then
    local gctx=${ntype#glob_ctx=}
    if ((gctx==_ble_ctx_PWORD||gctx==_ble_ctx_PWORDE)); then
      chars=}$chars
    elif ((gctx==_ble_ctx_PWORDR)); then
      chars=}/$chars
    fi
  fi
}
function ble/syntax:bash/ctx-globpat {
  # Contents of glob () (in extglob @(...) and case in (...))
  local chars; ble/syntax:bash/ctx-globpat/get-stop-chars
  if ble/syntax:bash/check-plain-with-escape "[^$chars]+"; then
    return 0
  elif ble/syntax:bash/check-process-subst; then
    return 0
  elif [[ $tail == ['<>']* ]]; then
    ((_ble_syntax_attr[i++]=ctx))
    return 0
  elif ble/syntax:bash/check-quotes; then
    return 0
  elif ble/syntax:bash/check-dollar; then
    return 0
  elif ble/syntax:bash/check-glob; then
    return 0
  elif ble/syntax:bash/check-brace-expansion; then
    return 0
  elif ble/syntax:bash/starts-with-histchars; then
    ble/syntax:bash/check-history-expansion ||
      ((_ble_syntax_attr[i]=ctx,i++))
    return 0
  fi

  return 1
}
function ble/syntax:bash/ctx-globpat.end {
  local is_end= tail=${text:i}
  local ntype; ble/syntax/parse/nest-type
  if [[ $ntype == glob_ctx=* ]]; then
    local gctx=${ntype#glob_ctx=}
    if ((gctx==_ble_ctx_PWORD||gctx==_ble_ctx_PWORDE)); then
      [[ ! $tail || $tail == '}'* ]] && is_end=1
    elif ((gctx==_ble_ctx_PWORDR)); then
      [[ ! $tail || $tail == ['/}']* ]] && is_end=1
    fi
  fi

  if [[ $is_end ]]; then
    ble/syntax/parse/nest-pop
    ble/syntax/parse/check-end
    return 0
  fi

  return 0
}

# Context _ble_ctx_BRAX (bracket expression)
_ble_syntax_context_proc[_ble_ctx_BRAX]=ble/syntax:bash/ctx-bracket-expression
_ble_syntax_context_end[_ble_ctx_BRAX]=ble/syntax:bash/ctx-bracket-expression.end
function ble/syntax:bash/ctx-bracket-expression {
  local nctx; ble/syntax/parse/nest-ctx
  if ((nctx==_ble_ctx_PATN)); then
    local chars; ble/syntax:bash/ctx-globpat/get-stop-chars
  elif ((nctx==_ble_ctx_PWORD||nctx==_ble_ctx_PWORDE||nctx==_ble_ctx_PWORDR)); then
    local chars=${_ble_syntax_bash_chars[nctx]}
  else
    # In the following contexts, there is no problem with the same processing as ctx-command.
    #
    #   ctx-command (various)
    #   ctx-redirect (_ble_ctx_RDRF _ble_ctx_RDRD _ble_ctx_RDRD2 _ble_ctx_RDRS)
    #   ctx-values (_ble_ctx_VALI, _ble_ctx_VALR, _ble_ctx_VALQ)
    #   ctx-conditions (_ble_ctx_CONDI, _ble_ctx_CONDQ)
    #     The exception in this context is that some operators such as && || < > delimiters
    #     is allowed in words, but this exception does not apply to words containing [...].
    #
    # When is-delimiters, [... is incompletely terminated there.
    local chars=${_ble_syntax_bash_chars[_ble_ctx_ARGI]//'~'}
  fi
  chars="][${chars#']'}"

  local ntype; ble/syntax/parse/nest-type
  local force_attr=; [[ $ntype == glob_attr=* ]] && force_attr=${ntype#*=}

  local rex
  if [[ $tail == ']'* ]]; then
    ((_ble_syntax_attr[i++]=${force_attr:-_ble_attr_GLOB}))
    ble/syntax/parse/nest-pop

    # When the normal argument has the form of an array assignment, tilde expansion is effective thereafter.
    # Example: echo arr[i]=... arr[i]+=...
    if [[ $ntype == 'a[' ]]; then
      local is_assign=
      if [[ $tail == ']='* ]]; then
        ((_ble_syntax_attr[i++]=ctx,is_assign=1))
      elif [[ $tail == ']+'* ]]; then
        ble/syntax/parse/set-lookahead 2
        [[ $tail == ']+='* ]] && ((_ble_syntax_attr[i]=ctx,i+=2,is_assign=1))
      fi

      if [[ $is_assign ]]; then
        ble/util/assert '[[ ${_ble_syntax_bash_command_CtxAssign[ctx]} ]]'
        ((ctx=_ble_syntax_bash_command_CtxAssign[ctx]))
        if local tail=${text:i}; [[ $tail == '~'* ]]; then
          ble/syntax:bash/check-tilde-expansion rhs
        fi
      fi
    fi
    return 0
  elif [[ $tail == '['* ]]; then
    rex='^\[@([^'$chars']+(@\]?)?)?'
    rex=${rex//@/:}'|'${rex//@/'\.'}'|'${rex//@/=}'|^\['
    [[ $tail =~ $rex ]]
    ((_ble_syntax_attr[i]=${force_attr:-ctx},
      i+=${#BASH_REMATCH}))
    return 0
  elif ctx=${force_attr:-$ctx} ble/syntax:bash/check-plain-with-escape "[^$chars]+"; then
    return 0
  elif ble/syntax:bash/check-process-subst; then
    return 0
  elif ble/syntax:bash/check-quotes; then
    return 0
  elif ble/syntax:bash/check-dollar; then
    return 0
  elif ble/syntax:bash/check-glob; then
    return 0
  elif ble/syntax:bash/check-brace-expansion; then
    return 0
  elif ble/syntax:bash/check-tilde-expansion; then
    return 0
  elif ble/syntax:bash/starts-with-histchars; then
    ble/syntax:bash/check-history-expansion ||
      ((_ble_syntax_attr[i++]=${force_attr:-ctx}))
    return 0
  elif ((nctx==_ble_ctx_PATN)) && [[ $tail == ['<>']* ]]; then
    ((_ble_syntax_attr[i++]=${force_attr:-ctx}))
    return 0
  fi

  return 1
}
function ble/syntax:bash/ctx-bracket-expression.end {
  local is_end=

  local tail=${text:i}
  if [[ ! $tail ]]; then
    is_end=1
  else
    local nctx; ble/syntax/parse/nest-ctx
    local external_ctx=$nctx
    if ((nctx==_ble_ctx_PATN)); then
      local ntype; ble/syntax/parse/nest-type
      [[ $ntype == glob_ctx=* ]] &&
        external_ctx=${ntype#glob_ctx=}
    fi

    if ((external_ctx==_ble_ctx_PATN)); then
      [[ $tail == ')'* ]] && is_end=1
    elif ((external_ctx==_ble_ctx_PWORD||external_ctx==_ble_ctx_PWORDE)); then
      [[ $tail == '}'* ]] && is_end=1
    elif ((external_ctx==_ble_ctx_PWORDR)); then
      [[ $tail == ['}/']* ]] && is_end=1
    else
      # Outside is ctx-command etc.
      if ble/syntax:bash/check-word-end/is-delimiter; then
        is_end=1
      elif [[ $tail == ':'* && ${_ble_syntax_bash_command_IsAssign[ctx]} ]]; then
        is_end=1
      fi
    fi
  fi

  if [[ $is_end ]]; then
    ble/syntax/parse/nest-pop
    ble/syntax/parse/check-end
    return "$?"
  fi

  return 0
}

_ble_syntax_context_proc[_ble_ctx_PARAM]=ble/syntax:bash/ctx-param
_ble_syntax_context_proc[_ble_ctx_PWORD]=ble/syntax:bash/ctx-pword
_ble_syntax_context_proc[_ble_ctx_PWORDR]=ble/syntax:bash/ctx-pword
_ble_syntax_context_proc[_ble_ctx_PWORDE]=ble/syntax:bash/ctx-pword-error
function ble/syntax:bash/ctx-param {
  # Parameter expansion - immediately after the parameter
  if [[ $tail == '}'* ]]; then
    ((_ble_syntax_attr[i]=_ble_syntax_attr[inest]))
    ((i+=1))
    ble/syntax/parse/nest-pop
    return 0
  fi

  local rex='##?|%%?|:?[-?=+]|:|/[/#%]?'
  ((_ble_bash>=40000)) && rex=$rex'|,,?|\^\^?|~~?'
  if ((_ble_bash>=50200)); then
    rex=$rex'|@[QEPAaUuLKk]?'
  elif ((_ble_bash>=50100)); then
    rex=$rex'|@[QEPAaUuLK]?'
  elif ((_ble_bash>=40400)); then
    rex=$rex'|@[QEPAa]?'
  fi
  rex='^('$rex')'
  if [[ $tail =~ $rex ]]; then
    ((_ble_syntax_attr[i]=_ble_ctx_PARAM,
      i+=${#BASH_REMATCH}))
    if [[ $BASH_REMATCH == '/'* ]]; then
      ((ctx=_ble_ctx_PWORDR))
    elif [[ $BASH_REMATCH == : ]]; then
      ((ctx=_ble_ctx_EXPR,_ble_syntax_attr[i-1]=_ble_ctx_EXPR))
    elif [[ $BASH_REMATCH == @* ]]; then
      ((ctx=_ble_ctx_PWORDE))
    else
      ((ctx=_ble_ctx_PWORD))
      [[ $BASH_REMATCH == [':-+=?#%']* ]] &&
        tail=${text:i} ble/syntax:bash/check-tilde-expansion pword
    fi
    return 0
  else
    local i0=$i
    ((ctx=_ble_ctx_PWORD))
    ble/syntax:bash/ctx-pword || return 1

    # Error coloring of only one character
    if ((i0+2<=i)); then
      ((_ble_syntax_attr[i0+1])) ||
        ((_ble_syntax_attr[i0+1]=_ble_syntax_attr[i0]))
    fi
    ((_ble_syntax_attr[i0]=_ble_attr_ERR))
    return 0
  fi
}
function ble/syntax:bash/ctx-pword {
  # Parameter expansion - word part
  if ble/syntax:bash/check-plain-with-escape "[^${_ble_syntax_bash_chars[ctx]}]+"; then
    return 0
  elif ((ctx==_ble_ctx_PWORDR)) && [[ $tail == '/'* ]]; then
    ((_ble_syntax_attr[i++]=_ble_ctx_PARAM,ctx=_ble_ctx_PWORD))
    return 0
  elif [[ $tail == '}'* ]]; then
    ((_ble_syntax_attr[i]=_ble_syntax_attr[inest]))
    ((i+=1))
    ble/syntax/parse/nest-pop
    return 0
  elif ble/syntax:bash/check-quotes; then
    return 0
  elif ble/syntax:bash/check-dollar; then
    return 0
  elif ble/syntax:bash/check-glob; then
    return 0
  elif ble/syntax:bash/starts-with-histchars; then
    ble/syntax:bash/check-history-expansion ||
      ((_ble_syntax_attr[i]=ctx,i++))
    return 0
  fi

  return 1
}
function ble/syntax:bash/ctx-pword-error {
  local i0=$i
  if ble/syntax:bash/ctx-pword; then
    [[ $tail == '}'* ]] ||
      ((_ble_syntax_attr[i0]=_ble_attr_ERR))
    return 0
  else
    return 1
  fi
}

## @const _ble_ctx_EXPR
##   Context value of an arithmetic expression
##
##   List of supported nest types (ntype)
##
##   NTYPE             NEST-PUSH LOCATION       QUOTE  DESC
##   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
##   '$((' @ check-dollar x arithmetic expression expansion $(()) contents
##   '$[' @ check-dollar x arithmetic expression expansion $[] contents
## '((' @ .check-delimiter-or-redirect o Contents of arithmetic expression evaluation command (())
##   'a[' @ check-variable-assignment o contents of a[...]=
##   'd[' @ ctx-values o contents of a=([...]=)
##   'v[' @ check-dollar o contents of ${a[...]}
##   '${' @ check-dollar o Contents of ${v:...}
##   '"${' @ check-dollar x Contents of "${v:...}"
##   Nesting with 'expr-paren' @ .count-paren o () (quote removal enabled)
##   'expr-paren-ax' @ .count-paren + () nesting / $(( inside $[
##   'expr-paren-ai' @ .count-paren + () nesting / inside a[ v[ (unused)
##   'expr-paren-di' @ .count-paren o () nesting / inside d[ (unused)
##   Nesting with 'expr-brack' @ .count-bracket o [] (quote removal always enabled) (unused)
##   'expr-brack-ai' @ .count-bracket + nesting with [] / $(( inside $[ a[ v[ [
##   'expr-brack-di' @ .count-bracket nesting with o [] / inside d[
##
##   '$('            @ check-dollar                 o  $(command)
##   'cmdsub_nofork' @ check-dollar                 o  ${ command; }
##   'cmd_brace'     @ ctx-command/check-word-end   o  { command; }
##
##   QUOTE = o ... quote removal is enabled internally
##   QUOTE = x ... quote removal is disabled internally
##
_ble_syntax_context_proc[_ble_ctx_EXPR]=ble/syntax:bash/ctx-expr
## @fn ble/syntax:bash/ctx-expr/.count-paren
##   Count the number of parentheses () in an arithmetic expression.
##   @var ntype Specifies the nesting type of the current arithmetic expression.
##   @var char Specifies the parenthesis character.
function ble/syntax:bash/ctx-expr/.count-paren {
  if [[ $char == ')' ]]; then
    if [[ $ntype == '((' || $ntype == '$((' ]]; then
      if [[ $tail == '))'* ]]; then
        ((_ble_syntax_attr[i]=_ble_syntax_attr[inest]))
        ((i+=2))
        ble/syntax/parse/nest-pop
      else
        # such as ((echo) > /dev/null) or $((echo) > /dev/null)
        # Consider this to be a confusing subshell command substitution.
        # I had no choice but to leave the parts that I had thought were arithmetic expressions as is.
        ((ctx=_ble_ctx_ARGX0,
          _ble_syntax_attr[i++]=_ble_syntax_attr[inest]))
      fi
      return 0
    elif [[ $ntype == expr-paren* ]]; then
      ((_ble_syntax_attr[i++]=ctx))
      ble/syntax/parse/nest-pop
      return 0
    fi
  elif [[ $char == '(' ]]; then
    # determine nested ntype
    local ntype2=
    case $ntype in
    ('((')
      ntype2=expr-paren ;;
    ('$((')
      ntype2=expr-paren-ax ;;
    (expr-paren|expr-paren-ax|expr-paren-ai|expr-paren-di)
      ntype2=$ntype ;;
    ('$['|'a['|'v['|'d['|expr-brack|expr-brack-ai|expr-brack-di|'${'|'"${'|*)
      ble/util/assert-fail "unexpected ntype='$ntype' here" ;;
    esac

    ble/syntax/parse/nest-push "$_ble_ctx_EXPR" "$ntype2"
    ((_ble_syntax_attr[i++]=ctx))
    return 0
  fi

  return 1
}
## @fn ble/syntax:bash/ctx-expr/.count-bracket
##   Count the number of parentheses [] in an arithmetic expression.
##   @var ntype Specifies the nesting type of the current arithmetic expression.
##   @var char Specifies the parenthesis character.
function ble/syntax:bash/ctx-expr/.count-bracket {
  if [[ $char == ']' ]]; then
    if [[ $ntype == expr-brack* || $ntype == '$[' ]]; then
      # Cases such as arithmetic expansion $[...] and nesting ((a[...]=123)).
      ((_ble_syntax_attr[i]=_ble_syntax_attr[inest]))
      ((i++))
      ble/syntax/parse/nest-pop
      return 0
    elif [[ $ntype == [ad]'[' ]]; then
      ((_ble_syntax_attr[i++]=_ble_ctx_EXPR))
      ble/syntax/parse/nest-pop
      if [[ $tail == ']='* ]]; then
        # If a[...]=, a=([...]=)
        ((i++))
        tail=${text:i} ble/syntax:bash/check-tilde-expansion rhs
      elif ((_ble_bash>=30100)) && [[ $tail == ']+'* ]]; then
        ble/syntax/parse/set-lookahead 2
        if [[ $tail == ']+='* ]]; then
          # a[...]+=, a+=([...]+=)
          ((i+=2))
          tail=${text:i} ble/syntax:bash/check-tilde-expansion rhs
        fi
      else
        if [[ $ntype == 'a[' ]]; then
          # For the only command a[...]...
          if ((ctx==_ble_ctx_VRHS)); then
            # Example: arr[123]aaa
            ((ctx=_ble_ctx_CMDI,wtype=_ble_ctx_CMDI))
          elif ((ctx==_ble_ctx_ARGVR)); then
            # Example: declare arr[123]aaa
            ((ctx=_ble_ctx_ARGVI,wtype=_ble_ctx_ARGVI))
          elif ((ctx==_ble_ctx_ARGER)); then
            # Example: eval arr[123]aaa
            ((ctx=_ble_ctx_ARGEI,wtype=_ble_ctx_ARGEI))
          fi
        else # ntype == 'd['
          # For the only value '[...]...'.
          ((ctx=_ble_ctx_VALI,wtype=_ble_ctx_VALI))
        fi
      fi
      return 0
    elif [[ $ntype == 'v[' ]]; then
      # For example ${v[]...}.
      ((_ble_syntax_attr[i++]=_ble_ctx_EXPR))
      ble/syntax/parse/nest-pop
      return 0
    fi
  elif [[ $char == '[' ]]; then
    local ntype2=
    case $ntype in
    ('$['|'a['|'v[')
      ntype2=expr-brack-ai ;;
    ('d[')
      ntype2=expr-brack-di ;;
    (expr-brack|expr-brack-ai|expr-brack-di)
      ntype2=$ntype ;;
    ('(('|'$(('|expr-paren|expr-paren-ax|expr-paren-ai|expr-paren-di|'${'|'"${'|*)
      ble/util/assert-fail "unexpected ntype='$ntype' here" ;;
    esac
    ble/syntax/parse/nest-push "$_ble_ctx_EXPR" "$ntype2"
    ((_ble_syntax_attr[i++]=ctx))
    return 0
  fi

  return 1
}
## @fn ble/syntax:bash/ctx-expr/.count-brace
##   When a closing brace '}' appears in an arithmetic expression, the arithmetic expression is exited.
##   @var ntype Specifies the nesting type of the current arithmetic expression.
##   @var char Specifies the parenthesis character.
function ble/syntax:bash/ctx-expr/.count-brace {
  if [[ $char == '}' ]]; then
    ((_ble_syntax_attr[i]=_ble_syntax_attr[inest]))
    ((i++))
    ble/syntax/parse/nest-pop
    return 0
  fi

  return 1
}
## @fn ble/syntax:bash/ctx-expr/.check-plain-with-escape rex is_quote
##   @var[in] ntype
function ble/syntax:bash/ctx-expr/.check-plain-with-escape {
  local i0=$i
  ble/syntax:bash/check-plain-with-escape "$@" || return 1

  if [[ $tail == '\'* ]]; then
    case $ntype in
    ('$(('|'$['|expr-paren-ax|'${'|'"${')
      _ble_syntax_attr[i0]=$_ble_attr_ERR ;;
    ('(('|expr-paren|expr-brack)
      if ((_ble_bash>=50100)); then
        _ble_syntax_attr[i0]=$_ble_attr_ERR
      fi ;;
    ('a['|'v['|expr-paren-ai|expr-brack-ai)
      if ((_ble_bash>=40400)); then
        _ble_syntax_attr[i0]=$_ble_attr_ERR
      fi ;;
    # ('d['|expr-paren-di|expr-brack-di) ;; # \ is always OK inside d[ (designated init)
    esac
  fi

  return 0
}

function ble/syntax:bash/ctx-expr {
  # Contents of the expression
  local rex
  if rex='^[_a-zA-Z][_a-zA-Z0-9]*'; [[ $tail =~ $rex ]]; then
    local rematch=$BASH_REMATCH
    local ret; ble/syntax/highlight/vartype "$BASH_REMATCH" readvar:expr:global
    ((_ble_syntax_attr[i]=ret,i+=${#rematch}))
    return 0
  elif rex='^0[xX][0-9a-fA-F]*|^[0-9]+(#[_a-zA-Z0-9@]*)?'; [[ $tail =~ $rex ]]; then
    ((_ble_syntax_attr[i]=_ble_attr_VAR_NUMBER,i+=${#BASH_REMATCH}))
    return 0
  fi

  local ntype
  ble/syntax/parse/nest-type
  if ble/syntax:bash/ctx-expr/.check-plain-with-escape "[^${_ble_syntax_bash_chars[ctx]}_a-zA-Z0-9]+" 1; then
    return 0
  elif [[ $tail == ['][()}']* ]]; then
    local char=${tail::1}
    if [[ $ntype == *'(' || $ntype == expr-paren* ]]; then
      # ntype = '(('            # ((...))
      #       = '$(('           # $((...))
      #       = 'expr-paren' # (..) in expression
      #       = 'expr-paren-ax' # $(( (..) in $[
      #       = 'expr-paren-ai' # a[ v[ inside (..)
      #       = 'expr-paren-di' # d[ inside (..)
      ble/syntax:bash/ctx-expr/.count-paren && return 0
    elif [[ $ntype == *'[' || $ntype == expr-brack* ]]; then
      # ntype = 'a['             # a[...]=
      #       = 'v['             # ${a[...]}
      #       = 'd['             # a=([...]=)
      #       = '$['             # $[...]
      #       = 'expr-brack' # [...] in expression
      #       = 'expr-brack-ai' # $(( [...] in $[ a[ v[
      #       = 'expr-brack-di' # [...] in d[
      ble/syntax:bash/ctx-expr/.count-bracket && return 0
    elif [[ $ntype == '${' || $ntype == '"${' ]]; then
      # ntype = '${'  # ${var:offset:length}
      #       = '"${' # "${var:offset:length}"
      ble/syntax:bash/ctx-expr/.count-brace && return 0
    else
      ble/util/assert-fail "unexpected ntype=$ntype for arithmetic expression"
    fi

    # Characters that are not nested are treated as normal characters.
    ((_ble_syntax_attr[i++]=ctx))
    return 0
  elif ble/syntax:bash/check-quotes; then
    return 0
  elif ble/syntax:bash/check-dollar; then
    return 0
  elif ble/syntax:bash/starts-with-histchars; then
    # The frightening thing is that history expansion is effective even in mathematical formulas...
    ble/syntax:bash/check-history-expansion ||
      ((_ble_syntax_attr[i]=ctx,i++))
    return 0
  fi

  return 1
}

#------------------------------------------------------------------------------
# Brace expansion

## When _ble_ctx_CONDI and _ble_ctx_RDRS, it behaves as inactive brace expansion.
## For _ble_ctx_RDRF, _ble_ctx_RDRD, and _ble_ctx_RDRD2, brace expansion that expands into multiple words is an error.
## Perform nest-push, analyze it, and set an error when it is determined that it is a brace expansion.

function ble/syntax:bash/check-brace-expansion {
  [[ $tail == '{'* ]] || return 1

  local rex='^\{[-+a-zA-Z0-9.]*(\}?)'
  [[ $tail =~ $rex ]]
  local str=$BASH_REMATCH

  local force_attr= inactive=

  # Completely inert in certain contexts
  # Note: {fd}> In line with the redirect read-ahead,
  #   Even if it is inactive, it must be read all at once.
  #   cf ble/syntax:bash/starts-with-delimiter-or-redirect
  if [[ $- != *B* ]]; then
    inactive=1
  elif ((ctx==_ble_ctx_CONDI||ctx==_ble_ctx_CONDQ||ctx==_ble_ctx_RDRS||ctx==_ble_ctx_VRHS)); then
    inactive=1
  elif ((_ble_bash>=50300&&ctx==_ble_ctx_VALR)); then
    # Brace expansions such as arr=([9]={1..10}) are inactive in bash-5.3 and later.
    inactive=1
  elif ((ctx==_ble_ctx_PATN||ctx==_ble_ctx_BRAX)); then
    local ntype; ble/syntax/parse/nest-type
    if [[ $ntype == glob_attr=* ]]; then
      force_attr=${ntype#*=}
      (((force_attr==_ble_ctx_RDRS||force_attr==_ble_ctx_VRHS||force_attr==_ble_ctx_ARGVR||force_attr==_ble_ctx_ARGER||force_attr==_ble_ctx_VALR)&&(inactive=1)))
    elif ((ctx==_ble_ctx_BRAX)); then
      local nctx; ble/syntax/parse/nest-ctx
      (((nctx==_ble_ctx_CONDI||octx==_ble_ctx_CONDQ)&&(inactive=1)))
    fi
  elif ((ctx==_ble_ctx_BRACE1||ctx==_ble_ctx_BRACE2)); then
    local ntype; ble/syntax/parse/nest-type
    if [[ $ntype == glob_attr=* ]]; then
      force_attr=${ntype#*=}
    fi
  fi

  if [[ $inactive ]]; then
    ((_ble_syntax_attr[i]=${force_attr:-ctx},i+=${#str}))
    return 0
  fi

  # Tilde expansion is disabled when brace expansion is present.
  # Note: When it is _ble_ctx_VRHS etc., it is inactive so it does not come here, so it is OK
  [[ ${_ble_syntax_bash_command_IsAssign[ctx]} ]] &&
    ctx=${_ble_syntax_bash_command_IsAssign[ctx]}

  # Brace expansion of the form {a..b..c}
  if rex='^\{(([-+]?[0-9]+)\.\.[-+]?[0-9]+|[a-zA-Z]\.\.[a-zA-Z])(\.\.[-+]?[0-9]+)?\}$'; [[ $str =~ $rex ]]; then
    if [[ $force_attr ]]; then
      ((_ble_syntax_attr[i]=force_attr,i+=${#str}))
    else
      local rematch1=${BASH_REMATCH[1]}
      local rematch2=${BASH_REMATCH[2]}
      local rematch3=${BASH_REMATCH[3]}
      local len2=${#rematch2}; ((len2||(len2=1)))
      local attr=$_ble_attr_BRACE
      if ((ctx==_ble_ctx_RDRF||ctx==_ble_ctx_RDRD||ctx==_ble_ctx_RDRD2)); then
        # Error when expanded to multiple words with redirect
        local lhs=${rematch1::len2} rhs=${rematch1:len2+2}
        if [[ $rematch2 ]]; then
          local lhs1=$((10#0${lhs#[-+]})); [[ $lhs == -* ]] && ((lhs1=-lhs1))
          local rhs1=$((10#0${rhs#[-+]})); [[ $rhs == -* ]] && ((rhs1=-rhs1))
          lhs=$lhs1 rhs=$rhs1
        fi
        [[ $lhs != "$rhs" ]] && ((attr=_ble_attr_ERR))
      fi

      ((_ble_syntax_attr[i++]=attr))
      ((_ble_syntax_attr[i]=ctx,i+=len2,
        _ble_syntax_attr[i]=_ble_attr_BRACE,i+=2,
        _ble_syntax_attr[i]=ctx,i+=${#rematch1}-len2-2))
      if [[ $rematch3 ]]; then
        ((_ble_syntax_attr[i]=_ble_attr_BRACE,i+=2,
          _ble_syntax_attr[i]=ctx,i+=${#rematch3}-2))
      fi
      ((_ble_syntax_attr[i++]=attr))
    fi

    return 0
  fi

  # Other than that
  # Note: {aa},bb} is interpreted as {"aa}","bb"}, so
  #   Here, nest-push is performed regardless of the presence or absence of the terminating "}".
  local ntype=
  ((ctx==_ble_ctx_RDRF||ctx==_ble_ctx_RDRD||ctx==_ble_ctx_RDRD2)) && force_attr=$ctx
  [[ $force_attr ]] && ntype="glob_attr=$force_attr"
  ble/syntax/parse/nest-push "$_ble_ctx_BRACE1" "$ntype"
  local len=$((${#str}-1))
  ((_ble_syntax_attr[i++]=${force_attr:-_ble_attr_BRACE},
    len&&(_ble_syntax_attr[i]=${force_attr:-ctx},i+=len)))

  return 0
}

# Context _ble_ctx_BRAX (brace expansion)
_ble_syntax_context_proc[_ble_ctx_BRACE1]=ble/syntax:bash/ctx-brace-expansion
_ble_syntax_context_proc[_ble_ctx_BRACE2]=ble/syntax:bash/ctx-brace-expansion
_ble_syntax_context_end[_ble_ctx_BRACE1]=ble/syntax:bash/ctx-brace-expansion.end
_ble_syntax_context_end[_ble_ctx_BRACE2]=ble/syntax:bash/ctx-brace-expansion.end
function ble/syntax:bash/ctx-brace-expansion {
  if [[ $tail == '}'* ]] && ((ctx==_ble_ctx_BRACE2)); then
    local force_attr=
    local ntype; ble/syntax/parse/nest-type
    [[ $ntype == glob_attr=* ]] && force_attr=$_ble_attr_ERR # *Error instead of ${ntype#*=}

    ((_ble_syntax_attr[i++]=${force_attr:-_ble_attr_BRACE}))
    ble/syntax/parse/nest-pop
    return 0
  elif [[ $tail == ','* ]]; then
    local force_attr=
    local ntype; ble/syntax/parse/nest-type
    [[ $ntype == glob_attr=* ]] && force_attr=${ntype#*=}

    ((_ble_syntax_attr[i++]=${force_attr:-_ble_attr_BRACE}))
    ((ctx=_ble_ctx_BRACE2))
    return 0
  fi

  local chars=",${_ble_syntax_bash_chars[_ble_ctx_ARGI]//'~:'}"
  ((ctx==_ble_ctx_BRACE2)) && chars="}$chars"
  ble/syntax:bash/cclass/update/reorder chars
  if ble/syntax:bash/check-plain-with-escape "[^$chars]+"; then
    return 0
  elif ble/syntax:bash/check-process-subst; then
    return 0
  elif ble/syntax:bash/check-quotes; then
    return 0
  elif ble/syntax:bash/check-dollar; then
    return 0
  elif ble/syntax:bash/check-glob; then
    return 0
  elif ble/syntax:bash/check-brace-expansion; then
    return 0
  elif ble/syntax:bash/starts-with-histchars; then
    ble/syntax:bash/check-history-expansion ||
      ((_ble_syntax_attr[i++]=ctx))
    return 0
  fi

  return 1
}
function ble/syntax:bash/ctx-brace-expansion.end {
  if ((i==${#text})) || ble/syntax:bash/check-word-end/is-delimiter; then
    ble/syntax/parse/nest-pop
    ble/syntax/parse/check-end
    return "$?"
  fi

  return 0
}

#------------------------------------------------------------------------------
# tilde expansion

# Reading by ${_ble_syntax_bash_chars[_ble_ctx_ARGI]}
# It is assumed to be called from ctx-command ctx-values ctx-conditions ctx-redirect.

## @fn ble/syntax:bash/check-tilde-expansion
##   Detect and handle tilde expansion.
##   ~ at the beginning of a word, or :~ in the middle of a word in variable assignment format, or
##   Processes ~ at the beginning of word during parameter expansion.
function ble/syntax:bash/check-tilde-expansion {
  [[ $tail == ['~:']* ]] || return 1

  # @var rhs_enabled
  #   Whether tilde expansion is valid on the right side of the context of variable assignment format. set -o posix only
  #   Valid only in contexts where
  local rhs_enabled=
  { ((ctx==_ble_ctx_VRHS||ctx==_ble_ctx_ARGVR||ctx==_ble_ctx_VALR||ctx==_ble_ctx_ARGER)) ||
      ! ble/base/is-POSIXLY_CORRECT; } && rhs_enabled=1

  local tilde_enabled=$((i==wbegin||ctx==_ble_ctx_PWORD))
  [[ $1 == rhs && $rhs_enabled ]] && tilde_enabled=1 # Immediately after =

  if [[ $tail == ':'* ]]; then
    _ble_syntax_attr[i++]=$ctx

    # Tilde expansion is valid for the right-hand side of variable assignment or the square bracket expression immediately below it.
    if [[ $rhs_enabled ]]; then
      if ! ((tilde_enabled=_ble_syntax_bash_command_IsAssign[ctx])); then
        if ((ctx==_ble_ctx_BRAX)); then
          local nctx; ble/syntax/parse/nest-ctx
          ((tilde_enabled=_ble_syntax_bash_command_IsAssign[nctx]))
        fi
      fi
    fi

    local tail=${text:i}
    [[ $tail == '~'* ]] || return 0
  fi

  if ((tilde_enabled)); then
    local chars="${_ble_syntax_bash_chars[_ble_ctx_ARGI]}/:"
    # Note: When using pword, you also want to exclude delimiters.
    #   instead of _ble_syntax_bash_chars[_ble_ctx_PWORD]
    #   Modify and use _ble_syntax_bash_chars[_ble_ctx_ARGI].
    ((ctx==_ble_ctx_PWORD)) && chars=${chars/'{'/'{}'}

    ble/syntax:bash/cclass/update/reorder chars
    local delimiters="$_ble_term_IFS;|&)<>"
    local rex='^(~\+|~[^'$chars']*)([^'$delimiters'/:]?)'; [[ $tail =~ $rex ]]
    local str=${BASH_REMATCH[1]}

    local path attr=$ctx
    builtin eval "path=$str"
    if [[ ! ${BASH_REMATCH[2]} && $path != "$str" ]]; then
      ((attr=_ble_attr_TILDE))

      if ((ctx==_ble_ctx_BRAX)); then
        # _ble_ctx_BRAX does not come at the beginning of the word, so
        # It should come here only when [[ $tail == ':~'* ]].
        # In this case, each parenthesis expression is canceled immediately after :.
        ble/util/assert 'ble/util/unlocal tail; [[ $tail == ":~"* ]]'
        ble/syntax/parse/nest-pop
      fi
    else
      # When starting with ~+ and not a valid tilde expansion, backtrack to ~ (#D1424)
      if [[ $str == '~+' ]]; then
        ble/syntax/parse/set-lookahead 3
        str='~'
      fi
    fi
    ((_ble_syntax_attr[i]=attr,i+=${#str}))
  else
    ((_ble_syntax_attr[i]=ctx,i++)) # skip tilde
    local chars=${_ble_syntax_bash_chars[_ble_ctx_ARGI]}
    ble/syntax:bash/check-plain-with-escape "[^$chars]+" # Add (OK even if it fails)
  fi

  return 0
}

#------------------------------------------------------------------------------
# Words in the form of variable assignments
#
#   In fact, even if it is a normal argument, it is handled slightly differently if it is in the form of variable assignment.
#   Tilde expansion is valid on the right side of arguments in variable assignment format.
#

# Context value that switches context when in variable assignment format. Variable assignment form even if it is not actually a variable assignment
# It is necessary to distinguish when tilde expansion by an expression is valid.
_ble_syntax_bash_command_CtxAssign[_ble_ctx_CMDI]=$_ble_ctx_VRHS
_ble_syntax_bash_command_CtxAssign[_ble_ctx_COARGI]=$_ble_ctx_VRHS
_ble_syntax_bash_command_CtxAssign[_ble_ctx_ARGVI]=$_ble_ctx_ARGVR
_ble_syntax_bash_command_CtxAssign[_ble_ctx_ARGEI]=$_ble_ctx_ARGER
_ble_syntax_bash_command_CtxAssign[_ble_ctx_ARGI]=$_ble_ctx_ARGQ
_ble_syntax_bash_command_CtxAssign[_ble_ctx_FARGI3]=$_ble_ctx_FARGQ3
_ble_syntax_bash_command_CtxAssign[_ble_ctx_CARGI1]=$_ble_ctx_CARGQ1
_ble_syntax_bash_command_CtxAssign[_ble_ctx_CPATI]=$_ble_ctx_CPATQ
_ble_syntax_bash_command_CtxAssign[_ble_ctx_VALI]=$_ble_ctx_VALQ
_ble_syntax_bash_command_CtxAssign[_ble_ctx_CONDI]=$_ble_ctx_CONDQ

# The following array is used to switch from a context in which tilde expansion is enabled to a context in which it is disabled.
_ble_syntax_bash_command_IsAssign[_ble_ctx_VRHS]=$_ble_ctx_CMDI
_ble_syntax_bash_command_IsAssign[_ble_ctx_ARGVR]=$_ble_ctx_ARGVI
_ble_syntax_bash_command_IsAssign[_ble_ctx_ARGER]=$_ble_ctx_ARGEI
_ble_syntax_bash_command_IsAssign[_ble_ctx_ARGQ]=$_ble_ctx_ARGI
_ble_syntax_bash_command_IsAssign[_ble_ctx_FARGQ3]=$_ble_ctx_FARGI3
_ble_syntax_bash_command_IsAssign[_ble_ctx_CARGQ1]=$_ble_ctx_CARGI1
_ble_syntax_bash_command_IsAssign[_ble_ctx_CPATQ]=$_ble_ctx_CPATI
_ble_syntax_bash_command_IsAssign[_ble_ctx_VALR]=$_ble_ctx_VALI
_ble_syntax_bash_command_IsAssign[_ble_ctx_VALQ]=$_ble_ctx_VALI
_ble_syntax_bash_command_IsAssign[_ble_ctx_CONDQ]=$_ble_ctx_CONDI

## @fn ble/syntax:bash/check-variable-assignment
## @var[in] tail
function ble/syntax:bash/check-variable-assignment {
  ((wbegin==i)) || return 1

  # Words of the form [0]=value in value lists are treated specially.
  if ((ctx==_ble_ctx_VALI)) && [[ $tail == '['* ]]; then
    ((ctx=_ble_ctx_VALR))
    ble/syntax/parse/nest-push "$_ble_ctx_EXPR" 'd['
    # → Exit with ble/syntax:bash/ctx-expr/.count-bracket
    ((_ble_syntax_attr[i++]=ctx))
    return 0
  fi

  [[ ${_ble_syntax_bash_command_CtxAssign[ctx]} ]] || return 1

  # Pattern match (var= any of var+= arr[)
  local suffix='[=[]'
  ((_ble_bash>=30100)) && suffix=$suffix'|\+=?'
  local rex_assign="^([_a-zA-Z][_a-zA-Z0-9]*)($suffix)"
  [[ $tail =~ $rex_assign ]] || return 1
  local rematch=$BASH_REMATCH
  local rematch1=${BASH_REMATCH[1]} # for bash-3.1 ${#arr[n]} bug
  local rematch2=${BASH_REMATCH[2]} # for bash-3.1 ${#arr[n]} bug
  if [[ $rematch2 == '+' ]]; then
    # var+... ambiguous state

    # Note: It comes here when the next character after + is not =, so
    # This means that the character following the + is read ahead.
    ble/syntax/parse/set-lookahead "$((${#rematch}+1))"

    return 1
  fi

  local variable_assign=
  if ((ctx==_ble_ctx_CMDI||ctx==_ble_ctx_ARGVI||ctx==_ble_ctx_ARGEI&&${#rematch2})); then
    # When assigning variables, ctx is first converted to _ble_ctx_VRHS, _ble_ctx_ARGVR
    local ret; ble/syntax/highlight/vartype "$rematch1" newvar:global
    ((wtype=_ble_attr_VAR,
      _ble_syntax_attr[i]=ret,
      i+=${#rematch},
      ${#rematch2}&&(_ble_syntax_attr[i-${#rematch2}]=_ble_ctx_EXPR),
      variable_assign=1,
      ctx=_ble_syntax_bash_command_CtxAssign[ctx]))
  else
    # In cases other than variable assignments, convert to _ble_ctx_ARGQ etc. only when = appears.
    ((_ble_syntax_attr[i]=ctx,
      i+=${#rematch}))
  fi

  if [[ $rematch2 == '[' ]]; then
    # arr[
    if [[ $variable_assign ]]; then
      i=$((i-1)) ble/syntax/parse/nest-push "$_ble_ctx_EXPR" 'a['
      # → Exit with ble/syntax:bash/ctx-expr/.count-bracket
    else
      ((i--))
      tail=${text:i} ble/syntax:bash/check-glob assign
      # → nest-push "$_ble_ctx_BRAX" 'a[' in ble/syntax:bash/check-glob and
      # → If = is present after exiting with ble/syntax:bash/ctx-bracket-expression, set context value
    fi
  elif [[ $rematch2 == *'=' ]]; then
    if [[ $variable_assign && ${text:i} == '('* ]]; then
      # var=( var+=(
      # * Immediately after nest-pop, it is still a continuation of _ble_ctx_VRHS and _ble_ctx_ARGVR.
      #   Example: a=(1 2)b=1 is interpreted as a='(1 2)b=1'.
      #   Therefore, leave ctx (context at nest-pop) as is (_ble_ctx_VRHS, _ble_ctx_ARGVR).

      ble/syntax:bash/ctx-values/enter
      ((_ble_syntax_attr[i++]=_ble_attr_DEL))
    else
      # var=... var+=...
      [[ $variable_assign ]] || ((ctx=_ble_syntax_bash_command_CtxAssign[ctx]))
      if local tail=${text:i}; [[ $tail == '~'* ]]; then
        ble/syntax:bash/check-tilde-expansion rhs
      fi
    fi
  fi

  return 0
}

#------------------------------------------------------------------------------
# Context: command line

_ble_syntax_context_proc[_ble_ctx_ARGX]=ble/syntax:bash/ctx-command
_ble_syntax_context_proc[_ble_ctx_ARGX0]=ble/syntax:bash/ctx-command
_ble_syntax_context_proc[_ble_ctx_CMDX]=ble/syntax:bash/ctx-command
_ble_syntax_context_proc[_ble_ctx_CMDX0]=ble/syntax:bash/ctx-command
_ble_syntax_context_proc[_ble_ctx_CMDX1]=ble/syntax:bash/ctx-command
_ble_syntax_context_proc[_ble_ctx_CMDXT]=ble/syntax:bash/ctx-command
_ble_syntax_context_proc[_ble_ctx_CMDXC]=ble/syntax:bash/ctx-command
_ble_syntax_context_proc[_ble_ctx_CMDXE]=ble/syntax:bash/ctx-command
_ble_syntax_context_proc[_ble_ctx_CMDXD]=ble/syntax:bash/ctx-command
_ble_syntax_context_proc[_ble_ctx_CMDXD0]=ble/syntax:bash/ctx-command
_ble_syntax_context_proc[_ble_ctx_CMDXV]=ble/syntax:bash/ctx-command
_ble_syntax_context_proc[_ble_ctx_ARGI]=ble/syntax:bash/ctx-command
_ble_syntax_context_proc[_ble_ctx_ARGQ]=ble/syntax:bash/ctx-command
_ble_syntax_context_proc[_ble_ctx_CMDI]=ble/syntax:bash/ctx-command
_ble_syntax_context_proc[_ble_ctx_VRHS]=ble/syntax:bash/ctx-command
_ble_syntax_context_proc[_ble_ctx_ARGVR]=ble/syntax:bash/ctx-command
_ble_syntax_context_proc[_ble_ctx_ARGER]=ble/syntax:bash/ctx-command
_ble_syntax_context_end[_ble_ctx_CMDI]=ble/syntax:bash/ctx-command/check-word-end
_ble_syntax_context_end[_ble_ctx_ARGI]=ble/syntax:bash/ctx-command/check-word-end
_ble_syntax_context_end[_ble_ctx_ARGQ]=ble/syntax:bash/ctx-command/check-word-end
_ble_syntax_context_end[_ble_ctx_VRHS]=ble/syntax:bash/ctx-command/check-word-end
_ble_syntax_context_end[_ble_ctx_ARGVR]=ble/syntax:bash/ctx-command/check-word-end
_ble_syntax_context_end[_ble_ctx_ARGER]=ble/syntax:bash/ctx-command/check-word-end

# declare var=value / eval var=value
_ble_syntax_context_proc[_ble_ctx_ARGVX]=ble/syntax:bash/ctx-command
_ble_syntax_context_proc[_ble_ctx_ARGVI]=ble/syntax:bash/ctx-command
_ble_syntax_context_end[_ble_ctx_ARGVI]=ble/syntax:bash/ctx-command/check-word-end
_ble_syntax_context_proc[_ble_ctx_ARGEX]=ble/syntax:bash/ctx-command
_ble_syntax_context_proc[_ble_ctx_ARGEI]=ble/syntax:bash/ctx-command
_ble_syntax_context_end[_ble_ctx_ARGEI]=ble/syntax:bash/ctx-command/check-word-end

# for var in ... / case arg in
_ble_syntax_context_proc[_ble_ctx_SARGX1]=ble/syntax:bash/ctx-command-compound-expect
_ble_syntax_context_proc[_ble_ctx_FARGX1]=ble/syntax:bash/ctx-command-compound-expect
_ble_syntax_context_proc[_ble_ctx_FARGX2]=ble/syntax:bash/ctx-command-compound-expect
_ble_syntax_context_proc[_ble_ctx_FARGX3]=ble/syntax:bash/ctx-command
_ble_syntax_context_proc[_ble_ctx_FARGI1]=ble/syntax:bash/ctx-command
_ble_syntax_context_proc[_ble_ctx_FARGI2]=ble/syntax:bash/ctx-command
_ble_syntax_context_proc[_ble_ctx_FARGI3]=ble/syntax:bash/ctx-command
_ble_syntax_context_proc[_ble_ctx_FARGQ3]=ble/syntax:bash/ctx-command
_ble_syntax_context_end[_ble_ctx_FARGI1]=ble/syntax:bash/ctx-command/check-word-end
_ble_syntax_context_end[_ble_ctx_FARGI2]=ble/syntax:bash/ctx-command/check-word-end
_ble_syntax_context_end[_ble_ctx_FARGI3]=ble/syntax:bash/ctx-command/check-word-end
_ble_syntax_context_end[_ble_ctx_FARGQ3]=ble/syntax:bash/ctx-command/check-word-end
_ble_syntax_context_proc[_ble_ctx_CARGX1]=ble/syntax:bash/ctx-command-compound-expect
_ble_syntax_context_proc[_ble_ctx_CARGX2]=ble/syntax:bash/ctx-command-compound-expect
_ble_syntax_context_proc[_ble_ctx_CPATX]=ble/syntax:bash/ctx-command-case-pattern-expect
_ble_syntax_context_proc[_ble_ctx_CPATX0]=ble/syntax:bash/ctx-command-case-pattern-expect
_ble_syntax_context_proc[_ble_ctx_CARGI1]=ble/syntax:bash/ctx-command
_ble_syntax_context_proc[_ble_ctx_CARGQ1]=ble/syntax:bash/ctx-command
_ble_syntax_context_proc[_ble_ctx_CARGI2]=ble/syntax:bash/ctx-command
_ble_syntax_context_proc[_ble_ctx_CPATI]=ble/syntax:bash/ctx-command
_ble_syntax_context_proc[_ble_ctx_CPATQ]=ble/syntax:bash/ctx-command
_ble_syntax_context_end[_ble_ctx_CARGI1]=ble/syntax:bash/ctx-command/check-word-end
_ble_syntax_context_end[_ble_ctx_CARGQ1]=ble/syntax:bash/ctx-command/check-word-end
_ble_syntax_context_end[_ble_ctx_CARGI2]=ble/syntax:bash/ctx-command/check-word-end
_ble_syntax_context_end[_ble_ctx_CPATI]=ble/syntax:bash/ctx-command/check-word-end
_ble_syntax_context_end[_ble_ctx_CPATQ]=ble/syntax:bash/ctx-command/check-word-end
_ble_syntax_context_proc[_ble_ctx_TARGX1]=ble/syntax:bash/ctx-command-time-expect
_ble_syntax_context_proc[_ble_ctx_TARGX2]=ble/syntax:bash/ctx-command-time-expect
_ble_syntax_context_proc[_ble_ctx_TARGI1]=ble/syntax:bash/ctx-command
_ble_syntax_context_proc[_ble_ctx_TARGI2]=ble/syntax:bash/ctx-command
_ble_syntax_context_end[_ble_ctx_TARGI1]=ble/syntax:bash/ctx-command/check-word-end
_ble_syntax_context_end[_ble_ctx_TARGI2]=ble/syntax:bash/ctx-command/check-word-end
_ble_syntax_context_proc[_ble_ctx_FNAMEX]=ble/syntax:bash/ctx-command-function-expect
_ble_syntax_context_proc[_ble_ctx_FNAMEI]=ble/syntax:bash/ctx-command
_ble_syntax_context_end[_ble_ctx_FNAMEI]=ble/syntax:bash/ctx-command/check-word-end
_ble_syntax_context_proc[_ble_ctx_COARGX]=ble/syntax:bash/ctx-command-compound-expect
_ble_syntax_context_end[_ble_ctx_COARGI]=ble/syntax:bash/ctx-coproc/check-word-end

## @fn ble/syntax:bash/starts-with-delimiter-or-redirect
##
##   Determine whether it is whitespace, command delimiters, or redirects.
##   1>2 and {fd}>2 at the start of a word are also considered redirects.
##
## Note: Even if it doesn't match "1>2" or "{fd}>" here, in normal context
##   As long as columns such as "{fd}" and "1" are read all at once, there should be no read-ahead problem.
##   Brace expansion analysis is carefully implemented so that "{fd}" is read all at once.
##
##   @var[out] BASH_REMATCH
##     When the function succeeds, BASH_REMATCH contains the matching delimiter
##     or the redirection.
function ble/syntax:bash/starts-with-delimiter-or-redirect {
  local delimiters=$_ble_syntax_bash_RexDelimiter
  local redirect=$_ble_syntax_bash_RexRedirect
  local cont='\\'$_ble_term_nl
  [[ ( $tail =~ ^$delimiters || $wbegin -lt 0 && $tail =~ ^$redirect || $wbegin -lt 0 && $tail =~ ^$cont ) && $tail != ['<>']'('* ]]
}
function ble/syntax:bash/starts-with-delimiter {
  [[ $tail == ["$_ble_term_IFS;|&<>()"]* && $tail != ['<>']'('* ]]
}
function ble/syntax:bash/check-word-end/is-delimiter {
  local tail=${text:i}
  if [[ $tail == [!"$_ble_term_IFS;|&<>()"]* ]]; then
    return 1
  elif [[ $tail == ['<>']* ]]; then
    ble/syntax/parse/set-lookahead 2
    [[ $tail == ['<>']'('* ]] && return 1
  fi
  return 0
}

## @fn ble/syntax:bash/check-here-document-from spaces
##   @param[in] spaces
function ble/syntax:bash/check-here-document-from {
  local spaces=$1
  [[ $nparam && $spaces == *$'\n'* ]] || return 1
  local rex="$_ble_term_FS@([RI][QH][^$_ble_term_FS]*)(.*$)" && [[ $nparam =~ $rex ]] || return 1

  # Start Here Document
  local rematch1=${BASH_REMATCH[1]}
  local rematch2=${BASH_REMATCH[2]}
  local padding=${spaces%%$'\n'*}
  ((_ble_syntax_attr[i]=ctx,i+=${#padding}))
  nparam=${nparam::${#nparam}-${#BASH_REMATCH}}${nparam:${#nparam}-${#rematch2}}
  ble/syntax/parse/nest-push "$_ble_ctx_HERE0"
  ((i++))
  nparam=$rematch1
  return 0
}

function ble/syntax:bash/ctx-coproc/.is-next-compound {
  # @var ahead
  #   Whether the next character at current position p was referenced
  local p=$i ahead=1 tail=${text:i}

  # Ignore whitespace
  if local rex=$'^[ \t]+'; [[ $tail =~ $rex ]]; then
    ((p+=${#BASH_REMATCH}))
    ahead=1 tail=${text:p}
  fi

  local is_compound=
  if [[ $tail == '('* ]]; then
    is_compound=1
  elif rex='^[a-z]+|^\[\[?|^[{}!]'; [[ $tail =~ $rex ]]; then
    local rematch=$BASH_REMATCH

    ((p+=${#rematch}))
    [[ $rematch == ['{}!'] || $rematch == '[[' ]]; ahead=$?

    rex='^(\[\[|for|select|case|if|while|until|fi|done|esac|then|elif|else|do|[{}!]|coproc|function)$'
    if  [[ $rematch =~ $rex ]]; then
      if rex='^[;|&()'$_ble_term_IFS']|^$|^[<>]\(?' ahead=1; [[ ${text:p} =~ $rex ]]; then
        local rematch=$BASH_REMATCH
        ((p+=${#rematch}))
        [[ $rematch && $rematch != ['<>'] ]]; ahead=$?
        [[ $rematch != ['<>']'(' ]] && is_compound=1
      fi
    fi
  fi

  # Read ahead settings
  ble/syntax/parse/set-lookahead "$((p+ahead-i))"
  [[ $is_compound ]]
}
function ble/syntax:bash/ctx-coproc/check-word-end {
  ble/util/assert '((ctx==_ble_ctx_COARGI))'

  # When it is not inside the word, it exits.
  ((wbegin<0)) && return 1

  # If there is still a continuation, exit
  ble/syntax:bash/check-word-end/is-delimiter || return 1

  local wbeg=$wbegin wlen=$((i-wbegin)) wend=$i
  local word=${text:wbegin:wlen}
  local wt=$wtype

  if local rex='^[_a-zA-Z][_a-zA-Z0-9]*$'; [[ $word =~ $rex ]]; then
    if ble/syntax:bash/ctx-coproc/.is-next-compound; then
      # Syntax: variable name compound command
      local attr=$_ble_attr_VAR

      # If it is an alias, the interpretation may change. When alias is expanded strictly to a variable name
      # It is judged as a variable name only when If expanded to the start of a compound command, it will be formatted into normal processing.
      # Ruback. Otherwise it is an error.
      if ble/alias#active "$word"; then
        attr=
        local ret; ble/alias#expand "$word"
        case $word in
        # Fallback to normal processing
        ('if'|'while'|'until'|'for'|'select'|'case'|'{'|'[[') ;;
        # Normal processing (syntax error)
        ('fi'|'done'|'esac'|'then'|'elif'|'else'|'do'|'}'|'!'|'coproc'|'function'|'in') ;;
        (*)
          if ble/string#match "$word" '^[_a-zA-Z][_a-zA-Z0-9]*$'; then
            # OK if expanded to variable name
            attr=$_ble_attr_CMD_ALIAS
          else
            attr=$_ble_attr_ERR
          fi
        esac
      fi

      if [[ $attr ]]; then
        # Note: [_a-zA-Z0-9]+ is supposed to be read once, so
        #   There should be no problem if you retroactively substitute here.
        _ble_syntax_attr[wbegin]=$attr
        ((ctx=_ble_ctx_CMDXC,wtype=_ble_ctx_ARGVI))
        ble/syntax/parse/word-pop
        return 0
      fi
    fi
  fi

  ((ctx=_ble_ctx_CMDI,wtype=_ble_ctx_CMDX))
  ble/syntax:bash/ctx-command/check-word-end
}

## @arr _ble_syntax_bash_command_EndCtx
##   Sets the next context value after the word ends.
##   Used with check-word-end.
##
##   Note #1: time -p -- cmd is bash-4.2 or later
##     In versions lower than bash-4.2, the command must come immediately after -p.
##
_ble_syntax_bash_command_EndCtx=()
_ble_syntax_bash_command_EndCtx[_ble_ctx_ARGI]=$_ble_ctx_ARGX
_ble_syntax_bash_command_EndCtx[_ble_ctx_ARGQ]=$_ble_ctx_ARGX
_ble_syntax_bash_command_EndCtx[_ble_ctx_ARGVI]=$_ble_ctx_ARGVX
_ble_syntax_bash_command_EndCtx[_ble_ctx_ARGVR]=$_ble_ctx_ARGVX
_ble_syntax_bash_command_EndCtx[_ble_ctx_ARGEI]=$_ble_ctx_ARGEX
_ble_syntax_bash_command_EndCtx[_ble_ctx_ARGER]=$_ble_ctx_ARGEX
_ble_syntax_bash_command_EndCtx[_ble_ctx_VRHS]=$_ble_ctx_CMDXV
_ble_syntax_bash_command_EndCtx[_ble_ctx_FARGI1]=$_ble_ctx_FARGX2
_ble_syntax_bash_command_EndCtx[_ble_ctx_FARGI2]=$_ble_ctx_FARGX3
_ble_syntax_bash_command_EndCtx[_ble_ctx_FARGI3]=$_ble_ctx_FARGX3
_ble_syntax_bash_command_EndCtx[_ble_ctx_FARGQ3]=$_ble_ctx_FARGX3
_ble_syntax_bash_command_EndCtx[_ble_ctx_CARGI1]=$_ble_ctx_CARGX2
_ble_syntax_bash_command_EndCtx[_ble_ctx_CARGQ1]=$_ble_ctx_CARGX2
_ble_syntax_bash_command_EndCtx[_ble_ctx_CARGI2]=$_ble_ctx_CASE
_ble_syntax_bash_command_EndCtx[_ble_ctx_CPATI]=$_ble_ctx_CPATX0
_ble_syntax_bash_command_EndCtx[_ble_ctx_CPATQ]=$_ble_ctx_CPATX0
_ble_syntax_bash_command_EndCtx[_ble_ctx_TARGI1]=$((_ble_bash>=40200?_ble_ctx_TARGX2:_ble_ctx_CMDXT)) #1
_ble_syntax_bash_command_EndCtx[_ble_ctx_TARGI2]=$_ble_ctx_CMDXT
_ble_syntax_bash_command_EndCtx[_ble_ctx_FNAMEI]=$_ble_ctx_CMDXC

## @arr _ble_syntax_bash_command_EndWtype[wtype]
##   Specify the wtype to actually register as tree.
##   *Note that the wtype being analyzed contains the wtype at the start of the analysis.
_ble_syntax_bash_command_EndWtype[_ble_ctx_ARGX]=$_ble_ctx_ARGI
_ble_syntax_bash_command_EndWtype[_ble_ctx_ARGX0]=$_ble_ctx_ARGI
_ble_syntax_bash_command_EndWtype[_ble_ctx_ARGVX]=$_ble_ctx_ARGVI
_ble_syntax_bash_command_EndWtype[_ble_ctx_ARGEX]=$_ble_ctx_ARGEI
_ble_syntax_bash_command_EndWtype[_ble_ctx_CMDX]=$_ble_ctx_CMDI
_ble_syntax_bash_command_EndWtype[_ble_ctx_CMDX0]=$_ble_ctx_CMDX0
_ble_syntax_bash_command_EndWtype[_ble_ctx_CMDX1]=$_ble_ctx_CMDI
_ble_syntax_bash_command_EndWtype[_ble_ctx_CMDXT]=$_ble_ctx_CMDI
_ble_syntax_bash_command_EndWtype[_ble_ctx_CMDXC]=$_ble_ctx_CMDI
_ble_syntax_bash_command_EndWtype[_ble_ctx_CMDXE]=$_ble_ctx_CMDI
_ble_syntax_bash_command_EndWtype[_ble_ctx_CMDXD]=$_ble_ctx_CMDI
_ble_syntax_bash_command_EndWtype[_ble_ctx_CMDXD0]=$_ble_ctx_CMDI
_ble_syntax_bash_command_EndWtype[_ble_ctx_CMDXV]=$_ble_ctx_CMDI
_ble_syntax_bash_command_EndWtype[_ble_ctx_FARGX1]=$_ble_ctx_FARGI1 # variable name
_ble_syntax_bash_command_EndWtype[_ble_ctx_SARGX1]=$_ble_ctx_ARGI
_ble_syntax_bash_command_EndWtype[_ble_ctx_FARGX2]=$_ble_ctx_FARGI2 # in
_ble_syntax_bash_command_EndWtype[_ble_ctx_FARGX3]=$_ble_ctx_ARGI # in
_ble_syntax_bash_command_EndWtype[_ble_ctx_CARGX1]=$_ble_ctx_ARGI
_ble_syntax_bash_command_EndWtype[_ble_ctx_CARGX2]=$_ble_ctx_CARGI2 # in
_ble_syntax_bash_command_EndWtype[_ble_ctx_CPATX]=$_ble_ctx_CPATI
_ble_syntax_bash_command_EndWtype[_ble_ctx_CPATX0]=$_ble_ctx_CPATI
_ble_syntax_bash_command_EndWtype[_ble_ctx_TARGX1]=$_ble_ctx_ARGI # -p
_ble_syntax_bash_command_EndWtype[_ble_ctx_TARGX2]=$_ble_ctx_ARGI # --
_ble_syntax_bash_command_EndWtype[_ble_ctx_FNAMEX]=$_ble_ctx_FNAMEI # function NAME

## @arr _ble_syntax_bash_command_Expect
##
##   Set a regular expression that represents the types of commands that are allowed.
##   Used with check-word-end.
##   It must correspond to the setting of the array _ble_syntax_bash_command_bwtype.
##
##   * Assumption: Match only reserved words
##     For the context value this array is set to,
##     By default, the command attribute is _ble_attr_ERR.
##     All allowed commands are reserved words, so
##     If it is allowed, it will be automatically overwritten with _ble_attr_KEYWORD, so it is OK.
##
##     When matching a word other than a reserved word,
##     You must explicitly cancel the attribute value _ble_attr_ERR.
##
_ble_syntax_bash_command_Expect=()
_ble_syntax_bash_command_Expect[_ble_ctx_CMDXC]='^(\(|\{|\(\(|\[\[|for|select|case|if|while|until)$'
_ble_syntax_bash_command_Expect[_ble_ctx_CMDXE]='^(\}|fi|done|esac|then|elif|else|do)$'
_ble_syntax_bash_command_Expect[_ble_ctx_CMDXD]='^(\{|do)$'
_ble_syntax_bash_command_Expect[_ble_ctx_CMDXD0]='^(\{|do)$'

## @fn ble/syntax:bash/ctx-command/check-word-end
##   @var[in,out] ctx
##   @var[in,out] wbegin
##   @var[in,out] etc.
function ble/syntax:bash/ctx-command/check-word-end {
  # When it is not inside the word, it exits.
  ((wbegin<0)) && return 1

  # If there is still a continuation, exit
  ble/syntax:bash/check-word-end/is-delimiter || return 1

  local wbeg=$wbegin wlen=$((i-wbegin)) wend=$i
  local word=${text:wbegin:wlen}
  local stat_wt=$wtype # wtype during word parsing

  [[ ${_ble_syntax_bash_command_EndWtype[stat_wt]} ]] &&
    wtype=${_ble_syntax_bash_command_EndWtype[stat_wt]}
  local rex_expect_command=${_ble_syntax_bash_command_Expect[stat_wt]}
  if [[ $rex_expect_command ]]; then
    # Contexts that accept only certain commands
    [[ $word =~ $rex_expect_command ]] || ((wtype=_ble_ctx_CMDX0))
  elif ((stat_wt==_ble_ctx_ARGX0||stat_wt==_ble_ctx_CPATX0)); then
    ((wtype=_ble_attr_ERR))
  elif ((stat_wt==_ble_ctx_CMDX1)); then
    local rex='^(then|elif|else|do|\}|done|fi|esac)$'
    [[ $word =~ $rex ]] && ((wtype=_ble_ctx_CMDX0))
  fi
  local tree_wt=$wtype # wtype actually registered as a word
  ble/syntax/parse/word-pop

  if ((ctx==_ble_ctx_CMDI)); then
    local ret
    ble/alias#expand "$word"; local word_expanded=$ret

    # Keyword processing
    if ((tree_wt==_ble_ctx_CMDX0)); then
      ((_ble_syntax_attr[wbeg]=_ble_attr_ERR,ctx=_ble_ctx_ARGX))
      return 0
    elif ((stat_wt!=_ble_ctx_CMDXV)); then # Note: Keywords are not processed immediately after variable assignment
      local processed=
      case $word_expanded in
      ('[[')
        # Start conditional command
        ble/syntax/parse/touch-updated-attr "$wbeg"
        ((_ble_syntax_attr[wbeg]=_ble_attr_DEL,
          ctx=_ble_bash>=50200?_ble_ctx_CMDXE:_ble_ctx_ARGX0))

        ble/syntax/parse/word-cancel # Delete the word "[[" (and all nodes inside it)
        if [[ $word == '[[' ]]; then
          # "[[" is once read as a square bracket expression, so remove that information.
          _ble_syntax_attr[wbeg+1]= # Erase colored as bracket expressions
        fi

        i=$wbeg ble/syntax/parse/nest-push "$_ble_ctx_CONDX"

        # workaround: Replace word "[[" inside nest
        i=$wbeg ble/syntax/parse/word-push "$_ble_ctx_CMDI" "$wbeg"
        ble/syntax/parse/word-pop
        return 0 ;;
      ('time')               ((ctx=_ble_ctx_TARGX1)); processed=keyword ;;
      ('!')                  ((ctx=_ble_ctx_CMDXT)) ; processed=keyword ;;
      ('function')           ((ctx=_ble_ctx_FNAMEX)); processed=keyword ;;
      ('if'|'while'|'until') ((ctx=_ble_ctx_CMDX1)) ; processed=begin ;;
      ('for')                ((ctx=_ble_ctx_FARGX1)); processed=begin ;;
      ('select')             ((ctx=_ble_ctx_SARGX1)); processed=begin ;;
      ('case')               ((ctx=_ble_ctx_CARGX1)); processed=begin ;;
      ('{')
        # Resetting word attributes
        ble/syntax/parse/touch-updated-attr "$wbeg"
        if ((stat_wt==_ble_ctx_CMDXD||stat_wt==_ble_ctx_CMDXD0)); then
          attr=$_ble_attr_KEYWORD_MID # When "for ...; {" etc.
        else
          attr=$_ble_attr_KEYWORD_BEGIN
        fi
        ((_ble_syntax_attr[wbeg]=attr))

        # Delete words & nest & reinstall words
        ble/syntax/parse/word-cancel
        ((ctx=_ble_ctx_CMDXE))
        i=$wbeg ble/syntax/parse/nest-push "$_ble_ctx_CMDX1" 'cmd_brace'
        i=$wbeg ble/syntax/parse/word-push "$_ble_ctx_CMDI" "$wbeg"
        ble/syntax/parse/word-pop
        return 0 ;;
      ('then'|'elif'|'else'|'do') ((ctx=_ble_ctx_CMDX1)); processed=middle ;;
      ('done'|'fi'|'esac')        ((ctx=_ble_ctx_CMDXE)); processed=end ;;
      ('}')
        if local ntype; ble/syntax/parse/nest-type; [[ $ntype == 'cmd_brace' ]]; then
          ble/syntax/parse/touch-updated-attr "$wbeg"
          ((_ble_syntax_attr[wbeg]=_ble_attr_KEYWORD_END))
          ble/syntax/parse/nest-pop
        else
          ble/syntax/parse/touch-updated-attr "$wbeg"
          ((_ble_syntax_attr[wbeg]=_ble_attr_ERR))
          ((ctx=_ble_ctx_CMDXE))
        fi
        return 0 ;;
      ('coproc')
        if ((_ble_bash>=40000)); then
          if ble/syntax:bash/ctx-coproc/.is-next-compound; then
            ((ctx=_ble_ctx_CMDXC))
          else
            ((ctx=_ble_ctx_COARGX))
          fi
          processed=keyword
        fi ;;
      esac

      if [[ $processed ]]; then
        local attr=
        case $processed in
        (keyword) attr=$_ble_attr_KEYWORD ;;
        (begin)   attr=$_ble_attr_KEYWORD_BEGIN ;;
        (end)     attr=$_ble_attr_KEYWORD_END ;;
        (middle)  attr=$_ble_attr_KEYWORD_MID ;;
        esac
        if [[ $attr ]]; then
          ble/syntax/parse/touch-updated-attr "$wbeg"
          ((_ble_syntax_attr[wbeg]=attr))
        fi

        return 0
      fi
    fi

    # Considering the possibility that it is a function definition, read without placing stat
    ((ctx=_ble_ctx_ARGX))
    if local rex='^([ 	]*)(\([ 	]*\)?)?'; [[ ${text:i} =~ $rex && $BASH_REMATCH ]]; then

      # for bash-3.1 ${#arr[n]} bug
      local rematch1=${BASH_REMATCH[1]}
      local rematch2=${BASH_REMATCH[2]}

      if [[ $rematch2 == '('*')' ]]; then
        # case: /hoge ( *)/ function definition (change word type wtype)
        # Rewrite the value set in ble/syntax/parse/word-pop above.

        local attr=$_ble_attr_ERR
        # Note: An arbitrary function name has been allowed in bash-5.3-alpha,
        # but it has been postponed after bash-5.3-rc2 [1].  It will be enabled
        # again at the same time as quote removal of the name of the function
        # definition.  When it is supported, the following number 990000 should
        # be updated to the actual version number.
        # [1] https://lists.gnu.org/archive/html/bug-bash/2025-06/msg00005.html
        if ((_ble_bash>=990000)) || [[ $word_expanded != *[\\\'\"\`\$\<\>\(\)]* ]]; then
          _ble_syntax_tree[i-1]="$_ble_ctx_FNAMEI ${_ble_syntax_tree[i-1]#* }"
          attr=$_ble_attr_DEL
        fi

        ((_ble_syntax_attr[i]=_ble_ctx_CMDX1,i+=${#rematch1},
          _ble_syntax_attr[i]=attr,i+=${#rematch2},
          ctx=_ble_ctx_CMDXC))
      elif [[ $rematch2 == '('* ]]; then
        # case: /hoge \( */ If the parenthesis is not closed:
        #   I have no choice but to analyze it thinking that it is an extglob parenthesis.
        ((_ble_syntax_attr[i]=_ble_ctx_ARGX0,i+=${#rematch1},
          _ble_syntax_attr[i]=_ble_attr_ERR,
          ctx=_ble_ctx_ARGX0))
        ble/syntax/parse/nest-push "$_ble_ctx_PATN"
        ((${#rematch2}>=2&&(_ble_syntax_attr[i+1]=_ble_ctx_CMDXC),
          i+=${#rematch2}))
      else
        # case: /hoge */ probably command

        # Note (#D2126): Since the initial implementation e1e87c2c (2015-02-26), the analysis break point has been
        # I was reading it all at once without placing it, but I reconstructed the correct context by generating a complementary context.
        # Since this becomes difficult, we will place the analysis break point at the end of the word. correctly
        # As long as lookahead is set, there should be no problem.
        ble/syntax/parse/set-lookahead "$((${#rematch1}+1))"
      fi
    fi

    # Builtin with special handling of arguments
    case $word_expanded in
    ('declare'|'readonly'|'typeset'|'local'|'export'|'alias')
      ((ctx=_ble_ctx_ARGVX)) ;;
    ('eval')
      ((ctx=_ble_ctx_ARGEX)) ;;
    esac

    return 0
  fi

  if ((ctx==_ble_ctx_FARGI2)); then
    # for name do ...; done
    if [[ $word == do ]]; then
      ((ctx=_ble_ctx_CMDX1))
      return 0
    fi
  elif ((ctx==_ble_ctx_FARGI2||ctx==_ble_ctx_CARGI2)); then
    # for name in ... / case value in
    if [[ $word != in ]];  then
      ble/syntax/parse/touch-updated-attr "$wbeg"
      ((_ble_syntax_attr[wbeg]=_ble_attr_ERR))
    fi
  elif ((ctx==_ble_ctx_FNAMEI)); then
    # Note: An arbitrary function name has been allowed in bash-5.3-alpha,
    # but it has been postponed after bash-5.3-rc2 [1].  It will be enabled
    # again at the same time as quote removal of the name of the function
    # definition.  When it is supported, the following number 990000 should
    # be updated to the actual version number.
    # [1] https://lists.gnu.org/archive/html/bug-bash/2025-06/msg00005.html
    if ((_ble_bash<990000)) && [[ $word == *[\\\'\"\`\$\<\>\(\)]* ]]; then
      _ble_syntax_attr[i-1]=$_ble_attr_ERR
    fi

    local rex_space=$'[ \t]'
    if ble/string#match "${text:i}" "^($rex_space*)(\(\(|\($rex_space*\)?)?"; then
      local rematch1=${BASH_REMATCH[1]}
      local rematch2=${BASH_REMATCH[2]}
      ((${#rematch1})) && ((_ble_syntax_attr[i]=_ble_ctx_FNAMEX,i+=${#rematch1}))

      if [[ $rematch2 == '('*')' ]]; then
        ((_ble_syntax_attr[i]=_ble_attr_DEL,i+=${#rematch2}))
      elif [[ $rematch2 == '((' ]]; then
        if ((_ble_bash>=40200)); then
          ble/syntax/parse/set-lookahead 2
        else
          # Note: In Bash < 4.2, "function f ((expr))" becomes a syntax error.
          # We proceed the analysis by interpret it as the arithmetic command
          # (as in Bash >= 4.2), but we highlight the starting "((" with
          # _ble_attr_ERR.  The following is a modified version of the code in
          # ble/syntax:bash/ctx-command/.check-delimiter-or-redirect.
          ((_ble_syntax_attr[i]=_ble_attr_ERR,ctx=_ble_bash>=50200?_ble_ctx_CMDXE:_ble_ctx_ARGX0))
          ble/syntax/parse/nest-push "$_ble_ctx_EXPR" '(('
          ((i+=2))
        fi
      else
        if ((_ble_bash>=50100)) || [[ $rematch2 != '('* ]]; then
          ble/syntax/parse/set-lookahead "$((${#rematch2}+1))"
        else
          # Note: In Bash < 5.1, "function f (echo)" becomes a syntax error.  We
          # try to interpret it as if it is in Bash >= 5.1, but we highlight the
          # opening "(" with _ble_attr_ERR.  The following is a modified version of
          # the code in ble/syntax:bash/ctx-command/.check-delimiter-or-redirect.
          ((_ble_syntax_attr[i]=_ble_attr_ERR,ctx=_ble_ctx_CMDXE))
          ble/syntax/parse/nest-push "$_ble_ctx_CMDX1" '('
          ((${#rematch2}>=2&&(_ble_syntax_attr[i+1]=_ble_ctx_CMDX1),i+=${#rematch2}))
        fi
      fi
    fi
  fi

  if ((_ble_syntax_bash_command_EndCtx[ctx])); then
    ((ctx=_ble_syntax_bash_command_EndCtx[ctx]))
  fi

  return 0
}

## @arr _ble_syntax_bash_command_Opt
##   Set whether the command can end on the spot.
##   Used with .check-delimiter-or-redirect.
_ble_syntax_bash_command_Opt=()
_ble_syntax_bash_command_Opt[_ble_ctx_ARGX]=1
_ble_syntax_bash_command_Opt[_ble_ctx_ARGX0]=1
_ble_syntax_bash_command_Opt[_ble_ctx_ARGVX]=1
_ble_syntax_bash_command_Opt[_ble_ctx_ARGEX]=1
_ble_syntax_bash_command_Opt[_ble_ctx_CMDX0]=1
_ble_syntax_bash_command_Opt[_ble_ctx_CMDXV]=1
_ble_syntax_bash_command_Opt[_ble_ctx_CMDXE]=1
_ble_syntax_bash_command_Opt[_ble_ctx_CMDXD0]=1

_ble_syntax_bash_is_command_form_for=

function ble/syntax:bash/ctx-command/.check-delimiter-or-redirect {
  if [[ $tail =~ ^$_ble_syntax_bash_RexIFSs || $wbegin -lt 0 && $tail == $'\\\n'* ]]; then
    # blank or \ + newline

    local spaces=$BASH_REMATCH
    if [[ $tail == $'\\\n'* ]]; then
      # \ + Line breaks are simply ignored
      spaces=$'\\\n'
    elif [[ $spaces == *$'\n'* ]]; then
      # If there is a line break: Check here document / update context with line break
      ble/syntax:bash/check-here-document-from "$spaces" && return 0
      if ((ctx==_ble_ctx_ARGX||ctx==_ble_ctx_ARGX0||ctx==_ble_ctx_ARGVX||ctx==_ble_ctx_ARGEX||ctx==_ble_ctx_CMDX0||ctx==_ble_ctx_CMDXV||ctx==_ble_ctx_CMDXT||ctx==_ble_ctx_CMDXE)); then
        ((ctx=_ble_ctx_CMDX))
      elif ((ctx==_ble_ctx_FARGX2||ctx==_ble_ctx_FARGX3||ctx==_ble_ctx_CMDXD0)); then
        ((ctx=_ble_ctx_CMDXD))
      fi
    fi

    # ctx passes through as is.
    ((_ble_syntax_attr[i]=ctx,i+=${#spaces}))
    return 0

  elif [[ $tail =~ ^$_ble_syntax_bash_RexRedirect ]]; then
    # Redirect (& supersedes standalone interpretation)

    # for bash-3.1 ${#arr[n]} bug ... Once put in rematch1, get the number of characters with ${#rematch1}.
    local len=${#BASH_REMATCH}
    local rematch1=${BASH_REMATCH[1]}
    local rematch3=${BASH_REMATCH[3]}
    ((_ble_syntax_attr[i]=_ble_attr_DEL,
      ${#rematch1}<len&&(_ble_syntax_attr[i+${#rematch1}]=_ble_ctx_ARGX)))
    if ((ctx==_ble_ctx_CMDX||ctx==_ble_ctx_CMDX1||ctx==_ble_ctx_CMDXT)); then
      ((ctx=_ble_ctx_CMDXV))
    elif ((ctx==_ble_ctx_CMDXC||ctx==_ble_ctx_CMDXD||ctx==_ble_ctx_CMDXD0)); then
      ((ctx=_ble_ctx_CMDXV,
        _ble_syntax_attr[i]=_ble_attr_ERR))
    elif ((ctx==_ble_ctx_CMDXE)); then
      ((ctx=_ble_ctx_CMDX0))
    elif ((ctx==_ble_ctx_FARGX3)); then
      ((_ble_syntax_attr[i]=_ble_attr_ERR))
    fi

    if [[ ${text:i+len} != [!$'\n|&()']* ]]; then
      # If the redirect ends on the spot, there will be no nest-push in the first place and an error will occur.
      # Note: The character set for the above judgment is a subset of _ble_syntax_bash_RexDelimiter.
      #   However, spaces and <> are allowed because they can be included in redirects.
      ((_ble_syntax_attr[i+len-1]=_ble_attr_ERR))
    else
      if [[ $rematch3 == '>&' ]]; then
        ble/syntax/parse/nest-push "$_ble_ctx_RDRD2" "$rematch3"
      elif [[ $rematch1 == *'&' ]]; then
        ble/syntax/parse/nest-push "$_ble_ctx_RDRD" "$rematch3"
      elif [[ $rematch1 == *'<<<' ]]; then
        ble/syntax/parse/nest-push "$_ble_ctx_RDRS" "$rematch3"
      elif [[ $rematch1 == *\<\< ]]; then
        # Note: emacs bug workaround
        #   For some reason, when I write '<<', Emacs calls it a here document.
        #   I started to misunderstand it, so I had no choice but to change it to \<\<.
        ble/syntax/parse/nest-push "$_ble_ctx_RDRH" "$rematch3"
      elif [[ $rematch1 == *\<\<- ]]; then
        ble/syntax/parse/nest-push "$_ble_ctx_RDRI" "$rematch3"
      else
        ble/syntax/parse/nest-push "$_ble_ctx_RDRF" "$rematch3"
      fi
    fi
    ((i+=len))
    return 0
  elif local rex='^(&&|\|[|&]?)|^;(;&?|&)|^[;&]'
       ((_ble_bash<40000)) && rex='^(&&|\|\|?)|^;(;)|^[;&]'
       [[ $tail =~ $rex ]]
  then
    # Control operators && || | & ; |& ;; ;;& ;&

    if [[ $BASH_REMATCH == ';' ]]; then
      if ((ctx==_ble_ctx_FARGX2||ctx==_ble_ctx_FARGX3||ctx==_ble_ctx_CMDXD0)); then
        ((_ble_syntax_attr[i++]=_ble_attr_DEL,ctx=_ble_ctx_CMDXD))
        return 0
      elif ((ctx==_ble_ctx_CMDXT)); then
        # Note #D0592: Only for time ; and ! ;, _ble_ctx_CMDXE occurs immediately without an error.
        # Note #D1477: Behavior changes in Bash 4.4.
        ((_ble_syntax_attr[i++]=_ble_attr_DEL,ctx=_ble_bash>=40400?_ble_ctx_CMDX:_ble_ctx_CMDXE))
        return 0
      fi
    fi

    # for bash-3.1 ${#arr[n]} bug
    local rematch1=${BASH_REMATCH[1]} rematch2=${BASH_REMATCH[2]}
    ((_ble_syntax_attr[i]=_ble_attr_DEL,
      (_ble_syntax_bash_command_Opt[ctx]||ctx==_ble_ctx_CMDX&&${#rematch2})||
        (_ble_syntax_attr[i]=_ble_attr_ERR)))

    ((ctx=${#rematch1}?_ble_ctx_CMDX1:(
         ${#rematch2}?_ble_ctx_CASE:
         _ble_ctx_CMDX)))
    ((i+=${#BASH_REMATCH}))
    return 0
  elif local rex='^\(\(?' && [[ $tail =~ $rex ]]; then
    # subshell (, arithmetic command ((
    local m=${BASH_REMATCH[0]}
    if ((ctx==_ble_ctx_CMDX||ctx==_ble_ctx_CMDX1||ctx==_ble_ctx_CMDXT||ctx==_ble_ctx_CMDXC)); then
      # Note: In the "ctx==_ble_ctx_FNAMEI" branch of
      # ble/syntax:bash/ctx-command/check-word-end, we have modified copies of
      # the following code.  When we modify the following code, the
      # corresponding versions in ble/syntax:bash/ctx-command/check-word-end
      # should also be updated.
      ((_ble_syntax_attr[i]=_ble_attr_DEL))
      ((ctx=_ble_bash>=50200||${#m}==1?_ble_ctx_CMDXE:_ble_ctx_ARGX0))
      [[ $_ble_syntax_bash_is_command_form_for && $tail == '(('* ]] && ((ctx=_ble_ctx_CMDXD0))
      ble/syntax/parse/nest-push "$((${#m}==1?_ble_ctx_CMDX1:_ble_ctx_EXPR))" "$m"
      ((i+=${#m}))
    else
      ble/syntax/parse/nest-push "$_ble_ctx_PATN"
      ((_ble_syntax_attr[i++]=_ble_attr_ERR))
    fi
    return 0
  elif [[ $tail == ')'* ]]; then
    local ntype
    ble/syntax/parse/nest-type
    local attr=
    if [[ $ntype == '(' || $ntype == '$(' || $ntype == '((' || $ntype == '$((' ]]; then
      # 1 $ntype == '('
      #   ( sub shell )
      #   <( process substitution )
      #   func ( invalid )
      # 2 $ntype== '$('
      #   $(command substitution)
      # 3 $ntype == '((', '$(('
      #   ((echo) >/dev/null) / $((echo) >/dev/null)
      #   *At first I thought this was an arithmetic expression, but it turned out to be a subshell.
      ((attr=_ble_syntax_attr[inest]))
    fi

    if [[ $attr ]]; then
      ((_ble_syntax_attr[i]=(ctx==_ble_ctx_CMDX||ctx==_ble_ctx_CMDX0||ctx==_ble_ctx_CMDXV||ctx==_ble_ctx_CMDXE||ctx==_ble_ctx_ARGX||ctx==_ble_ctx_ARGX0||ctx==_ble_ctx_ARGVX||ctx==_ble_ctx_ARGEX)?attr:_ble_attr_ERR,
        i+=1))
      ble/syntax/parse/nest-pop
      return 0
    fi
  fi

  return 1
}

## @fn ble/syntax:bash/ctx-command/.check-word-begin
##   Starts the word if it is not started.
##   @var[in,out] i,ctx,wtype,wbegin
##   @return Returns 1 when the argument appears where it should not.
_ble_syntax_bash_command_BeginCtx=()
_ble_syntax_bash_command_BeginCtx[_ble_ctx_ARGX]=$_ble_ctx_ARGI
_ble_syntax_bash_command_BeginCtx[_ble_ctx_ARGX0]=$_ble_ctx_ARGI
_ble_syntax_bash_command_BeginCtx[_ble_ctx_ARGVX]=$_ble_ctx_ARGVI
_ble_syntax_bash_command_BeginCtx[_ble_ctx_ARGEX]=$_ble_ctx_ARGEI
_ble_syntax_bash_command_BeginCtx[_ble_ctx_CMDX]=$_ble_ctx_CMDI
_ble_syntax_bash_command_BeginCtx[_ble_ctx_CMDX0]=$_ble_ctx_CMDI
_ble_syntax_bash_command_BeginCtx[_ble_ctx_CMDX1]=$_ble_ctx_CMDI
_ble_syntax_bash_command_BeginCtx[_ble_ctx_CMDXT]=$_ble_ctx_CMDI
_ble_syntax_bash_command_BeginCtx[_ble_ctx_CMDXC]=$_ble_ctx_CMDI
_ble_syntax_bash_command_BeginCtx[_ble_ctx_CMDXE]=$_ble_ctx_CMDI
_ble_syntax_bash_command_BeginCtx[_ble_ctx_CMDXD]=$_ble_ctx_CMDI
_ble_syntax_bash_command_BeginCtx[_ble_ctx_CMDXD0]=$_ble_ctx_CMDI
_ble_syntax_bash_command_BeginCtx[_ble_ctx_CMDXV]=$_ble_ctx_CMDI
_ble_syntax_bash_command_BeginCtx[_ble_ctx_FARGX1]=$_ble_ctx_FARGI1
_ble_syntax_bash_command_BeginCtx[_ble_ctx_SARGX1]=$_ble_ctx_FARGI1
_ble_syntax_bash_command_BeginCtx[_ble_ctx_FARGX2]=$_ble_ctx_FARGI2
_ble_syntax_bash_command_BeginCtx[_ble_ctx_FARGX3]=$_ble_ctx_FARGI3
_ble_syntax_bash_command_BeginCtx[_ble_ctx_CARGX1]=$_ble_ctx_CARGI1
_ble_syntax_bash_command_BeginCtx[_ble_ctx_CARGX2]=$_ble_ctx_CARGI2
_ble_syntax_bash_command_BeginCtx[_ble_ctx_CPATX]=$_ble_ctx_CPATI
_ble_syntax_bash_command_BeginCtx[_ble_ctx_CPATX0]=$_ble_ctx_CPATI
_ble_syntax_bash_command_BeginCtx[_ble_ctx_TARGX1]=$_ble_ctx_TARGI1
_ble_syntax_bash_command_BeginCtx[_ble_ctx_TARGX2]=$_ble_ctx_TARGI2
_ble_syntax_bash_command_BeginCtx[_ble_ctx_FNAMEX]=$_ble_ctx_FNAMEI
_ble_syntax_bash_command_BeginCtx[_ble_ctx_COARGX]=$_ble_ctx_COARGI

## @arr _ble_syntax_bash_command_isARGI[ctx]
##
##   Array for assert. Manage context values that may appear during shell word parsing. This arrangement
##   When a column element is a non-empty string, its context may appear during shell word parsing.
##
_ble_syntax_bash_command_isARGI[_ble_ctx_CMDI]=1
_ble_syntax_bash_command_isARGI[_ble_ctx_VRHS]=1
_ble_syntax_bash_command_isARGI[_ble_ctx_ARGI]=1
_ble_syntax_bash_command_isARGI[_ble_ctx_ARGQ]=1
_ble_syntax_bash_command_isARGI[_ble_ctx_ARGVI]=1
_ble_syntax_bash_command_isARGI[_ble_ctx_ARGVR]=1
_ble_syntax_bash_command_isARGI[_ble_ctx_ARGEI]=1
_ble_syntax_bash_command_isARGI[_ble_ctx_ARGER]=1
_ble_syntax_bash_command_isARGI[_ble_ctx_FARGI1]=1 # var
_ble_syntax_bash_command_isARGI[_ble_ctx_FARGI2]=1 # in
_ble_syntax_bash_command_isARGI[_ble_ctx_FARGI3]=1 # args...
_ble_syntax_bash_command_isARGI[_ble_ctx_FARGQ3]=1 # args... (after =)
_ble_syntax_bash_command_isARGI[_ble_ctx_CARGI1]=1 # value
_ble_syntax_bash_command_isARGI[_ble_ctx_CARGQ1]=1 # value (after =)
_ble_syntax_bash_command_isARGI[_ble_ctx_CARGI2]=1 # in
_ble_syntax_bash_command_isARGI[_ble_ctx_CPATI]=1  # pattern
_ble_syntax_bash_command_isARGI[_ble_ctx_CPATQ]=1  # pattern
_ble_syntax_bash_command_isARGI[_ble_ctx_TARGI1]=1 # -p
_ble_syntax_bash_command_isARGI[_ble_ctx_TARGI2]=1 # --
_ble_syntax_bash_command_isARGI[_ble_ctx_FNAMEI]=1 # function NAME
_ble_syntax_bash_command_isARGI[_ble_ctx_COARGI]=1 # var (after coproc)
# Detect the end of ${ list; }
function ble/syntax:bash/ctx-command/.check-funsub-end {
  ((_ble_bash>=50300)) || return 1

  # The context in which the new command name begins
  ((wbegin<0&&_ble_syntax_bash_command_BeginCtx[ctx]==_ble_ctx_CMDI)) || return 1

  [[ $tail == '}'* ]] || return 1

  local ntype
  ble/syntax/parse/nest-type
  [[ $ntype == 'cmdsub_nofork' ]] || return 1

  ((_ble_syntax_attr[i++]=_ble_syntax_attr[inest]))
  ble/syntax/parse/nest-pop
  return 0
}
function ble/syntax:bash/ctx-command/.check-word-begin {
  if ((wbegin<0)); then
    local octx
    ((octx=ctx,
      wtype=octx,
      ctx=_ble_syntax_bash_command_BeginCtx[ctx]))
    ble/util/assert '((ctx!=0))' "invalid ctx=$octx at the beginning of words" ||
      ((ctx=wtype=_ble_ctx_ARGI))

    # Note: The wtype set here is ultimately set in ctx-command/check-word-end.
    #   It is converted by the array _ble_syntax_bash_command_EndWtype and then registered in tree.
    ble/syntax/parse/word-push "$wtype" "$i"

    ((octx!=_ble_ctx_ARGX0&&octx!=_ble_ctx_CPATX0)); return "$?" # return unexpectedWbegin
  fi

  ble/util/assert '((_ble_syntax_bash_command_isARGI[ctx]))' "invalid ctx=$ctx in words"
  return 0
}

# Command/argument part
function ble/syntax:bash/ctx-command {
  if ble/syntax:bash/starts-with-delimiter-or-redirect; then
    ble/util/assert '
      ((ctx==_ble_ctx_ARGX||ctx==_ble_ctx_ARGX0||ctx==_ble_ctx_ARGVX||ctx==_ble_ctx_ARGEX||
          ctx==_ble_ctx_FARGX2||ctx==_ble_ctx_FARGX3||ctx==_ble_ctx_COARGX||
          ctx==_ble_ctx_CMDX||ctx==_ble_ctx_CMDX0||ctx==_ble_ctx_CMDX1||ctx==_ble_ctx_CMDXT||ctx==_ble_ctx_CMDXC||
          ctx==_ble_ctx_CMDXE||ctx==_ble_ctx_CMDXD||ctx==_ble_ctx_CMDXD0||ctx==_ble_ctx_CMDXV))'  "invalid ctx=$ctx @ i=$i"
    ble/util/assert '((wbegin<0&&wtype<0))' "invalid word-context (wtype=$wtype wbegin=$wbegin) on non-word char."
    ble/syntax:bash/ctx-command/.check-delimiter-or-redirect; return "$?"
  fi

  ble/syntax:bash/check-comment && return 0

  ble/syntax:bash/ctx-command/.check-funsub-end && return 0

  local unexpectedWbegin=-1
  ble/syntax:bash/ctx-command/.check-word-begin || ((unexpectedWbegin=i))

  local wtype0=$wtype i0=$i

  local flagConsume=0
  if ble/syntax:bash/check-variable-assignment; then
    flagConsume=1
  elif local rex='^([^'${_ble_syntax_bash_chars[_ble_ctx_ARGI]}']+|\\.)'; [[ $tail =~ $rex ]]; then
    local rematch=$BASH_REMATCH
    local attr=$ctx
    [[ $BASH_REMATCH == '\'? ]] && attr=$_ble_attr_QESC
    ((_ble_syntax_attr[i]=attr,i+=${#rematch}))
    flagConsume=1
  elif ble/syntax:bash/check-process-subst; then
    flagConsume=1
  elif ble/syntax:bash/check-quotes; then
    flagConsume=1
  elif ble/syntax:bash/check-dollar; then
    flagConsume=1
  elif ble/syntax:bash/check-glob; then
    flagConsume=1
  elif ble/syntax:bash/check-brace-expansion; then
    flagConsume=1
  elif ble/syntax:bash/check-tilde-expansion; then
    flagConsume=1
  elif ble/syntax:bash/starts-with-histchars; then
    ble/syntax:bash/check-history-expansion ||
      ((_ble_syntax_attr[i]=ctx,i++))
    flagConsume=1
  fi

  if ((flagConsume)); then
    ble/util/assert '((wtype0>=0))'

    if ((ctx==_ble_ctx_FARGI1)); then
      # Check the variable name and color the var part of for var in ...
      local rex='^[_a-zA-Z][_a-zA-Z0-9]*$' attr=$_ble_attr_ERR
      if ((i0==wbegin)) && [[ ${text:i0:i-i0} =~ $rex ]]; then
        local ret; ble/syntax/highlight/vartype "$BASH_REMATCH" global; attr=$ret
      fi
      ((_ble_syntax_attr[i0]=attr))
    fi

    [[ ${_ble_syntax_bash_command_Expect[wtype0]} ]] &&
      ((_ble_syntax_attr[i0]=_ble_attr_ERR))
    if ((unexpectedWbegin>=0)); then
      ble/syntax/parse/touch-updated-attr "$unexpectedWbegin"
      ((_ble_syntax_attr[unexpectedWbegin]=_ble_attr_ERR))
    fi
    return 0
  else
    return 1
  fi
}

function ble/syntax:bash/ctx-command-compound-expect {
  ble/util/assert '((ctx==_ble_ctx_FARGX1||ctx==_ble_ctx_SARGX1||ctx==_ble_ctx_CARGX1||ctx==_ble_ctx_FARGX2||ctx==_ble_ctx_CARGX2||ctx==_ble_ctx_COARGX))'
  local _ble_syntax_bash_is_command_form_for=
  if ble/syntax:bash/starts-with-delimiter-or-redirect; then
    # If delimiter comes while processing "for var in ... / case arg in".
    if ((ctx==_ble_ctx_FARGX2)) && [[ $tail == [$';\n']* ]]; then
      # This is a form of for var in ... where the part after in is omitted.
      # Process in the same way as FARGX3 with ble/syntax:bash/ctx-command.
      ble/syntax:bash/ctx-command
      return "$?"
    elif ((ctx==_ble_ctx_FARGX1)) && [[ $tail == '(('* ]]; then
      # for ((...))
      # Leave it to the subsequent processing for _ble_ctx_CMDX1 without returning here.
      ((ctx=_ble_ctx_CMDX1,_ble_syntax_bash_is_command_form_for=1))
    elif [[ $tail == $'\n'* ]]; then
      if ((ctx==_ble_ctx_CARGX2)); then
        ((_ble_syntax_attr[i++]=_ble_ctx_ARGX))
      else
        ((_ble_syntax_attr[i++]=_ble_attr_ERR,ctx=_ble_ctx_ARGX))
      fi
      return 0
    elif [[ $tail =~ ^$_ble_syntax_bash_RexSpaces ]]; then
      ((_ble_syntax_attr[i]=ctx,i+=${#BASH_REMATCH}))
      return 0
    elif ((ctx!=_ble_ctx_COARGX)); then
      local i0=$i
      ((ctx=_ble_ctx_ARGX))
      ble/syntax:bash/ctx-command/.check-delimiter-or-redirect || ((i++))
      ((_ble_syntax_attr[i0]=_ble_attr_ERR))
      return 0
    fi
  fi

  # Comments prohibited
  local i0=$i
  if ble/syntax:bash/check-comment; then
    if ((ctx==_ble_ctx_FARGX1||ctx==_ble_ctx_SARGX1||ctx==_ble_ctx_CARGX1||ctx==_ble_ctx_COARGX)); then
      # If a comment comes while processing "for var / select var / case arg / coproc"
      ((_ble_syntax_attr[i0]=_ble_attr_ERR))
    fi
    return 0
  fi

  # Everything else is the same
  ble/syntax:bash/ctx-command
}

## @fn ble/syntax:bash/ctx-command-expect/.match-word word
##   Tests whether the word starting at the current position matches the specified word.
##   @param[in] word
##   @var[in] tail i
function ble/syntax:bash/ctx-command-expect/.match-word {
  local word=$1 len=${#1}
  if [[ $tail == "$word"* ]]; then
    ble/syntax/parse/set-lookahead "$((len+1))"
    if ((${#tail}==len)) || i=$((i+len)) ble/syntax:bash/check-word-end/is-delimiter; then
      return 0
    fi
  fi
  return 1
}

function ble/syntax:bash/ctx-command-time-expect {
  ble/util/assert '((ctx==_ble_ctx_TARGX1||ctx==_ble_ctx_TARGX2))'

  if ble/syntax:bash/starts-with-delimiter-or-redirect; then
    ble/util/assert '((wbegin<0&&wtype<0))'
    if [[ $tail =~ ^$_ble_syntax_bash_RexSpaces ]]; then
      ((_ble_syntax_attr[i]=ctx,i+=${#BASH_REMATCH}))
      return 0
    else
      ((ctx=_ble_ctx_CMDXT))
      ble/syntax:bash/ctx-command/.check-delimiter-or-redirect; return "$?"
    fi
  fi

  # Decay to _ble_ctx_CMDXT when it is not the expected word
  if ((ctx==_ble_ctx_TARGX1)); then
    # Note: In bash-5.1, it is OK even if "--" appears.
    # Set ctx=_ble_ctx_TARGX2 and process with the following if.
    ble/syntax:bash/ctx-command-expect/.match-word '-p' ||
      ((ctx=_ble_bash>=50100?_ble_ctx_TARGX2:_ble_ctx_CMDXT))
  fi
  if ((ctx==_ble_ctx_TARGX2)); then
    ble/syntax:bash/ctx-command-expect/.match-word '--' ||
      ((ctx=_ble_ctx_CMDXT))
  fi

  # Everything else is the same
  ble/syntax:bash/ctx-command
}

function ble/syntax:bash/ctx-command-case-pattern-expect {
  ble/util/assert '((ctx==_ble_ctx_CPATX||ctx==_ble_ctx_CPATX0))'

  if ble/syntax:bash/starts-with-delimiter-or-redirect; then
    local delimiter=$BASH_REMATCH
    if [[ $tail =~ ^$_ble_syntax_bash_RexSpaces ]]; then
      ((_ble_syntax_attr[i]=ctx,i+=${#BASH_REMATCH}))
    elif [[ $tail == '|'* ]]; then
      ((_ble_syntax_attr[i++]=ctx==_ble_ctx_CPATX?_ble_attr_ERR:_ble_attr_GLOB,ctx=_ble_ctx_CPATX))
    elif [[ $tail == ')'* ]]; then
      ((_ble_syntax_attr[i++]=ctx==_ble_ctx_CPATX?_ble_attr_ERR:_ble_attr_GLOB,ctx=_ble_ctx_CMDX))
    elif [[ $tail == '('* ]]; then
      # As with ctx-command, start @() with an error.
      ble/syntax:bash/ctx-command/.check-delimiter-or-redirect
    else
      # Line breaks, redirects, & are errors
      ((_ble_syntax_attr[i]=_ble_attr_ERR,i+=${#delimiter}))
    fi
    return "$?"
  fi

  # Comments prohibited
  local i0=$i
  if ble/syntax:bash/check-comment; then
    ((_ble_syntax_attr[i0]=_ble_attr_ERR))
    return 0
  fi

  # Everything else is the same
  ble/syntax:bash/ctx-command
}

function ble/syntax:bash/ctx-command-function-expect {
  ble/util/assert '((ctx==_ble_ctx_FNAMEX))'

  if ble/syntax:bash/starts-with-delimiter-or-redirect; then
    if [[ $tail =~ ^$_ble_syntax_bash_RexSpaces ]]; then
      ((_ble_syntax_attr[i]=ctx,i+=${#BASH_REMATCH}))
      return 0
    else
      local i0=$i
      ble/syntax:bash/ctx-command/.check-delimiter-or-redirect &&
        ((_ble_syntax_attr[i0]=_ble_attr_ERR))
      return "$?"
    fi
  fi

  # Comments prohibited
  local i0=$i
  if ble/syntax:bash/check-comment; then
    ((_ble_syntax_attr[i0]=_ble_attr_ERR))
    return 0
  fi

  # Everything else is the same
  ble/syntax:bash/ctx-command
}

#------------------------------------------------------------------------------
# Context: array value list
#

_ble_syntax_context_proc[_ble_ctx_VALX]=ble/syntax:bash/ctx-values
_ble_syntax_context_proc[_ble_ctx_VALI]=ble/syntax:bash/ctx-values
_ble_syntax_context_end[_ble_ctx_VALI]=ble/syntax:bash/ctx-values/check-word-end
_ble_syntax_context_proc[_ble_ctx_VALR]=ble/syntax:bash/ctx-values
_ble_syntax_context_end[_ble_ctx_VALR]=ble/syntax:bash/ctx-values/check-word-end
_ble_syntax_context_proc[_ble_ctx_VALQ]=ble/syntax:bash/ctx-values
_ble_syntax_context_end[_ble_ctx_VALQ]=ble/syntax:bash/ctx-values/check-word-end

## Context values ctx-values
##
##   When exiting from arr=() arr+=(), it is necessary to return to the original context value.
##   We will create one level of nested structure using nest-push and nest-pop.
##
##   However, some ingenuity is required to process here documents set externally.
##   If you use the outer nparam as is and exit again, apply the changes to the outer nparam.
##   ble/syntax:bash/ctx-values/enter, leave is used to carry over this nparam.
##

## @fn ble/syntax:bash/ctx-values/enter
##   @remarks This function is called from ble/syntax:bash/check-variable-assignment.
function ble/syntax:bash/ctx-values/enter {
  local outer_nparam=$nparam
  ble/syntax/parse/nest-push "$_ble_ctx_VALX"
  nparam=$outer_nparam
}
## @fn ble/syntax:bash/ctx-values/leave
function ble/syntax:bash/ctx-values/leave {
  local inner_nparam=$nparam
  ble/syntax/parse/nest-pop
  nparam=$inner_nparam
}

## @fn ble/syntax:bash/ctx-values/check-word-end
function ble/syntax:bash/ctx-values/check-word-end {
  # When it is not inside the word, it exits.
  ((wbegin<0)) && return 1

  # If there is still a continuation, exit
  [[ ${text:i:1} == [!"$_ble_term_IFS;|&<>()"] ]] && return 1

  local wbeg=$wbegin wlen=$((i-wbegin)) wend=$i
  local word=${text:wbegin:wlen}

  ble/syntax/parse/word-pop

  ble/util/assert '((ctx==_ble_ctx_VALI||ctx==_ble_ctx_VALR||ctx==_ble_ctx_VALQ))' 'invalid context'
  ((ctx=_ble_ctx_VALX))

  return 0
}

function ble/syntax:bash/ctx-values {
  # Command/argument part
  if ble/syntax:bash/starts-with-delimiter; then
    ble/util/assert '((ctx==_ble_ctx_VALX))' "invalid ctx=$ctx @ i=$i"
    ble/util/assert '((wbegin<0&&wtype<0))' "invalid word-context (wtype=$wtype wbegin=$wbegin) on non-word char."

    if [[ $tail =~ ^$_ble_syntax_bash_RexIFSs ]]; then
      local spaces=$BASH_REMATCH
      ble/syntax:bash/check-here-document-from "$spaces" && return 0

      # Blank (ctx passes through as is)
      ((_ble_syntax_attr[i]=ctx,i+=${#spaces}))
      return 0
    elif [[ $tail == ')'* ]]; then
      # End of array definition
      ((_ble_syntax_attr[i++]=_ble_attr_DEL))
      ble/syntax:bash/ctx-values/leave
      return 0
    elif [[ $type == ';'* ]]; then
      ((_ble_syntax_attr[i++]=_ble_attr_ERR))
      return 0
    else
      ((_ble_syntax_attr[i++]=_ble_attr_ERR))
      return 0
    fi
  fi

  if ble/syntax:bash/check-comment; then
    return 0
  fi

  if ((wbegin<0)); then
    ((ctx=_ble_ctx_VALI))
    ble/syntax/parse/word-push "$ctx" "$i"
  fi

  ble/util/assert '((ctx==_ble_ctx_VALI||ctx==_ble_ctx_VALR||ctx==_ble_ctx_VALQ))' "invalid context ctx=$ctx"

  if ble/syntax:bash/check-variable-assignment; then
    return 0
  elif ble/syntax:bash/check-plain-with-escape "[^${_ble_syntax_bash_chars[_ble_ctx_ARGI]}]+"; then
    return 0
  elif ble/syntax:bash/check-process-subst; then
    return 0
  elif ble/syntax:bash/check-quotes; then
    return 0
  elif ble/syntax:bash/check-dollar; then
    return 0
  elif ble/syntax:bash/check-glob; then
    return 0
  elif ble/syntax:bash/check-brace-expansion; then
    return 0
  elif ble/syntax:bash/check-tilde-expansion; then
    return 0
  elif ble/syntax:bash/starts-with-histchars; then
    ble/syntax:bash/check-history-expansion ||
      ((_ble_syntax_attr[i]=ctx,i++))
    return 0
  fi

  return 1
}

#------------------------------------------------------------------------------
# Context: [[ conditional expression ]]

_ble_syntax_context_proc[_ble_ctx_CONDX]=ble/syntax:bash/ctx-conditions
_ble_syntax_context_proc[_ble_ctx_CONDI]=ble/syntax:bash/ctx-conditions
_ble_syntax_context_end[_ble_ctx_CONDI]=ble/syntax:bash/ctx-conditions/check-word-end
_ble_syntax_context_proc[_ble_ctx_CONDQ]=ble/syntax:bash/ctx-conditions
_ble_syntax_context_end[_ble_ctx_CONDQ]=ble/syntax:bash/ctx-conditions/check-word-end

## @fn ble/syntax:bash/ctx-conditions/check-word-end
function ble/syntax:bash/ctx-conditions/check-word-end {
  # When it is not inside the word, it exits.
  ((wbegin<0)) && return 1

  # If there is still a continuation, exit
  [[ ${text:i:1} == [!"$_ble_term_IFS;|&<>()"] ]] && return 1

  local wbeg=$wbegin wlen=$((i-wbegin)) wend=$i
  local word=${text:wbegin:wlen}

  ble/syntax/parse/word-pop

  ble/util/assert '((ctx==_ble_ctx_CONDI||ctx==_ble_ctx_CONDQ))' 'invalid context'
  if [[ $word == ']]' ]]; then
    ble/syntax/parse/touch-updated-attr "$wbeg"
    ((_ble_syntax_attr[wbeg]=_ble_attr_DEL))
    ble/syntax/parse/nest-pop
  else
    ((ctx=_ble_ctx_CONDX))
  fi
  return 0
}

function ble/syntax:bash/ctx-conditions {
  # Command/argument part
  if ble/syntax:bash/starts-with-delimiter; then
    ble/util/assert '((ctx==_ble_ctx_CONDX))' "invalid ctx=$ctx @ i=$i"
    ble/util/assert '((wbegin<0&&wtype<0))' "invalid word-context (wtype=$wtype wbegin=$wbegin) on non-word char."

    if [[ $tail =~ ^$_ble_syntax_bash_RexIFSs ]]; then
      ((_ble_syntax_attr[i]=ctx,i+=${#BASH_REMATCH}))
      return 0
    else
      # [(<>;|&] etc.
      ((_ble_syntax_attr[i++]=_ble_ctx_CONDI))
      return 0
    fi
  fi

  ble/syntax:bash/check-comment && return 0

  if ((wbegin<0)); then
    ((ctx=_ble_ctx_CONDI))
    ble/syntax/parse/word-push "$ctx" "$i"
  fi

  ble/util/assert '((ctx==_ble_ctx_CONDI||ctx==_ble_ctx_CONDQ))' "invalid context ctx=$ctx"

  if ble/syntax:bash/check-variable-assignment; then
    return 0
  elif ble/syntax:bash/check-plain-with-escape "[^${_ble_syntax_bash_chars[_ble_ctx_ARGI]}]+"; then
    return 0
  elif ble/syntax:bash/check-process-subst; then
    return 0
  elif ble/syntax:bash/check-quotes; then
    return 0
  elif ble/syntax:bash/check-dollar; then
    return 0
  elif ble/syntax:bash/check-glob; then
    return 0
  elif ble/syntax:bash/check-brace-expansion; then
    return 0
  elif ble/syntax:bash/check-tilde-expansion; then
    return 0
  elif ble/syntax:bash/starts-with-histchars; then
    ble/syntax:bash/check-history-expansion ||
      ((_ble_syntax_attr[i++]=ctx))
    return 0
  else
    # For conditional commands, $, ), etc. are allowed. .
    ((_ble_syntax_attr[i++]=ctx))
    return 0
  fi

  return 1
}


#------------------------------------------------------------------------------
# Context: redirect

_ble_syntax_context_proc[_ble_ctx_RDRF]=ble/syntax:bash/ctx-redirect
_ble_syntax_context_proc[_ble_ctx_RDRD]=ble/syntax:bash/ctx-redirect
_ble_syntax_context_proc[_ble_ctx_RDRD2]=ble/syntax:bash/ctx-redirect
_ble_syntax_context_proc[_ble_ctx_RDRS]=ble/syntax:bash/ctx-redirect
_ble_syntax_context_end[_ble_ctx_RDRF]=ble/syntax:bash/ctx-redirect/check-word-end
_ble_syntax_context_end[_ble_ctx_RDRD]=ble/syntax:bash/ctx-redirect/check-word-end
_ble_syntax_context_end[_ble_ctx_RDRD2]=ble/syntax:bash/ctx-redirect/check-word-end
_ble_syntax_context_end[_ble_ctx_RDRS]=ble/syntax:bash/ctx-redirect/check-word-end
function ble/syntax:bash/ctx-redirect/check-word-begin {
  if ((wbegin<0)); then
    # *At the analysis stage, there is no distinction between _ble_ctx_RDRF/_ble_ctx_RDRD/_ble_ctx_RDRD2/_ble_ctx_RDRS.
    #   However, the ctx used for analysis is saved in the line below.
    #   This information is later used to generate completion candidates.
    ble/syntax/parse/word-push "$ctx" "$i"
    ble/syntax/parse/touch-updated-word "$i" #■Isn't this unnecessary?
  fi
}
function ble/syntax:bash/ctx-redirect/check-word-end {
  # When it is not inside the word, it exits.
  ((wbegin<0)) && return 1

  # If there is still a continuation, exit
  ble/syntax:bash/check-word-end/is-delimiter || return 1

  # Registering words
  ble/syntax/parse/word-pop

  # pop
  ble/syntax/parse/nest-pop
  # There is no ctx (context within words such as CMDI or ARGI) that requires a termination here.
  # This is because when you pushed, you should have been in the context of CMDX or ARGX.
  ble/util/assert '((!_ble_syntax_bash_command_isARGI[ctx]))' "invalid ctx=$ctx in words"
  return 0
}
function ble/syntax:bash/ctx-redirect {
  # A redirect must not be immediately followed by command termination or another redirect.
  if ble/syntax:bash/starts-with-delimiter-or-redirect; then
    ((_ble_syntax_attr[i++]=_ble_attr_ERR))
    [[ ${tail:1} =~ ^$_ble_syntax_bash_RexSpaces ]] &&
      ((_ble_syntax_attr[i]=ctx,i+=${#BASH_REMATCH}))
    return 0
  fi

  if local i0=$i; ble/syntax:bash/check-comment; then
    ((_ble_syntax_attr[i0]=_ble_attr_ERR))
    return 0
  fi

  # Setting word start
  ble/syntax:bash/ctx-redirect/check-word-begin

  if ble/syntax:bash/check-plain-with-escape "[^${_ble_syntax_bash_chars[_ble_ctx_ARGI]}]+"; then
    return 0
  elif ble/syntax:bash/check-process-subst; then
    return 0
  elif ble/syntax:bash/check-quotes; then
    return 0
  elif ble/syntax:bash/check-dollar; then
    return 0
  elif ble/syntax:bash/check-glob; then
    return 0
  elif ble/syntax:bash/check-brace-expansion; then
    return 0
  elif ble/syntax:bash/check-tilde-expansion; then
    return 0
  elif ble/syntax:bash/starts-with-histchars; then
    ble/syntax:bash/check-history-expansion ||
      ((_ble_syntax_attr[i]=ctx,i++))
    return 0
  fi

  return 1
}

#------------------------------------------------------------------------------
# Context: Heredoc
#
# | <<[-] word
# | contents
# | delimiter
#
# Create ctx-heredoc-word (word analysis) with reference to ctx-redirect.
#

_ble_syntax_bash_heredoc_EscSP='\040'
_ble_syntax_bash_heredoc_EscHT='\011'
_ble_syntax_bash_heredoc_EscLF='\012'
_ble_syntax_bash_heredoc_EscFS='\034'
function ble/syntax:bash/ctx-heredoc-word/initialize {
  local ret
  ble/util/s2c ' '
  ble/util/sprintf _ble_syntax_bash_heredoc_EscSP '\\%03o' "$ret"
  ble/util/s2c $'\t'
  ble/util/sprintf _ble_syntax_bash_heredoc_EscHT '\\%03o' "$ret"
  ble/util/s2c $'\n'
  ble/util/sprintf _ble_syntax_bash_heredoc_EscLF '\\%03o' "$ret"
  ble/util/s2c "$_ble_term_FS"
  ble/util/sprintf _ble_syntax_bash_heredoc_EscFS '\\%03o' "$ret"
}
ble/syntax:bash/ctx-heredoc-word/initialize

## @fn ble/syntax:bash/ctx-heredoc-word/remove-quotes word
##   @var[out] delimiter
function ble/syntax:bash/ctx-heredoc-word/remove-quotes {
  local text=$1 result=

  local rex='^[^\$"'\'']+|^\$?["'\'']|^\\.?|^.'
  while [[ $text && $text =~ $rex ]]; do
    local rematch=$BASH_REMATCH
    if [[ $rematch == \" || $rematch == \$\" ]]; then
      if rex='^\$?"(([^\"]|\\.)*)(\\?$|")'; [[ $text =~ $rex ]]; then
        local str=${BASH_REMATCH[1]}
        local a b
        b='\`' a='`'; str=${str//"$b"/"$a"}
        b='\"' a='"'; str=${str//"$b"/"$a"} # WA #D1751 checked
        b='\$' a='$'; str=${str//"$b"/"$a"}
        b='\\' a='\'; str=${str//"$b"/"$a"}
        result=$result$str
        text=${text:${#BASH_REMATCH}}
        continue
      fi
    elif [[ $rematch == \' ]]; then
      if rex="^('[^']*)'?"; [[ $text =~ $rex ]]; then
        builtin eval "result=\$result${BASH_REMATCH[1]}'"
        text=${text:${#BASH_REMATCH}}
        continue
      fi
    elif [[ $rematch == \$\' ]]; then
      if rex='^(\$'\''([^\'\'']|\\.)*)('\''|\\?$)'; [[ $text =~ $rex ]]; then
        builtin eval "result=\$result${BASH_REMATCH[1]}'"
        text=${text:${#BASH_REMATCH}}
        continue
      fi
    elif [[ $rematch == \\* ]]; then
      result=$result${rematch:1}
      text=${text:${#rematch}}
      continue
    fi

    result=$result$rematch
    text=${text:${#rematch}}
  done

  delimiter=$result$text
}

## @fn ble/syntax:bash/ctx-heredoc-word/remove-quotes delimiter
##   @var[out] escaped
function ble/syntax:bash/ctx-heredoc-word/escape-delimiter {
  local out=$1
  if [[ $out == *[\\\'$_ble_term_IFS$_ble_term_FS]* ]]; then
    local a b fs=$_ble_term_FS
    a=\\   ; b='\'$a; out=${out//"$a"/"$b"}
    a=\'   ; b='\'$a; out=${out//"$a"/"$b"}
    a=' '  ; b=$_ble_syntax_bash_heredoc_EscSP; out=${out//"$a"/"$b"}
    a=$'\t'; b=$_ble_syntax_bash_heredoc_EscHT; out=${out//"$a"/"$b"}
    a=$'\n'; b=$_ble_syntax_bash_heredoc_EscLF; out=${out//"$a"/"$b"}
    a=$fs  ; b=$_ble_syntax_bash_heredoc_EscFS; out=${out//"$a"/"$b"}
  fi
  escaped=$out
}
function ble/syntax:bash/ctx-heredoc-word/unescape-delimiter {
  builtin eval "delimiter=\$'$1'"
}

## Context value _ble_ctx_RDRH
##
##   @remarks
##     As with redirect, it is assumed that this context will be entered at the same time as nest-push.
##
_ble_syntax_context_proc[_ble_ctx_RDRH]=ble/syntax:bash/ctx-heredoc-word
_ble_syntax_context_end[_ble_ctx_RDRH]=ble/syntax:bash/ctx-heredoc-word/check-word-end
_ble_syntax_context_proc[_ble_ctx_RDRI]=ble/syntax:bash/ctx-heredoc-word
_ble_syntax_context_end[_ble_ctx_RDRI]=ble/syntax:bash/ctx-heredoc-word/check-word-end
function ble/syntax:bash/ctx-heredoc-word/check-word-end {
  ((wbegin<0)) && return 1

  # If there is still a continuation, exit
  ble/syntax:bash/check-word-end/is-delimiter || return 1

  # Terminal string such as word = "EOF"
  local octx=$ctx word=${text:wbegin:i-wbegin}

  # Termination processing
  ble/syntax/parse/word-pop
  ble/syntax/parse/nest-pop

  local I
  if ((octx==_ble_ctx_RDRI)); then I=I; else I=R; fi

  local Q delimiter
  if [[ $word == *[\'\"\\]* ]]; then
    Q=Q; ble/syntax:bash/ctx-heredoc-word/remove-quotes "$word"
  else
    Q=H; delimiter=$word
  fi

  local escaped; ble/syntax:bash/ctx-heredoc-word/escape-delimiter "$delimiter"
  nparam=$nparam$_ble_term_FS@$I$Q$escaped
  return 0
}
function ble/syntax:bash/ctx-heredoc-word {
  ble/syntax:bash/ctx-redirect
}

## Context values _ble_ctx_HERE0, _ble_ctx_HERE1
##
##   Evaluated in a nest-push environment.
##   It has the form nparam =~ [RI][QH]delimiter.
##
_ble_syntax_context_proc[_ble_ctx_HERE0]=ble/syntax:bash/ctx-heredoc-content
_ble_syntax_context_proc[_ble_ctx_HERE1]=ble/syntax:bash/ctx-heredoc-content
function ble/syntax:bash/ctx-heredoc-content {
  local indented= quoted= delimiter=
  ble/syntax:bash/ctx-heredoc-word/unescape-delimiter "${nparam:2}"
  [[ ${nparam::1} == I ]] && indented=1
  [[ ${nparam:1:1} == Q ]] && quoted=1

  local rex ht=$'\t' lf=$'\n'
  if ((ctx==_ble_ctx_HERE0)); then
    rex="^${indented:+$ht*}"$'([^\n]+\n?|\n)'
    [[ $tail =~ $rex ]] || return 1

    # Here document end determination
    # *The line, including leading and trailing spaces, must match the delimiter.
    local line=${BASH_REMATCH%"$lf"}
    local rematch1=${BASH_REMATCH[1]}
    if [[ ${rematch1%"$lf"} == "$delimiter" ]]; then
      local indent
      ((indent=${#BASH_REMATCH}-${#rematch1},
        _ble_syntax_attr[i]=_ble_ctx_HERE0,
        _ble_syntax_attr[i+indent]=_ble_ctx_RDRH,
        i+=${#line}))
      ble/syntax/parse/nest-pop
      return 0
    fi
  fi

  if [[ $quoted ]]; then
    ble/util/assert '((ctx==_ble_ctx_HERE0))'
    ((_ble_syntax_attr[i]=_ble_ctx_HERE0,i+=${#BASH_REMATCH}))
    return 0
  else
    ((ctx=_ble_ctx_HERE1))

    # \? and $? ${} $(()) $[] $() ``
    if rex='^(\\[\$`'$lf'])|^([^'${_ble_syntax_bash_chars[_ble_ctx_HERE1]}']|\\[^\$`'$lf'])+'$lf'?|^'$lf && [[ $tail =~ $rex ]]; then
      if [[ ${BASH_REMATCH[1]} ]]; then
        ((_ble_syntax_attr[i]=_ble_attr_QESC))
      else
        ((_ble_syntax_attr[i]=_ble_ctx_HERE0))
        [[ $BASH_REMATCH == *"$lf" ]] && ((ctx=_ble_ctx_HERE0))
      fi
      ((i+=${#BASH_REMATCH}))
      return 0
    fi

    if ble/syntax:bash/check-dollar; then
      return 0
    elif [[ $tail == '`'* ]] && ble/syntax:bash/check-quotes; then
      return 0
    elif ble/syntax:bash/starts-with-histchars; then
      ble/syntax:bash/check-history-expansion ||
        ((_ble_syntax_attr[i]=_ble_ctx_HERE0,i++))
      return 0
    else
      # A single $ or a terminating \?
      ((_ble_syntax_attr[i]=_ble_ctx_HERE0,i++))
      return 0
    fi
  fi
}

#------------------------------------------------------------------------------
# Utilities based on syntactic structures

function ble/syntax:bash/is-complete {
  local iN=${#_ble_syntax_text}

  # (1) When an error is set at the last point
  # - Unclosed single quotation etc. are here.
  # - It gets stuck here even when the nest is not closed.
  # - Actually, it takes here even when the here document is not closed.
  ((iN>0)) && ((_ble_syntax_attr[iN-1]==_ble_attr_ERR)) && return 1

  local stat=${_ble_syntax_stat[iN]}
  if [[ $stat ]]; then
    ble/string#split-words stat "$stat"

    # (2) When the nest is not closed
    local nlen=${stat[3]}; ((nlen>=0)) && return 1

    # (3) When there is a here document waiting
    local nparam=${stat[6]}; [[ $nparam == none ]] && nparam=
    local rex="$_ble_term_FS@([RI][QH][^$_ble_term_FS]*)(.*$)"
    [[ $nparam =~ $rex ]] && return 1

    # (4) Except when it is a complete context value
    local ctx=${stat[0]}
    ((ctx==_ble_ctx_ARGX||ctx==_ble_ctx_ARGX0||ctx==_ble_ctx_ARGVX||ctx==_ble_ctx_ARGEX||
        ctx==_ble_ctx_CMDX||ctx==_ble_ctx_CMDX0||ctx==_ble_ctx_CMDXT||ctx==_ble_ctx_CMDXE||ctx==_ble_ctx_CMDXV||
        ctx==_ble_ctx_TARGX1||ctx==_ble_ctx_TARGX2)) || return 1
  fi

  # Is the syntax if..fi, etc closed?
  local attrs ret
  IFS= builtin eval 'attrs="::${_ble_syntax_attr[*]/%/::}"' # WA #D1570 checked
  ble/string#count-string "$attrs" ":$_ble_attr_KEYWORD_BEGIN:"; local nbeg=$ret
  ble/string#count-string "$attrs" ":$_ble_attr_KEYWORD_END:"; local nend=$ret
  ((nbeg>nend)) && return 1

  return 0
}

## @fn ble/syntax:bash/find-end-of-array-index beg end
##   Finds "the position immediately before the binding brackets of the array index."
##   @param[in] beg
##     Specifies the starting position (position of "[") for subscripting array elements.
##   @param[in] end
##     Specify the end position of the search.
##   @var[out] ret
## Returns the position of "]" corresponding to beg.
##     Returns an empty string if there is no corresponding terminator.
function ble/syntax:bash/find-end-of-array-index {
  local beg=$1 end=$2
  ret=

  local inest0=$beg nest0
  [[ ${_ble_syntax_nest[inest0]} ]] || return 1

  local q stat1 nlen1 inest1 r=
  for ((q=inest0+1;q<end;q++)); do
    local stat1=${_ble_syntax_stat[q]}
    [[ $stat1 ]] || continue
    ble/string#split-words stat1 "$stat1"
    ((nlen1=stat1[3])) # (workaround Bash-4.2 segfault)
    ((inest1=nlen1<0?nlen1:q-nlen1))
    ((inest1<inest0)) && break
    ((r=q))
  done

  [[ ${_ble_syntax_text:r:end-r} == ']'* ]] && ret=$r
  [[ $ret ]]
}

## ble/syntax:bash/find-rhs wtype wbeg wlen opts
##   Gets the starting position of the right side of the variable assignment format.
##   @param[in] wtype wbeg wlen
##   @param[in] opts
##     element-assignment
##       This form of variable assignment is also allowed for array elements.
##     long-option
##       --long-option= format is also forced.
##   @var[out] ret
##     Returns the starting position of the right side.
##     If it is not in the form of variable assignment, it returns the starting position of the word.
##   @exit
##     Succeeds when the word has the form of a variable assignment.
## It will fail otherwise.
function ble/syntax:bash/find-rhs {
  local wtype=$1 wbeg=$2 wlen=$3 opts=$4

  local text=$_ble_syntax_text
  local word=${text:wbeg:wlen} wend=$((wbeg+wlen))

  local rex=
  if ((wtype==_ble_attr_VAR)); then
    rex='^[_a-zA-Z0-9]+(\+?=|\[)'
  elif ((wtype==_ble_ctx_VALI)); then
    if [[ :$opts: == *:element-assignment:* ]]; then
      # Allows variable assignment format even for array elements
      rex='^[_a-zA-Z0-9]+(\+?=|\[)|^(\[)'
    else
      rex='^(\[)'
    fi
  fi
  if [[ :$opts: == *:long-option:* ]]; then
    rex=${rex:+$rex'|'}'^--[-_a-zA-Z0-9]+='
  fi

  if [[ $rex && $word =~ $rex ]]; then
    local last_char=${BASH_REMATCH:${#BASH_REMATCH}-1}
    if [[ $last_char == '[' ]]; then
      # wtype==_ble_attr_VAR: arr[0]=x@ arr[1]+=x@
      # wtype==_ble_attr_VAR: declare arr[0]=x@ arr[1]+=x@
      # wtype==_ble_ctx_VALI: arr=([0]=x@ [1]+=x@)
      local p1=$((wbeg+${#BASH_REMATCH}-1))
      if ble/syntax:bash/find-end-of-array-index "$p1" "$wend"; then
        local p2=$ret
        case ${text:p2:wend-p2} in
        (']='*)  ((ret=p2+2)); return 0 ;;
        (']+='*) ((ret=p2+3)); return 0 ;;
        esac
      fi
    else
      # wtype==_ble_attr_VAR: var=x@ var+=x@
      # wtype==_ble_attr_VAR: declare var=x@ var+=x@
      ((ret=wbeg+${#BASH_REMATCH}))
      return 0
    fi
  fi

  ret=$wbeg
  return 1
}

#==============================================================================
# Analysis department

_ble_syntax_vanishing_word_umin=-1
_ble_syntax_vanishing_word_umax=-1
function ble/syntax/vanishing-word/register {
  local tree_array=$1 tofs=$2
  local beg=$3 end=$4 lbeg=$5 lend=$6
  (((beg<=0)&&(beg=1)))

  local node i nofs
  for ((i=end;i>=beg;i--)); do
    builtin eval "node=(\${$tree_array[tofs+i-1]})"
    ((${#node[@]})) || continue
    for ((nofs=0;nofs<${#node[@]};nofs+=_ble_syntax_TREE_WIDTH)); do
      local wtype=${node[nofs]} wlen=${node[nofs+1]}
      local wbeg=$((wlen<0?wlen:i-wlen)) wend=$i

      ((wbeg<lbeg&&(wbeg=lbeg),
        wend>lend&&(wend=lend)))
      ble/syntax/urange#update _ble_syntax_vanishing_word_ "$wbeg" "$wend"
    done
  done
}

#----------------------------------------------------------
# shift

## @var[in] shift2_j
## @var[in] beg,end,end0,shift
function ble/syntax/parse/shift.stat {
  if [[ ${_ble_syntax_stat[shift2_j]} ]]; then
    local -a stat; ble/string#split-words stat "${_ble_syntax_stat[shift2_j]}"

    local k klen kbeg
    for k in 1 3 4 5; do # wlen nlen tclen tplen
      (((klen=stat[k])<0)) && continue
      ((kbeg=shift2_j-klen))
      if ((kbeg<beg)); then
        ((stat[k]+=shift))
      elif ((kbeg<end0)); then
        ((stat[k]-=end0-kbeg))
      fi
    done

    _ble_syntax_stat[shift2_j]="${stat[*]}"
  fi
}

## @var[in] node,shift2_j,nofs
## @var[in] beg,end,end0,shift
function ble/syntax/parse/shift.tree/1 {
  local k klen kbeg
  for k in 1 2 3; do # wlen/nlen tclen tplen
    ((klen=node[nofs+k]))
    ((klen<0||(kbeg=shift2_j-klen)>end0)) && continue
    # It comes here when the length changes (k==1) or when the distance of the syntax tree changes (k==2, k==3).

    # (1) Record changes in word content
    #   When the contents of node are rewritten (when wbegin < end0):
    #   Instead of dirty expansion, just register it in _ble_syntax_word_umax.
    if [[ $k == 1 && ${node[nofs]} =~ ^[0-9]$ ]]; then
      ble/syntax/parse/touch-updated-word "$shift2_j"

      # clear coloring information
      node[nofs+4]='-'
    fi

    # (1) Correction of length and relative position
    if ((kbeg<beg)); then
      ((node[nofs+k]+=shift))
    elif ((kbeg<end0)); then
      ((node[nofs+k]-=end0-kbeg))
    fi
  done
}

## @var[in] shift2_j
## @var[in] beg,end,end0,shift
function ble/syntax/parse/shift.tree {
  [[ ${_ble_syntax_tree[shift2_j-1]} ]] || return 1
  local -a node
  ble/string#split-words node "${_ble_syntax_tree[shift2_j-1]}"

  local nofs
  if [[ $1 ]]; then
    nofs=$1 ble/syntax/parse/shift.tree/1
  else
    for ((nofs=0;nofs<${#node[@]};nofs+=_ble_syntax_TREE_WIDTH)); do
      ble/syntax/parse/shift.tree/1
    done
  fi

  _ble_syntax_tree[shift2_j-1]="${node[*]}"
}

## @var[in] shift2_j
## @var[in] beg,end,end0,shift
function ble/syntax/parse/shift.nest {
  # Nest-pushing is also performed at places other than the beginning of stat
  #   @ ctx-command/check-word-begin in "function name (").
  if [[ ${_ble_syntax_nest[shift2_j]} ]]; then
    local -a nest
    ble/string#split-words nest "${_ble_syntax_nest[shift2_j]}"

    local k klen kbeg
    for k in 1 3 4 5; do
      (((klen=nest[k])))
      ((klen<0||(kbeg=shift2_j-klen)<0)) && continue
      if ((kbeg<beg)); then
        ((nest[k]+=shift))
      elif ((kbeg<end0)); then
        ((nest[k]-=end0-kbeg))
      fi
    done

    _ble_syntax_nest[shift2_j]="${nest[*]}"
  fi
}

function ble/syntax/parse/shift.impl2/.shift-until {
  local limit=$1
  while ((shift2_j>=limit)); do
    [[ $bleopt_syntax_debug ]] && _ble_syntax_stat_shift[shift2_j+shift]=1
    ble/syntax/parse/shift.stat
    ble/syntax/parse/shift.nest
    ((shift2_j--))
  done
}

## @fn ble/syntax/parse/shift.impl2/.proc1
##
## @var[in] TE_i
##   A variable set by tree-enumerate.
##   Represents the terminal boundary of the word currently being processed.
##   Word information is stored in _ble_syntax_tree[TE_i-1].
##
## @var[in,out] shift2_j Stores how far it has been processed.
##
## @var[in]     i1,i2,j2,iN
## @var[in]     beg,end,end0,shift
##   These variables are further used in child functions.
##
function ble/syntax/parse/shift.impl2/.proc1 {
  if ((TE_i<j2)); then
    ((tprev=-1)) # interruption
    return 0
  fi

  ble/syntax/parse/shift.impl2/.shift-until "$((TE_i+1))"
  ble/syntax/parse/shift.tree "$TE_nofs"

  if ((tprev>end0&&wbegin>end0)) && [[ ${wtype//[0-9]} ]]; then
    # skip possible
    #   When it is a word (wtype=integer), nlen may have an external reference.
    #   Note that if tprev<=end0, tplen in stat may be the target of shift.
    [[ $bleopt_syntax_debug ]] && _ble_syntax_stat_shift[shift2_j+shift]=1
    ble/syntax/parse/shift.stat
    ble/syntax/parse/shift.nest
    ((shift2_j=wbegin)) # skip
  elif ((tchild>=0)); then
    ble/syntax/tree-enumerate-children ble/syntax/parse/shift.impl2/.proc1
  fi
}

function ble/syntax/parse/shift.method1 {
  # shift (shift is completed every time. It does not exit in the middle)
  local i j
  for ((i=i2,j=j2;i<=iN;i++,j++)); do
    # Note: Data range
    #   stat[i] is i in [0,iN]
    #   attr[i] is i in [0,iN)
    #   tree[i-1] is i in (0,iN]
    local shift2_j=$j
    ble/syntax/parse/shift.stat
    ((j>0))  && ble/syntax/parse/shift.tree
    ((i<iN)) && ble/syntax/parse/shift.nest
  done
}

function ble/syntax/parse/shift.method2 {
  [[ $bleopt_syntax_debug ]] && _ble_syntax_stat_shift=()

  local iN=${#_ble_syntax_text} # tree-enumerate starting point is (length of old text)
  local shift2_j=$iN # Variables passed to proc1
  ble/syntax/tree-enumerate ble/syntax/parse/shift.impl2/.proc1
  ble/syntax/parse/shift.impl2/.shift-until "$j2" # Unprocessed part
}

## @var[in] i1,i2,j2,iN
## @var[in] beg,end,end0,shift
function ble/syntax/parse/shift {
  # * Even with shift==0, it is necessary to shrink the part that disappeared due to the update.
  #   shift needs to be executed.

  # ble/syntax/parse/shift.method1 # Direct search
  ble/syntax/parse/shift.method2 # skip with tree-enumerate

  if ((shift!=0)); then
    # shift of update range
    ble/syntax/urange#shift _ble_syntax_attr_
    ble/syntax/wrange#shift _ble_syntax_word_
    ble/syntax/wrange#shift _ble_syntax_word_defer_
    ble/syntax/urange#shift _ble_syntax_vanishing_word_
  fi
}

#----------------------------------------------------------
# parse

_ble_syntax_dbeg=-1 _ble_syntax_dend=-1

## @fn ble/syntax/parse/determine-parse-range
##
##   @var[out] i1 i2 j2
##
##   @var[in] beg end end0
##   @var[in] _ble_syntax_dbeg
##   @var[in] _ble_syntax_dend
##     Specify the range of changes in the string and the range left unfinished by the previous analysis.
##
function ble/syntax/parse/determine-parse-range {
  local flagSeekStat=0
  ((i1=_ble_syntax_dbeg,i1>=end0&&(i1+=shift),
    i2=_ble_syntax_dend,i2>=end0&&(i2+=shift),
    (i1<0||beg<i1)&&(i1=beg,flagSeekStat=1),
    (i2<0||i2<end)&&(i2=end),
    (i2>iN)&&(i2=iN),
    j2=i2-shift))

  if ((flagSeekStat)); then
    # Go back to the last stat before beg
    local lookahead='stat[7]'
    local -a stat
    while ((i1>0)); do
      if [[ ${_ble_syntax_stat[--i1]} ]]; then
        ble/string#split-words stat "${_ble_syntax_stat[i1]}"
        ((i1+lookahead<=beg)) && break
      fi
    done
  fi

  ble/util/assert '((0<=i1&&i1<=beg&&end<=i2&&i2<=iN))' "X2 0 <= $i1 <= $beg <= $end <= $i2 <= $iN"
}

function ble/syntax/parse/check-end {
  [[ ${_ble_syntax_context_end[ctx]} ]] && "${_ble_syntax_context_end[ctx]}"
}

## @fn ble/syntax/parse text opts [beg end end0]
##
##   @param[in]     text
##     Specify the string to be parsed.
##
##   @param[in]     opts
##     Specify options that control fine-grained behavior.
##
##   @param[in] beg text change range starting point (default = start of text)
##   @param[in] end text change range end point (default = end of text)
##   @param[in] end0 For when length changes (default value = end)
##     These arguments are used to communicate the range of changes to the text.
##
##   @var [in,out] _ble_syntax_dbeg Analysis planned range starting point (initial value -1 = no analysis planned)
##   @var [in,out] _ble_syntax_dend End point of planned analysis range (Initial value -1 = No analysis planned)
## These variables record which parts need to be analyzed.
##     Even if you specify the change range of text using beg end beg2 end2,
##     The analysis for the change range will not be completed immediately, but will be updated sequentially.
##     Information about the unfinished analysis range from the previous parse call is stored here.
##
##   @var [in,out] _ble_syntax_stat[] (internal use) Records the status during analysis.
##   @var [in,out] _ble_syntax_nest[] (internal use) records nested structure
##   @var [in,out] _ble_syntax_attr[] Attributes for each character
##   @var [in,out] _ble_syntax_tree[] Records shell word information
##     These variables store the analysis results.
##
##   @var  [in,out] _ble_syntax_attr_umin
##   @var  [in,out] _ble_syntax_attr_umax
##   @var  [in,out] _ble_syntax_word_umin
##   @var  [in,out] _ble_syntax_word_umax
##     Updates the range of grammatical interpretation changes caused by this call.
##
function ble/syntax/parse {
  local text=$1 iN=${#1}
  local opts=$2
  local beg=${3:-0} end=${4:-$iN} end0=${5:-0}
  ((end==beg&&end0==beg&&_ble_syntax_dbeg<0)) && return 0

  local IFS=$_ble_term_IFS

  local shift=$((end-end0))
  ble/util/assert \
    '((0<=beg&&beg<=end&&end<=iN&&beg<=end0))' \
    "X1 0 <= beg:$beg <= end:$end <= iN:$iN, beg:$beg <= end0:$end0 (shift=$shift text=$text)" ||
    ((beg=0,end=iN))

  # Update of planned analysis range
  #   @var i1 Start of analysis range
  #   @var i2 End of range required for analysis (analysis ends when the context matches after this point)
  #   @var j2 Analysis end before shift
  local i1 i2 j2
  ble/syntax/parse/determine-parse-range

  ble/syntax/vanishing-word/register _ble_syntax_tree 0 "$i1" "$j2" 0 "$i2"

  ble/syntax/parse/shift

  # Restoration of mid-analysis state
  local ctx wbegin wtype inest tchild tprev nparam ilook
  if ((i1>0)) && [[ ${_ble_syntax_stat[i1]} ]]; then
    local -a stat
    ble/string#split-words stat "${_ble_syntax_stat[i1]}"
    local wlen=${stat[1]} nlen=${stat[3]} tclen=${stat[4]} tplen=${stat[5]}
    ctx=${stat[0]}
    wbegin=$((wlen<0?wlen:i1-wlen))
    wtype=${stat[2]}
    inest=$((nlen<0?nlen:i1-nlen))
    tchild=$((tclen<0?tclen:i1-tclen))
    tprev=$((tplen<0?tplen:i1-tplen))
    nparam=${stat[6]}; [[ $nparam == none ]] && nparam=
    ilook=$((i1+${stat[7]:-1}))
  else
    # Initial value
    ctx=$_ble_ctx_UNSPECIFIED ##!< Context of current analysis
    ble/syntax:"$_ble_syntax_lang"/initialize-ctx # ctx initialization
    wbegin=-1       ##!< When inside a shell word, the start position of the shell word
    wtype=-1        ##!< When inside a shell word, type of shell word
    inest=-1        ##!< When nested, parent's starting position
    tchild=-1
    tprev=-1
    nparam=
    ilook=1
  fi

  # Parts that have been analyzed previously [0,i1), [i2,iN)
  local -a tail_syntax_stat tail_syntax_tree tail_syntax_nest tail_syntax_attr
  tail_syntax_stat=("${_ble_syntax_stat[@]:j2:iN-i2+1}")
  tail_syntax_tree=("${_ble_syntax_tree[@]:j2:iN-i2}")
  tail_syntax_nest=("${_ble_syntax_nest[@]:j2:iN-i2}")
  tail_syntax_attr=("${_ble_syntax_attr[@]:j2:iN-i2}")
  ble/array#reserve-prototype "$iN"
  _ble_syntax_stat=("${_ble_syntax_stat[@]::i1}" "${_ble_array_prototype[@]:i1:iN-i1}") # Resume data
  _ble_syntax_tree=("${_ble_syntax_tree[@]::i1}" "${_ble_array_prototype[@]:i1:iN-i1}") # word
  _ble_syntax_nest=("${_ble_syntax_nest[@]::i1}" "${_ble_array_prototype[@]:i1:iN-i1}") # nested parent
  _ble_syntax_attr=("${_ble_syntax_attr[@]::i1}" "${_ble_array_prototype[@]:i1:iN-i1}") # Context/color etc.

  ble/syntax:"$_ble_syntax_lang"/initialize-vars

  # analysis
  _ble_syntax_text=$text
  local i sstat tail
  local debug_p1
  for ((i=i1;i<iN;)); do
    ble/syntax/parse/serialize-stat
    if ((i>=i2)) && [[ ${tail_syntax_stat[i-i2]} == "$sstat" ]]; then
      if ble/syntax/parse/nest-equals "$inest"; then
        # When the state is the same as the previous analysis → The rest are the same as the previous results
        _ble_syntax_stat=("${_ble_syntax_stat[@]::i}" "${tail_syntax_stat[@]:i-i2}")
        _ble_syntax_tree=("${_ble_syntax_tree[@]::i}" "${tail_syntax_tree[@]:i-i2}")
        _ble_syntax_nest=("${_ble_syntax_nest[@]::i}" "${tail_syntax_nest[@]:i-i2}")
        _ble_syntax_attr=("${_ble_syntax_attr[@]::i}" "${tail_syntax_attr[@]:i-i2}")
        break
      fi
    fi
    _ble_syntax_stat[i]=$sstat

    tail=${text:i}
    debug_p1=$i
    # processing
    "${_ble_syntax_context_proc[ctx]}" || ((_ble_syntax_attr[i]=_ble_attr_ERR,i++))

    # It may become CMDI/ARGI with nest-pop,
    # Also, FCTX may fail even if the character is the end of a word (if it is unrecognized), so
    # Check for word endings here (not inside or immediately after FCTX)
    ble/syntax/parse/check-end
  done
  builtin unset -v debug_p1

  ble/syntax/vanishing-word/register tail_syntax_tree "$((-i2))" "$((i2+1))" "$i" 0 "$i"

  ble/syntax/urange#update _ble_syntax_attr_ "$i1" "$i"

  (((i>=i2)?(
      _ble_syntax_dbeg=_ble_syntax_dend=-1
    ):(
      _ble_syntax_dbeg=i,_ble_syntax_dend=i2)))

  # Recording of termination status
  if ((i>=iN)); then
    ((i=iN))
    ble/syntax/parse/serialize-stat
    _ble_syntax_stat[i]=$sstat

    # Error display at nest start point is in +syntax.
    # If you set it here, you will not be able to cancel it when making a partial update.
    if ((inest>0)); then
      ((_ble_syntax_attr[iN-1]=_ble_attr_ERR))
      while ((inest>=0)); do
        ((i=inest))
        ble/syntax/parse/nest-pop
        ((inest>=i&&(inest=i-1)))
      done
    fi
  fi

  ble/util/assert \
    '((${#_ble_syntax_stat[@]}==iN+1))' \
    "unexpected array length #arr=${#_ble_syntax_stat[@]} (expected to be $iN), #proto=${#_ble_array_prototype[@]} should be >= $iN"
}

## @fn ble/syntax/highlight text [lang]
##   @param[in] text
##   @param[in] lang
##   @var[out] ret
function ble/syntax/highlight {
  local text=$1 lang=${2:-bash} cache_prefix=$3

  local -a _ble_highlight_layer_list=(plain syntax)
  local -a vars=()
  ble/array#push vars "${_ble_syntax_VARNAMES[@]}"
  ble/array#push vars "${_ble_highlight_layer_plain_VARNAMES[@]}"
  ble/array#push vars "${_ble_highlight_layer_syntax_VARNAMES[@]}"

  local "${vars[@]/%/=}" # WA #D1570 checked
  if [[ $cache_prefix ]] && ((${cache_prefix}_INITIALIZED++)); then
    ble/util/restore-vars "$cache_prefix" "${vars[@]}"

    ble/string#common-prefix "$_ble_syntax_text" "$text"
    local beg=${#ret}
    ble/string#common-suffix "${_ble_syntax_text:beg}" "${text:beg}"
    local end=$((${#text}-${#ret})) end0=$((${#_ble_syntax_text}-${#ret}))
  else
    ble/syntax/initialize-vars
    ble/highlight/layer:plain/initialize-vars
    ble/highlight/layer:syntax/initialize-vars
    _ble_syntax_lang=$lang
    local beg=0 end=${#text} end0=0
  fi

  ble/syntax/parse "$text" '' "$beg" "$end" "$end0"

  local HIGHLIGHT_BUFF HIGHLIGHT_UMIN HIGHLIGHT_UMAX
  ble/highlight/layer/update "$text" '' "$beg" "$end" "$end0"
  IFS= builtin eval "ret=\"\${$HIGHLIGHT_BUFF[*]}\""

  [[ $cache_prefix ]] &&
    ble/util/save-vars "$cache_prefix" "${vars[@]}"
  return 0
}

#==============================================================================
#
# syntax-complete
#
#==============================================================================

# ## @fn ble/syntax/getattr index
# function ble/syntax/getattr {
#   local i
#   attr=
#   for ((i=$1;i>=0;i--)); do
#     if [[ ${_ble_syntax_attr[i]} ]]; then
#       ((attr=_ble_syntax_attr[i]))
#       return 0
#     fi
#   done
#   return 1
# }

# ## @fn ble/syntax/getstat index
# function ble/syntax/getstat {
#   local i
#   for ((i=$1;i>=0;i--)); do
#     if [[ ${_ble_syntax_stat[i]} ]]; then
#       ble/string#split-words stat "${_ble_syntax_stat[i]}"
#       return 0
#     fi
#   done
#   return 1
# }

function ble/syntax/completion-context/add {
  local source=$1
  local comp1=$2
  ble/util/assert '[[ $source && comp1 -ge 0 ]]'
  sources[${#sources[*]}]="$source $comp1"
}

## @fn ble/syntax/completion-context/.check/parameter-expansion
##   @var[in] text istat index ctx
function ble/syntax/completion-context/.check/parameter-expansion {
  local rex_paramx='^(\$(\{[!#]?)?)([_a-zA-Z][_a-zA-Z0-9]*)?$'
  if [[ ${text:istat:index-istat} =~ $rex_paramx ]]; then
    local rematch1=${BASH_REMATCH[1]}
    local source=variable
    if [[ $rematch1 == '${'* ]]; then
      source=variable:b # suffix }
    elif ((ctx==_ble_ctx_BRACE1||ctx==_ble_ctx_BRACE2)); then
      source=variable:n # no suffix
    fi
    ble/syntax/completion-context/add "$source" "$((istat+${#rematch1}))"
  fi
}

## @fn ble/syntax/completion-context/prefix:*
##
##   @var[in] text index
##     Specifies the command line to be completed and the current cursor position.
##
##   @var[in] istat stat
##     Specify the location of the previous analysis restart point and the recorded information.
##
##   @var[in] ctx wbeg wlen
##     Context of the previous analysis restart point, word start point,
##     Specifies the length of the word at the previous parsing restart point.
##
##   @var[in] rex_param
##

## @fn ble/syntax/completion-context/prefix:inside-command
##   Generate complementary context for CMDI family (command continuation) context
_ble_syntax_completion_context_check_prefix[_ble_ctx_CMDI]=inside-command
function ble/syntax/completion-context/prefix:inside-command {
  if ((wlen>=0)); then
    ble/syntax/completion-context/add command "$wbeg"
  fi
  ble/syntax/completion-context/.check/parameter-expansion
}
## @fn ble/syntax/completion-context/prefix:inside-argument source
##   Generating complementary contexts for ARGI family (argument continuation) contexts
##   @param[in] source
_ble_syntax_completion_context_check_prefix[_ble_ctx_ARGI]='inside-argument argument'
_ble_syntax_completion_context_check_prefix[_ble_ctx_ARGQ]='inside-argument argument'
_ble_syntax_completion_context_check_prefix[_ble_ctx_FARGI1]='inside-argument variable:w'
_ble_syntax_completion_context_check_prefix[_ble_ctx_FARGI3]='inside-argument argument'
_ble_syntax_completion_context_check_prefix[_ble_ctx_FARGQ3]='inside-argument argument'
_ble_syntax_completion_context_check_prefix[_ble_ctx_CARGI1]='inside-argument argument'
_ble_syntax_completion_context_check_prefix[_ble_ctx_CARGQ1]='inside-argument argument'
_ble_syntax_completion_context_check_prefix[_ble_ctx_CPATI]='inside-argument argument'
_ble_syntax_completion_context_check_prefix[_ble_ctx_CPATQ]='inside-argument argument'
_ble_syntax_completion_context_check_prefix[_ble_ctx_COARGI]='inside-argument variable command:V'
_ble_syntax_completion_context_check_prefix[_ble_ctx_VALI]='inside-argument sabbrev file'
_ble_syntax_completion_context_check_prefix[_ble_ctx_VALQ]='inside-argument sabbrev file'
_ble_syntax_completion_context_check_prefix[_ble_ctx_CONDI]='inside-argument sabbrev file option'
_ble_syntax_completion_context_check_prefix[_ble_ctx_CONDQ]='inside-argument sabbrev file'
_ble_syntax_completion_context_check_prefix[_ble_ctx_ARGVI]='inside-argument sabbrev variable:='
_ble_syntax_completion_context_check_prefix[_ble_ctx_ARGEI]='inside-argument command:D file'
function ble/syntax/completion-context/prefix:inside-argument {
  if ((wlen>=0)); then
    local source
    for source; do
      ble/syntax/completion-context/add "$source" "$wbeg"
      if [[ $source != argument ]]; then
        local sub=${text:wbeg:index-wbeg}
        if [[ $sub == *[=:]* ]]; then
          sub=${sub##*[=:]}
          ble/syntax/completion-context/add "$source" "$((index-${#sub}))"
        fi
      fi
    done
  fi
  ble/syntax/completion-context/.check/parameter-expansion
}

## @fn ble/syntax/completion-context/prefix:next-command
##   Generating complementary contexts for CMDX lineage contexts
_ble_syntax_completion_context_check_prefix[_ble_ctx_CMDX]=next-command
_ble_syntax_completion_context_check_prefix[_ble_ctx_CMDX1]=next-command
_ble_syntax_completion_context_check_prefix[_ble_ctx_CMDXT]=next-command
_ble_syntax_completion_context_check_prefix[_ble_ctx_CMDXV]=next-command
function ble/syntax/completion-context/.check-prefix/.test-redirection {
  ##   @var[in] index
  local word=$1
  [[ $word =~ ^$_ble_syntax_bash_RexRedirect$ ]] || return 1
  # Grammatically speaking, redirects are not allowed.
  ((ctx==_ble_ctx_CMDXC||ctx==_ble_ctx_CMDXD||ctx==_ble_ctx_CMDXD0||ctx==_ble_ctx_FARGX3)) && return 0

  local rematch3=${BASH_REMATCH[3]}
  case $rematch3 in
  ('>&')
    ble/syntax/completion-context/add fd "$index"
    ble/syntax/completion-context/add file:no-fd "$index" ;;
  (*'&')
    ble/syntax/completion-context/add fd "$index" ;;
  ('<<'|'<<-')
    ble/syntax/completion-context/add wordlist:EOF:END:HERE "$index" ;;
  ('<<<'|*)
    ble/syntax/completion-context/add file "$index" ;;
  esac
  return 0
}
function ble/syntax/completion-context/prefix:next-command {
  # If the previous restart point was CMDX,
  # If there is a command name between you and your current location, it is a command.
  # Note that there may be other things than commands, such as spaces or ;&|.
  local word=${text:istat:index-istat}

  # Check command
  if ble/syntax:bash/simple-word/is-simple-or-open-simple "$word"; then
    # If the word starts with istat
    ble/syntax/completion-context/add command "$istat"

    # Check variables/assignments
    if ble/string#match "$word" '^[_a-zA-Z][_a-zA-Z0-9]*\+?=$'; then
      if ((_ble_bash>=30100)) || [[ $word != *+= ]]; then
        # VAR=<argument>: Generate argument candidates from current position
        ble/syntax/completion-context/add argument "$index"
      fi
    fi
  elif ble/syntax/completion-context/.check-prefix/.test-redirection "$word"; then
    builtin true
  elif [[ $word =~ ^$_ble_syntax_bash_RexSpaces$ ]]; then
    # When the word has not started yet (blank)
    shopt -q no_empty_cmd_completion ||
      ble/syntax/completion-context/add command "$index"
  fi

  ble/syntax/completion-context/.check/parameter-expansion
}
## @fn ble/syntax/completion-context/prefix:next-argument
##   Generating complementary contexts for ARGX lineage contexts
_ble_syntax_completion_context_check_prefix[_ble_ctx_ARGX]=next-argument
_ble_syntax_completion_context_check_prefix[_ble_ctx_CARGX1]=next-argument
_ble_syntax_completion_context_check_prefix[_ble_ctx_CPATX]=next-argument
_ble_syntax_completion_context_check_prefix[_ble_ctx_FARGX3]=next-argument
_ble_syntax_completion_context_check_prefix[_ble_ctx_COARGX]=next-argument
_ble_syntax_completion_context_check_prefix[_ble_ctx_ARGVX]=next-argument
_ble_syntax_completion_context_check_prefix[_ble_ctx_ARGEX]=next-argument
_ble_syntax_completion_context_check_prefix[_ble_ctx_VALX]=next-argument
_ble_syntax_completion_context_check_prefix[_ble_ctx_CONDX]=next-argument
_ble_syntax_completion_context_check_prefix[_ble_ctx_RDRS]=next-argument
function ble/syntax/completion-context/prefix:next-argument {
  local source
  if ((ctx==_ble_ctx_ARGX||ctx==_ble_ctx_CARGX1||ctx==_ble_ctx_FARGX3)); then
    source=(argument)
  elif ((ctx==_ble_ctx_COARGX)); then
    # Note: The reason for using variable instead of variable:w or variable:= is because
    #   Even if a variable name comes after coproc, it is either "variable assignment" or "coproc array name"
    #   I don't know if this is the case, so I'll try not to insert anything for the time being.
    source=(command:V variable)
  elif ((ctx==_ble_ctx_ARGVX)); then
    source=(sabbrev variable:= option)
  elif ((ctx==_ble_ctx_ARGEX)); then
    source=(command:D file)
  elif ((ctx==_ble_ctx_CONDX)); then
    source=(sabbrev file option)
  else
    source=(sabbrev file)
  fi

  local word=${text:istat:index-istat}
  if ble/syntax:bash/simple-word/is-simple-or-open-simple "$word"; then
    # If the word starts with istat
    local src
    for src in "${source[@]}"; do
      ble/syntax/completion-context/add "$src" "$istat"
    done

    if [[ ${source[0]} != argument ]]; then
      # If there is an unquoted '=' in the middle of the argument
      local rex="^([^='\"\$\\{}]|\\.)*="
      if [[ $word =~ $rex ]]; then
        word=${word:${#BASH_REMATCH}}
        ble/syntax/completion-context/add rhs "$((index-${#word}))"
      fi
    fi
  elif ble/syntax/completion-context/.check-prefix/.test-redirection "$word"; then
    builtin true
  elif [[ $word =~ ^$_ble_syntax_bash_RexSpaces$ ]]; then
    # When the word has not started yet (blank)
    local src
    for src in "${source[@]}"; do
      ble/syntax/completion-context/add "$src" "$index"
    done
  fi
  ble/syntax/completion-context/.check/parameter-expansion
}
## @fn ble/syntax/completion-context/prefix:next-compound
##   Complete compound commands.
_ble_syntax_completion_context_check_prefix[_ble_ctx_CMDXC]=next-compound
function ble/syntax/completion-context/prefix:next-compound {
  local rex word=${text:istat:index-istat}
  if [[ ${text:istat:index-istat} =~ $rex_param ]]; then
    ble/syntax/completion-context/add wordlist:-r:'for:select:case:if:while:until' "$istat"
  elif rex='^[[({]+$'; [[ $word =~ $rex ]]; then
    ble/syntax/completion-context/add wordlist:-r:'(:{:((:[[' "$istat"
  fi
}
## @fn ble/syntax/completion-context/prefix:next-identifier source
##   Context completion for simple words without escaping or quoting.
##   @param[in] source
_ble_syntax_completion_context_check_prefix[_ble_ctx_FARGX1]="next-identifier variable:w" # _ble_ctx_FARGX1 → (( If not variable name
_ble_syntax_completion_context_check_prefix[_ble_ctx_SARGX1]="next-identifier variable:w"
function ble/syntax/completion-context/prefix:next-identifier {
  local source=$1 word=${text:istat:index-istat}
  if [[ $word =~ $rex_param ]]; then
    ble/syntax/completion-context/add "$source" "$istat"
  elif [[ $word =~ ^$_ble_syntax_bash_RexSpaces$ ]]; then
    # If the word has not started yet, completion starts from the current position
    ble/syntax/completion-context/add "$source" "$index"
  else
    ble/syntax/completion-context/add none "$istat"
  fi
}
_ble_syntax_completion_context_check_prefix[_ble_ctx_ARGX0]="next-word sabbrev"
_ble_syntax_completion_context_check_prefix[_ble_ctx_CMDX0]="next-word sabbrev"
_ble_syntax_completion_context_check_prefix[_ble_ctx_CPATX0]="next-word sabbrev"
_ble_syntax_completion_context_check_prefix[_ble_ctx_CMDXD0]="next-word wordlist:-rs:';:{:do'"
_ble_syntax_completion_context_check_prefix[_ble_ctx_CMDXD]="next-word wordlist:-rs:'{:do'"
_ble_syntax_completion_context_check_prefix[_ble_ctx_CMDXE]="next-word wordlist:-rs:'}:fi:done:esac:then:elif:else:do'"
_ble_syntax_completion_context_check_prefix[_ble_ctx_CARGX2]="next-word wordlist:-rs:'in'"
_ble_syntax_completion_context_check_prefix[_ble_ctx_CARGI2]="next-word wordlist:-rs:'in'"
_ble_syntax_completion_context_check_prefix[_ble_ctx_FARGX2]="next-word wordlist:-rs:'in:do'"
_ble_syntax_completion_context_check_prefix[_ble_ctx_FARGI2]="next-word wordlist:-rs:'in:do'"
function ble/syntax/completion-context/prefix:next-word {
  local source=$1 word=${text:istat:index-istat} rex=$'^[^ \t]*$'
  if [[ $word =~ ^$_ble_syntax_bash_RexSpaces$ ]]; then
    ble/syntax/completion-context/add "$source" "$index"
  else
    ble/syntax/completion-context/add "$source" "$istat"
  fi
}
## @fn ble/syntax/completion-context/prefix:time-argument
_ble_syntax_completion_context_check_prefix[_ble_ctx_TARGX1]=time-argument
_ble_syntax_completion_context_check_prefix[_ble_ctx_TARGI1]=time-argument
_ble_syntax_completion_context_check_prefix[_ble_ctx_TARGX2]=time-argument
_ble_syntax_completion_context_check_prefix[_ble_ctx_TARGI2]=time-argument
function ble/syntax/completion-context/prefix:time-argument {
  ble/syntax/completion-context/.check/parameter-expansion
  ble/syntax/completion-context/add command "$istat"
  if ((ctx==_ble_ctx_TARGX1)); then
    local rex='^-p?$' words='-p'
    ((_ble_bash>=50100)) &&
      rex='^-[-p]?$' words='-p':'--'
    [[ ${text:istat:index-istat} =~ $rex ]] &&
      ble/syntax/completion-context/add wordlist:--:"$words" "$istat"
  elif ((ctx==_ble_ctx_TARGX2)); then
    local rex='^--?$'
    [[ ${text:istat:index-istat} =~ $rex ]] &&
      ble/syntax/completion-context/add wordlist:--:'--' "$istat"
  fi
}
## @fn ble/syntax/completion-context/prefix:function-name
_ble_syntax_completion_context_check_prefix[_ble_ctx_FNAMEX]=function-name
_ble_syntax_completion_context_check_prefix[_ble_ctx_FNAMEI]=function-name
function ble/syntax/completion-context/prefix:function-name {
  ble/syntax/completion-context/.check/parameter-expansion
  ble/syntax/completion-context/add function "$istat"
}
## @fn ble/syntax/completion-context/prefix:quote
_ble_syntax_completion_context_check_prefix[_ble_ctx_QUOT]=quote
function ble/syntax/completion-context/prefix:quote {
  ble/syntax/completion-context/.check/parameter-expansion
  ble/syntax/completion-context/prefix:quote/.check-container-word
}
function ble/syntax/completion-context/prefix:quote/.check-container-word {
  # Note: _ble_ctx_QUOTE is inside the nest, so go outside and search for the word.

  local nlen=${stat[3]}; ((nlen>=0)) || return 1
  local inest=$((nlen<0?nlen:istat-nlen))

  local nest; ble/string#split-words nest "${_ble_syntax_nest[inest]}"
  [[ ${nest[0]} ]] || return 1

  local wlen2=${nest[1]}; ((wlen2>=0)) || return 1
  local wbeg2=$((wlen2<0?wlen2:inest-wlen2))
  if ble/syntax:bash/simple-word/is-simple-or-open-simple "${text:wbeg2:index-wbeg2}"; then
    local wt=${nest[2]}
    [[ ${_ble_syntax_bash_command_EndWtype[wt]} ]] &&
      wt=${_ble_syntax_bash_command_EndWtype[wt]}
    if ((wt==_ble_ctx_CMDI)); then
      ble/syntax/completion-context/add command "$wbeg2"
    elif ((wt==_ble_ctx_ARGI||wt==_ble_ctx_ARGVI||wt==_ble_ctx_ARGEI||wt==_ble_ctx_FARGI2||wt==_ble_ctx_CARGI2)); then
      ble/syntax/completion-context/add argument "$wbeg2"
    elif ((wt==_ble_ctx_CPATI)); then # inside case pattern
      #ble/syntax/completion-context/add file "$wbeg2"
      return 0
    fi
  fi
}

## @fn ble/syntax/completion-context/prefix:redirection
##   Context to complete the filename part of redirect
_ble_syntax_completion_context_check_prefix[_ble_ctx_RDRF]=redirection
_ble_syntax_completion_context_check_prefix[_ble_ctx_RDRD2]=redirection
_ble_syntax_completion_context_check_prefix[_ble_ctx_RDRD]=redirection
function ble/syntax/completion-context/prefix:redirection {
  ble/syntax/completion-context/.check/parameter-expansion
  local p=$((wlen>=0?wbeg:istat))
  if ble/syntax:bash/simple-word/is-simple-or-open-simple "${text:p:index-p}"; then
    if ((ctx==_ble_ctx_RDRF)); then
      ble/syntax/completion-context/add file "$p"
    elif ((ctx==_ble_ctx_RDRD)); then
      ble/syntax/completion-context/add fd "$p"
    elif ((ctx==_ble_ctx_RDRD2)); then
      ble/syntax/completion-context/add fd "$p"
      ble/syntax/completion-context/add file:no-fd "$p"
    fi
  fi
}
_ble_syntax_completion_context_check_prefix[_ble_ctx_RDRH]=here
_ble_syntax_completion_context_check_prefix[_ble_ctx_RDRI]=here
function ble/syntax/completion-context/prefix:here {
  local p=$((wlen>=0?wbeg:istat))
  ble/syntax/completion-context/add wordlist:EOF:END:HERE "$p"
}


## @fn ble/syntax/completion-context/prefix:rhs
##   Context that completes the value part of VAR=value
_ble_syntax_completion_context_check_prefix[_ble_ctx_VRHS]=rhs
_ble_syntax_completion_context_check_prefix[_ble_ctx_ARGVR]=rhs
_ble_syntax_completion_context_check_prefix[_ble_ctx_ARGER]=rhs
_ble_syntax_completion_context_check_prefix[_ble_ctx_VALR]=rhs
function ble/syntax/completion-context/prefix:rhs {
  ble/syntax/completion-context/.check/parameter-expansion
  if ((wlen>=0)); then
    local p=$wbeg
    local rex='^[_a-zA-Z0-9]+(\+?=|\[)'
    ((ctx==_ble_ctx_VALR)) && rex='^(\[)'
    if [[ ${text:p:index-p} =~ $rex ]]; then
      if [[ ${BASH_REMATCH[1]} == '[' ]]; then
        # _ble_ctx_VRHS:  arr[0]=x@ arr[1]+=x@
        # _ble_ctx_ARGVR: declare arr[0]=x@ arr[1]+=x@
        # _ble_ctx_VALR:  arr=([0]=x@ [1]+=x@)
        local p1=$((wbeg+${#BASH_REMATCH}-1))
        if local ret; ble/syntax:bash/find-end-of-array-index "$p1" "$index"; then
          local p2=$ret
          case ${_ble_syntax_text:p2:index-p2} in
          (']='*)  ((p=p2+2)) ;;
          (']+='*) ((p=p2+3)) ;;
          (']+')
            ble/syntax/completion-context/add wordlist:-rW:'+=' "$((p2+1))"
            p= ;;
          esac
        fi
      else
        # _ble_ctx_VRHS:  var=x@ var+=x@
        # _ble_ctx_ARGVR: declare var=x@ var+=x@
        ((p+=${#BASH_REMATCH}))
      fi
    fi
  else
    local p=$istat
  fi

  if [[ $p ]] && ble/syntax:bash/simple-word/is-simple-or-open-simple "${text:p:index-p}"; then
    ble/syntax/completion-context/add rhs "$p"
  fi
}

_ble_syntax_completion_context_check_prefix[_ble_ctx_PARAM]=param
function ble/syntax/completion-context/prefix:param {
  local tail=${text:istat:index-istat}
  if [[ $tail == : ]]; then
    return 0
  elif [[ $tail == '}'* ]]; then
    local nlen=${stat[3]}
    local inest=$((nlen<0?nlen:istat-nlen))
    ((0<=inest&&inest<istat)) &&
      ble/syntax/completion-context/.check-prefix "$inest"
    return "$?"
  else
    return 1
  fi
}

## @fn ble/syntax/completion-context/prefix:expr
##   Context to complete variable names in formulas
_ble_syntax_completion_context_check_prefix[_ble_ctx_EXPR]=expr
function ble/syntax/completion-context/prefix:expr {
  local tail=${text:istat:index-istat} rex='[_a-zA-Z]+$'
  if [[ $tail =~ $rex ]]; then
    local p=$((index-${#BASH_REMATCH}))
    ble/syntax/completion-context/add variable:a "$p"
    return 0
  elif [[ $tail == ']'* ]]; then
    local inest=... ntype
    local nlen=${stat[3]}; ((nlen>=0)) || return 1
    local inest=$((istat-nlen))
    ble/syntax/parse/nest-type # ([in] inest; [out] ntype)

    if [[ $ntype == [ad]'[' ]]; then
      # arr[...]=@ or arr=([...]=@)
      if [[ $tail == ']' ]]; then
        ble/syntax/completion-context/add wordlist:-rW:'=' "$((istat+1))"
      elif ((_ble_bash>=30100)) && [[ $tail == ']+' ]]; then
        ble/syntax/completion-context/add wordlist:-rW:'+=' "$((istat+1))"
      elif [[ $tail == ']=' || _ble_bash -ge 30100 && $tail == ']+=' ]]; then
        ble/syntax/completion-context/add rhs "$index"
      fi
    fi
  fi
}

## @fn ble/syntax/completion-context/prefix:expr
##   Completion within brace expansion
_ble_syntax_completion_context_check_prefix[_ble_ctx_BRACE1]=brace
_ble_syntax_completion_context_check_prefix[_ble_ctx_BRACE2]=brace
function ble/syntax/completion-context/prefix:brace {
  # (1) Leave the nest until it becomes other than _ble_ctx_BRACE{1,2}
  local ctx1=$ctx istat1=$istat nlen1=${stat[3]}
  ((nlen1>=0)) || return 1
  local inest1=$((istat1-nlen1))
  while ((1)); do
    local nest=${_ble_syntax_nest[inest1]}
    [[ $nest ]] || return 1
    ble/string#split-words nest "$nest"
    ctx1=${nest[0]}
    ((ctx1==_ble_ctx_BRACE1||ctx1==_ble_ctx_BRACE2)) || break
    inest1=$((nest[3]<0?nest[3]:inest1-nest[3]))
    ((inest1>=0)) || return 1
  done

  # (2) Last stat
  for ((istat1=inest1;1;istat1--)); do
    ((istat1>=0)) || return 1
    [[ ${_ble_syntax_stat[istat1]} ]] && break
  done

  # (3) Word starting point
  local stat1
  ble/string#split-words stat1 "${_ble_syntax_stat[istat1]}"
  local wlen=${stat1[1]}
  local wbeg=$((wlen>=0?istat1-wlen:istat1))

  ble/syntax/completion-context/.check/parameter-expansion
  ble/syntax/completion-context/add argument "$wbeg"
}


## @fn ble/syntax/completion-context/.search-last-istat index
##   @param[in] index
##   @var[out] ret
function ble/syntax/completion-context/.search-last-istat {
  local index=$1 istat
  for ((istat=index;istat>=0;istat--)); do
    if [[ ${_ble_syntax_stat[istat]} ]]; then
      ret=$istat
      return 0
    fi
  done
  ret=
  return 1
}

## @fn ble/syntax/completion-context/.check-prefix from
##   @param[in,opt] from
##   @var[in] text
##   @var[in] index
##   @var[out] sources
function ble/syntax/completion-context/.check-prefix {
  local rex_param='^[_a-zA-Z][_a-zA-Z0-9]*$'
  local from=${1:-$((index-1))}

  local ret
  ble/syntax/completion-context/.search-last-istat "$from" || return 1
  local istat=$ret stat
  ble/string#split-words stat "${_ble_syntax_stat[istat]}"
  [[ ${stat[0]} ]] || return 1

  local ctx=${stat[0]} wlen=${stat[1]}
  local wbeg=$((wlen<0?wlen:istat-wlen))
  local name=${_ble_syntax_completion_context_check_prefix[ctx]}
  if [[ $name ]]; then
    builtin eval ble/syntax/completion-context/prefix:"$name"
  fi
}

## @fn ble/syntax/completion-context/here:*
##
##   @var[in] text index
##     Specifies the command line to be completed and the current cursor position.
##

function ble/syntax/completion-context/here:add {
  local source
  for source; do
    ble/syntax/completion-context/add "$source" "$index"
  done
}

_ble_syntax_completion_context_check_here[_ble_ctx_CMDX]='command'
_ble_syntax_completion_context_check_here[_ble_ctx_CMDXV]='command'
_ble_syntax_completion_context_check_here[_ble_ctx_CMDX1]='command'
_ble_syntax_completion_context_check_here[_ble_ctx_CMDXT]='command'
_ble_syntax_completion_context_check_here[_ble_ctx_CMDXC]='command compound'
_ble_syntax_completion_context_check_here[_ble_ctx_CMDXE]='command end'
_ble_syntax_completion_context_check_here[_ble_ctx_CMDXD0]='command for1'
_ble_syntax_completion_context_check_here[_ble_ctx_CMDXD]='command for2'
function ble/syntax/completion-context/here:command {
  case $1 in
  (compound)
    ble/syntax/completion-context/add wordlist:-rs:'(:{:((:[[:for:select:case:if:while:until' "$index" ;;
  (end)
    ble/syntax/completion-context/add wordlist:-rs:'}:fi:done:esac:then:elif:else:do' "$index" ;;
  (for1)
    ble/syntax/completion-context/add wordlist:-rs:';:{:do' "$index" ;;
  (for2)
    ble/syntax/completion-context/add wordlist:-rs:'{:do' "$index" ;;
  (*)
    if ! shopt -q no_empty_cmd_completion; then
      ble/syntax/completion-context/add command "$index"
    fi ;;
  esac
}

_ble_syntax_completion_context_check_here[_ble_ctx_ARGX]='argument'
_ble_syntax_completion_context_check_here[_ble_ctx_CARGX1]='argument'
_ble_syntax_completion_context_check_here[_ble_ctx_FARGX3]='argument'
_ble_syntax_completion_context_check_here[_ble_ctx_ARGX0]='argument none'
_ble_syntax_completion_context_check_here[_ble_ctx_CPATX0]='argument none'
_ble_syntax_completion_context_check_here[_ble_ctx_CMDX0]='argument none'
_ble_syntax_completion_context_check_here[_ble_ctx_FARGX1]='argument for1'
_ble_syntax_completion_context_check_here[_ble_ctx_SARGX1]='argument for1'
_ble_syntax_completion_context_check_here[_ble_ctx_ARGVX]='argument declare'
_ble_syntax_completion_context_check_here[_ble_ctx_ARGEX]='argument eval'
_ble_syntax_completion_context_check_here[_ble_ctx_CARGX2]='argument case'
_ble_syntax_completion_context_check_here[_ble_ctx_CPATI]='argument case-pattern'
_ble_syntax_completion_context_check_here[_ble_ctx_FARGX2]='argument for2'
_ble_syntax_completion_context_check_here[_ble_ctx_TARGX1]='argument time1'
_ble_syntax_completion_context_check_here[_ble_ctx_TARGX2]='argument time2'
_ble_syntax_completion_context_check_here[_ble_ctx_FNAMEX]='argument function'
_ble_syntax_completion_context_check_here[_ble_ctx_COARGX]='argument coproc'
_ble_syntax_completion_context_check_here[_ble_ctx_CONDX]='argument cond'
function ble/syntax/completion-context/here:argument {
  case $1 in
  (none)
    ble/syntax/completion-context/add sabbrev "$index" ;;
  (for1)
    # for @, select @
    ble/syntax/completion-context/add variable:w "$index"
    ble/syntax/completion-context/add sabbrev "$index" ;;
  (declare)
    # declare @
    ble/syntax/completion-context/add variable:= "$index"
    ble/syntax/completion-context/add option "$index"
    ble/syntax/completion-context/add sabbrev "$index" ;;
  (eval)
    # eval @, eval echo @
    ble/syntax/completion-context/add command:D "$index"
    ble/syntax/completion-context/add file "$index" ;;
  (case)
    # case a @
    ble/syntax/completion-context/add wordlist:-rs:'in' "$index" ;;
  (case-pattern)
    # case a in @
    ble/syntax/completion-context/add file "$index" ;;
  (for2)
    # for a @
    ble/syntax/completion-context/add wordlist:-rs:'in:do' "$index" ;;
  (time1)
    # time @
    local words='-p'
    ((_ble_bash>=50100)) && words='-p':'--'
    ble/syntax/completion-context/add command "$index"
    ble/syntax/completion-context/add wordlist:--:"$words" "$index" ;;
  (time2)
    # time -p @
    ble/syntax/completion-context/add command "$index"
    ble/syntax/completion-context/add wordlist:--:'--' "$index" ;;
  (function)
    # function @
    ble/syntax/completion-context/add function "$index" ;;
  (coproc)
    # coproc @
    ble/syntax/completion-context/add variable:w "$index"
    ble/syntax/completion-context/add command:V "$index" ;;
  (cond)
    # [[ @
    ble/syntax/completion-context/add sabbrev "$index"
    ble/syntax/completion-context/add option "$index"
    ble/syntax/completion-context/add file "$index" ;;
  (*)
    ble/syntax/completion-context/add argument "$index" ;;
  esac
}

# redirections
_ble_syntax_completion_context_check_here[_ble_ctx_RDRF]='add file'
_ble_syntax_completion_context_check_here[_ble_ctx_RDRS]='add file'
_ble_syntax_completion_context_check_here[_ble_ctx_RDRD]='add fd'
_ble_syntax_completion_context_check_here[_ble_ctx_RDRD2]='add fd file:no-fd'
_ble_syntax_completion_context_check_here[_ble_ctx_RDRH]='add wordlist:EOF:END:HERE'
_ble_syntax_completion_context_check_here[_ble_ctx_RDRI]='add wordlist:EOF:END:HERE'

# rhs
_ble_syntax_completion_context_check_here[_ble_ctx_VRHS]='add rhs'
_ble_syntax_completion_context_check_here[_ble_ctx_ARGVR]='add rhs'
_ble_syntax_completion_context_check_here[_ble_ctx_ARGER]='add rhs'
_ble_syntax_completion_context_check_here[_ble_ctx_VALR]='add rhs'

## @fn ble/syntax/completion-context/.check-here
##   Enumerates completion possibilities starting from the current location
##   @var[in]  text
##   @var[in]  index
##   @var[out] sources
function ble/syntax/completion-context/.check-here {
  ((${#sources[*]})) && return 0
  local -a stat
  ble/string#split-words stat "${_ble_syntax_stat[index]}"
  if [[ ${stat[0]-} && ${_ble_syntax_completion_context_check_here[stat[0]]-} ]]; then
    # Note: _ble_ctx_CMDI and _ble_ctx_ARGI are not processed here. Already marked with check-prefix
    #   Because it's supposed to be on.
    #
    # Note (#D1690): Since a complaint occurred, I initially decided not to start completion of arguments on the spot.
    #   However, it became impossible to start completion from an empty string. As expected, here
    #   must begin argument completion with .
    #
    #   In the first place, when a completion context can be generated using .check-prefix, it is possible to generate a completion context regardless of the input content.
    #   A completion context should be generated first. That way, reaching .check-here is
    #   It is limited to situations where there is no other way to generate a complementary context. At this time, actually
    #   No modification was necessary on the .check-here side.
    local proc=${_ble_syntax_completion_context_check_here[stat[0]]-}
    builtin eval ble/syntax/completion-context/here:"$proc"
  fi
}

## @fn ble/syntax/completion-context/generate
##   @var[out] sources[]
function ble/syntax/completion-context/generate {
  local text=$1 index=$2
  sources=()
  ((index<0&&(index=0)))

  ble/syntax/completion-context/.check-prefix
  ble/syntax/completion-context/.check-here
}

#------------------------------------------------------------------------------
# extract-command

## @fn ble/syntax:bash/extract-command/.register-word
## @var[in,out] comp_words, comp_line, comp_point, comp_cword
## @var[in]     TE_i TE_nofs wbegin wlen
function ble/syntax:bash/extract-command/.register-word {
  local wtxt=${_ble_syntax_text:wbegin:wlen}
  if [[ ! $comp_cword ]] && ((wbegin<=EC_pos)); then
    if ((EC_pos<=wbegin+wlen)); then
      comp_cword=${#comp_words[@]}
      comp_point=$((${#comp_line}+wbegin+wlen-EC_pos))
      comp_line="$wtxt$comp_line"
      ble/array#push comp_words "$wtxt"
    else
      comp_cword=${#comp_words[@]}
      comp_point=${#comp_line}
      comp_line="$wtxt $comp_line"
      ble/array#push comp_words "" "$wtxt"
    fi
  else
    comp_line="$wtxt$comp_line"
    ble/array#push comp_words "$wtxt"
  fi
  [[ $EC_opts == *:treeinfo:* ]] &&
    ble/array#push tree_words "$TE_i:$TE_nofs"
}

function ble/syntax:bash/extract-command/.construct-proc {
  if [[ $wtype =~ ^[0-9]+$ ]]; then
    if ((wtype==_ble_ctx_CMDI||wtype==_ble_ctx_CMDX0)); then
      if ((EC_pos<wbegin)); then
        comp_line= comp_point= comp_cword= comp_words=()
        [[ $EC_opts == *:treeinfo:* ]] && tree_words=()
      else
        ble/syntax:bash/extract-command/.register-word
        ble/syntax/tree-enumerate-break
        EC_found=1
        return 0
      fi
    elif ((wtype==_ble_ctx_ARGI||wtype==_ble_ctx_ARGVI||wtype==_ble_ctx_ARGEI||wtype==_ble_attr_VAR)); then
      ble/syntax:bash/extract-command/.register-word
      comp_line=" $comp_line"
    fi
  fi
}

function ble/syntax:bash/extract-command/.construct {
  comp_line= comp_point= comp_cword= comp_words=()
  [[ $EC_opts == *:treeinfo:* ]] && tree_words=()

  if [[ $1 == nested ]]; then
    ble/syntax/tree-enumerate-children \
      ble/syntax:bash/extract-command/.construct-proc
  else
    ble/syntax/tree-enumerate \
      ble/syntax:bash/extract-command/.construct-proc
  fi

  ble/array#reverse comp_words
  ((comp_cword=${#comp_words[@]}-1-comp_cword,
    comp_point=${#comp_line}-comp_point))
  [[ $EC_opts == *:treeinfo:* ]] &&
    ble/array#reverse tree_words
}

## (tree-enumerate-proc) ble/syntax:bash/extract-command/.scan
function ble/syntax:bash/extract-command/.scan {
  ((EC_pos<wbegin)) && return 0

  if ((wbegin+wlen<EC_pos)); then
    ble/syntax/tree-enumerate-break
  else
    local EC_has_word=
    ble/syntax/tree-enumerate-children \
      ble/syntax:bash/extract-command/.scan
    local has_word=$EC_has_word
    ble/util/unlocal EC_has_word

    if [[ $has_word && ! $EC_found ]]; then
      ble/syntax:bash/extract-command/.construct nested
      ble/syntax/tree-enumerate-break
    fi
  fi

  if [[ $wtype =~ ^[0-9]+$ && ! $EC_has_word ]]; then
    EC_has_word=$wtype
    return 0
  fi
}

## @fn ble/syntax:bash/extract-command index [opts]
##   @param[in] index
##   @param[in] opts
##     treeinfo
##       Get syntax tree information for each word that makes up the command.
##       Store the results in the following array.
##       @arr[out] tree_words
##
##   @var[out] comp_cword comp_words comp_line comp_point
function ble/syntax:bash/extract-command {
  local EC_pos=$1 EC_opts=:$2:
  local EC_found=

  local EC_has_word=
  ble/syntax/tree-enumerate \
    ble/syntax:bash/extract-command/.scan
  if [[ ! $EC_found && $EC_has_word ]]; then
    ble/syntax:bash/extract-command/.construct
  fi
  [[ $EC_found ]]
}

#------------------------------------------------------------------------------
# extract-command-by-noderef

## @fn ble/syntax/tree#previous-sibling i[:nofs] [opts]
## @fn ble/syntax/tree#next-sibling     i[:nofs] [opts]
##   Gets the previous or next sibling node for the word at the specified position.
##
##   @param[in] i:nofs
##
##   @param[in] opts
##     Colon-separated options.
##
##     When wvars is specified, information on the found words is stored in the following variables.
##     @var[out] wtype wlen wbeg wend wattr
##
##   @var[out] ret=i:nofs
##
function ble/syntax/tree#previous-sibling {
  local i0=${1%%:*} nofs0=0 opts=:$2:
  [[ $1 == *:* ]] && nofs0=${1#*:}

  local node
  ble/string#split-words node "${_ble_syntax_tree[i0-1]}"
  ble/util/assert '((${#node[@]}>nofs0))' "Broken AST: tree-node info missing at $((i0-1))[$nofs0]" || return 1
  local tplen=${node[nofs0+3]}
  ((tplen>=0)) || return 1

  local i=$((i0-tplen)) nofs=0
  ret=$i:$nofs
  if [[ $opts == *:wvars:* ]]; then
    ble/string#split-words node "${_ble_syntax_tree[i-1]}"
    ble/util/assert '((${#node[@]}>nofs))' "Broken AST: tree-node info missing at $((i-1))[$nofs]" || return 1
    wtype=${node[nofs]}
    wlen=${node[nofs+1]}
    ((wbeg=i-wlen,wend=i))
    wattr=${node[nofs+4]}
  fi
  return 0
}
function ble/syntax/tree#next-sibling {
  local i0=${1%%:*} nofs0=0 opts=:$2:
  [[ $1 == *:* ]] && nofs0=${1#*:}

  # I don't have a younger brother because I'm at the end of the line.
  ((nofs0)) && return 1

  local iN=${#_ble_syntax_text} i nofs node
  for ((i=i0+1;i<=iN;i++)); do
    [[ ${_ble_syntax_tree[i-1]} ]] || continue
    ble/string#split-words node "${_ble_syntax_tree[i-1]}"
    nofs=${#node[@]}
    while (((nofs-=_ble_syntax_TREE_WIDTH)>=0)); do
      # node = (wtype wlen tclen tplen wattr)+
      if ((i0==i-node[nofs+2])); then
        # My parents are found, so I don't have a younger brother.
        return 1
      elif ((i0==i-node[nofs+3])); then
        # this is my brother
        ret=$i:$nofs
        if [[ $opts == *:wvars:* ]]; then
          wtype=${node[nofs]}
          wlen=${node[nofs+1]}
          ((wbeg=i-wlen,wend=i))
          wattr=${node[nofs+4]}
        fi
        return 0
      fi
    done
  done
  return 1
}

## @fn ble/syntax:bash/extract-command-by-noderef i[:nofs] [opts]
##   @param[in] i:nofs
##     Specify the word.
##
##   @param[in] opts
##     Colon-separated options.
##
##     When treeinfo is specified, the position of each word is stored in the following array.
##     Store in "i:nofs" format.
##     @var[out] tree_words
##
##   @var[out] comp_words comp_line comp_cword comp_point
##     Stores the reconstructed command information.
##     Assume that the cursor is at the end of the specified word.
##
function ble/syntax:bash/extract-command-by-noderef {
  local i=${1%%:*} nofs=0 opts=:$2:
  [[ $1 == *:* ]] && nofs=${1#*:}

  # initialize output
  comp_words=()
  tree_words=()
  comp_line=
  comp_cword=0
  comp_point=0

  local ExprIsArgument='wtype==_ble_ctx_ARGI||wtype==_ble_ctx_ARGVI||wtype==_ble_ctx_ARGEI||wtype==_ble_attr_VAR'

  # Add own node
  local ret node wtype wlen wbeg wend wattr
  ble/string#split-words node "${_ble_syntax_tree[i-1]}"
  wtype=${node[nofs]} wlen=${node[nofs+1]}
  [[ ! ${wtype//[0-9]} ]] && ((wtype==_ble_ctx_CMDI||ExprIsArgument)) || return 1
  ble/array#push comp_words "${_ble_syntax_text:i-wlen:wlen}"
  [[ $opts == *:treeinfo:* ]] &&
    ble/array#push tree_words "$i:$nofs"

  # Adding older brother node
  ret=$i:$nofs
  while
    { [[ ${wtype//[0-9]} ]] || ((wtype!=_ble_ctx_CMDI)); } &&
      ble/syntax/tree#previous-sibling "$ret" wvars
  do
    [[ ! ${wtype//[0-9]} ]] || continue
    if ((wtype==_ble_ctx_CMDI||ExprIsArgument)); then
      ble/array#push comp_words "${_ble_syntax_text:wbeg:wlen}"
      [[ $opts == *:treeinfo:* ]] &&
        ble/array#push tree_words "$ret"
    fi
  done
  ble/array#reverse comp_words
  [[ $opts == *:treeinfo:* ]] &&
    ble/array#reverse tree_words

  # Current position (comp_cword, comp_point)
  ((comp_cword=${#comp_words[@]}-1))

  # Searching for younger brother nodes
  ret=$i:$nofs
  while ble/syntax/tree#next-sibling "$ret" wvars; do
    [[ ! ${wtype//[0-9]} ]] || continue
    ((wtype==_ble_ctx_CMDI)) && break
    if ((ExprIsArgument)); then
      ble/array#push comp_words "${_ble_syntax_text:wbeg:wlen}"
      [[ $opts == *:treeinfo:* ]] &&
        ble/array#push tree_words "$ret"
    fi
  done

  local IFS=$_ble_term_IFS
  comp_line="${comp_words[*]}"
  local tmp="${comp_words[*]::comp_cword+1}"
  comp_point=${#tmp}
}

#==============================================================================
#
# syntax-highlight
#
#==============================================================================

# Lazy initialization target
_ble_syntax_attr2iface=()

# lazy initializer
function ble/syntax/attr2iface/color_defface.onload {
  function ble/syntax/attr2iface/.define {
    ((_ble_syntax_attr2iface[$1]=_ble_faces__$2))
  }

  ble/syntax/attr2iface/.define _ble_ctx_UNSPECIFIED syntax_default

  ble/syntax/attr2iface/.define _ble_ctx_ARGX     syntax_default
  ble/syntax/attr2iface/.define _ble_ctx_ARGX0    syntax_default
  ble/syntax/attr2iface/.define _ble_ctx_ARGI     syntax_default
  ble/syntax/attr2iface/.define _ble_ctx_ARGQ     syntax_default
  ble/syntax/attr2iface/.define _ble_ctx_ARGVX    syntax_default
  ble/syntax/attr2iface/.define _ble_ctx_ARGVI    syntax_default
  ble/syntax/attr2iface/.define _ble_ctx_ARGVR    syntax_default
  ble/syntax/attr2iface/.define _ble_ctx_ARGEX    syntax_default
  ble/syntax/attr2iface/.define _ble_ctx_ARGEI    syntax_default
  ble/syntax/attr2iface/.define _ble_ctx_ARGER    syntax_default
  ble/syntax/attr2iface/.define _ble_ctx_CMDX     syntax_default
  ble/syntax/attr2iface/.define _ble_ctx_CMDX0    syntax_default
  ble/syntax/attr2iface/.define _ble_ctx_CMDX1    syntax_default
  ble/syntax/attr2iface/.define _ble_ctx_CMDXT    syntax_default
  ble/syntax/attr2iface/.define _ble_ctx_CMDXC    syntax_default
  ble/syntax/attr2iface/.define _ble_ctx_CMDXE    syntax_default
  ble/syntax/attr2iface/.define _ble_ctx_CMDXD    syntax_default
  ble/syntax/attr2iface/.define _ble_ctx_CMDXD0   syntax_default
  ble/syntax/attr2iface/.define _ble_ctx_CMDXV    syntax_default
  ble/syntax/attr2iface/.define _ble_ctx_CMDI     syntax_command
  ble/syntax/attr2iface/.define _ble_ctx_VRHS     syntax_default
  ble/syntax/attr2iface/.define _ble_ctx_QUOT     syntax_quoted
  ble/syntax/attr2iface/.define _ble_ctx_EXPR     syntax_expr
  ble/syntax/attr2iface/.define _ble_attr_ERR     syntax_error
  ble/syntax/attr2iface/.define _ble_attr_VAR     syntax_varname
  ble/syntax/attr2iface/.define _ble_attr_QDEL    syntax_quotation
  ble/syntax/attr2iface/.define _ble_attr_QESC    syntax_escape
  ble/syntax/attr2iface/.define _ble_attr_DEF     syntax_default
  ble/syntax/attr2iface/.define _ble_attr_DEL     syntax_delimiter
  ble/syntax/attr2iface/.define _ble_ctx_PARAM    syntax_param_expansion
  ble/syntax/attr2iface/.define _ble_ctx_PWORD    syntax_default
  ble/syntax/attr2iface/.define _ble_ctx_PWORDE   syntax_error
  ble/syntax/attr2iface/.define _ble_ctx_PWORDR   syntax_default
  ble/syntax/attr2iface/.define _ble_attr_HISTX   syntax_history_expansion
  ble/syntax/attr2iface/.define _ble_ctx_VALX     syntax_default
  ble/syntax/attr2iface/.define _ble_ctx_VALI     syntax_default
  ble/syntax/attr2iface/.define _ble_ctx_VALR     syntax_default
  ble/syntax/attr2iface/.define _ble_ctx_VALQ     syntax_default
  ble/syntax/attr2iface/.define _ble_ctx_CONDX    syntax_default
  ble/syntax/attr2iface/.define _ble_ctx_CONDI    syntax_default
  ble/syntax/attr2iface/.define _ble_ctx_CONDQ    syntax_default
  ble/syntax/attr2iface/.define _ble_attr_COMMENT syntax_comment
  ble/syntax/attr2iface/.define _ble_ctx_CASE     syntax_default
  ble/syntax/attr2iface/.define _ble_ctx_PATN     syntax_default
  ble/syntax/attr2iface/.define _ble_attr_GLOB    syntax_glob
  ble/syntax/attr2iface/.define _ble_ctx_BRAX     syntax_default
  ble/syntax/attr2iface/.define _ble_attr_BRACE   syntax_brace
  ble/syntax/attr2iface/.define _ble_ctx_BRACE1   syntax_default
  ble/syntax/attr2iface/.define _ble_ctx_BRACE2   syntax_default
  ble/syntax/attr2iface/.define _ble_attr_TILDE   syntax_tilde

  # for var in ... / case arg in / time -p --
  ble/syntax/attr2iface/.define _ble_ctx_SARGX1   syntax_default
  ble/syntax/attr2iface/.define _ble_ctx_FARGX1   syntax_default
  ble/syntax/attr2iface/.define _ble_ctx_FARGX2   syntax_default
  ble/syntax/attr2iface/.define _ble_ctx_FARGX3   syntax_default
  ble/syntax/attr2iface/.define _ble_ctx_FARGI1   syntax_varname
  ble/syntax/attr2iface/.define _ble_ctx_FARGI2   command_keyword
  ble/syntax/attr2iface/.define _ble_ctx_FARGI3   syntax_default
  ble/syntax/attr2iface/.define _ble_ctx_FARGQ3   syntax_default

  ble/syntax/attr2iface/.define _ble_ctx_CARGX1   syntax_default
  ble/syntax/attr2iface/.define _ble_ctx_CARGX2   syntax_default
  ble/syntax/attr2iface/.define _ble_ctx_CARGI1   syntax_default
  ble/syntax/attr2iface/.define _ble_ctx_CARGQ1   syntax_default
  ble/syntax/attr2iface/.define _ble_ctx_CARGI2   command_keyword
  ble/syntax/attr2iface/.define _ble_ctx_CPATX    syntax_default
  ble/syntax/attr2iface/.define _ble_ctx_CPATI    syntax_default
  ble/syntax/attr2iface/.define _ble_ctx_CPATQ    syntax_default
  ble/syntax/attr2iface/.define _ble_ctx_CPATX0   syntax_default

  ble/syntax/attr2iface/.define _ble_ctx_TARGX1   syntax_default
  ble/syntax/attr2iface/.define _ble_ctx_TARGX2   syntax_default
  ble/syntax/attr2iface/.define _ble_ctx_TARGI1   syntax_default
  ble/syntax/attr2iface/.define _ble_ctx_TARGI2   syntax_default

  ble/syntax/attr2iface/.define _ble_ctx_FNAMEX   syntax_default
  ble/syntax/attr2iface/.define _ble_ctx_FNAMEI   syntax_function_name

  ble/syntax/attr2iface/.define _ble_ctx_COARGX   syntax_default
  ble/syntax/attr2iface/.define _ble_ctx_COARGI   syntax_command

  # redirection words
  ble/syntax/attr2iface/.define _ble_ctx_RDRF    syntax_default
  ble/syntax/attr2iface/.define _ble_ctx_RDRD    syntax_default
  ble/syntax/attr2iface/.define _ble_ctx_RDRD2   syntax_default
  ble/syntax/attr2iface/.define _ble_ctx_RDRS    syntax_default

  # here documents
  ble/syntax/attr2iface/.define _ble_ctx_RDRH    syntax_document_begin
  ble/syntax/attr2iface/.define _ble_ctx_RDRI    syntax_document_begin
  ble/syntax/attr2iface/.define _ble_ctx_HERE0   syntax_document
  ble/syntax/attr2iface/.define _ble_ctx_HERE1   syntax_document

  ble/syntax/attr2iface/.define _ble_attr_CMD_BOLD       command_builtin_dot
  ble/syntax/attr2iface/.define _ble_attr_CMD_BUILTIN    command_builtin
  ble/syntax/attr2iface/.define _ble_attr_CMD_ALIAS      command_alias
  ble/syntax/attr2iface/.define _ble_attr_CMD_FUNCTION   command_function
  ble/syntax/attr2iface/.define _ble_attr_CMD_FILE       command_file
  ble/syntax/attr2iface/.define _ble_attr_CMD_JOBS       command_jobs
  ble/syntax/attr2iface/.define _ble_attr_CMD_DIR        command_directory
  ble/syntax/attr2iface/.define _ble_attr_CMD_SUFFIX     command_suffix
  ble/syntax/attr2iface/.define _ble_attr_CMD_SUFFIX_NEW command_suffix_new

  ble/syntax/attr2iface/.define _ble_attr_KEYWORD       command_keyword
  ble/syntax/attr2iface/.define _ble_attr_KEYWORD_BEGIN command_keyword
  ble/syntax/attr2iface/.define _ble_attr_KEYWORD_END   command_keyword
  ble/syntax/attr2iface/.define _ble_attr_KEYWORD_MID   command_keyword
  ble/syntax/attr2iface/.define _ble_attr_FILE_DIR      filename_directory
  ble/syntax/attr2iface/.define _ble_attr_FILE_STICKY   filename_directory_sticky
  ble/syntax/attr2iface/.define _ble_attr_FILE_LINK     filename_link
  ble/syntax/attr2iface/.define _ble_attr_FILE_ORPHAN   filename_orphan
  ble/syntax/attr2iface/.define _ble_attr_FILE_FILE     filename_other
  ble/syntax/attr2iface/.define _ble_attr_FILE_SETUID   filename_setuid
  ble/syntax/attr2iface/.define _ble_attr_FILE_SETGID   filename_setgid
  ble/syntax/attr2iface/.define _ble_attr_FILE_EXEC     filename_executable
  ble/syntax/attr2iface/.define _ble_attr_FILE_WARN     filename_warning
  ble/syntax/attr2iface/.define _ble_attr_FILE_FIFO     filename_pipe
  ble/syntax/attr2iface/.define _ble_attr_FILE_SOCK     filename_socket
  ble/syntax/attr2iface/.define _ble_attr_FILE_BLK      filename_block
  ble/syntax/attr2iface/.define _ble_attr_FILE_CHR      filename_character
  ble/syntax/attr2iface/.define _ble_attr_FILE_URL      filename_url
  ble/syntax/attr2iface/.define _ble_attr_VAR_UNSET     varname_unset
  ble/syntax/attr2iface/.define _ble_attr_VAR_EMPTY     varname_empty
  ble/syntax/attr2iface/.define _ble_attr_VAR_NUMBER    varname_number
  ble/syntax/attr2iface/.define _ble_attr_VAR_EXPR      varname_expr
  ble/syntax/attr2iface/.define _ble_attr_VAR_ARRAY     varname_array
  ble/syntax/attr2iface/.define _ble_attr_VAR_HASH      varname_hash
  ble/syntax/attr2iface/.define _ble_attr_VAR_READONLY  varname_readonly
  ble/syntax/attr2iface/.define _ble_attr_VAR_TRANSFORM varname_transform
  ble/syntax/attr2iface/.define _ble_attr_VAR_EXPORT    varname_export
  ble/syntax/attr2iface/.define _ble_attr_VAR_NEW       varname_new
}
blehook/eval-after-load color_defface ble/syntax/attr2iface/color_defface.onload

#------------------------------------------------------------------------------
# ble/syntax/highlight/cmdtype


## @fn ble/syntax/highlight/cmdtype1 command_type command
##   Determines attributes for the specified command.
##   @param[in] command_type
##     Specifies the result of builtin type -t command.
##   @param[in] command
##     Command name.
##   @var[out] type
function ble/syntax/highlight/cmdtype1 {
  type=$1
  local cmd=$2
  case $type:$cmd in
  (builtin::|builtin:.)
    # Make it bold because it's hard to read
    ((type=_ble_attr_CMD_BOLD)) ;;
  (builtin:*)
    ((type=_ble_attr_CMD_BUILTIN)) ;;
  (alias:*)
    ((type=_ble_attr_CMD_ALIAS)) ;;
  (function:*)
    ((type=_ble_attr_CMD_FUNCTION)) ;;
  (file:*)
    ((type=_ble_attr_CMD_FILE)) ;;
  (keyword:*)
    ((type=_ble_attr_KEYWORD)) ;;
  (*:%*)
    # jobs
    ble/util/joblist.check
    if jobs -- "$cmd" &>/dev/null; then
      ((type=_ble_attr_CMD_JOBS))
    else
      ((type=_ble_attr_ERR))
    fi ;;
  (*)
    if [[ -d $cmd ]] && shopt -q autocd &>/dev/null; then
      ((type=_ble_attr_CMD_DIR))
    elif [[ $cmd == *.* ]] && ble/function#try ble/complete/sabbrev#match "$cmd" 's'; then
      if [[ -e $cmd || -h $cmd ]]; then
        ((type=_ble_attr_CMD_SUFFIX))
      else
        ((type=_ble_attr_CMD_SUFFIX_NEW))
      fi
    else
      ((type=_ble_attr_ERR))
    fi ;;
  esac
}

# #D1341 #D1355 #D1440 locale measures
function ble/syntax/highlight/cmdtype/.jobs { local LC_ALL=C; jobs; }
ble/function#suppress-stderr ble/syntax/highlight/cmdtype/.jobs
function ble/syntax/highlight/cmdtype/.is-job-name {
  ble/util/joblist.check

  local value=$1 word=$2
  if [[ $value == '%'* ]] && jobs -- "$value" &>/dev/null; then
    return 0
  fi

  local quote=\'\"\\\`
  if [[ ${auto_resume+set} && $word != *["$quote"]* ]]; then
    if [[ $auto_resume == exact ]]; then
      local jobs job ret
      ble/util/assign-array jobs 'ble/syntax/highlight/cmdtype/.jobs'
      for job in "${jobs[@]}"; do
        ble/string#trim "${job#*' '}"
        ble/string#trim "${ret#*' '}"
        [[ $value == "$ret" ]] && return 0
      done
      return 1
    elif [[ $auto_resume == substring ]]; then
      jobs -- "%?$value" &>/dev/null; return "$?"
    else
      jobs -- "%$value" &>/dev/null; return "$?"
    fi
  fi

  return 1
}
function ble/syntax/highlight/cmdtype/.impl {
  local cmd=$1 word=$2
  local cmd_type; ble/util/type cmd_type "$cmd"
  ble/syntax/highlight/cmdtype1 "$cmd_type" "$cmd"

  if [[ $type == "$_ble_attr_CMD_ALIAS" && $cmd != "$word" ]]; then
    # If alias is disabled with \
    # unalias and check again (2fork)
    type=$(
      builtin unalias "$cmd"
      ble/util/type cmd_type "$cmd"
      ble/syntax/highlight/cmdtype1 "$cmd_type" "$cmd"
      printf %s "$type")
  elif ble/syntax/highlight/cmdtype/.is-job-name "$cmd" "$word"; then
    # You can define a function as %() { :; }, but jobs takes precedence.
    # (Is there a way to call a function named %?)
    # But it seems that things starting with % are never keywords.
    ((type=_ble_attr_CMD_JOBS))
  elif [[ $type == "$_ble_attr_KEYWORD" ]]; then
    # Note: If it is a reserved word (keyword), it is colored at the time of syntax analysis, so it is not colored as a command.
    #   If the function ble/syntax/highlight/cmdtype is called, it is in a command context.
    #   Reserved words are treated as commands when they are quoted or after a variable assignment or redirection.
    #   At this time, use the second candidate of type -a -t to determine the type #D1406
    ble/syntax/highlight/cmdtype1 "${cmd_type[1]}" "$cmd"
  fi
}

## @fn ble/syntax/highlight/cmdtype cmd word
##   @param[in] cmd
##     Specify the string after shell expansion and quote removal.
##   @param[in] word
##     Specify the string before shell expansion/quote removal.
##   @var[out] type

# Note: The associative array _ble_syntax_highlight_filetype is defined first in core-syntax-def.sh.
_ble_syntax_highlight_filetype_version=-1
function ble/syntax/highlight/cmdtype {
  local cmd=$1 word=$2

  # check cache
  if ((_ble_syntax_highlight_filetype_version!=_ble_edit_LINENO)); then
    ble/gdict#clear _ble_syntax_highlight_filetype
    ((_ble_syntax_highlight_filetype_version=_ble_edit_LINENO))
  fi

  if local ret; ble/gdict#get _ble_syntax_highlight_filetype "$word"; then
    type=$ret
    return 0
  fi

  ble/syntax/highlight/cmdtype/.impl "$cmd" "$word"
  ble/gdict#set _ble_syntax_highlight_filetype "$word" "$type"
}

#------------------------------------------------------------------------------
# ble/syntax/highlight/filetype

## @fn ble/syntax/highlight/filetype filename [opts]
##   @param[in] fielname
##   @param[in,opt] opts
##     @opt follow-symlink
##   @var[out] type
function ble/syntax/highlight/filetype {
  type=
  local file=$1

  # Note: #D1168 Paths starting with // are very slow on Cygwin.
  if [[ ( $OSTYPE == cygwin || $OSTYPE == msys ) && $file == //* ]]; then
    [[ $file == // ]] && ((type=_ble_attr_FILE_DIR))
    [[ $type ]]; return "$?"
  fi

  if [[ :$2: != *:follow-symlink:* && -h $file ]]; then
    if [[ -e $file ]]; then
      ((type=_ble_attr_FILE_LINK))
    else
      ((type=_ble_attr_FILE_ORPHAN))
    fi
  elif [[ -e $file ]]; then
    if [[ -d $file ]]; then
      if [[ -k $file ]]; then
        ((type=_ble_attr_FILE_STICKY))
      elif [[ :$2: != *:follow-symlink:* && -h ${file%/} ]]; then
        ((type=_ble_attr_FILE_LINK))
      else
        ((type=_ble_attr_FILE_DIR))
      fi
    elif [[ -f $file ]]; then
      if [[ -u $file ]]; then
        ((type=_ble_attr_FILE_SETUID))
      elif [[ -g $file ]]; then
        ((type=_ble_attr_FILE_SETGID))
      elif [[ -x $file ]]; then
        ((type=_ble_attr_FILE_EXEC))
      else
        ((type=_ble_attr_FILE_FILE))
      fi
    elif [[ -c $file ]]; then
      ((type=_ble_attr_FILE_CHR))
    elif [[ -p $file ]]; then
      ((type=_ble_attr_FILE_FIFO))
    elif [[ -S $file ]]; then
      ((type=_ble_attr_FILE_SOCK))
    elif [[ -b $file ]]; then
      ((type=_ble_attr_FILE_BLK))
    fi
  elif local rex='^https?://[^ ^`"<>\{|}]+$'; [[ $file =~ $rex ]]; then
    ((type=_ble_attr_FILE_URL))
  fi
  [[ $type ]]
}

#------------------------------------------------------------------------------
# ble/syntax/highlight/ls_colors

## @dict _ble_syntax_highlight_lscolors_ext
## @dict _ble_syntax_highlight_lscolors_suffix
##   Those dictionaries are defined in core-syntax-def.sh

_ble_syntax_highlight_lscolors=()
_ble_syntax_highlight_lscolors_rl_colored_completion_prefix=

function ble/syntax/highlight/ls_colors/.clear {
  _ble_syntax_highlight_lscolors=()
  ble/gdict#clear _ble_syntax_highlight_lscolors_ext
  ble/gdict#clear _ble_syntax_highlight_lscolors_suffix
  _ble_syntax_highlight_lscolors_rl_colored_completion_prefix=
}

## @fn ble/syntax/highlight/ls_colors/.register-suffix suffix value
##   @param[in] suffix value
function ble/syntax/highlight/ls_colors/.register-suffix {
  local suffix=$1 value=$2
  if [[ $suffix == .readline-colored-completion-prefix ]]; then
    _ble_syntax_highlight_lscolors_rl_colored_completion_prefix=$value
  elif [[ $suffix == .* ]]; then
    ble/gdict#set _ble_syntax_highlight_lscolors_ext "$suffix" "$value"
  else
    ble/gdict#set _ble_syntax_highlight_lscolors_suffix "$suffix" "$value"
  fi
}

function ble/syntax/highlight/ls_colors/.has-suffix {
  ((${#_ble_syntax_highlight_lscolors_ext[@]})) ||
    ((${#_ble_syntax_highlight_lscolors_suffix[@]}))
}

## @fn ble/syntax/highlight/ls_colors/.match-suffix path
##   @param[in] path
##   @var[out] ret
function ble/syntax/highlight/ls_colors/.match-suffix {
  ret=
  local filename=${1##*/} suffix= g=

  local ext=$filename
  while [[ $ext == *.* ]]; do
    ext=${ext#*.}
    if ble/gdict#get _ble_syntax_highlight_lscolors_ext ".$ext" && [[ $ret ]]; then
      suffix=.$ext g=$ret
      break
    fi
  done

  local key keys
  ble/gdict#keys _ble_syntax_highlight_lscolors_suffix
  keys=("${ret[@]}")
  for key in "${keys[@]}"; do
    ((${#key}>${#suffix})) &&
      [[ $filename == *"$key" ]] &&
      ble/gdict#get _ble_syntax_highlight_lscolors_suffix "$key" &&
      [[ $ret ]] &&
      suffix=$key g=$ret
  done

  ret=$g
  [[ $ret ]]
}

function ble/syntax/highlight/ls_colors/.parse {
  ble/syntax/highlight/ls_colors/.clear

  local fields field
  ble/string#split fields : "$1"
  for field in "${fields[@]}"; do
    [[ $field == *=* ]] || continue
    if [[ $field == 'ln=target' ]]; then
      _ble_syntax_highlight_lscolors[_ble_attr_FILE_LINK]=target
      continue
    fi

    local lhs=${field%%=*}
    local ret; ble/color/sgrspec2g "${field#*=}"; local rhs=$ret
    case $lhs in
    ('di') _ble_syntax_highlight_lscolors[_ble_attr_FILE_DIR]=$rhs  ;;
    ('st') _ble_syntax_highlight_lscolors[_ble_attr_FILE_STICKY]=$rhs  ;;
    ('ln') _ble_syntax_highlight_lscolors[_ble_attr_FILE_LINK]=$rhs ;;
    ('or') _ble_syntax_highlight_lscolors[_ble_attr_FILE_ORPHAN]=$rhs ;;
    ('fi') _ble_syntax_highlight_lscolors[_ble_attr_FILE_FILE]=$rhs ;;
    ('su') _ble_syntax_highlight_lscolors[_ble_attr_FILE_SETUID]=$rhs ;;
    ('sg') _ble_syntax_highlight_lscolors[_ble_attr_FILE_SETGID]=$rhs ;;
    ('ex') _ble_syntax_highlight_lscolors[_ble_attr_FILE_EXEC]=$rhs ;;
    ('cd') _ble_syntax_highlight_lscolors[_ble_attr_FILE_CHR]=$rhs  ;;
    ('pi') _ble_syntax_highlight_lscolors[_ble_attr_FILE_FIFO]=$rhs ;;
    ('so') _ble_syntax_highlight_lscolors[_ble_attr_FILE_SOCK]=$rhs ;;
    ('bd') _ble_syntax_highlight_lscolors[_ble_attr_FILE_BLK]=$rhs  ;;
    (.*)   ble/syntax/highlight/ls_colors/.register-suffix "$lhs" "$rhs" ;;
    (\*?*) ble/syntax/highlight/ls_colors/.register-suffix "${lhs:1}" "$rhs" ;;
    esac
  done
}

## @fn ble/syntax/highlight/ls_colors filename
##   Overrides g and succeeds when a corresponding LS_COLORS setting is found.
##   Otherwise, g is unchanged and fails.
##   @param[in] filename
##   @var[ref] type
##     This specifies the type of the file.  When the file is symbolic link and
##     `ln=target' is specified, this function rewrites `type` to the file type
##     of the target file.
##   @var[in,out] g
function ble/syntax/highlight/ls_colors {
  local file=$1
  if ((type==_ble_attr_FILE_LINK)) && [[ ${_ble_syntax_highlight_lscolors[_ble_attr_FILE_LINK]} == target ]]; then
    # determine type based on resolved file
    ble/syntax/highlight/filetype "$file" follow-symlink ||
      type=$_ble_attr_FILE_ORPHAN
    if ((type==_ble_attr_FILE_FILE)) && ble/syntax/highlight/ls_colors/.has-suffix; then
      ble/util/readlink "$file"
      file=$ret
    fi
  fi

  if ((type==_ble_attr_FILE_FILE)); then
    local ret=
    if ble/syntax/highlight/ls_colors/.match-suffix "$file"; then
      local g1=$ret
      ble/color/face2g filename_ls_colors; g=$ret
      ble/color/g#append g "$g1"
      return 0
    fi
  fi

  local g1=${_ble_syntax_highlight_lscolors[type]}
  if [[ $g1 ]]; then
    ble/color/face2g filename_ls_colors; g=$ret
    ble/color/g#append g "$g1"
    return 0
  fi

  return 1
}

function ble/syntax/highlight/getg-from-filename {
  local filename=$1 type=
  ble/syntax/highlight/filetype "$filename"
  if [[ $bleopt_filename_ls_colors ]]; then
    if ble/syntax/highlight/ls_colors "$filename"; then
      return 0
    fi
  fi

  if [[ $type ]]; then
    ble/syntax/attr2g "$type"
  else
    g=
  fi
}

function bleopt/check:filename_ls_colors {
  ble/syntax/highlight/ls_colors/.parse "$value"
}
bleopt -I filename_ls_colors

#------------------------------------------------------------------------------
# ble/progcolor

_ble_syntax_progcolor_vars=(
  node TE_i TE_nofs wtype wlen wbeg wend wattr)
_ble_syntax_progcolor_wattr_vars=(
  wattr_buff wattr_pos wattr_g)

## @fn ble/progcolor/load-word-data i:nofs
##   @var[out] TE_i TE_nofs node
##   @var[out] wtype wlen wbeg wend wattr
function ble/progcolor/load-word-data {
  # TE_i TE_nofs
  TE_i=${1%%:*} TE_nofs=${1#*:}
  [[ $1 != *:* ]] && TE_nofs=0

  # node
  ble/string#split-words node "${_ble_syntax_tree[TE_i-1]}"

  # wvars
  wtype=${node[TE_nofs]}
  wlen=${node[TE_nofs+1]}
  wattr=${node[TE_nofs+4]}
  wbeg=$((TE_i-wlen))
  wend=$TE_i
}

## @fn ble/progcolor/set-wattr value
##   @var[in] TE_i TE_nofs node
function ble/progcolor/set-wattr {
  ble/syntax/urange#update color_ "$wbeg" "$wend"
  ble/syntax/wrange#update _ble_syntax_word_ "$TE_i"
  node[TE_nofs+4]=$1
  local IFS=$_ble_term_IFS
  _ble_syntax_tree[TE_i-1]="${node[*]}"
}

## @fn ble/progcolor/eval-word [iword] [opts]
##   Returns the evaluated value of the iwordth word of the current command.
##   If iword is omitted, the word currently being colored is used.
##   The command will fail if the word cannot be evaluated.
##
##   @param[in,opt] iword
##   @param[in,opt] opts
##     Specify opts for ble/syntax:bash/simple-word/eval.
##
##   @var[in] progcolor_iword
##     Specifies the number of the word currently being processed.
##     Used when iword is omitted.
##   @var[in,out] progcolor_wvals
##   @var[in,out] progcolor_stats
##     A cache of word rating values.
##   @var[out] ret
##
function ble/progcolor/eval-word {
  local iword=${1:-progcolor_iword} opts=$2
  if [[ ${progcolor_stats[iword]+set} ]]; then
    ret=${progcolor_wvals[iword]}
    return "${progcolor_stats[iword]}"
  fi

  local wtxt=${comp_words[iword]}
  local simple_flags simple_ibrace
  if ! ble/syntax:bash/simple-word/reconstruct-incomplete-word "$wtxt"; then
    # not simple word
    ret=
    progcolor_stats[iword]=2
    progcolor_wvals[iword]=
    return 2
  fi

  ble/syntax:bash/simple-word/eval "$ret" "$opts"; local ext=$?
  ((ext==148)) && return 148
  if ((ext!=0)); then
    # fail glob
    ret=
    progcolor_stats[iword]=1
    progcolor_wvals[iword]=
    return 1
  fi

  progcolor_stats[iword]=0
  progcolor_wvals[iword]=$ret
  return 0
}

## @fn ble/progcolor/load-cmdspec-opts
##   @var[out] cmdspec_opts
function ble/progcolor/load-cmdspec-opts {
  if [[ $progcolor_cmdspec_opts ]]; then
    cmdspec_opts=$progcolor_cmdspec_opts
  else
    ble/cmdspec/opts#load "${comp_words[0]}"
    progcolor_cmdspec_opts=${cmdspec_opts:-:}
  fi
}

## @fn ble/progcolor/stop-option#init cmdspec_opts
##   @var[out] rexrej rexreq stopat
function ble/progcolor/stop-option#init {
  rexrej='^--$' rexreq= stopat=
  local cmdspec_opts=$1
  if [[ $cmdspec_opts ]]; then
    # copied from ble/complete/source:option/.stops-option
    if [[ :$cmdspec_opts: == *:no-options:* ]]; then
      stopat=0
      return 1
    elif ble/opts#extract-first-optarg "$cmdspec_opts" stop-options-at && [[ $ret ]]; then
      ((stopat=ret))
      return 1
    fi

    local ret
    if ble/opts#extract-first-optarg "$cmdspec_opts" stop-options-on && [[ $ret ]]; then
      rexrej=$ret
    elif [[ :$cmdspec_opts: == *:disable-double-hyphen:* ]]; then
      rexrej=
    fi
    if ble/opts#extract-first-optarg "$cmdspec_opts" stop-options-unless && [[ $ret ]]; then
      rexreq=$ret
    elif [[ :$cmdspec_opts: == *:stop-options-postarg:* ]]; then
      rexreq='^-.+'
      ble/opts#has "$cmdspec_opts" plus-options && rexreq='^[-+].+'
    fi
  fi
}
## @fn ble/progcolor/stop-option#test value
##   @var[in] rexrej rexreq
function ble/progcolor/stop-option#test {
  [[ $rexrej && $1 =~ $rexrej || $rexreq && ! ( $1 =~ $rexreq ) ]]
}

## @fn ble/progcolor/is-option-context
##   Determines whether the current word position is the context in which the option is interpreted.
##
##   @var progcolor_iword
##     Current word position.
##
##   @var progcolor_optctx[0]
##     When empty, it indicates that the option has not been initialized yet.
##     Records the extent to which optional stop conditions have been checked for the current command.
##
##   @var progcolor_optctx[1]
##     When negative, always indicates that the option is enabled.
##     A value of 0 always indicates that the option is disabled.
##     A positive value indicates that the option is valid for arguments before that position.
##
##   @var progcolor_optctx[2]
##   @var progcolor_optctx[3]
##   @var progcolor_optctx[4]
##     Record the value of each extracted rexrej rexreq stopat.
##     A cache of values initialized by ble/progcolor/stop-option#init.
##
function ble/progcolor/is-option-context {
  # If the optional stop position has already been calculated
  if [[ ${progcolor_optctx[1]} ]]; then
    # Note: The equal sign is the argument that caused the stop -- itself (valid as an option)
    ((progcolor_optctx[1]<0?1:(progcolor_iword<=progcolor_optctx[1])))
    return "$?"
  fi

  local rexrej rexreq stopat
  if [[ ! ${progcolor_optctx[0]} ]]; then
    progcolor_optctx[0]=1
    local cmdspec_opts
    ble/progcolor/load-cmdspec-opts
    ble/progcolor/stop-option#init "$cmdspec_opts"
    if [[ ! $rexrej$rexreq ]]; then
      progcolor_optctx[1]=${stopat:--1}
      ((progcolor_optctx[1]<0?1:(progcolor_iword<=progcolor_optctx[1])))
      return "$?"
    fi
    progcolor_optctx[2]=$rexrej
    progcolor_optctx[3]=$rexreq
    progcolor_optctx[4]=$stopat
  else
    rexrej=${progcolor_optctx[2]}
    rexreq=${progcolor_optctx[3]}
    stopat=${progcolor_optctx[4]}
  fi
  [[ $stopat ]] && ((progcolor_iword>stopat)) && return 1

  local iword
  for ((iword=progcolor_optctx[0];iword<progcolor_iword;iword++)); do
    ble/progcolor/eval-word "$iword" "$highlight_eval_opts"
    if ble/progcolor/stop-option#test "$ret"; then
      progcolor_optctx[1]=$iword
      return 1
    fi
  done
  progcolor_optctx[0]=$iword
  return 0
}

## @fn ble/progcolor/wattr#initialize
##   @var[out] wattr_buff
##   @var[out] wattr_pos
##   @var[out] wattr_g
function ble/progcolor/wattr#initialize {
  wattr_buff=()
  wattr_pos=$wbeg
  wattr_g=d
}
## @fn ble/progcolor/wattr#setg pos g
##   @param[in] pos
##   @param[in] g
##   @var[in,out] wattr_buff
##   @var[in,out] wattr_pos
##   @var[in,out] wattr_g
function ble/progcolor/wattr#setg {
  local pos=$1 g=$2
  local len=$((pos-wattr_pos))
  ((len>0)) && ble/array#push wattr_buff "$len:$wattr_g"
  wattr_pos=$pos
  wattr_g=$g
}
function ble/progcolor/wattr#setattr {
  local pos=$1 attr=$2 g
  ble/syntax/attr2g "$attr"
  ble/progcolor/wattr#setg "$pos" "$g"
}
## @fn ble/progcolor/wattr#finalize
##   @var[in,out] wattr_buff
##   @var[in,out] wattr_pos
##   @var[in,out] wattr_g
function ble/progcolor/wattr#finalize {
  local wattr
  if ((${#wattr_buff[@]})); then
    local len=$((wend-wattr_pos))
    ((len>0)) && ble/array#push wattr_buff \$:"$wattr_g"
    wattr_pos=$wend
    wattr_g=d
    IFS=, builtin eval 'wattr="m${wattr_buff[*]}"'
  else
    wattr=$wattr_g
  fi
  ble/progcolor/set-wattr "$wattr"
}


## @fn ble/progcolor/highlight-filename/.detect-separated-path word
##   @param[in] word
##   @var[in] wtype p0
##   @var[in] _ble_syntax_attr
##   @var[out] ret
##     Returns the set of valid delimiters.
function ble/progcolor/highlight-filename/.detect-separated-path {
  local word=$1
  ((wtype==_ble_ctx_ARGI||wtype==_ble_ctx_ARGEI||wtype==_ble_ctx_VALI||wtype==_ble_attr_VAR||wtype==_ble_ctx_RDRS)) || return 1

  local detect_opts=url:$highlight_eval_opts
  ((wtype==_ble_ctx_RDRS)) && detect_opts=$detect_opts:noglob
  [[ $word == '~'* ]] && ((_ble_syntax_attr[p0]!=_ble_attr_TILDE)) && detect_opts=$detect_opts:notilde
  ble/syntax:bash/simple-word/detect-separated-path "$word" :, "$detect_opts"
}

## @fn ble/progcolor/highlight-filename/.pathspec.wattr g [opts]
##   @param[in] g
##   @param[in,opt] opts
##   @var[in] wtype p0 p1
##   @var[in] path spec
function ble/progcolor/highlight-filename/.pathspec.wattr {
  local p=$p0 opts=$2

  if [[ :$opts: != *:no-path-color:* ]]; then
    local ipath npath=${#path[@]}
    for ((ipath=0;ipath<npath-1;ipath++)); do
      local epath=${path[ipath]} espec=${spec[ipath]}
      local g=d

      if ble/syntax/util/is-directory "$epath"; then
        local type
        if ble/syntax/highlight/filetype "$epath"; then
          ble/syntax/highlight/ls_colors ||
            ble/syntax/attr2g "$type"
        fi
      elif ((wtype==_ble_ctx_CMDI)); then
        # Directory must exist for command name #D1419
        ble/syntax/attr2g "$_ble_attr_ERR"
      fi

      # Do not underline command names.
      ((wtype==_ble_ctx_CMDI&&(g&=~_ble_color_gflags_Underline)))

      ble/progcolor/wattr#setg "$p" "$g"
      ((p=p0+${#espec}))
    done
  fi

  ble/progcolor/wattr#setg "$p" "$1"
  [[ $1 != d ]] &&
    ble/progcolor/wattr#setg "$p1" d
  return 0
}

## @fn ble/progcolor/highlight-filename/.pathspec-with-attr.wattr attr
##   @param[in] attr
##   @var[in] wtype p0 p1
##   @var[in] path spec
function ble/progcolor/highlight-filename/.pathspec-with-attr.wattr {
  local g; ble/syntax/attr2g "$1"
  ble/progcolor/highlight-filename/.pathspec.wattr "$g"
  return 0
}
## @fn ble/progcolor/highlight-filename/.pathspec-by-name.wattr value
##   @param[in] value
##   @var[in] wtype p0 p1
##   @var[in] path spec
function ble/progcolor/highlight-filename/.pathspec-by-name.wattr {
  local value=$1

  local highlight_opts=
  local type=; ble/syntax/highlight/filetype "$value"
  ((type==_ble_attr_FILE_URL)) && highlight_opts=no-path-color

  # check values
  if ((wtype==_ble_ctx_RDRF||wtype==_ble_ctx_RDRD2)); then
    if ((type==_ble_attr_FILE_DIR)); then
      # Can't redirect to directory
      type=$_ble_attr_ERR
    elif ((_ble_syntax_TREE_WIDTH<=TE_nofs)); then
      # When using noclobber, existing files cannot be overwritten with > or <>
      #
      # Assumption: Assume that the redirect and file end at the same location in _ble_syntax_word.
      #   At this time, the file name information should be stored next to the redirect information,
      #   Redirect information is considered to be contained in node[TE_nofs-_ble_syntax_TREE_WIDTH].
      #
      local redirect_ntype=${node[TE_nofs-_ble_syntax_TREE_WIDTH]:1}
      if [[ ( $redirect_ntype == *'>' || $redirect_ntype == '>'[\|\&] ) ]]; then
        if [[ -e $value || -h $value ]]; then
          if [[ -d $value || ! -w $value ]]; then
            # No directory or write permissions
            type=$_ble_attr_ERR
          elif [[ ( $redirect_ntype == [\<\&]'>' || $redirect_ntype == '>' || $redirect_ntype == '>&' ) && -f $value ]]; then
            if [[ -o noclobber ]]; then
              # Overwriting prohibited
              type=$_ble_attr_ERR
            else
              # Be careful about overwriting
              type=$_ble_attr_FILE_WARN
            fi
          fi
        elif [[ $value == */* && ! -w ${value%/*}/ || $value != */* && ! -w ./ ]]; then
          # You don't have write permission on the directory
          type=$_ble_attr_ERR
        fi
      elif [[ $redirect_ntype == '<' && ! -r $value ]]; then
        # File is missing or does not have read permission
        type=$_ble_attr_ERR
      fi
    fi
  fi

  local g=
  if [[ $bleopt_filename_ls_colors ]]; then
    ble/syntax/highlight/ls_colors "$value"
  fi
  [[ $type && ! $g ]] && ble/syntax/attr2g "$type"

  ble/progcolor/highlight-filename/.pathspec.wattr "${g:-d}" "$highlight_opts"
  return 0
}

## @fn ble/progcolor/highlight-filename/.single.wattr p0:p1
##   @param[in] p0 p1
##     Specifies a range (within the command line) of file names.
##   @param[in] wtype
function ble/progcolor/highlight-filename/.single.wattr {
  local p0=${1%%:*} p1=${1#*:}
  local wtxt=${text:p0:p1-p0}

  # alias should be determined before shell expansion etc.
  if ((wtype==_ble_ctx_CMDI)) && ble/alias#active "$wtxt"; then
    # Note: If the alias name contains characters such as [*?], it may failglob.
    # There isn't, but it's not a problem because it actually unfolds.
    ble/progcolor/wattr#setattr "$p0" "$_ble_attr_CMD_ALIAS"
    return 0
  fi

  local path_opts=after-sep:$highlight_eval_opts
  # Suppress when not in context of tilde expansion
  [[ $wtxt == '~'* ]] && ((_ble_syntax_attr[p0]!=_ble_attr_TILDE)) && path_opts=$path_opts:notilde
  ((wtype==_ble_ctx_RDRS||wtype==_ble_attr_VAR||wtype==_ble_ctx_VALI&&wbeg<p0)) && path_opts=$path_opts:noglob

  local ret path spec ext value count
  ble/syntax:bash/simple-word/evaluate-path-spec "$wtxt" / "count:$path_opts"; ext=$? value=("${ret[@]}")
  ((ext==148)) && return 148
  if ((ext==142)); then
    if [[ $ble_textarea_render_defer_running ]]; then
      # When timeout is set in background, coloring of this file name is given up.
      ble/progcolor/wattr#setg "$p0" d
    else
      # When you timeout with foreground, exit for now in order to color with background later.
      return 148
    fi
  elif ((ext&&(wtype==_ble_ctx_CMDI||wtype==_ble_ctx_ARGI||wtype==_ble_ctx_ARGEI||wtype==_ble_ctx_RDRF||wtype==_ble_ctx_RDRS||wtype==_ble_ctx_RDRD||wtype==_ble_ctx_RDRD2||wtype==_ble_ctx_VALI))); then
    # If deployment fails due to failglob etc.
    ble/progcolor/highlight-filename/.pathspec-with-attr.wattr "$_ble_attr_ERR"
  elif (((wtype==_ble_ctx_RDRF||wtype==_ble_ctx_RDRD||wtype==_ble_ctx_RDRD2)&&count>=2)); then
    # It is no good if it is expanded into multiple words.
    ble/progcolor/wattr#setattr "$p0" "$_ble_attr_ERR"
  elif ((wtype==_ble_ctx_CMDI)); then
    local attr=${_ble_syntax_attr[wbeg]}
    if ((attr!=_ble_attr_KEYWORD&&attr!=_ble_attr_KEYWORD_BEGIN&&attr!=_ble_attr_KEYWORD_END&&attr!=_ble_attr_KEYWORD_MID&&attr!=_ble_attr_DEL)); then
      local type=; ble/syntax/highlight/cmdtype "$value" "$wtxt"
      if ((type==_ble_attr_CMD_FILE||type==_ble_attr_CMD_FILE||type==_ble_attr_ERR)); then
        ble/progcolor/highlight-filename/.pathspec-with-attr.wattr "$type"
      elif [[ $type ]]; then
        ble/progcolor/wattr#setattr "$p0" "$type"
      fi
    fi
  elif ((wtype==_ble_ctx_RDRD||wtype==_ble_ctx_RDRD2)); then
    if local rex='^[0-9]+-?$|^-$'; [[ $value =~ $rex ]]; then
      ble/progcolor/wattr#setattr "$p0" "$_ble_attr_DEL"
    elif ((wtype==_ble_ctx_RDRD2)); then
      ble/progcolor/highlight-filename/.pathspec-by-name.wattr "$value"
    else
      ble/progcolor/wattr#setattr "$p0" "$_ble_attr_ERR"
    fi
  elif ((wtype==_ble_ctx_ARGI||wtype==_ble_ctx_ARGEI||wtype==_ble_ctx_VALI||wtype==_ble_attr_VAR||wtype==_ble_ctx_RDRS||wtype==_ble_ctx_RDRF)); then
    ble/progcolor/highlight-filename/.pathspec-by-name.wattr "$value"
  fi
}

function ble/progcolor/highlight-filename.wattr {
  local p0=$1 p1=$2
  if ((p0<p1)) && [[ $bleopt_highlight_filename ]]; then
    local wtxt=${text:p0:p1-p0}
    local ret; ble/progcolor/highlight-filename/.detect-separated-path "$wtxt"; local ext=$?
    ((ext==148)) && return 148
    if ((ext==0)); then
      local sep=$ret ranges i
      ble/syntax:bash/simple-word/locate-filename "$wtxt" "$sep" "url:$highlight_eval_opts"
      (($?==148)) && return 148; ranges=("${ret[@]}")
      for ((i=0;i<${#ranges[@]};i+=2)); do
        ble/progcolor/highlight-filename/.single.wattr "$((p0+ranges[i])):$((p0+ranges[i+1]))"
        (($?==148)) && return 148
      done
    elif ble/syntax:bash/simple-word/is-simple "$wtxt"; then
      ble/progcolor/highlight-filename/.single.wattr "$p0":"$p1"
      (($?==148)) && return 148
    fi
  fi
}

function ble/progcolor/@wattr {
  [[ $wtype =~ ^[0-9]+$ ]] || return 1
  [[ $wattr == - ]] || return 1
  local "${_ble_syntax_progcolor_wattr_vars[@]/%/=}" # WA #D1570 checked
  ble/progcolor/wattr#initialize

  "$@"; local ext=$?

  if ((ext==148)); then
    _ble_textarea_render_defer=1
    ble/syntax/wrange#update _ble_syntax_word_defer_ "$wend"
  else
    ble/progcolor/wattr#finalize
  fi
  return "$ext"
}

## @fn ble/progcolor/word:default/.is-option wtxt
##   @var[in] wtype
##   @var[in] progcolor_*
function ble/progcolor/word:default/.is-option {
  # Note: Synchronize with _ble_complete_option_chars regarding characters allowed as options.
  ((wtype==_ble_ctx_ARGI||wtype==_ble_ctx_ARGEI||wtype==_ble_ctx_ARGVI)) &&
    ble/string#match "$1" '^(-[-_a-zA-Z0-9!#$%&:;.,^~|\?/*@]*)=?' && # Finish fast judgment first
    ble/progcolor/is-option-context &&
    ble/string#match "$1" '^(-[-_a-zA-Z0-9!#$%&:;.,^~|\?/*@]*)=?' # Rerun for BASH_REMATCH
}

## @fn ble/progcolor/word:default
##   @var[in] node TE_i TE_nofs
##   @var[in] wtype wlen wbeg wend wattr
##   @var[in] ${_ble_syntax_progcolor_wattr_vars[@]}
function ble/progcolor/word:default/impl.wattr {
  if ((wtype==_ble_ctx_RDRH||wtype==_ble_ctx_RDRI||wtype==_ble_attr_ERR)); then
    # The keyword specification part of the here document is
    # Analysis is performed according to expansion, command substitution, etc.
    # Since no execution occurs, fill it with one color.
    ble/progcolor/wattr#setattr "$wbeg" "$wtype"

  elif ((wtype==_ble_ctx_FNAMEI)); then
    # Note: An arbitrary function name has been allowed in bash-5.3-alpha, but
    # it has been postponed after bash-5.3-rc2 [1].  It will be enabled again
    # at the same time as quote removal of the name of the function definition.
    # When it is supported, the following number 990000 should be updated to
    # the actual version number.
    # [1] https://lists.gnu.org/archive/html/bug-bash/2025-06/msg00005.html
    if ((_ble_bash<990000)) && [[ ${text:wbeg:wlen} == *[\\\'\"\`\$\<\>\(\)]* ]]; then
      ble/progcolor/wattr#setattr "$wbeg" "$_ble_attr_ERR"
    else
      ble/progcolor/wattr#setattr "$wbeg" "$wtype"
    fi
  else
    # @var p0 p1
    #   The range from which to extract the string.
    local p0=$wbeg p1=$wend wtxt=${text:wbeg:wlen}

    # variable assignment
    if ((wtype==_ble_attr_VAR||wtype==_ble_ctx_VALI)); then
      # In the case of variable assignment, only the right side is cut out.
      #   Note: arr=(a=a*b a[1]=a*b) etc. are not subject to pathname expansion.
      #     This is because it is recognized as a form of variable assignment.
      #     Below, by specifying element-assignment,
      #     The format of variable assignment is also extracted for array elements.
      local ret
      ble/syntax:bash/find-rhs "$wtype" "$wbeg" "$wlen" element-assignment && p0=$ret
    elif ((wtype==_ble_ctx_ARGI||wtype==_ble_ctx_ARGEI||wtype==_ble_ctx_VALI)) && { local rex='^[_a-zA-Z][_a-zA-Z0-9]*='; [[ $wtxt =~ $rex ]]; }; then
      # Regular arguments in variable assignment format
      ((p0+=${#BASH_REMATCH}))
    elif ble/progcolor/word:default/.is-option "$wtxt"; then
      # Optional arguments such as --prefix=
      local rematch=$BASH_REMATCH rematch1=${BASH_REMATCH[1]}
      local ret; ble/color/face2g argument_option
      ble/progcolor/wattr#setg "$p0" "$ret"
      ble/progcolor/wattr#setg "$((p0+${#rematch1}))" d
      ((p0+=${#rematch}))
    fi

    ble/progcolor/highlight-filename.wattr "$p0" "$p1"
    (($?==148)) && return 148
  fi

  return 0
}

function ble/progcolor/word:default {
  ble/progcolor/@wattr ble/progcolor/word:default/impl.wattr
}

## @fn ble/progcolor/default
##   @var[in] comp_words comp_cword comp_line comp_point
##   @var[in] tree_words
##   @var[in,out] color_umin color_umax
function ble/progcolor/default {
  local i "${_ble_syntax_progcolor_vars[@]/%/=}" # WA #D1570 checked
  for ((i=1;i<${#comp_words[@]};i++)); do
    local ref=${tree_words[i]}
    [[ $ref ]] || continue
    local progcolor_iword=$i
    ble/progcolor/load-word-data "$ref"
    ble/progcolor/word:default
  done
}

## @fn ble/progcolor/.compline-rewrite-command command [args...]
##   @var[in,out] comp_words comp_cword comp_line comp_point
function ble/progcolor/.compline-rewrite-command {
  local ocmd=${comp_words[0]}
  [[ $1 != "$ocmd" ]] || (($#>=2)) || return 1
  local IFS=$_ble_term_IFS
  local ins="$*"
  comp_line=$ins${comp_line:${#ocmd}}
  ((comp_point-=${#ocmd},comp_point<0&&(comp_point=0),comp_point+=${#ins}))
  comp_words=("$@" "${comp_words[@]:1}")
  ((comp_cword&&(comp_cword+=$#-1)))

  # update tree_words
  ble/array#reserve-prototype "$#"
  tree_words=("${tree_words[0]}" "${_ble_array_prototype[@]::$#-1}" "${tree_words[@]:1}")
}
## @fn ble/progcolor cmd opts
##   @var[in] comp_words comp_cword comp_line comp_point
##   @var[in] tree_words
##   @var[in,out] color_umin color_umax
function ble/progcolor {
  local cmd=$1 opts=$2

  # cache used by "eval-word"
  local -a progcolor_stats=()
  local -a progcolor_wvals=()

  # cache used by "load-cmdspec-opts"
  local progcolor_cmdspec_opts=

  # cache used by "is-option-context"
  local -a progcolor_optctx=()

  local -a alias_args=()
  local checked=" " processed=
  while ((1)); do
    if ble/is-function ble/cmdinfo/cmd:"$cmd"/chroma; then
      ble/progcolor/.compline-rewrite-command "$cmd" "${alias_args[@]}"
      ble/cmdinfo/cmd:"$cmd"/chroma "$opts"
      processed=1
      break
    elif [[ $cmd == */?* ]] && ble/is-function ble/cmdinfo/cmd:"${cmd##*/}"/chroma; then
      ble/progcolor/.compline-rewrite-command "${cmd##*/}" "${alias_args[@]}"
      ble/cmdinfo/cmd:"${cmd##*/}"/chroma "$opts"
      processed=1
      break
    fi
    checked="$checked$cmd "

    local ret
    ble/alias#expand "$cmd"
    ble/string#split-words ret "$ret"
    [[ $checked == *" $ret "* ]] && break
    cmd=$ret
    ((${#ret[@]}>=2)) &&
      alias_args=("${ret[@]:1}" "${alias_args[@]}")
  done
  [[ $processed ]] ||
    ble/progcolor/default

  # Perform default coloring for command names
  if [[ ${tree_words[0]} ]]; then
    local "${_ble_syntax_progcolor_vars[@]/%/=}" # WA #D1570 checked
    ble/progcolor/load-word-data "${tree_words[0]}"
    [[ $wattr == - ]] && ble/progcolor/word:default
  fi
}

#------------------------------------------------------------------------------
# ble/highlight/layer:syntax

# I want to implement it directly without relying on adapter
function ble/highlight/layer:syntax/touch-range {
  ble/syntax/urange#update '' "$@"
}
function ble/highlight/layer:syntax/fill {
  local _ble_local_script='
    local iNAME=0 i1NAME=$2 i2NAME=$3
    for ((iNAME=i1NAME;iNAME<i2NAME;iNAME++)); do
      NAME[iNAME]=$4
    done
  '; builtin eval -- "${_ble_local_script//NAME/$1}"
}

_ble_highlight_layer_syntax_VARNAMES=(
  _ble_highlight_layer_syntax_buff
  _ble_highlight_layer_syntax_active
  _ble_highlight_layer_syntax1_table
  _ble_highlight_layer_syntax2_table
  _ble_highlight_layer_syntax3_list
  _ble_highlight_layer_syntax3_table)
function ble/highlight/layer:syntax/initialize-vars {
  # Note (#D2000): core-syntax is lazily loaded, so layer/update/shift is targeted.
  # All arrays must have the required number of elements.
  local prev_iN=${#_ble_highlight_layer_plain_buff[*]}
  ble/array#reserve-prototype "$prev_iN"
  _ble_highlight_layer_syntax_buff=("${_ble_array_prototype[@]::prev_iN}")
  _ble_highlight_layer_syntax1_table=("${_ble_array_prototype[@]::prev_iN}")
  _ble_highlight_layer_syntax2_table=("${_ble_array_prototype[@]::prev_iN}")
  _ble_highlight_layer_syntax3_table=("${_ble_array_prototype[@]::prev_iN}") # errors
  _ble_highlight_layer_syntax3_list=()
}
ble/highlight/layer:syntax/initialize-vars

function ble/highlight/layer:syntax/update-attribute-table {
  ble/highlight/layer/update/shift _ble_highlight_layer_syntax1_table
  if ((_ble_syntax_attr_umin>=0)); then
    ble/highlight/layer:syntax/touch-range _ble_syntax_attr_umin _ble_syntax_attr_umax

    local i g=0
    ((_ble_syntax_attr_umin>0)) &&
      ((g=_ble_highlight_layer_syntax1_table[_ble_syntax_attr_umin-1]))

    for ((i=_ble_syntax_attr_umin;i<_ble_syntax_attr_umax;i++)); do
      if [[ ${_ble_syntax_attr[i]} ]]; then
        ble/syntax/attr2g "${_ble_syntax_attr[i]}"
      fi
      _ble_highlight_layer_syntax1_table[i]=$g
    done

    _ble_syntax_attr_umin=-1 _ble_syntax_attr_umax=-1
  fi
}

function ble/highlight/layer:syntax/word/.update-attributes/.proc {
  [[ $wtype =~ ^[0-9]+$ ]] || return 1
  [[ ${node[TE_nofs+4]} == - ]] || return 1

  if ((wtype==_ble_ctx_CMDI||wtype==_ble_ctx_ARGI||wtype==_ble_ctx_ARGVI||wtype==_ble_ctx_ARGEI)); then
    local comp_line comp_point comp_words comp_cword tree_words
    if ble/syntax:bash/extract-command-by-noderef "$TE_i:$TE_nofs" treeinfo; then
      local cmd=${comp_words[0]}
      ble/progcolor "$cmd"
      return 0
    fi
  fi

  # Single word coloring if command line cannot be restored
  ble/progcolor/word:default
}

## @fn ble/highlight/layer:syntax/word/.update-attributes
## @var[in] _ble_syntax_word_umin,_ble_syntax_word_umax
## @var[in,out] color_umin color_umax
function ble/highlight/layer:syntax/word/.update-attributes {
  ((_ble_syntax_word_umin>=0)) || return 1

  local _ble_syntax_bash_simple_eval_timeout=$bleopt_highlight_timeout_sync
  local highlight_eval_opts=cached:single:stopcheck

  [[ $bleopt_highlight_eval_word_limit ]] &&
    highlight_eval_opts=$highlight_eval_opts:limit=$((bleopt_highlight_eval_word_limit))

  # Timeout setting for simple-word/eval
  if [[ ! $ble_textarea_render_defer_running ]]; then
    local _ble_syntax_bash_simple_eval_timeout_carry=
    highlight_eval_opts=$highlight_eval_opts:timeout-carry
  fi

  ble/syntax/tree-enumerate-in-range "$_ble_syntax_word_umin" "$_ble_syntax_word_umax" \
    ble/highlight/layer:syntax/word/.update-attributes/.proc
}

## @fn ble/highlight/layer:syntax/word/.apply-attribute wbeg wend wattr
##   @param[in] wbeg wend wattr
function ble/highlight/layer:syntax/word/.apply-attribute {
  local wbeg=$1 wend=$2 wattr=$3
  ((wbeg<color_umin&&(wbeg=color_umin),
    wend>color_umax&&(wend=color_umax),
    wbeg<wend)) || return 1

  if [[ $wattr =~ ^[0-9]+$ ]]; then
    ble/array#fill-range _ble_highlight_layer_syntax2_table "$wbeg" "$wend" "$wattr"
  elif [[ $wattr == m* ]]; then
    local ranges; ble/string#split ranges , "${wattr:1}"
    local i=$wbeg j range
    for range in "${ranges[@]}"; do
      local len=${range%%:*} sub_wattr=${range#*:}
      if [[ $len == '$' ]]; then
        j=$wend
      else
        ((j=i+len,j>wend&&(j=wend)))
      fi
      ble/highlight/layer:syntax/word/.apply-attribute "$i" "$j" "$sub_wattr"
      (((i=j)<wend)) || break
    done
  elif [[ $wattr == d ]]; then
    ble/array#fill-range _ble_highlight_layer_syntax2_table "$wbeg" "$wend" ''
  fi
}

function ble/highlight/layer:syntax/word/.proc-childnode {
  if [[ $wtype =~ ^[0-9]+$ ]]; then
    local wbeg=$wbegin wend=$TE_i
    ble/highlight/layer:syntax/word/.apply-attribute "$wbeg" "$wend" "$attr"
  fi

  ((tchild>=0)) && ble/syntax/tree-enumerate-children "$proc_children"
}

## @var[in,out] _ble_syntax_word_umin _ble_syntax_word_umax
function ble/highlight/layer:syntax/update-word-table {
  # update table2 (I'll think about deleting words later)
  # (1) Calculating word color
  local color_umin=-1 color_umax=-1 iN=${#_ble_syntax_text}
  ble/highlight/layer:syntax/word/.update-attributes

  # (2) Color array shift
  ble/highlight/layer/update/shift _ble_highlight_layer_syntax2_table

  # 2015-08-16 Tentative (Actually, I want to take nested structure into consideration)
  ble/syntax/wrange#update _ble_syntax_word_ "$_ble_syntax_vanishing_word_umin" "$_ble_syntax_vanishing_word_umax"
  ble/syntax/wrange#update color_ "$_ble_syntax_vanishing_word_umin" "$_ble_syntax_vanishing_word_umax"
  _ble_syntax_vanishing_word_umin=-1 _ble_syntax_vanishing_word_umax=-1

  # (3) Register in color array
  ble/highlight/layer:syntax/word/.apply-attribute 0 "$iN" d # clear word color
  local TE_i
  for ((TE_i=_ble_syntax_word_umax;TE_i>=_ble_syntax_word_umin;)); do
    if ((TE_i>0)) && [[ ${_ble_syntax_tree[TE_i-1]} ]]; then
      local -a node
      ble/string#split-words node "${_ble_syntax_tree[TE_i-1]}"

      local wlen=${node[1]}
      local wbeg=$((TE_i-wlen)) wend=$TE_i

      if [[ ${node[0]} =~ ^[0-9]+$ ]]; then
        local attr=${node[4]}
        ble/highlight/layer:syntax/word/.apply-attribute "$wbeg" "$wend" "$attr"
      fi

      local tclen=${node[2]}
      if ((tclen>=0)); then
        local tchild=$((TE_i-tclen))
        local tree= TE_nofs=0 proc_children=ble/highlight/layer:syntax/word/.proc-childnode
        ble/syntax/tree-enumerate-children "$proc_children"
      fi

      ((TE_i=wbeg))
    else
      ((TE_i--))
    fi
  done
  ((color_umin>=0)) && ble/highlight/layer:syntax/touch-range "$color_umin" "$color_umax"

  _ble_syntax_word_umin=-1 _ble_syntax_word_umax=-1
}

function ble/highlight/layer:syntax/update-error-table/set {
  local i1=$1 i2=$2 g=$3
  if ((i1<i2)); then
    ble/highlight/layer:syntax/touch-range "$i1" "$i2"
    ble/highlight/layer:syntax/fill _ble_highlight_layer_syntax3_table "$i1" "$i2" "$g"
    _ble_highlight_layer_syntax3_list[${#_ble_highlight_layer_syntax3_list[@]}]="$i1 $i2"
  fi
}
function ble/highlight/layer:syntax/update-error-table {
  ble/highlight/layer/update/shift _ble_highlight_layer_syntax3_table

  # clear old errors
  #   It is easier to update before shift, but
  #   Process after shift to update umin umax.
  local j=0 jN=${#_ble_highlight_layer_syntax3_list[*]}
  if ((jN)); then
    for ((j=0;j<jN;j++)); do
      local -a range
      ble/string#split-words range "${_ble_highlight_layer_syntax3_list[j]}"

      local a=${range[0]} b=${range[1]}
      ((a>=DMAX0?(a+=DMAX-DMAX0):(a>=DMIN&&(a=DMIN)),
        b>=DMAX0?(b+=DMAX-DMAX0):(b>=DMIN&&(b=DMIN))))
      if ((a<b)); then
        ble/highlight/layer:syntax/fill _ble_highlight_layer_syntax3_table "$a" "$b" ''
        ble/highlight/layer:syntax/touch-range "$a" "$b"
      fi
    done
    _ble_highlight_layer_syntax3_list=()
  fi

  # This implementation sets all errors each time, so
  # Actually, you can do as below...
  #_ble_highlight_layer_syntax3_table=()

  # set errors
  if ((iN>0)) && [[ ${_ble_syntax_stat[iN]} ]]; then
    # Not executed when iN==0. face for lazy initialization (initially iN==0).
    local ret; ble/color/face2g syntax_error; local g=$ret

    # Nested not closed error
    local -a stat
    ble/string#split-words stat "${_ble_syntax_stat[iN]}"
    local ctx=${stat[0]} nlen=${stat[3]} nparam=${stat[6]}
    [[ $nparam == none ]] && nparam=
    local i inest
    if ((nlen>0)) || [[ $nparam ]]; then
      # Coloring the end points
      ble/highlight/layer:syntax/update-error-table/set "$((iN-1))" "$iN" "$g"

      if ((nlen>0)); then
        ((inest=iN-nlen))
        while ((inest>=0)); do
          # Start lexical coloring
          local inest2
          for ((inest2=inest+1;inest2<iN;inest2++)); do
            [[ ${_ble_syntax_attr[inest2]} ]] && break
          done
          ble/highlight/layer:syntax/update-error-table/set "$inest" "$inest2" "$g"

          ((i=inest))
          local wtype wbegin tchild tprev
          ble/syntax/parse/nest-pop
          ((inest>=i&&(inest=i-1)))
        done
      fi
    fi

    # Missing command/missing argument
    if ((ctx==_ble_ctx_CMDX1||ctx==_ble_ctx_CMDXC||ctx==_ble_ctx_FARGX1||ctx==_ble_ctx_SARGX1||ctx==_ble_ctx_FARGX2||ctx==_ble_ctx_CARGX1||ctx==_ble_ctx_CARGX2||ctx==_ble_ctx_COARGX)); then
      # Coloring the end points
      ble/highlight/layer:syntax/update-error-table/set "$((iN-1))" "$iN" "$g"
    fi
  fi
}

function ble/highlight/layer:syntax/update {
  local text=$1 player=$2
  local i iN=${#text}

  local umin=-1 umax=-1
  # At least in this range, the characters have changed, so it needs to be redrawn.
  ((DMIN>=0)) && umin=$DMIN umax=$DMAX

  # This time when layer:syntax is disabled
  if [[ ! $bleopt_highlight_syntax ]]; then
    if [[ $_ble_highlight_layer_syntax_active ]]; then
      _ble_highlight_layer_syntax_active=
      PREV_UMIN=0 PREV_UMAX=${#1}
    fi
    return 0
  fi

  # Last time layer:syntax was invalid
  if [[ ! $_ble_highlight_layer_syntax_active ]]; then
    # Request full update
    _ble_highlight_layer_syntax_active=1
    umin=0 umax=${#text}
  fi

  #--------------------------------------------------------

  if [[ $bleopt_syntax_debug ]]; then
    local debug_attr_umin=$_ble_syntax_attr_umin
    local debug_attr_uend=$_ble_syntax_attr_umax
  fi

  ble/cmdspec/initialize # load chroma
  ble/highlight/layer:syntax/update-attribute-table
  ble/highlight/layer:syntax/update-word-table
  ble/highlight/layer:syntax/update-error-table

  # shift&sgr settings
  if ((DMIN>=0)); then
    ble/highlight/layer/update/shift _ble_highlight_layer_syntax_buff
    if ((DMAX>0)); then
      local g sgr ch ret
      ble/highlight/layer:syntax/getg "$DMAX"
      ble/color/g2sgr "$g"; sgr=$ret
      ch=${_ble_highlight_layer_plain_buff[DMAX]}
      _ble_highlight_layer_syntax_buff[DMAX]=$sgr$ch
    fi
  fi

  local i j g gprev=0
  if ((umin>0)); then
    ble/highlight/layer:syntax/getg "$((umin-1))"
    gprev=$g
  fi

  if ((umin>=0)); then
    local ret
    for ((i=umin;i<=umax;i++)); do
      local ch=${_ble_highlight_layer_plain_buff[i]}
      ble/highlight/layer:syntax/getg "$i"
      [[ $g ]] || ble/highlight/layer/update/getg "$i"
      if ((gprev!=g)); then
        ble/color/g2sgr "$g"
        ch=$ret$ch
        ((gprev=g))
      fi
      _ble_highlight_layer_syntax_buff[i]=$ch
    done
  fi

  PREV_UMIN=$umin PREV_UMAX=$umax
  PREV_BUFF=_ble_highlight_layer_syntax_buff

  if [[ $bleopt_syntax_debug ]]; then
    local status buff= nl=$'\n'
    _ble_syntax_attr_umin=$debug_attr_umin _ble_syntax_attr_umax=$debug_attr_uend ble/syntax/print-status -v status

    local -a DRAW_BUFF=()
    ble/syntax/print-layer-buffer.draw plain
    ble/syntax/print-layer-buffer.draw syntax
    ble/syntax/print-layer-buffer.draw disabled
    ble/syntax/print-layer-buffer.draw region
    ble/syntax/print-layer-buffer.draw overwrite
    local ret; ble/canvas/sflush.draw
    status=$status$ret
    #ble/util/assign buff 'declare -p _ble_textarea_bufferName $_ble_textarea_bufferName | cat -A'; status="$status$buff"
    ble/edit/info/show ansi "$status"
  fi

  # # The following is for debugging word splitting
  # local -a words=() word
  # for ((i=1;i<=iN;i++)); do
  #   if [[ ${_ble_syntax_tree[i-1]} ]]; then
  #     ble/string#split-words word "${_ble_syntax_tree[i-1]}"
  #     local wtxt="${text:i-word[1]:word[1]}" value
  #     if ble/syntax:bash/simple-word/is-simple "$wtxt"; then
  #       local ret; ble/syntax:bash/simple-word/eval "$wtxt" noglob; value=$ret
  #     else
  #       value="? ($wtxt)"
  #     fi
  #     ble/array#push words "[$value ${word[*]}]"
  #   fi
  # done
  # ble/edit/info/show text "${words[*]}"
}

function ble/highlight/layer:syntax/getg {
  [[ $bleopt_highlight_syntax ]] || return 1
  local i=$1
  if [[ ${_ble_highlight_layer_syntax3_table[i]} ]]; then
    g=${_ble_highlight_layer_syntax3_table[i]}
  elif [[ ${_ble_highlight_layer_syntax2_table[i]} ]]; then
    g=${_ble_highlight_layer_syntax2_table[i]}
  elif [[ ${_ble_highlight_layer_syntax1_table[i]} ]]; then
    g=${_ble_highlight_layer_syntax1_table[i]}
  fi
}

function ble/highlight/layer:syntax/textarea_render_defer.hook {
  ble/syntax/wrange#update _ble_syntax_word_ "$_ble_syntax_word_defer_umin" "$_ble_syntax_word_defer_umax"
  _ble_syntax_word_defer_umin=-1
  _ble_syntax_word_defer_umax=-1
}
blehook textarea_render_defer!=ble/highlight/layer:syntax/textarea_render_defer.hook


function ble/syntax/import { return 0; }

blehook/invoke syntax_load
ble/function#try ble/textarea#invalidate str

return 0
