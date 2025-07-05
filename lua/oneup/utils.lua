local M = {}

---@alias length string|number|nil

---@class AdvLength
---@field min length the minimum value, nil -> 0
---@field max length the maximum value, nil -> infinity
---@field value length the value, nil -> min

---gets the integer value for a number or percent given a whole length
---@param value length
---@param whole integer
---@param default? integer
---@return integer
function M.getLength(value, whole, default)
    if type(value) == "nil" then
        return default or 0
    elseif type(value) == "string" then
        if value:sub(-1) == "%" then
            return math.floor(tonumber(value:sub(1, -2)) / 100.0 * whole + 0.5) ---@diagnostic disable-line:param-type-mismatch
        else
            return math.floor(tonumber(value) + 0.5) ---@diagnostic disable-line:param-type-mismatch
        end
    elseif type(value) == "number" then
        return math.floor(value + 0.5)
    else
        error("Value '"..value.."' could not be converted to an integer")
    end
end

---gets the integer value for a number or percent in the horizontal direction
---@param value length
---@return integer
function M.getLengthH(value)
    return M.getLength(value, vim.o.columns)
end

---gets the integer value for a number or percent in the vertical direction
---@param value length
---@return integer
function M.getLengthV(value)
    return M.getLength(value, vim.o.lines)
end

---gets the logical integer length given an AdvLength
---@param length AdvLength
---@param horizontal boolean
---@return integer
function M.advToInteger(length, horizontal)
    local whole
    if horizontal then
        whole = vim.o.columns
    else
        whole = vim.o.lines
    end

    local min = M.getLength(length.min, whole, 0)
    local max = M.getLength(length.max, whole, whole)
    local val = M.getLength(length.value, whole, min)

    return math.max(math.min(val, max), min)
end

---Sets a options from a table for a given buffer
---@param buf_id number
---@param opts table
function M.set_buf_opts(buf_id, opts)
    for option, value in pairs(opts) do
        vim.api.nvim_set_option_value(
            option,
            value,
            {
                buf = buf_id
            }
        )
    end
end

return M
