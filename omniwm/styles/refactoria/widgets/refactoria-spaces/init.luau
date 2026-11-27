local view = require("../lib/continuum")
local config = require("../lib/config")

-- Monitor-local tabs and focused application, with no global app leakage.
function render(ctx)
    return view.leading(ctx, ui, config)
end
