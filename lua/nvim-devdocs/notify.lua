local M = {}

M.log = function(message) vim.notify(message, vim.log.levels.INFO) end

M.log_warn = function(message) vim.notify(message, vim.log.levels.WARN) end

M.log_err = function(message) vim.notify(message, vim.log.levels.ERROR) end

return M
