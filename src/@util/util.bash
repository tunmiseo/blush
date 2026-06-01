# -*- mode: sh; mode: sh-bash -*-
# bash script to be sourced from interactive shell

#------------------------------------------------------------------------------
# ble.sh options

function bleopt/.read-arguments/process-option {
  local name=$1
  case $name in
  (help)
    flags=H$flags ;;
  (color|color=always)
    flags=c${flags//[cn]} ;;
  (color=never)
    flags=n${flags//[cn]} ;;
  (color=auto)
    flags=${flags//[cn]} ;;
  (color=*)
    ble/util/print "bleopt: '${name#*=}': unrecognized option argument for '--color'." >&2
    flags=E$flags ;;
  (reset)   flags=r$flags ;;
  (changed) flags=u$flags ;;
  (initialize) flags=I$flags ;;
  (*)
    ble/util/print "bleopt: unrecognized long option '--$name'." >&2
    flags=E$flags ;;
  esac
}

## @fn bleopt/expand-variable-pattern pattern opts
##   @param[in] pattern
##   @var[out] ret
function bleopt/expand-variable-pattern {
  ret=()
  local pattern=$1
  if [[ $pattern == *[@*?]* ]]; then
    builtin eval -- "ret=(\"\${!${pattern%%[@*?]*}@}\")"
    ble/array#filter-by-glob ret "${pattern//@/*}"
  elif [[ ${!pattern+set} || :$opts: == :allow-undefined: ]]; then
    ret=("$pattern")
  fi
  ((${#ret[@]}))
}

## @fn bleopt/.read-arguments
##   @var[out] flags
##     H --help
##     c --color=always
##     n --color=never
##     r --reset
##     u --changed
##     I --initialize
##   @var[out] pvars
##   @var[out] specs
function bleopt/.read-arguments {
  flags= pvars=() specs=()
  local stop_option=
  while (($#)); do
    local arg=$1; shift
    if [[ ! $stop_option && $arg == -?* ]]; then
      case $arg in
      (--)
        stop_option=1 ;;
      (--*)
        bleopt/.read-arguments/process-option "${arg:2}" ;;
      (*)
        local i c
        for ((i=1;i<${#arg};i++)); do
          c=${arg:i:1}
          case $c in
          (r) bleopt/.read-arguments/process-option reset ;;
          (u) bleopt/.read-arguments/process-option changed ;;
          (I) bleopt/.read-arguments/process-option initialize ;;
          (*)
            ble/util/print "bleopt: unrecognized option '-$c'." >&2
            flags=E$flags ;;
          esac
        done ;;
      esac
      continue
    elif local rex='^([_a-zA-Z0-9@*?]+)([:+-]?=|$)(.*)'; [[ $arg =~ $rex ]]; then
      local name=${BASH_REMATCH[1]#bleopt_}
      local var
      var=("bleopt_$name")
      local op=${BASH_REMATCH[2]}
      local value=${BASH_REMATCH[3]}

      # check/expand variable names
      if [[ $op == ':=' ]]; then
        if [[ $var == *[@*?]* ]]; then
          ble/util/print "bleopt: \`${var#bleopt_}': wildcard cannot be used in the definition." >&2
          flags=E$flags
          continue
        fi
      else
        local ret; bleopt/expand-variable-pattern "$var"

        # Exclude obsolete items
        var=()
        local v i=0
        for v in "${ret[@]}"; do
          ble/is-function "bleopt/obsolete:${v#bleopt_}" && continue
          var[i++]=$v
        done

        # If only obsolete is available for display purposes, it is also displayed as obsolete. Also obsolete when assigned
        # If you specify a name that is obsolete, or if the only matches are obsolete ones.
        # also works on obsolete.
        if ((${#var[@]} == 0 && ${#ret[*]})); then
          if [[ $op == [+-]= ]]; then
            # Since the operators += and -= need to read the original value,
            # they cannot be applied to obsoleted options.
            ble/util/print "bleopt: \`$op' cannot be applied to the obsolete option(s), \`$name'" >&2
            flags=E$flags
            continue
          fi
          var=("${ret[@]}")
        fi

        # Failure if suitable item is not found
        if ((${#var[@]}==0)); then
          ble/util/print "bleopt: option \`$name' not found" >&2
          flags=E$flags
          continue
        fi
      fi

      if [[ $op ]]; then
        ble/array#map-suffix var "${op#:}$value"
        ble/array#push specs "${var[@]}"
      else
        ble/array#push pvars "${var[@]}"
      fi
    else
      ble/util/print "bleopt: unrecognized argument '$arg'" >&2
      flags=E$flags
    fi
  done
}

function bleopt/changed.predicate {
  local cur=$1 def=_ble_opt_def_${1#bleopt_}
  [[ ! ${!def+set} || ${!cur} != "${!def}" ]]
}

function bleopt/default {
  local def=_ble_opt_def_${1#bleopt_}
  ret=${!def}
}

## @fn bleopt args...
##   @param[in] args
##     args has one of the following formats:
##
##     var=value
##       Set a value to an existing configuration variable.
##       Error if configuration variable does not exist.
##     var:=value
##       Set values to configuration variables.
##       If the configuration variable does not exist, create a new one.
##     var
##       Display variable settings
##
function bleopt {
  builtin eval -- "$_ble_bash_POSIXLY_CORRECT_local_adjust"
  local flags pvars specs
  bleopt/.read-arguments "$@"
  if [[ $flags == *E* ]]; then
    builtin eval -- "$_ble_bash_POSIXLY_CORRECT_local_leave"
    return 2
  elif [[ $flags == *H* ]]; then
    ble/util/print-lines \
      'usage: bleopt [OPTION] [NAME|NAME=VALUE|NAME[:+-]=VALUE]...' \
      '    Set ble.sh options. Without arguments, this prints all the settings.' \
      '' \
      '  Options' \
      '    --help           Print this help.' \
      '    -r, --reset      Reset options to the default values' \
      '    -I, --initialize Re-initialize settings' \
      '    -u, --changed    Only select changed options' \
      '    --color[=always|never|auto]' \
      '                     Change color settings.' \
      '' \
      '  Arguments' \
      '    NAME        Print the value of the option.' \
      '    NAME=VALUE  Set the value to the option.' \
      '    NAME:=VALUE Set or create the value to the option.' \
      '    NAME+=VALUE Add the value to the colon-separated list.' \
      '    NAME-=VALUE Remove the value to the colon-separated list.' \
      '' \
      '  NAME can contain "@", "*", and "?" as wildcards.' \
      ''
    builtin eval -- "$_ble_bash_POSIXLY_CORRECT_local_leave"
    return 0
  fi

  if ((${#pvars[@]}==0&&${#specs[@]}==0)); then
    local var ip=0
    for var in "${!bleopt_@}"; do
      ble/is-function "bleopt/obsolete:${var#bleopt_}" && continue
      pvars[ip++]=$var
    done
  fi

  [[ $flags == *u* ]] &&
    ble/array#filter pvars bleopt/changed.predicate

  # --reset: Replace all pvars with default settings
  if [[ $flags == *r* ]]; then
    local var
    for var in "${pvars[@]}"; do
      local name=${var#bleopt_}
      ble/is-function bleopt/obsolete:"$name" && continue
      local def=_ble_opt_def_$name
      [[ ${!def+set} && ${!var-} != "${!def}" ]] &&
        ble/array#push specs "$var=${!def}"
    done
    pvars=()
  elif [[ $flags == *I* ]]; then
    local var
    for var in "${pvars[@]}"; do
      bleopt/reinitialize "${var#bleopt_}"
    done
    pvars=()
  fi

  if ((${#specs[@]})); then
    local spec
    for spec in "${specs[@]}"; do
      if ! ble/string#match "$spec" '^([_a-zA-Z0-9]+)([+-]?=)(.*)$'; then
        ble/util/print "bleopt: internal error: unrecognized assignment ($spec)." >&2
        return 3
      fi
      local var=${BASH_REMATCH[1]} op=${BASH_REMATCH[2]} value=${BASH_REMATCH[3]}

      if [[ $op == [+-]= ]]; then
        local rhs=$value value=${!var}
        if [[ $op == += ]]; then
          ble/opts#append-unique value "$rhs"
        else
          ble/opts#remove value "$rhs"
        fi
      fi

      [[ ${!var+set} && ${!var} == "$value" ]] && continue
      if ble/is-function bleopt/check:"${var#bleopt_}"; then
        local bleopt_source=${BASH_SOURCE[1]}
        local bleopt_lineno=${BASH_LINENO[0]}
        if ! bleopt/check:"${var#bleopt_}"; then
          flags=E$flags
          continue
        fi
      fi
      builtin eval -- "$var=\"\$value\""
    done
  fi

  if ((${#pvars[@]})); then
    # Coloring
    local sgr0= sgr1= sgr2= sgr3= sgr4=
    if [[ $flags == *c* || $flags != *n* && -t 1 ]]; then
      local ret
      ble/color/face2sgr command_function; sgr1=$ret
      ble/color/face2sgr syntax_varname; sgr2=$ret
      ble/color/face2sgr syntax_quoted; sgr3=$ret
      ble/color/face2sgr syntax_escape; sgr4=$ret
      sgr0=$_ble_term_sgr0
    fi

    local var
    for var in "${pvars[@]}"; do
      local ret
      ble/string#quote-word "${!var}" sgrq="$sgr3":sgre="$sgr4":sgr0="$sgr0"
      ble/util/print "${sgr1}bleopt$sgr0 ${sgr2}${var#bleopt_}$sgr0=$ret"
    done
  fi

  [[ $flags != *E* ]]
  builtin eval -- "$_ble_bash_POSIXLY_CORRECT_local_return"
}

function bleopt/declare/.check-renamed-option {
  var=bleopt_$2

  local sgr0= sgr1= sgr2= sgr3=
  if [[ -t 2 ]]; then
    sgr0=$_ble_term_sgr0
    sgr1=${_ble_term_setaf[2]}
    sgr2=${_ble_term_setaf[1]}$_ble_term_bold
    sgr3=${_ble_term_setaf[4]}$_ble_term_bold
  fi

  local locate=$sgr1${BASH_SOURCE[3]-'(stdin)'}:${BASH_LINENO[2]}$sgr0
  ble/util/print "$locate (bleopt): The option '$sgr2$1$sgr0' has been renamed. Please use '$sgr3$2$sgr0' instead." >&2
  if ble/is-function bleopt/check:"$2"; then
    bleopt/check:"$2"
    return "$?"
  fi
  return 0
}
function bleopt/declare {
  local type=$1 name=bleopt_$2 default_value=${3-}
  # local set=${!name+set} value=${!name-}
  case $type in
  (-o)
    if [[ ${3-} ]]; then
      builtin eval -- "$name='[obsolete: renamed to $3]'"
    else
      builtin eval -- "$name='[obsolete]'"
    fi
    builtin eval -- "function bleopt/check:$2 { bleopt/declare/.check-renamed-option $2 $3; }"
    builtin eval -- "function bleopt/obsolete:$2 { return 0; }" ;;
  (-n)
    builtin eval -- "_ble_opt_def_$2=\$3"
    builtin eval -- ": \"\${$name:=\$default_value}\"" ;;
  (*)
    builtin eval -- "_ble_opt_def_$2=\$3"
    builtin eval -- ": \"\${$name=\$default_value}\"" ;;
  esac
  return 0
}
function bleopt/reinitialize {
  local name=$1
  local defname=_ble_opt_def_$name
  local varname=bleopt_$name
  [[ ${!defname+set} ]] || return 1
  [[ ${!varname} == "${!defname}" ]] && return 0
  ble/is-function bleopt/obsolete:"$name" && return 0
  ble/is-function bleopt/check:"$name" || return 0

  # Reset the value to the default value and check again.
  local value=${!varname}
  builtin eval -- "$varname=\$$defname"
  bleopt/check:"$name" &&
    builtin eval "$varname=\$value"
}

## @bleopt input_encoding
bleopt/declare -n input_encoding UTF-8
function bleopt/check:input_encoding {
  if ! ble/is-function ble/encoding:"$value"/decode; then
    ble/util/print "bleopt: Invalid value input_encoding='$value'. A function 'ble/encoding:$value/decode' is not defined." >&2
    return 1
  elif ! ble/is-function ble/encoding:"$value"/b2c; then
    ble/util/print "bleopt: Invalid value input_encoding='$value'. A function 'ble/encoding:$value/b2c' is not defined." >&2
    return 1
  elif ! ble/is-function ble/encoding:"$value"/c2bc; then
    ble/util/print "bleopt: Invalid value input_encoding='$value'. A function 'ble/encoding:$value/c2bc' is not defined." >&2
    return 1
  elif ! ble/is-function ble/encoding:"$value"/generate-binder; then
    ble/util/print "bleopt: Invalid value input_encoding='$value'. A function 'ble/encoding:$value/generate-binder' is not defined." >&2
    return 1
  elif ! ble/is-function ble/encoding:"$value"/is-intermediate; then
    ble/util/print "bleopt: Invalid value input_encoding='$value'. A function 'ble/encoding:$value/is-intermediate' is not defined." >&2
    return 1
  fi

  # Note: ble/encoding:$value/clear is an optional setting.

  if [[ $bleopt_input_encoding != "$value" ]]; then
    local bleopt_input_encoding=$value
    ble/decode/readline/rebind
  fi
  return 0
}

## @bleopt internal_stackdump_enabled
##   Controls whether the function call structure is printed to standard error when an error occurs.
##   Outputs an error if an arithmetic expression evaluates to a non-zero value.
## No error is output in other cases.
bleopt/declare -v internal_stackdump_enabled 0

## @bleopt openat_base
##   Allocate fd internally in ble.sh when exec {var}>foo cannot be used in versions lower than bash-4.1.
##   Specify the base of fd at this time. bleopt_openat_base, bleopt_openat_base+1, ...
##   are used in order. Default value is 30.
bleopt/declare -n openat_base 30

## @bleopt pager
bleopt/declare -v pager ''

## @bleopt editor
bleopt/declare -v editor ''

shopt -s checkwinsize

#------------------------------------------------------------------------------
# util

function ble/util/setexit { return "$1"; }

## @var _ble_util_upvar_setup
## @var _ble_util_upvar
##
##   These variables make the [-v varname] argument recognized when defining a function,
##   Used to allow external specification of the variable name that stores the result of a function.
##   When using it, write the function as follows. The default storage variable is ret.
##
##     function MyFunction {
##       eval "$_ble_util_upvar_setup"
##
##       ret=... # Code that performs the processing and stores the result in the variable ret
##               # (Please note that if you return in the middle, it will not work correctly)
##
##       eval "$_ble_util_upvar"
##     }
##
##   If you want to change the default storage variable to a different name (arg in the example below), do the following:
##
##     function MyFunction {
##       eval "${_ble_util_upvar_setup//ret/arg}"
##
##       arg=... # Code that performs the processing and stores the result in variable arg
##
##       eval "${_ble_util_upvar//ret/arg}"
##     }
##
_ble_util_upvar_setup='local var=ret ret; [[ $1 == -v ]] && var=$2 && shift 2'
_ble_util_upvar='local "${var%%\[*\]}" && ble/util/upvar "$var" "$ret"'
if ((_ble_bash>=50000)); then
  function ble/util/unlocal {
    if shopt -q localvar_unset; then
      shopt -u localvar_unset
      builtin unset -v "$@"
      shopt -s localvar_unset
    else
      builtin unset -v "$@"
    fi
  }
  function ble/util/upvar { ble/util/unlocal "${1%%\[*\]}" && builtin eval "$1=\"\$2\""; }
  function ble/util/uparr { ble/util/unlocal "$1" && builtin eval "$1=(\"\${@:2}\")"; }
else
  function ble/util/unlocal { builtin unset -v "$@"; }
  function ble/util/upvar { builtin unset -v "${1%%\[*\]}" && builtin eval "$1=\"\$2\""; }
  function ble/util/uparr { builtin unset -v "$1" && builtin eval "$1=(\"\${@:2}\")"; }
fi

function ble/util/save-vars {
  local __ble_name __ble_prefix=$1; shift
  for __ble_name; do
    if ble/is-array "$__ble_name"; then
      if ble/array#is-sparse "$__ble_name"; then
        ble/idict#copy "$__ble_prefix$__ble_name" "$__ble_name"
      else
        builtin eval "$__ble_prefix$__ble_name=(\"\${$__ble_name[@]}\")"
      fi
    else
      builtin eval "$__ble_prefix$__ble_name=\"\$$__ble_name\""
    fi
  done
}
function ble/util/restore-vars {
  local __ble_name __ble_prefix=$1; shift
  for __ble_name; do
    if ble/is-array "$__ble_prefix$__ble_name"; then
      if ble/array#is-sparse "$__ble_name"; then
        ble/idict#copy "$__ble_name" "$__ble_prefix$__ble_name"
      else
        # Note: Under bash-4.2, "${arr[@]}" on an empty array fails with set -u.
        # Therefore, set ${arr[@]+"${arr[@]}"}.
        builtin eval "$__ble_name=(\${$__ble_prefix$__ble_name[@]+\"\${$__ble_prefix$__ble_name[@]}\"})"
      fi
    else
      builtin eval "$__ble_name=\"\${$__ble_prefix$__ble_name-}\""
    fi
  done
}

#
# variable, array and strings
#

## @fn ble/variable#get-attr varname
##   Gets the attributes of the specified variable.
##   @var[out] attr
if ((_ble_bash>=40400)); then
  function ble/variable#get-attr {
    if [[ $1 == -v ]]; then
      builtin eval -- "$2=\${!3@a}"
    else
      attr=${!1@a}
    fi
  }
  function ble/variable#has-attr { [[ ${!1@a} == *["$2"]* ]]; }
else
  function ble/variable#get-attr {
    if [[ $1 == -v ]]; then
      local __ble_var=$2 __ble_tmp=$3
    else
      local __ble_var=attr __ble_tmp=$1
    fi
    ble/util/assign __ble_tmp 'declare -p "$__ble_tmp" 2>/dev/null'
    local rex='^declare -([a-zA-Z]*)'; [[ $__ble_tmp =~ $rex ]]
    builtin eval -- "$__ble_var=\${BASH_REMATCH[1]-}"
    return 0
  }
  function ble/variable#has-attr {
    local __ble_tmp=$1
    ble/util/assign __ble_tmp 'declare -p "$__ble_tmp" 2>/dev/null'
    local rex='^declare -([a-zA-Z]*)'
    [[ $__ble_tmp =~ $rex && ${BASH_REMATCH[1]} == *["$2"]* ]]
  }
fi
function ble/is-inttype { ble/variable#has-attr "$1" i; }
function ble/is-readonly { ble/variable#has-attr "$1" r; }
function ble/is-transformed { ble/variable#has-attr "$1" luc; }

function ble/variable#is-declared { [[ ${!1+set} ]] || declare -p "$1" &>/dev/null; }
function ble/variable#is-global/.test { ! local "$1"; }
function ble/variable#is-global {
  (builtin readonly "$1"; ble/variable#is-global/.test "$1") 2>/dev/null
}
function ble/variable#copy-state {
  local src=$1 dst=$2
  if [[ ${!src+set} ]]; then
    builtin eval -- "$dst=\${$src}"
  else
    builtin unset -v "$dst[0]" 2>/dev/null || builtin unset -v "$dst"
  fi
}

_ble_array_prototype=()
function ble/array#reserve-prototype {
  local n=$1 i
  for ((i=${#_ble_array_prototype[@]};i<n;i++)); do
    _ble_array_prototype[i]=
  done
}

## @fn ble/is-array arr
##
##   Note: There are various ways to implement this, but most of them don't work very well.
##
##   * ! declare +a arr will determine the local variables of the current function.
##   * Since bash-4.2 you can use ! declare -g +a arr, but
##     In this case, the array defined in the calling function cannot be seen.
##     Or rather, I can't even see the array in the current scope.
##   * Currently I am using compgen -A arrayvar,
##     With this method, associative arrays are recognized as arrays in bash-4.3 and later,
##     Associative arrays are not arrays under bash-4.2.
if ((_ble_bash>=40400)); then
  function ble/is-array { [[ ${!1@a} == *a* ]]; }
  function ble/is-assoc { [[ ${!1@a} == *A* ]]; }
else
  function ble/is-array {
    local "decl$1"
    ble/util/assign "decl$1" "declare -p $1" 2>/dev/null || return 1
    # Note: [b-zAB-Z] specifies a letter excluding "a".  For locales where
    # collation order is "AaBb...Zz", we avoid to use the range [b-zA-Z].
    local rex='^declare -[b-zAB-Z]*a'
    builtin eval "[[ \$decl$1 =~ \$rex ]]"
  }
  function ble/is-assoc {
    local "decl$1"
    ble/util/assign "decl$1" "declare -p $1" 2>/dev/null || return 1
    # Note: [ab-zB-Z] specifies a letter excluding "A".  For locales where
    # collation order is "aAbB...zZ", we avoid to use the range [a-zB-Z].
    local rex='^declare -[ab-zB-Z]*A'
    builtin eval "[[ \$decl$1 =~ \$rex ]]"
  }
  ((_ble_bash>=40000)) ||
    function ble/is-assoc { return 1; }
fi

function ble/array#is-sparse {
  builtin eval "((\${#$1[@]})) && set -- \"\${$1[@]:\${#$1[@]}:1}\"" && (($#))
}

## @fn ble/array#set arr value...
##   Set values in an array.
##   This is a function to avoid the problem that arr2=("${arr1[@]}") is slow in Bash 4.4.
function ble/array#set { builtin eval "$1=(\"\${@:2}\")"; }

## @fn ble/array#push arr value...
if ((_ble_bash>=40000)); then
  function ble/array#push {
    builtin eval "$1+=(\"\${@:2}\")"
  }
elif ((_ble_bash>=30100)); then
  function ble/array#push {
    # Note (workaround Bash 3.1/3.2 bug): #D1198
    #   For some reason, a=("${@:2}") seems to have something special set up in IFS.
    #   The behavior is the same as "${*:2}".
    IFS=$_ble_term_IFS builtin eval "$1+=(\"\${@:2}\")"
  }
else
  function ble/array#push {
    while (($#>=2)); do
      builtin eval -- "$1[\${#$1[@]}]=\"\$2\""
      set -- "$1" "${@:3}"
    done
  }
fi
## @fn ble/array#pop arr
##   @var[out] ret
function ble/array#pop {
  builtin eval "local i$1=\$((\${#$1[@]}-1))"
  if ((i$1>=0)); then
    builtin eval "ret=\${$1[i$1]}"
    builtin unset -v "$1[i$1]"
    return 0
  else
    ret=
    return 1
  fi
}
## @fn ble/array#unshift arr value...
function ble/array#unshift {
  builtin eval -- "$1=(\"\${@:2}\" \"\${$1[@]}\")"
}
## @fn ble/array#shift arr count
function ble/array#shift {
  # Note: In Bash 4.3 and below, ${arr[@]:${2:-1}} is offset='${2'
  # Since length='-1' is interpreted, the arithmetic expression is expanded first.
  builtin eval -- "$1=(\"\${$1[@]:$((${2:-1}))}\")"
}
## @fn ble/array#reverse arr
function ble/array#reverse {
  builtin eval "
  set -- \"\${$1[@]}\"; $1=()
  local e$1 i$1=\$#
  for e$1; do $1[--i$1]=\"\$e$1\"; done"
}

## @fn ble/array#insert-at arr index elements...
function ble/array#insert-at {
  builtin eval "$1=(\"\${$1[@]::$2}\" \"\${@:3}\" \"\${$1[@]:$2}\")"
}
## @fn ble/array#insert-after arr needle elements...
function ble/array#insert-after {
  local _ble_local_script='
    local iNAME=0 eNAME aNAME=
    for eNAME in "${NAME[@]}"; do
      ((iNAME++))
      [[ $eNAME == "$2" ]] && aNAME=iNAME && break
    done
    [[ $aNAME ]] && ble/array#insert-at "$1" "$aNAME" "${@:3}"
  '; builtin eval -- "${_ble_local_script//NAME/$1}"
}
## @fn ble/array#insert-before arr needle elements...
function ble/array#insert-before {
  local _ble_local_script='
    local iNAME=0 eNAME aNAME=
    for eNAME in "${NAME[@]}"; do
      [[ $eNAME == "$2" ]] && aNAME=iNAME && break
      ((iNAME++))
    done
    [[ $aNAME ]] && ble/array#insert-at "$1" "$aNAME" "${@:3}"
  '; builtin eval -- "${_ble_local_script//NAME/$1}"
}
## @fn ble/array#filter arr predicate
##   @param[in] predicate
##     When a function name is specified, the target string is passed
##     to the function as the first argument.  Otherwise, the value of
##     PREDICATE is treated as a command string where the argument can
##     be referenced as $1.
function ble/array#filter/.eval {
  builtin eval -- "$_ble_local_predicate_cmd"
}
function ble/array#filter {
  local _ble_local_predicate=$2 _ble_local_predicate_cmd=
  if [[ $2 == *'$'* ]] || ! ble/is-function "$2"; then
    _ble_local_predicate=ble/array#filter/.eval
    _ble_local_predicate_cmd=$2
  fi

  local _ble_local_script='
    local -a aNAME=() eNAME
    for eNAME in "${NAME[@]}"; do
      "$_ble_local_predicate" "$eNAME" && ble/array#push "aNAME" "$eNAME"
    done
    NAME=("${aNAME[@]}")
  '; builtin eval -- "${_ble_local_script//NAME/$1}"
}
function ble/array#filter/not.predicate { ! "$_ble_local_pred" "$1"; }
function ble/array#remove-if {
  local _ble_local_pred=$2
  ble/array#filter "$1" ble/array#filter/not.predicate
}
## @fn ble/array#filter-by-regex arr regex
function ble/array#filter/regex.predicate { [[ $1 =~ $_ble_local_rex ]]; }
function ble/array#filter-by-regex {
  local _ble_local_rex=$2
  local LC_ALL= LC_COLLATE=C 2>/dev/null
  ble/array#filter "$1" ble/array#filter/regex.predicate
  ble/util/unlocal LC_COLLATE LC_ALL 2>/dev/null
}
function ble/array#remove-by-regex {
  local _ble_local_rex=$2
  local LC_ALL= LC_COLLATE=C 2>/dev/null
  ble/array#remove-if "$1" ble/array#filter/regex.predicate
  ble/util/unlocal LC_COLLATE LC_ALL 2>/dev/null
}
function ble/array#filter/glob.predicate { [[ $1 == $_ble_local_glob ]]; }
function ble/array#filter-by-glob {
  local _ble_local_glob=$2
  local LC_ALL= LC_COLLATE=C 2>/dev/null
  ble/array#filter "$1" ble/array#filter/glob.predicate
  ble/util/unlocal LC_COLLATE LC_ALL 2>/dev/null
}
function ble/array#remove-by-glob {
  local _ble_local_glob=$2
  local LC_ALL= LC_COLLATE=C 2>/dev/null
  ble/array#remove-if "$1" ble/array#filter/glob.predicate
  ble/util/unlocal LC_COLLATE LC_ALL 2>/dev/null
}
## @fn ble/array#remove arr element
function ble/array#remove/.predicate { [[ $1 != "$_ble_local_value" ]]; }
function ble/array#remove {
  local _ble_local_value=$2
  ble/array#filter "$1" ble/array#remove/.predicate
}
## @fn ble/array#index arr needle
##   @var[out] ret
function ble/array#index {
  local _ble_local_script='
    local eNAME iNAME=0
    for eNAME in "${NAME[@]}"; do
      if [[ $eNAME == "$2" ]]; then ret=$iNAME; return 0; fi
      ((++iNAME))
    done
    ret=-1; return 1
  '; builtin eval -- "${_ble_local_script//NAME/$1}"
}
## @fn ble/array#last-index arr needle
##   @var[out] ret
function ble/array#last-index {
  local _ble_local_script='
    local eNAME iNAME=${#NAME[@]}
    while ((iNAME--)); do
      [[ ${NAME[iNAME]} == "$2" ]] && { ret=$iNAME; return 0; }
    done
    ret=-1; return 1
  '; builtin eval -- "${_ble_local_script//NAME/$1}"
}
## @fn ble/array#remove-at arr index
function ble/array#remove-at {
  local _ble_local_script='
    builtin unset -v "NAME[$2]"
    NAME=("${NAME[@]}")
  '; builtin eval -- "${_ble_local_script//NAME/$1}"
}

## @fn ble/array#map-prefix name prefix
## @fn ble/array#map-suffix name suffix
if ((_ble_bash>=50200)); then
  # Note(#D1738): When Bash 5.2's patsub_replacement is turned on, one needs to
  # quote the replacement to prevent '&' in the replacement from being replaced
  # to a matching string (i.e., an empty string in the present case).  However,
  # when compat42 is also turned on, the quoting of the replacement will remain
  # in the result.  There is no solution without changing an shell option.
  function ble/array#map-prefix {
    local _ble_local_script='NAME=("${NAME[@]/#/"$2"}")' # disable=#D1570,#D1751,#D2352
    if shopt -q compat42; then
      shopt -u compat42
      builtin eval -- "${_ble_local_script//NAME/$1}"
      shopt -s compat42
    else
      builtin eval -- "${_ble_local_script//NAME/$1}"
    fi
  }
  function ble/array#map-suffix {
    local _ble_local_script='NAME=("${NAME[@]/%/"$2"}")' # disable=#D1570,#D1751,#D2352
    if shopt -q compat42; then
      shopt -u compat42
      builtin eval -- "${_ble_local_script//NAME/$1}"
      shopt -s compat42
    else
      builtin eval -- "${_ble_local_script//NAME/$1}"
    fi
  }
elif ((_ble_bash<30100||40300<=_ble_bash&&_ble_bash<40400)); then
  # Note (#D1570): Bash 3.0 has a bug that ${scalar[@]/...} (#D2352) produces
  # an empty result if "scalar" is a scalar variable.  In Bash 4.3, in the same
  # situation, the results are contaminated by internal escape character
  # $'\001'.  We need to make sure that the target variable is an array.
  function ble/array#map-prefix {
    local _ble_local_script='
      NAME=("${NAME[@]}") # WA for #D1570
      NAME=("${NAME[@]/#/$2}") # disable=#D1570,#D1738,#D2352'
    builtin eval -- "${_ble_local_script//NAME/$1}"
  }
  function ble/array#map-suffix {
    local _ble_local_script='
      NAME=("${NAME[@]}") # WA for #D1570
      NAME=("${NAME[@]/%/$2}") # disable=#D1570,#D1738,#D2352'
    builtin eval -- "${_ble_local_script//NAME/$1}"
  }
elif ((40200<=_ble_bash&&_ble_bash<40300)); then
  # Note(#D2352): Bash 4.2 has a bug that for an array a=("") with a single
  # empty element, the substitution "${a[@]/#}" (#D1570,#D2352) produces no
  # elements.  This only happens when a has a single element, so we can treat
  # it separately.
  function ble/array#map-prefix {
    local _ble_local_script='
      if ((${#NAME[@]}==1)); then
        NAME=("${NAME[@]}") # compaction
        NAME[0]=$2${NAME[0]} # WA for #D2352
      else
        NAME=("${NAME[@]/#/$2}") # disable=#D1570,#D1738,#D2352
      fi'
    builtin eval -- "${_ble_local_script//NAME/$1}"
  }
  function ble/array#map-suffix {
    local _ble_local_script='
      if ((${#NAME[@]}==1)); then
        NAME=("${NAME[@]}") # compaction
        NAME[0]=${NAME[0]}$2 # WA for #D2352
      else
        NAME=("${NAME[@]/%/$2}") # disable=#D1570,#D1738,#D2352
      fi'
    builtin eval -- "${_ble_local_script//NAME/$1}"
  }
else
  function ble/array#map-prefix {
    local _ble_local_script='
      NAME=("${NAME[@]/#/$2}") # disable=#D1570,#D1738,#D2352'
    builtin eval -- "${_ble_local_script//NAME/$1}"
  }
  function ble/array#map-suffix {
    local _ble_local_script='
      NAME=("${NAME[@]/%/$2}") # disable=#D1570,#D1738,#D2352'
    builtin eval -- "${_ble_local_script//NAME/$1}"
  }
fi

## @fn ble/array#fill-range name begin end value
function ble/array#fill-range {
  # We originally tried to combine multiple arrays, but it finally turned out
  # to be even slower than simple assignments in a loop.  (cf
  # memo/benchmark/array-fill-range.sh)
  local _ble_local_script='
    local iNAME=$2
    while ((iNAME<'"$(($3))"')); do NAME[iNAME++]=$4; done'
  builtin eval -- "${_ble_local_script//NAME/$1}"
}

## @fn ble/idict#replace arr needle [replacement]
##   Replaces all elements matching needle with replacement.
##   If replacement is not specified, the corresponding element will be unset.
##   @var[in] arr
##   @var[in] needle
##   @var[in,opt] replacement
function ble/idict#replace {
  local _ble_local_script='
    local iNAME=0 extNAME=1
    for iNAME in "${!NAME[@]}"; do
      [[ ${NAME[iNAME]} == "$2" ]] || continue
      extNAME=0
      if (($#>=3)); then
        NAME[iNAME]=$3
      else
        builtin unset -v '\''NAME[iNAME]'\''
      fi
    done
    return "$extNAME"
  '; builtin eval -- "${_ble_local_script//NAME/$1}"
}

function ble/idict#copy {
  local __ble_script='
    '$1'=()
    local __ble_i
    for __ble_i in "${!'$2'[@]}"; do
      '$1'[__ble_i]=${'$2'[__ble_i]}
    done'
  builtin eval -- "$__ble_script"
}

_ble_string_prototype='        '
function ble/string#reserve-prototype {
  local n=$1 c
  for ((c=${#_ble_string_prototype};c<n;c*=2)); do
    _ble_string_prototype=$_ble_string_prototype$_ble_string_prototype
  done
}

## @fn ble/string#repeat str count
##   @param[in] str
##   @param[in] count
##   @var[out] ret
function ble/string#repeat {
  ble/string#reserve-prototype "$2"
  ret=${_ble_string_prototype::$2}
  ret=${ret// /"$1"}
}

## @fn ble/string#common-prefix a b
##   @param[in] a b
##   @var[out] ret
function ble/string#common-prefix {
  local a=$1 b=$2
  ((${#a}>${#b})) && local a=$b b=$a
  b=${b::${#a}}
  if [[ $a == "$b" ]]; then
    ret=$a
    return 0
  fi

  # l <= solution < u, (${a:u}: does not match, ${a:l} matches)
  local l=0 u=${#a} m
  while ((l+1<u)); do
    ((m=(l+u)/2))
    if [[ ${a::m} == "${b::m}" ]]; then
      ((l=m))
    else
      ((u=m))
    fi
  done

  ret=${a::l}
}

## @fn ble/string#common-suffix a b
##   @param[in] a b
##   @var[out] ret
function ble/string#common-suffix {
  local a=$1 b=$2
  ((${#a}>${#b})) && local a=$b b=$a
  b=${b:${#b}-${#a}}
  if [[ $a == "$b" ]]; then
    ret=$a
    return 0
  fi

  # l < solution <= u, (${a:l}: does not match, ${a:u} matches)
  local l=0 u=${#a} m
  while ((l+1<u)); do
    ((m=(l+u+1)/2))
    if [[ ${a:m} == "${b:m}" ]]; then
      ((u=m))
    else
      ((l=m))
    fi
  done

  ret=${a:u}
}

## @fn ble/string#split arr sep str...
##   Split a string.
##   If whitespace is used for splitting, empty elements will be removed.
##
##   @param[out] arr Specify the array name that stores the divided strings.
##   @param[in] sep Specifies the character to use for splitting.
##   @param[in] str Specifies the string to split.
##
function ble/string#split {
  local IFS=$2
  if [[ -o noglob ]]; then
    # Note: One sep is manually added to the end so that the last sep is not ignored.
    builtin eval "$1=(\$3\$2)"
  else
    set -f
    builtin eval "$1=(\$3\$2)"
    set +f
  fi
}
function ble/string#split-words {
  local IFS=$_ble_term_IFS
  if [[ -o noglob ]]; then
    builtin eval "$1=(\$2)"
  else
    set -f
    builtin eval "$1=(\$2)"
    set +f
  fi
}
## @fn ble/string#split-lines arr text
##   Splits a string into lines. Blank lines are not omitted.
##
##   @param[out] arr Specify the array name that stores the divided strings.
##   @param[in] text Specifies the string to split.
##   @var[out] ret
##
if ((_ble_bash>=40000)); then
  function ble/string#split-lines {
    mapfile -t "$1" <<< "$2"
  }
else
  function ble/string#split-lines {
    ble/util/mapfile "$1" <<< "$2"
  }
fi
## @fn ble/string#count-char text chars
##   @param[in] text
##   @param[in] chars
##     Specifies the set of characters to search for.
##   @var[out] ret
function ble/string#count-char {
  local text=$1 char=$2
  text=${text//[!"$char"]}
  ret=${#text}
}

## @fn ble/string#count-string text string
##   @var[out] ret
function ble/string#count-string {
  local text=${1//"$2"}
  ((ret=(${#1}-${#text})/${#2}))
}

## @fn ble/string#index-of text needle [n]
##   @param[in] text
##   @param[in] needle
##   @param[in] n
##     This argument searches for the nth match.
##   @var[out] ret
##     Returns the location found if there is a match.
##     Returns -1 if not found.
##   @exit
##     Succeeds if there is a match, fails if not found.
function ble/string#index-of {
  local haystack=$1 needle=$2 count=${3:-1}
  ble/string#repeat '*"$needle"' "$count"; local pattern=$ret
  builtin eval "local transformed=\${haystack#$pattern}"
  ((ret=${#haystack}-${#transformed}-${#needle},
    ret<0&&(ret=-1),ret>=0))
}

## @fn ble/string#last-index-of text needle [n]
##   @param[in] text
##   @param[in] needle
##   @param[in] n
##     This argument searches for the nth match.
##   @var[out] ret
function ble/string#last-index-of {
  local haystack=$1 needle=$2 count=${3:-1}
  ble/string#repeat '"$needle"*' "$count"; local pattern=$ret
  builtin eval "local transformed=\${haystack%$pattern}"
  if [[ $transformed == "$haystack" ]]; then
    ret=-1
  else
    ret=${#transformed}
  fi
  ((ret>=0))
}

## @fn ble/string#toggle-case text
## @fn ble/string#toupper text
## @fn ble/string#tolower text
##   @param[in] text
##   @var[out] ret
_ble_util_string_lower_list=abcdefghijklmnopqrstuvwxyz
_ble_util_string_upper_list=ABCDEFGHIJKLMNOPQRSTUVWXYZ
function ble/string#islower { [[ $1 == ["$_ble_util_string_lower_list"] ]]; }
function ble/string#isupper { [[ $1 == ["$_ble_util_string_upper_list"] ]]; }
function ble/string#toggle-case {
  local text=$1 ch i
  local -a buff
  for ((i=0;i<${#text};i++)); do
    ch=${text:i:1}
    if ble/string#isupper "$ch"; then
      ch=${_ble_util_string_upper_list%%"$ch"*}
      ch=${_ble_util_string_lower_list:${#ch}:1}
    elif ble/string#islower "$ch"; then
      ch=${_ble_util_string_lower_list%%"$ch"*}
      ch=${_ble_util_string_upper_list:${#ch}:1}
    fi
    ble/array#push buff "$ch"
  done
  IFS= builtin eval 'ret="${buff[*]-}"'
}
## @fn ble/string#tolower text
## @fn ble/string#toupper text
##   @var[out] ret
if ((_ble_bash>=40000)); then
  function ble/string#tolower { ret=${1,,}; }
  function ble/string#toupper { ret=${1^^}; }
else
  function ble/string#tolower {
    local i text=$1 ch
    local -a buff=()
    for ((i=0;i<${#text};i++)); do
      ch=${text:i:1}
      if ble/string#isupper "$ch"; then
        ch=${_ble_util_string_upper_list%%"$ch"*}
        ch=${_ble_util_string_lower_list:${#ch}:1}
      fi
      ble/array#push buff "$ch"
    done
    IFS= builtin eval 'ret="${buff[*]-}"'
  }
  function ble/string#toupper {
    local i text=$1 ch
    local -a buff=()
    for ((i=0;i<${#text};i++)); do
      ch=${text:i:1}
      if ble/string#islower "$ch"; then
        ch=${_ble_util_string_lower_list%%"$ch"*}
        ch=${_ble_util_string_upper_list:${#ch}:1}
      fi
      ble/array#push buff "$ch"
    done
    IFS= builtin eval 'ret="${buff[*]-}"'
  }
fi

function ble/string#capitalize {
  local tail=$1

  # prefix
  local rex='^[^a-zA-Z0-9]*'
  [[ $tail =~ $rex ]]
  local out=$BASH_REMATCH
  tail=${tail:${#BASH_REMATCH}}

  # words
  rex='^[a-zA-Z0-9]+[^a-zA-Z0-9]*'
  while [[ $tail =~ $rex ]]; do
    local rematch=$BASH_REMATCH
    ble/string#toupper "${rematch::1}"; out=$out$ret
    ble/string#tolower "${rematch:1}" ; out=$out$ret
    tail=${tail:${#rematch}}
  done
  ret=$out$tail
}

## @fn ble/string#trim text
##   @var[out] ret
function ble/string#trim {
  ret=$1
  local rex=$'^[ \t\n]+'
  [[ $ret =~ $rex ]] && ret=${ret:${#BASH_REMATCH}}
  local rex=$'[ \t\n]+$'
  [[ $ret =~ $rex ]] && ret=${ret::${#ret}-${#BASH_REMATCH}}
}
## @fn ble/string#ltrim text
##   @var[out] ret
function ble/string#ltrim {
  ret=$1
  local rex=$'^[ \t\n]+'
  [[ $ret =~ $rex ]] && ret=${ret:${#BASH_REMATCH}}
}
## @fn ble/string#rtrim text
##   @var[out] ret
function ble/string#rtrim {
  ret=$1
  local rex=$'[ \t\n]+$'
  [[ $ret =~ $rex ]] && ret=${ret::${#ret}-${#BASH_REMATCH}}
}

## @fn ble/string#escape-characters text chars1 [chars2]
##   @param[in]     text
##   @param[in]     chars1
##   @param[in,opt] chars2
##   @var[out] ret
if ((_ble_bash>=50200)); then
  function ble/string#escape-characters {
    ret=$1
    if [[ $ret == *["$2"]* ]]; then
      local P=${4-}'\' S=${5-}
      if [[ ! $3 ]]; then
        local patsub_replacement=
        shopt -q patsub_replacement && patsub_replacement=1
        shopt -s patsub_replacement
        ret=${ret//["$2"]/"$P"&"$S"} # #D1738 patsub_replacement
        [[ $patsub_replacement ]] || shopt -u patsub_replacement
      else
        local chars1=$2 chars2=${3:-$2}
        local i n=${#chars1} a b
        for ((i=0;i<n;i++)); do
          a=${chars1:i:1} b=$P${chars2:i:1}$S ret=${ret//"$a"/"$b"}
        done
      fi
    fi
  }
else
  function ble/string#escape-characters {
    ret=$1
    if [[ $ret == *["$2"]* ]]; then
      local chars1=$2 chars2=${3:-$2} P=${4-}'\' S=${5-}
      local i n=${#chars1} a b
      for ((i=0;i<n;i++)); do
        a=${chars1:i:1} b=$P${chars2:i:1}$S ret=${ret//"$a"/"$b"}
      done
    fi
  }
fi


## @fn ble/string#escape-for-sed-regex text
## @fn ble/string#escape-for-awk-regex text
## @fn ble/string#escape-for-extended-regex text
## @fn ble/string#escape-for-bash-glob text
## @fn ble/string#escape-for-bash-single-quote text [sgr1 sgr0]
## @fn ble/string#escape-for-bash-double-quote text
## @fn ble/string#escape-for-bash-escape-string text [sgr1 sgr0]
##   @param[in] text
##   @param[in,opt] sgr1 sgr0
##     Escape sequences used to highlight the escaped parts and the normal
##     parts, respectively.
##   @var[out] ret
function ble/string#escape-for-sed-regex {
  ble/string#escape-characters "$1" '\.[*^$/'
}
function ble/string#escape-for-awk-regex {
  ble/string#escape-characters "$1" '\.[*?+|^$(){}/'
}
function ble/string#escape-for-extended-regex {
  ble/string#escape-characters "$1" '\.[*?+|^$(){}'
}
function ble/string#escape-for-bash-glob {
  ble/string#escape-characters "$1" '\*?[('
}
function ble/string#escape-for-bash-single-quote {
  local q="'" Q="'${2-}\'${3-}'"
  ret=${1//$q/$Q}
}
function ble/string#escape-for-bash-double-quote {
  ble/string#escape-characters "$1" '\"$`'
  local a b
  a='!' b='"\!"' ret=${ret//"$a"/"$b"} # WA #D1751 checked
}
_ble_util_string_escape_string_pairs=(
  $'\001':'\001' $'\002':'\002' $'\003':'\003' $'\004':'\004'
  $'\005':'\005' $'\006':'\006' $'\016':'\016' $'\017':'\017'
  $'\020':'\020' $'\021':'\021' $'\022':'\022' $'\023':'\023'
  $'\024':'\024' $'\025':'\025' $'\026':'\026' $'\027':'\027'
  $'\030':'\030' $'\031':'\031' $'\032':'\032' $'\034':'\034'
  $'\035':'\035' $'\036':'\036' $'\037':'\037' $'\177':'\177'
)
function ble/string#escape-for-bash-escape-string {
  ble/string#escape-characters "$1" $'\\\a\b\e\f\n\r\t\v'\' '\abefnrtv'\' "$2" "$3"
  if [[ $ret == *[$'\001'-$'\037\177']* ]]; then
    local pair a b
    for pair in "${_ble_util_string_escape_string_pairs[@]}"; do
      a=${pair%%:*} b=$2${pair#*:}$3 ret=${ret//"$a"/"$b"}
    done
  fi
}
## @fn ble/string#escape-for-bash-specialchars text flags
##   @param[in] text
##   @param[in] flags
##     c Escape characters that induce tilde expansion in words.
##     b Also escapes brace expansion characters.
##     H Do not escape #, ~ at the beginning of a word.
##     T Don't escape the tilde at the beginning of a word.
## G Do not escape glob characters.
##   @var[out] ret
function ble/string#escape-for-bash-specialchars {
  local chars='\ "'\''`$|&;<>()!^'
  # Note: Although = and : do not require escaping grammatically,
  #   Necessary to avoid COMP_WORDBREAKS during completion.
  [[ $2 != *G* ]] && chars=$chars'*?['
  [[ $2 == *c* ]] && chars=$chars'=:'
  [[ $2 == *b* ]] && chars=$chars'{,}'
  ble/string#escape-characters "$1" "$chars"
  [[ $2 != *[HT]* && $ret == '~'* ]] && ret=\\$ret
  [[ $2 != *H* && $ret == '#'* ]] && ret=\\$ret
  if [[ $ret == *[$']\n\t']* ]]; then
    local a b
    a=']'   b=\\$a     ret=${ret//"$a"/"$b"}
    a=$'\n' b="\$'\n'" ret=${ret//"$a"/"$b"} # WA #D1751 checked
    a=$'\t' b=$'\\\t'  ret=${ret//"$a"/"$b"}
  fi

  # In the above process, extglob's ( is also quoted, so it is returned when it is G.
  if [[ $2 == *G* ]] && shopt -q extglob; then
    local a b
    a='!\(' b='!(' ret=${ret//"$a"/"$b"}
    a='@\(' b='@(' ret=${ret//"$a"/"$b"}
    a='?\(' b='?(' ret=${ret//"$a"/"$b"}
    a='*\(' b='*(' ret=${ret//"$a"/"$b"}
    a='+\(' b='+(' ret=${ret//"$a"/"$b"}
  fi
}

## @fn ble/string#escape-for-display str [opts]
##   Replaces control characters in str with caret notation, such as ^A.
##
##   @param[in] str
##   @param[in] opts
##     revert
##       Highlight the caret notation.
##     sgr1=*
##       Specifies the SGR sequence to use for caret notation.
##       Inserts at the start of caret notation.
##     sgr0=*
##       Specifies the ground SGR sequence to be used for parts other than caret notation.
##       Inserts at the end of the caret notation.
##
function ble/string#escape-for-display {
  local head= tail=$1 opts=$2

  local sgr0= sgr1=
  local rex_csi=$'\e\\[[ -?]*[@-~]' # disable=#D1440 (LC_COLLATE=C is set)
  if [[ :$opts: == *:revert:* ]]; then
    ble/color/g2sgr "$_ble_color_gflags_Revert"
    sgr1=$ret sgr0=$_ble_term_sgr0
  else
    if ble/string#match-safe ":$opts:" ":sgr1=(($rex_csi|[^:])*):"; then
      sgr1=${BASH_REMATCH[1]} sgr0=$_ble_term_sgr0
    fi
    if ble/string#match-safe ":$opts:" ":sgr0=(($rex_csi|[^:])*):"; then
      sgr0=${BASH_REMATCH[1]}
    fi
  fi

  while [[ $tail ]]; do
    if ble/util/isprint+ "$tail"; then
      head=$head$BASH_REMATCH
      tail=${tail:${#BASH_REMATCH}}
    else
      ble/util/s2c "${tail::1}"; local code=$ret
      if ble/unicode/GraphemeCluster/ControlRepresentation "$ret"; then
        ret=$sgr1$ret$sgr0
      else
        ret=${tail::1}
      fi
      head=$head$ret
      tail=${tail:1}
    fi
  done
  ret=$head
}

if ((_ble_bash>=40400)); then
  function ble/string#quote-words {
    local IFS=$_ble_term_IFS
    ret="${*@Q}"
  }
  function ble/string#quote-command {
    local IFS=$_ble_term_IFS
    ret=$1; shift
    (($#)) && ret="$ret ${*@Q}"
  }
else
  function ble/string#quote-words {
    local q=\' Q="'\''" IFS=$_ble_term_IFS
    if (($#==1)); then
      ret=("${1//$q/$Q}")    # WA for #D2352
      ret=("${ret[0]/%/$q}") # WA for #D2352 (disable=#D1738)
    else
      ret=("${@//$q/$Q}")    # disable=#D2352
      ret=("${ret[@]/%/$q}") # disable=#D1570,#D1738,#D2352
    fi
    ret="${ret[*]/#/$q}"   # disable=#D1570,#D1738
  }
  function ble/string#quote-command {
    if (($#<=1)); then
      ret=$1
      return 0
    fi
    local q=\' Q="'\''" IFS=$_ble_term_IFS
    ret=("${@:2}")
    ret=("${ret[@]//$q/$Q}")  # disable=#D1570,#D1738,#D2352
    ret=("${ret[@]/%/$q}")    # disable=#D1570,#D1738,#D2352
    ret="$1 ${ret[*]/#/$q}"   # disable=#D1570,#D1738
  }
fi
## @fn ble/string#quote-word text opts
##   @param[in,opt] opts
##     A colon-separated list of options.
##
##     @opt always
##       Always quote the entire string with '...' or $'...'.
##
##     @opt quote-empty
##       Generate "''" when TEXT is empty.  By default, this function generates
##       an empty string "" for an empty TEXT.
##
##     @opt sgrq=<esc>
##       Specify an escape sequence to highlight parts quoted by quotations.
##
##     @opt sgre=<esc>
##       Specify an escape sequence to highlight parts quoted by an escape.
##
##     @opt sgr0=<esc>
##       Specify an escape sequence to clear the highlighting.
##
##     @opt ansi
##       Use ANSI sequences instead of the current terminfo in automatically
##       generate highlighting.
##
function ble/string#quote-word {
  ret=${1-}

  local opts=${2-} sgrq= sgre= sgrq0= sgre0=
  if [[ $opts ]]; then
    local rex_csi=$'\e\\[[ -?]*[@-~]' # disable=#D1440 (LC_COLLATE is set)

    local sgr0
    if ble/string#match-safe ":$opts:" ":sgr0=(($rex_csi|[^:])*):"; then
      sgr0=${BASH_REMATCH[1]}
    elif [[ :$opts: == *:ansi:* ]]; then
      sgr0=$'\e[m'
    else
      sgr0=$_ble_term_sgr0
    fi

    if ble/string#match-safe ":$opts:" ":sgrq=(($rex_csi|[^:])*):"; then
      sgrq=${BASH_REMATCH[1]} sgrq0=$sgr0
    fi

    if ble/string#match-safe ":$opts:" ":sgre=(($rex_csi|[^:])*):"; then
      sgre=${BASH_REMATCH[1]} sgre0=$sgr0
    fi
  fi

  if [[ ! $ret ]]; then
    if [[ :$opts: == *:quote-empty:* || :$opts: == *:always:* ]]; then
      ret=$sgrq\'\'$sgrq0
    fi
    return 0
  fi

  local chars=$'\a\b\e\f\n\r\t\v\001-\037\177'
  if [[ $ret == *[$chars]* ]]; then
    ble/string#escape-for-bash-escape-string "$ret" "$sgrq0$sgre" "$sgre0$sgrq"
    ret=$sgrq\$\'$ret\'$sgrq0
    return 0
  fi

  local chars=$_ble_term_IFS'"`$\<>()|&;*?[]!^=:{,}#~' q=\'
  if [[ :$opts: == *:always:* || $ret == *["$chars"]* ]]; then
    ble/string#escape-for-bash-single-quote "$ret" "$sgrq0$sgre" "$sgre0$sgrq"
    ret=$sgrq$q$ret$q$sgrq0
    ret=${ret#"$sgrq$q$q$sgrq0"} ret=${ret%"$sgrq$q$q$sgrq0"}
  elif [[ $ret == *["$q"]* ]]; then
    local Q="$sgre\'$sgre0"
    ret=${ret//$q/$Q}
  fi
}

function ble/string#match { [[ $1 =~ $2 ]]; }

function ble/string#match-safe/.impl {
  local LC_ALL= LC_COLLATE=C
  [[ $1 =~ $2 ]]
}
function ble/string#match-safe {
  ble/string#match-safe/.impl "$@" 2>/dev/null # suppress locale error #D1440
}

## @fn ble/string#create-unicode-progress-bar/.block value
##   @var[out] ret
function ble/string#create-unicode-progress-bar/.block {
  local block=$1
  if ((block<=0)); then
    ble/util/c2w "$((0x2588))"
    ble/string#repeat ' ' "$ret"
  elif ((block>=8)); then
    ble/util/c2s "$((0x2588))"
    ((${#ret}==1)) || ret='*' # When LC_CTYPE is an unsupported character
  else
    ble/util/c2s "$((0x2590-block))"
    if ((${#ret}!=1)); then
      # When LC_CTYPE is an unsupported character
      ble/util/c2w "$((0x2588))"
      ble/string#repeat ' ' "$((ret-1))"
      ret=$block$ret
    fi
  fi
}

## @fn ble/string#create-unicode-progress-bar value max width opts
##   @param[in] opts
##     unlimited ... Indicates that the upper limit is unknown.
##   @var[out] ret
function ble/string#create-unicode-progress-bar {
  local value=$1 max=$2 width=$3 opts=:$4:

  local opt_unlimited=
  if [[ $opts == *:unlimited:* ]]; then
    opt_unlimited=1
    ((value%=max,width--))
  fi

  local progress=$((value*8*width/max))
  local progress_fraction=$((progress%8)) progress_integral=$((progress/8))

  local out=
  if ((progress_integral)); then
    if [[ $opt_unlimited ]]; then
      # When unlimited, the left side is blank.
      ble/string#create-unicode-progress-bar/.block 0
    else
      ble/string#create-unicode-progress-bar/.block 8
    fi
    ble/string#repeat "$ret" "$progress_integral"
    out=$ret
  fi

  if ((progress_fraction)); then
    if [[ $opt_unlimited ]]; then
      # When unlimited, 2 sho is used to represent the position.
      ble/string#create-unicode-progress-bar/.block "$progress_fraction"
      out=$out$'\e[7m'$ret$'\e[27m'
    fi

    ble/string#create-unicode-progress-bar/.block "$progress_fraction"
    out=$out$ret
    ((progress_integral++))
  else
    if [[ $opt_unlimited ]]; then
      ble/string#create-unicode-progress-bar/.block 8
      out=$out$ret
    fi
  fi

  if ((progress_integral<width)); then
    ble/string#create-unicode-progress-bar/.block 0
    ble/string#repeat "$ret" "$((width-progress_integral))"
    out=$out$ret
  fi

  ret=$out
}
# Note: For Bash-4.1 and below, the format "LC_CTYPE=C built-in command"
#   There is a bug where locale is not applied on the spot.
function ble/util/strlen.impl {
  local LC_ALL= LC_CTYPE=C
  ret=${#1}
}
function ble/util/strlen {
  ble/util/strlen.impl "$@" 2>/dev/null # suppress locale error #D1440
}
function ble/util/substr.impl {
  local LC_ALL= LC_CTYPE=C
  ret=${1:$2:$3}
}
function ble/util/substr {
  ble/util/substr.impl "$@" 2>/dev/null # suppress locale error #D1440
}

function ble/path#append {
  local _ble_local_script='opts=$opts${opts:+:}$2'
  _ble_local_script=${_ble_local_script//opts/"$1"}
  builtin eval -- "$_ble_local_script"
}
function ble/path#prepend {
  local _ble_local_script='opts=$2${opts:+:}$opts'
  _ble_local_script=${_ble_local_script//opts/"$1"}
  builtin eval -- "$_ble_local_script"
}
function ble/path#remove {
  [[ $2 ]] || return 1
  local _ble_local_script='
    opts=:${opts//:/::}:
    opts=${opts//:"$2":}
    opts=${opts//::/:} opts=${opts#:} opts=${opts%:}'
  _ble_local_script=${_ble_local_script//opts/"$1"}
  if shopt -q nocasematch 2>/dev/null; then
    shopt -u nocasematch
    _ble_local_script=$_ble_local_script';shopt -s nocasematch'
  fi
  builtin eval -- "$_ble_local_script"
}
## @fn ble/path#remove-glob/.impl str pat
##   @var[out] ret
function ble/path#remove-glob/.impl {
  local IFS=: nocasematch=
  if shopt -q nocasematch 2>/dev/null; then
    shopt -u nocasematch
    nocasematch=1
  fi

  local str=$1 pat=$2 paths i
  ble/string#split paths : "$str"
  for i in "${!paths[@]}"; do
    if [[ ${paths[i]} == $pat ]]; then
      builtin unset -v 'paths[i]'
    fi
  done
  ret="${paths[*]}"

  if [[ $nocasematch ]]; then
    shopt -s nocasematch
  fi
}
function ble/path#remove-glob {
  [[ $2 ]] || return 1
  [[ $1 == ret ]] || local ret
  IFS=: ble/path#remove-glob/.impl "${!1}" "$2"
  [[ $1 == ret ]] || builtin eval -- "$1=\$ret"
}
function ble/path#contains {
  builtin eval "[[ :\${$1}: == *:\"\$2\":* ]]"
}

## @fn ble/opts#has opts key
function ble/opts#has {
  local rex=':'$2'[=:]'
  [[ :$1: =~ $rex ]]
}
## @fn ble/opts#remove opts value
function ble/opts#remove {
  ble/path#remove "$@"
}
## @fn ble/opts#append-unique opts value
function ble/opts#append {
  ble/util/set "$1" "${!1:+${!1}:}$2"
}
## @fn ble/opts#append-unique opts value
function ble/opts#append-unique {
  [[ :${!1}: == *:"$2":* ]] || ble/opts#append "$1" "$2"
}

## @fn ble/opts#extract-first-optarg opts key [default_value]
function ble/opts#extract-first-optarg {
  ret=
  local rex=':'$2'(=[^:]*)?:'
  [[ :$1: =~ $rex ]] || return 1
  if [[ ${BASH_REMATCH[1]} ]]; then
    ret=${BASH_REMATCH[1]:1}
  elif [[ ${3+set} ]]; then
    ret=$3
  fi
  return 0
}
## @fn ble/opts#extract-last-optarg opts key [default_value]
##   @var[out] ret
function ble/opts#extract-last-optarg {
  ret=
  local rex='.*:'$2'(=[^:]*)?:'
  [[ :$1: =~ $rex ]] || return 1
  if [[ ${BASH_REMATCH[1]} ]]; then
    ret=${BASH_REMATCH[1]:1}
  elif [[ ${3+set} ]]; then
    ret=$3
  fi
  return 0
}
## @fn ble/opts#extract-all-optargs opts key [default_value]
##   extract all values from the string OPTS of the form
##   "...:key=value1:...:key=value2:...:key:...".
##
##   @param[in] key
##     This should not include any special characters of regular
##     expressions---preferably composed of [-_[:alnum:]].
##
##   @arr[out] ret
function ble/opts#extract-all-optargs {
  ret=()
  local value=:$1: rex=':'$2'(=[^:]*)?(:.*)$' count=0
  while [[ $value =~ $rex ]]; do
    ((count++))
    if [[ ${BASH_REMATCH[1]} ]]; then
      ble/array#push ret "${BASH_REMATCH[1]:1}"
    elif [[ ${3+set} ]]; then
      ble/array#push ret "$3"
    fi
    value=${BASH_REMATCH[2]}
  done
  ((count))
}

if ((_ble_bash>=40000)); then
  _ble_util_set_declare=(declare -A NAME)
  function ble/set#add { builtin eval -- "$1[x\$2]=1"; }
  function ble/set#remove { builtin unset -v "$1[x\$2]"; }
  function ble/set#contains { builtin eval "[[ \${$1[x\$2]+set} ]]"; }
else
  _ble_util_set_declare=(declare NAME)
  function ble/set#.escape {
    _ble_local_value=${_ble_local_value//$_ble_term_FS/"$_ble_term_FS$_ble_term_FS"}
    _ble_local_value=${_ble_local_value//:/"$_ble_term_FS."}
  }
  function ble/set#add {
    local _ble_local_value=$2; ble/set#.escape
    ble/path#append "$1" "$_ble_local_value"
  }
  function ble/set#remove {
    local _ble_local_value=$2; ble/set#.escape
    ble/path#remove "$1" "$_ble_local_value"
  }
  function ble/set#contains {
    local _ble_local_value=$2; ble/set#.escape
    builtin eval "[[ :\$$1: == *:\"\$_ble_local_value\":* ]]"
  }
fi


#--------------------------------------
# dict

_ble_util_adict_declare='declare NAME NAME_keylist'
## @fn ble/dict#.resolve dict key
function ble/adict#.resolve {
  # _ble_local_key
  _ble_local_key=$2
  _ble_local_key=${_ble_local_key//$_ble_term_FS/"$_ble_term_FS,"}
  _ble_local_key=${_ble_local_key//:/"$_ble_term_FS."}

  local keylist=${1}_keylist; keylist=:${!keylist}
  local vec=${keylist%%:"$_ble_local_key":*}
  if [[ $vec != "$keylist" ]]; then
    vec=${vec//[!:]}
    _ble_local_index=${#vec}
  else
    _ble_local_index=-1
  fi
}
function ble/adict#set {
  local _ble_local_key _ble_local_index
  ble/adict#.resolve "$1" "$2"
  if ((_ble_local_index>=0)); then
    builtin eval -- "$1[_ble_local_index]=\$3"
  else
    local _ble_local_script='
      local _ble_local_vec=${NAME_keylist//[!:]}
      NAME[${#_ble_local_vec}]=$3
      NAME_keylist=$NAME_keylist$_ble_local_key:
    '
    builtin eval -- "${_ble_local_script//NAME/$1}"
  fi
  return 0
}
function ble/adict#get {
  local _ble_local_key _ble_local_index
  ble/adict#.resolve "$1" "$2"
  if ((_ble_local_index>=0)); then
    builtin eval -- "ret=\${$1[_ble_local_index]}; [[ \${$1[_ble_local_index]+set} ]]"
  else
    builtin eval -- ret=
    return 1
  fi
}
function ble/adict#unset {
  local _ble_local_key _ble_local_index
  ble/adict#.resolve "$1" "$2"
  ((_ble_local_index>=0)) &&
    builtin eval -- "builtin unset -v '$1[_ble_local_index]'"
  return 0
}
function ble/adict#has {
  local _ble_local_key _ble_local_index
  ble/adict#.resolve "$1" "$2"
  ((_ble_local_index>=0)) &&
    builtin eval -- "[[ \${$1[_ble_local_index]+set} ]]"
}
function ble/adict#clear {
  builtin eval -- "${1}_keylist= $1=()"
}
function ble/adict#keys {
  local _ble_local_keylist=${1}_keylist
  _ble_local_keylist=${!_ble_local_keylist%:}
  ble/string#split ret : "$_ble_local_keylist"
  if [[ $_ble_local_keylist == *"$_ble_term_FS"* ]]; then
    if ((40200<=_ble_bash&&_ble_bash<40300&&${#ret[@]}==1)); then
      ret=("${ret[0]//$_ble_term_FS./:}")             # WA for #D2352
      ret=("${ret[0]//$_ble_term_FS,/$_ble_term_FS}") # WA for #D2352 (disable=#D1738)
    else
      ret=("${ret[@]//$_ble_term_FS./:}")             # disable=#D1570,#D2352
      ret=("${ret[@]//$_ble_term_FS,/$_ble_term_FS}") # disable=#D1570,#D1738,#D2352
    fi
  fi

  # filter out unset elements
  local _ble_local_keys _ble_local_i _ble_local_ref=$1[_ble_local_i]
  _ble_local_keys=("${ret[@]}") ret=()
  for _ble_local_i in "${!_ble_local_keys[@]}"; do
    [[ ${_ble_local_ref+set} ]] &&
      ble/array#push ret "${_ble_local_keys[_ble_local_i]}"
  done
}

if ((_ble_bash>=40000)); then
  _ble_util_dict_declare='declare -A NAME'
  function ble/dict#set   { builtin eval -- "$1[x\$2]=\$3"; }
  function ble/dict#get   { builtin eval -- "ret=\${$1[x\$2]-}; [[ \${$1[x\$2]+set} ]]"; }
  function ble/dict#unset { builtin eval -- "builtin unset -v '$1[x\$2]'"; }
  function ble/dict#has   { builtin eval -- "[[ \${$1[x\$2]+set} ]]"; }
  function ble/dict#clear { builtin eval -- "$1=()"; }
  if ((40200<=_ble_bash&&_ble_bash<50200)); then
    # WA for #D2352
    function ble/dict#keys {
      builtin eval -- 'ret=("${!'"$1"'[@]}")'
      if ((${#ret[@]}==1)); then
        ret[0]=${ret[0]#x} # WA for #D2352
      else
        ret=("${ret[@]#x}") # disable=#D2352
      fi
    }
  else
    function ble/dict#keys { builtin eval -- 'ret=("${!'"$1"'[@]}"); ret=("${ret[@]#x}")'; } # disable=#D2352
  fi
else
  _ble_util_dict_declare='declare NAME NAME_keylist='
  function ble/dict#set   { ble/adict#set   "$@"; }
  function ble/dict#get   { ble/adict#get   "$@"; }
  function ble/dict#unset { ble/adict#unset "$@"; }
  function ble/dict#has   { ble/adict#has   "$@"; }
  function ble/dict#clear { ble/adict#clear "$@"; }
  function ble/dict#keys  { ble/adict#keys  "$@"; }
fi

if ((_ble_bash>=40200)); then
  _ble_util_gdict_declare='{ builtin unset -v NAME; declare -gA NAME; NAME=(); }'
  function ble/gdict#set   { ble/dict#set   "$@"; }
  function ble/gdict#get   { ble/dict#get   "$@"; }
  function ble/gdict#unset { ble/dict#unset "$@"; }
  function ble/gdict#has   { ble/dict#has   "$@"; }
  function ble/gdict#clear { ble/dict#clear "$@"; }
  function ble/gdict#keys  { ble/dict#keys  "$@"; }
elif ((_ble_bash>=40000)); then
  _ble_util_gdict_declare='{ if ! ble/is-assoc NAME; then if local _ble_local_test 2>/dev/null; then NAME_keylist=; else builtin unset -v NAME NAME_keylist; declare -A NAME; fi fi; NAME=(); }'
  function ble/gdict#.is-adict {
    local keylist=${1}_keylist
    [[ ${!keylist+set} ]]
  }
  function ble/gdict#set   { if ble/gdict#.is-adict "$1"; then ble/adict#set   "$@"; else ble/dict#set   "$@"; fi; }
  function ble/gdict#get   { if ble/gdict#.is-adict "$1"; then ble/adict#get   "$@"; else ble/dict#get   "$@"; fi; }
  function ble/gdict#unset { if ble/gdict#.is-adict "$1"; then ble/adict#unset "$@"; else ble/dict#unset "$@"; fi; }
  function ble/gdict#has   { if ble/gdict#.is-adict "$1"; then ble/adict#has   "$@"; else ble/dict#has   "$@"; fi; }
  function ble/gdict#clear { if ble/gdict#.is-adict "$1"; then ble/adict#clear "$@"; else ble/dict#clear "$@"; fi; }
  function ble/gdict#keys  { if ble/gdict#.is-adict "$1"; then ble/adict#keys  "$@"; else ble/dict#keys  "$@"; fi; }
else
  _ble_util_gdict_declare='{ builtin unset -v NAME NAME_keylist; NAME_keylist= NAME=(); }'
  function ble/gdict#set   { ble/adict#set   "$@"; }
  function ble/gdict#get   { ble/adict#get   "$@"; }
  function ble/gdict#unset { ble/adict#unset "$@"; }
  function ble/gdict#has   { ble/adict#has   "$@"; }
  function ble/gdict#clear { ble/adict#clear "$@"; }
  function ble/gdict#keys  { ble/adict#keys  "$@"; }
fi


function ble/dict/.print {
  declare -p "$2" &>/dev/null || return 1
  local ret _ble_local_key _ble_local_value

  ble/util/print "builtin eval -- \"\${_ble_util_${1}_declare//NAME/$2}\""
  ble/"$1"#keys "$2"
  for _ble_local_key in "${ret[@]}"; do
    ble/"$1"#get "$2" "$_ble_local_key"
    ble/string#quote-word "$ret" quote-empty
    _ble_local_value=$ret

    ble/string#quote-word "$_ble_local_key" quote-empty
    _ble_local_key=$ret

    ble/util/print "ble/$1#set $2 $_ble_local_key $_ble_local_value"
  done
}
function ble/dict#print { ble/dict/.print dict "$1"; }
function ble/adict#print { ble/dict/.print adict "$1"; }
function ble/gdict#print { ble/dict/.print gdict "$1"; }

function ble/dict/.copy {
  local ret
  ble/"$1"#keys "$2"
  ble/"$1"#clear "$3"
  local _ble_local_key
  for _ble_local_key in "${ret[@]}"; do
    ble/"$1"#get "$2" "$_ble_local_key"
    ble/"$1"#set "$3" "$_ble_local_key" "$ret"
  done
}
function ble/dict#cp { ble/dict/.copy dict "$1" "$2"; }
function ble/adict#cp { ble/dict/.copy adict "$1" "$2"; }
function ble/gdict#cp { ble/dict/.copy gdict "$1" "$2"; }

#------------------------------------------------------------------------------
# assign: reading files/streams into variables
#

## @fn ble/util/readfile var filename
## @fn ble/util/mapfile arr < filename
##   Read the contents of a file into a variable or array.
##
##   @param[in] var
##     Specify the variable name to store the read contents.
##   @param[in] arr
##     Specify the name of the array that stores the read contents row by row.
##   @param[in] filename
##     Specifies the location of the file to read.
##
## Note: I considered the possibility of using $(< file) in bash-5.2 or higher, but the trailing newline
##   The fact that it disappears, and that there is no speed difference that makes it possible to use the trailing newline undefined,
##   For these reasons, we decided to postpone hiring him.
if ((_ble_bash>=40000)); then
  function ble/util/readfile { # 155ms for man bash
    local -a _ble_local_buffer=()
    mapfile _ble_local_buffer < "$2"; local _ble_local_ext=$?
    IFS= builtin eval "$1=\"\${_ble_local_buffer[*]-}\""
    return "$_ble_local_ext"
  }
  function ble/util/mapfile {
    mapfile -t "$1"
  }
else
  function ble/util/readfile { # 465ms for man bash
    [[ -r $2 && ! -d $2 ]] || return 1
    local IFS=
    ble/bash/read -d '' "$1" < "$2"
    return 0
  }
  function ble/util/mapfile {
    local IFS=
    local _ble_local_i=0 _ble_local_val _ble_local_arr; _ble_local_arr=()
    while ble/bash/read _ble_local_val || [[ $_ble_local_val ]]; do
      _ble_local_arr[_ble_local_i++]=$_ble_local_val
    done
    builtin eval "$1=(\"\${_ble_local_arr[@]}\")"
  }
fi

function ble/util/copyfile {
  local src=$1 dst=$2 content
  ble/util/readfile content "$1" || return "$?"
  ble/util/put "$content" >| "$dst"
}

## @fn ble/util/writearray [OPTIONS] arr
##   Outputs the contents of an array in a readable format.
##
## OPTIONS
##   -- Subsequent arguments are normal arguments
##   -d delim Sets the character used to separate array elements.
##            The default value is newline "\n".
##   --nlfix Output with line breaks separated. Use $'' when the element contains line breaks.
##            and escape the contents. List of element numbers that include line breaks
##            Add to the last element.
##
function ble/util/writearray/.read-arguments {
  _ble_local_array=
  _ble_local_nlfix=
  _ble_local_delim=$'\n'
  local flags=
  while (($#)); do
    local arg=$1; shift
    if [[ $flags != *-* && $arg == -* ]]; then
      case $arg in
      (--nlfix) _ble_local_nlfix=1 ;;
      (-d)
        if (($#)); then
          _ble_local_delim=$1; shift
        else
          ble/util/print "${FUNCNAME[1]}: '$arg': missing option argument." >&2
          flags=E$flags
        fi ;;
      (--) flags=-$flags ;;
      (*)
        ble/util/print "${FUNCNAME[1]}: '$arg': unrecognized option." >&2
        flags=E$flags ;;
      esac
    else
      if local rex='^[_a-zA-Z][_a-zA-Z0-9]*$'; ! [[ $arg =~ $rex ]]; then
        ble/util/print "${FUNCNAME[1]}: '$arg': invalid array name." >&2
        flags=E$flags
      elif [[ $flags == *A* ]]; then
        ble/util/print "${FUNCNAME[1]}: '$arg': an array name has been already specified." >&2
        flags=E$flags
      else
        _ble_local_array=$arg
        flags=A$flags
      fi
    fi
  done
  [[ $_ble_local_nlfix ]] && _ble_local_delim=$'\n'
  [[ $flags != *E* ]]
}

_ble_bin_awk_libES='
  function s2i_initialize(_, i) {
    for (i = 0; i < 16; i++)
      xdigit2int[sprintf("%x", i)] = i;
    for (i = 10; i < 16; i++)
      xdigit2int[sprintf("%X", i)] = i;
  }
  function s2i(s, base, _, i, n, r) {
    if (!base) base = 10;
    r = 0;
    n = length(s);
    for (i = 1; i <= n; i++)
      r = r * base + xdigit2int[substr(s, i, 1)];
    return r;
  }

  # ENCODING: UTF-8
  function c2s_initialize(_, i, n, buff) {
    if (sprintf("%c", 945) == "α") {
      C2S_UNICODE_PRINTF_C = 1;
      n = split(ENVIRON["__ble_rawbytes"], buff);
      for (i = 1; i <= n; i++)
        c2s_byte2raw[127 + i] = buff[i];
    } else {
      C2S_UNICODE_PRINTF_C = 0;
      for (i = 1; i <= 255; i++)
        c2s_byte2char[i] = sprintf("%c", i);
    }
  }
  function c2s(code, _, leadbyte_mark, leadbyte_sup, tail) {
    if (C2S_UNICODE_PRINTF_C)
      return sprintf("%c", code);

    leadbyte_sup = 128; # 0x80
    leadbyte_mark = 0;
    tail = "";
    while (leadbyte_sup && code >= leadbyte_sup) {
      leadbyte_sup /= 2;
      leadbyte_mark = leadbyte_mark ? leadbyte_mark / 2 : 65472; # 0xFFC0
      tail = c2s_byte2char[128 + int(code % 64)] tail;
      code = int(code / 64);
    }
    return c2s_byte2char[(leadbyte_mark + code) % 256] tail;
  }
  function c2s_raw(code, _, ret) {
    if (code >= 128 && C2S_UNICODE_PRINTF_C) {
      ret = c2s_byte2raw[code];
      if (ret != "") return ret;
    }
    return sprintf("%c", code);
  }

  function es_initialize(_, c) {
    s2i_initialize();
    c2s_initialize();
    es_control_chars["a"] = "\a";
    es_control_chars["b"] = "\b";
    es_control_chars["t"] = "\t";
    es_control_chars["n"] = "\n";
    es_control_chars["v"] = "\v";
    es_control_chars["f"] = "\f";
    es_control_chars["r"] = "\r";
    es_control_chars["e"] = "\033";
    es_control_chars["E"] = "\033";
    es_control_chars["?"] = "?";
    es_control_chars["'\''"] = "'\''";
    es_control_chars["\""] = "\"";
    es_control_chars["\\"] = "\\";

    for (c = 32; c < 127; c++)
      es_s2c[sprintf("%c", c)] = c;
  }
  function es_unescape(s, _, head, c) {
    head = "";
    while (match(s, /^[^\\]*\\/)) {
      head = head substr(s, 1, RLENGTH - 1);
      s = substr(s, RLENGTH + 1);
      if ((c = es_control_chars[substr(s, 1, 1)])) {
        head = head c;
        s = substr(s, 2);
      } else if (match(s, /^[0-9]([0-9][0-9]?)?/)) {
        head = head c2s_raw(s2i(substr(s, 1, RLENGTH), 8) % 256);
        s = substr(s, RLENGTH + 1);
      } else if (match(s, /^x[0-9a-fA-F][0-9a-fA-F]?/)) {
        head = head c2s_raw(s2i(substr(s, 2, RLENGTH - 1), 16));
        s = substr(s, RLENGTH + 1);
      } else if (match(s, /^U[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]([0-9a-fA-F]([0-9a-fA-F][0-9a-fA-F]?)?)?/)) {
        # \\U[0-9]{5,8}
        head = head c2s(s2i(substr(s, 2, RLENGTH - 1), 16));
        s = substr(s, RLENGTH + 1);
      } else if (match(s, /^[uU][0-9a-fA-F]([0-9a-fA-F]([0-9a-fA-F][0-9a-fA-F]?)?)?/)) {
        # \\[uU][0-9]{1,4}
        head = head c2s(s2i(substr(s, 2, RLENGTH - 1), 16));
        s = substr(s, RLENGTH + 1);
      } else if (match(s, /^c[ -~]/)) { # disable=#D1440 (caller is checked)
        # \\c[ -~] (non-ascii characters are unsupported)
        c = es_s2c[substr(s, 2, 1)];
        head = head c2s(_ble_bash >= 40400 && c == 63 ? 127 : c % 32);
        s = substr(s, 3);
      } else {
        head = head "\\";
      }
    }
    return head s;
  }
'
_ble_bin_awk_libNLFIX='
  ## @var nlfix_index
  ## @var nlfix_indices
  ## @var nlfix_rep_slash
  ## @var nlfix_rep_double_slash
  ## @fn nlfix_escape(s)
  ## @fn nlfix_unescape(s)
  ## @fn nlfix_put(s)
  ## @fn nlfix_begin()
  ## @fn nlfix_push(elem)
  ## @fn nlfix_end()
  function nlfix_escape(str) {
    gsub(/\\/,   nlfix_rep_double_slash, str);
    gsub(/'\''/, nlfix_rep_slash "'\''", str);
    gsub(/\007/, nlfix_rep_slash "a",    str);
    gsub(/\010/, nlfix_rep_slash "b",    str);
    gsub(/\011/, nlfix_rep_slash "t",    str);
    gsub(/\012/, nlfix_rep_slash "n",    str);
    gsub(/\013/, nlfix_rep_slash "v",    str);
    gsub(/\014/, nlfix_rep_slash "f",    str);
    gsub(/\015/, nlfix_rep_slash "r",    str);
    return "$'\''" str "'\''";
  }
  function nlfix_unescape(str) {
    if (str !~ /^\$'\''.*'\''$/) return str;
    str = substr(str, 3, length(str) - 3);
    gsub(/\\'\''/, "'\''", str);
    gsub(/\\a/, "\007", str);
    gsub(/\\b/, "\010", str);
    gsub(/\\t/, "\011", str);
    gsub(/\\n/, "\012", str);
    gsub(/\\v/, "\013", str);
    gsub(/\\f/, "\014", str);
    gsub(/\\r/, "\015", str);
    gsub(/\\\\/, nlfix_rep_slash, str);
    return str;
  }
  function nlfix_put(s) {
    if (file)
      printf("%s", s) > file;
    else
      printf("%s", s);
  }
  function nlfix_begin(_, tmp) {
    nlfix_rep_slash = "\\";
    if (AWKTYPE == "xpg4") nlfix_rep_slash = "\\\\";

    nlfix_rep_double_slash = "\\\\";
    sub(/.*/, nlfix_rep_double_slash, tmp);
    if (tmp == "\\") nlfix_rep_double_slash = "\\\\\\\\";

    nlfix_indices = "";
    nlfix_index = 0;
  }
  function nlfix_push(elem, file) {
    if (elem ~ /\n/) {
      nlfix_put(nlfix_escape(elem) "\n");
      nlfix_indices = nlfix_indices != "" ? nlfix_indices " " nlfix_index : nlfix_index;
    } else {
      nlfix_put(elem "\n");
    }
    nlfix_index++;
  }
  function nlfix_end(file) {
    nlfix_put(nlfix_indices "\n");
  }
'
_ble_util_writearray_rawbytes=
function ble/util/writearray {
  local _ble_local_array
  local -x _ble_local_nlfix _ble_local_delim
  ble/util/writearray/.read-arguments "$@" || return 2

  # select the fastest awk implementation
  local __ble_awk=ble/bin/awk __ble_awktype=$_ble_bin_awk_type
  if ble/is-function ble/bin/mawk; then
    __ble_awk=ble/bin/mawk __ble_awktype=mawk
  elif ble/is-function ble/bin/nawk; then
    __ble_awk=ble/bin/nawk __ble_awktype=nawk
  fi

  # Note: printf is also slow, but parse by awk is slower, so unless you use nlfix, you can't use it directly.
  # Use printf directly. However, printf is significantly slower in bash-5.2 and later, so avoid it.
  if ((!_ble_local_nlfix)) && ! [[ _ble_bash -ge 50200 && $__ble_awktype == [mn]awk ]]; then
    if [[ $_ble_local_delim ]]; then
      if [[ $_ble_local_delim == *["%\'"]* ]]; then
        local __ble_q=\' __ble_Q="'\''"
        _ble_local_delim=${_ble_local_delim//'%'/'%%'}
        _ble_local_delim=${_ble_local_delim//'\'/'\\'}
        _ble_local_delim=${_ble_local_delim//$__ble_q/$__ble_Q}
      fi
      builtin eval "printf '%s$_ble_local_delim' \"\${$_ble_local_array[@]}\""
    else
      builtin eval "printf '%s\0' \"\${$_ble_local_array[@]}\""
    fi
    return "$?"
  fi

  # Note: mawk will attempt to use an undefined function without actually
  # Even if it does not run, the compilation will fail and it will not work.
  local __ble_function_gensub_dummy=
  [[ $__ble_awktype == gawk ]] ||
    __ble_function_gensub_dummy='function gensub(rex, rep, n, str) { exit 3; }'

  # Note: gawk internally cannot generate bytes that are not in the current code from $'\302' etc.
  # Therefore, it is given from outside.
  if [[ ! $_ble_util_writearray_rawbytes ]]; then
    local IFS=$_ble_term_IFS __ble_tmp; __ble_tmp=('\'{2,3}{0..7}{0..7})
    builtin eval "local _ble_util_writearray_rawbytes=\$'${__ble_tmp[*]}'"
  fi
  local -x __ble_rawbytes=$_ble_util_writearray_rawbytes

  local __ble_rex_dq='^"([^\\"]|\\.)*"'
  local __ble_rex_es='^\$'\''([^\\'\'']|\\.)*'\'''
  local __ble_rex_sq='^'\''([^'\'']|'\'\\\\\'\'')*'\'''
  local __ble_rex_normal=$'^[^'$_ble_term_blank'$`"'\''()|&;<>\\]' # Note: []{}?*#!~^, @(), +() are OK even if they are not quoted.
  declare -p "$_ble_local_array" | "$__ble_awk" -v _ble_bash="$_ble_bash" '
    '"$__ble_function_gensub_dummy"'
    BEGIN {
      DELIM = ENVIRON["_ble_local_delim"];
      FLAG_NLFIX = ENVIRON["_ble_local_nlfix"];
      if (FLAG_NLFIX) DELIM = "\n";

      IS_GAWK = AWKTYPE == "gawk";
      IS_XPG4 = AWKTYPE == "xpg4";

      REP_SL = "\\";
      if (IS_XPG4) REP_SL = "\\\\";

      es_initialize();

      decl = "";
    }

    '"$_ble_bin_awk_libES"'
    '"$_ble_bin_awk_libNLFIX"'

    # Note: "str" must not contain "&" or "\\\\".  When "&" is
    # present, the escaping rule for "\\" changes in some awk.
    # Now there is no problem because only DELIM (one character) is
    # currently passed.
    function str2rep(str) {
      if (IS_XPG4) sub(/\\/, "\\\\\\\\", str);
      return str;
    }


    function unquote_dq(s, _, head) {
      if (IS_GAWK) {
        return gensub(/\\([$`"\\])/, "\\1", "g", s);
      } else {
        if (s ~ /\\[$`"\\]/) {
          gsub(/\\\$/, "$" , s);
          gsub(/\\`/ , "`" , s);
          gsub(/\\"/ , "\"", s);
          gsub(/\\\\/, "\\", s);
        }
        return s;
      }
    }
    function unquote_sq(s) {
      gsub(/'\'\\\\\'\''/, "'\''", s);
      return s;
    }
    function unquote_dqes(s) {
      if (s ~ /^"/)
        return unquote_dq(substr(s, 2, length(s) - 2));
      else
        return es_unescape(substr(s, 3, length(s) - 3)); # disable=#D1440 (\c? is unused)
    }
    function unquote(s) {
      if (s ~ /^"/)
        return unquote_dq(substr(s, 2, length(s) - 2));
      else if (s ~ /^\$/)
        return es_unescape(substr(s, 3, length(s) - 3)); # disable=#D1440 (\c? is unused)
      else if (s ~ /^'\''/)
        return unquote_sq(substr(s, 2, length(s) - 2));
      else if (s ~ /^\\/)
        return substr(s, 2, 1);
      else
        return s;
    }

#% # If the control character is not included in the element, it should all be in the format [1]="...".
    function analyze_elements_dq(decl, _, arr, i, n) {
      if (decl ~ /^\[[0-9]+\]="([^'$'\1\2''"\n\\]|\\.)*"( \[[0-9]+\]="([^\1\2"\\]|\\.)*")*$/) {
        if (IS_GAWK) {
          decl = gensub(/\[[0-9]+\]="(([^"\\]|\\.)*)" ?/, "\\1\001", "g", decl);
          sub(/\001$/, "", decl);
          decl = gensub(/\\([\\$"`])/, "\\1", "g", decl);
        } else {
          # Convert to a ^A-separated list
          gsub(/\[[0-9]+\]="([^"\\]|\\.)*" /, "&\001", decl);
          gsub(/" \001\[[0-9]+\]="/, "\001", decl);
          sub(/^\[[0-9]+\]="/, "", decl);
          sub(/"$/, "", decl);

          # Unescape
          gsub(/\\\\/, "\002", decl);
          gsub(/\\\$/, "$", decl);
          gsub(/\\"/, "\"", decl);
          gsub(/\\`/, "`", decl);
          gsub(/\002/, REP_SL, decl);
        }

        # Output
        if (DELIM != "") {
          gsub(/\001/, str2rep(DELIM), decl);
          printf("%s", decl DELIM);
        } else {
          n = split(decl, arr, /\001/);
          for (i = 1; i <= n; i++)
            printf("%s%c", arr[i], 0);
        }

#% # When using the [N]="" format, it is assumed that there is no line break within the element.
        if (FLAG_NLFIX) printf("\n");

        return 1;
      }
      return 0;
    }

    function _process_elem(elem) {
      if (FLAG_NLFIX) {
        nlfix_push(elem);
      } else if (DELIM != "") {
        printf("%s", elem DELIM);
      } else {
        printf("%s%c", elem, 0);
      }
    }

#% # In any case, this function will process it, although it will be a little slower.
    function analyze_elements_general(decl, _, arr, i, n, str, elem, m) {
      if (FLAG_NLFIX)
        nlfix_begin();

      # Note: We here assume that all the elements have the form [N]=...
      # Note: We here assume that the original array has at least one element
      n = split(decl, arr, /\]=/);
      str = " " arr[1];
      elem = "";
      first = 1;
      for (i = 2; i <= n; i++) {
        str = str "]=" arr[i];
        if (sub(/^ \[[0-9]+\]=/, "", str)) {
          if (first)
            first = 0;
          else
            _process_elem(elem);
          elem = "";
        }

        if (match(str, /('"$__ble_rex_dq"'|'"$__ble_rex_es"') /)) {
          mlen = RLENGTH;
          elem = elem unquote_dqes(substr(str, 1, mlen - 1));
          str = substr(str, mlen);
          continue;
        } else if (i == n || str !~ /^[\$"]/) {
          # Fallback: As far as all the values have the form "" or $'', the
          # control would only enter this branch for the last element.
          while (match(str, /'"$__ble_rex_dq"'|'"$__ble_rex_es"'|'"$__ble_rex_sq"'|'"$__ble_rex_normal"'|^\\./)) {
            mlen = RLENGTH;
            elem = elem unquote(substr(str, 1, mlen));
            str = substr(str, mlen + 1);
          }
        }
      }
      _process_elem(elem);

      if (FLAG_NLFIX)
        nlfix_end();
      return 1;
    }

    function process_declaration(decl) {
#% # declare remove
      sub(/^declare +(-[-aAilucnrtxfFgGI]+ +)?(-- +)?/, "", decl);

#% # Remove entire quote
      if (decl ~ /^([_a-zA-Z][_a-zA-Z0-9]*)='\''\(.*\)'\''$/) {
        # Note: nawk in Solaris 2.11 does not allow regex to start with /=.
        sub(/(=)'\''\(/, "=(", decl);
        sub(/\)'\''$/, ")", decl);
        gsub(/'\'\\\\\'\''/, "'\''", decl);
      }

#% # bash-3.0's declare -p gives incorrect output about newlines.
      if (_ble_bash < 30100) gsub(/\\\n/, "\n", decl);

#% # #D1238 Before bash-4.3, declare -p changed ^A, ^?
#% # ^A^A, ^A^? is output, so correct it.
#% # #D1325 Furthermore, in Bash-3.0, "x${_ble_term_DEL}y"
#% # The contents of _ble_term_DEL will be deleted.
#% # Must be "x""${_ble_term_DEL}""y".
      if (_ble_bash < 40400) {
        gsub(/\001\001/, "\001", decl);
        gsub(/\001\177/, "\177", decl);
      }

      sub(/^([_a-zA-Z][_a-zA-Z0-9]*)=\(['"$_ble_term_blank"']*/, "", decl);
      sub(/['"$_ble_term_blank"']*\)['"$_ble_term_blank"']*$/, "", decl);

#% # empty array
      if (decl == "") return 1;

#% # Fast implementation when only [N]="value". mawk seems to be slower.
      if (AWKTYPE != "mawk" && analyze_elements_dq(decl)) return 1;

      return analyze_elements_general(decl);
    }
    { decl = decl ? decl "\n" $0: $0; }
    END { process_declaration(decl); }
  '
}
function ble/util/readarray {
  local _ble_local_array
  local -x _ble_local_nlfix _ble_local_delim
  ble/util/writearray/.read-arguments "$@" || return 2

  if ((_ble_bash>=40400)); then
    local _ble_local_script='
      mapfile -t -d "$_ble_local_delim" NAME'
  elif ((_ble_bash>=40000)) && [[ $_ble_local_delim == $'\n' ]]; then
    local _ble_local_script='
      mapfile -t NAME'
  else
    local _ble_local_script='
      local IFS= NAMEI=0; NAME=()
      while ble/bash/read -d "$_ble_local_delim" "NAME[NAMEI++]"; do ((1)); done'
  fi

  if [[ $_ble_local_nlfix ]]; then
    _ble_local_script=$_ble_local_script'
      local NAMEN=${#NAME[@]} NAMEF NAMEI
      if ((NAMEN--)); then
        ble/string#split-words NAMEF "${NAME[NAMEN]}"
        builtin unset -v "NAME[NAMEN]"
        for NAMEI in "${NAMEF[@]}"; do
          builtin eval -- "NAME[NAMEI]=${NAME[NAMEI]}"
        done
      fi'
  fi
  builtin eval -- "${_ble_local_script//NAME/$_ble_local_array}"
}

## @fn ble/util/assign var command
##   A fast alternative to var=$(command). command is the current shell, not a subshell
##   will be executed. Roughly equivalent to var=${ command; } in Bash 5.3.
##
##   @param[in] var
##     Specify the variable name to which to assign.
##   @param[in] command...
##     Specifies the command to run.
##
## @remarks In util.bgproc.sh « ble/util/assign bgpid '(set -m; command &
##   Assuming that a process group is created with bgpid=$!; ble/util/print "$bgpid")' »
##   I am doing it. For example, bgpid=$(...) cannot be used because a process group is not created.
##
## @remarks There is small behavioral differences between the implementation by
##   the function substitution and the manual implementation using temporary
##   files.  In the function substitutions, the update of the job list is
##   suppressed, so the notified dead jobs are not flushed on just running
##   ble/util/assign jobs jobs.
##
## @remarks This function is intended to work under POSIXLY_CORRECT=y when it
##   is called by ble/base/adjust-builtin-wrappers/.impl1.
##
_ble_util_assign_base=$_ble_base_run/$$.util.assign.tmp
_ble_util_assign_level=0
if ((_ble_bash>=40000)); then
  function ble/util/assign/mktmp {
    _ble_local_tmpfile=$_ble_util_assign_base.$((_ble_util_assign_level++))
    ((BASH_SUBSHELL)) && _ble_local_tmpfile=$_ble_local_tmpfile.$BASHPID
  }
else
  function ble/util/assign/mktmp {
    _ble_local_tmpfile=$_ble_util_assign_base.$((_ble_util_assign_level++))
    ((BASH_SUBSHELL)) && _ble_local_tmpfile=$_ble_local_tmpfile.$RANDOM
  }
fi
function ble/util/assign/rmtmp {
  ((_ble_util_assign_level--))
#%if !release
  if ((BASH_SUBSHELL)); then
    printf 'caller %s\n' "${FUNCNAME[@]}" >| "$_ble_local_tmpfile"
  else
    >| "$_ble_local_tmpfile"
  fi
#%else
  >| "$_ble_local_tmpfile"
#%end
}
if ((_ble_bash>=50300)); then
  function ble/util/assign {
    builtin eval -- "$1=\${ builtin eval -- \"\$2\"; }"
  }
elif ((_ble_bash>=40000)); then
  # mapfile is faster than read
  function ble/util/assign {
    local _ble_local_tmpfile; ble/util/assign/mktmp
    builtin eval -- "$2" >| "$_ble_local_tmpfile"
    local _ble_local_ret=$? _ble_local_arr=
    mapfile -t _ble_local_arr < "$_ble_local_tmpfile"
    ble/util/assign/rmtmp
    local IFS=$'\n' # avoid tmpenv to make it POSIXLY_CORRECT-safe
    builtin eval -- "$1=\"\${_ble_local_arr[*]}\""
    return "$_ble_local_ret"
  }
else
  function ble/util/assign {
    local _ble_local_tmpfile; ble/util/assign/mktmp
    builtin eval -- "$2" >| "$_ble_local_tmpfile"
    local _ble_local_ret=$? IFS=
    ble/bash/read -d '' "$1" < "$_ble_local_tmpfile"
    ble/util/assign/rmtmp
    builtin eval -- "$1=\${$1%\$_ble_term_nl}"
    return "$_ble_local_ret"
  }
fi
## @fn ble/util/assign-array arr command args...
##   Fast alternative to mapfile -t arr < <(command ...).
##   command is executed in the current shell, not in a subshell.
##
##   @param[in] arr
##     Specify the array name to which to assign.
##   @param[in] command
##     Specifies the command to run.
##   @param[in] args...
##     Specify the arguments ($3 $4 ...) to reference from command.
##
if ((_ble_bash>=40000)); then
  function ble/util/assign-array {
    local _ble_local_tmpfile; ble/util/assign/mktmp
    builtin eval -- "$2" >| "$_ble_local_tmpfile"
    local _ble_local_ret=$?
    mapfile -t "$1" < "$_ble_local_tmpfile"
    ble/util/assign/rmtmp
    return "$_ble_local_ret"
  }
else
  function ble/util/assign-array {
    local _ble_local_tmpfile; ble/util/assign/mktmp
    builtin eval -- "$2" >| "$_ble_local_tmpfile"
    local _ble_local_ret=$?
    ble/util/mapfile "$1" < "$_ble_local_tmpfile"
    ble/util/assign/rmtmp
    return "$_ble_local_ret"
  }
fi

if ! ((_ble_bash>=40400)); then
  function ble/util/assign-array0 {
    local _ble_local_tmpfile; ble/util/assign/mktmp
    builtin eval -- "$2" >| "$_ble_local_tmpfile"
    local _ble_local_ret=$?
    mapfile -d '' -t "$1" < "$_ble_local_tmpfile"
    ble/util/assign/rmtmp
    return "$_ble_local_ret"
  }
else
  function ble/util/assign-array0 {
    local _ble_local_tmpfile; ble/util/assign/mktmp
    builtin eval -- "$2" >| "$_ble_local_tmpfile"
    local _ble_local_ret=$?
    local IFS= i=0 _ble_local_arr
    while ble/bash/read -d '' "_ble_local_arr[i++]"; do ((1)); done < "$_ble_local_tmpfile"
    ble/util/assign/rmtmp
    [[ ${_ble_local_arr[--i]} ]] || builtin unset -v "_ble_local_arr[i]"
    ble/util/unlocal i IFS
    builtin eval "$1=(\"\${_ble_local_arr[@]}\")"
    return "$_ble_local_ret"
  }
fi

## @fn ble/util/assign.has-output command
function ble/util/assign.has-output {
  local _ble_local_tmpfile; ble/util/assign/mktmp
  builtin eval -- "$1" >| "$_ble_local_tmpfile"
  [[ -s $_ble_local_tmpfile ]]
  local _ble_local_ret=$?
  ble/util/assign/rmtmp
  return "$_ble_local_ret"
}

function ble/util/assign-words {
  ble/util/assign "$1" "$2"
  ble/string#split-words "$1" "${!1}"
}

function ble/util/eval-stdout {
  local _ble_local_script
  ble/util/assign _ble_local_script "$1"
  builtin eval -- "$_ble_local_script"
}

if ((_ble_bash>=50300)); then
  function ble/util/compgen { builtin compgen -V "$@"; }
else
  function ble/util/compgen {
    local _ble_local_args
    _ble_local_compgen_args=("${@:2}")
    ble/util/assign-array "$1" 'builtin compgen "${_ble_local_compgen_args[@]}"'
  }
fi


#
# functions
#

## @fn ble/is-function function
##   Tests whether function function exists.
##
##   @param[in] function
##     Specifies the name of the function to check for existence.
##
if ((_ble_bash>=30200)); then
  function ble/is-function {
    declare -F -- "$1" &>/dev/null
  }
else
  # bash-3.1 has bug in declare -f.
  # it does not accept a function name containing non-alnum chars.
  function ble/is-function {
    local type
    ble/util/type type "$1"
    [[ $type == function ]]
  }
fi

# Since we use ble/util/assign and ble/is-function to initialize ble/bin/awk,
ble/bin/awk/.instantiate

## @fn ble/function#getdef function
##   @var[out] def
##
## Note: How to get function definitions where declare -pf "$name" does not depend on -o posix
##   It seemed to be legal, but when I use declare -pf "$name", the -t attribute is added.
##   When I was using the command, I added an extra attribute to the end of the command: declare -ft name.
##   will be included. Or maybe it would be better to save this attribute as well.
##   However, for now, use declare -pf name so that no attributes are included.
##   No.
if ((_ble_bash>=30200)); then
  function ble/function#getdef {
    local name=$1
    ble/is-function "$name" || return 1
    if [[ -o posix ]]; then
      ble/util/assign def 'builtin type -- "$name"'
      def=${def#*$'\n'}
    else
      ble/util/assign def 'declare -f -- "$name"'
    fi
  }
else
  function ble/function#getdef {
    local name=$1
    ble/is-function "$name" || return 1
    ble/util/assign def 'builtin type -- "$name"'
    def=${def#*$'\n'}
  }
fi

## @fn ble/function#evaldef def
##   Define the function. Basically equivalent to eval, but when evaluating, use shopt -s extglob and
##   shopt -u expand_aliases ensures.
function ble/function#evaldef {
  ble/base/evaldef "$1"
}

function ble/function#has-attr {
  local __ble_tmp=$1
  ble/util/assign-array __ble_tmp 'declare -pf -- "$__ble_tmp" 2>/dev/null'
  local nline=${#__ble_tmp[@]}
  ((nline)) &&
    ble/string#match "${__ble_tmp[nline-1]}" '^declare -([a-zA-Z]*)' &&
    [[ ${BASH_REMATCH[1]} == *["$2"]* ]]
}

builtin eval -- "${_ble_util_gdict_declare//NAME/_ble_util_function_traced}"
function ble/function#trace {
  local func
  for func; do
    declare -ft -- "$func" &>/dev/null || continue
    ble/gdict#set _ble_util_function_traced "$func" 1
  done
}
function ble/function#.has-trace {
  ble/gdict#has _ble_util_function_traced "$1"
}
function ble/function#has-trace {
  ble/function#.has-trace "$1" || ble/function#has-attr "$1" t
}
function ble/function#copy-trace {
  ble/function#has-trace "$1" && ble/function#trace "$2"
}

function ble/function#.copy-primitive {
  local def
  ble/function#getdef "$1" || return 1
  local def_new=${def/#"$1"/"$2"}
  [[ $def_new == "$def" ]] && return 1
  ble/function#evaldef "$def_new" || return 1
  ble/function#copy-trace "$1" "$2"
  return 0
}

## @fn ble/function/is-global-trace-context
##   Make sure that the global DEBUG is visible in the context of the caller of this function.
##   I will judge.
function ble/function/is-global-trace-context {
  # Note: Even if set -T is set, it is not the same as the one set by global.
  #   I don't know if it's something set somewhere deep in the call. So set -T
  #   Just because ``global'' is set does not mean that ``global'' is unconditionally visible.
  # Note: Functions belonging to ble do not automatically enable set -T temporarily.
  #   Since there is no such thing, I will allow it. However, when temporarily restoring-bash-options internally
  #   There is, but inside it, ble-attach or ble/function/is-global-trace-context etc.
  #   Assume that there is no need to execute .
  local func depth=1 ndepth=${#FUNCNAME[*]}
  for func in "${FUNCNAME[@]:1}"; do
    local src=${BASH_SOURCE[depth]}
    [[ $- == *T* && ( $func == ble || $func == ble[-/]* || $func == source && $src == "$_ble_base_blesh_raw" ) ]] ||
      [[ $func == source && depth -eq ndepth-1 && BASH_LINENO[depth] -eq 0 && ( ${src##*/} == .bashrc || ${src##*/} == .bash_profile || ${src##*/} == .profile ) ]] ||
      ble/gdict#has _ble_util_function_traced "$func" || return 1
    ((depth++))
  done
  return 0
}

## @fn ble/function#try function args...
##   Calls the function only if function exists.
##
##   @param[in] function
##     Specifies the name of the function to check for existence and execute.
##   @param[in] args
##     Specify the arguments to pass to the function.
##   @exit Returns the exit status of the function if it was called.
##     Returns 127 if the function does not exist.
##
function ble/function#try {
  local lastexit=$?
  ble/is-function "$1" || return 127
  ble/util/setexit "$lastexit"
  "$@"
}

function ble/function#get-source-and-lineno {
  local func=$1 ret unset_extdebug=
  shopt -q extdebug || { unset_extdebug=1; shopt -s extdebug; }
  ble/util/assign ret 'declare -F -- "$func" 2>/dev/null'; local ext=$?
  [[ ! $unset_extdebug ]] || shopt -u extdebug
  if ((ext==0)); then
    ret=${ret#*' '}
    lineno=${ret%%' '*}
    source=${ret#*' '}
    [[ $lineno && ! ${lineno//[0-9]} && $source ]] || return 1
  fi
  return "$ext"
}

## @fn ble/function#advice [-f] type function proc
##   Change the behavior of an existing function.
##
##   @option -f
##     Process only when the function exists. An error message is displayed if the function does not exist.
##     fails without displaying any message.
##
##   @param[in] type
##     When before is specified, the process proc is inserted before the function function.
##     When after is specified, the process proc is inserted after the function function.
##     When around is specified, processing proc is performed before and after calling function.
##     Inside proc, use ble/function#advice/do to call the original function
##     must be executed.
##
##   @fn ble/function#advice/do
##     A function that can be called from around proc.
##     Call the original function.
##
##   @arr[in,out] ADVICE_WORDS
##     This is a variable that can be referenced from within proc. Provides commands used to call functions.
##     Yes. For example, if the original function call was function arg1 arg2,
## ADVICE_WORDS=(function arg1 arg2) is set. before/around
##     The function to be called or the function to be called can be changed by rewriting this array before calling the original function.
##     You can change the arguments.
##
##   @var[in.out] ADVICE_EXIT
##     This is a variable that can be referenced from within proc. Return value after function execution in after/around
##     Used to refer to or change.
##
##   @var[in.out] ADVICE_FUNCNAME
##     This is a variable that can be referenced from within proc. Adjustment of ble/function#advice from FUNCNAME
##     Saves the result with unnecessary function calls removed.
##
function ble/function#advice/do {
  ble/util/setexit "$advice_lastexit" "$advice_lastarg"
  ble/function#advice/original:"${ADVICE_WORDS[@]}"
  ADVICE_EXIT=$?
}
function ble/function#advice/.proc {
  local advice_lastexit=$? advice_lastarg=$_

  local ADVICE_WORDS ADVICE_EXIT=127
  ADVICE_WORDS=("$@")
  local -a ADVICE_FUNCNAME=()
  local func
  for func in "${FUNCNAME[@]}"; do
    [[ $func == ble/function#advice/* ]] ||
      ble/array#push ADVICE_FUNCNAME "$func"
  done
  ble/util/unlocal func

  ble/function#try ble/function#advice/before:"${ADVICE_WORDS[@]}"
  if ble/is-function ble/function#advice/around:"${ADVICE_WORDS[0]}"; then
    ble/function#advice/around:"${ADVICE_WORDS[@]}"
  else
    ble/function#advice/do
  fi
  ble/function#try ble/function#advice/after:"${ADVICE_WORDS[@]}"
  return "$ADVICE_EXIT"
}
ble/function#trace ble/function#advice/.proc
function ble/function#advice {
  local flags=
  while [[ ${1-} == -[!-]* ]]; do
    flags=$flags${1#-}
    shift
  done

  local type=$1 name=$2 proc=$3
  if ! ble/is-function "$name"; then
    local t=; ble/util/type t "$name"
    case $t in
    (builtin|file) builtin eval "function $name { : ZBe85Oe28nBdg; command $name \"\$@\"; }" ;;
    (*)
      if [[ $flags != *f* ]]; then
        ble/util/print "ble/function#advice: $name is not a function." >&2
        return 1
      else
        return 0
      fi ;;
    esac
  fi

  local def; ble/function#getdef "$name"
  case $type in
  (remove)
    if [[ $def == *'ble/function#advice/.proc'* ]]; then
      ble/function#getdef ble/function#advice/original:"$name"
      if [[ $def ]]; then
        if [[ $def == *ZBe85Oe28nBdg* ]]; then
          builtin unset -f "$name"
        else
          ble/function#evaldef "${def#*:}"
          ble/function#copy-trace ble/function#advice/original:"$name" "$name"
        fi
      fi
    fi
    builtin unset -f ble/function#advice/{before,after,around,original}:"$name" 2>/dev/null
    return 0 ;;
  (before|after|around)
    if [[ $def != *'ble/function#advice/.proc'* ]]; then
      ble/function#evaldef ble/function#advice/original:"$def"
      ble/function#copy-trace "$name" ble/function#advice/original:"$name"
      builtin eval "function $name { ble/function#advice/.proc \"\$FUNCNAME\" \"\$@\"; }"
      ble/function#copy-trace ble/function#advice/original:"$name" "$name"
    fi

    local q=\' Q="'\''"
    builtin eval "ble/function#advice/$type:$name() { builtin eval -- '${proc//$q/$Q}'; }"
    ble/function#copy-trace ble/function#advice/original:"$name" ble/function#advice/$type:"$name"
    return 0 ;;
  (*)
    ble/util/print "ble/function#advice unknown advice type '$type'" >&2
    return 2 ;;
  esac
}

## @fn ble/function#push name [proc]
## @fn ble/function#pop name
##   This function saves and restores function definitions.
##
function ble/function#push {
  local name=$1 proc=$2
  if ble/is-function "$name"; then
    local index=0
    while ble/is-function "ble/function#push/$index:$name"; do
      ((++index))
    done

    ble/function#.copy-primitive "$name" "ble/function#push/$index:$name"
  else
    builtin eval "function ble/function#push/0:$name { command $name \"\$@\"; }"
    builtin eval "function ble/function#push/empty:$name { return 0; }"
  fi

  if [[ $proc ]]; then
    local q=\' Q="'\''"
    builtin eval "function $name { builtin eval -- '${proc//$q/$Q}'; }"
  else
    builtin unset -f "$name"
  fi
  return 0
}
function ble/function#pop {
  local name=$1 proc=$2

  local index=-1
  while ble/is-function "ble/function#push/$((index+1)):$name"; do
    ((++index))
  done

  if ((index<0)); then
    ble/util/print "ble/function#pop: $name is not a pushed function." >&2
    return 1
  else
    if ((index==0)) && ble/is-function "ble/function#push/empty:$name"; then
      builtin unset -f "$name"
      builtin unset -f "ble/function#push/empty:$name"
    else
      ble/function#.copy-primitive "ble/function#push/$index:$name" "$name"
    fi
    builtin unset -f "ble/function#push/$index:$name"
    return 0
  fi
}
function ble/function#push/call-top {
  local level
  for ((level=1;level<${#FUNCNAME[@]}&&level<=2;level++)); do
    local func=${FUNCNAME[level]} index=0
    if [[ $func == ble/function#push/[0-9]*:?* ]]; then
      index=${func#*/*/}; index=${index%%:*}
      func=${func#*:}
    else
      while ble/is-function "ble/function#push/$index:$func"; do ((index++)); done
    fi

    if ((index)); then
      "ble/function#push/$((index-1)):$func" "$@"
      return "$?"
    fi
  done

  ble/util/print "error(ble/function#push/call-top): called outside a pushed function" >&2
  return 2
}
ble/function#trace ble/function#push/call-top

: "${_ble_util_lambda_count:=0}"
## @fn ble/function#lambda var body
##   Define an anonymous function and store its actual name in the variable var.
function ble/function#lambda {
  local _ble_local_q=\' _ble_local_Q="'\''"
  if ((_ble_bash>=50300)); then
    ble/util/set "$1" "ble::function#lambda::$((_ble_util_lambda_count++))" # WA #D2221
  else
    ble/util/set "$1" "ble/function#lambda/$((_ble_util_lambda_count++))"
  fi
  builtin eval -- "function ${!1} { builtin eval -- '${2//$_ble_local_q/$_ble_local_Q}'; }"
}

## @fn ble/function#suppress-stderr function_name
##   @param[in] function_name
function ble/function#suppress-stderr {
  local name=$1
  if ! ble/is-function "$name"; then
    ble/util/print "$FUNCNAME: '$name' is not a function name" >&2
    return 2
  fi

  # In case of duplicate suppress-stderr, save the implementation only when it is undefined
  local lambda=ble/function#suppress-stderr:$name
  if ! ble/is-function "$lambda"; then
    ble/function#.copy-primitive "$name" "$lambda"
  fi

  builtin eval "function $name { $lambda \"\$@\" 2>/dev/null; }"
  return 0
}

## @fn ble/function#copy func1 func2
##   Copy a function to another name with care of ble/function#advice,
##   ble/function#push, and ble/function#suppress-error
##   @var[in] func1
##     The name of existing function to be copied.
##   @var[in] func2
##     The target function name to which func1 is copied.
function ble/function#copy {
  [[ $1 == "$2" ]] && return 0
  ble/function#.copy-primitive "$1" "$2" || return 1

  local prefix
  for prefix in advice/{original,before,after,around} suppress-stderr; do
    ble/function#.copy-primitive "ble/function#$prefix:$1" "ble/function#$prefix:$2"
  done

  local index=0
  while ble/function#.copy-primitive "ble/function#push/$index:$1" "ble/function#push/$index:$2"; do
    ((++index))
  done

  return 0
}

## @fn ble/function#copy func
##   Remove a function ble/function#advice, ble/function#push, and
##   ble/function#suppress-error
function ble/function#remove {
  ble/is-function "$1" || return 1

  builtin unset -f "$1"

  local prefix
  for prefix in advice/{original,before,after,around} suppress-stderr; do
    builtin unset -f "ble/function#$prefix:$1"
  done

  local index=0
  while ble/is-function "ble/function#push/$index:$1"; do
    builtin unset -f "ble/function#push/$((index++)):$1"
  done

  return 0
}

function ble/function#rename {
  ble/function#copy "$1" "$2" && ble/function#remove "$1"
}

#
# miscellaneous utils
#

# Note: "printf -v" for an array element is only allowed in bash-4.1
# or later.
if ((_ble_bash>=40100)); then
  function ble/util/set {
    builtin printf -v "$1" %s "$2"
  }
else
  function ble/util/set {
    builtin eval -- "$1=\"\$2\""
  }
fi

if ((_ble_bash>=30100)); then
  function ble/util/sprintf {
    builtin printf -v "$@"
  }
else
  function ble/util/sprintf {
    local -a args; args=("${@:2}")
    ble/util/assign "$1" 'builtin printf "${args[@]}"'
  }
fi

## @fn ble/util/type varname command
##   @param[out] varname
##     Specify the variable name to store the result.
##   @param[in] command
##     Specify the command name to determine the type.
function ble/util/type {
  ble/util/assign-array "$1" 'builtin type -a -t -- "$3" 2>/dev/null' "$2"
}

if ((_ble_bash>=40000)); then
  function ble/is-alias {
    [[ $1 && ${BASH_ALIASES[$1]+set} ]]
  }
  function ble/alias#active {
    shopt -q expand_aliases &&
      [[ $1 && ${BASH_ALIASES[$1]+set} ]]
  }
  ## @fn ble/alias#expand word
  ##   @var[out] ret
  ##   @exit
  ##     Succeeds when alias expansion actually occurs.
  function ble/alias#expand {
    ret=$1
    ble/alias#active "$1" && ret=${BASH_ALIASES[$1]}
  }
  ## @fn ble/alias/list
  ##   Get the list of active alias names.  When "shopt expand_aliases" is
  ##   turned off, this returns an empty array.
  ##   @arr[out] ret
  function ble/alias/list {
    if shopt -q expand_aliases; then
      ret=("${!BASH_ALIASES[@]}")
    else
      ret=()
    fi
  }
  ## @fn ble/alias/list-pairs
  ##   Extract the definitions of the currently defined aliases and store the
  ##   alias names and values to the arrays "names" and "values", respectively.
  ##   @arr[out] names values
  function ble/alias/list-pairs {
    names=() values=()
    shopt -q expand_aliases || return 0

    local alias ret
    for alias in "${!BASH_ALIASES[@]}"; do
      ble/array#push names "$alias"
      ble/string#ltrim "${BASH_ALIASES[$alias]}"
      ble/array#push values "$ret"
    done
  }
else
  function ble/is-alias {
    [[ $1 != *=* ]] && alias "$1" &>/dev/null
  }
  function ble/alias#active {
    shopt -q expand_aliases &&
      [[ $1 != *=* ]] && alias "$1" &>/dev/null
  }
  function ble/alias#expand {
    ret=$1
    local type; ble/util/type type "$ret"
    [[ $type != alias ]] && return 1
    local data; ble/util/assign data 'LC_ALL=C alias "$ret"' &>/dev/null
    [[ $data == 'alias '*=* ]] && builtin eval "ret=${data#alias *=}"
  }
  function ble/alias/list {
    ret=()
    shopt -q expand_aliases || return 0

    local data iret=0
    ble/util/assign-array data 'alias -p'
    for data in "${data[@]}"; do
      [[ $data == 'alias '*=* ]] &&
        data=${data%%=*} &&
        builtin eval "ret[iret++]=${data#alias }"
    done
  }
  function ble/alias/list-pairs {
    names=() values=()
    shopt -q expand_aliases || return 0

    local lines line ret
    ble/util/assign-array lines 'alias -p'
    for line in "${lines[@]}"; do
      [[ $line == 'alias '*=* ]] || continue
      line=${line#'alias '}
      ble/array#push names "${line%%=*}"
      builtin eval -- "ret=${line#*=}"
      ble/string#ltrim "$ret"
      ble/array#push values "$ret"
    done
  }
fi

## @fn ble/util/load-standard-builtin name [check_command]
function ble/util/load-standard-builtin {
  local ret; ble/util/readlink "$BASH"
  local bash_prefix=${ret%/*/*}

  # list possible paths of the loadable builtins
  local -a loadable_paths=()
  ((_ble_bash>=40400)) && [[ ${BASH_LOADABLE_PATHS-} ]] &&
    ble/string#split loadable_paths : "$BASH_LOADABLES_PATH"
  ble/array#push loadable_paths "$bash_prefix"/lib{,64}/bash
  [[ ! $bash_prefix ]] &&
    ble/array#push loadable_paths /usr/lib{,64}/bash

  local loadable_path
  for loadable_path in "${loadable_paths[@]}"; do
    if [[ -s $loadable_path/$1 ]] && (
         enable -f "$loadable_path/$1" "$1" &&
           help "$1" &&
           { [[ ! $2 ]] || builtin eval -- "$2"; }
       ) &>/dev/null
    then
      enable -f "$loadable_path/$1" "$1"
      return 0
    fi
  done

  return 1
}

## @fn ble/util/is-stdin-ready [fd] [exit]
##   Returns if there is already any user inputs pending in stdin.
##   @param[in,opt] fd
##     This specifies the file descriptor to check.  If omitted, it uses the
##     file descriptor saved in $_ble_util_fd_tui_stdin.
##   @param[in,opt] exit
##     This specifies the exit status when we cannot test it.  The default
##     value is 1.
##   @remarks When stdin (0) is connected to /dev/null, this function succeeds
##     unconditionally, even though a read from /dev/null will fail.
if ((_ble_bash>=40000)); then
  # #D1341 Countermeasure Locale is not applied to built-in commands in variable assignment format.
  function ble/util/is-stdin-ready {
    local IFS= LC_ALL= LC_CTYPE=C stdin=${1:-${_ble_util_fd_tui_stdin:-0}}

    if ((stdin==0)) || { ((stdin==_ble_util_fd_tui_stdin)) && [[ -t 0 && ! $_ble_edit_exec_inside_userspace ]]; }; then
      # Note: When the specified file descriptor is 0 or
      # _ble_util_fd_tui_stdin, we do not have to explicitly redirect the
      # standard input of "builtin read".  However, we need to care about the
      # case when fd 0 is redirected in the current context.  This is checked
      # by [[ -t $stdin ]] assuming that fd 0 is not a TTY when it is
      # temporarily redirected.  We also need to care about the case that the
      # current fd 0 is replaced for the command execution (because ble.sh
      # allows different sets of fds for the command execution).  This is
      # checked by [[ !  $_ble_edit_exec_inside_userspace ]].
      #
      # This is for the performance, and also for a workaround for the problem
      # with Cygwin and MSYS in Windows Terminal.  When we connect to Cygwin or
      # MSYS from Windows Terminal, for some reason, "builtin read -t 0
      # <redirection>" and "builtin read -t 0 -u fd" misbehave and causes
      # problems.  This is likely to be an issue with Windows Terminal or
      # Windows Pseudo Console API, but it seems difficult to identify the
      # exact problem.  Fortunately, in our codebase, most calls of
      # ble/util/is-stdin-ready does not seem to require the redirection, so we
      # can significantly reduce the chances of the problems in Windows
      # Terminal.
      builtin read -t 0
    else
      # Note: We use the explicit redirection "<&fd" instead of "-u fd" because
      # it turned out that "builtin read -t 0 -u fd" is slower than "builtin
      # read -t 0 <&fd".
      builtin read -t 0 <&"$stdin"
    fi
  }
  # suppress locale error #D1440
  ble/function#suppress-stderr ble/util/is-stdin-ready
else
  function ble/util/is-stdin-ready { return "${2:-1}"; }
fi

# Note: BASHPID is Bash-4.0 or higher

if ((_ble_bash>=40000)); then
  function ble/util/getpid { return 0; }
  function ble/util/is-running-in-subshell { [[ $$ != $BASHPID ]]; }
else
  ## @fn ble/util/getpid
  ##   @var[out] BASHPID
  function ble/util/getpid {
    local command='echo $PPID'
    ble/util/assign BASHPID 'ble/bin/sh -c "$command"'
  }
  function ble/util/is-running-in-subshell {
    # Note: Under bash-4.3, BASH_SUBSHELL cannot be increased by pipes or process replacement.
    #   It seems to have low reliability. However, as long as it is executed within a function, it may be okay.
    #   No.
    ((BASH_SUBSHELL==0)) || return 0
    local BASHPID; ble/util/getpid
    [[ $$ != $BASHPID ]]
  }
fi

## @fn ble/fd#is-open fd
##   Test if the specified file descriptor is open.
##
_ble_util_fd_is_open_stdout=
_ble_util_fd_is_open_stderr=
if ((_ble_bash>=40000)) && [[ -d /proc/$BASHPID/fd ]]; then
  # Bash 3 does not have BASHPID
  function ble/fd#is-open { [[ $1 && -e /proc/$BASHPID/fd/$1 ]]; }
  function ble/fd#is-open/.upgrade { builtin unset -f "$FUNCNAME"; }
else
  # This is the most primitive but incomplete implementation and will be
  # overwritten later when "ble/fd#alloc/.nextfd" is ready.  We need this
  # implementation to make "ble/fd#alloc/.nextfd" work.  This temporary
  # implementation ensures that the number is not used when it fails, but the
  # number may not be actually used when it succeeds.  This is because this
  # function may unexpectedly hit the undo-redirection fd for `2>/dev/null'.
  function ble/fd#is-open { builtin : 9>&"$1"; } 2>/dev/null

  function ble/fd#is-open/.upgrade {
    if ! { [[ $_ble_util_fd_null ]] && ((1)) >&"$_ble_util_fd_null"; } 2>/dev/null; then
      ble/util/print "$FUNCNAME: [FATAL] call this function after \$_ble_util_fd_null is ready" >&2
      return 1
    fi

    local fd1 fd2
    ble/fd#alloc/.nextfd fd1
    ble/fd#alloc/.nextfd fd2
    _ble_util_fd_is_open_stdout=$fd1
    _ble_util_fd_is_open_stderr=$fd2

    # This is the final version.  This implementation uses "exec" to move file
    # descriptors without creating any "undo-redirection" fds.  To reserve the
    # numbers of the file descriptors, we duplicate the file descriptor with
    # O_CLOEXEC connected to /dev/null stored in $_ble_util_fd_null.  After
    # defining this function, "ble/fd#is-open" needs to be called at least once
    # to replace the file descriptors with the ones with O_CLOEXEC.
    builtin eval -- "
      ble/fd#alloc/.exec $fd1 '>/dev/null'             # disable=#D1835
      ble/fd#alloc/.exec $fd2 '>&$fd1'                 # disable=#D1835
      function ble/fd#is-open {
        ble/string#match \"\$1\" '^[0-9]+$' || return 1
        [[ \$1 == $fd1 || \$1 == $fd2 || \$1 == $_ble_util_fd_null ]] && return 0
        ble/fd#alloc/.exec $fd2 '>&2'                  # disable=#D1835
        exec 2>&$_ble_util_fd_null                     # disable=#D1835
        ble/fd#alloc/.exec $fd1 \">&\$1\"              # disable=#D1835
        local ext=\$?
        exec 2>&$fd2                                   # disable=#D1835
        ble/fd#alloc/.exec $fd1 '>&$_ble_util_fd_null' # disable=#D1835
        ble/fd#alloc/.exec $fd2 '>&$fd1'               # disable=#D1835
        return \"\$ext\"
      }
    "
    builtin unset -f "$FUNCNAME"
  }
fi

function ble/fd#alloc/.close { builtin eval "exec $1<&-"; } # disable=#D2164
if ((30100<=_ble_bash&&_ble_bash<30200)); then
  function ble/fd#alloc/.close/.upgrade {
    if ! { [[ $_ble_util_fd_null ]] && ((1)) >&"$_ble_util_fd_null"; } 2>/dev/null; then
      ble/util/print "$FUNCNAME: [FATAL] call this function after \$_ble_util_fd_null is ready" >&2
      return 1
    fi

    # Bash 3.1 has a bug that the file descriptor (>= 10) cannot be closed by
    # 33>&-.  We here utilize another bug in Bash 3.1, where 77>&33- fails
    # halfway when 77 is in use and results in just closing 33.  We use the
    # file descriptor for /dev/null in place of 77.
    builtin eval -- "
      function ble/fd#alloc/.close {
        ((\$1==$_ble_util_fd_null||\$1==2)) && return 1
        exec $_ble_util_fd_null<&\"\$1\"-
      } 2>/dev/null"
    builtin unset -f "$FUNCNAME"
  }
else
  function ble/fd#alloc/.close/.upgrade { builtin unset -f "$FUNCNAME"; }
fi

## @env[in] _ble_util_fdlist_cloexec
##   A colon-separated list of the file descriptors that should be closed on
##   the initialization of ble.sh.  Each element has the form of
##   /[0-9]+(=[to])?/. These are supposed to be leftovers from the parent
##   ble.sh sessions that should have been closed by CLOEXEC.  When
##   ble/fd#add-cloexec failed, the file descriptor is added to this
##   environment variable.
## @env[in] _ble_util_fdvars_export
##   A colon-separated list of the environment variable names that contain file
##   descriptors that are shared by the parent ble.sh session if possible.

function ble/fd/.validate-shared-fds {
  local -a close_fd=()
  # We first check if the exported fds are still valid.  If an exported fd is
  # invalidated by e.g. closing the other end point, the fd becomes invalid and
  # another stream can be later assigned to the same number.  Using the
  # re-assigned number as if it was the inherited fd causes problems.  Before
  # performing any redirections, we here explicitly close the invalidated fds
  # and unset the environment variables.
  if [[ ${_ble_util_fdvars_export-} ]]; then
    local ret var fd
    ble/string#split ret : "$_ble_util_fdvars_export"
    for var in "${ret[@]}"; do
      ble/string#match "$var" '^[a-zA-Z_][a-zA-Z_0-9]*$' || continue
      fd=${!var}
      ble/string#match "$fd" '^[0-9]+$' || continue
      if ! ble/fd#is-open "$fd"; then
        ble/array#push close_fd "$fd"
        builtin unset -v "$var"
      fi
    done

    # We also check variables exported from older versions by the variable name
    # pattern.  In case some variables contain unrelated numbers, we require
    # the number to have at least two digits.
    for var in "${!_ble_util_fd_@}"; do
      fd=${!var}
      ble/string#match "$fd" '^[0-9]{2,}$' || continue
      if ! ble/fd#is-open "$fd"; then
        ble/array#push close_fd "$fd"
        builtin unset -v "$var"
      fi
    done
    _ble_util_fdvars_export=
  fi

  if [[ ${_ble_util_fdlist_cloexec-} ]]; then
    local ret fd
    ble/string#split ret : "$_ble_util_fdlist_cloexec"
    for fd in "${ret[@]}"; do
      ble/string#match "$fd" '^([0-9]+)(=(.*))?' || continue
      local fd=${BASH_REMATCH[1]} type=${BASH_REMATCH[3]-}

      # When the type of the file descriptor does not match the recorded one,
      # we keep the file descriptor because the file descriptor is probably
      # replaced with another one by other programs.
      case $type in
      (L*)
        [[ -h /proc/$$/fd/$1 ]] &&
          ble/util/readlink "/proc/$$/fd/$1" &&
          [[ ${ret//:} == "${type#L}" ]] || continue ;;
      (t) [[ -t $fd ]] || continue ;;
      (o) [[ ! -t $fd ]] || continue ;;
      esac

      ble/array#push close_fd "$fd"
    done
    _ble_util_fdlist_cloexec=
  fi

  if ((${#close_fd[@]})); then
    "${_ble_util_set_declare[@]//NAME/mark}" # disable=#D1570
    local fd
    for fd in "${close_fd[@]}"; do
      ble/set#contains mark "$fd" && continue
      ble/set#add mark "$fd"

      # Note: XXX--At this point, the implementation of ble/fd#alloc/.close
      # does not work for Bash 3.1.  We give up closing file descriptors in
      # Bash 3.1.
      ble/fd#alloc/.close "$fd"
    done
  fi
}
ble/fd/.validate-shared-fds
_ble_util_fdlist_cloexit=
export _ble_util_fdlist_cloexec=
export _ble_util_fdvars_export=

_ble_util_openat_nextfd=
## @fn ble/fd#alloc/.nextfd var [fdbase [opts]]
##   @param[out] var
##   @opt no-increment
##     Do not update _ble_util_openat_nextfd.
function ble/fd#alloc/.nextfd {
  [[ $_ble_util_openat_nextfd ]] ||
    _ble_util_openat_nextfd=${bleopt_openat_base:-30}
  # Note: In Bash 3.1, explicitly closing with exec fd>&- does not work.
  #   The read process fails to read after opening.
  #   So I need to find an fd that is not open. #D0992
  # Note: Checks whether the specified fd is open or not.
  #   I found a portable and fast way to determine
  #   Always search for fds that are not open. #D1318
  # Note: If the fd is exhausted, the search becomes an infinite loop, so set the upper limit of the fd search range to 1024.
  #   limit. If not found, overwrite the initial value fd.
  local _ble_local_init=${2:-$_ble_util_openat_nextfd}
  local _ble_local_limit=$((_ble_local_init+1024))
  local _ble_local_nextfd=$_ble_local_init
  while ((_ble_local_nextfd<_ble_local_limit)) &&
          ble/fd#is-open "$_ble_local_nextfd"; do
    ((_ble_local_nextfd++))
  done
  if ((_ble_local_nextfd>=_ble_local_limit)); then
    _ble_local_nextfd=$_ble_local_init
    ble/fd#alloc/.close "$_ble_local_nextfd"
  fi
  (($1=_ble_local_nextfd++))
  [[ ${2-} || :${3-}: == *:no-increment:* ]] ||
    _ble_util_openat_nextfd=$_ble_local_nextfd
}

## @var _ble_util_fd_null
##   We open a stream connected to /dev/null for read/write and store the
##   number in this variable.
##
##   @remark We originally initialized this variable using "ble/fd#alloc" after
##   we define "ble/fd#alloc".  However, because of bash-3.1 bug (#D2164), we
##   need the file descriptor associated with /dev/null for ble/fd#add-cloexec,
##   and ble/fd#add-cloexec is needed by ble/fd#alloc.  We give up initializing
##   _ble_util_fd_null using "ble/fd#alloc" and manually initialize it here.
##   Some part needs to be performed later after ble/fd#add-cloexec is defined.
if [[ :$bleopt_connect_tty: == *:inherit:* ]]; then
  # Initialize the variable as if "ble/fd#alloc _ble_util_fd_null base:inherit"
  if [[ ! ${_ble_util_fd_null-} ]] || ! ble/fd#is-open "$_ble_util_fd_null"; then
    builtin eval "exec $_ble_util_fd_null<>/dev/null"
    ble/opts#append-unique _ble_util_fdvars_export _ble_util_fd_null
    export _ble_util_fd_null
    ble/fd#alloc/.nextfd _ble_util_fd_null
  fi
else
  # Initialize the variable as if "ble/fd#alloc _ble_util_fd_null base".
  # ble/fd#add-cloexec needs to be performed later.
  ble/fd#alloc/.nextfd _ble_util_fd_null
  builtin eval "exec $_ble_util_fd_null<>/dev/null"
  ble/opts#append-unique _ble_util_fdlist_cloexit "$_ble_util_fd_null"
  # later: ble/fd#add-cloexec "$_ble_util_fd_null"
fi

# We now switch to the complete implementation of "ble/fd#alloc/.close" relying
# on $_ble_util_fd_null.
ble/fd#alloc/.close/.upgrade

## @fn ble/fd#alloc/.exec fddst redir
##   Performs builtin eval "exec $fddst$redir" with special cares for bugs in
##   old versions of Bash.
##   @param fddst
##     The file descriptor that is supposed to be modified
##   @param redir
##     Redirection operator plus arguments
function ble/fd#alloc/.exec {
  # Note (#D0857): Bash 3.2/3.1 has a bug for the file descriptors (>= 10).
  #   When a file descriptor is already used, the redirections of the form
  #   33>... (disable=#D0857) silently fails.  To work around this bug, we
  #   first close the file descriptor by ble/fd#alloc/.close.
  # Note (#D2164): We also need to close the destination file descriptor FD
  #   before performing "exec FD>...".  When FD is open and has the CLOEXEC
  #   attribute, the redirection is performed but immediately undone by Bash.
  #   https://lists.gnu.org/archive/html/bug-bash/2024-02/msg00188.html
  ble/fd#alloc/.close "$1"
  builtin eval "exec $1$2"
}

# We now switch to the complete implementation of "ble/fd#is-open" utilizing
# "ble/fd#alloc/.nextfd", "ble/fd#alloc/.exec", and "$_ble_util_fd_null".
ble/fd#is-open/.upgrade

## @fn ble/fd#list
if [[ -d /proc/$$/fd ]]; then
  ## @fn ble/fd#list/.impl [pid]
  ##   List the file descriptors opened for the specified process.  If PID is
  ##   not specified, this returns the list for the current process.
  ##   @arr[out] ret
  if ((_ble_bash>=50300)); then
    function ble/fd#list/.impl {
      local pid=$1
      builtin compgen -V ret -G "/proc/$pid/fd/[0-9]*"
      ret=("${ret[@]##*/}") # disable=#D2352 (bash >= 5.3 are unaffected)
    }
  else
    # Note: In Bash < 5.3.0, we cannot rely on "compgen -G" because we need to
    # redirect the output of "compgen -G" to capture the result, and this
    # changes the list of the file descriptors.  We need to manually list the
    # file descriptors using the pathname expansion.

    ## @fn ble/fd#list/.adjust-glob
    ##   @var[out] set shopt gignore
    function ble/fd#list/.adjust-glob {
      set=$- shopt= gignore=$GLOBIGNORE
      ble/base/list-shopt failglob dotglob
      shopt -u failglob
      set +f
      GLOBIGNORE=
    }
    ## @fn ble/fd#list/.restore-glob
    ##   @var[in] set shopt gignore
    function ble/fd#list/.restore-glob {
      # Note: dotglob is changed by GLOBIGNORE
      GLOBIGNORE=$gignore
      if [[ :$shopt: == *:dotglob:* ]]; then shopt -s dotglob; else shopt -u dotglob; fi
      [[ $set == *f* ]] && set -f
      [[ :$shopt: == *:failglob:* ]] && shopt -s failglob
    }

    function ble/fd#list/.impl {
      ret=()
      local pid=$1

      local set shopt gignore
      ble/fd#list/.adjust-glob

      local fd
      for fd in /proc/"$pid"/fd/[0-9]*; do
        fd=${fd##*/}
        [[ $fd && ! ${fd//[0-9]} ]] &&
          ble/array#push ret "$fd"
      done

      ble/fd#list/.restore-glob
    }
  fi

  if ((_ble_bash>=40000)); then
    function ble/fd#list { ble/fd#list/.impl "$BASHPID"; }
  else
    function ble/fd#list {
      local BASHPID
      ble/util/getpid
      ble/fd#list/.impl "$BASHPID"
    }
  fi
else
  ## @fn ble/fd#list
  ##   List the file descriptors opened for the current process.
  ##   @arr[out] ret
  function ble/fd#list {
    ret=()
    local fd
    for fd in {0..255}; do
      ble/fd#is-open "$fd" && ble/array#push ret "$fd"
    done
  }
fi

if ((_ble_bash>=40400)) && ble/util/load-standard-builtin fdflags 'builtin fdflags 0; (($?<=2))'; then
  # Implementation of ble/fd#cloexec by loadable builtin (8us)

  function ble/fd#cloexec/.add { builtin fdflags -s +cloexec "$1"; }
  function ble/fd#cloexec/.remove { builtin fdflags -s -cloexec "$1"; }
elif ((_ble_bash>=40000)); then
  # Implementation of ble/fd#cloexec by undo fd.
  #
  # In bash >= 4.0, the "undo fd" (i.e., the file descriptor that holds the
  # original stream of the redirected file descriptor) gets O_CLOEXEC.  If we
  # can identify the "undo fd", we can duplicate it to another file descriptor
  # to get O_CLOEXEC version of the original stream.  This can only be used in
  # bash >= 4.0, because older versions of bash does not give O_CLOEXEC to the
  # undo fds.
  if [[ -d /proc/$$/fd ]]; then
    # Implementation of ble/fd#cloexec by procfs (1588us)
    function ble/fd#cloexec/.listfd {
      local ret fd
      ble/fd#list/.impl "$$"
      for fd in "${ret[@]}"; do
        ble/util/set "$1[fd]" 1
      done
    }

    ## @fn ble/fd#cloexec/.probe
    ##   @var[out] ret
    function ble/fd#cloexec/.probe {
      local fdset2
      ble/fd#cloexec/.listfd fdset2

      local fd
      for fd in "${!fdset1[@]}"; do builtin unset -v 'fdset2[fd]'; done
      fd=("${!fdset2[@]}")

      ((${#fd[@]}==1)) &&
        ble/fd#alloc/.nextfd ret '' no-increment &&
        builtin eval -- "exec $ret<&$fd" &&
        return 0

      ret=
      return 1
    }

    ## @fn ble/fd#cloexec/.dup-undo-redirection-fd
    ##   @var[out] ret
    function ble/fd#cloexec/.dup-undo-redirection-fd {
      local fd=$1 fdset1
      ble/fd#cloexec/.listfd fdset1
      builtin eval -- "ble/fd#cloexec/.probe $fd</dev/null"
    }
  else
    # Implementation of ble/fd#cloexec by manual fd scan (1996us)

    ## @fn ble/fd#cloexec/.probe
    ##   @var[out] ret
    function ble/fd#cloexec/.probe {
      local fd
      local -a mark=()
      for fd in "${candidates[@]}"; do
        [[ $fd && ! ${fd//[0-9]} && ! ${mark[fd]-} ]] || continue
        mark[fd]=1

        ble/fd#is-open "$fd" &&
          ble/fd#alloc/.nextfd ret '' no-increment &&
          builtin eval -- "exec $ret<&$fd" &&
          return 0
      done
      ret=
      return 1
    }

    function ble/fd#cloexec/.dup-undo-redirection-fd {
      local fd=$1

      local -a candidates=()
      local fdtmp
      ble/fd#alloc/.nextfd fdtmp 10 &&
        ble/array#push candidates "$fdtmp"
      ble/fd#alloc/.nextfd fdtmp "$((fd<10?10:fd+1))" &&
        ble/array#push candidates "$fdtmp"
      ble/fd#alloc/.nextfd fdtmp '' no-increment &&
        ble/array#push candidates "$fdtmp"

      builtin eval -- "ble/fd#cloexec/.probe $fd</dev/null"
    }
  fi

  function ble/fd#cloexec/.add {
    local fd=$1 ret
    ble/fd#cloexec/.dup-undo-redirection-fd "$fd" &&
      builtin eval -- "exec $fd>&- $fd>&$ret $ret>&-" # disable=#D2164 (here bash4+)
  } 2>/dev/null
  function ble/fd#cloexec/.remove {
    local fd=$1
    if ((fd!=0)); then
      builtin eval -- "exec 0<&$fd $fd<&- $fd<&0" </dev/null # disable=#D2164 (here bash4+)
    else
      builtin eval -- "exec 1>&$fd $fd>&- $fd>&1" >/dev/null # disable=#D2164 (here bash4+)
    fi
  }
else
  function ble/fd#cloexec/.add { return 1; }
  function ble/fd#cloexec/.remove { return 1; }
fi

function ble/fd#add-cloexec {
  ble/fd#cloexec/.add "$1" && return 0

  local type
  if [[ -h /proc/$$/fd/$1 ]] && ble/util/readlink "/proc/$$/fd/$1"; then
    type=L${ret//:}
  elif [[ -t ${!1} ]]; then
    type=t
  else
    type=o
  fi

  ble/opts#remove _ble_util_fdlist_cloexec "$1"
  ble/opts#append _ble_util_fdlist_cloexec "$1=$type"
}
function ble/fd#remove-cloexec {
  ble/fd#cloexec/.remove "$1" || return "$?"
  ble/opts#remove _ble_util_fdlist_cloexec "$1"
  return 0
}

## @fn ble/fd#alloc fdvar redirect [opts]
##   Executes the operation corresponding to "exec {fdvar}>foo".
##   @param[out] fdvar
##     Assigns the used file descriptor to the specified variable.
##   @param[in] redirect
##     Specify a redirect.
##   @param[in,opt] opts
##     A colon-separated list of the options.  These control how the new file
##     descriptor should be allocated:
##
##     @opt inherit
##       If the variable already contains a valid fd, we skip the allocation of
##       the new fd.  "export" is implied.
##     @opt inherit-tty
##       If the variable already contains a valid fd connected to TTY, we skip
##       the allocation of the new fd.  "export" is implied.
##     @opt share
##       When the redirection has the form ">&NUMBER", we assign the number to
##       the variable instead of actually duplicating the fd.  This can be
##       safely used only when the stream associated with the number will never
##       be changed.
##     @opt overwrite
##       If the variable already contains a number, we perform the redirection
##       on the number.
##     @opt base
##       When a new number needs to be assigned, we determine the number based
##       on "bleopt openat_base" instead of using Bash's {fd}<> redirections.
##
##     These control how the file descriptors are closed on the session end or
##     exported to the child sessions:
##
##     @opt export
##       The specified variable is exported to the child processes.  This
##       suppresses "cloexec". Also, "preserve" is implied.
##     @opt preserve
##       By default, ble.sh closes all the file descriptors allocated by
##       ble/fd#alloc on the session end.  It also closes all the file
##       descriptors allocated by the parent or previous ble.sh session.  This
##       option suppresses the auto closing of the file descriptor allocated by
##       this call.
function ble/fd#alloc {
  local _ble_local_opts=$3
  if [[ :$_ble_local_opts: == *:inherit:* ]]; then
    [[ ${!1-} ]] && ble/fd#is-open "${!1}" && return 0
    _ble_local_opts=$_ble_local_opts:export
  elif [[ :$_ble_local_opts: == *:inherit-tty:* ]]; then
    [[ ${!1-} && -t ${!1-} ]] && return 0
    _ble_local_opts=$_ble_local_opts:export
  fi

  if [[ :$_ble_local_opts: == *:share:* ]]; then
    if ble/string#match "$2" '[<>]&['"$_ble_term_IFS"']*([0-9]+)['"$_ble_term_IFS"']*$'; then
      builtin eval -- "$1=${BASH_REMATCH[1]}"
      return 0
    fi
  fi

  if [[ ${!1-} && :$_ble_local_opts: == *:overwrite:* ]]; then
    # When we overwrite or replace an existing fd stored in the variable, we do
    # not register it for the auto-closing on unload.  This is because an
    # existing code may want to use the fd, or we might have already register
    # it for the auto-closing.
    _ble_local_opts=$_ble_local_opts:preserve

    ble/fd#alloc/.exec "${!1}" "$2"
  elif ((_ble_bash>=40100)) && [[ :$_ble_local_opts: != *:base:* ]]; then
    builtin eval "exec {$1}$2"
  else
    ble/fd#alloc/.nextfd "$1"
    ble/fd#alloc/.exec "${!1}" "$2"
  fi; local _ble_local_ext=$?

  if ((_ble_local_ext==0)); then
    if [[ :$_ble_local_opts: == *:export:* ]]; then
      export "$1"
      ble/opts#append-unique _ble_util_fdvars_export "$1"
    elif [[ :$_ble_local_opts: != *:preserve:* ]]; then
      ble/opts#append-unique _ble_util_fdlist_cloexit "${!1}"
      ble/fd#add-cloexec "${!1}"
    fi
  fi
  return "$_ble_local_ext"
}
function ble/fd#finalize {
  local fds fd
  ble/string#split fds : "$_ble_util_fdlist_cloexit"
  for fd in "${fds[@]}"; do
    [[ $fd ]] || continue
    ble/fd#alloc/.close "$fd"
  done
  _ble_util_fdlist_cloexit=
  _ble_util_fdlist_cloexec=
}
function ble/fd#is-cloexit {
  [[ :$_ble_util_fdlist_cloexit: == *:"$fd":* ]]
}
## @fn ble/fd#close fd
##   Closes the specified fd.
function ble/fd#close {
  set -- "$(($1))"
  (($1>=3)) || return 1
  ble/fd#alloc/.close "$1"
  ble/opts#remove _ble_util_fdlist_cloexit "$1"
  ble/opts#remove _ble_util_fdlist_cloexec "$1"
  return 0
}

bleopt/declare -v connect_tty 1
export bleopt_connect_tty

## @var _ble_util_fd_null
##   The final part of the initialization of _ble_util_fd_null is performed
##   here.
ble/fd#add-cloexec "$_ble_util_fd_null"

## @var _ble_util_fd_zero
##   @remark MSYS1 somehow does not support duping a file descriptor to
##   /dev/zero
_ble_util_fd_zero=
if [[ -c /dev/zero ]] && ! ble/base/is-msys1; then
  if [[ :$bleopt_connect_tty: == *:inherit:* ]]; then
    ble/fd#alloc _ble_util_fd_zero '< /dev/zero' base:inherit
  else
    ble/fd#alloc _ble_util_fd_zero '< /dev/zero' base
  fi
fi

## @var[export,opt] _ble_util_fd_tty_stdin
## @var[export,opt] _ble_util_fd_tty_stdout
## @var[export,opt] _ble_util_fd_tty_stderr
## @var[export]     _ble_util_fd_cmd_stdin
## @var[export]     _ble_util_fd_cmd_stdout
## @var[export]     _ble_util_fd_cmd_stderr
## @var             _ble_util_fd_tui_stdin
## @var             _ble_util_fd_tui_stdout
## @var             _ble_util_fd_tui_stderr
##   We keep three different sets of standard streams. "tty" is to inherit and
##   maintain the standard streams connected to TTY to child processes. "tui"
##   is used for the interactive interface of ble.sh, and "cmd" is used for the
##   user commands.
function ble/fd/.initialize-standard-stream {
  local var_tty=_ble_util_fd_tty_$1
  local var_cmd=_ble_util_fd_cmd_$1
  local var_tui=_ble_util_fd_tui_$1
  local fd=${2::1} redir=${2:1}

  # For "cmd" (the stream used by the user commands), we always use the initial
  # standard stream on the startup.  We duplicate the fd to assign a new number
  # for "cmd".  This is because "cmd" can be later independently redirected by
  # the user commands using "exec".
  ble/fd#alloc "$var_cmd" "$redir&$fd" base

  if [[ -t $fd ]]; then
    # When the specified fd is a TTY, we keep it in another fd and use it for
    # everything.  We *reuse* the number recorded in "tty" if any, or
    # otherwise, we assign a new number to "tty".  We duplicate the original fd
    # to the number in "tty" and copy the number to "tui".
    local alloc_opts=base
    [[ $bleopt_connect_tty == inherit ]] && alloc_opts=$alloc_opts:overwrite:export
    ble/fd#alloc "$var_tty" "$redir&$fd" "$alloc_opts"
    ble/util/set "$var_tui" "${!var_tty}"
    return 0
  fi

  if [[ ! $_ble_init_command && $bleopt_connect_tty ]]; then
    local alloc_opts=base
    [[ $bleopt_connect_tty == inherit ]] && alloc_opts=$alloc_opts:inherit-tty
    if ble/fd#alloc "$var_tty" "$redir /dev/tty" "$alloc_opts"; then
      # When connect_tty is enabled and we succeed to get the fd to TTY, we
      # save the number in "tty" and "tui" and redirect the target fd to the
      # duplicated one.
      ble/util/set "$var_tui" "${!var_tty}"
      builtin eval -- "exec $fd$redir&${!var_tui}"
      return 0
    else
      # When the existing "tty" fd is invalid or we failed to connect to the
      # TTY, we remove it.
      builtin unset -v "$var_tty"
    fi
  fi

  # When connect_tty is unavailable, we use the common streams as the user
  # commands for ble.sh's interface.  This means that when a user command
  # redirects any standard streams by "exec", ble.sh's interface is also
  # affected.  We keep the existing value of "tty", which may be initialized by
  # the parent session.
  ble/util/set "$var_tui" "${!var_cmd}"
}
ble/fd/.initialize-standard-stream stdin  '0<'
ble/fd/.initialize-standard-stream stdout '1>'
ble/fd/.initialize-standard-stream stderr '2>'

## @fn ble/fd/save-external-standard-streams [fd_in fd_out fd_err]
##   @var[in,opt] fd_in fd_out fd_err
##     Specify the source file descriptors that are saved as standard streams
##     for the external state.
function ble/fd/save-external-standard-streams {
  ble/fd#alloc _ble_util_fd_cmd_stdin  "<&${1:-0}" base:overwrite
  ble/fd#alloc _ble_util_fd_cmd_stdout ">&${2:-1}" base:overwrite
  ble/fd#alloc _ble_util_fd_cmd_stderr ">&${3:-2}" base:overwrite
  ble/fd#add-cloexec "$_ble_util_fd_cmd_stdin"
  ble/fd#add-cloexec "$_ble_util_fd_cmd_stdout"
  ble/fd#add-cloexec "$_ble_util_fd_cmd_stderr"
}

function ble/fd#close-all-tty {
  local ret
  ble/fd#list

  # Note: I thought about closing 0 1 2 and _ble_util_fd_std{in,out,err}, but somehow
  # It seems that there are many things that are saved by redirect, so check them all.
  # I made it.
  local fd
  for fd in "${ret[@]}"; do
    if ble/string#match "$fd" '^[0-9]+$' && [[ -t $fd ]]; then
      ble/fd#alloc/.exec "$fd" ">&$_ble_util_fd_null"
      ble/opts#remove _ble_util_fdlist_cloexit "$fd"
    fi
  done
}
## @fn ble/util/nohup command [opts]
##   @param[in] command
##   @param[in,opt] opts
##     @opt print-bgpid
function ble/util/nohup {
  if ((!BASH_SUBSHELL)); then
    (ble/util/nohup "$@")
    return "$?"
  fi

  ble/fd#close-all-tty
  shopt -u huponexit
  builtin eval -- "$1" &>/dev/null </dev/null & { local pid=$!; disown; }
  if [[ :$2: == *:print-bgpid:* ]]; then
    ble/util/print "$pid"
  fi
}

function ble/util/print-quoted-command {
  local ret; ble/string#quote-command "$@"
  ble/util/print "$ret"
}
function ble/util/declare-print-definitions {
  (($#==0)) && return 0

  # Note (#D2055): Due to mawk 1.3.3-20090705 bug, [:blank:] cannot be used inside regular expressions.
  # cannot be used. mawk on Ubuntu 16.04 LTS and Ubuntu 18.04 LTS
  # 1.3.3-20090705 is used. So, in a variable called _ble_term_blank
  # Use by inserting <SP><TAB>.

  # Note (#D2404): the current version of msys-2.0 reports OSTYPE=cygwin.
  local ostype=$OSTYPE
  ble/base/is-msys && ostype=msys

  declare -p "$@" | ble/bin/awk -v _ble_bash="$_ble_bash" -v OSTYPE="$ostype" '
    BEGIN {
      decl = "";

#% # Solution #D1270: Disappears when ^M is substituted in MSYS2
      flag_escape_cr = OSTYPE == "msys";
    }

    function fix_value(value) {
#% # bash-3.0's declare -p gives incorrect output about newlines.
      if (_ble_bash < 30100) gsub(/\\\n/, "\n", value);

#% # #D1238 Before bash-4.3, declare -p changed ^A, ^?
#% # ^A^A, ^A^? is output, so correct it.
#% # #D1325 Furthermore, in Bash-3.0, "x${_ble_term_DEL}y"
#% # The contents of _ble_term_DEL will be deleted.
#% # Must be "x""${_ble_term_DEL}""y".
      if (_ble_bash < 30100) {
        gsub(/\001\001/, "\"\"${_ble_term_SOH}\"\"", value);
        gsub(/\001\177/, "\"\"${_ble_term_DEL}\"\"", value);
      } else if (_ble_bash < 40400) {
        gsub(/\001\001/, "${_ble_term_SOH}", value);
        gsub(/\001\177/, "${_ble_term_DEL}", value);
      }

      if (flag_escape_cr)
        gsub(/\015/, "${_ble_term_CR}", value);
      return value;
    }

#% # #D1522 #D1614 If the array element contains ^A or ^? under Bash-3.2
#% # With the arr=(...) format, ^A, ^? are doubled during evaluation, so
#% # Assignment must be made for each element.
    function print_array_elements(decl, _, name, out, key, value) {
      if (match(decl, /^[_a-zA-Z][_a-zA-Z0-9]*=\(/) == 0) return 0;
      name = substr(decl, 1, RLENGTH - 2);
      decl = substr(decl, RLENGTH + 1, length(decl) - RLENGTH - 1);
      sub(/^['"$_ble_term_blank"']+/, decl);

      out = name "=()\n";

      while (match(decl, /^\[[0-9]+\]=/)) {
        key = substr(decl, 2, RLENGTH - 3);
        decl = substr(decl, RLENGTH + 1);

        value = "";
        if (match(decl, /^('\''[^'\'']*'\''|\$'\''([^\\'\'']|\\.)*'\''|\$?"([^\\"]|\\.)*"|\\.|[^'"$_ble_term_blank"'"'\''`;&|()])*/)) {
          value = substr(decl, 1, RLENGTH)
          decl = substr(decl, RLENGTH + 1)
        }

        out = out name "[" key "]=" fix_value(value) "\n";
        sub(/^['"$_ble_term_blank"']+/, decl);
      }

      if (decl != "") return 0;

      print out;
      return 1;
    }

    function declflush(_, isArray) {
      if (!decl) return 0;
      isArray = (decl ~ /^declare +-[ilucnrtxfFgGI]*[aA]/);

#% # declare remove
      sub(/^declare +(-[-aAilucnrtxfFgGI]+ +)?(-- +)?/, "", decl);
      if (isArray) {
        if (decl ~ /^([_a-zA-Z][_a-zA-Z0-9]*)='\''\(.*\)'\''$/) {
          # Note: nawk in Solaris 2.11 does not allow regex to start with /=.
          sub(/(=)'\''\(/, "=(", decl);
          sub(/\)'\''$/, ")", decl);
          gsub(/'\'\\\\\'\''/, "'\''", decl);
        }

        if (_ble_bash < 40000 && decl ~ /[\001\177]/)
          if (print_array_elements(decl))
            return 1;
      }

      print fix_value(decl);
      decl = "";
      return 1;
    }
    /^declare / {
      declflush();
      decl = $0;
      next;
    }
    { decl = decl "\n" $0; }
    END { declflush(); }
  '
}

## @fn ble/util/print-global-definitions/.print-decl name opts
##   Prints the declaration of the specified variable.
##   @param[in] name
##     Specify the variable name to be processed.
##   @param[in] opts
##     unset is specified when a variable with the specified name is not found.
##   @stdout
##     Outputs variable declarations. If a variable with the specified name is not found, the state is unset.
##     Outputs the command to do.
function ble/util/print-global-definitions/.print-decl {
  local __ble_name=$1 __ble_decl=
  if [[ ! ${!__ble_name+set} || :$2: == *:unset:* ]]; then
    __ble_decl="declare $__ble_name; builtin unset -v $__ble_name"
  elif ble/variable#has-attr "$__ble_name" aA; then
    if ((_ble_bash>=40000)); then
      ble/util/assign __ble_decl "declare -p $__ble_name" 2>/dev/null
      __ble_decl=${__ble_decl#declare -* }
    else
      ble/util/assign __ble_decl "ble/util/declare-print-definitions $__ble_name" 2>/dev/null
    fi
    if ble/is-array "$__ble_name"; then
      __ble_decl="declare -a $__ble_decl"
    else
      __ble_decl="declare -A $__ble_decl"
    fi
  else
    __ble_decl=${!__ble_name}
    __ble_decl="declare $__ble_name='${__ble_decl//$__ble_q/$__ble_Q}'"
  fi
  ble/util/print "$__ble_decl"
}

## @fn ble/util/print-global-definitions varnames...
##   @var[in] varnames
##
##   Outputs the definition of the specified variable as a global variable.
##
##   Restriction: If there is a readonly local variable with the same name,
##   Returns unset because the value of the global variable cannot be obtained.
## In the first place, there are many problems with readonly variables, so they are not used in ble.sh.
##
##   Limitation: The variable names __ble_* are used to implement this function, so
##   Not compatible.
##
##   Note: bash-4.2 has a bug where when a global variable does not exist
##   declare -g -r var creates a new local read-only var variable.
##   This is not a problem with the current implementation.
##
function ble/util/print-global-definitions {
  local __ble_opts=
  [[ $1 == --hidden-only ]] && { __ble_opts=hidden-only; shift; }
  ble/util/for-global-variables ble/util/print-global-definitions/.print-decl "$__ble_opts" "$@"
}

## @fn ble/util/for-global-variables proc opts varnames...
##   @fn proc name opts
##     @param[in] name
##       Specify the variable name to be processed.
##     @param[in] opts
##       unset is specified when a variable with the specified name is not found.
##   @param[in] opts
##     When hidden-only is included, the corresponding global variable is another local variable.
##     Call proc only when covered.
##   @param[in] varnames...
##     Specifies a set of variable names to be processed.
function ble/util/for-global-variables {
  local __ble_proc=$1 __ble_opts=$2; shift 2
  local __ble_hidden_only=
  [[ :$__ble_opts: == *:hidden-only:* ]] && __ble_hidden_only=1
  (
    ble/util/joblist/__suppress__
    ((_ble_bash>=50000)) && shopt -u localvar_unset
    __ble_error=
    __ble_q="'" __ble_Q="'\''"
    # Completion will probably prevent function calls from overlapping 20 layers.
    __ble_MaxLoop=20
    builtin unset -v "${!_ble_processed_@}"

    for __ble_name; do
      [[ ${__ble_name//[_a-zA-Z0-9]} || $__ble_name == __ble_* ]] && continue
      ((__ble_processed_$__ble_name)) && continue
      ((__ble_processed_$__ble_name=1))

      __ble_found=
      if ((_ble_bash>=40200)); then
        declare -g -r "$__ble_name"
        for ((__ble_i=0;__ble_i<__ble_MaxLoop;__ble_i++)); do
          if ! builtin unset -v "$__ble_name"; then
            # Note: Even if the variable is declared readonly at the top level,
            # we can test if the visible variable is global or not by using
            # `(readonly var; ! local var)' because `local var' succeeds if the
            # visible variable is local readonly.
            if builtin readonly "$__ble_name"; ble/variable#is-global/.test "$__ble_name"; then
              __ble_found=1
              [[ $__ble_hidden_only && $__ble_i == 0 ]] ||
                "$__ble_proc" "$__ble_name"
            fi
            break
          fi
        done
      else
        for ((__ble_i=0;__ble_i<__ble_MaxLoop;__ble_i++)); do
          if ble/variable#is-global "$__ble_name"; then
            __ble_found=1
            [[ $__ble_hidden_only && $__ble_i == 0 ]] ||
              "$__ble_proc" "$__ble_name"
            break
          fi
          builtin unset -v "$__ble_name" || break
        done
      fi

      if [[ ! $__ble_found ]]; then
        __ble_error=1
        [[ $__ble_hidden_only && $__ble_i == 0 ]] ||
          "$__ble_proc" "$__ble_name" unset
      fi
    done

    [[ ! $__ble_error ]]
  ) 2>/dev/null
}

## @fn ble/util/has-glob-pattern pattern
##   Determines whether the specified pattern contains a glob pattern.
##
## Note: In Bash 5.0, if a variable contains \, echo $var returns
##   It is interpreted as pathname expansion, and failglob, nullglob, etc. are valid, but
##   If it is explicitly written like echo \[a\], it will not be interpreted as pathname expansion.
##   This judgment is based on whether it is recognized as a glob pattern when written explicitly.
function ble/util/has-glob-pattern {
  [[ $1 ]] || return 1

  local restore=:
  if ! shopt -q nullglob 2>/dev/null; then
    restore="$restore;shopt -u nullglob"
    shopt -s nullglob
  fi
  if shopt -q failglob 2>/dev/null; then
    restore="$restore;shopt -s failglob"
    shopt -u failglob
  fi

  local dummy=$_ble_base_run/$$.dummy ret
  builtin eval "ret=(\"\$dummy\"/${1#/})" 2>/dev/null
  builtin eval -- "$restore"
  [[ ! $ret ]]
}

## @fn ble/util/is-cygwin-slow-glob word
##   In Cygwin, expansion of paths starting with // is slow (#D1168), so check accordingly.
function ble/util/is-cygwin-slow-glob {
  # Note: core-complete.sh performs escaping, so
  #   A string such as "'//...'" is passed to "$1".
  [[ ( $OSTYPE == cygwin || $OSTYPE == msys ) && ${1#\'} == //* && ! -o noglob ]] &&
    ble/util/has-glob-pattern "$1"
}

## @fn ble/util/eval-pathname-expansion pattern
##   @var[out] ret
function ble/util/eval-pathname-expansion {
  ret=()
  if ble/util/is-cygwin-slow-glob; then # Note: #D1168
    if shopt -q failglob &>/dev/null; then
      return 1
    elif shopt -q nullglob &>/dev/null; then
      return 0
    else
      set -f
      ble/util/eval-pathname-expansion "$1"; local ext=$1
      set +f
      return "$ext"
    fi
  fi

  # adjust glob settings
  local canon=
  if [[ :$2: == *:canonical:* ]]; then
    canon=1
    local set=$- shopt gignore=$GLOBIGNORE
    ble/base/list-shopt failglob nullglob extglob dotglob
    shopt -u failglob
    shopt -s nullglob
    shopt -s extglob
    set +f
    GLOBIGNORE=
  fi

  # Note: If failglob fails, the continuation will not be executed unless it is enclosed in eval.
  # Note: The error message when failglob fails is killed.
  builtin eval "ret=($1)" 2>/dev/null; local ext=$?

  # restore glob settings
  if [[ $canon ]]; then
    # Note: dotglob is changed by GLOBIGNORE
    GLOBIGNORE=$gignore
    if [[ :$shopt: == *:dotglob:* ]]; then shopt -s dotglob; else shopt -u dotglob; fi
    [[ $set == *f* ]] && set -f
    [[ :$shopt: != *:extglob:* ]] && shopt -u extglob
    [[ :$shopt: != *:nullglob:* ]] && shopt -u nullglob
    [[ :$shopt: == *:failglob:* ]] && shopt -s failglob
  fi

  return "$ext"
}


# The regular expression is _ble_bash>=30000
_ble_util_rex_isprint='^[ -~]+' # disable=#D1440 (LC_COLLATE is set)
## @fn ble/util/isprint+ str
##
##   @var[out] BASH_REMATCH Used in ble-exit/text/update/position.
function ble/util/isprint+ {
  local LC_ALL= LC_COLLATE=C
  [[ $1 =~ $_ble_util_rex_isprint ]]
}
# suppress locale error #D1440
ble/function#suppress-stderr ble/util/isprint+

## @fn ble/util/mktime Y m d H M S z
## @fn ble/util/mktime 'Y-m-d H:M:S z'
##   @param[in] Y m d H M S
##     These specify year, month, day, hour, minute, and second, respectively.
##   @param[in,opt] z
##     This specifies the time zone in the format [-+]HHMM.  If `z` is
##     unspecified, the local time zone is used, but this implementation does
##     not consider the summer time currently.  We assume that the time
##     difference with respect to UTC would be the same as the current one
##     while the conversion.
_ble_util_mktime_tzdelta=
function ble/util/mktime {
  if (($#==6||$#==7)); then
    local tz=${7-}
    if [[ ! $tz ]]; then
      # TODO: summer time
      # if ble/is-function ble/bin/gawk; then
      #   local mktime_str
      #   ble/util/sprintf mktime_str 'mktime("%04d %02d %02d %02d %02d %02d")' "${@:1:6}"
      #   ble/util/assign ret "ble/bin/gawk 'BEGIN{print $mktime_str; exit}'"
      # elif ble/is-function ble/bin/mawk; then
      #   local mktime_str
      #   ble/util/sprintf mktime_str 'mktime("%04d %02d %02d %02d %02d %02d")' "${@:1:6}"
      #   ble/util/assign ret "ble/bin/mawk 'BEGIN{print $mktime_str; exit}'"
      # else
      #   # if date supports +%s and -d DATE.
      #   ble/bin/date -d "$1-$2-$3 $4:$5:$6" +%s
      # fi
      if [[ ! ${_ble_util_mktime_tzdelta-} ]]; then
        # Note: Currently, the time difference is calculated for the current
        # time.  This does not consider the summer time of the specified time.
        # If needed, we need to specify the time to the date command using the
        # GNU extension "-d time" every time.  We cannot cache the time
        # difference in this case.
        ble/util/assign _ble_util_mktime_tzdelta 'ble/bin/date +%z'
      fi
      tz=$_ble_util_mktime_tzdelta
    fi

    local tzdelta
    if ble/string#match "$tz" '^[-+]([0-9]{1,2})([0-9]{2})$'; then
      tzdelta=${tz::1}$(((10#0${BASH_REMATCH[1]}*60+10#0${BASH_REMATCH[2]})*60))
    else
      tzdelta=0
    fi

    local Y=$((10#0$1)) m=$((10#0$2)) d=$((10#0$3))
    local H=$((10#0$4)) M=$((10#0$5)) S=$((10#0$6))

    ((m<3)) && ((Y--,m+=12))
    local day_delta=$((365*(Y-1970)+(Y/4-Y/100+Y/400-477)+(m+1)*306/10-63+(d-1)))
    ((ret=((day_delta*24+H)*60+M)*60+S-tzdelta))
    return 0
  elif ble/string#match "${1-}" '^([0-9]{4})-([01]?[0-9])-([0-3]?[0-9]) ([0-2]?[0-9]):([0-5]?[0-9]):([0-5]?[0-9])( ([-+][0-9]{3,4}))?$'; then
    ble/util/mktime "${BASH_REMATCH[@]:1:6}" "${BASH_REMATCH[8]-}"
  else
    ble/util/print "$FUNCNAME: invalid argument '${1-}'" >&2
    return 2
  fi
}

if ((_ble_bash>=40200)); then
  function ble/util/strftime {
    if [[ $1 = -v ]]; then
      builtin printf -v "$2" "%($3)T" "${4:--1}"
    else
      builtin printf "%($1)T" "${2:--1}"
    fi
  }
else
  function ble/util/strftime {
    if [[ $1 = -v ]]; then
      local fmt=$3 time=$4
      ble/util/assign "$2" "ble/bin/date +\"\$fmt\" $time"
    else
      ble/bin/date +"$1" ${2+"$2"}
    fi
  }
fi

## @fn ble/util/time
## @fn ble/util/timeval
##   Get the current UNIX time. ble/util/time is in seconds,
##   ble/util/timeval is in microseconds. Decomposition into seconds before Bash 5.0
##   There is only Noh.
if ((_ble_bash>=50000)); then
  function ble/util/time { ret=$EPOCHSECONDS; }
  function ble/util/timeval { ret=${EPOCHREALTIME//[!0-9]}; }
else
  function ble/util/time {
    if ble/util/strftime -v ret '%s' 2>/dev/null && ble/string#match '^[0-9]{3,}$'; then
      function ble/util/time { ble/util/strftime -v ret '%s'; }
    else
      function ble/util/time {
        ble/util/strftime -v ret '%F %T %z'
        ble/util/mktime "$ret"
      }
      ble/util/time
    fi

    # In Bash >= 4.2, we continue to use printf %(...)T.  In Bash < 4.2, we use
    # the internal clock SECONDS relative to the origin _ble_util_time_base.
    if ((_ble_bash<40200)) && ble/string#match "${SECONDS-}" '^[0-9]+$'; then
      builtin readonly SECONDS
      _ble_util_time_base=$((ret-SECONDS))
      function ble/util/time { ((ret=_ble_util_time_base+SECONDS)); }
    fi
  }
  function ble/util/timeval { ble/util/time; ((ret*=1000000)); }

fi

#%< util.hook.sh

#------------------------------------------------------------------------------
# ble/util/msleep

#%include benchmark.sh

function ble/util/msleep/.check-sleep-decimal-support {
  local version; ble/util/assign version 'LC_ALL=C ble/bin/sleep --version 2>&1' 2>/dev/null # suppress locale error #D1440
  [[ $version == *'GNU coreutils'* || $OSTYPE == darwin* && $version == 'usage: sleep seconds' ]]
}

_ble_util_msleep_delay=2000 # [usec]
function ble/util/msleep/.core {
  local sec=${1%%.*}
  ((10#0${1##*.}&&sec++)) # Round up the decimal part
  ble/bin/sleep "$sec"
}
function ble/util/msleep {
  local v=$((1000*$1-_ble_util_msleep_delay))
  ((v<=0)) && v=0
  ble/util/sprintf v '%d.%06d' "$((v/1000000))" "$((v%1000000))"
  ble/util/msleep/.core "$v"
}

_ble_util_msleep_calibrate_count=0
function ble/util/msleep/.calibrate-loop {
  local _ble_measure_threshold=10000
  local ret nsec _ble_measure_count=1 v=0
  _ble_util_msleep_delay=0 ble-measure -q 'ble/util/msleep 1'
  local delay=$((nsec/1000-1000)) count=$_ble_util_msleep_calibrate_count
  ((count<=0||delay<_ble_util_msleep_delay)) && _ble_util_msleep_delay=$delay # minimum value
  # ((_ble_util_msleep_delay=(count*_ble_util_msleep_delay+delay)/(count+1))) # Average value
}
function ble/util/msleep/calibrate {
  ble/util/msleep/.calibrate-loop &>/dev/null
  ((++_ble_util_msleep_calibrate_count<5)) &&
    ble/util/idle.continue
}

## @fn ble/util/msleep/.use-read-timeout type
##   @param[in] type
##     FILE.OPEN
##       FILE=fifo Create a file with mkfifo.
##       Open FILE=zero /dev/zero.
##       Open FILE=ptmx /dev/ptmx.
##       OPEN=open Opens the file every time.
##       OPEN=exec1 Opens the file read-only.
##       OPEN=exec2 Opens a file for reading and writing.
##     socket
##       Use /dev/udp/0.0.0.0/80.
##     procsub
##       Use 9< <(sleep).
function ble/util/msleep/.use-read-timeout {
  local msleep_type=$1 opts=${2-}
  _ble_util_msleep_fd=
  case $msleep_type in
  (socket)
    _ble_util_msleep_delay1=10000 # Time taken for short msleep [usec]
    _ble_util_msleep_delay2=50000 # /bin/sleep 0 time [usec]
    function ble/util/msleep/.core2 {
      ((v-=_ble_util_msleep_delay2))
      ble/bin/sleep "$((v/1000000))"
      ((v%=1000000))
    }
    function ble/util/msleep {
      local v=$((1000*$1-_ble_util_msleep_delay1))
      ((v<=0)) && v=100
      ((v>1000000+_ble_util_msleep_delay2)) &&
        ble/util/msleep/.core2
      ble/util/sprintf v '%d.%06d' "$((v/1000000))" "$((v%1000000))"
      ! ble/bash/read-timeout "$v" v < /dev/udp/0.0.0.0/80
    }
    function ble/util/msleep/.calibrate-loop {
      local _ble_measure_threshold=10000
      local ret nsec _ble_measure_count=1 v=0

      _ble_util_msleep_delay1=0 ble-measure 'ble/util/msleep 1'
      local delay=$((nsec/1000-1000)) count=$_ble_util_msleep_calibrate_count
      ((count<=0||delay<_ble_util_msleep_delay1)) && _ble_util_msleep_delay1=$delay # minimum value

      _ble_util_msleep_delay2=0 ble-measure 'ble/util/msleep/.core2'
      local delay=$((nsec/1000))
      ((count<=0||delay<_ble_util_msleep_delay2)) && _ble_util_msleep_delay2=$delay # minimum value
    } ;;
  (procsub)
    _ble_util_msleep_delay=300
    ble/fd#alloc _ble_util_msleep_fd '< <(
      [[ $- == *i* ]] && builtin trap -- '' INT QUIT
      while kill -0 $$; do command sleep 300; done &>/dev/null
    )'
    function ble/util/msleep {
      local v=$((1000*$1-_ble_util_msleep_delay))
      ((v<=0)) && v=100
      ble/util/sprintf v '%d.%06d' "$((v/1000000))" "$((v%1000000))"
      ! ble/bash/read-timeout "$v" -u "$_ble_util_msleep_fd" v
    } ;;
  (*.*)
    if local rex='^(fifo|zero|ptmx)\.(open|exec)([12])(-[_a-zA-Z0-9]+)?$'; [[ $msleep_type =~ $rex ]]; then
      local file=${BASH_REMATCH[1]}
      local open=${BASH_REMATCH[2]}
      local direction=${BASH_REMATCH[3]}
      local fall=${BASH_REMATCH[4]}

      # tmpfile
      case $file in
      (fifo)
        _ble_util_msleep_tmp=$_ble_base_run/$$.util.msleep.pipe
        if [[ ! -p $_ble_util_msleep_tmp ]]; then
          [[ -e $_ble_util_msleep_tmp ]] && ble/bin/rm -rf "$_ble_util_msleep_tmp"
          ble/bin/mkfifo "$_ble_util_msleep_tmp"
        fi ;;
      (zero)
        open=dup
        _ble_util_msleep_tmp=$_ble_util_fd_zero ;;
      (ptmx)
        _ble_util_msleep_tmp=/dev/ptmx ;;
      esac

      # redirection type
      local redir='<'
      ((direction==2)) && redir='<>'

      # open type
      if [[ $open == dup ]]; then
        _ble_util_msleep_fd=$_ble_util_msleep_tmp
        _ble_util_msleep_read='! ble/bash/read-timeout "$v" -u "$_ble_util_msleep_fd" v'
      elif [[ $open == exec ]]; then
        ble/fd#alloc _ble_util_msleep_fd "$redir \"\$_ble_util_msleep_tmp\"" base
        _ble_util_msleep_read='! ble/bash/read-timeout "$v" -u "$_ble_util_msleep_fd" v'
      else
        _ble_util_msleep_read='! ble/bash/read-timeout "$v" v '$redir' "$_ble_util_msleep_tmp"'
      fi

      # fallback/switch
      if [[ $fall == '-coreutil' ]]; then
        _ble_util_msleep_switch=200 # [msec]
        _ble_util_msleep_delay1=2000 # Time taken for short msleep [usec]
        _ble_util_msleep_delay2=50000 # /bin/sleep 0 time [usec]
        function ble/util/msleep {
          if (($1<_ble_util_msleep_switch)); then
            local v=$((1000*$1-_ble_util_msleep_delay1))
            ((v<=0)) && v=100
            ble/util/sprintf v '%d.%06d' "$((v/1000000))" "$((v%1000000))"
            builtin eval -- "$_ble_util_msleep_read"
          else
            local v=$((1000*$1-_ble_util_msleep_delay2))
            ((v<=0)) && v=100
            ble/util/sprintf v '%d.%06d' "$((v/1000000))" "$((v%1000000))"
            ble/bin/sleep "$v"
          fi
        }
        function ble/util/msleep/.calibrate-loop {
          local _ble_measure_threshold=10000
          local ret nsec _ble_measure_count=1

          _ble_util_msleep_switch=200
          _ble_util_msleep_delay1=0 ble-measure 'ble/util/msleep 1'
          local delay=$((nsec/1000-1000)) count=$_ble_util_msleep_calibrate_count
          ((count<=0||delay<_ble_util_msleep_delay1)) && _ble_util_msleep_delay1=$delay # Select minimum value

          _ble_util_msleep_delay2=0 ble-measure 'ble/bin/sleep 0'
          local delay=$((nsec/1000))
          ((count<=0||delay<_ble_util_msleep_delay2)) && _ble_util_msleep_delay2=$delay # Select minimum value
          ((_ble_util_msleep_switch=_ble_util_msleep_delay2/1000+10))
        }
      else
        function ble/util/msleep {
          local v=$((1000*$1-_ble_util_msleep_delay))
          ((v<=0)) && v=100
          ble/util/sprintf v '%d.%06d' "$((v/1000000))" "$((v%1000000))"
          builtin eval -- "$_ble_util_msleep_read"
        }
      fi
    fi ;;
  esac

  # Note: Older versions of Cygwin will give you a "Communication error on send" error with bidirectional pipes.
  #   If it does not behave as expected, replace it with process replacement. #D1449
  # #D1467 On Cygwin/Linux, timeout is 142, but this is system dependent.
  #   As shown in man bash, check if it is greater than 128
  if [[ :$opts: == *:check:* && $_ble_util_msleep_fd ]]; then
    if ble/bash/read-timeout 0.000001 -u "$_ble_util_msleep_fd" _ble_util_msleep_dummy 2>/dev/null; (($?<=128)); then
      ble/fd#close _ble_util_msleep_fd
      _ble_util_msleep_fd=
      return 1
    fi
  fi
  return 0
}

_ble_util_msleep_builtin_available=
if ((_ble_bash>=40400)) && ble/util/load-standard-builtin sleep; then
  _ble_util_msleep_builtin_available=1
  _ble_util_msleep_delay=300
  function ble/util/msleep/.core { builtin sleep "$1"; }

  ## @fn ble/builtin/sleep/.read-time time
  ##   @var[out] a1 b1
  ##     Returns the integer and decimal parts respectively.
  ##   @var[in,out] flags
  function ble/builtin/sleep/.read-time {
    a1=0 b1=0
    local unit= exp=
    if local rex='^\+?([0-9]*)\.([0-9]*)([eE][-+]?[0-9]+)?([smhd]?)$'; [[ $1 =~ $rex ]]; then
      a1=${BASH_REMATCH[1]}
      b1=${BASH_REMATCH[2]}00000000000000
      b1=$((10#0${b1::14}))
      exp=${BASH_REMATCH[3]}
      unit=${BASH_REMATCH[4]}
    elif rex='^\+?([0-9]+)([eE][-+]?[0-9]+)?([smhd]?)$'; [[ $1 =~ $rex ]]; then
      a1=${BASH_REMATCH[1]}
      exp=${BASH_REMATCH[2]}
      unit=${BASH_REMATCH[3]}
    else
      ble/util/print "ble/builtin/sleep: invalid time spec '$1'" >&2
      flags=E$flags
      return 2
    fi

    if [[ $exp ]]; then
      case $exp in
      ([eE]-*)
        ((exp=10#0${exp:2}))
        while ((exp--)); do
          ((b1=a1%10*frac_scale/10+b1/10,a1/=10))
        done ;;
      ([eE]*)
        exp=${exp:1}
        ((exp=${exp#+}))
        while ((exp--)); do
          ((b1*=10,a1=a1*10+b1/frac_scale,b1%=frac_scale))
        done ;;
      esac
    fi

    local scale=
    case $unit in
    (d) ((scale=24*3600)) ;;
    (h) ((scale=3600)) ;;
    (m) ((scale=60)) ;;
    esac
    if [[ $scale ]]; then
      ((b1*=scale))
      ((a1=a1*scale+b1/frac_scale))
      ((b1%=frac_scale))
    fi
    return 0
  }

  function ble/builtin/sleep {
    local set shopt; ble/base/.adjust-bash-options set shopt
    local frac_scale=100000000000000
    local a=0 b=0 flags=
    if (($#==0)); then
      ble/util/print "ble/builtin/sleep: no argument" >&2
      flags=E$flags
    fi
    while (($#)); do
      case $1 in
      (--version) flags=v$flags ;;
      (--help)    flags=h$flags ;;
      (-*)
        flags=E$flags
        ble/util/print "ble/builtin/sleep: unknown option '$1'" >&2 ;;
      (*)
        if local a1 b1; ble/builtin/sleep/.read-time "$1"; then
          ((b+=b1))
          ((a=a+a1+b/frac_scale))
          ((b%=frac_scale))
        fi ;;
      esac
      shift
    done
    if [[ $flags == *h* ]]; then
      ble/util/print-lines \
        'usage: sleep NUMBER[SUFFIX]...' \
        'Pause for the time specified by the sum of the arguments. SUFFIX is one of "s"' \
        '(seconds), "m" (minutes), "h" (hours) or "d" (days).' \
        '' \
        'OPTIONS' \
        '     --help    Show this help.' \
        '     --version Show version.'
    fi
    if [[ $flags == *v* ]]; then
      ble/util/print "sleep (ble) $BLE_VERSION"
    fi
    if [[ $flags == *E* ]]; then
      ble/util/setexit 2
    elif [[ $flags == *[vh]* ]]; then
      ble/util/setexit 0
    else
      b=00000000000000$b
      b=${b:${#b}-14}
      builtin sleep "$a.$b"
    fi
    local ext=$?
    ble/base/.restore-bash-options set shopt 1
    return "$ext"
  }
  function sleep {
    builtin eval -- "$_ble_bash_POSIXLY_CORRECT_local_adjust"
    ble/builtin/sleep "$@"
    builtin eval -- "$_ble_bash_POSIXLY_CORRECT_local_return"
  }
elif [[ -f $_ble_base/lib/@init/init-msleep.bash ]] &&
       source -- "$_ble_base/lib/@init/init-msleep.bash" &&
       ble/util/msleep/.load-compiled-builtin
then
  # Compile sleep.so yourself.
  #
  # Note: #D1452 #D1468 #D1469 The originally used read -t method is
  # I found out that it was blocked due to a bug in Bash. If bash 4.3..5.1, which OS?
  # But I will reproduce it. I have no choice but to compile loadable builtin myself.
  # I decided to do it. I thought so, but I can't enable this due to licensing issues.
  # No.
  function ble/util/msleep { ble/builtin/msleep "$1"; }
elif ((40000<=_ble_bash&&!(40300<=_ble_bash&&_ble_bash<50200))) &&
       [[ $OSTYPE != cygwin* && $OSTYPE != msys* && $OSTYPE != haiku* && $OSTYPE != minix* ]]
then
  # How to open FIFO (mkfifo) in advance for both reading and writing and use read -t.
  #
  # Note: #D1452 #D1468 #D1469 Since Bash 4.3, read -t is generally
  # It may become stuck due to race condition with SIGALRM. socket
  # (/dev/udp) and fifos are particularly prone to problems. Especially noticeable on Cygwin.
  # However, the frequency of occurrence varies depending on the environment, usage, and method. Cygwin/MSYS,
  # fifo does not work as expected in Haiku and Minix.
  ble/util/msleep/.use-read-timeout fifo.exec2
elif ((_ble_bash>=40000)) && ble/fd#is-open "$_ble_util_fd_zero"; then
  # How to read -t to /dev/zero.
  #
  # Note: #D1452 #D1468 #D1469 The originally used method for FIFO is safe.
  # If not, read -t to /dev/zero. It will keep reading 0
  # Therefore, it will use the CPU, but be patient and only use it for short sleep times.
  # I'll do something. /dev/zero existed on all the OSs I checked (Linux,
  # Cygwin, FreeBSD, Solaris, Minix, Haiku, MSYS2)。
  ble/util/msleep/.use-read-timeout zero.exec1-coreutil
elif ble/bin#freeze-utility-path sleepenh; then
  function ble/util/msleep/.core { ble/bin/sleepenh "$1" &>/dev/null; }
elif ble/bin#freeze-utility-path usleep; then
  function ble/util/msleep {
    local v=$((1000*$1-_ble_util_msleep_delay))
    ((v<=0)) && v=0
    ble/bin/usleep "$v" &>/dev/null
  }
elif ble/util/msleep/.check-sleep-decimal-support; then
  function ble/util/msleep/.core { ble/bin/sleep "$1"; }
fi

function ble/util/sleep {
  local msec=$((${1%%.*}*1000))
  if [[ $1 == *.* ]]; then
    frac=${1##*.}000
    ((msec+=10#0${frac::3}))
  fi
  ble/util/msleep "$msec"
}

#------------------------------------------------------------------------------
# ble/util/conditional-sync

function ble/util/conditional-sync/.collect-descendant-pids {
  local pid=$1 awk_script='
    $1 ~ /^[0-9]+$/ && $2 ~ /^[0-9]+$/ {
      child[$2,child[$2]++]=$1;
    }
    function print_recursive(pid, _, n, i) {
      if (child[pid]) {
        n = child[pid];
        child[pid] = 0; # avoid infinite loop
        for (i = 0; i < n; i++) {
          print_recursive(child[pid, i]);
        }
      }
      print pid;
    }
    END { print_recursive(pid); }
  '
  ble/util/assign ret 'ble/bin/ps -A -o pid,ppid'
  ble/util/assign-array ret 'ble/bin/awk -v pid="$pid" "$awk_script" <<< "$ret"'
}

## @fn ble/util/conditional-sync/.kill
##   @var[in] __ble_pid
##   @var[in] __ble_opts
function ble/util/conditional-sync/.kill {
  [[ $__ble_pid ]] || return 0
  local kill_pids
  if [[ :$__ble_opts: == *:killall:* ]]; then
    ble/util/conditional-sync/.collect-descendant-pids "$__ble_pid"
    kill_pids=("${ret[@]}")
  else
    kill_pids=("$__ble_pid")
  fi

  # Note #D2031: In Cygwin/MSYS2 (Windows), we somehow need to fork at least
  # one process before `kill` to make sure it works.
  if [[ $OSTYPE == cygwin* || $OSTYPE == msys* ]]; then
    (ble/util/setexit 0)
  fi

  if [[ :$__ble_opts: == *:SIGKILL:* ]]; then
    builtin kill -9 "${kill_pids[@]}" &>/dev/null
  else
    builtin kill -- "${kill_pids[@]}" &>/dev/null
  fi
} &>/dev/null

## @fn ble/util/conditional-sync command [condition weight opts]
##   Evaluate COMMAND and kill it when CONDITION becomes unsatisfied before
##   COMMAND ends.
##
##   @param[in] command
##     The command that is evaluated in a subshell.  If an empty string is
##     specified, only the CONDITION is checked for the synchronization and any
##     background subshell is not started.
##
##   @param[in,opt] condition
##     The command to test the condition to continue to run the command.  The
##     default condition is "! ble/decode/has-input".  The following local
##     variables are available from the condition command:
##
##     @var sync_elapsed
##       Accumulated time of sleep in milliseconds.
##
##   @param[in,opt] weight
##     The interval of checking CONDITION in milliseconds.  The default is
##     "100".
##   @param[in,opt] opts
##     A colon-separated list of the following fields to control the detailed
##     behavior:
##
##     @opt progressive-weight
##       The interval of checking CONDITION is gradually increased and stops
##       at the value specified by WEIGHT.
##     @opt timeout=TIMEOUT
##       When this is specified, COMMAND is unconditionally terminated when
##       it does not end within the time specified by TIMEOUT in milliseconds
##     @opt killall
##       Kill also all the children and descendant processes. When this is
##       unspecified, only the subshell used to run COMMAND is killed.
##     @opt SIGKILL
##       The processes are killed by SIGKILL.  When this is unspecified, the
##       processes are killed by SIGTERM.
##
##     @opt pid=PID
##       When specified, COMMAND is not evaluated, and the function instead
##       waits for the exit of the process specified by PID.  If a negative
##       integer is specified, it is treated as PGID.  When the condition is
##       unsatisfied or the timeout has been reached, the specified process
##       will be killed.
##
##     @opt no-wait-pid
##       Do not wait for the exit status of the background process
##
function ble/util/conditional-sync {
  local __ble_command=$1
  local __ble_continue=${2:-'! ble/decode/has-input'}
  local __ble_weight=$3; ((__ble_weight<=0&&(__ble_weight=100)))
  local __ble_opts=$4

  local __ble_timeout= ret
  ble/opts#extract-last-optarg "$__ble_opts" timeout && ((__ble_timeout=ret))

  [[ :$__ble_opts: == *:progressive-weight:* ]] &&
    local __ble_weight_max=$__ble_weight __ble_weight=1

  # read opt "pid=PID/-PGID"
  ble/opts#extract-last-optarg "$__ble_opts" pid
  local __ble_pid=$ret
  ble/util/unlocal ret

  local sync_elapsed=0
  if [[ $__ble_timeout ]] && ((__ble_timeout<=0)); then
    ble/util/conditional-sync/.kill
    return 142
  fi
  builtin eval -- "$__ble_continue" || return 148
  (
    ble/util/joblist/__suppress__
    [[ $__ble_pid ]] || { builtin eval -- "$__ble_command" & __ble_pid=$!; }
    while
      # check timeout
      if [[ $__ble_timeout ]]; then
        if ((__ble_timeout<=0)); then
          ble/util/conditional-sync/.kill
          return 142
        fi
        ((__ble_weight>__ble_timeout)) && __ble_weight=$__ble_timeout
        ((__ble_timeout-=__ble_weight))
      fi

      ble/util/msleep "$__ble_weight"
      ((sync_elapsed+=__ble_weight))
      [[ :$__ble_opts: == *:progressive-weight:* ]] &&
        ((__ble_weight<<=1,__ble_weight>__ble_weight_max&&(__ble_weight=__ble_weight_max)))
      [[ ! $__ble_pid ]] || builtin kill -0 "$__ble_pid" &>/dev/null
    do
      if ! builtin eval -- "$__ble_continue"; then
        ble/util/conditional-sync/.kill
        return 148
      fi
    done
    [[ ! $__ble_pid || :$__ble_opts: == *:no-wait-pid:* ]] || wait "$__ble_pid"
  )
}

#------------------------------------------------------------------------------

## @fn ble/util/cat [files..]
##   Alternative to cat. Read separated by NUL which cannot be handled directly.
function ble/util/cat/.impl {
  local content= IFS=
  while ble/bash/read -d '' content; do
    printf '%s\0' "$content"
  done
  [[ $content ]] && printf '%s' "$content"
}
function ble/util/cat {
  if (($#)); then
    local file
    for file; do ble/util/cat/.impl < "$1"; done
  else
    ble/util/cat/.impl
  fi
}

_ble_util_less_fallback=
function ble/util/get-pager {
  if [[ ! $_ble_util_less_fallback ]]; then
    if ble/bin#has less; then
      _ble_util_less_fallback=less
    elif ble/bin#has pager; then
      _ble_util_less_fallback=pager
    elif ble/bin#has more; then
      _ble_util_less_fallback=more
    else
      _ble_util_less_fallback=cat
    fi
  fi

  builtin eval "$1=\${bleopt_pager:-\${PAGER:-\$_ble_util_less_fallback}}"
}
function ble/util/pager {
  local pager; ble/util/get-pager pager
  builtin eval -- "$pager \"\$@\""
}

_ble_util_file_stat=
function ble/file/has-stat {
  if [[ ! $_ble_util_file_stat ]]; then
    _ble_util_file_stat=-
    if ble/bin#freeze-utility-path -n stat; then
      # Reference: http://stackoverflow.com/questions/17878684/best-way-to-get-file-modified-time-in-seconds
      if ble/bin/stat -c %Y / &>/dev/null; then
        _ble_util_file_stat=c
      elif ble/bin/stat -f %m / &>/dev/null; then
        _ble_util_file_stat=f
      fi
    fi
  fi

  function ble/file/has-stat { [[ $_ble_util_file_stat != - ]]; } || return 1
  ble/file/has-stat
}

## @fn ble/file#mtime filename
##   Get the mtime of the file filename.
##   @param[in] filename Specifies the file name.
##
##   @var[out] ret
##     Gets the time in Unix Epoch.
##     If a decimal fraction less than a second can also be obtained, store the fractional part in ret[1].
##
function ble/file#mtime {
  # fallback: print current time
  function ble/file#mtime { ble/util/time; ret=("$ret"); } || return 1

  if ble/bin/date -r / +%s &>/dev/null; then
    function ble/file#mtime { local file=$1; ble/util/assign-words ret 'ble/bin/date -r "$file" +"%s %N"' 2>/dev/null; }
  elif ble/file/has-stat; then
    # Reference: http://stackoverflow.com/questions/17878684/best-way-to-get-file-modified-time-in-seconds
    case $_ble_util_file_stat in
    (c) function ble/file#mtime { local file=$1; ble/util/assign ret 'ble/bin/stat -c %Y "$file"' 2>/dev/null; } ;;
    (f) function ble/file#mtime { local file=$1; ble/util/assign ret 'ble/bin/stat -f %m "$file"' 2>/dev/null; } ;;
    esac
  fi

  ble/file#mtime "$@"
}

function ble/file#inode {
  # fallback
  function ble/file#inode { ret=; ((0)); } || return 1

  if ble/bin#freeze-utility-path -n ls &&
      ble/util/assign-words ret 'ble/bin/ls -di /' 2>/dev/null &&
      ((${#ret[@]}==2)) && ble/string#match "$ret" '^[0-9]+$'
  then
    function ble/file#inode { local file=$1; ble/util/assign-words ret 'ble/bin/ls -di "$file"' 2>/dev/null; }
  elif ble/file/has-stat; then
    case $_ble_util_file_stat in
    (c) function ble/file#inode { local file=$1; ble/util/assign-words ret 'ble/bin/stat -c %i "$file"' 2>/dev/null; } ;;
    (f) function ble/file#inode { local file=$1; ble/util/assign-words ret 'ble/bin/stat -f %i "$file"' 2>/dev/null; } ;;
    esac
  fi

  ble/file#inode "$@"
}

function ble/file#hash {
  local file=$1 size
  if ! ble/util/assign size 'ble/bin/wc -c "$file" 2>/dev/null'; then
    ret=error:$RANDOM
    return 1
  fi
  ble/string#split-words size "$size"
  ble/file#hash/.impl
}
if ble/bin#freeze-utility-path -n git; then
  function ble/file#hash/.impl {
    ble/util/assign ret 'ble/bin/git hash-object "$file"'
    ret="size:$size;hash:$ret"
  }
elif ble/bin#freeze-utility-path -n openssl; then
  function ble/file#hash/.impl {
    ble/util/assign-words ret 'ble/bin/openssl sha1 -r "$file"'
    ret="size:$size;sha1:$ret"
  }
elif ble/bin#freeze-utility-path -n sha1sum; then
  function ble/file#hash/.impl {
    ble/util/assign-words ret 'ble/bin/sha1sum "$file"'
    ret="size:$size;sha1:$ret"
  }
elif ble/bin#freeze-utility-path -n sha1; then
  function ble/file#hash/.impl {
    ble/util/assign-words ret 'ble/bin/sha1 -r "$file"'
    ret="size:$size;sha1:$ret"
  }
elif ble/bin#freeze-utility-path -n md5sum; then
  function ble/file#hash/.impl {
    ble/util/assign-words ret 'ble/bin/md5sum "$file"'
    ret="size:$size;md5:$ret"
  }
elif ble/bin#freeze-utility-path -n md5; then
  function ble/file#hash/.impl {
    ble/util/assign-words ret 'ble/bin/md5 -r "$file"'
    ret="size:$size;md5:$ret"
  }
elif ble/bin#freeze-utility-path -n cksum; then
  function ble/file#hash/.impl {
    ble/util/assign-words ret 'ble/bin/cksum "$file"'
    ret="size:$size;cksum:$ret"
  }
else
  function ble/file#hash/.impl {
    ret="size:$size"
  }
fi

#------------------------------------------------------------------------------
## @fn ble/util/buffer text
_ble_util_buffer=()
function ble/util/buffer {
  _ble_util_buffer[${#_ble_util_buffer[@]}]=$1
}
function ble/util/buffer.print {
  ble/util/buffer "$1"$'\n'
}
function ble/util/buffer.print-lines {
  local line
  for line; do
    ble/util/buffer "$line"$'\n'
  done
}
function ble/util/buffer.flush {
  IFS= builtin eval 'local text="${_ble_util_buffer[*]-}"'
  _ble_util_buffer=()
  [[ $text ]] || return 0

  if [[ $_ble_term_state == internal ]]; then
    # Note: Hides the cursor only at the moment of output. Windows terminal etc.
    # Measures against terminals that forcefully display cursor movement.
    if [[ $_ble_term_cursor_hidden_current == hidden ]]; then
      # Note: Even if the current cursor-hidden state is "hidden", the TEXT may
      # contain the transition sequence from "reveal" to "hidden", we anyway
      # want to prefix civis.
      text=$_ble_term_civis$text
    else
      text=$_ble_term_civis$text$_ble_term_rmcivis
    fi

    [[ $bleopt_term_synchronized_update_mode == on ]] &&
      text=$'\e[?2026h'$text$'\e[?2026l'
  fi

  ble/util/put "$text" >&"$_ble_util_fd_tui_stderr"
}
function ble/util/buffer.clear {
  _ble_util_buffer=()
}

#------------------------------------------------------------------------------
# class dirty-range, urange

function ble/dirty-range#load {
  local prefix=
  if [[ $1 == --prefix=* ]]; then
    prefix=${1#--prefix=}
    ((beg=${prefix}beg,
      end=${prefix}end,
      end0=${prefix}end0))
  fi
}

function ble/dirty-range#clear {
  local prefix=
  if [[ $1 == --prefix=* ]]; then
    prefix=${1#--prefix=}
    shift
  fi

  ((${prefix}beg=-1,
    ${prefix}end=-1,
    ${prefix}end0=-1))
}

## @fn ble/dirty-range#update [--prefix=PREFIX] beg end end0
##   @param[out] PREFIX
##   @param[in] beg Starting point of change. beg<0 means no change
##   @param[in] end End point of change. end<0 indicates that the change is to the end
##   @param[in] end0 The position corresponding to end before the change.
function ble/dirty-range#update {
  local prefix=
  if [[ $1 == --prefix=* ]]; then
    prefix=${1#--prefix=}
    shift
    [[ $prefix ]] && local beg end end0
  fi

  local begB=$1 endB=$2 endB0=$3
  ((begB<0)) && return 1

  local begA endA endA0
  ((begA=${prefix}beg,endA=${prefix}end,endA0=${prefix}end0))

  local delta
  if ((begA<0)); then
    ((beg=begB,
      end=endB,
      end0=endB0))
  else
    ((beg=begA<begB?begA:begB))
    if ((endA<0||endB<0)); then
      ((end=-1,end0=-1))
    else
      ((end=endB,end0=endA0,
        (delta=endA-endB0)>0?(end+=delta):(end0-=delta)))
    fi
  fi

  if [[ $prefix ]]; then
    ((${prefix}beg=beg,
      ${prefix}end=end,
      ${prefix}end0=end0))
  fi
}

## @fn ble/urange#clear [--prefix=prefix]
##
##   @param[in,opt] prefix=
##   @var[in,out]   {prefix}umin {prefix}umax
##
function ble/urange#clear {
  local prefix=
  if [[ $1 == --prefix=* ]]; then
    prefix=${1#*=}; shift
  fi
  ((${prefix}umin=-1,${prefix}umax=-1))
}
## @fn ble/urange#update [--prefix=prefix] min max
##
##   @param[in,opt] prefix=
##   @param[in]     min max
##   @var[in,out]   {prefix}umin {prefix}umax
##
function ble/urange#update {
  local prefix=
  if [[ $1 == --prefix=* ]]; then
    prefix=${1#*=}; shift
  fi
  local min=$1 max=$2
  ((0<=min&&min<max)) || return 1
  (((${prefix}umin<0||min<${prefix}umin)&&(${prefix}umin=min),
    (${prefix}umax<0||${prefix}umax<max)&&(${prefix}umax=max)))
}
## @fn ble/urange#shift [--prefix=prefix] dbeg dend dend0
##
##   @param[in,opt] prefix=
##   @param[in]     dbeg dend dend0
##   @var[in,out]   {prefix}umin {prefix}umax
##
function ble/urange#shift {
  local prefix=
  if [[ $1 == --prefix=* ]]; then
    prefix=${1#*=}; shift
  fi
  local dbeg=$1 dend=$2 dend0=$3 shift=$4
  ((dbeg>=0)) || return 1
  [[ $shift ]] || ((shift=dend-dend0))
  ((${prefix}umin>=0&&(
      dbeg<=${prefix}umin&&(${prefix}umin<=dend0?(${prefix}umin=dend):(${prefix}umin+=shift)),
      dbeg<=${prefix}umax&&(${prefix}umax<=dend0?(${prefix}umax=dbeg):(${prefix}umax+=shift))),
    ${prefix}umin<${prefix}umax||(
      ${prefix}umin=-1,
      ${prefix}umax=-1)))
}

#------------------------------------------------------------------------------
## @fn ble/util/joblist opts
##   Get a list of current jobs and check for changes in job status.
##
##   @param[in] opts
##     ignore-volatile-jobs
##
##   @var[in,out] _ble_util_joblist_events
##   @var[out] joblist Array that stores job list
##   @var[in,out] _ble_util_joblist_jobs Internal use
##   @var[in,out] _ble_util_joblist_list Internal use
##
##   @remark Regarding the implementation method.
##   Internally calls jobs twice to check for finished jobs.
##   For comparison, the results of the previous jobs call are also recorded in _ble_util_joblist_{jobs,list} (#1).
##   First, store the results of the first jobs call in jobs0,list (#2) and compare #1 and #2 to check for changes in job status.
##   Next, overwrite #1 with the result of the second jobs call, compare #2 and #1, and check the completed jobs.
##
_ble_util_joblist_jobs=
_ble_util_joblist_list=()
_ble_util_joblist_events=()
function ble/util/joblist {
  local opts=$1 jobs0
  ble/util/assign jobs0 'jobs'

  # Note (#D2157): ble/util/assign uses the function substitution in bash >=
  # 5.3.  However, in the function substitution, the update of the joblist is
  # disabled.  For this reason, reading the output of "jobs" by ble/util/assign
  # doesn't clear the notified job entries.  To clear job entries, we perform a
  # dummy call of the jobs builtin without using a function substitution.
  ((_ble_bash>=50300)) && jobs >/dev/null

  if [[ $jobs0 == "$_ble_util_joblist_jobs" ]]; then
    # If the result is the same as the previous call, it can be assumed that there is no change in state. Termination/forced termination
    # If there is a completed job, it will be displayed as "Ended" or "Terminated".
    # However, since such a display is not made more than once, there is always a change.
    joblist=("${_ble_util_joblist_list[@]}")
    return 0
  elif [[ ! $jobs0 ]]; then
    # It is possible that the job that existed in the previous call will disappear without permission in the new call.
    # Not. The fact that the current result is empty means that the previous result should also be empty.
    # If you do that, you should enter the upper branch, so you shouldn't come here. But when I got here
    # Therefore, be careful and set it to empty so that it returns.
    _ble_util_joblist_jobs=
    _ble_util_joblist_list=()
    joblist=()
    return 0
  fi

  local lines list ijob
  ble/string#split lines $'\n' "$jobs0"
  if ((${#lines[@]})); then
    ble/util/joblist.split list "${lines[@]}"
  else
    list=()
  fi

  # check changed jobs from _ble_util_joblist_list to list
  if [[ $jobs0 != "$_ble_util_joblist_jobs" ]]; then
    for ijob in "${!list[@]}"; do
      if [[ ${_ble_util_joblist_list[ijob]} && ${list[ijob]#'['*']'[-+ ]} != "${_ble_util_joblist_list[ijob]#'['*']'[-+ ]}" ]]; then
        ble/array#push _ble_util_joblist_events "${list[ijob]}"
        list[ijob]=
      fi
    done
  fi

  ble/util/assign _ble_util_joblist_jobs 'jobs'
  _ble_util_joblist_list=()
  if [[ $_ble_util_joblist_jobs != "$jobs0" ]]; then
    ble/string#split lines $'\n' "$_ble_util_joblist_jobs"
    ble/util/joblist.split _ble_util_joblist_list "${lines[@]}"

    # check removed jobs through list -> _ble_util_joblist_list.
    if [[ :$opts: != *:ignore-volatile-jobs:* ]]; then
      for ijob in "${!list[@]}"; do
        local job0=${list[ijob]}
        if [[ $job0 && ! ${_ble_util_joblist_list[ijob]} ]]; then
          ble/array#push _ble_util_joblist_events "$job0"
        fi
      done
    fi
  else
    for ijob in "${!list[@]}"; do
      [[ ${list[ijob]} ]] &&
        _ble_util_joblist_list[ijob]=${list[ijob]}
    done
  fi
  joblist=("${_ble_util_joblist_list[@]}")
} 2>/dev/null

# A dummy function to mark the fore ground subshells by ble.sh.  Since ble.sh
# works in `bind -x', foreground completed subshells also remain in the job
# list and can be unexpectedly notified to users.  To avoid it, we mark
# foreground subshells by including the call to this dummy function.
function ble/util/joblist/__suppress__ { return 0; }

function ble/util/joblist.split {
  local arr=$1; shift
  local line ijob= rex_ijob='^\[([0-9]+)\]'
  local -a out=()
  for line; do
    [[ $line =~ $rex_ijob ]] && ijob=${BASH_REMATCH[1]}
    [[ $ijob ]] && out[ijob]=${out[ijob]:+${out[ijob]}$_ble_term_nl}$line
  done

  for ijob in "${!out[@]}"; do
    [[ ${out[ijob]} != *'ble/util/joblist/__suppress__'* ]] &&
      builtin eval -- "$arr[ijob]=\${out[ijob]}"
  done
}

## @fn ble/util/joblist.check
##   Only check for job status changes.
##   Call it explicitly just before calling jobs internally to ensure that job status changes are not missed.
function ble/util/joblist.check {
  local joblist
  ble/util/joblist "$@"
}
## @fn ble/util/joblist.has-events
##   Check whether there is a record of job status changes that have not been output.
function ble/util/joblist.has-events {
  local joblist
  ble/util/joblist
  ((${#_ble_util_joblist_events[@]}))
}

## @fn ble/util/joblist.flush
##   Confirm job status changes and output the changes detected so far.
function ble/util/joblist.flush {
  local joblist
  ble/util/joblist
  ((${#_ble_util_joblist_events[@]})) || return 1
  printf '%s\n' "${_ble_util_joblist_events[@]}"
  _ble_util_joblist_events=()
}
function ble/util/joblist.bflush {
  local joblist out
  ble/util/joblist
  ((${#_ble_util_joblist_events[@]})) || return 1
  ble/util/sprintf out '%s\n' "${_ble_util_joblist_events[@]}"
  ble/util/buffer "$out"
  _ble_util_joblist_events=()
}

## @fn ble/util/joblist.clear
##   Clears the comparison buffer when job status changes are output by bash itself.
function ble/util/joblist.clear {
  _ble_util_joblist_jobs=
  _ble_util_joblist_list=()
}

#------------------------------------------------------------------------------
## @fn ble/util/save-editing-mode varname
##   Set the current editing mode (emacs/vi/none) to a variable.
##
##   @param varname Specify the variable name of the variable to be set.
##
function ble/util/save-editing-mode {
  if [[ -o emacs ]]; then
    builtin eval "$1=emacs"
  elif [[ -o vi ]]; then
    builtin eval "$1=vi"
  else
    builtin eval "$1=none"
  fi
}
## @fn ble/util/restore-editing-mode varname
##   Restore edit mode.
##
##   @param varname Specify the variable name of the variable that recorded the edit mode.
##
function ble/util/restore-editing-mode {
  case ${!1} in
  (emacs) set -o emacs ;;
  (vi) set -o vi ;;
  (none) set +o emacs ;;
  esac
}

## @fn ble/util/reset-keymap-of-editing-mode
##   Revert to default keymap. bind 'set keymap vi-insert' etc.
## The keymap may be other than the default keymap.
##   Execute set -o emacs/vi to return to the default keymap. #D1038
function ble/util/reset-keymap-of-editing-mode {
  if [[ -o emacs ]]; then
    set -o emacs
  elif [[ -o vi ]]; then
    set -o vi
  fi
}

## @fn ble/util/rlvar#load
##   @var[out] _ble_local_rlvars
function ble/util/rlvar#load {
  # Note (#D1823): suppress warnings in a non-interactive session
  ble/util/assign _ble_local_rlvars 'builtin bind -v 2>/dev/null'
  _ble_local_rlvars=$'\n'$_ble_local_rlvars
}

## @fn ble/util/rlvar#has name
##   Check if bash supports the specified readline variable.
function ble/util/rlvar#has {
  if [[ ! ${_ble_local_rlvars:-} ]]; then
    local _ble_local_rlvars
    ble/util/rlvar#load
  fi
  [[ $_ble_local_rlvars == *$'\n'"set $1 "* ]]
}

## @fn ble/util/rlvar#test name [default(0 or 1)]
function ble/util/rlvar#test {
  if [[ ! ${_ble_local_rlvars:-} ]]; then
    local _ble_local_rlvars
    ble/util/rlvar#load
  fi
  if [[ $_ble_local_rlvars == *$'\n'"set $1 on"* ]]; then
    return 0
  elif [[ $_ble_local_rlvars == *$'\n'"set $1 off"* ]]; then
    return 1
  elif (($#>=2)); then
    (($2))
    return "$?"
  else
    return 2
  fi
}
## @fn ble/util/rlvar#read name [default_value]
function ble/util/rlvar#read {
  [[ ${2+set} ]] && ret=$2
  if [[ ! ${_ble_local_rlvars:-} ]]; then
    local _ble_local_rlvars
    ble/util/rlvar#load
  fi
  local rhs=${_ble_local_rlvars#*$'\n'"set $1 "}
  [[ $rhs != "$_ble_local_rlvars" ]] && ret=${rhs%%$'\n'*}
}

## @fn ble/util/rlvar#bind-bleopt name bleopt [opts]
function ble/util/rlvar#bind-bleopt {
  local name=$1 bleopt=$2 opts=$3
  if [[ ! ${_ble_local_rlvars:-} ]]; then
    local _ble_local_rlvars
    ble/util/rlvar#load
  fi

  # If Bash supports readline variables, along with assignments to bleopt.
  # Also set the corresponding value in the readline variable.
  if ble/util/rlvar#has "$name"; then
    # Value synchronization
    # Note (#D1148): For things that have different default values on the ble.sh side than Bash,
    # (Unless --keep-rlvars is specified during initialization) Rewrite to ble.sh side.
    # Put it away. Many users don't configure it themselves, so useful features are turned off.
    # On the other hand, the user who sets it will probably be able to turn it back off himself.
    if [[ :$_ble_base_arguments_opts: == *:keep-rlvars:* ]]; then
      local ret; ble/util/rlvar#read "$name"
      [[ :$opts: == *:bool:* && $ret == off ]] && ret=
      bleopt "$bleopt=$ret"
    else
      local var=bleopt_$bleopt val=off
      [[ ${!var:-} ]] && val=on
      # Note: #D1823 suppress stderr for non-interactive warning
      builtin bind "set $name $val" 2>/dev/null
    fi

    local proc_original=
    if ble/is-function "bleopt/check:$bleopt"; then
      ble/function#push "bleopt/check:$bleopt"
      proc_original='ble/function#push/call-top "$@" || return "$?"'
    fi

    # Note: #D1823 suppress stderr for non-interactive warning
    local proc_set='builtin bind "set '$name' $value" 2>/dev/null'
    if [[ :$opts: == *:bool:* ]]; then
      proc_set='
        if [[ $value ]]; then
          builtin bind "set '$name' on" 2>/dev/null
        else
          builtin bind "set '$name' off" 2>/dev/null
        fi'
    fi

    builtin eval -- "
      function bleopt/check:$bleopt {
        $proc_original
        $proc_set
        return 0
      }"
  fi

  local proc_bleopt='bleopt '$bleopt'="$1"'
  if [[ :$opts: == *:bool:* ]]; then
    proc_bleopt='
      local value; ble/string#split-words value "$1"
      if [[ ${value-} == 1 || ${value-} == [Oo][Nn] ]]; then
        bleopt '$bleopt'="$value"
      else
        bleopt '$bleopt'=
      fi'
  fi
  builtin eval -- "
    function ble/builtin/bind/set:$name {
      $proc_bleopt
      return 0
    }"
}

#------------------------------------------------------------------------------
# Functions for modules

## @fn ble/util/invoke-hook array
##   Execute the commands registered in array.
function ble/util/invoke-hook {
  local -a hooks; builtin eval "hooks=(\"\${$1[@]}\")"
  local hook ext=0
  for hook in "${hooks[@]}"; do builtin eval -- "$hook" || ext=$?; done
  return "$ext"
}

## @fn ble/util/.read-arguments-for-no-option-command commandname args...
##   @var[out] flags args
function ble/util/.read-arguments-for-no-option-command {
  local commandname=$1; shift
  flags= args=()

  local flag_literal=
  while (($#)); do
    local arg=$1; shift
    if [[ ! $flag_literal ]]; then
      case $arg in
      (--) flag_literal=1 ;;
      (--help) flags=h$flags ;;
      (-*)
        ble/util/print "$commandname: unrecognized option '$arg'" >&2
        flags=e$flags ;;
      (*)
        ble/array#push args "$arg" ;;
      esac
    else
      ble/array#push args "$arg"
    fi
  done
}


## @fn ble-autoload scriptfile functions...
##   Configure settings to automatically read the file in which the function is defined.
##   Define the actual functions in scriptfile.
##   When the function specified in functions is called for the first time,
##   The scriptfile will be automatically sourced.
##
##   @param[in] scriptfile
##     File where functions are defined
##
##     Note: When defining variables globally within this file,
##     Do not use declare/typeset.
##     Since it is sourced from within the function that performs autoload,
##     It will be treated as a local variable of that function.
##     If you want to define special variables such as associative arrays, use ble-autoload
##     Please do this at the same time as setting.
##     *Declare -g is for bash-4.3 or later.
##
##   @param[in] functions...
##     List of function names to define
##
##     This is the function that serves as the starting point for source in scriptfile.
##     There is no need to list all the function names defined in scriptfile.
##     The function used as the starting point for the scriptfile call is sufficient.
##
function ble/util/autoload {
  local file=$1; shift
  ble/util/import/is-loaded "$file" && return 0

  # *If $FUNCNAME is originally set as an environment variable,
  #   Not defined as a special variable.
  #   In this case, it is dangerous to execute it as a command blindly.

  local q=\' Q="'\''" funcname
  for funcname; do
    builtin eval "function $funcname {
      builtin unset -f $funcname
      ble-import '${file//$q/$Q}' &&
        $funcname \"\$@\"
    }"
  done
}
function ble/util/autoload/.print-usage {
  ble/util/print 'usage: ble-autoload SCRIPTFILE FUNCTION...'
  ble/util/print '  Setup delayed loading of functions defined in the specified script file.'
} >&2
## @fn ble/util/autoload/.read-arguments args...
##   @var[out] file functions flags
function ble/util/autoload/.read-arguments {
  file= flags= functions=()

  local args
  ble/util/.read-arguments-for-no-option-command ble-autoload "$@"

  # check empty arguments
  local arg index=0
  for arg in "${args[@]}"; do
    if [[ ! $arg ]]; then
      if ((index==0)); then
        ble/util/print 'ble-autoload: the script filename should not be empty.' >&2
      else
        ble/util/print 'ble-autoload: function names should not be empty.' >&2
      fi
      flags=e$flags
    fi
    ((index++))
  done

  [[ $flags == *h* ]] && return 0

  if ((${#args[*]}==0)); then
    ble/util/print 'ble-autoload: script filename is not specified.' >&2
    flags=e$flags
  elif ((${#args[*]}==1)); then
    ble/util/print 'ble-autoload: function names are not specified.' >&2
    flags=e$flags
  fi

  file=${args[0]} functions=("${args[@]:1}")
}
function ble-autoload {
  builtin eval -- "$_ble_bash_POSIXLY_CORRECT_local_adjust"
  local file flags
  local -a functions=()
  ble/util/autoload/.read-arguments "$@"
  if [[ $flags == *[eh]* ]]; then
    [[ $flags == *e* ]] && builtin printf '\n'
    ble/util/autoload/.print-usage
    local ext=0
    [[ $flags == *e* ]] && ext=2
    builtin eval -- "$_ble_bash_POSIXLY_CORRECT_local_leave"
    return "$ext"
  fi

  ble/util/autoload "$file" "${functions[@]}"
  builtin eval -- "$_ble_bash_POSIXLY_CORRECT_local_return"
}

## @fn ble-import scriptfile...
##   Search for the specified file and read it with source.
##   Files that have already been imported will not be read.
##
##   @param[in] scriptfile
##     Specify the file to read.
##     If you specify an absolute path, that file will be used.
##     Otherwise, search from $_ble_base:$_ble_base/local:$_ble_base/share.
##
_ble_util_import_files=()

bleopt/declare -n import_path "${XDG_DATA_HOME:-$HOME/.local/share}/blesh/local"

## @fn ble/util/import/search/.check-directory name dir
##   @var[out] ret
function ble/util/import/search/.check-directory {
  local name=$1 dir=${2%/}
  [[ -d ${dir:=/} ]] || return 1

  # If the path starts with {lib,contrib}/, only the lib,contrib directory is searched.
  if [[ $name == lib/* ]]; then
    [[ $dir == */lib ]] || return 1
    dir=${dir%/lib}
  elif [[ $name == contrib/* ]]; then
    [[ $dir == */contrib ]] || return 1
    dir=${dir%/contrib}
  fi

  if [[ -f $dir/$name ]]; then
    ret=$dir/$name
    return 0
  elif [[ $name != *.bash && -f $dir/$name.bash ]]; then
    ret=$dir/$name.bash
    return 0
  elif [[ $name != *.sh && -f $dir/$name.sh ]]; then
    ret=$dir/$name.sh
    return 0
  fi
  return 1
}
function ble/util/import/search {
  ret=$1
  if [[ $ret != /* && $ret != ./* && $ret != ../* ]]; then
    local -a dirs=()
    if [[ $bleopt_import_path ]]; then
      local tmp; ble/string#split tmp : "$bleopt_import_path"
      ble/array#push dirs "${tmp[@]}"
    fi
    ble/array#push dirs "$_ble_base"{,/contrib,/lib}

    "${_ble_util_set_declare[@]//NAME/checked}" # WA #D1570 checked
    local path
    for path in "${dirs[@]}"; do
      ble/set#contains checked "$path" && continue
      ble/set#add checked "$path"
      ble/util/import/search/.check-directory "$ret" "$path" && break
    done
  fi
  [[ -e $ret && ! -d $ret ]]
}
function ble/util/import/encode-filename {
  ret=$1
  local chars=%$'\t\n !"$&\'();<>\\^`|' # <emacs bug `>
  if [[ $ret == *["$chars"]* ]]; then
    local i n=${#chars} reps a b
    reps=(%{25,08,0A,2{0..2},24,2{6..9},3B,3C,3E,5C,5E,60,7C})
    for ((i=0;i<n;i++)); do
      a=${chars:i:1} b=${reps[i]} ret=${ret//"$a"/"$b"}
    done
  fi
  return 0
}
function ble/util/import/is-loaded {
  local ret
  ble/util/import/search "$1" &&
    ble/util/import/encode-filename "$ret" &&
    ble/is-function ble/util/import/guard:"$ret"
}
# called by ble/base/unload (ble.pp)
function ble/util/import/finalize {
  local file ret
  for file in "${_ble_util_import_files[@]}"; do
    ble/util/import/encode-filename "$file"; local enc=$ret
    local guard=ble/util/import/guard:$enc
    builtin unset -f "$guard"

    local onload=ble/util/import/onload:$enc
    if ble/is-function "$onload"; then
      "$onload" ble/util/unlocal
      builtin unset -f "$onload"
    fi
  done
  _ble_util_import_files=()
}
## @fn ble/util/import/.read-arguments args...
##   @var[out] files callbacks
##   @var[out] flags
##     E error
##     N not_found
##     h help
##     d delay
##     f force
##     q query
function ble/util/import/.read-arguments {
  flags= files=() callbacks=()
  local -a not_found=()
  while (($#)); do
    local arg=$1; shift
    if [[ $flags != *-* ]]; then
      case $arg in
      (--)
        flags=-$flags
        continue ;;
      (--*)
        case $arg in
        (--delay) flags=d$flags ;;
        (--help)  flags=h$flags ;;
        (--force) flags=f$flags ;;
        (--query) flags=q$flags ;;
        (--callback=*)
          ble/array#push callbacks "${arg#*=}" ;;
        (--callback)
          if (($#)); then
            ble/array#push callbacks "$1"
            shift
          else
            ble/util/print "ble-import: missing optarg for '--callback'" >&2
            flags=E$flags
          fi ;;
        (*)
          ble/util/print "ble-import: unrecognized option '$arg'" >&2
          flags=E$flags ;;
        esac
        continue ;;
      (-?*)
        local i c
        for ((i=1;i<${#arg};i++)); do
          c=${arg:i:1}
          case $c in
          ([dfq]) flags=$c$flags ;;
          (C)
            if ((i+1<${#arg})); then
              ble/array#push callbacks "${arg:i+1}"
            elif (($#)); then
              ble/array#push callbacks "$1"
              shift
            else
              ble/util/print "ble-import: missing optarg for '-C'" >&2
              flags=E$flags
            fi
            break ;;
          (*)
            ble/util/print "ble-import: unrecognized option '-$c'" >&2
            flags=E$flags ;;
          esac
        done
        continue ;;
      esac
    fi

    local ret
    if ! ble/util/import/search "$arg"; then
      ble/array#push not_found "$arg"
      continue
    fi; local file=$ret
    ble/array#push files "$file"
  done

  # When there is a file that does not exist
  if ((${#not_found[@]})); then
    flags=N$flags
    if [[ $flags != *[fq]* ]]; then
      local file
      for file in "${not_found[@]}"; do
        ble/util/print "ble-import: file '$file' not found" >&2
      done
      flags=E$flags
    fi
  fi

  return 0
}
function ble/util/import {
  local files file ext=0 ret enc
  files=("$@")
  set -- # Note #D1859: Prevent arguments from being inherited by source
  for file in "${files[@]}"; do
    ble/util/import/encode-filename "$file"; enc=$ret
    local guard=ble/util/import/guard:$enc
    ble/is-function "$guard" && return 0
    [[ -e $file ]] || return 1
    source -- "$file" || { ext=$?; continue; }
    builtin eval "function $guard { return 0; }"
    ble/array#push _ble_util_import_files "$file"

    local onload=ble/util/import/onload:$enc
    ble/function#try "$onload" ble/util/invoke-hook
  done
  return "$ext"
}
## @fn ble/util/import/option:query
##   @var[in] files flags
function ble/util/import/option:query {
  if [[ $flags == *N* ]]; then
    return 127
  elif ((${#files[@]})); then
    local file
    for file in "${files[@]}"; do
      ble/util/import/is-loaded "$file" || return 1
    done
    return 0
  else
    ble/util/print-lines "${_ble_util_import_files[@]}"
    return "$?"
  fi
}

function ble/util/import/.dispatch {
  local files flags callbacks
  ble/util/import/.read-arguments "$@"
  if [[ $flags == *[Eh]* ]]; then
    [[ $flags == *E* ]] && ble/util/print
    ble/util/print-lines \
      'usage: ble-import [-dfq|--delay|--force|--query]' \
      '          [-C CALLBACK|--callback=CALLBACK]+ [--] [SCRIPTFILE...]' \
      'usage: ble-import --help' \
      '' \
      '    Search and source script files that have not yet been loaded.  When none of' \
      '    -q, --query, -d, --delay, -C, --callback is specified, SCRIPTFILEs are' \
      '    sourced.' \
      '' \
      '  OPTIONS' \
      '    --help        Show this help.' \
      '    -d, --delay   Register SCRIPTFILEs for later loading in idle time.' \
      '    -f, --force   Ignore non-existent files without errors.' \
      '    -q, --query   When SCRIPTFILEs are specified, test if all of these files' \
      '                  are already loaded.  Without SCRIPTFILEs, print the list of' \
      '                  already imported files.' \
      '    -C, --callback=CALLBACK' \
      '                  Specify a command that will be evaluated when all of' \
      '                  SCRIPTFILEs are loaded.  If all of SCRIPTFILEs are already' \
      '                  loaded, the callback is immediately evaluated.' \
      '' \
      >&2
    [[ $flags == *E* ]] && return 2
    return 0
  fi

  if [[ $flags == *q* ]]; then
    ble/util/import/option:query
    return "$?"
  fi

  if ((!${#files[@]})); then
    [[ $flags == *f* ]] && return 0
    ble/util/print 'ble-import: files are not specified.' >&2
    return 2
  fi

  if ((${#callbacks[@]})); then
    local file i q=\' Q="'\''"
    for file in "${files[@]}"; do
      ble/util/import/is-loaded "$file" && continue
      for i in "${!callbacks[@]}"; do
        callbacks[i]="ble/util/import/eval-after-load '${file//$q/$Q}' '${callbacks[i]//$q/$Q}'"
      done
    done

    local cb
    for cb in "${callbacks[@]}"; do
      builtin eval -- "$cb"
    done
  fi

  if [[ $flags == *d* ]] && ble/is-function ble/util/idle.push; then
    local ret
    ble/string#quote-command ble/util/import "${files[@]}"
    ble/util/idle.push "$ret"
    return 0
  fi

  ((${#callbacks[@]})) || ble/util/import "${files[@]}"
}
function ble-import {
  builtin eval -- "$_ble_bash_POSIXLY_CORRECT_local_adjust"
  ble/util/import/.dispatch "$@"
  builtin eval -- "$_ble_bash_POSIXLY_CORRECT_local_return"
}

_ble_util_import_onload_count=0
function ble/util/import/eval-after-load {
  local ret file
  if ! ble/util/import/search "$1"; then
    ble/util/print "ble-import: file '$1' not found." >&2
    return 2
  fi; file=$ret

  ble/util/import/encode-filename "$file"; local enc=$ret
  local guard=ble/util/import/guard:$enc
  if ble/is-function "$guard"; then
    builtin eval -- "$2"
  else
    local onload=ble/util/import/onload:$enc
    if ! ble/is-function "$onload"; then
      local q=\' Q="'\''" list=_ble_util_import_onload_$((_ble_util_import_onload_count++))
      builtin eval -- "$list=(); function $onload { \"\$1\" $list \"\${@:2}\"; }"
    fi
    "$onload" ble/array#push "$2"
  fi
}

## @fn ble/util/stackdump [message]
## @fn ble-stackdump [message]
##   Prints the current call stack state.
##
##   @param[in,opt] message
##     Specifies the message to display before stack information.
##   @var[in] _ble_util_stackdump_title
##     Specifies the title to be displayed before the stack information.
##
_ble_util_stackdump_title=stackdump
_ble_util_stackdump_start=
function ble/util/stackdump {
  ((bleopt_internal_stackdump_enabled)) || return 1
  local message=$1 nl=$'\n' IFS=$_ble_term_IFS
  message="$_ble_term_sgr0$_ble_util_stackdump_title: $message$nl"
  local extdebug= iarg=$BASH_ARGC args=
  shopt -q extdebug 2>/dev/null && extdebug=1
  local i i0=${_ble_util_stackdump_start:-1} iN=${#FUNCNAME[*]}
  for ((i=i0;i<iN;i++)); do
    if [[ $extdebug ]] && ((BASH_ARGC[i])); then
      args=("${BASH_ARGV[@]:iarg:BASH_ARGC[i]}")
      ble/array#reverse args
      args=" ${args[*]}"
      ((iarg+=BASH_ARGC[i]))
    else
      args=
    fi
    message="$message  @ ${BASH_SOURCE[i]}:${BASH_LINENO[i-1]} (${FUNCNAME[i]}$args)$nl"
  done
  ble/util/put "$message"
}

function ble/util/stackdump/.read-arguments {
  ext=0
  local flags
  ble/util/.read-arguments-for-no-option-command ble-stackdump "$@"
  if [[ $flags == *[eh]* ]]; then
    [[ $flags == *e* ]] && ble/util/print
    {
      ble/util/print 'usage: ble-stackdump command [message]'
      ble/util/print '  Print stackdump.'
    } >&2
    [[ $flags == *e* ]] && ext=2
    return 1
  fi
  return 0
}
function ble-stackdump {
  builtin eval -- "$_ble_bash_POSIXLY_CORRECT_local_adjust"
  local args ext
  if ble/util/stackdump/.read-arguments "$@"; then
    local _ble_util_stackdump_start=2
    local IFS=$_ble_term_IFS
    ble/util/stackdump "${args[*]}"
    ext=$?
  fi
  builtin eval -- "$_ble_bash_POSIXLY_CORRECT_local_leave"
  return "$ext"
}

## @fn ble/util/assert command [message]
## @fn ble-assert command [message]
##   Evaluates the command and displays a message if it fails.
##
##   @param[in] command
##     Specifies the command to evaluate. Evaluated with eval.
##   @param[in,opt] message
##     Specify the message to display when failure occurs.
##
function ble/util/assert {
  local expr=$1 message=$2
  if ! builtin eval -- "$expr"; then
    local _ble_util_stackdump_title='assertion failure'
    local _ble_util_stackdump_start=3
    ble/util/stackdump "$expr$_ble_term_nl$message" >&2
    return 1
  else
    return 0
  fi
}
function ble/util/assert-fail {
  local message=$1
  local _ble_util_stackdump_title='assertion failure'
  local _ble_util_stackdump_start=3
  ble/util/stackdump "$message" >&2
  return 1
}

## @fn ble/util/assert/.read-arguments args...
##   @var[out] args ext
function ble/util/assert/.read-arguments {
  ext=0
  local flags
  ble/util/.read-arguments-for-no-option-command ble-assert "$@"
  if [[ $flags != *h* ]]; then
    if ((${#args[@]}==0)); then
      ble/util/print 'ble-assert: command is not specified.' >&2
      flags=e$flags
    fi
  fi
  if [[ $flags == *[eh]* ]]; then
    [[ $flags == *e* ]] && ble/util/print
    {
      ble/util/print 'usage: ble-assert command [message]'
      ble/util/print '  Evaluate command and print stackdump on fail.'
    } >&2
    [[ $flags == *e* ]] && ext=2
    return 1
  fi
  return 0
}
function ble-assert {
  builtin eval -- "$_ble_bash_POSIXLY_CORRECT_local_adjust"
  local args ext
  if ble/util/assert/.read-arguments "$@"; then
    local IFS=$_ble_term_IFS
    ble/util/assert "${args[0]}" "${args[*]:1}"
    ext=$?
  fi
  builtin eval -- "$_ble_bash_POSIXLY_CORRECT_local_leave"
  return "$ext"
}

#------------------------------------------------------------------------------
# Event loop

bleopt/declare -v debug_idle ''

## @fn ble/util/clock
##   A lightweight clock that can be used to measure time in milliseconds.
##   The starting point of measurement is when ble.sh is loaded.
##   @var[out] ret
_ble_util_clock_base=
_ble_util_clock_reso=
_ble_util_clock_type=
function ble/util/clock/.initialize {
  local LC_ALL= LC_NUMERIC=C
  if ((_ble_bash>=50000)) && {
       local now=$EPOCHREALTIME
       [[ $now == *.???* && $now != $EPOCHREALTIME ]]; }; then
    # implementation with EPOCHREALTIME
    builtin readonly EPOCHREALTIME
    _ble_util_clock_base=$((10#0${now%.*}))
    _ble_util_clock_reso=1
    _ble_util_clock_type=EPOCHREALTIME
    function ble/util/clock {
      local LC_ALL= LC_NUMERIC=C
      local now=$EPOCHREALTIME
      local integral=$((10#0${now%%.*}-_ble_util_clock_base))
      local mantissa=${now#*.}000; mantissa=${mantissa::3}
      ((ret=integral*1000+10#0$mantissa))
    }
    ble/function#suppress-stderr ble/util/clock # locale
  elif [[ -r /proc/uptime ]] && {
         local uptime
         ble/util/readfile uptime /proc/uptime
         ble/string#split-words uptime "$uptime"
         [[ $uptime == *.* ]]; }; then
    # implementation with /proc/uptime
    _ble_util_clock_base=$((10#0${uptime%.*}))
    _ble_util_clock_reso=10
    _ble_util_clock_type=uptime
    function ble/util/clock {
      local now
      ble/util/readfile now /proc/uptime
      ble/string#split-words now "$now"
      local integral=$((10#0${now%%.*}-_ble_util_clock_base))
      local fraction=${now#*.}000; fraction=${fraction::3}
      ((ret=integral*1000+10#0$fraction))
    }
  elif ((_ble_bash>=40200)); then
    local ret
    ble/util/time
    _ble_util_clock_base=$ret
    _ble_util_clock_reso=1000
    _ble_util_clock_type=printf
    function ble/util/clock {
      ble/util/time
      ((ret=(ret-_ble_util_clock_base)*1000))
    }
  elif [[ $SECONDS && ! ${SECONDS//[0-9]} ]]; then
    builtin readonly SECONDS
    _ble_util_clock_base=$SECONDS
    _ble_util_clock_reso=1000
    _ble_util_clock_type=SECONDS
    function ble/util/clock {
      local now=$SECONDS
      ((ret=(now-_ble_util_clock_base)*1000))
    }
  else
    local ret
    ble/util/time
    _ble_util_clock_base=$ret
    _ble_util_clock_reso=1000
    _ble_util_clock_type=date
    function ble/util/clock {
      ble/util/time
      ((ret=(ret-_ble_util_clock_base)*1000))
    }
  fi
}
ble/util/clock/.initialize 2>/dev/null

if ((_ble_bash>=40000)); then
  ## @fn[custom] ble/util/idle/IS_IDLE
  ##   Returns an exit status of 0 when there is nothing else to do (idle).
  ##   Note: This configuration function is overwritten by ble-decode.sh.
  function ble/util/idle/IS_IDLE { ! ble/util/is-stdin-ready; }

  _ble_util_idle_sclock=0
  function ble/util/idle/.sleep {
    local msec=$1
    ((msec<=0)) && return 0
    ble/util/msleep "$msec"
    ((_ble_util_idle_sclock+=msec))
  }

  function ble/util/idle.clock/.initialize {
    function ble/util/idle.clock/.initialize { return 0; }

    ## @fn ble/util/idle.clock
    ##   Clock used for task scheduling
    ##   @var[out] ret
    function ble/util/idle.clock/.restart { return 0; }
    if [[ ! $_ble_util_clock_type || $_ble_util_clock_type == date ]]; then
      function ble/util/idle.clock {
        ret=$_ble_util_idle_sclock
      }
    elif ((_ble_util_clock_reso<=100)); then
      function ble/util/idle.clock {
        ble/util/clock
      }
    else
      ## @fn ble/util/idle/.adjusted-clock
      ##   Based on the reference clock (rclock) and accumulated sleep time (sclock),
      ## Provides a sub-second resolution clock (aclock) of the reference clock.
      ##
      ## @var[in,out] _ble_util_idle_aclock_tick_rclock
      ## @var[in,out] _ble_util_idle_aclock_tick_sclock
      ##   Retains the values of rclock and sclock from the last time the reference clock was switched.
      ##
      ## @var[in,out] _ble_util_idle_aclock_shift
      ##   Represents the amount of time shift.
      ##
      ##   Because I don't know the subsecond time at the time of initialization,
      ##   Assuming that it is 0.000, start measuring the time.
      ##   The amount of deviation is known at the first second transition and is recorded.
      ##   In order to provide a uniform clock, we will also use this deviation to apply.
      ##
      _ble_util_idle_aclock_shift=
      _ble_util_idle_aclock_tick_rclock=
      _ble_util_idle_aclock_tick_sclock=
      function ble/util/idle.clock/.restart {
        _ble_util_idle_aclock_shift=
        _ble_util_idle_aclock_tick_rclock=
        _ble_util_idle_aclock_tick_sclock=
      }
      function ble/util/idle/.adjusted-clock {
        local resolution=$_ble_util_clock_reso
        local sclock=$_ble_util_idle_sclock
        local ret; ble/util/clock; local rclock=$((ret/resolution*resolution))

        if [[ $_ble_util_idle_aclock_tick_rclock != "$rclock" ]]; then
          if [[ $_ble_util_idle_aclock_tick_rclock && ! $_ble_util_idle_aclock_shift ]]; then
            local delta=$((sclock-_ble_util_idle_aclock_tick_sclock))
            ((_ble_util_idle_aclock_shift=delta<resolution?resolution-delta:0))
          fi
          _ble_util_idle_aclock_tick_rclock=$rclock
          _ble_util_idle_aclock_tick_sclock=$sclock
        fi

        ((ret=rclock+(sclock-_ble_util_idle_aclock_tick_sclock)-_ble_util_idle_aclock_shift))
      }
      function ble/util/idle.clock {
        ble/util/idle/.adjusted-clock
      }
    fi
  }

  function ble/util/idle/.initialize-options {
    local interval='ble_util_idle_elapsed>600000?500:(ble_util_idle_elapsed>60000?200:(ble_util_idle_elapsed>5000?100:20))'
    ((_ble_bash>50000)) && [[ $_ble_util_msleep_builtin_available ]] && interval=20
    bleopt/declare -v idle_interval "$interval"
  }
  ble/util/idle/.initialize-options

  ## @arr _ble_util_idle_task
  ##   Keep a task list. Each element represents one task,
  ##   A string in the format status|command.
  ##   command specifies the coroutine that executes the task.
  ##   status has one of the following values:
  ##
  ##     R
  ##       Indicates that the task is currently being executed.
  ##       Set in ble/util/idle.push.
  ##     I
  ##       This task is waiting for the next user's input.
  ##       Set it with ble/util/idle.wait-user-input from within the task.
  ##     S<rtime>
  ##       Task waiting for time <rtime>.
  ##       Set it with ble/util/idle.sleep from within the task.
  ##     W<stime>
  ##       sleep Task waiting for cumulative time <stime>.
  ##       Set it with ble/util/idle.isleep from within the task.
  ##     E<filename>
  ##       Task waiting for file or directory <filename> to appear.
  ##       Set it with ble/util/idle.wait-filename from within the task.
  ##     F<filename>
  ##       Task waiting for file <filename> to reach a finite size.
  ##       Set it with ble/util/idle.wait-file-content from within the task.
  ##     P<pid>
  ##       A task waiting for process <pid> (accessible to the user) to exit.
  ##       Set it with ble/util/idle.wait-process from within the task.
  ##     C<command>
  ##       A task waiting for the execution result of command <command> to become true.
  ##       Set it with ble/util/idle.wait-condition from within the task.
  ##     Z
  ##       The task is stopped. It is restarted by setting the state from outside.
  ##
  _ble_util_idle_task=()
  _ble_util_idle_lasttask=
  _ble_util_idle_SEP=$_ble_term_FS

  ## @fn ble/util/idle.do
  ##   Starts processing in standby state.
  ##
  ##   @exit
  ##     Returns success (0) when any wait processing is executed.
  ##     Returns failure (1) when nothing is executed.
  ##
  function ble/util/idle.do {
    local IFS=$_ble_term_IFS
    ble/util/idle/IS_IDLE || return 1
    ((${#_ble_util_idle_task[@]}==0)) && return 1
    ble/util/buffer.flush

    local ret
    ble/util/idle.clock/.initialize
    ble/util/idle.clock/.restart
    ble/util/idle.clock
    local _ble_idle_clock_start=$ret
    local _ble_idle_sclock_start=$_ble_util_idle_sclock
    local _ble_idle_is_first=1
    local _ble_idle_processed=
    local _ble_idle_info_shown=
    local _ble_idle_after_task=0
    while ((1)); do
      local _ble_idle_key
      local _ble_idle_next_time= _ble_idle_next_itime= _ble_idle_running= _ble_idle_waiting=
      for _ble_idle_key in "${!_ble_util_idle_task[@]}"; do
        ble/util/idle/IS_IDLE || break 2
        local _ble_idle_to_process=
        local _ble_idle_status=${_ble_util_idle_task[_ble_idle_key]%%"$_ble_util_idle_SEP"*}
        case ${_ble_idle_status::1} in
        (R) _ble_idle_to_process=1 ;;
        (I) [[ $_ble_idle_is_first ]] && _ble_idle_to_process=1 ;;
        (S) ble/util/idle.do/.check-clock "$_ble_idle_status" && _ble_idle_to_process=1 ;;
        (W) ble/util/idle.do/.check-clock "$_ble_idle_status" && _ble_idle_to_process=1 ;;
        (F) [[ -s ${_ble_idle_status:1} ]] && _ble_idle_to_process=1 ;;
        (E) [[ -e ${_ble_idle_status:1} ]] && _ble_idle_to_process=1 ;;
        (P) ! builtin kill -0 ${_ble_idle_status:1} &>/dev/null && _ble_idle_to_process=1 ;;
        (C) builtin eval -- "${_ble_idle_status:1}" && _ble_idle_to_process=1 ;;
        (Z) ;;
        (*) builtin unset -v '_ble_util_idle_task[_ble_idle_key]'
        esac

        if [[ $_ble_idle_to_process ]]; then
          local _ble_idle_command=${_ble_util_idle_task[_ble_idle_key]#*"$_ble_util_idle_SEP"}
          _ble_idle_processed=1
          ble/util/idle.do/.call-task "$_ble_idle_command"

          # Note: #D1450 Even if _ble_idle_command returns 148, idle.do is
          # I decided not to give up. Because the conditions are not necessarily the same as IS_IDLE.
          # ((ext==148)) && return 0

          ((_ble_idle_after_task++))
        elif [[ $_ble_idle_status == [FEPC]* ]]; then
          _ble_idle_waiting=1
        fi
      done

      _ble_idle_is_first=
      ble/util/idle.do/.sleep-until-next; local ext=$?
      ((ext==148)) && break

      [[ $_ble_idle_next_itime$_ble_idle_next_time$_ble_idle_running$_ble_idle_waiting ]] || break
    done

    [[ $_ble_idle_info_shown ]] &&
      ble/edit/info/immediate-default
    ble/util/idle.do/.do-after-task
    [[ $_ble_idle_processed ]]
  }
  ## @fn ble/util/idle.do/.do-after-task
  ##   @var[ref] _ble_idle_after_task
  function ble/util/idle.do/.do-after-task {
    if ((_ble_idle_after_task)); then
      # If there is a waiting time of 50ms or more, processing such as redrawing will be attempted.
      blehook/invoke idle_after_task
      _ble_idle_after_task=0
    fi
  }
  ## @fn ble/util/idle.do/.call-task command
  ##   @var[in,out] _ble_idle_next_time
  ##   @var[in,out] _ble_idle_next_itime
  ##   @var[in,out] _ble_idle_running
  ##   @var[in,out] _ble_idle_waiting
  function ble/util/idle.do/.call-task {
    local _ble_local_command=$1
    local ble_util_idle_status=
    local ble_util_idle_elapsed=$((_ble_util_idle_sclock-_ble_idle_sclock_start))
    if [[ $bleopt_debug_idle && ( $_ble_edit_info_scene == default || $_ble_idle_info_shown ) ]]; then
      _ble_idle_info_shown=1
      ble/edit/info/immediate-show text "${EPOCHREALTIME:+[$EPOCHREALTIME] }idle: $_ble_local_command"
    fi
    builtin eval -- "$_ble_local_command"; local ext=$?
    if ((ext==148)); then
      _ble_util_idle_task[_ble_idle_key]=R$_ble_util_idle_SEP$_ble_local_command
    elif [[ $ble_util_idle_status ]]; then
      _ble_util_idle_task[_ble_idle_key]=$ble_util_idle_status$_ble_util_idle_SEP$_ble_local_command
      if [[ $ble_util_idle_status == [WS]* ]]; then
        local scheduled_time=${ble_util_idle_status:1}
        if [[ $ble_util_idle_status == W* ]]; then
          local next=_ble_idle_next_itime
        else
          local next=_ble_idle_next_time
        fi
        if [[ ! ${!next} ]] || ((scheduled_time<next)); then
          builtin eval "$next=\$scheduled_time"
        fi
      elif [[ $ble_util_idle_status == R ]]; then
        _ble_idle_running=1
      elif [[ $ble_util_idle_status == [FEPC]* ]]; then
        _ble_idle_waiting=1
      fi
    else
      builtin unset -v '_ble_util_idle_task[_ble_idle_key]'
    fi
    return "$ext"
  }
  ## @fn ble/util/idle.do/.check-clock status
  ##   @var[in,out] _ble_idle_next_itime
  ##   @var[in,out] _ble_idle_next_time
  function ble/util/idle.do/.check-clock {
    local status=$1
    if [[ $status == W* ]]; then
      local next=_ble_idle_next_itime
      local current_time=$_ble_util_idle_sclock
    elif [[ $status == S* ]]; then
      local ret
      local next=_ble_idle_next_time
      ble/util/idle.clock; local current_time=$ret
    else
      return 1
    fi

    local scheduled_time=${status:1}
    if ((scheduled_time<=current_time)); then
      return 0
    elif [[ ! ${!next} ]] || ((scheduled_time<next)); then
      builtin eval "$next=\$scheduled_time"
    fi
    return 1
  }
  ## @fn ble/util/idle.do/.sleep-until-next
  ##   @var[in] _ble_idle_next_time
  ##   @var[in] _ble_idle_next_itime
  ##   @var[in] _ble_idle_running
  ##   @var[in] _ble_idle_waiting
  function ble/util/idle.do/.sleep-until-next {
    ble/util/idle/IS_IDLE || return 148
    [[ $_ble_idle_running ]] && return 0
    local isfirst=1
    while
      # If you are waiting for other conditions such as files, go back outside and check the status only once.
      [[ $_ble_idle_waiting && ! $isfirst ]] && break

      local sleep_amount=
      if [[ $_ble_idle_next_itime ]]; then
        local clock=$_ble_util_idle_sclock
        local sleep1=$((_ble_idle_next_itime-clock))
        if [[ ! $sleep_amount ]] || ((sleep1<sleep_amount)); then
          sleep_amount=$sleep1
        fi
      fi
      if [[ $_ble_idle_next_time ]]; then
        local ret; ble/util/idle.clock; local clock=$ret
        local sleep1=$((_ble_idle_next_time-clock))
        if [[ ! $sleep_amount ]] || ((sleep1<sleep_amount)); then
          sleep_amount=$sleep1
        fi
      fi
      [[ $_ble_idle_waiting ]] || ((sleep_amount>0))
    do
      # Note: The variable ble_util_idle_elapsed is
      #   Referenced when evaluating $((bleopt_idle_interval)).
      local ble_util_idle_elapsed=$((_ble_util_idle_sclock-_ble_idle_sclock_start))

      # Run idle_after_task if necessary if sleep_amount is long enough
      ((sleep_amount>50)) && ble/util/idle.do/.do-after-task

      local interval=$((bleopt_idle_interval))

      if [[ ! $sleep_amount ]] || ((interval<sleep_amount)); then
        sleep_amount=$interval
      fi
      ble/util/idle/.sleep "$sleep_amount"
      ble/util/idle/IS_IDLE || return 148
      isfirst=
    done
  }

  function ble/util/idle.push/.impl {
    local base=$1 entry=$2
    local i=$base
    while [[ ${_ble_util_idle_task[i]-} ]]; do ((i++)); done
    _ble_util_idle_task[i]=$entry
    _ble_util_idle_lasttask=$i
  }
  function ble/util/idle.push {
    local status=R nice=0
    while [[ $1 == -* ]]; do
      local sleep= isleep=
      case $1 in
      (-[SWPFEC]) status=${1:1}$2; shift 2 ;;
      (-[SWPFECIRZ]*) status=${1:1}; shift ;;
      (-n) nice=$2; shift 2 ;;
      (-n*) nice=${1#-n}; shift ;;
      (--sleep)    sleep=$2; shift 2 ;;
      (--sleep=*)  sleep=${1#*=}; shift ;;
      (--isleep)   isleep=$2; shift 2 ;;
      (--isleep=*) isleep=${1#*=}; shift ;;
      (*) break ;;
      esac

      if [[ $sleep ]]; then
        local ret
        ble/util/idle.clock/.initialize
        ble/util/idle.clock
        status=S$((ret+sleep))
        ble/util/is-running-in-idle &&
          ble/util/idle.do/.check-clock "$status"
      elif [[ $isleep ]]; then
        status=W$((_ble_util_idle_sclock+isleep))
        ble/util/is-running-in-idle &&
          ble/util/idle.do/.check-clock "$status"
      fi
    done
    ble/util/idle.push/.impl "$nice" "$status$_ble_util_idle_SEP$1"
  }
  function ble/util/idle.push-background {
    ble/util/idle.push -n 10000 "$@"
  }
  function ble/util/idle.cancel {
    local command=$1 i removed=
    for i in "${!_ble_util_idle_task[@]}"; do
      [[ ${_ble_util_idle_task[i]} == *"$_ble_util_idle_SEP$command" ]] &&
        builtin unset -v '_ble_util_idle_task[i]' &&
        removed=1
    done
    [[ $removed ]]
  }
  function ble/util/idle.clear {
    ((${#_ble_util_idle_task[@]})) || return 1
    _ble_util_idle_task=()
  }

  function ble/util/is-running-in-idle {
    [[ ${ble_util_idle_status+set} ]]
  }
  function ble/util/idle.suspend {
    [[ ${ble_util_idle_status+set} ]] || return 2
    ble_util_idle_status=Z
  }
  function ble/util/idle.sleep {
    [[ ${ble_util_idle_status+set} ]] || return 2
    local ret; ble/util/idle.clock
    ble_util_idle_status=S$((ret+$1))
  }
  function ble/util/idle.isleep {
    [[ ${ble_util_idle_status+set} ]] || return 2
    ble_util_idle_status=W$((_ble_util_idle_sclock+$1))
  }
  ## @fn ble/util/idle.sleep-until clock opts
  function ble/util/idle.sleep-until {
    [[ ${ble_util_idle_status+set} ]] || return 2
    if [[ :$2: == *:checked:* ]]; then
      local ret; ble/util/idle.clock
      (($1>ret)) || return 1
    fi
    ble_util_idle_status=S$1
  }
  ## @fn ble/util/idle.isleep-until sclock opts
  function ble/util/idle.isleep-until {
    [[ ${ble_util_idle_status+set} ]] || return 2
    if [[ :$2: == *:checked:* ]]; then
      (($1>_ble_util_idle_sclock)) || return 1
    fi
    ble_util_idle_status=W$1
  }
  function ble/util/idle.wait-user-input {
    [[ ${ble_util_idle_status+set} ]] || return 2
    ble_util_idle_status=I
  }
  function ble/util/idle.wait-process {
    [[ ${ble_util_idle_status+set} ]] || return 2
    ble_util_idle_status=P$1
  }
  function ble/util/idle.wait-file-content {
    [[ ${ble_util_idle_status+set} ]] || return 2
    ble_util_idle_status=F$1
  }
  function ble/util/idle.wait-filename {
    [[ ${ble_util_idle_status+set} ]] || return 2
    ble_util_idle_status=E$1
  }
  function ble/util/idle.wait-condition {
    [[ ${ble_util_idle_status+set} ]] || return 2
    ble_util_idle_status=C$1
  }
  function ble/util/idle.continue {
    [[ ${ble_util_idle_status+set} ]] || return 2
    ble_util_idle_status=R
  }

  function ble/util/idle/.declare-external-modifier {
    local name=$1
    builtin eval -- 'function ble/util/idle#'"$name"' {
      local index=$1
      [[ ${_ble_util_idle_task[index]+set} ]] || return 2
      local ble_util_idle_status=${_ble_util_idle_task[index]%%"$_ble_util_idle_SEP"*}
      local ble_util_idle_command=${_ble_util_idle_task[index]#*"$_ble_util_idle_SEP"}
      ble/util/idle.clock/.initialize
      ble/util/idle.'"$name"' "${@:2}"
      _ble_util_idle_task[index]=$ble_util_idle_status$_ble_util_idle_SEP$ble_util_idle_command
    }'
  }
  # @fn ble/util/idle#suspend
  # @fn ble/util/idle#sleep time
  # @fn ble/util/idle#isleep time
  ble/util/idle/.declare-external-modifier suspend
  ble/util/idle/.declare-external-modifier sleep
  ble/util/idle/.declare-external-modifier isleep

  ble/util/idle.push-background 'ble/util/msleep/calibrate'
else
  function ble/util/idle.do { return 1; }
fi

#------------------------------------------------------------------------------
# ble/util/fiberchain

_ble_util_fiberchain=()
_ble_util_fiberchain_prefix=
function ble/util/fiberchain#initialize {
  _ble_util_fiberchain=()
  _ble_util_fiberchain_prefix=$1
}
function ble/util/fiberchain#resume/.core {
  _ble_util_fiberchain=()
  local fib_clock=0
  local fib_ntask=$#
  while (($#)); do
    ((fib_ntask--))
    local fiber=${1%%:*} fib_suspend= fib_kill=
    local argv; ble/string#split-words argv "$fiber"
    [[ $1 == *:* ]] && fib_suspend=${1#*:}
    "$_ble_util_fiberchain_prefix/$argv.fib" "${argv[@]:1}"

    if [[ $fib_kill ]]; then
      break
    elif [[ $fib_suspend ]]; then
      _ble_util_fiberchain=("$fiber:$fib_suspend" "${@:2}")
      return 148
    fi
    shift
  done
}
function ble/util/fiberchain#resume {
  ble/util/fiberchain#resume/.core "${_ble_util_fiberchain[@]}"
}
## @fn ble/util/fiberchain#push fiber...
##   @param[in] fiber
##     You can specify more than one.
##     Each is a string of words separated by spaces.
##     Cannot contain colon ":".
##     Specify the fiber name name as the first word.
##     If there is an argument args..., specify it as the second and subsequent words.
##
##   @remarks
##     The actual fiber that will be executed will be the following command.
##     "$_ble_util_fiber_chain_prefix/$name.fib" "${args[@]}"
##
function ble/util/fiberchain#push {
  ble/array#push _ble_util_fiberchain "$@"
}
function ble/util/fiberchain#clear {
  _ble_util_fiberchain=()
}

#------------------------------------------------------------------------------
# **** terminal controls ****

bleopt/declare -v vbell_default_message ' Wuff, -- Wuff!! '
bleopt/declare -v vbell_duration 2000
bleopt/declare -n vbell_align right

function ble/term:cygwin/initialize.hook {
  # RI fix
  # Note: For some reason, RI (ESC M) is not displayed in Cygwin console.
  #   Implemented as a single line scroll up.
  #   On the other hand, you can scroll up with CUU (CSI A).
  printf '\eM\e[B' >&"$_ble_util_fd_tui_stderr"
  _ble_term_ri=$'\e[A'

  # Modification of DL
  function ble/canvas/put-dl.draw {
    local value=${1-1} i
    ((value)) || return 1

    # Note: When DL erases to the last line, nothing is erased...
    DRAW_BUFF[${#DRAW_BUFF[*]}]=$'\e[2K'
    if ((value>1)); then
      local ret
      ble/string#repeat $'\e[B\e[2K' "$((value-1))"; local a=$ret
      DRAW_BUFF[${#DRAW_BUFF[*]}]=$ret$'\e['$((value-1))'A'
    fi

    DRAW_BUFF[${#DRAW_BUFF[*]}]=${_ble_term_dl//'%d'/$value}
  }
}

function ble/term/DA2R.hook {
  blehook term_DA2R-=ble/term/DA2R.hook
  case $_ble_term_TERM in
  (contra:*)
    _ble_term_cuu=$'\e[%dk'
    _ble_term_cud=$'\e[%de'
    _ble_term_cuf=$'\e[%da'
    _ble_term_cub=$'\e[%dj'
    _ble_term_cup=$'\e[%l;%cf' ;;
  (cygwin:*)
    ble/term:cygwin/initialize.hook ;;
  esac
}
function ble/term/.initialize {
  if [[ -s $_ble_base_cache/term.$TERM && $_ble_base_cache/term.$TERM -nt $_ble_base/lib/@init/init-term.bash ]]; then
    source -- "$_ble_base_cache/term.$TERM"
  else
    source -- "$_ble_base/lib/@init/init-term.bash"
  fi

  ble/string#reserve-prototype "$_ble_term_it"
  blehook term_DA2R!=ble/term/DA2R.hook
}
ble/term/.initialize

function ble/term/put {
  BUFF[${#BUFF[@]}]=$1
}
function ble/term/cup {
  local x=$1 y=$2 esc=$_ble_term_cup
  esc=${esc//'%x'/$x}
  esc=${esc//'%y'/$y}
  esc=${esc//'%c'/$((x+1))}
  esc=${esc//'%l'/$((y+1))}
  BUFF[${#BUFF[@]}]=$esc
}
function ble/term/flush {
  IFS= builtin eval 'ble/util/put "${BUFF[*]}"'
  BUFF=()
}

# **** vbell/abell ****

function ble/term/audible-bell {
  ble/util/put '' >&2
}

# About managing visible-bell display.
#
# Use the worker subshell to delete the vbell display.
# Two files are used for the current display content and deletion.
#
#   workerfile=$_ble_base_run/$$.visible-bell.$i
#     One is allocated to one worker,
#     It is non-empty while the worker is alive.
#     The timestamp also represents the worker startup time.
#
#   _ble_term_visible_bell_ftime=$_ble_base_run/$$.visible-bell.time
#     Used to record the time when the display was last updated.
#
# The previous display contents are stored in the following array.
#
# @arr _ble_term_visible_bell_prev=(vbell_type message [x0 y0 x y])

_ble_term_visible_bell_prev=()
_ble_term_visible_bell_ftime=$_ble_base_run/$$.visible-bell.time

_ble_term_visible_bell_show='%message%'
_ble_term_visible_bell_clear=
function ble/term/visible-bell:term/init {
  if [[ ! $_ble_term_visible_bell_clear ]]; then
    local -a BUFF=()
    ble/term/put "$_ble_term_ri_or_cuu1$_ble_term_sc$_ble_term_sgr0"
    ble/term/cup 0 0
    ble/term/put "$_ble_term_el%message%$_ble_term_sgr0$_ble_term_rc${_ble_term_cud//'%d'/1}"
    IFS= builtin eval '_ble_term_visible_bell_show="${BUFF[*]}"'

    BUFF=()
    ble/term/put "$_ble_term_sc$_ble_term_sgr0"
    ble/term/cup 0 0
    ble/term/put "$_ble_term_el2$_ble_term_rc"
    IFS= builtin eval '_ble_term_visible_bell_clear="${BUFF[*]}"'
  fi

  # truncate to fit on one line
  local cols=${COLUMNS:-80}
  ((_ble_term_xenl||cols--))
  local message=${1::cols}
  _ble_term_visible_bell_prev=(term "$message")
}
function ble/term/visible-bell:term/show {
  local sgr=$1 message=${_ble_term_visible_bell_prev[1]}
  message=${_ble_term_visible_bell_show//'%message%'/"$sgr$message"}
  ble/util/put "$message" >&2
}
function ble/term/visible-bell:term/update {
  ble/term/visible-bell:term/show "$@"
}
function ble/term/visible-bell:term/clear {
  local sgr=$1
  ble/util/put "$_ble_term_visible_bell_clear" >&2
}

function ble/term/visible-bell:canvas/init {
  local message=$1

  local lines=1 cols=${COLUMNS:-80}
  ((_ble_term_xenl||cols--))
  local x= y=
  local ret sgr0= sgr1=
  ble/canvas/trace-text "$message" nonewline:external-sgr
  message=$ret

  local x0=$((COLUMNS-1-x)) y0=0
  ((x0<0)) && x0=0
  case :$bleopt_vbell_align: in
  (*:left:*) x0=0 ;;
  (*:center:*) ((x0/=2)) ;;
  esac

  _ble_term_visible_bell_prev=(canvas "$message" "$x0" "$y0" "$x" "$y")
}
function ble/term/visible-bell:canvas/show {
  local sgr=$1 opts=$2
  local message=${_ble_term_visible_bell_prev[1]}
  local x0=${_ble_term_visible_bell_prev[2]}
  local y0=${_ble_term_visible_bell_prev[3]}
  local x=${_ble_term_visible_bell_prev[4]}
  local y=${_ble_term_visible_bell_prev[5]}

  local -a DRAW_BUFF=()
  [[ :$opts: != *:update:* && $_ble_attached ]] && # WA #D1495
    [[ $_ble_term_ri || :$opts: != *:erased:* && :$opts: != *:update:* ]] &&
    ble/canvas/panel/ensure-tmargin.draw
  if [[ $_ble_term_rc ]]; then
    local ret=
    [[ :$opts: != *:update:* && $_ble_attached ]] && ble/canvas/panel/save-position goto-top-dock # WA #D1495
    ble/canvas/put.draw "$_ble_term_ri_or_cuu1$_ble_term_sc$_ble_term_sgr0"
    ble/canvas/put-cup.draw "$((y0+1))" "$((x0+1))"
    ble/canvas/put.draw "$sgr$message$_ble_term_sgr0"
    ble/canvas/put.draw "$_ble_term_rc"
    ble/canvas/put-cud.draw 1
    [[ :$opts: != *:update:* && $_ble_attached ]] && ble/canvas/panel/load-position.draw "$ret" # WA #D1495
  else
    ble/canvas/put.draw "$_ble_term_ri_or_cuu1$_ble_term_sgr0"
    ble/canvas/put-hpa.draw "$((1+x0))"
    ble/canvas/put.draw "$sgr$message$_ble_term_sgr0"
    ble/canvas/put-cud.draw 1
    ble/canvas/put-hpa.draw "$((1+_ble_canvas_x))"
  fi
  ble/canvas/bflush.draw
  ble/util/buffer.flush
}
function ble/term/visible-bell:canvas/update {
  ble/term/visible-bell:canvas/show "$@"
}
function ble/term/visible-bell:canvas/clear {
  local sgr=$1
  local x0=${_ble_term_visible_bell_prev[2]}
  local y0=${_ble_term_visible_bell_prev[3]}
  local x=${_ble_term_visible_bell_prev[4]}
  local y=${_ble_term_visible_bell_prev[5]}

  local -a DRAW_BUFF=()
  if [[ $_ble_term_rc ]]; then
    local ret=
    #[[ $_ble_attached ]] && ble/canvas/panel/save-position goto-top-dock # WA #D1495
    ble/canvas/put.draw "$_ble_term_sc$_ble_term_sgr0"
    ble/canvas/put-cup.draw "$((y0+1))" "$((x0+1))"
    ble/canvas/put.draw "$sgr"
    ble/canvas/put-spaces.draw "$x"
    #ble/canvas/put-ech.draw "$x"
    #ble/canvas/put.draw "$_ble_term_el"
    ble/canvas/put.draw "$_ble_term_sgr0$_ble_term_rc"
    #[[ $_ble_attached ]] && ble/canvas/panel/load-position.draw "$ret" # WA #D1495
  else
    : # Coordinates are shifted because _ble_canvas_x of the parent process is not known
    # ble/util/buffer.flush
    # ble/canvas/put.draw "$_ble_term_ri_or_cuu1$_ble_term_sgr0"
    # ble/canvas/put-hpa.draw "$((1+x0))"
    # ble/canvas/put.draw "$sgr"
    # ble/canvas/put-spaces.draw "$x"
    # ble/canvas/put.draw "$_ble_term_sgr0"
    # ble/canvas/put-cud.draw 1
    # ble/canvas/put-hpa.draw "$((1+_ble_canvas_x))" # _ble_canvas_x of parent process?
  fi
  ble/canvas/flush.draw >&2
}

function ble/term/visible-bell/defface.hook {
  ble/color/defface vbell       reverse
  ble/color/defface vbell_flash reverse,fg=green
  ble/color/defface vbell_erase bg=252
}
blehook color_defface_load+=ble/term/visible-bell/defface.hook

function ble/term/visible-bell/.show {
  local bell_type=${_ble_term_visible_bell_prev[0]}
  ble/term/visible-bell:"$bell_type"/show "$@"
}
function ble/term/visible-bell/.update {
  local bell_type=${_ble_term_visible_bell_prev[0]}
  ble/term/visible-bell:"$bell_type"/update "$1" "$2:update"
}
function ble/term/visible-bell/.clear {
  local bell_type=${_ble_term_visible_bell_prev[0]}
  ble/term/visible-bell:"$bell_type"/clear "$@"
  >| "$_ble_term_visible_bell_ftime"
}

## @fn ble/term/visible-bell/.erase-previous-visible-bell
##   @var[in] _ble_term_visible_bell_prev
##   @var[in] sgr0
function ble/term/visible-bell/.erase-previous-visible-bell {
  local ret workers
  ble/util/eval-pathname-expansion '"$_ble_base_run/$$.visible-bell."*' canonical
  workers=("${ret[@]}")

  local workerfile
  for workerfile in "${workers[@]}"; do
    if [[ -s $workerfile && ! ( $workerfile -ot $_ble_term_visible_bell_ftime ) ]]; then
      ble/term/visible-bell/.clear "$sgr0"
      return 0
    fi
  done
  return 1
}

function ble/term/visible-bell/.create-workerfile {
  local i=0
  while
    workerfile=$_ble_base_run/$$.visible-bell.$i
    [[ -s $workerfile ]]
  do ((i++)); done
  ble/util/print 1 >| "$workerfile"
}
## @fn ble/term/visible-bell/.worker
##   @var[in] workerfile
function ble/term/visible-bell/.worker {
  # Note: ble/util/assign cannot be used. There may be a conflict between the main unit's ble/util/assign and the temporary file.
  ble/util/msleep 50
  [[ $workerfile -ot $_ble_term_visible_bell_ftime ]] && return 0 >| "$workerfile"
  ble/term/visible-bell/.update "$sgr2"

  if [[ :$opts: == *:persistent:* ]]; then
    local dead_workerfile=$_ble_base_run/$$.visible-bell.Z
    ble/util/print 1 >| "$dead_workerfile"
    return 0 >| "$workerfile"
  fi

  # load time duration settings
  local msec=$((bleopt_vbell_duration))

  # wait
  ble/util/msleep "$msec"
  [[ $workerfile -ot $_ble_term_visible_bell_ftime ]] && return 0 >| "$workerfile"

  # check and clear
  ble/term/visible-bell/.clear "$sgr0"

  >| "$workerfile"
}

## @fn ble/term/visible-bell message [opts]
function ble/term/visible-bell {
  local message=$1 opts=$2
  message=${message:-$bleopt_vbell_default_message}

  # Note: It will not be displayed if there is only one line. When the line is 0, everything goes to the log, so it is output. empty sentence
  # If it is a string, it is displayed because it is just not set.
  ((LINES==1)) && return 0

  [[ :$bleopt_vbell_align: == *:panel:* ]] &&
    ble/function#try ble/edit/visible-bell "$message" "$opts" &&
    return 0

  local sgr0=$_ble_term_sgr0
  local sgr1=${_ble_term_setaf[2]}$_ble_term_rev
  local sgr2=$_ble_term_rev
  if ble/is-function ble/color/face2sgr; then
    local ret
    ble/color/face2sgr vbell_flash; sgr1=$ret
    ble/color/face2sgr vbell; sgr2=$ret
    ble/color/face2sgr vbell_erase; sgr0=$ret
  fi

  local show_opts=
  ble/term/visible-bell/.erase-previous-visible-bell && show_opts=erased

  if ble/is-function ble/canvas/trace-text; then
    ble/term/visible-bell:canvas/init "$message"
  else
    ble/term/visible-bell:term/init "$message"
  fi
  ble/term/visible-bell/.show "$sgr1" "$show_opts"

  local workerfile; ble/term/visible-bell/.create-workerfile
  # Note: By specifying ble/util/joblist/__suppress__,
  #   Prevent it from appearing in the list of finished jobs.
  #   If no measures are taken, a list of jobs will be displayed in the replacement implementation of read.
  # Note: If you don't close the standard output, inside $()
  #   visible-bell worker blocks when calling read.
  # ref #D1000, #D1087
  ( ble/util/joblist/__suppress__; ble/term/visible-bell/.worker 1>/dev/null & )
}
function ble/term/visible-bell/cancel-erasure {
  >| "$_ble_term_visible_bell_ftime"
}
function ble/term/visible-bell/erase {
  local sgr0=$_ble_term_sgr0
  if ble/is-function ble/color/face2sgr; then
    local ret
    ble/color/face2sgr vbell_erase; sgr0=$ret
  fi
  ble/term/visible-bell/.erase-previous-visible-bell
}

#---- stty --------------------------------------------------------------------

# Regarding handling of line breaks (C-m, C-j)
#   -icrnl must be specified to prevent the input C-m from being converted to C-j automatically.
#   (Since icrnl is included in the -nl setting, this must be canceled.)
#   On the other hand, we want the output LF to be converted to CR LF, so onlcr is retained.
#   (This is included in the -nl setting)
#
# -About icanon
#   There is a program to configure stty icanon. Setting this will buffer the input.
#   It is not possible to receive input on the spot. As a result, it looks like it is hung.
#   Therefore, we will set -icanon on enter.

[[ ${_ble_term_stty_save+set} ]] || _ble_term_stty_save=
bleopt/declare -v term_stty_restore ''
function bleopt/check:term_stty_restore {
  if [[ $value && ! $_ble_term_stty_save ]]; then
    ble/util/assign _ble_term_stty_save 'ble/bin/stty -g'
  fi
  return 0
}

## @var _ble_term_stty_state
##   This variable retains the current stty state, such as whether effects of
##   special control characters are turned off.  When ble.sh has not modified
##   the stty state, the variable is empty, "".  When ble.sh has modified the
##   stty for the internal state, the variable is set to "1".  When ble.sh has
##   modified the stty for the external state, the variable is set to "0".
##
## Note #D1238: When using the arr=(...) format, ^? automatically turns into ^A^? in Bash 3.2.
##   Since there is no other choice, we will use ble/array#push to initialize the following array.
_ble_term_stty_state=
_ble_term_stty_flags_enter=()
_ble_term_stty_flags_leave=()
ble/array#push _ble_term_stty_flags_enter intr undef quit undef susp undef
ble/array#push _ble_term_stty_flags_leave intr '' quit '' susp ''
function ble/term/stty/.initialize-flags {
  # # ^U, ^V, ^W, ^?
  # # Note: lnext and werase are not in POSIX, so they exist in stty items
  # # Check.
  # # Note (#D1683): ble/decode/readline/adjust-uvw is the correct solution. The following pairs
  # # The effectiveness of the measures is unknown. Rather, there are problems such as ^? not working inside vim :term.
  # # Disable it for now as it seems to cause problems.
  # ble/array#push _ble_term_stty_flags_enter kill undef erase undef
  # ble/array#push _ble_term_stty_flags_leave kill '' erase ''
  # local stty; ble/util/assign stty 'stty -a'
  # if [[ $stty == *' lnext '* ]]; then
  #   ble/array#push _ble_term_stty_flags_enter lnext undef
  #   ble/array#push _ble_term_stty_flags_leave lnext ''
  # fi
  # if [[ $stty == *' werase '* ]]; then
  #   ble/array#push _ble_term_stty_flags_enter werase undef
  #   ble/array#push _ble_term_stty_flags_leave werase ''
  # fi

  if [[ $TERM == minix ]]; then
    local stty; ble/util/assign stty 'stty -a'
    if [[ $stty == *' rprnt '* ]]; then
      ble/array#push _ble_term_stty_flags_enter rprnt undef
      ble/array#push _ble_term_stty_flags_leave rprnt ''
    elif [[ $stty == *' reprint '* ]]; then
      ble/array#push _ble_term_stty_flags_enter reprint undef
      ble/array#push _ble_term_stty_flags_leave reprint ''
    fi
  fi
}
ble/term/stty/.initialize-flags

function ble/term/stty/initialize {
  if [[ $bleopt_term_stty_restore ]]; then
    [[ $_ble_term_stty_save ]] ||
      ble/util/assign _ble_term_stty_save 'ble/bin/stty -g'
  fi
  ble/bin/stty -ixon -echo -nl -icrnl -icanon \
               "${_ble_term_stty_flags_enter[@]}"
  _ble_term_stty_state=1
}
function ble/term/stty/leave {
  ((_ble_term_stty_state)) || return 0
  _ble_term_stty_state=0
  if [[ $bleopt_term_stty_restore && $_ble_term_stty_save ]]; then
    ble/bin/stty "$_ble_term_stty_save"
  else
    ble/bin/stty echo -nl icanon "${_ble_term_stty_flags_leave[@]}"
  fi
}
function ble/term/stty/enter {
  # Note (#D2184): This function is overwritten later in Bash 5.2 to work
  # around the problem that "checkwinsize" does not work in "bind -x" in Bash
  # 5.2.  The changes to this function needs to be also reflected in the later
  # overwriting version of "ble/term/stty/enter".
  ((_ble_term_stty_state)) && return 0
  if [[ $bleopt_term_stty_restore ]]; then
    ble/term/stty/initialize
  else
    ble/bin/stty -echo -nl -icrnl -icanon "${_ble_term_stty_flags_enter[@]}"
    _ble_term_stty_state=1
  fi
}
function ble/term/stty/finalize {
  ble/term/stty/leave
  _ble_term_stty_save=
}
function ble/term/stty/TRAPEXIT {
  if [[ ! $_ble_term_stty_state ]]; then
    # Note: The empty "_ble_term_stty_state" means that the stty state has
    # never been touched by ble.sh, so we do nothing in that case.
    return 0
  fi

  # echo for exit
  if [[ $bleopt_term_stty_restore && $_ble_term_stty_save ]]; then
    ble/bin/stty "$_ble_term_stty_save"
  else
    ble/bin/stty echo -nl "${_ble_term_stty_flags_leave[@]}"
  fi
  _ble_term_stty_state=0
}

function ble/term/update-winsize {
  # (0) Implemented by checkwinsize (2167.054 usec/eval)
  if ((_ble_bash<50200||50300<=_ble_bash)); then
    function ble/term/update-winsize {
      if shopt -q checkwinsize; then
        (:)
      else
        shopt -s checkwinsize
        (:)
        shopt -u checkwinsize
      fi 2>&"$_ble_util_fd_tui_stderr"
    }
    ble/term/update-winsize
    return 0
  fi

  local ret

  # (a) Implementation with "tput lines cols" or "tput li co" (2909.052 usec/eval)
  if ble/bin#freeze-utility-path tput; then
    if ble/util/assign-words ret 'ble/bin/tput lines cols' 2>/dev/null &&
        [[ ${#ret[@]} -eq 2 && ${ret[0]} =~ ^[0-9]+$ && ${ret[1]} =~ ^[0-9]+$ ]]
    then
      LINES=${ret[0]} COLUMNS=${ret[1]}
      function ble/term/update-winsize {
        local -x ret LINES= COLUMNS=
        ble/util/assign-words ret 'ble/bin/tput lines cols' 2>/dev/null
        ble/util/unlocal LINES COLUMNS
        [[ ${ret[0]} ]] && LINES=${ret[0]}
        [[ ${ret[1]} ]] && COLUMNS=${ret[1]}
      }
      return 0
    elif ble/util/assign-words ret 'ble/bin/tput li co' 2>/dev/null &&
        [[ ${#ret[@]} -eq 2 && ${ret[0]} =~ ^[0-9]+$ && ${ret[1]} =~ ^[0-9]+$ ]]
    then
      LINES=${ret[0]} COLUMNS=${ret[1]}
      function ble/term/update-winsize {
        local -x ret LINES= COLUMNS=
        ble/util/assign-words ret 'ble/bin/tput li co' 2>/dev/null
        ble/util/unlocal LINES COLUMNS
        [[ ${ret[0]} ]] && LINES=${ret[0]}
        [[ ${ret[1]} ]] && COLUMNS=${ret[1]}
      }
      return 0
    fi
  fi

  # (b) Implementation with "stty size" (2976.172 usec/eval)
  if ble/util/assign-words ret 'ble/bin/stty size' 2>/dev/null &&
      [[ ${#ret[@]} -eq 2 && ${ret[0]} =~ ^[0-9]+$ && ${ret[1]} =~ ^[0-9]+$ ]]
  then
    LINES=${ret[0]} COLUMNS=${ret[1]}
    function ble/term/update-winsize {
      local ret
      ble/util/assign-words ret 'ble/bin/stty size' 2>/dev/null
      [[ ${ret[0]} ]] && LINES=${ret[0]}
      [[ ${ret[1]} ]] && COLUMNS=${ret[1]}
    }
    return 0
  fi

  # (c) Implementation using "resize" (3108.696 usec/eval)
  if ble/bin#freeze-utility-path resize &&
      ble/util/assign ret 'ble/bin/resize' &&
      ble/string#match "$ret" 'COLUMNS=([0-9]+).*LINES=([0-9]+)'
  then
    LINES=${BASH_REMATCH[2]} COLUMNS=${BASH_REMATCH[1]}
    function ble/term/update-winsize {
      local ret
      ble/util/assign ret 'ble/bin/resize' 2>/dev/null
      ble/string#match ret 'COLUMNS=([0-9]+).*LINES=([0-9]+)'
      [[ ${BASH_REMATCH[2]} ]] && LINES=${BASH_REMATCH[2]}
      [[ ${BASH_REMATCH[1]} ]] && COLUMNS=${BASH_REMATCH[1]}
    }
    return 0
  fi

  # (d) Implementation with "bash -O checkwinsize -c ..." (bash-4.3 and above) (9094.595 usec/eval)
  function ble/term/update-winsize {
    local ret script='LINES= COLUMNS=; (:); [[ $COLUMNS && $LINES ]] && builtin echo "$LINES $COLUMNS"'
    ble/util/assign-words ret '"$BASH" -O checkwinsize -c "$script"' 2>&"$_ble_util_fd_tui_stderr"
    [[ ${ret[0]} ]] && LINES=${ret[0]}
    [[ ${ret[1]} ]] && COLUMNS=${ret[1]}
  }
  ble/term/update-winsize
  return 0
}

# In bash-5.2, checkwinsize does not work inside "bind -x", so
# Obtain the terminal size yourself in ble/term/stty/enter and update LINES COLUMNS.
# Ru.
if ((50200<=_ble_bash&&_ble_bash<50300)); then
  ## @fn ble/term/update-winsize/.stty-enter.advice
  ##   Adjust the ble/term/stty/enter implementation using "stty size".
  ##
  ##   'stty "${enter_options[@]}" on first ble/term/stty/enter call
  ##   Check if 'size' works, and if it seems to work, add size to stty and call it from now on.
  ##   Then, reset LINES and COLUMNS based on that.
  ##
  ##   The test itself changes stty settings, so the first call to ble/term/stty/enter
  ##   We plan to carry out adjustments, including tests, at the time of launch.
  function ble/term/update-winsize/.stty-enter.advice {
    local ret stderr test_command='ble/bin/stty -echo -nl -icrnl -icanon "${_ble_term_stty_flags_enter[@]}" size'
    if ble/util/assign stderr 'ble/util/assign-words ret "$test_command" 2>&1' &&
        [[ ! $stderr ]] &&
        ((${#ret[@]}==2)) &&
        [[ ${ret[0]} =~ ^[0-9]+$ && ${ret[1]} =~ ^[0-9]+$ ]]
    then
      LINES=${ret[0]} COLUMNS=${ret[1]}
      function ble/term/stty/enter {
        ((_ble_term_stty_state)) && return 0
        local ret
        if [[ $bleopt_term_stty_restore ]]; then
          ble/term/stty/initialize
          ble/util/assign-words ret 'ble/bin/stty size'
        else
          ble/util/assign-words ret 'ble/bin/stty -echo -nl -icrnl -icanon "${_ble_term_stty_flags_enter[@]}" size'
          _ble_term_stty_state=1
        fi
        [[ ${ret[0]} =~ ^[0-9]+$ ]] && LINES=${ret[0]}
        [[ ${ret[1]} =~ ^[0-9]+$ ]] && COLUMNS=${ret[1]}
      }
    else
      ble/term/update-winsize
      ble/function#advice before ble/term/stty/enter ble/term/update-winsize
    fi
    builtin unset -f "$FUNCNAME"
  }
  ble/function#advice before ble/term/stty/enter ble/term/update-winsize/.stty-enter.advice
fi


#---- cursor state ------------------------------------------------------------

bleopt/declare -v term_cursor_external 0

_ble_term_cursor_current=unknown
_ble_term_cursor_internal=0
_ble_term_cursor_hidden_current=unknown
_ble_term_cursor_hidden_internal=reveal

# #D1516 What happens when the cursor has not been changed and you are trying to return it to the default value?
# Since there is no such thing, we will set it to 0 from the beginning. DECSCUSR(0) in xterm.js
#   is not the user's default value. External command restores cursor shape
#   It is assumed that you will.
# #D1873 If you simply specify 0, the cursor is not set by the user.
#   However, when I use term/enter after executing the command, unknown is eventually set.
#   DECSCUSR(0) is sent and becomes a problem. I have never changed it as ble.sh.
#   I decided to introduce something called default as a value to indicate that it is not.
#   When set to default, clearing is not performed on term/enter.
_ble_term_cursor_current=default

function ble/term/cursor-state/.update {
  local state=$(($1))
  [[ ${_ble_term_cursor_current/default/0} == "$state" ]] && return 0

  if [[ ! $_ble_term_Ss ]]; then
    case $_ble_term_TERM in
    (mintty:*|xterm:*|RLogin:*|kitty:*|screen:*|tmux:*|contra:*|cygwin:*|wezterm:*|wt:*)
      local _ble_term_Ss=$'\e[@1 q' ;;
    esac
  fi
  local ret=${_ble_term_Ss//@1/"$state"}
  if [[ $ret ]]; then
    # Note: Skip if pass-through seq is already included.
    [[ $ret != $'\eP'*$'\e\\' ]] &&
      ble/term/quote-passthrough "$ret" '' all

    ble/util/buffer "$ret"
  fi

  _ble_term_cursor_current=$state
}
function ble/term/cursor-state/set-internal {
  _ble_term_cursor_internal=$1
  [[ $_ble_term_state == internal ]] &&
    ble/term/cursor-state/.update "$1"
}

function ble/term/cursor-state/.update-hidden {
  local state=$1
  [[ $state != hidden ]] && state=reveal

  # Note: the actual sequence is added by ble/util/buffer.flush.
  _ble_term_cursor_hidden_current=$state
}
function ble/term/cursor-state/hide {
  _ble_term_cursor_hidden_internal=hidden
  [[ $_ble_term_state == internal ]] &&
    ble/term/cursor-state/.update-hidden hidden
}
function ble/term/cursor-state/reveal {
  _ble_term_cursor_hidden_internal=reveal
  [[ $_ble_term_state == internal ]] &&
    ble/term/cursor-state/.update-hidden reveal
}

#---- DECSET(2004): bracketed paste mode --------------------------------------

function ble/term/bracketed-paste-mode/.init {
  local _ble_local_rlvars; ble/util/rlvar#load

  bleopt/declare -v term_bracketed_paste_mode on
  if ((_ble_bash>=50100)) && ! ble/util/rlvar#test enable-bracketed-paste; then
    # Since Bash 5.1, it is on by default, so if it is disabled, the user intentionally
    # That means it's turned off.
    bleopt term_bracketed_paste_mode=
  elif [[ ${TERM%%-*} == eterm ]]; then
    # Note (#D2087): eterm (Emacs 28.2) sends bracketed paste in eterm
    # Then, the end judgment seems to be broken. However, disabling this on the shell side also solves the problem.
    # I don't. This seems to be a problem with bracketed paste processing set by Emacs itself.
    bleopt term_bracketed_paste_mode=
  fi
  function bleopt/check:term_bracketed_paste_mode {
    if [[ $_ble_term_bracketedPasteMode_internal ]]; then
      if [[ $value ]]; then
        [[ $bleopt_term_bracketed_paste_mode ]] || ble/util/buffer $'\e[?2004h'
      else
        [[ ! $bleopt_term_bracketed_paste_mode ]] || ble/util/buffer $'\e[?2004l'
      fi
    fi
  }
  ble/util/rlvar#bind-bleopt enable-bracketed-paste term_bracketed_paste_mode bool

  builtin unset -f "$FUNCNAME"
}
ble/term/bracketed-paste-mode/.init

_ble_term_bracketedPasteMode_internal=
function ble/term/bracketed-paste-mode/enter {
  _ble_term_bracketedPasteMode_internal=1
  [[ ${bleopt_term_bracketed_paste_mode-} ]] &&
    ble/util/buffer $'\e[?2004h'
}
function ble/term/bracketed-paste-mode/leave {
  _ble_term_bracketedPasteMode_internal=
  [[ ${bleopt_term_bracketed_paste_mode-} ]] &&
    ble/util/buffer $'\e[?2004l'
}
if [[ $TERM == minix ]]; then
  # Minix console cannot use DECSET either.
  function ble/term/bracketed-paste-mode/enter { return 0; }
  function ble/term/bracketed-paste-mode/leave { return 0; }
fi

#---- DECSET(2026): synchronized update ---------------------------------------

bleopt/declare -v term_synchronized_update_mode auto
function ble/term/synchronized-update-mode/resolve-auto {
  [[ $bleopt_term_synchronized_update_mode == auto ]] || return 0

  case $_ble_term_TERM in
  (mintty:*|foot:*|wezterm:*|iTerm2:*|kitty:*|alacritty:*|zellij:*)
    bleopt_term_synchronized_update_mode=on ;;
  (*)
    bleopt_term_synchronized_update_mode= ;;
  esac
}

#---- DA2 ---------------------------------------------------------------------

_ble_term_TERM=()
_ble_term_DA1R=()
_ble_term_DA2R=()
_ble_term_TERM_done=

function ble/term/DA2/request {
  case $TERM in
  (linux)
    # Note #D1213: Linux console (kernel 5.0.0) is "\e[>"
    #  will close the escape sequence. 5.4.8 is fine.
    _ble_term_TERM=linux:- ;;
  (st|st-*)
    # Some people complained about st's unknown csi sequence message.
    # Since st can be determined using TERM, DA2 can be skipped.
    _ble_term_TERM=st:- ;;
  (*)
    ble/util/buffer $'\e[>c' # DA2 request (received in ble/decode/csi/.decode)
  esac
}

## @fn ble/term/DA2/initialize-term [depth]
##   @var[out] _ble_term_TERM
function ble/term/DA2/initialize-term {
  local depth=$1
  local da2r=${_ble_term_DA2R[depth]}
  local rex='^[0-9]*(;[0-9]*)*$'; [[ $da2r =~ $rex ]] || return 1
  local da2r_vec
  ble/string#split da2r_vec ';' "$da2r"
  da2r_vec=("${da2r_vec[@]/#/10#0}") # Interpret as decimal even if it starts with 0; WA #D1570 checked (is-array)

  case $da2r in
  # Note #D1946: Terminology is indistinguishable from xterm, but it seems to be fixed, so
  # Considering that it is unlikely that you are using the corresponding version of xterm, I decided to
  # I will judge it as terminology.
  ('0;271;0')  _ble_term_TERM[depth]=terminology:200 ;;   # 2012-10-05 https://github.com/borisfaure/terminology/commit/500e7be8b2b876462ed567ef6c90527f37482adb
  ('41;285;0') _ble_term_TERM[depth]=terminology:300 ;;   # 2013-01-22 https://github.com/borisfaure/terminology/commit/526cc2aeacc0ae54825cbc3a3e2ab64f612f83c9
  ('61;337;0') _ble_term_TERM[depth]=terminology:10400 ;; # 2019-01-20 https://github.com/borisfaure/terminology/commit/96bbfd054b271f7ad7f31e699b13c12cb8fbb2e2

  # Note #D1909: wezterm has changed DA2 on 2022-04-07. Distinguished from xterm-277
  # Although it is not marked, there is a possibility that you are using the corresponding xterm version (2012-01-08).
  # Seeing that it is low, I decided to use wezterm for now. More mlterm-3.4.2..3.7.1
  # (201412..201608) also used 1;277;0.
  ('0;0;0') _ble_term_TERM[depth]=wezterm:0 ;;
  ('1;277;0') _ble_term_TERM[depth]=wezterm:20220408 ;; # 2022-04-07 https://github.com/wez/wezterm/commit/ad91e3776808507cbef9e6d758b89d7ca92a4c7e

  # Konsole is also pretty much set in stone. Looks like it was changed recently.
  ('0;115;0') _ble_term_TERM[depth]=konsole:30000  ;; # 2001-09-16 https://github.com/KDE/konsole/commit/2d93fed82aa27e89c9d7301d09d2e24e4fa4416d
  ('1;115;0') _ble_term_TERM[depth]=konsole:220380 ;; # 2022-02-24 https://github.com/KDE/konsole/commit/0cc64dcf7b90075bd17e46653df3069208d6a590

  # mlterm (#D1999)
  # - 0;96;0   v3.1.0 (2012-03-24) https://github.com/arakiken/mlterm/commit/6ca37d7f99337194d8c893cc48285c0614762535
  # * 1;96;0   v3.1.2 (2012-05-20) https://github.com/arakiken/mlterm/commit/6293d0af9cf1e78fd6c35620824b62ff6c87370b
  # * 1;277;0  v3.4.2 (2014-12-27) https://github.com/arakiken/mlterm/commit/c4fb36291ec67daf73c48c5b60d1af88ad0487e6
  # - 1;279;0  v3.7.2 (2016-08-06) https://github.com/arakiken/mlterm/commit/24a2a4886b70f747fba4ea7c07d6e50a6a49039d
  # * 24;279;0 v3.7.2 (2016-08-11) https://github.com/arakiken/mlterm/commit/d094f0f4a31224e1b8d2fa15c6ab37bd1c4c4713
  ('1;96;0')   _ble_term_TERM[depth]=mlterm:30102 ;;
  ('1;277;0')  _ble_term_TERM[depth]=mlterm:30402 ;; # Note: Same as wezterm:20220408. Prefer wezterm
  ('24;279;0') _ble_term_TERM[depth]=mlterm:30702 ;;

  # iTerm2
  # * 0;95;     v1.0.0.20110724 (2010-08-07) https://github.com/gnachman/iTerm2/commit/732e2016a488f9e06a88cd2ab3925436e437864e
  # - 0:95      v2.9.20151111   (2015-02-24) https://github.com/gnachman/iTerm2/commit/e5b7db007c9340b93607096f64f4895fe4cef544
  # * 0;95;0    v2.9.20151111   (2015-03-02) https://github.com/gnachman/iTerm2/commit/5a613a9c1bf7ddd0fea34135a391fd3fa7c53585
  # - 0;95;0    v3.3.0beta1     (2018-10-10) https://github.com/gnachman/iTerm2/commit/b3058e6806c22f345329923a15394502e2b4a251 (LC_TERMINAL_VERSION)
  # - 1;95;0    v3.5.0beta1     (2021-08-14) https://github.com/gnachman/iTerm2/commit/6c923fab1e78147b00a5867aa7e20617739608db
  # - 41;95;0   v3.5.0beta3     (2021-10-13) https://github.com/gnachman/iTerm2/commit/05dd985955736e222b4144c45dc7e33cafd76948
  # * 41;2500;0 v3.5.0beta3     (2021-10-13) https://github.com/gnachman/iTerm2/commit/2fef388179057cf0090d536350ed644c7d4499d7
  # * 64;2500;0 v3.5.5beta1     (2024-07-28) https://github.com/gnachman/iTerm2/commit/cd9445d59c667cbae57987f1de0100e0a031d666
  ('0;95;0')    _ble_term_TERM[depth]=iTerm2:${LC_TERMINAL_VERSION-2.9+} ;;
  ('41;2500;0') _ble_term_TERM[depth]=iTerm2:${LC_TERMINAL_VERSION-3.5.0+} ;;
  ('64;2500;0') _ble_term_TERM[depth]=iTerm2:${LC_TERMINAL_VERSION-3.5.6+} ;;

  ('0;10;1') # Windows Terminal
    # Currently it is hardcoded.
    # https://github.com/microsoft/terminal/blob/bcc38d04/src/terminal/adapter/adaptDispatch.cpp#L779-L782
    _ble_term_TERM[depth]=wt:0 ;;
  ('0;'*';1')
    if ((da2r_vec[1]>=3000)); then
      # Zellij seems to use the same range as Alacritty with the same scheme,
      # which makes it essentially difficult to differentiate it from
      # Alacritty.  Zellij has introduce DA2 in PR [1], whose primary purpose
      # was cursor position, etc.  The design of its DA2 was not specifically
      # discussed/mentioned.  The first release with the support for DA2 report
      # was 0.10.0 [2], so the minimum value by Zellij would be 1000, which
      # clearly conflicts with the recent versions of Alacritty.  We currently
      # use 3000 to distinguish Zellij and Alacritty, but this value needs to
      # be updated before Alacritty's version reaches v0.30.0.
      #
      # [1] https://github.com/zellij-org/zellij/pull/500 (2021-05-13)
      # [2] https://github.com/zellij-org/zellij/releases/tag/v0.10.0
      _ble_term_TERM[depth]=zellij:$((da2r_vec[1]))
    elif ((da2r_vec[1]>=1001)); then
      # Alacritty
      # https://github.com/alacritty/alacritty/blob/4734b2b8/alacritty_terminal/src/term/mod.rs#L1315
      # https://github.com/alacritty/alacritty/blob/4734b2b8/alacritty_terminal/src/term/mod.rs#L3104
      _ble_term_TERM[depth]=alacritty:$((da2r_vec[1]))
    fi ;;
  ('1;0'?????';0')
    _ble_term_TERM[depth]=foot:${da2r:3:5} ;;
  ('1;'*)
    if ((4000<=da2r_vec[1]&&da2r_vec[1]<=4009&&3<=da2r_vec[2])); then
      _ble_term_TERM[depth]=kitty:$((da2r_vec[1]-4000))
    elif ((803<=da2r_vec[1]&&da2r_vec[1]<5400&&da2r_vec[2]==0)); then
      local version=$((da2r_vec[1]))
      _ble_term_TERM[depth]=vte:$version
      if ((version<4000)); then
        # Note #D1785: DECSCUSR is not supported in vte below 0.40.0. Further unknown sequence
        # It is also impossible to ignore the impact. Nevertheless, VTE-based terminals
        # Since TERM=xterm is set, DECSCUSR will be output and the display will be distorted.
        # Check the vte version and force DECSCUSR off.
        _ble_term_Ss=
      fi
    fi ;;
  ('61;'*)
    # VTE
    # "1;ver;0"  0.8.3-1 <= VTE <= 0.53.0 (2002-08-22) https://gitlab.gnome.org/GNOME/vte/-/commit/3c6d81bf06becda3f9ab005c7310b2343588115e#24cb0c42588db6a1cc9a132b1257c457b6b09ca6_3382_3449
    # "65;ver;1" 0.53.0  <= VTE <= 0.75.1 (2018-03-27) https://gitlab.gnome.org/GNOME/vte/-/commit/fde88ef7f9226a0849ca62663bc1eaa9862178b8
    # "61;ver;1" 0.75.1  <= VTE           (2024-02-04) https://gitlab.gnome.org/GNOME/vte/-/commit/fe5b4c4ca43d78fa7cda012691a2837ba99a38f2
    if ((7501<=da2r_vec[1]&&da2r_vec[2]==1)); then
      _ble_term_TERM[depth]=vte:$((da2r_vec[1]))
    fi ;;
  ('65;'*)
    if ((5300<=da2r_vec[1]&&da2r_vec[1]<=7501&&da2r_vec[2]==1)); then
      _ble_term_TERM[depth]=vte:$((da2r_vec[1]))
    elif ((da2r_vec[1]>=100)); then
      _ble_term_TERM[depth]=RLogin:$((da2r_vec[1]))
    fi ;;
  ('67;'*)
    local rex='^67;[0-9]{3,};0$'
    if [[ $TERM == cygwin && $da2r =~ $rex ]]; then
      _ble_term_TERM[depth]=cygwin:$((da2r_vec[1]))
    fi ;;
  ('77;'*';0')
    _ble_term_TERM[depth]=mintty:$((da2r_vec[1])) ;;
  ('83;'*)
    local rex='^83;[0-9]+;0$'
    [[ $da2r =~ $rex ]] && _ble_term_TERM[depth]=screen:$((da2r_vec[1])) ;;
  ('84;0;0')
    _ble_term_TERM[depth]=tmux:0 ;;
  ('99;'*)
    _ble_term_TERM[depth]=contra:$((da2r_vec[1])) ;;
  esac
  [[ ${_ble_term_TERM[depth]} ]] && return 0

  # xterm
  if rex='^xterm(-|$)'; [[ $TERM =~ $rex ]]; then
    local version=$((da2r_vec[1]))
    if rex='^1;[0-9]+;0$'; [[ $da2r =~ $rex ]]; then
      # Note: vte (2000 or more), kitty (4000 or more) have been processed
      builtin true
    elif rex='^0;[0-9]+;0$'; [[ $da2r =~ $rex ]]; then
      ((95<=version))
    elif rex='^(2|24|1[89]|41|6[145]);[0-9]+;0$'; [[ $da2r =~ $rex ]]; then
      ((280<=version))
    elif rex='^32;[0-9]+;0$'; [[ $da2r =~ $rex ]]; then
      ((354<=version&&version<2000))
    else
      builtin false
    fi && { _ble_term_TERM[depth]=xterm:$version; return 0; }
  fi

  _ble_term_TERM[depth]=unknown:-
  return 0
}

function ble/term/DA1/notify { _ble_term_DA1R=$1; blehook/invoke term_DA1R; }
function ble/term/DA2/notify {
  # Note #D1485: DA2R from the outer terminal is mixed in when attaching with screen
  # Something happened. The contents received from the second time onwards should not be used inside ble.sh.
  # Make it.
  local depth=${#_ble_term_DA2R[@]}
  if ((depth==0)) || ble/string#match "${_ble_term_TERM[depth-1]}" '^(screen|tmux):'; then
    _ble_term_DA2R[depth]=$1
    ble/term/DA2/initialize-term "$depth"

    local is_outermost=1
    case ${_ble_term_TERM[depth]} in
    (screen:*|tmux:*)
      # Also issues DA2 requests to external terminals. [ Note: The first DA2 request is
      # Sent from ble/decode/attach (decode.sh). ]
      local ret is_outermost=
      ble/term/quote-passthrough $'\e[>c' "$((depth+1))"
      ble/util/buffer "$ret" ;;
    (contra:*)
      if [[ ! ${_ble_term_Ss-} ]]; then
        _ble_term_Ss=$'\e[@1 q'
      fi ;;
    (terminology:*)
      # Note #D1946: Terminology has xenl state when returning cursor position.
      # There is a bug where (ty->termstate.wrapnext) remains. In order to avoid this,
      # Use CR to return to the beginning of the line, then DECRC.
      _ble_term_sc=$'\e7' _ble_term_rc=$'\r\e8' ;;
    esac

    if ((depth==0)); then
      ble/term/synchronized-update-mode/resolve-auto
    fi
    if [[ $is_outermost ]]; then
      _ble_term_TERM_done=1
      ble/term/modifyOtherKeys/reset
    fi

    # The external terminal information will not be processed later.
    ((depth)) && return 0
  fi

  blehook/invoke term_DA2R
}

## @fn ble/term/quote-passthrough seq [level] [opts]
##   Processes the specified sequence so that it passes through the terminal multiplexer.
##
##   @param[in] seq
##     Specify the sequence to send.
##
##   @param[in,opt] level
##     A layer that delivers sequences. 0 is the terminal multiplayer running the innermost Bash.
##     Kusa. If omitted, the sequence is delivered to the outermost terminal.
##
##   @param[in,opt] opts
##     Colon-separated settings.
##
##     all
## Send the same sequence to all terminals/terminal multiplexers below the specified layer
##       I will. [Note: The terminal multiplexer itself may process and act on the outside.
##       Since it is not sent to the outside using pass-through, the terminal multiplexer
##       Send it to yourself too. ]
##
##   @var[out] ret
##     Stores the processed sequence.
##
function ble/term/quote-passthrough {
  local seq=$1 level=${2:-$((${#_ble_term_DA2R[@]}-1))} opts=$3
  local all=; [[ :$opts: == *:all:* ]] && all=1
  ret=$seq
  [[ $seq ]] || return 0
  local i
  for ((i=level;--i>=0;)); do
    if [[ ${_ble_term_TERM[i]} == tmux:* ]]; then
      # Note: In tmux, \e included in pass-through seq is changed to \e\e.
      # escape
      ret=$'\ePtmux;'${ret//$'\e'/$'\e\e'}$'\e\\'${all:+$seq}
    else
      # Note: screen indicates that the first occurrence of \e\\ ends the pass-through sequence.
      # Therefore, it is not possible to simply nest pass-through sequences. So, example
      # For example, when pass-through "\ePXXX\e\\YYY", between \e and \\
      # Divide it like [\ePXXX\e][\\YYY] and pass-through each.
      ret=$'\eP'${ret//$'\e\\'/$'\e\e\\\eP\\'}$'\e\\'${all:+$seq}
    fi
  done
}

_ble_term_DECSTBM=
_ble_term_DECSTBM_reset=
function ble/term/test-DECSTBM.hook1 {
  (($1==2)) && _ble_term_DECSTBM=$'\e[%s;%sr'
}
function ble/term/test-DECSTBM.hook2 {
  if [[ $_ble_term_DECSTBM ]]; then
    if (($1==2)); then
      # Failed to reset DECSTBM with \e[;r
      _ble_term_DECSTBM_reset=$'\e[r'
    else
      _ble_term_DECSTBM_reset=$'\e[;r'
    fi
  fi
}
function ble/term/test-DECSTBM {
  # Note: In kitty and wezterm, \e[;r in a form distinguishable from SCORC cannot be restored.
  # I can't go home.
  local -a DRAW_BUFF=()
  ble/canvas/panel/goto-top-dock.draw
  ble/canvas/put.draw "$_ble_term_sc"$'\e[1;2r'
  ble/canvas/put-cup.draw 2 1
  ble/canvas/put-cud.draw 1
  ble/term/CPR/request.draw ble/term/test-DECSTBM.hook1
  ble/canvas/put.draw $'\e[;r'
  ble/canvas/put-cup.draw 2 1
  ble/canvas/put-cud.draw 1
  ble/term/CPR/request.draw ble/term/test-DECSTBM.hook2
  ble/canvas/put.draw $'\e[r'"$_ble_term_rc"
  ble/canvas/bflush.draw
}

#---- DSR(6) ------------------------------------------------------------------
# CPR (CURSOR POSITION REPORT)

_ble_term_CPR_timeout=60
_ble_term_CPR_last_seconds=$SECONDS
_ble_term_CPR_hook=()
function ble/term/CPR/request.buff {
  ((SECONDS>_ble_term_CPR_last_seconds+_ble_term_CPR_timeout)) &&
    _ble_term_CPR_hook=()
  _ble_term_CPR_last_seconds=$SECONDS
  ble/array#push _ble_term_CPR_hook "$1"
  ble/util/buffer $'\e[6n'
  return 147
}
function ble/term/CPR/request.draw {
  ((SECONDS>_ble_term_CPR_last_seconds+_ble_term_CPR_timeout)) &&
    _ble_term_CPR_hook=()
  _ble_term_CPR_last_seconds=$SECONDS
  ble/array#push _ble_term_CPR_hook "$1"
  ble/canvas/put.draw $'\e[6n'
  return 147
}
function ble/term/CPR/notify {
  local hook=${_ble_term_CPR_hook[0]}
  ble/array#shift _ble_term_CPR_hook
  [[ ! $hook ]] || builtin eval -- "$hook $1 $2"
}

#---- SGR(>4): modifyOtherKeys ------------------------------------------------

bleopt/declare -v term_modifyOtherKeys_external auto
bleopt/declare -v term_modifyOtherKeys_internal auto
bleopt/declare -v term_modifyOtherKeys_passthrough_kitty_protocol ''

_ble_term_modifyOtherKeys_current=
_ble_term_modifyOtherKeys_current_method=
_ble_term_modifyOtherKeys_current_TERM=
function ble/term/modifyOtherKeys/.update {
  local IFS=$_ble_term_IFS state=${1%%:*}
  [[ $1 == "$_ble_term_modifyOtherKeys_current" ]] &&
    [[ $state != 2 || "${_ble_term_TERM[*]}" == "$_ble_term_modifyOtherKeys_current_TERM" ]] &&
    return 0

  # Note: For RLogin, modifyStringKeys (\e[>5m) must also be specified.
  #   Also, RLogin changes the S-number by modifyStringKeys.
  #   Please note that it does not translate into symbols.
  local previous=${_ble_term_modifyOtherKeys_current%%:*} method
  if [[ $state == 2 ]]; then
    case $_ble_term_TERM in
    (RLogin:*) method=RLogin_modifyStringKeys ;;
    (kitty:*)
      local da2r_vec
      ble/string#split da2r_vec ';' "$_ble_term_DA2R"
      if ((da2r_vec[2]>=23)); then
        method=kitty_keyboard_protocol
      else
        method=kitty_modifyOtherKeys
      fi ;;
    (screen:*|tmux:*)
      method=modifyOtherKeys

      if [[ $bleopt_term_modifyOtherKeys_passthrough_kitty_protocol ]]; then
        # Note (#D1843): if the outermost terminal is kitty-0.23+, we directly
        #   send keyboard-protocol sequences to the outermost kitty.
        local index=$((${#_ble_term_TERM[*]}-1))
        if [[ ${_ble_term_TERM[index]} == kitty:* ]]; then
          local da2r_vec
          ble/string#split da2r_vec ';' "${_ble_term_DA2R[index]}"
          ((da2r_vec[2]>=23)) && method=kitty_keyboard_protocol
        fi
      fi ;;
    (*)
      method=modifyOtherKeys
      if [[ $1 == *:auto ]]; then
        # Disable it on devices that cause problems.
        ble/term/modifyOtherKeys/.supported || method=disabled
      fi ;;
    esac

    # Note #D2062: modifyOtherKeys has no effect when inside mc, regardless of the outer terminal.
    # make effective. C-o will no longer work, and other commands for mc will no longer work.
    # There is a possibility that
    [[ $MC_SID ]] && method=disabled

    # If it is enabled using another method, release it first.
    if ((previous>=2)) &&
      [[ $method != "$_ble_term_modifyOtherKeys_current_method" ]]
    then
      ble/term/modifyOtherKeys/.update 1
      previous=1
    fi
  else
    method=$_ble_term_modifyOtherKeys_current_method
  fi
  _ble_term_modifyOtherKeys_current=$1
  _ble_term_modifyOtherKeys_current_method=$method
  _ble_term_modifyOtherKeys_current_TERM="${_ble_term_TERM[*]}"

  case $method in
  (RLogin_modifyStringKeys)
    case $state in
    (0) ble/util/buffer $'\e[>5;0m' ;;
    (1) ble/util/buffer $'\e[>5;1m' ;;
    (2) ble/util/buffer $'\e[>5;1m\e[>5;2m' ;;
    esac
    ;; # fallback to modifyOtherKeys
  (kitty_modifyOtherKeys)
    # Note: kitty has quirks in its implementation of modifyOtherKeys.
    # Note #D1549: 1 does not disable it. Weird behavior.
    # Note #D1626: In more recent kitty, \e[>4;0m doesn't work either, so you have to use \e[>4m.
    case $state in
    (0|1) ble/util/buffer $'\e[>4;0m\e[>4m' ;;
    (2)   ble/util/buffer $'\e[>4;1m\e[>4;2m\e[m' ;;
    esac
    return 0 ;;
  (kitty_keyboard_protocol)
    # Note: Kovid removed the support for modifyOtherKeys in kitty 0.24 after
    #   vim has pointed out the quirk of kitty.  The kitty keyboard mode only
    #   has push/pop operations so that their numbers need to be balanced.
    local seq=
    case $state in
    (0|1) # pop keyboard mode
      # When this is empty, ble.sh has not yet pushed any keyboard modes, so
      # we just ignore the keyboard mode change.
      [[ $previous ]] || return 0

      ((previous>=2)) && seq=$'\e[<u' ;;
    (2) # push keyboard mode
      ((previous>=2)) || seq=$'\e[>1u' ;;
    esac
    if [[ $seq ]]; then
      # Note (#D1843): we directly send kitty-keyboard-protocol sequences to
      #   the outermost terminal.
      local ret
      ble/term/quote-passthrough "$seq"
      ble/util/buffer "$ret"

      # find innermost tmux and adjust its modifyOtherKeys state (do not care
      # about screen which is transparent for the user input keys)
      local level
      for ((level=1;level<${#_ble_term_TERM[@]}-1;level++)); do
        [[ ${_ble_term_TERM[level]} == tmux:* ]] || continue
        case $state in
        (0) seq=$'\e[>4;0m\e[m' ;;
        (1) seq=$'\e[>4;1m\e[m' ;;
        (2) seq=$'\e[>4;1m\e[>4;2m\e[m' ;;
        esac
        ble/term/quote-passthrough "$seq" "$level"
        ble/util/buffer "$ret"
        break
      done
    fi
    return 0 ;;
  (disabled)
    return 0 ;;
  esac

  # Note: Even if an unsupported device mistakes it for SGR,
  #  Clear SGR last to make sure it's okay.
  # Note: If \e[>4;2m, it is because the device is not supported.
  #   First set it to \e[>4;1m, then set it to \e[>4;2m.
  case $state in
  (0) ble/util/buffer $'\e[>4;0m\e[m' ;;
  (1) ble/util/buffer $'\e[>4;1m\e[m' ;;
  (2) ble/util/buffer $'\e[>4;1m\e[>4;2m\e[m' ;;
  esac
}
function ble/term/modifyOtherKeys/.supported {
  [[ $_ble_term_TERM_done ]] || return 1

  # libvte displays SGR(>4) directly on the screen.
  [[ $_ble_term_TERM == vte:* ]] && return 1

  # The modified version of Poderosa changes the window size each time with notifications, resulting in cluttered display.
  [[ $MWG_LOGINTERM == rosaterm ]] && return 1

  case $TERM in
  (linux)
    # Note #D1213: Linux (kernel 5.0.0) closes escape sequences with "\e[>"
    # I end up. 5.4.8 is fine, but it still doesn't support modifyOtherKeys.
    return 1 ;;
  (minix|sun*)
    # The minix and Solaris consoles also output the same output.
    return 1 ;;
  (st|st-*)
    # Note #D1631: There was a complaint about unknown csi appearing in the st error log, so I disabled it.
    # Probably st will not support modifyOtherKeys in the future.
    return 1 ;;
  esac

  return 0
}
function ble/term/modifyOtherKeys/enter {
  local value=$bleopt_term_modifyOtherKeys_internal
  if [[ $value == auto ]]; then
    value=2:auto
  fi
  ble/term/modifyOtherKeys/.update "$value"
}
function ble/term/modifyOtherKeys/leave {
  local value=$bleopt_term_modifyOtherKeys_external
  if [[ $value == auto ]]; then
    value=1:auto
  fi
  ble/term/modifyOtherKeys/.update "$value"
}
function ble/term/modifyOtherKeys/reset {
  ble/term/modifyOtherKeys/.update "$_ble_term_modifyOtherKeys_current"
}

#---- Alternate Screen Buffer mode --------------------------------------------

_ble_term_altscr_state=
function ble/term/enter-altscr {
  [[ $_ble_term_altscr_state ]] && return 0
  _ble_term_altscr_state=("$_ble_canvas_x" "$_ble_canvas_y")
  if [[ $_ble_term_rmcup ]]; then
    ble/util/buffer "$_ble_term_smcup"
  else
    local -a DRAW_BUFF=()
    ble/canvas/put.draw $'\e[?1049h'
    ble/canvas/put-cup.draw "$LINES" 0
    ble/canvas/put-ind.draw "$LINES"
    ble/canvas/bflush.draw
  fi
}
function ble/term/leave-altscr {
  [[ $_ble_term_altscr_state ]] || return 0
  if [[ $_ble_term_rmcup ]]; then
    ble/util/buffer "$_ble_term_rmcup"
  else
    local -a DRAW_BUFF=()
    ble/canvas/put-cup.draw "$LINES" 0
    ble/canvas/put-ind.draw
    ble/canvas/put.draw $'\e[?1049l'
    ble/canvas/bflush.draw
  fi
  _ble_canvas_x=${_ble_term_altscr_state[0]}
  _ble_canvas_y=${_ble_term_altscr_state[1]}
  _ble_term_altscr_state=()
}

#---- rl variable: convert-meta -----------------------------------------------

_ble_term_rl_convert_meta_adjusted=
_ble_term_rl_convert_meta_external=
function ble/term/rl-convert-meta/enter {
  [[ $_ble_term_rl_convert_meta_adjusted ]] && return 0
  _ble_term_rl_convert_meta_adjusted=1

  if ble/util/rlvar#test convert-meta; then
    _ble_term_rl_convert_meta_external=on
    builtin bind 'set convert-meta off'
  else
    _ble_term_rl_convert_meta_external=off
  fi
}
function ble/term/rl-convert-meta/leave {
  [[ $_ble_term_rl_convert_meta_adjusted ]] || return 1
  _ble_term_rl_convert_meta_adjusted=

  [[ $_ble_term_rl_convert_meta_external == on ]] &&
    builtin bind 'set convert-meta on'
}

#---- terminal enter/leave ----------------------------------------------------

_ble_term_attached=
_ble_term_state=external

## @fn ble/term/enter-for-widget [opts]
##   @param[opt] opts
##     @opt noflush
function ble/term/enter-for-widget {
  ble/term/bracketed-paste-mode/enter
  ble/term/modifyOtherKeys/enter
  ble/term/cursor-state/.update "$_ble_term_cursor_internal"
  ble/term/cursor-state/.update-hidden "$_ble_term_cursor_hidden_internal"
  [[ :$1: == *:noflush:* ]] || ble/util/buffer.flush
}
## @fn ble/term/leave-for-widget
function ble/term/leave-for-widget {
  ble/term/visible-bell/erase
  ble/term/bracketed-paste-mode/leave
  ble/term/modifyOtherKeys/leave
  ble/term/cursor-state/.update "$bleopt_term_cursor_external"
  ble/term/cursor-state/.update-hidden reveal
  # Note: To reveal the cursor, we need to make sure that ble/util/buffer.flush
  # is called this timing (where _ble_term_cursor_hidden_current=reveal).
  ble/util/buffer.flush
}

## @fn ble/term/enter [opts]
##   @param[opt] opts
##     @opt noflush
function ble/term/enter {
  [[ $_ble_term_state == internal ]] && return 0
  _ble_term_state=internal
  ble/term/stty/enter
  ble/term/rl-convert-meta/enter
  ble/term/enter-for-widget "$1"
}
## @fn ble/term/leave
function ble/term/leave {
  [[ $_ble_term_state == external ]] && return 0
  ble/term/stty/leave
  ble/term/rl-convert-meta/leave
  ble/term/leave-for-widget
  [[ $_ble_term_cursor_current == default ]] ||
    _ble_term_cursor_current=unknown # vim won't restore
  _ble_term_cursor_hidden_current=unknown
  _ble_term_state=external
}

## @fn ble/term/initialize [opts]
##   @param[opt] opts
##     @opt noflush
function ble/term/initialize {
  ble/term/DA2/request
  ble/term/test-DECSTBM
}
## @fn ble/term/attach [opts]
##   @param[opt] opts
##     @opt noflush
function ble/term/attach {
  [[ $_ble_term_attached ]] && return 0
  _ble_term_attached=1
  ble/term/stty/initialize
  ble/term/enter "$1"
}
## @fn ble/term/enter [opts]
##   @param[opt] opts
##     @opt noflush
function ble/term/detach {
  [[ $_ble_term_attached ]] || return 0
  _ble_term_attached=
  ble/term/stty/finalize
  ble/term/leave
  ble/util/buffer.flush
}

#------------------------------------------------------------------------------
# String manipulations

_ble_util_s2c_table_enabled=
## @fn ble/util/s2c text [index]
##   @param[in] text
##   @param[in,opt] index
##   @var[out] ret
if ((_ble_bash>=50300)); then
  # Unicode can be read with printf "'c" (any LC_CTYPE is Unicode)
  function ble/util/s2c {
    builtin printf -v ret %d "'$1"
  }
elif ((_ble_bash>=40100)); then
  function ble/util/s2c {
    # Note #D1881: Before bash-5.2, the mbstate_t state for printf %d "'x" is
    # It will remain. So try clearing it once.
    if ble/util/is-unicode-output; then
      builtin printf -v ret %d "'μ"
    else
      builtin printf -v ret %d "'x"
    fi
    builtin printf -v ret %d "'$1"
  }
elif ((_ble_bash>=40000&&!_ble_bash_loaded_in_function)); then
  # - Can be cached in an associative array
  # - Unicode can be read with printf "'c"
  declare -A _ble_util_s2c_table
  _ble_util_s2c_table_enabled=1
  function ble/util/s2c {
    [[ $_ble_util_locale_triple != "$LC_ALL:$LC_CTYPE:$LANG" ]] &&
      ble/util/.update-locale-cache

    local s=${1::1}
    ret=${_ble_util_s2c_table[x$s]}
    [[ $ret ]] && return 0

    ble/util/sprintf ret %d "'$s"
    _ble_util_s2c_table[x$s]=$ret
  }
elif ((_ble_bash>=40000)); then
  function ble/util/s2c {
    ble/util/sprintf ret %d "'${1::1}"
  }
else
  # In bash-3, printf %d "'ah" etc.
  # Only the value of the first byte that makes up "a" is displayed.
  # Either find a command to convert it to a unicode value somehow, or
  # You need to extract each byte and convert it to unicode.
  # In bash-3 you can read bytes using read -n 1. Take advantage of this.
  function ble/util/s2c {
    local s=${1::1}
    if [[ $s == [$'\x01'-$'\x7F'] ]]; then
      if [[ $s == $'\x7F' ]]; then
        # Note: In bash-3.0, printf %d "'^?" returns 0.
        #   printf %d \'^? will return 127 without any problem.
        ret=127
      else
        ble/util/sprintf ret %d "'$s"
      fi
      return 0
    fi

    local bytes byte
    ble/util/assign-words bytes '
      local IFS=
      while ble/bash/read -n 1 byte; do
        builtin printf "%d " "'\''$byte"
      done <<< "$s"
      IFS=$_ble_term_IFS
    '
    ble/encoding:"$bleopt_input_encoding"/b2c "${bytes[@]}"
  }
fi

# ble/util/c2s

## @fn ble/util/c2s.impl char
##   @var[out] ret
if ((_ble_bash>=40200)); then
  # $'...' in bash-4.2 supports \uXXXX and \UXXXXXXXX sequences.

  # workarounds of bashbug that printf '\uFFFF' results in a broken surrogate
  # pair in systems where sizeof(wchar_t) == 2.
  function ble/util/.has-bashbug-printf-uffff {
    ((40200<=_ble_bash&&_ble_bash<50000)) || return 1

    # Note: CentOS 7 did not have C.UTF-8, so use 2>/dev/null. Also on macOS
    # C.UTF-8 is not available. In any case, sizeof(wchar_t) == 2 on these systems
    # There is no need to convert it to UTF-8 correctly.
    local LC_ALL=C.UTF-8 2>/dev/null

    local ret
    builtin printf -v ret '\uFFFF'
    ((${#ret}==2))
  }
  # suppress locale error #D1440
  ble/function#suppress-stderr ble/util/.has-bashbug-printf-uffff

  if ble/util/.has-bashbug-printf-uffff; then
    function ble/util/c2s.impl {
      if ((0xE000<=$1&&$1<=0xFFFF)) && [[ $_ble_util_locale_encoding == UTF-8 ]]; then
        builtin printf -v ret '\\x%02x' "$((0xE0|$1>>12&0x0F))" "$((0x80|$1>>6&0x3F))" "$((0x80|$1&0x3F))"
      else
        builtin printf -v ret '\\U%08x' "$1"
      fi
      builtin eval "ret=\$'$ret'"
    }
    function ble/util/chars2s.impl {
      if [[ $_ble_util_locale_encoding == UTF-8 ]]; then
        local -a buff=()
        local c i=0
        for c; do
          ble/util/c2s.cached "$c"
          buff[i++]=$ret
        done
        IFS= builtin eval 'ret="${buff[*]}"'
      else
        builtin printf -v ret '\\U%08x' "$@"
        builtin eval "ret=\$'$ret'"
      fi
    }
  else
    function ble/util/c2s.impl {
      builtin printf -v ret '\\U%08x' "$1"
      builtin eval "ret=\$'$ret'"
    }
    function ble/util/chars2s.impl {
      builtin printf -v ret '\\U%08x' "$@"
      builtin eval "ret=\$'$ret'"
    }
  fi
else
  _ble_text_xdigit=(0 1 2 3 4 5 6 7 8 9 A B C D E F)
  _ble_text_hexmap=()
  for ((i=0;i<256;i++)); do
    _ble_text_hexmap[i]=${_ble_text_xdigit[i>>4&0xF]}${_ble_text_xdigit[i&0xF]}
  done

  # Operation confirmed 3.1, 3.2, 4.0, 4.2, 4.3
  function ble/util/c2s.impl {
    if (($1<0x80)); then
      builtin eval "ret=\$'\\x${_ble_text_hexmap[$1]}'"
      return 0
    fi

    local bytes i iN seq=
    ble/encoding:"$_ble_util_locale_encoding"/c2b "$1"
    for ((i=0,iN=${#bytes[@]};i<iN;i++)); do
      seq="$seq\\x${_ble_text_hexmap[bytes[i]&0xFF]}"
    done
    builtin eval "ret=\$'$seq'"
  }

  function ble/util/chars2s.loop {
    for c; do
      ble/util/c2s.cached "$c"
      buff[i++]=$ret
    done
  }
  function ble/util/chars2s.impl {
    # Note: Calling a function from a function with a large number of arguments is expensive, so
    # We will call the function in small parts every B=160.
    local -a buff=()
    local c i=0 b N=$# B=160
    for ((b=0;b+B<N;b+=B)); do
      ble/util/chars2s.loop "${@:b+1:B}"
    done
    ble/util/chars2s.loop "${@:b+1:N-b}"
    IFS= builtin eval 'ret="${buff[*]}"'
  }
fi

# Apparently caching is the fastest way.
_ble_util_c2s_table=()
## @fn ble/util/c2s char
##   @var[out] ret
function ble/util/c2s {
  [[ $_ble_util_locale_triple != "$LC_ALL:$LC_CTYPE:$LANG" ]] &&
    ble/util/.update-locale-cache

  ret=${_ble_util_c2s_table[$1]-}
  if [[ ! $ret ]]; then
    ble/util/c2s.impl "$1"
    _ble_util_c2s_table[$1]=$ret
  fi
}
function ble/util/c2s.cached {
  # Version without locale check
  ret=${_ble_util_c2s_table[$1]-}
  if [[ ! $ret ]]; then
    ble/util/c2s.impl "$1"
    _ble_util_c2s_table[$1]=$ret
  fi
}
function ble/util/chars2s {
  [[ $_ble_util_locale_triple != "$LC_ALL:$LC_CTYPE:$LANG" ]] &&
    ble/util/.update-locale-cache
  ble/util/chars2s.impl "$@"
}

## @fn ble/util/c2bc
##   gets a byte count of the encoded data of the char
##   Gets the number of bytes when encoding the specified character using the current encoding method.
##   @param[in]  $1 = code
##   @param[out] ret
function ble/util/c2bc {
  ble/encoding:"$bleopt_input_encoding"/c2bc "$1"
}

## @fn ble/util/.update-locale-cache
##
##  How to use
##
##    [[ $_ble_util_locale_triple != "$LC_ALL:$LC_CTYPE:$LANG" ]] &&
##      ble/util/.update-locale-cache
##
_ble_util_locale_triple=
_ble_util_locale_ctype=
_ble_util_locale_encoding=UTF-8
_ble_util_locale_broken=
function ble/util/.test-C-locale {
  # Note: In Termux, even with the locale "C", the behavior appears to be that
  # of UTF-8.  This makes it impossible to manipulate binary data in the shell.
  local LC_ALL= LC_CTYPE= LANG=C
  local s='alpha'
  ((${#s}==3)); local ext=$?
  ble/util/unlocal LC_ALL LC_CTYPE LANG
  return "$ext"
} 2>/dev/null # suppress locale error #D1440
## @fn ble/util/.test-utf8-locale
##   @var[in] ctype
function ble/util/.test-utf8-locale {
  # Note: To test the specified locale in WSL, it seems one needs to activate
  # the locale by setting the locale to another one at least once.  We first
  # set the locale to "C" and use it to obtain the number of bytes, 3, and then
  # check the target locale.
  local LC_ALL= LC_CTYPE= LANG=C
  local s='alpha'
  LANG=$ctype
  ((${#s}==1)); local ext=$?
  ble/util/unlocal LC_ALL LC_CTYPE LANG
  return "$ext"
} 2>/dev/null # suppress locale error #D1440

function ble/util/.update-locale-cache {
  _ble_util_locale_triple=$LC_ALL:$LC_CTYPE:$LANG

  # clear cache if LC_CTYPE is changed
  local ctype=${LC_ALL:-${LC_CTYPE:-$LANG}}
  local ret; ble/string#tolower "$ctype"
  if [[ $_ble_util_locale_ctype != "$ret" ]]; then
    _ble_util_locale_ctype=$ret
    _ble_util_c2s_table=()
    [[ $_ble_util_s2c_table_enabled ]] &&
      _ble_util_s2c_table=()

    _ble_util_locale_encoding=C
    _ble_util_locale_broken=
    ble/util/.test-C-locale || _ble_util_locale_broken=C

    if local rex='\.([^@]+)'; [[ $_ble_util_locale_ctype =~ $rex ]]; then
      local enc=${BASH_REMATCH[1]}
      if [[ $enc == utf-8 || $enc == utf8 ]]; then
        enc=UTF-8
      fi

      if [[ $enc == UTF-8 ]] && ! ble/util/.test-utf8-locale "$ctype"; then
        _ble_util_locale_broken=${_ble_util_locale_broken:+$_ble_util_locale_broken$_ble_term_FS}$ctype

        # Note #D2281: In WSL, even when the current locale is broken, builtin
        # printf seems to produce the UTF-8 representation of the specified
        # codepoint, which will be stored in "_ble_edit_str".  This causes
        # problems because they cannot be properly processed by textmap,
        # syntax, etc. within the current locale.  In such a case, we
        # explicitly generate the fallback string of the form \uXXXX or
        # \UXXXXXXXX for the multibyte UTF-8 characters.
        if ble/base/is-wsl; then
          ble/function#advice around ble/util/c2s.impl '
            local char=${ADVICE_WORDS[1]}
            if [[ $_ble_util_locale_broken ]] && ((char>=0x80)); then
              if ((char<0x10000)); then
                ble/util/sprintf ret '\''\\u%04X'\'' "$char"
              else
                ble/util/sprintf ret '\''\\U%08X'\'' "$char"
              fi
            else
              ble/function#advice/do
            fi
          '

          ble/function#advice around ble/util/chars2s.impl '
            local char=${ADVICE_WORDS[1]}
            if [[ $_ble_util_locale_broken ]]; then
              local out= char
              for char in "${ADVICE_WORDS[@]:1}"; do
                ble/util/c2s "$char"
                out=$out$ret
              done
              ret=$out
            else
              ble/function#advice/do
            fi
          '
        fi
      elif ble/is-function ble/encoding:"$enc"/b2c; then
        _ble_util_locale_encoding=$enc
      fi
    fi
  fi
}

builtin eval -- "${_ble_util_gdict_declare//NAME/_ble_util_locale_broken_notified}"
function ble/util/notify-broken-locale {
  [[ $_ble_util_locale_triple != "$LC_ALL:$LC_CTYPE:$LANG" ]] &&
    ble/util/.update-locale-cache

  [[ $_ble_util_locale_broken ]] || return 0

  local broken broken_locales
  ble/string#split broken_locales "$_ble_term_FS" "$_ble_util_locale_broken"
  for broken in "${broken_locales[@]}"; do
    [[ $broken ]] || continue
    ble/gdict#has _ble_util_locale_broken_notified "$broken" && continue
    ble/gdict#set _ble_util_locale_broken_notified "$broken" 1
    ble/util/print "ble.sh: The locale '$broken' (LC_CTYPE) seems broken. Please check that the locale exists in the system." >&2
    if [[ $broken == C && $OSTYPE == linux-android && $HOME == */com.termux/* ]]; then
      ble/util/print 'ble.sh: Termux has an issue with its locale "C", and the fix is discussed at https://github.com/termux/termux-packages/discussions/23010' >&2
    fi
  done
}

function ble/util/is-unicode-output {
  [[ $_ble_util_locale_triple != "$LC_ALL:$LC_CTYPE:$LANG" ]] &&
    ble/util/.update-locale-cache
  [[ $_ble_util_locale_encoding == UTF-8 ]]
}

#------------------------------------------------------------------------------

## @fn ble/util/s2chars text
##   @var[out] ret
function ble/util/s2chars {
  local text=$1 n=${#1} i chars
  chars=()
  for ((i=0;i<n;i++)); do
    ble/util/s2c "${text:i:1}"
    ble/array#push chars "$ret"
  done
  ret=("${chars[@]}")
}
function ble/util/s2bytes {
  local LC_ALL= LC_CTYPE=C
  ble/util/s2chars "$1"; local ext=$?
  ble/util/unlocal LC_ALL LC_CTYPE
  ble/util/.update-locale-cache
  return "$?"
} &>/dev/null

# Format of keyseq used by bind

## @fn ble/util/c2keyseq char
##   @var[out] ret
function ble/util/c2keyseq {
  local char=$(($1))
  case $char in
  (7)   ret='\a' ;;
  (8)   ret='\b' ;;
  (9)   ret='\t' ;;
  (10)  ret='\n' ;;
  (11)  ret='\v' ;;
  (12)  ret='\f' ;;
  (13)  ret='\r' ;;
  (27)  ret='\e' ;;
  (92)  ret='\\' ;;
  (127) ret='\d' ;;
  (28)  ret='\x1c' ;; # workaround \C-\, \C-\\
  (156) ret='\x9c' ;; # workaround \M-\C-\, \M-\C-\\
  (*)
    if ((char<32||128<=char&&char<160)); then
      local char7=$((char&0x7F))
      if ((1<=char7&&char7<=26)); then
        ble/util/c2s "$((char7+96))"
      else
        ble/util/c2s "$((char7+64))"
      fi
      ret='\C-'$ret
      ((char&0x80)) && ret='\M-'$ret
    else
      ble/util/c2s "$char"
    fi ;;
  esac
}
## @fn ble/util/chars2keyseq char...
##   @var[out] ret
function ble/util/chars2keyseq {
  local char str=
  for char; do
    ble/util/c2keyseq "$char"
    str=$str$ret
  done
  ret=$str
}
## @fn ble/util/keyseq2chars keyseq
##   @arr[out] ret
function ble/util/keyseq2chars {
  local keyseq=$1
  local -a chars=()
  local mods=
  local rex='^([^\]+)|^\\([CM]-|[0-7]{1,3}|x[0-9a-fA-F]{1,2}|.)?'
  while [[ $keyseq ]]; do
    local text=${keyseq::1} esc
    [[ $keyseq =~ $rex ]] &&
      text=${BASH_REMATCH[1]} esc=${BASH_REMATCH[2]}

    if [[ $text ]]; then
      keyseq=${keyseq:${#text}}
      ble/util/s2chars "$text"
    else
      keyseq=${keyseq:1+${#esc}}
      ret=()
      case $esc in
      ([CM]-)  mods=$mods${esc::1}; continue ;;
      (x?*)    ret=$((16#${esc#x})) ;;
      ([0-7]*) ret=$((8#$esc)) ;;
      (a) ret=7 ;;
      (b) ret=8 ;;
      (t) ret=9 ;;
      (n) ret=10 ;;
      (v) ret=11 ;;
      (f) ret=12 ;;
      (r) ret=13 ;;
      (e) ret=27 ;;
      (d) ret=127 ;;
      (*) ble/util/s2c "$esc" ;;
      esac
    fi

    [[ $mods == *C* ]] && ((ret=ret==63?127:(ret&0x1F)))
    [[ $mods == *M* ]] && ble/array#push chars 27
    #[[ $mods == *M* ]] && ((ret|=0x80))
    mods=
    ble/array#push chars "${ret[@]}"
  done

  if [[ $mods ]]; then
    [[ $mods == *M* ]] && ble/array#push chars 27
    ble/array#push chars 0
  fi

  ret=("${chars[@]}")
}

#------------------------------------------------------------------------------

## @fn ble/encoding:UTF-8/b2c byte...
##   @var[out] ret
function ble/encoding:UTF-8/b2c {
  local bytes b0 n i
  bytes=("$@")
  ret=0
  ((b0=bytes[0]&0xFF))
  ((n=b0>=0xF0
    ?(b0>=0xFC?5:(b0>=0xF8?4:3))
    :(b0>=0xE0?2:(b0>=0xC0?1:0)),
    ret=n?b0&0x7F>>n:b0))
  for ((i=1;i<=n;i++)); do
    ((ret=ret<<6|0x3F&bytes[i]))
  done
}

## @fn ble/encoding:UTF-8/c2b char
##   @arr[out] bytes
function ble/encoding:UTF-8/c2b {
  local code=$1 n i
  ((code=code&0x7FFFFFFF,
    n=code<0x80?0:(
      code<0x800?1:(
        code<0x10000?2:(
          code<0x200000?3:(
            code<0x4000000?4:5))))))
  if ((n==0)); then
    bytes=("$code")
  else
    bytes=()
    for ((i=n;i;i--)); do
      ((bytes[i]=0x80|code&0x3F,
        code>>=6))
    done
    ((bytes[0]=code&0x3F>>n|0xFF80>>n&0xFF))
  fi
}

## @fn ble/encoding:C/b2c byte
##   @var[out] ret
function ble/encoding:C/b2c {
  local byte=$1
  ((ret=byte&0xFF))
}
## @fn ble/encoding:C/c2b char
##   @arr[out] bytes
function ble/encoding:C/c2b {
  local code=$1
  bytes=("$((code&0xFF))")
}

#------------------------------------------------------------------------------
# builtin readonly

builtin eval -- "${_ble_util_gdict_declare//NAME/_ble_builtin_readonly_blacklist}"

function ble/builtin/readonly/.initialize-blacklist {
  function ble/builtin/readonly/.initialize-blacklist { return 0; }

  local -a list=()

  # Bash variables ble.sh uses
  ble/array#push list FUNCNEST IFS IGNOREEOF POSIXLY_CORRECT TMOUT # adjust
  ble/array#push list PWD OLDPWD CDPATH # readlink
  ble/array#push list BASHPID GLOBIGNORE MAPFILE REPLY # util
  ble/array#push list INPUTRC # decode
  ble/array#push list LINES COLUMNS # canvas
  ble/array#push list HIST{CONTROL,IGNORE,SIZE,TIMEFORMAT} # history
  ble/array#push list PROMPT_COMMAND PS1 # prompt
  ble/array#push list BASH_COMMAND BASH_REMATCH HISTCMD LINENO PIPESTATUS TIMEFORMAT # exec
  ble/array#push list BASH_XTRACEFD PS4 # debug

  # Other common variables that ble.sh uses
  ble/array#push list CC LESS MANOPT MANPAGER PAGER PATH MANPATH

  # Other uppercase variables that ble.sh internally uses in each module
  ble/array#push list BUFF # util
  ble/array#push list KEYS KEYMAP WIDGET LASTWIDGET # decode
  ble/array#push list DRAW_BUFF # canvas
  ble/array#push list D{MIN,MAX,MAX0} {HIGHLIGHT,PREV}_{BUFF,UMAX,UMIN} LEVEL LAYER_{UMAX,UMIN} # color
  ble/array#push list HISTINDEX_NEXT FILE LINE INDEX INDEX_FILE # history
  ble/array#push list ARG FLAG REG # vi
  ble/array#push list COMP{1,2,S,V} ACTION CAND DATA INSERT PREFIX_LEN # core-complete
  ble/array#push list PRETTY_NAME NAME VERSION # edit (/etc/os-release)

  local v
  for v in "${list[@]}"; do ble/gdict#set _ble_builtin_readonly_blacklist "$v" 1; done
}
function ble/builtin/readonly/.check-variable-name {
  # Local variables are always allowed to make readonly.  Note: this
  # implementation does not block propagating tempenv variables being
  # propagated to the global context.  There is no way to reliably detect the
  # tempenv variables.
  ble/variable#is-global "$1" || return 0

  # If the variable starts with "_" but does not start with "_ble", it could be
  # a global variable used by another framework.  We allow such namespaced
  # variables being readonly.
  if [[ $1 == _* && $1 != _ble* && $1 != __ble* ]]; then
    return 0
  fi

  # These special variables should not be made readonly.
  case $1 in
  (?)                    return 1;; # single character variables
  (BLE_*|ADVICE_*)       return 1;; # ble.sh variables
  (COMP_*|COMPREPLY)     return 1;; # completion variables
  (READLINE_*)           return 1;; # readline variables
  (LC_*|LANG)            return 1;; # locale variables
  esac

  # If the variable name is in the black list, the variable cannot be readonly.
  ble/builtin/readonly/.initialize-blacklist
  if ble/gdict#has _ble_builtin_readonly_blacklist "$1"; then
    return 1
  fi

  # Otherwise, the variables that do not contain lowercase characters are
  # allowed to become readonly.  Note (#D2103): We adjust LC_COLLATE in
  # ble/builtin/readonly.
  if [[ $1 != *[a-z]* ]]; then
    return 0
  fi

  return 1
}

builtin eval -- "${_ble_util_gdict_declare//NAME/_ble_builtin_readonly_mark}"
_ble_builtin_readonly_message_count=0
blehook internal_PREEXEC!='_ble_builtin_readonly_message_count=0'

## @fn ble/builtin/readonly/.print-warning
##   @var[out] _ble_local_caller
function ble/builtin/readonly/.print-warning {
  [[ -t 2 ]] || return 0

  # If the caller information has not been initialized:
  if [[ ! $_ble_local_caller ]]; then
    _ble_local_caller=-
    local i n=${#FUNCNAME[@]}
    for ((i=1;i<n;i++)); do
      [[ ${FUNCNAME[i]} == *readonly ]] && continue
      [[ ${FUNCNAME[i]} == ble/function#advice/* ]] && continue
      _ble_local_caller="${BASH_SOURCE[i]}:${BASH_LINENO[i-1]}"
      break
    done
  fi

  local s_caller=
  if [[ $_ble_local_caller != - ]]; then
    ! ble/gdict#has _ble_builtin_readonly_mark "$_ble_local_caller:$1" || return 0
    ble/gdict#set _ble_builtin_readonly_mark "$_ble_local_caller:$1" yes
    s_caller=" ($_ble_local_caller)"
  else
    # We show messages only up to ten times
    ((_ble_builtin_readonly_message_count++<10)) || return 0
  fi

  _ble_local_flags=w$_ble_local_flags
  ble/util/print "ble.sh$s_caller: An attempt to make variable \`$1' readonly was blocked." >&2

  return 0
}
function ble/builtin/readonly {
  local _ble_local_set _ble_local_shopt
  ble/base/.adjust-bash-options _ble_local_set _ble_local_shopt
  local LC_ALL= LC_COLLATE=C 2>/dev/null # suppress locale error #D1440

  local _ble_local_flags=
  local -a _ble_local_options=()
  local _ble_local_caller= # used by print-warning
  while (($#)); do
    if ble/string#match "$1" '^([_a-zA-Z][_a-zA-Z0-9]*)($|=)'; then
      _ble_local_flags=v$_ble_local_flags
      local _ble_local_var=${BASH_REMATCH[1]}
      if [[ ${BASH_REMATCH[2]} == = ]]; then
        ble/util/sprintf "$_ble_local_var" "${1#*=}"
      fi

      if ble/builtin/readonly/.check-variable-name "$_ble_local_var"; then
        _ble_local_flags=r$_ble_local_flags
        ble/array#push _ble_local_options "$_ble_local_var"
      else
        ble/builtin/readonly/.print-warning "$1"
      fi
    else
      ble/array#push _ble_local_options "$1"
    fi
    shift
  done

  if [[ $_ble_local_flags == *w* ]]; then
    ble/util/print 'ble.sh: The global variables with unprefixed lowercase names or special names should not be made readonly. It can break arbitrary Bash configurations.' >&2
  fi
  local _ble_local_ext=0
  if [[ $_ble_local_flags != *v* || $_ble_local_flags == *r* ]]; then
    # We call `builtin readonly' only when no variables are specified
    # (e.g. readonly, readonly --help), or at least one variable are allowed to
    # become readonly.
    builtin readonly "${_ble_local_options[@]}"
    _ble_local_ext=$?
  fi

  ble/util/unlocal LC_ALL LC_COLLATE 2>/dev/null # suppress locale error #D1440
  ble/base/.restore-bash-options _ble_local_set _ble_local_shopt
  return "$?"
}

function readonly {
  builtin eval -- "$_ble_bash_POSIXLY_CORRECT_local_adjust"
  ble/builtin/readonly "$@"
  builtin eval -- "$_ble_bash_POSIXLY_CORRECT_local_return"
}

#------------------------------------------------------------------------------
# ble/util/message

>| "$_ble_base_run/$$.util.message-listening"
>> "$_ble_base_run/$$.util.message"
_ble_util_message_precmd=()

## @fn ble/util/message/.encode-data target data
##   @param[in] target
##     Specify the PID of the process to send
##   @param[in] data
##     Specify the data to send
##   @var[out] ret
function ble/util/message/.encode-data {
  local target=$1 data=$2
  if ((${#data}<256)); then
    ble/string#quote-word "$data"
    ret=eval:$ret
  else
    if ((_ble_bash<40000)); then
      local BASHPID
      ble/util/getpid
    fi

    local index=0 file
    while
      file=$_ble_base_run/$target.util.message.data-$BASHPID-$index
      [[ -e $file ]]
    do ((++index)); done

    ble/util/put "$data" >| "$file"

    ret=file:${file##*.}
  fi
}
## @fn ble/util/message/.decode-data data
##   @var[out] ret
function ble/util/message/.decode-data {
  ret=$1
  case $ret in
  (eval:*)
    local value=${ret#eval:}
    ble/syntax:bash/simple-word/is-simple "$value" &&
      builtin eval -- "ret=($value)" ;;
  (file:*)
    local file=$_ble_base_run/$$.util.message.${ret#file:}
    ble/util/readfile ret "$file"
    ble/array#push _ble_local_remove "$file"
  esac
}

function ble/util/message.post {
  local target=${1:-$$} event=${2-} type=${3-} data=${4-}

  if ! [[ $type && $type != *["$_ble_term_IFS"]* ]]; then
    ble/util/print "ble/util/message: invalid message type format '$type'" >&2
    return 2
  elif [[ $target == $$ ]] && ! ble/is-function ble/util/message/handler:"$type"; then
    ble/util/print "ble/util/message: unknown message type name '$type'" >&2
    return 2
  fi

  case $event in
  (precmd) ;;
  (*)
    ble/util/print "ble/util/message: unknown event type '$event'" >&2
    return 2 ;;
  esac

  if [[ $target == broadcast ]]; then
    local ret file
    ble/util/eval-pathname-expansion '"$_ble_base_run"/+([0-9]).util.message-listening' canonical
    for file in "${ret[@]}"; do
      file=${file%-listening}
      local pid=${file##*/}; pid=${pid%%.*}
      if builtin kill -0 "$pid"; then
        ble/util/message/.encode-data "$pid" "$data"
        ble/util/print "$event $type $ret" >> "$file"
      fi
    done

  elif ble/string#match "$target" '^[0-9]+$'; then
    if ! builtin kill -0 "$target"; then
      ble/util/print "ble/util/message: target process $target is not found" >&2
      return 2
    elif [[ ! -f $_ble_base_run/$target.util.message-listening ]]; then
      ble/util/print "ble/util/message: target process $target is not listening ble-messages" >&2
      return 2
    fi

    local ret
    ble/util/message/.encode-data "$target" "$data"
    ble/util/print "$event $type $ret" >> "$_ble_base_run/$target.util.message"
  else
    ble/util/print "ble/util/message: unknown target '$target'" >&2
    return 2
  fi
}
function ble/util/message.check {
  local file=$_ble_base_run/$$.util.message
  while [[ -f $file && -s $file ]]; do
    local fread=$file
    ble/bin/mv -f "$file" "$file-reading" && fread=$file-reading

    local IFS=$_ble_term_IFS event type data
    while ble/bash/read event type data || [[ $event ]]; do
      # check message handler
      [[ $type ]] && ble/is-function ble/util/message/handler:"$type" || continue

      case $event in
      (precmd) ble/array#push _ble_util_message_precmd "$type $data" ;;
      esac
    done < "$fread"

    >| "$fread"
  done
}
function ble/util/message.process {
  ble/util/message.check

  local event=$1
  case $event in
  (precmd)
    local _ble_local_messages
    _ble_local_messages=("${_ble_util_message_precmd[@]}")
    _ble_util_message_precmd=()

    local _ble_local_message
    local -a _ble_local_remove=()
    for _ble_local_message in "${_ble_local_messages[@]}"; do
      local _ble_local_event=${_ble_local_message%%' '*}
      local ret; ble/util/message/.decode-data "${_ble_local_message#* }"
      local _ble_local_data=$ret
      ble/util/unlocal ret
      ble/util/message/handler:"$_ble_local_event" "$_ble_local_data"
    done

    ((${#_ble_local_remove[@]})) && ble/bin/rm -f "${_ble_local_remove[@]}" ;;
  (*)
    ble/util/print "ble/util/message: unknown event type '$event'" >&2
    return 2 ;;
  esac
}

function ble/util/message/handler:print {
  ble/edit/enter-command-layout # #D1800 pair=leave-command-layout
  ble/util/print "$1" >&2
  ble/edit/leave-command-layout # #D1800 pair=enter-command-layout
}

blehook internal_PRECMD!='ble/util/message.process precmd'
