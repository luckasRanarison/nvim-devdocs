local M = {}

local config = {
  dir_path = vim.fn.stdpath("data") .. "/devdocs",
  telescope = {},
  telescope_alt = {
    layout_config = {
      width = 75,
    },
  },
  float_win = {
    relative = "editor",
    height = 25,
    width = 100,
    border = "rounded",
  },
  wrap = false,
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
