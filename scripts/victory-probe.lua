-- Loaded only into disposable test copies by test-victory.py.
local Event = require 'utils.event'
local Missions = require 'maps.expanse.space_missions'
local Data = require 'maps.expanse.mission_data'
local legacy = script.active_mods['mts-expanse'] == '0.1.12'
local mts = script.active_mods['multi-team-support'] ~= nil
local target = mts and 'team-1' or 'player'
local Public = {}

local function write(result)
    helpers.write_file('victory-test.jsonl', helpers.table_to_json(result) .. '\n', true)
end

function Public.install(Expanse)
    local function seed()
        if mts then
            Expanse.reset('team-1')
            Expanse.reset('team-2')
        end
        local state = Expanse.test_state(target)
        local surface = game.surfaces[state.active_surface_index]
        local position = surface.find_non_colliding_position('steel-chest', {8, 8}, 20, 1)
        local chest = assert(surface.create_entity{name = 'steel-chest', position = position, force = target})
        chest.insert{name = 'iron-plate', count = 37}
        game.forces[target].technologies['automation'].researched = true
        storage.victory_test = {surface = surface.index, chest = chest, reset_tick = state.reset_tick}
        if mts then
            local other = Expanse.test_state('team-2')
            storage.victory_test.other_surface = other.active_surface_index
            storage.victory_test.other_reset_tick = other.reset_tick
        end
        if legacy then
            -- Model a save made during the old victory countdown, alongside an
            -- unrelated scheduled event that the upgrade must leave intact.
            table.insert(state.schedule, {tick = game.tick + 120, event = 'map_reset', parameters = {force_name = target}})
            table.insert(state.schedule, {tick = game.tick + 20000, event = 'gui_update', parameters = {test_keep = true}})
            state.map_reset_delay_ticks = 7200
        end
    end
    Event.on_init(seed)
    Event.on_nth_tick(30, function()
        if legacy then return end
        local audit = storage.victory_test
        local state = Expanse.test_state(target)
        if not audit.started then
            audit.started = game.tick
            for _, task in pairs(state.schedule) do
                assert(task.event ~= 'map_reset', 'upgrade retained a legacy victory reset')
            end
            if audit.upgraded then
                local preserved = false
                for _, task in pairs(state.schedule) do
                    if task.parameters and task.parameters.test_keep then preserved = true end
                end
                assert(preserved, 'upgrade removed unrelated scheduled event')
            end
            if not Missions.enabled() then
                audit.no_missions = true
                return
            end

            local hub = state.use_space_platform and state.space_platform.hub or state.nonspace_pad
            local inventory_type = state.use_space_platform and defines.inventory.hub_main or defines.inventory.cargo_landing_pad_main
            local hub_inventory = hub.get_inventory(inventory_type)
            local function deliver(tier, item, count, quality)
                while count > 0 do
                    local pod = assert(game.surfaces[state.active_surface_index].create_entity{
                        name = 'cargo-pod', position = {0, 0}, force = target
                    })
                    local inv = pod.get_inventory(defines.inventory.cargo_unit)
                    local inserted = inv.insert{name = item, count = count, quality = quality}
                    assert(inserted > 0, 'cargo insertion failed')
                    state.cargo_pods[pod.unit_number] = {pod = pod, tier = tier}
                    Missions.rocket_delivery(state, pod)
                    pod.destroy()
                    count = count - inserted
                end
            end

            -- Replay a mission already stuck with every requirement credited.
            -- Any following delivery should award its bonus and advance once.
            state.missions[4].level = 2
            state.missions[4].delivered = {}
            for key, count in pairs(Data.costs[4][2]) do state.missions[4].delivered[key] = count end
            local before = hub_inventory.get_item_count('space-science-pack')
            deliver(4, 'iron-plate', 1, 'normal')
            assert(state.missions[4].level == 3, 'completed mission remains stuck')
            assert(hub_inventory.get_item_count('space-science-pack') == before + 200, 'one-time reward missing')
            deliver(4, 'iron-plate', 1, 'normal')
            assert(hub_inventory.get_item_count('space-science-pack') == before + 200, 'one-time reward duplicated')
            write{kind = 'reward_pass', force = target, support = Missions.support_mode(state)}

            state.missions[10].level = 11
            state.missions[10].delivered = {}
            deliver(10, 'spidertron', 4, 'normal')
            assert(not next(state.missions[10].delivered), 'wrong quality credited')
            for key, count in pairs(Data.costs[10][11]) do
                if key ~= 'tree-seed|legendary' then
                    local item, quality = Missions.split_key(key)
                    deliver(10, item, count, quality)
                    assert(state.victory_tick == nil, 'premature victory')
                end
            end
            deliver(10, 'tree-seed', 9, 'legendary')
            assert(state.victory_tick == nil, 'incomplete final mission won')
            deliver(10, 'tree-seed', 1, 'legendary')
            assert(state.victory_tick ~= nil and state.missions[10].level == 12, 'victory not recorded')
            audit.victory_tick = state.victory_tick
            for _, task in pairs(state.schedule) do assert(task.event ~= 'map_reset', 'victory scheduled a reset') end
            -- Production should continue after victory.
            state.space_production = {['iron-plate|normal'] = 3}
            state.space_production_interval_ticks = 180
        end
        if audit.done or game.tick < math.max(audit.started + 7320, 10020) then return end
        assert(state.active_surface_index == audit.surface and game.surfaces[audit.surface], 'factory surface replaced')
        assert(state.reset_tick == audit.reset_tick, 'factory reset occurred')
        assert(audit.chest.valid and audit.chest.get_item_count('iron-plate') == 37, 'factory contents lost')
        assert(game.forces[target].technologies['automation'].researched, 'research lost')
        if not audit.no_missions then
            assert(state.missions[4].level == 3 and state.missions[10].level == 12, 'mission progress lost')
            assert(state.victory_tick == audit.victory_tick, 'victory marker changed')
            -- Repeated victory events must remain harmless.
            script.raise_event(state.events.victory, {force_name = target})
            assert(state.victory_tick == audit.victory_tick, 'repeated victory changed completion time')
            for _, task in pairs(state.schedule) do assert(task.event ~= 'map_reset', 'repeated victory scheduled reset') end
            local hub = state.use_space_platform and state.space_platform.hub or state.nonspace_pad
            local inv = hub.get_inventory(state.use_space_platform and defines.inventory.hub_main or defines.inventory.cargo_landing_pad_main)
            local before = inv.get_item_count('iron-plate')
            Missions.produce_space_goods(state)
            assert(inv.get_item_count('iron-plate') == before + 3, 'post-victory production stopped')
        end
        if mts then
            local other = Expanse.test_state('team-2')
            assert(other.active_surface_index == audit.other_surface and other.reset_tick == audit.other_reset_tick, 'other team reset')
        end
        write{kind = 'keep_playing_pass', force = target, tick = game.tick, upgraded = audit.upgraded == true}
        audit.done = true
    end)
    Event.on_configuration_changed(function()
        if storage.victory_test then storage.victory_test.upgraded = true end
    end)
end

return Public
