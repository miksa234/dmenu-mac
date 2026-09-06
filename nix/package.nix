{
  stdenv,
  makeWrapper,
  ...
}:

stdenv.mkDerivation {
  pname = "dmenu-mac";
  version = "0.1.0";

  src = ../.;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin
    install -m755 dmenu-mac $out/bin/dmenu-mac
    install -m755 dmenu-mac_path $out/bin/dmenu-mac_path
    install -m755 dmenu-mac_run $out/bin/dmenu-mac_run-unwrapped
    makeWrapper $out/bin/dmenu-mac_run-unwrapped $out/bin/dmenu-mac_run \
      --prefix PATH : $out/bin
  '';
}
