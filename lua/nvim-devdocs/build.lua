local path = require("plenary.path")

local notify = require("nvim-devdocs.notify")
local plugin_config = require("nvim-devdocs.config").get()
local html_to_md = require("nvim-devdocs.transpiler").html_to_md

local function build_docs(entry, index, docs)
  local alias = entry.slug:gsub("~", "-")
  local docs_dir = path:new(plugin_config.dir_path, "docs")
  local current_doc_dir = path:new(docs_dir, alias)
  local index_path = path:new(plugin_config.dir_path, "index.json")
  local lock_path = path:new(plugin_config.dir_path, "docs-lock.json")

  if not docs_dir:exists() then docs_dir:mkdir() end
  if not current_doc_dir:exists() then current_doc_dir:mkdir() end
  if not index_path:exists() then index_path:write("{}", "w") end
  if not lock_path:exists() then lock_path:write("{}", "w") end

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

    local markdown, md_sections = html_to_md(doc, sections)

    for id, md_path in pairs(md_sections) do
      path_map[key .. "#" .. id] = count .. "," .. md_path
    end

    path_map[key] = tostring(count)

    local file_path = path:new(current_doc_dir, tostring(count) .. ".md")

    file_path:write(markdown, "w")
    count = count + 1
  end

  for i, index_entry in ipairs(index.entries) do
    local main = vim.split(index_entry.path, "#")[1]
    index.entries[i].path = path_map[index_entry.path] or path_map[main]
  end

  local index_parsed = vim.fn.json_decode(index_path:read())
  index_parsed[alias] = index
  index_path:write(vim.fn.json_encode(index_parsed), "w")

  local lock_parsed = vim.fn.json_decode(lock_path:read())
  lock_parsed[alias] = entry
  lock_path:write(vim.fn.json_encode(lock_parsed), "w")

  notify.log("Build complete! [" .. alias .. "]")
end

return build_docs
