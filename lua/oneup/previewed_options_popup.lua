local Popup = require("oneup.popup")
local OptionsPopup = require("oneup.options_popup")
local utils = require("oneup.utils")

---@alias PreviewedOption { text: string, preview: (string[] | fun(option: PreviewedOption): string[]), [any]: any }
---
---@class PreviewedOptionsPopup: OptionsPopup
---@field private preview_popup Popup
---@field private update_aucmd integer
---@field private border boolean
---@field private options PreviewedOption[]
local PreviewedOptionsPopup = {}
PreviewedOptionsPopup.__index = PreviewedOptionsPopup
setmetatable(PreviewedOptionsPopup, OptionsPopup)

---@class PreviewedOptionsPopupPreviewOpts
---@field title string?             the title to display on the popup, useless if border is not true
---@field width AdvLength|length    the width of the popup

---@class PreviewedOptionsPopupOptionsOpts
---@field title string?         the title to display on the popup, useless if border is not true
---@field width AdvLength|length    the width of the popup

---@class PreviewedOptionsPopupOpts
---@field preview_opts PreviewedOptionsPopupPreviewOpts
---@field options_opts PreviewedOptionsPopupOptionsOpts
---@field options PreviewedOption[]     A list of options that may be selected from
---@field height AdvLength|length       the height of both popups
---@field border boolean?               border?
---@field persistent boolean?           Whether or not the popup will persist once window has been exited
---@field on_close function?            function to run when the popup is closed

---@param opts PreviewedOptionsPopupOpts the options for the given popup
---@param enter boolean whether or not to immediately focus the popup
function PreviewedOptionsPopup:new(opts, enter)
    local prevPopup = Popup:new({
        text = {},
        title = opts.preview_opts.title,
        width = opts.preview_opts.width,
        height = opts.height,
        border = opts.border,
        focusable = false,
        modifiable = true,
        persistent = true
    }, false)
    prevPopup.resize = function(_) end

    ---@type PreviewedOptionsPopup
    ---@diagnostic disable-next-line:assign-type-mismatch
    local optsPopup = OptionsPopup:new({
        options = opts.options,
        title = opts.options_opts.title,
        width = opts.options_opts.width,
        height = opts.height,
        border = opts.border,
        persistent = opts.persistent,
    }, enter)

    optsPopup.update_aucmd = vim.api.nvim_create_autocmd(
        { "CursorMoved" },
        {
            callback = function ()
                local option = optsPopup:get_option()
                if option == nil then return end

                local val_or_func = option.preview---@diagnostic disable-line:invisible
                ---@type string[]
                local val
                if type(val_or_func) == "function" then
                    val = val_or_func(option) ---@diagnostic disable-line:invisible
                else
                    val = val_or_func
                end

                prevPopup:setText(val)
            end
        }
    )

    optsPopup.preview_popup = prevPopup
    optsPopup.border = opts.border
    if opts.border == nil then optsPopup.border = true end
    optsPopup.on_close = function () ---@diagnostic disable-line:invisible
        prevPopup:close()
        if optsPopup.update_aucmd ~= nil then ---@diagnostic disable-line:invisible
            vim.api.nvim_del_autocmd(optsPopup.update_aucmd) ---@diagnostic disable-line:invisible
            self.update_aucmd = nil
        end
        if opts.on_close ~= nil then
            opts.on_close()
        end
    end

    setmetatable(optsPopup, self)
    optsPopup:resize()

    return optsPopup
end

---@diagnostic disable:invisible
function PreviewedOptionsPopup:resize()
    --calculate height
    local height = utils.advToInteger(self.height, false)
    local row = math.floor(((vim.o.lines - height) / 2) - 1)
    row = math.max(1, row)


    --calculate options popup width
    local opts_width = utils.advToInteger(self.width, false)

    --calculate preview popup width
    local prev_width = utils.advToInteger(self.preview_popup.width, false)

    local width = opts_width + prev_width + 1
    if self.border then width = width + 1 end

    local opts_col = math.floor((vim.o.columns - width) / 2)
    opts_col = math.max(0, opts_col)

    local prev_col = opts_col + opts_width + 1
    if self.border then prev_col = prev_col + 1 end

    vim.api.nvim_win_set_config(
        self.window_id,
        {
            relative = "editor",
            row = row,
            col = opts_col,
            width = opts_width,
            height = height,
        }
    )
    vim.api.nvim_win_set_config(
        self.preview_popup.window_id,
        {
            relative = "editor",
            row = row,
            col = prev_col,
            width = prev_width,
            height = height,
        }
    )
end
---@diagnostic enable:invisible

return PreviewedOptionsPopup
