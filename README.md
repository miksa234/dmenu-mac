# dmenu-mac

dmenu-mac is a dmenu for macOS.

## Requirements

- macOS
- Xcode Command Line Tools

## Installation

```sh
make
sudo make install
```

## Running dmenu-mac

Run it as a launcher:

```sh
dmenu-mac_run -p "Run:"
```

Or provide items directly:

```sh
printf 'one\ntwo\nthree\n' | dmenu-mac -i -l 3
```

See `dmenu-mac(1)` for options and keybindings.

## Nix-darwin

Add `dmenu-mac` as a flake input and install it with Home Manager:

```nix
inputs.dmenu-mac.url = "github:miksa234/dmenu-mac";

home.packages = [
  inputs.dmenu-mac.packages.${pkgs.system}.default
];
```

Or install the package directly:

```sh
nix profile install github:miksa234/dmenu-mac
```
