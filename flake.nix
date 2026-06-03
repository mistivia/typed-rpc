{
    description = "typed-rpc Haskell project";

    inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
        flake-utils.url = "github:numtide/flake-utils";
        flex-record = {
            url = "https://github.com/mistivia/releases/releases/download/flex-record-0.1.1/flex-record-0.1.1.tar.gz";
            inputs.nixpkgs.follows = "nixpkgs";
            inputs.flake-utils.follows = "flake-utils";
        };
    };

    outputs = { self, nixpkgs, flake-utils, flex-record}:
        flake-utils.lib.eachDefaultSystem (system:
        let
            pkgs = nixpkgs.legacyPackages.${system};
            haskellPackages = pkgs.haskellPackages.override {
                overrides = hself: hsuper: {
                    "flex-record" = flex-record.packages.${system}.default;
                };
            };
            project = haskellPackages.callCabal2nix "typed-rpc" ./. {};
            devTools = with haskellPackages; [
                cabal-install
                hoogle
                haskell-language-server
            ];
        in
        {
            packages.default = project;
            devShells.default = haskellPackages.shellFor {
                packages = p: [ project ];
                nativeBuildInputs = devTools;
            };
        });
}
