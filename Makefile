PREFIX ?= /usr/local
CC ?= clang
CFLAGS ?= -O2 -Wall -Wextra

BUILD = build
BINDIR = $(DESTDIR)$(PREFIX)/bin
MANDIR = $(DESTDIR)$(PREFIX)/share/man/man1

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
	install -d "$(BINDIR)"
	install -m 755 $(BUILD)/dmenu-mac $(BUILD)/dmenu-mac_path dmenu-mac_run "$(BINDIR)"
	install -d "$(MANDIR)"
	install -m 644 dmenu-mac.1 "$(MANDIR)"

uninstall:
	rm -f "$(BINDIR)/dmenu-mac" \
		"$(BINDIR)/dmenu-mac_path" \
		"$(BINDIR)/dmenu-mac_run" \
		"$(MANDIR)/dmenu-mac.1"

clean:
	rm -rf $(BUILD)

.PHONY: all install uninstall clean
