local Popup = require("oneup.popup")
local utils = require("oneup.utils")

---@class PromptPopup: Popup
---@field verify_input (fun(text:string):boolean)?,     function used to verify input before confirm function is ran
---@field on_confirm fun(text:string),                  function used to process input
---@field private text string[]
local PromptPopup = {}
PromptPopup.__index = PromptPopup
setmetatable(PromptPopup, Popup)

---@class PromptPopupOpts
---@field text string[]                                 text to display on the popup as a list of lines
---@field title string?                                 the title to display on the popup, useless if border is not true
---@field width AdvLength|length
---@field height AdvLength|length
---@field border boolean?                               border?
---@field verify_input (fun(text:string):boolean)?,     function used to verify input before confirm function is ran
---@field on_confirm fun(text:string),                  function used to process input
---@field prompt string?                                possible prompt for input
---@field on_close function?     function to run when the popup is closed
---@field close_bind string[]|string|nil

---@param opts PromptPopupOpts popup options
---@param enter boolean whether or not to immediately focus the popup
---@return PromptPopup
function PromptPopup:new(opts, enter)
    ---@type PopupOpts
    local base_opts = {
        text = opts.text,
        title = opts.title,
        width = opts.width,
        border = opts.border,
        persistent = true,
        close_bind = opts.close_bind,
        on_close = opts.on_close
    }

    table.insert(base_opts.text,"")

    ---@type PromptPopup
    local out = Popup:new(base_opts, enter) ---@diagnostic disable-line: assign-type-mismatch
    out.text = opts.text
    out.verify_input = opts.verify_input
    out.on_confirm = opts.on_confirm

    local buf = out:bufId()
    utils.set_buf_opts(
        buf,
        {
            buftype = "prompt",
            modifiable = true
        }
    )
    vim.fn.prompt_setprompt(buf, opts.prompt or "")
    vim.fn.prompt_setcallback(buf, function (text)
        Popup.setText(out, out.text) ---@diagnostic disable-line: invisible
        if out.verify_input ~= nil then
            if not out.verify_input(text) then
                vim.api.nvim_buf_set_lines(
                    buf,
                    ---@diagnostic disable-next-line: invisible
                    #vim.api.nvim_buf_get_lines(out:bufId(), 0, -1, false),
                    -1,
                    false,
                    {}
                )
                vim.cmd("startinsert!")
                print("Invalid input '"..text.."'.")
                return
            end
        end
        out.on_confirm(text)
        out:close()
    end)
    vim.cmd("startinsert")
    vim.schedule(function ()
        local close_aucmd = vim.api.nvim_create_autocmd(
            {
                "BufLeave",
                "ModeChanged"
            },
            {
                callback = function ()
                    out:close()
                end
            }
        )
        ---@diagnostic disable-next-line: invisible
        out.close_aucmd = close_aucmd
    end)

    setmetatable(out, self)

    return out
end

---sets the text of the prompt popup
---@param text string[] the text to set for the popup as a list of lines
function PromptPopup:setText(text)
    self.text = text
    Popup.setText(self, text)
end

return PromptPopup
