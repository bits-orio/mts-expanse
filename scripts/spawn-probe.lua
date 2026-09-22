-- Installed only into disposable test copies by test-spawn.py.
local Event = require 'utils.event'
local Functions = require 'maps.expanse.functions'
local Public = {}

function Public.install(Expanse, upgrade)
    Event.on_init(function()
        Expanse.reset('team-17')
        Expanse.reset('team-18')
        if upgrade then
            local state = Expanse.test_state('team-17')
            local other = Expanse.test_state('team-18')
            local surface = game.surfaces[state.active_surface_index]
            Functions.expand(state, {x = 15, y = 0})
            state.size = state.size + 1
            state.missions[4].level = 3
            game.forces['team-17'].technologies.automation.researched = true
            local pos = assert(surface.find_non_colliding_position('steel-chest', {7,7}, 100, 1))
            local chest = assert(surface.create_entity{name='steel-chest', position=pos, force='team-17'})
            chest.insert{name='iron-plate', count=37}
            storage.spawn_upgrade = {surface=surface, size=state.size, chest=chest,
                other_surface=game.surfaces[other.active_surface_index]}
            state.active_surface_index = state.nonspace_pad and state.nonspace_pad.surface.index or other.active_surface_index
        end
    end)
    Event.on_nth_tick(30, function()
        if storage.spawn_probe_done then return end
        if upgrade then
            local fixture = storage.spawn_upgrade
            local state = Expanse.test_state('team-17')
            local result = {checks={
                upgraded_from_0_1_15 = script.active_mods['mts-expanse'] ~= '0.1.15',
                gameplay_recovered = fixture.surface.valid and state.active_surface_index == fixture.surface.index,
                factory_preserved = fixture.chest.valid and fixture.chest.get_item_count('iron-plate') == 37,
                progress_preserved = state.size == fixture.size and state.grid['15_0'] and state.missions[4].level == 3,
                research_preserved = game.forces['team-17'].technologies.automation.researched,
                other_team_preserved = fixture.other_surface.valid,
            }}
            helpers.write_file('spawn-result.json', helpers.table_to_json(result))
            storage.spawn_probe_done = true
            return
        end
        local state = Expanse.test_state('team-17')
        local other = Expanse.test_state('team-18')
        local other_surface = game.surfaces[other.active_surface_index]
        local other_size = other.size
        if not storage.spawn_probe_old_index then
            storage.spawn_probe_old_index = state.active_surface_index
            -- Deletion completes at the end of the tick, as on a real MTS disband.
            local deleted = {}
            for _, surface in pairs(game.surfaces) do
                if surface.name:match('^team%-17%-') then deleted[#deleted + 1] = surface end
            end
            for _, surface in ipairs(deleted) do game.delete_surface(surface) end
            return
        end
        storage.spawn_probe_done = true
        local old_index = storage.spawn_probe_old_index
        -- An ordinary mod upgrade must not re-create NonOrbit for a retired team.
        Expanse.test_configuration_changed({})
        local after_upgrade = game.surfaces[old_index]
        local reused_by = after_upgrade and after_upgrade.name or 'none'
        state = Expanse.test_state('team-17')
        Expanse.test_ensure_state(state)
        local active = game.surfaces[state.active_surface_index]
        local expected = script.active_mods['space-age'] and 'team-17-expanse' or 'team-17-nauvis'
        local result = {
            reused_index = old_index,
            reused_by_after_upgrade = reused_by,
            active_name = active and active.name,
            checks = {
                proper_gameplay_surface = active and active.name:sub(1, #expected) == expected,
                gameplay_is_not_support = active and active.name ~= state.nonspace_surface,
                starting_oil = active and active.count_entities_filtered{name='crude-oil'} > 0,
            other_team_preserved = other_surface.valid and other.active_surface_index == other_surface.index and other.size == other_size,
            }
        }
        local checks = result.checks
        checks.no_retired_support_recreated = reused_by == 'none'
        -- Recover a wrong index when the actual world still exists. Its contents,
        -- research, missions, and expansion progress must survive, including reload.
        Functions.expand(state, {x = 15, y = 0})
        state.size = state.size + 1
        state.missions[4].level = 3
        local force = game.forces['team-17']
        force.technologies.automation.researched = true
        local pos = assert(active.find_non_colliding_position('steel-chest', {7, 7}, 100, 1))
        local chest = assert(active.create_entity{name='steel-chest', position=pos, force=force})
        chest.insert{name='iron-plate', count=37}
        local size = state.size
        state.overlay = {cells=rendering.draw_text{text='stale', color={1,1,1}, surface=other_surface, target={0,0}}}
        local old_overlay = state.overlay.cells
        state.active_surface_index = other_surface.index
        Expanse.test_configuration_changed({})
        checks.existing_factory_preserved = active.valid and state.active_surface_index == active.index
            and chest.valid and chest.get_item_count('iron-plate') == 37
            and state.size == size and state.grid['15_0'] and state.missions[4].level == 3
            and force.technologies.automation.researched
        checks.wrong_surface_overlay_removed = not old_overlay.valid
        checks.foreign_world_not_deleted = other_surface.valid
        -- Exercise the actual public MTS lifecycle event, not just a direct helper.
        local root = Expanse.test_root()
        root.pending_player_teleports[999999] = {force_name='team-17', tick=game.tick+10}
        root.object_to_force[999999] = 'team-17'
        script.raise_event(remote.call('mts-v1', 'get_event_id', 'on_team_released'), {force_name='team-17'})
        checks.released_state_removed = root.team_states['team-17'] == nil
            and root.pending_player_teleports[999999] == nil and root.object_to_force[999999] == nil
        checks.release_keeps_other_team = root.team_states['team-18'] == other and other_surface.valid
        helpers.write_file('spawn-result.json', helpers.table_to_json(result))
    end)
end
return Public
