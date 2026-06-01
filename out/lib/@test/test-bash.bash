# -*- mode: sh; mode: sh-bash -*-

ble-import lib/@core/core-test

ble/test/start-section 'bash' 117

# Under what conditions does case $word need to be quoted?

# Of course, quote is required when directly writing characters that have special meaning in bash's syntax. word
# No splitting or pathname expansions occur. If $* or ${arr[*]} is included,
# In this case, the elements are concatenated using IFS regardless of whether they are quoted or not, so be careful with IFS.
# Necessary.
(
  # word splitting does not happen
  a='x y'
  ble/test code:'ret=$a' ret="x y"
  ble/test '[[ $a == "x y" ]]'
  ble/test 'case $a in ("x y") true ;; (*) false ;; esac'
  a='x  y'
  ble/test code:'ret=$a' ret="x  y"
  ble/test '[[ $a == "x  y" ]]'
  ble/test 'case $a in ("x  y") true ;; (*) false ;; esac'
  IFS=abc a='xabcy'
  ble/test code:'ret=$a' ret="xabcy"
  ble/test '[[ $a == "xabcy" ]]'
  ble/test 'case $a in ("xabcy") true ;; (*) false ;; esac'
  IFS=$' \t\n'

  # BUG bash-3.0..4.3
  #   word splitting happens in here strings.
  a='x y'
  ble/test 'read -r ret <<< $a' ret="x y"
  a='x  y'
  if ((_ble_bash<40400)); then
    ble/test 'read -r ret <<< $a' ret="x y"
  else
    ble/test 'read -r ret <<< $a' ret="x  y"
  fi
  IFS=abc a='xabcy'
  if ((_ble_bash<40400)); then
    ble/test 'read -r ret <<< $a' ret="x   y"
  else
    ble/test 'read -r ret <<< $a' ret="xabcy"
  fi
  IFS=$' \t\n'

  # pathname expansion does not happen
  b='/*'
  ble/test code:'ret=$b' ret="/*"
  ble/test 'case $b in ("/*") true ;; (*) false ;; esac'
  ble/test 'read -r ret <<< $b' ret="/*"
)

# Arithmetic bugs
(
  # BUG bash 3.0..4.1
  #   Lazy evaluation of && doesn't work. Therefore, naive conditional arithmetic recursion is not possible.
  L='0&&L'
  if ((40200<=_ble_bash)); then
    ble/test '((L,1))'
  elif ((30200<=_ble_bash)); then
    # bash 3.2..4.1 bug: infinite recursion
    ble/test '! ((L,1))'
  else
    # bash 3.0..3.1 bug: crashes?
    ble/test '( ! ((L,1)) )'
  fi

  i=0 M='i++,M[i>=10]'
  ble/test '((M,1))'
  ble/test code:'ret=$i' ret=10
)

# Variable bugs
(
  # BUG bash-3.1
  #   a=(""); echo "a${a[*]}b" | cat -A will result in a^?b and a mysterious character will be inserted.
  #   You can do something like echo "a""${a[*]}""b" etc.
  a=("")
  function f1 { ret=$1; }
  if ((30100<=_ble_bash&&_ble_bash<30200)); then
    ble/test 'f1 "a${a[*]}b"' ret=$'a\177b'
    ble/test code:'ret="a${a[*]}b"' ret=$'a\177b'
    ble/test 'case "a${a[*]}b" in ($'\''a\177b'\'') true ;; (*) false ;; esac'
    ble/test 'read -r ret <<< "a${a[*]}b"' ret=$'a\177b'
  else
    ble/test 'f1 "a${a[*]}b"' ret='ab'
    ble/test code:'ret="a${a[*]}b"' ret='ab'
    ble/test 'case "a${a[*]}b" in (ab) true ;; (*) false ;; esac'
    ble/test 'read -r ret <<< "a${a[*]}b"' ret=ab
  fi

  # BUG bash-3.0..3.1
  #   "${var//%d/123}" doesn't work. You can use something like "${var//'%d'/123}".
  var=X%dX%dX
  if ((_ble_bash<30200)); then
    ble/test code:'ret=${var//%d/.}' ret='X%dX%dX'
  else
    ble/test code:'ret=${var//%d/.}' ret='X.X.X'
  fi

  # BUG bash-3.0..3.1
  #   local GLOBIGNORE Then, even after exiting the function, the effect remains during pathname expansion.
  #   (Even if you look at the contents of the variable directly, it looks like there is nothing.) With unset GLOBIGNORE etc.
  #   It will be fixed.
  ble/test/chdir || exit
  touch {a..c}.txt
  function f1 { local GLOBIGNORE='*.txt'; }
  if ((_ble_bash<30200)); then
    ble/test 'f1; echo *' stdout='*'
  else
    ble/test 'f1; echo *' stdout='a.txt b.txt c.txt'
  fi

  # BUG bash-3.0..3.1 (#D2221)
  #   local POSIXLY_CORRECT allows set -o posix to remain in effect even after exiting the function.
  #   Although no variables are defined, [[ -o posix ]], echo "$SHELLOPTS", or actually
  #   If you check the behavior, POSIX mode is enabled. unset -v
  #   Setting POSIXLY_CORRECT fixes it.
  function f1 { local POSIXLY_CORRECT=y; builtin unset -v POSIXLY_CORRECT; }
  set +o posix
  if ((_ble_bash<30200)); then
    ble/test 'f1; [[ -o posix ]]'
  else
    ble/test 'f1; [[ ! -o posix ]]'
  fi
  builtin unset -v POSIXLY_CORRECT
  ble/test '[[ ! -o posix ]]'
  set +o posix

  # BUG bash-3.0..4.3 (#D2221)
  #   local POSIXLY_CORRECT; unset -v POSIXLY_CORRECT in the function
  #   posix mode is enabled.
  function f1 { local POSIXLY_CORRECT; builtin unset -v POSIXLY_CORRECT; [[ ! -o posix ]]; }
  if ((_ble_bash<40400)); then
    ble/test '! f1'
  else
    ble/test 'f1'
  fi
  set +o posix

  # COMPAT bash-5.3+ (#D2221)
  # In Bash 5.3 and later, functions with slashes in their names cannot be called in POSIX mode.
  function f1/sub { return 0; }
  if ((_ble_bash<50300)); then
    ble/test 'set -o posix; f1/sub; ret=$?; set +o posix' ret=0
  else
    ble/test 'set -o posix; f1/sub; ret=$?; set +o posix' ret=127
  fi

  # BUG bash-3.0
  #   It seems that ${#param} is supposed to return the number of bytes rather than the number of characters, but
  #   When I actually try it, it is the number of characters (bash-3.0.22). A patch hit somewhere.
  #   → This seems to have been fixed in bash-3.0.4.
  #
  #   (*${param:ofs:len} is counted by the number of characters if it is 3.0-beta1 or later)
  if ((_ble_bash<30004)); then
    ble/test code:'a=alpha ret=${#a}' ret=3
  else
    ble/test code:'a=alpha ret=${#a}' ret=1
  fi

  # BUG bash-3.0
  #   If you output a variable that includes a newline with declare -p A, the newline will disappear. Example: seemingly correct output
  #   However, "\ + newline" is not an escape for a newline, but a long character.
  #   This is a notation for writing column literals on two lines. In other words, it is ignored.
  #
  #   $ A=$'\n'; declare -p A
  #   | A="\
  #   | "
  builtin unset -v v
  v=$'a\nb'
  if ((_ble_bash<30100)); then
    ble/test code:'declare -p v' stdout=$'declare -- v="a\\\nb"'
  elif ((_ble_bash<50200)); then
    ble/test code:'declare -p v' stdout=$'declare -- v="a\nb"'
  else
    ble/test code:'declare -p v' stdout='declare -- v=$'\''a\nb'\'
  fi

  # BUG bash-3.0 [Ref #D1774]
  #   When you use the form "${...#$'...'}" (#D1774), the expansion result of $'...' is not ...
  #   There will be extra quotation marks, like '...'. Even if I set extquote, the result is
  #   No change.
  builtin unset -v scalar
  if ((_ble_bash<30100)); then
    ble/test code:'ret="[${scalar-$'\''hello'\''}]"' ret="['hello']" # disable=#D1774
  else
    ble/test code:'ret="[${scalar-$'\''hello'\''}]"' ret='[hello]'   # disable=#D1774
  fi
)

# Array bugs
(
  ## @fn ble/test:bash/count-words generated expected [args...]
  function ble/test:bash/count-words {
    local generator=$1
    local expected=$2
    shift 2
    builtin eval -- "b=($generator)"
    ble/test --depth=1 --display-code="$generator (# of words)" code:'ret=${#b[@]}' ret="$expected"
  }

  # BUG bash-4.2..5.1 [Ref #D2352]
  #   The element disappears with a=(""); b=("${a[@]#$empty}"). This is the bash-4.2 version below.
  #   It's probably a bug of the same type as Google. Also, a=(x); b=("${a[@]#x}") also causes the element to disappear.
  #   There is no problem when there are two or more elements.
  empty= nonempty=x
  if ((40200<=_ble_bash&&_ble_bash<50200)); then
    # bash-4.2..5.1 bug: the element vanish
    bugD2352=0
  else
    bugD2352=1
  fi

  a=("")
  ble/test:bash/count-words '"${a[@]#}"'          1           ''
  ble/test:bash/count-words '"${@#}"'             1           ''
  ble/test:bash/count-words '"${a[@]#$empty}"'    "$bugD2352" ''
  ble/test:bash/count-words '"${@#$empty}"'       "$bugD2352" ''
  ble/test:bash/count-words '"${a[@]#$nonempty}"' "$bugD2352" ''
  ble/test:bash/count-words '"${@#$nonempty}"'    "$bugD2352" ''
  a=(x)
  ble/test:bash/count-words '"${a[@]#x}"'         "$bugD2352" 'x'
  ble/test:bash/count-words '"${@#x}"'            "$bugD2352" 'x'
  ble/test:bash/count-words '"${a[@]#$empty}"'    1           'x'
  ble/test:bash/count-words '"${@#$empty}"'       1           'x'
  ble/test:bash/count-words '"${a[@]#$nonempty}"' "$bugD2352" 'x'
  ble/test:bash/count-words '"${@#$nonempty}"'    "$bugD2352" 'x'

  # BUG bash-4.0..4.4 [Ref #D0924]
  #   Local -a x; local -A x will segfault.
  #   ref http://lists.gnu.org/archive/html/bug-bash/2019-02/msg00047.html,
  #   f() { local -a a; local -A a; }; f # segfault with this
  #
  #   - Does not occur if -A is used for an array defined in another scope.
  #   - Even if the scope is the same, you can unset a and then local -A a.
  #   - Doesn't happen globally.
  function f1 { local -a a; local -A a; }
  if ((_ble_bash<40000)); then
    ble/test f1 exit=2
  elif ((_ble_bash<50000)); then
    ble/test '(f1)' exit=139 # SIGSEGV
  else
    ble/test f1 exit=1
  fi

  # BUG bash-3.0..4.4
  #   When concatenating array elements or $* with case words or here strings, IFS says "
  #   " is replaced.
  c=(a b c)
  IFS=x
  if ((_ble_bash<50000)); then
    # bash-3.0..4.4 bug
    ble/test 'case ${c[*]} in ("a b c") true ;; (*) false ;; esac'
    ble/test 'read -r ret <<< ${c[*]}' ret="a b c"
  else
    ble/test 'case ${c[*]} in ("axbxc") true ;; (*) false ;; esac'
    ble/test 'read -r ret <<< ${c[*]}' ret="axbxc"
  fi
  ble/test 'case "${c[*]}" in ("axbxc") true ;; (*) false ;; esac'
  ble/test 'read -r ret <<< "${c[*]}"' ret="axbxc"
  IFS=$' \t\n'

  # BUG bash-3.0 and 4.3 [Ref #D1570]
  #   * "${var[@]/xxx/yyy}" (#D1570) produces empty results for scalar variables.
  #     About ${var[@]//xxx/yyy}, ${var[@]/%/yyy}, ${var[@]/#/yyy} (#D1570)
  #     The same is true.
  #   * "${scalar[@]/xxxx}" (#D1570) will be completely empty. Guaranteed that the variable name is an array
  #     Must have been.
  #   * bash-4.3 has a bug where \001 is added before each character.
  builtin unset -v scalar
  scalar=abcd
  if ((_ble_bash<30100)); then
    ble/test code:'ret=${scalar[@]//[bc]}' ret=''   # disable=#D1570
    ble/test code:'ret=${scalar[*]//[bc]}' ret=''   # disable=#D1570
  elif ((40300<=_ble_bash&&_ble_bash<40400)); then
    ble/test code:'ret=${scalar[@]//[bc]}' ret=$'\001a\001\001\001d' # disable=#D1570
    ble/test code:'ret=${scalar[*]//[bc]}' ret=$'\001a\001\001\001d' # disable=#D1570
  else
    ble/test code:'ret=${scalar[@]//[bc]}' ret='ad' # disable=#D1570
    ble/test code:'ret=${scalar[*]//[bc]}' ret='ad' # disable=#D1570
  fi

  # BUG bash-4.2 [Ref #D2352]
  #   a=(""); b=("${a[@]/#}") causes the element to disappear (disable=#D1570). two or more elements
  #   Sometimes it's fine. There is no problem when the element is a non-empty string. If the string after replacement is finite
  #   There is no problem in that case.
  empty= nonempty=1
  if ((40200<=_ble_bash&&_ble_bash<40300)); then
    # bash-4.2..5.1 bug: the element vanish
    bugD2352=0
  else
    bugD2352=1
  fi
  a=("")
  ble/test:bash/count-words '"${a[@]}"'             1           ''
  # The problem happens with "${a[@]/#}" (disable=#D1570)
  ble/test:bash/count-words '"${a[@]/#}"'           "$bugD2352" '' # disable=#D1570
  ble/test:bash/count-words '"${a[@]/#/}"'          "$bugD2352" '' # disable=#D1570
  ble/test:bash/count-words '"${a[@]/#/$empty}"'    "$bugD2352" '' # disable=#D1570,#D1738
  ble/test:bash/count-words '"${a[@]/#/$nonempty}"' 1           '' # disable=#D1570,#D1738
  ble/test:bash/count-words '"${@/#}"'              "$bugD2352" '' # disable=#D1570
  ble/test:bash/count-words '"${@/#/}"'             "$bugD2352" '' # disable=#D1570
  ble/test:bash/count-words '"${@/#/$empty}"'       "$bugD2352" '' # disable=#D1570,#D1738
  ble/test:bash/count-words '"${@/#/$nonempty}"'    1           '' # disable=#D1570,#D1738
  ble/test:bash/count-words '"${a[0]/#}"'           1           '' # disable=#D1570
  ble/test:bash/count-words '"${a[0]/#/}"'          1           '' # disable=#D1570
  ble/test:bash/count-words '"${a[0]/#/$empty}"'    1           '' # disable=#D1570,#D1738
  ble/test:bash/count-words '"${a[0]/#/$nonempty}"' 1           '' # disable=#D1570,#D1738
  # The same problem also happens with "${a[@]/x}" (disable=#D1570)
  ble/test:bash/count-words '"${a[@]/x}"'           "$bugD2352" '' # disable=#D1570
  ble/test:bash/count-words '"${a[@]/x/}"'          "$bugD2352" '' # disable=#D1570
  ble/test:bash/count-words '"${a[@]/x/$empty}"'    "$bugD2352" '' # disable=#D1570,#D1738
  ble/test:bash/count-words '"${@/x}"'              "$bugD2352" '' # disable=#D1570
  ble/test:bash/count-words '"${@/x/}"'             "$bugD2352" '' # disable=#D1570
  ble/test:bash/count-words '"${@/x/$empty}"'       "$bugD2352" '' # disable=#D1570,#D1738
  ble/test:bash/count-words '"${a[0]/x}"'           1           '' # disable=#D1570
  ble/test:bash/count-words '"${a[0]/x/}"'          1           '' # disable=#D1570
  ble/test:bash/count-words '"${a[0]/x/$empty}"'    1           '' # disable=#D1570,#D1738
  # The problem doesn't happen when there are more than one element.
  a=("" "")
  ble/test:bash/count-words '"${a[@]}"'             2           '' '' # disable=#D1570
  ble/test:bash/count-words '"${a[@]/#}"'           2           '' '' # disable=#D1570
  ble/test:bash/count-words '"${a[@]/#/}"'          2           '' '' # disable=#D1570
  ble/test:bash/count-words '"${a[@]/#/$empty}"'    2           '' '' # disable=#D1570,#D1738
  ble/test:bash/count-words '"${a[@]/#/$nonempty}"' 2           '' '' # disable=#D1570,#D1738
  ble/test:bash/count-words '"${@}"'                2           '' '' # disable=#D1570
  ble/test:bash/count-words '"${@/#}"'              2           '' '' # disable=#D1570
  ble/test:bash/count-words '"${@/#/}"'             2           '' '' # disable=#D1570
  ble/test:bash/count-words '"${@/#/$empty}"'       2           '' '' # disable=#D1570,#D1738
  ble/test:bash/count-words '"${@/#/$nonempty}"'    2           '' '' # disable=#D1570,#D1738

  # BUG bash-3.0..4.2
  #   When concatenating array elements on the right side of an assignment, IFS is replaced with " ".
  #   Working example:
  #     IFS= eval 'value=${arr[*]}'
  #     IFS= eval 'value="${arr[*]}"'
  #     IFS= eval 'local value="${arr[*]}"'
  #   Example that doesn't work (there are spaces in between):
  #     IFS= eval 'local value=${arr[*]}'
  c=(a b c)
  ble/test code:'ret=${c[*]}' ret="a b c"
  ble/test 'case ${c[*]} in ("a b c") true ;; (*) false ;; esac'
  ble/test 'read -r ret <<< ${c[*]}' ret="a b c"
  # ${c[*]} is affected by IFS
  IFS=x
  if ((_ble_bash<40300)); then
    # bash-3.0..4.2 bug
    ble/test code:'ret=${c[*]}' ret="a b c"
  else
    ble/test code:'ret=${c[*]}' ret="axbxc"
  fi
  ble/test code:'ret="${c[*]}"' ret="axbxc"
  IFS=$' \t\n'

  # BUG bash-3.0..4.1
  #   ${#a[*]} returns 1 for variables that are declared but unset.
  #   a[${#a[*}]=value or ble/array#push a value when you push the array in advance.
  #   If you want to declare it, you need to specify -a like local -a a.
  #
  #   [Problem]
  #
  #   bash-4.0, 4.1 (local): If you just use local arr in a function under bash-4.1
  #   ${#arr[*]} becomes 1. After that, even if you set element #1, ${#arr[*]} remains 1.
  #   There is even. Because of this, even if arr[${#arr[*]}]=... it is always assigned only to element #1
  #   It will not be done.
  #
  #   bash-3.0 to 3.2 (declare): In bash-3.2 and below, declare arr is not limited to functions.
  #   Just ${#arr[*]} becomes 1. However, if you set it to element [1], ${#arr[*]}
  #   increases to 2. Therefore, ble/array#push will not fail even though there is an extra empty element.
  #   Yes.
  #
  #   [Solved]
  #
  #   If you run local -a arr, the problem will not occur. *There is also a problem with local arr=() (#D0184)
  #   does not occur, but with this description, the string '()' is assigned in bash-3.0, causing a problem.
  #   There is.
  builtin unset -v arr1 arr2
  local arr1
  local -a arr2
  if ((_ble_bash<40200)); then
    ble/test code:'ret=${#arr1[@]}' ret=1
  else
    ble/test code:'ret=${#arr1[@]}' ret=0
  fi
  ble/test code:'ret=${#arr2[@]}' ret=0

  # BUG bash-3.0..3.2 [Ref #D1241]
  #   The value of ^? or ^A is converted to ^A^? or ^A^A by declare -p.
  a=($'\x7F' $'\x01')
  if ((_ble_bash<40000)); then
    ble/test 'declare -p a' stdout=$'declare -a a=\'([0]="\x01\x01\x01\x7F" [1]="\x01\x01\x01\x01")\'' # '
  elif ((_ble_bash<40400)); then
    ble/test 'declare -p a' stdout=$'declare -a a=\'([0]="\x01\x7F" [1]="\x01\x01")\'' # '
  else
    ble/test 'declare -p a' stdout='declare -a a=([0]=$'\''\177'\'' [1]=$'\''\001'\'')' # disable=#D0525
  fi

  # BUG bash-3.1
  # Even if the called function creates an array with the same name as the one defined in the caller, it will be empty.
  #   > $ function dbg/test2 { local -a hello=(1 2 3); echo "hello=(${hello[*]})";}
  #   > $ function dbg/test1 { local -a hello=(3 2 1); dbg/test2;}
  #   > $ dbg/test1
  #   > hello=()
  #
  #   This seems to have been fixed in bash-3.1-patches/bash31-004.
  function f1 { local -a arr=(b b b); ble/util/print "(${arr[*]})"; }
  function f2 { local -a arr=(a a a); f1; }
  if ((30100<=_ble_bash&&_ble_bash<30104)); then
    ble/test f2 stdout='()'
  else
    ble/test f2 stdout='(b b b)'
  fi

  # BUG bash-3.1
  #   In the first place, bash-3.1 parses function a { local -a alpha=() beta=(); }
  #   Since I can't do it, I can't even start the ble.sh test.
  if ((30100<=_ble_bash&&_ble_bash<30104)); then
    ble/test 'function f1 { local -a alpha=(); local -a beta=(); }'
  else
    ble/test 'function f1 { local -a alpha=() beta=(); }'
  fi

  # BUG bash-3.0..3.1 [Ref #D0182]
  #   ${#arr[n]} returns number of bytes instead of number of characters
  if ((_ble_bash<30200)); then
    ble/test code:'ret=alpha ret=${#ret[0]}' ret=3 # disable=#D0182
  else
    ble/test code:'ret=alpha ret=${#ret[0]}' ret=1 # disable=#D0182
  fi

  # BUG bash-3.0 [Ref #D0184]
  #   local a=(...) or declare a=(...) (#D0184) is the same as a="(...)"
  #   It will be. There is no problem if it is in the form a=().
  declare ret=(1 2 3) # disable=#D0184
  if ((_ble_bash<30100)); then
    ble/test ret='(1 2 3)'
  else
    ble/test ret='1'
  fi

  # BUG bash-3.0 [Ref #D0525]
  #   Until now, I had believed that there was no problem with the form local -a a=(), but apparently local -a
  #   It seems that a=('1 2') (#D0525) has the same meaning as local -a a=(1 2).
  #   a="123 345"; declare -a arr=("$a"); (#D0525) It doesn't work like this.
  #   a="123 345"; declare -a arr; arr=("$a"); You need to do this.
  declare -a ret=("1 2") # disable=#D0525
  if ((_ble_bash<30100)); then
    ble/test ret='1'
  else
    ble/test ret='1 2'
  fi
  v="1 2 3"
  declare -a ret=("$v") # disable=#D0525
  if ((_ble_bash<30100)); then
    ble/test ret='1'
  else
    ble/test ret='1 2 3'
  fi

  # BUG bash-3.0
  #   When IFS is non-default declare -a arr2=("${arr1[@]}") (disable=#D0525)
  #   It also doesn't work properly.
  a=(1 2 3)
  IFS=x
  declare -a a1=("${a[@]}") # disable=#D0525
  a2=("${a[@]}") # disable=#D0525
  IFS=$' \t\n'
  if ((_ble_bash<30100)); then
    ble/test code:'ret=$a1' ret=1x2x3
    ble/test code:'ret=$a2' ret=1
  else
    ble/test code:'ret=$a1' ret=1
    ble/test code:'ret=$a2' ret=1
  fi

  # BUG bash-3.0
  #   When IFS is non-default, split using declare -a arr2=($v) does not work. teenager
  #   Instead, it is separated by spaces.
  IFS=x
  v=1x2x3
  declare -a a1=($v)
  a2=($v)
  if ((_ble_bash<30100)); then
    ble/test code:'ret=$a1' ret=1x2x3
    ble/test code:'ret=$a2' ret=1
  else
    ble/test code:'ret=$a1' ret=1
    ble/test code:'ret=$a2' ret=1
  fi
  v='1 2 3'
  declare -a a1=($v)
  a2=($v)
  if ((_ble_bash<30100)); then
    ble/test code:'ret=$a1' ret=1
    ble/test code:'ret=$a2' ret='1 2 3'
  else
    ble/test code:'ret=$a1' ret='1 2 3'
    ble/test code:'ret=$a2' ret='1 2 3'
  fi
  IFS=$' \t\n'
)

# Other bugs
(
  # BUG bash-3.0..4.0 (3.0..5.2 in non-interactive session)

  # If you put \' inside $'', does history expansion occur inside ''? For example
  # rex='a'$'\'\'''!a' will expand the !a part (9f0644470 OK).
  #
  # Incidentally, if there is no corresponding history, an error message will be displayed in versions 4.1 and below.
  #
  # Note: All versions of 3.0..5.2 and devel are
  # The problem is reproduced in John. The problem does not occur if you specify an interactive session or set +H.
  # Only occurs on 3.0..4.0.
  #
  # Note: Looking back, this item was added to memo.txt in commit 9f064447 (2015-03-08).
  # has been added. However, the corresponding items are not described in memo.txt. #D0206 is near
  # We are discussing slightly different things.
  #
  q=\' line='$'$q'\'$q'!!'$q'\'$q
  code='(builtin history -s histentry; builtin history -p "$line")'
  if ((_ble_bash<30100)); then
    # 3.0 fails in the first place.
    ble/test "$code" stdout=
  elif ((_ble_bash<40100)) || [[ $- != *[iH]* ]]; then
    # Unintentional expansion occurs in non-interactive sessions or 3.1..4.0
    ble/test "$code" stdout="${line//!!/histentry}"
  else
    # expected behavior
    ble/test "$code" stdout="$line"
  fi
  if ((_ble_bash<40100)); then
    ble/test '(set -H; builtin history -c; builtin history -p "$line")' stdout= exit=1
  else
    ble/test '(set -H; builtin history -c; builtin history -p "$line")' stdout="$line"
  fi

  # BUG bash-3.1 and 3.2 [Ref #D0857]
  #   A file descriptor >= 10 cannot be redirected if it is already in use.  In
  #   bash-3.2, we can first close the file descriptor and then perform the
  #   redirect.  In bash-3.1, because of the next bug, one cannot simply close
  #   the file descriptor.  One needs to move the file descriptor to another
  #   number.
  if [[ -d /proc/$$/fd ]] && { ((1)) >/dev/tty; } 2>/dev/null; then
    (
      exec 7>/dev/null 77>/dev/null # disable=#D0857
      exec 7>/dev/tty 77>/dev/tty   # disable=#D0857
      ble/util/getpid
      if ((30100<=_ble_bash&&_ble_bash<40000)); then
        # bug
        ble/test '[[ -t 7 ]]'
        ble/test '[[ ! -t 77 ]]'
      else
        # expected
        ble/test '[[ -t 7 ]]'
        ble/test '[[ -t 77 ]]'
      fi
    )
  fi

  # BUG bash-3.1 [Ref #D2164]
  #   file descriptor >= 10 cannot be closed by exec 77>&-.
  if [[ -d /proc/$$/fd ]] && { ((1)) >/dev/tty; } 2>/dev/null; then
    (
      exec 7>/dev/null 77>/dev/null # disable=#D0857
      exec 7>&- 77>&-               # disable=#D2164
      ble/util/getpid
      if ((30100<=_ble_bash&&_ble_bash<30200)); then
        # bug
        ble/test '[[ ! -e /proc/$BASHPID/fd/7 ]]'
        ble/test '[[ -e /proc/$BASHPID/fd/77 ]]'
      else
        # expected
        ble/test '[[ ! -e /proc/$BASHPID/fd/7 ]]'
        ble/test '[[ ! -e /proc/$BASHPID/fd/77 ]]'
      fi
    )
  fi

  # BUG bash-3.0 [Ref #D1956]
  #   Even if you redirect at the outermost part of the function definition, it will not be redirected. For example,
  #   function func { ls -l /proc/$BASHPID/fd/{0..2}; } <&"$fd0" >&"$fd1"
  #
  #   It seems that this only occurs when the function is called with func REDIRECT &. call
  #   Does this mean that it has been overwritten with the original redirection list? e
  function f1 { ble/util/print hello; } >&"$fd1"
  function f2 { ble/util/print hello >&"$fd1"; }
  function f3 { { ble/util/print hello; } >&"$fd1"; }
  function test1 {
    local fd1=
    ble/fd#alloc fd1 '>&1'
    "$1" >/dev/null & local pid=$!
    wait "$pid"
    ble/fd#close fd1
  }
  if ((_ble_bash<30100)); then
    ble/test 'test1 f1' stdout=
  else
    ble/test 'test1 f1' stdout=hello
  fi
  ble/test 'test1 f2' stdout=hello
  ble/test 'test1 f3' stdout=hello
)

# Quirks
(
  # (#D2123) In all the Bash versions 1.14..5.3, expand_aliases inside
  # "compound-command &" are disabled in interactive sessions.
  shopt -s expand_aliases
  alias e='ble/util/print hello'
  ble/test 'eval "e"' stdout=hello
  ble/test 'true && eval "e"' stdout=hello
  ble/test 'eval "e" & wait' stdout=hello
  if [[ $- == *i* ]]; then
    ble/test '(eval "e") & wait' stdout=
    ble/test '{ eval "e"; } & wait' stdout=
    ble/test 'true && eval "e" & wait' stdout=
  else
    ble/test '(eval "e") & wait' stdout=hello
    ble/test '{ eval "e"; } & wait' stdout=hello
    ble/test 'true && eval "e" & wait' stdout=hello
  fi
  builtin unalias e
)

ble/test/end-section
