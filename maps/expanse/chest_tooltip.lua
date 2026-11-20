-- What a hungry chest still wants, as a line in the chest's hover tooltip. The
-- counts under the icons say how many; this adds the item names, in map view
-- too.
local Text = require 'maps.expanse.missions.text'

local Public = {}

local FIELD = 1

-- price is the chest's list of { name, quality, count }.
function Public.set(entity, price)
    if #price == 0 then
        entity.clear_tooltip_fields()
        return
    end
    local parts = {}
    for index, item in ipairs(price) do
        parts[index] = { 'expanse.tip_wanted_item', item.name, item.quality or 'normal', item.count,
            Text.item_name(item.name, item.quality) }
    end
    -- order 1 puts the line above the game's own rows instead of below them.
    entity.set_tooltip_field { id = FIELD, order = 1, name = { 'expanse.tip_wanted' }, value = Text.join(parts, ',  ') }
end

return Public
