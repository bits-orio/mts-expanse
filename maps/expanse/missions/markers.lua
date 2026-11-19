-- Marks mission silos and the landing pad where players look: a name and a
-- status line over each silo (no Alt mode needed) and a tag on the map.
local MissionData = require 'maps.expanse.mission_data'
local Model = require 'maps.expanse.missions.model'
local Ships = require 'maps.expanse.missions.ships'

local Public = {}

local GOLD = { 1, 0.82, 0.4 }
local WHITE = { 1, 1, 1 }
-- A silo is 9 tiles tall; the two lines sit just above its top edge.
local TITLE_OFFSET = { 0, -6.2 }
local STATUS_OFFSET = { 0, -5.2 }

local function status_text(state, data, stage)
    if stage.status == 'locked' then
        local tech = MissionData.mission_unlocks[data.tier]
        return { 'expanse-missions.label_locked', prototypes.technology[tech].localised_name }
    elseif stage.status == 'done' then
        return { 'expanse-missions.label_done' }
    end
    local weight = Model.inventory_weight(Model.rocket_inventory(data.entity))
    return { 'expanse-missions.label_active', stage.step, stage.steps, Ships.format_weight(weight) }
end

local function draw(silo, text, offset, color, scale)
    return rendering.draw_text { text = text, surface = silo.surface, target = { entity = silo, offset = offset },
        color = color, scale = scale, alignment = 'center' }
end

-- Releases up to 0.1.23 drew a grey tier number that only showed in Alt mode.
local function drop_legacy_renders(data)
    for _, render in pairs(data.renders or {}) do
        if render.valid then render.destroy() end
    end
    data.renders = nil
end

local function refresh_label(state, data)
    local silo = data.entity
    local stage = Model.stage(state, data.tier)
    local text = status_text(state, data, stage)
    -- Render objects die with the entity they hang on, e.g. after a silo repair.
    if not (data.title_label and data.title_label.valid and data.status_label and data.status_label.valid) then
        data.title_label = draw(silo, { 'expanse-missions.label_title', Ships.by_tier[data.tier].name }, TITLE_OFFSET, GOLD, 2)
        data.status_label = draw(silo, text, STATUS_OFFSET, WHITE, 1.3)
        data.status_key = nil
    end
    local key = stage.status .. stage.step .. (text[4] or '')
    if data.status_key ~= key then
        data.status_label.text = text
        data.status_key = key
    end
end

-- add_chart_tag returns nil until the team has charted the chunk, so this is
-- simply tried again on the next refresh.
local function ensure_tag(force, entity, current, icon, text)
    if current and current.valid then return current end
    return force.add_chart_tag(entity.surface, { position = entity.position, icon = { type = 'item', name = icon }, text = text })
end

-- Once a second per team, from the same tick that checks rockets. Rocket cargo
-- changes without an event, so the status line cannot be purely event-driven.
function Public.refresh(state)
    local force = game.forces[state.force_name or 'player']
    if not (force and force.valid) then return end
    for _, data in pairs(state.rocket_silos or {}) do
        if data.entity and data.entity.valid then
            drop_legacy_renders(data)
            refresh_label(state, data)
            data.chart_tag = ensure_tag(force, data.entity, data.chart_tag, 'rocket-silo', Ships.by_tier[data.tier].name .. ' mission silo')
        end
    end
    local pad = state.landing_pad
    if pad and pad.valid then
        state.landing_pad_tag = ensure_tag(force, pad, state.landing_pad_tag, 'cargo-landing-pad', 'Mission rewards land here')
    end
end

return Public
