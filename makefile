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

APP=closha
PREFIX ?= usr
OBJDIR ?= ../.b

#}}}
#{{{ Commands

install: ##Copy it into a location for runnable binaries
/ mkdir -p $(DESTDIR)/$(PREFIX)/bin
/ install -m 755 -D ./$(APP) $(DESTDIR)/$(PREFIX)/bin/$(APP)
/ install -m 644 -D package/$(APP).svg \
   $(DESTDIR)/$(PREFIX)/share/icons/hicolor/scalable/apps/$(APP).svg
/ install -m 644 -D package/$(APP)32x32.png \
   $(DESTDIR)/$(PREFIX)/share/icons/hicolor/32x32/apps/$(APP).png
/ install -m 644 -D package/$(APP).desktop \
   $(DESTDIR)/$(PREFIX)/share/applications/$(APP).desktop

uninstall: ##Uninstall the program
/ /usr/bin/rm $(DESTDIR)/$(PREFIX)/bin/$(APP)
/ /usr/bin/rm $(DESTDIR)/$(PREFIX)/share/icons/hicolor/scalable/apps/$(APP).svg
/ /usr/bin/rm $(DESTDIR)/$(PREFIX)/share/icons/hicolor/32x32/apps/$(APP).png
/ /usr/bin/rm $(DESTDIR)/$(PREFIX)/share/applications/$(APP).desktop


package: ##Create a package for Arch Linux by building a specific version
/ package/package.sh $(APP) $(OBJDIR) $(VERSION)

#}}}
