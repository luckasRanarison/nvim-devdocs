local M = {}

local job = require("plenary.job")
local curl = require("plenary.curl")

local list = require("nvim-devdocs.list")
local state = require("nvim-devdocs.state")
local notify = require("nvim-devdocs.notify")
local config = require("nvim-devdocs.config")
local build_docs = require("nvim-devdocs.build")

local devdocs_site_url = "https://devdocs.io"
local devdocs_cdn_url = "https://documents.devdocs.io"

local plugin_config = config.get()

M.fetch = function()
  notify.log("Fetching DevDocs registery...")

  curl.get(devdocs_site_url .. "/docs.json", {
    headers = {
      ["User-agent"] = "chrome", -- fake user agent, see #25
    },
    callback = function(response)
      if not DATA_DIR:exists() then DATA_DIR:mkdir() end
      REGISTERY_PATH:write(response.body, "w", 438)
      notify.log("DevDocs registery has been written to the disk")
    end,
    on_error = function(error)
      notify.log_err("nvim-devdocs: Error when fetching registery, exit code: " .. error.exit)
    end,
  })
end

M.install = function(entry, verbose, is_update)
  if not REGISTERY_PATH:exists() then
    if verbose then notify.log_err("DevDocs registery not found, please run :DevdocsFetch") end
    return
  end

  local alias = entry.slug:gsub("~", "-")
  local installed = list.get_installed_alias()
  local is_installed = vim.tbl_contains(installed, alias)

  if not is_update and is_installed then
    if verbose then notify.log("Documentation for " .. alias .. " is already installed") end
  else
    local ui = vim.api.nvim_list_uis()

    if ui[1] and entry.db_size > 10000000 then
      local input = vim.fn.input({
        prompt = "Building large docs can freeze neovim, continue? y/n ",
      })

      if input ~= "y" then return end
    end

    local callback = function(index)
      local doc_url = string.format("%s/%s/db.json?%s", devdocs_cdn_url, entry.slug, entry.mtime)

      notify.log("Downloading " .. alias .. " documentation...")
      curl.get(doc_url, {
        callback = vim.schedule_wrap(function(response)
          local docs = vim.fn.json_decode(response.body)
          build_docs(entry, index, docs)
        end),
        on_error = function(error)
          notify.log_err(
            "nvim-devdocs[" .. alias .. "]: Error during download, exit code: " .. error.exit
          )
        end,
      })
    end

    local index_url = string.format("%s/%s/index.json?%s", devdocs_cdn_url, entry.slug, entry.mtime)

    notify.log("Fetching " .. alias .. " documentation entries...")
    curl.get(index_url, {
      callback = vim.schedule_wrap(function(response)
        local index = vim.fn.json_decode(response.body)
        callback(index)
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
  if not REGISTERY_PATH:exists() then
    if verbose then notify.log_err("DevDocs registery not found, please run :DevdocsFetch") end
    return
  end

  local updatable = list.get_updatable()
  local content = REGISTERY_PATH:read()
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
  local installed = list.get_installed_alias()

  if not vim.tbl_contains(installed, alias) then
    notify.log(alias .. " documentation is already uninstalled")
  else
    local index = vim.fn.json_decode(INDEX_PATH:read())
    local lockfile = vim.fn.json_decode(LOCK_PATH:read())
    local doc_path = config.new_path("docs", alias)

    index[alias] = nil
    lockfile[alias] = nil

    INDEX_PATH:write(vim.fn.json_encode(index), "w")
    LOCK_PATH:write(vim.fn.json_encode(lockfile), "w")
    doc_path:rm({ recursive = true })

    notify.log(alias .. " documentation has been uninstalled")
  end
end

M.get_entries = function(alias)
  local installed = list.get_installed_alias()
  local is_installed = vim.tbl_contains(installed, alias)

  if not INDEX_PATH:exists() or not is_installed then return end

  local index_parsed = vim.fn.json_decode(INDEX_PATH:read())
  local entries = index_parsed[alias].entries

  for key, _ in ipairs(entries) do
    entries[key].alias = alias
  end

  return entries
end

M.get_all_entries = function()
  if not INDEX_PATH:exists() then return {} end

  local entries = {}
  local index_parsed = vim.fn.json_decode(INDEX_PATH:read())

  for alias, index in pairs(index_parsed) do
    for _, doc_entry in ipairs(index.entries) do
      local entry = {
        name = string.format("[%s] %s", alias, doc_entry.name),
        alias = alias,
        path = doc_entry.path,
        link = doc_entry.link,
      }
      table.insert(entries, entry)
    end
  end

  return entries
end

M.filter_doc = function(lines, pattern)
  if not pattern then return lines end

  -- https://stackoverflow.com/a/34953646/516188
  local function create_pattern(text) return text:gsub("([^%w])", "%%%1") end

  local filtered_lines = {}
  local found = false
  local search_pattern = create_pattern(pattern)
  local split = vim.split(pattern, " ")
  local header = split[1]
  local top_header = header and header:sub(1, #header - 1)

  for _, line in ipairs(lines) do
    if found and header then
      local line_split = vim.split(line, " ")
      local first = line_split[1]
      if first and first == header or first == top_header then break end
    end
    if line:match(search_pattern) then found = true end
    if found then table.insert(filtered_lines, line) end
  end

  return filtered_lines
end

M.render_cmd = function(bufnr, is_picker)
  vim.bo[bufnr].ft = plugin_config.previewer_cmd

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local chan = vim.api.nvim_open_term(bufnr, {})
  local args = is_picker and plugin_config.picker_cmd_args or plugin_config.cmd_args
  local previewer = job:new({
    command = plugin_config.previewer_cmd,
    args = args,
    on_stdout = vim.schedule_wrap(function(_, data)
      if not data then return end
      local output_lines = vim.split(data, "\n", {})
      for _, line in ipairs(output_lines) do
        pcall(function() vim.api.nvim_chan_send(chan, line .. "\r\n") end)
      end
    end),
    writer = table.concat(lines, "\n"),
  })

  previewer:start()
end

M.open = function(entry, bufnr, float)
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)

  if not float then
    vim.api.nvim_set_current_buf(bufnr)
  else
    local ui = vim.api.nvim_list_uis()[1]
    local row = (ui.height - plugin_config.float_win.height) * 0.5
    local col = (ui.width - plugin_config.float_win.width) * 0.5
    local float_opts = plugin_config.float_win

    float_opts.row = plugin_config.row or row
    float_opts.col = plugin_config.col or col

    local win = nil
    local last_win = state.get("last_win")

    if last_win and vim.api.nvim_win_is_valid(last_win) then
      win = last_win
      vim.api.nvim_win_set_buf(win, bufnr)
    else
      win = vim.api.nvim_open_win(bufnr, true, float_opts)
      state.set("last_win", win)
    end

    vim.wo[win].wrap = plugin_config.wrap
    vim.wo[win].linebreak = plugin_config.wrap
    vim.wo[win].nu = false
    vim.wo[win].relativenumber = false
  end

  local ignore = vim.tbl_contains(plugin_config.cmd_ignore, entry.alias)

  if plugin_config.previewer_cmd and not ignore then
    M.render_cmd(bufnr)
  else
    vim.bo[bufnr].ft = "markdown"
  end

  config.set_keymaps(bufnr, entry)
  plugin_config.after_open(bufnr)
end

return M
