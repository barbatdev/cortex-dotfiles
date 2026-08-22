function _screenshot_files
    set -l directory (_screenshots_dir)
    set -l files

    # BSD find lacks GNU -maxdepth, so retain the source helper's two-level scope in Fish.
    for file in (command find "$directory" -type f -print0 2>/dev/null | string split0)
        set -l relative (string replace -- "$directory/" '' "$file")
        set -l components (string split / -- "$relative")
        test (count $components) -le 2; or continue

        switch (path extension "$file")
            case .png .jpg .jpeg .gif
                set -a files "$file"
        end
    end

    if test (count $files) -gt 0
        command ls -t $files 2>/dev/null
    end
end
