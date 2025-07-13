local Text = require("oneup.text")

---@class Line
---@field align Align
---@field text Text[]
---@field hl_group string?
---@field hl_priority number
local Line = {}
Line.__index = Line

setmetatable(Line, {
    __call = function(cls, text, opts)
        return cls.new(text, opts)
    end
})

local ns = vim.api.nvim_create_namespace("oneup")

---@param text string|Text[] the content of the object
---@param opts? { hl_group: string?, hl_priority: number?, align: Align?}
---@return Line
function Line.new(text, opts)
    opts = opts or {}
    local self = setmetatable({}, Line)
    if type(text) == "string" then
        self.text = { Text(text) }
    else
        self.text = text
    end
    self.align = opts.align or "left"
    self.hl_group = opts.hl_group
    self.hl_priority = opts.hl_priority or 0
    return self
end

---@param buf number the id of the buffer to render the line to
---@param line integer the 0-indexed line number in the buffer to render to
---@param width integer the width of the buffer (for performance)
function Line:render(buf, line, width)
    ---@type string the text to render to the line
    local line_text = ""

    ---@type integer the total width of the text
    local text_width = 0

    ---@type integer[] the start columns of each text block with a highlight group
    local text_starts = {}

    ---@type Text[] a list of text blocks with a highlight group
    local hl_text = {}

    for _, text in ipairs(self.text) do
        if text.hl_group ~= nil then
            table.insert(text_starts, text_width)
            table.insert(hl_text, text)
        end

        local txt = text.text
        text_width = text_width + #txt
        line_text = line_text .. txt
    end

    --handle alignment
    if width - text_width > 0 then
        local padding = 0
        if self.align == "right" then
            padding = width - text_width
            line_text = line_text .. string.rep(" ", padding)
        elseif self.align == "center" then
            padding = math.floor((width - text_width) / 2.0)
            line_text = line_text .. string.rep(" ", padding)
        end

        if padding > 0 then
            for idx, col in ipairs(text_starts) do
                text_starts[idx] = col + padding
            end
        end
    end

    vim.api.nvim_buf_set_lines(buf, line, line + 1, false, { line_text })

    --handle text block highlighting
    for idx, text in ipairs(hl_text) do
        local col = text_starts[idx]
        vim.api.nvim_buf_set_extmark(buf, ns, line, col, {
            end_row = line,
            end_col = col + #text.text,
            priority = text.hl_priority,
            hl_group = text.hl_group,
        })
    end

    if self.hl_group == nil then return end

    --handle line highlighting
    vim.api.nvim_buf_set_extmark(buf, ns, line, 0, {
        end_row = line,
        line_hl_group = self.hl_group,
        priority = self.hl_priority,
    })
end

return Line
