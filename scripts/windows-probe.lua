-- Opens and operates the mod's windows with a real player: the mission board,
-- the silo side panel and the reset dialog. Loaded only into disposable test
-- profiles by scripts/test-windows.py, which runs the game in test mode
-- (Factorio 2.1.24 or newer), the one headless mode that has a player.
--
-- Clicks are sent through the mod's own event dispatcher, so every handler runs
-- exactly as it does for a mouse click.
local Event = require 'utils.event'
local Data = require 'maps.expanse.mission_data'
local Model = require 'maps.expanse.missions.model'
local Board = require 'maps.expanse.missions.board'
local SiloPanel = require 'maps.expanse.missions.silo_panel'
local ForfeitDialog = require 'maps.expanse.forfeit_dialog'
local W = require 'maps.expanse.widgets'
local Public = {}

local TIER, LEVEL = 4, 2
local START = 120
local FORFEIT_TAG = 'expanse_forfeit'

local function dispatch(event_id, fields)
    fields.name, fields.tick = event_id, game.tick
    script.get_event_handler(event_id)(fields)
end

local function click(element)
    dispatch(defines.events.on_gui_click, { player_index = element.player_index, element = element,
        button = defines.mouse_button_type.left, alt = false, control = false, shift = false, cursor_display_location = { x = 0, y = 0 } })
end

local function type_text(field, text)
    field.text = text
    dispatch(defines.events.on_gui_text_changed, { player_index = field.player_index, element = field, text = text })
end

-- First element under root for which test(element) is true, depth first.
local function find(root, test)
    if test(root) then return root end
    for _, child in pairs(root.children) do
        local found = find(child, test)
        if found then return found end
    end
    return nil
end

local function tagged(key, value, extra)
    return function(element)
        local tags = element.tags
        return tags[key] == value and (not extra or tags[extra[1]] == extra[2])
    end
end

local function build_silo(state, surface, force)
    surface.request_to_generate_chunks({ 50, 50 }, 2)
    surface.force_generate_chunk_requests()
    local tiles = {}
    for x = 30, 70 do for y = 30, 70 do tiles[#tiles + 1] = { name = 'grass-1', position = { x, y } } end end
    surface.set_tiles(tiles)
    for _, entity in pairs(surface.find_entities_filtered { area = { { 30, 30 }, { 70, 70 } } }) do
        if entity.type ~= 'character' then entity.destroy() end
    end
    local silo = assert(surface.create_entity { name = 'rocket-silo', position = { 50, 50 }, force = force })
    silo.minable_flag = false
    silo.destructible = false
    state.rocket_silos[silo.unit_number] = { entity = silo, tier = TIER }
    return silo
end

function Public.install(Expanse)
    local function check(name, ok)
        local test = storage.windows_test
        test.checks[name] = ok and true or false
        if not ok then log('WINDOWS_TEST FAIL ' .. name) end
    end

    local function state_and_player()
        return Expanse.test_state('player'), game.players[1]
    end

    -- One mission in each state the board can show.
    local function setup()
        local state, player = state_and_player()
        storage.windows_test = { checks = {} }
        check('test_mode_has_a_connected_player', player and player.connected)
        local surface = game.surfaces[state.active_surface_index]
        storage.windows_test.silo = build_silo(state, surface, player.force)
        -- A character opens a machine only within reach.
        player.teleport({ 43, 50 }, surface)
        state.missions[TIER] = { level = LEVEL, delivered = {} }
        state.missions[5] = { level = 1, delivered = {} }
        state.missions[6] = { level = 0, delivered = {} }
        state.missions[7] = { level = Model.step_count(7) + 1, delivered = {} }
    end

    local function board()
        local state, player = state_and_player()
        Board.open(player, state)
        local frame = player.gui.screen[Board.FRAME]
        check('board_opens_as_the_players_window', frame and player.opened == frame)
        local expected = { [TIER] = 'active', [5] = 'nosilo', [6] = 'locked', [7] = 'done' }
        for tier, status in pairs(expected) do
            check('board_state_' .. status, Model.stage(state, tier).status == status)
        end
        -- Entry 0 is "What you receive"; the others are the seven missions.
        for _, entry in ipairs({ 0, 4, 5, 6, 7, 8, 9, 10 }) do
            click(find(frame, tagged(W.TAG, 'select', { 'entry', entry })))
            check('board_shows_entry_' .. entry, frame.valid and frame.tags.selected == entry and #frame.body.children == 2)
        end
        -- The longest step of all missions still leaves the window on the screen.
        do
            local long_tier, long_level, most = TIER, LEVEL, 0
            for tier, levels in pairs(Data.costs) do
                for level = 1, Model.step_count(tier) do
                    local kinds = 0
                    for _ in pairs(levels[level]) do kinds = kinds + 1 end
                    if kinds > most then long_tier, long_level, most = tier, level, kinds end
                end
            end
            local saved = state.missions[long_tier]
            state.missions[long_tier] = { level = long_level, delivered = {} }
            click(find(frame, tagged(W.TAG, 'select', { 'entry', long_tier })))
            check('longest_step_scrolls_inside_the_window', find(frame, function(e) return e.type == 'scroll-pane' end) ~= nil and most > 15)
            state.missions[long_tier] = saved
        end
        click(find(frame, tagged(W.TAG, 'select', { 'entry', TIER })))
        click(find(frame, tagged(W.TAG, 'pin_silo')))
        local pins = player.get_pins()
        check('pin_button_pins_the_silo', #pins == 1 and pins[1].label == 'Atlas mission silo')
        local button = find(frame, tagged(W.TAG, 'pin_silo'))
        check('pin_button_offers_removal', button.caption[1] == 'expanse-missions.unpin_silo')
        click(button)
        check('pin_button_removes_the_pin', #player.get_pins() == 0)
        click(find(frame, tagged(W.TAG, 'close')))
        check('board_close_button_closes', player.gui.screen[Board.FRAME] == nil)
        Board.open(player, state)
        player.opened = nil
    end

    local function open_silo()
        local _, player = state_and_player()
        check('escape_closes_the_board', player.gui.screen[Board.FRAME] == nil)
        player.opened = storage.windows_test.silo
    end

    local function silo_panel()
        local state, player = state_and_player()
        local test = storage.windows_test
        local data = state.rocket_silos[test.silo.unit_number]
        local frame = player.gui.relative[SiloPanel.FRAME]
        check('silo_panel_opens_with_the_silo', frame ~= nil)
        if not frame then return end
        local needed = frame.inner.needed
        local kinds = 0
        for _ in pairs(Data.costs[TIER][LEVEL]) do kinds = kinds + 1 end
        check('silo_panel_lists_every_needed_item', needed and #needed.children == kinds)
        local slot = needed.children[1]
        check('slot_shows_still_to_launch_and_in_chest', slot.number > 0 and slot.secondary_number == 0)
        check('launch_is_off_without_a_rocket', frame.inner.launch.enabled == false)
        check('silo_panel_shows_the_cargo_chest', find(frame, function(e) return e.type == 'inventory' end) ~= nil)
        local name, quality = Model.split_key(slot.name)
        check('cargo_chest_takes_the_item', data.cargo_chest.insert { name = name, quality = quality, count = 3 } == 3)
        test.slot = slot
    end

    local function silo_panel_updates()
        local state, player = state_and_player()
        local test = storage.windows_test
        local slot = test.slot
        -- Same element as before: the number was written into the open panel.
        check('slot_number_follows_the_chest_in_place', slot and slot.valid and slot.secondary_number == 3)
        -- Shift-click on the chest slot inside the panel: the stack goes to the player.
        local name = Model.split_key(slot.name)
        local slots = find(player.gui.relative[SiloPanel.FRAME], function(e) return e.type == 'inventory' end)
        local before = player.get_main_inventory().get_item_count(name)
        dispatch(defines.events.on_gui_inventory_action, { player_index = player.index, element = slots, slot = 1,
            action = defines.inventory_actions.stack_transfer, button = defines.mouse_button_type.left, alt = false, control = false, shift = true })
        local chest = state.rocket_silos[test.silo.unit_number].cargo_chest
        check('shift_click_moves_the_stack_to_the_player', chest.get_item_count(name) == 0 and player.get_main_inventory().get_item_count(name) == before + 3)
        player.opened = nil
    end

    local function reset_dialog()
        local _, player = state_and_player()
        check('closing_the_silo_removes_its_panel', player.gui.relative[SiloPanel.FRAME] == nil)
        ForfeitDialog.open(player)
        local frame = player.gui.screen[ForfeitDialog.FRAME]
        check('reset_dialog_opens', frame ~= nil)
        local confirm, field = frame.buttons.confirm, frame.content.confirm_text
        check('reset_button_starts_disabled', confirm.enabled == false)
        type_text(field, 'yes')
        check('reset_button_stays_off_for_another_word', confirm.enabled == false)
        type_text(field, 'reset')
        check('reset_button_works_after_the_word', confirm.enabled == true)
        click(find(frame, tagged(FORFEIT_TAG, 'cancel')))
        check('keep_playing_closes_the_dialog', player.gui.screen[ForfeitDialog.FRAME] == nil)
    end

    local function finish()
        local test = storage.windows_test
        local passed = true
        for _, ok in pairs(test.checks) do passed = passed and ok end
        helpers.write_file('windows-result.json', helpers.table_to_json(test.checks), false)
        log('WINDOWS_TEST DONE ' .. (passed and 'pass' or 'fail'))
        script.finish_test(passed)
    end

    -- The cargo station appears with the first mission tick after the silo
    -- exists, and the open panel refreshes once a second, so those steps wait.
    local steps = {
        [START] = setup,
        [START + 90] = board,
        [START + 92] = open_silo,
        [START + 94] = silo_panel,
        [START + 220] = silo_panel_updates,
        [START + 222] = reset_dialog,
        [START + 224] = finish,
    }
    Event.add(defines.events.on_tick, function()
        local step = steps[game.tick]
        if step then step() end
    end)
end

return Public
