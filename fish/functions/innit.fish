# Usage: innit — change to the first available InnIT directory.
function innit
    _go_first_existing_dir "$INNIT_DIR" "$WORKSPACE_DIR/innit-sas"
end
