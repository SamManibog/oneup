local Popup = require("oneup.popup")
local OptionsPopup = require("oneup.options_popup")

---@alias PreviewedOption { text: string, preview_callback: (string[] | fun(option: PreviewedOption): string[]), [any]: any }
---
---@class PreviewedOptionsPopup: Popup
---@field previewPopup Popup
---@field options PreviewedOption[]
local PreviewedOptionsPopup = {}
PreviewedOptionsPopup.__index = PreviewedOptionsPopup
setmetatable(PreviewedOptionsPopup, OptionsPopup)

---@class PreviewedOptionsPopupPreviewOpts
---@field title string?         the title to display on the popup, useless if border is not true
---@field width string?         the width of the popup (may be a percent) sets width based on text if nil
---@field height string?        the height of the popup (may be a percent) sets height based on text if nil
---@field min_width integer?    the absolute minimum width for the popup. useless if width is not a percentage
---@field min_height integer?   the absolute minimum height for the popup. useless if height is not a percentage

---@class PreviewedOptionsPopupOptionsOpts
---@field title string?         the title to display on the popup, useless if border is not true
---@field width string?         the width of the popup (may be a percent) sets width based on text if nil
---@field height string?        the height of the popup (may be a percent) sets height based on text if nil
---@field min_width integer?    the absolute minimum width for the popup. useless if width is not a percentage
---@field min_height integer?   the absolute minimum height for the popup. useless if height is not a percentage

---@class PreviewedOptionsPopupOpts
---@field preview_opts PreviewedOptionsPopupPreviewOpts
---@field options_opts PreviewedOptionsPopupOptionsOpts
---@field options PreviewedOption[]     A list of options that may be selected from
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
        height = opts.preview_opts.height,
        min_width = opts.preview_opts.min_width,
        min_height = opts.preview_opts.min_height,
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
        height = opts.options_opts.height,
        min_width = opts.options_opts.min_width ,
        min_height = opts.options_opts.min_height ,
        border = opts.border ,
        persisten = opts.persistent,
        on_close = opts.on_close,
    }, enter)
    optsPopup.previewPopup = prevPopup

    setmetatable(optsPopup, self)

    return optsPopup
end

return PreviewedOptionsPopup
