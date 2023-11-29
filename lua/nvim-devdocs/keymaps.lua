local M = {}

local config = require("nvim-devdocs.config")

local function set_buf_keymap(key, action, bufnr, description)
  vim.keymap.set("n", key, action, { buffer = bufnr, desc = description })
end

local mappings = {
  open_in_browser = {
    desc = "Open in the browser",
    handler = function(entry)
      local slug = entry.alias:gsub("-", "~")
      vim.ui.open("https://devdocs.io/" .. slug .. "/" .. entry.link)
    end,
  },
}

---@param bufnr number
---@param entry DocEntry
M.set_keymaps = function(bufnr, entry)
  for map, key in pairs(config.options.mappings) do
    if type(key) == "string" and key ~= "" then
      local value = mappings[map]
      if value then set_buf_keymap(key, function() value.handler(entry) end, bufnr, value.desc) end
    end
  end
end

return M
