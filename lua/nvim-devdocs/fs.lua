local M = {}

---@param registery RegisteryEntry[]
M.write_registery = function(registery)
  local encoded = vim.fn.json_encode(registery)
  REGISTERY_PATH:write(encoded, "w")
end

---@param index IndexTable
M.write_index = function(index)
  local encoded = vim.fn.json_encode(index)
  INDEX_PATH:write(encoded, "w")
end

---@param lockfile LockTable
M.write_lockfile = function(lockfile)
  local encoded = vim.fn.json_encode(lockfile)
  LOCK_PATH:write(encoded, "w")
end

---@return RegisteryEntry[]?
M.read_registery = function()
  if not REGISTERY_PATH:exists() then return end
  local buf = REGISTERY_PATH:read()
  return vim.fn.json_decode(buf)
end

---@return IndexTable?
M.read_index = function()
  if not INDEX_PATH:exists() then return end
  local buf = INDEX_PATH:read()
  return vim.fn.json_decode(buf)
end

---@return LockTable?
M.read_lockfile = function()
  if not LOCK_PATH:exists() then return end
  local buf = LOCK_PATH:read()
  return vim.fn.json_decode(buf)
end

---@param alias string
M.remove_docs = function(alias)
  local doc_path = DOCS_DIR:joinpath(alias)
  doc_path:rm({ recursive = true })
end

return M
