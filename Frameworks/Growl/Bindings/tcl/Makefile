MKDIR = /bin/mkdir -p -m 0755
RM = /bin/rm -f
RMDIR = /bin/rm -fr
INSTALL = /usr/bin/install -m 0644
TCLSH = /usr/bin/tclsh

DESTDIR =
PREFIX = /Library/Tcl/growl1.0

OBJS = GrowlApplicationBridge.o TclGrowler.o growl.o
TARGET = libgrowl.dylib

CC = gcc
CFLAGS = -Wall -DUSE_TCL_STUBS
FRAMEWORKS = -framework Cocoa -framework Tcl -ltclstub8.4
LDFLAGS = -dynamiclib -install_name $(PREFIX)/$(TARGET)

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) $(LDFLAGS) $(FRAMEWORKS) $(OBJS) -o $@

clean:
	$(RM) $(OBJS) $(TARGET)

install: all
	$(MKDIR) "$(DESTDIR)$(PREFIX)"
	$(INSTALL) "$(TARGET)" "$(DESTDIR)$(PREFIX)"
	echo pkg_mkIndex "$(DESTDIR)$(PREFIX)" | $(TCLSH)

uninstall:
	$(RMDIR) "$(DESTDIR)$(PREFIX)"
