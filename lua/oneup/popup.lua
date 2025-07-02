local utils = require("oneup.utils")

---@class PopupOpts
---@field text string[]         text to display on the popup as a list of lines
---@field title string?         the title to display on the popup, useless if border is not true
---@field width string?         the width of the popup (may be a percent) sets width based on text if nil
---@field height string?        the height of the popup (may be a percent) sets height based on text if nil
---@field min_width integer?    the absolute minimum width for the popup. useless if width is a regular number
---@field min_height integer?   the absolute minimum height for the popup. useless if height is a regular number
---@field border boolean?       border?
---@field focusable boolean?    whether the popup may be focused (defaults to true)
---@field modifiable boolean?   whether or not the popup's buffer is modifiable
---@field persistent boolean?   Whether or not the popup will persist once window has been exited
---@field on_close function?     function to run when the popup is closed

---@class Popup
---@field private buffer_id integer
---@field private window_id integer
---@field private closed boolean
---@field private close_aucmd integer?
---@field private resize_aucmd integer?
---@field private title string? the title of the popup
---@field private width_mult integer?
---@field private height_mult integer?
---@field private min_width integer
---@field private min_height integer
---@field private border boolean
---@field private on_close function
local Popup = {}
Popup.__index = Popup

function Popup:close()
    if not self.closed then
        -- self.closed variable is necessary to prevent double firing
        self.closed = true
        if self.on_close ~= nil then self.on_close() end

        --if statement protects against :q being used
        if vim.api.nvim_win_is_valid(self.window_id) then
            vim.api.nvim_win_close(self.window_id, true)
        end

        --destroy associated autocommands
        if self.close_aucmd ~= nil then
            vim.api.nvim_del_autocmd(self.close_aucmd)
            self.close_aucmd = nil
        end
        if self.resize_aucmd ~= nil then
            vim.api.nvim_del_autocmd(self.resize_aucmd)
            self.resize_aucmd = nil
        end
    end
end

function Popup:resize()
    local win_cfg = vim.api.nvim_win_get_config(self.window_id)
    local height = win_cfg.height
    local width = win_cfg.width

    if self.height_mult ~= nil then
        height = math.floor( (vim.o.lines * self.height_mult) + 0.5)
        height = math.max(height, self.min_height)
    end
    local row = math.floor(((vim.o.lines - height) / 2) - 1)
    row = math.max(1, row)

    if self.width_mult ~= nil then
        width = math.floor( (vim.o.columns * self.width_mult) + 0.5)
        width = math.max(width, self.min_width)
    end
    local col = math.floor((vim.o.columns - width) / 2)
    col = math.max(0, col)

    vim.api.nvim_win_set_config(
        self.window_id,
        {
            relative = "editor",
            row = row,
            col = col,
            width = width,
            height = height,
        }
    )
end

---sets the text of the popup
---@param text string[]
function Popup:set_text(text)
    local original_mod = self:get_modifiable()
    self:set_modifiable(true)

    self.text = text
    vim.api.nvim_buf_set_lines(
        self.buffer_id,
        0,
        -1,
        true,
        self.text or {""}
    )

    if not original_mod then
        self:set_modifiable(false)
    end
end

function Popup:win_id()
    return self.window_id
end

function Popup:buf_id()
    return self.buffer_id
end

---allows the associated buffer of a popup to be modified
---@param value boolean whether or not the popup buffer should be modifiable
function Popup:set_modifiable(value)
    vim.api.nvim_set_option_value(
        "modifiable",
        value,
        {
            buf = self.buffer_id
        }
    )
end

---returns whether or not the popup's buffer is modifiable
---@return boolean modifiable whether or not the buffer is modifiable
function Popup:get_modifiable()
    return vim.api.nvim_get_option_value(
        "modifiable",
        {
            buf = self.buffer_id
        }
    )
end

---Creates a new popup
---@param opts PopupOpts the options for the new popup
---@param enter boolean whether or not to immediately focus the popup
function Popup:new(opts, enter)
    if opts.modifiable == nil then opts.modifiable = false end
    if opts.focusable == nil then opts.focusable = true end
    if opts.border == nil then opts.border = true end
    if opts.persistent == nil then opts.persistent = false end

    local width = 40
    local height = 40
    local width_mult, height_mult
    ---set height based on text
    if opts.height == nil then
        height = math.max(#opts.text, 1)
        if opts.min_height ~= nil then
            height = math.max(height, opts.min_height)
        end
    elseif opts.height:sub(-1) == "%" then
        height_mult = tonumber(opts.height:sub(1, -2)) / 100
    else
        height = math.floor(tonumber(opts.height)) ---@diagnostic disable-line:param-type-mismatch
        if height == nil then error("height '" .. opts.height .. "' is invalid.") end
    end

    if opts.width == nil then
        if opts.title ~= nil then
            width = math.max(width, #opts.title)
        end
        if opts.text ~= nil then
            for _, line in pairs(opts.text) do
                width = math.max(width, #line)
            end
        end
        if opts.min_width ~= nil then
            width = math.max(width, opts.min_width)
        end
    elseif opts.width:sub(-1) == "%" then
        width_mult = tonumber(opts.width:sub(1, -2)) / 100
    else
        width = math.floor(tonumber(opts.width)) ---@diagnostic disable-line:param-type-mismatch
        if width == nil then error("width '" .. opts.width .. "' is invalid.") end
    end


    --create buffer
    ---@type integer
    local buffer = vim.api.nvim_create_buf(false, true)

    vim.api.nvim_buf_set_lines(
        buffer,
        0,
        -1,
        true,
        opts.text or {""}
    )

    utils.set_buf_opts(buffer, {
        modifiable = opts.modifiable,
        bufhidden = "wipe",
        buftype = "nowrite",
        swapfile = false
    })

    --create window
    ---@type integer
    local window = vim.api.nvim_open_win(
        buffer,
        enter,
        {
            relative = "editor",
            row = 10,
            col = 10,
            width = width,
            height = height,
            focusable = opts.focusable,
            zindex = 99,
            style = "minimal",
        }
    )

    if opts.border then
        local config = {
            border = "rounded"
        }
        if opts.title then
            config.title = opts.title
            config.title_pos = "center"
        end
        vim.api.nvim_win_set_config(
            window,
            config
        )
    end

    --create final object
    ---@type Popup
    local out

    local close_aucmd = nil
    --create closing autocommand
    if not opts.persistent then
        close_aucmd = vim.api.nvim_create_autocmd(
            {
                --[["BufEnter",
                "UIEnter",
                "TabEnter",
                "WinEnter",
                "BufHidden",
                "BufWipeout",]]
                "BufLeave",
                --"BufWinLeave",
            },
            {
                callback = function ()
                    out:close()
                end
            }
        )
    end

    --create resize autocommand
    local resize_aucmd = vim.api.nvim_create_autocmd(
        {
            "VimResized"
        },
        {
            callback = function ()
                out:resize()
            end
        }
    )

    out = {
        buffer_id = buffer,
        window_id = window,
        opts = opts,
        closed = false,
        close_aucmd = close_aucmd,
        resize_aucmd = resize_aucmd,
        title = opts.title,
        width_mult = width_mult,
        height_mult = height_mult,
        min_width = opts.min_width or 1,
        min_height = opts.min_height or 1,
        border = opts.border,
        on_close = opts.on_close,
    }

    setmetatable(out, self)
    out:resize()

    return out
end

---sets a keymap for the given popup when focused
---@param mode string the mode to set the keymap for
---@param lhs string the keystring to be replaced
---@param rhs string | function the keys or callback to replace lhs with
---@param opts? table options defined by https://neovim.io/doc/user/api.html#nvim_set_keymap() (excluding callback)
function Popup:set_keymap(mode, lhs, rhs, opts)
    local logical_opts = opts or {}

    ---@type string
    local logical_rhs = ""
    if type(rhs) == "string" then
        logical_rhs = rhs
    else
        logical_opts.callback = rhs
    end

    vim.api.nvim_buf_set_keymap(
        self.buffer_id,
        mode,
        lhs,
        logical_rhs,
        logical_opts
    )
end

---returns the exact width of the popup
---@return integer width
function Popup:width()
    return vim.api.nvim_win_get_config(self.window_id).width
end

---returns the exact height of the popup
---@return integer height
function Popup:height()
    return vim.api.nvim_win_get_config(self.window_id).height
end

return Popup
