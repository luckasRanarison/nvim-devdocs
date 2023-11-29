local M = {}

local path = require("plenary.path")

---@class nvim_devdocs.Config
local default = {
  dir_path = vim.fn.stdpath("data") .. "/devdocs",
  telescope = {},
  filetypes = {},
  float_win = {
    relative = "editor",
    height = 25,
    width = 100,
    border = "rounded",
  },
  wrap = false,
  previewer_cmd = nil,
  cmd_args = {},
  cmd_ignore = {},
  picker_cmd = false,
  picker_cmd_args = {},
  ensure_installed = {},
  mappings = {
    open_in_browser = "",
  },
  ---@diagnostic disable-next-line: unused-local
  after_open = function(bufnr) end,
}

---@class nvim_devdocs.Config
M.options = {}

M.setup = function(new_config)
  M.options = vim.tbl_deep_extend("force", default, new_config or {})

  DATA_DIR = path:new(default.dir_path)
  DOCS_DIR = DATA_DIR:joinpath("docs")
  INDEX_PATH = DATA_DIR:joinpath("index.json")
  LOCK_PATH = DATA_DIR:joinpath("docs-lock.json")
  REGISTERY_PATH = DATA_DIR:joinpath("registery.json")

  return default
end

M.get_float_options = function()
  local ui = vim.api.nvim_list_uis()[1]
  local row = (ui.height - M.options.float_win.height) * 0.5
  local col = (ui.width - M.options.float_win.width) * 0.5
  local float_opts = M.options.float_win

  float_opts.row = M.options.float_win.row or row
  float_opts.col = M.options.float_win.col or col
  float_opts.zindex = 10

  return float_opts
end

return M
