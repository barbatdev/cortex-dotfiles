-- Run with the real Luau CLI from any directory. UI constructors only record
-- returned public trees; formatting is deterministic, not a host-runtime claim.
local view = require("../lib/continuum")
local mark = require("../lib/mark")
local config = {
    displays = {
        retina = { id = "display:1", name = "Built-in" },
        lg = { id = "display:2", name = "LG" },
        xiaomi = { id = "display:3", name = "Xiaomi" },
        samsung = { id = "display:4", name = "Samsung" },
    },
    widths = { retina = 250, lg = 252, xiaomi = 180, samsung = 320, unknown = 252 },
}
local ui = {}
for _, kind in ipairs({ "row", "stack", "box", "path", "text", "symbol" }) do
    ui[kind] = function(props)
        props.kind = kind
        return props
    end
end
local function nodes(tree, predicate)
    local result = {}
    local function walk(node)
        if predicate(node) then table.insert(result, node) end
        for _, child in ipairs(node) do walk(child) end
    end
    walk(tree)
    return result
end
local function texts(tree)
    local result = {}
    for _, node in ipairs(nodes(tree, function(node) return node.kind == "text" end)) do
        table.insert(result, node.text)
    end
    return table.concat(result, "|")
end
local function actions(tree)
    return nodes(tree, function(node) return node.onClick ~= nil end)
end
local function workspaceActions(tree)
    return nodes(tree, function(node)
        return node.onClick ~= nil and node.target ~= nil
    end)
end
local function lines(tree)
    return nodes(tree, function(node) return node.kind == "path" and node.h == 3 end)
end
local function spacers(tree)
    return nodes(tree, function(node)
        return node.kind == "box" and node.w == 16 and node.h == 35
    end)
end
local function freeze(value)
    for _, child in pairs(value) do
        if type(child) == "table" and not table.isfrozen(child) then freeze(child) end
    end
    return table.freeze(value)
end
local function context(id, name)
    return {
        data = {
            bar = { monitorId = id, monitor = name, style = {}, workspaces = {
                { id = "ws-one", name = "internet", focused = true, windows = {
                    { name = "Safari", focused = true },
                } },
                { id = "ws-two", name = "mail; $(not-a-command)", focused = false,
                    windows = { { name = "Other monitor app", focused = false } } },
            } },
            app = "Global app must not leak", cpu = 16, volume = 32, battery = 84,
            system = { memory = { used = 12000 } },
            wifi = { power = true, connected = true, location = "denied" },
            date = "mar 17", clock = "14:32",
        },
        format = {
            percent = function(value) return tostring(value * 100) .. "%" end,
            bytes = function(value) return tostring(value) .. " B" end,
        },
    }
end
local checked = 0
local function check(run)
    run()
    checked += 1
end
check(function()
    local ctx = context("display:1", "Built-in")
    freeze(ctx.data)
    local tree = view.leading(ctx, ui, config)
    assert(texts(tree) == "internet|mail; $(not-a-command)|Safari")
    local clicks = workspaceActions(tree)
    assert(#clicks == 2 and clicks[1].key == "ws-one" and clicks[2].key == "ws-two")
    assert(clicks[1].onClick == "switch-workspace ws-one")
    assert(clicks[2].onClick == "switch-workspace ws-two")
    assert(clicks[2].target == "workspace ws-two")
    assert(#lines(tree) == 1 and lines(tree)[1].h == 3)
    assert(texts(view.trailing(ctx, ui, config)) ==
        "CPU|16%|RAM|12000 B|VOL|32%|Wi-Fi|mar 17 · 14:32|BAT|84%")
end)
check(function()
    local ctx = context("display:2", "LG")
    local names = { "grok bot", "discord", "whatsapp + whatsapp web", "chatgpt",
        "spotify", "ventana de herdr", "X.com" }
    ctx.data.bar.workspaces = {}
    for index, name in ipairs(names) do
        table.insert(ctx.data.bar.workspaces, {
            id = "lg-space-" .. tostring(index), name = name, focused = index == 3,
            windows = { { name = "LG app must not leak", focused = true } },
        })
    end
    local reads = {}
    local bar = ctx.data.bar
    ctx.data = setmetatable({}, {
        __index = function(_, key)
            reads[key] = true
            if key == "bar" then return bar end
            if key == "clock" then return "14:32" end
            error("LG requested unnecessary feed: " .. key)
        end,
    })
    freeze(bar)
    freeze(ctx.data)
    local tree = view.leading(ctx, ui, config)
    assert(texts(tree) == "1|2|3|4|5|6|7")
    local clicks = actions(tree)
    assert(#clicks == 7)
    for index, click in ipairs(clicks) do
        local id = "lg-space-" .. tostring(index)
        assert(click.key == id and click.onClick == "switch-workspace " .. id)
        assert(click.target == "workspace " .. id)
        assert(click.help == tostring(index) .. ": " .. names[index])
        assert(click.w == 36 and click.h == 35 and click.pad == 0)
        assert(click.kind == "stack" and click[1].align == "center")
        assert(#click == 1 and click[1].text == tostring(index))
    end
    assert(#lines(tree) == 1 and clicks[3].fill == "elevatedSurface")
    local active = nodes(tree, function(node)
        return node.kind == "stack" and node[1] == clicks[3]
    end)
    assert(#active == 1 and #active[1] == 2 and active[1][2] == lines(tree)[1])
    assert(lines(tree)[1].align == "bottom" and lines(tree)[1].w == nil)
    assert(lines(tree)[1].viewBox[3] == 100 and lines(tree)[1].d == "M0 0 H100 V3 H0 Z")
    local trailing = view.trailing(ctx, ui, config)
    assert(texts(trailing) == "14:32" and #actions(trailing) == 0)
    assert(reads.bar and reads.clock)
    assert(#spacers(tree) == 1 and #spacers(trailing) == 1)
    assert(tree[2][1].kind == "path" and tree[2][1].d == mark.d)
    local viewport = nodes(tree, function(node) return node.scroll == true end)
    assert(#viewport == 1 and viewport[1].w == 252)
end)
for _, entry in ipairs({ { "display:3", "Xiaomi" }, { "display:4", "Samsung" } }) do
    check(function()
        local ctx = context(entry[1], entry[2])
        freeze(ctx.data)
        assert(texts(view.leading(ctx, ui, config)) ==
            "internet|mail; $(not-a-command)|Safari")
        assert(texts(view.trailing(ctx, ui, config)) == "CPU|16%|RAM|12000 B|mar 17 · 14:32")
        assert(#actions(view.trailing(ctx, ui, config)) == 0)
    end)
end
check(function()
    local ctx = context("display:99", "Unknown")
    assert(texts(view.leading(ctx, ui, config)) == "internet|mail; $(not-a-command)")
    assert(view.trailing(ctx, ui, config).w == 0)
    assert(#spacers(view.leading(ctx, ui, config)) == 0)
end)
check(function()
    local ctx = context("display:1", "Built-in")
    ctx.data.bar.style = nil
    assert(view.leading(ctx, ui, config).w == 0)
    assert(view.trailing(ctx, ui, config).w == 0)
end)
check(function()
    local duplicate = table.clone(config)
    duplicate.displays = table.clone(config.displays)
    duplicate.displays.lg = { id = "display:1", name = "Built-in" }
    local ctx = context("display:1", "Built-in")
    assert(texts(view.leading(ctx, ui, duplicate)) == "internet|mail; $(not-a-command)")
    assert(view.trailing(ctx, ui, duplicate).w == 0)
    assert(#spacers(view.leading(ctx, ui, duplicate)) == 0)
end)
check(function()
    local ctx = context("display:1", "Wrong display reusing this ID")
    assert(texts(view.leading(ctx, ui, config)) == "internet|mail; $(not-a-command)")
    assert(#spacers(view.leading(ctx, ui, config)) == 0)
    assert(view.trailing(ctx, ui, config).w == 0)
end)
check(function()
    local ctx = context("display:9", "LG")
    assert(texts(view.leading(ctx, ui, config)) == "internet|mail; $(not-a-command)")
    local remapped = table.clone(config)
    remapped.displays = table.clone(config.displays)
    remapped.displays.lg = { id = "display:9", name = "LG" }
    assert(texts(view.leading(ctx, ui, remapped)) == "1|2")
    assert(view.leading(ctx, ui, remapped)[2][1].d == mark.d)
    assert(texts(view.trailing(ctx, ui, remapped)) == "14:32")
end)
check(function()
    local ctx = context("display:2", "LG")
    local first = view.leading(ctx, ui, config)
    ctx.data.bar.workspaces[1].focused = false
    ctx.data.bar.workspaces[2].focused = true
    local next = view.leading(ctx, ui, config)
    assert(#lines(first) == 1 and #lines(next) == 1)
    assert(workspaceActions(next)[1].fill == nil and workspaceActions(next)[2].fill == "elevatedSurface")
    assert(workspaceActions(next)[2].onClick == "switch-workspace ws-two")
end)
check(function()
    local ctx = context("display:1", "Built-in")
    ctx.data.cpu, ctx.data.system, ctx.data.volume, ctx.data.battery = nil, nil, nil, nil
    ctx.data.wifi = nil
    assert(texts(view.trailing(ctx, ui, config)) ==
        "CPU|—|RAM|—|VOL|—|Wi-Fi —|mar 17 · 14:32|BAT|—")
end)
check(function()
    local ctx = context("display:1", "Built-in")
    ctx.data.cpu, ctx.data.volume, ctx.data.battery = 0, 0, 0
    ctx.data.system.memory.used = 0
    ctx.data.wifi.connected = false
    ctx.data.muted, ctx.data.charging = true, true
    assert(texts(view.trailing(ctx, ui, config)) ==
        "CPU|0%|RAM|0 B|VOL|Muted|Wi-Fi offline|mar 17 · 14:32|BAT ↑|0%")
end)
check(function()
    for _, entry in ipairs({ { "display:1", "Built-in" }, { "display:2", "LG" },
        { "display:3", "Xiaomi" }, { "display:4", "Samsung" }, { "display:99", "Unknown" } }) do
        local ctx = context(entry[1], entry[2])
        freeze(ctx.data)
        local leading = view.leading(ctx, ui, config)
        local trailing = view.trailing(ctx, ui, config)
        for _, tree in ipairs({ leading, trailing }) do
            for _, text in ipairs(nodes(tree, function(node) return node.kind == "text" end)) do
                assert(text.color == "foreground" or text.color == "secondaryForeground")
                assert(text.font == (if text.style == "mono" then "FiraCode Nerd Font Mono Beard" else "Inter"))
                assert(text.weight == "regular" or text.weight == "medium")
            end
            for _, box in ipairs(nodes(tree, function(node) return node.kind == "box" and node.fill ~= nil end)) do
                assert(box.fill == "border")
            end
        end
        assert(not string.find(texts(leading), "Refactor", 1, true))
        local underline = lines(leading)
        assert(#underline == 1 and underline[1].fill == "accent" and underline[1].h == 3)
        local tabs = workspaceActions(leading)
        assert(tabs[1][1].weight == "medium" and tabs[1][1].color == "foreground")
        assert(tabs[2][1].weight == "regular" and tabs[2][1].color == "secondaryForeground")
    end
end)
check(function()
    for _, entry in ipairs({ { "display:1", "Built-in" }, { "display:2", "LG" },
        { "display:3", "Xiaomi" }, { "display:4", "Samsung" }, { "display:99", "Unknown" } }) do
        local ctx = context(entry[1], entry[2])
        freeze(ctx.data)
        local leading = view.leading(ctx, ui, config)
        local trailing = view.trailing(ctx, ui, config)
        if entry[1] ~= "display:99" then
            assert(#spacers(leading) == 1 and #spacers(trailing) == 1)
            for _, lane in ipairs({ leading, trailing }) do
                assert(lane.kind == "row" and lane.gap == 0 and lane.h == 35 and #lane == 2)
                assert(lane.pad == nil and lane.fill == nil and lane.radius == nil and lane.w == nil)
            end
            assert(leading[1] == spacers(leading)[1] and leading[2].gap == 12)
            assert(trailing[2] == spacers(trailing)[1] and trailing[1].gap == 10)
            for _, spacer in ipairs({ leading[1], trailing[2] }) do
                assert(spacer.fill == nil and spacer.onClick == nil and #spacer == 0)
            end
        else
            assert(#spacers(leading) == 0 and #spacers(trailing) == 0)
            assert(leading.gap == 12 and leading.h == 35)
            assert(trailing.w == 0 and trailing.h == 0)
        end
        local tabs = workspaceActions(leading)
        assert(#tabs == 2)
        for _, tab in ipairs(tabs) do
            assert(tab.h == 35 and tab.pad == (if entry[1] == "display:2" then 0 else 9))
            assert(tab.w == (if entry[1] == "display:2" then 36 else nil))
            assert(tab.kind == (if entry[1] == "display:2" then "stack" else "row"))
            assert(tab[1].align == (if entry[1] == "display:2" then "center" else nil))
        end
        local viewport = nodes(leading, function(node) return node.scroll == true end)
        assert(#viewport == 1 and viewport[1].w == config.widths[
            if entry[1] == "display:1" then "retina" elseif entry[1] == "display:2" then "lg"
            elseif entry[1] == "display:3" then "xiaomi" elseif entry[1] == "display:4" then "samsung"
            else "unknown"])
    end
end)
check(function()
    -- Execute the real renderer for every Wi-Fi state; no permission or SSID read.
    for _, state in ipairs({ "unavailable", "off", "offline", "connected" }) do
        local ctx = context("display:1", "Built-in")
        if state == "unavailable" then
            ctx.data.wifi = nil
        else
            ctx.data.wifi = setmetatable({ power = state ~= "off", connected = state == "connected" }, {
                __index = function(_, key) error("Wi-Fi requested private field: " .. key) end,
            })
        end
        ctx.data.muted = state == "off"
        freeze(ctx.data)
        local tree = view.trailing(ctx, ui, config)
        local clicks = actions(tree)
        assert(#clicks == 3)
        assert(clicks[1].onClick == "shell toggle volume")
        assert(clicks[2].onClick == "shell toggle wifi")
        assert(clicks[3].onClick == "shell toggle calendar")
        assert(texts(clicks[1]) == (if state == "off" then "VOL|Muted" else "VOL|32%"))
        assert(texts(clicks[2]) == (if state == "unavailable" then "Wi-Fi —"
            elseif state == "off" then "Wi-Fi off" elseif state == "offline" then "Wi-Fi offline" else "Wi-Fi"))
        assert(texts(clicks[3]) == "mar 17 · 14:32")
        for _, click in ipairs(clicks) do
            assert(type(click.onClick) == "string" and click.cursor == "pointer")
            assert(click.gap == 5 and click.pad == nil and click.w == nil and click.fill == nil)
        end
    end
end)
check(function()
    for _, entry in ipairs({ { "display:1", "Built-in" }, { "display:2", "LG" },
        { "display:3", "Xiaomi" }, { "display:4", "Samsung" }, { "display:99", "Unknown" } }) do
        local ctx = context(entry[1], entry[2])
        freeze(ctx.data)
        local leading = view.leading(ctx, ui, config)
        local trailing = view.trailing(ctx, ui, config)
        local marks = nodes(leading, function(node)
            return node.kind == "path" and node.h ~= 3
        end)
        local mapped = entry[1] ~= "display:99"
        assert(#marks == (if mapped then 1 else 0))
        if mapped then
            local node = marks[1]
            assert(node.d == mark.d and node.fill == "accent")
            assert(node.w == 17.094 and node.h == 22)
            for index, value in ipairs({ 238, 130, 777, 1000 }) do
                assert(node.viewBox[index] == value)
            end
            assert(node.onClick == nil and node.font == nil)
            assert(node.evenOdd == nil and node.scale == nil and node.rotate == nil)
            assert(node.shadow == nil and node.animate == nil and #node == 0)
            if entry[1] == "display:1" then
                assert(leading[2][1].kind == "stack" and leading[2][1][1] == marks[1])
                assert(leading[2][1].onClick == "menu apple" and #leading[2][1] == 1)
            else
                assert(leading[2][1] == marks[1])
                assert(#actions(leading) == #workspaceActions(leading))
            end
            assert(leading[2].gap == 12 and leading[2].h == 35)
        end
        assert(#nodes(trailing, function(node) return node.kind == "path" end) == 0)
    end
end)
check(function()
    for _, entry in ipairs({ { "display:1", "Built-in" }, { "display:2", "LG" },
        { "display:3", "Xiaomi" }, { "display:4", "Samsung" }, { "display:99", "Unknown" },
        { "display:1", "Wrong name" } }) do
        local ctx = context(entry[1], entry[2])
        -- Menu access must not add private feeds, mutate data or execute actions.
        local data = ctx.data
        ctx.data = setmetatable({}, { __index = function(_, key)
            assert(key == "bar", "Leading requested extra feed: " .. key)
            return data.bar
        end })
        freeze(ctx.data)
        local leading = view.leading(ctx, ui, config)
        local menus = nodes(leading, function(node)
            return node.onClick ~= nil and node.target == nil
        end)
        local retina = entry[1] == "display:1" and entry[2] == "Built-in"
        assert(#menus == (if retina then 2 else 0))
        if #menus == 2 then
            assert(menus[1].onClick == "menu apple" and menus[1].help == "Apple Menu")
            assert(menus[2].onClick == "shell toggle hidden-bar" and menus[2].help == "Hidden Icons Bar")
            local content = leading[2]
            assert(content[1] == menus[1] and menus[1][1].d == mark.d)
            assert(menus[1][1].w == 17.094 and menus[1][1].h == 22 and menus[1][1].fill == "accent")
            assert(content[2][1] == menus[2] and #content[2] == 1 and content[2].gap == 4)
            assert(menus[2][1].name == "app.dashed")
            assert(content[3].scroll == true and content[3].w == 250)
            for _, button in ipairs(menus) do
                assert(button.w == 28 and button.h == 28 and button.cursor == "pointer")
                assert(button.kind == "stack" and button.hover == "surface" and #button == 1)
                assert(button.pad == nil and button.fill == nil and button.radius == nil)
            end
            local symbol = menus[2][1]
            assert(symbol.kind == "symbol" and symbol.color == "foreground")
            assert(symbol.size == 14 and symbol.w == 14 and symbol.h == 14)
        end
        assert(#nodes(leading, function(node)
            return node.kind == "symbol" and node.name == "applelogo"
        end) == 0)
        assert(#workspaceActions(leading) == 2)
        assert(workspaceActions(leading)[1].onClick == "switch-workspace ws-one")
        assert(workspaceActions(leading)[2].onClick == "switch-workspace ws-two")
    end
end)
assert(checked == 17)
print("RefactorIA: 17 behavior checks passed")
