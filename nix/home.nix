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
    "fish/functions/_parse_github_repo.fish".source = ../fish/functions/_parse_github_repo.fish;
    "fish/functions/_git_config_identity.fish".source = ../fish/functions/_git_config_identity.fish;
    "fish/functions/clone-workdev.fish".source = ../fish/functions/clone-workdev.fish;
    "fish/functions/clone-personaldev.fish".source = ../fish/functions/clone-personaldev.fish;
    "fish/functions/git-workdev.fish".source = ../fish/functions/git-workdev.fish;
    "fish/functions/git-personaldev.fish".source = ../fish/functions/git-personaldev.fish;
    "fish/functions/git-whoami.fish".source = ../fish/functions/git-whoami.fish;
    "fish/functions/is-pcsoft-forbidden.fish".source = ../fish/functions/is-pcsoft-forbidden.fish;
    "fish/functions/is-pcsoft-editable.fish".source = ../fish/functions/is-pcsoft-editable.fish;
    "fish/functions/edit.fish".source = ../fish/functions/edit.fish;
    "fish/functions/_wt_git_root.fish".source = ../fish/functions/_wt_git_root.fish;
    "fish/functions/_wt_is_pcsoft_repo.fish".source = ../fish/functions/_wt_is_pcsoft_repo.fish;
    "fish/functions/_wt_path_for.fish".source = ../fish/functions/_wt_path_for.fish;
    "fish/functions/wtadd.fish".source = ../fish/functions/wtadd.fish;
    "fish/functions/wtlist.fish".source = ../fish/functions/wtlist.fish;
    "fish/functions/wtremove.fish".source = ../fish/functions/wtremove.fish;
  };
}
