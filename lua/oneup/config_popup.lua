--local Popup = require("oneup.popup")
--local OptionsPopup = require("oneup.options_popup")
local PreviewedOptionsPopup = require("oneup.previewed_options_popup")

---@alias ConfigFieldType
---| '"string"'
---| '"number"'
---| '"boolean"'
---| '"option"'
---| '"string list"'
---| '"number list"'
---| '"boolean list"'

---@alias ConfigOption { type: ConfigFieldType, verify: (fun(value): boolean)?, default: any }

---@class ConfigPopupSubmenuOpts
---@field width  AdvLength|length
---@field height AdvLength|length

---@class ConfigPopupOpts
---@field fields table<string, ConfigOption>
---@field big_input_opts ConfigPopupSubmenuOpts     customization for larger field editors
---@field small_input_width AdvLength|length        customization for single-line field editors
---@field preview_opts PreviewedOptionsPopupSubmenuOpts
---@field options_opts PreviewedOptionsPopupSubmenuOpts
---@field height AdvLength|length       the height of the config popup
---@field border boolean?               border?
---@field persistent boolean?           Whether or not the popup will persist once window has been exited
---@field on_close function?            function to run when the popup is closed
---@field close_bind string[]|string|nil
---@field next_bind string[]|string|nil
---@field previous_bind string[]|string|nil
---@field edit_bind string[]|string|nil
---@field config table the initial config for the popup

---@class ConfigPopup: PreviewedOptionsPopup
---@field config table
---@field opts ConfigPopupOpts  used to reopen the menu after temporary closes
---@field true_close boolean    used to block the on_close event from running when closing to open a new menu
local ConfigPopup = {}
ConfigPopup.__index = ConfigPopup
setmetatable(ConfigPopup, PreviewedOptionsPopup)

---@param popup ConfigPopup
---@param name string
local function configPreview(popup, name)
    local preview
    local field_desc = popup.opts.fields[name]

    if popup.config[name] == nil then
        local prev_raw
        if type(field_desc.default) == "function" then
            prev_raw = field_desc.default()
        else
            prev_raw = field_desc.default
        end

        if type(prev_raw) == "table" then
            preview = {}
            for _, value in ipairs(prev_raw) do
                table.insert(preview, tostring(value))
            end
        else
            preview = { tostring(prev_raw) }
        end
    else
        local prev_raw = popup.config[name]

        if type(prev_raw) == "table" then
            preview = {}
            for _, value in ipairs(prev_raw) do
                table.insert(preview, tostring(value))
            end
        else
            preview = { tostring(prev_raw) }
        end
    end

    return preview
end

---@param opts ConfigPopupOpts the options to create the popup with
---@param enter boolean whether or not to immediately enter the popup upon creation
---@return ConfigPopup
function ConfigPopup:new(opts, enter)
    ---@type ConfigPopup
    local p

    ---@type PreviewedOption[]
    local options = {}
    for name, _ in pairs(opts.fields) do
        ---@param opt PreviewedOption
        local preview_func = function(opt)
            return configPreview(p, opt.text)
        end
        table.insert(options, {
            text = name,
            preview = preview_func
        })
    end

    ---@type ConfigPopup
    p = PreviewedOptionsPopup:new({---@diagnostic disable-line
        options = options,
        preview_opts = opts.preview_opts,
        options_opts = opts.options_opts,
        height = opts.height,
        border = opts.border,
        persistent = opts.persistent,
        on_close = opts.on_close,
        close_bind = opts.close_bind,
        next_bind = opts.next_bind,
        previous_bind = opts.previous_bind
    }, enter)
    p.opts = opts
    p.true_close = true
    p.config = vim.tbl_extend("keep", {}, opts.config)

    setmetatable(p, ConfigPopup)

    ---@diagnostic disable
    ---@type string[]
    local binds
    if opts.edit_bind == nil then
        binds = { "<CR>" }
    elseif type(opts.edit_bind) ~= "table" then
        binds = { opts.edit_bind } ---@diagnostic disable-line:assign-type-mismatch
    else
        binds = opts.edit_bind
    end
    for _, bind in pairs(binds) do
        p:setKeymap("n", bind, function() p:editField(p:getOption()) end)
    end
    ---@diagnostic enable

    ---@type ConfigPopup
    return p
end

function ConfigPopup:close()
    ---@diagnostic disable:invisible
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
    ---@diagnostic enable:invisible
end

---opens a menu to edit the configuration field with the given name
---@param name string
function ConfigPopup:editField(name)
    print(name)
    error("todo")
end

---returns the current configuration for the popup
---@return table
function ConfigPopup:getConfig()
    error("todo")
end

return ConfigPopup
