-- The seven ships a team supplies by rocket, keyed by mission tier. The name is
-- the proper noun the mission data already uses for its "new-ship" reward; role
-- and cargo are in the locale file as expanse-missions.role-<name> / gives-<name>.
local Public = {}

-- The engine's weight unit: 1 t is 1,000,000.
Public.TONNE = 1000000
-- What one mission rocket lifts, from the startup setting that also sets the
-- silo prototype's lift weight (data-updates.lua).
Public.ROCKET_WEIGHT = Public.TONNE * (tonumber(settings.startup['mts-expanse-mission-rocket-lift'].value) or 1)
Public.FIRST_TIER = 4
Public.LAST_TIER = 10

Public.by_tier = {
    [4] = { name = 'Atlas', icon = 'space-location/nauvis' },
    [5] = { name = 'Odysseus', icon = 'item/thruster' },
    [6] = { name = 'Hephaestus', icon = 'space-location/vulcanus' },
    [7] = { name = 'Zeus', icon = 'space-location/fulgora' },
    [8] = { name = 'Gaia', icon = 'space-location/gleba' },
    [9] = { name = 'Chione', icon = 'space-location/aquilo' },
    [10] = { name = 'Galactica', icon = 'space-location/shattered-planet' },
}

local DEFAULT_THRESHOLDS = { 30, 60, 90, 150, 210, 300 }

-- Where the silo of a tier is placed, as a localised "x to y tiles from spawn".
-- Follows functions.lua calculate_tier: the Atlas silo is a tier 4 special, the
-- next five silos are tier 5 specials, and the last one lies past the final ring.
function Public.ring(state, tier)
    local thresholds = state.tier_distance_thresholds or DEFAULT_THRESHOLDS
    if tier == Public.LAST_TIER then
        return { 'expanse-missions.ring_beyond', thresholds[6] }
    end
    local index = tier == Public.FIRST_TIER and 3 or 4
    return { 'expanse-missions.ring_between', thresholds[index], thresholds[index + 1] }
end

function Public.role(tier)
    return { 'expanse-missions.role-' .. Public.by_tier[tier].name }
end

function Public.gives(tier)
    return { 'expanse-missions.gives-' .. Public.by_tier[tier].name }
end

-- "620 kg", "1.5 t" or "3 t" for an item weight in the engine's unit.
function Public.format_weight(weight)
    if weight < Public.TONNE then
        return math.floor(weight / 1000 + 0.5) .. ' kg'
    end
    if weight % Public.TONNE == 0 then
        return math.floor(weight / Public.TONNE) .. ' t'
    end
    return string.format('%.1f t', weight / Public.TONNE)
end

-- Cargo weight at which a mission rocket leaves by itself. The setting is given
-- for a 1 t rocket and scales with the rocket.
function Public.launch_weight(state)
    return (state.rocket_launch_weight_threshold or 999500) * Public.ROCKET_WEIGHT / Public.TONNE
end

return Public
