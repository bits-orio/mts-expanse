-- The items a new player starts with, handed out again after a base reset.
--
-- The list comes from whoever owns it: Multi-Team Support's starter items when
-- it runs (the list its admins edit, which also holds what starter mods such as
-- FasterStart gave), otherwise the freeplay scenario's, otherwise the base
-- game's own start.
local Public = {}

local MTS_INTERFACE = 'mts-v1'
local VANILLA = {
    { name = 'iron-plate', count = 8 }, { name = 'wood', count = 1 }, { name = 'pistol', count = 1 },
    { name = 'firearm-magazine', count = 10 }, { name = 'burner-mining-drill', count = 1 }, { name = 'stone-furnace', count = 1 },
}

local function from_interface(name, method)
    local interface = remote.interfaces[name]
    return interface and interface[method] and remote.call(name, method) or nil
end

-- Entries are { name, count, quality, scope, grid }. scope 'team' marks an
-- entry a team gets once; grid is the equipment of an armor.
function Public.items()
    local items = from_interface(MTS_INTERFACE, 'get_starter_items')
    if items and #items > 0 then return items end
    local created = from_interface('freeplay', 'get_created_items')
    if created and next(created) then
        items = {}
        for name, count in pairs(created) do items[#items + 1] = { name = name, count = count } end
        table.sort(items, function(a, b) return a.name < b.name end)
        return items
    end
    return VANILLA
end

-- One armor with its equipment, worn when the armor slot is free. Returns
-- false when it found no free slot.
local function insert_with_grid(owner, item)
    local spec = { name = item.name, count = 1, quality = item.quality }
    local armor = owner.get_inventory(defines.inventory.character_armor)
    local stack = armor and armor.is_empty() and armor.can_insert(spec) and armor[1]
    if not stack then
        local main = owner.get_main_inventory()
        stack = main and main.find_empty_stack()
    end
    if not (stack and stack.set_stack(spec)) then return false end
    for _, equipment in pairs(stack.grid and item.grid or {}) do
        -- An equipment prototype can be gone after a mod change; the rest still goes in.
        if prototypes.equipment[equipment.name] then
            local placed = stack.grid.put { name = equipment.name, position = equipment.position, quality = equipment.quality }
            if placed and equipment.energy then placed.energy = equipment.energy end
        end
    end
    return true
end

-- owner is a player or a character. with_team_items also hands over the
-- entries a team gets once.
function Public.give(owner, with_team_items)
    for _, item in pairs(Public.items()) do
        local count = item.count or 1
        if prototypes.item[item.name] and count > 0 and (with_team_items or item.scope ~= 'team') then
            if item.grid and insert_with_grid(owner, item) then count = count - 1 end
            if count > 0 then owner.insert { name = item.name, count = count, quality = item.quality } end
        end
    end
end

-- Gives every player of the list a kit. The team's one-time entries go to
-- preferred when that player is on the list, otherwise to the first player
-- who is online.
function Public.restore(players, preferred)
    local receivers, team_receiver = {}, nil
    for _, player in pairs(players) do
        -- Not player.character: that is nil while a player looks around in
        -- remote view, and such a player still has a body with an inventory.
        if player.valid and player.get_main_inventory() then
            receivers[#receivers + 1] = player
            if player == preferred or (player.connected and not team_receiver) then team_receiver = player end
        end
    end
    team_receiver = team_receiver or receivers[1]
    for _, player in ipairs(receivers) do Public.give(player, player == team_receiver) end
    return #receivers
end

return Public
