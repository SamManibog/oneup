local M = {}

local utils = require("config.utils")
local Popup = require("oneup.popup")

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

--[==[
---@class MenuItem
---@field linenr number         the line number of the option
---@field data table?           additional data for the menu item

---generates bindings for menu navigation in the given buffer
---@param popup Popup            the buffer in which to apply the binds
---@param items MenuItem[]      the items on the menu
---@param upbinds string[]      a list of bindings to go upward
---@param downbinds string[]    a list of bindings to go downward
---@param stateTable table      a table in which to find the current menu item
---@param currentKey string     the key at which to find the current menu item index in state table
---@param wrap boolean          whether or not to wrap to top/bottom if at bottom/top of menu
local function gen_menu_navigation_binds(popup, items, upbinds, downbinds, stateTable, currentKey, wrap)
    local navigate = function(up)
        if up then
            --update menu item index
            local idx = stateTable[currentKey] + 1
            if idx > #items then
                if wrap then
                    stateTable[currentKey] = 1
                end
            else
                stateTable[currentKey] = idx
            end
        else
            --update menu item index
            local idx = stateTable[currentKey] - 1
            if idx <= 0 then
                if wrap then
                    stateTable[currentKey] = #items
                end
            else
                stateTable[currentKey] = idx
            end

        end
        vim.api.nvim_win_set_cursor(
            popup:get_win_id(),
            {
                col = 0,
                row = items[stateTable[currentKey]].linenr
            }
        )
    end

    for _, bind in pairs(upbinds) do
        vim.api.nvim_buf_set_keymap(
            popup:get_buf_id()
            "n",
            bind,
            "",
            {
                silent = true,
                callback = function() navigate(true) end
            }
        )
    end
    for _, bind in pairs(downbinds) do
        vim.api.nvim_buf_set_keymap(
            popup:get_buf_id()
            "n",
            bind,
            "",
            {
                silent = true,
                callback = function() navigate(false) end
            }
        )
    end
end
]==]

---@class OptionsMenuOpts
---@field title string?         the title to display on the popup, useless if border is not true
---@field width integer?        the minimum width excluding the border
---@field height integer?       the minimum height excluding the border
---@field border boolean?       border?
---@field persistent boolean?   Whether or not the popup will persist once window has been exited
---@field stayOpen boolean?     Whether or not the popup will persist by default when an action has been executed
---@field closeBinds string[]?  A list of keybinds that will close the menu
---@field selectBinds string[]?  A list of keybinds that will run the highlighted action

---@param actions { bind: string?, desc: string, persist: boolean|nil, callback: function, [any]: any }[] a list of tables describing the available actions
---@param opts OptionsMenuOpts the options for the given popup
---@param enter boolean whether or not to immediately focus the popup
function M.new_options_menu(actions, opts, enter)
    local menuText = {}

    --determine max length of keybinds to allow right alignment
    local keybind_length = 0
    for _, action in pairs(actions) do
        if action.bind == nil then break end

        keybind_length = math.max(keybind_length, string.len(action.bind))
    end

    local height = 0
    local actionList = {}
    local bindless = true
    for _, action in pairs(actions) do
        if action.bind ~= nil then
            bindless = false
            break
        end
    end
    for _, action in pairs(actions) do
        table.insert(actionList, {
            callback = action.callback,
            persist = action.persist
        })

        if bindless then
            table.insert(menuText, action.desc)
        else
            if action.bind == nil then
                local padding = string.rep(" ", keybind_length)
                table.insert(menuText, padding .. " - " .. action.desc)
            else
                local padding = string.rep(" ", keybind_length - string.len(action.bind))
                table.insert(menuText, padding .. action.bind .. " - " .. action.desc)
            end
        end

        height = height + 1
    end

    --@type PopupOpts
    local popupOpts = {
        title = opts.title,
        width = opts.width,
        height = opts.height,
        border = opts.border,
        persistent = opts.persistent,

        text = menuText,
    }

    popupOpts["text"] = menuText

    local p = Popup:new(popupOpts, enter)

    local ns = vim.api.nvim_create_namespace("oneup_menu")

    vim.api.nvim_set_option_value(
        "cursorline",
        true,
        {
           win = p:get_win_id()
        }
    )

    vim.api.nvim_set_hl(
        ns,
        "CursorLine",
        { link = "Visual" }
    )

    vim.api.nvim_win_set_hl_ns(p:get_win_id(), ns)

    for _, action in pairs(actions) do
        if action.bind == nil then break end

        vim.api.nvim_buf_set_keymap(
            p:get_buf_id(),
            "n",
            action.bind,
            "",
            {
                silent = true,
                callback = function()
                    action.callback()

                    local shouldClose = true
                    if opts.stayOpen == true then shouldClose = false end
                    if action.persist ~= nil then shouldClose = not action.persist end

                    if shouldClose then
                        p:close()
                    end
                end
            }
        )
    end

    if opts.closeBinds ~= nil then
        for _, closer in pairs(opts.closeBinds) do
            vim.api.nvim_buf_set_keymap(
                p:get_buf_id(),
                "n",
                closer,
                "",
                {
                    silent = true,
                    callback = function() p:close() end
                }
            )
        end
    end

    if opts.selectBinds ~= nil then
        for _, selector in pairs(opts.selectBinds) do
            vim.api.nvim_buf_set_keymap(
                p:get_buf_id(),
                "n",
                selector,
                "",
                {
                    silent = true,
                    callback = function()
                        local action = actionList[vim.api.nvim_win_get_cursor(0)[1]]
                        action.callback()

                        local shouldClose = true
                        if opts.stayOpen == true then shouldClose = false end
                        if action.persist ~= nil then shouldClose = not action.persist end

                        if shouldClose then
                            p:close()
                        end
                    end
                }
            )
        end
    end

    return p
end

---@class OptionsPreviewMenuOpts
---@field height integer            the height for both popups
---@field menu_width integer        the menu width
---@field preview_width integer     the preview width
---@field menu_title string?        the title to display on the menu, useless if border is not true
---@field preview_title string?     the title to display on the preview, useless if border is not true
---@field border boolean?       border?
---@field persistent boolean?   Whether or not the popup will persist once window has been exited
---@field stayOpen boolean?     Whether or not the popup will persist by default when an action has been executed
---@field closeBinds string[]?  A list of keybinds that will close the menu
---@field selectBinds string[]?  A list of keybinds that will run the highlighted action

---@param actions { bind: string?, desc: string, persist: boolean|nil, callback: function, preview: (string[] | fun(): string[]), [any]: any }[] a list of tables describing the available actions
---@param opts OptionsPreviewMenuOpts the options for the given popup
---@param enter boolean whether or not to immediately focus the popup
function M.new_options_preview_menu(actions, opts, enter)
    if opts.border == nil then opts.border = true end

    ---@type OptionsMenuOpts
    local optionsOpts = {
        title = opts.menu_title,
        width = opts.menu_width,
        height = opts.height,
        border = opts.border,
        persistent = opts.persistent,
        stayOpen = opts.stayOpen,
        closeBinds = opts.closeBinds,
        selectBinds = opts.selectBinds
    }

    local initText
    if type(actions[1].preview) == "function" then
        initText = actions[1].preview()
    else
        initText = actions[1].preview
    end

    local optionsPopup = M.new_options_menu(actions, optionsOpts, enter)
    local previewPopup = Popup:new({
        text = initText,
        title = opts.preview_title,
        width = opts.preview_width,
        height = opts.height,
        border = opts.border,
        persistent = true,
        focusable = false
    }, false)

    previewPopup.resize = function(_) end
    optionsPopup.resize = function(_)
        local combined_width = opts.preview_width + opts.menu_width
        if opts.border then combined_width = combined_width + 2 end

        local menu_row = math.floor(((vim.o.lines - opts.height) / 2) - 1)
        local menu_col = math.floor((vim.o.columns - combined_width) / 2)
        menu_col = math.max(0, menu_col)
        menu_row = math.max(1, menu_row)

        vim.api.nvim_win_set_config(
            optionsPopup:get_win_id(),
            {
                relative = "editor",
                row = menu_row,
                col = menu_col,
                width = opts.menu_width,
                height = opts.height,
            }
        )

        local prev_col = menu_col + opts.menu_width + 1
        if opts.border then prev_col = prev_col + 1 end

        vim.api.nvim_win_set_config(
            previewPopup:get_win_id(),
            {
                relative = "editor",
                row = menu_row,
                col = prev_col,
                width = opts.preview_width,
                height = opts.height
            }
        )
    end

    ---@diagnostic disable-next-line inject-field
    optionsPopup.previewAutocommand = vim.api.nvim_create_autocmd(
        {
            "CursorMoved"
        },
        {
            callback = function ()
                local col = vim.api.nvim_win_get_cursor(0)[1]
                if col <= 0 or col > #actions then return end

                local val_or_func = actions[col].preview
                ---@type string[]
                local val
                if type(val_or_func) == "function" then
                    val = val_or_func()
                else
                    val = val_or_func
                end

                previewPopup:set_text(val)
            end
        }
    )

    ---@diagnostic disable invisible
    optionsPopup.opts.on_close = function()
        if optionsPopup.previewAutocommand ~= nil then
            vim.api.nvim_del_autocmd(optionsPopup.previewAutocommand)
            optionsPopup.previewAutocommand = nil
        end
        previewPopup:close()
    end
    ---@diagnostic enable invisible

    ---@diagnostic disable-next-line inject-field
    optionsPopup.preview = previewPopup

    optionsPopup:resize()

    return optionsPopup
end

return M
