local notify = require("nvim-devdocs.notify")
local transpiler = require("nvim-devdocs.transpiler")

local function build_docs(entry, index, docs)
  local alias = entry.slug:gsub("~", "-")
  local current_doc_dir = DOCS_DIR:joinpath(alias)

  notify.log("Building " .. alias .. " documentation...")

  if not DOCS_DIR:exists() then DOCS_DIR:mkdir() end
  if not INDEX_PATH:exists() then INDEX_PATH:write("{}", "w") end
  if not LOCK_PATH:exists() then LOCK_PATH:write("{}", "w") end
  if not current_doc_dir:exists() then current_doc_dir:mkdir() end

  local section_map = {}
  local path_map = {}

  for _, index_entry in pairs(index.entries) do
    local splited = vim.split(index_entry.path, "#")
    local main = splited[1]
    local id = splited[2]

    if not section_map[main] then section_map[main] = {} end
    if id then table.insert(section_map[main], id) end
  end

  local count = 1

  for key, doc in pairs(docs) do
    local sections = section_map[key]
    local markdown, md_sections = transpiler.html_to_md(doc, sections)
    local file_path = current_doc_dir:joinpath(tostring(count) .. ".md")

    for id, md_path in pairs(md_sections) do
      path_map[key .. "#" .. id] = count .. "," .. md_path
    end

    path_map[key] = tostring(count)
    file_path:write(markdown, "w")
    count = count + 1
  end

  for i, index_entry in ipairs(index.entries) do
    local main = vim.split(index_entry.path, "#")[1]
    index.entries[i].link = index.entries[i].path
    index.entries[i].path = path_map[index_entry.path] or path_map[main]
  end

  local index_parsed = vim.fn.json_decode(INDEX_PATH:read())
  index_parsed[alias] = index
  INDEX_PATH:write(vim.fn.json_encode(index_parsed), "w")

  local lock_parsed = vim.fn.json_decode(LOCK_PATH:read())
  lock_parsed[alias] = entry
  LOCK_PATH:write(vim.fn.json_encode(lock_parsed), "w")

  notify.log("Build complete!")
end

return build_docs
