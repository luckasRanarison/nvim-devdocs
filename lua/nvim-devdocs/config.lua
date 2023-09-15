local M = {}

local path = require("plenary.path")

local config = {
  dir_path = vim.fn.stdpath("data") .. "/devdocs",
  telescope = {},
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

M.get = function() return config end

M.setup = function(new_config)
  if new_config ~= nil then
    for key, value in pairs(new_config) do
      config[key] = value
    end
  end

  DATA_DIR = path:new(config.dir_path)
  DOCS_DIR = DATA_DIR:joinpath("docs")
  INDEX_PATH = DATA_DIR:joinpath("index.json")
  LOCK_PATH = DATA_DIR:joinpath("docs-lock.json")
  REGISTERY_PATH = DATA_DIR:joinpath("registery.json")

  return config
end

M.set_keymaps = function(bufnr, entry)
  local slug = entry.alias:gsub("-", "~")
  local keymaps = config.mappings
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
