function _wt_is_pcsoft_repo
    set -l root (_wt_git_root); or return 1
    git -C "$root" ls-files 2>/dev/null | string match -rqi '\.(wdp|wwp|wpp|wpj|wwh|wpw|prw|wdd|fic|mmo|ndx|wdr|wdq|wdi|wdt|wdv|wdk|rep|sty|cpl|bkp|wdg|wdc|wde|wdw)$'
end
