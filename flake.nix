{
  description = "Inert Home Manager boundary for cortex-dotfiles";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }:
    let
      mkHomeConfiguration = { username, homeDirectory, system }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          extraSpecialArgs = {
            inherit username homeDirectory system;
          };
          modules = [ ./nix/home.nix ];
        };
    in
    {
      homeConfigurations.jbarbat = mkHomeConfiguration {
        username = "jbarbat";
        homeDirectory = "/Users/jbarbat";
        system = "aarch64-darwin";
      };
    };
}
