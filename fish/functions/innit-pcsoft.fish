# Usage: innit-pcsoft — change to the InnIT PCSoft directory or fallback.
function innit-pcsoft
    _go_first_existing_dir "$INNIT_PCSOFT_DIR" "$INNIT_DIR"
end
