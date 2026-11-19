-- Side panel on a mission silo's own window: which mission this is, what the
-- step still needs, how full the rocket is, the launch rule in one sentence,
-- and a button that sends the rocket with what is aboard.
local Model = require 'maps.expanse.missions.model'
local Ships = require 'maps.expanse.missions.ships'
local W = require 'maps.expanse.widgets'

local Public = { FRAME = 'expanse_missions_silo_panel' }

local WIDTH = 330

local function silo_tier(state, silo)
    local data = state.rocket_silos and state.rocket_silos[silo.unit_number]
    return data and data.entity == silo and data.tier or nil
end

local function ready_to_launch(silo, weight)
    return weight > 0 and silo.rocket_silo_status == defines.rocket_silo_status.rocket_ready
end

-- Everything the panel shows, as one string. The panel is rebuilt only when
-- this changes, so an open panel does not flicker every second.
local function signature(stage, outstanding, weight, ready)
    local parts = { stage.status, stage.step, weight, tostring(ready) }
    for key, count in pairs(outstanding) do parts[#parts + 1] = key .. count end
    table.sort(parts, function(a, b) return tostring(a) < tostring(b) end)
    return table.concat(parts, ';')
end

local function needed_grid(parent, outstanding)
    local keys = {}
    for key in pairs(outstanding) do keys[#keys + 1] = key end
    table.sort(keys)
    if #keys == 0 then
        W.label(parent, { 'expanse-missions.panel_all_aboard' }, nil, W.GREEN)
        return
    end
    W.label(parent, { 'expanse-missions.panel_needed' }, 'default-semibold', W.GREY).style.top_margin = 4
    local grid = parent.add { type = 'table', column_count = 6 }
    for _, key in ipairs(keys) do
        local name, quality = Model.split_key(key)
        W.item_slot(grid, name, quality, outstanding[key])
    end
end

local function rocket_standing(silo)
    return silo.rocket_silo_status == defines.rocket_silo_status.rocket_ready
end

local function cargo_block(parent, silo, weight, ready)
    parent.add { type = 'line' }.style.top_margin = 6
    if rocket_standing(silo) then
        W.label(parent, { 'expanse-missions.panel_cargo', Ships.format_weight(weight) }, 'default-bold')
        local bar = parent.add { type = 'progressbar', value = math.min(weight / Ships.ROCKET_WEIGHT, 1) }
        bar.style.horizontally_stretchable = true
        bar.style.color = weight >= Ships.ROCKET_WEIGHT and W.GREEN or W.GOLD
    else
        -- While a rocket is being built or is leaving, the silo has no cargo
        -- hold to read; the cargo chest keeps collecting meanwhile.
        W.label(parent, { 'expanse-missions.panel_no_rocket' }, 'default-bold')
    end
    W.label(parent, { 'expanse-missions.panel_rule' }, nil, W.GREY)
    local button = parent.add { type = 'button', caption = { 'expanse-missions.panel_launch' }, style = 'confirm_button',
        tags = { [W.TAG] = 'launch', unit = silo.unit_number } }
    button.style.top_margin = 6
    button.enabled = ready
end

local function build(player, state, silo, tier, key)
    Public.close(player)
    local stage = Model.stage(state, tier)
    local frame = player.gui.relative.add { type = 'frame', name = Public.FRAME, direction = 'vertical',
        caption = { 'expanse-missions.panel_title', Ships.by_tier[tier].name },
        anchor = { gui = defines.relative_gui_type.rocket_silo_gui, position = defines.relative_gui_position.left },
        tags = { key = key } }
    frame.style.width = WIDTH
    local inner = frame.add { type = 'frame', direction = 'vertical', style = 'inside_shallow_frame_with_padding' }
    if stage.status == 'locked' or stage.status == 'done' then
        W.label(inner, { 'expanse-missions.panel_' .. stage.status }, nil, W.GREY)
        return
    end
    W.label(inner, { 'expanse-missions.step_of', stage.step, stage.steps }, 'default-bold')
    needed_grid(inner, Model.outstanding(state, tier))
    local weight = Model.inventory_weight(Model.rocket_inventory(silo))
    cargo_block(inner, silo, weight, ready_to_launch(silo, weight))
end

function Public.close(player)
    local frame = player.gui.relative[Public.FRAME]
    if frame then frame.destroy() end
end

-- Shows the panel for a mission silo and removes it for any other entity.
function Public.show(player, state, silo)
    local tier = silo and silo.valid and silo.type == 'rocket-silo' and state and silo_tier(state, silo)
    if not tier then
        Public.close(player)
        return
    end
    local stage = Model.stage(state, tier)
    local weight = Model.inventory_weight(Model.rocket_inventory(silo))
    local key = signature(stage, Model.outstanding(state, tier), weight, ready_to_launch(silo, weight)) .. tostring(rocket_standing(silo))
    local frame = player.gui.relative[Public.FRAME]
    if frame and frame.tags.key == key then return end
    build(player, state, silo, tier, key)
end

-- Rocket cargo changes without an event, so open panels are checked once a
-- second from the mission tick. Players with no silo open cost one comparison.
function Public.refresh_open(state, players)
    for _, player in pairs(players) do
        local opened = player.opened_gui_type == defines.gui_type.entity and player.opened
        if opened and opened.valid and opened.type == 'rocket-silo' then
            Public.show(player, state, opened)
        end
    end
end

return Public
