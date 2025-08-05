---@alias Align
---| '"left"'
---| '"center"'
---| '"right"'

---@alias length string|number|nil

---@class AdvLength
---@field min length the minimum value, nil -> 0
---@field max length the maximum value, nil -> infinity
---@field value length the value, nil -> min
