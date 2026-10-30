{ username, homeDirectory, system, pkgs, lib, ... }:

{
  assertions = [
    {
      assertion = username != "" && homeDirectory != "";
      message = "Home Manager configurations must provide explicit non-empty username and homeDirectory values.";
    }
    {
      assertion = system == "aarch64-darwin" || system == "x86_64-linux";
      message = "Only aarch64-darwin and x86_64-linux Home Manager configurations are supported.";
    }
  ];

  home = {
    username = username;
    homeDirectory = homeDirectory;
    stateVersion = "24.11";
    packages = lib.optionals pkgs.stdenv.isLinux [ pkgs.starship ];
  };

  programs.home-manager.enable = true;

  xdg.configFile."nix/nix.conf".text = "experimental-features = nix-command flakes\n";
}
