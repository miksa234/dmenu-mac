{
  stdenv,
  ...
}:

stdenv.mkDerivation {
  pname = "dmenu-mac";
  version = "0.1.0";

  src = ../.;

  installPhase = ''
    mkdir -p $out/bin $out/share/man/man1
    install -m755 build/dmenu-mac build/dmenu-mac_path dmenu-mac_run "$out/bin"
    install -m644 dmenu-mac.1 "$out/share/man/man1"
  '';
}
