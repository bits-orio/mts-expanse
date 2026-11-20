-- Checks that the mission rocket cargo setting reaches everything that used to
-- assume a 1 t rocket: the silo prototype, the rocket's hold, the weight at
-- which a rocket leaves by itself, the silo label and the cargo chest's request
-- budget. Loaded only into disposable test profiles by scripts/test-rocket-lift.py.
local Event = require 'utils.event'
local Data = require 'maps.expanse.mission_data'
local Public = {}

local TIER, LEVEL = 4, 2
local ITEM = 'space-platform-foundation'
local KEY = ITEM .. '|normal'
local TONNE = 1000000
local START = 600
-- One step that needs more of one item than any rocket holds, so a rocket is
-- never a "last load" and only the weight rule can send it.
Data.costs[TIER][LEVEL] = { [KEY] = 1000 }

function Public.install(Expanse)
    local tonnes = tonumber(settings.startup['mts-expanse-mission-rocket-lift'].value)

    local function check(name, ok)
        storage.lift_test.checks[name] = ok and true or false
        if not ok then log('LIFT_TEST FAIL ' .. name) end
    end

    local function rocket(test)
        return test.silo.get_inventory(defines.inventory.rocket_silo_rocket)
    end

    local function setup()
        local state = Expanse.test_state('player')
        local surface = game.surfaces[state.active_surface_index]
        surface.request_to_generate_chunks({ 50, 50 }, 2)
        surface.force_generate_chunk_requests()
        local tiles = {}
        for x = 30, 70 do for y = 30, 70 do tiles[#tiles + 1] = { name = 'grass-1', position = { x, y } } end end
        surface.set_tiles(tiles)
        for _, entity in pairs(surface.find_entities_filtered { area = { { 30, 30 }, { 70, 70 } } }) do
            if entity.type ~= 'character' then entity.destroy() end
        end
        local silo = assert(surface.create_entity { name = 'rocket-silo', position = { 50, 50 }, force = 'player' })
        silo.rocket_parts = silo.prototype.rocket_parts_required
        state.rocket_silos[silo.unit_number] = { entity = silo, tier = TIER }
        state.missions[TIER] = { level = LEVEL, delivered = {} }
        storage.lift_test = { checks = {}, silo = silo, launches = 0, phase = 'building' }
        check('silo_prototype_lifts_the_setting', prototypes.entity['rocket-silo'].lift_weight == tonnes * TONNE)
    end

    local function load_just_under(test)
        local per_item = prototypes.item[ITEM].weight
        test.under = tonnes * TONNE / per_item - 1
        check('rocket_holds_the_setting', rocket(test).max_weight == tonnes * TONNE and rocket(test).insert { name = ITEM, count = test.under } == test.under)
        test.phase, test.deadline = 'holding', game.tick + 180
    end

    local function still_waiting(test)
        local state = Expanse.test_state('player')
        local data = state.rocket_silos[test.silo.unit_number]
        check('a_rocket_one_item_short_waits', test.launches == 0 and rocket(test).get_item_count(ITEM) == test.under)
        local label = data.status_label and data.status_label.valid and data.status_label.text
        check('silo_label_names_the_rocket_size', label and label[5] == tonnes .. ' t')
        local section = data.cargo_chest.get_requester_point().get_section(1)
        local filter = section and section.filters[1]
        -- Two rocket loads of the one outstanding item.
        check('chest_requests_two_rocket_loads', filter and filter.min == 2 * tonnes * TONNE / prototypes.item[ITEM].weight)
        rocket(test).insert { name = ITEM, count = 1 }
        test.phase, test.deadline = 'full', game.tick + 180
    end

    local function finish(test)
        check('a_full_rocket_leaves_by_itself', test.launches == 1)
        helpers.write_file('rocket-lift-result.json', helpers.table_to_json(test.checks), false)
        test.phase = 'done'
    end

    Event.add(defines.events.on_rocket_launch_ordered, function(event)
        local test = storage.lift_test
        if test and event.rocket_silo == test.silo then test.launches = test.launches + 1 end
    end)

    Event.add(defines.events.on_tick, function()
        if game.tick == START then setup() end
        local test = storage.lift_test
        if not test or test.phase == 'done' then return end
        if test.silo.valid then test.silo.energy = 1e9 end
        if test.phase == 'building' and test.silo.rocket_silo_status == defines.rocket_silo_status.rocket_ready then
            load_just_under(test)
        elseif test.phase == 'holding' and game.tick >= test.deadline then
            still_waiting(test)
        elseif test.phase == 'full' and game.tick >= test.deadline then
            finish(test)
        end
    end)
end

return Public
