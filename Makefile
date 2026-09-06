PREFIX ?= /usr/local
CC = clang
CFLAGS ?= -O2 -Wall -Wextra

BUILD = build

all: $(BUILD)/dmenu-mac $(BUILD)/dmenu-mac_path

$(BUILD)/config.h: config.def.h
	mkdir -p $(BUILD)
	cp $< $@

$(BUILD)/dmenu-mac: dmenu-mac.m $(BUILD)/config.h
	mkdir -p $(BUILD)
	$(CC) $(CFLAGS) -I$(BUILD) -fobjc-arc -framework AppKit -o $@ $<

$(BUILD)/dmenu-mac_path: dmenu-mac_path.c
	mkdir -p $(BUILD)
	$(CC) $(CFLAGS) -std=c99 -D_DARWIN_C_SOURCE -o $@ $<

install: all
	install -d "$(DESTDIR)$(PREFIX)/bin"
	install -m 755 $(BUILD)/dmenu-mac $(BUILD)/dmenu-mac_path dmenu-mac_run "$(DESTDIR)$(PREFIX)/bin"
	install -d "$(DESTDIR)$(PREFIX)/share/man/man1"
	install -m 644 dmenu-mac.1 "$(DESTDIR)$(PREFIX)/share/man/man1"

uninstall:
	rm -f "$(DESTDIR)$(PREFIX)/bin/dmenu-mac" \
		"$(DESTDIR)$(PREFIX)/bin/dmenu-mac_path" \
		"$(DESTDIR)$(PREFIX)/bin/dmenu-mac_run" \
		"$(DESTDIR)$(PREFIX)/share/man/man1/dmenu-mac.1"

clean:
	rm -rf $(BUILD)

.PHONY: all install uninstall clean
