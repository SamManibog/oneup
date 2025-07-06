local Popup = require("oneup.popup")
local OptionsPopup = require("oneup.options_popup")
local PreviewedOptionsPopup = require("oneup.previewed_options_popup")
local utils = require("oneup.utils")

---@alias ConfigFieldType
---| '"string"'
---| '"number"'
---| '"boolean"'
---| '"option"'
---| '"string list"'
---| '"number list"'
---| '"boolean list"'

---@alias ConfigOption { name: string, type: ConfigFieldType, verify: (fun(value): boolean)?, [any]: any } | { name: string, type: "option", options: (fun(): Option[])|Option[], [any]: any }

---@class ConfigPopupSubmenuOpts
---@field width  AdvLength|length
---@field height AdvLength|length

---@class ConfigPopupOpts
---@field fields ConfigOption[]
---@field big_input_opts ConfigPopupSubmenuOpts     customization for larger field editors
---@field small_input_width AdvLength|length        customization for single-line field editors
---@field preview_opts PreviewedOptionsPopupSubmenuOpts
---@field options_opts PreviewedOptionsPopupSubmenuOpts
---@field height AdvLength|length       the height of the config popup
---@field border boolean?               border?
---@field persistent boolean?           Whether or not the popup will persist once window has been exited
---@field on_close function?            function to run when the popup is closed

---@class ConfigPopup: PreviewedOptionsPopup
---@field options ConfigOption[]
---@field opts ConfigPopupOpts  used to reopen the menu after temporary closes
---@field true_close boolean    used to block the on_close event from running when closing to open a new menu

local ConfigPopup = {}
ConfigPopup.__index = ConfigPopup
setmetatable(ConfigPopup, PreviewedOptionsPopup)

---@param opts ConfigPopupOpts the options to create the popup with
---@param enter boolean whether or not to immediately enter the popup upon creation
---@return ConfigPopup
function ConfigPopup:new(opts, enter)
    ---@type ConfigPopup
    local p = PreviewedOptionsPopup:new({---@diagnostic disable-line:assign-type-mismatch
        options = opts.fields,
        preview_opts = opts.preview_opts,
        options_opts = opts.options_opts,
        height = opts.height,
        border = opts.border,
        persistent = opts.persistent,
        on_close = opts.on_close
    }, enter)
    p.opts = opts
    p.true_close = true

    return p
end

function ConfigPopup:close()
    if not self.closed then
        -- self.closed variable is necessary to prevent double firing
        self.closed = true
        if self.true_close and self.on_close ~= nil then self.on_close() end

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

return ConfigPopup
