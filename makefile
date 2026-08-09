#{{{ Boilerplate

.RECIPEPREFIX = /
.DEFAULT_GOAL = all

ifndef VERBOSE
.SILENT: # Silent mode unless you run it like "make all VERBOSE=1"
endif


help: ## Show this help
/ @grep -E -h '\s##\s' $(MAKEFILE_LIST) | sort | awk 'BEGIN {print "[Help]";print ""; FS = ":.*?## "}; {printf "\033[32m%-10s\033[0m %s\n", $$1, $$2}'
/ echo
# MAKEFILE_LIST lists the contents of this present file
# egrep selects only lines with the double sharp, they are then sorted
# BEGIN in AWK means an action to be executed once before the linewise
# FS means "field separator" - the separator between parts of a single line
# the printf looks so scary because of the ASCII color codes

#}}}
#{{{ Params

.PHONY: all library debug clean help test tarball package

CC ?= gcc --std=c2x
LDFLAGS ?= -Wl,--exclude-libs=ALL

BIN ?= ../bin
OBJDIR ?= ../.b

APP=closha.sh


#}}}
#{{{ Commands

$(BIN):
/ mkdir -p $(BIN)

$(OBJDIR)/$(APP):
/ mkdir -p $(OBJDIR)/$(APP)

all: | $(BIN) ##Build the program
/ clear
/ $(COMPILE) -o $(BIN)/$(APP) $(APP).c 
/ @echo "_________________________________________"
/ @echo "|            BUILD SUCCESS              |"
/ @echo "========================================="


dist: | $(OBJDIR)/$(APP) ##Create a tarball with the source code
/ tar --exclude .git -c closha.sh makefile -f $(OBJDIR)/$(APP)/$(APP).tar.gz

install: ##Copy it into a location for runnable binaries
/ mkdir -p $(DESTDIR)/$(PREFIX)/bin
/ install -D ./$(APP) $(DESTDIR)/$(PREFIX)/bin/$(APP)


package: ##Create a package for Arch linux by building a specific version
/ builddeps/package.sh projector $(VERSION) $(OBJDIR)

#}}}
