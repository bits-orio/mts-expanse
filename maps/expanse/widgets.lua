-- Small GUI helpers shared by the mission windows and the reset dialog.
local Event = require 'utils.event'

local Public = {}

Public.GREEN = { 0.35, 0.85, 0.35 }
Public.RED = { 1, 0.45, 0.35 }
Public.GREY = { 0.6, 0.6, 0.6 }
Public.GOLD = { 1, 0.82, 0.4 }

-- Every clickable element of these windows carries tags[TAG] = <action>, so one
-- click handler per module serves them all and no element name has to be unique.
Public.TAG = 'expanse_ui'

function Public.label(parent, caption, font, color)
    local label = parent.add { type = 'label', caption = caption }
    if font then label.style.font = font end
    if color then label.style.font_color = color end
    label.style.single_line = false
    return label
end

function Public.heading(parent, caption)
    local label = Public.label(parent, caption, 'heading-2', Public.GOLD)
    label.style.top_margin = 8
    return label
end

function Public.column_headers(table_element, captions)
    for _, caption in ipairs(captions) do
        Public.label(table_element, caption, 'default-semibold', Public.GREY)
    end
end

-- Item icon with the engine's own tooltip. number is optional.
function Public.item_slot(parent, name, quality, number)
    return parent.add {
        type = 'sprite-button', sprite = 'item/' .. name, quality = quality, style = 'slot_button', number = number,
        elem_tooltip = { type = 'item-with-quality', name = name, quality = quality },
    }
end

function Public.pusher(parent)
    local pusher = parent.add { type = 'empty-widget' }
    pusher.style.horizontally_stretchable = true
    return pusher
end

function Public.close(player, name)
    local frame = player.gui.screen[name]
    if frame then frame.destroy() end
end

-- A screen window with a draggable title bar and a close button. It becomes
-- player.opened, so Escape and E close it like any built-in window.
function Public.window(player, name, title, width)
    Public.close(player, name)
    local frame = player.gui.screen.add { type = 'frame', name = name, direction = 'vertical', tags = { [Public.TAG] = 'window' } }
    local bar = frame.add { type = 'flow', direction = 'horizontal' }
    bar.drag_target = frame
    bar.style.horizontal_spacing = 8
    bar.add { type = 'label', caption = title, style = 'frame_title', ignored_by_interaction = true }
    local drag = bar.add { type = 'empty-widget', style = 'draggable_space_header', ignored_by_interaction = true }
    drag.style.horizontally_stretchable = true
    drag.style.height = 24
    bar.add { type = 'sprite-button', sprite = 'utility/close', style = 'close_button', tags = { [Public.TAG] = 'close', frame = name } }
    frame.style.width = width
    frame.auto_center = true
    player.opened = frame
    return frame
end

local function on_gui_click(event)
    local element = event.element
    if not (element and element.valid) then return end
    local tags = element.tags
    if tags[Public.TAG] == 'close' then
        Public.close(game.get_player(event.player_index), tags.frame)
    end
end

local function on_gui_closed(event)
    local element = event.element
    if element and element.valid and element.tags[Public.TAG] == 'window' then
        element.destroy()
    end
end

Event.add(defines.events.on_gui_click, on_gui_click)
Event.add(defines.events.on_gui_closed, on_gui_closed)

return Public
