local Popup = require("oneup.popup")
local utils = require("config.utils")


---@class InputPopup: Popup
local InputPopup = {}
setmetatable(InputPopup, getmetatable(Popup))

---@class InputPopupOpts
---@field text string[]                                 text to display on the popup as a list of lines
---@field title string?                                 the title to display on the popup, useless if border is not true
---@field width integer?                                the minimum width excluding the border
---@field border boolean?                               border?
---@field verify_input (fun(text:string):boolean)?,     function used to verify input before confirm function is ran
---@field on_confirm fun(text:string),                  function used to process input
---@field prompt string?                                possible prompt for input

---@param opts InputPopupOpts
---@param enter boolean whether or not to immediately focus the popup
---@return InputPopup
function InputPopup:new(opts, enter)
    local base_opts = {}

    base_opts.text = opts.text
    table.insert(base_opts.text,"")
    if opts.title ~= nil then
        base_opts.title = opts.title
    end
    if opts.width ~= nil then
        base_opts.width = opts.width
    end
    if opts.border ~= nil then
        base_opts.border = opts.border
    end
    base_opts.persistent = true

    ---@type InputPopup
    local base_popup = Popup:new(base_opts, enter) ---@diagnostic disable-line

    local buf = base_popup:get_buf_id()
    utils.set_buf_opts(
        buf,
        {
            buftype = "prompt",
            modifiable = true
        }
    )
    vim.fn.prompt_setprompt(buf, opts.prompt or "")
    vim.fn.prompt_setcallback(buf,function (text)
        if opts.verify_input ~= nil then
            if not opts.verify_input(text) then
                vim.api.nvim_buf_set_lines(
                    buf,
                    ---@diagnostic disable-next-line: invisible
                    #vim.api.nvim_buf_get_lines(base_popup:get_buf_id(), 0, -1, false),
                    -1,
                    false,
                    {}
                )
                vim.cmd("startinsert!")
                print("Invalid input '"..text.."'.")
                return
            end
        end
        opts.on_confirm(text)
        base_popup:close()
    end)
    vim.cmd("startinsert")
    vim.schedule(function ()
        local close_aucmd = vim.api.nvim_create_autocmd(
            {
                "BufEnter",
                "UIEnter",
                "TabEnter",
                "WinEnter",
                "BufHidden",
                "BufWipeout",
                "BufLeave",
                "BufWinLeave",
                "ModeChanged"
            },
            {
                callback = function ()
                    base_popup:close()
                end
            }
        )
        ---@diagnostic disable-next-line: invisible
        base_popup.close_aucmd = close_aucmd
    end)

    return base_popup
end

return InputPopup
