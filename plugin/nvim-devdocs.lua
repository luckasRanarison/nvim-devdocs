local M = require("nvim-devdocs")

M.setup = function(opts)
  local config = require("nvim-devdocs.config")
  local completion = require("nvim-devdocs.completion")
  local operations = require("nvim-devdocs.operations")

  config.setup(opts)

  local ensure_installed = config.get().ensure_installed

  vim.defer_fn(function() operations.install_args(ensure_installed) end, 5000)

  local cmd = vim.api.nvim_create_user_command

  cmd("DevdocsFetch", M.fetch_registery, {})
  cmd("DevdocsInstall", M.install_doc, { nargs = "*", complete = completion.get_non_installed })
  cmd("DevdocsUninstall", M.uninstall_doc, { nargs = "*", complete = completion.get_installed })
  cmd("DevdocsOpen", M.open_doc, { nargs = "?", complete = completion.get_installed })
  cmd("DevdocsOpenFloat", M.open_doc_float, { nargs = "?", complete = completion.get_installed })
  cmd("DevdocsUpdate", M.update, { nargs = "+", complete = completion.get_updatable })
  cmd("DevdocsUpdateAll", M.update_all, {})
end

return M
