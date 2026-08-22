# Usage: innit-webs — change to the InnIT web directory or fallback.
function innit-webs
    _go_first_existing_dir "$INNIT_WEBS_DIR" "$INNIT_DIR"
end
