local view = require("../lib/continuum")
local config = require("../lib/config")

interval = 2

-- Helper reads register native dependencies: LG reads bar + clock only;
-- wide roles retain their metrics, and unmapped displays read only bar.
function render(ctx)
    return view.trailing(ctx, ui, config)
end
