local M = {}

local log = require("nvim-devdocs.log")
local list = require("nvim-devdocs.list")
local state = require("nvim-devdocs.state")
local pickers = require("nvim-devdocs.pickers")
local operations = require("nvim-devdocs.operations")
local config = require("nvim-devdocs.config")
local completion = require("nvim-devdocs.completion")
local filetypes = require("nvim-devdocs.filetypes")

M.fetch_registery = operations.fetch

M.install_doc = function(args)
  if vim.tbl_isempty(args.fargs) then
    pickers.installation_picker()
  else
    operations.install_args(args.fargs, true)
  end
end

M.uninstall_doc = function(args)
  if vim.tbl_isempty(args.fargs) then pickers.uninstallation_picker() end

  for _, arg in pairs(args.fargs) do
    operations.uninstall(arg)
  end
end

M.open_doc = function(args, float)
  if vim.tbl_isempty(args.fargs) then
    log.debug("Opening all installed entries")
    local installed = list.get_installed_alias()
    local entries = list.get_doc_entries(installed)
    pickers.open_picker(entries or {}, float)
  else
    local alias = args.fargs[1]
    log.debug("Opening " .. alias .. " entries")
    pickers.open_picker_alias(alias, float)
  end
end

M.open_doc_float = function(args) M.open_doc(args, true) end

M.open_doc_current_file = function(float)
  local filetype = vim.bo.filetype
  local names = config.options.filetypes[filetype] or filetypes[filetype] or filetype

  if type(names) == "string" then names = { names } end

  local docs =
    vim.tbl_flatten(vim.tbl_map(function(name) return list.get_doc_variants(name) end, names))
  local entries = list.get_doc_entries(docs)

  if entries and not vim.tbl_isempty(entries) then
    pickers.open_picker(entries, float)
  else
    log.error("No documentation found for the current filetype")
  end
end

M.update = function(args)
  if vim.tbl_isempty(args.fargs) then
    pickers.update_picker()
  else
    operations.install_args(args.fargs, true, true)
  end
end

M.update_all = function()
  local updatable = list.get_updatable()

  if vim.tbl_isempty(updatable) then
    log.info("All documentations are up to date")
  else
    operations.install_args(updatable, true, true)
  end
end

M.toggle = function()
  local buf = state.get("last_buf")
  local win = state.get("last_win")

  if not buf or not vim.api.nvim_buf_is_valid(buf) then return end

  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
    state.set("last_win", nil)
  else
    win = vim.api.nvim_open_win(buf, true, config.get_float_options())
    state.set("last_win", win)
  end
end

M.keywordprg = function(args)
  local keyword = args.fargs[1]

  if keyword then
    operations.keywordprg(keyword)
  else
    log.error("No keyword provided")
  end
end

---@param opts nvim_devdocs.Config
M.setup = function(opts)
  config.setup(opts)

  vim.defer_fn(function()
    log.debug("Installing required docs")
    operations.install_args(config.options.ensure_installed)
  end, 3000)

  local cmd = vim.api.nvim_create_user_command

  cmd("DevdocsFetch", M.fetch_registery, {})
  cmd("DevdocsInstall", M.install_doc, { nargs = "*", complete = completion.get_non_installed })
  cmd("DevdocsUninstall", M.uninstall_doc, { nargs = "*", complete = completion.get_installed })
  cmd("DevdocsOpen", M.open_doc, { nargs = "?", complete = completion.get_installed })
  cmd("DevdocsOpenFloat", M.open_doc_float, { nargs = "?", complete = completion.get_installed })
  cmd("DevdocsOpenCurrent", function() M.open_doc_current_file() end, {})
  cmd("DevdocsOpenCurrentFloat", function() M.open_doc_current_file(true) end, {})
  cmd("DevdocsKeywordprg", M.keywordprg, { nargs = "?" })
  cmd("DevdocsUpdate", M.update, { nargs = "*", complete = completion.get_updatable })
  cmd("DevdocsUpdateAll", M.update_all, {})
  cmd("DevdocsToggle", M.toggle, {})

  log.debug("Plugin initialized")
end

return M
