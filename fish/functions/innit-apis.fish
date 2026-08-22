# Usage: innit-apis — change to the InnIT APIs directory or fallback.
function innit-apis
    _go_first_existing_dir "$INNIT_APIS_DIR" "$INNIT_DIR"
end
