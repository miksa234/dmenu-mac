# dmenu-mac - dynamic menu

dmenu-mac is a small native dynamic menu for macOS.

## Requirements

- macOS
- Xcode Command Line Tools

## Installation

```sh
make
sudo make install
```

## Running dmenu-mac

Run it as a command launcher:

```sh
dmenu-mac_run -p "Run:"
```

Or provide newline-separated items directly:

```sh
printf 'one\ntwo\nthree\n' | dmenu-mac -i -l 3
```

See `dmenu-mac(1)` for options and keybindings.
