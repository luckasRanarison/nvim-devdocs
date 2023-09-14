local M = {}

local state = {
  preview_lines = nil,
  last_win = nil,
}

M.get = function(key) return state[key] end

M.set = function(key, value) state[key] = value end

return M
