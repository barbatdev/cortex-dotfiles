{ username, homeDirectory, system, ... }:

{
  assertions = [
    {
      assertion = username != "" && homeDirectory != "";
      message = "homeConfigurations.jbarbat must provide explicit non-empty username and homeDirectory values.";
    }
  ];

  home = {
    username = username;
    homeDirectory = homeDirectory;
    stateVersion = "24.11";
  };

  programs.home-manager.enable = true;

  xdg.configFile = {
    "nix/nix.conf".text = "experimental-features = nix-command flakes\n";
  };
}
