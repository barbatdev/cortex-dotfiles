-- Native API 1 view construction; no providers, subprocesses or stored state.
local M = {}
local mark = require("./mark")

local function resolve(bar, config)
    local matches = 0
    local selected = nil
    for _, role in ipairs({ "retina", "lg", "xiaomi", "samsung" }) do
        local entry = config.displays[role]
        if entry and entry.id ~= "" and entry.id == bar.monitorId then
            matches += 1
            if entry.name ~= "" and entry.name == bar.monitor then selected = role end
        end
    end
    -- Refuse duplicate IDs even when only one configured name matches.
    return if matches == 1 then selected else nil
end

local function empty(ui)
    return ui.box{ w = 0, h = 0 }
end

-- Public leading-lane renderer. Only host-provided workspaces become tabs.
function M.leading(ctx, ui, config)
    local bar = ctx.data.bar
    if not bar or not bar.style then return empty(ui) end
    local role = resolve(bar, config)
    local row = { gap = 12, h = 35 }
    if role then
        -- Official full-beard geometry, proportionally sized; violet approved for all roles.
        local node = ui.path{ d = mark.d, viewBox = mark.viewBox,
            w = mark.w, h = mark.h, fill = "accent" }
        if role == "retina" then
            -- Only Retina wraps the unchanged mark in the native Apple menu target.
            node = ui.stack{ w = 28, h = 28, cursor = "pointer", hover = "surface",
                onClick = "menu apple", help = "Apple Menu", node }
        end
        table.insert(row, node)
    end
    if role == "retina" then
        -- Native resident-icon access stays separate; no app-menu or task switcher.
        table.insert(row, ui.row{ gap = 4,
            ui.stack{ w = 28, h = 28, cursor = "pointer", hover = "surface",
                onClick = "shell toggle hidden-bar", help = "Hidden Icons Bar",
                ui.symbol{ name = "app.dashed", size = 14, w = 14, h = 14, color = "foreground" } },
        })
    end
    local tabs = { gap = 0, h = 35, scroll = true, w = config.widths[role or "unknown"] }
    for index, workspace in ipairs(bar.workspaces) do
        local label = if role == "lg" then tostring(index) else workspace.name
        if label == "" then label = tostring(index) end
        -- API 1 rows center only on the cross axis; stacks center the digit in both axes.
        local tab = if role == "lg" then ui.stack else ui.row
        local node = tab{
            key = workspace.id, h = 35, w = if role == "lg" then 36 else nil,
            pad = if role == "lg" then 0 else 9,
            fill = if workspace.focused then "elevatedSurface" else nil,
            hover = "surface", onClick = "switch-workspace " .. workspace.id,
            target = "workspace " .. workspace.id, cursor = "pointer",
            help = tostring(index) .. ": " .. workspace.name,
            ui.text{ text = label, style = "mono", font = "FiraCode Nerd Font Mono Beard", size = 11,
                align = if role == "lg" then "center" else nil,
                weight = if workspace.focused then "medium" else "regular",
                color = if workspace.focused then "foreground" else "secondaryForeground" },
        }
        if workspace.focused then
            node = ui.stack{ key = workspace.id, node,
                ui.path{ h = 3, align = "bottom", viewBox = { 0, 0, 100, 3 },
                    d = "M0 0 H100 V3 H0 Z", fill = "accent" } }
        end
        table.insert(tabs, node)
    end
    table.insert(row, ui.row(tabs))
    if role and role ~= "lg" then
        -- ctx.data.app is global; use this monitor's focused workspace/window.
        local app = nil
        for _, workspace in ipairs(bar.workspaces) do
            if workspace.focused then
                for _, item in ipairs(workspace.windows) do
                    if item.focused then app = item.name end
                end
            end
        end
        if app and app ~= "" then
            table.insert(row, ui.row{ gap = 12,
                ui.box{ w = 1, h = 14, fill = "border" },
                ui.text{ text = app, font = "Inter", size = 11, weight = "regular",
                    color = "secondaryForeground", maxWidth = 160, help = app },
            })
        end
    end
    -- space-3 on every mapped display: outer left edge, no extra child gap.
    if role then
        return ui.row{ gap = 0, h = 35,
            ui.box{ w = 16, h = 35 }, ui.row(row),
        }
    end
    return ui.row(row)
end

local function percent(ctx, value)
    return if value ~= nil then ctx.format.percent(value / 100) else "—"
end

local function metric(ui, label, value, action)
    local row = { gap = 5, ui.box{ w = 1, h = 14, fill = "border" } }
    -- API 1 string actions; native shell toggles never spawn a process.
    row.onClick = action
    row.cursor = if action then "pointer" else nil
    if label ~= "" then
        table.insert(row, ui.text{ text = label, style = "mono", font = "FiraCode Nerd Font Mono Beard",
            size = 11, weight = "regular", color = "foreground" })
    end
    table.insert(row, ui.text{ text = value, style = "mono", font = "FiraCode Nerd Font Mono Beard",
        size = 11, weight = "regular", color = "secondaryForeground" })
    return ui.row(row)
end

-- Public trailing-lane renderer. Missing facts remain unavailable, never zero.
function M.trailing(ctx, ui, config)
    local bar = ctx.data.bar
    if not bar or not bar.style then return empty(ui) end
    local role = resolve(bar, config)
    if not role then return empty(ui) end
    local row = { gap = 10, h = 35 }
    if role == "lg" then
        -- Reads are reactive even inside helpers; LG subscribes only to clock.
        table.insert(row, metric(ui, "", ctx.data.clock))
    else
        local system = ctx.data.system
        table.insert(row, metric(ui, "CPU", percent(ctx, ctx.data.cpu)))
        table.insert(row, metric(ui, "RAM", if system and system.memory and system.memory.used ~= nil
            then ctx.format.bytes(system.memory.used) else "—"))
        if role == "retina" then
            table.insert(row, metric(ui, "VOL", if ctx.data.muted then "Muted" else percent(ctx, ctx.data.volume), "shell toggle volume"))
            local wifi = ctx.data.wifi
            local label = if not wifi then "Wi-Fi —"
                elseif not wifi.power then "Wi-Fi off"
                elseif not wifi.connected then "Wi-Fi offline"
                else "Wi-Fi"
            -- Never requests SSID/Location access merely to show connection state.
            table.insert(row, metric(ui, "", label, "shell toggle wifi"))
        end
        table.insert(row, metric(ui, "", ctx.data.date .. " · " .. ctx.data.clock,
            if role == "retina" then "shell toggle calendar" else nil))
        if role == "retina" then
            table.insert(row, metric(ui, if ctx.data.charging then "BAT ↑" else "BAT", percent(ctx, ctx.data.battery)))
        end
    end
    -- space-3 on every mapped display: outer right edge, not the notch edge.
    return ui.row{ gap = 0, h = 35,
        ui.row(row), ui.box{ w = 16, h = 35 },
    }
end

return M
