# -*- mode: makefile-gmake -*-

all:
.PHONY: all

# git version
GIT_VERSION = $(shell LANG=C git --version)

# check GNU Make
ifeq ($(.FEATURES),)
  $(error Sorry, please use a newer version (3.81 or later) of gmake (GNU Make).)
endif
MAKE_VERSION := $(shell LANG=C $(MAKE) --version | head -1)

# check gawk
GAWK := $(shell which gawk 2>/dev/null || bash -c 'builtin type -P gawk' 2>/dev/null)
ifneq ($(GAWK),)
  GAWK_VERSION := $(shell LANG=C $(GAWK) --version 2>/dev/null | sed -n '1{/[Gg][Nn][Uu] [Aa][Ww][Kk]/p;}')
  ifeq ($(GAWK_VERSION),)
    $(error Sorry, gawk is found but does not seem to work. Please install a proper version of gawk (GNU Awk).)
  endif
else
  GAWK := $(shell which awk 2>/dev/null || bash -c 'builtin type -P awk' 2>/dev/null)
  ifeq ($(GAWK),)
    $(error Sorry, gawk/awk could not be found. Please check your PATH environment variable.)
  endif
  GAWK_VERSION := $(shell LANG=C $(GAWK) --version 2>/dev/null | sed -n '1{/[Gg][Nn][Uu] [Aa][Ww][Kk]/p;}')
  ifeq ($(GAWK_VERSION),)
    $(error Sorry, gawk could not be found. Please install gawk (GNU Awk).)
  endif
endif

MWGPP := $(GAWK) -f make/mwg_pp.awk

# Note (#D2058): we had used "cp -p xxx out/xxx" to copy files to the build
# directory, but some filesystem (ecryptfs) has a bug that the subsecond
# timestamps are truncated causing an issue: make every time copies all the
# files into the subdirectory `out`.  We give up using `cp -p` and instead copy
# the file with `cp` with the timestamps being the copy time.
CP := cp

#------------------------------------------------------------------------------
# ble.sh

FULLVER := 0.4.0-devel4

BLE_GIT_COMMIT_ID :=
BLE_GIT_BRANCH :=
ifneq ($(wildcard .git),)
  BLE_GIT_COMMIT_ID := $(shell git show -s --format=%h)
  BLE_GIT_BRANCH := $(shell git rev-parse --abbrev-ref HEAD)
else ifneq ($(wildcard make/.git-archive-export.mk),)
  ifeq ($(shell grep '\$$Format:.*\$$' make/.git-archive-export.mk),)
    include make/.git-archive-export.mk
  endif
endif
ifeq ($(BLE_GIT_COMMIT_ID),)
  $(error Failed to determine the commit id of the current tree.  The .git directory is required to build ble.sh.)
endif

OUTDIR:=out

outdirs += $(OUTDIR)

outfiles+=$(OUTDIR)/ble.sh
-include $(OUTDIR)/ble.dep
# Note: ble.sh depends on lib/@init/init-cmap.bash and lib/@init/init-bind.bash
# because it contains the hash of these files for the cache.
$(OUTDIR)/ble.sh: ble.pp GNUmakefile lib/@init/init-cmap.bash lib/@init/init-bind.bash | $(OUTDIR)
	DEPENDENCIES_PHONY=1 DEPENDENCIES_OUTPUT="$(@:%.sh=%.dep)" DEPENDENCIES_TARGET="$@" \
	  FULLVER=$(FULLVER) \
	  BLE_GIT_COMMIT_ID="$(BLE_GIT_COMMIT_ID)" \
	  BLE_GIT_BRANCH="$(BLE_GIT_BRANCH)" \
	  BUILD_GIT_VERSION="$(GIT_VERSION)" \
	  BUILD_MAKE_VERSION="$(MAKE_VERSION)" \
	  BUILD_GAWK_VERSION="$(GAWK_VERSION)" \
	  $(MWGPP) $< >/dev/null
.DELETE_ON_ERROR: $(OUTDIR)/ble.sh

GENTABLE := bash make/canvas.c2w.generate-table.sh

src/@canvas/canvas.c2w.bash:
	$(GENTABLE) c2w
src/@canvas/canvas.c2w.musl.bash: make/canvas.c2w.wcwidth.cpp make/canvas.c2w.wcwidth-musl.cpp
	+make -C make canvas.c2w.wcwidth.exe
	make/canvas.c2w.wcwidth.exe table_musl2014 | $(GENTABLE) convert-custom-c2w _ble_util_c2w_musl > $@
src/@canvas/canvas.emoji.bash:
	$(GENTABLE) emoji
src/@canvas/canvas.GraphemeClusterBreak.bash:
	$(GENTABLE) GraphemeClusterBreak

# Note: the following line is a workaround for the missing
#   DEPENDENCIES_PHONY option for mwg_pp in older Makefile
ble-form.sh:

#------------------------------------------------------------------------------
# lib

outdirs += $(OUTDIR)/lib
outdirs += $(OUTDIR)/lib/@benchmark
outdirs += $(OUTDIR)/lib/@core
outdirs += $(OUTDIR)/lib/@init
outdirs += $(OUTDIR)/lib/@keymap
outdirs += $(OUTDIR)/lib/@test
outdirs += $(OUTDIR)/lib/@util
outdirs += $(OUTDIR)/lib/@vim

# keymap
outfiles += $(OUTDIR)/lib/keymap.emacs.sh
outfiles += $(OUTDIR)/lib/keymap.vi.sh
outfiles += $(OUTDIR)/lib/keymap.vi_digraph.sh
outfiles += $(OUTDIR)/lib/keymap.vi_digraph.txt

# init
outfiles += $(OUTDIR)/lib/init-term.sh
outfiles += $(OUTDIR)/lib/init-bind.sh
outfiles += $(OUTDIR)/lib/init-cmap.sh
outfiles += $(OUTDIR)/lib/init-msys1.sh

# core
outfiles += $(OUTDIR)/lib/core-complete.sh
outfiles += $(OUTDIR)/lib/core-syntax.sh
outfiles += $(OUTDIR)/lib/core-test.sh
outfiles += $(OUTDIR)/lib/core-cmdspec.sh
outfiles += $(OUTDIR)/lib/core-debug.sh
outfiles += $(OUTDIR)/lib/core-edit.ignoreeof-messages.txt
outfiles += $(OUTDIR)/lib/core-decode.emacs-rlfunc.txt
outfiles += $(OUTDIR)/lib/core-decode.vi_imap-rlfunc.txt
outfiles += $(OUTDIR)/lib/core-decode.vi_nmap-rlfunc.txt

# vim
outfiles += $(OUTDIR)/lib/vim-surround.sh
outfiles += $(OUTDIR)/lib/vim-arpeggio.sh
outfiles += $(OUTDIR)/lib/vim-airline.sh

# lib
outfiles += $(OUTDIR)/lib/util.bgproc.sh

# test
outfiles += $(OUTDIR)/lib/test-bash.sh
outfiles += $(OUTDIR)/lib/test-main.sh
outfiles += $(OUTDIR)/lib/test-util.sh
outfiles += $(OUTDIR)/lib/test-canvas.sh
outfiles += $(OUTDIR)/lib/test-decode.sh
outfiles += $(OUTDIR)/lib/test-edit.sh
outfiles += $(OUTDIR)/lib/test-syntax.sh
outfiles += $(OUTDIR)/lib/test-complete.sh
outfiles += $(OUTDIR)/lib/test-keymap.vi.sh

outfiles += $(OUTDIR)/lib/@keymap/keymap.emacs.bash
outfiles += $(OUTDIR)/lib/@keymap/keymap.vi.bash
outfiles += $(OUTDIR)/lib/@keymap/keymap.vi_digraph.bash
outfiles += $(OUTDIR)/lib/@keymap/keymap.vi_digraph.txt

outfiles += $(OUTDIR)/lib/@init/init-term.bash
outfiles += $(OUTDIR)/lib/@init/init-bind.bash
outfiles += $(OUTDIR)/lib/@init/init-cmap.bash
outfiles += $(OUTDIR)/lib/@init/init-msys1.bash
outfiles += $(OUTDIR)/lib/@init/init-msleep.bash
outfiles += $(OUTDIR)/lib/@init/init-msleep.c

outfiles += $(OUTDIR)/lib/@core/core-complete.bash
outfiles += $(OUTDIR)/lib/@core/core-syntax.bash
outfiles += $(OUTDIR)/lib/@core/core-test.bash
outfiles += $(OUTDIR)/lib/@core/core-cmdspec.bash
outfiles += $(OUTDIR)/lib/@core/core-debug.bash
outfiles += $(OUTDIR)/lib/@core/core-edit.ignoreeof-messages.txt
outfiles += $(OUTDIR)/lib/@core/core-decode.emacs-rlfunc.txt
outfiles += $(OUTDIR)/lib/@core/core-decode.vi_imap-rlfunc.txt
outfiles += $(OUTDIR)/lib/@core/core-decode.vi_nmap-rlfunc.txt

outfiles += $(OUTDIR)/lib/@vim/vim-surround.bash
outfiles += $(OUTDIR)/lib/@vim/vim-arpeggio.bash
outfiles += $(OUTDIR)/lib/@vim/vim-airline.bash

outfiles += $(OUTDIR)/lib/@util/util.bgproc.bash

outfiles += $(OUTDIR)/lib/@test/test-bash.bash
outfiles += $(OUTDIR)/lib/@test/test-main.bash
outfiles += $(OUTDIR)/lib/@test/test-util.bash
outfiles += $(OUTDIR)/lib/@test/test-canvas.bash
outfiles += $(OUTDIR)/lib/@test/test-canvas.GraphemeClusterTest.bash
outfiles += $(OUTDIR)/lib/@test/test-decode.bash
outfiles += $(OUTDIR)/lib/@test/test-edit.bash
outfiles += $(OUTDIR)/lib/@test/test-syntax.bash
outfiles += $(OUTDIR)/lib/@test/test-complete.bash
outfiles += $(OUTDIR)/lib/@test/test-keymap.vi.bash

outfiles += $(OUTDIR)/lib/@benchmark/benchmark.ksh

$(OUTDIR)/lib/keymap.emacs.sh: lib/@keymap/keymap.emacs.bash | $(OUTDIR)/lib
	$(CP) $< $@
$(OUTDIR)/lib/keymap.vi.sh: lib/@keymap/keymap.vi.bash | $(OUTDIR)/lib
	$(CP) $< $@
$(OUTDIR)/lib/keymap.vi_digraph.sh: lib/@keymap/keymap.vi_digraph.bash | $(OUTDIR)/lib
	$(CP) $< $@
$(OUTDIR)/lib/keymap.vi_digraph.txt: lib/@keymap/keymap.vi_digraph.txt | $(OUTDIR)/lib
	$(CP) $< $@

$(OUTDIR)/lib/init-term.sh: lib/@init/init-term.bash | $(OUTDIR)/lib
	$(CP) $< $@
$(OUTDIR)/lib/init-msys1.sh: lib/@init/init-msys1.bash lib/@init/init-msys1-helper.c | $(OUTDIR)/lib
	$(MWGPP) $< > $@
$(OUTDIR)/lib/init-cmap.sh: lib/@init/init-cmap.bash | $(OUTDIR)/lib
	$(MWGPP) $< > $@
$(OUTDIR)/lib/init-bind.sh: lib/@init/init-bind.bash | $(OUTDIR)/lib
	$(MWGPP) $< > $@

$(OUTDIR)/lib/core-complete.sh: lib/@core/core-complete.bash | $(OUTDIR)/lib
	$(CP) $< $@
$(OUTDIR)/lib/core-syntax.sh: lib/@core/core-syntax.bash lib/@core/core-syntax-ctx.def | $(OUTDIR)/lib
	$(MWGPP) $< > $@
$(OUTDIR)/lib/core-test.sh: lib/@core/core-test.bash | $(OUTDIR)/lib
	$(CP) $< $@
$(OUTDIR)/lib/core-cmdspec.sh: lib/@core/core-cmdspec.bash | $(OUTDIR)/lib
	$(CP) $< $@
$(OUTDIR)/lib/core-debug.sh: lib/@core/core-debug.bash | $(OUTDIR)/lib
	$(CP) $< $@
$(OUTDIR)/lib/core-edit.ignoreeof-messages.txt: lib/@core/core-edit.ignoreeof-messages.txt | $(OUTDIR)/lib
	$(CP) $< $@
$(OUTDIR)/lib/core-decode.emacs-rlfunc.txt: lib/@core/core-decode.emacs-rlfunc.txt | $(OUTDIR)/lib
	$(CP) $< $@
$(OUTDIR)/lib/core-decode.vi_imap-rlfunc.txt: lib/@core/core-decode.vi_imap-rlfunc.txt | $(OUTDIR)/lib
	$(CP) $< $@
$(OUTDIR)/lib/core-decode.vi_nmap-rlfunc.txt: lib/@core/core-decode.vi_nmap-rlfunc.txt | $(OUTDIR)/lib
	$(CP) $< $@

$(OUTDIR)/lib/vim-surround.sh: lib/@vim/vim-surround.bash | $(OUTDIR)/lib
	$(CP) $< $@
$(OUTDIR)/lib/vim-arpeggio.sh: lib/@vim/vim-arpeggio.bash | $(OUTDIR)/lib
	$(CP) $< $@
$(OUTDIR)/lib/vim-airline.sh: lib/@vim/vim-airline.bash | $(OUTDIR)/lib
	$(CP) $< $@

$(OUTDIR)/lib/util.bgproc.sh: lib/@util/util.bgproc.bash | $(OUTDIR)/lib
	$(CP) $< $@

$(OUTDIR)/lib/test-bash.sh: lib/@test/test-bash.bash | $(OUTDIR)/lib
	$(CP) $< $@
$(OUTDIR)/lib/test-main.sh: lib/@test/test-main.bash | $(OUTDIR)/lib
	$(CP) $< $@
$(OUTDIR)/lib/test-util.sh: lib/@test/test-util.bash | $(OUTDIR)/lib
	$(CP) $< $@
$(OUTDIR)/lib/test-canvas.sh: lib/@test/test-canvas.bash lib/@test/test-canvas.GraphemeClusterTest.bash | $(OUTDIR)/lib
	$(MWGPP) $< > $@
$(OUTDIR)/lib/test-decode.sh: lib/@test/test-decode.bash | $(OUTDIR)/lib
	$(CP) $< $@
$(OUTDIR)/lib/test-edit.sh: lib/@test/test-edit.bash | $(OUTDIR)/lib
	$(CP) $< $@
$(OUTDIR)/lib/test-syntax.sh: lib/@test/test-syntax.bash | $(OUTDIR)/lib
	$(CP) $< $@
$(OUTDIR)/lib/test-complete.sh: lib/@test/test-complete.bash | $(OUTDIR)/lib
	$(CP) $< $@
$(OUTDIR)/lib/test-keymap.vi.sh: lib/@test/test-keymap.vi.bash | $(OUTDIR)/lib
	$(CP) $< $@

$(OUTDIR)/lib/@%.bash: lib/@%.bash | $(OUTDIR)/lib $(OUTDIR)/lib/@benchmark $(OUTDIR)/lib/@core $(OUTDIR)/lib/@init $(OUTDIR)/lib/@keymap $(OUTDIR)/lib/@test $(OUTDIR)/lib/@util $(OUTDIR)/lib/@vim
	$(CP) $< $@
$(OUTDIR)/lib/@%.txt: lib/@%.txt | $(OUTDIR)/lib $(OUTDIR)/lib/@benchmark $(OUTDIR)/lib/@core $(OUTDIR)/lib/@init $(OUTDIR)/lib/@keymap $(OUTDIR)/lib/@test $(OUTDIR)/lib/@util $(OUTDIR)/lib/@vim
	$(CP) $< $@
$(OUTDIR)/lib/@%.c: lib/@%.c | $(OUTDIR)/lib $(OUTDIR)/lib/@benchmark $(OUTDIR)/lib/@core $(OUTDIR)/lib/@init $(OUTDIR)/lib/@keymap $(OUTDIR)/lib/@test $(OUTDIR)/lib/@util $(OUTDIR)/lib/@vim
	$(CP) $< $@
$(OUTDIR)/lib/@benchmark/benchmark.ksh: lib/@benchmark/benchmark.ksh | $(OUTDIR)/lib/@benchmark
	$(CP) $< $@

$(OUTDIR)/lib/@core/core-syntax.bash: lib/@core/core-syntax.bash lib/@core/core-syntax-ctx.def | $(OUTDIR)/lib/@core
	$(MWGPP) $< > $@
$(OUTDIR)/lib/@init/init-msys1.bash: lib/@init/init-msys1.bash lib/@init/init-msys1-helper.c | $(OUTDIR)/lib/@init
	$(MWGPP) $< > $@
$(OUTDIR)/lib/@init/init-cmap.bash: lib/@init/init-cmap.bash | $(OUTDIR)/lib/@init
	$(MWGPP) $< > $@
$(OUTDIR)/lib/@init/init-bind.bash: lib/@init/init-bind.bash | $(OUTDIR)/lib/@init
	$(MWGPP) $< > $@
$(OUTDIR)/lib/@test/test-canvas.bash: lib/@test/test-canvas.bash lib/@test/test-canvas.GraphemeClusterTest.bash | $(OUTDIR)/lib/@test
	$(MWGPP) $< > $@

outfiles += $(OUTDIR)/lib/benchmark.ksh
$(OUTDIR)/lib/benchmark.ksh: lib/@benchmark/benchmark.ksh src/@benchmark/benchmark.bash | $(OUTDIR)/lib
	$(MWGPP) $< > $@

#outfiles += $(OUTDIR)/lib/init-msleep.sh
#$(OUTDIR)/lib/init-msleep.sh: lib/@init/init-msleep.bash lib/@init/init-msleep.c | $(OUTDIR)/lib
#	$(MWGPP) $< > $@

# I'll delete it someday
removedfiles += \
  keymap/emacs.rlfunc.txt \
  keymap/emacs.sh \
  keymap/isearch.sh \
  keymap/vi.sh \
  keymap/vi_digraph.sh \
  keymap/vi_digraph.txt \
  keymap/vi_imap.rlfunc.txt \
  keymap/vi_nmap.rlfunc.txt \
  keymap/vi_test.sh \
  lib/keymap.vi_test.sh

#------------------------------------------------------------------------------
# licenses and documents

outdirs += $(OUTDIR)/licenses $(OUTDIR)/doc
outfiles-license += $(OUTDIR)/licenses/LICENSE.md
ifneq ($(USE_DOC),no)
  outfiles-doc += $(OUTDIR)/doc/README.md
  outfiles-doc += $(OUTDIR)/doc/README-ja_JP.md
  outfiles-doc += $(OUTDIR)/doc/CONTRIBUTING.md
  outfiles-doc += $(OUTDIR)/doc/ChangeLog.md
  outfiles-doc += $(OUTDIR)/doc/Release.md
endif

# Workaround for make-3.81 (#D2065)
#
# We want to do something like the following:
#
#   $(OUTDIR)/license/%.md: %.md | $(OUTDIR)/license
#   	$(CP) $< $@
#   $(OUTDIR)/doc/%.md: %.md | $(OUTDIR)/doc
#   	$(CP) $< $@
#
# However, because of a bug in make-3.81, this rule overrides all the other
# more detailed patterns such as $(OUTDIR)/doc/contrib/%.md.  As a result, even
# when we want to apply preprocessing to specific file patterns under
# $(OUTDIR)/doc/%, $(CP) is always used to install the files.  To work around
# this problem in make-3.81, we need to manually filter the target files whose
# source files are at the top level in the source tree.
#
outfiles-doc-toplevel := \
  $(filter $(outfiles-doc),$(patsubst %,$(OUTDIR)/doc/%,$(wildcard *.md)))
$(outfiles-doc-toplevel): $(OUTDIR)/doc/%.md: %.md | $(OUTDIR)/doc
	$(CP) $< $@
outfiles-license-toplevel := \
  $(filter $(outfiles-license),$(patsubst %,$(OUTDIR)/licenses/%,$(wildcard *.md)))
$(outfiles-license-toplevel): $(OUTDIR)/licenses/%.md: %.md | $(OUTDIR)/licenses
	$(CP) $< $@

$(OUTDIR)/doc/%: docs/% | $(OUTDIR)/doc
	$(CP) $< $@

#------------------------------------------------------------------------------
# contrib

# contrib is vendored in-tree (English-converted; no git submodule, no
# re-fetch).  contrib/contrib.mk must exist in the working tree and is built
# locally from the in-tree sources.  If it is missing, fail loudly -- do NOT
# re-download upstream, which would overwrite the English-converted sources with
# the original Japanese ones.
contrib/contrib.mk:
	@printf '%s\n' \
	  'ERROR: contrib/contrib.mk is missing.' \
	  'The contrib component is vendored in-tree and English-converted.' \
	  'Restore contrib/ from your own source -- do not re-fetch upstream.' >&2; \
	exit 1

include contrib/contrib.mk

#------------------------------------------------------------------------------
# target "all"

$(outdirs):
	mkdir -p $@

build: contrib/contrib.mk $(outfiles) $(outfiles-doc) $(outfiles-license)
.PHONY: build

all: build

#------------------------------------------------------------------------------
# target "install"

# Users can specify make variables INSDIR, INSDIR_LICENSE, and INSDIR_DOC to
# control the install locations.  Instead of INSDIR, users may specify DESTDIR
# and/or PREFIX to automatically set up these variables.

ifneq ($(INSDIR),)
  INSDIR_LICENSE := $(INSDIR)/licenses
  INSDIR_DOC     := $(INSDIR)/doc
else
  ifneq ($(DESTDIR),)
    DATADIR := $(abspath $(DESTDIR)/$(PREFIX)/share)
  else ifneq ($(PREFIX),)
    DATADIR := $(abspath $(PREFIX)/share)
  else ifneq ($(XDG_DATA_HOME),)
    DATADIR := $(abspath $(XDG_DATA_HOME))
  else
    DATADIR := $(abspath $(HOME)/.local/share)
  endif

  INSDIR         := $(DATADIR)/blesh
  INSDIR_LICENSE := $(DATADIR)/blesh/licenses
  INSDIR_DOC     := $(DATADIR)/doc/blesh
endif

ifneq ($(strip_comment),)
  opt_strip_comment := --strip-comment=$(strip_comment)
else
  opt_strip_comment :=
endif

insfiles         := $(outfiles:$(OUTDIR)/%=$(INSDIR)/%)
insfiles-license := $(outfiles-license:$(OUTDIR)/licenses/%=$(INSDIR_LICENSE)/%)
insfiles-doc     := $(outfiles-doc:$(OUTDIR)/doc/%=$(INSDIR_DOC)/%)

install-files := \
  $(insfiles) $(insfiles-license) $(insfiles-doc) \
  $(INSDIR)/cache.d $(INSDIR)/run
install: $(install-files)
uninstall:
	bash make_command.sh uninstall $(install-files)
.PHONY: install uninstall

$(insfiles): $(INSDIR)/%: $(OUTDIR)/%
	bash make_command.sh install $(opt_strip_comment) "$<" "$@"
$(insfiles-license): $(INSDIR_LICENSE)/%: $(OUTDIR)/licenses/%
	bash make_command.sh install "$<" "$@"
$(insfiles-doc): $(INSDIR_DOC)/%: $(OUTDIR)/doc/%
	bash make_command.sh install "$<" "$@"
$(INSDIR)/cache.d $(INSDIR)/run:
	mkdir -p $@ && chmod a+rwxt $@

clean:
	-rm -rf $(outfiles) $(outfiles-doc) $(outfiles-license) $(OUTDIR)/ble.dep
.PHONY: clean

dist: $(outfiles) $(outfiles-doc) $(outfiles-license)
	FULLVER=$(FULLVER) bash make_command.sh dist $^
.PHONY: dist

dist_excludes= \
	--exclude=./ble/backup \
	--exclude=*~ \
	--exclude=./ble/.git \
	--exclude=./ble/out \
	--exclude=./ble/dist \
	--exclude=./ble/ble.sh
dist.date:
	cd .. && tar cavf "$$(date +ble.%Y%m%d.tar.xz)" ./ble $(dist_excludes)
.PHONY: dist.date

#------------------------------------------------------------------------------

define DeclareMakeCommand
$1: $2
	bash make_command.sh $1
.PHONY: $1
endef

$(eval $(call DeclareMakeCommand,ignoreeof-messages,))
$(eval $(call DeclareMakeCommand,scan,))
$(eval $(call DeclareMakeCommand,check,build))
$(eval $(call DeclareMakeCommand,check-all,build))
$(eval $(call DeclareMakeCommand,list-functions,))
