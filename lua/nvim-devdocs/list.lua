local M = {}

local path = require("plenary.path")

local notify = require("nvim-devdocs.notify")
local plugin_config = require("nvim-devdocs.config").get()

local lock_path = path:new(plugin_config.dir_path, "docs-lock.json")
local registery_path = path:new(plugin_config.dir_path, "registery.json")

M.get_installed_alias = function()
  if not lock_path:exists() then return {} end

  local lockfile = lock_path:read()
  local lock_parsed = vim.fn.json_decode(lockfile)
  local installed = vim.tbl_keys(lock_parsed)

  return installed
end

M.get_installed_entry = function()
  if not registery_path:exists() then
    notify.log_err("Devdocs registery not found, please run :DevdocsFetch")
    return
  end

  local content = registery_path:read()
  local parsed = vim.fn.json_decode(content)
  local installed = M.get_installed_alias()

  local results = vim.tbl_filter(function(entry)
    for _, alias in pairs(installed) do
      if entry.slug == alias:gsub("-", "~") then return true end
    end
    return false
  end, parsed)

  return results
end

M.get_updatable = function()
  if not registery_path:exists() or not lock_path:exists() then return {} end

  local results = {}
  local registery = registery_path:read()
  local registery_parsed = vim.fn.json_decode(registery)
  local lockfile = lock_path:read()
  local lock_parsed = vim.fn.json_decode(lockfile)

  for alias, value in pairs(lock_parsed) do
    for _, doc in pairs(registery_parsed) do
      if doc.slug == value.slug and doc.mtime > value.mtime then
        table.insert(results, alias)
        break
      end
    end
  end

  return results
end

return M
