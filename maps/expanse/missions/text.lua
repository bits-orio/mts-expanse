-- Localised wording shared by the mission GUIs and chat lines.
local Model = require 'maps.expanse.missions.model'

local Public = {}

-- Joins localised strings with a separator. A localised string holds at most 20
-- parameters, so long lists are nested in groups.
function Public.join(parts, separator)
    if #parts == 0 then return '' end
    local groups, group = {}, { '' }
    for index, part in ipairs(parts) do
        if index > 1 then group[#group + 1] = separator end
        group[#group + 1] = part
        if #group >= 19 then
            groups[#groups + 1] = group
            group = { '' }
        end
    end
    if #group > 1 then groups[#groups + 1] = group end
    if #groups == 1 then return groups[1] end
    table.insert(groups, 1, '')
    return #groups <= 20 and groups or Public.join(groups, '')
end

function Public.item_name(name, quality)
    local item = prototypes.item[name].localised_name
    if quality and quality ~= 'normal' then
        return { 'expanse-missions.item_with_quality', item, prototypes.quality[quality].localised_name }
    end
    return item
end

local function sorted_keys(tbl)
    local keys = {}
    for key in pairs(tbl or {}) do keys[#keys + 1] = key end
    table.sort(keys)
    return keys
end

local function research_lines(lines, research, short)
    for _, tech in ipairs(sorted_keys(research)) do
        local progress = research[tech]
        local name = prototypes.technology[tech].localised_name
        if progress >= 1 then
            lines[#lines + 1] = { 'expanse-missions.reward_research' .. short, tech, name }
        else
            lines[#lines + 1] = { 'expanse-missions.reward_research_part' .. short, tech, name, math.floor(progress * 100 + 0.5) }
        end
    end
end

local function item_lines(lines, rewards, locale_key, interval)
    for _, key in ipairs(sorted_keys(rewards)) do
        local name, quality = Model.split_key(key)
        lines[#lines + 1] = { locale_key, name, quality, rewards[key], Public.item_name(name, quality), interval }
    end
end

-- Chat wording: all produced items as icons with one interval behind them.
local function production_summary(lines, production, interval)
    local parts = {}
    item_lines(parts, production, 'expanse-missions.reward_item_short')
    if #parts > 0 then
        lines[#lines + 1] = { 'expanse-missions.reward_production_short', Public.join(parts, ' '), interval }
    end
end

-- "every minute", or the configured production interval in seconds.
function Public.interval(state)
    local ticks = state.space_production_interval_ticks or 3600
    if ticks == 3600 then return { 'expanse-missions.interval_minute' } end
    return { 'expanse-missions.interval_seconds', math.floor(ticks / 60 + 0.5) }
end

-- One sentence per reward of a step, for the board. short = true gives the
-- compact wording used in chat.
function Public.reward_lines(state, rewards, short)
    local lines = {}
    if not rewards then return lines end
    short = short and '_short' or ''
    research_lines(lines, rewards.research, short)
    if short == '' then
        item_lines(lines, rewards.production, 'expanse-missions.reward_production', Public.interval(state))
    else
        production_summary(lines, rewards.production, Public.interval(state))
    end
    item_lines(lines, rewards.once, 'expanse-missions.reward_once' .. short)
    local script_reward = rewards.script or {}
    if script_reward['new-ship'] then
        lines[#lines + 1] = { 'expanse-missions.reward_ship' .. short, script_reward['new-ship'] }
    end
    if script_reward.victory then
        lines[#lines + 1] = { 'expanse-missions.reward_victory' .. short }
    end
    return lines
end

return Public
