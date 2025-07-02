local Popup = require("oneup.popup")
local OptionsPopup = require("oneup.options_popup")

---@alias PreviewedOption { text: string, preview: (string[] | fun(option: PreviewedOption): string[]), [any]: any }
---
---@class PreviewedOptionsPopup: Popup
---@field private preview_popup Popup
---@field private update_aucmd integer
---@field private border boolean
---@field private options PreviewedOption[]
local PreviewedOptionsPopup = {}
PreviewedOptionsPopup.__index = PreviewedOptionsPopup
setmetatable(PreviewedOptionsPopup, {
    __index = OptionsPopup,
    __call = function (cls, ...)
    local self = setmetatable({}, cls)
    self:new(...)
    return self
  end,
})

---@class PreviewedOptionsPopupPreviewOpts
---@field title string?         the title to display on the popup, useless if border is not true
---@field width string?         the width of the popup (may be a percent) sets width based on text if nil
---@field min_width integer?    the absolute minimum width for the popup. useless if width is not a percentage

---@class PreviewedOptionsPopupOptionsOpts
---@field title string?         the title to display on the popup, useless if border is not true
---@field width string?         the width of the popup (may be a percent) sets width based on text if nil
---@field min_width integer?    the absolute minimum width for the popup. useless if width is not a percentage

---@class PreviewedOptionsPopupOpts
---@field preview_opts PreviewedOptionsPopupPreviewOpts
---@field options_opts PreviewedOptionsPopupOptionsOpts
---@field options PreviewedOption[]     A list of options that may be selected from
---@field height string?        the height of the popup (may be a percent) sets height based on text if nil
---@field min_height integer?   the absolute minimum height for the popup. useless if height is not a percentage
---@field border boolean?       border?
---@field persistent boolean?   Whether or not the popup will persist once window has been exited
---@field on_close function?    function to run when the popup is closed

---@param opts PreviewedOptionsPopupOpts the options for the given popup
---@param enter boolean whether or not to immediately focus the popup
function PreviewedOptionsPopup:new(opts, enter)
    local prevPopup = Popup:new({
        text = {},
        title = opts.preview_opts.title,
        width = opts.preview_opts.width,
        height = opts.height,
        min_width = opts.preview_opts.min_width,
        min_height = opts.min_height,
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
        min_width = opts.options_opts.min_width,
        min_height = opts.min_height,
        border = opts.border,
        persistent = opts.persistent,
    }, enter)

    optsPopup.update_aucmd = vim.api.nvim_create_autocmd(
        { "CursorMoved" },
        {
            callback = function ()
                local col = vim.api.nvim_win_get_cursor(0)[1]
                if col <= 0 or col > #optsPopup.options then return end ---@diagnostic disable-line:invisible

                local val_or_func = optsPopup.options[col].preview ---@diagnostic disable-line:invisible
                ---@type string[]
                local val
                if type(val_or_func) == "function" then
                    val = val_or_func(optsPopup.options[col]) ---@diagnostic disable-line:invisible
                else
                    val = val_or_func
                end

                prevPopup:set_text(val)
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
    local opts_win_cfg = vim.api.nvim_win_get_config(self.window_id)
    local prev_win_cfg = vim.api.nvim_win_get_config(self.preview_popup.window_id)

    --calculate height
    local height = opts_win_cfg.height
    if self.height_mult ~= nil then
        height = math.floor( (vim.o.lines * self.height_mult) + 0.5)
        height = math.max(height, self.min_height)
    end
    local row = math.floor(((vim.o.lines - height) / 2) - 1)
    row = math.max(1, row)


    --calculate options popup width
    local opts_width = opts_win_cfg.width
    if self.width_mult ~= nil then
        opts_width = math.floor( (vim.o.columns * self.width_mult) + 0.5)
        opts_width = math.max(opts_width, self.min_width)
    end

    --calculate preview popup width
    local prev_width = prev_win_cfg.width
    if self.preview_popup.width_mult ~= nil then
        prev_width = math.floor( (vim.o.columns * self.preview_popup.width_mult) + 0.5)
        prev_width = math.max(prev_width, self.preview_popup.min_width)
    end

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
