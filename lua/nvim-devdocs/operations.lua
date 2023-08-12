local M = {}

local curl = require("plenary.curl")
local path = require("plenary.path")

local list = require("nvim-devdocs.list")
local notify = require("nvim-devdocs.notify")
local transpiler = require("nvim-devdocs.transpiler")
local plugin_config = require("nvim-devdocs.config").get()

local devdocs_site_url = "https://devdocs.io"
local devdocs_cdn_url = "https://documents.devdocs.io"
local docs_dir = path:new(plugin_config.dir_path, "docs")
local registery_path = path:new(plugin_config.dir_path, "registery.json")
local index_path = path:new(plugin_config.dir_path, "index.json")

M.fetch = function()
  notify.log("Fetching DevDocs registery...")

  curl.get(devdocs_site_url .. "/docs.json", {
    callback = function(response)
      local dir_path = path:new(plugin_config.dir_path)
      local file_path = path:new(plugin_config.dir_path, "registery.json")

      if not dir_path:exists() then dir_path:mkdir() end

      file_path:write(response.body, "w", 438)

      notify.log("DevDocs registery has been written to the disk")
    end,
    on_error = function(error)
      notify.log_err("nvim-devdocs: Error when fetching registery, exit code: " .. error.exit)
    end,
  })
end

M.install = function(entry, verbose, is_update)
  if not registery_path:exists() then
    if verbose then notify.log_err("DevDocs registery not found, please run :DevdocsFetch") end
    return
  end

  local alias = entry.slug:gsub("~", "-")
  local doc_path = path:new(docs_dir, alias .. ".json")

  if not docs_dir:exists() then docs_dir:mkdir() end
  if not index_path:exists() then index_path:write("{}", "w", 438) end

  if not is_update and doc_path:exists() then
    if verbose then notify.log("Documentation for " .. alias .. " is already installed") end
  else
    local doc_url = string.format("%s/%s/db.json?%s", devdocs_cdn_url, entry.slug, entry.mtime)

    notify.log((is_update and "Updating " or "Installing ") .. alias .. " documentation...")
    curl.get(doc_url, {
      callback = function(response)
        doc_path:write(response.body, "w", 438)
        notify.log(alias .. " documentation has been " .. (is_update and "updated" or "installed"))
      end,
      on_error = function(error)
        notify.log_err(
          "nvim-devdocs[" .. alias .. "]: Error during download, exit code: " .. error.exit
        )
      end,
    })

    local index_url = string.format("%s/%s/index.json?%s", devdocs_cdn_url, entry.slug, entry.mtime)

    curl.get(index_url, {
      callback = vim.schedule_wrap(function(response)
        local index_content = index_path:read()
        local index_parsed = vim.fn.json_decode(index_content)
        local response_parsed = vim.fn.json_decode(response.body)

        response_parsed.mtime = entry.mtime
        index_parsed[alias] = response_parsed
        index_path:write(vim.fn.json_encode(index_parsed), "w", 438)
        notify.log(alias .. " documentation has been indexed")
      end),
      on_error = function(error)
        notify.log_err(
          "nvim-devdocs[" .. alias .. "]: Error during download, exit code: " .. error.exit
        )
      end,
    })
  end
end

M.install_args = function(args, verbose, is_update)
  if not registery_path:exists() then
    if verbose then notify.log_err("DevDocs registery not found, please run :DevdocsFetch") end
    return
  end

  local updatable = list.get_updatable()
  local content = registery_path:read()
  local parsed = vim.fn.json_decode(content)

  for _, arg in ipairs(args) do
    local slug = arg:gsub("-", "~")
    local data = {}

    for _, entry in ipairs(parsed) do
      if entry.slug == slug then
        data = entry
        break
      end
    end

    if vim.tbl_isempty(data) then
      notify.log_err("No documentation available for " .. arg)
    else
      if is_update and not vim.tbl_contains(updatable, arg) then
        notify.log(arg .. " documentation is already up to date")
      else
        M.install(data, verbose, is_update)
      end
    end
  end
end

M.uninstall = function(alias)
  local file_path = path:new(docs_dir, alias .. ".json")

  if not file_path:exists() then
    notify.log(alias .. " documentation is already uninstalled")
  else
    local index = index_path:read()
    local parsed = vim.fn.json_decode(index)

    parsed[alias] = nil

    if vim.tbl_isempty(parsed) then
      index_path:write("{}", "w", 438)
    else
      index_path:write(vim.fn.json_encode(parsed), "w", 438)
    end

    file_path:rm()
    notify.log(alias .. " documentation has been uninstalled")
  end
end

M.get_entry = function(alias, entry_path)
  local file_path = path:new(plugin_config.dir_path, "docs", alias .. ".json")

  if index_path:exists() or not file_path:exists() then
    local content = file_path:read()
    local parsed = vim.fn.json_decode(content)
    local main_path = vim.split(entry_path, "#")[1]
    local entry = { key = main_path, value = parsed[main_path] }

    return entry
  end
end

M.get_entries = function(alias)
  local file_path = path:new(plugin_config.dir_path, "docs", alias .. ".json")

  if not index_path:exists() or not file_path:exists() then return end

  local entries = {}
  local index_content = index_path:read()
  local index_parsed = vim.fn.json_decode(index_content)
  local docs_content = file_path:read()
  local docs_decoded = vim.fn.json_decode(docs_content)

  for _, entry in pairs(index_parsed[alias].entries) do
    local doc = ""
    local entry_path = vim.split(entry.path, "#")
    local local_path = entry_path[2] and entry_path[2] or entry_path[1]

    for doc_entry, value in pairs(docs_decoded) do
      if string.lower(doc_entry) == string.lower(entry_path[1]) then doc = value end
    end

    table.insert(entries, { name = entry.name, path = local_path, value = doc })
  end

  table.insert(entries, { name = "index", path = "index", value = docs_decoded["index"] })

  return entries
end

M.get_all_entries = function()
  if not index_path:exists() then return end

  local entries = {}
  local index_content = index_path:read()
  local index_parsed = vim.fn.json_decode(index_content)

  for alias, index in pairs(index_parsed) do
    for _, doc_entry in ipairs(index.entries) do
      local entry = {
        name = string.format("[%s] %s", alias, doc_entry.name),
        alias = alias,
        path = doc_entry.path,
      }
      table.insert(entries, entry)
    end
  end

  return entries
end

M.open = function(entry, float)
  local markdown = transpiler.html_to_md(entry.value)
  local lines = vim.split(markdown, "\n")
  local buf = vim.api.nvim_create_buf(not float, true)

  vim.bo[buf].ft = "markdown"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)

  if not float then
    vim.api.nvim_set_current_buf(buf)
  else
    local ui = vim.api.nvim_list_uis()[1]
    local row = (ui.height - plugin_config.float_win.height) * 0.5
    local col = (ui.width - plugin_config.float_win.width) * 0.5
    local float_opts = plugin_config.float_win

    if not plugin_config.row then float_opts.row = row end
    if not plugin_config.col then float_opts.col = col end

    local win = vim.api.nvim_open_win(buf, true, float_opts)

    vim.wo[win].wrap = plugin_config.wrap
    vim.wo[win].linebreak = plugin_config.wrap
    vim.wo[win].nu = false
    vim.wo[win].relativenumber = false
  end
end

return M
