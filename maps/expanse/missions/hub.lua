-- Entry point for the mission UI and cargo stations. main.lua holds the team
-- state and calls in here; the lookups it needs are injected at load time so
-- this module never requires main.lua.
local Event = require 'utils.event'
local ExpanseEvents = require 'maps.expanse.events'
local SpaceMissions = require 'maps.expanse.space_missions'
local Board = require 'maps.expanse.missions.board'
local Cargo = require 'maps.expanse.missions.cargo'
local Markers = require 'maps.expanse.missions.markers'
local SiloPanel = require 'maps.expanse.missions.silo_panel'
local W = require 'maps.expanse.widgets'

local Public = { board = Board, cargo = Cargo }

local lookups = {}

-- lookups.state_from_player(player) -> the team state a player acts on, or nil.
function Public.inject(injected)
    lookups = injected
end

-- Once a second per team state, from main.lua's state tick.
function Public.tick(state)
    if not SpaceMissions.enabled() then return end
    for _, data in pairs(state.rocket_silos or {}) do
        Cargo.tick(state, data)
    end
    Markers.refresh(state)
    local force = game.forces[state.force_name or 'player']
    if force and force.valid then
        SiloPanel.refresh_open(state, force.connected_players)
    end
end

local function launch(state, unit_number)
    local data = state.rocket_silos and state.rocket_silos[unit_number]
    if data and data.entity and data.entity.valid then
        SpaceMissions.launch_silo(state, data.entity)
    end
end

local ACTIONS = {
    select = function(player, state, tags) Board.refresh(player, state, tags.entry) end,
    show_silo = function(player, state, tags) Board.show_silo(player, state, tags.tier) end,
    launch = function(_, state, tags) launch(state, tags.unit) end,
}

local function on_gui_click(event)
    local element = event.element
    if not (element and element.valid) then return end
    local tags = element.tags
    local action = ACTIONS[tags[W.TAG]]
    if not action then return end
    local player = game.get_player(event.player_index)
    local state = lookups.state_from_player(player)
    if state then action(player, state, tags) end
end

local function on_gui_opened(event)
    if not SpaceMissions.enabled() then return end
    local player = game.get_player(event.player_index)
    SiloPanel.show(player, lookups.state_from_player(player), event.entity)
end

local function on_gui_closed(event)
    if event.entity then SiloPanel.close(game.get_player(event.player_index)) end
end

-- A delivery, an unlock or a reset changed a mission: redraw what is open.
local function on_mission_update(event)
    for _, player in pairs(game.connected_players) do
        if not SpaceMissions.enabled() then
            Board.close(player)
        elseif Board.is_open(player) then
            local state = lookups.state_from_player(player)
            if state and (not event.force_name or event.force_name == state.force_name) then
                Board.refresh(player, state)
            end
        end
    end
end

Event.add(defines.events.on_gui_click, on_gui_click)
Event.add(defines.events.on_gui_opened, on_gui_opened)
Event.add(defines.events.on_gui_closed, on_gui_closed)
Event.add(ExpanseEvents.mission_gui_update, on_mission_update)

return Public
