local M = {}

local path = require("plenary.path")
local scandir = require("plenary.scandir")

local notify = require("nvim-devdocs.notify")
local plugin_config = require("nvim-devdocs.config").get()

local docs_dir = path:new(plugin_config.dir_path, "docs")
local index_path = path:new(plugin_config.dir_path, "index.json")
local registery_path = path:new(plugin_config.dir_path, "registery.json")

M.get_installed_alias = function()
  if not docs_dir:exists() then return {} end

  local files = scandir.scan_dir(path.__tostring(docs_dir), { all_dirs = false })
  local installed = vim.tbl_map(function(file_path)
    local splited = path._split(path:new(file_path))
    local filename = splited[#splited]
    local basename = filename:gsub(".json", "")
    return basename
  end, files)

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
  if not registery_path:exists() then return {} end

  local results = {}
  local registery_content = registery_path:read()
  local registery_parsed = vim.fn.json_decode(registery_content)
  local index_content = index_path:read()
  local index_parsed = vim.fn.json_decode(index_content)

  for alias, value in pairs(index_parsed) do
    local slug = alias:gsub("-", "~")

    for _, doc in pairs(registery_parsed) do
      if doc.slug == slug and doc.mtime > value.mtime then table.insert(results, alias) end
    end
  end

  return results
end

return M
