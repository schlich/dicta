{
  description = "A reporter's tape recorder for reviewing what coding agents did";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      # dicta drives niri, PipeWire, and Wayland, so it is Linux-only.
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (pkgs: rec {
        dicta = pkgs.callPackage ./package.nix { };
        default = dicta;
        noctalia-plugins = dicta.noctaliaPlugins;
        claude-code-plugin = dicta.claudeCodePlugin;
      });

      homeManagerModules.default = import ./hm-module.nix self;

      checks = forAllSystems (pkgs: {
        hook = pkgs.callPackage ./tests/hook.nix { };
        noctalia-plugins = self.packages.${pkgs.stdenv.hostPlatform.system}.noctalia-plugins;
        claude-code-plugin = self.packages.${pkgs.stdenv.hostPlatform.system}.claude-code-plugin;
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt-tree);
    };
}
