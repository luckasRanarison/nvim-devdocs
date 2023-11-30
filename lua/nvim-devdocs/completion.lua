local M = {}

local list = require("nvim-devdocs.list")

---@param args string[]
---@param arg_lead string
local function filter_args(args, arg_lead)
  return vim.tbl_filter(function(entry)
    local starts_with = string.find(entry, arg_lead, 1, true) == 1
    if starts_with then return true end
    return false
  end, args)
end

M.get_installed = function(arg_lead)
  local installed = list.get_installed_alias()
  return filter_args(installed, arg_lead)
end

M.get_non_installed = function(arg_lead)
  local non_installed = list.get_non_installed_alias()
  return filter_args(non_installed, arg_lead)
end

M.get_updatable = function(arg_lead)
  local updatable = list.get_updatable()
  return filter_args(updatable, arg_lead)
end

return M
