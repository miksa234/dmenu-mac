{
  description = "dmenu-mac development shell";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";

  outputs = { nixpkgs, ... }:
    let
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          dmenu-mac = pkgs.callPackage ./nix/package.nix { };
        in {
          inherit dmenu-mac;
          default = dmenu-mac;
        });

      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in {
          default = pkgs.mkShell {
            nativeBuildInputs = with pkgs; [ gnumake bear ];

            shellHook = ''
              if ! xcode-select -p >/dev/null 2>&1; then
                echo "warning: Xcode Command Line Tools are not installed"
              fi
            '';
          };
        });
    };
}
