-- The "Reset your base?" dialog. One step: it lists what a reset removes and
-- what it keeps, and the red button only works after the word RESET is typed.
local Event = require 'utils.event'
local W = require 'maps.expanse.widgets'

local Public = { FRAME = 'expanse_forfeit_dialog' }

local CONFIRM_WORD = 'RESET'
local WIDTH = 470
-- Own tag key, so these buttons never reach another module's click handler.
local TAG = 'expanse_forfeit'

local on_confirm

-- callback(player) runs the reset. Injected by main.lua, which owns the state.
function Public.inject(callback)
    on_confirm = callback
end

function Public.close(player)
    W.close(player, Public.FRAME)
end

local function typed_confirm_word(frame)
    local text = frame.content.confirm_text.text
    return text:match('^%s*(.-)%s*$'):upper() == CONFIRM_WORD
end

local function buttons(frame)
    local flow = frame.add { type = 'flow', name = 'buttons', direction = 'horizontal' }
    flow.style.top_margin = 8
    flow.add { type = 'button', caption = { 'expanse.forfeit_cancel' }, style = 'back_button', tags = { [TAG] = 'cancel' } }
    W.pusher(flow)
    local confirm = flow.add { type = 'button', name = 'confirm', caption = { 'expanse.forfeit_confirm' }, style = 'red_confirm_button',
        tags = { [TAG] = 'confirm' } }
    confirm.enabled = false
end

-- death_count is set when the dialog opens by itself after repeated deaths.
function Public.open(player, death_count)
    local frame = W.window(player, Public.FRAME, { 'expanse.forfeit_title' }, WIDTH)
    local content = frame.add { type = 'frame', name = 'content', direction = 'vertical', style = 'inside_shallow_frame_with_padding' }
    if death_count then
        W.label(content, { 'expanse.forfeit_auto_reason', death_count }, nil, W.GOLD)
    end
    W.label(content, { 'expanse.forfeit_removed' })
    W.label(content, { 'expanse.forfeit_kept' }).style.top_margin = 6
    W.label(content, { 'expanse.forfeit_no_undo' }, 'default-bold').style.top_margin = 6
    W.label(content, { 'expanse.forfeit_type', CONFIRM_WORD }, nil, W.GREY).style.top_margin = 6
    local field = content.add { type = 'textfield', name = 'confirm_text', text = '', tags = { [TAG] = 'text' } }
    field.style.width = 160
    buttons(frame)
    field.focus()
end

local function dialog_of(event)
    local element = event.element
    if not (element and element.valid and element.tags[TAG]) then return nil end
    local player = game.get_player(event.player_index)
    return player, player.gui.screen[Public.FRAME], element.tags[TAG]
end

local function confirm(player, frame)
    if not typed_confirm_word(frame) then return end
    Public.close(player)
    if on_confirm then on_confirm(player) end
end

local function on_gui_click(event)
    local player, frame, action = dialog_of(event)
    if not frame then return end
    if action == 'cancel' then
        Public.close(player)
    elseif action == 'confirm' then
        confirm(player, frame)
    end
end

local function on_gui_text_changed(event)
    local _, frame, action = dialog_of(event)
    if frame and action == 'text' then
        frame.buttons.confirm.enabled = typed_confirm_word(frame)
    end
end

-- Enter in the text box confirms, the same as the red button.
local function on_gui_confirmed(event)
    local player, frame, action = dialog_of(event)
    if frame and action == 'text' then confirm(player, frame) end
end

Event.add(defines.events.on_gui_click, on_gui_click)
Event.add(defines.events.on_gui_text_changed, on_gui_text_changed)
Event.add(defines.events.on_gui_confirmed, on_gui_confirmed)

return Public
