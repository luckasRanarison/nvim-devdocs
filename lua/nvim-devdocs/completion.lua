local M = {}

local list = require("nvim-devdocs.list")

---@param arg_lead string
---@return string[]
M.get_non_installed = function(arg_lead)
  if not REGISTERY_PATH:exists() then return {} end

  local content = REGISTERY_PATH:read()
  local parsed = vim.fn.json_decode(content)
  local installed = list.get_installed_alias()
  local args = {}

  for _, entry in pairs(parsed) do
    local arg = entry.slug:gsub("~", "-")
    local starts_with = string.find(arg, arg_lead, 1, true) == 1
    if starts_with and not vim.tbl_contains(installed, arg) then table.insert(args, arg) end
  end

  return args
end

---@param arg_lead string
---@return string[]
M.get_installed = function(arg_lead)
  local installed = list.get_installed_alias()
  local args = vim.tbl_filter(function(entry)
    local starts_with = string.find(entry, arg_lead, 1, true) == 1
    if starts_with then return true end
    return false
  end, installed)

  return args
end

---@param arg_lead string
---@return string[]
M.get_updatable = function(arg_lead)
  local updatable = list.get_updatable()
  local args = vim.tbl_filter(function(entry)
    local starts_with = string.find(entry, arg_lead, 1, true) == 1
    if starts_with then return true end
    return false
  end, updatable)

  return args
end

return M
