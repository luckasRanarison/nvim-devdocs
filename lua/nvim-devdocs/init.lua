local M = {}

local list = require("nvim-devdocs.list")
local notify = require("nvim-devdocs.notify")
local pickers = require("nvim-devdocs.pickers")
local operations = require("nvim-devdocs.operations")
local config = require("nvim-devdocs.config")
local completion = require("nvim-devdocs.completion")

M.fetch_registery = function() operations.fetch() end

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

M.open_doc = function(args)
  if vim.tbl_isempty(args.fargs) then
    pickers.global_search_picker(false)
  else
    local alias = args.fargs[1]
    pickers.open_picker(alias, false)
  end
end

M.open_doc_float = function(args)
  if vim.tbl_isempty(args.fargs) then
    pickers.global_search_picker(true)
  else
    local alias = args.fargs[1]
    pickers.open_picker(alias, true)
  end
end

M.aliases = {
  ["cs"] = "csharp",
  ["go"] = "go",
  ["js"] = "javascript",
  ["jsx"] = "javascript",
  ["md"] = "markdown",
  ["py"] = "python",
  ["rb"] = "ruby",
  ["rs"] = "rust",
  ["sass"] = "sass",
  ["scss"] = "sass",
  ["sh"] = "bash",
  ["ts"] = "typescript",
  ["tsx"] = "typescript",
  ["yml"] = "yaml",
}
M.open_doc_current_file = function()
  local filetype = vim.bo.filetype
  local alias = M.aliases[filetype] or filetype
  pickers.open_picker(alias, false)
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
    notify.log("All documentations are up to date")
  else
    operations.install_args(updatable, true, true)
  end
end

M.setup = function(opts)
  config.setup(opts)

  local ensure_installed = config.get().ensure_installed

  vim.defer_fn(function() operations.install_args(ensure_installed) end, 3000)

  local cmd = vim.api.nvim_create_user_command

  cmd("DevdocsFetch", M.fetch_registery, {})
  cmd("DevdocsInstall", M.install_doc, { nargs = "*", complete = completion.get_non_installed })
  cmd("DevdocsUninstall", M.uninstall_doc, { nargs = "*", complete = completion.get_installed })
  cmd("DevdocsOpen", M.open_doc, { nargs = "?", complete = completion.get_installed })
  cmd("DevdocsOpenCurrentFileFloat", M.open_doc_current_file_float, {})
  cmd("DevdocsOpenCurrentFile", M.open_doc_current_file, {})
  cmd("DevdocsUpdate", M.update, { nargs = "*", complete = completion.get_updatable })
  cmd("DevdocsUpdateAll", M.update_all, {})
end

return M
