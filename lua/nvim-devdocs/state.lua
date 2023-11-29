local M = {}

---@alias nvim_devdocs.StateKey "current_doc" | "preview_lines" | "last_win" | "last_mode" | "last_buf"

local state = {
  current_doc = nil, -- ex: "javascript", used for `keywordprg`
  preview_lines = nil,
  last_win = nil,
  last_mode = nil, -- "normal" | "float"
  last_buf = nil,
}

---@param key nvim_devdocs.StateKey
---@return any
M.get = function(key) return state[key] end

---@param key nvim_devdocs.StateKey
M.set = function(key, value) state[key] = value end

return M
