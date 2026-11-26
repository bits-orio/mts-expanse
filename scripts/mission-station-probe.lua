-- Native engine regressions for the mission cargo station, loaded only into
-- disposable test profiles by scripts/test-mission-station.py.
local Event = require 'utils.event'
local SpaceMissions = require 'maps.expanse.space_missions'
local Model = require 'maps.expanse.missions.model'
local Data = require 'maps.expanse.mission_data'
local Public = {}

local TIER, LEVEL = 4, 2
local ITEM = 'fast-inserter'
local KEY = ITEM .. '|normal'
local SURPLUS = 5

local function section_counts(section)
    local counts = {}
    for _, filter in pairs(section and section.filters or {}) do
        if filter.value then counts[filter.value.name] = filter.min end
    end
    return counts
end

local function build_silo(state, surface, force)
    surface.request_to_generate_chunks({50, 50}, 2)
    surface.force_generate_chunk_requests()
    local tiles = {}
    for x = 30, 70 do for y = 30, 70 do tiles[#tiles + 1] = {name = 'grass-1', position = {x, y}} end end
    surface.set_tiles(tiles)
    for _, entity in pairs(surface.find_entities_filtered{area = {{30, 30}, {70, 70}}}) do
        if entity.type ~= 'character' then entity.destroy() end
    end
    local silo = assert(surface.create_entity{name = 'rocket-silo', position = {50, 50}, force = force})
    silo.minable_flag = false
    silo.destructible = false
    assert(surface.create_entity{name = 'substation', position = {60, 45}, force = force})
    local source = assert(surface.create_entity{name = 'electric-energy-interface', position = {63, 45}, force = force})
    source.power_production, source.electric_buffer_size, source.energy = 10e9, 10e9, 10e9
    state.rocket_silos[silo.unit_number] = {entity = silo, tier = TIER}
    -- Everything of the step is credited except ten fast inserters: one part load.
    local delivered = {}
    for key, count in pairs(Data.costs[TIER][LEVEL]) do delivered[key] = count end
    delivered[KEY] = delivered[KEY] - 10
    state.missions[TIER] = {level = LEVEL, delivered = delivered}
    return silo
end

function Public.install(Expanse, mts)
    local target = mts and 'team-1' or 'player'
    Event.on_init(function()
        if mts then Expanse.reset(target) end
        storage.station_test = {checks = {}, phase = 'build'}
    end)
    Event.on_nth_tick(30, function()
        local audit = storage.station_test
        if audit.done or game.tick < 600 then return end
        local state = Expanse.test_state(target)
        local surface = game.surfaces[state.active_surface_index]
        local force = game.forces[target]
        local function check(name, condition) assert(condition, name); audit.checks[name] = true end

        if audit.phase == 'build' then
            audit.silo = build_silo(state, surface, force)
            audit.phase = 'station'
            return
        end
        local data = state.rocket_silos[audit.silo.unit_number]
        local silo = data.entity
        if silo.rocket_silo_status == defines.rocket_silo_status.building_rocket and silo.rocket_parts < 50 then
            silo.rocket_parts = 50
        end
        local chest, combinator = data.cargo_chest, data.cargo_combinator
        if not (chest and chest.valid and combinator and combinator.valid) then return end

        if audit.phase == 'station' then
            check('station_is_protected', not chest.destructible and not chest.minable_flag and not combinator.destructible)
            check('station_survives_base_reset', Expanse.forfeit_impl.is_preserved_force_entity(state, chest)
                and Expanse.forfeit_impl.is_preserved_force_entity(state, combinator))
            chest.insert{name = ITEM, count = 4}
            -- A player ticking this box used to stall the mission: the rocket takes no scripted cargo while it is on.
            silo.use_transitional_requests = true
            audit.phase = 'signals'
            -- The station is refreshed once a second; give it two refreshes.
            audit.resume_tick = game.tick + 120
        elseif audit.phase == 'signals' then
            if game.tick < audit.resume_tick then return end
            local requests = section_counts(chest.get_requester_point().get_section(1))
            local signals = section_counts(combinator.get_control_behavior().get_section(1))
            -- Requests are the chest's target content; the signal is what is still missing from it.
            check('automatic_platform_requests_are_switched_off', not silo.use_transitional_requests)
            check('chest_requests_only_the_outstanding_item', requests[ITEM] == 10 and table_size(requests) == 1)
            check('combinator_shows_what_is_missing_from_the_chest', signals[ITEM] == 6 and table_size(signals) == 1)
            chest.insert{name = ITEM, count = 6 + SURPLUS}
            audit.phase = 'launch'
        elseif audit.phase == 'launch' then
            if state.missions[TIER].level == LEVEL then
                local outstanding = Model.outstanding(state, TIER)[KEY] or 0
                assert(outstanding + (Model.in_transit(state, TIER)[KEY] or 0) + (state.missions[TIER].delivered[KEY] or 0)
                    == Data.costs[TIER][LEVEL][KEY], 'cargo counted twice or lost while in flight')
                return
            end
            check('part_load_launches_and_completes_the_step', state.missions[TIER].level == LEVEL + 1)
            check('surplus_stays_in_the_chest', chest.get_item_count(ITEM) == SURPLUS)
            audit.phase = 'next_step'
        elseif audit.phase == 'next_step' then
            local requests = section_counts(chest.get_requester_point().get_section(1))
            local next_costs = Data.costs[TIER][LEVEL + 1]
            local valid = table_size(requests) > 0
            for name, count in pairs(requests) do valid = valid and count <= (next_costs[name .. '|normal'] or 0) end
            check('requests_follow_the_next_step', valid and requests[ITEM] == nil)

            -- A reset keeps research, so a mission with its technology done must reopen.
            force.technologies[Data.mission_unlocks[TIER]].researched = true
            state.missions[TIER] = {level = 0, delivered = {}}
            SpaceMissions.sync_unlocks(state)
            check('researched_mission_reopens', state.missions[TIER].level == 1)

            check('command_refuses_unknown_team', (not mts) or Expanse.forfeit_impl.command_state('team-99') == nil)
            check('command_refuses_default_state_under_mts', (Expanse.forfeit_impl.command_state(nil) == nil) == mts)
            check('remote_reset_refuses_default_state_under_mts', (not mts) or Expanse.reset() == false)

            surface.create_decoratives{check_collision = false, decoratives = {{name = 'enemy-decal', position = {35, 35}, amount = 1}}}
            SpaceMissions.convert_decoratives(surface, {x = 30, y = 30}, 9, 15)
            local area = {{28, 28}, {47, 47}}
            check('aquilo_decals_replace_enemy_decals', #surface.find_decoratives_filtered{area = area, name = 'aqulio-ice-decal-blue'} == 1
                and #surface.find_decoratives_filtered{area = area, name = 'enemy-decal'} == 0)

            local old = {missions = {[8] = {level = 7}}, space_production = {}}
            SpaceMissions.migrate_gaia_rewards(old)
            SpaceMissions.migrate_gaia_rewards(old)
            check('gaia_fruit_migrates_once', old.space_production['yumako|normal'] == 4 and old.space_production['jellynut|normal'] == 4)
            check('gaia_no_longer_changes_spoil_time', Data.rewards[8][4].script == nil and Data.rewards[8][4].production['yumako|normal'] == 4)

            helpers.write_file('station-result.json', helpers.table_to_json(audit.checks))
            audit.done = true
        end
    end)
end

return Public
