---@diagnostic disable: need-check-nil, param-type-mismatch
local M = {}

local normalize_html = function(str)
  str = str:gsub("&lt;", "<")
  str = str:gsub("&gt;", ">")
  str = str:gsub("&amp;", "&")
  str = str:gsub("&quot;", '"')
  str = str:gsub("&apos;", "'")
  str = str:gsub("&nbsp;", " ")
  str = str:gsub("&copy;", "©")
  str = str:gsub("&ndash;", "–")

  return str
end

local tag_mappings = {
  h1 = { left = "# ", right = "\n\n" },
  h2 = { left = "## ", right = "\n\n" },
  h3 = { left = "### ", right = "\n\n" },
  h4 = { left = "#### ", right = "\n\n" },
  h5 = { left = "##### ", right = "\n\n" },
  h6 = { left = "###### ", right = "\n\n" },
  span = {},
  nav = {},
  header = {},
  div = { left = "\n", right = "\n" },
  section = { right = "\n" },
  p = { right = "\n\n" },
  ul = { right = "\n" },
  ol = { right = "\n" },
  dl = { right = "\n" },
  dt = { right = "\n" },
  figure = { right = "\n" },
  dd = { left = ": " },
  pre = { left = "\n```\n", right = "\n```\n" },
  code = { left = "`", right = "`" },
  samp = { left = "`", right = "`" },
  var = { left = "`", right = "`" },
  kbd = { left = "`", right = "`" },
  mark = { left = "`", right = "`" },
  tt = { left = "`", right = "`" },
  b = { left = "`", right = "`" },
  strong = { left = "**", right = "**" },
  i = { left = "_", right = "_" },
  s = { left = "~~", right = "~~" },
  em = { left = "_", right = "_" },
  small = { left = "_", right = "_" },
  sup = { left = "^", right = "^" },
  blockquote = { left = "> " },
  summary = { left = "<", right = ">" },

  -- TODO: Handle these correctly
  math = { left = "```math\n", right = "\n```" },
  annotation = { left = "[", right = "]" },
  semantics = {},
  mspace = { left = " " },
  msup = { right = "^" },
  mfrac = { right = "/" },
  mrow = {},
  mo = {},
  mn = {},
  mi = {},

  br = { right = "\n" },
  hr = { right = "---\n\n" },
}

local inline_tags = {
  "span",
  "a",
  "strong",
  "em",
  "abbr",
  "code",
  "tt",
  "i",
  "s",
  "sub",
  "sup",
  "mark",
  "small",
  "var",
  "kbd",
}

local skipable_tags = {
  "input",
  "use",
  "svg",
  "button",

  -- exceptions, (parent) table -> child
  "tr",
  "td",
  "th",
  "thead",
  "tbody",
}

local monospace_tags = {
  "code",
  "tt",
  "samp",
  "kbd",
}

local is_inline_tag = function(tag_name) return vim.tbl_contains(inline_tags, tag_name) end
local is_skipable_tag = function(tag_name) return vim.tbl_contains(skipable_tags, tag_name) end
local is_monospace_tag = function(tag_name) return vim.tbl_contains(monospace_tags, tag_name) end

local transpiler = {}

---HTML to Markdown transpiler
---@param source string the string to convert
---@param section_map table<string, string> a map of the doc sections for indexing
function transpiler:new(source, section_map)
  local new = {
    parser = vim.treesitter.get_string_parser(source, "html"),
    lines = vim.split(source, "\n"),
    result = "",
    section_map = section_map,
    sections = {},
  }
  new.parser:parse()
  self.__index = self

  return setmetatable(new, self)
end

---Returns the text at a given range, zero based index
function transpiler:get_text_range(row_start, col_start, row_end, col_end)
  local extracted_lines = {}

  for i = row_start, row_end do
    local line = self.lines[i + 1]

    if row_start == row_end then
      line = line:sub(col_start + 1, col_end)
    elseif i == row_start then
      line = line:sub(col_start + 1)
    elseif i == row_end then
      line = line:sub(1, col_end)
    end

    table.insert(extracted_lines, line)
  end

  return table.concat(extracted_lines, "\n")
end

---@param node TSNode
---@return string
function transpiler:get_node_text(node)
  if not node then return "" end

  local row_start, col_start = node:start()
  local row_end, col_end = node:end_()
  local text = self:get_text_range(row_start, col_start, row_end, col_end)

  return text
end

---@param node TSNode
function transpiler:get_node_tag_name(node)
  if not node then return "" end

  local tag_name = nil
  local child = node:named_child()

  if child then
    local tag_node = child:named_child()
    if tag_node then tag_name = self:get_node_text(tag_node) end
  end

  return tag_name
end

---@param node TSNode
---@param tag_name boolean
function transpiler:has_parent_tag(node, tag_name)
  local current = node:parent()

  while current do
    local parent_tag_name = self:get_node_tag_name(current)
    if parent_tag_name == tag_name then return true end
    current = current:parent()
  end

  return false
end

---@param node TSNode
---@return table<string, string>
function transpiler:get_node_attributes(node)
  if not node then return {} end

  local attributes = {}
  local tag_node = node:named_child()

  if not tag_node then return {} end

  local tag_children = tag_node:named_children()

  for i = 2, #tag_children do
    local attribute_node = tag_children[i]
    local attribute_name_node = attribute_node:named_child()
    local attribute_name = self:get_node_text(attribute_name_node)
    local value = ""

    if attribute_name_node and attribute_name_node:next_named_sibling() then
      local quotetd_value_node = attribute_name_node:next_named_sibling()
      local value_node = quotetd_value_node:named_child()
      if value_node then value = self:get_node_text(value_node) end
    end

    attributes[attribute_name] = value
  end

  return attributes
end

---Removes start and end tag
---@param node TSNode
---@return TSNode[]
function transpiler:filter_tag_children(node)
  local children = node:named_children()
  local filtered = vim.tbl_filter(function(child)
    local type = child:type()
    return type ~= "start_tag" and type ~= "end_tag"
  end, children)

  return filtered
end

---Converts HTML to Markdown
---@return string, table<string, string>
function transpiler:transpile()
  self.parser:for_each_tree(function(tree)
    local root = tree:root()
    if root then
      local children = root:named_children()
      for _, node in ipairs(children) do
        self.result = self.result .. self:eval(node)
      end
    end
  end)

  self.result = self.result:gsub("\n\n\n+", "\n\n")

  return self.result, self.sections
end

---Returns the Markdown representation of a node
---@param node TSNode
---@return string
function transpiler:eval(node)
  local result = ""
  local node_type = node:type()
  local node_text = self:get_node_text(node)
  local attributes = self:get_node_attributes(node)

  if node_type == "text" or node_type == "entity" then
    result = result .. normalize_html(node_text)
  elseif node_type == "element" then
    local tag_node = node:named_child()
    local tag_type = tag_node:type()
    local tag_name = self:get_node_tag_name(node)
    local parent_node = node:parent()
    local parent_tag_name = self:get_node_tag_name(parent_node)

    if tag_type == "start_tag" then
      local children = self:filter_tag_children(node)

      for _, child in ipairs(children) do
        result = result .. self:eval_child(child, node)
      end
    end

    if is_skipable_tag(tag_name) then return "" end
    if is_monospace_tag(tag_name) and self:has_parent_tag(node, "pre") then return result end -- avoid nested code blocks

    if tag_name == "a" then
      result = string.format("[%s](%s)", result, attributes.href)
    elseif tag_name == "img" and string.match(attributes.src, "^data:") then
      result = string.format("![%s](%s)\n", attributes.alt, "data:inline_image")
    elseif tag_name == "img" then
      result = string.format("![%s](%s)\n", attributes.alt, attributes.src)
    elseif tag_name == "pre" and attributes["data-language"] then
      result = "\n```" .. attributes["data-language"] .. "\n" .. result .. "\n```\n"
    elseif tag_name == "pre" and attributes["class"] then
      local language = attributes["class"]:match("language%-(.+)")
      result = "\n```" .. (language or "") .. "\n" .. result .. "\n```\n"
    elseif tag_name == "abbr" then
      result = string.format("%s(%s)", result, attributes.title)
    elseif tag_name == "iframe" then
      result = string.format("[%s](%s)\n", attributes.title, attributes.src)
    elseif tag_name == "details" then
      result = "..."
    elseif tag_name == "table" then
      result = self:eval_table(node) .. "\n"
    elseif tag_name == "li" then
      if parent_tag_name == "ul" then result = "- " .. result .. "\n" end
      if parent_tag_name == "ol" then
        local siblings = self:filter_tag_children(parent_node)
        for i, sibling in ipairs(siblings) do
          if node:equal(sibling) then result = i .. ". " .. result .. "\n" end
        end
      end
    else
      local map = tag_mappings[tag_name]
      if map then
        local left = map.left and map.left or ""
        local right = map.right and map.right or ""
        result = left .. result .. right
      else
        result = result .. node_text
      end
    end
  end

  -- use the Markdown text for indexing docs in the index.json file
  local id = attributes.id

  if id and self.section_map and vim.tbl_contains(self.section_map, id) then
    table.insert(self.sections, { id = id, md_path = vim.trim(result) })
  end

  return result
end

---@param node TSNode
---@param parent_node TSNode
---@return string
function transpiler:eval_child(node, parent_node)
  local result = self:eval(node)
  local tag_name = self:get_node_tag_name(node)
  local sibling = node:next_named_sibling()
  local attributes = self:get_node_attributes(parent_node)

  -- checks if there should be additional spaces/characters between two elements
  if sibling then
    local start_row, start_col = node:end_()
    local target_row, target_col = sibling:start()

    -- The <pre> HTML element represents preformatted text
    -- which is to be presented exactly as written in the HTML file
    if self:has_parent_tag(node, "pre") or attributes.class == "_rfc-pre" then
      local child = sibling:named_child()

      -- skip all the tags to get the actual text offset, see #56
      while child do
        local child_sibling = child:next_named_sibling()
        if child:type() == "start_tag" and child_sibling then
          local c_row, c_col = child:end_()
          local s_row, s_col = child_sibling:start()

          if c_row == s_row and c_col == s_col then
            child = child_sibling:named_child()
          else
            start_row, start_col = c_row, c_col
            target_row, target_col = s_row, s_col

            if child_sibling:type() == "text" or "entity" then break end
          end
        else
          break
        end
      end

      local row, col = start_row, start_col
      while row ~= target_row or col ~= target_col do
        local char = self:get_text_range(row, col, row, col + 1)
        if char ~= "" then
          result = result .. char
          col = col + 1
        else
          result = result .. "\n"
          row, col = row + 1, 0
        end
      end
    else
      local is_inline = is_inline_tag(tag_name) or not tag_name -- is text
      if is_inline and start_col ~= target_col then result = result .. " " end
    end
  end

  return result
end

---Converts <table> tag, table nodes are evaluated from parent to child
---@param node TSNode
---@return string
function transpiler:eval_table(node)
  local result = ""
  local children = self:filter_tag_children(node)
  ---@type TSNode[]
  local tr_nodes = {}
  local first_child_tag = self:get_node_tag_name(children[1])

  if first_child_tag == "tr" then
    vim.list_extend(tr_nodes, children)
  else
    -- extracts tr from thead, tbody
    for _, child in ipairs(children) do
      vim.list_extend(tr_nodes, self:filter_tag_children(child))
    end
  end

  local max_col_len_map = {}
  local result_map = {} -- the converted text of each col
  local colspan_map = {} -- colspan attribute

  for i, tr in ipairs(tr_nodes) do
    local tr_children = self:filter_tag_children(tr)

    result_map[i] = {}
    colspan_map[i] = {}

    for j, tcol_node in ipairs(tr_children) do
      local inner_result = ""
      local tcol_children = self:filter_tag_children(tcol_node)
      local attributes = self:get_node_attributes(tcol_node)

      for _, tcol_child in ipairs(tcol_children) do
        inner_result = inner_result .. self:eval(tcol_child)
      end

      inner_result = inner_result:gsub("\n", "")
      result_map[i][j] = inner_result
      colspan_map[i][j] = attributes.colspan or 1

      if not max_col_len_map[j] then max_col_len_map[j] = 1 end
      if max_col_len_map[j] < #inner_result then max_col_len_map[j] = #inner_result end
    end
  end

  -- draws columns evenly
  for i = 1, #tr_nodes do
    local current_col = 1
    for j, value in ipairs(result_map[i]) do
      local colspan = tonumber(colspan_map[i][j])
      local col_len = max_col_len_map[current_col]

      if not col_len then break end

      result = result .. "| " .. value .. string.rep(" ", col_len - #value + 1)
      current_col = current_col + 1

      if colspan > 1 then
        local len = current_col + colspan - 1
        while current_col < len do
          local spacing = max_col_len_map[current_col]
          if spacing then result = result .. string.rep(" ", spacing + 3) end
          current_col = current_col + 1
        end
      end
    end

    result = result .. "|\n"

    -- generates row separator
    if i == 1 then
      current_col = 1
      for j = 1, #result_map[i] do
        local colspan = tonumber(colspan_map[i][j])
        local col_len = max_col_len_map[current_col]

        if not col_len then break end

        local line = string.rep("-", col_len)
        current_col = current_col + 1

        if colspan > 1 then
          local len = current_col + colspan - 1
          while current_col < len do
            local spacing = max_col_len_map[current_col]
            if spacing then line = line .. string.rep("-", spacing + 3) end
            current_col = current_col + 1
          end
        end
        result = result .. "| " .. string.gsub(line, "\n", "") .. " "
      end

      result = result .. "|\n"
    end
  end

  return result
end

---Converts a `RegisteryEntry` to yaml
---@param entry RegisteryEntry
---@return string
M.to_yaml = function(entry)
  local lines = {}

  for key, value in pairs(entry) do
    if key == "attribution" then
      value = normalize_html(value)
      value = value:gsub("<a.*>(.*)</a>", "%1")
      value = value:gsub("<br>", "")
      value = value:gsub("\n *", " ")
    end
    if key == "links" then value = vim.fn.json_encode(value) end
    table.insert(lines, key .. ": " .. value)
  end

  return table.concat(lines, "\n")
end

---@param html string
---@param section_map table<string, string>
---@return string, table<string, string>
M.html_to_md = function(html, section_map)
  local t = transpiler:new(html, section_map)
  return t:transpile()
end

return M
