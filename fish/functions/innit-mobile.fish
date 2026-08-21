# Usage: innit-mobile — change to the InnIT mobile directory or fallback.
function innit-mobile
    _go_first_existing_dir "$INNIT_MOBILE_DIR" "$INNIT_DIR"
end
