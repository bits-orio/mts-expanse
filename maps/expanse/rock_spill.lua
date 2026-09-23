-- The infinite rock's ore spill, and the penalty for burying the island in it.
--
-- Ore lands within a set radius of the rock (map setting, one chunk by default). Without
-- a cap the engine searches the whole surface for a free spot for each item; on an island
-- already covered in ore, with nothing but void around it, one mine of ~120 items hung a
-- 2.0.77 headless server for minutes. Capped, a mine on a full island costs a few
-- milliseconds and simply yields less.
--
-- A mine whose ore does not all fit means the miner has covered every free tile around the
-- rock. The team is warned once, and the miner loses a tenth of their health every second
-- until they die. The death is announced to the team.
local Event = require 'utils.event'
local Global = require 'utils.global'

local Public = {}

local DRAIN_FRACTION = 0.1
local DRAIN_INTERVAL_TICKS = 60
local WARNING_COLOR = { r = 1, g = 0.35, b = 0.25 }

-- sick[player_index] = { started = tick, fatal = bool }
local store = { sick = {} }
Global.register(store, function (tbl)
    store = tbl
end)

-- Warn once and start the drain. A player already draining is left alone.
local function start(force, player)
    if not (player and player.valid) or store.sick[player.index] then
        return
    end
    store.sick[player.index] = { started = game.tick }
    if force and force.valid then
        force.print({ 'expanse.rock-spill-warning-team', player.name }, WARNING_COLOR)
    end
    player.print({ 'expanse.rock-spill-warning-player' }, WARNING_COLOR)
end

-- Spill ore next to the rock, no further than args.radius tiles away. Returns how many
-- items found room on the ground or a belt; the rest are not produced at all. When some
-- did not fit and args.miner is a player, that player starts draining.
-- args: surface, position, name, count, radius, force?, miner?
function Public.spill(args)
    local placed = args.surface.spill_item_stack({
        position = args.position,
        stack = { name = args.name, count = args.count },
        enable_looted = true,
        allow_belts = true,
        max_radius = args.radius,
        use_start_position_on_failure = false
    })
    local count = #placed
    if count < args.count then
        start(args.force, args.miner)
    end
    return count
end

local function drain()
    for index, entry in pairs(store.sick) do
        local player = game.get_player(index)
        local character = player and player.valid and player.character
        if character and character.valid then
            local loss = character.max_health * DRAIN_FRACTION
            if character.health <= loss then
                entry.fatal = true
                character.die()
            else
                character.health = character.health - loss
            end
        end
    end
end

local function on_player_died(event)
    local entry = store.sick[event.player_index]
    if not entry then
        return
    end
    store.sick[event.player_index] = nil
    local player = game.get_player(event.player_index)
    if entry.fatal and player and player.valid and player.force.valid then
        player.force.print({ 'expanse.rock-spill-death', player.name }, WARNING_COLOR)
    end
end

Event.on_nth_tick(DRAIN_INTERVAL_TICKS, drain)
Event.add(defines.events.on_player_died, on_player_died)

return Public
