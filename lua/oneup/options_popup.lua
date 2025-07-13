local Popup = require("oneup.popup")

---@alias Option { text: string, is_title?: boolean, [any]: any }

---@alias Align
---| '"left"'
---| '"center"'
---| '"right"'

---@class OptionsPopup: Popup
---@field private current integer               the currently selected option
---@field private options Option[]              a list of options
---@field private mark_id integer               the id of the ext mark used to highlight the current selection
---@field private title_marks integer[]         a list of extmark ids corresponding to titles (used to keep them aligned)
---@field private title_rows integer[]          a list of rows corresponding to each title mark
---@field private title_widths integer[]        a list of widths for each separator
---@field private title_align Align|integer either a number or title align
---@field private updateTitles fun(self: OptionsPopup)
local OptionsPopup = {}
OptionsPopup.__index = OptionsPopup
setmetatable(OptionsPopup, Popup)

local dividerText = string.rep("-", 256)

---@class OptionsPopupOpts
---@field title string?         the title to display on the popup, useless if border is not true
---@field options Option[]      A list of options that may be selected from
---@field height AdvLength|length
---@field width AdvLength|length
---@field separator_align Align|integer? either a number or title align to align separator titles to
---@field border boolean?       border?
---@field persistent boolean?   Whether or not the popup will persist once window has been exited
---@field on_close function?    function to run when the popup is closed
---@field close_bind string[]|string|nil
---@field next_bind string[]|string|nil
---@field previous_bind string[]|string|nil

---@param opts OptionsPopupOpts the options for the given popup
---@param enter boolean whether or not to immediately focus the popup
function OptionsPopup:new(opts, enter)
    local text = {}
    for _, _ in pairs(opts.options) do
        table.insert(text, "")
    end

    --@type PopupOpts
    local popupOpts = {
        text = text,
        focusable = true,
        modifiable = false,

        title = opts.title,
        width = opts.width,
        height = opts.height,
        border = opts.border,
        persistent = opts.persistent,
        on_close = opts.on_close,
        close_bind = opts.close_bind,
    }

    ---@class OptionsPopup
    local p = Popup:new(popupOpts, enter)
    p.options = opts.options
    p.title_align = opts.separator_align or 0

    setmetatable(p, self)
    p:refreshText()

    p.current = 0
    p:nextOption()

    ---@diagnostic disable:param-type-mismatch,assign-type-mismatch
    local next_binds
    if opts.next_bind == nil then
        next_binds = { "j", "<Down>" }
    elseif type(opts.next_bind) ~= "table" then
        next_binds = { opts.next_bind }
    else
        next_binds = opts.next_bind
    end
    local prev_binds
    if opts.previous_bind == nil then
        prev_binds = { "k", "<Up>" }
    elseif type(opts.previous_bind) ~= "table" then
        prev_binds = { opts.previous_bind }
    else
        prev_binds = opts.previous_bind
    end

    for _, bind in pairs(next_binds) do
        p:setKeymap("n", bind, function() p:nextOption() end)
    end
    for _, bind in pairs(prev_binds) do
        p:setKeymap("n", bind, function() p:prevOption() end)
    end
    ---@diagnostic enable

    return p
end

---resizes the popup
function OptionsPopup:resize()
    Popup.resize(self)
    self:updateTitles()
end

---returns the currently selected option in the popup. useful for keybinds
---@return Option option
function OptionsPopup:getOption()
    return self.options[self.current]
end

---iterates forward to the next option in the popup
function OptionsPopup:nextOption()
    self.current = self.current + 1

    if self.current > #self.options then
        self.current = 0
        self:nextOption()
    elseif self.options[self.current].is_title then
        self:nextOption()
    else
        self.mark_id = vim.api.nvim_buf_set_extmark(
            self:bufId(),
            vim.api.nvim_create_namespace("oneup"),
            self.current - 1,
            0,
            {
                id = self.mark_id,
                line_hl_group = "PmenuSel"
            }
        )
        vim.api.nvim_win_set_cursor(self:winId(), {self.current, 0})
    end
end

---iterates backward to the previous option in the popup
function OptionsPopup:prevOption()
    self.current = self.current - 1

    if self.current <= 0 then
        self.current = #self.options + 1
        self:prevOption()
    elseif self.options[self.current].is_title then
        self:prevOption()
    else
        self.mark_id = vim.api.nvim_buf_set_extmark(
            self:bufId(),
            vim.api.nvim_create_namespace("oneup"),
            self.current - 1,
            0,
            {
                id = self.mark_id,
                line_hl_group = "PmenuSel"
            }
        )
        vim.api.nvim_win_set_cursor(self:winId(), {self.current, 0})
    end
end

function OptionsPopup:updateTitles()
    local ns = vim.api.nvim_create_namespace("oneup")

    ---@type integer
    local base = 0
    local center = false
    local right = false
    local tail = " "
    if type(self.title_align) == "string" then
        if self.title_align == "center" then
            base = math.floor(self:getWidth() / 2) - 1
            center = true
        elseif self.title_align == "right" then
            base = self:getWidth() - 1
            right = true
        end
    elseif self.title_align <= -1 then
        right = true
        base = self:getWidth() + self.title_align - 1
    else
        base = self.title_align - 1
        if base <= 0 then
            tail = ""
            base = base + 1
        end
    end

    for idx, _ in ipairs(self.title_marks) do
        local text = ""
        if center then
            text = string.rep("-", base - math.floor(self.title_widths[idx] / 2.0)) .. tail
        elseif right then
            text = string.rep("-", base - self.title_widths[idx]) .. tail
        else
            text = string.rep("-", base) .. tail
        end

        vim.api.nvim_buf_set_extmark(
            self:bufId(),
            ns,
            self.title_rows[idx],
            0,
            {
                id = self.title_marks[idx],
                virt_text = { { text, "Title" } },
                virt_text_pos = "inline"
            }
        )
    end
end

function OptionsPopup:refreshText()
    local menuText = {}
    local titles = {}
    local title_widths = {}
    do
        local row = 0
        for _, option in pairs(self.options) do
            if option.is_title then
                table.insert(titles, row)
            end
            table.insert(menuText, option.text)
            table.insert(title_widths, #option.text)
            row = row + 1
        end
    end

    if #titles == #self.options then
        error("Options menu must have a non-title option")
    end

    self.title_widths = title_widths
    self.title_rows = titles
    self.title_marks = {}

    local ns = vim.api.nvim_create_namespace("oneup")

    vim.api.nvim_buf_clear_namespace(self:bufId(), ns, 0, -1)
    Popup.setText(self, menuText)

    --highlight titles
    for _, row in pairs(titles) do
        vim.api.nvim_buf_set_extmark(
            self:bufId(),
            ns,
            row,
            0,
            {
                line_hl_group = "Title",
                virt_text = { { dividerText, "Title" } },
                virt_text_pos = "eol",
                virt_text_hide = true
            }
        )
        table.insert(self.title_marks,
            vim.api.nvim_buf_set_extmark(
                self:bufId(),
                ns,
                row,
                0,
                {
                    virt_text = { { "", "Title" } },
                    virt_text_pos = "inline"
                }
            )
        )
    end
    self:updateTitles()

    local row
    if self.current == nil then
        row = 0
    else
        row = self.current - 1
    end

    self.mark_id = vim.api.nvim_buf_set_extmark(
        self:bufId(),
        ns,
        row,
        0,
        {
            priority = 200,
            line_hl_group = "PmenuSel"
        }
    )

end

OptionsPopup.set_text = nil
OptionsPopup.set_modifiable = nil

return OptionsPopup
