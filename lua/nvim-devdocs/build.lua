local M = {}

local fs = require("nvim-devdocs.fs")
local log = require("nvim-devdocs.log")
local transpiler = require("nvim-devdocs.transpiler")

---@param entry RegisteryEntry
---@param doc_index DocIndex
---@param docs table<string, string>
M.build_docs = function(entry, doc_index, docs)
  local alias = entry.slug:gsub("~", "-")
  local current_doc_dir = DOCS_DIR:joinpath(alias)

  log.info("Building " .. alias .. " documentation...")

  if not DOCS_DIR:exists() then DOCS_DIR:mkdir() end
  if not current_doc_dir:exists() then current_doc_dir:mkdir() end

  local index = fs.read_index() or {}
  local lockfile = fs.read_lockfile() or {}

  --- Used for extracting the markdown headers that will be used as breakpoints when spliting the docs
  local section_map = {}
  local path_map = {}

  for _, index_entry in pairs(doc_index.entries) do
    local splited = vim.split(index_entry.path, "#")
    local main = splited[1]
    local id = splited[2]

    if not section_map[main] then section_map[main] = {} end
    if id then table.insert(section_map[main], id) end
  end

  -- The entries need to be sorted in order to make spliting work
  local sort_lookup = {}
  local sort_lookup_last_index = 1
  local count = 1
  local total = vim.tbl_count(docs)

  for key, doc in pairs(docs) do
    log.debug(string.format("Converting %s (%s/%s)", key, count, total))

    local sections = section_map[key]
    local file_path = current_doc_dir:joinpath(tostring(count) .. ".md")
    local success, result, md_sections =
      xpcall(transpiler.html_to_md, debug.traceback, doc, sections)

    if not success then
      local message = string.format(
        'Failed to convert "%s", please report this issue\n\n%s\n\nOriginal html document:\n\n%s',
        key,
        result,
        doc
      )
      log.error(message)
      return
    end

    for _, section in ipairs(md_sections) do
      path_map[key .. "#" .. section.id] = count .. "," .. section.md_path
      sort_lookup[key .. "#" .. section.id] = sort_lookup_last_index
      sort_lookup_last_index = sort_lookup_last_index + 1
    end

    -- Use number as filename instead of the entry name to avoid invalid filenames
    path_map[key] = tostring(count)
    file_path:write(result, "w")
    count = count + 1
    log.debug(file_path .. " has been writen")
  end

  log.debug("Sorting docs entries")
  table.sort(doc_index.entries, function(a, b)
    local index_a = sort_lookup[a.path] or -1
    local index_b = sort_lookup[b.path] or -1
    return index_a < index_b
  end)

  log.debug("Filling docs links and path")
  for i, index_entry in ipairs(doc_index.entries) do
    local main = vim.split(index_entry.path, "#")[1]
    doc_index.entries[i].link = doc_index.entries[i].path
    doc_index.entries[i].path = path_map[index_entry.path] or path_map[main]
  end

  index[alias] = doc_index
  lockfile[alias] = entry

  fs.write_index(index)
  fs.write_lockfile(lockfile)

  log.info("Build complete!")
end

return M
