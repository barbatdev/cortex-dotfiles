# Usage: work — change to the first available work projects directory.
function work
    _go_first_existing_dir "$WORK_PROJECTS_DIR" "$BARBATDEV_DIR/innit"
end
