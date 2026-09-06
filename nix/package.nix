{
  stdenv,
  ...
}:

stdenv.mkDerivation {
  pname = "dmenu-mac";
  version = "0.1.0";

  src = ../.;

  installPhase = ''
    mkdir -p $out/bin
    install -m755 build/dmenu-mac build/dmenu-mac_path dmenu-mac_run "$out/bin"
  '';
}
