M = {}

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
  header = {},
  div = {},
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
  b = { left = "`", right = "`" },
  strong = { left = "**", right = "**" },
  em = { left = " _", right = "_ " },
  small = { left = " _", right = "_ " },
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
  hr = { right = "---" },
}

local skipable_tag = {
  "input",

  -- exceptions, table -> child
  "tr",
  "td",
  "th",
  "thead",
  "tbody",
}

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

M.html_to_md = function(html)
  local transpiler = {
    parser = vim.treesitter.get_string_parser(html, "html"),
    lines = vim.split(html, "\n"),
    result = "",
  }

  ---@param node TSNode
  function transpiler:get_node_text(node)
    local row_start, col_start = node:start()
    local row_end, col_end = node:end_()
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
  function transpiler:get_node_tag_name(node)
    local tag_node = node:named_child():named_child()
    local tag_name = self:get_node_text(tag_node)

    return tag_name
  end

  ---@param node TSNode
  function transpiler:get_node_attributes(node)
    local attributes = {}
    local tag_node = node:named_child()

    if tag_node == nil then return {} end

    local tag_children = tag_node:named_children()

    for i = 2, #tag_children do
      local attribute_node = tag_children[i]
      local attribute_name_node = attribute_node:named_child()
      local attribute_name = self:get_node_text(attribute_name_node)
      local value = ""

      if attribute_name_node:next_named_sibling() then
        local quotetd_value_node = attribute_name_node:next_named_sibling()
        local value_node = quotetd_value_node:named_child()
        if value_node then value = self:get_node_text(value_node) end
      end

      attributes[attribute_name] = value
    end

    return attributes
  end

  ---@param node TSNode
  function transpiler:filter_tag_children(node)
    local children = node:named_children()
    local filtered = vim.tbl_filter(function(child)
      local type = child:type()
      return type ~= "start_tag" and type ~= "end_tag"
    end, children)

    return filtered
  end

  ---@param node TSNode
  function transpiler:eval(node)
    local result = ""
    local node_type = node:type()
    local node_text = self:get_node_text(node)

    if node_type == "text" or node_type == "entity" then
      result = result .. normalize_html(node_text)
    elseif node_type == "element" then
      local tag_node = node:named_child()
      local tag_type = tag_node:type()
      local tag_name = self:get_node_text(tag_node:named_child())
      local attributes = self:get_node_attributes(node)

      if tag_type == "start_tag" then
        local children = self:filter_tag_children(node)
        for _, child in ipairs(children) do
          result = result .. self:eval(child)
        end
      end

      if vim.tbl_contains(skipable_tag, tag_name) then return "" end

      if tag_name == "a" then
        result = string.format("[%s](%s)", result, attributes.href)
      elseif tag_name == "img" then
        result = string.format("![%s](%s)", attributes.alt, attributes.src)
      elseif tag_name == "pre" and attributes["data-language"] then
        result = "\n```" .. attributes["data-language"] .. "\n" .. result .. "\n```\n"
      elseif tag_name == "abbr" then
        result = string.format("%s(%s)", result, attributes.title)
      elseif tag_name == "iframe" then
        result = string.format("[%s](%s)\n", attributes.title, attributes.src)
      elseif tag_name == "details" then
        result = "..."
      elseif tag_name == "table" then
        result = self:eval_table(node) .. "\n"
      elseif tag_name == "li" then
        local parent_node = node:parent()
        local parent_tag_name = self:get_node_tag_name(parent_node)

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

    result = result:gsub("\n\n\n+", "\n\n")

    return result
  end

  ---@param node TSNode
  function transpiler:eval_table(node)
    local result = ""
    local children = self:filter_tag_children(node)
    ---@type TSNode[]
    local tr_nodes = {}

    -- extracts tr from thead, tbody
    for _, child in ipairs(children) do
      vim.list_extend(tr_nodes, self:filter_tag_children(child))
    end

    local max_col_len_map = {}
    local result_map = {}
    local colspan_map = {}

    for i, tr in ipairs(tr_nodes) do
      local tr_children = self:filter_tag_children(tr)
      result_map[i] = {}
      colspan_map[i] = {}

      for j, tcol_node in ipairs(tr_children) do
        local inner_result = ""
        local tcol_children = self:filter_tag_children(tcol_node)
        local attributes = self:get_node_attributes(tcol_node)

        for _, tcol_child in ipairs(tcol_children) do
          inner_result = self:eval(tcol_child)
        end

        result_map[i][j] = inner_result
        colspan_map[i][j] = attributes.colspan and attributes.colspan or 1

        if max_col_len_map[j] == nil then max_col_len_map[j] = 0 end
        if max_col_len_map[j] < #inner_result then max_col_len_map[j] = #inner_result end
      end
    end

    -- draws columns evenly
    for i = 1, #tr_nodes do
      local current_col = 1
      for j, value in ipairs(result_map[i]) do
        local col_len = max_col_len_map[current_col]
        local colspan = tonumber(colspan_map[i][j])
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
          local col_len = max_col_len_map[current_col]
          local colspan = tonumber(colspan_map[i][j])
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
          result = result .. "| " .. line .. " "
        end

        result = result .. "|\n"
      end
    end

    return result
  end

  function transpiler:transpile()
    self.parser:parse()
    self.parser:for_each_tree(function(tree)
      local root = tree:root()
      if root then
        local children = root:named_children()
        for _, node in ipairs(children) do
          self.result = self.result .. self:eval(node)
        end
      end
    end)

    return self.result
  end

  return transpiler:transpile()
end

return M
