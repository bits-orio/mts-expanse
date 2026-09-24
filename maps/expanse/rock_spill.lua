-- The infinite rock's ore spill, and the penalty for burying the island in it.
--
-- Ore lands within a set radius of the rock (map setting, one chunk by default). Without
-- a cap the engine searches the whole surface for a free spot for each item; on an island
-- already covered in ore, with nothing but void around it, one mine of ~120 items hung a
-- 2.0.77 headless server for minutes. Capped, a mine on a full island costs a few
-- milliseconds and simply yields less.
--
-- A mine whose ore does not all fit means the miner has covered every free tile around the
-- rock. Every such mine costs the miner a quarter of their health, so four in a row kill
-- them; stopping stops the loss. The team is warned once per episode, and a death is
-- announced to the team. Nothing runs on a tick: it is all driven by the mine itself.
local Event = require 'utils.event'
local Global = require 'utils.global'

local Public = {}

local HEALTH_LOSS_FRACTION = 0.25
-- An overflow this long after the previous one is a fresh episode and warns again.
local EPISODE_GAP_TICKS = 60 * 60
local WARNING_COLOR = { r = 1, g = 0.35, b = 0.25 }

-- buried[player_index] = { last_tick = tick, fatal = bool }
local store = { buried = {} }
Global.register(store, function (tbl)
    store = tbl
end)

local function warn(force, player)
    if force and force.valid then
        force.print({ 'expanse.rock-spill-warning-team', player.name }, WARNING_COLOR)
    end
    player.print({ 'expanse.rock-spill-warning-player' }, WARNING_COLOR)
end

-- One overflowing mine: warn if this is a new episode, then take the health.
local function bury(force, player)
    if not (player and player.valid) then
        return
    end
    local entry = store.buried[player.index]
    if not entry or game.tick - entry.last_tick > EPISODE_GAP_TICKS then
        entry = {}
        store.buried[player.index] = entry
        warn(force, player)
    end
    entry.last_tick = game.tick
    local character = player.character
    if not (character and character.valid) then
        return
    end
    local loss = character.max_health * HEALTH_LOSS_FRACTION
    if character.health <= loss then
        entry.fatal = true
        character.die()
    else
        character.health = character.health - loss
    end
end

-- Spill ore next to the rock, no further than args.radius tiles away. Returns how many
-- items found room on the ground or a belt; the rest are not produced at all. When some
-- did not fit and args.miner is a player, that player is buried.
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
        bury(args.force, args.miner)
    end
    return count
end

local function on_player_died(event)
    local entry = store.buried[event.player_index]
    if not entry then
        return
    end
    store.buried[event.player_index] = nil
    local player = game.get_player(event.player_index)
    if entry.fatal and player and player.valid and player.force.valid then
        player.force.print({ 'expanse.rock-spill-death', player.name }, WARNING_COLOR)
    end
end

Event.add(defines.events.on_player_died, on_player_died)

return Public
