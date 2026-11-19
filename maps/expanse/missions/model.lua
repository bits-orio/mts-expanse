-- Read-only view of one mission for everything that shows or feeds it: the
-- board, the silo panel, the silo label, chat lines and the cargo chest.
local MissionData = require 'maps.expanse.mission_data'
local Ships = require 'maps.expanse.missions.ships'

local Public = {}

function Public.split_key(key)
    return key:match('^(.-)|(.+)$')
end

-- The last level of every mission is a marker costing one legendary rocket
-- part. It is never a step a player works on.
function Public.step_count(tier)
    return #MissionData.costs[tier] - 1
end

function Public.silo_data(state, tier)
    for _, data in pairs(state.rocket_silos or {}) do
        if data.tier == tier and data.entity and data.entity.valid then
            return data
        end
    end
    return nil
end

local function add_contents(counts, inventory)
    if not inventory then return end
    for _, item in pairs(inventory.get_contents()) do
        local key = item.name .. '|' .. (item.quality or 'normal')
        counts[key] = (counts[key] or 0) + item.count
    end
end

function Public.rocket_inventory(silo)
    return silo and silo.valid and silo.get_inventory(defines.inventory.rocket_silo_rocket) or nil
end

function Public.inventory_weight(inventory)
    local weight = 0
    for _, item in pairs(inventory and inventory.get_contents() or {}) do
        weight = weight + prototypes.item[item.name].weight * item.count
    end
    return weight
end

-- Cargo that has left the team's hands but is not credited yet: what stands in
-- the rocket plus what flies in pods launched from this tier's silo. A launched
-- rocket keeps its cargo in the pod, and the silo's rocket inventory is empty
-- from the launch order on, so nothing is counted twice.
function Public.in_transit(state, tier)
    local counts = {}
    local data = Public.silo_data(state, tier)
    add_contents(counts, data and Public.rocket_inventory(data.entity))
    for _, cargo in pairs(state.cargo_pods or {}) do
        if cargo.tier == tier and cargo.pod and cargo.pod.valid then
            add_contents(counts, cargo.pod.get_inventory(defines.inventory.cargo_unit))
        end
    end
    return counts
end

-- Costs of the step the mission is on, or nil when locked or complete.
function Public.current_costs(state, tier)
    local level = state.missions[tier].level
    if level < 1 or level > Public.step_count(tier) then return nil end
    return MissionData.costs[tier][level]
end

-- What the current step still needs that is not on its way yet, keyed
-- "name|quality". This is the number a supplier may act on without ever
-- bringing more than the step can use.
function Public.outstanding(state, tier)
    local costs = Public.current_costs(state, tier)
    local outstanding = {}
    if not costs then return outstanding end
    local delivered = state.missions[tier].delivered
    local transit = Public.in_transit(state, tier)
    for key, count in pairs(costs) do
        local left = count - (delivered[key] or 0) - (transit[key] or 0)
        if left > 0 then outstanding[key] = left end
    end
    return outstanding
end

local function sorted_items(costs, delivered)
    local items = {}
    for key, count in pairs(costs) do
        local name, quality = Public.split_key(key)
        items[#items + 1] = {
            key = key, name = name, quality = quality, count = count,
            delivered = math.min(delivered[key] or 0, count),
            weight = prototypes.item[name].weight,
        }
    end
    -- Open lines first, then by name, so the list reads as a to-do list.
    table.sort(items, function(a, b)
        local a_done, b_done = a.delivered >= a.count, b.delivered >= b.count
        if a_done ~= b_done then return b_done end
        if a.name ~= b.name then return a.name < b.name end
        return a.quality < b.quality
    end)
    return items
end

-- Where a mission stands: status is 'locked', 'nosilo', 'active' or 'done'.
-- Cheap enough for the once-a-second label refresh.
function Public.stage(state, tier)
    local level = state.missions[tier].level
    local steps = Public.step_count(tier)
    local data = Public.silo_data(state, tier)
    local status = 'active'
    if level > steps then status = 'done'
    elseif level == 0 then status = 'locked'
    elseif not data then status = 'nosilo' end
    return { status = status, steps = steps, step = math.max(1, math.min(level, steps)), silo = data and data.entity or nil }
end

function Public.build(state, tier)
    local mission = state.missions[tier]
    local model = Public.stage(state, tier)
    model.tier = tier
    model.ship = Ships.by_tier[tier]
    model.tech = MissionData.mission_unlocks[tier]
    model.items, model.need_weight, model.total_weight = {}, 0, 0
    local costs = Public.current_costs(state, tier)
    if costs then
        model.items = sorted_items(costs, mission.delivered)
        model.rewards = MissionData.rewards[tier][mission.level]
    end
    for _, item in pairs(model.items) do
        model.need_weight = model.need_weight + (item.count - item.delivered) * item.weight
        model.total_weight = model.total_weight + item.count * item.weight
    end
    model.fraction = model.total_weight > 0 and (model.total_weight - model.need_weight) / model.total_weight or 0
    model.rockets = math.ceil(model.need_weight / Ships.ROCKET_WEIGHT)
    -- Share of the whole mission that is done, for the progress bar.
    model.progress = model.status == 'done' and 1 or (model.step - 1 + model.fraction) / model.steps
    return model
end

return Public
