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
}
