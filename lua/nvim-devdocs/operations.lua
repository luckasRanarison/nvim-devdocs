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

---@param entry RegisteryEntry
---@param verbose? boolean
---@param is_update? boolean
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

---@param args string[]
---@param verbose? boolean
---@param is_update? boolean
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

---@param alias string
M.uninstall = function(alias)
  local installed = list.get_installed_alias()

  if not vim.tbl_contains(installed, alias) then
    notify.log(alias .. " documentation is already uninstalled")
  else
    local index = vim.fn.json_decode(INDEX_PATH:read())
    local lockfile = vim.fn.json_decode(LOCK_PATH:read())
    local doc_path = DOCS_DIR:joinpath(alias)

    index[alias] = nil
    lockfile[alias] = nil

    INDEX_PATH:write(vim.fn.json_encode(index), "w")
    LOCK_PATH:write(vim.fn.json_encode(lockfile), "w")
    doc_path:rm({ recursive = true })

    notify.log(alias .. " documentation has been uninstalled")
  end
end

---@param alias string
---@return DocEntry[] | nil
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

---@return DocEntry[]
M.get_all_entries = function()
  if not INDEX_PATH:exists() then return {} end

  local entries = {}
  local index_parsed = vim.fn.json_decode(INDEX_PATH:read())

  for alias, index in pairs(index_parsed) do
    local entries_count = #index.entries
    for idx, doc_entry in ipairs(index.entries) do
      local next_path = nil
      if idx < entries_count then
        next_path = index.entries[idx+1].path
      end
      local entry = {
        name = string.format("[%s] %s", alias, doc_entry.name),
        alias = alias,
        path = doc_entry.path,
        next_path = next_path,
        link = doc_entry.link,
      }
      table.insert(entries, entry)
    end
  end

  return entries
end

---@param entry DocEntry
---@param callback function
M.read_entry = function(entry, callback)
  local splited_path = vim.split(entry.path, ",")
  local file = splited_path[1]
  local file_path = DOCS_DIR:joinpath(entry.alias, file .. ".md")

  file_path:_read_async(vim.schedule_wrap(function(content)
    local pattern = splited_path[2]
    local next_pattern = nil
    if entry.next_path ~= nil then
      next_pattern = vim.split(entry.next_path, ",")[2]
    end
    local lines = vim.split(content, "\n")
    local filtered_lines = M.filter_doc(lines, pattern, next_pattern)

    callback(filtered_lines)
  end))
end

---if we have a pattern to search for, only consider lines after the pattern
---@param lines string[]
---@param pattern? string
---@param next_pattern? string
---@return string[]
M.filter_doc = function(lines, pattern, next_pattern)
  if not pattern then return lines end

  -- https://stackoverflow.com/a/34953646/516188
  local function create_pattern(text) return text:gsub("([^%w])", "%%%1") end

  local filtered_lines = {}
  local found = false
  local pattern_lines = vim.split(pattern, "\n")
  local search_pattern = create_pattern(pattern_lines[1]) -- only search the first line
  local next_pattern_lines = vim.split(next_pattern, "\n")
  local next_search_pattern = create_pattern(next_pattern_lines[1]) -- only search the first line

  for _, line in ipairs(lines) do
    if found then
      if line:match(next_search_pattern) then break end
    end
    if line:match(search_pattern) then found = true end
    if found then table.insert(filtered_lines, line) end
  end

  if not found then return lines end

  return filtered_lines
end

---@param bufnr number
---@param is_picker? boolean
M.render_cmd = function(bufnr, is_picker)
  vim.bo[bufnr].ft = config.options.previewer_cmd

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local chan = vim.api.nvim_open_term(bufnr, {})
  local args = is_picker and config.options.picker_cmd_args or config.options.cmd_args
  local previewer = job:new({
    command = config.options.previewer_cmd,
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

---@param entry DocEntry
---@param bufnr number
---@param float boolean
M.open = function(entry, bufnr, float)
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)

  if not float then
    vim.api.nvim_set_current_buf(bufnr)
  else
    local ui = vim.api.nvim_list_uis()[1]
    local row = (ui.height - config.options.float_win.height) * 0.5
    local col = (ui.width - config.options.float_win.width) * 0.5
    local float_opts = config.options.float_win

    float_opts.row = config.options.float_win.row or row
    float_opts.col = config.options.float_win.col or col
    float_opts.zindex = 10

    local win = nil
    local last_win = state.get("last_win")

    if last_win and vim.api.nvim_win_is_valid(last_win) then
      win = last_win
      vim.api.nvim_win_set_buf(win, bufnr)
    else
      win = vim.api.nvim_open_win(bufnr, true, float_opts)
      state.set("last_win", win)
    end

    vim.wo[win].wrap = config.options.wrap
    vim.wo[win].linebreak = config.options.wrap
    vim.wo[win].nu = false
    vim.wo[win].relativenumber = false
  end

  local ignore = vim.tbl_contains(config.options.cmd_ignore, entry.alias)

  if config.options.previewer_cmd and not ignore then
    M.render_cmd(bufnr)
  else
    vim.bo[bufnr].ft = "markdown"
  end

  vim.bo[bufnr].keywordprg = ":DevdocsKeywordprg"

  config.set_keymaps(bufnr, entry)
  config.options.after_open(bufnr)
end

---@param keyword string
M.keywordprg = function(keyword)
  local alias = state.get("current_doc")
  local float = state.get("last_mode") == "float"
  local bufnr = vim.api.nvim_create_buf(false, false)
  local entries = M.get_entries(alias)
  local entry

  local function callback(filtered_lines)
    vim.bo[bufnr].modifiable = true
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, filtered_lines)
    vim.bo[bufnr].modifiable = false

    M.open(entry, bufnr, float)
  end

  for _, value in pairs(entries or {}) do
    if value.name == keyword or value.link == keyword then
      entry = value
      M.read_entry(entry, callback)
    end
  end

  if not entry then notify.log("No documentation found for " .. keyword) end
end

return M
