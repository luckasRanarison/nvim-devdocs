local M = {}

local path = require("plenary.path")

local list = require("nvim-devdocs.list")
local notify = require("nvim-devdocs.notify")
local pickers = require("nvim-devdocs.pickers")
local operations = require("nvim-devdocs.operations")
local config = require("nvim-devdocs.config")
local completion = require("nvim-devdocs.completion")
local plugin_config = require("nvim-devdocs.config").get()

local registery_path = path:new(plugin_config.dir_path, "registery.json")

M.fetch_registery = function() operations.fetch() end

M.install_doc = function(args)
  if registery_path:exists() then
    if vim.tbl_isempty(args.fargs) then pickers.installation_picker() end

    operations.install_args(args.fargs, true)
  else
    notify.log_err("DevDocs registery not found, please run :DevdocsFetch")
  end
end

M.uninstall_doc = function(args)
  if vim.tbl_isempty(args.fargs) then pickers.uninstallation_picker() end

  for _, arg in pairs(args.fargs) do
    operations.uninstall(arg)
  end
end

M.open_doc = function(args)
  if vim.tbl_isempty(args.fargs) then
    pickers.global_search_picker(false)
  else
    local arg = args.fargs[1]
    local entries = operations.get_entries(arg)

    if entries then
      pickers.open_doc_entry_picker(entries, false)
    else
      notify.log_err(arg .. " documentation is not installed")
    end
  end
end

M.open_doc_float = function(args)
  if vim.tbl_isempty(args.fargs) then
    pickers.global_search_picker(true)
  else
    local arg = args.fargs[1]
    local entries = operations.get_entries(arg)

    if entries then
      pickers.open_doc_entry_picker(entries, true)
    else
      notify.log_err(arg .. " documentation is not installed")
    end
  end
end

M.update = function(args)
  if registery_path:exists() then
    if vim.tbl_isempty(args.fargs) then pickers.update_picker() end

    operations.install_args(args.fargs, true, true)
  else
    notify.log_err("DevDocs registery not found, please run :DevdocsFetch")
  end
end

M.update_all = function()
  if registery_path:exists() then
    local updatable = list.get_updatable()

    if vim.tbl_isempty(updatable) then
      notify.log("All documentations are up to date")
    else
      operations.install_args(updatable, true, true)
    end
  else
    notify.log_err("DevDocs registery not found, please run :DevdocsFetch")
  end
end

M.setup = function(opts)
  config.setup(opts)

  local ensure_installed = config.get().ensure_installed

  vim.defer_fn(function() operations.install_args(ensure_installed) end, 5000)

  local cmd = vim.api.nvim_create_user_command

  cmd("DevdocsFetch", M.fetch_registery, {})
  cmd("DevdocsInstall", M.install_doc, { nargs = "*", complete = completion.get_non_installed })
  cmd("DevdocsUninstall", M.uninstall_doc, { nargs = "*", complete = completion.get_installed })
  cmd("DevdocsOpen", M.open_doc, { nargs = "?", complete = completion.get_installed })
  cmd("DevdocsOpenFloat", M.open_doc_float, { nargs = "?", complete = completion.get_installed })
  cmd("DevdocsUpdate", M.update, { nargs = "*", complete = completion.get_updatable })
  cmd("DevdocsUpdateAll", M.update_all, {})
end

return M
