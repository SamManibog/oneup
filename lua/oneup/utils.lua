local M = {}

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
