#{{{ Boilerplate

.RECIPEPREFIX = /
.DEFAULT_GOAL = install

ifndef VERBOSE
.SILENT: # Silent mode unless you run it like "make all VERBOSE=1"
endif


help: ##Show this help
/ @grep -E -h '\s##' $(MAKEFILE_LIST) | sort \
   | awk 'BEGIN {print "[Help]";print ""; FS = ":.*?##"}; {printf "\033[32m%-10s\033[0m %s\n", $$1, $$2}'
/ echo
# MAKEFILE_LIST lists the contents of this present file
# egrep selects only lines with the double sharp, they are then sorted
# BEGIN in AWK means an action to be executed once before the linewise
# FS means "field separator" - the separator between parts of a single line
# the printf looks so scary because of the ASCII color codes

#}}}
#{{{ Params

.PHONY: all install uninstall package help

APP=closha.sh
PREFIX ?= usr
OBJDIR ?= ../.b

#}}}
#{{{ Commands

install: ##Copy it into a location for runnable binaries
/ mkdir -p $(DESTDIR)/$(PREFIX)/bin
/ install -D ./$(APP) $(DESTDIR)/$(PREFIX)/bin/$(APP)

uninstall: ##Uninstall the program
/ /usr/bin/rm $(DESTDIR)/$(PREFIX)/bin/$(APP)


package: ##Create a package for Arch Linux by building a specific version
/ build/package.sh closha $(OBJDIR) $(VERSION)

#}}}
