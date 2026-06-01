#!/bin/bash

ble/util/import "$_ble_base/lib/core-syntax.sh"

## @fn ble/complete/string#search-longest-suffix-in needle haystack
##   @var[out] ret
function ble/complete/string#search-longest-suffix-in {
  local needle=$1 haystack=$2
  local l=0 u=${#needle}
  while ((l<u)); do
    local m=$(((l+u)/2))
    if [[ $haystack == *"${needle:m}"* ]]; then
      u=$m
    else
      l=$((m+1))
    fi
  done
  ret=${needle:l}
}
## @fn ble/complete/string#common-suffix-prefix lhs rhs
##   @var[out] ret
function ble/complete/string#common-suffix-prefix {
  local lhs=$1 rhs=$2
  if ((${#lhs}<${#rhs})); then
    local i n=${#lhs}
    for ((i=0;i<n;i++)); do
      ret=${lhs:i}
      [[ $rhs == "$ret"* ]] && return 0
    done
    ret=
  else
    local j m=${#rhs}
    for ((j=m;j>0;j--)); do
      ret=${rhs::j}
      [[ $lhs == *"$ret" ]] && return 0
    done
    ret=
  fi
}

## @fn ble/complete/string#match-patterns str patterns...
## Tests whether the specified string matches any pattern in the patterns set.
##   @param[in] str
##   @param[in] patterns
##   @exit
function ble/complete/string#match-patterns {
  local s=$1 found= pattern; shift
  for pattern; do
    if [[ $s == $pattern ]]; then
      return 0
    fi
  done
  return 1
}

## @fn ble/complete/get-wordbreaks
##   @var[out] wordbreaks
function ble/complete/get-wordbreaks {
  wordbreaks=$_ble_term_IFS$COMP_WORDBREAKS
  [[ $wordbreaks == *'('* ]] && wordbreaks=${wordbreaks//['()']}'()'
  [[ $wordbreaks == *']'* ]] && wordbreaks=']'${wordbreaks//']'}
  [[ $wordbreaks == *'-'* ]] && wordbreaks=${wordbreaks//'-'}'-'
}

# 
#==============================================================================
# Selection interface (ble/complete/menu)

## @arr _ble_complete_menu_page_icons
##
## Each element is a string in the following format.
##
##   x0,y0,x1,y1,${#pack},${#esc1}[,bbox]:$pack$esc1
##
## * x0,y0 and x1,y1 are the drawing start and end points of the menu item.
## * esc1 is the drawing sequence to actually output.
## * bbox has the form "x y cols lines" and is used when generating a drawing sequence.
## Stores information about the bbox used. This is especially true when a truncate occurs.
## Refer to this when drawing a state under the same conditions.

_ble_complete_menu_items=()
_ble_complete_menu_class=
_ble_complete_menu_param=
_ble_complete_menu_page_style=
_ble_complete_menu_page_index=
_ble_complete_menu_page_offset=
_ble_complete_menu_page_icons=()
_ble_complete_menu_page_infodata=()
_ble_complete_menu_selected=-1

function ble/complete/menu#check-cancel {
  ((menu_iloop++%menu_interval==0)) &&
    [[ :$menu_construct_opts: != *:sync:* ]] &&
    ble/decode/has-input
}

## @fn ble/complete/menu-style:$menu_style/construct-page
## Calculate the display/arrangement of the candidate list menu.
##
##   @var[in] menu_style
##   @arr[in] menu_items
##   @var[in] menu_class menu_param
##   @var[in] cols lines
##   @var[in,out] begin
##   @var[out] end
##   @var[out] x y esc
##
## @fn ble/complete/menu-style:$menu_style/guess
## scroll Predict which page the th candidate is on.
## Returns the first possible page number ipage.
##
##   @var[in] scroll
##   @var[out] ipage begin end
##   @var[in] cols lines
##

_ble_complete_menu_style_hash=
_ble_complete_menu_style_measure=()
_ble_complete_menu_style_icons=()
_ble_complete_menu_style_pages=()

#
# ble/complete/menu-style:align
#

## @fn ble/complete/menu#render-item item opts
##   @var[in] cols lines
## Note: Used in "$menu_class"/render-item.
##   @var[out] x y ret
function ble/complete/menu#render-item {
  # use custom renderer
  if ble/is-function "$menu_class"/render-item; then
    "$menu_class"/render-item "$@"
    return "$?"
  fi

  local item=$1 opts=$2
  #g=0 lc=0 lg=0 LINES=$lines COLUMNS=$cols ble/canvas/trace "$item" truncate:ellipsis

  local sgr0=$_ble_term_sgr0 sgr1=$_ble_term_rev
  [[ :$opts: == *:selected:* ]] && local sgr0=$sgr1 sgr1=$sgr0
  ble/canvas/trace-text "$item" nonewline:external-sgr
  ret=$sgr0$ret$_ble_term_sgr0
}

## @fn ble/complete/menu#get-prefix-width format column_width
##   @param[in] format
##   @param[in] column_width
##   @var[out] prefix_width
##   @var[out] prefix_format
function ble/complete/menu#get-prefix-width {
  prefix_width=0
  prefix_format=${1:-$bleopt_menu_prefix}
  if [[ $prefix_format ]]; then
    local prefix1 column_width=$2
    ble/util/sprintf prefix1 "$prefix_format" "${#menu_items[@]}"
    local x1 y1 x2 y2 g=0
    LINES=1 COLUMNS=$column_width x=0 y=0 ble/canvas/trace "$prefix1" truncate:measure-bbox
    if ((x2<=column_width/2)); then
      prefix_width=$x2
      ble/string#reserve-prototype "$prefix_width"
    fi
  fi
}

## @fn ble/complete/menu#render-prefix index
##   @param[in] index
##   @param[in,opt] column_width
##   @var[in] prefix_width
##   @var[in] prefix_format
##   @var[out] prefix_esc
function ble/complete/menu#render-prefix {
  prefix_esc=
  local index=$1
  if ((prefix_width)); then
    local prefix1; ble/util/sprintf prefix1 "$prefix_format" "$((index+1))"
    local x=0 y=0 g=0
    LINES=1 COLUMNS=$prefix_width ble/canvas/trace "$prefix1" truncate:relative
    prefix_esc=$ret$_ble_term_sgr0
    if ((x<prefix_width)); then
      prefix_esc=${_ble_string_prototype::prefix_width-x}$prefix_esc
    fi
  fi
}

## @fn ble/complete/menu-style:align/construct/.measure-candidates-in-page
## Measure the width of the candidate within the range that fits on the page
##   @var[in] begin
## Specify the candidate to be displayed at the beginning of the page.
##   @var[out] end
## Returns the end of the range of candidates to display on the page.
## In reality, when drawing, you can change the characters by moving characters such as full-width characters.
## It is not always possible to display this much.
##   @var[out] wcell
## Returns the cell width when drawing the page.
##   @arr[in,out] _ble_complete_menu_style_measure
## This is an array that caches measurement results.
##
##   @var[in] lines cols menu_iloop
function ble/complete/menu-style:align/construct/.measure-candidates-in-page {
  local max_wcell=$bleopt_menu_align_max; ((max_wcell>cols&&(max_wcell=cols)))
  ((wcell=bleopt_menu_align_min,wcell<2&&(wcell=2)))
  local ncell=0 index=$begin
  local item ret esc1 w
  for item in "${menu_items[@]:begin}"; do
    ble/complete/menu#check-cancel && return 148
    local wcell_old=$wcell

    # Calculate the candidate display width w
    local w=${_ble_complete_menu_style_measure[index]%%:*}
    if [[ ! $w ]]; then
      local prefix_esc
      ble/complete/menu#render-prefix "$index"
      local x=$prefix_width y=0
      ble/complete/menu#render-item "$item"; esc1=$ret
      local w=$((y*cols+x))
      _ble_complete_menu_style_measure[index]=$w:${#item},${#esc1}:$item$esc1$prefix_esc
    fi

    # wcell, ncell update
    local wcell_request=$((w++,w<=max_wcell?w:max_wcell))
    ((wcell<wcell_request)) && wcell=$wcell_request

    # new ncell
    local line_ncell=$((cols/wcell))
    local cand_ncell=$(((w+wcell-1)/wcell))
    if [[ $menu_style == align-nowrap ]]; then
      # Note: nowrap occurs when wcell == max_wcell, so
      # wcell does not change after line break processing is complete.
      local x1=$((ncell%line_ncell*wcell))
      local ncell_eol=$(((ncell/line_ncell+1)*line_ncell))
      if ((x1>0&&x1+w>=cols)); then
        # leading
        ((ncell=ncell_eol+cand_ncell))
      elif ((x1+w<cols)); then
        # If it fits in the margin
        ((ncell+=cand_ncell))
        ((ncell>ncell_eol&&(ncell=ncell_eol)))
      else
        ((ncell+=cand_ncell))
      fi
    else
      ((ncell+=cand_ncell))
    fi

    local max_ncell=$((line_ncell*lines))
    ((index&&ncell>max_ncell)) && { wcell=$wcell_old; break; }
    ((index++))
  done
  end=$index
}

## @fn ble/complete/menu-style:align/construct-page
##   @var[in,out] begin end x y esc
##   @arr[out] _ble_complete_menu_style_icons
##
##   @var[in,out] cols lines menu_iloop
function ble/complete/menu-style:align/construct-page {
  x=0 y=0 esc=

  local prefix_width prefix_format
  ble/complete/menu#get-prefix-width "$bleopt_menu_align_prefix" "$bleopt_menu_align_max"

  local wcell=2
  ble/complete/menu-style:align/construct/.measure-candidates-in-page
  (($?==148)) && return 148

  local ncell=$((cols/wcell))
  local index=$begin entry
  for entry in "${_ble_complete_menu_style_measure[@]:begin:end-begin}"; do
    ble/complete/menu#check-cancel && return 148

    local w=${entry%%:*}; entry=${entry#*:}
    local s=${entry%%:*}; entry=${entry#*:}
    local len; ble/string#split len , "$s"
    local item=${entry::len[0]} esc1=${entry:len[0]:len[1]} prefix_esc=${entry:len[0]+len[1]}

    local x0=$x y0=$y
    if ((x==0||x+w<cols)); then
      ((x+=w%cols,y+=w/cols))
      ((y>=lines&&(x=x0,y=y0,1))) && break
    else
      if [[ $menu_style == align-nowrap ]]; then
        ((y+1>=lines)) && break
        esc=$esc$'\n'
        ((x0=x=0,y0=++y))
        ((x=w%cols,y+=w/cols))
        ((y>=lines&&(x=x0,y=y0,1))) && break
      else
        ((x+=prefix_width))
        ble/complete/menu#render-item "$item" ||
          ((begin==index)) || #[Note: It will be displayed even if at least one item protrudes]
          { x=$x0 y=$y0; break; }; esc1=$ret
      fi
    fi

    _ble_complete_menu_style_icons[index]=$((x0+prefix_width)),$y0,$x,$y,${#item},${#esc1}:$item$esc1
    esc=$esc$prefix_esc$esc1

    # Space between candidates
    if ((++index<end)); then
      local icell=$((x==0?0:(x+wcell)/wcell))
      if ((icell<ncell)); then
        # next square
        local pad=$((icell*wcell-x))
        ble/string#reserve-prototype "$pad"
        esc=$esc${_ble_string_prototype::pad}
        ((x=icell*wcell))
      else
        # next line
        ((y+1>=lines)) && break
        esc=$esc$'\n'
        ((x=0,++y))
      fi
    fi
  done
  end=$index
}
function ble/complete/menu-style:align-nowrap/construct-page {
  ble/complete/menu-style:align/construct-page "$@"
}

#
# ble/complete/menu-style:dense
#

## @fn ble/complete/menu-style:dense/construct-page
##   @var[in,out] begin end x y esc
##   @var[in,out] cols lines menu_iloop
function ble/complete/menu-style:dense/construct-page {

  local prefix_width prefix_format
  ble/complete/menu#get-prefix-width "$bleopt_menu_dense_prefix" "$cols"

  x=0 y=0 esc=
  local item index=$begin N=${#menu_items[@]}
  for item in "${menu_items[@]:begin}"; do
    ble/complete/menu#check-cancel && return 148

    local x0=$x y0=$y

    local prefix_esc esc1
    ble/complete/menu#render-prefix "$index"
    ((x+=prefix_width,x>cols&&(y+=x/cols,x%=cols)))
    ble/complete/menu#render-item "$item" ||
      ((index==begin)) ||
      { x=$x0 y=$y0; break; }; esc1=$ret

    if [[ $menu_style == dense-nowrap ]]; then
      if ((y>y0&&x>0||y>y0+1)); then
        ((++y0>=lines)) && break
        esc=$esc$'\n'
        ((y=y0,x0=0,x=prefix_width))
        ble/complete/menu#render-item "$item" ||
          ((begin==index)) ||
          { x=$x0 y=$y0; break; }; esc1=$ret
      fi
    fi

    local x1=$((x0+prefix_width)) y1=$y0
    ((x1>=cols)) && ((y1+=x1/cols,x1%=cols))
    _ble_complete_menu_style_icons[index]=$x1,$y1,$x,$y,${#item},${#esc1}:$item$esc1
    esc=$esc$prefix_esc$esc1

    # Space between candidates
    if ((++index<N)); then
      if [[ $menu_style == dense-nowrap ]] && ((x==0)); then
        : skip
      elif ((x+1<cols)); then
        esc=$esc' '
        ((x++))
      else
        ((y+1>=lines)) && break
        esc=$esc$'\n'
        ((x=0,++y))
      fi
    fi
  done
  end=$index
}
## @fn ble/complete/menu-style:dense/construct opts
## Align suggestions for complete_menu_style=align{,-nowrap}.
function ble/complete/menu-style:dense-nowrap/construct-page {
  ble/complete/menu-style:dense/construct-page "$@"
}

#
# ble/complete/menu-style:linewise
#

## @fn ble/complete/menu-style:linewise/construct-page opts
##   @var[in,out] begin end x y esc
function ble/complete/menu-style:linewise/construct-page {
  local opts=$1 ret
  local max_icon_width=$((cols-1))

  local prefix_width prefix_format
  ble/complete/menu#get-prefix-width "$bleopt_menu_linewise_prefix" "$max_icon_width"

  local item x0 y0 esc1 index=$begin
  end=$begin x=0 y=0 esc=
  for item in "${menu_items[@]:begin:lines}"; do
    ble/complete/menu#check-cancel && return 148

    local prefix_esc=
    ble/complete/menu#render-prefix "$index" "$max_icon_width"
    esc=$esc$prefix_esc
    ((x=prefix_width))

    ((x0=x,y0=y))
    local lines1=1 cols1=$max_icon_width
    lines=$lines1 cols=$cols1 y=0 ble/complete/menu#render-item "$item"; esc1=$ret
    _ble_complete_menu_style_icons[index]=$x0,$y0,$x,$y,${#item},${#esc1},"$x0 0 $cols1 $lines1":$item$esc1
    ((index++))
    esc=$esc$esc1

    ((y+1>=lines)) && break
    ((x=0,++y))
    esc=$esc$'\n'
  done
  end=$index
}
function ble/complete/menu-style:linewise/guess {
  ((ipage=scroll/lines,
    begin=ipage*lines,
    end=begin))
}

#
# ble/complete/menu-style:desc
#

_ble_complete_menu_desc_pageheight=()

## @fn ble/complete/menu-style:desc/construct-page opts
##   @var[in,out] begin end x y esc
##   @var[in] ipage
function ble/complete/menu-style:desc/construct-page {
  local opts=$1 ret
  local opt_raw=; [[ $menu_style != desc-text ]] && opt_raw=1

  # Default value in case of failure/error
  end=$begin esc= x=0 y=0

  local colsep=' | '
  local desc_sgr0=$'\e[m'
  ble/color/face2sgr-ansi menu_desc_quote; local desc_sgrq=$ret
  ble/color/face2sgr-ansi menu_desc_type; local desc_sgrt=$ret

  local ncolumn=1 nline=$lines
  local nrest_item=$((${#menu_items[@]}-begin))
  if [[ $bleopt_menu_desc_multicolumn_width ]]; then
    ncolumn=$((cols/bleopt_menu_desc_multicolumn_width))
    if ((ncolumn<1)); then
      ncolumn=1
    elif ((ncolumn>nrest_item)); then
      ncolumn=$nrest_item
    fi
  fi
  ((nline=(${#menu_items[@]}-begin+ncolumn-1)/ncolumn,
    nline>lines&&(nline=lines)))
  local ncolumn_max=$(((nrest_item+nline-1)/nline))
  ((ncolumn>ncolumn_max&&(ncolumn=ncolumn_max)))

  # Note #D1727: During relative movement, when touching the right edge, the behavior differs depending on the terminal.
  # This is a problem, so set it to col-1 so that it does not touch the right end. some devices
  # Since we know that the relative movement will not be broken even if it touches the right edge,
  # Allow touching the right edge with white list.
  local available_width=$cols
  case $_ble_term_TERM in
  (screen:*|tmux:*|kitty:*|contra:*) ;;
  (*) ((available_width--)) ;;
  esac

  local wcolumn=$(((available_width-${#colsep}*(ncolumn-1))/ncolumn))

  local prefix_width prefix_format
  ble/complete/menu#get-prefix-width "$bleopt_menu_desc_prefix" "$wcolumn"
  ((wcolumn>=prefix_width+15)) || prefix_width=0

  local wcand_limit=$(((wcolumn-prefix_width+1)*2/3))
  ((wcand_limit<10&&(wcand_limit=wcolumn-prefix_width)))

  local -a DRAW_BUFF=()
  local index=$begin icolumn ymax=0
  for ((icolumn=0;icolumn<ncolumn;icolumn++)); do

    # Draw each candidate and calculate the width
    local measure; measure=()
    local pack w esc1 max_width=0
    for pack in "${menu_items[@]:index:nline}"; do
      ble/complete/menu#check-cancel && return 148

      x=0 y=0
      lines=1 cols=$wcand_limit ble/complete/menu#render-item "$pack"; esc1=$ret
      ((w=y*wcand_limit+x,w>max_width&&(max_width=w)))

      ble/array#push measure "$w:${#pack}:$pack$esc1"
    done

    local cand_width=$max_width
    local desc_x=$((prefix_width+cand_width+1)); ((desc_x>wcolumn&&(desc_x=wcolumn)))
    local desc_prefix=; ((wcolumn-prefix_width-desc_x>30)) && desc_prefix=': '

    local xcolumn=$((icolumn*(wcolumn+${#colsep})))

    x=0 y=0
    local entry w s pack esc1 x0 y0 pad
    for entry in "${measure[@]}"; do
      ble/complete/menu#check-cancel && return 148

      w=${entry%%:*} entry=${entry#*:}
      s=${entry%%:*} entry=${entry#*:}
      pack=${entry::s} esc1=${entry:s}

      local prefix_esc
      ble/complete/menu#render-prefix "$index"
      ble/canvas/put.draw "$prefix_esc"
      ((x+=prefix_width))

      # Candidate display
      ((x0=x,y0=y,x+=w))
      _ble_complete_menu_style_icons[index]=$((xcolumn+x0)),$y0,$((xcolumn+x)),$y,${#pack},${#esc1},"0 0 $wcand_limit 1":$pack$esc1
      ((index++))
      ble/canvas/put.draw "$esc1"

      # margin
      ble/canvas/put-spaces.draw "$((pad=desc_x-x))"
      ble/canvas/put.draw "$desc_prefix"
      ((x+=pad+${#desc_prefix}))

      # Explanation display
      local desc=$desc_sgrt'(no description)'$desc_sgr0
      ble/function#try "$menu_class"/get-desc "$pack"
      if [[ $opt_raw ]]; then
        y=0 g=0 lc=0 lg=0 LINES=1 COLUMNS=$wcolumn ble/canvas/trace.draw "$desc" truncate:relative:ellipsis:face0=menu_desc_default
      else
        ble/color/face2sgr menu_desc_default
        ble/canvas/put.draw "$ret"
        y=0 lines=1 cols=$wcolumn ble/canvas/trace-text "$desc" nonewline
        ble/canvas/put.draw "$ret"
      fi
      ble/canvas/put.draw "$_ble_term_sgr0"
      ((y+1>=nline)) && break
      ble/canvas/put-move.draw "$((-x))" 1
      ((x=0,++y))
    done
    ((y>ymax)) && ymax=$y

    if ((icolumn+1<ncolumn)); then
      # Output column divider (move to start of next column at the end)
      ble/canvas/put-move.draw "$((wcolumn-x))" "$((-y))"
      for ((y=0;y<=ymax;y++)); do
        ble/canvas/put.draw "$colsep"
        if ((y<ymax)); then
          ble/canvas/put-move.draw -${#colsep} 1
        else
          ble/canvas/put-move-y.draw "$((-y))"
        fi
      done
    else
      ((y<ymax)) && ble/canvas/put-move-y.draw "$((ymax-y))"
      ((x+=xcolumn,y=ymax))
    fi
  done

  _ble_complete_menu_desc_pageheight[ipage]=$nline
  end=$index
  ble/canvas/sflush.draw -v esc
}
function ble/complete/menu-style:desc/guess {
  local ncolumn=1
  if [[ $bleopt_menu_desc_multicolumn_width ]]; then
    ncolumn=$((cols/bleopt_menu_desc_multicolumn_width))
    ((ncolumn<1)) && ncolumn=1
  fi
  local nitem_per_page=$((ncolumn*lines))
  ((ipage=scroll/nitem_per_page,
    begin=ipage*nitem_per_page,
    end=begin))
}
function ble/complete/menu-style:desc/locate {
  local type=$1 osel=$2
  local ipage=$_ble_complete_menu_page_index
  local nline=${_ble_complete_menu_desc_pageheight[ipage]:-1}

  case $type in
  (right) ((ret=osel+nline)) ;;
  (left)  ((ret=osel-nline)) ;;
  (down)  ((ret=osel+1)) ;;
  (up)    ((ret=osel-1)) ;;
  (*) return 1 ;;
  esac

  local beg=$_ble_complete_menu_page_offset
  local end=$((beg+${#_ble_complete_menu_page_icons[@]}))
  if ((ret<beg)); then
    ((ret=beg-1))
  elif ((ret>end)); then
    ((ret=end))
  fi
  return 0
}

function ble/complete/menu-style:desc-text/construct-page { ble/complete/menu-style:desc/construct-page "$@"; }
function ble/complete/menu-style:desc-text/guess { ble/complete/menu-style:desc/guess; }
function ble/complete/menu-style:desc-text/locate { ble/complete/menu-style:desc/locate "$@"; }

# Obsolete menu_style (now synonym to "desc")
function ble/complete/menu-style:desc-raw/construct-page { ble/complete/menu-style:desc/construct-page "$@"; }
function ble/complete/menu-style:desc-raw/guess { ble/complete/menu-style:desc/guess; }
function ble/complete/menu-style:desc-raw/locate { ble/complete/menu-style:desc/locate "$@"; }

## @fn ble/complete/menu#construct/.initialize-size
##   @var[out] cols lines
function ble/complete/menu#construct/.initialize-size {
  ble/edit/info/.initialize-size
  local maxlines=$((bleopt_complete_menu_maxlines))
  ((maxlines>0&&lines>maxlines)) && lines=$maxlines
}
## @fn ble/complete/menu#construct opts
## adapter part of implementation separation
##
##   @param[in] opts
##     A colon-separated list of options.
##
##     @opt scroll=INT
##       This option is used to select the page that contains the item
##       specified by the index INT.
##
##     @opt sync
##       Do not cancel menu preparation on the user input.  Note: This is
##       implemented through ble/complete/menu#check-cancel.
##
##   @var[in] menu_style
##
##   @arr[in] menu_items
## Specifies a list of items.
##
##   @var[in] menu_class menu_param
## These variables are used to call the various callbacks listed below.
##
##   @fn[in,opt] $menu_class/render-item item opts
## Specify the renderer function that determines the rendering content for each item.
##     @param[in] item
## Specifies the item to be drawn.
##     @param[in] opts
##       selected
## Indicates that the selected item will be drawn.
##     @var[in] lines cols
## Specify the number of rows and columns in the drawing range.
##     @var[in,out] x y
## Specify the drawing start position. Returns the ending position.
##     @var[out] ret
## Returns the sequence used for drawing.
##
##   @fn[in,opt] $menu_class/onselect nsel osel
## Specifies the callback that will be called when the item is selected.
##     @param[in] nsel osel
##
##   @fn[in,opt] $menu_class/get-desc item
## Gets the item's description.
##     @param[out] desc
##
##   @fn[in,opt] $menu_class/onaccept nsel [item]
##   @fn[in,opt] $menu_class/oncancel nsel
##
function ble/complete/menu#construct {
  local menu_construct_opts=$1
  local menu_iloop=0
  local menu_interval=$bleopt_complete_polling_cycle

  _ble_complete_menu_items=("${menu_items[@]}")
  _ble_complete_menu_class=$menu_class
  _ble_complete_menu_param=$menu_param
  _ble_complete_menu_selected=-1

  local nitem=${#menu_items[@]}
  if [[ :$menu_construct_opts: == *:hidden:* ]]; then
    ble/array#reserve-prototype "$nitem"
    _ble_complete_menu_page_style=
    _ble_complete_menu_page_index=
    _ble_complete_menu_page_offset=
    _ble_complete_menu_page_icons=("${_ble_array_prototype[@]::nitem}")
    _ble_complete_menu_page_infodata=(store 0 0 '')
    return 0
  elif ((nitem==0)); then
    # Special display when there is no item
    _ble_complete_menu_page_style=
    _ble_complete_menu_page_index=0
    _ble_complete_menu_page_offset=0
    _ble_complete_menu_page_icons=()
    _ble_complete_menu_page_infodata=(ansi $'\e[38;5;242m(no items)\e[m')
    return 0
  fi

  local cols lines
  ble/complete/menu#construct/.initialize-size
  local hash=$nitem,$lines,$cols:$menu_style

  # Specifying the items you want to display
  local scroll=0 use_cache=
  if ble/string#match ":$menu_construct_opts:" ':scroll=([0-9]+):'; then
    scroll=${BASH_REMATCH[1]}
    ((nitem&&(scroll%=nitem)))
    [[ $hash == "$_ble_complete_menu_style_hash" ]] && use_cache=1
  fi
  if [[ ! $use_cache ]]; then
    _ble_complete_menu_style_measure=()
    _ble_complete_menu_style_icons=()
    _ble_complete_menu_style_pages=()
  fi
  _ble_complete_menu_style_hash=$hash

  local begin=0 end=0 ipage=0 x y esc
  ble/function#try ble/complete/menu-style:"$menu_style"/guess
  while ((end<nitem)); do
    ((scroll<begin)) && return 1
    local page_data=${_ble_complete_menu_style_pages[ipage]}
    if [[ $page_data ]]; then
      # Read from cache if cache exists
      local fields; ble/string#split fields , "${page_data%%:*}"
      begin=${fields[0]} end=${fields[1]}
      if ((begin<=scroll&&scroll<end)); then
        x=${fields[2]} y=${fields[3]} esc=${page_data#*:}
        break
      fi
    else
      # Build the page when there is no cache
      ble/complete/menu-style:"$menu_style"/construct-page "$menu_construct_opts" || return "$?"
      _ble_complete_menu_style_pages[ipage]=$begin,$end,$x,$y:$esc
      ((begin<=scroll&&scroll<end)) && break
    fi
    begin=$end
    ((ipage++))
  done

  _ble_complete_menu_page_style=$menu_style
  _ble_complete_menu_page_index=$ipage
  _ble_complete_menu_page_offset=$begin
  _ble_complete_menu_page_icons=("${_ble_complete_menu_style_icons[@]:begin:end-begin}")
  _ble_complete_menu_page_infodata=(store "$x" "$y" "$esc")
  return 0
}

function ble/complete/menu#show {
  ble/edit/info/immediate-show "${_ble_complete_menu_page_infodata[@]}"
}
function ble/complete/menu#clear {
  ble/edit/info/default
}

## @fn ble/complete/menu#select/.erase-item-selection.draw i
##   @param[in] i
##     Index of the item in the current page.
##
##   @var[in] infoy
##   @var[in] _ble_complete_menu_page_icons
##   @var[in] _ble_canvas_panel_height
##   @var[in] _ble_edit_info_panel
##   @var[out] _ble_canvas_x _ble_canvas_y
function ble/complete/menu#select/.erase-item-selection.draw {
  local i=$1
  local entry=${_ble_complete_menu_page_icons[i]}
  [[ $entry ]] || return 1

  local fields text=${entry#*:}
  ble/string#split fields , "${entry%%:*}"

  ((fields[3]<_ble_canvas_panel_height[_ble_edit_info_panel])) || return 1

  # Note: The info panel may be deleted due to changes in the contents of the edited string.
  # Draws only when the current item is properly inside the info panel. (#D0880)

  ble/canvas/panel#goto.draw "$_ble_edit_info_panel" "${fields[@]::2}"
  ble/canvas/put.draw "${text:fields[4]}"
  _ble_canvas_x=${fields[2]} _ble_canvas_y=$((infoy+fields[3]))
}

## @fn ble/complete/menu#select/.render-item-selection.draw i
##   @param[in] i
##     Index of the item in the current page.
##
##   @var[in] infoy
##   @var[in] _ble_complete_menu_page_icons
##   @var[in] _ble_canvas_panel_height
##   @var[in] _ble_edit_info_panel
##   @var[out] _ble_canvas_x _ble_canvas_y
##
##   @exit 1
##     This means that the selected item is not rendered (not registered in
##     _ble_complete_menu_page_icons) because the item is hidden.
##   @exit 12
##     Request re-arrangement of the menu items.  This is caused when the item
##     is not in the original page due to the size change of the info panel.
function ble/complete/menu#select/.render-item-selection.draw {
  local i=$1
  local entry=${_ble_complete_menu_page_icons[i]}
  [[ $entry ]] || return 1

  local fields text=${entry#*:}
  ble/string#split fields , "${entry%%:*}"

  local x=${fields[0]} y=${fields[1]}
  local item=${text::fields[4]}

  # construct reverted candidate
  local ret
  if [[ ${fields[6]} ]]; then
    local box cols lines
    ble/string#split-words box "${fields[6]}"
    x=${box[0]} y=${box[1]} cols=${box[2]} lines=${box[3]}
    ble/complete/menu#render-item "$item" selected
    ((x+=fields[0]-box[0]))
    ((y+=fields[1]-box[1]))
  else
    local cols lines
    ble/complete/menu#construct/.initialize-size
    ble/complete/menu#render-item "$item" selected
  fi

  # Note: The info panel may be deleted due to changes in the contents of the edited string.
  # Draws only when the current item is properly inside the info panel. (#D0880)
  ((y<_ble_canvas_panel_height[_ble_edit_info_panel])) || return 12

  ble/canvas/panel#goto.draw "$_ble_edit_info_panel" "${fields[@]::2}"
  ble/canvas/put.draw "$ret"
  _ble_canvas_x=$x _ble_canvas_y=$((infoy+y))
}

## @fn ble/complete/menu#select index [opts]
##   @param[in] opts
##     goto-page-top
## After moving to the page containing the specified item,
## Specifies to move to the top item on the page.
function ble/complete/menu#select {
  local menu_class=$_ble_complete_menu_class
  local menu_param=$_ble_complete_menu_param
  local osel=$_ble_complete_menu_selected nsel=$1 opts=$2
  local ncand=${#_ble_complete_menu_items[@]}
  ((0<=osel&&osel<ncand)) || osel=-1
  ((0<=nsel&&nsel<ncand)) || nsel=-1
  ((osel==nsel)) && return 0

  local infox infoy
  ble/canvas/panel#get-origin "$_ble_edit_info_panel" --prefix=info

  # Page update
  local visible_beg=0
  local visible_end=$ncand
  if [[ :$_ble_complete_menu_opts: != *:hidden:* ]]; then
    visible_beg=$_ble_complete_menu_page_offset
    visible_end=$((visible_beg+${#_ble_complete_menu_page_icons[@]}))
    if ((nsel>=0&&!(visible_beg<=nsel&&nsel<visible_end))); then
      ble/complete/menu/show scroll="$nsel"; local ext=$?
      ((ext)) && return "$ext"

      if [[ $_ble_complete_menu_page_index ]]; then
        local ipage=$_ble_complete_menu_page_index
        ble/term/visible-bell "menu: Page $((ipage+1))" persistent
      else
        ble/term/visible-bell "menu: Offset $_ble_complete_menu_page_offset/$ncand" persistent
      fi

      visible_beg=$_ble_complete_menu_page_offset
      visible_end=$((visible_beg+${#_ble_complete_menu_page_icons[@]}))

      # For menu_style that doesn't support scrolling or when you scroll too much.
      ((visible_end<=nsel&&(nsel=visible_end-1)))
      ((nsel<=visible_beg&&(nsel=visible_beg)))
      ((visible_beg<=osel&&osel<visible_end)) || osel=-1
    fi
  fi

  local -a DRAW_BUFF=()
  local ret; ble/canvas/panel/save-position; local pos0=$ret
  if ((osel>=0)); then
    ble/complete/menu#select/.erase-item-selection.draw "$((osel-visible_beg))"
  fi

  local value=
  if ((nsel>=0)); then
    [[ :$opts: == *:goto-page-top:* ]] && nsel=$visible_beg

    ble/complete/menu#select/.render-item-selection.draw "$((nsel-visible_beg))"

    _ble_complete_menu_selected=$nsel
  else
    _ble_complete_menu_selected=-1
    value=$_ble_complete_menu_original
  fi
  ble/canvas/panel/load-position.draw "$pos0"
  ble/canvas/bflush.draw

  ble/function#try "$menu_class"/onselect "$nsel" "$osel"
  return 0
}

# widgets

function ble/widget/menu/forward {
  local opts=$1
  local nsel=$((_ble_complete_menu_selected+1))
  local ncand=${#_ble_complete_menu_items[@]}
  if ((nsel>=ncand)); then
    if [[ :$opts: == *:cyclic:* ]] && ((ncand>=2)); then
      nsel=0
    else
      ble/widget/.bell "menu: no more candidates"
      return 1
    fi
  fi
  ble/complete/menu#select "$nsel"
}
function ble/widget/menu/backward {
  local opts=$1
  local nsel=$((_ble_complete_menu_selected-1))
  if ((nsel<0)); then
    local ncand=${#_ble_complete_menu_items[@]}
    if [[ :$opts: == *:cyclic:* ]] && ((ncand>=2)); then
      ((nsel=ncand-1))
    else
      ble/widget/.bell "menu: no more candidates"
      return 1
    fi
  fi
  ble/complete/menu#select "$nsel"
}

function ble/widget/menu/forward-column {
  local osel=$((_ble_complete_menu_selected))
  if local ret; ble/function#try ble/complete/menu-style:"$_ble_complete_menu_page_style"/locate right "$osel"; then
    local nsel=$ret ncand=${#_ble_complete_menu_items[@]}
    if ((0<=nsel&&nsel<ncand&&nsel!=osel)); then
      ble/complete/menu#select "$nsel"
    else
      ble/widget/.bell "menu: no more candidates"
    fi
  else
    ble/widget/menu/forward
  fi
}
function ble/widget/menu/backward-column {
  local osel=$((_ble_complete_menu_selected))
  if local ret; ble/function#try ble/complete/menu-style:"$_ble_complete_menu_page_style"/locate left "$osel"; then
    local nsel=$ret ncand=${#_ble_complete_menu_items[@]}
    if ((0<=nsel&&nsel<ncand&&nsel!=osel)); then
      ble/complete/menu#select "$nsel"
    else
      ble/widget/.bell "menu: no more candidates"
    fi
  else
    ble/widget/menu/backward
  fi
}

_ble_complete_menu_lastcolumn=
## @fn ble/widget/menu/.check-last-column
##   @var[in,out] ox
function ble/widget/menu/.check-last-column {
  if [[ $_ble_complete_menu_lastcolumn ]]; then
    local lastwidget=${LASTWIDGET%%' '*}
    if [[ $lastwidget == ble/widget/menu/forward-line ||
            $lastwidget == ble/widget/menu/backward-line ]]
    then
      ox=$_ble_complete_menu_lastcolumn
      return 0
    fi
  fi
  _ble_complete_menu_lastcolumn=$ox
}
## @fn ble/widget/menu/.goto-column column
## Moves to the element corresponding to the specified column in the current row.
##   @param[in] column
function ble/widget/menu/.goto-column {
  local column=$1
  local offset=$_ble_complete_menu_page_offset
  local osel=$_ble_complete_menu_selected
  ((osel>=0)) || return 1
  local entry=${_ble_complete_menu_page_icons[osel-offset]}
  local fields; ble/string#split fields , "${entry%%:*}"
  local ox=${fields[0]} oy=${fields[1]}
  local nsel=-1
  if ((ox<column)); then
    # forward search within the line
    nsel=$osel
    for entry in "${_ble_complete_menu_page_icons[@]:osel+1-offset}"; do
      ble/string#split fields , "${entry%%:*}"
      local x=${fields[0]} y=${fields[1]}
      ((y==oy&&x<=column)) || break
      ((nsel++))
    done
  elif ((ox>column)); then
    # backward search within the line
    local i=$osel
    while ((--i>=offset)); do
      entry=${_ble_complete_menu_page_icons[i-offset]}
      ble/string#split fields , "${entry%%:*}"
      local x=${fields[0]} y=${fields[1]}
      ((y<oy||x<=column&&(nsel=i,1))) && break
    done
  fi
  ((nsel>=0&&nsel!=osel)) &&
    ble/complete/menu#select "$nsel"
}
function ble/widget/menu/forward-line {
  local offset=$_ble_complete_menu_page_offset
  local osel=$_ble_complete_menu_selected
  ((osel>=0)) || return 1

  local nsel=-1 goto_column=
  if local ret; ble/function#try ble/complete/menu-style:"$_ble_complete_menu_page_style"/locate down "$osel"; then
    nsel=$ret
  else
    local entry=${_ble_complete_menu_page_icons[osel-offset]}
    local fields; ble/string#split fields , "${entry%%:*}"
    local ox=${fields[0]} oy=${fields[1]}
    ble/widget/menu/.check-last-column
    local i=$osel nsel=-1 is_next_page=
    for entry in "${_ble_complete_menu_page_icons[@]:osel+1-offset}"; do
      ble/string#split fields , "${entry%%:*}"
      local x=${fields[0]} y=${fields[1]}
      ((y<=oy||y==oy+1&&x<=ox||nsel<0)) || break
      ((++i,y>oy&&(nsel=i)))
    done
    ((nsel<0&&(is_next_page=1,nsel=offset+${#_ble_complete_menu_page_icons[@]})))
    ((is_next_page)) && goto_column=$ox
  fi

  local ncand=${#_ble_complete_menu_items[@]}
  if ((0<=nsel&&nsel<ncand)); then
    ble/complete/menu#select "$nsel"
    [[ $goto_column ]] && ble/widget/menu/.goto-column "$goto_column"
    return 0
  else
    ble/widget/.bell 'menu: no more candidates'
    return 1
  fi
}
function ble/widget/menu/backward-line {
  local offset=$_ble_complete_menu_page_offset
  local osel=$_ble_complete_menu_selected
  ((osel>=0)) || return 1

  local nsel=-1 goto_column=
  if local ret; ble/function#try ble/complete/menu-style:"$_ble_complete_menu_page_style"/locate up "$osel"; then
    nsel=$ret
  else
    local entry=${_ble_complete_menu_page_icons[osel-offset]}
    local fields; ble/string#split fields , "${entry%%:*}"
    local ox=${fields[0]} oy=${fields[1]}
    ble/widget/menu/.check-last-column
    local nsel=$osel
    while ((--nsel>=offset)); do
      entry=${_ble_complete_menu_page_icons[nsel-offset]}
      ble/string#split fields , "${entry%%:*}"
      local x=${fields[0]} y=${fields[1]}
      ((y<oy-1||y==oy-1&&x<=ox)) && break
    done
    ((0<=nsel&&nsel<offset)) && goto_column=$ox
  fi

  local ncand=${#_ble_complete_menu_items[@]}
  if ((0<=nsel&&nsel<ncand)); then
    ble/complete/menu#select "$nsel"
    [[ $goto_column ]] && ble/widget/menu/.goto-column "$goto_column"
  else
    ble/widget/.bell 'menu: no more candidates'
    return 1
  fi
}
function ble/widget/menu/backward-page {
  if ((_ble_complete_menu_page_offset>0)); then
    ble/complete/menu#select "$((_ble_complete_menu_page_offset-1))" goto-page-top
  else
    ble/widget/.bell "menu: this is the first page."
    return 1
  fi
}
function ble/widget/menu/forward-page {
  local next=$((_ble_complete_menu_page_offset+${#_ble_complete_menu_page_icons[@]}))
  if ((next<${#_ble_complete_menu_items[@]})); then
    ble/complete/menu#select "$next"
  else
    ble/widget/.bell "menu: this is the last page."
    return 1
  fi
}
function ble/widget/menu/beginning-of-page {
  ble/complete/menu#select "$_ble_complete_menu_page_offset"
}
function ble/widget/menu/end-of-page {
  local nicon=${#_ble_complete_menu_page_icons[@]}
  ((nicon)) && ble/complete/menu#select "$((_ble_complete_menu_page_offset+nicon-1))"
}

function ble/widget/menu/cancel {
  ble/decode/keymap/pop
  ble/complete/menu#clear
  "$_ble_complete_menu_class"/oncancel
}
function ble/widget/menu/accept {
  ble/decode/keymap/pop
  ble/complete/menu#clear
  local nsel=$_ble_complete_menu_selected
  local hook=$_ble_complete_menu_accept_hook
  _ble_complete_menu_accept_hook=
  if ((nsel>=0)); then
    "$_ble_complete_menu_class"/onaccept "$nsel" "${_ble_complete_menu_items[nsel]}"
  else
    "$_ble_complete_menu_class"/onaccept "$nsel"
  fi
}

function ble-decode/keymap:menu/define {
  # ble-bind -f __defchar__ menu_complete/self-insert
  # ble-bind -f __default__ 'menu_complete/exit-default'
  ble-bind -f __default__ 'bell'
  ble-bind -f __line_limit__ nop
  ble-bind -f C-m         'menu/accept'
  ble-bind -f RET         'menu/accept'
  ble-bind -f C-g         'menu/cancel'
  ble-bind -f 'C-x C-g'   'menu/cancel'
  ble-bind -f 'C-M-g'     'menu/cancel'
  ble-bind -f C-f         'menu/forward-column'
  ble-bind -f right       'menu/forward-column'
  ble-bind -f C-i         'menu/forward cyclic'
  ble-bind -f TAB         'menu/forward cyclic'
  ble-bind -f C-b         'menu/backward-column'
  ble-bind -f left        'menu/backward-column'
  ble-bind -f C-S-i       'menu/backward cyclic'
  ble-bind -f S-TAB       'menu/backward cyclic'
  ble-bind -f C-n         'menu/forward-line'
  ble-bind -f down        'menu/forward-line'
  ble-bind -f C-p         'menu/backward-line'
  ble-bind -f up          'menu/backward-line'
  ble-bind -f prior       'menu/backward-page'
  ble-bind -f next        'menu/forward-page'
  ble-bind -f home        'menu/beginning-of-page'
  ble-bind -f end         'menu/end-of-page'
}

# sample implementation
function ble/complete/menu.class/onaccept {
  local hook=$_ble_complete_menu_accept_hook
  _ble_complete_menu_accept_hook=
  "$hook" "$@"
}
function ble/complete/menu.class/oncancel {
  local hook=$_ble_complete_menu_cancel_hook
  _ble_complete_menu_cancel_hook=
  "$hook" "$@"
}
function ble/complete/menu#start {
  _ble_complete_menu_accept_hook=$1; shift
  _ble_complete_menu_cancel_hook=

  local menu_style=linewise
  local menu_items; menu_items=("$@")
  local menu_class=ble/complete/menu.class menu_param=
  ble/complete/menu#construct sync || return "$?"
  ble/complete/menu#show
  ble/complete/menu#select 0
  ble/decode/keymap/push menu
  return 147
}

# 
#==============================================================================
# Candidate source (context, source, action)

## Local variables commonly used within ble/complete
##
## @var COMP1 COMP2 COMPS COMPV
## COMP1-COMP2 specifies the range for completion.
## COMPS represents the string in COMP1-COMP2,
## COMPV represents the evaluated value of COMPS (quotes removed and simple parameter expansion performed).
## If COMPS contains a complex structure and immediate evaluation is not possible,
## COMPV will be unset. If necessary, use [[ $comps_flags == *v* ]] to determine.
## * [[ -v COMPV ]] is for bash-4.2 or later.
##
## @var comp_type
## Controls how candidates are generated.
## A string consisting of a colon-separated combination of the following options:
##
## a Generate candidates for use in ambiguous completion.
## Whether there is a fuzzy match or not is determined by the caller, so
## It is sufficient to generate as many candidates as possible that have a possibility of vague matching.
## m ambiguous completion (matches middle part)
## A Ambiguous completion (substring/first character does not need to match either)
##
##   i (rlvar completion-ignore-case)
## Generates completion candidates that are case-insensitive.
##   vstat (rlvar visible-stats)
## Add a symbol indicating the file type to the end of the file name.
##   markdir (rlvar mark-directories)
## Add / after directory name completion.
##
##   sync
## Indicates that there is no interruption even if there is user input.
##   raw
## Use the string before shell evaluation as COMPV.
##

function ble/complete/check-cancel {
  [[ :$comp_type: != *:sync:* ]] && ble/decode/has-input
}

#------------------------------------------------------------------------------
# action

## existing action
##
##   ble/complete/action:plain
##   ble/complete/action:{,literal-}{word,substr}
##   ble/complete/action:file{,_rhs}
##   ble/complete/action:cdpath
##   ble/complete/action:progcomp
##   ble/complete/action:mandb{,.flag}
##   ble/complete/action:command
##   ble/complete/action:variable
##   ble/complete/action:tilde
##   ble/complete/action:{suffix-,}sabbrev
##
## implementation of action
##
## @fn ble/complete/action:$ACTION/initialize
## Basically you just need to set INSERT
##   @var[in    ] CAND
##   @var[in,out] ACTION
##   @var[in,out] DATA
##   @var[in,out] INSERT
## Specify the string to replace COMP1-COMP2
##
##   @var[in] COMP1 COMP2 COMPS COMPV comp_type
##
##   @var[in] COMP_PREFIX
##
##   @var[in] comps_flags
## A string consisting of the following flag characters.
##
## p Indicates completion immediately after parameter expansion.
## This is necessary when adding the characters that make up the identifier immediately after.
##
## v Indicates that COMPV is available.
## f Indicates that COMPV evaluation failed with failglob.
##
## S indicates that you are inside a quote ''.
## E Represents being inside the quote $''.
## D Represents being inside a quote "".
## I Indicates that you are inside the quote $"".
## B Indicates that it is immediately after the quote \.
## x indicates that you are inside a brace expansion.
##
## Note: Because of shopt -s nocaseglob, the flag character is
## It is necessary to define the characters in uppercase and lowercase letters so that they do not overlap.
##
##   @var[in] comps_fixed
## If the completion target contains brace expansion, it takes the form ibrace:value.
## Otherwise, it is an empty string.
## ibrace is the length of the COMPS prefix required to preserve the brace expansion structure.
## value is the evaluation result of the last word resulting from brace expansion of ${COMPS::ibrace}.
##
## @fn ble/complete/action:$ACTION/initialize.batch
##   Convert all the elements stored in "cands" to the array "inserts" at once.
##
##   @var[in] ACTION
##   @var[in] DATA
##   @arr[in] cands
##   @arr[out] inserts
##
##   @var[in] COMP1 COMP2 COMPS COMPV comp_type
##   @var[in] COMP_PREFIX
##   @var[in] comps_flags
##   @var[in] comps_fixed
##     (see ble/complete/action:$ACTION/initialize)
##
## @fn ble/complete/action:$ACTION/complete
## When confirming uniqueness, process the inserted string/range.
## For example, add / to the end of a directory name.
##
##   @var[in] CAND
##   @var[in] ACTION
##   @var[in] DATA
##   @var[in] COMP1 COMP2 COMPS COMPV comp_type comps_flags
##
##   @var[in,out] insert suffix
## Specifies the string to be inserted by completion.
## Returns the string to be inserted after processing.
##
##   @var[in] insert_beg insert_end
## Specifies the range to be replaced by completion.
##
##   @var[in,out] insert_flags
## A string that is a combination of the following flag characters:
##
## r [in] Indicates a completion that rewrites an existing part.
## If this is not included, it will be supplemented by adding it while retaining the existing part.
## m [out] Indicates a request to display a list of candidates (menu).
## n [out] Requests to try completion again (without confirming) and display a list of candidates.
##
## @fn ble/complete/action:$ACTION/init-menu-item
##   @var[in] ACTION CAND INSERT DATA PREFIX_LEN
##     These variables contain the data of the current item.
##   @var[ref] g prefix suffix
##     When the corresponding information exists, the corresponding variable is
##     updated.
##
## @fn ble/complete/action:$ACTION/get-desc
##   @var[in] ACTION CAND INSERT DATA PREFIX_LEN
##     These variables contain the data of the current item.
##   @var[in] desc_sgr0 desc_sgrq desc_sgrt
##     These variables specify the graphic styles of descriptions
##   @var[out] desc
##     Store the generated description

function ble/complete/string#escape-for-completion-context {
  local str=$1 escape_flags=$2
  case $comps_flags in
  (*S*)    ble/string#escape-for-bash-single-quote "$str"  ;;
  (*E*)    ble/string#escape-for-bash-escape-string "$str" ;;
  (*[DI]*) ble/string#escape-for-bash-double-quote "$str"  ;;
  (*)
    if [[ $comps_fixed ]]; then
      ble/string#escape-for-bash-specialchars "$str" "b$escape_flags"
    else
      ble/string#escape-for-bash-specialchars "$str" "$escape_flags"
    fi ;;
  esac
}

function ble/complete/action/complete.addtail {
  suffix=$suffix$1
}
function ble/complete/action/complete.mark-directory {
  [[ :$comp_type: == *:markdir:* && $CAND != */ ]] &&
    [[ ! -h $CAND || ( $insert == "$COMPS" || :$comp_type: == *:marksymdir:* ) ]] &&
    ble/complete/action/complete.addtail /
}
function ble/complete/action/complete.close-quotation {
  case $comps_flags in
  (*[SE]*) ble/complete/action/complete.addtail \' ;;
  (*[DI]*) ble/complete/action/complete.addtail \" ;;
  esac
}

## @fn ble/complete/action/quote-insert.initialize action
##   @var[out] ${_ble_complete_quote_insert_varnames[@]}
##
## @fn ble/complete/action/quote-insert action
##   @var[ref] INSERT
##   @var[in] ${_ble_complete_quote_insert_varnames[@]}
##
## Note: Call quote-insert.initialize before calling quote-insert.
## The quote_... variable must be initialized.
##
## Example:
##
##   local "${_ble_complete_quote_insert_varnames[@]/%/=}" # WA #D1570 checked
##   ble/complete/action/quote-insert.initialize "$action"
##   for INSERT; do
##     ble/complete/action/quote-insert "$action"
##     : do something with INSERT
##   done
##

_ble_complete_quote_insert_varnames=(
  quote_action
  quote_escape_flags
  quote_cont_cutbackslash
  quote_paramx_comps
  quote_trav_prefix
  quote_fixed_comps
  quote_fixed_compv
  quote_fixed_comps_len
  quote_fixed_compv_len)

function ble/complete/action/quote-insert.initialize {
  quote_action=$1

  quote_escape_flags=c
  if [[ $quote_action == command ]]; then
    quote_escape_flags=
  elif [[ $quote_action == progcomp ]]; then
    # #D1362 Bash when "compopt -o filenames" is specified,
    # Quote the tilde only when there is a file with the same name as a completion candidate starting with '~'.
    # [[ $CAND == '~'* && ! ( $comp_opts == *:filenames:* && -e $CAND ) ]] &&
    #   quote_escape_flags=T$quote_escape_flags
    # #D1434 = and : will not be quoted unless filenames is included.
    # Since bash-complete can generate unquoted =, : .
    [[ $comp_opts != *:filenames:* ]] &&
      quote_escape_flags=${quote_escape_flags//c}
  fi
  [[ $comps_fixed ]] && quote_escape_flags=b$quote_escape_flags

  # If an isolated backslash is prefixed, it is removed to prevent double quotes.
  quote_cont_cutbackslash=
  [[ $comps_flags == *B* && $COMPS == *'\' ]] &&
    quote_cont_cutbackslash=1

  # Escape if there is a parameter expansion immediately before
  quote_paramx_comps=$COMPS
  if [[ $comps_flags == *p* ]]; then
    # Note: Safety measure (Originally, when there is p in comps_flags, it should not end with '\')
    [[ $comps_flags == *B* && $quote_paramx_comps == *'\' ]] &&
      quote_paramx_comps=${quote_paramx_comps%'\'}

    case $comps_flags in
    (*[DI]*)
      if [[ $COMPS =~ $rex_raw_paramx ]]; then
        local rematch1=${BASH_REMATCH[1]}
        quote_paramx_comps=$rematch1'${'${COMPS:${#rematch1}+1}'}'
      else
        # Note: Safety measure (should match above)
        quote_paramx_comps=$quote_paramx_comps'""'
      fi ;;
    (*)
      quote_paramx_comps=$quote_paramx_comps'\' ;;
    esac
  fi

  # Restore context when rewriting retroactively
  quote_trav_prefix=
  case $comps_flags in
  (*S*) quote_trav_prefix=\' ;;
  (*E*) quote_trav_prefix=\$\' ;;
  (*D*) quote_trav_prefix=\" ;;
  (*I*) quote_trav_prefix=\$\" ;;
  esac

  # Be careful about comps_fixed when rewriting retroactively.
  quote_fixed_comps=('')
  quote_fixed_compv=('')
  quote_fixed_comps_len=('')
  quote_fixed_compv_len=('')
  if [[ $comps_fixed ]]; then
    quote_fixed_compv=${comps_fixed#*:}
    quote_fixed_compv_len=${#quote_fixed_compv}
    quote_fixed_comps_len=${comps_fixed%%:*}
    quote_fixed_comps=${COMPS::quote_fixed_comps_len}
  fi

  # When rewriting backwards, use '/' delimiters to preserve the original expansion as much as possible.
  # After comps_fixed[1], store the expanded results separated by '/' in ascending order.
  local i v
  for ((i=1;i<${#comps_fixed[@]};i++)); do
    v=${comps_fixed[i]#*:}
    quote_fixed_compv[i]=$v
    quote_fixed_compv_len[i]=${#v}
    quote_fixed_comps_len[i]=${comps_fixed[i]%%:*}
    quote_fixed_comps[i]=${COMPS::quote_fixed_comps_len[i]}
  done
}

## @fn ble/complete/action/quote-insert
# Note: The processing of this function is consistent with ble/complete/action/quote-insert.batch/awk.
# I need to be there. When changing this function, also make equivalent changes to quote-insert.batch/awk.
# changes need to be applied.
function ble/complete/action/quote-insert {
  if [[ ! $quote_action ]]; then
    local "${_ble_complete_quote_insert_varnames[@]/%/=}" # WA #D1570 checked
    ble/complete/action/quote-insert.initialize "${1:-plain}"
  fi

  local escape_flags=$quote_escape_flags
  if [[ $quote_action == command ]]; then
    # Note (#D1715,#D1978): Regarding the judgment of "*:noquote:*". action=command
    # DATA=:noquote: is only used in alias generation. And the alias generation is
    # This is done by calling yield directly without using yield.batch. So :noquote:
    # There is no need to make this determination on the awk batch side.
    [[ $DATA == *:noquote:* || $COMPS == "$COMPV" && ( $CAND == '[[' || $CAND == '!' ) ]] && return 0
  elif [[ $quote_action == progcomp ]]; then
    [[ $comp_opts == *:noquote:* ]] && return 0
    [[ $comp_opts == *:ble/syntax-raw:* && $comp_opts != *:filenames:* ]] && return 0

    # For bash-completion, as compopt -o nospace,
    # There is a completion function to add spaces yourself. There is a problem if you quote at this time.
    [[ $comp_opts == *:nospace:* && $CAND == *' ' && ! -f $CAND ]] && return 0

    # #D1362 Bash requires "compopt -o filenames" and
    # Quote the tilde only when there is a file with the same name as a completion candidate starting with '~'.
    [[ $CAND == '~'* && ! ( $comp_opts == *:filenames:* && -e $CAND ) ]] &&
      escape_flags=T$escape_flags
  fi

  # When adding to an already input string, the original word is retained.
  if [[ $comps_flags == *v* && $CAND == "$COMPV"* ]]; then
    local ins ret
    ble/complete/string#escape-for-completion-context "${CAND:${#COMPV}}" "$escape_flags"; ins=$ret
    if [[ $comps_flags == *p* && $ins == [_a-zA-Z0-9]* ]]; then
      INSERT=$quote_paramx_comps$ins
    else
      [[ $quote_cont_cutbackslash ]] && ins=${ins#'\'}
      INSERT=$COMPS$ins;
    fi
    return 0
  fi

  # When rewriting retroactively, the longest possible partial path within a word is retained.
  local i=${#quote_fixed_comps[@]}
  while ((--i>=0)); do
    if [[ ${quote_fixed_comps[i]} && $CAND == "${quote_fixed_compv[i]}"* ]]; then
      local ret; ble/complete/string#escape-for-completion-context "${CAND:quote_fixed_compv_len[i]}" "$escape_flags"
      INSERT=${quote_fixed_comps[i]}$quote_trav_prefix$ret
      return 0
    fi
  done

  # If it doesn't match the existing one, completely rewrite it.
  local ret; ble/complete/string#escape-for-completion-context "$CAND" "$escape_flags"
  INSERT=$quote_trav_prefix$ret
}

function ble/complete/action/quote-insert.batch/awk {
  local q=\'
  local -x comp_opts=$comp_opts
  local -x comps=$COMPS
  local -x compv=$COMPV
  local -x comps_flags=$comps_flags
  local -x quote_action=$quote_action
  local -x quote_escape_flags=$quote_escape_flags
  local -x quote_paramx_comps=$quote_paramx_comps
  local -x quote_cont_cutbackslash=$quote_cont_cutbackslash
  local -x quote_trav_prefix=$quote_trav_prefix

  local -x quote_fixed_count=${#quote_fixed_comps[@]}
  local i
  for ((i=0;i<quote_fixed_count;i++)); do
    local -x "quote_fixed_comps$i=${quote_fixed_comps[i]}"
    local -x "quote_fixed_compv$i=${quote_fixed_compv[i]}"
  done

  "$quote_batch_awk" -v quote_batch_nulsep="$quote_batch_nulsep" -v q="$q" '
    function exists(filename) { return substr($0, 1, 1) == "1"; }
    function is_file(filename) { return substr($0, 2, 1) == "1"; }

    function initialize(_, flags, comp_opts, tmp, i) {
      IS_XPG4 = AWKTYPE == "xpg4";
      REP_SL = "\\";
      if (IS_XPG4) REP_SL = "\\\\";

      REP_DBL_SL = "\\\\"; # gawk, nawk
      sub(/.*/, REP_DBL_SL, tmp);
      if (tmp == "\\") REP_DBL_SL = "\\\\\\\\"; # mawk, xpg4

      Q = q "\\" q q;

      DELIM = 10;
      if (quote_batch_nulsep != "") {
        RS = "\0";
        DELIM = 0;
      }

      quote_action = ENVIRON["quote_action"];

      comps = ENVIRON["comps"];
      compv = ENVIRON["compv"];
      compv_len = length(compv);

      comps_flags = ENVIRON["comps_flags"];
      escape_type = 0;
      if (comps_flags ~ /S/)
        escape_type = 1;
      else if (comps_flags ~ /E/)
        escape_type = 2;
      else if (comps_flags ~ /[DI]/)
        escape_type = 3;
      else
        escape_type = 4;
      comps_v = (comps_flags ~ /v/);
      comps_p = (comps_flags ~ /p/);

      comp_opts = ENVIRON["comp_opts"];
      is_noquote = comp_opts ~ /:noquote:/;
      is_nospace = comp_opts ~ /:nospace:/;
      is_syntaxraw = comp_opts ~ /:ble\/syntax-raw:/ && comp_opts !~ /:filenames:/;

      flags = ENVIRON["quote_escape_flags"];
      escape_c = (flags ~ /c/);
      escape_b = (flags ~ /b/);
      escape_tilde_always = 1;
      escape_tilde_exists = 0;
      if (quote_action == "progcomp") {
        escape_tilde_always = 0;
        escape_tilde_exists = (comp_opts ~ /:filenames:/);
      }

      quote_cont_cutbackslash   = ENVIRON["quote_cont_cutbackslash"] != "";
      quote_paramx_comps        = ENVIRON["quote_paramx_comps"];
      quote_trav_prefix     = ENVIRON["quote_trav_prefix"];

      quote_fixed_count = ENVIRON["quote_fixed_count"];
      for (i = 0; i < quote_fixed_count; i++) {
        quote_fixed_comps[i]     = ENVIRON["quote_fixed_comps" i];
        quote_fixed_compv[i]     = ENVIRON["quote_fixed_compv" i];
        quote_fixed_comps_len[i] = length(quote_fixed_comps[i]);
        quote_fixed_compv_len[i] = length(quote_fixed_compv[i]);
      }
    }
    BEGIN { initialize(); }

    function escape_for_completion_context(text) {
      if (escape_type == 1) {
        # single quote
        gsub(/'$q'/, Q, text);
      } else if (escape_type == 2) {
        # escape string
        if (text ~ /[\\'$q'\a\b\t\n\v\f\r\033]/) {
          gsub(/\\/  , REP_DBL_SL, text);
          gsub(/'$q'/, REP_SL q  , text);
          gsub(/\007/, REP_SL "a", text);
          gsub(/\010/, REP_SL "b", text);
          gsub(/\011/, REP_SL "t", text);
          gsub(/\012/, REP_SL "n", text);
          gsub(/\013/, REP_SL "v", text);
          gsub(/\014/, REP_SL "f", text);
          gsub(/\015/, REP_SL "r", text);
          gsub(/\033/, REP_SL "e", text);
        }
      } else if (escape_type == 3) {
        # double quote
        gsub(/[\\"$`]/, "\\\\&", text); # Note: All awks behaves the same for "\\\\&"
      } else if (escape_type == 4) {
        # bash specialchars
        gsub(/[]\\ "'$q'`$|&;<>()!^*?[]/, "\\\\&", text);
        if (escape_c) gsub(/[=:]/, "\\\\&", text);
        if (escape_b) gsub(/[{,}]/, "\\\\&", text);
        if (ret ~ /^~/ && (escape_tilde_always || escape_tilde_exists && exists(cand)))
          text = "\\" text;
        gsub(/\n/, "$" q REP_SL "n" q, text);
        gsub(/\t/, "$" q REP_SL "t" q, text);
      }
      return text;
    }

    function quote_insert(cand, _, i) {
      # progcomp specific
      if (quote_action == "command") {
        if (comps == compv && cand ~ /^(\[\[|]]|!)$/) return cand;
      } else if (quote_action == "progcomp") {
        if (is_noquote || is_syntaxraw) return cand;
        if (is_nospace && cand ~ / $/ && !is_file(cand)) return cand;
      }

      if (comps_v && substr(cand, 1, compv_len) == compv) {
        ins = escape_for_completion_context(substr(cand, compv_len + 1));
        if (comps_p && ins ~ /^[_a-zA-Z0-9]/) {
          return quote_paramx_comps ins;
        } else {
          if (quote_cont_cutbackslash) sub(/^\\/, "", ins);
          return comps ins;
        }
      }

      for (i = quote_fixed_count; --i >= 0; ) {
        if (quote_fixed_comps_len[i] && substr(cand, 1, quote_fixed_compv_len[i]) == quote_fixed_compv[i]) {
          ins = substr(cand, quote_fixed_compv_len[i] + 1);
          return quote_fixed_comps[i] quote_trav_prefix escape_for_completion_context(ins);
        }
      }

      return quote_trav_prefix escape_for_completion_context(cand);
    }

    {
      cand = substr($0, 3);
      insert = quote_insert(cand);
      printf("%s%c", insert, DELIM);
    }
  '
}
function ble/complete/action/quote-insert.batch/proc {
  local _ble_local_tmpfile; ble/util/assign/mktmp

  local delim='\n'
  [[ $quote_batch_nulsep ]] && delim='\0'
  if [[ $quote_action == progcomp ]]; then
    local cand file exist
    for cand in "${cands[@]}"; do
      ((cand_iloop++%bleopt_complete_polling_cycle==0)) && ble/complete/check-cancel && return 148
      f=0 e=0
      [[ -e $cand ]] && e=1
      [[ -f $cand ]] && f=1
      printf "$e$f%s$delim" "$cand"
    done
  else
    printf "00%s$delim" "${cands[@]}"
  fi >| "$_ble_local_tmpfile"

  local fname_cands=$_ble_local_tmpfile
  ble/util/conditional-sync \
    'ble/complete/action/quote-insert.batch/awk < "$fname_cands"' \
    '! ble/complete/check-cancel' '' progressive-weight
  local ext=$?

  ble/util/assign/rmtmp
  return "$ext"
}
## @fn ble/complete/action/quote-insert.batch
##   @arr[in] cands
##   @arr[out] inserts
function ble/complete/action/quote-insert.batch {
  local opts=$1

  local quote_batch_nulsep=
  local quote_batch_awk=ble/bin/awk
  if [[ :$opts: != *:newline:* ]]; then
    if ((_ble_bash>=40400)); then
      if [[ $_ble_bin_awk_type == [mg]awk ]]; then
        quote_batch_nulsep=1
      elif ble/bin#has mawk; then
        quote_batch_nulsep=1
        quote_batch_awk=mawk
      elif ble/bin#has gawk; then
        quote_batch_nulsep=1
        quote_batch_awk=gawk
      fi
    fi
    [[ ! $quote_batch_nulsep ]] &&
      [[ "${cands[*]}" == *$'\n'* ]] &&
      return 1
  fi

  if [[ $quote_batch_nulsep ]]; then
    ble/util/assign-array0 inserts ble/complete/action/quote-insert.batch/proc
  else
    ble/util/assign-array inserts ble/complete/action/quote-insert.batch/proc
  fi
  return "$?"
}

## @fn ble/complete/action/requote-final-insert
##   @var[ref] insert insert_flags
function ble/complete/action/requote-final-insert {
  local threshold=$((bleopt_complete_requote_threshold))
  ((threshold>=0)) || return 0

  local comps_prefix= check_optarg=
  if [[ $insert == "$COMPS"* ]]; then
    [[ $comps_flags == *[SEDI]* ]] && return 0

    # Note: The following settings will be allowed to be rewritten retroactively.
    [[ $COMPS != *[!':/={,'] ]] && comps_prefix=$COMPS
    check_optarg=$COMPS
  else
    # When rewriting retroactively (assuming it is not in a halfway quote state)
    check_optarg=$insert
  fi

  # Note: --prefix='/usr/local', PREFIX='/usr/local', -L'/usr/local/share/lib'
  # etc., the quote on the right side of option/variable assignment, etc., starts from the point where it seems to be the starting point.
  # start.
  if [[ $check_optarg ]]; then
    if ble/string#match "$check_optarg" '^([_a-zA-Z][_a-zA-Z0-9]*|-[-a-zA-Z0-9.]+)=(([^\'\''"`${}]*|\\.)*:)?'; then
      # If there is --prefix=, PREFIX=, PATH=xxxx:, etc., quote immediately after = or :.
      comps_prefix=$BASH_REMATCH
    elif [[ $COMP_PREFIX == -[!'-=:/\'\''"$`{};&|<>!^{}'] && $check_optarg == "$COMP_PREFIX"* ]]; then
      # -L'/path/to/library' etc. Only when COMP_PREFIX=-L and COMPS starts with -L.
      comps_prefix=${check_optarg::2}
    fi
  fi

  if [[ $comps_fixed ]]; then
    local comps_fixed_part=${COMPS::${comps_fixed%%:*}}
    [[ $comps_prefix == "$comps_fixed_part"* ]] ||
      comps_prefix=$comps_fixed_part
  fi

  if [[ $insert == "$comps_prefix"* && $comps_prefix != *[!':/={,'] ]]; then
    local ret ins=${insert:${#comps_prefix}}
    if ! ble/syntax:bash/simple-word/is-literal "$ins" &&
        ble/syntax:bash/simple-word/safe-eval "$ins" limit=2 &&
        ((${#ret[@]}==1))
    then
      if [[ $comps_flags == *[SEDI]* ]]; then
        ble/complete/string#escape-for-completion-context "$ret"
        case $comps_flags in
        (*S*) ret=\'$ret ;;
        (*E*) ret=\$\'$ret ;;
        (*D*) ret=\"$ret ;;
        (*I*) ret=\$\"$ret ;;
        esac
      else
        ble/string#quote-word "$ret" quote-empty
      fi
      ((${#ret}+threshold<=${#ins})) || return 0
      insert=$comps_prefix$ret
      [[ $insert == "$COMPS"* ]] || insert_flags=r$insert_flags #Rewritten retroactively
    fi
  fi
  return 0
}

function ble/complete/action#inherit-from {
  local dst=$1 src=$2
  local member srcfunc dstfunc
  for member in initialize{,.batch} complete getg get-desc init-menu-item; do
    srcfunc=ble/complete/action:$src/$member
    dstfunc=ble/complete/action:$dst/$member
    ble/is-function "$srcfunc" && builtin eval "function $dstfunc { $srcfunc \"\$@\"; }"
  done
}

# action:plain
function ble/complete/action:plain/initialize {
  ble/complete/action/quote-insert
}
function ble/complete/action:plain/initialize.batch {
  ble/complete/action/quote-insert.batch
}
function ble/complete/action:plain/complete {
  ble/complete/action/requote-final-insert
}
function ble/complete/action:plain/get-desc {
  [[ $DATA ]] && desc=$DATA
}

# action:literal-substr
function ble/complete/action:literal-substr/initialize { return 0; }
function ble/complete/action:literal-substr/initialize.batch { inserts=("${cands[@]}"); }
function ble/complete/action:literal-substr/complete { return 0; }
function ble/complete/action:literal-substr/get-desc { ble/complete/action:plain/get-desc; }

# action:substr (equivalent to plain)
function ble/complete/action:substr/initialize {
  ble/complete/action/quote-insert
}
function ble/complete/action:substr/initialize.batch {
  ble/complete/action/quote-insert.batch
}
function ble/complete/action:substr/complete {
  ble/complete/action/requote-final-insert
}
function ble/complete/action:substr/get-desc { ble/complete/action:plain/get-desc; }

# action:literal-word
function ble/complete/action:literal-word/initialize { return 0; }
function ble/complete/action:literal-word/initialize.batch { inserts=("${cands[@]}"); }
function ble/complete/action:literal-word/complete {
  if [[ $comps_flags == *x* ]]; then
    ble/complete/action/complete.addtail ','
  else
    ble/complete/action/complete.addtail ' '
  fi
}
function ble/complete/action:literal-word/get-desc { ble/complete/action:plain/get-desc; }

# action:word
#
# DATA ... specifies a string to use as a description of the candidate
#
function ble/complete/action:word/initialize {
  ble/complete/action/quote-insert
}
function ble/complete/action:word/initialize.batch {
  ble/complete/action/quote-insert.batch
}
function ble/complete/action:word/complete {
  ble/complete/action/requote-final-insert
  ble/complete/action/complete.close-quotation
  ble/complete/action:literal-word/complete
}
function ble/complete/action:word/get-desc {
  ble/complete/action:plain/get-desc
}

# action:file
# action:file_rhs (source:argument internal use)

## @fn ble/complete/action:file/.get-filename word
## Extract the file name considering the case of "compopt -o ble/syntax-raw".
## Looking at Bash's behavior, it seems that it only performs tilde expansion.
##   @var[in] CAND DATA
function ble/complete/action:file/.get-filename {
  ret=$CAND
  if [[ $ACTION == progcomp && :$DATA: == *:ble/syntax-raw:* && $ret == '~'* ]]; then
    local tilde=${ret%%/*} chars='\ "'\''`$|&;<>()!^*?[=:{,}'
    [[ $tilde == *["$chars"]* ]] && return 0
    builtin eval "local expand=$tilde"
    [[ $expand == "$tilde" ]] && return 0
    ret=$expand${ret:${#tilde}}
  fi
}
function ble/complete/action:file/initialize {
  ble/complete/action/quote-insert
}
function ble/complete/action:file/initialize.batch {
  ble/complete/action/quote-insert.batch
}
function ble/complete/action:file/complete {
  local ret
  ble/complete/action:file/.get-filename
  if [[ -e $ret || -h $ret ]]; then
    if [[ -d $ret ]]; then
      ble/complete/action/requote-final-insert
      ble/complete/action/complete.mark-directory
    else
      ble/complete/action:word/complete
    fi
  else
    # Note (#D2096): When "compopt -o filenames" is specified by progcomp, the
    # candidates are processed by action:file/complete.  However, words that
    # are not local filenames can also be generated.  Such a word would also
    # want to be suffixed by a space.
    ble/complete/action:word/complete
  fi
}
function ble/complete/action:file/init-menu-item {
  local ret
  ble/complete/action:file/.get-filename; local file=$ret
  ble/syntax/highlight/getg-from-filename "$file"
  [[ $g ]] || { local ret; ble/color/face2g filename_warning; g=$ret; }

  if [[ :$comp_type: == *:vstat:* ]]; then
    if [[ -h $file ]]; then
      suffix='@'
    elif [[ -d $file ]]; then
      suffix='/'
    elif [[ -x $file ]]; then
      suffix='*'
    fi
  fi
}
function ble/complete/action:file_rhs/initialize {
  ble/complete/action:file/initialize
}
function ble/complete/action:file_rhs/initialize.batch {
  ble/complete/action:file/initialize.batch
}
function ble/complete/action:file_rhs/complete {
  CAND=${CAND:${#DATA}} ble/complete/action:file/complete
}
function ble/complete/action:file_rhs/init-menu-item {
  CAND=${CAND:${#DATA}} ble/complete/action:file/init-menu-item
}

_ble_complete_action_file_desc[_ble_attr_FILE_LINK]='symbolic link'
_ble_complete_action_file_desc[_ble_attr_FILE_ORPHAN]='symbolic link (orphan)'
_ble_complete_action_file_desc[_ble_attr_FILE_DIR]='directory'
_ble_complete_action_file_desc[_ble_attr_FILE_STICKY]='directory (sticky)'
_ble_complete_action_file_desc[_ble_attr_FILE_SETUID]='file (setuid)'
_ble_complete_action_file_desc[_ble_attr_FILE_SETGID]='file (setgid)'
_ble_complete_action_file_desc[_ble_attr_FILE_EXEC]='file (executable)'
_ble_complete_action_file_desc[_ble_attr_FILE_FILE]='file'
_ble_complete_action_file_desc[_ble_attr_FILE_CHR]='character device'
_ble_complete_action_file_desc[_ble_attr_FILE_FIFO]='named pipe'
_ble_complete_action_file_desc[_ble_attr_FILE_SOCK]='socket'
_ble_complete_action_file_desc[_ble_attr_FILE_BLK]='block device'
_ble_complete_action_file_desc[_ble_attr_FILE_URL]='URL'
function ble/complete/action:file/get-desc {
  local type; ble/syntax/highlight/filetype "$CAND"
  desc=${_ble_complete_action_file_desc[type]:-'file (???)'}
}

# action:progcomp
#
# DATA ... compopt Compatible options separated by colons
#
## @fn ble/complete/action:progcomp/initialize/.reconstruct-from-noquote
##   @var[in,out] INSERT CAND
##   @var[in] progcomp_resolve_brace
function ble/complete/action:progcomp/initialize/.reconstruct-from-noquote {
  local simple_flags simple_ibrace ret count
  ble/syntax:bash/simple-word/is-simple-or-open-simple "$INSERT" &&
    ble/syntax:bash/simple-word/reconstruct-incomplete-word "$INSERT" &&
    ble/complete/source/eval-simple-word "$ret" single:count &&
    ((count==1)) || return 0

  CAND=$ret

  # Conversely, when there is brace expansion, the INSERT is corrected and returned.
  if [[ $quote_fixed_comps && $CAND == "$quote_fixed_compv"* ]]; then
    local ret; ble/complete/string#escape-for-completion-context "${CAND:quote_fixed_compv_len}" "$escape_flags"
    INSERT=$quote_fixed_comps$quote_trav_prefix$ret
    return 3
  fi
  return 0
}

function ble/complete/action:progcomp/initialize {
  if [[ :$DATA: == *:noquote:* ]]; then
    local progcomp_resolve_brace=$quote_fixed_comps
    [[ :$DATA: == *:ble/syntax-raw:* ]] && progcomp_resolve_brace=
    ble/complete/action:progcomp/initialize/.reconstruct-from-noquote
    return 0
  else
    ble/complete/action/quote-insert progcomp
  fi
}
## @fn ble/complete/action:progcomp/initialize.batch
##   @arr[in] cands
##   @arr[out] inserts
function ble/complete/action:progcomp/initialize.batch {
  if [[ :$DATA: == *:noquote:* ]]; then
    inserts=("${cands[@]}")

    # Note: When directly completing comp_words, brace expansion was intentionally suppressed.
    # Therefore, we do not restore the brace expansion.
    local progcomp_resolve_brace=$quote_fixed_comps
    [[ :$DATA: == *:ble/syntax-raw:* ]] && progcomp_resolve_brace=

    cands=()
    local INSERT simple_flags simple_ibrace ret count icand=0
    for INSERT in "${inserts[@]}"; do
      ((cand_iloop++%bleopt_complete_polling_cycle==0)) && ble/complete/check-cancel && return 148
      local CAND=$INSERT
      ble/complete/action:progcomp/initialize/.reconstruct-from-noquote ||
        inserts[icand]=$INSERT #When overwriting INSERT ($?==3)
      cands[icand++]=$CAND
    done
  else
    ble/complete/action/quote-insert.batch newline
  fi
}

function ble/complete/action:progcomp/complete {
  if [[ $DATA == *:filenames:* ]]; then
    ble/complete/action:file/complete
  else
    if [[ $DATA != *:ble/no-mark-directories:* && -d $CAND ]]; then
      ble/complete/action/requote-final-insert
      ble/complete/action/complete.mark-directory
    else
      ble/complete/action:word/complete
    fi
  fi

  [[ $DATA == *:nospace:* ]] && suffix=${suffix%' '}
  [[ $DATA == *:ble/no-mark-directories:* && -d $CAND ]] && suffix=${suffix%/}
}
function ble/complete/action:progcomp/init-menu-item {
  if [[ $DATA == *:filenames:* ]]; then
    ble/complete/action:file/init-menu-item
  fi
}
function ble/complete/action:progcomp/get-desc {
  if [[ $DATA == *:filenames:* ]]; then
    ble/complete/action:file/get-desc
  fi
}

# action:command

function ble/complete/action:command/initialize {
  ble/complete/action/quote-insert command
}
function ble/complete/action:command/initialize.batch {
  ble/complete/action/quote-insert.batch newline
}
function ble/complete/action:command/complete {
  if [[ -d $CAND ]]; then
    ble/complete/action/complete.mark-directory
  elif ! ble/bin#has "$CAND"; then
    # When the function name is contracted and unique.
    #
    # Note: When a function name is contracted,
    # Even if it is not originally uniquely determined, it may come here as uniquely determined.
    # When the command does not exist, it is determined that the command has been reduced.
    #
    if [[ $CAND == */ ]]; then
      # Assuming that it has been reduced, it generates a continuation completion candidate.
      insert_flags=${insert_flags}n
    fi
  else
    ble/complete/action:word/complete
  fi
}
function ble/complete/action:command/init-menu-item {
  if [[ -d $CAND ]]; then
    local ret; ble/color/face2g filename_directory; g=$ret
  else
    local type
    if [[ $CAND != "$INSERT" ]]; then
      ble/syntax/highlight/cmdtype "$CAND" "$INSERT"
    else
      # Note: ble/syntax/highlight/cmdtype has a cache function, but
      # It is assumed that it will not be called for a keyword, so if you pass the keyword
      # It returns _ble_attr_ERR.
      local type; ble/util/type type "$CAND"
      ble/syntax/highlight/cmdtype1 "$type" "$CAND"
    fi
    if [[ $CAND == */ ]] && ((type==_ble_attr_ERR)); then
      type=_ble_attr_CMD_FUNCTION
    fi
    ble/syntax/attr2g "$type"
  fi
}

_ble_complete_action_command_desc[_ble_attr_CMD_BOLD]=builtin
_ble_complete_action_command_desc[_ble_attr_CMD_BUILTIN]=builtin
_ble_complete_action_command_desc[_ble_attr_CMD_ALIAS]=alias
_ble_complete_action_command_desc[_ble_attr_CMD_FUNCTION]=function
_ble_complete_action_command_desc[_ble_attr_CMD_FILE]=file
_ble_complete_action_command_desc[_ble_attr_KEYWORD]=command
_ble_complete_action_command_desc[_ble_attr_CMD_JOBS]=job
_ble_complete_action_command_desc[_ble_attr_ERR]='command ???'
_ble_complete_action_command_desc[_ble_attr_CMD_DIR]=directory
function ble/complete/action:command/get-desc {
  local title= value=
  if [[ -d $CAND ]]; then
    title=directory
  else
    local type; ble/util/type type "$CAND"
    ble/syntax/highlight/cmdtype1 "$type" "$CAND"

    case $type in
    ($_ble_attr_CMD_ALIAS)
      local ret
      ble/alias#expand "$CAND"
      title=alias value=$ret ;;
    ($_ble_attr_CMD_FILE)
      local path; ble/bin#get-path "$CAND"
      [[ $path == ?*/"$CAND" ]] && path="from ${path%/"$CAND"}"
      title=file value=$path ;;
    ($_ble_attr_CMD_FUNCTION)

      local source lineno
      ble/function#get-source-and-lineno "$CAND"

      local def; ble/function#getdef "$CAND"
      ble/string#match "$def" '^[^()]*\(\)[[:blank:]]*\{[[:blank:]]+(.*[^[:blank:]])[[:blank:]]+\}[[:blank:]]*$' &&
        def=${BASH_REMATCH[1]} #Extract the contents of a function
      local ret sgr0=$'\e[27m' sgr1=$'\e[7m' #Note: Generated with sgr-ansi
      lines=1 cols=${COLUMNS:-80} x=0 y=0 ble/canvas/trace-text "$def" external-sgr

      title=function value="${source##*/}:$lineno $desc_sgrq$ret" ;;
    ($_ble_attr_CMD_JOBS)
      ble/util/joblist.check
      local job; ble/util/assign job 'jobs -- "$CAND" 2>/dev/null' || job='???'
      title=job value=${job:-(ambiguous)} ;;
    ($_ble_attr_ERR)
      if [[ $CAND == */ ]]; then
        title='function namespace'
      else
        title=${_ble_complete_action_command_desc[_ble_attr_ERR]}
      fi ;;
    (*)
      title=${_ble_complete_action_command_desc[type]:-'???'} ;;
    esac
  fi
  desc=${title:+$desc_sgrt($title)$desc_sgr0}${value:+ $value}
}

# action:variable
#
# DATA ... Specifies the context of the variable name.
# assignment braced word arithmetic.
#
function ble/complete/action:variable/initialize { ble/complete/action/quote-insert; }
function ble/complete/action:variable/initialize.batch { ble/complete/action/quote-insert.batch newline; }
function ble/complete/action:variable/complete {
  case $DATA in
  (assignment)
    # Insert = in var= etc.
    ble/complete/action/complete.addtail '=' ;;
  (braced)
    # Insert } in ${var etc.
    ble/complete/action/complete.addtail '}' ;;
  (word)       ble/complete/action:word/complete ;;
  (arithmetic|nosuffix) ;; # do nothing
  esac
}
function ble/complete/action:variable/init-menu-item {
  local ret; ble/color/face2g syntax_varname; g=$ret
}
function ble/complete/action:variable/get-desc {
  local _ble_local_title=variable
  if ble/is-array "$CAND"; then
    _ble_local_title=array
  elif ble/is-assoc "$CAND"; then
    _ble_local_title=assoc
  fi

  local _ble_local_value=
  if [[ $_ble_local_title == array || $_ble_local_title == assoc ]]; then
    builtin eval "local count=\${#$CAND[@]}"
    if ((count==0)); then
      count=empty
    else
      count="$count items"
    fi
    _ble_local_value=$'\e[94m['$count$']\e[m'
  else
    local ret; ble/string#quote-word "${!CAND}" ansi:sgrq="$desc_sgrq":quote-empty
    _ble_local_value=$ret
  fi
  desc="$desc_sgrt($_ble_local_title)$desc_sgr0 $_ble_local_value"
}

#------------------------------------------------------------------------------
# source

## @fn ble/complete/source/test-limit value
##   Tests whether "value" exceeds the completion limit
##   specified by bleopt complete_limit or complete_limit_auto.
##
##   @var[in] comp_type
##   @var[in,out] cand_limit_reached
##
function ble/complete/source/test-limit {
  local value=$1 limit=
  if [[ :$comp_type: == *:auto_menu:* && $bleopt_complete_limit_auto_menu ]]; then
    limit=$bleopt_complete_limit_auto_menu
  elif [[ :$comp_type: == *:auto:* && $bleopt_complete_limit_auto ]]; then
    limit=$bleopt_complete_limit_auto
  else
    limit=$bleopt_complete_limit
  fi

  if [[ $limit && value -gt limit ]]; then
    cand_limit_reached=1

    # Note: #D1618 When automatic candidate list display fails, an incomplete list is generated.
    # Cancel the entire completion to prevent this from happening.
    [[ :$comp_type: == *:auto_menu: ]] && cand_limit_reached=cancel
    return 1
  else
    return 0
  fi
}

## @fn ble/complete/source/eval-simple-word
## @fn ble/complete/source/evaluate-path-spec
## Specify the interruption setting and timeout setting (only when auto-complete) for completion,
## Call simple-word/{eval,evaluate-path-spec} for each.
##
## Note: The current implementation does not allow interrupts due to user input 148 and timeout
## Changed behavior so that these functions return 148 for both 142 and abort
## I am doing it. This is because it is convenient for the caller to handle both without distinction.
##
function ble/complete/source/eval-simple-word {
  local word=$1 opts=$2
  if [[ :$comp_type: != *:sync:* && :$opts: != *:noglob:* ]]; then
    opts=$opts:stopcheck:cached
    [[ :$comp_type: == *:auto:* && $bleopt_complete_timeout_auto ]] &&
      opts=$opts:timeout=$((bleopt_complete_timeout_auto))
  fi
  ble/syntax:bash/simple-word/eval "$word" "$opts"; local ext=$?
  ((ext==142)) && return 148
  return "$ext"
}
function ble/complete/source/evaluate-path-spec {
  local word=$1 sep=$2 opts=$3
  if [[ :$comp_type: != *:sync:* && :$opts: != *:noglob:* ]]; then
    opts=$opts:stopcheck:cached:single
    [[ :$comp_type: == *:auto:* && $bleopt_complete_timeout_auto ]] &&
      opts=$opts:timeout=$((bleopt_complete_timeout_auto))
  fi
  ble/syntax:bash/simple-word/evaluate-path-spec "$word" "$sep" "$opts"; local ext=$?
  ((ext==142)) && return 148
  return "$ext"
}


## @fn ble/complete/source/reduce-compv-for-ambiguous-match
## Generate and set pseudo COMPV and COMPS for ambiguous completion.
##   @var[in] comp_type comps_flags comps_fixed
##   @var[in,out] COMPS COMPV
function ble/complete/source/reduce-compv-for-ambiguous-match {
  [[ :$comp_type: == *:[maA]:* ]] || return 0

  local comps=$COMPS compv=$COMPV
  local comps_prefix= compv_prefix=
  if [[ $comps_fixed ]]; then
    comps_prefix=${comps::${comps_fixed%%:*}}
    compv_prefix=${comps_fixed#*:}
    compv=${COMPV:${#compv_prefix}}
  fi

  case $comps_flags in
  (*S*) comps_prefix=$comps_prefix\' ;;
  (*E*) comps_prefix=$comps_prefix\$\' ;;
  (*D*) comps_prefix=$comps_prefix\" ;;
  (*I*) comps_prefix=$comps_prefix\$\" ;;
  esac

  if [[ $compv && :$comp_type: == *:a:* ]]; then
    compv=${compv::1}
    ble/complete/string#escape-for-completion-context "$compv"
    comps=$ret
  else
    compv= comps=
  fi

  COMPV=$compv_prefix$compv
  COMPS=$comps_prefix$comps
}


_ble_complete_yield_varnames=("${_ble_complete_quote_insert_varnames[@]}")

## @fn ble/complete/cand/yield.initialize action
function ble/complete/cand/yield.initialize {
  ble/complete/action/quote-insert.initialize "$1"
}

## @fn ble/complete/cand/yield ACTION CAND DATA
##   @param[in] ACTION
##   @param[in] CAND
##   @param[in] DATA
##   @var[in] COMP_PREFIX
##   @var[in] flag_force_fignore
##   @var[in] flag_source_filter
function ble/complete/cand/yield {
  local ACTION=$1 CAND=$2 DATA=$3
  [[ $flag_force_fignore ]] && ! ble/complete/.fignore/filter "$CAND" && return 0
  [[ $flag_source_filter ]] || ble/complete/candidates/filter#test "$CAND" || return 0

  local INSERT=$CAND
  ble/complete/action:"$ACTION"/initialize || return "$?"

  local PREFIX_LEN=0
  [[ $CAND == "$COMP_PREFIX"* ]] && PREFIX_LEN=${#COMP_PREFIX}

  local icand
  ((icand=cand_count++))
  cand_cand[icand]=$CAND
  cand_word[icand]=$INSERT
  cand_pack[icand]=$ACTION:${#CAND},${#INSERT},$PREFIX_LEN:$CAND$INSERT$DATA
}

## @fn ble/complete/cand/yield.batch action data
##   @arr[in] cands
function ble/complete/cand/yield.batch {
  local ACTION=$1 DATA=$2

  local inserts threshold=500
  [[ $OSTYPE == cygwin* || $OSTYPE == msys* ]] && threshold=2000
  if ((${#cands[@]}>=threshold)) && ble/function#try ble/complete/action:"$ACTION"/initialize.batch; then
    local i n=${#cands[@]}
    for ((i=0;i<n;i++)); do
      ((cand_iloop++%bleopt_complete_polling_cycle==0)) && ble/complete/check-cancel && return 148
      local CAND=${cands[i]} INSERT=${inserts[i]}

      [[ $flag_force_fignore ]] && ! ble/complete/.fignore/filter "$CAND" && continue
      [[ $flag_source_filter ]] || ble/complete/candidates/filter#test "$CAND" || continue

      local PREFIX_LEN=0
      [[ $CAND == "$COMP_PREFIX"* ]] && PREFIX_LEN=${#COMP_PREFIX}

      local icand
      ((icand=cand_count++))
      cand_cand[icand]=$CAND
      cand_word[icand]=$INSERT
      cand_pack[icand]=$ACTION:${#CAND},${#INSERT},$PREFIX_LEN:$CAND$INSERT$DATA
    done
  else
    local cand
    for cand in "${cands[@]}"; do
      ((cand_iloop++%bleopt_complete_polling_cycle==0)) && ble/complete/check-cancel && return 148
      ble/complete/cand/yield "$ACTION" "$cand" "$DATA"
    done
  fi
  return 0
}

function ble/complete/cand/yield-filenames {
  local action=$1; shift

  local rex_hidden=
  [[ :$comp_type: != *:match-hidden:* ]] &&
    rex_hidden=${COMPV:+'.{'${#COMPV}'}'}'(^|/)\.[^/]*$'

  local -a cands=()
  local cand icand=0
  for cand; do
    ((cand_iloop++%bleopt_complete_polling_cycle==0)) && ble/complete/check-cancel && return 148
    [[ $rex_hidden && $cand =~ $rex_hidden ]] && continue
    cands[icand++]=$cand
  done

  [[ $FIGNORE ]] && local flag_force_fignore=1
  local "${_ble_complete_yield_varnames[@]/%/=}" # WA #D1570 checked
  ble/complete/cand/yield.initialize "$action"
  ble/complete/cand/yield.batch "$action"
}

_ble_complete_cand_varnames=(ACTION CAND INSERT DATA PREFIX_LEN)

## @fn ble/complete/cand/unpack data
##   @param[in] data
##     ACTION:ncand,ninsert,PREFIX_LEN:$CAND$INSERT$DATA
##   @var[out] ACTION CAND INSERT DATA PREFIX_LEN
function ble/complete/cand/unpack {
  local pack=$1
  ACTION=${pack%%:*} pack=${pack#*:}
  local text=${pack#*:}
  IFS=, builtin eval 'pack=(${pack%%:*})'
  CAND=${text::pack[0]}
  INSERT=${text:pack[0]:pack[1]}
  DATA=${text:pack[0]+pack[1]}
  PREFIX_LEN=${pack[2]}
}

## defined source
##
##   source:wordlist
##   source:command
##   source:file
##   source:dir
##   source:argument
##   source:variable
##
## implementation of source
##
## @fn ble/complete/source:$name args...
##   @param[in] args...
## User-defined arguments set in ble/syntax/completion-context/generate.
##
##   @var[in] COMP1 COMP2 COMPS COMPV comp_type
##   @var[in] comp_filter_type
##   @var[out] COMP_PREFIX
## Temporary variable referenced in ble/complete/cand/yield.
##
##   @var[in,out] cand_count cand_cand cand_word cand_pack
##   @var[in,out] cand_limit_reached

# source:none
function ble/complete/source:none { return 0; }

# source:wordlist
#
# -r Insert the specified word as is without escaping it
# -W Do not insert blank space on completion
# -s sabbrev Generate candidates as well
#
function ble/complete/source:wordlist {
  [[ $comps_flags == *v* ]] || return 1
  local COMPS=$COMPS COMPV=$COMPV
  ble/complete/source/reduce-compv-for-ambiguous-match
  [[ $COMPV =~ ^.+/ ]] && COMP_PREFIX=${BASH_REMATCH[0]}

  # process options
  local opt_raw= opt_noword= opt_sabbrev=
  while (($#)) && [[ $1 == -* ]]; do
    local arg=$1; shift
    case $arg in
    (--) break ;;
    (--*) ;; # ignore
    (-*)
      local i iN=${#arg}
      for ((i=1;i<iN;i++)); do
        case ${arg:i:1} in
        (r) opt_raw=1 ;;
        (W) opt_noword=1 ;;
        (s) opt_sabbrev=1 ;;
        (*) ;; # ignore
        esac
      done ;;
    esac
  done

  [[ $opt_sabbrev ]] &&
    ble/complete/source:sabbrev

  local action=word
  [[ $opt_noword ]] && action=substr
  [[ $opt_raw ]] && action=literal-$action

  local cand "${_ble_complete_yield_varnames[@]/%/=}" # WA #D1570 checked
  ble/complete/cand/yield.initialize "$action"
  for cand; do
    [[ $cand == "$COMPV"* ]] && ble/complete/cand/yield "$action" "$cand"
  done
}

# source:command

function ble/complete/action:suffix-sabbrev/initialize {
  ble/complete/action/quote-insert
}
function ble/complete/action:suffix-sabbrev/initialize.batch {
  ble/complete/action/quote-insert.batch newline
}
function ble/complete/action:suffix-sabbrev/complete {
  ble/complete/action/requote-final-insert
  ble/complete/action/complete.close-quotation
}
function ble/complete/action:suffix-sabbrev/init-menu-item {
  local ret; ble/color/face2g command_suffix; g=$ret
}
function ble/complete/action:suffix-sabbrev/get-desc {
  local key1= ent1=
  if [[ $CAND == *.* ]] && ble/complete/sabbrev#match "$CAND" 's'; then
    local ret
    ble/string#quote-word "${ent1#*:}" sgrq="$desc_sgrq":sgr0="$desc_sgr0"
    desc="$desc_sgrt(suffix)$desc_sgr0 .$key1=$ret"
  else
    desc="$desc_sgrt(suffix)$desc_sgr0 ??? (unmatching)"
  fi
}

function ble/complete/source:command/.is-suffix-sabbrev {
  [[ $1 =~ $source_file_regex ]] &&
    ! ble/complete/sabbrev/suffix.is-normal-command "$1"
}

function ble/complete/source:command/.contract-by-slashes {
  local slashes=${COMPV//[!'/']}
  ble/bin/awk -F / -v baseNF="${#slashes}" '
    function initialize_common() {
      common_NF = NF;
      for (i = 1; i <= NF; i++) common[i] = $i;
      common_degeneracy = 1;
      common0_NF = NF;
      common0_str = $0;
    }
    function print_common(_, output) {
      if (!common_NF) return;

      if (common_degeneracy == 1) {
        print common0_str;
        common_NF = 0;
        return;
      }

      output = common[1];
      for (i = 2; i <= common_NF; i++)
        output = output "/" common[i];

      # Note:
      #   For candidates `a/b/c/1` and `a/b/c/2`, prints `a/b/c/`.
      #   For candidates `a/b/c` and `a/b/c/1`, prints `a/b/c` and `a/b/c/1`.
      if (common_NF == common0_NF) print output;
      print output "/";

      common_NF = 0;
    }

    {
      if (NF <= baseNF + 1) {
        print_common();
        print $0;
      } else if (!common_NF) {
        initialize_common();
      } else {
        n = common_NF < NF ? common_NF : NF;
        for (i = baseNF + 1; i <= n; i++)
          if (common[i] != $i) break;
        matched_length = i - 1;

        if (matched_length <= baseNF) {
          print_common();
          initialize_common();
        } else {
          common_NF = matched_length;
          common_degeneracy++;
        }
      }
    }

    END { print_common(); }
  '
}

## @fn ble/complete/source:command/.print-command
function ble/complete/source:command/.print-command {
  # Note #D1922: Ambiguous completion for pathname commands is handled by itself, not by compgen -c.
  # Regarding the directory name, it is generated on the ble/complete/source:command/.print side.
  # It is not generated here.
  if [[ $COMPV == */* && :$comp_type: == *:[maA]:* ]]; then
    local ret
    ble/complete/source:file/generate "$COMPV"; (($?==148)) && return 148
    ble/complete/source/test-limit "${#ret[@]}" || return 1
    ble/array#filter ret '[[ ! -d $1 && -x $1 ]]'
    ((${#ret[@]})) && printf '%s\n' "${ret[@]}"

    local COMPS=$COMPS COMPV=$COMPV
    ble/complete/source/reduce-compv-for-ambiguous-match

  else
    local COMPS=$COMPS COMPV=$COMPV
    ble/complete/source/reduce-compv-for-ambiguous-match

    # Note: cygwin is very slow when starting with cyg,x86,i68, etc. Empty in other environments
    # Completion can be slow.
    local slow_compgen=
    if [[ ! $COMPV ]]; then
      shopt -q no_empty_cmd_completion && return 0
      slow_compgen=1
    elif [[ :$PATH: == *:/mnt/*:* ]] && ble/base/is-wsl; then
      # Note #D2280: Since the upstream WSL2 doesn't seem to be going to fix
      # the slow filesystem issue with /mnt/*, we decided to add a workaround.
      # https://github.com/akinomyoga/ble.sh/issues/96
      # https://github.com/akinomyoga/ble.sh/pull/504
      slow_compgen=1
    elif [[ $OSTYPE == cygwin* || $OSTYPE == msys* ]]; then
      case $COMPV in
      (?|cy*|x8*|i6*|msy*)
        slow_compgen=1 ;;
      esac
    fi

    # Note: For some reason, compgen -A command does not remove quotes. compgen -A
    # function has quotes removed. Therefore, the compgen -A command directly
    # Pass the connection COMPV and pass compv_quoted to the compgen -A function.
    if [[ $slow_compgen ]]; then
      ble/util/conditional-sync \
        'builtin compgen -c -- "$COMPV"' \
        '! ble/complete/check-cancel' 128 progressive-weight
    else
      builtin compgen -c -- "$COMPV"
    fi
  fi

  if [[ $COMPV == */* ]]; then
    local q="'" Q="'\''"
    local compv_quoted="'${COMPV//$q/$Q}'"
    builtin compgen -A function -- "$compv_quoted"
  fi
}

function ble/complete/source:command/.print {
  if [[ :$comp_type: != *:[maA]:* && $bleopt_complete_contract_function_names ]]; then
    ble/complete/source:command/.print-command |
      ble/complete/source:command/.contract-by-slashes
  else
    ble/complete/source:command/.print-command
  fi

  # Directory name enumeration (generated with /)
  #
  # Note: shopt -q autocd &> Enumerates whether or not it is /dev/null.
  #
  # Note: compgen -A directory (see code below) has a bug,
  # Do not use since bash-4.3 and later do not remove quotes (#D0714 #M0009)
  #
  #     [[ :$comp_type: == *:a:* ]] && local COMPS=${COMPS::1} COMPV=${COMPV::1}
  #     compgen -A directory -S / -- "$compv_quoted"
  #
  local flags=$1
  if [[ $flags != *D* ]]; then
    local ret
    ble/complete/source:file/generate "$COMPV" suffix-slash; (($?==148)) && return 148
    ble/complete/source/test-limit "${#ret[@]}" || return 1
    ((${#ret[@]})) && printf '%s\n' "${ret[@]}"
  fi

  # Job name enumeration
  if [[ ! $COMPV || $COMPV == %* ]]; then
    # %command name
    local q="'" Q="'\''"
    local compv_quoted=${COMPV#'%'}
    compv_quoted="'${compv_quoted//$q/$Q}'"
    builtin compgen -j -P % -- "$compv_quoted"

    # %Job number
    local i joblist; ble/util/joblist
    local job_count=${#joblist[@]}
    for i in "${!joblist[@]}"; do
      if local rex='^\[([0-9]+)\]'; [[ ${joblist[i]} =~ $rex ]]; then
        joblist[i]=%${BASH_REMATCH[1]}
      else
        builtin unset -v 'joblist[i]'
      fi
    done
    joblist=("${joblist[@]}")

    # %% %+ %-
    if ((job_count>0)); then
      ble/array#push joblist %% %+
      ((job_count>=2)) &&
        ble/array#push joblist %-
    fi

    builtin compgen -W '"${joblist[@]}"' -- "$compv_quoted"
  fi
}
function ble/complete/source:command/.generate {
  local flags=$1 compgen
  ble/util/assign compgen 'ble/complete/source:command/.print "$flags"'
  local -a arr=()
  [[ $compgen ]] && ble/util/assign-array arr 'ble/bin/sort -u <<< "$compgen"' # 1 fork/exec

  ble/complete/source/test-limit "${#arr[@]}" || return 1

  local action=command "${_ble_complete_yield_varnames[@]/%/=}" # WA #D1570 checked
  ble/complete/cand/yield.initialize "$action"

  # Invalid keyword, alias for determination
  local is_quoted=
  [[ $COMPS != "$COMPV" ]] && is_quoted=1
  local rex_keyword='^(if|then|else|elif|fi|case|esac|for|select|while|until|do|done|function|time|[!{}]|\[\[|coproc|\]\]|in)$'
  local expand_aliases=
  shopt -q expand_aliases && expand_aliases=1

  local cand icand=0 cands
  for cand in "${arr[@]}"; do
    ((cand_iloop++%bleopt_complete_polling_cycle==0)) && ble/complete/check-cancel && return 148

    # workaround: For some reason compgen -c -- "$compv_quoted"
    # Delete the exact match directory name as it will be mixed in.
    [[ $cand != */ && -d $cand ]] && ! ble/bin#has "$cand" && continue

    if [[ $is_quoted ]]; then
      local disable_count=
      # #D1691 keyword is invalid if quoted
      [[ $cand =~ $rex_keyword ]] && ((disable_count++))
      # #D1715 Invalid if alias is also quoted
      [[ $expand_aliases ]] && ble/is-alias "$cand" && ((disable_count++))
      if [[ $disable_count ]]; then
        local type; ble/util/type type "$cand"
        ((${#type[@]}>disable_count)) || continue
      fi
    else
      # 'in' and ']]' always error unless aliased
      [[ $cand == ']]' || $cand == in ]] &&
        ! { [[ $expand_aliases ]] && ble/is-alias "$cand"; } &&
        continue

      if [[ ! $expand_aliases ]]; then
        # #D1715 compgen -c enumerates alias even if expand_aliases is disabled, so
        # Exclude alias here (type takes expand_aliases into account).
        ble/is-alias "$cand" && ! ble/bin#has "$cand" && continue
      fi

      # You don't want alias to be quoted, so don't include characters that can be quoted.
      # If the
      # The special characters are !#%-~^[]{}+*:@,.?_. Furthermore, the target of escape/quote and
      # The only possible characters are [*?]{,}!^~#:. _.@+%- is not quoted ].
      if ble/string#match "$cand" '[][*?{,}!^~#]' && ble/is-alias "$cand"; then
        ble/complete/cand/yield "$action" "$cand" :noquote:
        continue
      fi
    fi

    cands[icand++]=$cand
  done
  ble/complete/cand/yield.batch "$action"
}

## ble/complete/source:command flags
##   @param[in] flags
##     A set of flag characters.
##     @opt D
##       When D is specified, directory-name generation is suppressed.
##     @opt V
##       When V is specified, variable-name generation is suppressed.
function ble/complete/source:command {
  [[ $comps_flags == *v* ]] || return 1

  local comp_opts=: old_cand_count=$cand_count

  # Try progcomp by "complete -E" before checking no_empty_cmd_completion.
  if [[ ! $_ble_edit_str ]]; then
    ble/complete/source:argument/.generate-user-defined-completion empty; local ext=$?
    ((ext==148||ext==0&&cand_count>old_cand_count)) && return "$ext"
  fi

  [[ ! $COMPV ]] && shopt -q no_empty_cmd_completion && return 1
  [[ $COMPV =~ ^.+/ ]] && COMP_PREFIX=${BASH_REMATCH[0]}

  # Try progcomp by "complete -I"
  ble/complete/source:argument/.generate-user-defined-completion initial; local ext=$?
  ((ext==148||ext==0&&cand_count>old_cand_count)) && return "$ext"

  ble/complete/source:sabbrev

  # Generate command names (including job specs and directory names)
  ble/complete/source:command/.generate "$1"

  # Generate variable names
  [[ $1 != *V* ]] &&
    ble/string#match "$COMPV" '^([_a-zA-Z][_a-zA-Z0-9]*)?$' &&
    ble/complete/source:variable '='

  # Generate candidates for suffix sabbrev
  local ret
  if ble/complete/sabbrev/suffix.construct-regex; then
    local source_file_regex=$ret
    local source_file_filter=ble/complete/source:command/.is-suffix-sabbrev
    ble/complete/source:file filter:action=suffix-sabbrev
  fi
}

# source:file, source:function

function ble/complete/source:function/.print-raw {
  local COMPS=$COMPS COMPV=$COMPV
  ble/complete/source/reduce-compv-for-ambiguous-match
  local q="'" Q="'\''"
  local compv_quoted="'${COMPV//$q/$Q}'"
  builtin compgen -A function -- "$compv_quoted"
}
function ble/complete/source:function/.print {
  if [[ :$comp_type: != *:[maA]:* && $bleopt_complete_contract_function_names ]]; then
    ble/complete/source:function/.print-raw |
      ble/complete/source:command/.contract-by-slashes
  else
    ble/complete/source:function/.print-raw
  fi
}
function ble/complete/source:function {
  local compgen
  ble/util/assign compgen 'ble/complete/source:function/.print'
  [[ $compgen ]] || return 0

  local cands
  ble/util/assign-array cands 'ble/bin/sort -u <<< "$compgen"'
  ((${#cands[@]})) || return 0

  ble/complete/source/test-limit "${#cands[@]}" || return 1

  local action=command "${_ble_complete_yield_varnames[@]/%/=}" # disable=#D1570
  ble/complete/cand/yield.initialize "$action"
  ble/complete/cand/yield.batch "$action"
}

# source:file, source:dir

function ble/complete/util/eval-pathname-expansion/.print-def {
  local pattern=$1 ret
  IFS= builtin eval "ret=($pattern)" 2>/dev/null
  ble/string#quote-words "${ret[@]}"
  ble/util/print "ret=($ret)"
}

## @fn ble/complete/util/eval-pathname-expansion pattern
##   @var[out] ret
function ble/complete/util/eval-pathname-expansion {
  local pattern=$1

  local -a dtor=()

  if [[ -o noglob ]]; then
    set +f
    ble/array#push dtor 'set -f'
  fi

  if ! shopt -q nullglob; then
    shopt -s nullglob
    ble/array#push dtor 'shopt -u nullglob'
  fi

  if ! shopt -q dotglob; then
    shopt -s dotglob
    ble/array#push dtor 'shopt -u dotglob'
  else
    # If you touch GLOBIGNORE, the settings will change.
    # dotglob is explicitly saved and restored.
    ble/array#push dtor 'shopt -s dotglob'
  fi

  if ! shopt -q extglob; then
    shopt -s extglob
    ble/array#push dtor 'shopt -u extglob'
  fi

  if [[ :$comp_type: == *:i:* ]]; then
    if ! shopt -q nocaseglob; then
      shopt -s nocaseglob
      ble/array#push dtor 'shopt -u nocaseglob'
    fi
  else
    if shopt -q nocaseglob; then
      shopt -u nocaseglob
      ble/array#push dtor 'shopt -s nocaseglob'
    fi
  fi

  if ble/util/is-cygwin-slow-glob "$pattern"; then # Note: #D1168
    if shopt -q failglob &>/dev/null || shopt -q nullglob &>/dev/null; then
      pattern=
    else
      set -f
      ble/array#push dtor 'set +f'
    fi
  fi

  if [[ $GLOBIGNORE ]]; then
    local GLOBIGNORE_save=$GLOBIGNORE
    GLOBIGNORE=
    ble/array#push dtor 'GLOBIGNORE=$GLOBIGNORE_save'
  fi

  ble/array#reverse dtor

  ret=()
  if [[ :$comp_type: == *:sync:* ]]; then
    IFS= builtin eval "ret=($pattern)" 2>/dev/null
  else
    local sync_command='ble/complete/util/eval-pathname-expansion/.print-def "$pattern"'
    local sync_opts=progressive-weight
    [[ :$comp_type: == *:auto:* && $bleopt_complete_timeout_auto ]] &&
      sync_opts=$sync_opts:timeout=$((bleopt_complete_timeout_auto))

    local def
    ble/util/assign def 'ble/util/conditional-sync "$sync_command" "" "" "$sync_opts"' &>/dev/null; local ext=$?
    if ((ext==148)) || ble/complete/check-cancel; then
      ble/util/invoke-hook dtor
      return 148
    fi
    builtin eval -- "$def"
  fi

  ble/util/invoke-hook dtor
  return 0
}

## @fn ble/complete/source:file/.construct-ambiguous-pathname-pattern path [fixlen] [opts]
## Generates a fuzzy match pattern corresponding to the specified path.
## For example, generate file names with a*/b*/g* for alpha/beta/gamma.
## However, "../" and "./" should be left as is (without converting them to ".*.*/", ".*/", etc.).
##
##   @param[in] path
##   @param[in,opt] fixlen
##   @param[in,opt] opts
##     @opt substr
##   @var[out] ret
##
##   @remarks
## Initially, it was generated using a*/b*/g* and left to filtering out those that did not match in the later filters, but it was slow.
## Therefore, I changed it to generate patterns like a*l*p*h*a*/b*e*t*a*/g*a*m*m*a*.
##
function ble/complete/source:file/.construct-ambiguous-pathname-pattern {
  local path=$1 fixlen=${2:-1} opts=${3:-}
  local pattern= i=0 j
  local names; ble/string#split names / "$1"
  local name
  for name in "${names[@]}"; do
    ((i++)) && pattern=$pattern/
    if [[ $name == .. || $name == . && i -lt ${#names[@]} ]]; then
      pattern=$pattern$name
      continue
    fi

    [[ $name ]] || continue

    if [[ :$opts: == *:substr:* ]]; then
      ble/string#quote-word "$name"
      pattern=$pattern*$ret*
    else
      ble/string#quote-word "${name::fixlen}"
      pattern=$pattern$ret*
      for ((j=fixlen;j<${#name};j++)); do
        ble/string#quote-word "${name:j:1}"
        if [[ $_ble_bash -lt 50000 && $pattern == *\* ]]; then
          # Convert * to extglob *([!ch]) #D1389
          pattern=$pattern'([!'$ret'])'
        fi
        pattern=$pattern$ret*
      done
    fi
  done
  [[ $pattern == *'*' ]] || pattern=$pattern*
  ret=$pattern
}
## @fn ble/complete/source:file/.construct-pathname-pattern path
##   @param[in] path
##   @var[in] comp_type
##   @var[out] ret
function ble/complete/source:file/.construct-pathname-pattern {
  local path=$1 pattern
  case :$comp_type: in
  (*:m:*) ble/complete/source:file/.construct-ambiguous-pathname-pattern "$path" '' substr; pattern=$ret ;;
  (*:a:*) ble/complete/source:file/.construct-ambiguous-pathname-pattern "$path"; pattern=$ret ;;
  (*:A:*) ble/complete/source:file/.construct-ambiguous-pathname-pattern "$path" 0; pattern=$ret ;;
  (*) ble/string#quote-word "$path"; pattern=$ret*
  esac
  ret=$pattern
}

## @fn ble/complete/source:file/generate path [opts] [prefix]
##    @param[in] path
##    @param[in,opt] opts
##      @opt suffix-slash
##      @opt ensure-slash
##    @param[in,opt] prefix
##    @var[in] comp_type
##    @arr[out] ret
function ble/complete/source:file/generate {
  local path=$1 opts=${2-} prefix=${3-}

  if [[ :$comp_type: == *:[maA]:* && $path == *[!/]*/* ]]; then
    ble/complete/source:file/generate "${path##*/}" "$opts" "$prefix${path%/*}/"
    (($?==148)) && return 148
    ((${#ret[@]})) && return 0
  fi

  if [[ $prefix ]]; then
    ble/string#quote-word "$prefix"
    prefix=$ret
  fi
  ble/complete/source:file/.construct-pathname-pattern "$path"
  local pattern=$prefix$ret
  case :$opts: in
  (*:suffix-slash:*) pattern=$pattern/ ;;
  (*:ensure-slash:*) pattern=${pattern%/}/ ;;
  esac

  ble/complete/util/eval-pathname-expansion "$pattern"
}

## @fn ble/complete/source:file opts
##   @param[in,opt] opts
##     @opt directory
##       Generate only directory names
##     @opt no-fd
##       Exclude filenames that look like file descriptors and -
##     @opt filter-by-regex
##       Filter the generated filenames by the regular expression stored in the
##       shell variable `source_file_regex`.
##       @var[in] source_file_regex
##     @opt filter
##       Filter the generated filenames by the predicate stored specified by
##       the shell variable `source_file_filter`.
##       @var[in] source_file_filter
##     @opt action=ACTION
##
function ble/complete/source:file {
  local opts=$1
  [[ $comps_flags == *v* ]] || return 1
  [[ :$comp_type: != *:[maA]:* && $COMPV =~ ^.+/ ]] && COMP_PREFIX=${BASH_REMATCH[0]}
  # If the input string is empty, fuzzy completion is essentially the same as normal completion, so skip it.
  [[ :$comp_type: == *:[maA]:* && ! $COMPV ]] && return 1

  # Note: compgen -A file/directory (see code below) has a bug,
  # Do not use in bash-4.0 and 4.1 as quote removal is not performed (#D0714 #M0009)
  #
  #     local q="'" Q="'\''"; local compv_quoted="'${COMPV//$q/$Q}'"
  #     local candidates; ble/util/compgen candidates -A file -- "$compv_quoted"

  ble/complete/source:tilde; local ext=$?
  ((ext==148||ext==0)) && return "$ext"

  local -a candidates=()
  local ret pathgen_opts=
  [[ :$opts: == *:directory:* ]] && pathgen_opts=$pathgen_opts:suffix-slash
  ble/complete/source:file/generate "$COMPV" "$pathgen_opts"; (($?==148)) && return 148
  ble/complete/source/test-limit "${#ret[@]}" || return 1

  if [[ :$opts: == *:directory:* ]]; then
    candidates=("${ret[@]%/}") # disable=#D2352 (filename should not be empty)
  else
    candidates=("${ret[@]}")
  fi
  [[ :$opts: == *:no-fd:* ]] &&
    ble/array#remove-by-regex candidates '^[0-9]+-?$|^-$'

  [[ :$opts: == *:filter-by-regex:* ]] &&
    ble/array#filter-by-regex candidates "$source_file_regex"
  [[ :$opts: == *:filter:* ]] &&
    ble/array#filter candidates "$source_file_filter"

  local action=file ret=
  ble/opts#extract-last-optarg "$opts" action
  [[ $ret ]] && action=$ret

  local flag_source_filter=1
  ble/complete/cand/yield-filenames "$action" "${candidates[@]}"
}

function ble/complete/source:dir {
  ble/complete/source:file "directory:$1"
}

# source:rhs

function ble/complete/source:rhs { ble/complete/source:file; }

#------------------------------------------------------------------------------
# source:tilde

function ble/complete/action:tilde/initialize {
  # Tilde is not quoted
  CAND=${CAND#\~} ble/complete/action/quote-insert
  INSERT=\~$INSERT

  # Note: Check for invalid user names with tilde expansion on Windows, etc.
  local rex='^~[^/'\''"$`\!:]*$'; [[ $INSERT =~ $rex ]]
}
function ble/complete/action:tilde/complete {
  ble/complete/action/complete.mark-directory
}
function ble/complete/action:tilde/init-menu-item {
  local ret
  ble/color/face2g filename_directory; g=$ret
}
function ble/complete/action:tilde/get-desc {
  if [[ $CAND == '~+' ]]; then
    desc='current directory (tilde expansion)'
  elif [[ $CAND == '~-' ]]; then
    desc='previous directory (tilde expansion)'
  elif local rex='^~[0-9]$'; [[ $CAND =~ $rex ]]; then
    desc='DIRSTACK directory (tilde expansion)'
  else
    desc='user directory (tilde expansion)'
  fi
}

function ble/complete/source:tilde/.generate {
  # generate user directories
  local pattern=${COMPS#\~}
  [[ :$comp_type: == *:[maA]:* ]] && pattern=
  builtin compgen -P \~ -u -- "$pattern"

  # generate special tilde expansions
  printf '%s\n' '~' '~+' '~-'
  local dirstack_max=$((${#DIRSTACK[@]}-1))
  ((dirstack_max>=0)) &&
    builtin eval "printf '%s\n' '~'{0..$dirstack_max}"
}

# tilde expansion
function ble/complete/source:tilde {
  local rex='^~[^/'\''"$`\!:]*$'; [[ $COMPS =~ $rex ]] || return 1

  # Generate candidates
  # Note: On Windows, the same username is
  # Run sort -u as it will be enumerated multiple times.
  local compgen candidates
  ble/util/assign compgen ble/complete/source:tilde/.generate
  [[ $compgen ]] || return 1
  ble/util/assign-array candidates 'ble/bin/sort -u <<< "$compgen"'

  # Filter by yourself using COMPS
  local flag_source_filter=1
  if [[ $COMPS == '~'?* ]]; then
    local filter_type=$comp_filter_type
    [[ $filter_type == none ]] && filter_type=head
    local comp_filter_type
    local comp_filter_pattern
    ble/complete/candidates/filter#init "$filter_type" "$COMPS"
    ble/array#filter candidates ble/complete/candidates/filter#test
  fi

  ((${#candidates[@]})) || return 1

  local old_cand_count=$cand_count
  ble/complete/cand/yield-filenames tilde "${candidates[@]}"; local ext=$?
  return "$((ext?ext:cand_count>old_cand_count))"
}

function ble/complete/source:fd {
  [[ $comp_filter_type == none ]] &&
    local comp_filter_type=head

  local old_cand_count=$cand_count
  local action=word "${_ble_complete_yield_varnames[@]/%/=}" # WA #D1570 checked
  ble/complete/cand/yield.initialize "$action"
  ble/complete/cand/yield "$action" -
  if [[ -d /proc/self/fd ]]; then
    local ret
    ble/complete/util/eval-pathname-expansion '/proc/self/fd/*'

    local fd
    for fd in "${ret[@]}"; do
      fd=${fd#/proc/self/fd/}
      [[ ${fd//[0-9]} ]] && continue
      ble/fd#is-cloexit "$fd" && continue
      ble/complete/cand/yield "$action" "$fd"
      ble/complete/cand/yield "$action" "$fd-"
    done
  else
    local fd
    for ((fd=0;fd<10;fd++)); do
      ble/fd#is-open "$fd" || continue
      ble/complete/cand/yield "$action" "$fd"
      ble/complete/cand/yield "$action" "$fd-"
    done
  fi

  return "$((cand_count>old_cand_count))"
}

#------------------------------------------------------------------------------
# progcomp

# progcomp/.compgen

## @fn ble/complete/progcomp/.compvar-initialize-wordbreaks
##   @var[out] wordbreaks
function ble/complete/progcomp/.compvar-initialize-wordbreaks {
  local ifs=$_ble_term_IFS q=\'\" delim=';&|<>()' glob='[*?' hist='!^{' esc='`$\'
  local escaped=$ifs$q$delim$glob$hist$esc
  wordbreaks=${COMP_WORDBREAKS//[$escaped]} # =:
}
## @fn ble/complete/progcomp/.compvar-perform-wordbreaks word
##   @var[in] wordbreaks
##   @arr[out] ret
function ble/complete/progcomp/.compvar-perform-wordbreaks {
  local word=$1
  if [[ ! $word ]]; then
    ret=('')
    return 0
  fi

  ret=()
  while local head=${word%%["$wordbreaks"]*}; [[ $head != $word ]]; do
    # Note: #D1094 Combine consecutive wordbreaks into one, following bash behavior.
    ble/array#push ret "$head"
    word=${word:${#head}}
    head=${word%%[!"$wordbreaks"]*}
    ble/array#push ret "$head"
    word=${word:${#head}}
  done

  # Note: #D1094 Push to ret even if $word is empty.
  # When $word is empty, it means that it ends with wordbreaks, but
  # In that case, consider starting a new word after the wordbreaks.
  ble/array#push ret "$word"
}
function ble/complete/progcomp/.compvar-eval-word {
  local opts=$2:single
  if [[ :$opts: == *:noglob:* ]]; then
    ble/syntax:bash/simple-word/eval "$1" "$opts"
  else
    [[ $bleopt_complete_timeout_compvar ]] &&
      opts=timeout=$((bleopt_complete_timeout_compvar)):retry-noglob-on-timeout:$opts
    ble/complete/source/eval-simple-word "$1" "$opts"
  fi
}

## @fn ble/complete/progcomp/.compvar-generate-subwords/impl1 word
## Strategy to split with $wordbreaks and then evaluate.
##
##   @param word
##   @arr[out] words
##   @var[in,out] point
##   @var[in] wordbreaks
##   @exit
## Fails if it cannot be processed as a simple word.
## otherwise returns 0.
function ble/complete/progcomp/.compvar-generate-subwords/impl1 {
  local word=$1 ret simple_flags simple_ibrace
  if [[ $point ]]; then
    # Split word into first half and second half at point
    local left=${word::point} right=${word:point}
  else
    local left=$word right=
    local point= # hide
  fi

  ble/syntax:bash/simple-word/reconstruct-incomplete-word "$left" || return 1
  left=$ret
  if [[ $right ]]; then
    case $simple_flags in
    (*I*) right=\$\"$right ;;
    (*D*) right=\"$right ;;
    (*E*) right=\$\'$right ;;
    (*S*) right=\'$right ;;
    (*B*) right=\\$right ;;
    esac
    ble/syntax:bash/simple-word/reconstruct-incomplete-word "$right" || return 1
    right=$ret
  fi

  point=0 words=()

  # Evaluate each word (first half)
  local eval_opts=noglob
  ((${#ret[@]}==1)) && eval_opts=
  ble/syntax:bash/simple-word#break-word "$left" "$wordbreaks"
  local subword
  for subword in "${ret[@]}"; do
    ble/complete/progcomp/.compvar-eval-word "$subword" "$eval_opts"
    ble/array#push words "$ret"
    ((point+=${#ret}))
  done

  # Evaluation for each word (second half)
  if [[ $right ]]; then
    ble/syntax:bash/simple-word#break-word "$right" "$wordbreaks"
    local subword isfirst=1
    for subword in "${ret[@]}"; do
      ble/complete/progcomp/.compvar-eval-word "$subword" noglob
      if [[ $isfirst ]]; then
        isfirst=
        local iword=${#words[@]}; ((iword&&iword--))
        words[iword]=${words[iword]}$ret
      else
        ble/array#push words "$ret"
      fi
    done
  fi
  return 0
}
## @fn ble/complete/progcomp/.compvar-generate-subwords/impl2 word
## Strategy to evaluate and then split with $wordbreaks.
##
##   @param word
##   @arr[out] words
##   @var[in,out] point
##   @var[in] wordbreaks
##   @exit
## Fails if it cannot be processed as a simple word.
## otherwise returns 0.
function ble/complete/progcomp/.compvar-generate-subwords/impl2 {
  local word=$1
  ble/syntax:bash/simple-word/reconstruct-incomplete-word "$word" || return 1

  ble/complete/progcomp/.compvar-eval-word "$ret"; (($?==148)) && return 148; local value1=$ret
  if [[ $point ]]; then
    if ((point==${#word})); then
      point=${#value1}
    elif ble/syntax:bash/simple-word/reconstruct-incomplete-word "${word::point}"; then
      ble/complete/progcomp/.compvar-eval-word "$ret"; (($?==148)) && return 148
      point=${#ret}
    fi
  fi

  ble/complete/progcomp/.compvar-perform-wordbreaks "$value1"; words=("${ret[@]}")
  return 0
}
## @fn ble/complete/progcomp/.compvar-generate-subwords word1
## Split word1 by COMP_WORDBREAKS.
##
##   @arr[out] words
## Stores the word fragments obtained by segmentation.
##
##   @var[in,out] subword_flags
## When E is included, it indicates that the word has been expanded or divided.
## When the whole word is a simple word, first eval and divide using COMP_WORDBREAKS.
## If not, first split with COMP_WORDBREAKS,
## Attempt a simple word eval for each word fragment.
##
## When Q is included, suppress expansion and quoting in subsequent processing,
## Indicates that the word is passed as is to the completion function.
## This is used to complete the username for the tilde ~.
##
##   @var[in,out] point
##   @var[in] wordbreaks
##
## Note: If the whole word is a simple word, eval it first and split it using COMP_WORDBREAKS.
## At this time, set subword_flags=E.
##
function ble/complete/progcomp/.compvar-generate-subwords {
  local word1=$1 ret simple_flags simple_ibrace
  if [[ ! $word1 ]]; then
    # Note: If you use '' to make the empty string a valid word, git's completion function will not work.
    # I have no choice but to register it as an empty string.
    subword_flags=E
    words=('')
  elif [[ $word1 == '~' ]]; then
    # #D1362: When ~ is expanded, the user name cannot be completed, so pass it as is.
    subword_flags=Q
    words=('~')
  elif ble/complete/progcomp/.compvar-generate-subwords/impl1 "$word1"; then
    # First, try a split-first, then-evaluate strategy.
    subword_flags=E
  elif ble/complete/progcomp/.compvar-generate-subwords/impl2 "$word1"; then
    # Next, try an evaluate-then-divide strategy.
    subword_flags=E
  else
    ble/complete/progcomp/.compvar-perform-wordbreaks "$word1"; words=("${ret[@]}")
  fi
}
## @fn ble/complete/progcomp/.compvar-quote-subword word
##   @var[in] index subword_flags
##   @var[out] ret
##   @var[in,out] p
function ble/complete/progcomp/.compvar-quote-subword {
  local word=$1 to_quote= is_evaluated= is_quoted=
  if [[ $subword_flags == *[EQ]* ]]; then
    [[ $subword_flags == *E* ]] && to_quote=1
  elif ble/syntax:bash/simple-word/reconstruct-incomplete-word "$word"; then
    is_evaluated=1
    ble/complete/progcomp/.compvar-eval-word "$ret"; (($?==148)) && return 148; word=$ret
    to_quote=1
  fi

  # Requote everything except the command name
  if [[ $to_quote ]]; then
    local shell_specialchars=']\ ["'\''`$|&;<>()*?{}!^'$'\n\t' q="'" Q="'\''" qq="''"
    if ((index>0)) && [[ $word == *["$shell_specialchars"]* || $word == [#~]* ]]; then
      is_quoted=1
      word="'${w//$q/$Q}'" word=${word#"$qq"} word=${word%"$qq"}
    fi
  fi

  # When word fragments are corrected, p is also corrected.
  if [[ $p && $word != "$1" ]]; then
    if ((p==${#1})); then
      p=${#word}
    else
      local left=${word::p}
      if [[ $is_evaluated ]]; then
        if ble/syntax:bash/simple-word/reconstruct-incomplete-word "$left"; then
          ble/complete/progcomp/.compvar-eval-word "$ret"; (($?==148)) && return 148; left=$ret
        fi
      fi
      if [[ $is_quoted ]]; then
        left="'${left//$q/$Q}" left=${left#"$qq"}
      fi
      p=${#left}
    fi
  fi

  ret=$word
}

## @fn ble/complete/progcomp/.compvar-reduce-cur current_subword
##   @param[in] current_subword
##   @var[out] cur
builtin unset -v _ble_complete_progcomp_cur_wordbreaks
_ble_complete_progcomp_cur_rex_simple=
_ble_complete_progcomp_cur_rex_break=
function ble/complete/progcomp/.compvar-reduce-cur {
  # Regular expression update
  if [[ ! ${_ble_complete_progcomp_cur_wordbreaks+set} || $COMP_WORDBREAKS != "$_ble_complete_progcomp_cur_wordbreaks" ]]; then
    _ble_complete_progcomp_cur_wordbreaks=$COMP_WORDBREAKS
    _ble_complete_progcomp_cur_rex_simple='^([^\"'\'']|\\.|"([^\"]|\\.)*"|'\''[^'\'']*'\'')*'
    local chars=${COMP_WORDBREAKS//[\'\"]/} rex_break=
    [[ $chars == *\\* ]] && chars=${chars//\\/} rex_break='\\(.|$)'
    [[ $chars == *\$* ]] && chars=${chars//\$/} rex_break+=${rex_break:+'|'}'\$([^$'\'${rex_break:+\\}']|$)'
    if [[ $chars == '^' ]]; then
      rex_break+=${rex_break:+'|'}'\^'
    elif [[ $chars ]]; then
      [[ $chars == ?*']'* ]] && chars=']'${chars//']'/}
      [[ $chars == '^'* ]] && chars=${chars:1}${chars::1}
      [[ $chars == *'-'*? ]] && chars=${chars//'-'/}'-'
      rex_break+=${rex_break:+'|'}[$chars]
    fi
    _ble_complete_progcomp_cur_rex_break='^([^\"'\''$]|\$*\\.|\$*"([^\"]|\\.)*"|'\''[^'\'']*'\''|\$+'\''([^'\''\]|\\.)*'\''|\$+([^'\'']|$))*\$*('${rex_break:-'^$'}')'
  fi

  cur=$1
  if [[ $cur =~ $_ble_complete_progcomp_cur_rex_simple && ${cur:${#BASH_REMATCH}} == [\'\"]* ]]; then
    cur=${cur:${#BASH_REMATCH}+1}
  elif [[ $cur =~ $_ble_complete_progcomp_cur_rex_break ]]; then
    cur=${cur:${#BASH_REMATCH}}
    case ${BASH_REMATCH[5]} in (\$*|@|\\?) cur=${BASH_REMATCH[5]#\\}$cur ;; esac
  fi
}

## @fn ble/complete/progcomp/.compvar-initialize
## Construct variables provided by program completion.
##   @var[in]  comp_words comp_cword comp_line comp_point
##   @var[out] COMP_WORDS COMP_CWORD COMP_LINE COMP_POINT COMP_KEY COMP_TYPE
##   @var[out] cmd cur prev
## Stores arguments to be passed to the completion function. cmd is the code before division by COMP_WORDBREAKS.
## command name. cur holds the part of the current word before the cursor. However,
## If there is an unclosed quotation mark, the contents of the quotation mark are replaced by the characters COMP_WORDBREAKS.
## Returns the last word after being split by it, if any.
##   @var[out] progcomp_prefix
function ble/complete/progcomp/.compvar-initialize {
  COMP_TYPE=9
  COMP_KEY=9
  ((${#KEYS[@]})) && COMP_KEY=${KEYS[${#KEYS[@]}-1]:-9} # KEYS defined in ble-decode/widget/.call-keyseq

  # Note: The subsequent processing basically uses comp_words, comp_line, comp_point, and comp_cword.
  # COMP_WORDS COMP_LINE COMP_POINT Copy to COMP_CWORD.
  # (1) However, when directly substituted. bash-completion does not work properly if $'' etc.
  # Remove escape and process appropriately.
  # (2) Split words on characters in COMP_WORDBREAKS other than shell special characters.

  local wordbreaks
  ble/complete/progcomp/.compvar-initialize-wordbreaks

  progcomp_prefix=
  COMP_CWORD=-1
  COMP_POINT=0
  COMP_LINE=
  COMP_WORDS=()
  cmd=${comp_words[0]-}
  cur= prev=
  local ret simple_flags simple_ibrace
  local word1 index=0 offset=0 sep=
  for word1 in "${comp_words[@]}"; do
    # @var offset_dst
    # Starting position within COMP_LINE of the current word
    local offset_dst=${#COMP_LINE}
    # @var point
    # When word is the current word, maintains the cursor position within word.
    # Empty string otherwise.
    local point=$((comp_point-offset))
    ((0<=point&&point<=${#word1})) || point=
    ((offset+=${#word1}))

    local words subword_flags=
    ble/complete/progcomp/.compvar-generate-subwords "$word1"

    local w wq i=0 o=0 p
    for w in "${words[@]}"; do
      # @var p
      # The position of the cursor within the current word fragment.
      # An empty string if the cursor is not inside the current word fragment.
      p=
      if [[ $point ]]; then
        ((p=point-o))
        # Note: #D1094 Even numbered word fragments if on the boundary
        # (non-wordbreaks).
        ((i%2==0?p<=${#w}:p<${#w})) || p=
        ((o+=${#w},i++))
      fi
      # When the cursor is on the subword boundary, it belongs to the left subword.
      # Clear point so that no processing is performed on the subword on the right.
      [[ $p ]] && point=
      [[ $point ]] && progcomp_prefix=$progcomp_prefix$w

      # Note: When w -> wq is modified, p is also modified here.
      ble/complete/progcomp/.compvar-quote-subword "$w"; local wq=$ret

      # word registration
      if [[ $p ]]; then
        COMP_CWORD=${#COMP_WORDS[*]}
        ((COMP_POINT=${#COMP_LINE}+${#sep}+p))
        ble/complete/progcomp/.compvar-reduce-cur "${COMP_LINE:offset_dst}${wq::p}"
        prev=${COMP_WORDS[COMP_CWORD-1]}
      fi
      ble/array#push COMP_WORDS "$wq"
      COMP_LINE=$COMP_LINE$sep$wq
      sep=
    done

    sep=' '
    ((offset++))
    ((index++))
  done
}
function ble/complete/progcomp/.compgen-helper-prog {
  if [[ $comp_prog ]]; then
    local COMP_WORDS COMP_CWORD cmd cur prev
    local -x COMP_LINE COMP_POINT COMP_TYPE COMP_KEY
    ble/complete/progcomp/.compvar-initialize

    if [[ $comp_opts == *:ble/prog-trim:* ]]; then
      # WA: aws_completer
      local compreply
      ble/util/assign compreply '"$comp_prog" "$cmd" "$cur" "$prev" < /dev/null'
      ble/bin/sed "s/[[:blank:]]\{1,\}\$//" <<< "$compreply"
    else
      "$comp_prog" "$cmd" "$cur" "$prev" < /dev/null
    fi
  fi
}
## @fn ble/complete/progcomp/compopt [-o OPTION|+o OPTION]
##   This function temporarily replaces the compopt builtin to record the
##   completion options "-o/+o OPTION" dynamically specified in completion
##   functions called through "complete -F func".
##
##   OPTION
##     In addition to the ones supported by Bash, the following ble Extensions
##     may be specified.
##
##     ble/syntax-raw
##       This indicates that the generated candidate should be inserted as is
##       and later manipulations should operate on its literal value instead of
##       the expansion results.  This suppresses the reconstruction of brace
##       expansions.  Later filtering are performed by the literal word
##       (e.g. foo\*bar) instead of its value after shell expansions
##       (e.g. foo*bar).  Requoting is performed only when "-o filenames" is
##       specified and "-o noquote" is unspecified.
##
##     ble/default
##       When no candidates are generated by the user's completion, ble.sh
##       performs its own completion for arguments.  This is turned on by
##       default.  To disable it, "compopt +o ble/default" can be run in the
##       completion function.
##
##     ble/no-default (deprecate)
##       Disable "-o ble/default".  This is an opposite option to ble/default.
##
##     ble/no-mark-directories
##       Do not suffix a slash "/" after the completed candidate that matches a
##       directory name.
##
##     ble/prog-trim
##       Trim a space at the end of each line in the output of command
##       specified by "complete -C command".  This option is intended for
##       internal processing by ble.sh, but one may specify it in the
##       completion function specified by "complete -F func" since "-F" is
##       processed in prior to "-C".
##
##     ble/filter-by-prefix
##       Filter the generated candidates afterward by the prefix COMPV (the
##       expansion results of the current word).
##
function ble/complete/progcomp/compopt/.error {
  if ((_ble_bash>=40000&&$#>=2)); then
    # let the builtin output the error message
    builtin compopt "${@:2}"
  else
    ble/util/print "ble.sh: compopt: $1" >&2
  fi
  has_error=1
}
function ble/complete/progcomp/compopt/.enable {
  if [[ $1 == ble/no-default ]]; then
    # redirect deprecated option
    ble/complete/progcomp/compopt/.disable ble/default
    return "$?"
  elif [[ ! $1 || $1 == *:* ]]; then
    ble/complete/progcomp/compopt/.error "$1: invalid option name" -o "$1"
    return "$?"
  fi

  ble/array#push ospec "-$1"
  ble/array#push compopt_args -o "$1"
}
function ble/complete/progcomp/compopt/.disable {
  if [[ $1 == ble/no-default ]]; then
    # redirect deprecated option
    ble/complete/progcomp/compopt/.enable ble/default
    return "$?"
  elif [[ ! $1 || $1 == *:* ]]; then
    ble/complete/progcomp/compopt/.error "$1: invalid option name" +o "$1"
    return "$?"
  fi

  ble/array#push ospec "+$1"
  ble/array#push compopt_args +o "$1"
}
function ble/complete/progcomp/compopt/.read-arguments {
  ospec=() has_cmd= compopt_args=()

  local has_error= has_stop= has_help=
  while (($#)); do
    local arg=$1; shift
    if [[ $arg == [-+]?* && ! $has_stop ]]; then
      case $arg in
      (--?*)
        case $arg in
        (--help) has_help=1 ;;
        (*)
          ble/complete/progcomp/compopt/.error "unrecognized long option '$arg'" ;;
        esac ;;
      (--) has_stop=1 ;;
      (-*)
        arg=${arg:1}
        while [[ $arg ]]; do
          local c=${arg::1}
          arg=${arg:1}
          case $c in
          (o)
            if [[ ! $arg ]]; then
              if (($#)); then
                arg=$1; shift
              else
                ble/complete/progcomp/compopt/.error '-o: option requires an argument' -o
                break 2
              fi
            fi
            ble/complete/progcomp/compopt/.enable "$arg"
            arg= ;;
          ([DEI])
            ble/array#push compopt_args "-$c"
            has_cmd=1 ;;
          (*)
            ble/complete/progcomp/compopt/.error "-$c: invalid option" "-$c" ;;
          esac
        done ;;
      (+o)
        arg=${arg:2}
        if [[ ! $arg ]]; then
          if (($#)); then
            arg=$1; shift
          else
            ble/complete/progcomp/compopt/.error '+o: option requires an argument' +o
            break
          fi
        fi
        ble/complete/progcomp/compopt/.disable "$arg" ;;
      (*)
        ble/complete/progcomp/compopt/.error "$arg: invalid option" "$arg" ;;
      esac
    else
      ble/array#push compopt_args "$arg"
      has_cmd=1
      has_stop=1 # Bash's compopt stops parsing options on any name
    fi
  done

  if [[ $has_error ]]; then
    return 2
  elif [[ $has_help ]]; then
    if ((_ble_bash>=40000)); then
      builtin help compopt
    else
      ble/util/print-lines \
        'compopt: compopt [-o|+o option] [-DEI] [name ...]' \
        '    Modify or display completion options.' '' >&2
    fi
    return 2
  fi

  return 0
}
function ble/complete/progcomp/compopt {
  local ospec has_cmd compopt_args
  ble/complete/progcomp/compopt/.read-arguments "$@" || return 2

  if ((${#ospec[@]})); then
    local s
    for s in "${ospec[@]}"; do
      case $s in
      (-*) comp_opts=${comp_opts//:"${s:1}":/:}${s:1}: ;;
      (+*) comp_opts=${comp_opts//:"${s:1}":/:} ;;
      esac
    done
  elif [[ $has_cmd ]]; then
    builtin compopt "${compopt_args[@]}"
  else
    local option options out='compopt'
    ble/string#split options : "${comp_opts%:}"
    "${_ble_util_set_declare[@]//NAME/mark}" # WA #D1570 checked
    ble/set#add mark ''
    for option in "${options[@]}"; do
      ble/set#contains mark "$option" && continue
      ble/set#add mark "$option"
      out="$out -o $option"
    done
    ble/util/print "$out"
  fi
}
function ble/complete/progcomp/.check-limits {
  # user-input check
  ((cand_iloop++%bleopt_complete_polling_cycle==0)) &&
    [[ ! -t 0 ]] && ble/complete/check-cancel &&
    return 148
  ble/complete/source/test-limit "$((progcomp_read_count++))"
  return "$?"
}
function ble/complete/progcomp/.compgen-helper-func {
  [[ $comp_func ]] || return 1
  local -a COMP_WORDS
  local COMP_LINE COMP_POINT COMP_CWORD COMP_TYPE COMP_KEY cmd cur prev
  ble/complete/progcomp/.compvar-initialize

  local progcomp_read_count=0
  local _ble_builtin_read_hook='ble/complete/progcomp/.check-limits || { ble/bash/read "$@" < /dev/null; return 148; }'

  ble/function#push compopt 'ble/complete/progcomp/compopt "$@"'

  # WA (#D1807): A workaround for blocking scp/ssh
  ble/function#push ssh '
    local IFS=$_ble_term_IFS
    if [[ " ${FUNCNAME[*]} " == *" ble/complete/progcomp/.compgen "* ]]; then
      local -a args; args=("$@")
      ble/util/conditional-sync "exec ssh \"\${args[@]}\"" \
        '\''! ble/complete/check-cancel'\'' 128 progressive-weight:killall
    else
      ble/function#push/call-top "$@"
    fi'

  # WA (#D1834): Suppress invocation of "command_not_found_handle" in the
  #   completion functions
  ble/function#push command_not_found_handle

  builtin eval '"$comp_func" "$cmd" "$cur" "$prev"' < /dev/null >&"$_ble_util_fd_tui_stdout" 2>&"$_ble_util_fd_tui_stderr"; local ext=$?

  ble/function#pop command_not_found_handle
  ble/function#pop ssh
  ble/function#pop compopt

  [[ $ext == 124 ]] && progcomp_retry=1
  return 0
}

## @fn ble/complete/progcomp/parse-complete/.next
##   @var[out] optarg
##   @var[in,out] compdef
##   @var[in] rex
function ble/complete/progcomp/parse-complete/.next {
  if [[ $compdef =~ $rex ]]; then
    builtin eval "arg=$BASH_REMATCH"
    compdef=${compdef:${#BASH_REMATCH}}
    return 0
  elif [[ ${compdef%%' '*} ]]; then
    # He shouldn't have come here
    arg=${compdef%%' '*}
    compdef=${compdef#*' '}
    return 0
  else
    return 1
  fi
}
function ble/complete/progcomp/parse-complete/.optarg {
  optarg=
  if ((ic+1<${#arg})); then
    optarg=${arg:ic+1}
    ic=${#arg}
    return 0
  elif [[ $compdef =~ $rex ]]; then
    builtin eval "optarg=$BASH_REMATCH"
    compdef=${compdef:${#BASH_REMATCH}}
    return 0
  else
    return 2
  fi
}
## @fn ble/complete/progcomp/parse-complete compdef
##   @param[in] compdef
##   @var[in,out] comp_opts
##   @var[out] compoptions comp_prog comp_func flag_noquote
function ble/complete/progcomp/parse-complete {
  compoptions=()
  comp_prog=
  comp_func=
  flag_noquote=
  local compdef=${1#'complete '}

  local arg optarg rex='^([^][*?;&|[:blank:]<>()\`$"'\''{}#^!]|\\.|'\''[^'\'']*'\'')+[[:blank:]]+' # #D1709 safe (WA gawk 4.0.2)
  while ble/complete/progcomp/parse-complete/.next; do
    case $arg in
    (-*)
      local ic c
      for ((ic=1;ic<${#arg};ic++)); do
        c=${arg:ic:1}
        case $c in
        ([abcdefgjksuvE])
          # Note: workaround #D0714 #M0009 #D0870
          case $c in
          (c) flag_noquote=1 ;;
          (d) ((_ble_bash>=40300)) && flag_noquote=1 ;;
          (f) ((40000<=_ble_bash&&_ble_bash<40200)) && flag_noquote=1 ;;
          esac
          ble/array#push compoptions "-$c" ;;
        ([pr])
          ;; #Ignore (-p display -r delete)
        ([AGWXPS])
          # Note: workaround #D0714 #M0009 #D0870
          ble/complete/progcomp/parse-complete/.optarg || break 2
          if [[ $c == A ]]; then
            case $optarg in
            (command) flag_noquote=1 ;;
            (directory) ((_ble_bash>=40300)) && flag_noquote=1 ;;
            (file) ((40000<=_ble_bash&&_ble_bash<40200)) && flag_noquote=1 ;;
            esac
          fi
          ble/array#push compoptions "-$c" "$optarg" ;;
        (o)
          ble/complete/progcomp/parse-complete/.optarg || break 2
          comp_opts=${comp_opts//:"$optarg":/:}$optarg:
          ble/array#push compoptions "-$c" "$optarg" ;;
        (C)
          if ((_ble_bash<40000)); then
            # In bash-3.2 and below, -C is output last (unquoted)
            comp_prog=${compdef%' '}
            compdef=
          else
            # -C is quoted in bash-4.0 and later
            ble/complete/progcomp/parse-complete/.optarg || break 2
            comp_prog=$optarg
          fi
          ble/array#push compoptions "-$c" ble/complete/progcomp/.compgen-helper-prog ;;
        (F)
          # unquoted optarg (under bash-3.2, unquoted -C prog may follow)
          if ((_ble_bash<40000)) && [[ $compdef == *' -C '* ]]; then
            comp_prog=${compdef#*' -C '}
            comp_prog=${comp_prog%' '}
            ble/array#push compoptions '-C' ble/complete/progcomp/.compgen-helper-prog
            comp_func=${compdef%%' -C '*}
          else
            comp_func=${compdef%' '}
            ((_ble_bash>=50200)) && builtin eval "comp_func=($comp_func)"
          fi
          compdef=

          ble/array#push compoptions "-$c" ble/complete/progcomp/.compgen-helper-func ;;
        (*)
          # -D, -I, etc. just discard
        esac
      done ;;
    (*)
      ;; #ignore
    esac
  done
}

## @fn ble/complete/progcomp/.filter-and-split-compgen arr opts
##   filter/sort/uniq candidates
##
##   @param[out] arr
##     Array name to store the results.
##   @param[in,opt] opts
##     Colon-separated list to control the detailed behavior.
##
##     @opt workaround-for-git
##       Apply a workaround for git. This will trim a space appended at the end
##       of each word.
##
##     @opt array
##       When this is specified, the variable "compgen" is treated as an array
##       where each element corresponds to one completion candidate.
##       Otherwise, the variable "compgen" is treated as a scalar variable
##       where each line corresponds to one completion candidate.
##
##   @var[out] flag_mandb
##   @var[in] compgen
##   @var[in] COMPV compcmd comp_cword comp_words
##   @var[in] comp_opts
##
##     @opt ble/filter-by-prefix
##       Select only the completions starting with "$COMPV".  If nothing is
##       selected, use the original set of completions.
##
function ble/complete/progcomp/.filter-and-split-compgen {
  flag_mandb=

  # Load data from compgen
  local out nlfix=
  if [[ :$2: == *:array:* ]]; then
    ble/util/assign out 'ble/util/writearray --nlfix compgen; ble/util/put nlfix'
    if [[ $out == *$'\n\n'nlfix ]]; then
      out=${out%$'\n\n'nlfix}
    elif  [[ $out == nlfix ]]; then
      out=
    else
      nlfix=1
      out=${out%$'\n'nlfix}
    fi
  else
    out=$compgen
  fi
  [[ $out ]] || return 0

  #----------------------------------------------------------------------------
  # Prepare settings for filtering

  # rtrim (workaround-for-git)
  local -x c_rtrim=
  [[ :$2: == *:workaround-for-git:* ]] && c_rtrim=set

  # ble/filter-by-prefix
  # Filter only words starting with "$COMPV" using a regular expression. So there are no candidates
  # If so, list the words without filtering.
  #
  # 2019-02-03 Actually, with the current implementation, there may be no need to bother with filtering.
  # Previously, even if I passed -- "$COMPV" to compgen, it did not filter.
  # #D0245 cdd38598 in ble/complete/progcomp/.compgen-helper-func,
  # The cause seems to be that I forgot to pass the argument to "$comp_func".
  # This was fixed in 1929132b, but I feel like the filter was left in just in case.
  local -x c_rex_filter=
  if [[ $comp_opts == *:ble/filter-by-prefix:* ]]; then
    local ret; ble/string#escape-for-awk-regex "$COMPV"; c_rex_filter="^$ret"
  fi

  # sort
  local -x c_sort= c_nlfix_prefix=
  local awk=ble/bin/awk post_filter=''
  local -a sort_args=()
  if [[ $comp_opts != *:nosort:* ]]; then
    if ble/is-function ble/bin/gawk; then
      # When gawk is available, we can use the gawk extension "asort(items)" to
      # sort the items.
      c_sort=set
      awk=ble/bin/gawk
    elif [[ $_ble_bin_awk_type == gawk ]]; then
      # There seems to be systems where the command "awk" is gawk, but the
      # command "gawk" is not found.  In this case, "_ble_bin_awk_type" is
      # supposed to be "gawk" as long as the awk type is correctly detected,
      # and we can use "asort(items)" with ble/bin/awk.
      c_sort=set
    elif ((nlfix)); then
      # When we want to sort items that may contain newlines, we utilize the
      # nlfix representation to sort the items.  We first prefix "1:", "2:",
      # and "3:" to items without newlines, items with newlines, and the nlfix
      # footer, respectively.  We then sort the items with and without newlines
      # separetely and finally remove the prefix.
      c_nlfix_sort=set
      post_filter=' | ble/bin/sort "${sort_args[@]}" | ble/bin/sed "s/^[1-3]://"'
    else
      # When items do not contain newlines, we can simply sort items using the
      # sort command.
      post_filter=' | ble/bin/sort "${sort_args[@]}"'
    fi
  fi

  # Prepare mandb
  local -x c_mandb=
  local -a args_mandb=()
  if [[ $comp_cword -gt 0 && $COMPV != [!-]* ]]; then
    # Expand the command name.  We first try to use the external variable
    # compcmd, which is supposed contain the expanded command name.  However,
    # when the variable "compcmd" contains a special value, we try to expand
    # the first word in-place.
    local cmd=$compcmd
    if [[ $cmd == _DefaultCmD_ || $cmd == _InitialWorD_ || $cmd == -[DI] ]]; then
      cmd=${comp_words[0]}
      local ret
      ble/syntax:bash/simple-word/safe-eval "$cmd" nonull && cmd=$ret
    fi

    # If the first word is "git" and the first non-option word "SUBCMD"
    # exists before comp_cword, we try to get mandb associated with
    # "git-SUBCMD".
    local man_page=${cmd##*/}
    if [[ $man_page == git ]]; then
      local isubcmd
      for ((isubcmd=1;isubcmd<comp_cword;isubcmd++)); do
        local subcmd=${comp_words[isubcmd]} ret
        if ble/syntax:bash/simple-word/safe-eval "$subcmd"; then
          ((${#ret[@]})) || continue
          subcmd=$ret
        fi
        if [[ $subcmd != -* ]]; then
          man_page=git-$subcmd
          break
        fi
      done
    fi

    if local ret; ble/complete/mandb/generate-cache "$man_page"; then
      c_mandb=set
      args_mandb=(mode=mandb "$ret")
      sort_args=(-t "$_ble_term_FS" -k 1)
    fi
  fi

  #----------------------------------------------------------------------------
  # Filter script

  local fs=$_ble_term_FS
  local awk_script='
    '$_ble_bin_awk_libNLFIX'

    #--------------------------------------------------------------------------
    # mandb

    function mandb_register_entry(name, display, entry) {
      # If the completion generated by progcomp ends with = yet the suffix
      # specified by the entry is a space, we replace the suffix in the
      # entry.
      # Note: nawk in Solaris 2.11 does not allow regex to start with /=.
      if (display ~ /(=)$/ && match(entry, /^[^'$fs']*'$fs'[^'$fs']*'$fs' '$fs'/) > 0)
        entry = substr(entry, 1, RLENGTH - 2) "=" substr(entry, RLENGTH);

      if (name2index[name] != "") {
        # Remove duplicates after removing trailing /=$/.  If the new
        # "display" is longer, overwrite the existing one.
        if (length(display) <= length(name2display[name])) return;
        name2display[name] = display;
        mandb_entries[name2index[name]] = entry;
      } else {
        name2index[name] = mandb_count;
        name2display[name] = display;
        mandb_entries[mandb_count++] = entry;
      }
    }

    function mandb_process_items(items, n, _, i, items_count, item, name, entry, record, desc, option, optarg, suffix) {
      items_count = 0;
      mandb_count = 0;
      for (i = 1; i <= n; i++) {
        item = items[i];
        name = item;

        # Note: nawk in Solaris 2.11 does not allow regex to start with /=.
        sub(/(=)$/, "", name);
        if (mandb[name]) {
          mandb_register_entry(name, item, mandb[name]);
          continue;
        } else if (sub(/^--no-/, "--", name)) {
          # Synthesize description of "--no-OPTION"
          if ((entry = mandb[name]) || (entry = mandb[substr(name, 2)])) {
            split(entry, record, FS);
            if ((desc = record[4])) {
              desc = "\033[1mReverse[\033[m " desc " \033[;1m]\033[m";
              if (match(item, /['"$_ble_term_blank"']*[:=[]/)) {
                option = substr(item, 1, RSTART - 1);
                optarg = substr(item, RSTART);
                suffix = substr(item, RSTART, 1);
                if (suffix == "[") suffix = "";
              } else {
                option = item;
                optarg = "";
                suffix = " ";
              }
              mandb_register_entry(name, item, option FS optarg FS suffix FS desc);
              continue;
            }
          }
        }

        items[++items_count] = item;
      }
      for (i = 0; i < mandb_count; i++)
        items[++items_count] = mandb_entries[i];
      while (n > items_count)
        delete items[n--];
      return items_count;
    }

    #--------------------------------------------------------------------------
    # filters

    # uniq, remove empty
    function uniq_items(items, n, _, m, i, item, uniq) {
      m = 0;
      for (i = 1; i <= n; i++) {
        item = items[i];
        if (!uniq[item]++ && item != "")
          items[++m] = item;
      }
      while (n > m)
        delete items[n--];
      return m;
    }

    # filter by regex, restore if nothing matches
    function filter_items_by_regex(items, n, rex_filter, _, m, i, item) {
      m = 0;
      for (i = 1; i <= item_count; i++) {
        item = items[i];
        if (item ~ rex_filter)
          items[++m] = item;
      }
      if (m == 0) m = n;
      while (n > m)
        delete items[n--];
    }

    #--------------------------------------------------------------------------

    BEGIN {
      c_rex_filter = ENVIRON["c_rex_filter"];
      c_enable_filter = c_rex_filter != "";
      c_enable_rtrim = ENVIRON["c_rtrim"] != "";
      c_enable_sort = ENVIRON["c_sort"] != "";
      c_enable_nlfix_sort = ENVIRON["c_nlfix_sort"] != "";
      c_enable_mandb = ENVIRON["c_mandb"] != "";

      if (nlfix) nlfix_begin();
    }

    mode == "mandb" {
      name = $0
      sub(/'"$_ble_term_FS"'.*/, "", name);
      if (!mandb[name]) mandb[name] = $0;
      next;
    }

    { items[++item_count] = $0; }

    END {
      if (nlfix) {
        n = split(items[item_count], indices, " ");
        delete items[item_count--];
        for (i = 1; i <= n; i++) {
          j = indices[i] + 1;
          items[j] = nlfix_unescape(items[j]);
        }
      }

      # 1. uniq
      item_count = uniq_items(items, item_count);

      # 2. rtrim
      if (c_enable_rtrim) {
        for (i = 1; i <= item_count; i++)
          sub(/[[:blank:]]+$/, "", items[i]);
      }

      # 3. filter-by-prefix
      if (c_enable_filter) {
        item_count = filter_items_by_regex(items, item_count, c_rex_filter);
      }

      # 4. sort
      if (c_enable_sort) {
        # Note: if we directly write "asort(items);", it will cause compilation
        # error in some awk implementation that does not have asort. We instead
        # enable the call of "asort(items)" only when it is enabled.
        '${c_sort:+'asort(items);'}'
      }

      # 5. mandb
      has_mandb = 0;
      if (c_enable_mandb) {
        item_count = mandb_process_items(items, item_count);
        has_mandb = mandb_count != 0;
      }

      if (c_enable_nlfix_sort) {
        for (i = 1; i <= item_count; i++)
          if (items[i] !~ /\n/)
            nlfix_push("1:" items[i]);
        for (i = 1; i <= item_count; i++)
          if (items[i] ~ /\n/)
            nlfix_push("2:" items[i]);
        nlfix_put("3:");
        nlfix_end();
      } else if (nlfix) {
        for (i = 1; i <= item_count; i++)
          nlfix_push(items[i]);
        nlfix_end();
      } else {
        for (i = 1; i <= item_count; i++)
          print items[i];
      }

      if (has_mandb) exit 10;
    }
  '
  [[ $post_filter ]] && post_filter=$post_filter'; ble/util/setexit "${PIPESTATUS[0]}"'
  ble/util/assign out '"$awk" -F "$_ble_term_FS" -v nlfix="$nlfix" "$awk_script" "${args_mandb[@]}" mode=compgen - <<< "$out"'"$post_filter"
  (($?==10)) && flag_mandb=1

  if ((nlfix)); then
    ble/util/readarray --nlfix "$1" <<< "$out"
  else
    ble/string#split-lines "$1" "$out"
  fi
  return 0
} 2>/dev/null

function ble/complete/progcomp/patch:cobraV2/extract_activeHelp.patch {
  local cobra_version=$1
  if ((cobra_version<10500)); then
    local -a completions
    completions=("${out[@]}")
  fi

  local prefix=$cur
  [[ $comps_flags == *v* ]] && prefix=$COMPV
  local unprocessed has_desc=
  unprocessed=()
  local lines line cand desc
  for lines in "${out[@]}"; do
    ble/string#split-lines lines "$lines"
    for line in "${lines[@]}"; do
      if [[ $line == *$'\t'* ]]; then
        cand=${line%%$'\t'*}
        desc=${line#*$'\t'}
        [[ $cand == "$prefix"* ]] || continue
        ble/complete/cand/yield word "$cand" "$desc"
        has_desc=1
      elif [[ $line ]]; then
        ble/array#push unprocessed "$line"
      fi
    done
  done

  [[ $has_desc ]] && bleopt complete_menu_style=desc
  if ((${#unprocessed[@]})); then
    if ((cobra_version>=10500)); then
      completions=("${unprocessed[@]}")
    else
      out=("${unprocessed[@]}")
    fi
    ble/function#advice/do
  fi
}

function ble/complete/progcomp/patch:cobraV2/get_completion_results.advice {
  local -a orig_words
  orig_words=("${words[@]}")
  local -a words
  words=(ble/complete/progcomp/patch:cobraV2/get_completion_results.invoke "${orig_words[@]:1}")
  ble/function#advice/do
}
function ble/complete/progcomp/patch:cobraV2/get_completion_results.invoke {
  local -a invoke_args; invoke_args=("$@")
  ble/util/conditional-sync \
    "${orig_words[0]} \"\${invoke_args[@]}\"" \
    '! ble/complete/check-cancel' 128 progressive-weight:killall
}
## @fn ble/complete/progcomp/call-by-conditional-sync funcname
##   This modifies the function to process its task in a subshell using
##   ble/util/conditional-sync so that the processing can be canceled on the
##   user inputs.
##
##   @var[in] funcname
##     A function to call through ble/util/conditional-sync.  This function is
##     going to be run in subshell, so the change to the environment made by
##     the function becomes unavailable after the modification.
function ble/complete/progcomp/call-by-conditional-sync {
  ble/is-function "$1" || return 0
  ble/function#advice around "$1" '
    ble/util/conditional-sync \
      ble/function#advice/do \
      '\''! ble/complete/check-cancel'\'' 128 progressive-weight:killall'
}

## @fn ble/complete/progcomp/adjust-third-party-completions
##   This function sets up the workarounds for third-party plugins.
##   @var[in] comp_func comp_prog
##   @var[ref] comp_opts
function ble/complete/progcomp/adjust-third-party-completions {
  # WA: Workarounds for third-party plugins
  if [[ $comp_func ]]; then
    # fzf
    if [[ $comp_func == _fzf_* ]]; then
      ble-import -f contrib/integration/fzf-completion
    elif [[ $comp_func == _skim_* ]]; then
      ble-import -f contrib/integration/skim-completion
    fi

    # bash_completion
    if ble/is-function _comp_initialize || ble/is-function _quote_readline_by_ref; then
      ble-import -f contrib/integration/bash-completion
      ble/function#try ble/contrib/integration:bash-completion/adjust
    fi

    # cobra GenBashCompletionV2
    if [[ $comp_func == __start_* ]]; then
      local target=__${comp_func#__start_}_handle_completion_types
      if ble/is-function "$target"; then
        local cobra_version=
        if ble/is-function "__${comp_func#__start_}_extract_activeHelp"; then
          cobra_version=10500 # v1.5.0 (Release 2022-06-21)
        fi
        ble/function#advice around "$target" "ble/complete/progcomp/patch:cobraV2/extract_activeHelp.patch $cobra_version"
      fi

      # https://github.com/akinomyoga/ble.sh/issues/353#issuecomment-1813801048
      # Note: Some programs can be slow to generate completions for internet
      # access or another reason.  Since the go programs called by cobraV2
      # completions are supposed to be an independent executable file (without
      # being shell functions), we can safely call them inside a subshell for
      # ble/util/conditional-sync.
      local target=__${comp_func#__start_}_get_completion_results
      if ble/is-function "$target"; then
        ble/function#advice around "$target" ble/complete/progcomp/patch:cobraV2/get_completion_results.advice
      fi
    fi

    # conditional-sync for the dnf completion.
    # Note: The workaround for the latest version of the dnf completion
    # (comp_func=_do_dnf5_completion) is in contrib/integration/bash-completion
    # because it relies on bash-completion.
    [[ $comp_func == _dnf ]] &&
      ble/complete/progcomp/call-by-conditional-sync _dnf_commands_helper

    # WA for zoxide TAB
    if [[ $comp_func == _z || $comp_func == __zoxide_z_complete ]]; then
      ble-import -f contrib/integration/zoxide
      ble/function#try ble/contrib/integration:zoxide/adjust
    fi

    # WA for _complete_nix
    if [[ $comp_func == _complete_nix ]]; then
      ble-import -f integration/nix-completion
      ble/contrib/integration:nix-completion/adjust
    fi

    # https://github.com/akinomyoga/ble.sh/issues/292 (Android Debug Bridge)
    ble/function#suppress-stderr _adb 2>/dev/null

    # conditional-sync for docker and docker-compose
    [[ $comp_func == _docker ]] &&
      ble/complete/progcomp/call-by-conditional-sync __docker_q
    [[ $comp_func == _docker_compose ]] &&
      ble/complete/progcomp/call-by-conditional-sync __docker_compose_q
  fi
  if [[ $comp_prog ]]; then
    # aws
    if [[ $comp_prog == aws_completer ]]; then
      comp_opts=${comp_opts}ble/no-mark-directories:ble/prog-trim:
    fi
  fi
}

## @fn ble/complete/progcomp/.compgen opts
##
##   @param[in] opts
## A colon-separated list of options.
##
##     @opt default
## Use default completion settings (complete -D).
##     @opt empty
## Use the completion setting for empty command lines (complete -E).
##     @opt initial
## Use the first word (command name) completion setting (complete -I).
##
##   @param[in,opt] cmd
## Specifies the name used to search for program completion rules. If omitted
## ${comp_words[0]} is used. initial or default is specified for opts.
## Not used if
##
##   @var[out] comp_opts
##
##   @var[in] COMP1 COMP2 COMPV COMPS comp_type
## Standard variables of ble/complete/source.
##
##   @var[in] comp_words comp_line comp_point comp_cword
## Variables generated by ble/syntax:bash/extract-command.
##
## @var[in] and many other things
## @exit Returns 148 when there is input.
function ble/complete/progcomp/.compgen {
  local opts=$1

  local compcmd= is_special_completion=
  local -a alias_args=()
  case :$opts: in
  (*:default:*)
    if ((_ble_bash>=40100)); then
      is_special_completion=1
      compcmd='-D'
    else
      compcmd=_DefaultCmD_
    fi ;;
  (*:empty:*)
    if ((_ble_bash>=40100)); then
      is_special_completion=1
      compcmd='-E'
    else
      compcmd=_EmptycmD_
    fi ;;
  (*:initial:*)
    if ((_ble_bash>=50000)); then
      is_special_completion=1
      compcmd='-I'
    else
      compcmd=_InitialWorD_
    fi ;;
  (*)
    compcmd=${cmd:-${comp_words[0]}} ;;
  esac

  local compdef
  if [[ $is_special_completion ]]; then
    # -D, -E, and -I
    ble/util/assign compdef 'builtin complete -p "$compcmd" 2>/dev/null'
  elif ble/syntax:bash/simple-word/is-simple "$compcmd"; then
    # Assumptions already quoted by the caller
    ble/util/assign compdef "builtin complete -p -- $compcmd 2>/dev/null"
    local ret; ble/syntax:bash/simple-word/eval "$compcmd"; compcmd=$ret
  else
    ble/util/assign compdef 'builtin complete -p -- "$compcmd" 2>/dev/null'
  fi
  [[ $compdef ]] || return 1
  # strip -D, -E, -I, or $compcmd
  # Note (#D1579): bash-5.1 seems to output '' only for empty commands.
  # Note (#D2088): In bash-5.2, '...' is displayed when the command name contains special characters.
  # However, on the other hand, you can safely evaluate it with eval, so at this point you can change the command name to
  # There is no need to delete it.
  compdef=${compdef%"${compcmd:-''}"}
  compdef=${compdef%' '}' '

  local comp_prog comp_func compoptions flag_noquote
  ble/complete/progcomp/parse-complete "$compdef"
  local comp_opts_parsed=$comp_opts

  ble/complete/progcomp/adjust-third-party-completions

  ble/complete/check-cancel && return 148

  # Note: The completion function specified to -F may directly yield the blesh
  # completion items, so we need to record the original cand_count before
  # calling "builtin compgen".
  local old_cand_count=$cand_count

  # Note: The reason to ble/util/assign only compgen is to evaluate compgen in the original shell, not in the subshell.
  # This is necessary so that the loaded completion function can be used from the next time, such as when the completion function is loaded lazily.
  local compgen compgen_compv=$COMPV
  if [[ ! $flag_noquote && :$comp_opts: != *:noquote:* ]]; then
    local q="'" Q="'\''"
    compgen_compv="'${compgen_compv//$q/$Q}'"
  fi
  local progcomp_prefix= progcomp_retry=
  if ((_ble_bash>=50300)); then
    # WA #D1682: libvirt's completion for virsh automatically rewrites variables IFS and word.
    # If you leave it as is, it will fall out. Since there is no other choice, restore the contents of the variable with tmpenv
    # I'll do something.
    IFS=$IFS word= builtin compgen -V compgen "${compoptions[@]}" -- "$compgen_compv" 2>/dev/null
  else
    IFS=$IFS word= ble/util/assign compgen 'builtin compgen "${compoptions[@]}" -- "$compgen_compv" 2>/dev/null'
  fi

  # Note #D0534: complete -D If the completion function according to the completion specification returns 124, start again.
  # Perform completion from the beginning. Interpolate within the ble/complete/progcomp/.compgen-helper-func function
  # Check the exit status of the function and if it is 124
  # Set retry in progcomp_retry.
  # Note #D1760: Retry when 124 is returned even when other than complete -D.
  if [[ $progcomp_retry && ! $_ble_complete_retry_guard ]]; then
    local _ble_complete_retry_guard=1
    opts=:$opts:
    opts=${opts//:default:/:}
    ble/complete/progcomp/.compgen "$opts"
    return "$?"
  fi

  # When plusdirs is added dynamically, it is necessary to generate it separately.
  if [[ $comp_opts_parsed != *:plusdirs:* && $comp_opts == *:plusdirs:* ]]; then
    local compgen_plusdirs
    if ((_ble_bash>=50300)); then
      builtin compgen -V compgen_plusdirs -o plusdirs -- "$compgen_compv" 2>/dev/null
      ble/array#push compgen_plusdirs "${compgen_plusdirs[@]}"
    else
      ble/util/assign compgen_plusdirs 'builtin compgen -o plusdirs -- "$compgen_compv" 2>/dev/null'
      [[ $compgen_plusdirs ]] && compgen=$compgen$'\n'$compgen_plusdirs
    fi
  fi

  # If "builtin compgen" produces no results, return here.
  local has_compgen=
  if ((_ble_bash>=50300)); then
    ((${#compgen[@]})) && has_compgen=1
  else
    [[ $compgen ]] && has_compgen=1
  fi
  if [[ ! $has_compgen ]]; then
    # Note: The completion function may directly yield the blesh completions,
    # in which case we exit with status 0.
    ((cand_count>old_cand_count))
    return "$?"
  fi

  local filter_opts=
  ((_ble_bash>=50300)) && filter_opts=array

  # WA: There are some git completion functions that arbitrarily add space to the end and specify -o nospace.
  # It seems that the intention is to insert a space after the word, but
  # The spaces normally included in the candidates generated by compgen (e.g. compgen -f) are
  # Since this is an escape target during insertion, the trailing space will also be escaped.
  #
  # There is no other choice, so use sed to remove the [[:blank:]]+ at the end of each candidate.
  # This will cause a real problem in that you will not be able to insert file names that end with a space, but
  # It is wrong to create such strange completion functions.
  if [[ $comp_func == __git* && $comp_opts == *:nospace:* ]]; then
    filter_opts=$filter_opts:workaround-for-git
    if ((_ble_bash>=50300)); then
      # If all the candidates end with [[:blank:]], we remove "compopt -o
      # nospace".
      local tmp
      tmp=("${compgen[@]}")
      ble/array#remove-by-glob tmp '*[[:blank:]]'
      ((${#tmp[@]}==0)) && comp_opts=${comp_opts//:nospace:/:}
    else
      ble/string#match "$compgen" $'(^|\n|[^[:blank:]])(\n|$)' ||
        comp_opts=${comp_opts//:nospace:/:}
    fi
  fi
  ble/complete/progcomp/process-compgen-output "$compcmd" "$filter_opts" || return "$?"

  ((cand_count>old_cand_count))
}

## @fn ble/complete/progcomp/process-compgen-output compcmd opts
##   @param[in] opts
##     @opt workaround-for-git
##
##   @var[in] compgen
##   @var[in] COMPS COMPV comp_cword comp_words
##   @var[in] comp_opts
##
##   @var[in] progcomp_prefix
##     This variable is expected to be initialized by
##     "ble/complete/progcomp/.compvar-initialize" before calling the
##     completion function.
##
function ble/complete/progcomp/process-compgen-output {
  local compcmd=$1 filter_opts=$2

  local cands flag_mandb=
  ble/complete/progcomp/.filter-and-split-compgen cands "$filter_opts" # compgen (comp_opts, etc) -> cands, flag_mandb

  ble/complete/source/test-limit "${#cands[@]}" || return 1

  # determine COMP_PREFIX for filenames
  if [[ $comp_opts == *:filenames:* ]]; then
    if [[ $comp_opts == *:ble/syntax-raw:* ]]; then
      [[ $COMPS == */* ]] && COMP_PREFIX=${COMPS%/*}/
    else
      [[ $COMPV == */* ]] && COMP_PREFIX=${COMPV%/*}/
    fi
  fi

  local action=progcomp "${_ble_complete_yield_varnames[@]/%/=}" # WA #D1570 checked
  ble/complete/cand/yield.initialize "$action"
  if [[ $flag_mandb ]]; then
    local -a entries; entries=("${cands[@]}")
    cands=()
    local fs=$_ble_term_FS has_desc= icand=0 entry
    for entry in "${entries[@]}"; do
      ((cand_iloop++%bleopt_complete_polling_cycle==0)) && ble/complete/check-cancel && return 148
      if [[ $entry == -*"$fs"*"$fs"*"$fs"* ]]; then
        local cand=${entry%%"$fs"*}
        ble/complete/cand/yield mandb "$cand" "$entry"
        [[ $entry == *"$fs"*"$fs"*"$fs"?* ]] && has_desc=1
      else
        cands[icand++]=$progcomp_prefix$entry
      fi
    done
    [[ $has_desc ]] && bleopt complete_menu_style=desc
  else
    [[ $progcomp_prefix ]] &&
      ble/array#map-prefix cands "$progcomp_prefix"
  fi
  ble/complete/cand/yield.batch "$action" "$comp_opts"
}

## @fn ble/complete/progcomp/.compline-rewrite-command cmd [args...]
## In response to changing the command name due to alias expansion etc.,
## Replaces the command name to be completed with the specified one.
##
##   @var[in,out] comp_line comp_words comp_point comp_cword
##
function ble/complete/progcomp/.compline-rewrite-command {
  local ocmd=${comp_words[0]}
  [[ $1 != "$ocmd" ]] || (($#>=2)) || return 1
  local IFS=$_ble_term_IFS
  local ins="$*"
  if (($#==0)); then
    # Command removal (when expanded to empty with alias)
    local ret; ble/string#ltrim "${comp_line:${#ocmd}}"
    ((comp_point-=${#comp_line}-${#ret}))
    comp_line=$ret
  else
    comp_line=$ins${comp_line:${#ocmd}}
    ((comp_point-=${#ocmd}))
  fi
  ((comp_point<0&&(comp_point=0),comp_point+=${#ins}))
  comp_words=("$@" "${comp_words[@]:1}")
  ((comp_cword&&(comp_cword+=$#-1)))
}

function ble/complete/progcomp/.split-alias-words {
  local tail=$1
  local rex_redir='^'$_ble_syntax_bash_RexRedirect
  local rex_word='^'$_ble_syntax_bash_simple_rex_element'+'
  local rex_delim=$'^[\n;|&]'
  local rex_spaces=$'^[ \t]+'
  local rex_misc='^[<>()]+'

  local -a words=()
  while [[ $tail ]]; do
    if [[ $tail =~ $rex_redir && $tail != ['<>']'('* ]]; then
      ble/array#push words "$BASH_REMATCH"
      tail=${tail:${#BASH_REMATCH}}
    elif [[ $tail =~ $rex_word ]]; then
      local w=$BASH_REMATCH
      tail=${tail:${#w}}
      if [[ $tail && $tail != ["$_ble_term_IFS;|&<>()"]* ]]; then
        local s=${tail%%["$_ble_term_IFS"]*}
        tail=${tail:${#s}}
        w=$w$s
      fi
      ble/array#push words "$w"
    elif [[ $tail =~ $rex_delim ]]; then
      words=()
      tail=${tail:${#BASH_REMATCH}}
    elif [[ $tail =~ $rex_spaces ]]; then
      tail=${tail:${#BASH_REMATCH}}
    elif [[ $tail =~ $rex_misc ]]; then
      ble/array#push words "$BASH_REMATCH"
      tail=${tail:${#BASH_REMATCH}}
    else
      local w=${tail%%["$_ble_term_IFS"]*}
      ble/array#push words "$w"
      tail=${tail:${#w}}
    fi
  done

  # skip assignments/redirections
  local i=0 rex_assign='^[_a-zA-Z0-9]+(\['$_ble_syntax_bash_simple_rex_element'*\])?\+?='
  while ((i<${#words[@]})); do
   if [[ ${words[i]} =~ $rex_assign ]]; then
     ((i++))
   elif [[ ${words[i]} =~ $rex_redir && ${words[i]} != ['<>']'('* ]]; then
     ((i+=2))
   else
     break
   fi
  done

  ret=("${words[@]:i}")
}

## @fn ble/complete/progcomp/.try-load-completion cmd
## Call bash-completion's loader and check the lazy completion settings.
function ble/complete/progcomp/.try-load-completion {
  if ble/is-function _comp_load; then
    ble/function#push command_not_found_handle
    _comp_load -- "$1" < /dev/null &>/dev/null; local ext=$?
    ble/function#pop command_not_found_handle
  elif ble/is-function __load_completion; then
    ble/function#push command_not_found_handle
    __load_completion "$1" < /dev/null &>/dev/null; local ext=$?
    ble/function#pop command_not_found_handle
  else
    return 1
  fi
  ((ext==0)) || return "$ext"

  builtin complete -p -- "$1" &>/dev/null
}

## @fn ble/complete/progcomp cmd opts
## Search for a completion specification and call the corresponding completion function.
##   @var[in] comp_line comp_words comp_point comp_cword
function ble/complete/progcomp {
  local cmd=${1-${comp_words[0]}} opts=$2

  # copy compline variables
  local orig_comp_words orig_comp_cword=$comp_cword orig_comp_line=$comp_line orig_comp_point=$comp_point
  orig_comp_words=("${comp_words[@]}")
  local comp_words comp_cword=$comp_cword comp_line=$comp_line comp_point=$comp_point
  comp_words=("${orig_comp_words[@]}")
  [[ $cmd == "${orig_comp_words[0]}" ]] ||
    ble/complete/progcomp/.compline-rewrite-command "$cmd"

  local orig_qcmds_set=
  local -a orig_qcmds=()
  local -a alias_args=()
  [[ :$opts: == *:__recursive__:* ]] ||
    local alias_checked=' '
  while ((1)); do

    # @var cmd ... original command name
    # @var ucmd ... simple-word/eval command name
    # @var qcmds ... simple-word/eval x quote-word command
    local ret ucmd qcmds
    ucmd=$cmd qcmds=("$cmd")
    if ble/syntax:bash/simple-word/is-simple "$cmd"; then
      if ble/syntax:bash/simple-word/eval "$cmd" noglob &&
          [[ $ret != "$cmd" || ${#ret[@]} -ne 1 ]]; then

        ucmd=${ret[0]} qcmds=()
        local word
        for word in "${ret[@]}"; do
          ble/string#quote-word "$word" quote-empty
          ble/array#push qcmds "$ret"
        done
      else
        ble/string#quote-word "$cmd" quote-empty
        qcmds=("$ret")
      fi

      [[ $cmd == "${orig_comp_words[0]}" ]] &&
        orig_qcmds_set=1 orig_qcmds=("${qcmds[@]}")
    fi

    if ble/is-function ble/cmdinfo/complete:"$ucmd"; then
      ble/complete/progcomp/.compline-rewrite-command "${qcmds[@]}" "${alias_args[@]}"
      ble/cmdinfo/complete:"$ucmd" "$opts"
      return "$?"
    elif [[ $ucmd == */?* ]] && ble/is-function ble/cmdinfo/complete:"${ucmd##*/}"; then
      ble/string#quote-word "${ucmd##*/}"; qcmds[0]=$ret
      ble/complete/progcomp/.compline-rewrite-command "${qcmds[@]}" "${alias_args[@]}"
      ble/cmdinfo/complete:"${ucmd##*/}" "$opts"
      return "$?"
    elif builtin complete -p -- "$ucmd" &>/dev/null; then
      cmd=$ucmd
      ble/complete/progcomp/.compline-rewrite-command "${qcmds[@]}" "${alias_args[@]}"
      ble/complete/progcomp/.compgen "$opts"
      return "$?"
    elif [[ $ucmd == */?* ]] && builtin complete -p -- "${ucmd##*/}" &>/dev/null; then
      # Note (#D2125): Even when we find the completion settings through the
      # basename of the command path, we pass the full path to the completion
      # function since some completions seem to try to call the command name
      # (that is not supposed to be in PATH) to the completion function.
      cmd=${ucmd##*/}
      ble/string#quote-word "$ucmd"; qcmds[0]=$ret
      ble/complete/progcomp/.compline-rewrite-command "${qcmds[@]}" "${alias_args[@]}"
      ble/complete/progcomp/.compgen "$opts"
      return "$?"
    elif ble/complete/progcomp/.try-load-completion "${ucmd##*/}"; then
      cmd=${ucmd##*/}
      ble/string#quote-word "$ucmd"; qcmds[0]=$ret
      ble/complete/progcomp/.compline-rewrite-command "${qcmds[@]}" "${alias_args[@]}"
      ble/complete/progcomp/.compgen "$opts"
      return "$?"
    fi
    alias_checked=$alias_checked$cmd' '

    # break if progcomp_alias is valid
    ((_ble_bash<50000)) || shopt -q progcomp_alias || break

    local ret
    ble/alias#expand "$cmd"
    [[ $ret == "$cmd" ]] && break
    ble/complete/progcomp/.split-alias-words "$ret"
    if ((${#ret[@]}==0)); then
      # When the contents disappear due to alias expansion, repeat expansion using the next word as a command.
      ble/complete/progcomp/.compline-rewrite-command "${alias_args[@]}"
      if ((${#comp_words[@]})); then
        if ((comp_cword==0)); then
          ble/complete/source:command
        else
          ble/complete/progcomp "${comp_words[0]}" "__recursive__:$opts"
        fi
      fi
      return "$?"
    fi

    [[ $alias_checked != *" $ret "* ]] || break
    cmd=$ret
    ((${#ret[@]}>=2)) &&
      alias_args=("${ret[@]:1}" "${alias_args[@]}")
  done

  # Rebuilding comp_words
  comp_words=("${orig_comp_words[@]}")
  comp_cword=$orig_comp_cword
  comp_line=$orig_comp_line
  comp_point=$orig_comp_point
  [[ $orig_qcmds_set ]] &&
    ble/complete/progcomp/.compline-rewrite-command "${orig_qcmds[@]}"
  ble/complete/progcomp/.compgen "default:$opts"
}

#------------------------------------------------------------------------------
# mandb

# Set of characters allowed to appear in option names (excluding - and +)
# Exclude non-ASCII or symbols /[][()<>{}="'\''`]/
# Note: \ and / are escaped so that they can be used inside awk regular expressions.
# Note (#D2039): @ is used in cd -@
_ble_complete_option_chars='_!#$%&:;.,^~|\\?\/*a-zA-Z0-9@'

# action:mandb
#
#   DATA ... cmd FS menu_suffix FS insert_suffix FS desc
#
function ble/complete/action:mandb/initialize {
  ble/complete/action/quote-insert
}
function ble/complete/action:mandb/initialize.batch {
  ble/complete/action/quote-insert.batch newline
}
function ble/complete/action:mandb/complete {
  ble/complete/action/complete.close-quotation
  local fields
  ble/string#split fields "$_ble_term_FS" "$DATA"
  local tail=${fields[2]}
  [[ $tail == ' ' && $comps_flags == *x* ]] && tail=','
  ble/complete/action/complete.addtail "$tail"
}
function ble/complete/action:mandb/init-menu-item {
  local ret; ble/color/face2g argument_option; g=$ret

  local fields
  ble/string#split fields "$_ble_term_FS" "$DATA"
  suffix=${fields[1]}
}
function ble/complete/action:mandb/get-desc {
  local fields
  ble/string#split fields "$_ble_term_FS" "$DATA"
  desc=${fields[3]}
}

function ble/complete/mandb/load-mandb-conf {
  [[ -s $1 ]] || return 0
  local line words
  while ble/bash/read line || [[ $line ]]; do
    ble/string#split-words words "${line%%'#'*}"
    case ${words[0]} in
    (MANDATORY_MANPATH)
      [[ -d ${words[1]} ]] &&
        ble/array#push manpath_mandatory "${words[1]}" ;;
    (MANPATH_MAP)
      ble/dict#set manpath_map "${words[1]}" "${words[2]}" ;;
    esac
  done < "$1"
}

_ble_complete_mandb_default_manpath=()
function ble/complete/mandb/initialize-manpath {
  ((${#_ble_complete_mandb_default_manpath[@]})) && return 0
  local manpath
  MANPATH= ble/util/assign manpath 'manpath || ble/bin/man -w' 2>/dev/null
  ble/string#split manpath : "$manpath"
  if ((${#manpath[@]}==0)); then
    local -a manpath_mandatory=()
    builtin eval -- "${_ble_util_dict_declare//NAME/manpath_map}"
    ble/complete/mandb/load-mandb-conf /etc/man_db.conf
    ble/complete/mandb/load-mandb-conf ~/.manpath

    # default mandatory manpath
    if ((${#manpath_mandatory[@]}==0)); then
      local ret
      ble/complete/util/eval-pathname-expansion '~/*/share/man'
      ble/array#push manpath_mandatory "${ret[@]}"
      ble/complete/util/eval-pathname-expansion '~/@(opt|.opt)/*/share/man'
      ble/array#push manpath_mandatory "${ret[@]}"
      for ret in /usr/local/share/man /usr/local/man /usr/share/man; do
        [[ -d $ret ]] && ble/array#push manpath_mandatory "$ret"
      done
    fi

    builtin eval -- "${_ble_util_dict_declare//NAME/mark}"

    local paths path ret
    ble/string#split paths : "$PATH"
    for path in "${paths[@]}"; do
      [[ -d $path ]] || continue
      [[ $path == *?/ ]] && path=${path%/}
      if ble/dict#get manpath_map "$path"; then
        path=$ret
      else
        path=${path%/bin}/share/man
      fi
      if [[ -d $path ]] && ! ble/set#contains mark "$path"; then
        ble/set#add mark "$path"
        ble/array#push manpath "$path"
      fi
    done

    for path in "${manpath_mandatory[@]}"; do
      if [[ -d $path ]] && ! ble/set#contains mark "$path"; then
        ble/set#add mark "$path"
        ble/array#push manpath "$path"
      fi
    done
  fi
  _ble_complete_mandb_default_manpath=("${manpath[@]}")
}

function ble/complete/mandb/search-file/.extract-path {
  local command=$1
  [[ $_ble_complete_mandb_lang ]] &&
    local LC_ALL=$$_ble_complete_mandb_lang
  ble/util/assign path 'ble/bin/man -w "$command"' 2>/dev/null
}
ble/function#suppress-stderr ble/complete/mandb/search-file/.extract-path

function ble/complete/mandb/search-file/.check {
  local path=$1
  if [[ $path && -s $path ]]; then
    ret=$path
    return 0
  else
    return 1
  fi
}
## @fn ble/complete/mandb/search-file command
## Search for man page files corresponding to the specified command.
##   @var[out] ret
## Stores the path to the found file.
##   @exit
## Succeeds when the corresponding file is found.
function ble/complete/mandb/search-file {
  local command=$1

  local path
  ble/complete/mandb/search-file/.extract-path "$command"
  ble/complete/mandb/search-file/.check "$path" && return 0

  # Get manpaths
  ble/string#split ret : "$MANPATH"

  # Replace empty paths with the default manpaths
  ((${#ret[@]})) || ret=('')
  local -a manpath=()
  for path in "${ret[@]}"; do
    if [[ $path ]]; then
      ble/array#push manpath "$path"
    else
      # system manpath
      ble/complete/mandb/initialize-manpath
      ble/array#push manpath "${_ble_complete_mandb_default_manpath[@]}"
    fi
  done

  local path
  for path in "${manpath[@]}"; do
    [[ -d $path ]] || continue
    ble/complete/mandb/search-file/.check "$path/man1/$command.1" && return 0
    ble/complete/mandb/search-file/.check "$path/man1/$command.8" && return 0
    if ble/is-function ble/bin/gzip; then
      ble/complete/mandb/search-file/.check "$path/man1/$command.1.gz" && return 0
      ble/complete/mandb/search-file/.check "$path/man1/$command.8.gz" && return 0
    fi
    if ble/is-function ble/bin/bzcat; then
      ble/complete/mandb/search-file/.check "$path/man1/$command.1.bz" && return 0
      ble/complete/mandb/search-file/.check "$path/man1/$command.1.bz2" && return 0
      ble/complete/mandb/search-file/.check "$path/man1/$command.8.bz" && return 0
      ble/complete/mandb/search-file/.check "$path/man1/$command.8.bz2" && return 0
    fi
    if ble/is-function ble/bin/xzcat; then
      ble/complete/mandb/search-file/.check "$path/man1/$command.1.xz" && return 0
      ble/complete/mandb/search-file/.check "$path/man1/$command.8.xz" && return 0
    fi
    if ble/is-function ble/bin/lzcat; then
      ble/complete/mandb/search-file/.check "$path/man1/$command.1.lzma" && return 0
      ble/complete/mandb/search-file/.check "$path/man1/$command.8.lzma" && return 0
    fi
  done
  return 1
}

if ble/bin#freeze-utility-path preconv; then
  function ble/complete/mandb/.preconv { ble/bin/preconv; }
else
  # There is no preconv on macOS
  function ble/complete/mandb/.preconv {
    ble/bin/od -A n -t u1 -v | ble/bin/awk '
      BEGIN {
        ECHAR = 65533; # U+FFFD

        # Initialize table
        byte = 0;
        for (i = 0; byte < 128; byte++) { mtable[byte] = 0; vtable[byte] = i++; }
        for (i = 0; byte < 192; byte++) { mtable[byte] = 0; vtable[byte] = ECHAR; }
        for (i = 0; byte < 224; byte++) { mtable[byte] = 1; vtable[byte] = i++; }
        for (i = 0; byte < 240; byte++) { mtable[byte] = 2; vtable[byte] = i++; }
        for (i = 0; byte < 248; byte++) { mtable[byte] = 3; vtable[byte] = i++; }
        for (i = 0; byte < 252; byte++) { mtable[byte] = 4; vtable[byte] = i++; }
        for (i = 0; byte < 254; byte++) { mtable[byte] = 5; vtable[byte] = i++; }
        for (i = 0; byte < 256; byte++) { mtable[byte] = 0; vtable[byte] = ECHAR; }

        M = 0; C = 0;
      }
      function put_uchar(uchar) {
        if (uchar < 128)
          printf("%c", uchar);
        else
          printf("\\[u%04X]", uchar);
      }
      function process_byte(byte) {
        if (M) {
          if (128 <= byte && byte < 192) {
            C = C * 64 + byte % 64;
            if (--M == 0) put_uchar(C);
            return;
          } else {
            # while (M--) C *= 64; put_uchar(C);
            put_uchar(ECHAR);
            M = 0;
          }
        }

        M = mtable[byte];
        C = vtable[byte];
        if (M == 0) put_uchar(C);
      }
      { for (i = 1; i <= NF; i++) process_byte($i); }
    '
  }
fi

_ble_complete_mandb_lang=
if ble/is-function ble/bin/groff; then
  # ENCODING: UTF-8
  _ble_complete_mandb_convert_type=man
  function ble/complete/mandb/convert-mandoc {
    if [[ $_ble_util_locale_encoding == UTF-8 ]]; then
      ble/bin/groff -k -Tutf8 -man
    else
      ble/bin/groff -Tascii -man
    fi
  }

  # Note #D1551: Neither groff -k nor preconv exist by default on macOS (groff-1.19.2)
  if [[ $OSTYPE == darwin* ]] && ! ble/bin/groff -k -Tutf8 -man &>/dev/null <<< 'α'; then
    if ble/bin/groff -T utf8 -m man &>/dev/null <<< '\[u03B1]'; then
      function ble/complete/mandb/convert-mandoc {
        if [[ $_ble_util_locale_encoding == UTF-8 ]]; then
          ble/complete/mandb/.preconv | ble/bin/groff -T utf8 -m man
        else
          ble/bin/groff -T ascii -m man
        fi
      }
    else
      _ble_complete_mandb_lang=C
      function ble/complete/mandb/convert-mandoc {
        ble/bin/groff -T ascii -m man
      }
    fi
  fi
elif ble/is-function ble/bin/nroff; then
  _ble_complete_mandb_convert_type=man
  function ble/complete/mandb/convert-mandoc {
    if [[ $_ble_util_locale_encoding == UTF-8 ]]; then
      ble/bin/nroff -Tutf8 -man
    else
      ble/bin/nroff -Tascii -man
    fi
  }
elif ble/is-function ble/bin/mandoc; then
  # bsd
  _ble_complete_mandb_convert_type=mdoc
  function ble/complete/mandb/convert-mandoc {
    ble/bin/mandoc -mdoc
  }
fi

function ble/complete/mandb/.generate-cache-from-man {
  ble/is-function ble/bin/man &&
    ble/is-function ble/complete/mandb/convert-mandoc || return 1

  local command=$1
  local ret
  ble/complete/mandb/search-file "$command" || return 1
  local LC_ALL= LC_COLLATE=C 2>/dev/null
  local path=$ret
  case $ret in
  (*.gz)       ble/bin/gzip -cd "$path" ;;
  (*.bz|*.bz2) ble/bin/bzcat "$path" ;;
  (*.lzma)     ble/bin/lzcat "$path" ;;
  (*.xz)       ble/bin/xzcat "$path" ;;
  (*)          ble/bin/cat "$path" ;;
  esac | ble/bin/awk -v type="$_ble_complete_mandb_convert_type" '
    BEGIN {
      g_keys_count = 0;
      g_desc = "";
      if (type == "man") {
        print ".TH __ble_ignore__ 1 __ble_ignore__ __ble_ignore__";
        print ".ll 9999"
        topic_start = ".TP";
      }
      mode = "begin";

      fmt3_state = "";
      fmt5_state = "";
      fmt6_state = "";
    }
    function output_pair(key, desc) {
      print "";
      print "__ble_key__";
      if (topic_start != "") print topic_start;
      print key;
      print "";
      print "__ble_desc__";
      print "";
      print desc;
    }

    function all_flush(_, i) {
      stage_flush();
      fmt3_flush();
      fmt5_flush();
      fmt6_flush();
    }
    function all_reset() {
      g_keys_count = 0;
      g_desc = "";
      mode = "none";
      prev_line = "";
      fmt3_state = "";
      fmt5_state = "";
      fmt6_state = "";
    }

    # ".Dd" seems to be the include directive for macros?
    # ".Nm" (in mdoc) specifies the name of the target the man page describes
    mode == "begin" && /^\.(Dd|Nm)['"$_ble_term_blank"']/ {
      if (type == "man" && /^\.Dd['"$_ble_term_blank"']+\$Mdoc/) topic_start = "";
      print $0;
    }

    function stage_key(key) {
      g_keys[g_keys_count++] = key;
      g_desc = "";
    }
    function stage_desc(desc) {
      if (g_desc != "") g_desc = g_desc "\n";
      g_desc = g_desc desc;
    }
    function stage_flush() {
      if (g_keys_count == 0) return;

      for (i = 0; i < g_keys_count; i++)
        output_pair(g_keys[i], g_desc);
      g_keys_count = 0;
      g_desc = "";
      mode = "none";
    }

    # Comment: [.ig \n comments \n ..]
    /^\.ig/ { mode = "ignore"; next; }
    mode == "ignore" {
      if (/^\.\.['"$_ble_term_blank"']*/) mode = "none";
      next;
    }

    {
      sub(/['"$_ble_term_blank"']+$/, "");
      REQ = match($0, /^\.[_a-zA-Z0-9]+/) ? substr($0, 2, RLENGTH - 1) : "";
    }

    REQ ~ /^(S[Ss]|S[Hh]|Pp)$/ { all_flush(); next; }

    #--------------------------------------------------------------------------
    # Format #7: [key \n .RS ... \n desc \n .RE]
    # This is used by rg (riggrep).  The key appears in a plain context without
    # any starting marker. This switches to fmt5 after identifying the key.

    function fmt7_check_start() {
      # If the previous line is empty, this is not fmt7.
      if (prev_line == "") return 0;

      # If we are already in a non-trivial state of the option description in
      # other formats, we do not try to interpret it as fmt7.
      if (g_keys_count || mode !~ /^(begin|none)$/) return 0;
      if (fmt3_state != "") return 0;
      if (fmt5_state !~ /^$|^key$/) return 0;
      if (fmt6_state != "") return 0;

      fmt5_state = "desc";
      fmt5_key = prev_line;
      fmt5_desc = "";
      return 1;
    }

    REQ == "RS" && fmt7_check_start() { next; }

    #--------------------------------------------------------------------------
    # Format #5: [.PP \n key \n .RS \n desc \n .RE]
    # This format is used by "ping" and "git".

    REQ == "PP" {
      all_flush();
      fmt5_state = "key";
      fmt5_key = "";
      fmt5_desc = "";
      next;
    }

    fmt5_state {
      if (fmt5_state == "key") {
        if (/^\.RS([^_a-zA-Z0-9]|$)/)
          fmt5_state = "desc";
        else if (/^\.RE([^_a-zA-Z0-9]|$)/)
          fmt5_state = "";
        else
          fmt5_key = (fmt5_key ? fmt5_key "\n" : "") $0;
      } else if (fmt5_state == "desc") {
        if (/^\.RE([^_a-zA-Z0-9]|$)/) {
          fmt5_flush();
          all_reset();
        } else {
          fmt5_desc = (fmt5_desc ? fmt5_desc "\n" : "") $0;
        }
      }
    }

    function fmt5_flush(_, key, desc) {
      if (fmt5_state == "desc") {
        stage_key(fmt5_key);
        stage_desc(fmt5_desc);
        stage_flush();

      } else if (fmt5_state == "key" && fmt5_key ~ /^[^[:space:]][^\n]*(\n[[:space:]][[:space:]][^\n]*|\n[[:space:]]*)+$/) {
        # This is a special rule for the man page of "docker".  It doesn'\''t
        # have any separator or indentation instruction for the description of
        # options.  It manually inserts whitespaces to indent descriptions.
        key = fmt5_key;
        sub(/\n.*/, "", key);
        desc = substr(fmt5_key, length(key) + 1);
        stage_key(key);
        stage_desc(desc);
        stage_flush();

      }
      fmt5_state = "";
    }

    #--------------------------------------------------------------------------
    # Format #3: [.HP \n keys \n .IP \n desc]
    # GNU sed seems to use this format.
    # GNU coreutils mv seems to contain [.HP \n key      desc ] (for option "-b")
    # Once we find desc, we can switch to the normal processing of mode = "desc".

    REQ == "HP" {
      all_flush();
      fmt3_state = "key";
      fmt3_key_count = 0;
      fmt3_desc = "";
      next;
    }

    function fmt3_process(_, key) {
      if (REQ == "TP") { fmt3_switch(); return; }
      if (REQ == "PD") return;

      if (fmt3_state == "key") {
        if (REQ == "IP") { fmt3_state = "desc"; return; }
        if (match($0, /(	|    )['"$_ble_term_blank"']*/)) {
          fmt3_keys[fmt3_key_count++] = substr($0, 1, RSTART - 1);
          fmt3_desc = substr($0, RSTART + RLENGTH);
          fmt3_state = "desc";
        } else {
          fmt3_keys[fmt3_key_count++] = $0;
        }
      } else if (fmt3_state == "desc") {
        if (fmt3_desc != "") fmt3_desc = fmt3_desc "\n";
        fmt3_desc = fmt3_desc $0;
      }
    }
    function fmt3_switch(_, i) {
      if (fmt3_state == "desc" && fmt3_key_count > 0) {
        for (i = 0; i < fmt3_key_count; i++)
          stage_key(fmt3_keys[i]);
        stage_desc(fmt3_desc);
        mode = "desc"; # switch to normal "desc" processing
      }
      fmt3_state = "";
      fmt3_key_count = 0;
      fmt3_desc = "";
    }
    function fmt3_flush() {
      fmt3_switch();
      stage_flush();
    }

    fmt3_state { fmt3_process(); }

    #--------------------------------------------------------------------------
    # Format #4: [[.IP "key" 4 \n .IX Item "..."]+ \n .PD \n desc]
    # This format is used by "wget".

    /^\.IP['"$_ble_term_blank"']+".*"(['"$_ble_term_blank"']+[0-9]+)?$/ && fmt3_state != "key" {
      fmt6_init();
      fmt4_init();
      next;
    }

    function fmt4_init() {
      if (mode != "fmt4_desc")
        if (!(g_keys_count && g_desc == "")) all_flush();

      gsub(/^\.IP['"$_ble_term_blank"']+"|"(['"$_ble_term_blank"']+[0-9]+)?$/, "");
      stage_key($0);
      mode = "fmt4_desc";
    }
    mode == "fmt4_desc" {
      if ($0 == "") { all_flush(); mode = "none"; next; }

      # fish has a special format of [.IP "\(bu" 2 \n keys desc]
      if (g_keys_count == 1 && g_keys[0] == "\\(bu" && match($0, /^\\fC[^\\]+\\fP( or \\fC[^\\]+\\fP)?/) > 0) {
        _key = substr($0, 1, RLENGTH);
        _desc = substr($0, RLENGTH + 1);
        if (match(_key, / or \\fC[^\\]+\\fP/) > 0)
          _key = substr(_key, 1, RSTART - 1) ", " substr(_key, RSTART + 4);
        g_keys[0] = _key;
        g_desc = _desc;
        next;
      }

      if (REQ == "PD") next;
      if (/^\.IX['"$_ble_term_blank"']+Item['"$_ble_term_blank"']+/) next;

      stage_desc($0);
    }

    #--------------------------------------------------------------------------
    # Format #6: [.IP "key" \n desc .IP]
    # This format is used by "rsync".

    function fmt6_init() {
      fmt6_flush();
      fmt6_state = "desc"
      fmt6_key = $0;
      fmt6_desc = "";
    }
    fmt6_state {
      if (REQ == "IX") {
        # Exclude fmt4 case
        fmt6_state = "";
      } else if (REQ == "IP") {
        fmt6_flush();
      } else {
        fmt6_desc = fmt6_desc $0 "\n";
      }
    }
    function fmt6_flush() {
      if (!fmt6_state) return;
      fmt6_state = "";
      if (fmt6_desc)
        output_pair(fmt6_key, fmt6_desc);
    }

    #--------------------------------------------------------------------------
    # Format #2: [.It Fl key \n desc] or [.It Fl Xo \n key \n .Xc desc]
    # This form was found in both "mdoc" and "man"
    /^\.It Fl([^_a-zA-Z0-9]|$)/ {
      if (g_keys_count && g_desc != "") all_flush();
      sub(/^\.It Fl/, ".Fl");
      if ($0 ~ / Xo$/) {
        g_current_key = $0;
        mode = "fmt2_keyc"
      } else {
        stage_key($0);
        mode = "desc";
      }
      next;
    }
    mode == "fmt2_keyc" {
      if (/^\.PD['"$_ble_term_blank"']*([0-9]+['"$_ble_term_blank"']*)?$/) next;
      g_current_key = g_current_key "\n" $0;
      if (REQ == "Xc") {
        stage_key(g_current_key);
        mode = "desc";
      }
      next;
    }
    #--------------------------------------------------------------------------
    # Format #1: [.TP \n key \n desc]
    # Format #1: [.TP \n key   desc \n desc...]
    # This is the typical format in "man".
    type == "man" && REQ == "TP" {
      if (g_keys_count && g_desc != "") all_flush();
      mode = "key1";
      next;
    }

    function fmt1_process_key(line, _, key, desc) {
      # In Japanese version of "man ls", key and desc is separated by multiple
      # spaces, where the number of spaces seem to vary from 5 to more than 10
      # spaces.
      if (match(line, /['"$_ble_term_blank"']['"$_ble_term_blank"']['"$_ble_term_blank"']/) > 0) {
        key = substr(line, 1, RSTART - 1)
        desc = substr(line, RSTART);
        sub(/^['"$_ble_term_blank"']+/, "", desc);

        stage_key(key);
        stage_desc(desc);
      } else {
        stage_key(line);
      }
      mode = "desc";
    }

    mode == "key1" {
      if (/^\.PD['"$_ble_term_blank"']*([0-9]+['"$_ble_term_blank"']*)?$/) next;
      fmt1_process_key($0);
      next;
    }
    mode == "desc" {
      if (REQ == "PD") next;
      stage_desc($0);
      next;
    }
    { prev_line = $0; }

    #--------------------------------------------------------------------------

    END { all_flush(); }
  ' | ble/complete/mandb/convert-mandoc 2>/dev/null | ble/bin/awk -F "$_ble_term_FS" '
    function flush_pair(_, i, desc, prev_opt) {
      if (g_option_count) {
        gsub(/\034/, "\x1b[7m^\\\x1b[27m", g_desc);
        sub(/(\.  |; ).*/, ".", g_desc); # Long descriptions are truncated.

        for (i = 0; i < g_option_count; i++) {
          desc = g_desc;

          # show a short option
          if (i > 0 && g_options[i] ~ /^--/) {
            prev_opt = g_options[i - 1];
            sub(/\034.*/, "", prev_opt);
            if (prev_opt ~ /^-[^-]$/)
              desc = "\033[1m[\033[0;36m" prev_opt "\033[0;1m]\033[m " desc;
          }

          print g_options[i] FS desc;
        }
      }
      g_option_count = 0;
      g_desc = "";
    }

    function process_key(line, _, n, specs, i, spec, option, optarg, suffix) {
      gsub(/^['"$_ble_term_blank"']+|['"$_ble_term_blank"']+$/, "", line);
      if (line == "") return;

      gsub(/\x1b\[[ -?]*[@-~]/, "", line); # CSI seq # disable=#D1440 LC_COLLATE_C is set
      gsub(/\x1b[ -\/]*[0-~]/, "", line);  # ESC seq # disable=#D1440 LC_COLLATE_C is set
      gsub(/\t/, "    ", line); # HT
      gsub(/.\x08/, "", line); # CHAR BS
      gsub(/\x0E/, "", line); # SO
      gsub(/\x0F/, "", line); # SI
      gsub(/[\x00-\x1F]/, "", line); # Give up all the other control chars
      gsub(/^['"$_ble_term_blank"']*|['"$_ble_term_blank"']*$/, "", line);
      gsub(/['"$_ble_term_blank"']+/, " ", line);
      if (line !~ /^[-+]./) return;

      n = split(line, specs, /,(['"$_ble_term_blank"']+|$)| or /);
      prev_optarg = "";
      for (i = n; i > 0; i--) {
        spec = specs[i];
        sub(/,['"$_ble_term_blank"']+$/, "", spec);

        # Exclude non-options.
        # Exclude FS (\034) because it is used for separators in the cache format.
        if (spec !~ /^[-+]/ || spec ~ /\034/) { specs[i] = ""; continue; }

        if (match(spec, /\[[:=]?|[:='"$_ble_term_blank"']/)) {
          option = substr(spec, 1, RSTART - 1);
          optarg = substr(spec, RSTART);
          suffix = substr(spec, RSTART + RLENGTH - 1, 1);
          if (suffix == "[") suffix = "";
          prev_optarg = optarg;
        } else {
          option = spec;
          optarg = "";
          suffix = " ";

          # Carry previous optarg
          if (prev_optarg ~ /[A-Z]|<.+>/) {
            optarg = prev_optarg;
            if (option ~ /^[-+].$/) {
              sub(/^\[=/, "[", optarg);
              sub(/^=/, "", optarg);
              sub(/^[^'"$_ble_term_blank"'[]/, " &", optarg);
            } else {
              if (optarg ~ /^\[[^:=]/)
                sub(/^\[/, "[=", optarg);
              else if (optarg ~ /^[^:='"$_ble_term_blank"'[]/)
                optarg = " " optarg;
            }

            if (match(optarg, /^\[[:=]?|^[:='"$_ble_term_blank"']/)) {
              suffix = substr(optarg, RSTART + RLENGTH - 1, 1);
              if (suffix == "[") suffix = "";
            }
          }
        }

        specs[i] = option FS optarg FS suffix;
      }

      for (i = 1; i <= n; i++) {
        if (specs[i] == "") continue;
        option = substr(specs[i], 1, index(specs[i], FS) - 1);
        if (!g_hash[option]++)
          g_options[g_option_count++] = specs[i];
      }
    }

    function process_desc(line) {
      gsub(/^['"$_ble_term_blank"']*|['"$_ble_term_blank"']*$/, "", line);
      if (line == "") {
        if (g_desc != "") return 0;
        return 1;
      }

      gsub(/['"$_ble_term_blank"']['"$_ble_term_blank"']+/, " ", line);
      if (g_desc != "") g_desc = g_desc " ";
      g_desc = g_desc line;
      return 1;
    }

    function process_string_fragment(str) {
      if (mode == "key") {
        process_key(str);
      } else if (mode == "desc") {
        if (!process_desc(str)) mode = "";
      }
    }

    function process_line(line, _, head, m0) {
      gsub(/‐|‑|⁃|−|﹣/, "-", line);
      while (match(line, /__ble_(key|desc)__/) > 0) {
        head = substr(line, 1, RSTART - 1);
        m0 = substr(line, RSTART, RLENGTH);
        line = substr(line, RSTART + RLENGTH);

        process_string_fragment(head);

        if (m0 == "__ble_key__") {
          flush_pair();
          mode = "key";
        } else {
          mode = "desc";
        }
      }

      process_string_fragment(line);
    }

    { process_line($0); }
    END { flush_pair(); }
  ' | ble/bin/sort -t "$_ble_term_FS" -k 1
  ble/util/unlocal LC_COLLATE LC_ALL 2>/dev/null
}

## @fn ble/complete/mandb:help/generate-cache [opts]
function ble/complete/mandb:help/generate-cache {
  local opts=$1
  local -x cfg_usage= cfg_help=1 cfg_plus= cfg_plus_generate=
  [[ :$opts: == *:mandb-help-usage:* ]] && cfg_usage=1
  [[ :$opts: == *:mandb-usage:* ]] && cfg_usage=1 cfg_help=
  ble/string#match ":$opts:" ':plus-options(=[^:]+)?:' &&
    cfg_plus=1 cfg_plus_generate=${BASH_REMATCH[1]:1}

  local space=$' \t' # for #D1709 (WA gawk 4.0.2)
  local rex_argsep='(\[?[:=]|  ?|\[)'
  local rex_option='[-+](,|[^]:='$space',[]+)('$rex_argsep'(<[^<>]+>|\([^()]+\)|\[[^][]+\]|[^-'"$_ble_term_blank"'、。][^'"$_ble_term_blank"'、。]*))?([,'"$_ble_term_blank"']|$)'
  local LC_ALL= LC_COLLATE=C 2>/dev/null
  ble/bin/awk -F "$_ble_term_FS" '
    BEGIN {
      cfg_help = ENVIRON["cfg_help"];
      g_help_indent = -1;
      g_help_score = -1; # score based on indent and the interval between the
                         # option and desc. smaller is better.
      g_help_keys_count = 0;
      g_help_desc = "";

      cfg_usage = ENVIRON["cfg_usage"];
      g_usage_count = 0;

      cfg_plus_generate = ENVIRON["cfg_plus_generate"];
      cfg_plus = ENVIRON["cfg_plus"] cfg_plus_generate;

      entries_init();
    }

    #--------------------------------------------------------------------------
    # entries

    function entries_init() {
      entries_count = 0;
    }

    function entries_register(entry, score, _, name, ientry) {
      name = entry;
      sub(/'"$_ble_term_FS"'.*$/, "", name);
      if (name ~ /^\+/ && !cfg_plus) return;

      if (entries_index[name] != "") {
        if (score >= entries_score[name]) return;
        ientry = entries_index[name];
      } else {
        ientry = entries_count++;
        entries_keys[ientry] = name;
      }

      entries_index[name] = ientry;
      entries_entry[name] = entry;
      entries_score[name] = score;
    }

    function entries_dump(_, ientry, name) {
      for (ientry = 0; ientry < entries_count; ientry++) {
        name = entries_keys[ientry];
        print entries_entry[name];
      }
    }

    #--------------------------------------------------------------------------
    # utils

    function str_convert_bs2ansi(str, _, head, n, a, c, flag_bold, flag_underline, i, prefix, suffix) {
      if (str !~ /\x08/) return str;

      head = "";
      while (match(str, /(.\x08)+./) > 0) {
        n = split(substr(str, RSTART, RLENGTH), a, "\x08");
        c = a[1];
        flag_bold = 0;
        flag_underline = 0;
        for (i = 2; i <= n; i++) {
          if (a[i] == "_") {
            if (c == "_" && !flag_bold)
              flag_bold = 1;
            else
              flag_underline = 1;
          } else {
            if (a[i] == c)
              flag_bold = 1;
            else {
              if (c == "_")
                flag_underline = 1;
              c = a[i];
            }
          }
        }
        if (flag_bold || flag_underline) {
          prefix = "";
          suffix = "";
          if (flag_bold) {
            prefix = "1";
            suffix = "22";
          }
          if (flag_underline) {
            prefix = prefix != "" ? prefix ";4" : "4";
            suffix = suffix != "" ? suffix ";24" : "24";
          }
          c = "\x1b[" prefix "m" c "\x1b[" suffix "m";
        }

        head = head substr(str, 1, RSTART - 1) c;
        str = substr(str, RSTART + RLENGTH);
      }
      return head str;
    }

    function split_option_optarg_suffix(optspec, _, key, suffix, optarg) {
      # Note: Skip options that contain FS (due to the limitation by the cache format)
      if (index(optspec, FS) != 0) return "";

      if ((pos = match(optspec, /'"$rex_argsep"'/)) > 0) {
        key = substr(optspec, 1, pos - 1);
        suffix = substr(optspec, pos + RLENGTH - 1, 1);
        if (suffix == "[") suffix = "";
        optarg = substr(optspec, pos);

        # Note (#D2244): Remove formatting like "_\x08A" and "A\x08A". "less
        # --help" contains such sequences.
        gsub(/.\x08/, "", optarg);
      } else {
        key = optspec;
        optarg = "";
        suffix = " ";
      }

      # Note: Exclude option names containing non-option characters
      if (key ~ /[^-+'"$_ble_complete_option_chars"']/) return "";

      return key FS optarg FS suffix;
    }

    {
      gsub(/\x1b\[[ -?]*[@-~]/, ""); # CSI seq # disable=#D1440 LC_COLLATE_C is set
      gsub(/\x1b[ -\/]*[0-~]/, "");  # ESC seq # disable=#D1440 LC_COLLATE_C is set
      gsub(/\t/, "    "); # HT
      gsub(/[\x00-\x1F]/, ""); # Remove all the other C0 chars
    }

    #--------------------------------------------------------------------------
    # Generate + options without descriptions

    function generate_plus(_, i, n) {
      if (!cfg_plus_generate) return;
      n = length(cfg_plus_generate);
      for (i = 1; i <= n; i++)
        entries_register("+" substr(cfg_plus_generate, i, 1) FS FS FS, 999);
    }

    #--------------------------------------------------------------------------
    # Extract usage [-DEI] [-f[helo] | --prefix=PATH]

    function usage_parse(line, _, optspec, optspec1, option, optarg, n, i, o) {
      while (match(line, /\[['"$_ble_term_blank"']*([^][]|\[[^][]*\])+['"$_ble_term_blank"']*\]/)) {
        optspec = substr(line, RSTART + 1, RLENGTH - 2);
        line = substr(line, RSTART + RLENGTH);

        # optspec: " -DEI | --prefix=PATH | ... ", etc.
        while (match(optspec, /([^][|]|\[[^][]*\])+/)) {
          optspec1 = substr(optspec, RSTART, RLENGTH);
          optspec = substr(optspec, RSTART + RLENGTH);
          gsub(/^['"$_ble_term_blank"']+|['"$_ble_term_blank"']+$/, "", optspec1);

          # optspec1: "--option optarg", "-f[optarg]", "-xzvf", etc.
          if (match(optspec1, /^[-+][^]:='"$space"'[]+/)) {
            option = substr(optspec1, RSTART, RLENGTH);
            optarg = substr(optspec1, RSTART + RLENGTH);
            n = RLENGTH;
            if (option ~ /^-.*-/) {
              if ((keyinfo = split_option_optarg_suffix(optspec1)) != "")
                g_usage[g_usage_count++] = keyinfo;
            } else {
              o = substr(option, 1, 1);
              for (i = 2; i <= n; i++)
                if ((keyinfo = split_option_optarg_suffix(o substr(option, i, 1) optarg)) != "")
                  g_usage[g_usage_count++] = keyinfo;
            }
          }
        }
      }
    }
    function usage_generate(_, i) {
      for (i = 0; i < g_usage_count; i++)
        entries_register(g_usage[i] FS, 999);
    }

    cfg_usage {
      if (NR <= 20 && (g_usage_start || $0 ~ /^[_a-zA-Z0-9]|^[^-'"$_ble_term_blank"'][^'"$_ble_term_blank"']*(: |：)/) ) {
        g_usage_start = 1;
        usage_parse($0);
      } else if (/^['"$_ble_term_blank"']*$/)
        cfg_usage = 0;
    }

    #--------------------------------------------------------------------------
    # Extract option descriptions

    function get_indent(text, _, i, n, ret) {
      ret = 0;
      n = length(text);
      for (i = 1; i <= n; i++) {
        c = substr(text, i, 1);
        if (c == " ")
          ret++;
        else if (c == "\t")
          ret = (int(ret / 8) + 1) * 8;
        else
          break;
      }
      return ret;
    }
    function help_flush(_, i, desc, prev_opt) {
      if (g_help_indent < 0) return;
      for (i = 0; i < g_help_keys_count; i++) {
        desc = g_help_desc;

        # show a short option
        if (i > 0 && g_help_keys[i] ~ /^--/) {
          prev_opt = g_help_keys[i - 1];
          sub(/\034.*/, "", prev_opt);
          if (prev_opt ~ /^-[^-]$/) {
            # Note: This particular form of desc is used by
            # ble/complete/mandb:bash-completion/_parse_help.advice.  When we
            # change the format, the function also needs to be updated.
            desc = "\033[1m[\033[0;36m" prev_opt "\033[0;1m]\033[m " desc;
          }
        }

        entries_register(g_help_keys[i] FS desc, g_help_score);
      }
      g_help_indent = -1;
      g_help_keys_count = 0;
      g_help_desc = "";
    }
    function help_start(keydef, _, key, keyinfo, keys, nkey, i, optarg) {
      if (g_help_desc != "") help_flush();
      g_help_indent = get_indent(keydef);
      g_help_score = g_help_indent;

      nkey = 0;
      for (;;) {
        sub(/^,?['"$_ble_term_blank"']+/, "", keydef);

        if (match(keydef, /^'"$rex_option"'/) <= 0) break;
        key = substr(keydef, 1, RLENGTH);
        keydef = substr(keydef, RLENGTH + 1);

        sub(/[,'"$_ble_term_blank"']$/, "", key);
        keys[nkey++] = key;
      }

      # Copy optarg "-A, --accept=LIST" => "-A LIST, --accept=LIST"
      if (nkey >= 2) {
        optarg = "";
        for (i = nkey; --i >= 0; ) {
          if (match(keys[i], /'"$rex_argsep"'/) > 0) {
            optarg = substr(keys[i], RSTART);
            sub(/^['"$_ble_term_blank"']+/, "", optarg);
            if (optarg !~ /[A-Z]|<.+>/) optarg = "";
          } else if (optarg != ""){
            if (keys[i] ~ /^[-+].$/) {
              optarg2 = optarg;
              sub(/^\[=/, "[", optarg2);
              sub(/^=/, "", optarg2);
              sub(/^[^'"$_ble_term_blank"'[]/, " &", optarg2);
              keys[i] = keys[i] optarg2;
            } else {
              optarg2 = optarg;
              if (optarg2 ~ /^\[[^:=]/)
                sub(/^\[/, "[=", optarg2);
              else if (optarg2 ~ /^[^:='"$_ble_term_blank"'[]/)
                optarg2 = " " optarg2;
              keys[i] = keys[i] optarg2;
            }
          }
        }
      }

      for (i = 0; i < nkey; i++)
        if ((keyinfo = split_option_optarg_suffix(keys[i])) != "")
          g_help_keys[g_help_keys_count++] = keyinfo;
    }
    function help_append_desc(desc) {
      gsub(/^['"$_ble_term_blank"']+|['"$_ble_term_blank"']$/, "", desc);
      if (desc == "") return;
      desc = str_convert_bs2ansi(desc);

      if (g_help_desc == "")
        g_help_desc = desc;
      else
        g_help_desc = g_help_desc " " desc;
    }

    # Note (#D1847): We here restrict the number of spaces between synonymous
    # options within 2 or 3.  Note that "rex_option" already contains the
    # trailing comma or space.
    cfg_help && match($0, /^['"$_ble_term_blank"']*'"$rex_option"'((['"$_ble_term_blank"']['"$_ble_term_blank"']?)?'"$rex_option"')*/) {
      key = substr($0, 1, RLENGTH);
      desc = substr($0, RLENGTH + 1);
      if (desc ~ /^,/) next;
      help_start(key);
      help_append_desc(desc);
      if (desc !~ /^['"$_ble_term_blank"']/) g_help_score += 100;
      next;
    }
    g_help_indent >= 0 {
      sub(/['"$_ble_term_blank"']+$/, "");
      indent = get_indent($0);
      if (indent <= g_help_indent)
        help_flush();
      else
        help_append_desc($0);
    }

    #--------------------------------------------------------------------------

    END {
      help_flush();
      usage_generate();
      generate_plus();
      entries_dump();
    }
  ' | ble/bin/sort -t "$_ble_term_FS" -k 1
  ble/util/unlocal LC_COLLATE LC_ALL 2>/dev/null
}

## @fn ble/complete/mandb/generate-cache cmdname [opts]
##   @param[in,opt] opts
##     @opt man=MAN_PAGE
##   @var[out] ret
## Returns the cache file name.
function ble/complete/mandb/generate-cache {
  local command=${1##*/} opts=${2-}
  [[ $command ]] || return 1
  local lc_messages=${LC_ALL:-${LC_MESSAGES:-${LANG:-C}}}
  local mandb_cache_dir=$_ble_base_cache/complete.mandb/${lc_messages//'/'/%}
  local fcache=$mandb_cache_dir/$command

  local cmdspec_opts; ble/cmdspec/opts#load "$command"
  [[ :$cmdspec_opts: == *:no-options:* ]] && return 1

  # fcache_help
  if ble/opts#extract-all-optargs "$cmdspec_opts" mandb-help --help; then
    local -a helpspecs; helpspecs=("${ret[@]}")
    local subcache=$mandb_cache_dir/help.d/$command
    if ! [[ -s $subcache && $subcache -nt $_ble_base/lib/core-complete.sh ]]; then
      ble/util/mkd "${subcache%/*}"
      local helpspec
      for helpspec in "${helpspecs[@]}"; do
        if [[ $helpspec == %* ]]; then
          builtin eval -- "${helpspec:1}"
        elif [[ $helpspec == @* ]]; then
          ble/util/print "${helpspec:1}"
        else
          ble/string#split-words helpspec "${helpspec#+}"
          "$command" "${helpspec[@]}" 2>&1
        fi
      done | ble/complete/mandb:help/generate-cache "$cmdspec_opts" >| "$subcache"
    fi
  fi

  # fcache_man
  if [[ :$cmdspec_opts: != *:mandb-disable-man:* ]] && {
       ble/opts#extract-last-optarg "$opts" bin
       local path=${ret:-"$1"}
       ble/bin#has "$path"; }; then
    local subcache=$mandb_cache_dir/man.d/$command
    if ! [[ -s $subcache && $subcache -nt $_ble_base/lib/core-complete.sh ]]; then
      ble/util/mkd "${subcache%/*}"
      ble/complete/mandb/.generate-cache-from-man "$command" >| "$subcache"
    fi
  fi

  # collect available caches
  local -a subcaches=()
  local subcache update=
  ble/complete/util/eval-pathname-expansion '"$mandb_cache_dir"/_parse_help.d/"$command".??????????????'
  for subcache in "${ret[@]}" "$mandb_cache_dir"/{help,man}.d/"$command"; do
    if [[ -s $subcache && $subcache -nt $_ble_base/lib/core-complete.sh ]]; then
      ble/array#push subcaches "$subcache"
      [[ $fcache -nt $subcache ]] || update=1
    fi
  done

  if [[ $update ]]; then
    local -x exclude=
    ble/opts#extract-last-optarg "$cmdspec_opts" mandb-exclude && exclude=$ret

    local fs=$_ble_term_FS
    ble/bin/awk -F "$_ble_term_FS" '
      BEGIN {
        plus_count = 0;
        nodesc_count = 0;
        exclude = ENVIRON["exclude"];
      }
      function emit(name, entry) {
        hash[name] = entry;
        if (exclude != "" && name ~ exclude) return;
        print entry;
      }

      $4 == "" {
        if ($1 ~ /^\+/) {
          plus_name[plus_count] = $1;
          plus_entry[plus_count] = $0;
          plus_count++;
        } else {
          nodesc_name[nodesc_count] = $1;
          nodesc_entry[nodesc_count] = $0;
          nodesc_count++;
        }
        next;
      }
      !hash[$1] { emit($1, $0); }

      END {
        # minus options
        for (i = 0; i < nodesc_count; i++)
          if (!hash[nodesc_name[i]])
            emit(nodesc_name[i], nodesc_entry[i]);

        # plus options
        for (i = 0; i < plus_count; i++) {
          name = plus_name[i];
          if (hash[name]) continue;

          split(plus_entry[i], record, FS);
          optarg = record[2];
          suffix = record[3];
          desc = "";

          mname = name;
          sub(/^\+/, "-", mname);
          if (hash[mname]) {
            if (!optarg) {
              split(hash[mname], record, FS);
              optarg = record[2];
              suffix = record[3];
            }

            desc = hash[mname];
            sub(/^[^'$fs']*'$fs'[^'$fs']*'$fs'[^'$fs']*'$fs'/, "", desc);
            if (desc) desc = "\033[1mReverse[\033[m " desc " \033[;1m]\033[m";
          }

          if (!desc) desc = "reverse of \033[4m" mname "\033[m";
          emit(name, name FS optarg FS suffix FS desc);
        }
      }
    ' "${subcaches[@]}" >| "$fcache"
  fi

  ret=$fcache
  [[ -s $fcache ]]
}
function ble/complete/mandb/load-cache {
  ret=()
  ble/complete/mandb/generate-cache "$@" &&
    ble/util/mapfile ret < "$ret"
}

## @fn ble/complete/source:option/.is-option-context args...
## args... contains an argument such as "--" that stops option interpretation.
## Determine if there are any.
##
##   @param[in] args...
##   @var[in] cmdspec_opts
##
function ble/complete/source:option/.is-option-context {
  #(($#)) || return 0

  local rexrej rexreq stopat
  ble/progcolor/stop-option#init "$cmdspec_opts"
  if [[ $stopat ]] && ((stopat<=$#)); then
    return 1
  elif [[ ! $rexrej$rexreq ]]; then
    return 0
  fi

  local word ret
  for word; do
    ble/syntax:bash/simple-word/safe-eval "$word" noglob &&
      ble/progcolor/stop-option#test "$ret" &&
      return 1
  done
  return 0
}

## @fn ble/complete/source:option [opts]
##   @param[in,opt] opts
##     @opt empty
##       Generate option names even when the current word is empty.  By
##       default, the generation of the options is enabled only when the
##       current word starts with - or +.
##     @opt reuse-comp_words
##       When this option is specified, use the externally-specified variables
##       "comp_words", "comp_line", "comp_point", and "comp_cword" instead of
##       extracting them by the syntax analysis on the current point.  This is
##       used when the target command is intentionally different from the shell
##       syntax, such as the case of "sudo command ...".
function ble/complete/source:option {
  local opts=$1
  if [[ :$opts: == *:empty:* ]]; then
    # Explicitly perform completion for empty strings
    [[ ! $COMPV ]] || return 0
  else
    # Candidates are generated only when /^[-+].*/ (the first /^[-+]/ is not filled in with ambiguous completion)
    local rex='^-[-+'$_ble_complete_option_chars']*$|^\+[_'$_ble_complete_option_chars']*$'
    [[ $COMPV =~ $rex ]] || return 0
  fi

  local COMPS=$COMPS COMPV=$COMPV
  ble/complete/source/reduce-compv-for-ambiguous-match
  [[ :$comp_type: == *:[maA]:* ]] && local COMP2=$COMP1

  if [[ :$opts: != *:reuse-comp_words:* ]]; then
    local comp_words comp_line comp_point comp_cword
    ble/syntax:bash/extract-command "$COMP2" || return 1
  fi

  ble/complete/source:option/generate-for-command "${comp_words[@]::comp_cword}"
}

## @fn ble/complete/source:option/generate-for-command command prev_args...
##   This function generates the option names based on man pages.
##
##   @param[in] command
##     The command name
##   @param[in] prev_args
##     The previous arguments before the word we currently try to complete.
##
##   For example, when one would like to generate the option
##   candidates for "cmd abc def ghi -xx[TAB]", command is "cmd", and
##   prev_args are "abc" "def" "ghi".
##
##   @var[in] COMP1 COMP2 COMPV COMPS comp_type
##     These variables carry the information on the completion
##     context. [COMP1, COMP2] specifies the range of the complete
##     target in the command-line text. COMPS is the word to
##     complete. COMPV is, if available, its current value after
##     evaluation. The variable "comp_type" contains additional flags
##     for the completion context.
##   @var[ref] cand_iloop
##
function ble/complete/source:option/generate-for-command {
  local cmd=$1 prev_args
  prev_args=("${@:2}")

  local alias_checked=' '
  while
    local ret cmdv=$cmd
    ble/syntax:bash/simple-word/safe-eval "$cmd" nonull && cmdv=$ret
    ! ble/complete/mandb/load-cache "$cmdv"
  do
    alias_checked=$alias_checked$cmd' '
    ble/alias#expand "$cmd" || return 1
    local words; ble/string#split-words ret "$ret"; words=("${ret[@]}")

    # Skip variable assignments
    local iword=0 rex='^[_a-zA-Z][_a-zA-Z0-9]*\+?='
    while [[ ${words[iword]} =~ $rex ]]; do ((iword++)); done
    [[ ${words[iword]} && $alias_checked != *" ${words[iword]} "* ]] || return 1
    prev_args=("${words[@]:iword+1}" "${prev_args[@]}")
    cmd=${words[iword]}
  done
  local -a entries; entries=("${ret[@]}")

  # If the main command name is git, try to load the man page corresponding to
  # the subcommand.
  if [[ ${cmdv##*/} == git ]]; then
    local isubcmd
    for ((isubcmd=0;isubcmd<${#prev_args[@]};isubcmd++)); do
      local subcmd=${prev_args[isubcmd]}
      if ble/syntax:bash/simple-word/safe-eval "$subcmd"; then
        ((${#ret[@]}==0)) || continue
        subcmd=$ret
      fi
      if [[ $subcmd != -* ]] && ble/complete/mandb/load-cache "git-$subcmd"; then
        cmdv=git-$subcmd
        entries=("${ret[@]}")
        prev_args=("${prev_args[@]:isubcmd+1}")
        break
      fi
    done
  fi

  local cmdspec_opts=
  ble/cmdspec/opts#load "$cmdv"
  # Check for option disabling conditions such as "--" and non-optional arguments
  ble/complete/source:option/.is-option-context "${prev_args[@]}" || return 1

  local "${_ble_complete_yield_varnames[@]/%/=}" # WA #D1570 checked
  ble/complete/cand/yield.initialize mandb
  local entry fs=$_ble_term_FS has_desc=
  for entry in "${entries[@]}"; do
    ((cand_iloop++%bleopt_complete_polling_cycle==0)) &&
      ble/complete/check-cancel && return 148
    local CAND=${entry%%$fs*}
    [[ $CAND == "$COMPV"* ]] || continue
    ble/complete/cand/yield mandb "$CAND" "$entry"
    [[ $entry == *"$fs"*"$fs"*"$fs"?* ]] && has_desc=1
  done

  [[ $has_desc && :$opts: != *:empty:* ]] && bleopt complete_menu_style=desc
}

#------------------------------------------------------------------------------
# source:argument

## @fn ble/complete/source:argument/.generate-user-defined-completion opts
## Performs user-defined completion. ble/cmdinfo/complete:command name
## If a function is defined, use it.
## Otherwise, the program completion registered by complete is used.
##
##   @param[in] opts
## Specifies a colon-separated list of options.
##     @opt empty
## Indicates completion for an empty command line.
##     @opt initial
## Indicates completion of the first word (command name).
##   @var[in] COMP1 COMP2
##   @var[in] (variables set by ble/syntax/parse)
##
function ble/complete/source:argument/.generate-user-defined-completion {
  shopt -q progcomp || return 1
  [[ :$comp_type: == *:[maA]:* ]] && local COMP2=$COMP1

  local opts=$1

  local comp_words comp_line comp_point comp_cword
  if ! ble/syntax:bash/extract-command "$COMP2"; then
    # Note: The extraction of the command fails when the command word is empty,
    # yet we want to perform the programmable completions by "complete -E" and
    # "complete -I".  When the command extraction fails with a non-empty word,
    # we do not perform completion because the word is not a command.
    if [[ ! $COMPV && ( :$opts: == *:empty:* || :$opts: == *:initial:* ) ]]; then
      # Note: The completions with "complete -E" and "complete -I" are valid
      # even with the empty command line.  In this case, COMP_WORDS is an empty
      # array and COMP_CWORD becomes -1.
      comp_words=() comp_line= comp_point=0 comp_cword=-1
    else
      return 1
    fi
  fi

  # @var comp2_in_word cursor position in word
  # @var comp1_in_word In-word completion start point
  local forward_words=
  ((comp_cword>0)) && IFS=' ' builtin eval 'forward_words="${comp_words[*]::comp_cword} "'
  local comp2_in_word=$((comp_point-${#forward_words}))
  local comp1_in_word=$((comp2_in_word-(COMP2-COMP1)))

  # Split a word when the completion start point is in the middle of the word
  if ((comp1_in_word>0)); then
    local w=${comp_words[comp_cword]}
    comp_words=("${comp_words[@]::comp_cword}" "${w::comp1_in_word}" "${w:comp1_in_word}" "${comp_words[@]:comp_cword+1}")
    IFS=' ' builtin eval 'comp_line="${comp_words[*]}"'
    ((comp_cword++,comp_point++))
    ((comp2_in_word=COMP2-COMP1,comp1_in_word=0))
  fi

  # For ambiguous completion, reduce the content of the word #D1413
  if [[ $COMPV && :$comp_type: == *:[maA]:* ]]; then
    local oword=${comp_words[comp_cword]::comp2_in_word} ins
    local ins=; [[ :$comp_type: == *:a:* ]] && ins=${COMPV::1}

    # escape ins
    local ret comps_flags= comps_fixed= # referenced in ble/complete/string#escape-for-completion-context
    if [[ $oword ]]; then
      # Note: Actually, when using ambiguous completion, COMP2=$COMP1 is set,
      # Furthermore, since the word is divided by COMP1, it shouldn't fit here.
      local simple_flags simple_ibrace
      ble/syntax:bash/simple-word/reconstruct-incomplete-word "$oword" || return 1
      comps_flags=v$simple_flags
      ((${simple_ibrace%:*})) && comps_fixed=1
    fi
    ble/complete/string#escape-for-completion-context "$ins" c; ins=$ret
    ble/util/unlocal comps_flags comps_fixed

    # rewrite
    ((comp_point+=${#ins}))
    comp_words=("${comp_words[@]::comp_cword}" "$oword$ins" "${comp_words[@]:comp_cword+1}")
    IFS=' ' builtin eval 'comp_line="${comp_words[*]}"'
    ((comp2_in_word+=${#ins}))
  fi

  if [[ :$opts: == *:empty:* ]]; then
    ble/complete/progcomp/.compgen empty
  elif [[ :$opts: == *:initial:* ]]; then
    ble/complete/progcomp/.compgen initial
  else
    ble/complete/progcomp "${comp_words[0]}"
  fi
}

function ble/complete/source:argument/generate {
  local old_cand_count=$cand_count

  #----------------------------------------------------------------------------
  # 1. Attempt user-defined completion
  ble/complete/source:argument/.generate-user-defined-completion; local ext=$?
  ((ext==148||cand_count>old_cand_count)) && return "$ext"

  ble/complete/source:argument/fallback
}

## @fn ble/complete/source:argument/fallback
##   @param[in] opts
##     @opt reuse-comp_words
##   @var[in] comp_opts
##     @opt ble/default
##     @opt dirnames
##     @opt default
function ble/complete/source:argument/fallback {
  local opts=$1 old_cand_count=$cand_count

  # When no completions are generated, we attempt "ble/default" argument
  # completions in the following.  If "ble/default" completions are disabled,
  # we emulate Bash's behavior based on "-o default" and "-o dirnames".
  if [[ $comp_opts != *:ble/default:* ]]; then
    # Bash's default behavior for no matches
    if [[ $comp_opts == *:dirnames:* ]]; then
      ble/complete/source:dir; ext=$?
      ((ext==148||cand_count>old_cand_count)) && return "$ext"
    fi

    if [[ $comp_opts == *:default:* ]]; then
      ble/complete/source:file; ext=$?
      ((ext==148||cand_count>old_cand_count)) && return "$ext"
    fi

    # Note: In ble.sh, the completions corresponding to "-o bashdefault" are
    # performed before source:argument by different completion sources, so it
    # is always performed and cannot be turned off.

    return "$ext"
  fi

  #----------------------------------------------------------------------------
  # 2. Attempt built-in argument completion

  # "-option" complete options based on mandb
  local option_opts=
  [[ :$opts: == *:reuse-comp_words:* ]] &&
    option_opts=$option_opts:reuse-comp_words
  ble/complete/source:option "$option_opts"; local ext=$?
  ((ext==148)) && return "$ext"

  # When "-o dirnames" is specified, the directory names are first attempted,
  # and then the filenames are attempted only when no directory names match.
  # We do not check the option "-o default" for the filenames because we
  # consider the filename generation is anyway implied by "-o ble/default".
  local old_cand_count_dirnames=$cand_count
  if [[ $comp_opts == *:dirnames:* ]]; then
    ble/complete/source:dir; ext=$?
    ((ext==148)) && return "$ext"
  fi
  if ((cand_count==old_cand_count_dirnames)); then
    ble/complete/source:file; ext=$?
    ((ext==148)) && return "$ext"
  fi

  # Attempt to generate options for empty strings after filenames
  ble/complete/source:option "$option_opts:empty"; local ext=$?
  ((ext==148||cand_count>old_cand_count)) && return "$ext"

  #----------------------------------------------------------------------------
  # 3. Attempt rhs completion

  if local rex='^/?[-_a-zA-Z0-9.]+\+?[:=]|^-[^-/=:]'; [[ $COMPV =~ $rex ]]; then
    # For example, var=filename --option=filename /I:filename.
    local prefix=$BASH_REMATCH value=${COMPV:${#BASH_REMATCH}}
    local COMP_PREFIX=$prefix
    [[ :$comp_type: != *:[maA]:* && $value =~ ^.+/ ]] &&
      COMP_PREFIX=$prefix${BASH_REMATCH[0]}

    local ret cand "${_ble_complete_yield_varnames[@]/%/=}" # WA #D1570 checked
    ble/complete/source:file/generate "$value"; (($?==148)) && return 148
    ble/complete/source/test-limit "${#ret[@]}" || return 1
    ble/complete/cand/yield.initialize file_rhs
    for cand in "${ret[@]}"; do
      ((cand_iloop++%bleopt_complete_polling_cycle==0)) && ble/complete/check-cancel && return 148
      [[ -e $cand || -h $cand ]] || continue
      [[ $FIGNORE ]] && ! ble/complete/.fignore/filter "$cand" && continue
      ble/complete/cand/yield file_rhs "$prefix$cand" "$prefix"
    done
  fi

  ((cand_count>old_cand_count))
}

function ble/complete/source:argument {
  local comp_opts=:ble/default:

  # If expansion fails with failglob, add * and try to expand again.
  if [[ $comps_flags == *f* && $COMPS != *\* && :$comp_type: != *:[maA]:* ]]; then
    local ret simple_flags simple_ibrace
    ble/syntax:bash/simple-word/reconstruct-incomplete-word "$COMPS"
    ble/complete/source/eval-simple-word "$ret*" && ((${#ret[*]})) &&
      ble/complete/cand/yield-filenames file "${ret[@]}"
    (($?==148)) && return 148
  fi

  ble/complete/source:argument/generate
  local ext=$?
  ((ext==148)) && return 148
  [[ $comp_opts == *:ble/default:* ]] || return "$ext"

  ble/complete/source:sabbrev
}

# source:variable
# source:user
# source:hostname

function ble/complete/source/compgen {
  [[ $comps_flags == *v* ]] || return 1
  local COMPS=$COMPS COMPV=$COMPV
  ble/complete/source/reduce-compv-for-ambiguous-match

  local compgen_action=$1
  local action=$2
  local data=$3

  local q="'" Q="'\''"
  local compv_quoted="'${COMPV//$q/$Q}'"
  local arr
  ble/util/compgen arr -A "$compgen_action" -- "$compv_quoted"

  ble/complete/source/test-limit "${#arr[@]}" || return 1

  # If there is already an exact match, omit it to complete from an earlier starting point.
  [[ $1 != '=' && ${#arr[@]} == 1 && $arr == "$COMPV" ]] && return 0

  local cand "${_ble_complete_yield_varnames[@]/%/=}" # WA #D1570 checked
  ble/complete/cand/yield.initialize "$action"
  for cand in "${arr[@]}"; do
    ((cand_iloop++%bleopt_complete_polling_cycle==0)) && ble/complete/check-cancel && return 148
    ble/complete/cand/yield "$action" "$cand" "$data"
  done
}

function ble/complete/source:variable {
  local data=
  case $1 in
  ('=') data=assignment ;;
  ('b') data=braced ;;
  ('a') data=arithmetic ;;
  ('n') data=nosuffix ;;
  ('w'|*) data=word ;;
  esac
  ble/complete/source/compgen variable variable "$data"
}
function ble/complete/source:user {
  ble/complete/source/compgen user word
}
function ble/complete/source:hostname {
  ble/complete/source/compgen hostname word
}

#------------------------------------------------------------------------------
# context

## @fn  ble/complete/complete/determine-context-from-opts opts
##   @param[in] opts
##   @var[out] context
function ble/complete/complete/determine-context-from-opts {
  local opts=$1
  context=syntax
  if local ret; ble/opts#extract-last-optarg "$opts" context; then
    local rematch1=$ret
    if ble/is-function ble/complete/context:"$rematch1"/generate-sources; then
      context=$rematch1
    else
      ble/util/print "ble/widget/complete: unknown context '$rematch1'" >&2
    fi
  fi
}
## @fn ble/complete/context/filter-prefix-sources
##   @var[in] comp_text comp_index
##   @var[in,out] sources
function ble/complete/context/filter-prefix-sources {
  # Select only completion contexts that start before the current position
  local -a filtered_sources=()
  local src asrc
  for src in "${sources[@]}"; do
    ble/string#split-words asrc "$src"
    local comp1=${asrc[1]}
    ((comp1<comp_index)) &&
      ble/array#push filtered_sources "$src"
  done
  sources=("${filtered_sources[@]}")
  ((${#sources[@]}))
}
## @fn ble/complete/context/overwrite-sources source
##   @param[in] source
##   @var[in] comp_text comp_index
##   @var[in,out] comp_type
##   @var[in,out] sources
function ble/complete/context/overwrite-sources {
  local source_name=$1
  local -a new_sources=()
  local src asrc mark
  for src in "${sources[@]}"; do
    ble/string#split-words asrc "$src"
    [[ ${mark[asrc[1]]} ]] && continue
    ble/array#push new_sources "$source_name ${asrc[1]}"
    mark[asrc[1]]=1
  done
  ((${#new_sources[@]})) ||
    ble/array#push new_sources "$source_name $comp_index"
  sources=("${new_sources[@]}")
}

## @fn ble/complete/context:syntax/generate-sources comp_text comp_index
##   @var[in] comp_text comp_index
##   @var[out] sources
function ble/complete/context:syntax/generate-sources {
  ble/syntax/import
  ble-edit/content/update-syntax
  ble/cmdspec/initialize # load user configruation
  ble/syntax/completion-context/generate "$comp_text" "$comp_index"
  ((${#sources[@]}))
}
function ble/complete/context:filename/generate-sources {
  ble/complete/context:syntax/generate-sources || return "$?"
  ble/complete/context/overwrite-sources file
}
function ble/complete/context:command/generate-sources {
  ble/complete/context:syntax/generate-sources || return "$?"
  ble/complete/context/overwrite-sources command
}
function ble/complete/context:variable/generate-sources {
  ble/complete/context:syntax/generate-sources || return "$?"
  ble/complete/context/overwrite-sources variable
}
function ble/complete/context:username/generate-sources {
  ble/complete/context:syntax/generate-sources || return "$?"
  ble/complete/context/overwrite-sources user
}
function ble/complete/context:hostname/generate-sources {
  ble/complete/context:syntax/generate-sources || return "$?"
  ble/complete/context/overwrite-sources hostname
}

# Note: The behavior of the glob completion in Bash seems inconsistent or
# really complicated, so we simplify the behavior so that the user can predict
# the consequence.  In Bash, * is appended to the pattern when one of the
# following condition is met:
#
# * An argument to the readline bindable function is specified.
# * "glob-complete-word" is called inside the emacs editing mode.
# * "bash-vi-command" is attempted on a word that does not contain any glob
#   characters
#
# Note: Even though "glob-complete-word" appends '*', the bindable functions
# "glob-expand-word" and "glob-list-word" do not append '*' unles an argument
# is supplied.  This does not satisfy the command duration.
#
# In this implementation, we first attempt the pathname expansion without
# appending '*', and if it doesn't produce any words or only produces the
# original word, we attempt another pathname expansion by appending '*'.  When
# an argument is specified, we attempt the pathname expansion with suffix '*'
# from the beginning.
#
function ble/complete/context:glob/generate-sources {
  comp_type=$comp_type:raw
  ble/complete/context:syntax/generate-sources || return "$?"
  ble/complete/context/overwrite-sources glob
}
function ble/complete/source:glob {
  [[ $comps_flags == *v* ]] || return 1
  [[ :$comp_type: == *:[maA]:* ]] && return 1

  local ret pattern=$COMPV

  # We first attempt pathname expansion without appending '*'.
  local prefix_expansion=
  if [[ ${comp_edit_arg-} ]]; then
    # Note: When an edit arg is specified, we attempt the pathname expansion
    # with suffix '*' from the beginning.  This mimics Bash's behavior.
    prefix_expansion=1
  else
    ble/complete/source/eval-simple-word "$pattern"; (($?==148)) && return 148
    if ((!${#ret[@]})) && [[ $pattern != *'*' ]]; then
      prefix_expansion=1
    elif ((${#ret[@]}==1)) && [[ $ret == "$pattern" ]]; then
      prefix_expansion=1
    fi
  fi

  # We then attempt pathname expansion with suffix '*' if necessary.
  if [[ $prefix_expansion ]]; then
    ble/complete/source/eval-simple-word "$pattern*"; (($?==148)) && return 148
  fi

  local cand action=file "${_ble_complete_yield_varnames[@]/%/=}" # WA #D1570 checked
  ble/complete/cand/yield.initialize "$action"
  for cand in "${ret[@]}"; do
    ((cand_iloop++%bleopt_complete_polling_cycle==0)) && ble/complete/check-cancel && return 148
    ble/complete/cand/yield "$action" "$cand"
  done
}

function ble/complete/context:dynamic-history/generate-sources {
  comp_type=$comp_type:raw
  ble/complete/context:syntax/generate-sources || return "$?"
  ble/complete/context/overwrite-sources dynamic-history
}
function ble/complete/source:dynamic-history {
  [[ $comps_flags == *v* ]] || return 1
  [[ :$comp_type: == *:[maA]:* ]] && return 1
  [[ $COMPV ]] || return 1

  local wordbreaks; ble/complete/get-wordbreaks
  wordbreaks=${wordbreaks//$'\n'}

  local ret; ble/string#escape-for-extended-regex "$COMPV"
  local rex_needle='(^|['$wordbreaks'])'$ret'[^'$wordbreaks']+'
  local rex_wordbreaks='['$wordbreaks']'
  ble/util/assign-array ret 'HISTTIMEFORMAT= builtin history | ble/bin/grep -Eo "$rex_needle" | ble/bin/sed "s/^$rex_wordbreaks//" | ble/bin/sort -u'

  local cand action=literal-word "${_ble_complete_yield_varnames[@]/%/=}" # WA #D1570 checked
  ble/complete/cand/yield.initialize "$action"
  for cand in "${ret[@]}"; do
    ((cand_iloop++%bleopt_complete_polling_cycle==0)) && ble/complete/check-cancel && return 148
    ble/complete/cand/yield "$action" "$cand"
  done
}

# 
#==============================================================================
# Candidate generation

## @var[out] cand_count
## number of candidates
## @arr[out] cand_cand
## candidate string
## @arr[out] cand_word
## Insert string (~ escaped candidate string)
##
## @arr[out] cand_pack
## Completion candidate data is compiled into one array.
## When using elements, expand them into variables as shown below.
##
##     local "${_ble_complete_cand_varnames[@]/%/=}" # WA #D1570 checked
##     ble/complete/cand/unpack "${cand_pack[0]}"
##
## ACTION is stored at the beginning, so
## To reference only ACTION, do as follows.
##
##     local ACTION=${cand_pack[0]%%:*}
##

## @fn ble/complete/util/construct-ambiguous-regex text fixlen
## Generates a regular expression for fuzzy matching.
##   @param[in] text
##   @param[in,out] fixlen=1
##   @var[in] comp_type
##   @var[out] ret
function ble/complete/util/construct-ambiguous-regex {
  local text=$1 fixlen=${2:-1}
  local opt_icase=; [[ :$comp_type: == *:i:* ]] && opt_icase=1
  local -a buff=()
  local i=0 n=${#text} ch=
  for ((i=0;i<n;i++)); do
    ((i>=fixlen)) && ble/array#push buff '.*'
    ch=${text:i:1}
    if [[ $ch == [a-zA-Z] ]]; then
      if [[ $opt_icase ]]; then
        ble/string#toggle-case "$ch"
        ch=[$ch$ret]
      fi
    else
      ble/string#escape-for-extended-regex "$ch"; ch=$ret
    fi
    ble/array#push buff "$ch"
  done
  IFS= builtin eval 'ret="${buff[*]}"'
}
## @fn ble/complete/util/construct-glob-pattern text
## Generates a glob for partial matching.
function ble/complete/util/construct-glob-pattern {
  local text=$1
  if [[ :$comp_type: == *:i:* ]]; then
    local i n=${#text} c
    local -a buff=()
    for ((i=0;i<n;i++)); do
      c=${text:i:1}
      if [[ $c == [a-zA-Z] ]]; then
        ble/string#toggle-case "$c"
        c=[$c$ret]
      else
        ble/string#escape-for-bash-glob "$c"; c=$ret
      fi
      ble/array#push buff "$c"
    done
    IFS= builtin eval 'ret="${buff[*]}"'
  else
    ble/string#escape-for-bash-glob "$1"
  fi
}


function ble/complete/.fignore/prepare {
  comp_fignore=()
  local i=0 leaf tmp
  ble/string#split tmp ':' "$FIGNORE"
  for leaf in "${tmp[@]}"; do
    [[ $leaf ]] && comp_fignore[i++]="$leaf"
  done
}
function ble/complete/.fignore/filter {
  local pat
  for pat in "${comp_fignore[@]}"; do
    [[ $1 == *"$pat" ]] && return 1
  done
  return 0
}

## @fn ble/complete/candidates/.pick-nearest-sources
## Find a list of completion sources closest to the starting point.
##
##   @var[in] comp_index
##   @arr[in,out] remaining_sources
##   @arr[out]    nearest_sources
##   @var[out] COMP1 COMP2
## Complementary range
##   @var[out] COMPS
## Complement range command string (may include quotes)
##   @var[out] COMPV
## The actual string that the command string in the completion range means
##   @var[out] comps_flags comps_fixed
function ble/complete/candidates/.pick-nearest-sources {
  COMP1= COMP2=$comp_index
  nearest_sources=()

  local -a unused_sources=()
  local src asrc
  for src in "${remaining_sources[@]}"; do
    ble/string#split-words asrc "$src"
    if ((COMP1<asrc[1])); then
      COMP1=${asrc[1]}
      ble/array#push unused_sources "${nearest_sources[@]}"
      nearest_sources=("$src")
    elif ((COMP1==asrc[1])); then
      ble/array#push nearest_sources "$src"
    else
      ble/array#push unused_sources "$src"
    fi
  done
  remaining_sources=("${unused_sources[@]}")

  COMPS=${comp_text:COMP1:COMP2-COMP1}
  comps_flags=
  comps_fixed=('')

  if [[ ! $COMPS ]]; then
    comps_flags=${comps_flags}v COMPV=
  elif local ret simple_flags simple_ibrace; ble/syntax:bash/simple-word/reconstruct-incomplete-word "$COMPS"; then
    local reconstructed=$ret
    if [[ :$comp_type: == *:raw:* ]]; then
      # Store the value before expansion in COMPV. Fails if inside brace expansion
      if ((${simple_ibrace%:*})); then
        COMPV=
      else
        comps_flags=$comps_flags${simple_flags}v
        COMPV=$reconstructed
      fi
    elif
      if ble/complete/source/eval-simple-word "$reconstructed" && ((${#ret[@]})) || { (($?==148)) && return 148; }; then
        # Store expanded value in COMPV (default)
        COMPV=("${ret[@]}")
      elif ble/complete/source/eval-simple-word "$reconstructed*" && ((${#ret[@]})) || { (($?==148)) && return 148; }; then
        # When failglob fails but there is a possibility of a match if you continue typing
        COMPV=()
        local word suffix
        for word in "${ret[@]}"; do
          suffix=${word#$reconstructed}
          [[ $suffix != "$word" ]] &&
            ble/array#push COMPV "${word::${#word}-${#suffix}}"
        done
      else
        ble/util/setexit 1
      fi
    then
      comps_flags=$comps_flags${simple_flags}v

      if ((${simple_ibrace%:*})); then
        ble/complete/source/eval-simple-word "${reconstructed::${simple_ibrace#*:}}" single; (($?==148)) && return 148
        comps_fixed=${simple_ibrace%:*}:$ret
        comps_flags=${comps_flags}x
      fi

      local path spec i s
      ble/syntax:bash/simple-word/evaluate-path-spec "$reconstructed" '' noglob:fixlen="${simple_ibrace#*:}"
      for ((i=0;i<${#spec[@]};i++)); do
        s=${spec[i]}
        [[ $s == "$comps_fixed" || $s == "$reconstructed" ]] && continue
        ble/array#push comps_fixed "${#s}:${path[i]}"
      done
    else
      # Note: Come here when simple-word/eval fails due to failglob.
      COMPV=
      comps_flags=$comps_flags${simple_flags}f
    fi
    [[ $COMPS =~ $rex_raw_paramx ]] && comps_flags=${comps_flags}p

  else
    COMPV=
  fi
}

function ble/complete/candidates/clear {
  cand_count=0
  cand_cand=()
  cand_word=()
  cand_pack=()
}

## @fn ble/complete/candidates/filter-by-command command [start]
## Execute the specified command on the generated candidates (cand_*),
## Keep only successful candidates and remove others.
##   @param[in] command
##   @param[in,opt] start
##   @var[in,out] cand_count
##   @arr[in,out] cand_{prop,cand,word,show,data}
##   @exit
## Returns 148 when interrupted by user input.
function ble/complete/candidates/filter-by-command {
  local command=$1 start=${2:-0}
  # todo: Inefficient implementation that touches multiple arrays, but I'll think about it later
  local i j=$start
  local -a prop=() cand=() word=() show=() data=()
  for ((i=start;i<cand_count;i++)); do
    ((i%bleopt_complete_polling_cycle==0)) && ble/complete/check-cancel && return 148
    builtin eval -- "$command" || continue
    cand[j]=${cand_cand[i]}
    word[j]=${cand_word[i]}
    data[j]=${cand_pack[i]}
    ((j++))
  done
  cand_count=$j
  cand_cand=("${cand[@]}")
  cand_word=("${word[@]}")
  cand_pack=("${data[@]}")
}
## @fn ble/complete/candidates/.filter-by-regex rex_filter
## Only the generated candidates (cand_*) that match the specified regular expression are retained.
##   @param[in] rex_filter
##   @var[in,out] cand_count
##   @arr[in,out] cand_{prop,cand,word,show,data}
##   @exit
## Returns 148 when interrupted by user input.
function ble/complete/candidates/.filter-by-regex {
  local rex_filter=$1
  ble/complete/candidates/filter-by-command '[[ ${cand_cand[i]} =~ $rex_filter ]]'
}
function ble/complete/candidates/.filter-by-glob {
  local globpat=$1
  ble/complete/candidates/filter-by-command '[[ ${cand_cand[i]} == $globpat ]]'
}
function ble/complete/candidates/.filter-word-by-prefix {
  local prefix=$1
  ble/complete/candidates/filter-by-command '[[ ${cand_word[i]} == "$prefix"* ]]'
}

function ble/complete/candidates/.initialize-rex_raw_paramx {
  local element=$_ble_syntax_bash_simple_rex_element
  local open_dquot=$_ble_syntax_bash_simple_rex_open_dquot
  rex_raw_paramx='^('$element'*('$open_dquot')?)\$[_a-zA-Z][_a-zA-Z0-9]*$'
}

## Candidate filters are implemented through the following functions.
##
##   @fn ble/complete/candidates/filter:FILTER_TYPE/init compv
##   @fn ble/complete/candidates/filter:FILTER_TYPE/test cand
##     @var[in] comp_filter_type
##     @var[in,out] comp_filter_pattern
##
##   @fn ble/complete/candidates/filter:FILTER_TYPE/match needle text
##     @param[in] needle text
##
## Function ble/complete/candidates/filter:FILTER_TYPE/count-match-chars value
##     @var[in] COMPV
##
## When used, call it through the following function (match, count-match-chars are called directly).
##
##   @fn ble/complete/candidates/filter#init type compv
##   @fn ble/complete/candidates/filter#test value
##     @var[in,out] comp_filter_type
##     @var[in,out] comp_filter_pattern
##
function ble/complete/candidates/filter#init {
  comp_filter_type=$1
  comp_filter_pattern=
  ble/complete/candidates/filter:"$comp_filter_type"/init "$2"
}
function ble/complete/candidates/filter#test {
  ble/complete/candidates/filter:"$comp_filter_type"/test "$1"
}

function ble/complete/candidates/filter:none/init { ble/complete/candidates/filter:head/init "$@"; }
function ble/complete/candidates/filter:none/test { return 0; }
function ble/complete/candidates/filter:none/count-match-chars { ble/complete/candidates/filter:head/count-match-chars "$@"; }
function ble/complete/candidates/filter:none/match { ble/complete/candidates/filter:head/match "$@"; }

function ble/complete/candidates/filter:head/init {
  local ret; ble/complete/util/construct-glob-pattern "$1"
  comp_filter_pattern=$ret*
}
function ble/complete/candidates/filter:head/count-match-chars { # unused but for completeness
  local value=$1 compv=$COMPV
  if [[ :$comp_type: == *:i:* ]]; then
    ble/string#tolower "$value"; value=$ret
    ble/string#tolower "$compv"; compv=$ret
  fi

  if [[ $value == "$compv"* ]]; then
    ret=${#compv}
  elif [[ $compv == "$value"* ]]; then
    ret=${#value}
  else
    ret=0
  fi
}
function ble/complete/candidates/filter:head/test { [[ $1 == $comp_filter_pattern ]]; }

## @fn ble/complete/candidates/filter:head/match needle text
##   @arr[out] ret
function ble/complete/candidates/filter:head/match {
  local needle=$1 text=$2
  if [[ :$comp_type: == *:i:* ]]; then
    ble/string#tolower "$needle"; needle=$ret
    ble/string#tolower "$text"; text=$ret
  fi

  if [[ ! $needle || ! $text ]]; then
    ret=()
  elif [[ $text == "$needle"* ]]; then
    ret=(0 "${#needle}")
    return 0
  elif [[ $text == "${needle::${#text}}" ]]; then
    ret=(0 "${#text}")
    return 0
  else
    ret=()
    return 1
  fi
}

function ble/complete/candidates/filter:substr/init {
  local ret; ble/complete/util/construct-glob-pattern "$1"
  comp_filter_pattern=*$ret*
}
function ble/complete/candidates/filter:substr/count-match-chars {
  local value=$1 compv=$COMPV
  if [[ :$comp_type: == *:i:* ]]; then
    ble/string#tolower "$value"; value=$ret
    ble/string#tolower "$compv"; compv=$ret
  fi

  if [[ $value == *"$compv"* ]]; then
    ret=${#compv}
    return 0
  fi
  ble/complete/string#common-suffix-prefix "$value" "$compv"
  ret=${#ret}
}
function ble/complete/candidates/filter:substr/test { [[ $1 == $comp_filter_pattern ]]; }
function ble/complete/candidates/filter:substr/match {
  local needle=$1 text=$2
  if [[ :$comp_type: == *:i:* ]]; then
    ble/string#tolower "$needle"; needle=$ret
    ble/string#tolower "$text"; text=$ret
  fi

  if [[ ! $needle ]]; then
    ret=()
  elif [[ $text == *"$needle"* ]]; then
    text=${text%%"$needle"*}
    local beg=${#text}
    local end=$((beg+${#needle}))
    ret=("$beg" "$end")
  elif ble/complete/string#common-suffix-prefix "$text" "$needle"; ((${#ret})); then
    local end=${#text}
    local beg=$((end-${#ret}))
    ret=("$beg" "$end")
  else
    ret=()
  fi
}

function ble/complete/candidates/filter:hsubseq/.determine-fixlen {
  fixlen=${1:-1}
  if [[ $comps_fixed ]]; then
    local compv_fixed_part=${comps_fixed#*:}
    [[ $compv_fixed_part ]] && fixlen=${#compv_fixed_part}
  fi
}
## @fn ble/complete/candidates/filter:hsubseq/init compv [fixlen]
##   @param[in] compv
##   @param[in,opt] fixlen
##   @var[in] comps_fixed
##   @var[out] comp_filter_pattern
function ble/complete/candidates/filter:hsubseq/init {
  local fixlen; ble/complete/candidates/filter:hsubseq/.determine-fixlen "$2"
  local ret; ble/complete/util/construct-ambiguous-regex "$1" "$fixlen"
  comp_filter_pattern=^$ret
}
## @fn ble/complete/candidates/filter:hsubseq/count-match-chars value [fixlen]
## Returns how far in COMPV the specified string matches.
##   @var[out] ret
function ble/complete/candidates/filter:hsubseq/count-match-chars {
  local value=$1 compv=$COMPV
  if [[ :$comp_type: == *:i:* ]]; then
    ble/string#tolower "$value"; value=$ret
    ble/string#tolower "$compv"; compv=$ret
  fi

  local fixlen
  ble/complete/candidates/filter:hsubseq/.determine-fixlen "$2"
  [[ $value == "${compv::fixlen}"* ]] || return 1

  value=${value:fixlen}
  local i n=${#COMPV}
  for ((i=fixlen;i<n;i++)); do
    local a=${value%%"${compv:i:1}"*}
    [[ $a == "$value" ]] && { ret=$i; return 0; }
    value=${value:${#a}+1}
  done
  ret=$n
}
function ble/complete/candidates/filter:hsubseq/test { [[ $1 =~ $comp_filter_pattern ]]; }
function ble/complete/candidates/filter:hsubseq/match {
  local needle=$1 text=$2
  if [[ :$comp_type: == *:i:* ]]; then
    ble/string#tolower "$needle"; needle=$ret
    ble/string#tolower "$text"; text=$ret
  fi

  local fixlen; ble/complete/candidates/filter:hsubseq/.determine-fixlen "$3"

  local prefix=${needle::fixlen}
  if [[ $text != "$prefix"* ]]; then
    if [[ $text && $text == "${prefix::${#text}}" ]]; then
      ret=(0 "${#text}")
    else
      ret=()
    fi
    return 0
  fi

  local pN=${#text} iN=${#needle}
  local first=1
  ret=()
  while ((1)); do
    if [[ $first ]]; then
      first=
      local p0=0 p=${#prefix} i=${#prefix}
    else
      ((i<iN)) || return 0

      while ((p<pN)) && [[ ${text:p:1} != "${needle:i:1}" ]]; do
        ((p++))
      done
      ((p<pN)) || return 1
      p0=$p
    fi

    while ((i<iN&&p<pN)) && [[ ${text:p:1} == "${needle:i:1}" ]]; do
      ((p++,i++))
    done
    ((p0<p)) && ble/array#push ret "$p0" "$p"
  done
}

## @fn ble/complete/candidates/filter:subseq/init compv
##   @param[in] compv
##   @var[in] comps_fixed
##   @var[out] comp_filter_pattern
function ble/complete/candidates/filter:subseq/init {
  [[ $comps_fixed ]] && return 1
  ble/complete/candidates/filter:hsubseq/init "$1" 0
}
function ble/complete/candidates/filter:subseq/count-match-chars {
  ble/complete/candidates/filter:hsubseq/count-match-chars "$1" 0
}
function ble/complete/candidates/filter:subseq/test { [[ $1 =~ $comp_filter_pattern ]]; }
function ble/complete/candidates/filter:subseq/match {
  ble/complete/candidates/filter:hsubseq/match "$1" "$2" 0
}

function ble/complete/candidates/generate-with-filter {
  local filter_type=$1 opts=$2
  local -a remaining_sources nearest_sources
  remaining_sources=("${sources[@]}")

  local src asrc source
  while ((${#remaining_sources[@]})); do
    nearest_sources=()
    ble/complete/candidates/.pick-nearest-sources; (($?==148)) && return 148

    [[ ! $COMPV && :$opts: == *:no-empty:* ]] && continue
    local comp_filter_type
    local comp_filter_pattern
    ble/complete/candidates/filter#init "$filter_type" "$COMPV" || continue

    for src in "${nearest_sources[@]}"; do
      ble/string#split-words asrc "$src"
      ble/string#split source : "${asrc[0]}"

      local COMP_PREFIX= #Default value (referenced by yield-candidate)
      ble/complete/source:"${source[@]}"
      ble/complete/check-cancel && return 148
    done

    [[ $comps_fixed ]] &&
      ble/complete/candidates/.filter-word-by-prefix "${COMPS::${comps_fixed%%:*}}"
    ((cand_count)) && return 0
  done
  return 0
}

function ble/complete/candidates/comp_type#read-rl-variables {
  local _ble_local_rlvars; ble/util/rlvar#load
  ble/util/rlvar#test completion-ignore-case 0 && comp_type=${comp_type}:i
  ble/util/rlvar#test visible-stats 0 && comp_type=${comp_type}:vstat
  ble/util/rlvar#test mark-directories 1 && comp_type=${comp_type}:markdir
  ble/util/rlvar#test mark-symlinked-directories 1 && comp_type=${comp_type}:marksymdir
  ble/util/rlvar#test match-hidden-files 1 && comp_type=${comp_type}:match-hidden
  ble/util/rlvar#test menu-complete-display-prefix 0 && comp_type=${comp_type}:menu-show-prefix

  # color settings are always enabled
  comp_type=$comp_type${bleopt_complete_menu_color:+:menu-color}
  comp_type=$comp_type${bleopt_complete_menu_color_match:+:menu-color-match}
}

## @fn ble/complete/candidates/generate opts
##   @param[in] opts
##   @var[in] comp_text comp_index
##   @arr[in] sources
##   @var[out] COMP1 COMP2 COMPS COMPV
##   @var[out] comp_type comps_flags comps_fixed
##   @var[out] cand_count cand_cand cand_word cand_pack
##   @var[in,out] cand_limit_reached
function ble/complete/candidates/generate {
  local opts=$1

  if [[ :$comp_type: == *:auto:* ]]; then
    if [[ ! $COMPV && :$bleopt_complete_auto_complete_opts: == *:syntax-suppress-empty:* ]]; then
      return 0
    elif [[ :$bleopt_complete_auto_complete_opts: == *:syntax-suppress-ambiguous:* ]]; then
      local bleopt_complete_ambiguous=
    fi
  fi

  local flag_force_fignore=
  local flag_source_filter=
  local -a comp_fignore=()
  if [[ $FIGNORE ]]; then
    ble/complete/.fignore/prepare
    ((${#comp_fignore[@]})) && shopt -q force_fignore && flag_force_fignore=1
  fi

  local rex_raw_paramx
  ble/complete/candidates/.initialize-rex_raw_paramx
  ble/complete/candidates/comp_type#read-rl-variables

  local cand_iloop=0
  ble/complete/candidates/clear
  # #D1416 Filter:none is used because there are times when you want to complete with COMPS instead of COMPV, such as when using ~[TAB]
  ble/complete/candidates/generate-with-filter none "$opts" || return "$?"
  ((cand_count)) && return 0

  if [[ $bleopt_complete_ambiguous && $COMPV ]]; then
    local original_comp_type=$comp_type
    comp_type=${original_comp_type}:m
    ble/complete/candidates/generate-with-filter substr "$opts" || return "$?"
    ((cand_count)) && return 0
    comp_type=${original_comp_type}:a
    ble/complete/candidates/generate-with-filter hsubseq "$opts" || return "$?"
    ((cand_count)) && return 0
    comp_type=${original_comp_type}:A
    ble/complete/candidates/generate-with-filter subseq "$opts" || return "$?"
    ((cand_count)) && return 0
    comp_type=$original_comp_type
  fi

  return 0
}

## @fn ble/complete/candidates/determine-common-prefix/.apply-partial-comps
##   @var[in] COMPS
##   @var[in] comps_fixed
##   @var[in,out] common
function ble/complete/candidates/determine-common-prefix/.apply-partial-comps {
  local word0=$COMPS word1=$common fixed=
  if [[ $comps_fixed ]]; then
    local fixlen=${comps_fixed%%:*}
    fixed=${word0::fixlen}
    word0=${word0:fixlen}
    word1=${word1:fixlen}
  fi

  local ret spec path spec0 path0 spec1 path1
  ble/complete/source/evaluate-path-spec "$word0"; (($?==148)) && return 148; spec0=("${spec[@]}") path0=("${path[@]}")
  ble/complete/source/evaluate-path-spec "$word1"; (($?==148)) && return 148; spec1=("${spec[@]}") path1=("${path[@]}")
  local i=${#path1[@]}
  while ((i--)); do
    if ble/array#last-index path0 "${path1[i]}"; then
      local elem=${spec1[i]} # workaround bash-3.1 ${#arr[i]} bug
      word1=${spec0[ret]}${word1:${#elem}}
      break
    fi
  done
  common=$fixed$word1
}

# Note (#D1978): In case of single determination by progcomp (syntax-raw), it is rewritten retroactively.
# It does not attempt to restore parts of the original word, even if they are.
function ble/completion/candidates/determine-common-prefix/.is-progcomp-raw {
  ((cand_count==1)) && [[ ${cand_pack[0]} == progcomp:*:ble/syntax-raw:* ]] || return 0

  # Just to be sure, check that DATA really includes :ble/syntax-raw:
  local "${_ble_complete_cand_varnames[@]/%/=}" # WA #D1570 checked
  ble/complete/cand/unpack "${cand_pack[0]}"
  [[ $DATA == *:ble/syntax-raw:* ]]
}

## @fn ble/complete/candidates/determine-common-prefix
## Calculate common prefix based on cand_*.
##   @var[in] cand_*
##   @var[out] ret
function ble/complete/candidates/determine-common-prefix {
  # common part
  local common=${cand_word[0]}
  local clen=${#common}
  if ((cand_count>1)); then
    # set up ignore case
    local unset_nocasematch= flag_tolower=
    if [[ :$comp_type: == *:i:* ]]; then
      if ((_ble_bash<30100)); then
        flag_tolower=1
        ble/string#tolower "$common"; common=$ret
      else
        unset_nocasematch=1
        shopt -s nocasematch
      fi
    fi

    local word loop=0
    for word in "${cand_word[@]:1}"; do
      ((loop++%bleopt_complete_polling_cycle==0)) && ble/complete/check-cancel && break

      if [[ $flag_tolower ]]; then
        ble/string#tolower "$word"; word=$ret
      fi

      ((clen>${#word}&&(clen=${#word})))
      while [[ ${word::clen} != "${common::clen}" ]]; do
        ((clen--))
      done
      common=${common::clen}
    done

    [[ $unset_nocasematch ]] && shopt -u nocasematch
    ble/complete/check-cancel && return 148

    [[ $flag_tolower ]] && common=${cand_word[0]::${#common}}
  fi

  if [[ $common != "$COMPS"* && ! ( $cand_count -eq 1 && $comp_type == *:i:* ) ]]; then
    if ! ble/completion/candidates/determine-common-prefix/.is-progcomp-raw; then
      # Attempt to partially replace common with COMPS
      # Note: When using ignore-case, we want to match the case to the candidate, so we use COMPS.
      # is not replaced.
      ble/complete/candidates/determine-common-prefix/.apply-partial-comps
    fi
  fi

  if ((cand_count>1)) && [[ $common != "$COMPS"* ]]; then
    local common0=$common
    common=$COMPS #Cancel completion insertion for now

    if [[ :$comp_type: == *:[maAi]:* ]]; then
      # When there is a fuzzy match, rewriting can occur retroactively.
      # Replaces the matching parts and adds the unmatched parts to the end.

      local simple_flags simple_ibrace
      if ble/syntax:bash/simple-word/reconstruct-incomplete-word "$common0"; then
        local common_reconstructed=$ret
        local value=$ret filter_type=head
        case :$comp_type: in
        (*:m:*) filter_type=substr ;;
        (*:a:*) filter_type=hsubseq ;;
        (*:A:*) filter_type=subseq ;;
        esac

        local is_processed=
        ble/complete/source/eval-simple-word "$common_reconstructed" single; local ext=$?
        ((ext==148)) && return 148
        if ((ext==0)) && ble/complete/candidates/filter:"$filter_type"/count-match-chars "$ret"; then
          if [[ $filter_type == head ]] && ((ret<${#COMPV})); then
            is_processed=1
            # Note: #D1181 The reason you came here is from an external framework.
            # This means that there are candidates that are not matched at the beginning.
            # It seems that the user is aware of the risk of losing the input string, so rewriting is allowed.
            [[ $bleopt_complete_allow_reduction ]] && common=$common0
          elif ((ret)); then
            is_processed=1
            ble/string#escape-for-bash-specialchars "${COMPV:ret}" c
            common=$common0$ret
          fi
        fi

        # #D1417 Regarding things such as tilde expansion and path name expansion that result in completely different expansion if cut in the middle
        # In order to process it more correctly, we also check partial matches for notilde and noglob, although they are not complete solutions.
        #
        # For example, if you have already entered ~nouser and the common match is ~
        # When checking how much of ~ partially matches ~nouser, if tilde expansion is effective,
        # Since ~ is expanded to /home/user and then checked for partial matches,
        # No match occurs, and all of "~nouser" is additionally inserted, resulting in "~~nouser".
        # Therefore, it is necessary to disable tilde expansion and path name expansion and try partial matching.
        if [[ ! $is_processed ]] &&
             local notilde=\'\' &&
             ble/syntax:bash/simple-word/safe-eval "$notilde$COMPS" reconstruct:noglob &&
             local compv_notilde=$ret &&
             ble/syntax:bash/simple-word/eval "$notilde$common_reconstructed" noglob &&
             local commonv_notilde=$ret &&
             COMPV=$compv_notilde ble/complete/candidates/filter:"$filter_type"/count-match-chars "$commonv_notilde"
        then
          if [[ $filter_type == head ]] && ((ret<${#COMPV})); then
            is_processed=1
            [[ $bleopt_complete_allow_reduction ]] && common=$common0
          elif ((ret)); then
            # Note: In the current implementation, all *?[ included in the expansion result are treated as globs.
            # It is supposed to be handled as follows. In other words, when 'a*b' is an ambiguous match, originally
            # The quote is removed and becomes a*b. This is the current implementation
            # This is the limit.
            is_processed=1
            ble/string#escape-for-bash-specialchars "${compv_notilde:ret}" TG
            common=$common0$ret
          fi
        fi

        [[ $is_processed ]] || common=$common0$COMPS
      fi

    else
      # Note: #D0768 Allow retroactive rewriting to occur if it is grammatically simple (as long as it does not destroy the structure).
      # Note: #D1181 Allow rewriting even if the common part generated by an external framework does not match the beginning.
      if ble/syntax:bash/simple-word/is-simple-or-open-simple "$common"; then
        local flag_reduction=
        if [[ $bleopt_complete_allow_reduction ]]; then
          flag_reduction=1
        else
          local simple_flags simple_ibrace
          ble/syntax:bash/simple-word/reconstruct-incomplete-word "$common0" &&
            ble/complete/source/eval-simple-word "$ret" single &&
            [[ $ret == "$COMPV"* ]] &&
            flag_reduction=1
          (($?==148)) && return 148
        fi

        [[ $flag_reduction ]] && common=$common0
      fi
    fi
  fi

  ret=$common
}

# 
#==============================================================================
# List of candidates

_ble_complete_menu_active=
_ble_complete_menu_style=
_ble_complete_menu_opts=
_ble_complete_menu0_beg=
_ble_complete_menu0_end=
_ble_complete_menu0_str=
_ble_complete_menu_common_part=
_ble_complete_menu0_comp=()
_ble_complete_menu0_pack=()
_ble_complete_menu_comp=()

## @fn ble/complete/menu-complete.class/render-item pack opts
##   @param[in] pack
## A string in the same format as the cand_pack elements.
##   @param[in] opts
## Colon-separated options.
##     selected
## Generates a drawing sequence for the selected candidate.
##   @var[in,out] x y
##   @var[out] ret
##   @var[in] cols lines
##   @var[in] _ble_complete_menu_common_part
function ble/complete/menu-complete.class/render-item {
  local opts=$2

  # Note: select is not in the context of displaying a menu, so
  # It cannot be referenced unless the completion context is restored.
  if [[ :$opts: == *:selected:* ]]; then
    local COMP1=${_ble_complete_menu_comp[0]}
    local COMP2=${_ble_complete_menu_comp[1]}
    local COMPS=${_ble_complete_menu_comp[2]}
    local COMPV=${_ble_complete_menu_comp[3]}
    local comp_type=${_ble_complete_menu_comp[4]}
    local comps_flags=${_ble_complete_menu0_comp[5]}
    local comps_fixed=${_ble_complete_menu0_comp[6]}
    local menu_common_part=$_ble_complete_menu_common_part
  fi

  local "${_ble_complete_cand_varnames[@]/%/=}" # WA #D1570 checked
  ble/complete/cand/unpack "$1"

  local prefix_len=$PREFIX_LEN
  [[ :$comp_type: == *:menu-show-prefix:* ]] && prefix_len=0

  local filter_target=${CAND:prefix_len}
  if [[ ! $filter_target ]]; then
    ret=
    return 0
  fi

  # Get color settings, display contents, prepositions, and suffixes
  local g=0 show=$filter_target suffix= prefix=
  ble/function#try ble/complete/action:"$ACTION"/init-menu-item
  local g0=$g; [[ :$comp_type: == *:menu-color:* ]] || g0=0

  # Extracting matching parts
  local m
  if [[ :$comp_type: == *:menu-color-match:* && $_ble_complete_menu_common_part && $show == *"$filter_target"* ]]; then
    local filter_type=head
    case :$comp_type: in
    (*:m:*) filter_type=substr ;;
    (*:a:*) filter_type=hsubseq ;;
    (*:A:*) filter_type=subseq ;;
    esac

    local needle=${_ble_complete_menu_common_part:prefix_len}
    ble/complete/candidates/filter:"$filter_type"/match "$needle" "$filter_target"; m=("${ret[@]}")

    # When narrowing down is occurring using a substring of the display string
    if [[ $show != "$filter_target" ]]; then
      local show_prefix=${show%%"$filter_target"*}
      local offset=${#show_prefix}
      local i n=${#m[@]}
      for ((i=0;i<n;i++)); do ((m[i]+=offset)); done
    fi
  else
    m=()
  fi

  # Initialization of basic colors (Note: For faster speed, refer to _ble_color_g2sgr directly)
  if [[ :$opts: == *:selected:* ]]; then
    ble/color/face2g menu_complete_selected
    ble/color/g#append g0 "$ret"
  fi
  # @var sgrN0 sgrN1
  #   The graphics for unmatchinig part of the completion item.  sgrN0 and
  #   sgrN1 are specified to "ble/canvas/trace-text $esc external-sgr" as sgr0
  #   and sgr1; sgr0 specifies the default graphics and sgr1 specifies the
  #   graphics for the visible representation of the control characters.
  local sgrN0= sgrN1= sgrB0= sgrB1=
  ble/color/g2sgr "$g0"; sgrN0=$ret
  ble/color/g2sgr "$((g0^_ble_color_gflags_Revert))"; sgrN1=$ret
  # @var sgrB0 sgrB1
  #   The graphics for matching part of the completion item.
  if ((${#m[@]})); then
    # Initialize matching color
    g=$g0
    ret=$_ble_syntax_highlight_lscolors_rl_colored_completion_prefix
    [[ $ret ]] || ble/color/face2g menu_complete_match
    ble/color/g#append g "$ret"
    ble/color/g2sgr "$g"; sgrB0=$ret
    ble/color/g2sgr "$((g^_ble_color_gflags_Revert))"; sgrB1=$ret
  fi

  # Prefix output
  local out= flag_overflow= p0=0
  if [[ $prefix ]]; then
    ble/canvas/trace-text "$prefix" nonewline || flag_overflow=1
    out=$out$_ble_term_sgr0$ret
  fi

  # Match output
  if ((${#m[@]})); then
    local i iN=${#m[@]} p p0=0
    for ((i=0;i<iN;i++)); do
      ((p=m[i]))
      if ((p0<p)); then
        if ((i%2==0)); then
          local sgr0=$sgrN0 sgr1=$sgrN1
        else
          local sgr0=$sgrB0 sgr1=$sgrB1
        fi
        ble/canvas/trace-text "${show:p0:p-p0}" nonewline:external-sgr || flag_overflow=1
        out=$out$sgr0$ret
      fi
      p0=$p
    done
  fi

  # remaining output
  if ((p0<${#show})); then
    local sgr0=$sgrN0 sgr1=$sgrN1
    ble/canvas/trace-text "${show:p0}" nonewline:external-sgr || flag_overflow=1
    out=$out$sgr0$ret
  fi

  # Postfix output
  if [[ $suffix ]]; then
    ble/canvas/trace-text "$suffix" nonewline || flag_overflow=1
    out=$out$_ble_term_sgr0$ret
  fi

  ret=$out$_ble_term_sgr0
  [[ ! $flag_overflow ]]
}

function ble/complete/menu-complete.class/get-desc {
  local item=$1
  local "${_ble_complete_cand_varnames[@]/%/=}" # WA #D1570 checked
  ble/complete/cand/unpack "$item"
  desc="$desc_sgrt(action:$ACTION)$desc_sgr0"
  ble/function#try ble/complete/action:"$ACTION"/get-desc
}

function ble/complete/menu-complete.class/onselect {
  local nsel=$1 osel=$2
  local insert=${_ble_complete_menu_original:-${_ble_complete_menu_comp[2]}}
  if ((nsel>=0)); then
    local "${_ble_complete_cand_varnames[@]/%/=}" # WA #D1570 checked
    ble/complete/cand/unpack "${_ble_complete_menu_items[nsel]}"
    insert=$INSERT
  fi

  if [[ :$bleopt_complete_menu_complete_opts: == *:insert-selection:* ]]; then
    ble-edit/content/replace-limited "$_ble_complete_menu0_beg" "$_ble_edit_ind" "$insert"
    ((_ble_edit_ind=_ble_complete_menu0_beg+${#insert}))
  fi
}

function ble/complete/menu/clear {
  if [[ $_ble_complete_menu_active ]]; then
    _ble_complete_menu_active=
    ble/complete/menu#clear
    [[ $_ble_highlight_layer_menu_filter_beg ]] &&
      ble/textarea#invalidate str # cancel layer:menu_filter (#D0995)
  fi
  return 0
}
blehook widget_bell!=ble/complete/menu/clear
blehook history_leave!=ble/complete/menu/clear

## @fn ble/complete/menu/get-footprint
##   @var[out] footprint
function ble/complete/menu/get-footprint {
  footprint=$_ble_edit_ind:$_ble_edit_mark_active:${_ble_edit_mark_active:+$_ble_edit_mark}:$_ble_edit_overwrite_mode:$_ble_edit_str
}

## @fn ble/complete/menu/show opts
##
##   @param[in] opts
##     A colon-separated list of options.  In addition to the options supported
##     by ble/complete/menu#construct, the following options are supported.
##
##     @opt init
##       When this is specified, the variables containing the current
##       completion context, "_ble_complete_menu{,0}_*", are initialized.  When
##       this is specified, the following variables need to be supplied by the
##       caller:
##
##       @var[in] _ble_edit_str _ble_edit_ind
##       @var[in] COMP1 COMP2 COMPS COMPV comps_flags comps_fixed
##
##       Based on those variables, the following variables are initialied.
##
##       @var[out] _ble_complete_menu_active=1
##       @arr[out] _ble_complete_menu0_comp
##       @arr[out] _ble_complete_menu_comp
##       @var[out] _ble_complete_menu0_str
##       @var[out] _ble_complete_menu0_beg
##       @var[out] _ble_complete_menu0_end
##       @var[out] _ble_complete_menu_footprint
##
##       This option implies opt and "update-items".  The items specified in
##       the array "cand_pack" are saved in the array
##       "_ble_complete_menu0_pack".
##
##       @arr[out] _ble_complete_menu0_pack
##
##       When this is specified, the menu style and opts are updated to be the
##       one specified by bleopt complete_menu_style and "hidden" from
##       complete_menu_complete_opts, respectively.  Otherwise, the menu style
##       and opts are the one used in the previous call of
##       ble/complete/menu/show.
##
##       @var[out] _ble_complete_menu_style
##       @var[out] _ble_complete_menu_opts
##
##     @opt update-context
##       When this is specified, the following variables, containing the text
##       surrounding the completed word, are updated based on the current
##       content of the command line.
##
##       @var[ref] _ble_complete_menu0_str
##       @var[ref] _ble_complete_menu0_end
##       @var[ref] _ble_complete_menu_footprint
##
##     @opt update-items
##       When this is specified, the menu items are specified through the
##       following variables.
##
##       @var[in] comp_type
##       @arr[in] cand_pack
##       @var[in] menu_common_part
##
##       The items are saved in the following variable.
##
##       @arr[out] _ble_complete_menu_items
##
function ble/complete/menu/show {
  local opts=$1

  [[ :$opts: == *:init:* ]] && opts=$opts:update-items

  if [[ :$opts: != *:update-items:* ]]; then
    local comp_type=${_ble_complete_menu_comp[4]}
    local cand_pack; cand_pack=("${_ble_complete_menu_items[@]}")
    local menu_common_part=$_ble_complete_menu_common_part
  fi

  # settings for ble/complete/menu/menu#construct
  local menu_style=$_ble_complete_menu_style
  local menu_opts=$_ble_complete_menu_opts
  if [[ ! $_ble_complete_menu_style || :$opts: == *:init:* ]]; then
    menu_style=$bleopt_complete_menu_style
    menu_opts=
    [[ :$bleopt_complete_menu_complete_opts: == *:hidden:* && :$opts: != *:show_menu:* ]] &&
      menu_opts=$menu_opts:hidden

    _ble_complete_menu_style=$menu_style
    _ble_complete_menu_opts=$menu_opts
  fi

  local menu_items; menu_items=("${cand_pack[@]}")

  _ble_complete_menu_common_part=$menu_common_part
  local menu_class=ble/complete/menu-complete.class menu_param=

  local menu_construct_opts=$opts
  [[ :$comp_type: == *:sync:* ]] &&
    menu_construct_opts=$menu_construct_opts:sync
  [[ :$_ble_complete_menu_opts: == *:hidden:* ]] &&
    menu_construct_opts=$menu_construct_opts:hidden

  ble/complete/menu#construct "$menu_construct_opts" || return "$?"
  ble/complete/menu#show

  case :$opts: in
  (*:init:*)
    local beg=$COMP1 end=$_ble_edit_ind #Position after inserting complement instead of COMP2
    local str=$_ble_edit_str
    [[ $_ble_decode_keymap == auto_complete ]] &&
      str=${str::_ble_edit_ind}${str:_ble_edit_mark}
    local footprint; ble/complete/menu/get-footprint
    _ble_complete_menu_active=1
    _ble_complete_menu0_beg=$beg
    _ble_complete_menu0_end=$end
    _ble_complete_menu0_str=$str
    _ble_complete_menu0_comp=("$COMP1" "$COMP2" "$COMPS" "$COMPV" "$comp_type" "$comps_flags" "$comps_fixed")
    _ble_complete_menu0_pack=("${cand_pack[@]}")
    _ble_complete_menu_comp=("$COMP1" "$COMP2" "$COMPS" "$COMPV" "$comp_type")
    _ble_complete_menu_footprint=$footprint ;;

  (*:update-context:*)
    # Redisplaying the menu after completion based on what is already displayed in menu.
    # Adjustments are made while retaining the information at the start of completion.

    # The string on the left side of the editing area may be rewritten by ambiguous completion.
    local left0=${_ble_complete_menu0_str::_ble_complete_menu0_end}
    local left1=${_ble_edit_str::_ble_edit_ind}
    local ret; ble/string#common-prefix "$left0" "$left1"; left0=$ret

    # There is a possibility that the string on the right side of the editing area will be absorbed and rewritten.
    local right0=${_ble_complete_menu0_str:_ble_complete_menu0_end}
    local right1=${_ble_edit_str:_ble_edit_ind}
    local ret; ble/string#common-suffix "$right0" "$right1"; right0=$ret

    local footprint; ble/complete/menu/get-footprint
    _ble_complete_menu0_str=$left0$right0
    _ble_complete_menu0_end=${#left0}
    _ble_complete_menu_footprint=$footprint ;;
  esac
  return 0
}

function ble/complete/menu/redraw {
  if [[ $_ble_complete_menu_active ]]; then
    ble/complete/menu#show
  fi
}

## ble/complete/menu/get-active-range [str [ind]]
##   @param[in,opt] str ind
##   @var[out] beg end
function ble/complete/menu/get-active-range {
  [[ $_ble_complete_menu_active ]] || return 1

  local str=${1-$_ble_edit_str} ind=${2-$_ble_edit_ind}
  local mbeg=$_ble_complete_menu0_beg
  local mend=$_ble_complete_menu0_end
  local left=${_ble_complete_menu0_str::mend}
  local right=${_ble_complete_menu0_str:mend}
  if [[ ${str::ind} == "$left"* && ${str:ind} == *"$right" ]]; then
    ((beg=mbeg,end=${#str}-${#right}))
    return 0
  else
    ble/complete/menu/clear
    return 1
  fi
}

## @fn ble/complete/menu/generate-candidates-from-menu
## Re-extracts candidates from the currently displayed menu contents.
##   @var[out] COMP1 COMP2 COMPS COMPV comp_type comps_flags comps_fixed
##   @var[out] cand_count cand_cand cand_word cand_pack
function ble/complete/menu/generate-candidates-from-menu {
  # completion context information
  COMP1=${_ble_complete_menu_comp[0]}
  COMP2=${_ble_complete_menu_comp[1]}
  COMPS=${_ble_complete_menu_comp[2]}
  COMPV=${_ble_complete_menu_comp[3]}
  comp_type=${_ble_complete_menu_comp[4]}
  comps_flags=${_ble_complete_menu0_comp[5]}
  comps_fixed=${_ble_complete_menu0_comp[6]}

  # remaining candidates
  cand_count=${#_ble_complete_menu_items[@]}
  cand_cand=() cand_word=() cand_pack=()
  local pack "${_ble_complete_cand_varnames[@]/%/=}" # WA #D1570 checked
  for pack in "${_ble_complete_menu_items[@]}"; do
    ble/complete/cand/unpack "$pack"
    ble/array#push cand_cand "$CAND"
    ble/array#push cand_word "$INSERT"
    ble/array#push cand_pack "$pack"
  done
  ((cand_count))
}

# 
#==============================================================================
# complement

## @fn ble/complete/generate-candidates-from-opts opts
##   @var[out] COMP1 COMP2 COMPS COMPV comp_type comps_flags comps_fixed
##   @var[out] cand_count cand_cand cand_word cand_pack
##   @var[in,out] cand_limit_reached
function ble/complete/generate-candidates-from-opts {
  local opts=$1

  # Determining the context
  local context; ble/complete/complete/determine-context-from-opts "$opts"

  # Generation of complementary sources
  comp_type=
  [[ :$opts: == *:auto_menu:* ]] && comp_type=auto_menu
  local comp_text=$_ble_edit_str comp_index=$_ble_edit_ind
  local sources
  ble/complete/context:"$context"/generate-sources "$comp_text" "$comp_index" || return "$?"

  ble/complete/candidates/generate "$opts"
}

## @fn ble/complete/insert insert_beg insert_end insert suffix
function ble/complete/insert {
  local insert_beg=$1 insert_end=$2
  local insert=$3 suffix=$4
  local original_text=${_ble_edit_str:insert_beg:insert_end-insert_beg}
  local ret

  # Minimize edit range
  local insert_replace=
  if [[ $insert == "$original_text"* ]]; then
    # If there is no replacement of existing part
    insert=${insert:insert_end-insert_beg}
    ((insert_beg=insert_end))
  else
    # If there is replacement of existing part
    ble/string#common-prefix "$insert" "$original_text"
    if [[ $ret ]]; then
      insert=${insert:${#ret}}
      ((insert_beg+=${#ret}))
    fi
  fi

  if [[ $bleopt_complete_skip_matched ]]; then
    # Absorb text to the right of the cursor
    if [[ $insert ]]; then
      local right_text=${_ble_edit_str:insert_end}
      right_text=${right_text%%[$IFS]*}
      if ble/string#common-prefix "$insert" "$right_text"; [[ $ret ]]; then
        # Absorb if the first match is to the right of the cursor
        ((insert_end+=${#ret}))
      elif ble/complete/string#common-suffix-prefix "$insert" "$right_text"; [[ $ret ]]; then
        # Absorb if there is a trailing match to the right of the cursor
        ((insert_end+=${#ret}))
      fi
    fi

    # Absorption of suffix
    if [[ $suffix ]]; then
      local right_text=${_ble_edit_str:insert_end}
      if ble/string#common-prefix "$suffix" "$right_text"; [[ $ret ]]; then
        ((insert_end+=${#ret}))
      elif ble/complete/string#common-suffix-prefix "$suffix" "$right_text"; [[ $ret ]]; then
        ((insert_end+=${#ret}))
      fi
    fi
  fi

  local ins=$insert$suffix
  ble/widget/.replace-range "$insert_beg" "$insert_end" "$ins"
  ((_ble_edit_ind=insert_beg+${#ins},
    _ble_edit_ind>${#_ble_edit_str}&&
      (_ble_edit_ind=${#_ble_edit_str})))
  return 0
}

## @fn ble/complete/insert-common
##   @var[out] COMP1 COMP2 COMPS COMPV comp_type comps_flags comps_fixed
##   @var[out] cand_count cand_cand cand_word cand_pack
##
##   @var[in] menu_show_opts
##     This variable is supposed to be set by ble/widget/complete.
function ble/complete/insert-common {
  local ret
  ble/complete/candidates/determine-common-prefix; (($?==148)) && return 148
  local insert=$ret suffix=
  local insert_beg=$COMP1 insert_end=$COMP2
  local insert_flags=
  [[ $insert == "$COMPS"* ]] || insert_flags=r

  if ((cand_count==1)); then
    # Uniqueness confirmed
    local ACTION=${cand_pack[0]%%:*}
    if ble/is-function ble/complete/action:"$ACTION"/complete; then
      local "${_ble_complete_cand_varnames[@]/%/=}" # WA #D1570 checked
      ble/complete/cand/unpack "${cand_pack[0]}"
      ble/complete/action:"$ACTION"/complete
      (($?==148)) && return 148
    fi
  else
    # When there are multiple candidates
    insert_flags=${insert_flags}m
  fi

  local do_insert=1
  if ((cand_count>1)) && [[ $insert_flags == *r* ]]; then
    # Replaces the existing part, and does not replace it if it is not unique.
    # When using ambiguous completion, it is adjusted within determine-common-prefix, so insert it.
    if [[ :$comp_type: != *:[maAi]:* ]]; then
      do_insert=
    fi
  elif [[ $insert$suffix == "$COMPS" ]]; then
    # If there is no change, do not insert.
    do_insert=
  fi
  if [[ $do_insert ]]; then
    ble/complete/insert "$insert_beg" "$insert_end" "$insert" "$suffix"
    blehook/invoke complete_insert
  fi

  if [[ $insert_flags == *m* ]]; then
    # menu_common_part (menu emphasis string)
    # If insert is a simple word, then
    # Set menu_common_part as the evaluation value after insertion.
    # If not, there is no other choice, so let's use the value before insertion as COMPV.
    local menu_common_part=$COMPV
    local ret simple_flags simple_ibrace
    if ble/syntax:bash/simple-word/reconstruct-incomplete-word "$insert"; then
      ble/complete/source/eval-simple-word "$ret" single
      (($?==148)) && return 148
      menu_common_part=$ret
    fi
    ble/complete/menu/show "$menu_show_opts" || return "$?"
  elif [[ $insert_flags == *n* ]]; then
    ble/widget/complete show_menu:regenerate || return "$?"
  else
    _ble_complete_state=complete
    ble/complete/menu/clear
  fi
  return 0
}

## @fn ble/complete/insert-all
##   @var[out] COMP1 COMP2 COMPS COMPV comp_type comps_flags comps_fixed
##   @var[out] cand_count cand_cand cand_word cand_pack
function ble/complete/insert-all {
  local "${_ble_complete_cand_varnames[@]/%/=}" # WA #D1570 checked
  local pack beg=$COMP1 end=$COMP2 insert= suffix= insert_flags= index=0
  for pack in "${cand_pack[@]}"; do
    ble/complete/cand/unpack "$pack"
    insert=$INSERT suffix= insert_flags=

    if ble/is-function ble/complete/action:"$ACTION"/complete; then
      ble/complete/action:"$ACTION"/complete
      (($?==148)) && return 148
    fi
    [[ $suffix != *' ' ]] && suffix="$suffix "

    ble/complete/insert "$beg" "$end" "$insert" "$suffix"
    blehook/invoke complete_insert
    beg=$_ble_edit_ind end=$_ble_edit_ind
    ((index++))
  done

  _ble_complete_state=complete
  ble/complete/menu/clear
  return 0
}

## @fn ble/complete/insert-braces/.compose words...
## Compresses the specified word into a brace expansion.
##   @var[in] comp_type
##   @stdout
## Returns the compressed brace expansion.
function ble/complete/insert-braces/.compose {
  # Note: If awk supports RS = "\0", separate with \0.
  # Otherwise, separate with \x1E (ASCII RS).
  if ble/bin/awk0.available; then
    local printf_format='%s\0' char_RS='"\0"' awk=ble/bin/awk0
  else
    local printf_format='%s\x1E' char_RS='"\x1E"' awk=ble/bin/awk
  fi

  local q=\'
  local -x rex_atom='^(\\.|[0-9]+|.)' del_close= del_open= quote_type=
  local -x COMPS=$COMPS
  if [[ :$comp_type: != *:[maAi]:* ]]; then
    local rex_brace='[,{}]|\{[-a-zA-Z0-9]+\.\.[-a-zA-Z0-9]+\}'
    case $comps_flags in
    (*S*)    rex_atom='^('$q'(\\'$q'|'$rex_brace')'$q'|[0-9]+|.)' # '...'
             del_close=\' del_open=\' quote_type=S ;;
    (*E*)    rex_atom='^(\\.|'$q'('$rex_brace')\$'$q'|[0-9]+|.)'  # $'...'
             del_close=\' del_open=\$\' quote_type=E ;;
    (*[DI]*) rex_atom='^(\\[\"$`]|"('$rex_brace')"|[0-9]+|.)'     # "...", $"..."
             del_close=\" del_open=\" quote_type=D ;;
    esac
  fi

  printf "$printf_format" "$@" | "$awk" '
    function starts_with(str, head) {
      return substr(str, 1, length(head)) == head;
    }

    # Note: value ~ /[[:lower:]]/ cannot be used in mawk. value ~ /[a-z]/ may
    # match uppercase characters in some strange locales, e.g., en_US.UTF-8 in
    # Ubuntu 16.04 LTS.
    function islower(s) {
      return s == tolower(s);
    }

    BEGIN {
      RS = '"$char_RS"';
      rex_atom = ENVIRON["rex_atom"];
      del_close = ENVIRON["del_close"];
      del_open = ENVIRON["del_open"];
      quote_type = ENVIRON["quote_type"];
      COMPS = ENVIRON["COMPS"];

      BRACE_OPEN = del_close "{" del_open;
      BRACE_CLOS = del_close "}" del_open;
    }

    function to_atoms(str, arr, _, chr, atom, level, count, rex) {
      count = 0;
      while (match(str, rex_atom) > 0) {
        chr = substr(str, 1, RLENGTH);
        str = substr(str, RLENGTH + 1);
        if (chr == BRACE_OPEN) {
          atom = chr;
          level = 1;
          while (match(str, rex_atom) > 0) {
            chr = substr(str, 1, RLENGTH);
            str = substr(str, RLENGTH + 1);
            atom = atom chr;
            if (chr == BRACE_OPEN)
              level++;
            else if (chr == BRACE_CLOS && --level==0)
              break;
          }
        } else {
          atom = chr;
        }
        arr[count++] = atom;
      }
      return count;
    }

    function remove_empty_quote(str, _, rex_quote_first, rex_quote, out, empty, m) {
      if (quote_type == "S" || quote_type == "E") {
        rex_quote_first = "^[^'$q']*'$q'";
        rex_quote = "'$q'[^'$q']*'$q'|(\\\\.|[^'$q'])+";
      } else if (quote_type == "D") {
        rex_quote_first = "^[^\"]*\"";
        rex_quote = "\"([^\\\"]|\\\\.)*\"|(\\\\.|[^\"])+";
      } else return str;
      empty = del_open del_close;

      out = "";

      if (starts_with(str, COMPS)) {
        out = COMPS;
        str = substr(str, length(COMPS) + 1);
        if (match(str, rex_quote_first) > 0) {
          out = out substr(str, 1, RLENGTH);
          str = substr(str, RLENGTH + 1);
        }
      }

      while (match(str, rex_quote) > 0) {
        m = substr(str, 1, RLENGTH);
        if (m != empty) out = out m;
        str = substr(str, RLENGTH + 1);
      }

      if (str == del_open)
        return out;
      else
        return out str del_close;
    }

    function zpad(value, width, _, wpad, i, pad) {
      wpad = width - length(value);
      pad = "";
      for (i = 0; i < wpad; i++) pad = "0" pad;
      if (value < 0)
        return "-" pad (-value);
      else
        return pad value;
    }
    function zpad_remove(value) {
      if (value ~ /^0+$/)
        value = "0";
      else if (value ~ /^-/)
        sub(/^-0+/, "-", value);
      else
        sub(/^0+/, "", value);
      return value;
    }
    function zpad_a2i(text) {
      sub(/^-0+/, "-", text) || sub(/^0+/, "", text);
      return 0 + text;
    }

    function range_contract(arr, len, _, i, value, alpha, lower, upper, keys, ikey, dict, b, e, beg, end, tmp) {
      lower = "abcdefghijklmnopqrstuvwxyz";
      upper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
      for (i = 0; i < len; i++) {
        value = arr[i];
        if (dict[value]) {
          dict[value]++;
        } else {
          keys[ikey++] = value;
          dict[value] = 1;
        }
      }

      len = 0;

      for (i = 0; i < ikey; i++) {
        while (dict[value = keys[i]]--) {
          if (value ~ /^([a-zA-Z])$/) {
            alpha = islower(value) ? lower : upper;
            beg = end = value;
            b = e = index(alpha, value);
            while (b > 1 && dict[tmp = substr(alpha, b - 1, 1)]) {
              dict[beg = tmp]--;
              b--;
            }
            while (e < 26 && dict[tmp = substr(alpha, e + 1, 1)]) {
              dict[end = tmp]--;
              e++;
            }

            if (e == b) {
              arr[len++] = beg;
            } else if (e == b + 1) {
              arr[len++] = beg;
              arr[len++] = end;
            } else {
              arr[len++] = del_close "{" beg ".." end "}" del_open;
            }

          } else if (value ~ /^(0+|-?0*[1-9][0-9]*)$/) {
            beg = end = value;
            b = e = zpad_a2i(value);
            wmax = wmin = length(value);

            # range extension for normal numbers
            if (value ~ /^(0|-?[1-9][0-9]*)$/) {
              while (dict[b - 1]) dict[--b]--;
              while (dict[e + 1]) dict[++e]--;

              tmp = length(beg = "" b);
              if (tmp < wmin) wmin = tmp;
              else if (tmp > wmax) wmax = tmp;

              tmp = length(end = "" e);
              if (tmp < wmin) wmin = tmp;
              else if (tmp > wmax) wmax = tmp;
            }

            # try range extension for zpad numbers
            if (wmax == wmin) {
              while (length(tmp = zpad(b - 1, wmin)) == wmin && dict[tmp]) { dict[tmp]--; --b; }
              while (length(tmp = zpad(e + 1, wmin)) == wmin && dict[tmp]) { dict[tmp]--; ++e; }
              beg = zpad(b, wmin);
              end = zpad(e, wmin);
            }

            if (e == b) {
              arr[len++] = beg;
            } else if (e == b + 1) {
              arr[len++] = beg;
              arr[len++] = end;
            } else if (b < 0 && e < 0) {
              # if all the numbers are negative, factorize -
              arr[len++] = del_close "-{" substr(end, 2) ".." substr(beg, 2) "}" del_open;
            } else {
              arr[len++] = del_close "{" beg ".." end "}" del_open;
            }

          } else {
            arr[len++] = value;
          }
        }
      }
      return len;
    }

    function simple_brace(arr, len, _, ret, i) {
      if (len == 0) return "";

      len = range_contract(arr, len);
      if (len == 1) return arr[0];

      ret = BRACE_OPEN arr[0];
      for (i = 1; i < len; i++)
        ret = ret del_close "," del_open arr[i];
      return ret BRACE_CLOS;
    }

    #--------------------------------------------------------------------------
    # right factorization

    function rfrag_strlen_common(a, b, _, la, lb, tmp, i, n) {
      ret = 0;
      alen = to_atoms(a, abuf);
      blen = to_atoms(b, bbuf);
      while (alen > 0 && blen > 0) {
        if (abuf[alen - 1] != bbuf[blen - 1]) break;
        ret += length(abuf[alen - 1]);
        alen--;
        blen--;
      }
      return ret;
    }
    function rfrag_get_level(str, _, len, i, rfrag0, rfrag0len, rfrag1) {
      len = length(str);
      rfrag_matching_offset = len;
      for (i = 0; i < rfrag_depth - 1; i++) {
        rfrag0 = rfrag[i];
        rfrag0len = length(rfrag0);
        rfrag1 = substr(str, len - rfrag0len + 1);
        str = substr(str, 1, len -= rfrag0len);
        if (rfrag0 != rfrag1) break;
        rfrag_matching_offset -= rfrag0len;
      }
      while (i && rfrag[i - 1] == "") i--; # empty fragment
      return i;
    }
    function rfrag_reduce(new_depth, _, c, i, brace, frags) {
      while (rfrag_depth > new_depth) {
        rfrag_depth--;
        c = rfrag_count[rfrag_depth];
        for (i = 0; i < c; i++)
          frags[i] = rfrag[rfrag_depth, i];
        frags[c] = rfrag[rfrag_depth];
        brace = simple_brace(frags, c + 1);

        if (rfrag_depth == 0)
          return brace;
        else
          rfrag[rfrag_depth - 1] = brace rfrag[rfrag_depth - 1];
      }
    }
    function rfrag_register(str, level, _, rfrag0, rfrag1, len) {
      if (level == rfrag_depth) {
        rfrag_depth = level + 1;
        rfrag[level] = "";
        rfrag_count[level] = 0;
      } else if (rfrag_depth != level + 1) {
        print "ERR(rfrag)";
      }

      rfrag0 = rfrag[level];
      rfrag1 = substr(str, 1, rfrag_matching_offset);
      len = rfrag_strlen_common(rfrag0, rfrag1);
      if (len == 0) {
        rfrag[level, rfrag_count[level]++] = rfrag0;
        rfrag[level] = rfrag1;
      } else {
        rfrag[level] = substr(rfrag0, length(rfrag0) - len + 1);
        rfrag[level + 1, 0] = substr(rfrag0, 1, length(rfrag0) - len);
        rfrag[level + 1] = substr(rfrag1, 1, length(rfrag1) - len);
        rfrag_count[level + 1] = 1;
        rfrag_depth++;
      }
    }
    function rfrag_dump(_, i, j, prefix) {
      print "depth = " rfrag_depth;
      for (i = 0; i < rfrag_depth; i++) {
        prefix = "";
        for (j = 0; j < i; j++) prefix = prefix "  ";
        for (j = 0; j < rfrag_count[i]; j++)
          print prefix "rfrag[" i "," j "] = " rfrag[i,j];
        print prefix "rfrag[" i "] = " rfrag[i];
      }
    }
    function rfrag_brace(arr, len, _, i, level) {
      if (len == 0) return "";
      if (len == 1) return arr[0];

      rfrag_depth = 1;
      rfrag[0] = arr[0];
      rfrag_count[0] = 0;
      for (i = 1; i < len; i++) {
        level = rfrag_get_level(arr[i]);
        rfrag_reduce(level + 1);
        rfrag_register(arr[i], level);
      }

      return rfrag_reduce(0);
    }

    #--------------------------------------------------------------------------
    # left factorization

    function lfrag_strlen_common(a, b, _, ret, abuf, bbuf, alen, blen, ia, ib) {
      ret = 0;
      alen = to_atoms(a, abuf);
      blen = to_atoms(b, bbuf);
      for (ia = ib = 0; ia < alen && ib < blen; ia++ + ib++) {
        if (abuf[ia] != bbuf[ib]) break;
        ret += length(abuf[ia]);
      }
      return ret;
    }
    function lfrag_get_level(str, _, i, frag0, frag0len, frag1) {
      lfrag_matching_offset = 0;
      for (i = 0; i < lfrag_depth - 1; i++) {
        frag0 = frag[i]
        frag0len = length(frag0);
        frag1 = substr(str, lfrag_matching_offset + 1, frag0len);
        if (frag0 != frag1) break;
        lfrag_matching_offset += frag0len;
      }
      while (i && frag[i - 1] == "") i--; # empty fragment
      return i;
    }
    function lfrag_reduce(new_depth, _, c, i, brace, frags) {
      while (lfrag_depth > new_depth) {
        lfrag_depth--;
        c = frag_count[lfrag_depth];
        for (i = 0; i < c; i++)
          frags[i] = frag[lfrag_depth, i];
        frags[c] = frag[lfrag_depth];
        brace = rfrag_brace(frags, c + 1);

        if (lfrag_depth == 0)
          return brace;
        else
          frag[lfrag_depth - 1] = frag[lfrag_depth - 1] brace;
      }
    }
    function lfrag_register(str, level, _, frag0, frag1, len) {
      if (lfrag_depth == level) {
        lfrag_depth = level + 1;
        frag[level] = "";
        frag_count[level] = 0;
      } else if (lfrag_depth != level + 1) {
        print "ERR";
      }

      frag0 = frag[level];
      frag1 = substr(str, lfrag_matching_offset + 1);
      len = lfrag_strlen_common(frag0, frag1);
      if (len == 0) {
        frag[level, frag_count[level]++] = frag0;
        frag[level] = frag1;
      } else {
        frag[level] = substr(frag0, 1, len);
        frag[level + 1, 0] = substr(frag0, len + 1);
        frag[level + 1] = substr(frag1, len + 1);
        frag_count[level + 1] = 1;
        lfrag_depth++;
      }
    }

    function lfrag_dump(_, i, j, prefix) {
      print "depth = " lfrag_depth;
      for (i = 0; i < lfrag_depth; i++) {
        prefix = "";
        for (j = 0; j < i; j++) prefix = prefix "  ";
        for (j = 0; j < frag_count[i]; j++)
          print prefix "frag[" i "," j "] = " frag[i,j];
        print prefix "frag[" i "] = " frag[i];
      }
    }

    NR == 1 {
      lfrag_depth = 1;
      frag[0] = $0;
      frag_count[0] = 0;
      #lfrag_dump();
      next
    }
    {
      level = lfrag_get_level($0);
      lfrag_reduce(level + 1);
      lfrag_register($0, level);
      #lfrag_dump();
    }

    END {
      result = lfrag_reduce(0);
      result = remove_empty_quote(result);
      print result;
    }
  '
}

## @fn ble/complete/insert-braces
##   @var[out] COMP1 COMP2 COMPS COMPV comp_type comps_flags comps_fixed
##   @var[out] cand_count cand_cand cand_word cand_pack
##
##   @var[in] menu_show_opts
##     This variable is supposed to be set by ble/widget/complete and
##     referenced in ble/complete/insert-common.
function ble/complete/insert-braces {
  if ((cand_count==1)); then
    ble/complete/insert-common; return "$?"
  fi

  local comps_len=${#COMPS} loop=0
  local -a tails=()

  # Common parts (case sensitive)
  local common=${cand_word[0]}
  ble/array#push tails "${common:comps_len}"
  local word clen=${#common}
  for word in "${cand_word[@]:1}"; do
    ((loop++%bleopt_complete_polling_cycle==0)) && ble/complete/check-cancel && return 148

    # common part
    ((clen>${#word}&&(clen=${#word})))
    while [[ ${word::clen} != "${common::clen}" ]]; do
      ((clen--))
    done
    common=${common::clen}

    # Part after COMPS
    ble/array#push tails "${word:comps_len}"
  done

  local fixed=$COMPS
  if [[ $common != "$COMPS"* ]]; then
    # When retroactive rewriting occurs
    tails=()

    # Front fixed part
    local fixed= fixval=
    {
      # Make sure to fix up to comps_fixed
      [[ $comps_fixed ]] &&
        fixed=${COMPS::${comps_fixed%%:*}} fixval=${comps_fixed#*:}

      # If COMPS can be applied partially, use it
      local ret simple_flags simple_ibrace
      ble/complete/candidates/determine-common-prefix/.apply-partial-comps # var[in,out] common
      if ble/syntax:bash/simple-word/reconstruct-incomplete-word "$common"; then
        ble/complete/source/eval-simple-word "$ret" single
        (($?==148)) && return 148
        fixed=$common fixval=$ret
      fi
    }

    # Rebuild cand_word from cand_cand
    local cand ret fixval_len=${#fixval}
    for cand in "${cand_cand[@]}"; do
      ((loop++%bleopt_complete_polling_cycle==0)) && ble/complete/check-cancel && return 148
      [[ $cand == "$fixval"* ]] || continue

      ble/complete/string#escape-for-completion-context "${cand:fixval_len}"
      case $comps in
      (*S*) cand=\'$ret\'   ;;
      (*E*) cand=\$\'$ret\' ;;
      (*D*) cand=\"$ret\"   ;;
      (*I*) cand=\$\"$ret\" ;;
      (*)   cand=$ret ;;
      esac

      ble/array#push tails "$cand"
    done
  fi

  local tail; ble/util/assign tail 'ble/complete/insert-braces/.compose "${tails[@]}"'
  local beg=$COMP1 end=$COMP2 insert=$fixed$tail suffix=

  if [[ $comps_flags == *x* ]]; then
    ble/complete/action/complete.addtail ','
  else
    ble/complete/action/complete.addtail ' '
  fi

  ble/complete/insert "$beg" "$end" "$insert" "$suffix"
  blehook/invoke complete_insert
  _ble_complete_state=complete
  ble/complete/menu/clear
  return 0
}

_ble_complete_state=

## @widget complete opts
##   @param[in] opts
## A colon-separated list.
## Below are the options that specify the behavior.
##
## insert_common (default)
## Insert common match.
##     insert_all
## Insert all suggestions.
##     insert_braces
## Inserts candidates together into a brace expansion.
##     insert_unique
## When the candidate is unique, it is inserted without entering menu completion.
##     show_menu
## Display the menu.
##     enter_menu
## Enter menu completion.
##     menu-style=*
##       Specify the menu style when the menu is shown (with show_menu,
##       enter_menu).  This overrides the default specified by "bleopt
##       complete_menu_style".
##
##     context=*
## Specifies the context for candidate generation.
##     backward
## Move to the last candidate when entering menu completion.
##     no-empty
## Suppress completion with empty COMPV.
##     no-bell
## Does not generate a bell when there are no candidates.
##
##     auto_menu
## Specifies that it is being called via auto-menu.
## Use complete_limit_auto_menu to limit the number of completion candidates.
## Abort the entire completion when complete_limit is reached for some completion sources.
##
function ble/widget/complete {
  local opts=$1 arg=
  ble-edit/content/get-arg
  local comp_edit_arg=$arg # Note: referenced by source:glob

  local state=$_ble_complete_state
  _ble_complete_state=start

  local ret
  ble/opts#extract-last-optarg "$opts" menu-style &&
    [[ $ret ]] && ble/is-function ble/complete/menu-style:"$ret"/construct &&
    local bleopt_complete_menu_style=$ret

  case :$opts: in
  (*:insert_*:*) ;;
  (*:toggle_menu:*)
    if [[ $_ble_complete_menu_active ]]; then
      ble/widget/menu_complete/toggle-hidden
      return 0
    else
      opts=$opts:show_menu
    fi ;;
  (*:show_menu:*) ;;
  (*:enter_menu:*)
    [[ $_ble_complete_menu_active && :$opts: != *:context=*:* ]] &&
      ble/complete/menu-complete/enter "$opts" && return 0 ;;
  (*)
    if [[ $bleopt_complete_menu_complete ]]; then
      if [[ $_ble_complete_menu_active && :$opts: != *:context=*:* ]]; then
        local footprint; ble/complete/menu/get-footprint
        [[ $footprint == "$_ble_complete_menu_footprint" ]] &&
          ble/complete/menu-complete/enter "$opts" && return 0
      fi
      [[ $WIDGET == "$LASTWIDGET" && $state != complete ]] && opts=$opts:enter_menu
    fi ;;
  esac

  local COMP1 COMP2 COMPS COMPV
  local comp_type comps_flags comps_fixed
  local cand_count cand_cand cand_word cand_pack
  ble/complete/candidates/clear

  local menu_show_opts=init
  local cand_limit_reached=
  if [[ $_ble_complete_menu_active && :$opts: != *:regenerate:* &&
          :$opts: != *:context=*:* && ${#_ble_complete_menu_items[@]} -gt 0 ]]
  then
    if [[ $_ble_complete_menu_filter_enabled && $bleopt_complete_menu_filter ]] ||
         ble/complete/menu-filter || { (($?==148)) && return 148; }
    then
      if ble/complete/menu/generate-candidates-from-menu || { (($?==148)) && return 148; }; then
        if ((cand_count)); then
          menu_show_opts=update-context:update-items
        fi
      fi
    fi
  fi
  if ((cand_count==0)); then
    local bleopt_complete_menu_style=$bleopt_complete_menu_style #Allow temporary changes to source etc.
    ble/complete/generate-candidates-from-opts "$opts"; local ext=$?
    ((ext==148)) && return 148
    if [[ $cand_limit_reached ]]; then
      [[ :$opts: != *:no-bell:* ]] &&
        ble/widget/.bell 'complete: limit reached'
      if [[ $cand_limit_reached == cancel ]]; then
        ble/edit/info/default
        return 1
      fi
    fi
    if ((ext!=0||cand_count==0)); then
      [[ :$opts: != *:no-bell:* && ! $cand_limit_reached ]] &&
        ble/widget/.bell 'complete: no completions'
      ble/edit/info/default
      return 1
    fi
  fi

  if [[ :$opts: == *:insert_common:* || :$opts: == *:insert_unique:* && cand_count -eq 1 ]]; then
    ble/complete/insert-common; return "$?"

  elif [[ :$opts: == *:insert_braces:* ]]; then
    ble/complete/insert-braces; return "$?"

  elif [[ :$opts: == *:insert_all:* ]]; then
    ble/complete/insert-all; return "$?"

  elif [[ :$opts: == *:enter_menu:* ]]; then
    local menu_common_part=$COMPV
    ble/complete/menu/show "$menu_show_opts" || return "$?"
    ble/complete/menu-complete/enter "$opts" || {
      (($?==148)) && return 148
      [[ :$opts: == *:no-bell:* ]] || ble/widget/.bell 'menu-complete: no completions'
    }
    return 0

  elif [[ :$opts: == *:show_menu:* ]]; then
    local menu_common_part=$COMPV
    ble/complete/menu/show "$menu_show_opts:show_menu"
    return "$?" # exit status of ble/complete/menu/show

  fi

  ble/complete/insert-common; return "$?"
}

function ble/widget/complete-insert {
  local original=$1 insert=$2 suffix=$3
  [[ ${_ble_edit_str::_ble_edit_ind} == *"$original" ]] || return 1

  local insert_beg=$((_ble_edit_ind-${#original}))
  local insert_end=$_ble_edit_ind
  ble/complete/insert "$insert_beg" "$insert_end" "$insert" "$suffix"
}

function ble/widget/menu-complete {
  local opts=$1
  ble/widget/complete enter_menu:insert_unique:$opts
}

function ble/widget/complete/.select-menu-with-arg {
  [[ $bleopt_complete_menu_complete && $_ble_complete_menu_active ]] || return 1

  local footprint; ble/complete/menu/get-footprint
  [[ $footprint == "$_ble_complete_menu_footprint" ]] || return 1

  local arg_opts= opts=$1
  [[ :$opts: == *:enter-menu:* ]] && arg_opts=always
  [[ :$opts: == *:nobell:* ]] && arg_opts=$arg_opts:nobell

  # Enter menu only if the current key can actually be interpreted as part of the argument
  ble/widget/menu/append-arg/.is-argument "$arg_opts" || return 1
  ble/complete/menu-complete/enter
  ble/widget/menu/append-arg "$arg_opts"
  return 0
}

#------------------------------------------------------------------------------
# menu-filter

## @fn ble/complete/menu-filter/.filter-candidates
##   @var[in,out] comp_type
##   @var[out] cand_pack
function ble/complete/menu-filter/.filter-candidates {
  cand_pack=()

  local iloop=0 interval=$bleopt_complete_polling_cycle
  local filter_type pack "${_ble_complete_cand_varnames[@]/%/=}" # WA #D1570 checked
  for filter_type in head substr hsubseq subseq; do
    ble/path#remove-glob comp_type '[maA]'
    case $filter_type in
    (substr)  comp_type=${comp_type}:m ;;
    (hsubseq) comp_type=${comp_type}:a ;;
    (subseq)  comp_type=${comp_type}:A ;;
    esac

    local comp_filter_type
    local comp_filter_pattern
    ble/complete/candidates/filter#init "$filter_type" "$COMPV"
    for pack in "${_ble_complete_menu0_pack[@]}"; do
      ((iloop++%interval==0)) && ble/complete/check-cancel && return 148
      ble/complete/cand/unpack "$pack"
      ble/complete/candidates/filter#test "$CAND" &&
        ble/array#push cand_pack "$pack"
    done
    ((${#cand_pack[@]}!=0)) && return 0
  done
}
## @fn ble/complete/menu-filter/.get-filter-target
##   @var[out] str ind
function ble/complete/menu-filter/.get-filter-target {
  if [[ $_ble_decode_keymap == emacs || $_ble_decode_keymap == vi_[ic]map ]]; then
    str=$_ble_edit_str
    ind=$_ble_edit_ind
  elif [[ $_ble_decode_keymap == vi_nmap ]]; then
    str=$_ble_edit_str
    ind=$_ble_edit_ind
    ble-edit/content/eolp "$ind" || ((ind++))
  elif [[ $_ble_decode_keymap == auto_complete ]]; then
    str=${_ble_edit_str::_ble_edit_ind}${_ble_edit_str:_ble_edit_mark}
    ind=$_ble_edit_ind
  else
    return 1
  fi
}
function ble/complete/menu-filter {
  [[ $_ble_decode_keymap == menu_complete ]] && return 0
  local str ind
  ble/complete/menu-filter/.get-filter-target || return 1

  local beg end; ble/complete/menu/get-active-range "$str" "$ind" || return 1
  local input=${str:beg:end-beg}
  [[ $input == "${_ble_complete_menu_comp[2]}" ]] && return 0

  local ret simple_flags simple_ibrace
  if ! ble/syntax:bash/simple-word/reconstruct-incomplete-word "$input"; then
    ble/syntax:bash/simple-word/is-never-word "$input" && return 1
    return 0
  fi
  [[ $simple_ibrace ]] && ((${simple_ibrace%%:*}>10#0${_ble_complete_menu0_comp[6]%%:*})) && return 1 # When entering another brace expansion element
  ble/syntax:bash/simple-word/eval "$ret" single; (($?==148)) && return 148
  local COMPV=$ret

  local comp_type=${_ble_complete_menu0_comp[4]} cand_pack
  ble/complete/menu-filter/.filter-candidates; (($?==148)) && return 148

  local menu_common_part=$COMPV
  ble/complete/menu/show update-items || return "$?"
  _ble_complete_menu_comp=("$beg" "$end" "$input" "$COMPV" "$comp_type")
  return 0
}

function ble/complete/menu-filter.idle {
  ble/util/idle.wait-user-input
  [[ $bleopt_complete_menu_filter ]] || return 1
  [[ $_ble_complete_menu_active ]] || return 1
  ble/complete/menu-filter; local ext=$?
  ((ext==148)) && return 148
  ((ext)) && ble/complete/menu/clear
  return 0
}

# ble/highlight/layer:menu_filter

## @fn ble/highlight/layer/buff#operate-gflags name beg end mask gflags
function ble/highlight/layer/buff#operate-gflags {
  local BUFF=$1 beg=$2 end=$3 mask=$4 gflags=$5
  ((beg<end)) || return 1

  if [[ $mask == auto ]]; then
    mask=0
    ((gflags&_ble_color_gflags_FgMask)) && ((mask|=_ble_color_gflags_FgMask))
    ((gflags&_ble_color_gflags_BgMask)) && ((mask|=_ble_color_gflags_BgMask))
  fi

  local i g ret
  for ((i=beg;i<end;i++)); do
    ble/highlight/layer/update/getg "$i"
    ((g=g&~mask|gflags))
    ble/color/g2sgr "$g"
    builtin eval -- "$BUFF[$i]=\$ret\${_ble_highlight_layer_plain_buff[$i]}"
  done
}
## @fn ble/highlight/layer/buff#set-explicit-sgr name index
function ble/highlight/layer/buff#set-explicit-sgr {
  local BUFF=$1 index=$2
  builtin eval "((index<\${#$BUFF[@]}))" || return 1
  local g; ble/highlight/layer/update/getg "$index"
  local ret; ble/color/g2sgr "$g"
  builtin eval "$BUFF[index]=\$ret\${_ble_highlight_layer_plain_buff[index]}"
}

_ble_highlight_layer_menu_filter_buff=()
_ble_highlight_layer_menu_filter_beg=
_ble_highlight_layer_menu_filter_end=
function ble/highlight/layer:menu_filter/update {
  local text=$1 player=$2

  # shift
  local obeg=$_ble_highlight_layer_menu_filter_beg
  local oend=$_ble_highlight_layer_menu_filter_end
  if [[ $obeg ]] && ((DMIN>=0)); then
    ((DMAX0<=obeg?(obeg+=DMAX-DMAX0):(DMIN<obeg&&(obeg=DMIN)),
      DMAX0<=oend?(oend+=DMAX-DMAX0):(DMIN<oend&&(oend=DMIN))))
  fi
  _ble_highlight_layer_menu_filter_beg=$obeg
  _ble_highlight_layer_menu_filter_end=$oend

  # determine range
  local beg= end=
  if [[ $bleopt_complete_menu_filter && $_ble_complete_menu_active && ${#_ble_complete_menu_items[@]} -gt 0 ]]; then
    local str ind
    ble/complete/menu-filter/.get-filter-target &&
      ble/complete/menu/get-active-range "$str" "$ind" &&
      [[ ${str:beg:end-beg} != "${_ble_complete_menu0_comp[2]}" ]] || beg= end=
  fi

  # Skip if no changes
  [[ ! $obeg && ! $beg ]] && return 0
  ((PREV_UMIN<0)) && [[ $beg == "$obeg" && $end == "$oend" ]] &&
    PREV_BUFF=_ble_highlight_layer_menu_filter_buff && return 0

  local umin=$PREV_UMIN umax=$PREV_UMAX
  if [[ $beg ]]; then
    local ret
    ble/color/face2g menu_filter_fixed; local gF=$ret
    ble/color/face2g menu_filter_input; local gI=$ret
    local mid=$_ble_complete_menu0_end
    ((mid<beg?(mid=beg):(end<mid&&(mid=end))))

    local buff_name=_ble_highlight_layer_menu_filter_buff
    builtin eval "$buff_name=(\"\${$PREV_BUFF[@]}\")"
    ble/highlight/layer/buff#operate-gflags "$buff_name" "$beg" "$mid" auto "$gF"
    ble/highlight/layer/buff#operate-gflags "$buff_name" "$mid" "$end" auto "$gI"
    ble/highlight/layer/buff#set-explicit-sgr "$buff_name" "$end"
    PREV_BUFF=$buff_name

    if [[ $obeg ]]; then :
      ble/highlight/layer:{selection}/.invalidate "$beg" "$obeg"
      ble/highlight/layer:{selection}/.invalidate "$end" "$oend"
    else
      ble/highlight/layer:{selection}/.invalidate "$beg" "$end"
    fi
  else
    if [[ $obeg ]]; then
      ble/highlight/layer:{selection}/.invalidate "$obeg" "$oend"
    fi
  fi
  _ble_highlight_layer_menu_filter_beg=$beg
  _ble_highlight_layer_menu_filter_end=$end
  ((PREV_UMIN=umin,PREV_UMAX=umax))
}
function ble/highlight/layer:menu_filter/getg {
  local index=$1
  local obeg=$_ble_highlight_layer_menu_filter_beg
  local oend=$_ble_highlight_layer_menu_filter_end
  local mid=$_ble_complete_menu0_end
  if [[ $obeg ]] && ((obeg<=index&&index<oend)); then
    local ret
    if ((index<mid)); then
      ble/color/face2g menu_filter_fixed; local g0=$ret
    else
      ble/color/face2g menu_filter_input; local g0=$ret
    fi
    ble/highlight/layer/update/getg "$index"
    ble/color/g.append "$g0"
  fi
}

_ble_complete_menu_filter_enabled=
if ble/is-function ble/util/idle.push-background; then
  _ble_complete_menu_filter_enabled=1
  ble/util/idle.push -n 9999 ble/complete/menu-filter.idle
  ble/array#insert-before _ble_highlight_layer_list region menu_filter
fi

#------------------------------------------------------------------------------
#
# menu-complete
#

## Menu completion refers to the following variables
##
##   @var[in] _ble_complete_menu0_beg
##   @var[in] _ble_complete_menu0_end
##   @var[in] _ble_complete_menu_original
##   @var[in] _ble_complete_menu_selected
##   @var[in] _ble_complete_menu_common_part
##   @arr[in] _ble_complete_menu_page_icons
##
## Additionally, use the following variables:
##
##   @var[in,out] _ble_complete_menu_original=

_ble_complete_menu_original=

## @fn ble/complete/menu-complete/select index [opts]
function ble/complete/menu-complete/select {
  ble/complete/menu#select "$@"
}

## @fn ble/complete/menu-complete/enter [opts]
##   @var[in,opt] opts
##     backward
##     insert_unique
function ble/complete/menu-complete/enter {
  ((${#_ble_complete_menu_items[@]}>=1)) || return 1
  local beg end; ble/complete/menu/get-active-range || return 1

  local opts=$1

  _ble_edit_mark=$beg
  _ble_edit_ind=$end
  local comps_fixed=${_ble_complete_menu0_comp[6]}
  if [[ $comps_fixed ]]; then
    local comps_fixed_length=${comps_fixed%%:*}
    ((_ble_edit_mark+=comps_fixed_length))
  fi

  # When unique. Execute confirmation within the framework of menu-complete, including menu processing.
  if [[ :$opts: == *:insert_unique:* ]] && ((${#_ble_complete_menu_items[@]}==1)); then
    ble/complete/menu#select 0
    ble/decode/keymap/push menu_complete
    ble/widget/menu_complete/exit complete
    return 0
  fi

  _ble_complete_menu_original=${_ble_edit_str:beg:end-beg}
  ble/complete/menu/redraw

  if [[ :$opts: == *:backward:* ]]; then
    ble/complete/menu#select "$((${#_ble_complete_menu_items[@]}-1))"
  else
    ble/complete/menu#select 0
  fi

  _ble_edit_mark_active=insert
  ble/decode/keymap/push menu_complete
  return 0
}

function ble/complete/menu-complete/exit {
  ble/decode/keymap/pop
  if [[ $_ble_decode_keymap == vi_nmap ]]; then
    ble/keymap:vi/needs-eol-fix && ((_ble_edit_ind--))
    ble/keymap:vi/adjust-command-mode
  fi
}

function ble/widget/menu_complete/exit {
  local opts=$1

  if ((_ble_complete_menu_selected>=0)); then
    # Reconfigure replacement information
    local new=${_ble_edit_str:_ble_complete_menu0_beg:_ble_edit_ind-_ble_complete_menu0_beg}
    if [[ :$bleopt_complete_menu_complete_opts: != *:insert-selection:* ]]; then
      local "${_ble_complete_cand_varnames[@]/%/=}" # WA #D1570 checked
      ble/complete/cand/unpack "${_ble_complete_menu_items[_ble_complete_menu_selected]}"
      new=$INSERT
    fi
    local old=$_ble_complete_menu_original
    local comp_text=${_ble_edit_str::_ble_complete_menu0_beg}$old${_ble_edit_str:_ble_edit_ind}
    local insert_beg=$_ble_complete_menu0_beg
    local insert_end=$((_ble_complete_menu0_beg+${#old}))
    local insert=$new
    local insert_flags=

    # Determining and inserting suffix
    local suffix=
    if [[ :$opts: == *:complete:* ]]; then
      local icon=${_ble_complete_menu_page_icons[_ble_complete_menu_selected-_ble_complete_menu_page_offset]}
      local icon_data=${icon#*:} icon_fields
      ble/string#split icon_fields , "${icon%%:*}"
      local pack=${icon_data::icon_fields[4]}

      local ACTION=${pack%%:*}
      if ble/is-function ble/complete/action:"$ACTION"/complete; then
        # Restore completion context
        local COMP1=${_ble_complete_menu0_comp[0]}
        local COMP2=${_ble_complete_menu0_comp[1]}
        local COMPS=${_ble_complete_menu0_comp[2]}
        local COMPV=${_ble_complete_menu0_comp[3]}
        local comp_type=${_ble_complete_menu0_comp[4]}
        local comps_flags=${_ble_complete_menu0_comp[5]}
        local comps_fixed=${_ble_complete_menu0_comp[6]}

        # Loading completion suggestions
        local "${_ble_complete_cand_varnames[@]/%/=}" # WA #D1570 checked
        ble/complete/cand/unpack "$pack"

        ble/complete/action:"$ACTION"/complete
      fi
      ble/complete/insert "$_ble_complete_menu0_beg" "$_ble_edit_ind" "$insert" "$suffix"
    fi

    # notification
    blehook/invoke complete_insert
  fi

  ble/complete/menu/clear
  _ble_edit_mark_active=
  _ble_complete_menu_original=
  ble/complete/menu-complete/exit
}
function ble/widget/menu_complete/cancel {
  ble/complete/menu#select -1
  _ble_edit_mark_active=
  _ble_complete_menu_original=
  ble/complete/menu-complete/exit
}
function ble/widget/menu_complete/accept {
  ble/widget/menu_complete/exit complete
}
function ble/widget/menu_complete/exit-default {
  ble/widget/menu_complete/exit
  ble/decode/widget/redispatch
}

_ble_complete_menu_switch_styles=(align-nowrap desc linewise dense-nowrap)
function ble/widget/menu_complete/switch-style {
  local menu_style
  if [[ $1 && $1 != [-+] ]]; then
    menu_style=$1
  else
    local ret nstyle=${#_ble_complete_menu_switch_styles[@]} shift=${1:-+}1
    if ble/array#index _ble_complete_menu_switch_styles "$_ble_complete_menu_style"; then
      ((ret=(ret+shift+nstyle)%nstyle))
    else
      ((ret=shift<0?nstyle-1:0))
    fi
    menu_style=${_ble_complete_menu_switch_styles[ret]}
  fi
  [[ $menu_style != "$_ble_complete_menu_style" ]] || return 0

  _ble_complete_menu_style=$menu_style
  bleopt complete_menu_style="$menu_style"
  local sel=$_ble_complete_menu_selected
  ble/complete/menu/show scroll="$sel"
  ble/complete/menu#select "$sel"
}
function ble/widget/menu_complete/toggle-hidden {
  if [[ :$_ble_complete_menu_opts: == *:hidden:* ]]; then
    ble/opts#remove _ble_complete_menu_opts hidden
  else
    _ble_complete_menu_opts=$_ble_complete_menu_opts:hidden
  fi

  local sel=$_ble_complete_menu_selected
  ble/complete/menu/show scroll="$sel"
  ble/complete/menu#select "$sel"
}

function ble-decode/keymap:menu_complete/define {
  # ble-bind -f __defchar__ menu_complete/self-insert
  ble-bind -f __default__ 'menu_complete/exit-default'
  ble-bind -f __line_limit__ nop
  ble-bind -f C-m         'menu_complete/accept'
  ble-bind -f RET         'menu_complete/accept'
  ble-bind -f C-g         'menu_complete/cancel'
  ble-bind -f 'C-x C-g'   'menu_complete/cancel'
  ble-bind -f 'C-M-g'     'menu_complete/cancel'
  ble-bind -f C-f         'menu/forward-column'
  ble-bind -f right       'menu/forward-column'
  ble-bind -f C-i         'menu/forward cyclic'
  ble-bind -f TAB         'menu/forward cyclic'
  ble-bind -f C-b         'menu/backward-column'
  ble-bind -f left        'menu/backward-column'
  ble-bind -f C-S-i       'menu/backward cyclic'
  ble-bind -f S-TAB       'menu/backward cyclic'
  ble-bind -f C-n         'menu/forward-line'
  ble-bind -f down        'menu/forward-line'
  ble-bind -f C-p         'menu/backward-line'
  ble-bind -f up          'menu/backward-line'
  ble-bind -f prior       'menu/backward-page'
  ble-bind -f next        'menu/forward-page'
  ble-bind -f home        'menu/beginning-of-page'
  ble-bind -f end         'menu/end-of-page'

  ble-bind -f 'C-x SP'    'menu_complete/toggle-hidden'
  ble-bind -f 'C-x right' 'menu_complete/switch-style +'
  ble-bind -f 'C-x C-n'   'menu_complete/switch-style +'
  ble-bind -f 'C-x left'  'menu_complete/switch-style -'
  ble-bind -f 'C-x C-p'   'menu_complete/switch-style -'
  ble-bind -f 'C-x a'     'menu_complete/switch-style align-nowrap'
  ble-bind -f 'C-x c'     'menu_complete/switch-style dense-nowrap'
  ble-bind -f 'C-x d'     'menu_complete/switch-style desc'
  ble-bind -f 'C-x l'     'menu_complete/switch-style linewise'

  local key
  for key in {,M-,C-}{0..9}; do
    ble-bind -f "$key" 'menu/append-arg'
  done
}

_ble_complete_menu_arg=
## @fn ble/widget/menu/append-arg [opts]
##   @param[in,opt] opts
##     A colon-separated list of the options:
##
##     always
##       When a numeric argument is not started, the normal digit is by default
##       treated as normal user input.  This option makes the normal digit
##       always start a numeric argument.
##     nobell
##       Do not ring edit bell when no corresponding item is found.
##
function ble/widget/menu/append-arg {
  [[ ${LASTWIDGET%%' '*} == */append-arg ]] || _ble_complete_menu_arg=

  # If argument input has not started and (unmodified) number keys are used, they are just normal numbers.
  # Treat as input.
  local i=${#KEYS[@]}; ((i&&i--))
  local flag=$((KEYS[i]&_ble_decode_MaskFlag))
  if ! [[ :$1: == *:always:* || flag -ne 0 || $_ble_complete_menu_arg ]]; then
    ble/widget/menu_complete/exit-default
    return "$?"
  fi

  local code=$((KEYS[i]&_ble_decode_MaskChar))
  ((48<=code&&code<=57)) || return 1
  local ret; ble/util/c2s "$code"; local ch=$ret
  ((_ble_complete_menu_arg=10#0$_ble_complete_menu_arg$ch))

  # If the number is not within the range, delete the number from the beginning.
  local count=${#_ble_complete_menu_items[@]}
  while ((_ble_complete_menu_arg>count)); do
    ((_ble_complete_menu_arg=10#0${_ble_complete_menu_arg:1}))
  done
  if ! ((_ble_complete_menu_arg)); then
    [[ :$1: == *:nobell:* ]] ||
      ble/widget/.bell 'menu: out of range'
    return 0
  fi

  # move
  ble/complete/menu#select "$((_ble_complete_menu_arg-1))"
}

## @fn ble/widget/menu/append-arg/.is-argument [opts]
##   @param[in,opt] opts
function ble/widget/menu/append-arg/.is-argument {
  local i=${#KEYS[@]}; ((i&&i--))
  local flag=$((KEYS[i]&_ble_decode_MaskFlag))
  local code=$((KEYS[i]&_ble_decode_MaskChar))
  [[ :$1: == *:always:* ]] || ((flag)) || return 1
  ((48<=code&&code<=57))
}

#------------------------------------------------------------------------------
#
# auto-complete
#

function ble/complete/auto-complete/initialize {
  local ret
  ble/decode/kbd/generate-keycode ac_enter
  _ble_complete_KCODE_ENTER=$ret
}
ble/complete/auto-complete/initialize

function ble/highlight/layer:region/mark:auto_complete/get-face {
  face=auto_complete
}

_ble_complete_ac_type=
_ble_complete_ac_comp1=
_ble_complete_ac_cand=
_ble_complete_ac_word=
_ble_complete_ac_insert=
_ble_complete_ac_suffix=

## @fn ble/complete/auto-complete/enter type comp1 suggest cand word [insert suffix]
##   @param[in] type
## c ... prefix completion
## h ... prefix completion with history. Same treatment as c
## m ... substring completion
## a ... Ambiguous completion (first character confirmed)
## A ... Ambiguous completion
##   @param[in] comp1
## Completion starting point
##   @param[in] suggest
## Presentation string
##   @param[in] cand
## original word
##   @param[in] word
## Insert string (before confirmation)
##   @param[in,opt] insert
## Insert string (when confirmed). If omitted, it is assumed to be the same as word.
##   @param[in] suffix
## Suffix insertion string. If omitted, it is assumed to be an empty string.
##
##   @var[in] _ble_edit_ind
## Specify the insertion position of the suggested string.
##   @var[out] _ble_edit_mark
## Returns the ending point of the suggested string.
##
function ble/complete/auto-complete/enter {
  local type=$1 COMP1=$2 suggest=$3 cand=$4 word=$5 insert1=${6-$5} suffix=${7-}

  local limit=$((bleopt_line_limit_length))
  if ((limit&&${#_ble_edit_str}+${#suggest}>limit)); then
    # auto-complete simply fails if it hits the character limit.
    return 1
  fi

  # presentation
  local insert; ble-edit/content/replace-limited "$_ble_edit_ind" "$_ble_edit_ind" "$suggest" nobell
  ((_ble_edit_mark=_ble_edit_ind+${#suggest}))

  _ble_complete_ac_type=$type
  _ble_complete_ac_comp1=$COMP1
  _ble_complete_ac_cand=$cand
  _ble_complete_ac_word=$word
  _ble_complete_ac_insert=$insert1
  _ble_complete_ac_suffix=$suffix

  _ble_edit_mark_active=auto_complete
  ble/decode/keymap/push auto_complete
  ble-decode-key "$_ble_complete_KCODE_ENTER" # dummy key input to record keyboard macros
  return 0
}

## @fn ble/complete/auto-complete/source:history/.search-light text
## Search history using !string or !?string
##   @param[in] text
##   @var[out] ret
function ble/complete/auto-complete/source:history/.search-light {
  [[ $_ble_history_prefix ]] && return 1

  local text=$1
  [[ ! $text ]] && return 1

  # Attempt to match by !string
  # string cannot contain [$wordbreaks]. ? is OK
  local wordbreaks="<>();&|:$_ble_term_IFS"
  local word= expand
  if [[ $text != [-0-9#?!]* ]]; then
    word=${text%%[$wordbreaks]*}
    command='!'$word ble/util/assign expand 'ble/edit/histexpand/run' &>/dev/null || return 1
    if [[ $expand == "$text"* ]]; then
      ret=$expand
      return 0
    fi
  fi

  # Attempt to match by !?string
  # string cannot contain "?"
  if [[ $word != "$text" ]]; then
    # Longest match not containing ?
    local fragments; ble/string#split fragments '?' "$text"
    local frag longest_fragments len=0; longest_fragments=('')
    for frag in "${fragments[@]}"; do
      local len1=${#frag}
      ((len1>len&&(len=len1))) && longest_fragments=()
      ((len1==len)) && ble/array#push longest_fragments "$frag"
    done

    for frag in "${longest_fragments[@]}"; do
      command='!?'$frag ble/util/assign expand 'ble/edit/histexpand/run' &>/dev/null || return 1
      [[ $expand == "$text"* ]] || continue
      ret=$expand
      return 0
    done
  fi

  return 1
}

_ble_complete_ac_history_needle=
_ble_complete_ac_history_index=
_ble_complete_ac_history_start=
## @fn ble/complete/auto-complete/source:history/.search-heavy text
##   @var[out] ret
function ble/complete/auto-complete/source:history/.search-heavy {
  local text=$1

  local count; ble/history/get-count -v count
  local start=$((count-1))
  local index=$((count-1))
  local needle=$text

  # Resume search from midway
  ((start==_ble_complete_ac_history_start)) &&
    [[ $needle == "$_ble_complete_ac_history_needle"* ]] &&
    index=$_ble_complete_ac_history_index

  local isearch_time=0 isearch_ntask=1
  local isearch_opts=head
  [[ :$comp_type: == *:sync:* ]] || isearch_opts=$isearch_opts:stop_check
  ble/history/isearch-backward-blockwise "$isearch_opts"; local ext=$?
  _ble_complete_ac_history_start=$start
  _ble_complete_ac_history_index=$index
  _ble_complete_ac_history_needle=$needle
  ((ext)) && return "$ext"

  ble/history/get-edited-entry -v ret "$index"
  return 0
}

## @fn ble/complete/auto-complete/source:history/.impl opts
##   @param[in] opts
##   @var[in] comp_type comp_text comp_index
function ble/complete/auto-complete/source:history/.impl {
  local opts=$1
  local searcher=.search-heavy
  [[ :$opts: == *:light:*  ]] && searcher=.search-light

  local ret
  ((_ble_edit_ind==${#_ble_edit_str})) || return 1
  ble/complete/auto-complete/source:history/"$searcher" "$_ble_edit_str" || return "$?" # 0, 1 or 148
  local command=$ret
  [[ $command == "$_ble_edit_str" ]] && return 1
  ble/complete/auto-complete/enter h 0 "${command:${#_ble_edit_str}}" '' "$command"
}
function ble/complete/auto-complete/source:history {
  [[ :$bleopt_complete_auto_complete_opts: != *:history-disabled:* ]] || return 1
  ble/complete/auto-complete/source:history/.impl light; local ext=$?
  ((ext==0||ext==148)) && return "$ext"

  [[ $_ble_history_prefix || $_ble_history_load_done ]] &&
    ble/complete/auto-complete/source:history/.impl; local ext=$?
  ((ext==0||ext==148)) && return "$ext"
}

## @fn ble/complete/auto-complete/source:syntax
##   @var[in] comp_type comp_text comp_index
function ble/complete/auto-complete/source:syntax {
  [[ :$bleopt_complete_auto_complete_opts: != *:syntax-disabled:* ]] || return 1

  local sources
  ble/complete/context:syntax/generate-sources "$comp_text" "$comp_index" &&
    ble/complete/context/filter-prefix-sources || return 1

  # ble/complete/candidates/generate settings
  local bleopt_complete_contract_function_names=
  local bleopt_complete_menu_style=$bleopt_complete_menu_style # source local settings
  ((bleopt_complete_polling_cycle>25)) &&
    local bleopt_complete_polling_cycle=25
  local COMP1 COMP2 COMPS COMPV
  local comps_flags comps_fixed
  local cand_count cand_cand cand_word cand_pack
  local cand_limit_reached=
  ble/complete/candidates/generate; local ext=$?
  [[ $COMPV ]] || return 1
  ((ext)) && return "$ext"

  if [[ :$bleopt_complete_auto_complete_opts: == *:syntax-unique:* ]]; then
    ((cand_count==1))
  else
    ((cand_count))
  fi || return 1

  local word=${cand_word[0]} cand=${cand_cand[0]}
  [[ $word == "$COMPS" ]] && return 1

  # Modifications such as addtail
  local insert=$word suffix=
  local ACTION=${cand_pack[0]%%:*}
  if ble/is-function ble/complete/action:"$ACTION"/complete; then
    local "${_ble_complete_cand_varnames[@]/%/=}" # WA #D1570 checked
    ble/complete/cand/unpack "${cand_pack[0]}"
    local insert_beg=$COMP1 insert_end=$COMP2 insert_flags=
    ble/complete/action:"$ACTION"/complete
  fi

  local type= suggest=
  if [[ $insert == "$COMPS"* ]]; then
    # Do not present when input candidates have already been entered as a continuation.
    [[ ${comp_text:COMP1} == "$insert"* ]] && return 1

    type=c
    suggest="${insert:${#COMPS}}"
  else
    case :$comp_type: in
    (*:a:*) type=a ;;
    (*:m:*) type=m ;;
    (*:A:*) type=A ;;
    (*)   type=r ;;
    esac
    suggest=" [$insert] "
  fi
  ble/complete/auto-complete/enter "$type" "$COMP1" "$suggest" "$cand" "$word" "$insert" "$suffix"
}

_ble_complete_auto_source=(history syntax)

## @fn ble/complete/auto-complete.impl opts
##   @param[in] opts
# A colon-separated list of options.
## sync Specifies that processing should not be interrupted even if there is user input.
function ble/complete/auto-complete.impl {
  local opts=$1
  local comp_type=auto
  [[ :$opts: == *:sync:* ]] && comp_type=${comp_type}:sync

  local comp_text=$_ble_edit_str comp_index=$_ble_edit_ind
  [[ $comp_text ]] || return 0

  # auto-complete is suppressed inside the menu-filter editing area
  if local beg end; ble/complete/menu/get-active-range "$_ble_edit_str" "$_ble_edit_ind"; then
    ((_ble_edit_ind<end)) && return 0
  fi

  local source
  for source in "${_ble_complete_auto_source[@]}"; do
    ble/complete/auto-complete/source:"$source"; local ext=$?
    ((ext==0)) && break
    ((ext==148)) && return "$ext"
  done
}

## Background function ble/complete/auto-complete.idle
function ble/complete/auto-complete.idle {
  # *If you don't overwrite it, you can always exit with wait-user-input.
  ble/util/idle.wait-user-input

  [[ $bleopt_complete_auto_complete ]] || return 1
  [[ $_ble_decode_keymap == emacs || $_ble_decode_keymap == vi_[ic]map ]] || return 0

  case $_ble_decode_widget_last in
  (ble/widget/self-insert|ble/widget/magic-space|ble/widget/magic-slash) ;;
  (ble/widget/complete|ble/widget/vi_imap/complete)
    [[ :$bleopt_complete_auto_complete_opts: == *:suppress-after-complete:* ]] && return 0 ;;
  (*) return 0 ;;
  esac

  [[ $_ble_edit_str ]] || return 0

  if [[ :$bleopt_complete_auto_complete_opts: == *:suppress-inside-line:* ]]; then
    [[ ${_ble_edit_str:_ble_edit_ind:1} == [!$'\n'] ]] && return 0
  elif [[ :$bleopt_complete_auto_complete_opts: == *:suppress-inside-word:* ]]; then
    [[ ${_ble_edit_str:_ble_edit_ind:1} == [!$' \t\n"'\'';&|<>()=:'] ]] && return 0
  fi

  # Process after bleopt_complete_auto_delay has elapsed
  ble/util/idle.sleep-until "$((_ble_idle_clock_start+bleopt_complete_auto_delay))" checked && return 0

  ble/complete/auto-complete.impl
}

## Background function ble/complete/auto-menu.idle
function ble/complete/auto-menu.idle {
  ble/util/idle.wait-user-input
  [[ $_ble_complete_menu_active ]] && return 0
  ((bleopt_complete_auto_menu>0)) || return 1

  case $_ble_decode_widget_last in
  (ble/widget/self-insert|ble/widget/magic-slash) ;;
  (ble/widget/complete) ;;
  (ble/widget/vi_imap/complete) ;;
  (ble/widget/auto_complete/self-insert) ;;
  (*) return 0 ;;
  esac

  [[ $_ble_edit_str ]] || return 0

  # Process after bleopt_complete_auto_delay has elapsed
  local until=$((_ble_idle_clock_start+bleopt_complete_auto_menu))
  ble/util/idle.sleep-until "$until" checked && return 0

  ble/widget/complete auto_menu:show_menu:no-empty:no-bell
}

ble/function#try ble/util/idle.push-background ble/complete/auto-complete.idle
ble/function#try ble/util/idle.push-background ble/complete/auto-menu.idle

## @widget auto-complete-enter
##
##   Note:
## This is an editing function used when explicitly starting auto-completion with a keyboard macro.
## Generate key ac_enter using ble-decode-key in auto-complete.idle
## and auto-completion is activated through this key during playback.
##
function ble/widget/auto-complete-enter {
  ble/complete/auto-complete.impl sync
}
function ble/widget/auto_complete/cancel {
  ble/decode/keymap/pop
  ble-edit/content/replace "$_ble_edit_ind" "$_ble_edit_mark" ''
  _ble_edit_mark=$_ble_edit_ind
  _ble_edit_mark_active=
  _ble_complete_ac_insert=
  _ble_complete_ac_suffix=
}
function ble/widget/auto_complete/insert {
  ble/decode/keymap/pop
  ble-edit/content/replace "$_ble_edit_ind" "$_ble_edit_mark" ''
  _ble_edit_mark=$_ble_edit_ind

  local comp_text=$_ble_edit_str
  local insert_beg=$_ble_complete_ac_comp1
  local insert_end=$_ble_edit_ind
  local insert=$_ble_complete_ac_insert
  local suffix=$_ble_complete_ac_suffix
  ble/complete/insert "$insert_beg" "$insert_end" "$insert" "$suffix"
  blehook/invoke complete_insert

  _ble_edit_mark_active=
  _ble_complete_ac_insert=
  _ble_complete_ac_suffix=
  ble/complete/menu/clear
  ble-edit/content/clear-arg
  return 0
}
function ble/widget/auto_complete/cancel-default {
  ble/widget/auto_complete/cancel
  ble/decode/widget/redispatch
}

## @fn ble/widget/auto_complete/self-insert/.is-magic-space
##   @var[in] KEYS
## Determines whether the current keystroke corresponds to a magic-space in the parent keymap.

function ble/widget/auto_complete/self-insert/.is-magic-space {
  ((${#KEYS[@]}==1)) || return 1

  local ikeymap=$((${#_ble_decode_keymap_stack[@]}-1))
  ((ikeymap>=0)) || return 1

  local dicthead=_ble_decode_${_ble_decode_keymap_stack[ikeymap]}_kmap_
  builtin eval "local ent=\${$dicthead$_ble_decode_key__seq[KEYS[0]]-}"
  local command=${ent#*:}
  [[ $command == ble/widget/magic-space || $command == ble/widget/magic-slash ]]
}

function ble/widget/auto_complete/self-insert {
  if [[ $_ble_edit_overwrite_mode ]] || ble/widget/auto_complete/self-insert/.is-magic-space; then
    ble/widget/auto_complete/cancel-default
    return "$?"
  fi

  local code; ble/widget/self-insert/.get-code
  ((code==0)) && return 0

  local ret

  # If the insertion does not change the current candidate, then
  # Insert while displaying suggestions.
  ble/util/c2s "$code"; local ins=$ret
  local comps_cur=${_ble_edit_str:_ble_complete_ac_comp1:_ble_edit_ind-_ble_complete_ac_comp1}
  local comps_new=$comps_cur$ins
  local processed=
  if [[ $_ble_complete_ac_type == [ch] ]]; then
    # c: If the entered part is included at the beginning of the completion result
    # Even after insertion, if it is included at the beginning of the completion result, that number of characters is confirmed.
    if [[ $_ble_complete_ac_word == "$comps_new"* ]]; then
      ((_ble_edit_ind+=${#ins}))

      # Note: If there is an exact match midway through, we will exit without inserting tail.
      [[ $_ble_complete_ac_word == "$comps_new" ]] && ble/widget/auto_complete/cancel
      processed=1
    fi
  elif [[ $_ble_complete_ac_type == [rmaA] && $ins != [{,}] ]]; then
    if local ret simple_flags simple_ibrace; ble/syntax:bash/simple-word/reconstruct-incomplete-word "$comps_new"; then
      if ble/complete/source/eval-simple-word "$ret" single && local compv_new=$ret; then
        # r: When rewritten retroactively
        # Even if inserted, if it matches after expansion, insert it as is.
        # There may be cases where they do not match after expansion, but in that case, delete the candidate and try again.
        # a: Fuzzy match
        # After inserting a character, expand it and if it is a fuzzy match, insert it as is.

        local filter_type=head
        case $_ble_complete_ac_type in
        (*m*) filter_type=substr  ;;
        (*a*) filter_type=hsubseq ;;
        (*A*) filter_type=subseq  ;;
        esac

        local comps_fixed=
        local comp_filter_type
        local comp_filter_pattern
        ble/complete/candidates/filter#init "$filter_type" "$compv_new"
        if ble/complete/candidates/filter#test "$_ble_complete_ac_cand"; then
          local insert; ble-edit/content/replace-limited "$_ble_edit_ind" "$_ble_edit_ind" "$ins"
          ((_ble_edit_ind+=${#insert},_ble_edit_mark+=${#insert}))
          [[ $_ble_complete_ac_cand == "$compv_new" ]] &&
            ble/widget/auto_complete/cancel
          processed=1
        fi
      fi
    fi
  fi

  if [[ $processed ]]; then
    # notify dummy insertion
    local comp_text= insert_beg=0 insert_end=0 insert=$ins suffix=
    blehook/invoke complete_insert
    return 0
  else
    ble/widget/auto_complete/cancel
    ble/decode/widget/redispatch
  fi
}

function ble/widget/auto_complete/@end {
  if ((_ble_edit_mark!=${#_ble_edit_str})); then
    ble/widget/auto_complete/cancel-default
  else
    ble/widget/auto_complete/"$@"
  fi
}
function ble/widget/auto_complete/insert-on-end {
  ble/widget/auto_complete/@end insert
}

function ble/widget/auto_complete/.insert-prefix {
  local ins
  if [[ $_ble_complete_ac_type == [ch] ]]; then
    ins=${_ble_edit_str:_ble_edit_ind:_ble_edit_mark-_ble_edit_ind}
  else
    ins=$_ble_complete_ac_insert
  fi

  local ret
  ble/complete/auto-complete/insert-prefix:"$1" "$ins" "${@:2}"
  local prefix=$ret
  [[ $prefix || ! $ins ]] || return 1

  if [[ $_ble_complete_ac_type == [ch] ]]; then
    if [[ $prefix == "$ins" ]]; then
      ble/widget/auto_complete/insert
      return 0
    else
      local ins=$prefix

      # Note: Shift by _ble_edit_ind as shown below.
      #   <C>he<I>llo world<M> → <C>hello <I>world<M>
      #   (<C> = comp1, <I> = _ble_edit_ind, <M> = _ble_edit_mark)
      ((_ble_edit_ind+=${#ins}))

      # notification
      local comp_text=$_ble_edit_str
      local insert_beg=$_ble_complete_ac_comp1
      local insert_end=$_ble_edit_ind
      local insert=${_ble_edit_str:insert_beg:insert_end-insert_beg}$ins
      local suffix=
      blehook/invoke complete_insert
      return 0
    fi
  elif [[ $_ble_complete_ac_type == [rmaA] ]]; then
    if [[ $prefix == "$ins" ]]; then
      ble/widget/auto_complete/insert
      return 0
    else
      local ins=$prefix

      # Note: Rewrite the content as follows.
      #   <C>hll<I> [hello world] <M> → <C>hello <I>world<M>
      #   (<C> = comp1, <I> = _ble_edit_ind, <M> = _ble_edit_mark)
      _ble_complete_ac_type=c
      # Note: There is no need to use replace-limited as the content will be shorter.
      ble-edit/content/replace "$_ble_complete_ac_comp1" "$_ble_edit_mark" "$_ble_complete_ac_insert"
      ((_ble_edit_ind=_ble_complete_ac_comp1+${#ins},
        _ble_edit_mark=_ble_complete_ac_comp1+${#_ble_complete_ac_insert}))

      # notification
      local comp_text=$_ble_edit_str
      local insert_beg=$_ble_complete_ac_comp1
      local insert_end=$_ble_edit_ind
      local insert=$ins
      local suffix=
      blehook/invoke complete_insert

      return 0
    fi
  fi
  return 1
}

function ble/complete/auto-complete/insert-prefix:word {
  local breaks=${bleopt_complete_auto_wordbreaks:-$_ble_term_IFS}
  local rex='^['$breaks']*([^'$breaks']+['$breaks']*)?'
  [[ $1 =~ $rex ]]
  ret=$BASH_REMATCH
}

function ble/widget/auto_complete/insert-word {
  ble/widget/auto_complete/.insert-prefix word
}

function ble/complete/auto-complete/insert-prefix:xword {
  local wtype=$2 word_class word_set word_sep
  ble/edit/word:"$wtype"/setup
  local x=0 y=0
  _ble_edit_str=$1 ble/edit/word/forward-range 1
  ret=${1::y?y:${#1}}
}

function ble/widget/auto_complete/insert-eword { ble/widget/auto_complete/.insert-prefix xword eword; }
function ble/widget/auto_complete/insert-cword { ble/widget/auto_complete/.insert-prefix xword cword; }
function ble/widget/auto_complete/insert-uword { ble/widget/auto_complete/.insert-prefix xword uword; }
function ble/widget/auto_complete/insert-sword { ble/widget/auto_complete/.insert-prefix xword sword; }
function ble/widget/auto_complete/insert-fword { ble/widget/auto_complete/.insert-prefix xword fword; }

function ble/widget/auto_complete/accept-line {
  ble/widget/auto_complete/insert
  ble-decode-key 13
}
function ble/widget/auto_complete/notify-enter {
  ble/decode/widget/skip-lastwidget
}
function ble-decode/keymap:auto_complete/define {
  ble-bind -f __defchar__ auto_complete/self-insert
  ble-bind -f __default__ auto_complete/cancel-default
  ble-bind -f __line_limit__ nop
  ble-bind -f 'C-g'     auto_complete/cancel
  ble-bind -f 'C-x C-g' auto_complete/cancel
  ble-bind -f 'C-M-g'   auto_complete/cancel
  ble-bind -f S-RET     auto_complete/insert
  ble-bind -f S-C-m     auto_complete/insert
  ble-bind -f C-f       'auto_complete/@end insert'
  ble-bind -f right     'auto_complete/@end insert'
  ble-bind -f C-e       'auto_complete/@end insert'
  ble-bind -f end       'auto_complete/@end insert'
  ble-bind -f M-f       'auto_complete/@end insert-cword'
  ble-bind -f C-right   'auto_complete/@end insert-cword'
  ble-bind -f M-right   'auto_complete/@end insert-word'
  ble-bind -f C-j       auto_complete/accept-line
  ble-bind -f C-RET     auto_complete/accept-line
  ble-bind -f ac_enter  auto_complete/notify-enter
}

#------------------------------------------------------------------------------
#
# sabbrev
#

# The following are variables defined in core-complete-def.sh:
#
# @var _ble_complete_sabbrev

function ble/complete/sabbrev/.initialize-print {
  sgr0= sgr1= sgr2= sgr3= sgr4= sgro=
  if [[ $flags == *c* || $flags != *n* && -t 1 ]]; then
    local ret
    ble/color/face2sgr command_function; sgr1=$ret
    ble/color/face2sgr syntax_varname; sgr2=$ret
    ble/color/face2sgr syntax_quoted; sgr3=$ret
    ble/color/face2sgr syntax_escape; sgr4=$ret
    ble/color/face2sgr argument_option; sgro=$ret
    sgr0=$_ble_term_sgr0
  fi
}
function ble/complete/sabbrev/.print-definition {
  local key=$1 type=${2%%:*} value=${2#*:}
  local option=
  [[ $type != w ]] && option=$sgro'-'$type$sgr0' '

  local ret
  ble/string#quote-word "$key" quote-empty:sgrq="$sgr3":sgre="$sgr4":sgr0="$sgr2"
  key=$sgr2$ret$sgr0
  ble/string#quote-word "$value" sgrq="$sgr3":sgre="$sgr4":sgr0="$sgr0"
  value=$ret
  ble/util/print "${sgr1}ble-sabbrev$sgr0 $option$key=$value"
}

## @fn ble/complete/sabbrev/register key value
## Register static abbreviation expansion.
##   @param[in] key value
##
## @fn ble/complete/sabbrev/list type [keys...]
## Displays a list of registered static abbreviation expansions.
##   @var[in] flags
##
## @fn ble/complete/sabbrev/reset type [keys...]
## Delete a registered static abbreviation expansion.
##   @var[in] flags
##
## @fn ble/complete/sabbrev/wordwise.get key
## Gets the expansion value for static abbreviation expansion.
##   @param[in] key
##   @var[out] ret
##

# Note: _ble_complete_sabbrev is defined in core-complete-def.sh
function ble/complete/sabbrev/register {
  local key=$1 value=$2
  ((_ble_complete_sabbrev_version++))
  ble/gdict#set _ble_complete_sabbrev "$key" "$value"
}
function ble/complete/sabbrev/list {
  local type=$1; shift
  local keys ret; keys=("$@")
  if ((${#keys[@]}==0)); then
    if [[ $type ]]; then
      # When type is specified, only sabbrevs of that type are displayed.
      local ret key
      ble/gdict#keys _ble_complete_sabbrev
      for key in "${ret[@]}"; do
        ble/gdict#get _ble_complete_sabbrev "$key" && [[ $ret == "$type":* ]] || continue
        ble/array#push keys "$key"
      done
    else
      ble/gdict#keys _ble_complete_sabbrev
      keys=("${ret[@]}")
    fi
    ((${#keys[@]})) || return 0
  fi

  local sgr0 sgr1 sgr2 sgr3 sgr4 sgro
  ble/complete/sabbrev/.initialize-print

  local key ext=0
  for key in "${keys[@]}"; do
    if ble/gdict#get _ble_complete_sabbrev "$key"; then
      ble/complete/sabbrev/.print-definition "$key" "$ret"
    else
      ble/util/print "ble-sabbrev: $key: not found." >&2
      ext=1
    fi
  done

  return "$ext"
}
function ble/complete/sabbrev/reset {
  local type=$1; shift
  if (($#)); then
    local key
    for key; do
      ble/gdict#unset _ble_complete_sabbrev "$key"
    done
    ((_ble_complete_sabbrev_version++))
  elif [[ $type ]]; then
    # When type is specified, delete only sabbrev of that type

    local ret key
    ble/gdict#keys _ble_complete_sabbrev
    if ((${#ret[@]})); then
      for key in "${ret[@]}"; do
        ble/gdict#get _ble_complete_sabbrev "$key" && [[ $ret == "$type":* ]] || continue
        ble/gdict#unset _ble_complete_sabbrev "$key"
      done
      ((_ble_complete_sabbrev_version++))
    fi
  else
    ble/gdict#clear _ble_complete_sabbrev
    ((_ble_complete_sabbrev_version++))
  fi
  return 0
}
## @fn ble/complete/sabbrev#get key [type]
function ble/complete/sabbrev#get {
  local key=$1
  ble/gdict#get _ble_complete_sabbrev "$key" &&
    [[ ! ${2-} || $ret == ["$2"]:* ]]
}

## @fn ble/complete/sabbrev#get-keys [type]
##   @arr[out] keys
function ble/complete/sabbrev#get-keys {
  keys=()
  local type=${1-} ret
  ble/gdict#keys _ble_complete_sabbrev
  if [[ $type ]]; then
    local key
    for key in "${ret[@]}"; do
      ble/gdict#get _ble_complete_sabbrev "$key" &&
        [[ $ret == ["$type"]:* ]] &&
        ble/array#push keys "$key"
    done
  else
    keys=("${ret[@]}")
  fi
}

function ble/complete/sabbrev/wordwise.get-keys {
  ble/complete/sabbrev#get-keys 'wm'
}

## @fn ble/complete/sabbrev/suffix.construct-regex
##   Generate a regular expression that matches any of the registered suffix
##   sabbrevs.
##   @var[out] ret
##     Stores the generated regular expressions
##   @var[ref] _ble_complete_sabbrev_suffix_regex
##     This array is used to cache the regular expression
_ble_complete_sabbrev_suffix_regex=()
function ble/complete/sabbrev/suffix.construct-regex {
  if [[ ${_ble_complete_sabbrev_suffix_regex[1]} != "$_ble_complete_sabbrev_version" ]]; then
    local keys out=
    ble/complete/sabbrev#get-keys 's'
    if ((${#keys[@]})); then
      local key
      for key in "${keys[@]}"; do
        if [[ $key ]]; then
          ble/string#escape-for-extended-regex "$key"
          out=${out:+$out'|'}$ret
        fi
      done
    fi
    _ble_complete_sabbrev_suffix_regex[0]=${out:+'\.('$out')$'}
    _ble_complete_sabbrev_suffix_regex[1]=$_ble_complete_sabbrev_version
  fi

  ret=${_ble_complete_sabbrev_suffix_regex[0]}
  [[ $ret ]]
}

## @fn ble/complete/sabbrev/literal.find str [opts]
## @fn ble/complete/sabbrev/suffix.find str [opts]
## Get the longest matching literal abbreviation and its value.
##   @param[in] str
##   @param[in,opt] opts
## Colon-separated options.
##
##     filter-by-patterns
## Match only sabbrevs that match the patterns specified in the patterns array
## Let's say.
##       @arr[in] patterns
##
##     literal
## Indicates that the specified word is already an expanded value.
##
##   @var[out] key1 ent1
##
function ble/complete/sabbrev/literal.find {
  local str=$1 opts=$2
  ble/complete/sabbrev#match "$str" 'il' "$opts"
}
function ble/complete/sabbrev/suffix.is-normal-command {
  ble/bin#has "$1" ||
    { ble/util/joblist.check; jobs -- "$1" &>/dev/null; } ||
    { [[ -d $1 ]] && shopt -q autocd &>/dev/null; }
}
function ble/complete/sabbrev/suffix.find {
  key1= ent1=
  local file=$1 opts=$2 ret
  [[ :$opts: != *:literal:* ]] &&
    ble/syntax:bash/simple-word/safe-eval "$file" &&
    file=$ret

  [[ $file == *.* ]] || return 1

  # If the command name can be interpreted normally, we do not try to expand
  # the command name.  This is to avoid mistakenly change the files in the
  # current directory, which accidentally matches a real command.
  ble/complete/sabbrev/suffix.is-normal-command "$file" && return 1

  ble/complete/sabbrev#match "$file" 's' "$opts"
}

## @fn ble/complete/sabbrev#match str type [opts]
function ble/complete/sabbrev#match {
  key1= ent1=
  local target=$1 type=$2 opts=$3 keys
  ble/complete/sabbrev#get-keys "$type"
  local key2 ent2 ret
  for key2 in "${keys[@]}"; do
    ((${#key2}>${#key1})) || continue
    ble/gdict#get _ble_complete_sabbrev "$key2" || continue; ent2=$ret

    case $ent2 in
    (i:*) [[ $target == *"$key2" ]] ;;
    (l:*) [[ $target == *"$key2" ]] && ble/string#match "${target%"$key2"}" $'(^|\n)[ \t]*$' ;;
    (s:*) [[ $target == *."$key2" ]] ;;
    (*)   [[ $target == "$key2" ]] ;;
    esac || continue

    [[ :$opts: == *:filter-by-patterns:* ]] &&
      ((${#patterns[@]})) &&
      ! ble/complete/string#match-patterns "$key2" "${patterns[@]}" &&
      continue

    key1=$key2 ent1=$ent2
  done

  [[ $key1 ]]
}

## @fn ble/complete/sabbrev/read-arguments/.set-type opt
##   @var[in,out] flags type
function ble/complete/sabbrev/read-arguments/.set-type {
  local new_type
  case $1 in
  (--type=wordwise | -w) new_type=w ;;
  (--type=dynamic  | -m) new_type=m ;;
  (--type=inline   | -i) new_type=i ;;
  (--type=linewise | -l) new_type=l ;;
  (--type=suffix   | -s) new_type=s ;;
  (*)
    ble/util/print "ble-sabbrev: unknown sabbrev type '${1#--type=}'." >&2
    flags=E$flags
    return  1 ;;
  esac

  if [[ $type && $type != "$new_type" ]]; then
    ble/util/print "ble-sabbrev: arg $1: a conflicting sabbrev type (-$type) has already been specified." >&2
    flags=E$flags
  fi
  type=$new_type
}

## @fn ble/complete/sabbrev/read-arguments args...
##   @arr[out] specs print
##   @var[out] flags type
function ble/complete/sabbrev/read-arguments {
  specs=() print=()
  flags= type=
  while (($#)); do
    local arg=$1; shift
    if [[ $flags != L && $arg == -* ]]; then
      case $arg in
      (--)
        flags=L$flags ;;
      (--help)
        flags=H$flags ;;
      (--reset)
        flags=r$flags
      (--color|--color=always)
        flags=c${flags//[cn]} ;;
      (--color=never)
        flags=n${flags//[cn]} ;;
      (--color=auto)
        flags=${flags//[cn]} ;;
      (--color=*)
        ble/util/print "ble-sabbrev: unknown color type '$arg'." >&2
        flags=E$flags ;;
      (--type=*)
        ble/complete/sabbrev/read-arguments/.set-type "$arg" ;;
      (--type)
        if ((!$#)); then
          ble/util/print "ble-sabbrev: option argument for '$arg' is missing" >&2
          flags=E$flags
        else
          ble/complete/sabbrev/read-arguments/.set-type "--type=$1"; shift
        fi ;;
      (--*)
        ble/util/print "ble-sabbrev: unknown option '$arg'." >&2
        flags=E$flags ;;
      (-*)
        local i n=${#arg} c
        for ((i=1;i<n;i++)); do
          c=${arg:i:1}
          case $c in
          ([wmils]) ble/complete/sabbrev/read-arguments/.set-type "-$c" ;;
          (r) flags=r$flags ;;
          (*)
            ble/util/print "ble-sabbrev: unknown option '-$c'." >&2
            flags=E$flags ;;
          esac
        done ;;
      esac
    else
      if [[ $arg == ?*=* ]]; then
        ble/array#push specs "$arg"
      else
        ble/array#push print "$arg"
      fi
    fi
  done
  return 0
}

## @fn ble-sabbrev key=value
## Register static abbreviation expansion.
function ble/complete/sabbrev {
  local flags type specs print
  ble/complete/sabbrev/read-arguments "$@"
  if [[ $flags == *H* || $flags == *E* ]]; then
    [[ $flags == *E* ]] && ble/util/print
    ble/util/print-lines \
      'usage: ble-sabbrev [--type=TYPE|-wmils] [KEY=VALUE]...' \
      'usage: ble-sabbrev [-r|--reset] [--type=TYPE|-wmils|KEY...]' \
      'usage: ble-sabbrev [--color[=auto|always|never]] [--type=TYPE|-wmils|KEY...]' \
      'usage: ble-sabbrev --help' \
      '     Register sabbrev expansion.' \
      '' \
      'OPTIONS' \
      '  -w, --type=wordwise   replace matching word.' \
      '  -m, --type=dynamic    run command and replace matching word.' \
      '  -i, --type=inline     replace matching suffix.' \
      '  -l, --type=linewise   replace matching line.' \
      '  -s, --type=suffix     replace word with extension in the command position.' \
      '' \
      '  -r, --reset           remove specified set of sabbrev.' \
      '' \
      '  --color=always         enable color output.' \
      '  --color=never          disable color output.' \
      '  --color, --color=auto  automatically determine color output (default).' \
      ''
    [[ ! $flags == *E* ]]; return "$?"
  fi

  local ext=0
  if ((${#specs[@]}==0||${#print[@]})); then
    if [[ $flags == *r* ]]; then
      ble/complete/sabbrev/reset "$type" "${print[@]}"
    else
      ble/complete/sabbrev/list "$type" "${print[@]}"
    fi || ext=$?
  fi

  local spec key value
  for spec in "${specs[@]}"; do
    # spec is of the form key=value
    key=${spec%%=*} value=${spec#*=}
    ble/complete/sabbrev/register "$key" "${type:-w}:$value"
  done
  return "$ext"
}
function ble-sabbrev {
  builtin eval -- "$_ble_bash_POSIXLY_CORRECT_local_adjust"
  ble/complete/sabbrev "$@"
  builtin eval -- "$_ble_bash_POSIXLY_CORRECT_local_return"
}

## @fn ble/complete/sabbrev/locate-key rex_source_type
## @var[out] pos
## @var[in] comp_index comp_text
function ble/complete/sabbrev/locate-key {
  pos=$comp_index
  local rex_source_type='^('$1')$'
  local sources src asrc
  ble/complete/context:syntax/generate-sources
  for src in "${sources[@]}"; do
    ble/string#split-words asrc "$src"
    [[ ${asrc[0]} =~ $rex_source_type ]] || continue

    if [[ ${asrc[0]} == argument ]]; then
      # When source:argument and variable assignment format, the right side is the target of sabbrev.
      # Call find-rhs with wtype set to ATTR_VAR (just like an argument to declare)
      # vinegar.
      local wtype=$_ble_attr_VAR wbeg=${asrc[1]} wlen=$((comp_index-asrc[1])) ret
      ble/syntax:bash/find-rhs "$wtype" "$wbeg" "$wlen" long-option &&
        asrc[0]=rhs asrc[1]=$ret
    fi

    if [[ ${asrc[0]} == rhs ]]; then
      # On the right side of the variable assignment format, the last field separated by : is targeted. the last
      # Skip to unquoted colon. [Note: If you refer to the grammar information, it will be more precise.
      # I may be able to decide, but I won't implement it for now]
      local rex_element
      ble/syntax:bash/simple-word/get-rex_element :
      local rex='^:*('$rex_element':+)'
      [[ ${_ble_edit_str:asrc[1]:comp_index-asrc[1]} =~ $rex ]] &&
        ((asrc[1]+=${#BASH_REMATCH}))
    fi

    ((asrc[1]<pos)) && pos=${asrc[1]}
  done
  ((pos<comp_index))
}

## @fn ble/complete/sabbrev/expand [opts]
##   @param[in,opt] opts
## Colon-separated options.
##
##     wordwise
##     literal
## Expanding wordwise sabbrev and literal sabbrev (line, inline) respectively
## Execute. If neither is specified, both will be executed.
##
##     pattern=PATTERN
## If one or more of these is specified, it will have the name specified by any PATTERN.
## Enable only one sabbrev.
##
##     strip-slash
## Delete the trailing / after expansion.
##
##     type-status
## Returns the type of sabbrev executed in the exit status.
##
function ble/complete/sabbrev/expand {
  local opts=$1
  local comp_index=$_ble_edit_ind comp_text=$_ble_edit_str

  [[ :$opts: == *:wordwise:* || :$opts: == *:literal:* || :$opts: == *:suffix:* ]] ||
    opts=$opts:wordwise:literal:suffix

  local -a patterns=()
  local ret
  ble/opts#extract-all-optargs "$opts" pattern &&
    patterns=("${ret[@]}")

  # Search matching wordwise/literal/suffix sabbrevs and pick the longest one.
  # When they have the same lengths, the priority is wordwise > suffix >
  # literal.
  local key= ent= pos_wbegin=
  if [[ :$opts: == *:wordwise:* ]]; then
    local pos key1 ret
    ble/complete/sabbrev/locate-key 'file|command|argument|variable:w|wordlist:.*|sabbrev|rhs' &&
      key1=${_ble_edit_str:pos:comp_index-pos} &&
      ble/complete/sabbrev#get "$key1" 'wm' &&
      { ((${#patterns[@]}==0)) || ble/complete/string#match-patterns "$key1" "${patterns[@]}"; } &&
      ((${#key1}>${#key})) && key=$key1 ent=$ret pos_wbegin=$pos
  fi
  if [[ :$opts: == *:suffix:* ]]; then
    local pos key1 ent1
    ble/complete/sabbrev/locate-key 'command' &&
      ble/complete/sabbrev/suffix.find "${_ble_edit_str:pos:comp_index-pos}" filter-by-patterns &&
      ((${#key1}>${#key})) && key=$key1 ent=$ent1 pos_wbegin=$pos
  fi
  if [[ :$opts: == *:literal:* ]]; then
    local key1 ent1
    ble/complete/sabbrev/literal.find "${_ble_edit_str::comp_index}" filter-by-patterns &&
      ((${#key1}>${#key})) && key=$key1 ent=$ent1
  fi
  [[ $key ]] || return 1

  local type=${ent%%:*} value=${ent#*:}

  local exit=0
  if [[ :$opts: == *:type-status:* ]]; then
    local ret
    ble/util/s2c "$type"
    exit=$ret
  fi

  case $type in
  ([wil])
    [[ :$opts: == *:strip-slash:* ]] && value=${value%/}
    local pos=$((comp_index-${#key}))
    ble/widget/.replace-range "$pos" "$comp_index" "$value"
    ((_ble_edit_ind=pos+${#value})) ;;
  (s)
    ble/widget/.replace-range "$pos_wbegin" "$pos_wbegin" "$value "
    ((_ble_edit_ind=comp_index+${#value}+1)) ;;
  (m)
    # prepare completion context
    local pos=$pos_wbegin
    local comp_type= comps_flags= comps_fixed=
    local COMP1=$pos COMP2=$pos COMPS=$key COMPV=
    ble/complete/candidates/comp_type#read-rl-variables

    local flag_force_fignore=
    local flag_source_filter=1

    # construct cand_pack
    local cand_count cand_cand cand_word cand_pack
    ble/complete/candidates/clear
    local COMP_PREFIX=

    # local settings
    local bleopt_sabbrev_menu_style=$bleopt_complete_menu_style
    local bleopt_sabbrev_menu_opts=

    # generate candidates
    # Ask COMPREPLY to add suggestions, or
    # Or have them call ble/complete/cand/yield etc. manually.
    local -a COMPREPLY=()
    builtin eval -- "$value"

    local cand action=word "${_ble_complete_yield_varnames[@]/%/=}" # WA #D1570 checked
    ble/complete/cand/yield.initialize "$action"
    for cand in "${COMPREPLY[@]}"; do
      ble/complete/cand/yield "$action" "$cand" ""
    done

    if ((cand_count==0)); then
      return 1
    elif ((cand_count==1)); then
      local value=${cand_word[0]}
      [[ :$opts: == *:strip-slash:* ]] && value=${value%/}
      ble/widget/.replace-range "$pos" "$comp_index" "$value"
      ((_ble_edit_ind=pos+${#value}))
      return "$exit"
    fi

    # Note: Existing content (key) will be deleted
    ble/widget/.replace-range "$pos" "$comp_index" ''

    local bleopt_complete_menu_style=$bleopt_sabbrev_menu_style
    local menu_common_part=
    ble/complete/menu/show init || return "$?"
    [[ :$bleopt_sabbrev_menu_opts: == *:enter_menu:* ]] &&
      ble/complete/menu-complete/enter "$bleopt_sabbrev_menu_opts"
    return 147 ;;
  (*) return 1 ;;
  esac
  return "$exit"
}
function ble/widget/sabbrev-expand {
  ble/complete/sabbrev/expand; local ext=$?
  ((ext)) && ble/widget/.bell
  return "$ext"
}

# Completion candidates for sabbrev
function ble/complete/action:sabbrev/initialize { CAND=$value; }
function ble/complete/action:sabbrev/complete { return 0; }
function ble/complete/action:sabbrev/init-menu-item {
  local ret; ble/color/face2g command_alias; g=$ret
  show=$INSERT
}
function ble/complete/action:sabbrev/get-desc {
  local ret; ble/complete/sabbrev#get "$INSERT"
  desc="$desc_sgrt(sabbrev)$desc_sgr0 $ret"
}
function ble/complete/source:sabbrev {
  local opts=$bleopt_complete_source_sabbrev_opts
  [[ ! $COMPS && :$opts: == *:no-empty-completion:* ]] && return 1

  local keys; ble/complete/sabbrev/wordwise.get-keys "$opts"

  local filter_type=$comp_filter_type
  [[ $filter_type == none ]] && filter_type=head
  local comps_fixed=

  # Reinitialize filtering settings with COMPS
  local comp_filter_type
  local comp_filter_pattern
  ble/complete/candidates/filter#init "$filter_type" "$COMPS"
  local cand action=sabbrev "${_ble_complete_yield_varnames[@]/%/=}" # WA #D1570 checked
  ble/complete/cand/yield.initialize "$action"
  for cand in "${keys[@]}"; do
    ble/complete/candidates/filter#test "$cand" || continue
    ble/complete/string#match-patterns "$cand" "${_ble_complete_source_sabbrev_ignore[@]}" && continue

    # In order to not be excluded by filter, it is necessary to enter the value after evaluation in cand.
    local ret simple_flags simple_ibrace
    ble/syntax:bash/simple-word/reconstruct-incomplete-word "$cand" &&
      ble/complete/source/eval-simple-word "$ret" single || continue

    local value=$ret # referenced in "ble/complete/action:sabbrev/initialize"
    local flag_source_filter=1
    ble/complete/cand/yield "$action" "$cand"
  done
}

function ble/complete/expand/expand-command-name {
  local map=$1 opts=${2-}

  # magic-accept
  if [[ :$opts: == *:accept:* ]]; then
    ble-edit/content/expand-command-name "$map"
    return "$?"
  fi

  local pos comp_index=$_ble_edit_ind comp_text=$_ble_edit_str
  ble/complete/sabbrev/locate-key 'command'
  ((pos<comp_index)) || return 1

  local word=${_ble_edit_str:pos:comp_index-pos}
  local ret
  "$map" "$word" && [[ $ret != "$word" ]] || return 1
  ble/widget/.replace-range "$pos" "$comp_index" "$ret"
  return 0
}

## @fn ble/complete/expand:NAME [opts]
##   @param[in] opts
##     @opt accept
##       This is specified when the expansion is called from the accept-line
##       widget for the magic-accept feature.  When this is specified, one can
##       attempt the global expansion regardless of the current cursor
##       position.  This is not specified when the expansion is called from
##       magic-space, where only the expansion before the current cursor
##       position should be attempted.

function ble/complete/expand:alias {
  ble/complete/expand/expand-command-name 'ble/alias#expand' "$1"
}

## @fn ble/complete/expand:autocd/.map word
##   @var[out] ret
function ble/complete/expand:autocd/.map {
  ble/syntax:bash/simple-word/safe-eval "$1" nonull || return 1

  [[ $ret && -d $ret ]] && ! ble/bin#has "$ret" || return 1

  if [[ $ret == -* ]]; then
    ret="cd -- $1"
  else
    ret="cd $1"
  fi
}

function ble/complete/expand:autocd {
  ble/complete/expand/expand-command-name 'ble/complete/expand:autocd/.map' "$1"
}

#------------------------------------------------------------------------------
#
# dabbrev
#

_ble_complete_dabbrev_original=
_ble_complete_dabbrev_regex1=
_ble_complete_dabbrev_regex2=
_ble_complete_dabbrev_index=
_ble_complete_dabbrev_pos=
_ble_complete_dabbrev_stack=()

function ble/complete/dabbrev/.show-status.fib {
  local index='!'$((_ble_complete_dabbrev_index+1))
  local nmatch=${#_ble_complete_dabbrev_stack[@]}
  local needle=$_ble_complete_dabbrev_original
  local text="(dabbrev#$nmatch: << $index) \`$needle'"

  local pos=$1
  if [[ $pos ]]; then
    local count; ble/history/get-count
    local percentage=$((count?pos*1000/count:1000))
    text="$text searching... @$pos ($((percentage/10)).$((percentage%10))%)"
  fi

  ((fib_ntask)) && text="$text *$fib_ntask"

  ble/edit/info/show text "$text"
}
function ble/complete/dabbrev/show-status {
  local fib_ntask=${#_ble_util_fiberchain[@]}
  ble/complete/dabbrev/.show-status.fib
}
function ble/complete/dabbrev/erase-status {
  ble/edit/info/default
}

## @fn ble/complete/dabbrev/initialize-variables
function ble/complete/dabbrev/initialize-variables {
  # Note: Since _ble_term_IFS is prefixed, it is guaranteed that ! or ^ does not come at the beginning.
  local wordbreaks; ble/complete/get-wordbreaks
  _ble_complete_dabbrev_wordbreaks=$wordbreaks

  local left=${_ble_edit_str::_ble_edit_ind}
  local original=${left##*[$wordbreaks]}
  local p1=$((_ble_edit_ind-${#original})) p2=$_ble_edit_ind
  _ble_edit_mark=$p1
  _ble_edit_ind=$p2
  _ble_complete_dabbrev_original=$original

  local ret; ble/string#escape-for-extended-regex "$original"
  local needle='(^|['$wordbreaks'])'$ret
  _ble_complete_dabbrev_regex1=$needle
  _ble_complete_dabbrev_regex2='('$needle'[^'$wordbreaks']*).*'

  local index; ble/history/get-index
  _ble_complete_dabbrev_index=$index
  _ble_complete_dabbrev_pos=${#_ble_edit_str}

  _ble_complete_dabbrev_stack=()
}

function ble/complete/dabbrev/reset {
  local original=$_ble_complete_dabbrev_original
  ble-edit/content/replace "$_ble_edit_mark" "$_ble_edit_ind" "$original"
  ((_ble_edit_ind=_ble_edit_mark+${#original}))
  _ble_edit_mark_active=
}

## @fn ble/complete/dabbrev/search-in-history-entry line index
##   @param[in] line
## Specify the content to search for.
##   @param[in] index
## Specify the history number to search.
##   @var[in] dabbrev_current_match
## Specifies the current match.
##   @var[in] dabbrev_pos
## Specifies the starting position within the history item.
##   @var[out] dabbrev_match
## If there is a match, return the matched content.
##   @var[out] dabbrev_match_pos
## If there is a match, returns the last position of the matching range.
## This corresponds to the next search start position.
function ble/complete/dabbrev/search-in-history-entry {
  local line=$1 index=$2

  # Does not match the currently edited line itself.
  local index_editing; ble/history/get-index -v index_editing
  if ((index!=index_editing)); then
    local pos=$dabbrev_pos
    while [[ ${line:pos} && ${line:pos} =~ $_ble_complete_dabbrev_regex2 ]]; do
      local rematch1=${BASH_REMATCH[1]} rematch2=${BASH_REMATCH[2]}
      local match=${rematch1:${#rematch2}}
      if [[ $match && $match != "$dabbrev_current_match" ]]; then
        dabbrev_match=$match
        dabbrev_match_pos=$((${#line}-${#BASH_REMATCH}+${#match}))
        return 0
      else
        ((pos++))
      fi
    done
  fi

  return 1
}

function ble/complete/dabbrev/.search.fib {
  if [[ ! $fib_suspend ]]; then
    local start=$_ble_complete_dabbrev_index
    local index=$_ble_complete_dabbrev_index
    local pos=$_ble_complete_dabbrev_pos

    # Note: start is the index at which backward-history-search is called for the first time.
    # index-- before backward-history-search is called, so
    # Define start by decreasing it by 1 from the beginning.
    # This ensures that a cyclic search will match you again.
    # Note: If start is now negative, set the "number of history items".
    # The latest item not yet registered in "history" (_ble_history_edit
    # ) is also included in the search.
    ((--start>=0)) || ble/history/get-count -v start
  else
    local start index pos; builtin eval -- "$fib_suspend"
    fib_suspend=
  fi

  local dabbrev_match=
  local dabbrev_pos=$pos
  local dabbrev_current_match=${_ble_edit_str:_ble_edit_mark:_ble_edit_ind-_ble_edit_mark}

  local line; ble/history/get-edited-entry -v line "$index"
  if ! ble/complete/dabbrev/search-in-history-entry "$line" "$index"; then
    ((index--,dabbrev_pos=0))

    local isearch_time=0
    local isearch_opts=stop_check:cyclic

    # Setting match judgment based on conditions
    isearch_opts=$isearch_opts:condition
    local dabbrev_original=$_ble_complete_dabbrev_original
    local dabbrev_regex1=$_ble_complete_dabbrev_regex1
    local needle='[[ $LINE =~ $dabbrev_regex1 ]] && ble/complete/dabbrev/search-in-history-entry "$LINE" "$INDEX"'
    # Note: It is faster to prune with glob first.
    [[ $dabbrev_original ]] && needle='[[ $LINE == *"$dabbrev_original"* ]] && '$needle

    # Displaying search progress
    isearch_opts=$isearch_opts:progress
    local isearch_progress_callback=ble/complete/dabbrev/.show-status.fib

    ble/history/isearch-backward-blockwise "$isearch_opts"; local ext=$?
    ((ext==148)) && fib_suspend="start=$start index=$index pos=$pos"
    if ((ext)); then
      if ((${#_ble_complete_dabbrev_stack[@]})); then
        ble/widget/.bell #It's gone around so I'll ring it.
        return 0
      else
        # If none are found
        return "$ext"
      fi
    fi
  fi

  local rec=$_ble_complete_dabbrev_index,$_ble_complete_dabbrev_pos,$_ble_edit_ind,$_ble_edit_mark
  ble/array#push _ble_complete_dabbrev_stack "$rec:$_ble_edit_str"
  local insert; ble-edit/content/replace-limited "$_ble_edit_mark" "$_ble_edit_ind" "$dabbrev_match"
  ((_ble_edit_ind=_ble_edit_mark+${#insert}))

  ((index>_ble_complete_dabbrev_index)) &&
    ble/widget/.bell #laps
  _ble_complete_dabbrev_index=$index
  _ble_complete_dabbrev_pos=$dabbrev_match_pos

  ble/textarea#redraw
}
function ble/complete/dabbrev/next.fib {
  ble/complete/dabbrev/.search.fib; local ext=$?
  if ((ext==0)); then
    _ble_edit_mark_active=insert
    ble/complete/dabbrev/.show-status.fib
  elif ((ext==148)); then
    ble/complete/dabbrev/.show-status.fib
  else
    ble/widget/.bell
    ble/widget/dabbrev/exit
    ble/complete/dabbrev/reset
    fib_kill=1
  fi
  return "$ext"
}
function ble/widget/dabbrev-expand {
  ble/complete/dabbrev/initialize-variables
  ble/decode/keymap/push dabbrev
  ble/util/fiberchain#initialize ble/complete/dabbrev
  ble/util/fiberchain#push next
  ble/util/fiberchain#resume
}
function ble/widget/dabbrev/next {
  ble/util/fiberchain#push next
  ble/util/fiberchain#resume
}
function ble/widget/dabbrev/prev {
  if ((${#_ble_util_fiberchain[@]})); then
    # If there are items being processed, cancel them one by one.
    local ret; ble/array#pop _ble_util_fiberchain
    if ((${#_ble_util_fiberchain[@]})); then
      ble/util/fiberchain#resume
    else
      ble/complete/dabbrev/show-status
    fi
  elif ((${#_ble_complete_dabbrev_stack[@]})); then
    # Go back when there is a previous match
    local ret; ble/array#pop _ble_complete_dabbrev_stack
    local rec str=${ret#*:}
    ble/string#split rec , "${ret%%:*}"
    ble-edit/content/reset-and-check-dirty "$str"
    _ble_edit_ind=${rec[2]}
    _ble_edit_mark=${rec[3]}
    _ble_complete_dabbrev_index=${rec[0]}
    _ble_complete_dabbrev_pos=${rec[1]}
    ble/complete/dabbrev/show-status
  else
    ble/widget/.bell
    return 1
  fi
}
function ble/widget/dabbrev/cancel {
  if ((${#_ble_util_fiberchain[@]})); then
    ble/util/fiberchain#clear
    ble/complete/dabbrev/show-status
  else
    ble/widget/dabbrev/exit
    ble/complete/dabbrev/reset
  fi
}
function ble/widget/dabbrev/exit {
  ble/decode/keymap/pop
  _ble_edit_mark_active=
  ble/complete/dabbrev/erase-status
}
function ble/widget/dabbrev/exit-default {
  ble/widget/dabbrev/exit
  ble/decode/widget/redispatch
}
function ble/widget/dabbrev/accept-line {
  ble/widget/dabbrev/exit
  ble-decode-key 13
}
function ble-decode/keymap:dabbrev/define {
  ble-bind -f __default__ 'dabbrev/exit-default'
  ble-bind -f __line_limit__ nop
  ble-bind -f 'C-g'       'dabbrev/cancel'
  ble-bind -f 'C-x C-g'   'dabbrev/cancel'
  ble-bind -f 'C-M-g'     'dabbrev/cancel'
  ble-bind -f C-r         'dabbrev/next'
  ble-bind -f C-s         'dabbrev/prev'
  ble-bind -f RET         'dabbrev/exit'
  ble-bind -f C-m         'dabbrev/exit'
  ble-bind -f C-RET       'dabbrev/accept-line'
  ble-bind -f C-j         'dabbrev/accept-line'
}

#------------------------------------------------------------------------------
# default cmdinfo/complete

## @fn ble/cmdinfo/complete/yield-flag cmd flags [opts]
## Complete the X in "-${flags}X".
##   @param[in] cmd
## mandb Command name used for search
##   @param[in] flags
## List of possible option characters
##   @param[in,opt] opts
## colon separated list
##
##     dedup[=XFLAGS]
## Excludes any exclusive flags that have already been specified. XFLAGS has exclusive flags
## Specify a set. If omitted or an empty string is specified, all flags are exclusive.
## considered to be the target.
##
##     cancel-on-empty
## Cancel completion candidate generation if there are no more candidate flags. By default,
## If there are no more candidate flags, the currently entered content will be completed.
##
##     hasarg=AFLAGS
## Specifies a collection of flags with optional arguments. sentences contained in this character set
## The option is not completed if the character is already specified in COMPV.
##
##   @var[in] COMPV

ble/complete/action#inherit-from mandb.flag mandb
function ble/complete/action:mandb.flag/initialize {
  ble/complete/action:mandb/initialize "$@"
}
function ble/complete/action:mandb.flag/init-menu-item {
  ble/complete/action:mandb/init-menu-item
  prefix=${CAND::!!PREFIX_LEN}
}

function ble/cmdinfo/complete/yield-flag {
  local cmd=$1 flags=$2 opts=$3
  [[ $COMPV != [!-]* && $COMPV != --* && $flags ]] || return 1

  local "${_ble_complete_yield_varnames[@]/%/=}" # WA #D1570 checked
  ble/complete/cand/yield.initialize mandb

  # opts dedup
  local ret
  if [[ ${COMPV:1} ]] && ble/opts#extract-last-optarg "$opts" dedup "$flags"; then
    local specified_flags=${ret//[!"${COMPV:1}"]}
    flags=${flags//["$specified_flags"]}
  fi

  if ble/opts#extract-last-optarg "$opts" hasarg; then
    [[ $COMPV == -*["$ret"]* ]] && return 1
  fi

  if [[ ! $flags ]]; then
    [[ :$opts: == *:cancel-on-empty:* ]] && return 1

    # If there are no more candidate flags, the current content is determined as unique.
    local "${_ble_complete_yield_varnames[@]/%/=}" # WA #D1570 checked
    ble/complete/cand/yield.initialize word
    ble/complete/cand/yield word "$COMPV"
    return "$?"
  fi

  local COMP_PREFIX=$COMPV

  # If desc is found in mandb, apply it
  local has_desc=
  if local ret; ble/complete/mandb/load-cache "$cmd"; then
    local entry fs=$_ble_term_FS
    for entry in "${ret[@]}"; do
      ((cand_iloop++%bleopt_complete_polling_cycle==0)) &&
        ble/complete/check-cancel && return 148
      local option=${entry%%$fs*}
      [[ $option == -? && ${option:1} == ["$flags"] ]] || continue
      ble/complete/cand/yield mandb.flag "$COMPV${option:1}" "$entry"
      [[ $entry == *"$fs"*"$fs"*"$fs"?* ]] && has_desc=1
      flags=${flags//${option:1}}
    done
    [[ $has_desc ]] && bleopt complete_menu_style=desc
  fi

  # If not found, generate without explanation
  local i
  for ((i=0;i<${#flags};i++)); do
    ble/complete/cand/yield mandb.flag "$COMPV${flags:i:1}"
  done
}


# action:cdpath (fix action:file)

function ble/complete/action:cdpath/initialize {
  DATA=$cdpath_basedir
  ble/complete/action:file/initialize
}
function ble/complete/action:cdpath/complete {
  CAND=$DATA$CAND ble/complete/action:file/complete
}
function ble/complete/action:cdpath/init-menu-item {
  ble/color/face2g cmdinfo_cd_cdpath; g=$ret
  if [[ :$comp_type: == *:vstat:* ]]; then
    if [[ -h $CAND ]]; then
      suffix='@'
    elif [[ -d $CAND ]]; then
      suffix='/'
    fi
  fi
}
function ble/complete/action:cdpath/get-desc {
  local sgr0=$_ble_term_sgr0 sgr1= sgr2=
  local g ret g1 g2
  ble/syntax/highlight/getg-from-filename "$DATA$CAND"; g1=$g
  [[ $g1 ]] || { ble/color/face2g filename_warning; g1=$ret; }
  ((g2=g1^_ble_color_gflags_Revert))
  ble/color/g2sgr "$g1"; sgr1=$ret
  ble/color/g2sgr "$g2"; sgr2=$ret
  ble/string#escape-for-display "$DATA$CAND" sgr1="$sgr2":sgr0="$sgr1"
  local filename=$sgr1$ret$sgr0

  CAND=$DATA$CAND ble/complete/action:file/get-desc
  desc="CDPATH $filename ($desc)"
}

function ble/cmdinfo/complete:cd/generate-cdable_vars {
  shopt -q cdable_vars || return 1
  ble/string#match "$COMPV" '^[_a-zA-Z0-9][_a-zA-Z0-9]*$' || return 1
  local arr
  ble/util/compgen arr -vX "_ble*" -- "$COMPV"

  ble/complete/source/test-limit "${#arr[@]}" || return 1

  local action=file old_cand_count=$cand_count
  local cand "${_ble_complete_yield_varnames[@]/%/=}" # WA #D1570 checked
  ble/complete/cand/yield.initialize "$action"
  for cand in "${arr[@]}"; do
    ((cand_iloop++%bleopt_complete_polling_cycle==0)) && ble/complete/check-cancel && return 148
    [[ $cand == "$COMPV"?* && -d ${!cand-} ]] &&
      ble/complete/cand/yield "$action" "$cand" "$data"
  done
  ((cand_count>old_cand_count))
}

## @fn ble/cmdinfo/complete:cd/.impl
##   @remarks
## This implementation is based on ble/complete/source:file.
## Please also refer to this original implementation for notes on implementation.
function ble/cmdinfo/complete:cd/.impl {
  local type=$1
  [[ $comps_flags == *v* ]] || return 1

  local old_cand_count=$cand_count

  case $type in
  (pushd|popd|dirs)
    # todo: do not process [-+]* after --
    # todo: Actually -N/+N is not an option but a regular argument
    if [[ $COMPV == [-+]* ]]; then
      # yield options
      local flags=n
      [[ $type == dirs ]] && flags=clpv
      ble/cmdinfo/complete/yield-flag "$type" "$flags" dedup:hasarg=0123456789:cancel-on-empty

      local "${_ble_complete_yield_varnames[@]/%/=}" # WA #D1570 checked
      ble/complete/cand/yield.initialize word
      local ret
      ble/color/face2sgr-ansi filename_directory
      local sgr1=$ret sgr0=$'\e[m'

      # yield -N/+N
      local i n=${#DIRSTACK[@]}
      for ((i=0;i<n;i++)); do
        local cand=${COMPV::1}$i
        [[ $cand == "$COMPV"* ]] || continue
        local j=$i; [[ $COMPV == -* ]] && j=$((n-1-i))
        ble/complete/cand/yield word "$cand" "DIRSTACK[$j] $sgr1${DIRSTACK[j]}$sgr0"
      done

      # yield - and -- for pushd
      if [[ $type == pushd ]]; then
        [[ ${OLDPWD:-} && $COMPV == - ]] &&
          ble/complete/cand/yield word - "OLDPWD $sgr1$OLDPWD$sgr0"
        [[ -- == "$COMPV"* ]] &&
          ble/complete/cand/yield word -- '(indicate the end of options)'
      fi

      ((cand_count!=old_cand_count)) && return 0
    fi
    [[ $type == pushd ]] || return 0 ;;
  (*)
    # todo: do not process [-+]* after --
    if [[ $COMPV == -* ]]; then
      local list=LP
      ((_ble_bash>=40200)) && list=${list}e
      ((_ble_bash>=40300)) && list=${list}@
      ble/cmdinfo/complete/yield-flag cd "$list" dedup

      local "${_ble_complete_yield_varnames[@]/%/=}" # WA #D1570 checked
      ble/complete/cand/yield.initialize word
      if [[ ${OLDPWD:-} && $COMPV == - ]]; then
        local ret
        ble/color/face2sgr-ansi filename_directory
        local sgr1=$ret sgr0=$'\e[m'
        ble/complete/cand/yield word - "OLDPWD $sgr1$OLDPWD$sgr0"
      fi
      [[ -- == "$COMPV"* ]] &&
        ble/complete/cand/yield word -- '(indicate the end of options)'

      return 0
    fi
  esac

  [[ :$comp_type: != *:[maA]:* && $COMPV =~ ^.+/ ]] && COMP_PREFIX=${BASH_REMATCH[0]}
  [[ :$comp_type: == *:[maA]:* && ! $COMPV ]] && return 1

  if [[ ! $CDPATH ]]; then
    ble/complete/source:dir || return "$?"
    ((cand_count>old_cand_count)) && return 0
    ble/cmdinfo/complete:cd/generate-cdable_vars
    return "$?"
  fi

  ble/complete/source:tilde; local ext=$?
  ((ext==148||ext==0)) && return "$ext"

  local is_pwd_visited= is_cdpath_generated=
  "${_ble_util_set_declare[@]//NAME/visited}" # WA #D1570 checked

  # Check CDPATH first
  local name names; ble/string#split names : "$CDPATH"
  for name in "${names[@]}"; do
    [[ $name ]] || continue
    name=${name%/}/

    # If the current directory is included in CDPATH, register with action=file
    local action=cdpath
    [[ ${name%/} == . || ${name%/} == "${PWD%/}" ]] &&
      is_pwd_visited=1 action=file

    local -a candidates=()
    local ret cand
    ble/complete/source:file/generate "$COMPV" '' "$name"; (($?==148)) && return 148
    ble/complete/source/test-limit "${#ret[@]}" || return 1
    for cand in "${ret[@]}"; do
      ((cand_iloop++%bleopt_complete_polling_cycle==0)) &&
        ble/complete/check-cancel && return 148
      [[ $cand && -d $cand ]] || continue
      [[ $cand == / ]] || cand=${cand%/}
      cand=${cand#"$name"}

      ble/set#contains visited "$cand" && continue
      ble/set#add visited "$cand"
      ble/array#push candidates "$cand"
    done
    ((${#candidates[@]})) || continue

    local flag_source_filter=1
    local cdpath_basedir=$name
    ble/complete/cand/yield-filenames "$action" "${candidates[@]}"; local ext=$?
    ((ext==148)) && return "$ext"
    [[ $action == cdpath ]] && is_cdpath_generated=1
  done
  [[ $is_cdpath_generated ]] &&
    bleopt complete_menu_style=desc

  # Check PWD next
  # Normal candidate generation only when current directory is not included in CDPATH
  if [[ ! $is_pwd_visited ]]; then
    local -a candidates=()
    local ret cand
    ble/complete/source:file/generate "$COMPV" ensure-slash; (($?==148)) && return 148
    ble/complete/source/test-limit "${#ret[@]}" || return 1
    for cand in "${ret[@]}"; do
      ((cand_iloop++%bleopt_complete_polling_cycle==0)) &&
        ble/complete/check-cancel && return 148
      [[ -d $cand ]] || continue
      [[ $cand == / ]] || cand=${cand%/}
      ble/set#contains visited "$cand" && continue
      ble/array#push candidates "$cand"
    done
    local flag_source_filter=1
    ble/complete/cand/yield-filenames file "${candidates[@]}"; local ext=$?
    ((ext==148)) && return "$ext"
  fi
  ((cand_count>old_cand_count)) && return 0

  ble/cmdinfo/complete:cd/generate-cdable_vars
}
function ble/cmdinfo/complete:cd {
  ble/cmdinfo/complete:cd/.impl cd
}
function ble/cmdinfo/complete:pushd {
  ble/cmdinfo/complete:cd/.impl pushd
}
function ble/cmdinfo/complete:popd {
  ble/cmdinfo/complete:cd/.impl popd
}
function ble/cmdinfo/complete:dirs {
  ble/cmdinfo/complete:cd/.impl dirs
}

blehook/invoke complete_load
blehook complete_load=
return 0
