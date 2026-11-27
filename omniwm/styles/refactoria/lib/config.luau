-- Fill BOTH fields using `omniwmctl query displays` before selecting the style.
-- Empty fields deliberately match nothing. Never guess display numbering.
-- Session IDs can change on reconnect; re-query and update this installed copy.
return {
    displays = {
        retina = { id = "", name = "" },
        lg = { id = "", name = "" },
        xiaomi = { id = "", name = "" },
        samsung = { id = "", name = "" },
    },
    -- Explicit scroll viewports in points, NOT inferred display widths.
    widths = { retina = 250, lg = 252, xiaomi = 180, samsung = 320, unknown = 252 },
}
