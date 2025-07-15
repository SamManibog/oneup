local utils = require("oneup.utils")

local Text = require("oneup.text")
local Line = require("oneup.line")

---@class PopupOpts
---@field text string[]|Line[]? text to display on the popup as a list of lines
---@field title string?         the title to display on the popup, useless if border is not true
---@field width AdvLength|length
---@field height AdvLength|length
---@field border boolean?       border?
---@field focusable boolean?    whether the popup may be focused (defaults to true)
---@field modifiable boolean?   whether or not the popup's buffer is modifiable
---@field persistent boolean?   Whether or not the popup will persist once window has been exited
---@field on_close function?     function to run when the popup is closed
---@field close_bind string[]|string|nil

---@class Popup
---@field text Line[]
---@field private buffer_id integer
---@field private window_id integer
---@field private closed boolean
---@field private close_aucmd integer?
---@field private resize_aucmd integer?
---@field private title string? the title of the popup
---@field private height AdvLength
---@field private width AdvLength
---@field private border boolean
---@field private on_close function
local Popup = {}
Popup.__index = Popup

local ns = vim.api.nvim_create_namespace("oneup")

---Creates a new popup
---@param opts PopupOpts the options for the new popup
---@param enter boolean whether or not to immediately focus the popup
function Popup:new(opts, enter)
    ---@type PopupOpts
    opts = vim.tbl_extend("keep",
        opts,
        {
            text = {},
            modifiable = false,
            focusable = true,
            border = true,
            persistent = false
        }
    )

    ---@diagnostic disable: need-check-nil,assign-type-mismatch,cast-type-mismatch,cast-local-type
    ---@type AdvLength
    local width
    if type(opts.width) == "table" then
        width = opts.width
    else
        width = { value = opts.width }
    end
    if width.value == nil then
        width.value = 0
        for _, line in pairs(opts.text) do
            width.value = math.max(width.value, #line) ---@diagnostic disable-line:param-type-mismatch
        end
    end

    ---@type AdvLength
    local height
    if type(opts.height) == "table" then
        height = opts.height
    else
        height = { value = opts.height }
    end
    if height.value == nil then
        height.value = math.max(1, #opts.text) ---@diagnostic disable-line:param-type-mismatch
    end
    ---@diagnostic enable

    --create buffer
    ---@type integer
    local buffer = vim.api.nvim_create_buf(false, true)

    utils.set_buf_opts(buffer, {
        modifiable = opts.modifiable,
        bufhidden = "wipe",
        buftype = "nowrite",
        swapfile = false,
        buflisted = false
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
            width = 10,
            height = 10,
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
                "BufLeave",
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
        text = {},
        buffer_id = buffer,
        window_id = window,
        opts = opts,
        closed = false,
        close_aucmd = close_aucmd,
        resize_aucmd = resize_aucmd,
        title = opts.title,
        width = width, ---@diagnostic disable-line:assign-type-mismatch
        height = height, ---@diagnostic disable-line:assign-type-mismatch
        border = opts.border,
        on_close = opts.on_close,
    }

    setmetatable(out, self)
    out:setText(opts.text)
    out:resize()

    ---@diagnostic disable
    ---@type string[]
    local binds
    if type(opts.close_bind) ~= "table" then
        binds = { opts.close_bind }
    else
        binds = opts.close_bind
    end
    for _, bind in pairs(binds) do ---@diagnostic disable-line
        out:setKeymap("n", bind, function() out:close() end) ---@diagnostic disable-line
    end
    ---@diagnostic enable

    return out
end


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
    local width = utils.advToInteger(self.width, true)
    local height = utils.advToInteger(self.height, false)

    local row = math.floor(((vim.o.lines - height) / 2) - 1)
    row = math.max(1, row)

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

    ---handle text allignment
    local original_mod = self:getModifiable()
    self:setModifiable(true)

    local buf = self.buffer_id
    for idx, line in pairs(self.text) do
        if line.align ~= "left" then
            line:render(buf, idx - 1, width)
        end
    end

    if not original_mod then
        self:setModifiable(false)
    end
end

---gets actual the text of the popup
---@return string[] text
function Popup:getText()
    return vim.api.nvim_buf_get_lines(
        self.buffer_id,
        0,
        -1,
        false
    )
end

---sets the text of the popup
---@param text Line[]|string[]
function Popup:setText(text)
    local logical_text = {}

    for _, line in ipairs(text) do
        if type(line) == "string" then
            table.insert(logical_text, Line(line))
        else
            table.insert(logical_text, line)
        end
    end

    self.text = logical_text
    self:updateText()
end

---makes the text of the popup reflect the stored text value
function Popup:updateText()
    local original_mod = self:getModifiable()
    self:setModifiable(true)

    local width = self:getWidth()
    local buf = self.buffer_id

    ---clear highlights
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)


    --update lines
    for idx, line in pairs(self.text) do
        line:render(buf, idx - 1, width)
    end

    --clear extra lines
    vim.api.nvim_buf_set_lines(self.buffer_id, #self.text, -1, false, {})

    if not original_mod then
        self:setModifiable(false)
    end
end

function Popup:winId()
    return self.window_id
end

function Popup:bufId()
    return self.buffer_id
end

---allows the associated buffer of a popup to be modified
---@param value boolean whether or not the popup buffer should be modifiable
function Popup:setModifiable(value)
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
function Popup:getModifiable()
    return vim.api.nvim_get_option_value(
        "modifiable",
        {
            buf = self.buffer_id
        }
    )
end

---sets a keymap for the given popup when focused
---@param mode string the mode to set the keymap for
---@param lhs string the keystring to be replaced
---@param rhs string | function the keys or callback to replace lhs with
---@param opts? table options defined by https://neovim.io/doc/user/api.html#nvim_set_keymap() (excluding callback)
function Popup:setKeymap(mode, lhs, rhs, opts)
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
function Popup:getWidth()
    return vim.api.nvim_win_get_config(self.window_id).width
end

---returns the exact height of the popup
---@return integer height
function Popup:getHeight()
    return vim.api.nvim_win_get_config(self.window_id).height
end

return Popup
