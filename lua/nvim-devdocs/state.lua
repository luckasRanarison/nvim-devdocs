local M = {}

local state = {
  current_doc = nil, -- ex: "javascript", used for `keywordprg`
  preview_lines = nil,
  last_win = nil,
  last_bufnr = nil,
  last_mode = nil, -- "normal" | "float"
}

---@return any
M.get = function(key) return state[key] end

M.set = function(key, value) state[key] = value end

return M
