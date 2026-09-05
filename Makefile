PREFIX ?= /usr/local
CC ?= clang
CFLAGS ?= -O2
CFLAGS += -Wall -Wextra -Wpedantic

all: dmenu-mac dmenu-mac_path

dmenu-mac: dmenu-mac.m
	$(CC) $(CFLAGS) -fobjc-arc -framework AppKit -o $@ $<

dmenu-mac_path: dmenu-mac_path.c
	$(CC) $(CFLAGS) -std=c99 -D_DARWIN_C_SOURCE -o $@ $<

install: all
	install -d "$(DESTDIR)$(PREFIX)/bin"
	install -m 755 dmenu-mac dmenu-mac_path dmenu-mac_run "$(DESTDIR)$(PREFIX)/bin"
	install -d "$(DESTDIR)$(PREFIX)/share/man/man1"
	install -m 644 dmenu-mac.1 "$(DESTDIR)$(PREFIX)/share/man/man1"

uninstall:
	rm -f "$(DESTDIR)$(PREFIX)/bin/dmenu-mac" \
		"$(DESTDIR)$(PREFIX)/bin/dmenu-mac_path" \
		"$(DESTDIR)$(PREFIX)/bin/dmenu-mac_run" \
		"$(DESTDIR)$(PREFIX)/share/man/man1/dmenu-mac.1"

clean:
	rm -f dmenu-mac dmenu-mac_path

.PHONY: all install uninstall clean
