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

---@param bufnr number
---@param entry DocEntry
M.set_keymaps = function(bufnr, entry)
  local slug = entry.alias:gsub("-", "~")
  local keymaps = M.options.mappings
  local set_buf_keymap = function(key, action, description)
    vim.keymap.set("n", key, action, { buffer = bufnr, desc = description })
  end

  if type(keymaps.open_in_browser) == "string" and keymaps.open_in_browser ~= "" then
    set_buf_keymap(
      keymaps.open_in_browser,
      function() vim.ui.open("https://devdocs.io/" .. slug .. "/" .. entry.link) end,
      "Open in the browser"
    )
  end
end

return M
