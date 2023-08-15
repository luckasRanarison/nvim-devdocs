local M = {}

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
  picker_cmd = nil,
  picker_cmd_args = {},
  ensure_installed = {},
}

M.get = function() return config end

M.setup = function(new_config)
  if new_config ~= nil then
    for key, value in pairs(new_config) do
      config[key] = value
    end
  end

  return config
end

return M
