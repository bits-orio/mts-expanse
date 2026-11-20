-- Teleport a player's body, whatever view they are in.
--
-- Since Factorio 2.1, LuaPlayer.teleport on a player in remote view (the map)
-- moves only the camera: it returns true and the character stays where it
-- stood. A team reset has to move the body, or a player who was looking at the
-- map is left standing on the surface that is about to be deleted.

local Public = {}

local function body_is_on(player, surface)
    return player.physical_surface_index == surface.index
end

--- Move the player's body to `position` on `surface`.
--- Returns true only when the body is on `surface` afterwards.
function Public.to(player, position, surface)
    if player.controller_type == defines.controllers.remote then
        player.exit_remote_view()
    end
    if player.teleport(position, surface) and body_is_on(player, surface) then
        return true
    end
    -- Still in a view that keeps the body behind (a remote view the engine
    -- will not leave): move the character entity itself.
    local character = player.character
    if character and character.valid then
        character.teleport(position, surface)
    end
    return body_is_on(player, surface)
end

return Public
