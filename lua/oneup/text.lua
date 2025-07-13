---@class Text
---@field text string
---@field hl_group string?
---@field hl_priority number
local Text = {}
Text.__index = Text
setmetatable(Text, {
    __call = function(cls, ...)
        return cls.new(...)
    end
})

---@param text string the content of the object
---@param opts? { hl_group: string?, hl_priority: number? }
---@return Text
function Text.new(text, opts)
    opts = opts or {}
    local self = setmetatable({}, Text)
    self.text = text
    self.hl_group = opts.hl_group
    self.hl_priority = opts.hl_priority or 0
    return self
end

return Text
