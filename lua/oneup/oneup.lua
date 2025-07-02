local M = {}

local utils = require("config.utils")

---@class AdvInputPopup
---@field private prompt_buf_id integer     buf id for the prompt buffer
---@field private prompt_win_id integer     win id for the prompt buffer window
--the input being handled
---@field private inputting {
---row: integer, 
---buf_id: integer, 
---win_id: integer,
---close_aucmd: integer?}?
---@field private prompt_width integer      the length of the prompt portion of the window
---@field private opts AdvInputPopupOpts    the options used in managing the buffer
---@field private closed boolean            whether or not the window has been closed
---@field private close_aucmd integer?      the autocommand id for handling closing the window
---@field private resize_aucmd integer?     the autocommand id for handling resizing the window
---@field private allow_swap boolean        swap whiteless for creation of input buffer
---@field inputs {[string]: string}         the inputs given to the popup
M.AdvInputPopup = {}
M.AdvInputPopup.__index = M.AdvInputPopup

---@class AdvInputPopupOpts
---@field prompts string[]                  prompts to display as a collection of key, prompt pairs
---@field confirm_binds string[]            the keybinds to confirm/process input
---@field cancel_binds string[]             the keybinds to cancel and close the menu
---@field title string?                     the title to display on the popup, useless if border is not true
---@field width integer?                    the width of the input buffer
---@field border boolean?                   border?
---@field verify_input {
---[string]: fun(text:string):boolean}?     table of functions used to verify input for a given prompt
---@field on_confirm fun(inputs:{[string]: string}) callback for after input has been confirmed

---@param opts AdvInputPopupOpts
---@return {prompt_width: integer, width: integer, height: integer}
local function calculate_input_dimensions(opts)
    local out = {}
    local prompt_count = 0
    out.prompt_width = 1 --min input width of 1
    for _, prompt in pairs(opts.prompts) do
        out.prompt_width = math.max(out.prompt_width, #prompt)
        prompt_count = prompt_count + 1
    end
    out.prompt_width = out.prompt_width + 2 --+2 for ": "
    out.width = out.prompt_width + opts.width
    out.height = prompt_count
    return out
end

function M.AdvInputPopup:resize()
    local dim = calculate_input_dimensions(self.opts)

    local row = math.floor(((vim.o.lines - dim.height) / 2) - 1)
    local col = math.floor((vim.o.columns - dim.width) / 2)
    col = math.max(0, col)
    row = math.max(1, row)

    vim.api.nvim_win_set_config(
        self.prompt_win_id,
        {
            relative = "editor",
            row = row,
            col = col,
            width = dim.width,
            height = dim.height,
        }
    )
    if self.inputting ~= nil then
        vim.api.nvim_win_set_config(
            self.inputting.win_id,
            {
                relative = "editor",
                row = row + self.inputting.row,
                col = col + self.prompt_width + 1,
                width = dim.width - self.prompt_width,
                height = 1,
            }
        )
    end
end

function M.AdvInputPopup:close()
    if not self.closed and not self.allow_swap then
        -- self.closed variable is necessary to prevent double firing
        self.closed = true

        --if statement protects against :q being used
        if vim.api.nvim_win_is_valid(self.prompt_win_id) then
            vim.api.nvim_win_close(self.prompt_win_id, true)
        end

        if self.inputting ~= nil then
            vim.api.nvim_win_close(self.inputting.win_id, true)
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
        if self.inputting ~= nil and self.inputting.close_aucmd ~= nil then
            vim.api.nvim_del_autocmd(self.inputting.close_aucmd)
        end
    end
end

---@param prompts {[string]: string} the list of prompts
---@param responses {[string]: string} the list of inputs to the prompts
---@param width integer the total width of the prompts
---@return string[]     the text for the prompt menu
function M.gen_prompt_text(prompts, responses, width)
    local out = {}
    for _, prompt in pairs(prompts) do
        table.insert(out,
            string.rep(" ", width - #prompt - 2)
            ..prompt
            ..": "
            ..(responses[prompt] or " ")
        )
    end
    return out
end

function M.AdvInputPopup:refresh_text()
    vim.api.nvim_set_option_value(
        "modifiable",
        true,
        {
            buf = self.prompt_buf_id,
        }
    )
    vim.api.nvim_buf_set_lines(
        self.prompt_buf_id,
        0,
        -1,
        true,
        M.gen_prompt_text(self.opts.prompts, self.inputs, self.prompt_width)
    )
    vim.api.nvim_set_option_value(
        "modifiable",
        false,
        {
            buf = self.prompt_buf_id,
        }
    )
end

---Creates a new popup
---@param opts AdvInputPopupOpts
---@param enter boolean whether or not to immediately focus the popup
---@return AdvInputPopup
function M.new_adv_input(opts, enter)
    if opts.width == nil then
        opts.width = 20
    end

    local dim = calculate_input_dimensions(opts)

    --create prompt buffer
    ---@type integer
    local prompt_buf = vim.api.nvim_create_buf(false, true)

    vim.api.nvim_buf_set_lines(
        prompt_buf,
        0,
        -1,
        true,
        M.gen_prompt_text(opts.prompts, {}, dim.prompt_width)
    )

    utils.set_buf_opts(prompt_buf, {
        modifiable = false,
        bufhidden = "wipe",
        buftype = "nowrite",
        swapfile = false
    })

    --create window
    ---@type integer
    local prompt_window = vim.api.nvim_open_win(
        prompt_buf,
        enter,
        {
            relative = "editor",
            row = 10,
            col = 10,
            width = dim.width,
            height = dim.height,
            focusable = true,
            zindex = 98,
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
            prompt_window,
            config
        )
    end

    --create final object
    ---@type AdvInputPopup
    local out

    local close_aucmd = nil
    --create closing autocommand
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
        prompt_buf_id = prompt_buf,
        prompt_win_id = prompt_window,
        prompt_width = dim.prompt_width,
        opts = opts,
        closed = false,
        inputs = {},
        close_aucmd = close_aucmd,
        resize_aucmd = resize_aucmd,
        allow_swap = false,
    }
    setmetatable(out, M.AdvInputPopup)
    out:resize()

    ---@diagnostic disable: invisible
    local ns = vim.api.nvim_create_namespace("oneup_adv_input_menu")

    vim.api.nvim_set_option_value(
        "cursorline",
        true,
        {
           win = out.prompt_win_id
        }
    )

    vim.api.nvim_set_hl(
        ns,
        "CursorLine",
        { link = "Visual" }
    )

    vim.api.nvim_win_set_hl_ns(out.prompt_win_id, ns)

    local close_input_buffer = function()
        vim.api.nvim_del_autocmd(out.inputting.close_aucmd)
        out.allow_swap = true
        vim.api.nvim_tabpage_set_win(0, out.prompt_win_id)
        vim.api.nvim_win_close(out.inputting.win_id, true)
        out.allow_swap = false
        out.close_aucmd = nil
        out.inputting = nil
    end

    for _, cancel_binds in pairs(opts.cancel_binds) do
        vim.api.nvim_buf_set_keymap(
            prompt_buf,
            "n",
            cancel_binds,
            "",
            {
                callback = function() out:close() end
            }
        )
    end

    for _, confirm_binds in pairs(opts.confirm_binds) do
        vim.api.nvim_buf_set_keymap(
            prompt_buf,
            "n",
            confirm_binds,
            "",
            {
                callback = function()
                    if out.opts.verify_input ~= nil then
                        for prompt, callback in pairs(out.opts.verify_input) do
                            if not callback(out.inputs[prompt] or "") then
                                print("Invalid input given.")
                                close_input_buffer()
                                return
                            end
                        end
                    end
                    out.opts.on_confirm(out.inputs)
                    out:close()
                end
            }
        )
    end


    for _, char in pairs({"I", "i", "A", "a"}) do
        vim.api.nvim_buf_set_keymap(
            prompt_buf,
            "n",
            char,
            "",
            {
                callback = function()
                    if out.closed == true then
                        return
                    end
                    --create inputting window

                    --determine position
                    local cursor = vim.api.nvim_win_get_cursor(0)
                    local prompt_row = cursor[1]

                    --determine key for prompt input
                    local prompt_key = nil

                    do
                        local index = 1 --rows are 1-indexed
                        for key, _ in pairs(out.opts.prompts) do
                            if prompt_row == index then
                                prompt_key = key
                            end
                            index = index + 1
                        end
                    end

                    --create input_buf
                    local input_buf = vim.api.nvim_create_buf(false, true)
                    utils.set_buf_opts(input_buf, {
                        bufhidden = "wipe",
                        buftype = "prompt",
                        swapfile = false
                    })
                    vim.fn.prompt_setprompt(input_buf, "")
                    vim.api.nvim_buf_set_lines(
                        input_buf,
                        0,
                        -1,
                        true,
                        {out.inputs[out.opts.prompts[prompt_row]]} or {""}
                    )

                    if prompt_key ~= nil then
                        vim.fn.prompt_setcallback(input_buf, function (text)
                            out.inputs[out.opts.prompts[prompt_row]] = text
                            out:refresh_text()
                            close_input_buffer()
                        end)
                    end

                    out.allow_swap = true

                    local input_dim = calculate_input_dimensions(out.opts)
                    local row = math.floor(((vim.o.lines - input_dim.height) / 2) - 1)
                    local col = math.floor((vim.o.columns - input_dim.width) / 2)
                    local input_win = vim.api.nvim_open_win(
                        input_buf,
                        true,
                        {
                            relative = "editor",
                            row = row + prompt_row,
                            col = col + out.prompt_width + 1,
                            width = dim.width - out.prompt_width,
                            height = 1,
                            focusable = true,
                            zindex = 99,
                            style = "minimal",
                        }
                    )

                    vim.api.nvim_set_option_value(
                        "cursorline",
                        true,
                        {
                            win = input_win
                        }
                    )
                    vim.api.nvim_win_set_hl_ns(input_win, ns)

                    vim.cmd("startinsert!")

                    vim.schedule(function ()
                        local input_close_aucmd = vim.api.nvim_create_autocmd(
                            "ModeChanged",
                            {
                                callback = function()
                                    out.inputs[out.opts.prompts[prompt_row]]
                                    = vim.api.nvim_buf_get_lines(
                                        input_buf,
                                        0,
                                        1,
                                        true
                                    )[1] or ""

                                    out:refresh_text()
                                    close_input_buffer()
                                end
                            }
                        )

                        out.inputting = {
                            row = prompt_row,
                            buf_id = input_buf,
                            win_id = input_win,
                            close_aucmd = input_close_aucmd
                        }
                        out:resize()

                        out.allow_swap = false
                    end)
                end
                ---@diagnostic enable: invisible
            }
        )
    end

    return out
end

return M
