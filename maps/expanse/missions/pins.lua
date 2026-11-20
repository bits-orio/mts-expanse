-- Map pins on mission silos. A pin puts a marker with the name and distance on
-- the player's screen, an arrow at the screen edge when the silo is out of
-- view, and an entry under the minimap. A pin belongs to one player, who can
-- rename or delete it there; the mod only keeps track of the ones it made.
local Ships = require 'maps.expanse.missions.ships'

local Public = {}

local function label(data)
    return Ships.by_tier[data.tier].name .. ' mission silo'
end

local function pin_of(data, player)
    local pin = data.pins and data.pins[player.index]
    return pin and pin.valid and pin or nil
end

function Public.is_pinned(data, player)
    return pin_of(data, player) ~= nil
end

function Public.add(data, player)
    if pin_of(data, player) or not (data.entity and data.entity.valid) then return end
    data.pins = data.pins or {}
    data.pins[player.index] = player.add_pin { entity = data.entity, label = label(data) }
end

function Public.remove(data, player)
    local pin = pin_of(data, player)
    if pin then pin.destroy() end
    if data.pins then data.pins[player.index] = nil end
end

-- The board's button: pin the silo, or take the pin away again.
function Public.toggle(data, player)
    if pin_of(data, player) then
        Public.remove(data, player)
    else
        Public.add(data, player)
    end
end

-- A silo was uncovered: everyone on the team gets a pin with the chat line.
function Public.team(state, data)
    local force = game.forces[state.force_name or 'player']
    if not (data and force and force.valid) then return end
    for _, player in pairs(force.players) do
        Public.add(data, player)
    end
end

-- Forget pins the player deleted, and remove the ones of players who left the
-- team: their silo is on a surface that is no longer theirs.
function Public.prune(state, data)
    if not data.pins then return end
    local force_name = state.force_name or 'player'
    for index, pin in pairs(data.pins) do
        local player = game.get_player(index)
        if not pin.valid then
            data.pins[index] = nil
        elseif not (player and player.force.name == force_name) then
            pin.destroy()
            data.pins[index] = nil
        end
    end
end

return Public
