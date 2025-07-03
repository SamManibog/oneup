local Popup = require("oneup.popup")

---@alias Option { text: string, is_title?: boolean, [any]: any }

---@class OptionsPopup: Popup
---@field private current integer       the currently selected option
---@field private options Option[]      a list of options
---@field private mark_id integer       the id of the ext mark used to highlight the current selection
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
    local titles = {}
    do
        local row = 0
        for _, option in pairs(opts.options) do
            if option.is_title then
                table.insert(titles, row)
            end
            table.insert(menuText, option.text)
            row = row + 1
        end
    end

    if #titles == #opts.options then
        error("Options menu must have a non-title option")
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

    setmetatable(p, self)

    local ns = vim.api.nvim_create_namespace("oneup_options_popup")
    vim.api.nvim_win_set_hl_ns(p:win_id(), ns)

    --highlight titles
    for _, row in pairs(titles) do
        vim.api.nvim_buf_set_extmark(
            p:buf_id(),
            ns,
            row,
            0,
            {
                line_hl_group = "Title",
                virt_text = { { "--------------------------------------------------------------------------------------------------------------------------------------------------------------------", "Title" } },
                virt_text_pos = "eol"
            }
        )
    end


    --create selected highlight

    p.mark_id = vim.api.nvim_buf_set_extmark(
        p:buf_id(),
        ns,
        0,
        0,
        {
            line_hl_group = "PmenuSel"
        }
    )

    p.current = 0
    p:next_option()

    return p
end

---returns the currently selected option in the popup. useful for keybinds
---@return Option option
function OptionsPopup:get_option()
    return self.options[self.current]
end

---iterates forward to the next option in the popup
function OptionsPopup:next_option()
    self.current = self.current + 1

    if self.current > #self.options then
        self.current = 0
        self:next_option()
    elseif self.options[self.current].is_title then
        self:next_option()
    else
        self.mark_id = vim.api.nvim_buf_set_extmark(
            self:buf_id(),
            vim.api.nvim_create_namespace("oneup_options_popup"),
            self.current - 1,
            0,
            {
                id = self.mark_id,
                line_hl_group = "PmenuSel"
            }
        )
        vim.api.nvim_win_set_cursor(self:win_id(), {self.current, 0})
    end
end

---iterates backward to the previous option in the popup
function OptionsPopup:prev_option()
    self.current = self.current - 1

    if self.current <= 0 then
        self.current = #self.options + 1
        self:prev_option()
    elseif self.options[self.current].is_title then
        self:prev_option()
    else
        self.mark_id = vim.api.nvim_buf_set_extmark(
            self:buf_id(),
            vim.api.nvim_create_namespace("oneup_options_popup"),
            self.current - 1,
            0,
            {
                id = self.mark_id,
                line_hl_group = "PmenuSel"
            }
        )
        vim.api.nvim_win_set_cursor(self:win_id(), {self.current, 0})
    end
end

OptionsPopup.set_text = nil
OptionsPopup.set_modifiable = nil

return OptionsPopup
