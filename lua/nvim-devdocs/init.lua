local M = {}

local path = require("plenary.path")

local list = require("nvim-devdocs.list")
local notify = require("nvim-devdocs.notify")
local pickers = require("nvim-devdocs.pickers")
local operations = require("nvim-devdocs.operations")
local plugin_config = require("nvim-devdocs.config").get()

M.fetch_registery = function() operations.fetch() end

M.install_doc = function(args)
  local registery_path = path:new(plugin_config.dir_path, "registery.json")

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
  local registery_path = path:new(plugin_config.dir_path, "registery.json")

  if registery_path:exists() then
    operations.install_args(args.fargs, true, true)
  else
    notify.log_err("DevDocs registery not found, please run :DevdocsFetch")
  end
end

M.update_all = function()
  local registery_path = path:new(plugin_config.dir_path, "registery.json")

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

return M
