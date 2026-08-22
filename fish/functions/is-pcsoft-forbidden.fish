function is-pcsoft-forbidden
    set -l extension (string lower -- (path extension "$argv[1]"))
    contains -- "$extension" .wdp .wwp .wpp .wpj .wwh .wpw .prw .wdd .fic .mmo .ndx .wdr .wdq .wdi .wdt .wdv .wdk .rep .sty .cpl .bkp .tk .cfg
end
