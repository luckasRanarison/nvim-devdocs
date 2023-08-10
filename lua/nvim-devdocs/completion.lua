local M = {}

local path = require("plenary.path")

local list = require("nvim-devdocs.list")
local plugin_config = require("nvim-devdocs.config").get()

M.get_non_installed = function(arg_lead)
  local registery_path = path:new(plugin_config.dir_path, "registery.json")

  if not registery_path:exists() then return {} end

  local content = registery_path:read()
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

M.get_installed = function(arg_lead)
  local installed = list.get_installed_alias()
  local args = vim.tbl_filter(function(entry)
    local starts_with = string.find(entry, arg_lead, 1, true) == 1
    if starts_with then return true end
    return false
  end, installed)

  return args
end

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
