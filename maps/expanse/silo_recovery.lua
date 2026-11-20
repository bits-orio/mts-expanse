local Public = {}

function Public.is_broken(silo)
    return silo and silo.valid
        and silo.rocket_silo_status == defines.rocket_silo_status.rocket_ready
        and not (silo.rocket and silo.rocket.valid)
end

local function move_inventory(from, to)
    if #to < #from then
        -- A rocket's inventory has no fixed slots: it grows with its cargo and
        -- is limited by weight alone, so the stacks are handed over whole.
        to.transfer_from_inventory(from)
        return
    end
    for i = 1, #from do
        to[i].swap_stack(from[i])
        if from.supports_filters() then to.set_filter(i, from.get_filter(i)) end
    end
    if from.supports_bar() then to.set_bar(from.get_bar()) end
end

function Public.rebuild(silo)
    if not Public.is_broken(silo) then return nil end
    -- A deleted rocket leaves the native silo permanently in rocket_ready.
    -- Changing recipes/parts or cloning it preserves that broken native state.
    -- Create the replacement before touching the original's contents.
    local replacement = silo.surface.create_entity {
        name = silo.name, position = silo.position, force = silo.force,
        quality = silo.quality, direction = silo.direction,
        create_build_effect_smoke = false
    }
    if not replacement then return nil end
    replacement.copy_settings(silo)
    for _, property in ipairs({'health', 'energy', 'destructible', 'minable_flag',
        'operable', 'rotatable', 'disabled_by_script', 'use_transitional_requests'}) do
        replacement[property] = silo[property]
    end
    for _, id in ipairs({defines.inventory.crafter_input, defines.inventory.crafter_output,
        defines.inventory.crafter_modules, defines.inventory.rocket_silo_rocket,
        defines.inventory.rocket_silo_trash}) do
        local from, to = silo.get_inventory(id), replacement.get_inventory(id)
        if from and to then move_inventory(from, to) end
    end
    -- rocket_parts counts the buffered next rocket separately from the missing
    -- prepared one. Starting a fresh launch cycle consumes exactly one set.
    replacement.rocket_parts = silo.rocket_parts + silo.prototype.rocket_parts_required
    replacement.crafting_progress = silo.crafting_progress
    replacement.bonus_progress = silo.bonus_progress
    for id, connector in pairs(silo.get_wire_connectors(false)) do
        local new_connector = replacement.get_wire_connector(id, true)
        for _, wire in pairs(connector.connections) do
            new_connector.connect_to(wire.target, false, wire.origin)
        end
    end
    for _, player in pairs(game.players) do
        if player.opened == silo then player.opened = replacement end
    end
    silo.destroy()
    return replacement
end

return Public
