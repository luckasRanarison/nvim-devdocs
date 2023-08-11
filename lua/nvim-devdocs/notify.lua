local M = {}

M.log = vim.schedule_wrap(function(message) vim.notify(message, vim.log.levels.INFO) end)

M.log_warn = vim.schedule_wrap(function(message) vim.notify(message, vim.log.levels.WARN) end)

M.log_err = vim.schedule_wrap(function(message) vim.notify(message, vim.log.levels.ERROR) end)

return M
