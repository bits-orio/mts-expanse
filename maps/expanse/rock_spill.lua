-- The infinite rock's ore spill, and the penalty for burying the island in it.
--
-- Ore lands anywhere on the team's island. The engine is told to search as far as the
-- farthest corner of the farthest unlocked cell plus one tile of void, which is every tile
-- of the surface that can hold an item; past that there is only out-of-map. Without that
-- bound the engine keeps searching the void for each item, and on an island already
-- covered in ore one mine of ~120 items hung a 2.0.77 headless server for minutes.
--
-- A mine whose ore does not all fit means every open space on the surface is taken by ore,
-- machines or full belts: the ore has spilled over. Every such mine costs the miner a quarter of their health, so four in a row kill
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

-- Distance from position to the farthest corner of any unlocked cell, plus one tile of
-- void, so a spill bounded by it can reach every tile of the island and nothing beyond.
-- Recomputed only when the cell count changes; a team unlocks cells far less often than it
-- mines the rock.
local function island_radius(state, position)
    local size = state.size or 1
    if state.island_radius and state.island_radius_size == size then
        return state.island_radius
    end
    local square = state.square_size
    local radius_sq = square * square
    for key in pairs(state.grid or {}) do
        local x, y = key:match('^(-?%d+)_(-?%d+)$')
        x, y = tonumber(x), tonumber(y)
        if x and y then
            for _, corner in ipairs({ { x, y }, { x + square, y }, { x, y + square }, { x + square, y + square } }) do
                local dx, dy = corner[1] - position.x, corner[2] - position.y
                local d = dx * dx + dy * dy
                if d > radius_sq then
                    radius_sq = d
                end
            end
        end
    end
    state.island_radius = math.ceil(math.sqrt(radius_sq)) + 1
    state.island_radius_size = size
    return state.island_radius
end

-- Spill ore next to the rock, anywhere on the team's island. Returns how many items found
-- room on the ground or a belt; the rest are not produced at all. When some did not fit
-- and args.miner is a player, that player is buried.
-- args: state, surface, position, name, count, force?, miner?
function Public.spill(args)
    local placed = args.surface.spill_item_stack({
        position = args.position,
        stack = { name = args.name, count = args.count },
        enable_looted = true,
        allow_belts = true,
        max_radius = island_radius(args.state, args.position),
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
