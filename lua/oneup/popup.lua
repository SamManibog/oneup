local utils = require("config.utils")

---@class PopupOpts
---@field text string[]         text to display on the popup as a list of lines
---@field title string?         the title to display on the popup, useless if border is not true
---@field width integer?        the minimum width excluding the border
---@field height integer?       the minimum height excluding the border
---@field border boolean?       border?
---@field focusable boolean?    whether the popup may be focused (defaults to true)
---@field persistent boolean?   Whether or not the popup will persist once window has been exited
---@field on_close function?     function to run when the popup is closed

---@class Popup
---@field private buf_id integer
---@field private win_id integer
---@field private closed boolean
---@field private close_aucmd integer?
---@field private resize_aucmd integer?
---@field private title string? the title of the popup
---@field private width integer?
---@field private height integer?
---@field private border boolean
---@field private on_close function
local Popup = {}

function Popup:close()
    if not self.closed then
        -- self.closed variable is necessary to prevent double firing
        self.closed = true
        if self.on_close ~= nil then self.on_close() end

        --if statement protects against :q being used
        if vim.api.nvim_win_is_valid(self.win_id) then
            vim.api.nvim_win_close(self.win_id, true)
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
    local height
    local width

    do
        ---@type integer
        height = self.height or 1
        local text = vim.api.nvim_buf_get_lines(self.buf_id, 0, -1, false)

        height = math.max(height, #text)

        --find width
        ---@type integer
        width = self.width or 1
        if self.title ~= nil then
            width = math.max(width, #self.title)
        end
        for _, line in pairs(text) do
            width = math.max(width, #line)
        end
    end

    local row = math.floor(((vim.o.lines - height) / 2) - 1)
    local col = math.floor((vim.o.columns - width) / 2)
    col = math.max(0, col)
    row = math.max(1, row)

    vim.api.nvim_win_set_config(
        self.win_id,
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
    utils.set_buf_opts(self.buf_id, {
        modifiable = true,
    })

    self.text = text
    vim.api.nvim_buf_set_lines(
        self.buf_id,
        0,
        -1,
        true,
        self.text or {""}
    )
    self:resize()

    utils.set_buf_opts(self.buf_id, {
        modifiable = false,
    })
end

function Popup:get_win_id()
    return self.win_id
end

function Popup:get_buf_id()
    return self.buf_id
end

---Creates a new popup
---@param opts PopupOpts the options for the new popup
---@param enter boolean whether or not to immediately focus the popup
function Popup:new(opts, enter)
    if opts.focusable == nil then opts.focusable = true end
    if opts.border == nil then opts.border = true end

    local width, height
    do
        ---@type integer
        height = opts.height or 1
        if opts.text ~= nil then
            height = math.max(height, #opts.text)
        end

        --find width
        ---@type integer
        width = opts.width or 1
        if opts.title ~= nil then
            width = math.max(width, #opts.title)
        end
        if opts.text ~= nil then
            for _, line in pairs(opts.text) do
                width = math.max(width, #line)
            end
        end
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
        modifiable = false,
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
            config.title = " "..opts.title.." "
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
                "BufEnter",
                "UIEnter",
                "TabEnter",
                "WinEnter",
                "BufHidden",
                "BufWipeout",
                "BufLeave",
                "BufWinLeave",
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

    ---@diagnostic disable-next-line: missing-fields
    out = {
        buf_id = buffer,
        win_id = window,
        opts = opts,
        closed = false,
        close_aucmd = close_aucmd,
        resize_aucmd = resize_aucmd,
        title = opts.title,
        width = opts.width,
        height = opts.height,
        border = opts.border,
        on_close = opts.on_close,
    }
    setmetatable(out, Popup)
    self.__index = self
    out:resize()

    return out
end

return Popup
