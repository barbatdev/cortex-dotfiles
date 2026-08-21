function is-pcsoft-editable
    set -l extension (string lower -- (path extension "$argv[1]"))
    contains -- "$extension" .wdg .wdc .wde .wdw
end
