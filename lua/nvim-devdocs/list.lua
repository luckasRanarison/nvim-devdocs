local M = {}

local notify = require("nvim-devdocs.notify")

M.get_installed_alias = function()
  if not LOCK_PATH:exists() then return {} end

  local lockfile = LOCK_PATH:read()
  local lock_parsed = vim.fn.json_decode(lockfile)
  local installed = vim.tbl_keys(lock_parsed)

  return installed
end

M.get_installed_entry = function()
  if not REGISTERY_PATH:exists() then
    notify.log_err("Devdocs registery not found, please run :DevdocsFetch")
    return
  end

  local content = REGISTERY_PATH:read()
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
  if not REGISTERY_PATH:exists() or not LOCK_PATH:exists() then return {} end

  local results = {}
  local registery = REGISTERY_PATH:read()
  local registery_parsed = vim.fn.json_decode(registery)
  local lockfile = LOCK_PATH:read()
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
