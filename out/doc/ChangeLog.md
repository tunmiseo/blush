<!---------------------------------------------------------------------------->
# ble-0.4.0-devel4

2023-04-03... (`#D2030`...) 1a5c451c...

## New features

- Bash 5.3 support
  - syntax: support bash-5.3 function subst `${ list; }` `#2045` 0906fd95 71272a4b
  - decode(bind): support the colonless form of `bind -x` of bash-5.3 `#D2106` 78d7d2e3
  - util(joblist): fix job detection in Bash 5.3 `#D2157` 6d835818
  - util(joblist): exclude more foreground dead jobs in Bash 5.3 `#D2174` 8a321424
  - global: work around function names with slashes in Bash 5.3 POSIX mode `#D2221` 48c7bbee
    - main: fix workaround for the posix vi-insert <kbd>C-i</kbd> binding in `bash <= 5.0` (reported by vasi786) `#D2243` 8e7ed824
  - main: update the startup message for debug versions of Bash `#D2222` afb29073
    - main: shorten the startup message for debug versions `#D2241` 0bc8610a
    - main: suppress `--bash-debug-version` in `ble-reload` `#D2275` ec422115
    - main (`ble/base/check-bash-debug-version`): print messages to stderr `#D2239` 8904d588
  - decode(read-user-settings): read the colonless form of `bind -x` of Bash 5.3 `#D2233` 62b23b69
  - progcomp: use Bash 5.3 `compgen -V` for completions with newlines (motivated by RBT22) `#D2253` 0e8c388a
    - progcomp: fix a bug that `x` at the end of the last completion is trimmed `#D2308` d9faeb37
  - main: fix attach failure with `--attach=prompt` in Bash 5.3 POSIX mode `#D2267` 49845707
    - syntax: fix a problem that `$_` is not preserved `#D2269` e053690d
  - keymap/vi: support bash-5.3 readline bindable function `bash-vi-complete` in `vi_nmap` `#D2305` 55e0ee71
  - syntax: parse function name as a word `#D2360` 72364a51
  - util (`ble/builtin/trap/invoke.sandbox`): set `BASH_TRAPSIG` `#D2364` 858630e5
- bgproc: support opts `kill9-timeout=TIMEOUT` `#D2034` 3ab41652
- progcomp(cd): change display name and support mandb desc (requested by EmilySeville7cfg) `#D2039` 74402098
- cmdspec: add completion options for builtins (motivated by EmilySeville7cfg) `#D2040` 9bd24691
- complete: support `bleopt complete_requote_threshold` (requested by rauldipeas) `#2048` bb7e118e
- menu (`ble/widget/menu/append-arg`): add option `bell` (motivated by bkerin) `#D2066` 3f31be18 bbf3fed3
- make: support `make uninstall` `#D2068` a39a4a89
- edit: support `bleopt {edit_marker{,_error},exec_exit_mark}` `#D2079` e4e1c874
- edit: add widget `zap-to-char` `#D2082` ce7ce403
- keymap/vi: split widget `text-object` into `text-object-{inner,outer}` (requested by Darukutsu) `#D2093` 11cf118a
- keymap/vi: implement text-object in xmap for brackets (requested by Darukutsu) `#D2095` 7d80167c
- util: support `ble-import -C callback` (motivated by Dominiquini) `#D2102` 0fdbe3b0
- mandb: look for git subcommands (motivated by bkerin) `#D2112` 9641c3b8
- edit (`display-shell-version`): show the `atuin` version `#D2124` 9045fb87
- complete: add widgets `auto_complete/insert-?word` (requested by Tommimon) `#D2127` 0c4b6772
  - auto-complete: insert word only when the cursor is at the end of line `#D2212` b72d78a9
- edit: add widgets `execute-named-command` and `history-goto` `#D2144` aa92b42a
- keymap/vi_nmap: support `shell-expand-line` `#D2145` aa92b42a
  - decode: fix quoting of `WIDGET` and `LASTWIDGET` (reported by 3ximus) `#D2205` 1313390b
- main: support `bash ble.sh --install` `#D2169` 986d26a3 3801a87e
- util(stty): support `bleopt term_stty_restore` (requested by TheFantasticWarrior) `#D2170` e64b02b7
  - util: update workaround of Bash 5.2 `checkwinsize` for `term_stty_restore` (reported by TheFantasticWarrior) `#D2184` ef8272a4
- magic expansions
  - edit: support `bleopt edit_magic_accept` (requested by pl643, bkerin) `#D2175` 3e9d8907
  - edit: support `bleopt edit_magic_accept=verify-syntax` `#D2178` ac84c153
  - edit: support `bleopt edit_magic_{expand,accept}=autocd` (motivated by Jai-JAP) `#D2187` b6344b3b
  - edit (`edit_magic_{accept,expand}`): support user-defined expansion (motivated by Jai-JAP) `#D2395` aa5bd676 eb349ea6
  - complete: apply `alias`/`autocd` expansions globally on `magic-accept` (motivated by Jai-JAP) `#D2399` a34b177a e7dbf375 b99cadb4
- main: support shell variable `BLE_VER` `#D2177` a12dedab
- util(bleopt, blehook, ble-face): support wildcards `*` and `?` and change `@` to match an empty string `#D2182` bf595293
- complete(cd): complete variable names for `cdable_vars` `#D2190` 10527901
- sabbrev: support suffix sabbrev to emulate Zsh's suffix aliases `#D2191` d66e05d2
  - sabbrev: fix bugs in sabbrev matching and positioning (reported by dgudim) `#D2198` 70a325f9
- complete: support `ble-face menu_desc_{default,type,quote}` (requested by romaia) `#D2193` b3e7237e
- complete: support `bleopt complete_menu_complete_opts=hidden` and menu-style switching (requested by CamRatliff) `#D2199` 16ff7df7
- syntax: support `ln=target` in `bleopt filename_ls_colors` (requested by akhilkedia) `#D2213` e169e31d
- syntax: support arbitrary suffixes in `bleopt filename_ls_colors` `#D2213` e169e31d
- util(vbell): support `bleopt vbell_align=panel` (requested by bb010g) `#D2228` fe85e0dd
- highlight: reflect the top-level positional parameters `#D2246` f08e8f08
- color: adjust default fg values in faces and add `bleopt color_scheme` (requested by mattmc3) `#D2248` e4cce0ea 5f5554a8 `#D2258` d6a38c43 `#D2263` 0aa66b25
  - syntax(highlight/vartype): add `ble-face varname_new` `#D2272` 5bfc0ae5
  - syntax(highlight/vartype): check variable existence for `${var?...}` `#D2273` 5bfc0ae5
- highlight: add `bleopt highlight_eval_word_limit` (motivated by orionalves) `#D2256` 6833bdf8
- progcomp: support `complete -E` `#D2257` ffac4205
  - progcomp: fix `complete -I` for empty words (reported by blackteahamburger) `#D2262` 9270b529
- make: support make variable `USE_DOC=no` (requested by blackteahamburger) `#D2260` 40fe9c95 134a38d1 c5caedf7
  - make: fix condition for the `INSDIR_LICENSE` rule (reported by Jai-JAP) `#D2260` 5a8dcb4b
- edit (`ble/widget/display-shell-version`): print shell options `#D2261` 70b89e5e ed5d451b
- edit: enable `BLE_PIPESTATUS` and `PIPESTATUS` in `PROMPT_COMMAND` and prompts (requested by mattmc3) `#D2276` 27888830
- nsearch: support `action={load-{line,command},insert{,-line}}` (motivated by vaab) `#D2286` 32f290df
- complete: support completion for `execute-named-command` `#D2288` 4fee44e6
- complete: support `ble-face menu_complete_{match,selected}` (requested by simonLeary42) `#D2291` 31f264ad
- edit: support `bleopt history_default_point={preserve,begin,end,near,far,{beginning,end}-of-line,preserve-column,...}` (requested by miltieIV2) `#D2297` 37291ff1
  - edit: support `bleopt history_default_point=auto` (reported by miltieIV2) `#D2297` 2a3351e7
  - color: fix a bug that reverse rendition vanishes `#D2318` 209b4da0
- edit: support `bleopt undo_point={first,last,near,auto}` `#D2303` 99af0ece
- keymap/vi: add readline-compatible widgets for `vi_imap` and `vi_nmap` (requested by excited-bore) `#D2304` d7ec488a
- edit: support bash-5.2 readline bindable function `vi-edit-and-execute-command` `#D2306` c395eb33 cc47acc2
- edit: support readline bindable function `paste-from-clipboard` in more environments `#D2307` 17646524
  - edit (`paste-from-clipboard`): fix wrong command names to freeze `#D2344` 262baf0e
- keymap/vi: support `:marks` `#D2320` 01182d3b
- cmap: add <kbd>dsr0</kbd> for <kbd>ESC [ 0 n</kbd> `#D2338` adf53ed3
- decode: record timeout in keyboard macro `#D2343` e8045741
- edit: add keybindings <kbd>C-up</kbd> and <kbd>C-down</kbd> for history movements (requested by DJCrashdummy) `#D2370` d7afee00
- util (`bleopt`): support `bleopt var+=value var-=value` for colon-separated lists `#D2381` 27816536
- complete: support `bleopt complete_auto_complete_opts=syntax-unique` (motivated by David0tt) `#D2382` 2f564e63
- complete: support `bleopt complete_auto_complete_opts={syntax,history}-disabled` (motivated by Diabochi) `#D2383` 2f564e63
- complete: support `bleopt complete_auto_complete_opts=suppress-inside-{line,word}:syntax-suppress-{ambiguous,empty}` (requested by pallaswept) `#D2384` 2f564e63
- util (`bleopt`, etc.): highlight shell quoting by backslash `#D2388` 7cf13879
- complete: introduce more stages to ambiguous pathname completions (reported by xuhdev) `#D2397` abb93e21

## Changes

- edit: clear character highlighting for overwriting mode (requested by mozirilla213) `#D2052` 1afc616b
- history (`ble/builtin/history -w`): write file even without any new entries (requested by Jai-JAP) `#D2053` c78e5c9f
- auto-complete: overwrite subsequent characters with self-insert in overwrite mode `#D2059` 7044b2db
- complete: move face definitions `menu_filter_*` to `core-complete-def.sh` `#D2060` af022266
- make: add `INSDIR_LICENSE` for install location of licenses (reported by willemw) `#D2064` d39998f0 acf3b091
- prompt: show prompt ruler after markers (motivated by U-Labs) `#D2067` e4a90378
- complete: suffix a space to non-filenames with `compopt -o filenames` (reported by Dominiquini) `#D2096` aef8927f
- edit: distinguish space and delimiters in `cword` and `eword` `#D2121` 4f453710
- prompt: update status line on face change (motivated by Vosjedev) `#D2134` f3e7e386
- decode: specify the default keymap for the keymap load hooks `#D2141` 4a34ccf2
- progcomp(compopt): refactor the completion option `ble/{no- => }default` `#D2155` 51f9f4f6
- main: export `BLE_SESSION_ID` `#D2188` 5871fea2
- menu-complete: adjust cursor position with `insert-selection` disabled (reported by gvlassis) `#D2206` 341179d1
- decode (`ble-bind`): do not convert registered C0 (motivated by gvlassis) `#D2210` cbf87fdc
  - decode: process <kbd>@ESC</kbd> generated by CSI sequence (reported by gvlassis, 10b14224cc, lokxii) `#D2214` 365101cf
- decode (`ble-bind`): support combined option arguments of the forms `--long=OPTARG` and `-kOPTARG` `#D2211` 1b16d399
- canvas: use `_ble_term_invis` to hide characters used to determine char-width modes (requested by tessus) `#D2223` 8bb302e0
  - canvas: hide cursor during char-width detection (requested by tessus) `#D2232` 0ff29b26
- exec: refine the elapsed time resolution `#D2249` 67548656 713c4215
- highlight (`ble/syntax/highlight/vartype`): reference the saved states of variables `#D2268` 063249b4
- complete: attempt pathname expansions of incomplete pattern for `COMPV` (reported by mcepl) `#D2278` 6a426954
- make: save commit id and branch name with `git archive` (requested by LecrisUT, blackteahamburger) `#D2290` 31f264ad
- edit: revert edits with widget `discard-line` (reported by dezza) `#D2301` 3b2b4b81
- vi_nmap: fix cursor position after <kbd>C-o</kbd> `#D2302` c106239a
- decode (`ble-bind`): initialize specified keymaps (motivated by quantumfrost) `#D2324` 66e450d7
- edit (`display-shell-version`): show `(integration: off)` for plugins with integration turned off `#D2330` 2ff03257
  - edit (`display-shell-version`): fix a bug that `WARNING` is never shown `#D2347` 8dfaa4e8
- decode (`ble/debug/keylog`): exclude duplicate characters due to backtracking `#D2332` 355d1dc0 0379e034
- util (`ble/string#quote-word`): highlight backslash escapes `#D2393` 36bedfbc
- util (`ble/function#call-top`): allow calling from impl function of pushed logic `#D2403` 4706cb29

## Fixes

- util (`conditional-sync`): fix bugs when `pid=PID` is specified (contributed by bkerin) `#D2031` 09f5cec2 `#D2034` 09f5cec2
  - util (`conditional-sync`): fix wrong command grouping overwriting `pid=PID` (reported by dragonde, georglauterbach) `#D2122`
- bgproc: return status of bgproc process `#D2036` 887d92dd
- mandb: replace TAB with 4 spaces before removing control characters (reported by EmilySeville7cfg) `#D2038` 313cfb25
- menu(desc): fix a bug that prefix is not shown with menu-filter `#D2039` e92b78d6
- progcomp: make option unique after applying mandb description `#D2042` 308ceeed
- util (`ble/util/idle`): fix an infinite loop `#D2043` 5f4c0afd
- main: fix `--inputrc=TYPE` not applied on startup `#D2044` 1b15b851 0adce7c9
- stty: suggest `stty sane` after exiting from bash >= 5.2 to non-ble session `#D2046` b57ab2d6
- util (`ble/builtin/readonly`): adjust bash options (reported by dongxi8) `#D2050` 1f3cbc01
- history (`ble/builtin/history`): fix error message on the empty `HISTFILE` `#D2061` a2e2c4b6
- complete: exit auto-complete mode on complete self-insert `#D2075` 2783d3d0
- complete: fix error messages on empty command names `#D2085` dab8dd04
- complete: fix parsing the output of `complete -p` in bash-5.2 (reported by maheis) `#D2088` a7eb5d04
- make: specify bash to search the awk path using `type -p` (reported by rashil2000) `#D2089` 26826354
- keymap/vi: fix the behavior of text-object for quotes in xmap (reported by Darukutsu) `#D2094` 5f9a44ec
- edit(redo): fix broken common prefix/suffix determination (reported by Darukutsu) `#D2098` c920ea65
- keymap/vi: improve text-object in omap for brackets (reported by Darukutsu) `#D2100` d1a1d538
- decode(bind): fix command-line argument parsing `#D2107` 57a13c3c
- edit(gexec): fix a bug that `LINENO` is vanishing `#D2108` b5776596
- mandb: fix extraction of option description in format 5 (reported by bkerin) `#D2110` 90a992cc
- decode: fix handling of @ESC in quoted-insert `#D2119` 0bbc3639
- syntax: save stat after command name for consistent completion-context `#D2126` 50d6f1bb
- term: fix control sequences for hiding cursor (reported by n87) `#D2130` f9b9aea8
  - term: fix `_ble_term_rmcivis` for `TERM=linux` `#D2197` 56765251
- highlight: fix inconsistent tab width in plain layer (reported by dgudim) `#D2132` f9072c40
- decode: consume incomplete keyseq in macros `#D2137` 27e6309e
- keymap/vi: fix conflicting binding to <kbd>C-RET</kbd> in `vi_imap` `#D2146` 0b18f3c2
- decode: force updating cache for <kbd>@ESC</kbd> `#D2148` 6154d71c
- progcomp(compopt): support printing the current options (reported by bkerin) `#D2154` 51f9f4f6
- progcomp(compopt): properly handle dynamically specified `plusdirs` `#D2156` 51f9f4f6
- edit: fix `BLE_COMMAND_ID` starting from `2` `#D2160` 8f4bf62a
- util(vbell): fix previous vbell not fully cleared `#D2181` 6c740a94
- decode(rlfunc): fix widget name `vi-command/edit-and-execute-{line => command}` (fixed by alexandregv) 6aa8ba67
- util(ble/util/idle.push): fix uninitialized `ble/util/idle.clock` (reported by Anyborr) `#D2189` 83ceb124
- prompt: clear list for the cylic dependency detection (reported by micimize, neilbags) `#D2200` 61968497 00cae745b
- util.hook: fix user DEBUG trap not executed at the top-level context `#D2202` 828fcfc1
- keymap/vi(relative-line.impl): fix uninitialized variable `nmove` `#D2203` 4268650d
- edit: render the final prompt before updating command history (motivated by pallaswept) `#D2207` 911a4051
  - debug: support `bleopt debug_profiler_opts=tree` `#D2216` a453f373
  - edit: fix leftover region after command execution `#D2247` 75c4a848
- keymap/vi: fix <kbd>C-w</kbd> not saving the word into kill ring `#D2208` aa7ca45d
- edit: fix standard streams in `EXIT` trap with `ble/widget/exit` `#D2217` 89f0dab8
  - edit: fix regressions of vbell and `ble/builtin/exit` in Bash 3.2 `#D2265` f5955d5f
- util(`ble/fd#cloexec`): check `fdflags` compatibility to avoid crash `#D2227` c3b3aaf8
- util(`ble/function#evaldef`): suppress alias expansions (reported by 103sbavert) `#D2240` 51e762fe
  - main: fix a bug that `_ble_bash` is missing (reported by tessus and Knusper) `#D2242` bb2dae6e a9b962d2 9eb1fee7
- mandb: fix incorrect use of `groff` in place of `nroff` `#D2245` e0ffc418
- edit: fix fd broken by ble-attach of new session in user space (reported by JohEngstrom) `#D2271` 49f97618 670c7ea0
- util (`ble-import`): do not specify arguments to `-C callback` `#D2277` 4f0e94a2
- main: fix issues with `ble/bin/awk` (reported by devidw) `#D2292` b0a7adcb
- util (`ble/path#remove-glob`): fix a bug that `*` matches and removes multiple paths `#D2310` fd518d24
- decode (`bind`): print the filename and line in error messages (motivated by excited-bore) `#D2311` 89c69077
- util: fix the race condition of `ble/util/idle.clock` and the `TMOUT` initialization (reported by Anyborr, georglauterbach) `#D2314` 154386de
- util (`ble/util/save-vars`): support saving sparse arrays to preserve undos and marks `#D2319` 486314c5
- main (`connect_tty`): do not reject `connect_tty=inherit` by the initial check of `ble.pp` `#D2335` d6d69dad
- decode: clear info panel when cmap cache is updated before attaching `#D2340` d7a16347
- edit (`display-shell-version`): fix a bug that `contrib/integration/bash-preexec` is not detected `#D2347` 8dfaa4e8
- util (`bleopt`): fix a bug that previous match result for `<pattern>=` affects `var:=` `#D2352` 8bea90d1
  - util (`ble/string#quote-words`): correct the comparison operator (fixup 8bea90d1) (contributed by anoriqq)
- syntax: fix a bug that the completion does not start with `<<[TAB]` `#D2354` 94109ea7
- syntax: fix infinite loop with `case a in \^J` `#D2361` 173ec27f
- util (`ble/util/writearray`): fix a bug in use of gensub in gawk (reported by allenap, LeonardoMor, aaronjamt, ionesculiviucristian, Gabryx64) `#D2368`
- complete: fix a bug that `mandb` record is generated as completions (reported by allenap) `#D2369` f1ccf771
- stty: avoid adjusting the `stty` state if it has never been modified (reported by LEI) `#D2376` edb21da9
- main: fix the initialization order of `ble/bin/awk` (contributed by yecho) `github#613` 8060b7ad
- util (`ble/util/load-standard-builtin`): actually load from `$loadable_path` (fixup 044c016a) (contributed by xarblu) `github#611` 52c38977
- edit: run `bleopt editor` with `eval` `#D2380` eff10c4b
- complete: fix extra quoting of requote with incomplete word `#D2386` 8028fa45
- cmdspec (`declare/chroma`): fix a bug of evaluating global variable `d` (reported by LeonardoMor) `#D2387` 57ad2bf5
- util (`ble/function#advice`): fix `-f` doing the opposite (reported by Funeralsawa) `#D2401` 801cc1c8
- make: fix a race condition (reported by sanvila) `#2406` xxxxxxxx
- syntax (completion-context): fix an infinite loop caused by nested braces (fixed by dlyongemallo) `#D2407` xxxxxxxx

## Compatibility

- Terminal detection
  - util: detect Zellij heuristically `#D2219` 86034398
  - term: detect iTerm2 `#D2224` da6e71db
  - util: update the iTerm2 detection `#D2331` dde63fa3
  - util: update the VTE detection `#D2335` 3b4cdf2e
- main: check `nawk` version explicitly `#D2037` 0ff7bca1
- mandb: inject in bash-completion-2.12 interfaces `#D2041` dabc8553
- complete: determine comp prefix from `COMPS` when `ble/syntax-raw` is specified (reported by teutat3s) `#D2049` f16c0d80
- syntax: allow double-quotes in `$(())` in bash-4.4 (requested by mozirilla213) `#D2051` 611c1d93
- syntax: support version-dependent arithmetic backslash `#D2051` 611c1d93
- util: work around mawk 1.3.3-20090705 regex (reported by dongxi8, Frezrik) `#D2055` 4089c4e1
- complete: update a workaround for cobra-1.5.0 (reported by 3ximus) `#D2057` a24435d3
- make: work around ecryptfs bug (reported by juanejot) `#D2058` 969a763e dc0cdb30
- edit: update mc-4.8.29 integration (reported by mooreye) `#D2062` 2c4194a2 68c5c5c4
- make: work around `make-3.81` bug of pattern rules `#D2065` f7ec170b
- decode: work around `convert-meta on` in bash >= 5.2 with broken locale (reported by 3ximus) `#D2069` 226f9718
- canvas: adjust GraphemeClusterBreak of hankaku-kana voiced marks `#D2077` 31d168cc
- canvas: update tables and grapheme clusters for Unicode 15.1.0 `#D2078` 503bb38b 9d84b424 9d84b424
- complete: use conditional-sync for cobraV2 completions (reported by sebhoss) `#D2084` 595f905b
- term: add workarounds for `eterm` `#D2087` a643f0ea
- global: adjust bash options for utilities outside the ble context (motivated by jkemp814) `#D2092` 6b144de7
- decode,syntax: quote `$#` in arguments properly `#D2097` 40a625d3
- global: work around case-interleaving collation (reported by dongxi8) `#D2103` a3b94bb3
- nsearch: set `immediate-accept` for `empty=emulate-readline` (reported by blackteahamburger) `#D2104` 870ecef7
- decode, vi_digraph: trim CR of text resources in MSYS `#D2105` 6f4badf4
- progcomp: conditionally suffix space for git completion (reported by bkerin) `#D2111` 2c7cca2f
- main: fix initialization errors with `set -u` `#D2116` b503887a
- progcomp: work around slow `make` completion in large repository (reported by blackteahamburger) `#D2117` 5f3a0010
- util(TRAPEXIT): fix condition for `stty sane` in Cygwin `#D2118` a7f604e1
- progcomp: fix the detection of the zoxide completion (reported by 6801318d8d) `#D2120` 29cd8f10
- progcomp: pass original command path to completion functions (reported by REmerald) `#D2125` 0cf0383a
- main: work around nRF Connect initialization (requested by liyafe1997) `#D2129` 2df3b109
- main(unload): redirect streams to work around trap `EXIT` in bash-5.2 (reported by ragnarov) `#D2142` 38a8d571
- complete: call the `docker` command through `ble/util/conditional-sync` `#D2150` 6c3f824a
- util,complete: work around regex `/=.../` failing in Solaris nawk `#D2162` 46fdf44a
- main: fix issues in MSYS1 `#D2163` 5f0b88fb
- util: work around bash-3.1 bug that `10>&-` fails to close the fd `#D2164` b5938192
- decode: fix the problem that key always timed out in bash-3 `#D2173` 0b176e76
- term: adjust the result of `tput clear` for `ncurses >= 6.1` (reported by cmndrsp0ck) `#D2185` 18dd51ab
- main: work around WSL's permission issue on `/run/user/1000` (reported by antonioetv and geoffreyvanwyk) `#D2195` fb826ab6
- decode: exclude `/etc/inputrc` in SUSE as well as in openSUSE (reported by Anyborr) `#D2220` 63be48df
- mandb: support man page format of `rg` (requested by pallaswept) `#D2225` 063bf66b
- mandb: restore ASCII hyphens from Unicode hyphens before analysis (reported by pallaswept) `#D2230` f160b8f0
- main: work around the issue WSL clears `/tmp` after Bash starts (reported by LeonardoMor) `#D2235` fcbf1ed0
- decode(`ble/builtin/bind`): support single quotes in the macro/command strings `#D2236` 2f90120e
- mandb: process less formatting sequences in parsing `--help` `#D2244` 60d36ba5
- mandb: hook into bash-completion's `_comp_command_offset` `#D2255` cbcce625
- canvas: update tables for Unicode 16.0.0 `#D2283` 5b43ca3f 25a10a6f
- complete: work around `mawk <= 1.3.4-20230525` type-inference bug (reported by KaKi87) `#D2295` 546499b5
- main: work around macOS sed (reported by Mossop) `#D2298` a16aa594
- main: delay attaching in kitty, Ghostty, and VS Code Terminal `#D2215` 430a1746
  - main: update workaround for Ghostty (reported by odili) `#D2322` 4338bbf7
- edit: adjust cursor position after `bind -x` in vi_nmap (requested by miltieIV2) `#D2317` 36ab934f
- progcomp: update workaround for the dnf completion (reported by msr8) `#D2321` 2a0c6ba6
- global: check `LC_COLLATE=C` for range expressions `#D2326` f507a1bc
- decode: fix unrecoginized <kbd>ESC O A</kbd> in `4.0 <= bash < 5.0` `#D2333` 6f4d0401
- decode: verify cache consistency by embedded hash (reported by teutat3s, bigbruno, giggio, erfan-star-1999) `#D2345` e63f6f67
- history: work around readonly `HISTSIZE` (reported by seefood) `#D2346` 2d55928a
- main: workaround coreutils `stty` in macOS (reported by EmilyGraceSeville7cf, sshresthaEG, syuraj, seefood, arc279) `#D2348` cdda9f9b
- main (`ble/bin#freeze-utility-path`): use `command` to call the command `#D2349` df6a4dad
  - main: fix the list of missing POSIX utilities in the error message (reported by LecrisUT) `#D2372` 5de739ef
- util (`ble/array#fill-range`): work around bash-5.2 array bug for wrong syntax highlighting `#D2352` 8bea90d1
  - complete: fix stray `}` after the completion prefix (fixup 8bea90d1) (reported by cmndrsp0ck) `#D2359` c6bcb824
- util (`ble/util/load-standard-builtins`): extend search paths `#D2357` 044c016a
- canvas: avoid using <kbd>DL</kbd> at the top to clear lines (requeted by u/JustABro_2321 aka AB-boi) `#D2358` f6a3a116
- edit: fix bash-3.2 problems of receiving <kbd>C-d</kbd> through `SIGUSR1` `#D2365` 38767afe
- main: update messages for broken locale and environment `#D2370` ea1e547b
- decode (`ble/builtin/bind`): suppress `builtin bind -x` with more-than-2-byte keyseq `#D2378` 41ee9aaa
- decode (`ble/builtin/bind`): treat the last `\e` as an isolated ESC (reported by sharpchen) `#D2385` cafef0c6
- main (`ble/bin/awk`): work around `gawk-5.4.0` bug for `gensub` back-references (reported by 0xhtml, raeraex2, l0042158) `#D2394` 40cc5766
- mandb: support the man-page format of `docker` (reported by NecRaul) `#D2398` a34b177a
- msys: work around `OSTYPE=cygwin` in msys-2.0 `#D2404` e9bef3c0
- github: update the version of `actions/checkout` `#D2405` xxxxxxxx

## Contrib

- histdb
  - fix(histdb): show error message only when bgproc crashed `#D2036` 887d92dd
  - util: add `ble/util/{time,timeval,mktime}` `#D2133` 34a886fe
  - histdb: suppress outputs from `PRAGMA quick_check;` `#D2147` 6154d71c
  - histdb: fix variable leak of `ret` `#D2152` 98a2ae15
  - util: fix `ble/util/time` in `bash < 4.2` `#D2161` 623dba91
  - histdb: support subcommands `#D2167` 4d7dd1ee
  - histdb: support `top`, `stats`, `calendar`, and `week` `#D2167` 4d7dd1ee
  - histdb: unify the color palette selection `#D2167` 4d7dd1ee
  - histdb: fix the seasonal default palette names `#D2289` 4fee44e6
  - histdb: fix the error with missing current working directory `#D2323` 98985f38
- contrib/fzf-git: update to be consistent with the upstream (motivated by arnoldmashava) `#D2054` c78e5c9f
- contrib/layer/pattern: add `{pattern}` layer `#D2074` 449d92ca
- contrib/fzf-git: fix unsupported command modes (reported by dgudim) `#D2083` ba2b8865
- contrib/bash-preexec: support the latest version of `bash-preexec` (reported by mcarans) `#D2128` 50af4d9c
- contrib/config/execmark: output error status through `ble/canvas/trace` `#D2136` 64cdcd01
- contrib/airline: remove dummy faces (reported by alexalekseyenko) `#D2204` 59787ee5
- contrib/airline: update themes `#D2204` 59787ee5
- contrib/fzf-git: fix unadjusted terminal states in calling `fzf` (reported by tessus) `#D2237` b154058a
- contrib/bash-preexec: support `__bp_set_ret_value` (requested by Comnenus) `#D2238` b154058a
- contrib/colorglass: fix fixed-point round `#D2239` b154058a
- contrib: add `config/github48{1,3}` for elapsed-mark examples (motivated by paulzzy, TheFantasticWarrior) `#D2249` 67548656 ed5d451b
- contrib: add `integration/fzf-menu` (motivated by pallaswept) `#D2251` ad6f58b7 `#D2259` 5b9d9ab3 `#D2402` eb349ea6
- contrib/integration/fzf-completion: add `ble/widget/fzf-complete` (motivated by 3ximus) `#D2252` ad6f58b7
- contrib/colorglass:  color: import themes from `Gogh-Co/Gogh` (motivated by d4rkb4sh8) `#D2274` d2eb75b5
- contrib/integration/fzf-completion: suppress unexpected quoting by compgen in dynamic completions (reported by mcepl) `#D2284` 32f290df
- contrib/integration/fzf-initialize: use `fzf --bash` when shell integration files are not found (motivated by louiss0) `#D2285` 32f290df
  - integration/fzf-initialize: (reported by 3ximus) `#D2285` a36d13ce
- config: add `github499-append-to-last-modified` (motivated by vaab) `#D2286` 32f290df
- integration: add `skim` integration for completion (reported by cmm) `#D2287` a36d13ce
- integration/zoxide: fix the problem of unquoted filenames (reported by tessus) `#D2216` 430a1746
- integration/{bash,fzf,skim}-completion: adjust dynamically loaded completion functions (motivated by tessus) `#D2327` 788dfd15
- integration/fzf: suppress dynamic binding `#D2350` e9d5ca26
- integration/bash-completion (`_comp_command_offset`): perform fallback completion based on the given context (motivated by Jai-JAP) `#D2377` 2ef5e483
- contrib: add `readline` (motivated by thoughtsunificator) `#D2379` a985559a
- contrib: add `alias-tips` (contributed by xuhdev) `#D2396` ac6c003f
- integration/bash-completion: check cancellation in the post process of the dnf completion (reported by xuhdev) `#D2400` 801cc1c8

## Documentation

- docs(CONTRIBUTING): add styleguide (motivated by bkerin) `#D2056` 44cf6756
- docs(README): fix dead links to blerc.template (fixed by weskeiser) e0f3ac28
- github: add FUNDING `#D2080` 3f133936
- blerc: describe keybinding to accept autosuggestion by TAB (motivated by TehFunkWagnalls) `#D2090` cd069860
- docs: apply Grammarly and fix typos `#D2099` 8b3f6f8c
- docs(README): add sabbrev example for named directories `#D2115` a9a21a0e
- docs(README): note `bleopt prompt_command_changes_layout=1` `#D2196` 208eaa9d
- docs(README): move disclaimers to a later section `#D2250` ad6f58b7
- README: use `[[ ! ${BLE_VERSION-} ]] || ble-attach` `#D2264` ed11901a
- github: update GitHub issue templates `#D2294` aa396f60
- memo: fix syntax error in the testing code for #D1779 (reported by andychu) `#D2329` 8c387422
- github: fix URLs in the nightly description (reported by TheFozid) `#D2373` 97c6caea
- history: include `HISTFILE` in the invalid timestamp mesasge (motivated by Strykar) `#D2374` 5c088fe7
- README: clarify small things `#D2379` a985559a
  - workflows: show date on the nightly page
  - README: clarify fzf compat issues
  - README: link the sabbrev section in Manual
  - README: clarify that blerc.template is prepared for the same version

## Test

- test(bash): fix condition for bash bug of history expansion `#D2071` aacf1462
- test(main): fix delimiter of `MSYS` in adding `winsymlinks` `#D2071` aacf1462
- test(util,vi): adjust `ble/util/is-stdin-ready` while testing `#D2105` 23a05827 6f4badf4
- test(vi): suppress warnings for non-interactive sessions `#D2113` b8b7ba0c
- test(bash,util): fix tests in interactive session `#D2123` 06ad3a6c
- test(vi): fix broken states after test `#D2123` 06ad3a6c
- test(bash): fix test cases for history expansion `#D2131` 838b4652
- test(bash): add tests for bash array bugs `#D2149` 6154d71c
- github/workflows: update versions of GitHub Actions `#D2186` 0c42c8bd 433ac7c2
- test: skip tests on `ble/test/chdir` failure `#D2234` 467ec48b

## Internal changes

- refactor: move files `{keymap/ => lib/keymap.}*` f4c973b8
- global: fix coding style `#D2072` bdcecbbf
- memo: add recent configs and create directories `#D2073` 99cb5e81
- highlight: generalize `region` layer `#D2074` 449d92ca
- keymap/vi: integrate vi tests into the test framework `#D2101` d16b8438
- global(leakvar): fix variable leak `#D2114` d3e1232d
- make(scan): apply builtin checks to `contrib` `#D2135` 2f16d985
  - contrib/fzf-git: do not use `ble/util/print` in a script mode (reported by dgudim) `#D2166` 8f0dfe9b
- decode: change Isolated ESC to U+07FC `#D2138` 82bfa665
- edit: introduce `selection` keymap for more flexible shift selection `#D2139` 2cac11ad
  - edit: fix a regression that delete-selection does not work (reported by cmndrsp0ck) `#D2151` 98a2ae15
- util: support `bleopt connect_tty` `#D2140` f940696f
  - util: support `ble/fd#add-cloexec` and add `O_CLOEXEC` by default `#D2158` 785267e1
  - util: fix error of bad file descriptors (reported by ragnarov) `#D2159` 785267e1
  - util: work around macOS/FreeBSD failure on `exec 32>&2` (reported by tessus, jon-hotaisle) `#D2165` 8f0dfe9b
  - main: record external file descriptors on `ble-attach` `#D2183` a508a827
  - util: check leftovers of CLOEXEC fds more strictly `#D2215` 79fe2483
- main: fix unprocessed `-PGID` in `*.pid` for cleanup `#D2143` a5da23c0
- history: prevent `SIGPIPE` from reverting the TTY state in trap `EXIT` `#D2153` 4b8a0799
  - history: fix initially shifted history index `#D2180` e425dc56
- edit: support `bleopt internal_exec_int_trace` (motivated by tessus) `#D2171` cebea478 3801a87e
- global: avoid using the builtin `:` `#D2192` f2fd2955
- global: pass `--` to `type` and `declare` before arbitrary arguments `#D2194` 5c0efcf6
- global: fix spelling mistakes `#D2201` 86815f61
- util (`ble/util/buffer.flush`): write to the TUI stderr `#D2218` b5c88947
- util (`ble/util/buffer.flush`): use <kbd>DECSET(2026)</kbd> in terminals with the support `#D2226` c3df08be
- main: refactor initialization sequence `#D2231` cc9d7f39
- util (`ble/util/is-stdin-ready`): check `$_ble_util_fd_tui_stdin` by default `#D2254` 29c00fd8
  - util (`ble/util/is-stdin-ready`): work around polling issue in Windows Terminal `#D2362` 622cb247
  - util (`ble/util/is-stdin-ready`): fix the condition to use stdin (reported by Jai-JAP, darukutsu) `#D2375` 38fe52b3
- decode (`ble-decode-key/bind`): reference the argument to check the widget name (contributed by musou1500) `#D2279` 21b1bb3d
- global: normalize quoting of function names of the form `prefix:$name` `#D2296` 3d7c98bb
- global: use `[:blank:]` instead of `[:space:]` `#D2299` e2fd8f0f
- global: rename `ret` not used as `REPLY` `#D2300` 86cbf78e
- global: avoid raw word splitting `#D2309` b55c4003
- global: use `ble/util/assign` in more places `#D2312` b0e39732
- main: show details of the loading time (motivated by tessus, Darukutsu) `#D2313` 3d8f6264
- canvas: optimize binary search in tables `#D2325` d56c7d2f d4c812b7
- util: optimize `ble/fd#list` using `compgen -G` `#D2328` 6f34012d
  - util (`ble/fd#list`): fix a bug that `BASHPID` undefined in `bash < 4.3` is used (fixup 6f34012d) `#D2352` 8bea90d1
  - util (`ble/fd#list`): fix `ble/fd#list` generating an internal fd and breaking `ble/fd#add-cloexec` (reported by xlei77) `#D2356` 02ca0006
- bind: clean up old codes to bind to <kbd>ESC</kbd> `#D2334` 514d177e c9cd95c4
- decode: move key definitions into `lib/init-cmap.sh` `#D2341` fbdda841
- complete: rename key `{auto_complete => ac}_enter` `#D2342` a30125c4
- color: change color representation for faithful 24-bit black (reported by seefood) `#D2351` 9ea84456
- global: reduce the uses of `:`, `true`, and `false` `#D2353` 61a46734
- global: use `ble/opts#extract-last-optarg` `#D2363` 1cfd6c0a
- global: use `source -- path` to source an arbitrary path `#D2366` 3d2e230a
- main: describe `--lib` in the output of `ble.sh --help` `#D2367` 9699ff6a

<!---------------------------------------------------------------------------->
# ble-0.4.0-devel3

2020-12-02...2023-04-03 (`#D1427`...`#D2030`) 276baf2...1a5c451c

## New features

- decode (`ble-decode-kbd`): support various specifications of key sequences `#D1439` 0f01cab
- edit: support new options `bleopt edit_line_type={logical,graphical}` (motivated by 3ximus) `#D1442` 40ae242
- complete: support new options `bleopt complete_limit{,_auto}` (contributed by timjrd) `#D1445` b13f114 5504bbc
  - complete: update the default value of `bleopt complete_limit{,auto}` `#D1500` aae553c
  - complete: inject user interruption and complete limits into `bash-completion` through `read` (motivated by timjrd) `#D1504` 856cec2 `#D1507` 4fc51ae
- edit (kill/copy): combine multiple kills and copies (suggested by 3ximus) `#D1443` 66564e1
  - edit (`{kill,copy}-region-or`): fix unconditionally combined kills/copies (reported by 3ximus) `#D1447` 1631751
- canvas: update emoji database and support `bleopt emoji_version` (motivated by endorfina) `#D1454` d1f8c27
  - emoji: unify emoji tables of different versions `#D1671` af82662
- canvas, edit: support `bleopt info_display` (suggested by 0neGuyDev) `#D1458` 69228fa
  - canvas (panel): always call `panel::render` to update height `#D1472` 51d2c05
  - util (visible-bell): work around coordinate mismatches in subshells `#D1495` 01cfb10
  - canvas: work around kitty's quirk not recognizing <kbd>DECSTBM</kbd> (<kbd>CSI ; r</kbd>) `#D1503` eca2976
- prompt: support `bleopt prompt_status_{line,align}` and `face prompt_status_line` `#D1462` cca1cbc
  - prompt: fix missing height allocation for status line `#D1487` b424fa5
  - prompt: support `bleopt prompt_status_align=justify` `#D1494` c30a0db
- syntax: properly support case patterns `#D1474` `#D1475` `#D1476` 64b55b7
- keymap/vi: add `ble/keymap:vi/script/get-mode` for user-defined mode strings `#D1488` f25a6e8 462918d
- prompt: support multiline `prompt_rps1` `#D1502` 4fa139a
  - canvas: fix wrong coordinate calculation on linefolding (reported by telometto) `#D1602` 9badb5f
  - prompt: fix coordinates after `prompt_rps1` `#D1972` e128801
  - prompt: clear remaining SGR after `prompt_rps1` (reported by linwaytin) `#D2003` ea99d944
- syntax: support tilde expansions in parameter expansions `#D1513` 0506df2
- decode: support `ble-bind -m KEYMAP --cursor DECSCUSR` (motivated by jmederosalvarado) `#D1514` `#D1515` `#D1516` 79d671d
  - decode: reflect changes after `ble-bind --cursor` `#D1873` 39efcf9
- edit: support `nsearch` options (motivated by Alyetama, rashil2000, carv-silva) `#D1517` 9125795
  - edit: support `nsearch` opts `empty=emulate-readline` (motivated by jainpratik163) `#D1661` d68ba61
  - edit: support bash-5.2 binding of `prior/next` to `history-search-{for,back}ward` `#D1661` d26a6e1
- syntax: support the deprecated redirection `>& file` `#D1539` b9b0de4
- complete: complete file descriptors and heredoc words after redirections `#D1539` b9b0de4
- main: support `blehook ATTACH DETACH`, `BLE_ONLOAD`, `BLE_ATTACHED` `#D1543` 750ca38
- main: support `ble` `#D1544` 750ca38
- main (`ble-update`): support package updates and `sudo` updates (motivated by huresche, oc1024) `#D1548` 0bc2660
  - main (`ble-update`): fix help message (contributed by NoahGorny) 50288bf
- syntax: support undocumented `${a~}` and `${a~~}` `#D1561` 4df29a6
- lib: support `lib/vim-airline` (motivated by huresche) `#D1565` da1d0ff
  - util (`ble/gdict`): refactor `#D1569` 7732eed
  - vim-airline: support `bleopt vim_airline_theme` `#D1589` 73b037f
  - prompt: track dependencies and detect changes `#D1590` `#D1591` cf8d949
  - prompt: preserve `LINES` and `COLUMNS` for custom sequences `#D1592` 040016d
  - color: fix the face initialiation order for uses in prompts (motivated by jmederosalvarado) `#D1593` 321371f
  - prompt (`contrib/prompt-git`): support dirty checking `#D1601` b2713d9
  - prompt (`contrib/prompt-git`): do not use `ble/util/idle` in Bash 3 `#D1606` 959cf27
  - util (`bleopt`): add new option `-I` to reinitialize user settings on reload `#D1607` 959cf27
  - vi (vi_cmap): fix wrong prompt calculations by the outdated initial values `#D1653` 2710b23
  - vim-airline: measure separator widths and fix layout of status line `#D1999` 1ce0d1ad 478c9a10
- util, color: refactor configuration interfaces (`bleopt`, `blehook`, `ble-face`) `#D1568` c94d292
  - color: support new face setting function `ble-face`
  - util (`bleopt`): support option `-r` and `-u` and wildcards in option names
  - util (`blehook`): hide internal hooks by default and support option `-a`
  - util, color: fix argument analysis of `bleopt`, `blehook`, and `ble-face` (fixup c94d292) `#D1571` bb53271
  - util (`blehook`): show explicitly specified internal hooks `#D1594` f4312df
  - util (`bleopt`): do no select obsoleted options by wildcards `#D1595` f4312df
  - util (`bleopt`): fix error messages for unknown options `#D1610` 66df3e2
  - util (`bleopt`, `bind`): fix error message and exit status, respectively `#D1640` b663cee
  - util (`blehook`): support wildcards `#D1861` 480b7b3
- progcomp: support quoted commands and better `progcomp_alias` `#D1581` `#D1583` dbe87c3
  - progcomp: fix a bug that command names may stray into completer function names `#D1611` 1f2d45f
- syntax: highlight quotes of the `\?` form `#D1584` 5076a03
  - syntax: recognize escape \" in double-quoted strings `#D1641` 4b71449
- prompt: support a new backslash sequence `\g{...}` `#D1609` be31391
  - prompt: accept more general `[TYPE:]SPEC` in `\g{...}` like `ble-face` `#D1963` 81b3b0e
  - prompt: fix non-working 24-bit color in `\g{...}` `#D1977` 881ec25
- complete: add a new option `bleopt complete_limit_auto_menu` `#D1618` 1829d80
- canvas: support grapheme clusters (motivated by huresche) `#D1619` c0d997b
  - canvas (`ble/util/c2w`): use `EastAsianWidth` and `GeneralCategory` to mimic `wcwidth` `#D1645` 9a132b7
  - canvas (c2w:auto): work around combining chars applied to the previous line `#D1649` 1cbbecb
  - canvas (c2w:auto): avoid duplicate requests `#D1649` 1cbbecb a3047f56
  - canvas (c2w:auto): send <kbd>DSR(6)</kbd> in the internal state `#D1664` a3047f5
  - canvas (c2w): support `bleopt char_width_mode=musl` `#D1668` 05b258f `#D1672` af82662
  - canvas (c2w:auto): detect `emacs` and `musl` `#D1668` 05b258f
- rlfunc: support vi word operations in `emacs` keymap (requested by SolarAquarion) `#D1624` 21d636a
- edit: support `TMOUT` for the session timeout `#D1631` 0e16dbd
- edit: support bash-5.2 `READLINE_ARGUMENT` `#D1638` d347fb3
- complete: support `complete [-DI]` in old versions of Bash through `_DefaultCmD_` and `_InitialWorD_` `#D1639` 925b2cd
- rlfunc: support nsearch widgets in `vi_nmap` keymap (requested by cornfeedhobo) `#D1651` 9a7c8b1
- prompt: support `bleopt prompt_ruler` (motivated by Barbarossa93) `#D1666` 05cf638
  - prompt: fix hanging by a zero-width `prompt_ruler` `#D1673` 9033f29
- edit: support `bleopt canvas_winch_action` (requested by Johann-Goncalves-Pereira, guptapriyanshu7) `#D1679` 2243e91
  - blerc: fix the name of the option `bleopt canvas_winch_action` (reported by Knusper) b1be640
  - edit: go back to the previous lines with `redraw-here` more aggressively `#D1966` a125187
- menu (menu-style:desc): improve descriptions (motivated by Shahabaz-Bagwan) `#D1685` 4de1b45
- menu (menu-style:desc): support multicolumns (motivated by Shahabaz-Bagwan) `#D1686` 231dc39
  - menu (menu-style:desc): fix not working `bleopt menu_desc_multicolumn_width=` `#D1727` 2140d1e
- term: let <kbd>DECSCUSR</kbd> pass through terminal multiplexers (motivated by cmplstofB) `#D1697` a3349e4
  - util: refactor `_ble_term_TERM` `#D1746` 63fba6b
- complete: requote for more compact representations on full completions `#D1700` a1859b6
  - complete (requote): requote from optarg/rhs starting point `#D1786` 93c2786
- complete: improve support for `declare` and `[[ ... ]]` `#D1701` da38404
  - syntax: fix completion and highlighting of `declare` with assignment arguments `#D1704` `#D1705` e12bae4
  - cmdspec: refactor `{mandb => cmdspec}_opts` `#D1706` `#D1707` 0786e92
- complete (menu-style:align): refactor `complete_menu_align => menu_align_{min,max}` (motivated by banoris) `#D1717` 22a2449
- prompt: support `bleopt prompt_command_changes_layout` `#D1750` e199bee
- exec: measure execution times `#D1756` 2b28bec
  - edit: work around a bash-4.4..5.1 bug of `exit` outputting time to stderr of exit context `#D1765` 3de751e e61dbaa
  - edit (`exec_elapsed_mark`): show hours and days `#D1793` 699dabb
- util: preserve original traps and restore them on unload `#D1775` `#D1776` `#D1777` 398e404
  - util (trap): fix a bug of restoring original traps `#D1850` 8d918b6
- progcomp: support `compopt -o ble/no-default` to suppress default completions `#D1789` 7b70a0e
- sabbrev: support options `-r` and `--reset` to remove entries `#D1790` 29b8be3
- util (blehook): support `hook!=handler` and `hook+-=handler` `#D1791` 0b8c097
- prompt: escape control characters in `\w` and `\W` `#D1798` 8940434 a9551e5
  - prompt: fix wrongly escaped UTF-8 chars in `\w` and `\W` `#D1806` d340233
  - prompt: fix a bug that `\u` is expanded to the shell name `#D1975` fe339c3
- emacs: support `bleopt keymap_emacs_mode_string_multiline` (motivated by ArianaAsl) `#D1818` 8e9d273
- util: synchronize rlvars with `bleopt complete_{menu_color{,_match},skip_matched} term_bracketed_paste_mode` (motivated by ArianaAsl) `#D1819` 6d20f51
  - util: suppress false warnings of `bind` inside non-interactive shells (reported by wukuan405) `#D1823` 1e19a67
- history: support `bleopt history_erasedups_limit` (motivated by SuperSandro2000) `#D1822` e4afb5a 3110967
- prompt: support `bleopt prompt_{emacs,vi}_mode_indicator` (motivated by ferdinandyb) `#D1843` 2b905f8
- util (`ble-import`): support option `-q` `#D1859` 1ca87a9
- history: support extension `HISTCONTROL=strip` (motivated by aiotter) `#D1874` 021e033
- benchmark (ble-measure): support an option `-V` `#D1881` 571ecec
- color: allow setting color filter by `_ble_color_color2sgr_filter` `#D1902` 88e74cc
- auto-complete: add `bleopt complete_auto_complete_opts` (motivated by DUOLabs333) `#D1901` `#D1911` 1478a04 6a21ebb
- menu-complete: add `bleopt complete_menu_complete_opts` (requested by DUOLabs333) `#D1911` 6a21ebb
- edit (`magic-space`): support `bleopt edit_magic_expand=...:alias` (requested by telometto) `#D1912` 63da2ac
  - auto-complete: cancel auto-complete for `magic-space` `#D1913` 01b4f67
- complete: support ambiguous completion for command paths `#D1922` 8a716ad
- complete: preserve original path segments as long as possible `#D1923` `#D1924` e3cdb9d
- main: support `BLE_SESSION_ID` and `BLE_COMMAND_ID` `#D1925` 44d9e10 `#D1947` 46ac426 `#D1954` 651c70c
- main: support an option `--inputrc={diff,all,user,none}` `#D1926` 92f2006
- util (`ble/builtin/trap`): support Bash 5.2 `trap -P` `#D1937` 826a275
- syntax: highlight `\?` in here documents `#D1959` e619e73
- syntax: recognize history expansion in here documents, `"...!"` (bash <= 4.2), and `$!` (bash <= 4.1) `#D1959` e619e73
- syntax: support context after `((...))` and `[[ ... ]]` in bash-5.2 `#D1962` 67cb967
- edit: support the readline variable `search-ignore-case` of bash-5.3 `#D1976` e3ad110
- menu-complete: add `insert_unique` option to the `complete` widget `#D1995` 36efbb7
- syntax: check alias expansions of `coproc` variable names `#D1996` 92ce433
- syntax: support new parameter transformation `"${arr@k}"` `#D1998` 1dd7e385
- edit: support a user command `ble append-line` (requested by mozirilla213) `#D2001` 2a524f34
- decode: accept isolated <kbd>ESC \<char\></kbd> (requested by mozirilla213) `#D2004` d7210494
- sabbrev: add widget `magic-slash` to approximate Zsh named directories (motivated by mozirilla213) `#D2008` e6b9581c
- sabbrev: support inline and linewise sabbre with `ble-sabbrev -il` `#D2012` 56208534
- complete: add `bleopt complete_source_sabbrev_{opts,ignore}` (motivated by mozirilla213) `#D2013` f95eb0cc `#D2016` 45c76746
- util.bgproc: separate `ble/util/bgproc` from `histdb` (motivated by bkerin) `#D2017` 7803305f
  - util.bgproc: fix use of `ble/util/idle` in bash-3 `#D2026` 79a6bd41
  - util.bgproc: increase frequency of bgproc termination check (motivated by bkerin) `#D2027` 8d623c19
  - util.bgproc: fix an `fd#alloc` failure in bash-4.2 `#D2029` 7c4ff7bc
- menu-complete: support selection by index (requested by bkerin) `#D2023` b91b8bc8

## Changes

- syntax: exclude <code>\\ + LF</code> at the word beginning from words (motivated by cmplstofB) `#D1431` 67e62d6
- complete: do not quote `:` and `=` in non-filename completions generated by progcomp (reported by 3ximus) `#D1434` d82535e
- edit: preserve the state of `READLINE_{LINE,POINT,MARK}` `#D1437` 8379d4a
- edit: change default behavior of <kbd>C-w</kbd> and <kbd>M-w</kbd> to operate on backward words `#D1448` 47a3301
- prompt: rename `bleopt prompt_{status_line => term_status}` `#D1462` cca1cbc
- edit (`ble/builtin/read`): cancel by <kbd>C-d</kbd> on an empty line `#D1473` ecb8888
- syntax: change syntax context after `time ;` and `! ;` for Bash 4.4 `#D1477` 4628370
- decode (rlfunc): update mapping `vi-replace` in `imap` and `vi-editing-mode` in `nmap` (reported by onelittlehope) `#D1484` f2ca811
- prompt: invalidate prompt and textarea on prompt setting changes `#D1492` 1f55913
- README: update informations on stable versions `#D1509` c8e658e
- README: update the description of how to uninstall `#D1510` c8e658e
- util (`bleopt`): validate initial user settings `#D1511` 82c5ece
  - util (`bleopt`): fix a bug that old values are double-expanded on init (fixup 82c5ece) `#D1521` f795c07
  - util (`bleopt`): do not validate obsoleted initial settings `#D1527` 032f6b2
- main: preserve user-space overridden builtins `#D1519` 0860be0
  - util (`ble/util/type`): fix a bug that aliases are not properly highlighted (reported by 3ximus) `#D1526` 45b30a7
  - main: preserve user's `expand_aliases` and allow aliases in internal space (fixup 0860be0) `#D1574` afc4112
  - main: main: fix expand_aliases unset on ble-reload (fixup afc4112) `#D1577` 3417388
- main: accept non-regular files as `blerc` and add option `--norc` `#D1530` 7244e2f
- prompt: let `stderr` pass through to tty in evaluating `PS0` (reported by tycho-kirchner) `#D1541` 24a88ce
- prompt: adjust behavior of `LINENO` and prompt sequence `\#` (reported by tycho-kirchner) `#D1542` 8b0257e
  - prompt: update `PS0` between multiple commands (motivated by tycho-kirchner) `#D1560` 8f29203
- edit (`widget:display-shell-version`): include `ble.sh` version `#D1545` 750ca38
  - edit (`display-shell-version`): detect configurations and print details `#D1781` 5015cb56
  - edit (`display-shell-version`): show information of the OS distribution and properly handle saved locales `#D1854` 066ec63 bdb7dd6
  - edit (`display-shell-version`): show `gawk`, `make`, and `git` versions of the build time `#D1892` e618133
  - edit (`display-shell-version`): support running as a user command (reported by DhruvaG2000) `#D1893` e618133
  - edit (`display-shell-version`): show warnings for fzf-integration `#D1907` 3bc3bea
  - edit (`display-shell-version`): show the `zoxide` version `#D1907` 3bc3bea
- complete (`ble-sabbrev`): support colored output `#D1546` 750ca38
- decode (`ble-bind`): support colored output `#D1547` 750ca38
  - decode (`ble-bind`): output bindings of the specified keymaps with `ble-bind -m KEYMAP` (fixup 750ca38) `#D1559` 6e0245a
- keymap/vi: update mode names on change of `bleopt keymap_vi_mode_name_*` (motivated by huresche) `#D1565` 11ac106
- main: show notifications against debug versions of Bash `#D1612` 8f974aa
- term: terminal identification
  - term (`_ble_term_TERM`): update `vte` identification `#D1620` 00e74d8
  - term (`_ble_term_TERM`): detect wezterm-20220408 `#D1909` 486564a
  - term (`_ble_term_TERM`): detect konsole `#D1988` 600e845 ed53858
- edit: suppress only `stderr` with `internal_suppress_bash_output` (motivated by rashil2000) `#D1646` a30887f
- prompt: do not evaluate `PROMPT_COMMAND` for subprompts `#D1654` 08e903e
- Makefile: work around the case the repository is cloned without `--recursive` `#D1655` 22ace5f
- repo: add subdirectories `make` and `docs` `#D1657` 75bd04c
- util: time out <kbd>CPR</kbd> requests `#D1669` 1481d48
  - util (CPR): fix the problem of always timing out (fixup 1481d48) `#D1792` 9b331c4
- main: suppress non-interactive warnings from manually sourced startup files (reported by andreclerigo) `#D1676` 0525528 88e2df5
- mandb: integrate `mandb` with `bash-completion` (motivated by Shahabaz-Bagwan, bbyfacekiller and EmilySeville7cfg) `#D1688` c1cd666
- syntax: do not start argument completions immediately after previous word (reported by EmilySeville7cfg) `#D1690` 371a5a4
  - syntax: revert 371a5a4 and generate empty completion source on syntax error `#D1609` e09fcab
- syntax: strictly check variable names of `for`-statements `#D1692` d056547
- widget `self-insert`: untranslate control chars and insert the last character `#D1696` 5ff3021
- complete (`source:command`): exclude inactive aliases `#D1715` d6242a7
- complete (`source:command`): not quote aliases and keywords `#D1715` d6242a7
- highlight (`wtype=CTX_CMDI`): check alias names before shell expansions `#D1715` d6242a7
  - util (`ble/is-alias`): fix a bug of unredirected error messages for bash-3.2 (fixup d6242a7) `#D1730` 31372cb
- edit (`history_share`): update history on `discard-line` (reported by SuperSandro2000) `#D1742` 8dbefe0
- canvas: do not insert explicit newlines on line folding if possible (reported by banoris) `#D1745` 02b9da6 dc3827b
  - edit: fix layout with `prompt_rps1` caused by missing `opts=relative` for `ble/textmap#update` `#D1769` f6af802
- edit (`ble-bind -x`): preserve multiline prompts on execution of `bind -x` commands (requested by SuperSandro2000) `#D1755` 7d05a28
- util (`ble/util/buffer`): hide cursor in rendering `#D1758` e332dc5
- complete (`action:file`): always suffix `/` to complete symlinked directory names (reported by SuperSandro2000) `#D1759` 397ac1f
- edit (command-help): show source files for functions `#D1779` 7683ab9
- edit (`ble/builtin/exit`): defer exit in trap handlers (motivated by SuperSandro2000) `#D1782` f62fc04 6fdabf3
  - util (`blehook`): fix a bug that the the hook arguments are lost (reported by SuperSandro2000) `#D1804` 479795d
  - edit: fix a bug of `ble/builtin/exit` inside subshells in the `EXIT` trap `#D1973` 0451521
- complete (`source:command/get-desc`): show function location and body `#D1788` 496e798
- edit (`ble-detach`): prepend a space to `stty sane` for `HISTIGNORE=' *'` `#D1796` 26b532e
- decode (`bind`): do not treat non-beginning `#` as comments `#D1820` 65c4138
- history: disable the history file when `HISTFILE` is empty `#D1836` 9549e83
- complete: generate options by empty-word copmletion after filenames (reported by geekscrapy) `#D1846` 6954b13
  - complete: do not show option descriptions for the empty-word completion (requested by geekscrapy) `#D1846` 1c7f7a1
- syntax (`extract-command`): extract unexpected command names as commands `#D1848` 5b63459
- main (`ble-reload`): preserve the original initialization options `#D1852` d8c92cc
 - main (`ble-reload`): fix a bug that the default rcfile is not loaded `#D1914` 85b5828
- blehook: print reusable code to restore the user hooks `#D1857` b763677
  - blehook: separate internal and user hooks `#D1856` b763677
  - blehook: prefer the uniq  `!=` to the addition `+=` `#D1871` fe7abd4
  - blehook: print hooks with `--color=auto` by default `#D1875` 3953afe
- util (`ble/builtin/trap`): refactor
  - trap,blehook: rename `ERR{ => EXEC}` and separate from the `ERR` trap `#D1858` 94d1371
  - trap: remove the support for the shell function `TRAPERR` `#D1858` 94d1371
  - trap: preserve `BASH_COMMAND` in trap handlers `#D1858` 94d1371
  - util (`ble/builtin/trap`): run EXIT trap in subshells `#D1862` 5b351e8
  - util (`ble/builtin/trap`): fix the RETURN trap `#D1863` 793dfad
  - trap,blehook: move to a new file `util.hook.sh` `#D1864` 55a182b
  - trap (`trap -p`): fix unprinted existing user traps `#D1864` 55a182b
  - trap (`ble/builtin/trap/finalize`): fix a failure of restoring the original trap `#D1864` 55a182b
  - trap (`trap -p`): print also custom traps `#D1864` 55a182b
  - trap: preserve positional parameters for user trap handlers `#D1865` 9e2963c
  - trap: suppress `INT` processing with user traps `#D1866` 5c28387
  - trap: unify handling of `DEBUG` and the other traps `#D1867` a22c25b
  - trap: work around possible interferences by recursive traps `#D1867` a22c25b
  - trap: ignore `RETURN` for `ble/builtin/trap/.handler` `#D1867` a22c25b
  - trap: fix a bug that `DEBUG` for internal commands clears `$?` `#D1867` a22c25b
  - trap: use `ble/util/assign/.mktmp` to read the `DEBUG` trap `#D1910` 1de9a1e
- progcomp: reproduce arguments of completion functions passed by Bash `#D1872` 4d2dd35
- prompt: preserve transient prompt with `same-dir` after `clear-screen` `#D1876` 69013d9
- color: let `bleopt term_index_colors` override the default if specified `#D1878` 7d238c0
- canvas: update Unicode version 15.0.0 `#D1880` 49e55f4
- decode (`vi_imap-rlfunc.txt`): update the widget for `backward-kill-word` as `kill-backward-{u => c}word` `#D1896` e19b796
- color: rearrange color table by `ble palette` (suggested by stackoverflow/caoanan) `#D1961` bb8541d
- util (`ble/util/idle`): process events before idle sleep `#D1980` 559d64b
- keymap/vi (`decompose-meta`): translate <kbd>S-a</kbd> to <kbd>A</kbd> `#D1988` 600e845
- sabbrev: apply sabbrev to right-hand sides of variable assignments `#D2006` 41faa494
- complete (`source:argument`): fallback to rhs completion also for `name+=rhs` `#D2006` 41faa494
- auto-complete: limit the line length for auto-complete `#D2009` 5bfbd6f2
- complete (`source:argument`): generate sabbrev completions after normal completions (motivated by mozirilla213) `#D2011` a6f168d0
- complete (`source:option`): carve out `ble/complete/source:option/generate-for-command` (requested by mozirilla213) `#D2014` 54ace59c

## Fixes

- term: fix a bug that VTE based terminals are not recognized `#D1427` 7e16d9d
- complete: fix a problem that candidates are not updated after menu-filter (reported by 3ximus) `#D1428` 98fbc1c
- complete/mandb-related fixes
  - mandb: support mandb in FreeBSD `#D1432` 6c54f79
  - mandb: fix BS contamination used by nroff to represent bold (reported by rlnore) `#D1429` b5c875a
  - mandb: fix an encoding prpblem of utf8 manuals `#D1446` 7a4a480
  - mandb: improve extraction and cache for each locale `#D1480` 3588158
  - mandb: fix an infinite loop by a leak variable (reported by rlanore, riblo) `#D1550` 0efcb65
  - mandb: work around old groff in macOS (reported by killermoehre) `#D1551` d4f816b
  - mandb: use `manpath` and `man -w`, and read `/etc/man_db.conf` and `~/.manpath` `#D1637` 2365e09
  - mandb: support the formats of the man pages of `awk` and `sed` (reported by bbyfacekiller) `#D1687` 6932018
  - mandb: generate completions of options also for the empty word `#D1689` b90ac78
  - mandb: support the man-page formats of `wget`, `fish`, and `ping` (reported by bbyfacekiller) `#D1687` a79280e
  - mandb: carry optarg for e.g. `-a, --accept=LIST` `#D1687` 23d5657
  - mandb: parse `--help` for specified commands `#D1693` e1ad2f1
  - mandb: fix small issues of man-page analysis `#D1708` caa77bc
  - mandb: insert a comma in brace expansions instead of a space `#D1719` 0ac7f03
  - mandb: support man-page format of `rsync` `#D1733` 7900144
  - mandb: fix a bug that the description is inserted for `--no-OPTION` `#D1761` 88614b8
  - mandb: fix a bug that the man page is not correctly searched (fixup 2365e09) `#D1794` 65ffe70
  - mandb: support the man-page formats of `man ls` in coreutils/Japanese and in macOS `#D1847` fa32829
  - mandb: include short name in the longname description `#D1879` 60b6989
- edit: work around the wrong job information of Bash in trap handlers (reported by 3ximus) `#D1435` `#D1436` bc4735e
- edit (command-help): work around the Bash bug that tempenv vanishes with `builtin eval` `#D1438` 8379d4a
- global: suppress missing locale errors (reported by 3ximus) `#D1440` 4d3c595
- edit (sword): fix definition of `sword` (shell words) `#D1441` f923388
- edit (`kill-forward-logical-line`): fix a bug not deleting newline at the end of the line `#D1443` 09cf7f1
- util (`ble/util/msleep`): fix hang in Cygwin by swithing from `/dev/udp/0.0.0.0/80` to `/dev/zero` `#D1452` d4d718a
  - util (`ble/util/msleep`): work around the bash-4.3 bug of `read -t` (reported by 3ximus) `#D1468` `#D1469` 4ca9b2e
- syntax: fix broken AST with `[[` keyword `#D1454` 69658ef
- benchmark (`ble-measure`): work around a locale-dependent decimal point of `EPOCHREALTIME` (reported by 3ximus) `#D1460` 1aa471b
- global: work around bash-4.2 bug of `declare -gA` (reported by 0xC0ncord) `#D1470` 8856a04
  - global: fix declaration of associative arrays for `ble-reload` (reported by 0xC0ncord) `#D1471` 3cae6e4
  - global: use a better workaround of bash-4.2 `declare -gA` by separating assignment `#D1567` 2408a20
- bind: work around broken `cmd_xmap` after switching the editing mode `#D1478` 8d354c1
  - decode (`encoding:C`): fix initialization for isolated ESC `#D1839` c3bba5b
- edit: clear graphic rendition on newlines and external commands `#D1479` 18bb2d5
- decode (rlfunc): work around incomplete bytes in keyseq (reported by onelittlehope) `#D1483` 3559658 beb0383 37363be
- main: fix a bug that unset `IFS` is not correctly restored `#D1489` 808f6f7
  - edit: fix error messages on accessing undo records in emacs mode (reported by rux616) `#D1497`  61a57c0 e9be69e
- canvas: fix a glitch that SGR at the end of command line is applied to new lines `#D1498` 4bdfdbf
- syntax: fix a bug that `eval() { :; }`, `declare() { :; }` are not treated as function definition `#D1529` b429095
- decode: fix a hang on attach failure by cache corruption `#D1531` 24ea379
- edit, etc: add workarounds for `localvar_inherit` `#D1532` 7b63c60
  - edit: fix a bug that `command-help` doesn't work `#D1635` 0f6a083
- progcomp: fix non-working `complete -C prog` (reported by Archehandoro) `#D1535` 026432d
- bind: fix a problem that `bind '"seq":"key"'` causes a loop macro `bind -s key key` (reported by thanosz) `#D1536` ea05fc5
  - bind: fix errors on readline macros (reported by RakibFiha) `#D1537` c257299
- main: work around sourcing `ble.sh` inside subshells `#D1554` bbc2a90
  - main: fix exit status for `bash ble.sh --test` (fixup bbc2a90) `#D1558` 641238a
  - main: fix reloading after ble-update (fixup bbc2a90) (fixed by oc1024) `#D1558` 9372670
- main: work around `. ble.sh --{test,update,clear-cache}` in intereactive sessions `#D1555` bbc2a90
- Makefile: create `run` directory instead of `tmp` `#D1557` 9bdb37d
- main: fix the workaround for `set -e` `#D1564` ab2f70b
  - main: fix the workaround for `set -u` `#D1575` 76073a9
  - main: fix the workaround for `set -eu` and refactor `#D1743` 6a946f0
  - decode: fix the workaround for `set -e` with `--prompt=attach` `#D1832` 5111323
- util: work around bash-3.0 bug `"${scal[@]/xxx}"` `#D1570` 24f79da
- sabbrev (`ble-sabbrev`): fix delayed output before the initialization `#D1573` 5d85238
- history: fix the workaround for bash-3.0 bug of reducing histories `#D1576` 15c9133
- syntax: fix a bug that argument completion is attempted in nested commands (reported by huresche) `#D1579` 301d40f
- edit (brackated-paste): fix incomplete `CR => LF` conversion (reported by alborotogarcia) `#D1587` 8d6da16
- main (adjust-bash-options): adjust `LC_COLLATE=C` `#D1588` e87ac21
- highlight (`layer:region`): fix blocked lower-layer changes without selection changes `#D1596` 5ede3c6
- complete (`auto-menu`): fix sleep loops by clock/sclock difference `#D1597` 53dd018
- history: fix a bug that history data is cleared on `history -r` `#D1605` 72c274e
- util (`ble/string#quote-command`): remove redundant trailing spaces for single word command `#D1613` 94556b4
- util: work around the Bash 3 bug of array assignments with `^A` and `^?` in Bash 3.2 `#D1614` b9f7611
- benchmark (`ble-measure`): fix a bug that the result is always 0 in Bash 3 and 4 (fixup bbc2a904) `#D1615` a034c91
- complete: fix a bug that the shopt settings are not restored correctly (reported by Lun4m) `#D1623` 899c114
- decode, canvas, etc.: explicitly treat CSI arguments as decimal numbers (reported by GorrillaRibs) `#D1625` c6473b7 2ea48d7
- history: fix the vanishing history entry used for `ble-attach` `#D1629` eb34061
- global: work around readonly `TMOUT` (reported by farmerbobathan) `#D1630` 44e6ec1
- complete: fix a task scheduling bug of referencing two different clocks (reported by rashil2000) `#D1636` fea5f5b
- canvas: update prompt trace on `char_width_mode` change (reported by Barbarossa93) `#D1642` 68ee111
- decode (`cmap/initialize`): fix unquoted special chars in the cmap cache `#D1647` 7434d2d
- decode: fix a bug that the characters input while initialization are delayed `#D1670` 430f449
- util (`ble/util/readfile`): fix a bug of always exiting with 1 in `bash <= 3.2` (reported by laoshaw) `#D1678` 61705bf
- trace: fix wrong positioning of the ellipses on overflow `#D1684` b90ac78
- complete: do not generate keywords for quoted command names `#D1691` 60d244f
- menu (menu-style:align): fix the failure of delaying `ble/canvas/trace` on items (motivated by banoris) `#D1710` acc9661
- complete: fix empty completions with `FIGNORE` (reported by seanfarley) `#D1711` 144ea5d
- main: fix the message of owner errors of cache directories (reported by zim0369) `#D1712` b547a41
- util (`ble/string#escape-for-bash-specialchars`): fix escaping of TAB `#D1713` 7db3d2b
- complete: fix failglob messages while progcomp for commands containing globchars `#D1716` e26a3a8
  - complete: fix a bug that the default progcomp does not work properly `#D1722` 01643fa
- highlight: fix a bug that arrays without the element `0` is not highlighted `#D1721` b0a0b6f
- util (visible-bell): erase visible-bell before running external commands `#D1723` 0da0c1c
  - util(`ble/util/eval-pathname-expansion`): fix restoring shopt options in bash-4.0 `#D1825` 736f4da
- util (`ble/function`): work around `shopt -u extglob` `#D1725` 952c388
- syntax: fix uninitialized syntax-highlighting in bash-3.2 `#D1731` e3f5bf7
- make: fix a bug that config update messages are removed on install `#D1736` 72d968f
- util: fix bugs in conversions from `'` to `\''` `#D1739` 6d15782
- canvas: fix unupdated prompt on async wcwidth resolution `#D1740` e14fa5d
- progcomp: retry completions on `$? == 124` also for non-default completions (reported by SuperSandro2000) `#D1759` 82b9c01
- app: work around data corruption by WINCH on intermediate state `#D1762` 5065fda
- util (`ble/util/import`): work around filenames with bash special characters `#D1763` b27f758
- edit: fix the restore failure of `PS1` and `PROMPT_COMMAND` on `ble-detach` `#D1784` b9fdaab
- complete: do not attempt an independent rhs completion for arguments (reported by rsteube) `#D1787` f8bbe2c
- history: fix the unsaved history in the detached state `#D1795` 344168e
- edit: fix an unexpected leave from the command layout on `read` `#D1800` 4dbf16f
  - edit: fix the command layout remaining after job information (reported by mozirilla213) `#D1991` dcfb067
- history: work around possible dirty prefix `*` in the history output `#D1808` 64a740d
- decode (`ble-bind`): fix the printed definition of `-c`/`-x` bindings `#D1821` 94de078
- command-help (`.read-man`): add missing `ble/util/assign/.rmtmp` `#D1840` 937a164
- complete: fix wrong `COMP_POINT` with `progcomp_alias` `#D1841` 369f7c0
- main (`ble-update`): fix error message with system-wide installation of `ble.sh` (fixed by tars0x9752) 1d2a9c1 a450775
- main. util: fix problems of readlink etc. found by test in macOS (reported by aiotter) `#D1849` fa955c1 `#D1855` a22e145
- progcomp: fix a bug that `COMP_WORDBREAKS` is ignored `#D1872` 4d2dd35
- global: quote `return $?` `#D1884` 801d14a
- canvas (`ble/canvas/trace`): fix text justification for empty lines (reported by rashil2000) `#D1894` cdf74c2
- main: fix adjustments of bash options (reported by rashil2000) `#D1895` 138c476
- complete: suppress error messages for non-bash_completion `_parse_help` (reported by nik312123) `#D1900` 267de7f
- prompt: fix the marker position for the readline variable `show-mode-in-prompt` (reported by Strykar) `#D1903` 09bb4d3
- highlight: fix a bug that `bleopt filename_ls_colors` is not working (reported by qoreQyaS) `#D1919` b568ade
- bind: fix <kbd>M-C-@</kbd>, <kbd>C-x C-@</kbd>, and <kbd>M-C-x</kbd> (`bash-4.2 -o emacs`) `#D1920` a410b03
- complete (action:file): support `ble/syntax-raw` in the filename extraction (reported by qoreQyaS) `#D1921` 32277da
- decode: fix a bug that the tab completion do not work with bash-4.4 and lower `#D1928` 7da9bce
- complete: fix non-working ambiguous path completion with `..` and `.` in the path `#D1930` 632e90a
- main (`ble-reload`): fix failure by non-existent rcfile `#D1931` b7ae2fa
- syntax (`ble/syntax/highlight/vartype`): check variable in global scope `#D1932` b7026de
- menu (linewise): fix layout calculation with variable width of line prefix (reported by bkerin) `#D1979` cc852dc
- edit (`ble/textarea#render`): fix interleaving outputs to `_ble_util_buffer` and `DRAW_BUFF` `#D1987` 6d61388
- keymap/vi (`expand-range-for-linewise-operator`): fix the end point being not extended `#D1994` bce2033
- keymap/vi (`operator:filter`): do not append newline at the end of line `#D1994` bce2033
- highlight: fix shifted error marks after delayed `core-syntax` `#D2000` f4145f16
- syntax: fix unrecognized variable assignment of the form `echo arr[i]+=rhs` `#D2007` 41faa494
- menu (linewise): fix clipping of long line (reported by bkerin) `#D2025` 4c6a4775

## Documentation

- blerc: add all the missing options `#D1667` 0228d76
- blerc: add missing faces `argument_option` and `cmdinfo_cd_cdpath` (reported by Prikalel) `#D1675` 26aaf87
- README: describe how to invoke multiple widgets with a keybinding (motivated by michaelmob) `#D1699` 6123551
- README: add links to `bash-it` and `oh-my-bash` `#D1724` 4a2575f
- README: mention the Guix package (motivated by kiasoc5) `#D1888` 0f7c04b
- blerc: add frequently used keybindings (motivated by KiaraGrouwstra, micimize) `#D1896` `#D1897` e19b796
- wiki/Q&A: add item for defining a widget calling multiple widgets (motivated by micimize) `#D1898` e19b796
- blerc: rename from `blerc` to `blerc.template` `#D1899` e19b796
- README: add a link to the explanation on the "more reliable setup" of bashrc (motivated by telometto) `#D1905` 09bb4d3
- README: describe `contrib/fzf` integration (reported by SuperSandro2000, tbagrel1) `#D1907` 3bc3bea b568ade
- README: add links to Manual pages for *kspec* and `modifyOtherKeys` `#D1917` fb7bd0b1 b568ade
- README: explain the build process `#D1964` `#D1965` 14ca1e5

## Optimization

- syntax (`layer:syntax/word`): perform pathname expansions in background subshells (motivated by 3ximus) `#D1449` 13e7bdd
  - syntax (`simple-word/is-simple-noglob`): suppress error messages on expansions `#D1461` a56873f
  - syntax (`simple-word/eval`): fix unperformed tilde expansions in the background (reported by 3ximus) `#D1463` 6ebec48
  - syntax (`simple-word/eval`): propagate timeouts in sync highlighting (reported by 3ximus) `#D1465` c2555e2
  - edit: change the priority of `render-defer` and `menu-filter` `#D1501` aae553c
- complete: perform pathname expansions in subshells (motivated by 3ximus) `#D1450` d511896
- complete: support `bleopt complete_timeout_compvar` to time out pathname expansions for `COMP_WORDS` / `COMP_LINE` `#D1457` cc2881a
- complete (`ble/complete/source:file`): remove slow old codes (reported by timjrd) `#D1512` e5be0c1
- syntax (`ble/syntax:bash/simple-word/eval`): optimize large array passing (motivated by timjrd) `#D1522` c89aa23
  - syntax (`ble/syntax:bash/simple-word/eval`): use `mapfile -d ''` for Bash 5.2 `#D1604` 72c274e
- main: prefer `nawk` over `mawk` and `gawk` `#D1523` `#D1524` c89aa23
  - main (`ble/bin/.freeze-utility-path`): fix unupdated temporary implementations `#D1528` c70a3b4
  - util (`ble/util/assign`): work around subshell conflicts `#D1578` 6e4bb12
- history: use `mapfile -d ''` to load history in Bash 5.2 `#D1603` 72c274e
- prompt: use `${PS1@P}` when the prompt contains only safe prompt sequences `#D1617` 8b5da08
  - prompt: fix not properly set `$?` in `${PS1@P}` evaluation (reported by nihilismus) `#D1644` 521aff9
  - prompt: fix a bug that the special treatment of `\$` in Cygwin/MSYS is disabled `#D1741` 4782a33
- decode: cache `inputrc` translations `#D1652` 994e2a5
- complete: use `awk` for batch `quote-insert` (motivated by banoris) `#D1714` a0b2ad2 92d9734
  - complete (quote-insert.batch): fix regex escaping in bracket expr of awk (reported by telometto) `#D1729` 8039b77
- prompt: reduce redundant evaluation of `PROMPT_COMMAND` on the startup `#D1778` 042376b
- main: run `ble/base/unload` directly at the end of `EXIT` handler `#D1797` 115baec
- util: optimize `ble/util/writearray` `#D1816` 96e9bf8
- history: optimize processing of `erasedups` (motivated by SuperSandro2000) `#D1817` 944d48e
- debug: add `ble/debug/profiler` (motivated by SuperSandro2000) `#D1824` f629698 11aa4ab 7bb10a7
  - util (`ble/string#split`): optimize `#D1826` 7bb10a7
  - global: avoid passing arbitrary strings through `awk -v var=value` `#D1827` 82232de
  - edit: properly set `LINENO` for `PS1`, `PROMPT_COMMAND`, and `DEBUG` `#D1830` 4d24f84
- complete: generate command names in background with slow WSL2 `PATH`s (contributed by musou1500) `#D2280` 0914a119

## Compatibility

- term: work around quirks of Solaris xpg4 awk `#D1481` 6ca0b8c
- term: support key sequences and control sequences of Solaris console `#D1481` 6ca0b8c
- term: work around Cygwin-console bug of bottom `IL`/`DL` `#D1482` 5dce0b8
- term: work around leaked <kbd>DA2R</kbd> in screen from outside terminal `#D1485` e130619
- complete: work around `fzf` completion settings loaded automatically `#D1508` 4fc51ae
- complete: work around `bash-completion` bugs (reported by oc1024) `#D1533` 9d4ad56
- main: work around MSYS2 .inputrc (reported by n1kk) `#D1534` 9e786ae
- util (`modifyOtherKeys`): work around a quirk of kitty (reported by NoahGorny) `#D1549` f599525
  - util (`modifyOtherKeys`): update the workaround for a new quiark of kitty `#D1627` 3e4ecf5
  - util (`modifyOtherKeys`): use the kitty protocol for kitty 0.23+ which removes the support of `modifyOtherKeys` (reported by kovidgoyal) `#D1681` ec91574
  - util (`modifyOtherKeys`): set up `modifyOtherKeys` only after `DA2` (reported by dongxi8) `#D1885` 149eee9
- global: work around empty `vi_imap` cache by `tmux-resurrect` `#D1562` 560160b
- decode: identify `kitty` and treat `\e[27u` as isolated ESC (reported by lyiriyah) `#D1585` c2a84a2
- complete: suppress known error messages of `bash-completion` (reported by oc1024, Lun4m) `#D1622` d117973
- decode: work around kitty keypad keys in modifyOtherKeys (reported by Nudin) `#D1626` 27c80f9
- main: work around `set -B` and `set -k` `#D1628` a860769
- term: disable `modifyOtherKeys` and do not send `DA2` for `st` (requested by Shahabaz-Bagwan) `#D1632` 92c7b26
- cmap: add `st`-specific escape sequences for cursor keys `#D1633` acfb879
- cmap: distinguish <kbd>find</kbd>/<kbd>select</kbd> from <kbd>home</kbd>/<kbd>end</kbd> for openSUSE `inputrc.keys` (reported by cornfeedhobo) `#D1648` c4d28f4
  - cmap: freeze the internal codes of <kbd>find</kbd>/<kbd>select</kbd> and kitty special keys `#D1674` fdfe62a
- main: work around self-modifying `PROMPT_COMMAND` by `bash-preexec` (reported by cornfeedhobo) `#D1650` 39ebf53
  - main: fix an infinite loop on `ble-reload` with externally saved `PROMPT_COMMAND` (reported by tars0x9752) `#D1851` 53af663
- decode: work around openSUSE broken `/etc/inputrc` `#D1662` e5b0c86
- decode: work around the overwritten builtin `set` (reported by eadmaster) `#D1680` a6b4e2c
- complete: work around the variable leaks by `virsh` completion from `libvirt` (reported by telometto) `#D1682` f985b9a
- stty: do not remove keydefs for <kbd>C-u</kbd>, <kbd>C-v</kbd>, <kbd>C-w</kbd>, and <kbd>C-?</kbd> (reported by laoshaw) `#D1683` 82f74f0
- builtin: print usages of emulated builtins on option errors `#D1694` 6f74021
- decode (`ble/builtin/bind`): improve compatibility of the deprecated form `bind key:rlfunc` (motivated by cmplstofB) `#D1698` b6fc4f0
  - decode (`ble/builtin/bind`): fix a bug that only lowercase is accepted for deprecated form `bind key:rlfunc` (reported by returntrip) `#D1726` a67458e e363f1b
- complete: work around a false warning messages of gawk-4.0.2 `#D1709` 9771693
- main: work around `XDG_RUNTIME_DIR` of a different user by `su` (reported by zim0369) `#D1712` 8d37048
- main (`ble/util/readlink`): work around non-standard or missing `readlink` (motivated by peterzky) `#D1720` a41279e
  - util (`ble/function#pop`): allow popping unset function `#D1834` c0abc95
- menu (`menu-style:desc`): work around xenl quirks for relative cursor movements (reported by telometto) `#D1728` 3e136a6
- global: work around the arithmetic syntax error of `10#` in Bash-5.1 `#D1734` 7545ea3
- global: adjust implementations for Bash 5.2 `patsub_replacement` `#D1738` 4590997
  - global: work around `compat42` quoting of `"${v/pat/"$rep"}"` `#D1751` a75bb25
  - prompt: fix a bug of `ble/prompt/print` redundantly quoting `$` `#D1752` a75bb25
  - global: identify bash-4.2 bug that internal quoting of `${v/%$empty/"$rep"}` remains `#D1753` a75bb25
  - global: work around `shopt -s compat42` `#D1754` a75bb25
- global (`ble/builtin/*`): work around `set -eu` in NixOS initialization (reported by SuperSandro2000) `#D1743` 001c595
- util, edit, contrib: add support for `bash-preexec` (motivated by SuperSandro2000) `#D1744` e85f52c
  - util (`ble/builtin/trap`): fix resetting `$?` and `$_` (reported by SuperSandro2000) `#D1757` dfc6221
  - util (`ble/builtin/trap`): fix a failure of setting the trap-handler exit status (reported by SuperSandro2000) `#D1771` c513ed4
  - edit (`TRAPDEBUG`): partially restore `$_` after `DEBUG` trap (reported by aiotter) `#D1853` 0b95d5d
- main: check `IN_NIX_SHELL` to inactivate ble.sh in nix-shell (suggested by SuperSandro2000) `#D1747` b4bd955
  - main: force prompt-attach inside the nix-shell `rc` `#D1766` ceb2e7c
- canvas: test the terminal for the sequence of clearing `DECSTBM` `#D1748` 4b1601d
- main: check `/dev/tty` on startup (reported by andychu) `#D1749` 711c69f
  - main: fix the check of tty on stdin/stdout `#D1833` 80f09c9
- util: add identification of Windows Terminal `wt` `#D1758` e332dc5
- complete: evaluate words for `noquote` (motivated by SuperSandro2000) `#D1767` 0a42299
- edit (TRAPDEBUG): preserve original `DEBUG` trap and enabled it in `PROMPT_COMMAND` (motivated by ammarooo) `#D1772` `#D1773` ec2a67a
  - main, trap: fix initialization order of `{save,restore}-BASH_REMATCH` (reported by SuperSandro2000) `#D1780` 689534d
- global: work around bash-3.0 bug that single quotes remains for `"${v-$''}"` `#D1774` 9b96578
- util: work around old `vte` not supporting `DECSCUSR` yet setting `TERM=xterm` (reported by dongxi8) `#D1785` 70277d0
- progcomp: work around the cobra V2 description hack (reported by SuperSandro2000) `#D1803` 71d0736
- complete: work around blocking `_scp_remote_files` and `_dnf` (reported by iantra) `#D1807` a4a779e 46f5c13
- history: work around broken timestamps in `HISTFILE` (reported by johnyaku) `#D1831` 5ef28eb
- progcomp: disable `command_not_found_handle` (reported by telometto, wisnoskij) `#D1834` 64d471a d5fe1d1 973ae8c
- util (`modifyOtherKeys`): work around delayed terminal identification `#D1842` 14f3c81
  - util (`modifyOtherKeys`): fix a bug that kitty protocol is never activated `#D1842` 14f3c81
- util (`modifyOtherKeys`): pass-through kitty protocol sequences (motivated by ferdinandyb) `#D1845` f66e0c1
- main: show warning for empty locale (movivated by Ultra980) `#D1927` 92f2006
- main: never load `/etc/inputrc` in openSUSE (motivated by Ultra980) `#D1926` 92f2006 0ceb0cb
- canvas: refine detection of `bleopt char_width_mode=musl` `#D1929` b0c16dd
- term (`terminology`): work around terminal glitches `#D1946` 9a1b4f9
- main (`ble/bin/awk`): add workaround for macOS `awk-32` `#D1974` e2ec89c
- util.hook: workaround bash-5.2 bug of nested read by `WINCH` `#D1981` a5b10e8
  - main (`ble/base/adjust-builtin-wrappers`): fix persistent tempenv `IFS=` in bash-5.0 (reported by pt12lol) `#D2030` 5baf6f63
- edit: always adjust the terminal states with `bind -x` (reported by linwaytin) `#D1983` 5d14cf1
  - edit: restore `PS1` while processing `bind -x` (reported by adoyle-h) `#D2024` 2eadcd5b
- syntax: suppress brace expansions in designated array initialization in Bash 5.3 `#D1989` 1e7b884
- progcomp: work around slow `nix` completion `#D1997` 2c1aacf
- complete: suppress error messages from `_adb` (reported by mozirilla213) `#D2005` f2aa32b0
- util: test the UTF-8 support of the current `LC_CTYPE` `#D2281` 537c6504 aa1b6f35

## Test

- github/workflows: add CI checks in macOS and msys2 (requested by aiotter) `##D1881` c5ddacc
  - github/workflows (nightly): add check for macOS (contributed by aiotter) `#D1881` 4cb0baa
  - github/workflows (nightly, test): interchange setup `#D1881` 4cb0baa
  - github/workflows: add `test.yml` `#D1881` 824dc53
  - fix for macOS tests
    - test (ble/util/c2s): fix locale settings in tests `#D1881` 26ed622
    - test (ble/util/msleep): loosen the condition `#D1881` 26ed622
    - test (ble/util/msleep): skip test in CI `#D1881` 26ed622
  - fix for msys2 tests
    - test: ensure a non-empty locale `#D1881` c5d1b82
    - test (ble/util/readlink): work around msys symlinks `#D1881` c5d1b82
    - test (ble/util/declare-print-definitions): skip array assignments involing CR in msys `#D1881` c5d1b82
    - test (ble/util/is-stdin-ready): skip test in the CI msys `#D1881` c5d1b82
    - main (bind): suppress non-interactive warning in msys `#D1881` c5d1b82
    - canvas (GraphemeClusterBreak): handle surrogate pairs for UCS-2 `wchar_t` `#D1881` 18bf121
    - util (ble/encoding:UTF-8/b2c): fix interpretation of leading byte `#D1881` 2e1a7c1
    - util (ble/util/s2c): work around intermediate mbstate of bash <= 5.2 `#D1881` 2e1a7c1
    - util (ble/util/s2bytes): clear locale cache `#D1881` 2e1a7c1
  - complete: fix syntax error for bash-3.0 `#D1881` 0b3e611
  - github/workflows: work around grep-3.0 which crashes in windows-latest `#D1915` fb7bd0b
- test (ble/util/writearray): use `ble/file#hash` instead of `sha256sum` `#D1882` b76e21e
- test (ble/util/readlink): work around external aliases `#D1890` 0c6291f

## Internal changes and fixes

- main: include hostname in local runtime directory `#D1444` 6494836
- global: update the style of document comments ff4c4e7
- util: add function `ble/string#quote-words` `#D1451` f03b87b
- syntax (`ble/syntax:bash/simple-word/eval`): cache `#D1453` 6d8311e
  - syntax (`simple-word/eval`): support `opts=single` for a better cache performance (motivated by 3ximus) `#D1464` 10caaa4
- global: refactor `setup => set up / set-up` `#D1456` c37a9dd
- global: clean up helps of user functions `#D1459` 33c283e
- benchmark (`ble-measure`): support `-T TIME` and `-B TIME` option `#D1460` 1aa471b
- util, color (`bleopt`, `blehook`, `ble-color-setface`): support `--color` and fix `sgr0` contamination in non-color output `#D1466` 69248ff
- global: fix status check for read timeout `#D1467` e886883
- decode: move `{keymap/*. => lib/core-decode.*-}rlfunc.txt` and clean up files `#D1486` f7323b4
  - Makefile: fix up f7323b4: restore rule for `keymap/*.txt` `#D1496` 054e5c1
- util, etc: ensure each function to work with arbitrary `IFS` `#D1490` `#D1491` 5f9adfe
- tui, canvas (`ble/canvas/trace`): support `opts=clip` `#D1493` 61ce90c
- tui, edit: add a new render mode for full-screen applications 817889d
- test (`test-canvas`): fix dependency on `ext/contra` `#D1525` c89aa23
- util: inherit special file descriptors `#D1552` 98835b5
  - util: fix a bug that old tty is used in new sessions `#D1586` 0e55b8e
- global: use `_ble_term_IFS` `#D1557` d23ad3c
- global: work around `localvar_inherit` for varname-list init `#D1566` 5c2edfc
- util: fix `ble/util/dense-array#fill-range` a46fdaf
- util: fix leak variables `buff`, `trap`, `{x,y}{1,2}` `#D1572` 5967d6c
- util: fix leak variables `#D1643` fcf634b
- edit (`command-help`): use `ble/util/assign/.mktmp` to determine the temporary filename `#D1663` 1af0800
- make: update lint check `#D1709` 7e26dcd
- test: save the test log to a file `#D1735` d8e6ea7
- benchmark: improve determination of the base time `#D1737` ad866c1
- make: add fallback Makefile for BSD make `#D1805` e5d8d00c
- main: support `bleopt debug_xtrace` (requested by SuperSandro2000) `#D1810` 022d38b
- test: clean up check failures by `make check` and `make scan` `#D1812` bb3e0a3
- util (`fd#alloc`): limit the search range of free fds `#D1813` 43be0e4 4c90072
- github/workflows: define an action for the nightly builds (contributed by uyha) `#D1814` a3082a0
- global: quote numbers for unexpected `IFS` `#D1835` 0179afc
- history: refactor hooks `history_{{delete,clear,insert} => change}` `#D1860` c393c93
- history: rename the hook `history_{on => }leave` `#D1860` c393c93
- make: check necessary `.git` `#D1887` 0f7c04b
- benchmark (zsh): fix for `KSH_ARRAYS` `#D1886` a144ffa 8cb9b84
- benchmark: support for ksh as `benchmark.ksh` `#D1886` 5dae4da
- github/workflows (build): rename directory in `ble-nightly.tar.xz` to `ble-nightly` (reported by Harduex) `#D1891` f20854f 4ea2e23 43c6d4b
- edit: update prompts on g2sgr change `#D1906` 40625ac
- util, decode, vi: fix leak variables `#D1933` 8d5cab8
- util: support `bleopt debug_idle` `#D1945` fa10184
- global: work around bash-4.4 no-argument return in trap `#D1970` eb4ffce
- util: replace builtin `readonly` with a shell function (requested by mozirilla213) `#D1985` 8683c84 e4758db
  - util (`ble/builtin/readonly`): show file and line in warnings `#D2015` 467fa448 2c9b56d7
- global: avoid directly using `/dev/tty` `#D1986` a835b83
- util: add `ble/util/message` `#D2001` 2a524f34
- global: normalize bracket expressions to `_a-zA-Z` / `_a-zA-Z0-9` `#D2006` 41faa494
- global: fix leak variables `#D2018` 6f5604de
- edit: handle nested WINCH properly `#D2020` a6b2c078
- make: include the source filenames in the installed files (suggested by bkerin) `#D2027` 610fab39

## Contrib

- prompt-git: detect staged changes `#D1718` 2b48e31
- prompt-git: fix a bug that information is not updated on reload `#D1732` 361e9c5
- config/execmark: show exit status in a separate line `#D1828` 4d24f84
  - config/execmark: add names of exit statuses `#D2019` a6b2c078
- prompt-git: ignore untracked files in submodules `#D1829` 4d24f84
- integration/fzf
  - fzf-completion: fix integration (reported by ferdinandyb) `#D1837` 12c022b
  - fzf-completion: remove `noquote` (reported by MK-Alias) `#D1889` 0c6291f
  - fzf-initialize: check directory existence before adding it to `PATH` (reported by Strykar) `#D1904` 09bb4d3
  - fzf-key-bindings: fix a problem that `modifyOtherKeys` is not reflected (reported by SuperSandro2000) `#D1908` 486564a
  - fzf-completion: quote only with `filenames` when `ble/syntax-raw` is specified (reported by christianknauer) `#D1978` 8965b61
- integration/zoxide
  - complete, contrib: add completion integration with `zoxide` (reported by ferdinandyb) `#D1838` a96bafe
  - zoxide: update `contrib/integration/zoxide` for zoxide v0.8.1 `#D1907` 3bc3bea
  - zoxide: adjust `zoxide icanon` (reported by linwaytin) `#D1993` dc7de6b
- README: update description on `_ble_contrib_fzf_base` (reported by Strykar) `#D1904` 09bb4d3
- colorglass: add color filter `#D1902` 88e74cc
  - colorglass: add `bleopt colorglass_{saturation,brightness}` (motivated by auwsom) `#D1906` 40625ac
- add `histdb` `#D1925` 44d9e10
  - histdb: support auto-complete source `histdb-word` `#D1938` 00cae74
  - histdb: automatically upgrade histdb version `#D1940` 4fac1e3
  - histdb: support auto-complete source `histdb-history` `#D1941` 4fac1e3
  - histdb: handle multiple exec lines for `histdb_ignore` `#D1942` 36e1c89
  - histdb: kill orphan `sqlite3` processes `#D1943` 36e1c89
  - histdb: back up the database `#D1944` 36e1c89
  - histdb: fix miscellaneous SQL query errors `#D1947` 46ac426
  - histdb: output error messages to tty `#D1952` 651c70c
  - histdb: fix remaining debug function name "assign{2 => }" in bash <= 3.2 `#D1953` 651c70c
  - histdb: fix a problem that the background process fails to start in bash-3.0 `#D1956` 651c70c
  - histdb: fix a bug that history search fails with a single quote in the commandline `#D1957` 651c70c
  - histdb: fix `histdb-word` completions in the middle of the commandline `#D1968` adaec05
  - histdb: support `bleopt histdb_remarks` `#D1968` adaec05
  - histdb: support timeout of background processes `#D1971` e0566bd
  - histdb: enable database timeout for transactions `#D1982` a5b10e8
  - histdb: fix `.timeout` not set for background `sqlite3` `#D1982` 20b42fa
  - histdb: suppress color codes in the default `histdb_remarks` `#D1968` 20b42fa
  - histdb: disable timeout of background processes in Bash 3.2 `#D1992` 20b42fa
  - histdb: rewrite to use `ble/util/bgproc` `#D2017` 7803305f
- integration: move `fzf` and `bash-preexec` integrations to subdir `#D1939` 86d9467

<!---------------------------------------------------------------------------->
# ble-0.4.0-devel2

2020-01-12 -- 2020-12-02 (`#D1215`...`#D1426`) c74abc5...276baf2

## New features

- complete: support `bleopt complete_auto_wordbreaks` (suggestion by dylankb) `#D1219` c294e31
- main: check `~/.config/blesh/init.sh` `#D1224` a82f961
- progcolor: support programmable highlighting `#D1218` 0770234 `#D1244` 9cb3583 `#D1245` 8e8a296 `#D1247` 154f638 `#D1269` fa0036c
- decode/kbd: support <kbd>U+XXXX</kbd>, <kbd>@ESC</kbd> and <kbd>@NUL</kbd> for keynames `#D1251` 441117c ef23ad1
- syntax: support `coproc` `#D1252` 7ff68d2
- vi/nmap: support readline widgets for <kbd>M-left</kbd>, <kbd>M-right</kbd>, <kbd>C-delete</kbd>, <kbd>#</kbd> and <kbd>&</kbd> `#D1258` 846e0be
- complete: add `compopt -o quote/default` for `fzf` (motivated by dylankb) `#D1275` 58e1be4
- util (`ble-import`): support an option `-d` (`--delay`) `#D1285` 9673e4e
- syntax: support parameter expansion of the form `${var/#pat}`, `${var/%pat}` `#D1286` e2f4809
- edit: support `bleopt editor line_limit_{type,length} history_limit_length` `#D1295` 2f9a000
- edit: support widgets `{vi,emacs}-editing-mode` `#D1301` 0c6c76e
- syntax: allow unquoted `[!` and `[^` in `simple-word` (reported by cmplstofB) `#D1303` 1efe833
- util (`ble/util/print-global-definitions`): support arrays and unset variables (test-util) 6e85f1c
- util (`ble/util/cat`): support NUL and multiple files (test-util) d19a9af
- edit: support Bash 5.1 `READLINE_MARK` and `PROMPT_COMMANDS` `#D1328` e97a858 `#D1338` 657bea5
  - edit, main: support array PROMPT_COMMAND in bash-5.1 `#D1380` b852a4f
- syntax: support confusing parameter expansions like `${#@}`, etc. `#D1330` b7b42eb
- contrib: add contrib for user settings `#D1335` f290115
- syntax: support `${var@UuLK}` in Bash 5.1 `#D1336` 04da4dd
- main: add an option `--test` `#D1340` 1410c72
- util (`ble/builtin/trap`): support `return` in `INT`/`EXIT`/`WINCH` `#D1347` `#D1348` 3865488
- history: support timestamp (reported by rux616) `#D1351` 4bcbd71 `#D1356` 350bb15 `#D1364` 1d8adf9
- edit: support Bash 4.4 `PS0` `#D1357` 23a1ac5
- vi: support `bleopt keymap_vi_mode_{update_prompt,show,name_*}` (suggested by Dave-Elec) `#D1365` 76be6f1
- prompt: support prompt sequence `\q{...}` `#D1365` 76be6f1
- edit: support `bind 'set show-mode-in-prompt'` `#D1365` 76be6f1
  - prompt: fix a bug that mode string is not shown in `auto_complete` and other sub-modes (reported by tigger04) `#D1371` f6fc7ff
  - prompt: redraw prompts on the prompt content change (reported by tigger04) `#D1371` 1954a1e
- prompt: support `bleopt prompt_{{ps1,rps1}{_final,_transient}}` (suggested by Dave-Elec) `#D1366` 06381c9
  - prompt: fix a bug that prompt are always re-insntiated for every rendering `#D1374` 0770cda
  - prompt: fix a bug that rprompt is not cleared when `bleopt prompt_rps1` is reset `#D1377` 1904b1d
  - prompt: fix a bug that prompts updated by `PROMPT_COMMAND` are not reflected immediately (reported by 3ximus) `#D1426` bbda197
- edit: support Bash 5.1 widgets `#D1368` e747ee3
- color: support `TERM=*-direct` `#D1369` 0d38897 `#D1370` f7dc477
- complete: support `bleopt complete_auto_menu` `#D1373` 77bfabd
  - complete: fix a problem of frequent bells with auto-menu activated `#D1381` 3b1d8ac
- complete: support `bleopt complete_menu_maxlines` `#D1375` 8e81cd7
- prompt: support `_ble_prompt_update` `#D1376` 0fa8739
- prompt: support `bleopt prompt_{xterm_title,screen_title,status_line}` `#D1378` 5c3f6fe
  - prompt: check `TERM` for prompt window titles when `_ble_term_TERM` is unavailable `#D1388` 3c88869
- syntax: support options `bleopt highlight_{syntax,filename,vartype}` to turn off highlighting (requested by pjmp) `#D1379` 0116f8b
- complete: support `shopt progcomp_alias` `#D1397` d68afa5
- complete: generate completions of options based on man pages `#D1405` 8183455
  - complete (mandb): fix a bug that `bleopt complete_menu_style` is globally changed `#D1412` b91fd10
- highlight: support colon separated lists of paths `#D1409` 2f40422
  - highlight: fix a bug that non-simple words are always highlighted as `syntax_error` (reported by cmplstofB) `#D1411` 46e2ac6
  - highlight: fix a bug that words are sometimes unhighlighted `#D1418` 4395484
  - highlight: fix a bug that non-existent directories are not highlighted in the command name context `#D1419` 4395484
- highlight: support options `#D1410` 2f40422
  - highlight: support highlighting of `declare` command options `#D1420` f0df481
  - highlight: fix unhighlighted tilde expansions `~+` (reported by cmplstofB) `#D1424` a32962e

## Changes

- highlight: highlight symlink directories as symlinks `#D1249` 25e8a72
- auto-complete: bind `insert-on-end` to `C-e` `#D1250` 90b45eb
- edit (`widget/shell-expand-line`): not quote expanded results by default `#D1255` a9b7810
- decode: refactor
  - decode: delay bind until keymap initialization `#D1258` 0beac33
  - decode: read user settings from `bind -Xsp` `#D1259` eef14d0
  - decode: fix a bug of `ble-bind` with uninitialized cmap `#D1260` 5d98210
  - decode: fix error messages of BSD `sed` rejecting unencoded bytes from `bind -p` (reported by dylankb) `#D1277` 0cc9160
- edit: provide proper `$BASH_COMMAND` and `$_` for PS1, PROMPT_COMMAND, PRECMD, etc. `#D1276` 7db48dc
- edit (quoted-insert): insert literal key sequence `#D1291` 420c933
- decode: support `decode_abort_char` for `modifyOtherKeys` `#D1293` ad98416
- edit (edit-and-execute): disable highlighting of old command line content `#D1295` 2f9a000
- util (`bleopt`): fail when a specified bleopt variable does not exist (test-util) 5966f22
- builtin: let redefined builtins return 2 for `--help` `#D1323` 731896c
- edit: preserve `PS1` when `internal_suppress_bash_output` is set `#D1344` 6ede0c7
- complete: complete param expan in additional contexts `#D1358` 3683305
- main: reload on ble-update when ble.sh is already updated `#D1359` a441d4d
- main (`ble-update`): clone github repository if the original repository is not found `#D1363` 6e3b3b5
- util (bleopt): change output format d4b12cd
- syntax: allow `time -- command` for Bash 5.1 `#D1367` 00d0e93
- menu: preserve columns with `{forward,backward}-line` `#D1396` 3d5a341
- syntax: rename `ble_debug` to `bleopt syntax_debug` `#D1398` 3cda58b
- syntax: change a style of buffer contents in `bleopt syntax_debug` `#D1399` 3cda58b
- complete: change to generate filenames starting from `.` by default (motivated by cmplstofB) `#D1425` 987436d

## Fix

- util (ble/builtin/trap): fix argument analysis for the form `trap INT` (reported by dylankb) `#D1221` db8b0c2
- main: fix an error message on ristricted shells `#D1220` b726225
- edit: fix a bug that the shell hangs with `source ble.sh --noattach && ble-attach` (reported by dylankb) `#D1223` 59c1ce4 3031007
- edit: fix a bug that the textarea state is not properly saved (reported by cmplstofB) `#D1227` 06ae2b1
- syntax: support hexadecimal literals for arithmetic expression (reported by cmplstofB) `#D1228` 90e4f35
- history: fix a bug that history append does not work with `set -C` (reported by cmplstofB) `#D1229` 604bb8b
- decode (`ble/builtin/bind`): fix widget mapping for `default_keymap=safe` `#D1234` 750a9f5
- main (ble-update): fix a bug that the check of `make` does not work in Bash 3.2 `#D1236` 08ced81
- syntax: fix a infinite loop for variable assignments and parameter expansions `#D1239` 327661f
- complete: clear menu on history move `#D1248` 06cc7de
- syntax: fix a bug that arguments of `eval` are not highlighted `#D1254` 5046d14
- decode: fix error message `command=${[key]-}` for mouse input `#D1263` 09bb274
- [ble-0.3] reload: fix a bug that the state is broken by `ble-reload` `#D1266` f2f30d1
- decode (`ble/builtin/bind`): remove comment from bind argument `#D1267` 880bb2c
- decode: use `BRE` instead of `ERE` for `POSIX sed` (reported by dylankb) `#D1283` 2184739
- decode: fix strange behaviors after `fzf` (convert <kbd>DEL</kbd> to <kbd>C-?</kbd>) `#D1281` 744c8e8
- edit: work around Bash rebinding on `TERM` change `#D1287` ac7ab55 7a99bf3
- term: work around terminfo/termcap entry collisions in `tput` (reported by killermoehre) `#D1289` f8c54ef
- complete: clear menu on discard-line (reported by animecyc) `#D1290` fb794b3 `#D1315` 99880ef
- vi (vi-command/nth-column): fix a bug in arithmetic expansion (reported by andychu) `#D1292` da6cc47
- complete: fix a bug that insert-word does not for with ambiguous candidates `#D1295` 2f9a000
- complete: fix a bug that menu-filter is only partially turned off by `complete_menu_filter` `#D1298` b3654e2
- decode: fix error messages for unsupported readline functions `#D1301` 91bdb64
- global: work around `shopt -s assoc_expand_once` `#D1305` 31908e1
- global: work around `TMOUT` for `builtin read` `#D1306` 1c22a9d
- syntax: fix failglob errors of heredocs of the form `<<$(echo A)` `#D1308` 3212fd2
- decode (`ble-bind`): fix an error message `#D1311` c868b6d
- util (`bleopt`): fix a bug that a new setting is not defined with `name:=` (test-util) `#D1312` c757b92
- util (`ble/util/{save,restore}-vars`): fix a bug that `name` and `prefix` cannot be saved/restored (test-util) 5f2480c
- util: fix `ble/is-{inttype,readonly,transformed}` (test-util) 485e1ac
- util (`ble/path#remove{,-glob}`): fix corner cases (test-util) ccbc9f8
- history: fix a problem that the history is doubled by `history -a` in `bashrc` `#D1314` 34821fe
- util (`ble/variable#get-attr`): fix an error message with special variable names such as `?` and `*` `#D1321` 557b774
- util (has-glob-pattern): fix abort in subshells (test-util) `#D1326` dc292a2
- edit: fix a bug that `set +H` is cancelled on command execution `#D1332` 02bdf4e
- syntax (`ble/syntax/parse/shift`): fix a bug of shift skip in nested words `#D1333` 65fbba0
- global: work around Bash-4.4 `return` in trap handlers `#D1334` aa09d15
- util (`ble-stackdump`): fix a shift of line numbers `#D1337` a14b72f d785b64
- edit (`ble-bind -x`): check range of `READLINE_{POINT,MARK}` `#D1339` efe1e81
- main: fix a bug that `~/.config/blesh/init.sh` is not detected (GitHub #53 by rux616) 61f9e10
- util (`ble/string#to{upper,lower}`): work around `LC_COLLATE=en_US.utf8` (test-util) `#D1341` 1f6b44e `#D1355` 4da6103 5f0d49f
- util (encoding, keyseq): fix miscelleneous encoding bugs (test-util) 435bd16
  - `ble/util/c2keyseq`: work around bash ambiguous keyseq `\M-\C-\\`
  - `ble/util/c2keyseq`: fix a bug that `C1` characters are not properly encoded
  - `ble/util/keyseq2chars`: fix a bug that `\xHH` is not properly processed
  - `ble/encoding:UTF-8/b2c`: work around Bash-4.2 arithmetic crash
  - `ble/encoding:UTF-8/b2c`: fix a bug that `G0` characters lose its seventh bit
  - `ble/encoding:UTF-8/c2b`: fix a bug that the first byte gets redundant bits
- edit: work around `WINCH` not updating `COLUMNS`/`LINES` after `ble-reload` `#D1345` a190455
- complete: initialize `bleopt complete_menu_style` options before `complete_load` hook (reported by rux616) `#D1352` 8a9a386
- main: fix problems caused by multiple `source ble.sh` in bashrc `#D1354` 5476933
- syntax: allow single-character variable name in named redirections `{a}<>` `#D1360` 4760409
- complete: quote `#` and `~` at the beginning of word `#D1362` f62fe54
- decode (`bind`): work around `shopt -s nocasematch` (reported by tigger04) `#D1372` 855cacf
- syntax (tree-enumerate): fix unmodified `wtype` of reconstructed words at the end `#D1385` 98576c7
- complete: fix a bug that progcomp retry by 124 caused the default completion again `#D1386` 98576c7
- complete: fix bugs that quotation disappears on ambiguous completion `#D1387` 98576c7
- complete: fix a bug of duplicated completions of filenames with spaces `#D1390` 98576c7
- complete: fix superlinear performace of ambiguous matching globpat `#D1389` 71afaba
- prompt: fix extra spaces on line folding before double width character `#D1400` d84bcd8
- prompt: fix a bug that lonig rps1 is not correctly turned off `#D1401` d84bcd8
- syntax (glob bracket expression): fix a bug of unsupported POSIX brackets `#D1402` 6fd9e22
- syntax (`ble/syntax:bash/simple-word/evaluate-path-spec`): fix a bug of unrecognized `[!...]` and `[^...]` `#D1403` 0b842f5
- complete (`cd`): fix duplicate candidates by `CDPATH` (reported by Lennart00 at `oh-my-bash`) `#D1415` 5777d7f
- complete (`source:file`): fix a bug that tilde expansion candidates are always filtered out `#D1416` 5777d7f
- complete: fix a problem of redundant unmatched ambiguous part with tilde expansions in the common prefix `#D1417` 5777d7f
- highlight: fix remaininig highlighting of vanishing words `#D1421` `#D1422` 1066653
- complete: fix a problem that the user setting `dotglob` is changed `#D1425` 987436d

## Compatibility

- main: work around cygwin uninitialized environment `#D1225` `#D1226` b9278bc
- global: work around Bash 3.2 bug of array initialization with <kbd>SOH</kbd>/<kbd>DEL</kbd> `#D1238` defdbd4 `#D1241` 1720ec0
- term: support `TERM=minix` `#D1262` ae0b80f
- msys2: support2 MSYS (motivated by SUCHMOKUO) `#D1264` 47e2863
  - edit: support `\$` in `PS1` for MSYS2 `#D1265` f6f8956
  - msys2: work around MSYS2 Bash bug of missing <kbd>CR</kbd> `#D1270` 71f3498
  - cygwin, msys2: support widget `paste-from-clipboard` `#D1271` cd26c65
- msys1: support MSYS1 `#D1272` 630d659
  - msys1: work around missing named pipes in MSYS1 `#D1273` 6f6c2e5
- term: support contra `SPD` `#D1288` 1e65f2c
- decode: work around Bash-4.1 bug that locale not applied with `LC_CTYPE=C eval command` (test-util) b2c7d1c
- util (`ble/variable#get-attr`): fix a bug that attributes are not obtained in Bash <= 4.3 (test-util) b2c7d1c
- decode: work around Bash-3.1 bug of `declare -f` rejecting special characters in function names (test-util) b2c7d1c
- edit (`ble/widget/bracketed-paste`): fix error messages on `paste_end` in older version of Bash (test-util) b2c7d1c
- decode: work around Bash-4.1 arithmetic bug of array subscripts evaluated in discarded branches `#D1320` 557b774
- complete: follow Bash-5.1 change of arithmetic literal `10#` `#D1322` 557b774
- decode: fix a bug of broken cmap cache found in ble-0.3 `#D1327` 16b56bf
- util (strftime): fix a bug not working with `-v var` option in Bash <= 4.1 (test-util) f1a2818
- complete: work around slow `compgen -c` in Cygwin `#D1329` 5327f5d
- edit: work around problems with `mc` (reported by onelittlehope) `#D1392` e97aa07
  - highlight: fix a problem that the attribute of the last character is applied till EOL `#D1393` 2ddb1ba `#D1395` ef09932

## Internal changes and fixes

- util: merge `ble/util/{save,restore}-{arrs => vars}` `#D1217` 6acb9a3
- internal: merge subdir `test` into `memo` `#D1230` f0c38b6
- ble-measure: improve calibration `DD1231` d3a7a52
- vi_test: fix a bug that test fails to restore the original state `#D1232` 4b882fb
- decode (ble/builtin/bind): skip checking stdin in parsing the keyseq `#D1235` 5f949e8
- syntax: delay load of `ble/syntax/parse` for syntax highlighting `#D1237` bb31b11
- memo: split `memo.txt` -> `note.txt`, `done.txt` and `ChangeLog.md` `#D1243` 31bc9aa 8b0fe34 419155e
- global: check isolated identifiers and leak variables `#D1246` 19cc99d 2e74b6d
- util: add `ble/function#{advice,push,pop}` to patch functions (motivated by dylankb) `#D1275` fbe531a
- util (`ble/util/stackdump`): output to `stdout` instead of `stderr` `#D1279` 9d3c50d
- complete (`ble-sabbrev`): delay initialization `#D1282` dfc4f66
- test: update `lib/test-{core => util}.sh` (reported by andychu) `#D1294` e835b0d
- edit: improve performance of bracketed-paste `#D1296` 0a45596 `#D1300` 3f33dab `#D1302` 5ee06c8 10ad274
- decode: improve performance of `ble-decode-char` `#D1297` 0d9d867
- ext: update `mwg_pp.awk` (for branch osh) 978ea32
- test: add `lib/core-test.sh` `#D1309` 68f8077
- global: do not use `local -i` `#D1310` f9f0f9b
- global: normalize calls of builtins `#D1313` b3b06f7
- test: refactor test `#D1316` `#D1317` 6c2f863
- util (`ble/util/openat`): change to open unused fds `#D1318` 6c2f863
- util: rename `ble/{util/openat => fd#alloc}` `#D1319` 6c2f863
- util (`ble/function#advice remove`): restore original command 149a640
- edit: rename `ble-edit/prompt/*` -> `ble/prompt/*` `#D1365` 76be6f1
- main: use `PROMPT_COMMAND` in bash-5.1 for prompt attach `#D1380` b852a4f
- main: unset `BLE_VERSION`, `_ble_bash`, etc. on `ble-unload` `#D1382` 6b615b6
- util: revisit `ble/variable#is-global` implementation `#D1383` 6b5468f
- cmap: recognize <kbd>SS3 O</kbd> as <kbd>blur</kbd> `#D1384` 445a5ad
- edit (`ble/widget/{accept-line,newline}`): automatically switch widgets by the keymap `#D1391` 5bed6e6
- complete: perform filter in `ble/complete/cand/yield` `#D1404` 7c6b67b 83fa830
  - complete: fix a bug that `ble/cmdinfo/complete:cd` candidates are unfiltered (reported by cmplstofB) `#D1413` 5c17a31
  - complete: fix unfiltered tilde expansions `#D1414` 5777d7f
  - complete: fix candidate filter failure in dynamic sabbrev expansion (reported by darrSonik) `#D1423` dabc515
- syntax, edit: use `type -a -t -- cmd` to get command types hidden by keywords `#D1406` ef2d912
- edit, complete: replace some external commands with Bash builtin `#D1407` 5386e93

<!---------------------------------------------------------------------------->
# ble-0.4.0-devel1

2019-03-21 -- 2020-01-12 (#D1015...#D1215) df4feaa...c74abc5

## New features

- emacs: support widgets `forward-byte` and `backward-byte` `#D1017` b2951ef
- emacs: support arguments of word wise operations `#D1020` 719092c
- emacs: support widgets `{capitalize,downcase,upcase}-xword` `#D1019` 719092c
- emacs: support widgets `alias-expand-line` and `history-and-alias-expand-line` `#D1024` fdaf579
- emacs: support keyboard macros `#D1028` 284668a
  - decode: workaround recursive charlog/keylog `#D1030` ea421a3
- complete: define `menu` keymap `#D1033` abfd060
- emacs: support widgets `kill{,-graphical,-logical}-line` `#D1037` 3bb3d33
- emacs: support a widget `re-read-init-file` `#D1038` ebe2928
- emacs: support widgets `readline-dump-{functions,macros,variables}` `#D1039` 49256a9
- emacs: support widgets `character-search-{for,back}ward` and `delete-forward-char-or-list` `#D1040` 2b20c88
- emacs: support widgets `insert-comment` and `do-lowercase-version` `#D1041` 7aae37b
- main: support options `--version` and `--help` `#D1042` b5ab789
- main: read `.inputrc` as `ble.sh` settings `#D1042` b5ab789
  - decode: fix a bug of error messages on reading `.inputrc` `#D1062` e163b9a
- complete: support widget `menu-complete insert_braces` `#D1043` 3d29c8d
  - complete (insert_braces): reimplement range contraction `#D1044` dc586da
  - complete (insert_braces): remove empty quotations `#D1045` `#D1046` dc586da
  - complete (insert_braces): fix support of replacement of existing part `#D1047` dc586da
- complete: support `complete context=dynamic-history` `#D1048` 4f7b284
- emacs: support a widget `edit-and-execute-command` `#D1050` ca5fe08
- emacs: support widgets `insert-{last,nth}-argument` `#D1051` 24458be
- complete: support `menu-complete backward` `#D1052` 2b0c7e8
- emacs: `history-nsearch-{for,back}ward-again` `#D1053` 60dde2c
- emacs: support widgets `tab-insert`, `tilde-expand` and `shell-expand-line` `#D1054` 156b76e
- emacs: support a widget `transpose-{c,u,s,f,e}words` `#D1055` d72c2d4
- emacs: support `bleopt decode_error_cseq_{abell,vbell,discard}` `#D1056` ab1b8b0
  - decode: fix a bug that cmap cache update is not triggered for `#D1073` f1e7674
- emacs: support a widget `universal-arg` `#D1057` 8b1dd07
- emacs: support kill ring and a widget `yank-pop` `#D1059` 8c9b6e8
- highlight: support job names by `auto_resume` `#D1065` ce46024
- decode: add support for `S8C1T` key sequences `#D1083` 9b7939b
- history: support `bleopt history_share` `#D1100` `#D1099` 305b89f `#D1193` 4838a46
- history: support full multiline history `#D1120` 8cf17f7
  - history: do not synchronize multiline resolution on "history -p" `#D1121` 9e56b7b
  - history.mlfix: suppress errors on Bash 3 `#D1122` 4fe7a0c
  - history: suppress error messages trying to kill background worker on reattach `#D1125` f045fec
- highlight: support dirname colors with pathname expansion, failglob and command names `#D1134` edaf495
- util: introduce `blehook` `#D1139` d1a78fb
  - blehook: support `blehook PRECMD PREEXEC POSTEXEC CHPWD ADDHISTORY` `#D1142` bedc2ba
  - blehook: add `blehook/eval-after-load` `#D1145` c1f7aa9
  - blehook: fix a bug that the definition of specified hooks are not printed `#D1146` a4a7cbc
- highlight: highlight word with the form of URL `#D1150` f48f2d7
- syntax: support syntax/globpat in param expansions `#D1157` `#D1158` 051222e `#D1160` 57b42ba
  - syntax: fix attr of nested extglob in param expansions `#D1159` 2d019f0
- decode: support `ble-bind -T kspecs timeout` for timeout and `lib/vim-arpeggio.sh` (request by divramod) `#D1174` 272344e
- complete: use `WORD*` pathname expansion for candidates on failglob with `WORD` `#D1177` c1b0532
- edit: support `bleopt accept_line_threshold` `#D1178` a3385f6 82a1e0b
- complete: support `bleopt complete_allow_reduction` `#D1181` 03040b7
- edit: support `bleopt exec_errexit_mark` `#D1182` 6adc2df
- color: support true colors `#D1184` bd631ce 5dd6b03
- color (`ble-color-setface`): support reference to another face (reported by cmplstofB) `#D1188` 1885b54 `#D1206` 7e31ad3
- edit: support `shopt -u promptvars` `#D1189` 269ba09
- highlight: highlight variable names and numbers according to its state `#D1210` `#D1211` 93dab7b
- highlight: support `${var@op}` (for bash 4.4) `#D1212` a85bdb8

## Changes

- edit: erase in page on `SIGWINCH` `#D1016` 7625ebe
- edit: the widgets `{kill,copy,delete}-region-or` now receives widgets as arguments `#D1021` bbbd155
- edit: disable aliases for builtins and keywords `#D1023` 61da093
- edit: disable `rps1` in secondary textareas `#D1027` b86709a
- edit: support `$?` in `PROMPT_COMMAND` and `PS1` evaluation `#D1074` 43f2967
- main: change default attach strategy to `--attach=prompt` `#D1076` 197f752
- main: change exit status of `ble-update` when it is already up to date `#D1081` d94f691
- progcomp: improve treatment of `COMP_WORDBREAKS` `#D1094` f6740b5 `#D1098` 6c6bae5
- history: replace builtin `history` `#D1101` 655d73e
  - history: synchronize undo/mark/dirty data with history changes `#D1102` `#D1103` `#D1104` 5367360
  - history: improve performance of `history -r` `#D1105` `#D1106` f204bc7
  - history: fix a problem that history file is doubled with `history -cr` in `PROMPT_COMMAND` `#D1110` e64edb7
  - history: suppress errors on new history file `#D1111` e64edb7 `#D1113` 91f07b6
  - history: fix a problem that `_ble_edit_history` is not synchronized with `history -r` `#D1112` e64edb7
  - history: do not process `_ble_edit_history` in detached state `#D1115` bf3b014
  - history: move history item on delete of current item with `history -d` `#D1114` bf3b014
  - history: fix a problem that history before load of ble.sh is lost `#D1126` 37cd154
  - history: fix problems of history output after `ble-reload` `#D1129` 9c8d858
- history: improve performance of `erasedups` `#D1107` 518e2ee
- history: correctly handle `HISTSIZE` overflow `#D1108` 7be255c
- sabbrev: support sabbrev expansion in wider contexts (reported by cmplstofB) `#D1117` ca6e03d
- main: change loading point of `.inputrc` `#D1127` af758e5
- highlight: do not split command names with `:` and `=` `#D1133` 8a1bd8f
- decode: support DA1 responses sent by some terminals (reported by miba072) `#D1135` 362ab05
- highlight: make brace expansions active for RHS of variable-assignment-form arguments `#D1138` 93cc8da
- main: adjust readline variables for `ble.sh` `#D1148` 36312f7
- edit: update prompt after execution of command through `ble-bind` `#D1151` 27208ea
- blehook: replace builtin `trap` `#D1152` d6c555e 7d4fd03
  - blehook: suppress extra `DEBUG` trap calls `#D1155` 25c3e19
- syntax: allow `},fi,done,esac,then,...` after subshell `()` `#D1165` fdb49f3
- edit: support options `--help` for `read` and `exit` `#D1173` faccc6b
- color (`ble-color-{set,def}face`): list faces without arguments `#D1180` 50327c3
- complete: search completion settings through alias expansion `#D1187` c472809
- history (`ble/builtin/history`): support an option `--help` `#D1192` d4c26c5

## Fixes

- decode: workaround Poderosa that returns `DSR` instead of `CPR` in reply to `DSR(6)` `#D1018` 8e22c17
- isearch: fix a bug to match with the old content of the current line `#D1025` 605dcd0
- vi: fix a bug that quoted-insert is not properly recorded with `qx...q` `#D1026` 06698a4
- decode: fix a bug that chars from nested widgets are not processed immediately `#D1028` c79d89b
- menu: fix a bug that fails to retrieve menu item description `#D1031` c936db8
- menu: fix a bug that menu item color is disabled `#D1032` c936db8
- vbell: fix a bug that persistent vbell is not erased before next vbell `#D1034` a3af6c0
- menu-complete: fix a bug that candidates from menu only contained visible ones `#D1036` 275779f
- menu-complete: fix a bug that original texts were lost on cancel `#D1049` 3bbfef6
- edit: fix a bug that rendering is caused twice `#D1053` c7599a2
- color (layer:region): fix a bug that highlighting is cleared without dirty ranges `#D1053` 23796bc
- edit (nsearch): fix a bug that the search range is narrowed after fail `#D1053` 3b2237e
- edit (nsearch): fix a bug of messages on search fail `#D1053` 3b2237e
- util: fix a bug that SGR of visible-bell remains 799f6d3
- decode: fix a bug of infinite loops on `ble-reload` `#D1077` 0f01bcf `#D1079` fee22b1
- decode: workaround a bash-5.0 bug of `bind -p` `#D1078` b52da28
- complete: workaround slow command candidates generation in Cygwin `#D1080` 376bfe7
- syntax: fix false error highlighting of commands after `}`, `fi`, `done` or `esac` `#D1082` 4ce2753
- decode: fix a bug that modifyOtherKeys did not work at all 1666ec2
- edit: fix a problem that status line vanishes on window resize `#D1085` 467b7a4
  - edit: recalculate prompts after resize `#D1088` b29f248
  - edit: fix the position of cursor after resize `#D1089` b29f248
- decode: fix a bug that `ble-update` breaks keymap cache `#D1086` ab8dad2
- edit (`ble/builtin/read`): suppress noisy job messages and delay caused by vbell `#D1087` 309b9e4
- edit (`ble/builtin/read`): workaround failglob crash on vbell inside `read` `#D1090` 2e6f44c
- edit: workaround a bash bug that history entries are removed by `history -p` `#D1091` 146f9e7
- edit (self-insert): workaround Bash-3.0 bug that ^? cannot be handled properly `#D1093` e09c7b5
- highlight: fix a bug that quoted tilde expansions are processed for filename highlighting `#D1095` 3f1f472
- menu-complete: fix a bug that word is expanded on cancel `#D1097` 001b914
- highlight: fix a problem that empty arguments are highlighted as errors `#D1116` 64ae8ce
- sabbrev: fix a bug that menu-filter is not canceled on some sabbrev expansion `#D1118` 30cc31c
- main: fix a bug that `source ble.sh --noattach` in `ble.sh` sessions hangs `#D1130` d35682a caa46c2 `#D1199`
- syntax: workaround bashbug 3.1/3.2 that `eval` ending with <kbd>\ + LF</kbd> causes error messages `#D1132` a4b7e00
- term: workaround `cygwin` console glitches `#D1143` b79c35f `#D1144` ef19d17
- main: fix a bug that error messages for unsupported shells are not printed `#D1149` 34bd6f8
- main: workaround `set -ex` `#D1153` 06ebf9f
- main: workaround shell variable `FUNCNEST` `#D1154` fa2aa47
- highlight: fix error messages on the command line `a=[` `#D1156` b159ea2
- util: fix a bug of "ble/builtin/trap" not recognizing "-" `#D1161` 11fddba
- init-bind: workaround a bash-5.0 bug that `bind '"\C-\\": ...'` does not work `#D1162` 80edf44
- init-bind: do not use workaround of `C-x` in vi mode `#D1163` e6a3d33
- vi_test: fix test for the macro playing `#D1164` 636517c
- exec: fix a problem that the shell hangs with failglob in pipe `#D1166` ac8ba6e
- complete: fix a problem of delay with path `//` in Cygwin `#D1168` 2cf8cc7
- prompt: fix the expansion of `\w` and `\W` in `PS1` for working directories with double slashes `#D1169` d1288dd
- exec: workaround termination of command execution on syntax error in array subscripts `#D1170` 4f442d0
- history: fix a bug that garbage `__ble_edt__` is added in front of history entries 61f4bd1
- decode: remove debug messages for `ble-bind -s` 64a17c3
- syntax: fix highlighting of `${!var@}` `#D1176` 161ed80
- term: fix `Ss` (`DECSCUSR`) 0c773da
- term: workaround linux console <kbd>CSI \></kbd>, <kbd>CSI M</kbd>, <kbd>CSI L</kbd> `#D1213` `#D1214` 0ec6f0c
- edit: fix exit status of Bash by key binding <kbd>C-d</kbd> `#D1215` a9756e9

## Support macOS, FreeBSD, Arch Linux, Solaris, Haiku, Minix

- util: fix the error message "usage: sleep seconds" on macOS bash 3.2 `#D1194` (reported by dylankb) 6ff4d2b
- decode: recover the terminal states after failing the default keymap initialization `#D1195` (reported by dylankb) 846f284
- main (`ble-update`): use shallow clone `#D1196` 2a20d9c
- main (`$_ble_base_cache`): use different directories for different ble versions `#D1197` 55951d1
- edit (`ble/builtin/read`): fix argument analysis with user-provided `IFS` in Bash 3.2 (reported by dylankb) `#D1198` 7411f06
- global: fix subshell detection in Bash 3.2 `#D1200` ca8df8a
- syntax: workaround Bash-4.1 arithmetic bug `#D1201` f248c52
- Makefile: fix "install" for BSD sed `#D1202` 32c2e1a
- term: support "tput" based on termcap `#D1203` `#D1204` 161af07
- global: adjust for FreeBSD and Arch Linux `#D1205` 6ac5b8c
- global: workaround Solaris awk `#D1207` 74d438d
- util: support Haiku `#D1208` e3de373
  - ble/util/msleep: do not use `read -t time` for Haiku
  - ble/term/stty: check available character settings
  - init-cmap: check termcap settings for <kbd>home</kbd>
- util: support Minix `#D1209` 49e6457
  - ble/util/msleep: do not use `read -t time -u FD` in Minix
  - ble-edit/prompt: does not abbreviate IPv4 address for `\h`
  - Makefile: create directory `dist` for `make dist`

## Internal changes

- complete: isolate menu related codes `#D1029` 43bb074
- global: use `builtin echo` explicitly `#D1035` a6232c2
- decode: re-implement rlfunc2widget without fork `#D1063` d2e7dbe
- blerc: add descriptions `#D1064` d61b6af
- decode: decode mouse events `#D1084` 51fae67
- history: move history related codes to `src/history.sh` `#D1119` 1bfc8eb e5b1980
  - history: move codes related to history prefixes and history searches to `history.sh` `#D1136` 1cda6ff 20024d2
  - history: use common "_ble_history_onleave" for different histories `#D1137` ec19d51
- keymap/vi: deal with textarea local data properly `#D1123` 2ea7cfd
- edit: remove `ble-edit/exec:exec` `#D1131` 0cb9c6d
- global: distinguish exit status 147 and 148 `#D1141` d1a78fb
- global: follow bash syntactic changes on arithmetic command 16e0f0e
- decode: check `bind -X` first to store the original bindings `#D1179` 4057ff0
- complete: resolve collision of flag chars with `shopt -s nocaseglob` `#D1186` 550fb14
- color: change return variable of `ble/color/{,i}face2{g,sgr}` to `ret` `#D1188` 1885b54
- global: workaround `shopt -s xpg_echo` `#D1191` e46f9a3

<!---------------------------------------------------------------------------->
# 2019-03-21

2019-02-09..2019-03-21 (#D0915...#D1015) 949e9a8...df4feaa

## New features

- auto-complete: support <kbd>end</kbd> at the end of line a374635
- decode: replace builtin `bind` for `ble.sh` settings `#D0915`  90ca3be `#D0918` e0cdd15
  - decode: update mapping of rl-functions and widgets for vi_imap and vi_nmap `#D1012` 7fec4b6
  - decode: support `bind [-psPSX] [-quf arg]` `#D1013` 9265f8a
- edit: support <kbd>C-x C-g</kbd>, <kbd>C-M-g</kbd> for `bell` and `cancel` `#D0919` 2e83120
- syntax: support `set +B` `#D0931` 12f80dd
- syntax: support aliased keywords `#D0936` 7054e28
- complete: support `ble-sabbrev -m key=function` `#D0942` bcdf843
- complete: support description of candidates `#D0945` `#D0946` 0fa73bf `#D0977` 96fe498
  - canvas: use ... instead of … when unicode is not available `#D0979` 51e600a
  - canvas (`ble/canvas/trace`): support `opts=truncate:confine` `#D0981` 79916d2
- complete: support insertion of ambiguous common part `#D0947` 3644a8e
- complete: support three levels of ambiguous matching `#D0948` 3644a8e
- complete: support menu item highlight of ambiguous matching `#D0949` 3644a8e
- complete: support menu pages `#D0958` ff43e01 a488e01 `#D0990` 32aeef0
  - menu-complete: show page numbers with `visible-bell` `#D0980` 6297e65
  - menu-complete: fix a bug that height of `menu` is too large (<= bash-4.1) `#D0983` 129a1f0
- edit: support `bleopt rps1=` for the right prompt `#D0959` 90a8915 `#D0964` fa2a874 `#D0970` 87c8348
  - rps1: fix coordinate calculations for rps1 `#D0982` 129a1f0
  - canvas (`ble/canvas/trace`): fix a bug that `measure-bbox` does not work (<= bash-3.1) `#D0988` 7f880de
  - canvas (`ble/canvas/trace`): fix a bug that `x1` and `y1` is not properly updated `#D0988` 7f880de
  - edit: support `bleopt rps1_transient` `#D0993` 44edd38
  - edit: fix a bug that `rps1` is cleared on execution of the command `#D1003` 5780154
  - edit: erase trailing spaces after newlines when `rps1_transient` is enabled `#D1004` 5780154
  - edit: support multiline `rps1` (Note: still restricted to fit in lines of `PS1`) `#D1005` 5780154
- complete: support "bleopt complete_menu_style=desc-raw" `#D0965` 1fd7a3e
- complete: support <kbd>prior</kbd>, <kbd>next</kbd>, <kbd>home</kbd>, <kbd>end</kbd> in `menu_complete` keymap `#D0966` b729d23
- edit: support `bleopt prompt_eol_mark=$'\e[94m[ble: EOF]\e[m'` `#D0968` 6c8b52a
- complete: highlight active ranges of `menu-filter` `#D0969` 500f702 `#D0971` aae8b26
  - menu-filter: cancel `menu-filter` when the word ends `#D0974` 6ce2ad2
  - menu-filter: improve highlight `#D0975` b89f39f
- isearch: show progress bar using unicode chars `#D0978` 51e600a
- main: support `ble-reload` ef51490
- complete: support `source:sabbrev` `#D0994` 5c9e579
- complete: clear menu on <kbd>C-g</kbd> `#D0995` e0f93a2
- vi_imap: support `bleopt keymap_vi_imap_undo=more` `#D0996` 50f8ad2
- util: support `bleopt vbell_align` and `ble-color-setface vbell{,_flash,_erase}` for vbell `#D0997` 325883e
  - vbell: fix a bug that garbages remain on short messages just after longer messages `#D1010` 3e9ff85
- decode: support "bleopt decode_abort_char=28" `#D0998` b110cb9
- complete: support `visible-stats` and `mark-directories` `#D1006` b389b3b
- complete: support `mark-symlinked-directories`, `match-hidden-files` and `menu-complete-display-prefix` `#D1007` fd66194
- canvas: support `bleopt char_width_mode=auto` `#D1011` 3978df3

## Changes

- prompt: support correct handling of escapes `#D0923` 22f9b56
- util (`ble/util/sleep`): adjust delay `#D0934` `#D0935` 5fd5cd6 ad1208b 188cd98
- complete: use candidates in menu if present `#D0939` 52eaf01
  - complete: fix a bug that menu-complete is disabled after `menu-filter` `#D0951` 08cba07
  - complete: fix a bug that wrong action is performed after `menu-filter` `#D0952` 08cba07
  - complete: fix a bug that extra <kbd>TAB</kbd> is needed to enter `menu-complete` `#D0956` aa6bd73
  - complete: fix a bug that candidates are not regenerated on function name completions `#D0961` bbea72e
  - complete: fix a problem that the menu style is reset on `menu-complete` `#D0972` 47c28ff
  - menu-filter: explicitly call `ble/complete/menu-filter` (<= bash-3.2) `#D0986` 1b14b11
- syntax: allow variable assignment in arguments of `eval` `#D0941` 2f2f0eb
- highlight: do not highlight overwrite modes when mark is active `#D0950` 4efe1a9
  - highlight: disable `layer:menu_filter` (<= bash-3.2) `#D0987` 1b14b11
- complete: disable `auto-complete` inside the active range of `menu-filter` `#D0957`
- util (visible-bell): truncate long messages to fit into a line `#D0973` e55ff86
- edit: render prompt immediately on newline `#D0991` cdb8acb `#D1003` 5780154
- syntax: detect syntax errors of `CTX_CMDX1` immediately followed by terminating keywords `#D1001` 7ea02b7
- complete: improve support of `bind 'completion-ignore-case on'` `#D1002` 25ebc55
- complete: preserve original path specifications on ambiguous completion `#D1014` a39d1ac
- complete: append `,` instead of ` ` after completion in brace expansions `#D1015` df4feaa

## Fixes

- main: workaround `set -evx` `#D0930` 698517d
- edit (widget `delete-horizontal-space`): fix a bug that spaces before the cursor is not removed `#D0932` 9290adb
- bleopt: fix a bug that false error messages are output on reload when `failglob` is set `#D0933` 64cdcba c62db26
- decode: fix a bug that <kbd>\\</kbd> cannot be input after reattach `#D0937` a46ada0
- reload: fix a bug that `PS1` is lost on reload with `--attach=prompt` `#D0938` 1107ca8
- main (`--attach=prompt`): workaround rewrite of `PROMPT_COMMAND` `#D0940` 863fd7b
- vi_nmap (`/`, `?`, `n`, `N`): fix search progress `#D0944` f20f840
- complete: fix a problem of slow ambiguous filename matching in nested directories `#D0960` 7b3ee55
- util: improve performance of `ble/{util/{mapfile,assign-array},string#split-lines}` (<= bash-3.2) `#D0985` ae176b2 `#D0989` 36b9a8f f199215
- sabbrev: fix a bug that sabbrev is disabled (<= bash-3.2) `#D0985` 840af29
- util (ble/util/msleep): suppress warnings from `usleep` `#D0984` 8e4180c
- util: fix a problem that <kbd>C-d</kbd> cannot be input in nested Bash 3.1 `#D0992` 88a1b0f
- edit: fix a bug of a redundant newline on `read -e` `#D0999` 700bc91

## Internal changes

- [refactor] info: rename info type `raw` -> `esc` `#D0954` ac86f10
- [refactor] do not use brace expansions for `VARNAMES` `#D0955` 711e7df
- [refactor] `ble-{highlight,complete,syntax}` -> `ble/*` 7aaa660 ae6be66 8ea903c
- [refactor] `ble-edit/info/.construct-text` -> `ble/canvas/trace-text` `#D0973` e55ff86
- rename `ble/complete/action:*/getg` -> `ble/complete/action:*/init-menu-item` `#D1006` b389b3b

<!---------------------------------------------------------------------------->
# 2019-02-09

2018-10-05 -- 2019-02-09 (#D0858..#D0914) 6ed51e7..949e9a8

## New features

- color (`ble-color-setface`): support various spec such as SGR params `#D0860` 82fe96d `#D0861` 257c16d `#D0864` 2eaf2a9
- syntax: corresponds to `bleopt filename_ls_colors` `#D0862` c7ff302 `#D0863` 3c5bacf ec31aab
- vi_omap: support <kbd>v</kbd>, <kbd>V</kbd>, <kbd>C-v</kbd> `#D0865` 54942e0 `#D0866` a9a1638 `#D0867` d3d8ea3 `#D0868` eb848dc
- main: improve support of `[[ -o posix ]]` `#D0871` 07ae3cc `#D0872` 513c543
- main: do not load ble.sh when bash is started by `bash -i -c command` `#D0873` fc23a6d
- main: support `ble-update` `#D0874` fc45be6 `#D0875` 0b50974 `#D0891` d010300 `#D0910` 4743c00 2dc3a3f
- vi_nmap: support <kbd>C-d</kbd>, <kbd>C-u</kbd>, <kbd>C-e</kbd>, <kbd>C-y</kbd>, <kbd>C-f</kbd>, <kbd>next</kbd>, <kbd>C-b</kbd>, <kbd>prior</kbd> `#D0886`
- isearch: use previous needle for empty string search `#D0889` 362fce3
- vi_imap: add a function `ble-decode/keymap:vi_imap/define-meta-bindings` `#D0892` a21d22f
- progcomp: support `complete -I` for Bash 5.0 `#D0895` `#D0896`
- progcomp: support candidates which replace the original text before the cursor `#D0897` 41b8cbb
- progcomp: support `compopt -o nosort|noquote|plusdirs` `#D0898` cc48539
- edit: support <kbd>M-*</kbd> `#D0899` 3fd7d6e
- edit: support <kbd>M-g</kbd>, <kbd>C-x *</kbd>, <kbd>C-x g</kbd> `#D0902` 41797c6
- progcomp: support `COMP_WORDBREAKS` `#D0903` 7cfe425
- complete: support completion of tilde expansion `#D0907` b4fc40c `#D0908` 9fafdb3
- main: support `BLE_VERSION` and `BLE_VERSINFO` (suggested by cmplstofB) `#D0909`
- global: support `--help` for public functions `ble-*` (suggested by cmplstofB) `#D0911` 77d459d f4d03f6 1d191c7 1209ac6 `#D0913` 92d9038

## Changes

- edit: change cursor position after <kbd>u</kbd> `#D0877` 9d5c945
- edit: handle panel layouts `#D0878`--`D0882` 6a26894 `#D0888` c8e0d28
- vi_nmap: support <kbd>z z</kbd>, <kbd>z t</kbd>, <kbd>z b</kbd>, <kbd>z .</kbd>, <kbd>z RET</kbd>, <kbd>z C-m</kbd>, <kbd>z +</kbd>, <kbd>z -</kbd> `#D0886`
- emacs: change M-m M-S-m from `beginning-of-line` to `non-space-beginning-of-line` f77f1aa
- bleopt: rename internal settings to `internal_{ignore_trap,suppress_bash_output,exec_type,stackdump_enabled}` fd042d8
- vi_nmap: change the behavior of <kbd>C-home</kbd>, <kbd>C-end</kbd> to match with those of vim 8682f98
- util (`ble/util/unlocal`): add workaround for Bash-5.0 `localvar_unset` `#D0904` 8677a71
- sabbrev: quote key in printing definitions by `ble-sabbrev` `#D0912` 2994d80

### Fixes

- info: fix a bug that coordinates calculation breaks with Japanese text `#D0858` 67c77dc
- syntax (`extract-command`): fix a bug that extraction of nested commands always fails `#D0859` c3270f6
- complete: fix a bug that the settings `complete -c` does not work `#D0870` 1ca5386 82bb154
- main: fix a bug that the determination of `_ble_base` fails when loaded as `source ble.sh` without specifying the directory of `ble.sh` 201deae
- util: Fixed a bug where `ble/util/assign` did not return the correct return value bd14982
- util: Fixed an issue where nested calls to `ble/util/assign-array` caused mixed contents bd14982
- progcomp: fix a bug that bash-completion does not work properly due to wrong `COMP_POINT` `#D0897` 41b8cbb
- global: fix leak variables `#D0900` 244f965 `#D0906` b8dcbfe 9892d63
- progcomp: fix a problem that completion functions can consume stdin `#D0903` 7cfe425

## Internal changes

- global: properly quote rhs of `[[ lhs == rhs ]]` f1c56ab
- syntax: rename variables `BLE_{ATTR,CTX,SYNTAX}_*` -> `_ble_{attr,ctx,syntax}_*` 1fbcd8b (ref #D0909)

<!---------------------------------------------------------------------------->
# 2018-10-05

2018-09-24 -- 2018-10-05 (#D0825..#D0857 6ed51e7)

## New features
  - highlight: Supports coloring of the right side of variable assignment and array elements `#D0839` 854c3b4
  - nsearch: Supports (non-incremental) history search <kbd>C-x {C-,}{p,n}</kbd> `history-{,substring-,n}search-{for,back}ward` `#D0843` e3b7d8b 0d31cd9 253b52e
  - isearch: If selected before search, restore after search `#D0845` 93f3a0f
  - decode: Display processing progress when there is a large amount of input such as when pasting `#D0848` c2d6100
  - decode: Supports batch string insertion to speed up pasting (`batch-insert`) `#D0849` 48eeb03
  - decode: Switch handling of independent <kbd>ESC</kbd> according to keymap with `bleopt decode_isolated_esc=auto` `#D0852` 9b20b45 edd481c
  - complete: `bleopt complete_{auto_complete,menu_filter}=` supports disabling auto-completion and candidate narrowing down `#D0852` 4425d12
  - vi: Reimplementation of text object words (reported by cmplstofB) `#D0855` 9f2a973 ad308ae 3a5c456 6ebcb35
  - vi: Support special rules for operator `d` `#D0855` fa0d3d3

## Bug/problem fixes
  - decode: Fixed the issue of double quotes for `-c` and `-x` arguments in `ble-bind -d` `#D0850`
  - auto-complete: Fixed an issue where command execution was not suppressed with <kbd>RET</kbd> when syntax errors were resolved by auto-completion `#D0827` daf360e
  - highlight: Fixed an issue where `shopt -s failglob` caused error coloring of array directive initializers (reported by cmplstofB) `#D0838` d6fe413
  - complete: Measures when ambiguous completion does not work for program completion `#D0841` 713e95d
  - isearch: Fixed a bug where recording of search position failed due to interruption by user input `#D0843`
  - isearch: Fixed an issue where positions and marks were not restored accurately when canceling `#D0847`
  - isearch, dabbrev: Fixed an issue where the current row was not updated until the user entered something during the search process `#D0847`
  - decode: Fixed issue where `ble-bind -m -P` `ble-bind -m kmap -f kspecs -` could not be used for unloaded keymaps 66e202a
  - auto-complete: <kbd>C-j</kbd> changed from just "confirm" to "confirm and run" `#D0852` 01476a7
  - edit: Where <kbd>M-S-f</kbd>, <kbd>M-S-b</kbd> should be bound Fixed the place where <kbd>M-C-f</kbd>, <kbd>M-C-b</kbd> is bound `#D0852` c68e7d7
  - color: Countermeasure for the problem that `<()` in an arithmetic expression is interpreted as process substitution in Bash 3.0 `#D0853` 520184d
  - syntax: Fixed a bug where words in comments were not removed for some reason (reported by cmplstofB) `#D0854` 641583f
  - vi: Fixed an issue where redirection for receiving <kbd>C-d</kbd> fails in Bash 3.1 and 3.2 `#D0857` d4b39b3

## Behavior change
  - sabbrev, vi_imap: Bind `sabbrev-expand` from <kbd>C-]</kbd> instead of <kbd>C-x '</kbd> `#D0825` e5969b7
  - core: When displaying the setting contents by specifying the setting name in `bleopt`, check the existence of the setting name `#D0850` 725d09c
  - isearch: Changed <kbd>C-d</kbd> to delete current selection `#D0826` c3bb69e `#D0852` db28f74
  - isearch: Changed to cancel the selection range when confirmed with <kbd>C-m</kbd> (<kbd>RET</kbd>) `#D0826` c3bb69e
  - decode: Reconfigure `ble-bind` options `#D0850` f7f1ec8 64ad962
  - decode: Overwrite the built-in command `bind` to check the arguments and run it so that the operation of `ble.sh` is not hindered `#D0850`
  - complete: autoload `ble-sabbrev` (`core-complete.sh`), `ble-syntax:bash/is-complete` (`core-syntax.sh`) `#D0842` df0b769
  - isearch: Changed the editing function `isearch/accept-line` to execute <kbd>RET</kbd> even if it is bound from something other than <kbd>RET</kbd> `#D0843`
  - vi, [in]search: Organize mark names (add `vi_` prefix to `char`/`line`/`block`/`search` and make new mark name `search`) `#D0843`
  - edit: Change function name `ble/widget/accept-single-line-or/accepts` → `ble-edit/is-single-complete-line` `#D0844`
  - isearch: Reconsider behavior when searching with empty string `#D0847` d05705e
  - decode: Various adjustments for input key decoding `#D0850` dc013ad
  - dabbrev: <kbd>C-m</kbd>, <kbd>RET</kbd> to finish expansion, <kbd>C-j</kbd>, <kbd>C-RET</kbd> to execute command `#D0852` 01476a7

## internal changes
  - isearch, dabbrev: Reimplemented by `ble/util/fiberchain` `#D0843`, `#D0846` 2c695cf bdf8072 95268c1
  - edit, vi: Organize mark names that represent selection range types a1a6272
  - edit: Change function name `ble/widget/accept-single-line-or/accepts` → `ble-edit/is-single-complete-line` `#D0844` 63ec9fe
  - refactor: Organize files 5e07e7f 1a03da2 673bd1d 55c4224 9ce944c 9a47c57 25487a7 5679ffc b7291a7
  - refactor: Organize function and variable names `#D0851` d1b780c 9129c47 4d1181a

<!---------------------------------------------------------------------------->
# 2018-09-23

2018-09-03 -- 2018-09-23 (#D0766..#D0824 8584e82)

### Complement: New features
  - complete: Support search from history in auto-completion `#D0766`, `#D0769` `#D0784` (fix)
  - complete: Supports <kbd>M-f</kbd> <kbd>C-f</kbd> etc. during auto-completion `#D0767`
  - complete: Support completion even if there is parameter expansion inside quotes such as `"$hello"` `#D0768`
  - complete: Supports completion on the right side of array element assignment `#D0773`
  - complete: Support completion during brace expansion `#D0774`
  - auto-complete: `ble/widget/auto_complete/accept-and-execute` Supported `#D0811`
  - complete: Added load hook to set complementarity `#D0812`
  - complete: Supports completion with specified type `#D0820` `#D0819` (fix)
  - complete: Support static abbrev expansion (set with `ble-sabbrev key=value`) `#D0820`
  - complete: Supports dynamic abbreviation expansion `#D0820`

## Complement: Bug/problem fixes
  - complete: Fixed a bug that immediately enters menu completion after completion is unique `#D0771`
  - complete: Fixed a problem where `[\[` was inserted in the completion immediately after `function fun [` `#D0772`
  - complete: Fixed a bug where the entered part would be deleted when trying to complete with ambiguous completion `#D0775`
  - complete: Fixed a bug where auto-completion was not activated `#D0776`
  - complete: Countermeasure for the issue where the shell exits when the program completion function fails with `failglob` (reported by cmplstofB) `#D0781`
  - complete: Fixed issue where `*` is included in command completion candidates when `failglob` is used (reported by cmplstofB) `#D0783`
  - complete: Fixed a bug where the emphasis of the entered range in the candidate list was disabled by filtering `#D0790`
  - complete: Fixed a bug where the mark position was incorrect after exiting auto-completion `#D0798`
  - complete: Fixed a bug where an error message was displayed when completing `for a in @` or `do @` position `#D0810`

## Completion: Behavior change
  - complete: Internal change in evaluation method of input part `#D0777`
  - complete: Change coloring of auto-completion `#D0780` `#D0792`
  - complete: Changed the command line (`COMP_*`) provided by program completion to include a word break at the start point of completion `#D0793`
  - auto-complete: Confirm completion with <kbd>C-RET</kbd> and execute command `#D0822`

## Others: New features
  - edit: Support `IGNOREEOF` `#D0787`
  - edit: Command `exit` asks the user if there are any remaining jobs and exits `#D0789`, `#D0805` (bugfix)
  - term: Implementation of color reduction on terminals that do not support 256 colors `#D0824`

## Others: Bug/problem fixes
  - isearch: Fixed a bug that prevented asynchronous search
  - color: Fixed lazy initialization order bug in `ble-color-setface` (reported by cmplstofB) `#D0779`
  - decode: Countermeasure for error message for `LC_ALL=C.UTF-8` on CentOS 7 `#D0785`
  - edit: Compatible with `bleopt allow_exit_with_jobs` for exiting when there are jobs <kbd>C-d</kbd> (request by cmplstofB) `#D0786`
  - edit: Fixed a bug that delayed program execution (`ble-edit/exec:gexec`) with <kbd>C-d</kbd> in Bash 3.*
  - syntax: Countermeasure for the problem where function definition parsing fails due to an arithmetic expression bug in Bash 3.2--4.1 `#D0788`
  - highlight: Fixed a bug where the coloring range of the `region` layer would be the default coloring if it crossed line breaks `#D0791`
  - isearch: Fixed bug where <kbd>C-h</kbd> returned to match with empty search string would select everything `#D0794`
  - decode: Fixed issue where `ble-bind -d` fails when `failglob` `#D0795`
  - edit: Fixed a bug that failed to extract the command name of `command-help` (reported by cmplstofB) `#D0799`
  - syntax: Fixed an issue where the parsing of replacement directives in history expansion was incorrect (report by cmplstofB) `#D0800`
  - edit: Fixed issue where history expansion `:&` cannot be used in Bash 3.0 `#D0801`
  - idle: Fixed an issue where an error message appeared when attempting a negative `sleep` `#D0802`
  - bind: Fixed a bug that broke Bash 3.0's <kbd>"</kbd> binding when `ble-detach` `#D0803`
  - edit: Solution to the problem that `stty sane` that is set on the command line immediately after `ble-detach` is not displayed `#D0804`
  - core: Fixed a bug where an error message is displayed when there are no completion candidates in Bash-3.0 `#D0807`
  - edit: Fixed the issue where the prompt was displayed when the window size was changed during command execution `#D0809`
  - edit: Fixed an issue where the display was distorted when using `read -e` in a widget or when `read -e` timed out `#D0809`
  - edit: Fixed bug where timeout did not work with `read -e` `#D0809`
  - term: Fixed a bug that caused colors to change on 16-color terminals `#D0823`

## Others: Changed behavior
  - edit: Redisplay input string in gray when `read -e` terminates due to cancellation/timeout `#D0809`
  - decode: Change default initialization of keymap to be checked at first `ble-bind` `#D0813`
  - core: `ble/util/clock` introduction `#D0814`
  - edit: Handle timeouts with more precision in `ble-edit/read -e -t timeout` (`ble/util/clock`) `#D0814`
  - color: Change the way the error message is displayed when `face` is not defined `#D0815`
  - edit: Changed to overwrite the contents of the terminal displayed below the current cursor position when executing a command `#D0816`
  - edit: In `accept-line`, to prevent flickering, info is not redrawn when no actual command execution is involved `#D0816`
  - edit: `ble/widget/history-expand-line` is now bound from <kbd>M-^</kbd> instead of <kbd>C-RET</kbd> `#D0820`
  - edit: Changed to try static abbreviation expansion at the current position when history expansion is not performed in `ble/widget/magic-space` `#D0820`
  - isearch: Changed <kbd>RET</kbd> to only end the search instead of executing the command. Execute command with <kbd>C-RET</kbd> `#D0822`

## others
  - Makefile: Output dependent files as `.PHONY` target `#D0778`
  - core: Fix `ble/util/assign` to be reentrant `#D0782`
  - Discussion complete: `#D0770` edit: `#D0796` vi: `#D0796`
  - `blerc` update

## Below is a list of widget name changes
  - `menu_complete/accept`              → `menu_complete/exit`
  - `auto_complete/accept`              → `auto_complete/insert`
  - `auto_complete/accept-on-end`       → `auto_complete/insert-on-end`
  - `auto_complete/accept-word`         → `auto_complete/insert-word`
  - `auto_complete/accept-and-execute`  → `auto_complete/accept-line`
  - `isearch/accept`                    → `isearch/accept-line`

<!---------------------------------------------------------------------------->
# 2018-09-02

2018-07-29 - 2018-09-02 (#D0684..#D0765 0c28ed9)

## Complement: New features
  - complete: Ambiguous completion `#D0707` `#D0708` `#D0710` `#D0713` `#D0743` (fix)
  - complete: Readline setting `completion-ignore-case` supported `#D0709` `#D0710`
  - complete: `ble/cmdinfo/complete:$command_name` Supported `#D0711`
  - complete: Supports continuation completion when entering `path:...` etc. `#D0715`
  - complete: Properly handle escaping, etc. inside quotes `#D0717`
  - complete: Supports auto-completion `#D0724`, `#D0728`, `#D0734` & `#D0735` (vim-mode), `#D0766` (history)
  - complete: Ability to skip when part of the completion result is included to the right of the cursor (`bind set skip-completed-text`) `#D0736`
  - complete: Ability to close quotes when completing inside quotes `#D0738`
  - complete: Supports completion of variable names inside arithmetic expressions `#D0742`
  - complete: Arrange and color candidate list display `#D0746` `#D0747` `#D0762` `#D0765`
  - complete: menu-completion (menu completion) supported `#D0749` `#D0757` `#D0764`
  - complete: menu-filter (candidate narrowing down) supported `#D0751`
  - complete: completion in vi_cmap `#D0761`

## Complement: Bug fixes/countermeasures
  - complete: Fixed an issue where command name completion on Cygwin could not be completed correctly when entering part of `.exe` `#D0703`
  - complete: Fixed an issue where variables `COMP_*` were not set correctly for program completion registered by `complete` `#D0711`
  - complete: Fixed an issue where file name completion including `"` and `''` could not be completed correctly `#D0712` `#D0714`
  - complete: Resolved the problem of not interrupting even if you enter a special key during completion `#D0729`
  - complete: Measures against program completion functions that do not recognize quotes `#D0739`
  - complete: Fixed inconsistency in program completion from the middle of the argument `#D0742` `#D0744`
  - complete: Corrected so that completion immediately after parameter expansion `${var}` can be executed correctly `#D0742`

## Completion: Behavior change
  - complete: Changed to limit candidates by referring to `shopt -s force_fignore` immediately before generating completion candidates `#D0704`
  - complete: `FIGNORE` now evaluates against candidate strings instead of escaped inserted strings `#D0704`
  - complete: Perform function name completion in units delimited by `/` `#D0706` `#D0724` (Suppressed when ambiguous match)
  - complete: Changed to use other completion context when exact match and uniqueness is confirmed in parameter expansion `#D0740`
  - complete: Change the character inserted after parameter expansion completion depending on the context `#D0741`
  - complete: change the escape when inserting completion immediately after parameter expansion depending on the context
  - complete: Omit directory name in candidates generated by program completion `#D0755`

## Others: New features
  - edit (`RET`): Insert line break when grammar is incomplete `#D0684`
  - core (`ble/util/idle`): Simple task scheduler implementation `#D0721`
  - core: add a function `ble/function#try` `#D0725`
  - idle: Implement background job waiting function in `ble/util/idle` `#D0731` `#D0745` (history bugfix)
  - base: `--attach=prompt` Supports `#D0737`
  - base: Changing the order during initialization and displaying the process with info
  - Improved support for decode: modifyOtherKeys `#D0752` `#D0756` `#D0758` `#D0759`
  - core (`ble/util/assing`): Changed so that arguments for the command can be specified after the 3rd argument `#D763`

## Others: Bug fixes/countermeasures
  - highlight: Fixed a bug that caused word coloring to be distorted `#D0686`
  - syntax: Fixed a bug that caused the error `_ble_syntax_attr: bad array subscript` under bash-3.2 `#D0687`
  - prompt: Fixed a bug where \v becomes an empty string on PS1 `#D0688`
  - highlight: Fixed a bug where coloring of `disabled` layers was ignored even if the command was canceled in overwrite mode `#D0689`
  - core (ble/term/visible-bell): Fixed a bug where the width was calculated incorrectly `#D0690`
  - decode: Fixed an issue where "stty" becomes strange immediately after switching the editing mode with "set -o vi/emacs" `D0691`
  - core: Dealing with the problem that it stops working when LANG=C `#D0698` `#D0699` `#D0700`
  - history: Countermeasure for the problem that history initialization takes a long time in Cygwin `#D0701`
  - history: Countermeasure for the issue where a mysterious waiting time occurs immediately after loading bashrc `#D0702`
  - emacs: Fixed a bug where strings were inserted twice during bracketed paste `#D0720`
  - main: Countermeasures when POSIXLY_CORRECT is set `#D0722` `#D0726` `#D0727`
  - edit: Measures against overwriting built-in commands using POSIXLY_CORRECT `#D0722`
  - decode: Fixed a bug in the implementation that relies on associative arrays. Associative arrays are also used in bash-4.0 and 4.1 '#D0730'
  - decode: Fixed a bug where commands containing shell special characters could not be executed correctly with `ble-bind -c`
  - edit: Fixed a bug that doubled the number of history items `#D0732`
  - vi: Fixed a bug where special keys were not played in keyboard macro `#D0733`
  - isearch: Fixed division by 0 bug when displaying current position
  - vi: Fixed a bug where the coloring indicating the operation range does not disappear even if you cancel `!!` `#D0760`

## others
  - refactor: `#D0725` `#D0750` `#D0753` `#D0754`
  - bash-bug: Bug report for Bash `#D0692` `D0695` `D0697`

<!---------------------------------------------------------------------------->
# 2018-03-15

2018-03-15 (#D0644..#D0683 7d365d5)

## New features
  - undo: vi-mode `u` `<C-r>` `U` (`#D0644` `#D0648`); emacs `#D0649`; `#D0662`
  - vi-mode (nmap/xmap): `f1` calls `command-help`
  - vi-mode (nmap): `C-a` `C-x` supported (nmap `#D0650`, xmap `#D0661`)
  - vi-mode (operator): Supports various operators `#D0655` (`gq`, `gw` `#D0652`; `!` `#D0653`; `g@` `#D0654`)
  - vi-mode (operator): Color operands with operators with additional inputs `#D0656`
  - vi-mode (registers): registers `"[0-9%:-]` `#D0666` `#D0668`, `:reg` `#D0665`
  - vi-mode (smap): selection mode `#D0672`
  - emacs: Support arguments in main commands `#D0646`
  - emacs: Display mode name when in multiline mode. Also display arguments. `#D0683`
  - edit: `safe` keymap
  - edit: Emoji character width `bleopt emoji_width=2` `#D0645`
  - core: Measures against incorrect `PATH` `#D0651`

## Behavior modification
  - vi-mode (nmap/xmap/omap `<paste>`): Changed to ignore arguments
  - vi-mode (map `/` `?` `n` `N`): Change the search matching method to be similar to vim `#D0658`
  - vi-mode (omap): Changed to search with `g~?` and switch case between matching range `#D0659`
  - vi-mode (map): Change the behavior when calling `+` `_` `g_` etc. near the last line to be similar to vim `#D0663`
  - vi-mode (xmap): Correct behavior of text object `[ia]['"]` in xmap `#D0670`
  - vi-mode (nmap): Changed so that `Y` does not move to the beginning of the line `#D0673`
  - vi-mode (xmap): Improve efficiency of rectangular range extraction `#D0677`
  - core: `ble.sh` Improved loading time `#D0675`, `#D0682`, (lazy loading `#D0678` `#D0679` `#D0680`, history reading behind the scenes `#D0681`)

## Bug fixes
  - vi-mode (omap): Fixed a bug where `cw` and `y?` did not work.
  - vi-mode: Fixed a bug where spaces were inserted in the content recorded by macro `#D0667` (Test added `#D0669`)
  - vi-mode: Fixed a bug that prevented line-oriented pasting from working `#D0674`
  - complete: Fixed a bug where completion of the first argument was not executed correctly depending on the command name `#D0664`
  - syntax: Fixed a bug where an error message appeared when $ret was specified in a here string `#D0660`
  - syntax: Fixed a bug where command coloring always resulted in an error in bash-3.0 `#D0676`
  - decode: Fixed a bug where ble-decode-unkbd returned ESC for every character `#D0657`
  - Makefile: Fixed bug where deleted file isearch.sh was required
  - Makefile: Fixed a bug that does not work with the latest gawk.

<!---------------------------------------------------------------------------->
# 2017-12-03

## New features
  - edit, vi-mode: Supports bracketed paste mode `#D0639`

## Behavior modification
  - core: Internal management of terminal state settings/restoration and cursor shape `#D0638`
    - Make the cursor shape the default when calling an external command
    - Restore cursor shape when returning from external command
  - syntax (extract-command): Fixed so that commands can be found even if they are lower in the syntax hierarchy `#D0635`
    This allows `command-help` (nmap `K`, emacs `f1`) to work even on redirect words.
  - syntax (tilde expansion): Supports tilde expansion inside normal words that have the form of variable assignment `#D0636`
  - syntax: [...] [...] loses meaning when tilde expansion occurs inside `#D0637`
  - vi-mode (cmap `<C-w>`): Change to vim behavior similar to imap `<C-w>`

## Bug fixes
  - complete: Fixed a bug where an empty string is confirmed when there are no completion candidates `#D0631`
  - complete, highlight: Fixed bugs around `failglob` (3) `#D0633` `#D0634`
  - vi-mode: Fixed bug where `ret` global variable was contaminated `#D0632`
  - highlight: Fixed a bug where an error message would appear when entering a read-only variable name
  - decode: when widget called from `__defchar__` returns 125
    Fixed a bug where key columns were not passed to widgets called from `__default__`
  - core: Fixed a bug that did not work at all when set -u `#D0642`
  - edit: Fixed bug where `read -e` does not work while loading ble.sh `#D0643`

<!---------------------------------------------------------------------------->
# 2017-11-26

## Bug fixes
  - general: Fixed a bug that caused problems with failglob `#D0630`
  - keymap/vi (nmap q): Fixed a bug that did not work on bash-3.0.
  - keymap/vi (cmap): Fixed a bug that caused exit with C-d `#D0629`
  - edit (ble/widget/command-help): Fixed a bug that caused an infinite loop when trying to run help on an alias.
  - edit (ble/util/type): Fixed a bug where the type of commands with names starting with "-" could not be determined and were not colored.
  - complete: Fixed a bug where completion may not be possible on the right side of variable assignment or redirect destination `#D0627`
  - complete: Fixed an issue where the value of a local variable in ble.sh was being referenced when the word to be completed contains parameter expansion `#D0628`

## Behavior change
  - bind/decode: Change how orphan ESCs are read. Modified <C-q><C-[> to input a single <C-[>
  - bind/decode: Support reading orphan ESC and C-@ when input_encoding=C
  - complete: Combine duplicate enumerated candidates `#D0606`
  - complete: Fixed an issue where exact matching directory names appeared in command candidates for some reason `#D0608`
  - edit (command-help): Fixed some built-in commands and reserved words to be moved to the correct location in man bash `#D0609`
  - edit (command-help): Changed to search command help after removing quotes etc. `#D0610`
  - core: Fixed the part where the right side was forgotten to be quoted when comparing conditional commands `#D0618`
  - highlight: When using `shopt -s failglob`, color failing words as errors `#D0630`

## parsing changes
  - syntax: `> a.txt; echo` is not a syntax error `#D0591`
  - syntax: After variable assignment/redirection, reserved words lose their meaning and are treated as commands `#D0592`
  - syntax: `time` and `time -p` are syntactically correct `#D0593`
  - syntax: Suppress `$()` not closing and causing another syntax error due to a syntax error with no argument for `>` such as `echo $(echo > )` `#D0601`
  - syntax: `function hello (())` is now treated as a syntax error in versions below bash-4.2 `#D0603`
  - syntax: Changed to parse `time -p -- command` in an independent context `#D0604`
    - complete: This solves the problem of not being able to complete the command for the `time` argument `#D0605`
  - syntax: Supports extglob internal process substitution `@(<(echo))` `#D0611`
  - syntax: Supports pattern analysis using `[...]` `#D0612`
  - syntax: Also deactivate nested extglob `@(@())` on the right side of variable assignment `#D0613`
  - syntax: Color `*` and `?` even when using `shopt -u extglob` `#D0616`
  - syntax: Supports coloring of brace expansion `#D0622`
  - syntax: Supports coloring of tilde expansion `#D0626`
  - syntax: Prohibition of redirection in `args` of `for var in args...` `#D0623`
  - highlight: Do not perform path name expansion or brace expansion for here strings `#D0624`
  - highlight: Error coloring `#D0625` when redirect destination file name is expanded to multiple words

## parsing fix
  - syntax: Fixed a bug where a syntax error would occur if there was no command after `}`, `done`, etc. in `$({ echo; })` or `$(while false; do :; done)` `#D0593`
  - syntax: Fixed a bug where command/function names starting with `-` were not colored correctly `#D0595`
  - Fixed a bug where syntax error coloring such as syntax: `if :; then :; fi $(echo)` was not executed `#D0597`
  - syntax: Fixed a bug that caused inconsistency due to read-ahead and improved the read-ahead framework `#D0601`
    - Fixed a bug that caused inconsistencies due to partial updates around process replacement.
    - Fixed a bug that caused inconsistency when inserting `) (` to `function hello (())` and changing it to `function hello () (())` `#D0602`
  - syntax: Fixed a bug where `_ble_syntax_bashc` is not updated even if you run `shopt -u extglob` `#D0615`

<!---------------------------------------------------------------------------->
# 2017-11-09

## New features
  - vi-mode (nmap): `*` `#` `qx...q` `@x`
  - vi-mode (cmap): history
  - core: Supports bleopt variable `pager` (default value `''`). Use `${bleopt_pager:-${PAGER:-Search as you like}}` as the pager used by `ble.sh`.
  - vi-mode (nmap `K`): Supports `ble/cmdinfo/help:$cmd`, `ble/cmdinfo/help`.

## Bug fixes
  - vi-mode (cmap `<C-[>`): Fixed a bug where the keymap to cancel command line mode was overwritten with `bell`.
  - decode: Fixed a bug where `unset` did not work correctly with `shopt -s failglob` and `shopt -s nullglob`.
  - vi-mode (nmap `K`): Fixed a bug that made operation impossible with `MANOPT=-a`

## Behavior change
  - edit (`ble/widget/command-help`), vi-mode (nmap `K`): Changed to display `man` of the command at the cursor position
  - base: Changed to refer to `XDG_CACHE_HOME` and `XDG_RUNTIME_DIR` respectively when determining cache directory and temporary directory.
  - Makefile: Changed the installation directory to refer to `XDG_DATA_DIR`
  - isearch: Changed to delay loading command history until actually needed
  - vi-mode (nmap `K`): Built-in command keyword displays `man bash`.
  - vi-mode (nmap `K`): Shell functions print function definitions.

<!---------------------------------------------------------------------------->
# 2017-11-05

## New features
  - vi-mode (exclusive motion): `:help exclusive-linewise` Supports special rules (exclusive -> inclusive, exclusive -> linewise)
  - vi-mode (omap): Cancel explicitly with `C-c` `C-[`
  - vi-mode: Added keymap/vi_test.sh. Automated vi-mode operation test because regression was severe
  - complete: Added bleopt variable `complete_stdin_frequency` (default value `50`)

## Behavior change
  - vi-mode (nmap `e`, `E`): Changed so that omap does not sound a bell when the destination is the blank space of the last character of the last line.
  - vi-mode (omap/xmap `<space>`, `<back>`, `<C-h>`): Change how newlines are counted
  - vi-mode (nmap `cw`, `cW`): Change behavior when on the last character of a word and on a whitespace
  - decode (ble-bind): Changed `ble-bind -D` to also output the internal state of the keymap.
  - term: Change default value of `_ble_term_SS` to empty string
  - complete: `shopt -s no_empty_cmd_completion` no longer performs completion (other than command completion)
  - edit (ble/widget/exit): When the string being edited remains, it will be redrawn in gray and then exit.

<!---------------------------------------------------------------------------->
# 2017-11-03

## breaking changes
  - vi-mode (widget): Rename blw/widget/vi-insert/* → ble/widget/vi_imap/*
  - vi-mode (bleopt variable): rename bleopt keymap_vi_normal_mode_name → keymap_vi_nmap_name
  - vi-mode (imap): vi-insert/magic-space deprecated. Use magic-space directly instead.

## New features
  - vi-mode (xmap): `o` `O`
  - vi-mode (nmap): `.` Completed for now?
  - vi-mode (xmap/nmap): `gv`

## Bug fixes
  - vi-mode (mark `` `x `` `'x`): Fixed bug where operator was not called
  - vi-mode (txtobj `[ia]w`): Fixed a bug where a sequence of only alphabetic characters and _ was considered a word instead of a sequence of alphanumeric characters and _.
  - vi-mode (imap): Fixed a bug where `<C-q>x` `<C-v>x` was not repeated correctly in `{count}i...<C-[>`
  - vi-mode (imap): Fixed bug where repetition was enabled in `{count}i...<C-c>`
  - vi-mode (nmap `{N}%`): Fixed a bug that prevented moving to the desired line.
  - vi-mode (nmap `_`): Fixed a bug where `d_` and `d1_` were not set to linewise.
  - vi-mode (xmap `I` `A`): Fixed a bug that prevented it from working.
  - vi-mode (xmap `I` `A`): Fixed a bug where the cursor position was shifted after execution
  - vi-mode (xmap `I` `A` `c` `s` `C`): Fixed a bug where the first line was missing from the edit range `` `[`] `` after inserting a rectangle.
  - vi-mode (xmap `?`): Fixed bug where search `?` became operator `g?`
  - vi-mode (xmap `/` `?` `n` `N`): Fixed a bug where the visual mode selection range was overwritten by the search match range.
  - vi-mode (xmap `/` `?` `n` `N`): Fixed a bug that moved to another history item in visual mode when there was no match in the current history item.
  - lib/vim-surround (nmap `cs` `cS`): Fixed a bug where arguments and registers were not valid when supporting nmap `.`
  - lib/vim-surround (xmap `S`): Fixed a bug where newlines were inserted before and after in visual mode with `v`

## Behavior change
  - vi-mode (imap `<C-w>`): Changed to deletion using vim word separator (`w`)
  - vi-mode (nmap `[rRfFtT]x`): Changed to cancel with `<C-[>`
  - vi-mode (nmap `w` `b` `e` `ge`): Changed to treat consecutive non-alphanumeric ASCII characters and consecutive Unicode characters as separate words.
  - vi-mode (xmap `c` `s` `C`): Supports rectangle insertion similar to `I`, `A`

<!---------------------------------------------------------------------------->
# 2017-10-30

## breaking changes
  - vi-mode: Rename keymap vi_command -> vi_nmap, vi_insert -> vi_imap
  - vi-mode: Rename some widgets
    - ble/widget/{no,}marked -> ble/widget/@{no,}marked
    - ble/widget/vi-command/* (part) -> ble/widget/vi_nmap/*
  - vi-mode: ble/widget/vi-insert/@norepeat Deprecated. Use another method (_ble_keymap_vi_imap_white_list).

## New features
  - vi-mode (nmap): . is under implementation (currently only changes made via the operator in nmap/omap are recorded)
  - vi-mode (mode): bleopt variable `term_vi_[inoxc]map`
  - decode: support orphan ESC timeout
  - edit: Supports shopt -s histverify, shopt -s histreedit #D0548

## Bug fixes
  - vi-mode (xmap): Fixed a bug where `p`, `P` did not work correctly.
  - vi-mode (imap): Fixed a bug where the specified argument (repeat count) was always canceled when entering insert mode
  - vi-mode (txtobj; nmap `gg`, `G`): Fixed a bug where register specifications were lost.
  - lib/vim-surround (nmap ds): Fixed a bug where arguments were not passed correctly to internally used operators `y`, `d`.
  - prompt: Fixed a bug where `PS1` set by `PROMPT_COMMAND` was not persisted.
  - decode: Fixed an issue where bash_execute_unix_command error occurred due to ambiguous registration in bind -x #D0545
  - decode: Fixed unnecessary calls to `default.sh` in `vi.sh` and `emacs.sh` #D0546
  - core: Fixed a bug where ble/util/assign was broken in bash-3.0.

## Behavior change
  - vi-mode (nmap `x`, `<delete>`, `s`, `X`, `C`, `D`): support registers
  - Guaranteed to return exit status 0 when successfully loaded in source ble.sh
  - Rename widget marked, nomarked to @marked, @nomarked. Original widget is deprecated (scheduled for removal)
  - ble.sh: Support loading through symbolic links even on non-Linux (even when `readlink -f` does not work) #D0544

<!---------------------------------------------------------------------------->
# 2017-10-22

## New features
  - vi-mode (mark): `mx` <code>`x</code> <code>'x</code> (`x` = <code>[][<>`'a-zA-Z"^.]</code>)
  - vi-mode (nmap): `gi` `<C-d>` (exit when empty string) `"x` (registers)
  - vi-mode (xmap): `I` `A` `p` `P` `J` `gJ` `aw` `iw`
  - lib/vim-surround.sh: nmap `yS` `ySS` `ySs` `cS`, xmap `S` `gS`
  - Control tab indentation
    - bleopt tab_width= (tab display width)
    - bleopt indent_offset=4 (indent width for `>` and `<`)
    - bleopt indent_tabs=1 (Whether to use tabs to indent `>` and `<`)
    - Default indent width changed from 8 to 4

## Bug fixes
  - vi-mode: Fixed a bug where `ESC ?` was also repeated when a repeat count was specified in insert mode.
  - vi-mode: Fixed operator `g?` not working.
  - vi-mode (nmap `/` `?`): Fixed a bug where `C-c` was not canceled while inputting the search target.
  - vi-mode (xmap `r` (visual char/line)): Fixed a bug where the whole replacement was inserted into the selection range.
  - vi-mode (xmap `$`): Fixed a bug where the display was not updated when `$` was used at the end of a line.
  - vi-mode (motion `0`): Fixed a bug where the operator was not recognized.
  - isearch: Fixed a bug that once matched, it continues to match the same thing, which was embedded in the previous `/` `?` `n` `N` support.
  - complete: Fixed completion function registered with `complete -F something -D` not being executed correctly.
  - prompt: Fixed a bug where it was not picking up PS1 set by PROMPT_COMMAND
  - textarea: Fixed a bug where drawing height could not be secured correctly when using `C-z` (`fz`) when editing multiple lines at the bottom of the terminal.

## Behavior change
  - vi-mode (operator `<` `>`): Correct behavior in Visual block
  - vi-mode (nmap `:` `/` `?`): Corrected so that it can be canceled by DEL or C-h with an empty string while inputting a string.
  - vi-mode (nmap `J`, `gJ`): supports arguments
  - vi-mode (nmap `p`): Fixed not to insert extra line when inserting at the last line.
  - vi-mode (xmap `Y` `D` `R`): Fixed the type of visual mode to record.
  - lib/vim-surround.sh: Fixed to confirm with '>' while entering tag name
  - widget (.SHELL_COMMAND): It is confusing that the commands that are not executed are colored, so I changed it so that it is grayed out.

## other changes
  - magic-space: insert a space and then reverse the history expansion order

----

# 2015-03-06..2017-10-09 (Git Commit Log)

## 2017-10-09
* keymap/vi: support specialized handling of keys for cmap
  - vi (nmap / ?): treatment of C-h and DEL on input of search targets
  - vim-surround.sh (nmap ys cs): treatment of > on input of tag names

## 2017-10-07
* keymap/vi_xmap: add tentative text object implementation
* lib/vim-surround: accept user input of tag names with the replacement being t, T, <
* keymap/vi_command: support search / ? n N

## 2017-10-05
* keymap/vi_command: fix behavior of yy, dd, D, etc. on the last line with count arg
* keymap/vi_xmap: support x <delete> C D X R Y
* keymap/vi_xmap: support r s
* keymap/vi-command: support : and few commands
* ble-core: fix a bug that conditions for assotiative arrays are inverted

## 2017-10-04
* [refactor] ble-edit (ble-edit/render -> ble/textarea): support "ble/textarea#{save,restore,clear}-state"
* [refactor] ble-edit (text/update/positions -> ble/textmap): support any time updates of text positions
* keymap/vi_command: support _ g0 g<home> g^ g$ g<end> gm go g_ ge gE
* check: fix "local lines=()" in vi_digraph.sh and update "check"
* (ble-highlight-layer:region): fix a bug that the "region" face is sometimes applied to intervals between selections

## 2017-10-03
* keymap/vi (visual mode): support previous selections
* keymap/vi (nmap p, P for block): convert HTs under inserting points to spaces
* (ble-decode-key/dump): fix a bug that pathname expansions internally occurred
* ble-core: add ble/string#split-lines
* keymap/vi (visual block): improve performance of block extraction
* keymap/vi_command (linewise operator d): go to the previous line on deleting the last line
* keymap/vi (operator d c g~ gu gU g?): support block
* keymap/vi (nmap p, operator y): support block

## 2017-10-02
* keymap/vi_xmap: support count arg for operators
* keymap/vi_command: fix a bug that linewise < > operators produce an error
* keymap/vi_command: perform EOL fix on history traveling with normal mode
* keymap/vi_xmap: support block selection

## 2017-10-01
* keymap/vi_xmap: support visual mode swithing
* keymap/vi: support visual mode

## 2017-09-28
* ble-edit: add a condition to accept-single-line-or
* keymap/vi_command: support gj gk

## 2017-09-27
* ble-edit: restore BASH_REMATCH
* ble-edit: do not execute pasted multiline texts
* ble-edit: support scrolling
* bleopt: implement value checking on assignment

## 2017-09-24
* ilb/vim-surround.sh: do not refer bleopt "vim_surruond_{char}" for digit replacement char
* keymap/vi: show configurable string (defaulted to be ~) on the normal mode
* keymap/vi_command: support % N%
* keymap/vi_command: support indentation for o O
* keymap/vi_command: reimplement text object is as
* keymap/vi (linewise-range.impl): fix a bug that the line ranges are reverted, fix behavior to go to nol

## 2017-09-23
* keymap/vi_command: support text object ip ap
* keymap/vi_command: support text object is as
* keymap/vi_insert: support indentation for C-m, C-h, DEL
* ble-edit: erase garbage input echo during initialization of ble.sh
* ble-edit (bleopt char_width=emacs): fix a bug that U+2000 - U+2600 are always treated as width 1
* keymap/vi: fix a bug that selection is not cleared on entering the normal mode during isearch

## 2017-09-22
* keymap/vi_command (r, gr): highlight on waiting replacement
* keymap/vi_command: support text object it at

## 2017-09-20
* ble-edit/exec: fix handling of $? and $_ and add a workaround for "set -o verbose"

## 2017-09-18
* lib/vim-surround: support configurable replacements with bleopt vi_surround_45:=tmpl vi_surround_q:=tmpl
* (bleopt): support the form "var:=value" which skips existence checks of variables
* lib/vim-surround: support ds cs
* ble-decode: fix stty settings for command execution
* keymap/vi_omap: fix mode transition from vi_omap to vi_insert
* [m] lib/vim-surround: remove redundant codes

## 2017-09-17
* keymap/vi (text object i[bB]): exclude newlines around the range and transform to linewise
* [m] keymap/vi (text object i"): behave the same as a" with arg >= 2 specified
* [m] keymap/vi: rename functions
* keymap/vi_insert: change the default of C-k to kill-forward-line
* keymap/vi_command: support digraphs for arg of f, F, t, T, r, gr
* keymap/vi: support digraph
* (ble-bind): support "ble-bind -@f kspec command"
* (ble-decode-kbd): fix a bug that keys "*" and "?" cannot be properly encoded

## 2017-09-16
* keymap/vi_command (operators): fix a bug that arg is cleared before the use
* lib/vim-surround: support b B r a C-] C-} as replacements
* keymap/vi: rename operator flag for < and >
* (ble/widget/self-insert): explicitly return 0
* ble-decode (ble-decode-key/.invoke-command): propagate exit status of widgets
* keymap/vi_omap: decompose M-*
* add ilb/vim-surround.sh, support operator "ys" and "yss"
* keymap/vi: add new keymap "vi_omap"

## 2017-09-15
* keymap/vi_command: support operators < >
* keymap/vi_command: support g~~ guu gUU g??
* keymap/vi_command: handle meta flags of input keys
* keymap/vi_command: support ~
* keymap/vi_command: fix the text object "aw"
* keymap/vi_command: rename widgets

## 2017-09-13
* ble-edit/info: fix cursor position calculations in rendering
* (ble-form/panel#set-height-and-clear.draw): fix to add lines on an increased height
* keymap/vi_command: support text objects [ia][][{}()<>bBwW'"`]

## 2017-09-12
* add ble-form.sh and introduce ble-form/panel
* ble-edit: rename functions
* keymap/vi_command: support text object iw
* ble-edit/info: show default contents at the end of bind
* ble.pp: fix PATH if standard utilities are not found on load
* keymap/vi_command: add operators g~ gu gU g?
* keymap/vi_command: refactor ydc operators
* ble-decode (ble-bind): fix check of redundant "ble/widget" prefix

## 2017-09-11
* ble-edit (ble/widget/clear-screen): show info after the clear
* keymap/vi_command (C-o): fix cusor positions after first-non-space commands
* keymap/vi: fix the initial position of "-- INSERT --"
* keymap/vi_command: support C-o
* ble-core: add string functions
* keymap/vi_insert: change mode names on "insert"
* keymap/vi: show current modes in the info area
* ble-edit: support ble-edit/info/set-default
* ble-edit: clear info on exit
* memo.txt: add comments from @B-bar
* ble-decode: check existence of keymaps

## 2017-09-10
* keymap/vi_command: fix C D
* keymap/vi_command: support arg for insert modes
* ble-decode: fix ble-decode-key and support __before_command__ and __after_command__
* keymap/vi_command: update bindings and support z{char} clear screens

## 2017-09-09
* keymap/vi_command: fix R and support gR
* keymap/vi_command: support f F t T ; ,
* ble-edit: suppress unnecessary history loads on history-next
* ble.pp: support loading ble.sh from inside of functions
* keymap/vi_command: support J gJ o O
* fix leak variables
* keymap/vi_command: support r gr

## 2017-09-08
* keymap/vi_command: fix mode change widgets and support gI
* keymap/vi_command: support G H L gg
* keymap/vi_command: fix behavior of [dcy][-+jk]
* keymap/vi_command: update memo.txt and support K
* keymap/vi_command (RET, C-m): fix to behave as + if the line contains LF
* keymap/vi_command: support w W b B e E

## 2017-09-07
* keymap/vi_command: support s S
* ble-edit: rename ble-edit/text/getxy -> ble-edit/text/getxy.out
* keymap/vi_command: support C-h DEL SP
* (ble/widget/vi-command/{forward,backward}-line): fix
* keymap/vi_command: return to insert mode on accept-line
* keymap/vi_command: support |
* keymap/vi_command: clear arg on mode changes
* keymap/vi_command: support I
* keymap/vi_command: support Y D C
* keymap/vi_command: support x X
* keymap/vi_command: support p P
* keymap/vi_command: check unknown flags
* keymap/vi_command: support A
* keymap/vi_command: add basic bash operations
* keymap/vi_command (+ -): travel history
* keymap/vi_command: support ^ + - $
* keymap/vi_command: fix behavior of "yh" and "yl"
* keymap/vi_command: support dd yy cc 0
* ble-edit: partial revert 35098f0 where necessary ble-edit/history/load calls were removed
* ble-edit (ble/widget/{for,back}ward-line, etc): fix a bug that the destination cursor pos was based on possible old layout
* keymap/vi.sh: support hjkl
* ble-edit: remove redundant ble-edit/history/load calls
* (ble/widget/.bell): fix exit status

## 2017-09-06
* check: add check codes for bashbug workarounds
* (ble-edit/text/get*): check if the cached text positions are up to date

## 2017-09-05
* keymap/vi: support mode switching
* (ble/widget/.goto-char): simplify
* (ble-edit/load-keymap-definition): workaround for bash-3.0
* (ble-decode-key): accept multiple keys
* ble-edit: support the value bleopt_default_keymap=vi

## 2017-09-04
* add keymap/vi.sh and switch keymap on editing mode change
* ble-decode: split and refactor external settings
* ble-decode: support bleopt_default_keymap=auto

## 2017-09-03
* ble.pp: remove the check enforcing "set -o emacs"
* ble-decode (ble-decode-{attach,detach}): support attached editing modes
* ble-decode: update spacing of an awk script
* ble.pp: fix "set -o emacs" checks
* ble-syntax: fix a bug that here strings are interpreted as here documents
* complete.sh: suppress error messages on internal compgen calls

## 2017-08-30
* ble-edit: check editing mode

## 2017-08-19
* cmap/default.sh: disable modifier keys "CAN @ ?" which is ambiguous with "C-x C-x"
* ble-edit: support "bleopt delete_selection_mode=1"

## 2017-06-09
* ble-syntax: workaround for the bash-4.2 arithmetic bug resulting in segfaults

## 2017-05-20
* ble.pp: guard double ble-attach

## 2017-04-21
* bind.sh: bash-4.4 workaroud: fix a bug C-x ? is not bound

## 2017-03-17
* README: update color settings and translate tips
* README: add a hint on editing multiline commands

## 2017-03-16
* (ble-color-gspec2g): change to recognize 0 padded color indices as decimal numbers
* README: bump release 0.1.7

## 2017-03-15
* README: update heading syntax of GitHub flavored markdown

## 2017-03-13
* suppress error messages caused by incorrect user LC_*/LANG values

## 2017-03-06
* complete: fix a bug that backquotes, newlines and tabs in completed words were not escaped

## 2017-03-05
* ble.pp ($_ble_init_original_IFS): \minor, fix unset
* ble-core.sh ($ble_util_upvar_setup): add "local ret" declartion
* (ble-syntax:bash/ctx-heredoc-word): use ctx-redirect to read keyword of here documents
* ble-color: move deprecated "ble-highlight-layer:adapter" codes to layer/adapter.sh as a sample
* save/restore IFS to protect ble functions from user's IFS
* memo.txt: assign numbers of the form "#D????" to old items
* (ble-syntax:bash): :new: support "select var in ..."
* (ble-syntax:bash): fix a recent bug that semicolons after "for (())" was not allowed
* (ble-syntax:bash): :new: support here documents

## 2017-03-04
* (ble-syntax:bash): fix a bug that semicolons are not allowed after "}", "fi", "done", etc.
* (ble-syntax:bash): support the construct with the form "for name do ...; done"
* (ble-syntax:bash): accept "do" immediately after "for (())" without semicolons
* Makefile: add a prerequisite "install"
* (ble-edit-attach): output CR before showing prompt

## 2017-03-02
* (ble-syntax:bash): allow `then, elif, else, do' after `}, etc.'
* (ble-syntax:bash): improve checks of quotes in parameter expansion and arithmetic expansion
  - change so that quotes are processed always in the syntax level
  - introduce new nest-types, ntype='$((' and ntype='$[', for CTX_EXPR (arithmetic expressions)
  - introduce a new nest-type ntype='NQ(' to support nesting in quote-removal-less contexts
  - fix so that quotes '...' in parameter expansions such as `${var#text}' are always enabled
* \clean: format memo.txt and document comments, etc.
* (ble-syntax:bash): add a work around of a bash-4.2 bug in arithmetic expressions

## 2017-03-01
* (ble-edit/info/draw-text): change to truncate overflow contents
* ble-edit: fix bugs that line representation is broken at the last line of terminals
  - \fix, use IND to ensure size of the edit area
  - \fix, clear _ble_line_{beg,end}{x,y} on newline
  - ble-edit.sh: add a function ble-edit/draw/put.ind
  - ble-edit.sh: add a function ble/widget/.insert-newline
  - (ble/widget/redraw-line): \clean, Remove unnecessary _ble_line_cur initialization. Just calling ble-edit/render/invalidate is sufficient.
  - (ble-edit/exec/.adjust-eol): \clean, Delete useless _ble_line_x=0 _ble_line_y=0. This is an assumption that has been made from the beginning.
  - (ble-edit/exec/.adjust-eol): \fix, Changed from directly outputting to stderr to outputting to ble/util/buffer.
* (ble-syntax:bash): support `} }', etc.
* (ble-syntax:bash): :new: support `for ((;;)) { ... }'
* (ble-syntax:bash): support `((echo)>/dev/null)' and `$((echo)>/dev/null)'
* complete: support completion of "in" keywords for "for var in"/"case arg in"
* (ble-syntax:bash): :new: support `for var in ...' and `case arg in'
* (ble-syntax:bash/ctx-command): [refactor] split into functions, use arrays for ctx settings
* (ble-syntax:bash): fix a bug that redirection accepted comments
* (ble-highlight-layer:syntax): fix a bug that causes error on a word beginning with #
  - Note: words beginning with '#' can be formed when `shopt -u interactive_comments'
* (ble-syntax:bash): fix a bug that beginning of process substitutions splitted words

## 2017-02-28
* ble-edit: [refact] rename ble/edit/prompt/update/update-cache_wd -> ble-edit/prompt/update/update-cache_wd
* ble-edit: [refact] rename ble/widget functions
* ble-edit: [refact] rename ble-edit functions
* ble-edit: use ble/util/buffer to suppress flicker
* ble-core: add variable "ble_util_upvar{,_setup}"

## 2017-02-25
* (ble-syntax/parse/shift): fix a bug that caused duplicated shifts
* (ble-syntax/print-status/.dump-arrays): add consistency checks

## 2017-02-14
* ble-syntax.sh: fix a bug that attempts "continue" out side of loop

## 2017-02-13
* ble-edit (ble/widget/isearch): fix a bug that isearch does not work in bash-4.4

## 2016-12-21
* ble-edit (exec): default value of the parameter "$_" is "$BASH"
* ble-edit (exec): support parameter "$_"

## 2016-12-06
* ble-core (ble/string#split): add a work around for "shopt -s nullglob"

## 2016-11-08
* Makefile: detect correct path of gawk for mwg_pp.awk

## 2016-11-07
* ble-core.sh: add a work around of bashbug to accept inputs of hankaku kana

## 2016-09-20
* (ble/util/sleep in Cygwin): check parent processes of blocking process substitutions

## 2016-09-16
* README: update
* (ble/util/upvar): fixed a bug that array elements cannot be exported

## 2016-09-14
* ble-core: add a function ble/util/upvar
* _ble_edit_str.replace: improve error correction of _ble_edit_ind and _ble_edit_mark

## 2016-09-11
* (ble/widget/isearch/cancel): return to the original position, i.e. restore _ble_edit_{ind,mark}
* (ble-syntax:bash/check-dollar): fixed a bug that isolated dollars generate syntax errors
* (ble/widget/accept-and-next): fixed a bug that the next line is not loaded on accepting the last histentry
* ble.sh (ble-edit/history/add): fixed a bug that erasedups is performed even if a new entry is rejected by ignorespace
* isearch: fixed a bug that words in the current line is not matched incrementally

## 2016-08-24
* complete.sh: recognize dangling symbolic links in completion and syntax-highlighting

## 2016-08-08
* term.sh: fixed a bug that xenl cap was always disabled.

## 2016-08-07
* ble-edit/prompt: improved admin privileges checks on Cygwin

## 2016-08-05
* (ble-edit/history/add): fixed a bug that history entries are not registered after certain operations.
* syntax: fixed a bug that causes an fatal error for param expansions with offset in quotes like "${v:1}"
* (ble/util/sleep): do not use /dev/tcp which generates error messages on Win10 Cygwin.

## 2016-07-16
* (ble/util/array-push): \refactor, rename, support multiple elements to append.
  - rename ble/util/array-push -> ble/array#push
  - rename ble/util/array-reverse -> ble/array#reverse

## 2016-07-15
* complete: enable completion of variable names in "..." and ${...}.
* complete.sh: insert '=' after the completion of variable name of assignment.
  - (ble/widget/complete):
    Expand completion-context so that arguments of source can be specified separated by colons.
  - ble-complete/source/variable:
    Change so that the suffix to be inserted at confirmation is selected according to the argument.
  - ble-syntax.sh (ble-syntax/completion-context):
    Depending on the context, specify the argument '=' in the variable candidate source to specify what should be inserted when the completion is confirmed.
* complete.sh: fixes and clean up; a new fn ble/string#split.
  - ble-core.sh: a new function ble/string#split to replace "GLOBIGNORE=* IFS=... eval 'arr=(...)'".
  - complete.sh: (ble-complete/.fignore/filter): fixed a bug that local variable pat was leaked.
  - complete.sh: (ble/widget/complete): fixed a bug that "shopt -s force_fignore" was ineffective.

## 2016-07-14
* (ble/util/sleep): add fallbacks to sleepenh and usleep for bash-3.*.
* isearch: fixed a bug that a new range overlapped with the current match cannot be matched incrementally.
* (bleopt): fixed a bug in printing variables.

## 2016-07-09
* (ble/history/add): work around for bash-3.0 to add history entries to bash command history.
* (ble/history/add): fixed a bug that command history was always disabled under bash-3.2.

## 2016-07-08
* ble-syntax.sh, complete.sh (shopt -q autocd): fixed a bug that error messages were output to stderr on completions in bash-3.*.
* ble-edit (prompt): :new: support shell variable PROMPT_DIRTRIM for PS1 instantiation.
* ble-edit: Now, the history index \! in PS1 is the index of the editted line.
  - isearch: also, the position shown while isearch is changed to the history index.

## 2016-07-07
* README: move language options to the top. add icons of the languages.
* update README and LICENSE
* ble-edit.sh (ble-edit/isearch/backward): improve the performance (work around for slow bash arrays).

## 2016-07-06
* ble-edit.sh (_ble_edit_history_edit): changed to hold the whole editted history data.
* ble-syntax: glob patterns are not active in variable assignments.
* ble-edit.sh: Fixed: Ensure job state changes are printed to standard output.
  - fixed a bug that job state changes are not output when PS1 contains '\j'.
  - fixed a bug that the changes are not output immediately.
* minor fixes in visible-bell and check-stderr.
  - ble-core.sh (ble-term/visible-bell): fixed a bug in subsecond treatment.
  - ble-edit.sh (.ble-edit/stdout/check-stderr): fixed a bug that lines without LF were not processed.

* (ble/util/joblist): use ble/util/joblist for internal usage of jobs.
  - ble-core.sh (ble/util/joblist): bugfix:
    There are four places where _ble_util_joblist_jobs is incorrectly used as _ble_util_joblist_list.
  - ble-core.sh (ble/util/joblist): bugfix:
    - Changes in (previous job) and - (previous job) were also detected as changes.
    - This cannot be said to be an essential change in the job status, so it will be ignored.
  - ble-core.sh (ble/util/joblist): bugfix: add ble/util/joblist.clear
    After a job state change is reported by bash itself,
    A state change may be reported twice, so in such a case, clear the cache.
  - Where each jobs in ble-edit.sh is called, call ble/util/joblist instead.
  - Where jobs are used in ble-syntax.sh and ble-color.sh to check the existence of jobs,
    First call ble/util/joblist to check the job status change, then make the desired jobs call.
* ble-core.sh: add a new function ble/util/joblist.

## 2016-07-05
* ble-core: add option bleopt_stackdump_enabled
  - Only when bleopt_stackdump_enabled is set to a non-zero value
    Make stackdump output. The default is 0 (no output).

## 2016-07-04
* ble-decode.sh (ble-decode-attach): fixed a bug that makes C-{u,v,w,?} ineffective after the second ble-attach.
  - ble-decode-bind/uvw now works on ble-attach from the second time onwards.
    Clear _ble_decode_bind__uvwflag immediately after source "~.bind" with ble-decode-attach.

## 2016-06-27
* ble-core.sh ($_ble_base/cache): move to _ble_base_cache="$_ble_base/cache.d/$UID" for user separation.
* ble-core.sh ($_ble_base_tmp): change to use /tmp/blesh/$UID if it is available.
  - Until now, temporary files were placed in the same directory as ble.sh.
    However, considering speed, I would like to place files such as ble_util_assign.tmp in tmpfs (on RAM).
    Therefore, change the temporary files to be placed above /tmp.
* ble-core.sh: add ble/util/sleep to provide subsecond sleep.

## 2016-06-25
* ble-edit.sh (_ble_edit_str.replace debug codes): resume from wrong state.

## 2016-06-23
* ble-core.sh (ble/util/array-reverse): improve performance.

## 2016-06-22
* ble-edit/isearch: show progress of search.

## 2016-06-19
* ble-edit/isearch: ble/widget/isearch/prev cancel a task in que, ble/widget/isearch/accept is not effective while a search.
  - ble/widget/isearch/prev: If there are currently running tasks (_ble_edit_isearch_que), cancel them one by one.
  - ble/widget/isearch/accept: If there is a task currently running, just ring the bell and skip the operation.
  - ble-edit/isearch/.goto-match: If there is a match, force drawing even with is-stdin-ready.
* ble-edit/isearch: check is-stdin-ready on history search to suspend.

## 2016-05-21
* update README.md for v0.1.5
* ble-edit.sh: bugfix, incorrect _ble_edit_ind caused by the inconsistensy of history/isearch targets.
  - _ble_edit_ind inconsistency due to history search of _ble_edit_history and loading of _ble_edit_history_edit
    This caused a dirty-range inconsistency and an error. It seems that a long-standing mysterious bug has been squashed.

## 2016-04-07
* ble-syntax.sh (ble-syntax/parse/shift.impl2): bugfix shift omission due to defect in control structure.

## 2016-01-24
* ble-syntax.sh: \debug add debug codes for dirty-range bug
  - ble-edit.sh: dirty range checks
  - ble-syntax.sh (ble-syntax/parse): remove readonly flag of `beg' and `end' for dirty-range bug

## 2015-12-30
* modify README: use -O option for curl; release v0.1.4.

## 2015-12-26
* (ble-color/faces): preserve orders of addhook-onload, and ble-color-{def,set}face.
  - ble-color/faces/addhook-onload, called before ble-color/faces initialization
    Because ble-color-defface and ble-color-setface were recorded independently,
    Processes were executed in a different order than they were actually called.
    The records are combined into one array _ble_faces_lazy_loader so that the order is preserved.

## 2015-12-25
* (ble-color) \change ble-color-{def,set}face processing is also delayed.
* functions/getopt.sh: \add description.

## 2015-12-24
* (ble-syntax:bash): :new:, support option `-p` for keyword `time`.
* (ble-syntax:bash): \new, support `a=([key]=value)` and `a+=([key]+=delta)`.
  * (ble-syntax): \new local variable `parse_suppressNextStat` in ble-syntax/parse.
  * (ble-syntax:bash): \bugfix, correct resume for `var+`, `arr[...]+` -> `var+=`, `arr[...]+=`.
  * (ble-syntax:bash): \new, support `a=([key]=value)` and `a+=([key]+=delta)`.
* (ble-syntax:bash): \new context CTX_CASE.
* (ble-syntax:bash): \new CTX_COND{X,I}; \change unexpected '(' is treated as extglob '@(' instead of sub-shell '(';
  * ble-syntax.sh: Separate `CTX_COND{X,I}` from `CTX_VAL{X,I}`.
  * ble-syntax.sh: '(' appearing in the command will be treated as extglob parentheses.
    Until now, it was provisionally treated as a sub-shell, but
    Since many errors occur and are noisy, we will treat them as extglob parentheses, which have fewer errors.
* ble-edit.sh: \bugfix histexpand condition [[ -o histexpand ]] inverted.
  * \bugfix History expansion no longer worked.
    There was an error in the condition judgment: [[ -o histexpand ]] → [[ ! -o histexpand ]]
  * \bugfix : is executed when history expansion fails.
    This is because history -p does not output anything to standard output if history expansion fails.
    If it fails, output it manually by echo "$BASH_COMMAND".
* (ble-syntax:bash): \support shopt -s extglob; \bugfix error on {delimiter after redirect,'<' redirect};
  * extglob support: `CTX_GLOB`, `ATTR_GLOB`, `ctx-glob`, `check-glob` added.
  * \bugfix Analysis data writing violation occurs when there is redirect/delimiter immediately after redirect.
  * \cleanup: Clean up common regular expressions:
    `$_ble_syntax_bash_rex_spaces`,
    `$_ble_syntax_bash_rex_IFSs`,
    `$_ble_syntax_bash_rex_delimiters`.
  * \bugfix `$_ble_syntax_bash_rex_redirect`: < was missing.

## 2015-12-23
* (ble-syntax:bash): special treatment of arguments of `declare`.
  * (ble-syntax:bash): Treat arguments of declare, typeset, local, export, and alias commands in a special way syntactically. In particular, it allows the array syntax =().
    For that purpose, add new context values ​​`CTX_ARGVX`, `CTX_ARGVI`.
  * (ble-syntax:bash): Completion candidates for `CTX_ARGVI` are variable names. The part after the equal sign '=' lists the file name completion candidates.
  * (ble-syntax:bash): Changed behavior of array syntax in normal assignment syntax.
    Up until now, when a=(1 2 3)echo etc., a=(1 2 3) was interpreted as an array assignment and the echo part was interpreted as a command.
    For this reason, I configured it so that when I nest-pop the array syntax, the word is immediately removed and becomes cxt==CTX_CMDXV.
    However, when we check the actual behavior of bash, it appears that a=(1 2 3)echo is interpreted as the right-hand side of an assignment statement, like a='(1 2 3)echo'.
    Changed so that there is no special behavior during nest-pop to match the actual behavior of bash.

## 2015-12-21
* (ble-syntax:bash): Fixed arithmetic expression termination condition, += invalid in bash-3.0; (completion-context): Generate completion candidate immediately after a+=.
  * ble-syntax.sh (ble-syntax:bash): Modify the termination condition of arithmetic expressions.
    $((...)) ((...)) counts '(', ')' to determine the end.
    $[...], ${arr[...]} In arr[...]=, '[', ']' are counted to determine the end.
    ${var:...:...} exits immediately when '}' is encountered.
  * ble-syntax.sh (completion-context): Generates completion candidates even immediately after a+=.
  * ble-syntax.sh (ble-syntax:bash): disable += under bash-3.1.
* ble-edit.sh: bugfix failure of catch C-d in bash-3.0.

## 2015-12-20
* (ble-highlight-layer:syntax): color of special files, permission of files in redirection.
  - ble-syntax.sh: bugfix of assertion test in ble-syntax/parse/tree-append.
  - ble-syntax.sh (ble-highlight-layer:syntax): color filenames of block device, character device, pipe, and socket.
  - ble-syntax.sh (ble-highlight-layer:syntax): redirection: check permissions.
* (ble-syntax:bash): bugfix, tree-structure corruption on edit of array subscripts in array-element assignment.
  - ble-syntax.sh: Parse tree corruption occurs when rewriting array index.
    At the end of array index ']=', nest-pop was performed at the beginning position.
    Because of this, past analysis results were being rewritten,
    Information installed during shift was disappearing.
* ble-edit.sh: add support `set +o history`; ble-syntax.sh: check file existence on '<' redirection.
  - ble-edit.sh: add support `set +o history`
  - ble-syntax.sh (ble-highlight-layer:syntax): check filename of `<` redirections.
  - ble-syntax.sh (constants): refact,
    definition of `local rex_redirect` -> global `_ble_syntax_bash_rex_redirect`.
    rename `_BLE_SYNTAX_CSPACE` -> `_ble_syntax_bash_cspace`.
  - ble-edit.sh: refact, rename functions `.ble-edit[./]history[./]*` -> `ble-edit/history/*`.
* complete: Add/modify candidate generation locations, list subdirectories as command completion candidates
  - ble-syntax.sh (complete): bugfix, no candidates were generated when trying to run complete on spaces between words.
  - ble-syntax.sh (complete): generate filenames after `VAR='.
  - ble-syntax.sh (complete): generate filenames just after the redirection.
  - complete.sh: Modify to list subdirectories of the current directory as command completion candidates.
    This is because there may be cases where you want to execute a file with an executable attribute located in a subdirectory.

## 2015-12-19
* complete.sh: support `FIGNORE`, `shopt -s force_fignore`.
  - Makefile: bugfix, remove `ble-getopt.sh` from the required files to generate ble.sh.
  - complete.sh: support `FIGNORE` and `shopt -s force_fignore`.
* functions/*: move unused file ble-getopt.sh to `functions/`. Add new impl of getopt.
* ble-syntax.sh (ble-syntax:bash): redirections: bugfix '<<<', support '>|', overwrite check of files, etc.
  - ble-syntax.sh (ble-highlight-layer:syntax): Support `set -o noclobber`; Check overwrites of target files of redirections for '>', '&>', and '<>' redirect.
  - ble-{core,decode,edit}.sh, bind.sh, term.sh, emacs.sh: change redirection '>' -> '>|' for the case of the noclobber option on.
  - ble-syntax.sh (ble-syntax:bash): support the redirect using `>|`.
  - ble-syntax.sh (ble-syntax:bash): bugfix false syntax error of `<<<`.
  - ble-syntax.sh (ble-syntax:bash): bugfix redundant skip on unexpected termination of redirect by an end of command or another redirection.
  - ble-syntax.sh (ble-syntax:bash): bugfix, do not allow newline after the redirection introducers.
* ble.pp, ble-core.sh: Check and modify dependencies on external commands.
  - ble.pp (ble/.check-environment): Remove tput (POSIX UP option) which is not necessarily required.
  - ble-core.sh (ble-term/visible-bell): Add a function `ble/util/getmtime` to get modified time of files in a compatible way.
  - ble-edit.sh (ble/widget/command-help): Select available pager from any of `$PAGER`, less, more, and cat.
* ble-syntax.sh: syntax: quotations in words in parameter expansion (shopt -u extquote, etc.).
  - ble-syntax.sh: support single quotation in parameter expansion.
  - ble-syntax.sh: support shopt -u extquote.
* clean up & minor behavior change: Check bash opts --{posix,noediting,restricted}, Unset mark on accept-line.
  * bug fix
    - ble-syntax.sh (ble-syntax:bash/extract-command/.construct-proc): remove a debug code which prints the message "clear words".
  * minor behavior change
    - ble-edit.sh (ble/widget/accept-line): redraw without mark.
    - ble.pp (startup check): do not load ble.sh for bash --posix, --noediting, or --restricted.
  * clean up
    - ble-decode.sh (ble-decode-byte:bind/EPILOGUE): use ble/util/is-stdin-ready instead of the direct use of `read`.
    - ble-core.sh (ble/util/is-stdin-ready): use LANG instead of LC_ALL.
    - ble-edit.sh, ble-syntax.sh: use [[ -o histexpand ]] rather than [[ $- == *H* ]].
    - ble-syntax.sh (test): remove unused functions `.ble-shopt-extglob-push`, and `.ble-shopt-extglob-pop` for test.
    - ble-edit.sh: remove old complete functions:
      - .ble-edit-comp.initialize-vars
      - .ble-edit-comp.common-part
      - .ble-edit-comp.complete-filename
      - ble/widget/complete
      - ble/widget/complete-F
    - ble-syntax.sh, complete.sh: no need of redirection for `shopt -q optname`.

## 2015-12-09
* Refactoring ble-edit.sh/ble-line-prompt.
  * .ble-line-prompt -> ble-edit/prompt.
  * `_ble_cursor_prompt`, `_ble_line_prompt` -> `_ble_edit_prompt`.
* Refactoring ble-core.sh, ble-color.sh, cmap/xterm.sh.
  * ble-core.sh: .ble-text.* -> ble/util/*.
  * ble-color.sh: .ble-color.* -> ble-color/.*.
  * cmap/xterm.sh: .ble-bind.function-key.* -> ble-bind/cmap:xterm/*.
* Refactoring ble-decode.sh.
  * ble-core.sh: .ble-term.{visible,audible}-bell -> ble-term/{visible,audible}-bell.
  * ble-decode.sh: .ble-stty.* -> ble-stty/*.
  * ble-decode.sh: .ble-decode-* -> Changed to appropriate name.
* Refactoring and clean up.
  * ble-edit.sh, etc: 'ble-edit+' -> 'ble/widget/.
  * 'ble-edit.sh: Organized ble-edit/exec function names.
  * ble-decode.sh: ble-decode-byte function name organization, ble-edit dependency separation.
  * README-ja_JP.md: Corrected Japanese explanation.
  * README.md: English correction.
  * ble-syntax.sh: Unified code comment @fn -> function.

## 2015-12-06
* ble-core.sh: Add function ble/util/cat to replace /bin/cat.
  - ble-core.sh: Function ble/util/cat. Implements the same functionality as a simple call to command cat with builtin read.
  - ble-decode.sh (ble-bind --help): The external command cat was called, but it can be implemented with bash's built-in command, so it has been replaced.
  - README.md: Added explanation about gmake/make.
* Update README-ja_JP.md
* ble-bind: New option `-L, --list-functions`, ble-color.sh bugfix initialization of faces:region,disabled,overwrite_mode.
  - ble-color.sh: bugfix, color initialization (region disabled overwrite_mode) was not registered for lazy loading.
  - ble-decode.sh (ble-bind): New option `-L, --list-functions` to list edit functions.

## 2015-12-03
* Changed default value of bleopt_char_width_mode from `emacs` to `east`.
* Update README-ja_JP.md.
* Add README-ja_JP.md. Japanese explanation.
* optimization: lazy init of faces (ble-{syntax,color}.sh), removal of temporary files (ble-core.sh).
  * ble-syntax.sh, ble-core.sh: lazy initialization of `_ble_faces_*`.
  * minor: modify messgese: initialization message, the header of the script ble.sh.
  * ble.pp: Add pp switch `measure_load_time` to identify the initialization bottle neck.
  * ble-core.sh (`_ble_base_tmp.wipe`): optimization, use parameter expansion instead of regex captures.
* Support here string, shopt -q progcomp; Bugfix ble-syntax/parse/nest-equals.
  * ble-syntax.sh: support here string.
  * ble.htm: comment out outdated descriptions.
  * ble-syntax.sh (ble-syntax/parse/nest-equals): bugfix, The case of onest[3]<0 was not considered in the previous bugfix.
  * complete.sh: Enable/disable program completion using shopt -q progcomp.
* update version numbers.
* ble-syntax.sh (ble-syntax/parse/nest-equals): fatal bugfix, misjudge on nest equality test causing nest structure corruption.
  * Note: The cause was that although the nest start position included in the _ble_syntax_nest element was recorded as a relative position, it was directly assigned to an absolute position variable.
  * Others ble-syntax.sh, ble-color.sh: compatibility fix., fgrep to command grep -F.
* README.md: correct download links.
* `*.sh`: Add `command` for external command execution.
* (ble-edit/stderr for bash-3.0): Add ignoreeof-message.txt for C-d message i18n.
* `*.sh`: New marker `__ENCODING__` for character code dependent part

## 2015-11-30
* complete.sh (ble-complete/source/argument): minor bugfix, default behavior using comp_opts exported by func .../.compgen.
  * Others ble.pp: check chmod.
* Makefile: a phony target `dist`.
* memo.txt: Organize todo.
* complete.sh: bugfix, completion doesn't work on an argument without complete -D spec.
* ble-edit.sh (ble-edit+isearch/next): bugfix, didn't match locally on self-insert of forward isearch.
* ble-decode.sh (generate-source-to-unbind-default): bugfix, need of LANG=C.
  * If you do not set LANG=C, the output of bind -sp will contain strange bytes and will fail to be interpreted.
    (This is not a problem if the character encoding system does not include ASCII characters, such as UTF-8.
    Add to memo.txt as Note(2015-11-30). )
* Update README.md
* ble-edit.sh: remove dependency on GNU awk.
  * ble.pp: Just in case, prepare use_gawk (PP variable) so that you can revert to gawk.
  * ble.pp (ble/.check-environment): check awk.
  * ble-core.sh (ble/util/array-reverse):(awk scripts):
    + uninitialized Initialize variable `decl`.
    + Replace locale dependent /[a-z]/ type with POSIX brackets (/[[:alpha:]]/, /[[:alnum:]]/).
  * ble-edit.sh (.ble-edit/history/generate-source-to-load-history):(awk scripts): uninitialized variable `n`.
  * ble-decode.sh (.ble-decode-bind/generate-source-to-unbind-default):(awk scripts):
    + Make sure that argument names and global variables do not overlap.
    + Do not use gawk-specific features (/\y/, match third argument).
    + There were places where variables targeted by bugfix and gsub were not specified.
  * I also confirmed the operation with gawk --lint and nawk respectively.

## 2015-11-29
* ble-edit/isearch: Search within the current command.
  * The old history item search function has been renamed:
    - ble-edit+isearch/forward -> ble-edit+isearch/history-forward,
    - ble-edit+isearch/backward -> ble-edit+isearch/history-backward,
    - ble-edit+isearch/self-insert -> ble-edit+isearch/history-self-insert.
  * Changed to record matching range in search history (_ble_edit_isearch_arr)
  * Added function to search in command from current position/replaced old function:
    - ble-edit+isearch/forward,
    - ble-edit+isearch/backward,
    - ble-edit+isearch/self-insert.
* ble-edit.sh (+isearch/next): Enclose matching range.
  * ble-edit.sh (+isearch/next), set region to matched range.
  * ble-edit.sh: pattern matching using [[ text == pattern ]] instead of case statement.
  * ble-color.sh (ble-syntax-layer:region/update): bugfix, PREV_UMIN/PREV_UMAX out of range due to the shift failure of omin/omax.
* ble-core.sh: full support for bleopt_input_encoding=C
  * ble-core.sh: Add functions: ble-text-b2c+C, and ble-text-c2b+C.
  * ble-core.sh (.ble-text.c2bc): rename .ble-text.c2bc -> ble-text-c2bc.
  * .gitignore: Organize old things. /wiki added.

## 2015-11-28
* Update README.md
* ble-decode.sh, ble-edit.sh: support `bind -xf`.
  * ble-core.sh: Add functions ble/string#common-{prefix,suffix}.
  * ble-decode.sh, ble-edit.sh: support `bind -xf COMMAND`.
  * ble-edit.sh:714: If ^M is directly embedded, GitHub seems to misunderstand the line break position, so change it to $'\r'.
  * complete.sh: embedded sed scripts, POSIX compliance.
* ble-color.sh: Add a function ble-color-show.
* README.md: Add animation gif.
* README.md: settings for syntax highlighting.
* README.md: Add some description of settings.

## 2015-11-27
* Create LICENSE.md
* Update README.md

## 2015-11-24
* ble-edit.sh (+magic-space): bugfix, expand history to the part before the current cursor position.
* complete.sh: behavior of source/argument, compopt -o/+o, bugfix.
  - complete.sh (ble-complete/source/argument): complete -o ..., compopt -o option +o reading option.
  - complete.sh (ble-complete/util/escape-regexchars): bugfix.
  - complete.sh: Add action/plain, action/argument, action/argument-nospace.
  - complete.sh: Add source/dir.
  - complete.sh (ble-complete/source/argument): support -o nospace, -o dirnames.
* complete.sh (ble-complete/source/argument): bugfixes.
  * ble-complete/source/argument/.compgen-helper-prog: Export `COMP_LINE` `COMP_POINT` `COMP_KEY` `COMP_TYPE`
  * ble-complete/source/argument/.compgen-helper-{prog,func}: Pass arguments `command`, `cur`, and `prev` for program/function.
  * ble-complete/source/argument: Fix option -F, -C interruption failure.
  * ble-complete/source/argument: Fix -F <-> -C miss arrangement.
  * ble-complete/source/argument: Correct IFS when compgen is called.
  * ble-complete/source/argument: `return 1` if no candidates are generated.
  * ble-complete/source/argument: Evaluate `compgen` in the original shell (i.e., not in a sub-shell).
  * ble-complete/source/argument: Filter and modify candidates generated by `compgen` using `sed`.

## 2015-11-23
* ble-edit.sh (ble-decode): show the message to run "stty sane" after "ble-detach".
* ble-syntax (ble-syntax:bash/extract-command): bugfix, removed the output variable being specified as local.
  - Others: complete.sh: compgen -F prog -C Compgen will issue a warning when you run cmd, so set it to compgen 2>/dev/null.
* complete.sh: Basic implementation of complete -p completion.
  * ble-core.sh: Create function ble/util/array-reverse.
  * ble-decode.sh (.ble-decode-keys, .ble-decode-key/invoke-command): bash-3.0 workaround, local -a keys=(), split local -a KEYS=() into two lines.
  * ble-syntax.sh: Maintenance for complete.
    * Added function ble-syntax/tree-enumerate-break: The intent of "((tprev=-1))" is difficult to understand.
    * Add function ble-syntax:bash/extract-command:
    * ble-syntax/tree-enumerate: Default value of shell variable iN to end of _ble_syntax_text.
    * ble-syntax/completion-context: Supports CTX_VALI, CTX_VALX.
    * ble-syntax/completion-context: Changed some completion contexts from file to argument.
  * complete.sh: completion based on complete -p setting.
    * ble-complete/source/argument: add

## 2015-11-22
* ble-syntax.sh: Organize bash grammar-related function names.
  * ble-decode.sh (ble-bind): Add . to error message. Delete old comment.
  * ble-syntax.sh (ble-syntax/parse/{check,ctx}-*): Organized the names of functions specific to bash grammar.

## 2015-11-21
* cmap/cmap+*.sh: Update for current ble-decode.sh.
* ble-edit.sh (ble-edit+magic-space): Add edit function magic-space.

## 2015-11-19
* Support of PROMPT_COMMAND, and function bleopt.
  * ble-edit.sh: easy support of PROMT_COMMAND.
  * ble-core.sh: Added bleopt function.
  * ble-decode.sh (.ble-decode-initialize-cmap): POSIX sed BRE does not support the quantifiers: \+, \?.
* ble-syntax.sh: More accurate history expansion.
  * Parsing history expansion according to histchars
  * When extglob is set, !( is not interpreted as history expansion.
  * History expansion in the string "~" ends just before "
* ble-core.sh: workaround for bash-3.0 regex in _ble_base_tmp.wipe.

## 2015-11-17
* `ext/mwg_pp.awk`: Include mwg_pp.awk in ext; Makefile (listf): renamed to list-functions and modified.
* ble-syntax.sh (ble-syntax/parse/nest-equals): bugfix (operater associativity), incorrect break of loops.

## 2015-11-09
* ble-core.sh (_ble_base_tmp.wipe): bugfix, correct iteration of old tmp files.

## 2015-11-08
* complete.sh: Support for interrupting candidate enumeration when there is user input (bash-4.0 or later); ble-syntax.sh: Fixed comment judgment.
  * ble-core.sh (ble/util/is-stdin-ready): Added functions. Determine whether there are any unprocessed characters left in standard input. This is used to determine whether user input is pending.
  * ble-syntax.sh (ble-syntax/parse/check-comment): Comments are disabled when using shopt -u interactive_comments when parsing the command line.
  * ble-syntax.sh (ble-syntax/parse/check-comment): bugfix Comment start judgment (beginning of word). The start of a word was determined not by the beginning of the word, but by the beginning of the word or the position of the analysis start point inside the word.
  * complete.sh (ble-complete/source/command/gen, ble-edit+complete): Since it takes time to enumerate and match command candidates, use ble/util/is-stdin-ready to determine whether to interrupt.

## 2015-11-07
* Update README.md
* ble.pp: check environment for required commands, ble-edit.sh: 'M-\'.
  * ble.pp: check required commands.
  * ble-core.sh: remove dependencies on `touch' command.
  * ble-edit.sh, keymap/emacs.sh: Add edit function: delete-horizontal-space ('M-\').

## 2015-11-06
* ble-syntax.sh: cleanup debug codes.
* ble-syntax.sh (ble-syntax/parse/shift.nest): bugfix, parse error by shift failure of _ble_syntax_nest.

## 2015-11-25
* Create README.md

## 2015-08-25
* m, bugfixes.
  * PS1's '!' handling,
  * PS1's \w processing,
  * (bash-3.0) An error message was missing when checking history '!1' &>/dev/null.
* bugfix, specify explicit collation order for regs and globs.
  * Character ranges in regular expressions and glob patterns are dependent on collation order.
  * To obtain the desired results for ascii characters, `local LC_COLLATE=C' should be explicitly specified.

## 2015-08-24
* ble-edit.sh (.ble-edit.history-add): bugfix, handling of HISTCONTROL.

## 2015-08-19
* bin/ble-edit.sh: bugfix for bash-3.0, history -s did not work correctly.

## 2015-08-18
* bugfix and cleanups.
  * ble-core.sh (ble-assert): bugfix, correct return value.
  * ble-edit.sh, ble-synta.sh: bash-3.0 bugfix, `local arr=(...)' form cannot be used in bash-3.0.
  * ble-edit.sh (hist_expanded.initialize): renamed to `ble-edit/hist_expanded.initialize'.

## 2015-08-16
* Measures to remove color from disappearing words (tentative).
  * ble-syntax.sh (ble-syntax/parse): Range aggregation of extinct words.
  * ble-syntax.sh: Organize range updates and translations. Added function ble/util/[uw]range#{update,shift}.
* Display system bug fixes.
  * ble-edit.sh (ble-edit/dirty-range/update): bugfix, error in reading endA0, error in variable name delta/del.
  * ble-syntax.sh (ble-highlight-layer:syntax/update-attribute-table): bugfix in umin/umax update, The variable name used for updating umax was incorrect.
* Measures against overwriting built-in commands. ble-syntax shift bufgix for bash-4.2 arithmetic expressions.
  * ble-syntax.sh (bash-4.2): bugfix, an arithmetic expression in ble-syntax/parse/shift.{tree1,nest} was found to crash bash-4.2.
  * ble-core.sh: Added ble/util/set function.
  * ble-edit.sh: Execute unset -f builtin to prevent builtin overwriting (it won't work if both builtin and unset are overwritten).
  * ble-edit.sh: Return/break/continue also prohibits overwriting.
  * ble-*.sh: Use [[ ]] instead of test.
* Suppress redrawing when pasting (determined by read -t 0). Display \x80-\x9F as M-^?
  * ble-edit.sh: Display \x80-\x9F in the edit string as M-^?. The display was distorted.
  * ble-edit.sh (ble-decode-byte:bind): Suppress redrawing when the next character comes.
  * ble-edit.sh: Organized function names around exec/gexec.
  * ble-edit.sh: Delete function .ble-edit-isearch.create-visible-text

## 2015-08-14
* Supports syntax function ..., history expansion bugfix.
  * ble/src: Added .srcoption.
  * ble-syntax.sh: Change color of defface function.
  * ble-syntax.sh: Supports syntax `function ...`.
  * ble-syntax.sh: Restrict commands that come immediately after `function ...`, `hoge ()` to compound-commands.
  * ble-edit.sh: bugfix, history expansion was enabled even when set +H. history -p performs expansion regardless of set +H.
  * ble-edit.sh: bugfix, defining the function echo prevents commands from being executed any further. Changed echo/printf to be called via builtin.
* ble/util/assign cleanup, ble/util/type add, .ble-line-prompt/update bugfix.
  * ble-core.sh (ble/util/assign): also specified in cleanup, ble/util/sprintf, ble/util/type, ble/util/isfunction,
  * ble-core.sh: Added ble/util/type. Change $(type -t) to process using this,
  * ble-edit.sh (.ble-line-prompt/update): bugfix, '$' and '`' in local sentences are escaped and not expanded.
* ble-edit.sh: Prompt update optimization.
* ble-core.sh (ble/util/assign): $(...) Speed-up function.
* shift Speed-up and word coloring that takes into account nested structure.
  * ble-syntax.sh (ble-syntax/parse/shift): shift taking into account nested structure,
  * ble-syntax.sh (_ble_syntax_tree): Changed to hold coloring information for each word in the data array,
  * ble-syntax.sh (ble-highlight-layer:syntax/update-word-table): Coloring taking into account nested structure.
* leak variables: g cs
* cleanup, leak variables treatment.
* ble-syntax.sh: Include unterminated clauses in the enumeration. Organize others.
  * ble-syntax.sh (ble-syntax/print-status): prints unterminated nodes.
  * ble-syntax.sh: add new functions ble-syntax/tree-enumerate, ble-syntax/tree-enumerate-children.
  * ble-syntax.sh: rename shell variable: _ble_syntax_word -> _ble_syntax_tree.
  * ble-syntax.sh: cleanup.

## 2015-08-13
* ble-syntax.sh: clenup, print-status/dump-tree.
* ble-syntax.sh (_ble_syntax_stat): Added tchild, tprev (offset information to older brother/child) to analysis state.
* ble-syntax.sh (_ble_syntax_word): Format change. This is a provisional method that calculates offset information for older brothers and children on the spot.

## 2015-08-12
* memo.txt: _ble_syntax_word format change plan, ble-syntax.sh: clean up

## 2015-08-11
* ble-syntax.sh (`_ble_syntax_nest[]`): Format change → "ctx wlen wtype nlen type"
* ble-syntax.sh (`_ble_syntax_stat[]`): Change format → "ctx wlen wtype nlen"
* ble-syntax.sh (`_ble_syntax_word[i]`): Change element format from wtype wbegin to wtype wlen.
* ble-edit.sh (.ble-line-info.draw): Control characters can also be inserted,
* ble-syntax.sh (ble-syntax/print-status): Added,
* ble.pp: Double boot countermeasures,
* ble-edit.sh: history load.

## 2015-08-08
* ble-syntex.sh (ble-syntax/completion-context/check-prefix): completion at redirect filenames.

## 2015-07-10
* memo.txt: Added todos.

## 2015-06-15
* modified complete.sh

## 2015-03-22
* ble-decode.sh: bugfix, even in bash-4.1 ESC [ needs to be translated
* ble-decode.sh: bugfix, even bash-4.1 needs to be registered with ESC *
* ble-core.sh, etc.: Temporary files will be placed in tmp/$UID.

## 2015-03-12
* ble-syntax.sh (ble-syntax/parse): There was word in a place where stat was not set, and it was not shifted.

## 2015-03-08
* ble-edit.sh (ble-edit/draw/trace): bugfix, fixed to use regular expression by setting LC_COLLATE.
* bashbug related bugfixes: Several bugfixes, all related to bash bugs...
  - `<bug>` The cursor display position is shifted in bash-4.1 and below.
  - `<bug>` bash-4.2, 4.0, 3.2, error occurs for incomplete editing content
  - `<bug>` Prompt is not displayed in bash-4.0, 4.1
  - `<bug>` Prompt color is not colored under bash-4.1
* ble-decode.sh (.ble-decode-char): control/alter/meta/shift/super/hyper prefix is
  It was applied to itself and output on the spot.
* ble-core.sh (ble/util/declare-print-definitions): Supports associative arrays
* ble-decode.sh, etc.: Unified option name ble_opt to bleopt
* ble-decode.sh: .ble-decode-char reimplementation
  - Merge modification functionality into send-modified-key (formerly sendkey-mod)
  - Supports modifications other than ESC such as C-x @ S
  - Interpretation of CSI sequence with .ble-decode-char/csi/*
  - Rewrite cmap/default.sh to correspond to new implementation

## 2015-03-06
* ble-decode.sh (stty): -icanon settings.
* ble-edit.sh (PS1): Bugfix, job count, time and other updates.
* ble-edit.sh (.ble-line-text/update/postion)
  - bugfix: When adding \n at the end of a line of ascii printable characters, it was not registered in ichg.
  - bugfix: 0 was specified for length specification of _ble_util_string_prototype
  - bugfix, handling of tab near end of line
  - Control characters are also subject to eviction.
  - When using xenl, always add \n at the end of the line (including when expelling).
  - Record any evictions.
* ble-edit.sh (.ble-line-text/getxy.cur): Create a new getxy to get the cursor position.
* ble-edit.sh (ble-edit/draw/trace): Drawing attributes
  - term.sh: Read drawing attributes from terminfo.
  - ble-color.sh: Supports blinking, invisible, italic, and strikethrough drawing attributes.
  - ble-color.sh: Changed to use the result of term.sh in sgr construction.
  - ble-edit.sh (.ble-line-prompt): Changed so that ble-color-g2sgr can write terminal-independent PS1.
* ble-decode.sh (ble-decode-kbd): bugfix, it was not handled correctly when there were multiple keys.
* Supports overwrite-mode
* ble-syntax.sh, ble-color.sh: Changed coloring using layer:syntax to using face.
* ble-decode.sh, ble-edit.sh: Unification of conditional commands. Unify test, [, etc. to [[.

----

<!---------------------------------------------------------------------------->
# Old ChangeLog

## 2015-03-03

  * ble-edit.sh, ble-edit.color: Color when discard-line
  * ble-edit.sh, ble-core.sh, etc: Change echo to builtin echo.
  * ble-edit.sh: bugfix, can't go up in multiple lines
  * ble-edit.sh: bugfix, the gap in accept-line of empty line is one line even though there are multiple lines.
  * Prompt reimplementation
    - ble-edit.sh (ble-edit/draw/trace): Tracing the position of strings containing escape sequences.
    - ble-edit.sh (.ble-line-prompt/update): Reimplemented prompt construction. Correct calculation even when $() is present.
  * ble-complete.sh (source/command): Enumerate directory names as candidates when running shopt -s autocd.
  * ble-complete.sh: Changed the method of selecting completion candidates. Prioritize those with closer starting points.

## 2015-03-01

  * ble-edit.sh: .ble-edit-draw.goto-xy, .ble-edit-draw.put deprecated
  * complete.sh: If the function name contains /, it will not be enumerated by compgen -c, so enumerate it separately.

## 2015-02-28

  * Initialization optimization
    - ble-decode.sh: ble-decode-kbd rewrite, ble-bind rewrite
    - ble-getopt.sh: slightly optimized
    - ble-decode.sh: Changed to receive ESC [ as UTF-8 2-byte code even in bash-4.3.
    - ble-decode.sh (.ble-decode-bind/generate-source-to-unbind-default): Consolidate awk calls into one.
    - ble-decode.sh (.ble-decode-key.bind/unbind): Rewritten with [[ ]], bugfix.
    - ble-decode.sh, bind.sh: Separate the code for generating bind -x into bind.sh.
    - ble-edit.sh, keymap.emacs.sh: Separate and cache keymap initialization part.
    - ble-edit.sh: history lazy loading supported
  * ble-core.sh, ble-color.sh: .ble-shopt-extglob-push/pop/pop-all deprecated
  * ble-edit.sh: bugfix, position shifted with .ble-line-info.clear
  * ble-edit.sh: ble-edit/draw/put.il, ble-edit/draw/put.dl
  * ble-color.sh (ble-highlight-layer/update/shift): Shift even if the length does not change.
  * ble.pp (include ble-getopt.sh): I'm not currently using it, so I'll remove it for now.
  * ble-syntax.sh (completion-context): Support for simple parameter expansion.

## 2015-02-27

  * [bug] String is no longer displayed when there are changed characters such as TAB
  * bash-3.0, 3.1 compatible
    "[bug]bash-3.1 Japanese coloring/drawing is weird"
    - ble-edit.sh, etc.: @bash-3.1 bashbug workaround, ${param//%d/x} doesn't work, so surround %d with ''.
    - ble-syntax.sh, etc.: @bash-3.1 bashbug workaround, x${#arr[n]} seems to return the number of bytes, so put it in a normal variable and call it ${#var}.
    - *.sh: @bash-3.0: += operator replacement, array declaration fix.
    - term.sh: @bash-3.0: bashbug workaround, output with declare -p is incorrect.
  * ble-edit.sh (.ble-line-text/update/slice): bugfix, when there was a change character, it referenced a local variable that no longer existed.
  * ble-core.sh: ble-load, ble-autoload
  * complete.sh:, ble-syntax.sh, ble-edit.sh: Implementation of context-sensitive completion

## 2015-02-26

  * ble-syntax.sh: a+=( corresponds to a=(

## 2015-02-25

  * ble/term.sh: Separate TERM dependent parts. Caching. It's not a complete transition, but it's gradual.
  * ble-decode.sh:
    - [bug] Created $_ble_bash/cache instead of $_ble_base/cache
    - [bug] accept-single-line-or-newline always accepts from second time onwards
  * ble-edit.sh:
    - [bug] Display is distorted when moving history when editing multiple lines
    - Implementation using printf %()T, compatible with PS1 \D{...}
    - [bug] Updating display attributes may not work properly.
    - [bug] The contents of info.draw shift when the number of lines in the edit string changes
  * Move cursor
    - ble-edit: Supports multi-line editing and cursor movement within fields
    - ble-edit.sh: Supports multi-line command history.
  * ble-syntax.sh: Rewrite ble-syntax-highlight+syntax to ble-highlight-layer:syntax
  * ble-syntax.sh:
    - Corresponds to the function definition func() format,
    - Supports conditional expressions [[ ... ]] and context within array initializers.
    - Responds to comments.
    - Supports the $[...] format (for some reason it is not mentioned in the bash explanation, but it can be used).
    - [bug] When inserting for at the beginning of invalid nest " $()"

## 2015-02-24

  * Supports partial update of ble-edit.sh output (measures against drawing flickering)
  * ble-syntax.sh: Change the format of _ble_syntax_word, _ble_syntax_stat
  * ble-syntax.sh: Stop the dirty-range expansion method that has been used so far and simply delete stat.
  * ble-syntax.sh: and numerous bugfixes associated with the above changes.
    - [bug] An invalid nest assertion occurs when deleting characters.
    - [bug] The moment the edited content reaches zero characters, a line break occurs and the display disappears.
    - [bug] Even if there is a line break, the beginning is not a command
    - [bug] Some fields are blank in _ble_region_highlight_table.
    - [bug] Word attributes continue to apply to subsequent words.
    - [bug] The string "BLE_ATTR_ERR" is mixed in _ble_syntax_attr.
    - Handling remaining dirty extensions and obsolete forms of _ble_syntax_word[]
      Delete the commented out part. Confirming efficiency due to dirty expansion changes,
      Addition of ToDo item due to slow shift.
  * ble-decode.sh: [bug] Created $_ble_bash/cache instead of $_ble_base/cache
  * ble-edit.sh: Changed the behavior of ble-edit+delete-backward-xword.

## 2015-02-23

  * ble-core.sh: ble-stackdump, ble-assert
  * [bug] Warning when dend-dbeg becomes negative in update-positions
  * [bug] Calculating coordinates when special characters span line breaks in info.draw

## 2015-02-22

  * ble-edit.sh: [bug] Lines are shifted when using .ble-line-info.draw
  * ble-syntax.sh: [bug] For and do are not colored?
  * Layering
    - ble-color.sh: How layers work, layers region, adapter, plain + RandomColor
    - ble-edit.sh: Display string construction function that supports layers. Removal of old construction functions. Change of output function.
    - ble-syntax.sh: Minor changes.

## 2015-02-21

  * Faster drawing
    - ble-syntax.sh: Apply according to the change range of attribute value and return the change range to LAYER_MIN, LAYER_MAX.
    - ble-edit.sh: Rewritten the construction part of the display string to support partial updates.
    - ble-syntax.sh: Changed to record the range of words whose contents have changed.
    - ble-syntax.sh (parse): _ble_syntax_attr_umin (change range of attribute value),
      To accommodate the accumulation of _ble_syntax_word_umin (word change range), shift is also executed for these.

## 2015-02-20

  * ble-decode.sh: around bind
    - bash-4.3 Changed to receive C-@ as UTF-8 2-byte code
    - bash-3.1 ESC [ changed to receive as UTF-8 2-byte code
    - bugfix, it was no longer possible to bind to \C-\\ \C-_ \C-^ \C-].
    - Organized version branch of bind.
    - Bind -r an existing bind regardless of ESC.
  * ble-decode.sh: Reimplementation of .ble-decode-key partial match search process. It was a strange move.
  * ble-decode.sh: bugfix, 8bit characters cannot be bound correctly. 8bit characters were encoded with c2s.
  * ble-syntax.sh: History expansion is enabled only when $- has H.
  * ble-syntax.sh: bugfix, work around bugs in bash-4.2. Rewriting arithmetic expressions that refer to arrays.
  * ble-core.sh: I was able to implement c2s using only bash functions, so I replaced fallback.
  * ble-core.sh: Memoize .ble-text.s2c with associative array in bash-4.0
  * ble-edit.sh: bugfix, c2w fails if ret has a specific value in advance in bash-4.0.
  * ble-edit.sh: bugfix, bind -x The handling of the prompt immediately before is the same in bash-4.0 as in the bash-3 series.
  * ble-edit.sh (around .ble-line-text.construct): Changed lc lg to be calculated later. One break. Commit once.

## 2015-02-19
  * ble-syntax.sh: Supports history expansion.
  * ble-decode.sh: bugfix, code to generate bind -x from bind -X.
    The format output by bind -X is escaped in a format that cannot be reused, so convert it.
  * ble.pp, etc: Supports noattach argument. Definition of ble-attach/ble-detach functions. Detach bugfix.
  * ble-edit.sh: bug, double prompt when setting bleopt_suppress_bash_output=

## 2015-02-18

  * ble.pp, ...: Change directory structure
  * ble-syntax.sh: Grammar support
    - Changed to treat process substitution as a word.
    - Supports arguments after redirection
    - Corresponds to fd part before redirection
  * bash-3.1 compatible
    - ble-edit.sh: Now you can capture C-d in bash-3.1 (although it's a rather difficult method).
    - ble-edit.sh, ble-decode.sh: bugfix, cursor keys do not work in bash-3. History not loaded.
    - ble-edis.sh: bash-3.1, bleopt_suppress_bash_output=1 works more stably, so I'll go with this.
    - ble-edit.sh: bash-3.1, cursor keys don't work. As usual, commands related to ESC [ ...
      I am getting an error that keymap cannot be found. I decided to read this after converting ESC [ to CSI (utf-8).
    - ble-syntax.sh: A workaround for a bug in bash-3.2.48, when an array element is referenced in (()), control jumps there unconditionally.

## 2015-02-17
  * ble-edit.sh (ble-edit/dirty-range): Added range update mechanism.
      _ble_edit_dirty also serves as a prompt redraw judgment, so we will leave it here for now.
  * ble-edit.sh: Fixed variable leak (global variable pollution). line i
  * ble-syntax.sh (ctx-command/check-word-end): Changed the processing timing for determining the end of a word.
  * ble-syntax.sh: Add context. CTX_CMDXF CTX_CMDX1 CTX_CMDXV CTX_ARGX0
    More accurate context judgment and error detection.
  * ble-syntax.sh: Many other fixes. It looks like there are still changes to be made, so I'll commit it now.

  * ble-edit.sh (accept-line): bug, commands starting with - cannot be executed.
  * ble-color.sh: [bug] Setting bg=black does not take effect.
    Corrected to distinguish between "unset" and "black".
  * ble-syntax (ble-syntax-highlight+syntax): nested error color range
  * ble-syntax: m, ;& is treated the same as ;; ;;& etc.
  * ble-syntax, etc: bash-3 regular expression countermeasures. Changed to a writing style that does not depend on differences in bash-3/4 regular expressions.

## 2015-02-16
  * ble-syntax.sh: bugfix, word length is not updated when updating to incremental.
    It was failing when storing to _ble_syntax_word.

## 2015-02-15
  * ble-synatax.sh: Incremental parsing and coloring according to bash syntax.

## 2015-02-14
  * ble-edit.sh (.ble-line-info.draw): Fixed the slow display.
    Improved so that ASCII characters are treated specially. It became dramatically faster.

## 2015-02-13
  * ble-edit.sh (keymap emacs): Give emacs name to default keymap.
  * ble-edit.sh (accept-line.exec): bugfix, unable to exit from recursive call loop in C-c.
    Organize and reimplement around exec so that you can escape from recursive calls using trap DEBUG.
  * ble-edit.sh: Change option names, organize each option, and add explanations.
  * ble-edit.sh (.ble-edit/gexec): A mechanism to execute commands in a global context.
    Also supports C-c for recursive calls. You can now switch the execution method with bleopt_exec_type.
    exec is the old way and gexec is this new way.

## 2015-02-12
  * ble-decode.sh: bugfix, fixed stty broken after exit
    Along with this, we also implemented ble's detach function.
  * ble-decode.sh: bugfix, bash-4.3 doesn't listen to sequences of three or more characters.
    Since I was getting an error that the keymap could not be found, I decided to bind -x for all sequences.
  * ble-core.sh: bugfix, command printf fallback does not work in environments where builtin printf \U.... cannot be used.
    Fixed printf path. Also changed to not use printf for ASCII.
  * ble-color.sh (ble-syntax-highlight+default):
    Additions and corrections. Also, implement inversion of the selection range as ble-syntax-highlight+region and call it.
  * ble.pp: Check whether it is in interactive mode at startup.

## 2015-02-11
  * ble-edit.sh (_ble_edit_io_*): Decided to switch stdout/stderr to suppress flickering.
    The reason it flickers is because bash's default output clears the ble display and displays what bash wants to display.
    In response to this, ble overwrites and redraws immediately after bash's output and manages to display it.
    In order to suppress the default output of bash, I decided to switch the output destination using exec.
    Directs bash output to be written to a file. Check the output file one by one,
    If an error is output, I decided to display it with visible-bell.
    Experimentally use this new method when `bleopt_suppress_bash_output=1`.
    When `bleopt_suppress_bash_output=`, the traditional flickering method.

## 2015-02-10
  * ble-edit.sh (accept-line.exec): Now you can define global variables from inside in bash-4.3
    Changed to override declare and typeset and specify -g option.
    Also, notes related to this are written in ble.htm.
  * ble-edit.sh (history): Optimized because it takes time to load.
  * General: bugfix, pathname expansion is dangerous if GLOBIGNORE='*' is not set in string splitting
  * ble-color.sh (ble-syntax-highlight+default): Better coloring.
  * ble-edit.sh (accept-line.exec): Change execution context of command bound with ble-bind -cf.
    Executes in the same context as accept-line.
  * ble-edit.sh (keymap default): Bind C-z M-z to fg.

## 2015-02-09
  * git repos
  * ble-edit: bugfix, locate-xword macro was not expanded
  * ble-decode: Various changes to support bash-4.3
    - Sort out cases of bind specification
    - all bind for bugfix, ESC ?, ESC [ ?
    - bugfix, in some cases bind -r doesn't work at all
      →It seems that "bind -sp | fgrep" sometimes results in "binary".
        Specify -a for fgrep.
    - bugfix, Japanese cannot be input. 8bit characters are not recognized.
      →Change 8bit characters to be specified in bind using an escape sequence.

## 2013-06-12
  * ble-edit: history-beginning, history-end, accept-and-next

## 2013-06-12
  * ble-edit:
    kill-forward-fword, kill-backward-fword, kill-fword,
    copy-forward-fword, copy-backward-fword, copy-fword,
    delete-forward-fword, delete-backward-fword, delete-fword,
    forward-fword, backward-fword
  * ble-edit: history-expand-line, display-shell-version

## 2013-06-10
  * ble-edit:
    kill-forward-uword, kill-backward-uword, kill-uword, kill-region-or-uword,
    copy-forward-uword, copy-backward-uword, copy-uword, copy-region-or-uword,
    forward-uword, backward-uword

  * ble-edit:
    delete-forward-uword, delete-backward-uword, delete-uword, delete-region-or-uword,
    delete-forward-sword, delete-backward-sword, delete-sword, delete-region-or-sword,
    delete-forward-cword, delete-backward-cword, delete-cword, delete-region-or-cword

  * ble-edit:
    The following editing functions have been deprecated:
      delete-region-or-uword, kill-region-or-uword, copy-region-or-uword,
      delete-region-or-sword, kill-region-or-sword, copy-region-or-sword,
      delete-region-or-cword, kill-region-or-cword, copy-region-or-cword.
    Use the following editing functions instead:
      delete-region-or type, kill-region-or type, copy-region-or type.

## 2013-06-09
  * ble-edit: kill-region, copy-region
  * ble-edit:
    kill-forward-sword, kill-backward-sword, kill-sword, kill-region-or-sword,
    copy-forward-sword, copy-backward-sword, copy-sword, copy-region-or-sword
  * ble-edit:
    kill-forward-cword, kill-backward-cword, kill-cword, kill-region-or-cword,
    copy-forward-cword, copy-backward-cword, copy-cword, copy-region-or-cword
  * ble-edit: forward-sword, backward-sword, forward-cword, backward-cword

## 2013-06-06
  * ble-edit-bind: All characters/keys can be input.
  * complete: Display candidate list (simple version)
  * ble-color.sh: Ported coloring functionality from highlight.sh

## 2013-06-05
  * ble-edit: history-isearch-backward, history-isearch-forward,
    isearch/self-insert,
    isearch/next, isearch/forward, isearch/backward,
    isearch/exit, isearch/cancel, isearch/default,
    isearch/prev, isearch/accept
  * ble-edit: yank
  * You can now display what has been bound so far with ble-bind -d.
  * ble-edit: complete, just file name completion for now
  * ble-edit: command-help

## 2013-06-04
  * ble-edit: discard-line, accept-line
  * ble-edit: history-prev, history-next
  * ble-edit: set-mark, kill-line, kill-backward-line, exchange-point-and-mark
  * ble-edit: clear-screen
  * ble-edit: transpose-chars
  * ble-edit: insert-string

## 2013-06-03
  * ble-edit: bell, self-insert, redraw-line,
  * ble-edit: delete-char, delete-backward-char, delete-char-or-exit,
    delete-forward-backward-char
  * ble-edit: forward-char, backward-char, end-of-line, beginning-of-line
  * ble-edit: quoted-insert
  * ble.sh: Completed to the point where you can easily input strings

## 2013-06-02
  * ble-getopt.sh: bugfixes
  * ble-getopt.sh: Changed to unset OPTARGS upon successful completion.
  * ble-decode-kbd, ble-decode-unkbd

## 2013-05-31
  * ble-getopt.sh: created
  * ble-decode: The outline is complete

## 2013-05-30
  * highlight.sh: Simple coloring
  * ble.sh:

    -- background --
    With the policy of highlight.sh, it is not possible to erase the content being edited that is displayed by bash,
    The cursor position also points to what bash is displaying.
    Items displayed in color are displayed below the items displayed by bash.
    There's only one way.

    Also, since the readline function cannot be called from a script,
    In the end, I changed the behavior of READLINE_LINE and READLINE_POINT when I wanted to update the coloring.
    Everything has to be imitated and reproduced on the script side.
    The bash specifications for READLINE_LINE and READLINE_POINT are strange, so Japanese etc.
    You have to do a lot of dirty things to get it working properly with multibyte.

    From the above, from operations such as editing strings to executing scripts,
    I decided to implement everything myself and overwrite all the bash readline functions.
    To do this, we will have to rewrite the script. ble (bash line editor) imitating zle
    Name it.

    -- As a policy --
    a. Use read -n 1 to extract characters from standard input one by one and process them.
    b. Connect ble's byte receiving function to all characters with bash's bind,
       Process bytes as they are received.

    As an extension of highlight.sh, I decided on policy b.
    Perhaps policy a. is also possible.

## 2013-05-29
  * highlight.sh: Create
