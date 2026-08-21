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

  xdg.configFile = {
    "fish/conf.d/10-core.fish".source = ../fish/conf.d/10-core.fish;
    "fish/functions/_go_dev_dir.fish".source = ../fish/functions/_go_dev_dir.fish;
    "fish/functions/_go_first_existing_dir.fish".source = ../fish/functions/_go_first_existing_dir.fish;
    "fish/functions/dev.fish".source = ../fish/functions/dev.fish;
    "fish/functions/barbat.fish".source = ../fish/functions/barbat.fish;
    "fish/functions/cowork.fish".source = ../fish/functions/cowork.fish;
    "fish/functions/personal.fish".source = ../fish/functions/personal.fish;
    "fish/functions/tools.fish".source = ../fish/functions/tools.fish;
    "fish/functions/worktrees.fish".source = ../fish/functions/worktrees.fish;
    "fish/functions/work.fish".source = ../fish/functions/work.fish;
    "fish/functions/innit.fish".source = ../fish/functions/innit.fish;
    "fish/functions/innit-apis.fish".source = ../fish/functions/innit-apis.fish;
    "fish/functions/innit-mobile.fish".source = ../fish/functions/innit-mobile.fish;
    "fish/functions/innit-webs.fish".source = ../fish/functions/innit-webs.fish;
    "fish/functions/innit-pcsoft.fish".source = ../fish/functions/innit-pcsoft.fish;
    "fish/functions/dotfiles.fish".source = ../fish/functions/dotfiles.fish;
  };
}
