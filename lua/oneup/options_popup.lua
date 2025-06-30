local Popup = require("oneup.popup")

---@alias Option { text: string, [any]: any }

---@class OptionsPopup: Popup
---@field options Option[]
local OptionsPopup = {}
OptionsPopup.__index = OptionsPopup
setmetatable(OptionsPopup, Popup)

---@class OptionsPopupOpts
---@field title string?         the title to display on the popup, useless if border is not true
---@field options Option[]      A list of options that may be selected from
---@field width string?         the width of the popup (may be a percent) sets width based on text if nil
---@field height string?        the height of the popup (may be a percent) sets height based on text if nil
---@field min_width integer?    the absolute minimum width for the popup. useless if width is not a percentage
---@field min_height integer?   the absolute minimum height for the popup. useless if height is not a percentage
---@field border boolean?       border?
---@field persistent boolean?   Whether or not the popup will persist once window has been exited
---@field on_close function?    function to run when the popup is closed

---@param opts OptionsPopupOpts the options for the given popup
---@param enter boolean whether or not to immediately focus the popup
function OptionsPopup:new(opts, enter)
    local menuText = {}
    for _, option in pairs(opts.options) do
        table.insert(menuText, option.text)
    end

    --@type PopupOpts
    local popupOpts = {
        text = menuText,
        focusable = true,
        modifiable = false,

        title = opts.title,
        width = opts.width,
        height = opts.height,
        min_width = opts.min_width,
        min_height = opts.min_height,
        border = opts.border,
        persistent = opts.persistent,
        on_close = opts.on_close,
    }

    ---@class OptionsPopup
    local p = Popup:new(popupOpts, enter)
    p.options = opts.options

    local ns = vim.api.nvim_create_namespace("oneup_menu")

    vim.api.nvim_set_option_value(
        "cursorline",
        true,
        {
           win = p:win_id()
        }
    )

    vim.api.nvim_set_hl(
        ns,
        "CursorLine",
        { link = "Visual" }
    )

    vim.api.nvim_win_set_hl_ns(p:win_id(), ns)

    setmetatable(p, self)

    return p
end

---returns the currently selected option in the popup. useful for keybinds
---@return table option
function OptionsPopup:get_option()
    return self.options[vim.api.nvim_win_get_cursor(0)[1]]
end

return OptionsPopup
