local M = {}

local path = require("plenary.path")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local previewers = require("telescope.previewers")
local state = require("telescope.state")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local config = require("telescope.config").values

local list = require("nvim-devdocs.list")
local notify = require("nvim-devdocs.notify")
local operations = require("nvim-devdocs.operations")
local transpiler = require("nvim-devdocs.transpiler")
local plugin_config = require("nvim-devdocs.config").get()

local new_docs_picker = function(prompt, entries, previwer, attach)
  return pickers.new(plugin_config.telescope, {
    prompt_title = prompt,
    finder = finders.new_table({
      results = entries,
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry.slug:gsub("~", "-"),
          ordinal = entry.slug:gsub("~", "-"),
        }
      end,
    }),
    sorter = config.generic_sorter(plugin_config.telescope),
    previewer = previwer,
    attach_mappings = attach,
  })
end

local metadata_previewer = previewers.new_buffer_previewer({
  title = "Metadata",
  define_preview = function(self, entry)
    local bufnr = self.state.bufnr
    local transpiled = transpiler.to_yaml(entry.value)
    local lines = vim.split(transpiled, "\n")

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.bo[bufnr].ft = "yaml"
  end,
})

local buf_doc_previewer = previewers.new_buffer_previewer({
  title = "Preview",
  keep_last_buf = true,
  define_preview = function(self, entry)
    local splited_path = vim.split(entry.value.path, ",")
    local file = splited_path[1]
    local file_path = path:new(plugin_config.dir_path, "docs", entry.value.alias, file .. ".md")
    local bufnr = self.state.bufnr

    local display_lines = function(lines)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      vim.bo[bufnr].ft = "markdown"
      -- TODO: highlight in picker
      -- vim.api.nvim_buf_call(bufnr, function()
      --   vim.fn.search(section)
      --   vim.fn.matchadd("Search", pattern)
      -- end)
    end

    file_path:_read_async(vim.schedule_wrap(function(content)
      local lines = vim.split(content, "\n")
      display_lines(lines)
    end))
  end,
})

local term_doc_previewer = previewers.new_termopen_previewer({
  title = "Preview",
  get_command = function(entry)
    local splited_path = vim.split(entry.value.path, ",")
    local file = splited_path[1]
    local file_path = path:new(plugin_config.dir_path, "docs", entry.value.alias, file .. ".md")
    local args = { plugin_config.previewer_cmd }

    vim.list_extend(args, plugin_config.picker_cmd_args)
    table.insert(args, path.__tostring(file_path))

    return args
  end,
})

local open_doc = function(float)
  local bufnr
  local selection = action_state.get_selected_entry()

  if plugin_config.picker_cmd then
    bufnr = vim.api.nvim_create_buf(false, true)
    local splited_path = vim.split(selection.value.path, ",")
    local file = splited_path[1]
    local file_path = path:new(plugin_config.dir_path, "docs", selection.value.alias, file .. ".md")
    local content = file_path:read()
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(content, "\n"))
  else
    bufnr = state.get_global_key("last_preview_bufnr")
  end

  local splited_path = vim.split(selection.value.path, ",")

  operations.open(selection.value.alias, bufnr, splited_path[2], float)
end

M.installation_picker = function()
  local registery_path = path:new(plugin_config.dir_path, "registery.json")

  if not registery_path:exists() then
    notify.log_err("DevDocs registery not found, please run :DevdocsFetch")
    return
  end

  local content = registery_path:read()
  local parsed = vim.fn.json_decode(content)
  local picker = new_docs_picker("Install documentation", parsed, metadata_previewer, function()
    actions.select_default:replace(function(prompt_bufnr)
      local selection = action_state.get_selected_entry()

      actions.close(prompt_bufnr)
      operations.install(selection.value)
    end)
    return true
  end)

  picker:find()
end

M.uninstallation_picker = function()
  local installed = list.get_installed_entry()
  local picker = new_docs_picker(
    "Uninstall documentation",
    installed,
    metadata_previewer,
    function()
      actions.select_default:replace(function(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        local alias = selection.value.slug:gsub("~", "-")

        actions.close(prompt_bufnr)
        operations.uninstall(alias)
      end)
      return true
    end
  )

  picker:find()
end

M.update_picker = function()
  local installed = list.get_updatable()
  local picker = new_docs_picker("Update documentation", installed, metadata_previewer, function()
    actions.select_default:replace(function(prompt_bufnr)
      local selection = action_state.get_selected_entry()
      local alias = selection.value.slug:gsub("~", "-")

      actions.close(prompt_bufnr)
      operations.install(alias, true, true)
    end)
    return true
  end)

  picker:find()
end

M.open_picker = function(alias, float)
  local entries = operations.get_entries(alias)

  if not entries then
    notify.log_err(alias .. " documentation is not installed")
    return
  end

  local previewer = buf_doc_previewer

  if plugin_config.previewer_cmd and plugin_config.previewer_cmd then
    previewer = term_doc_previewer
  end

  local picker = pickers.new(plugin_config.telescope, {
    prompt_title = "Select an entry",
    finder = finders.new_table({
      results = entries,
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry.name,
          ordinal = entry.name,
        }
      end,
    }),
    sorter = config.generic_sorter(plugin_config.telescope),
    previewer = previewer,
    attach_mappings = function()
      actions.select_default:replace(function(prompt_bufnr)
        actions.close(prompt_bufnr)
        open_doc(float)
      end)
      return true
    end,
  })

  picker:find()
end

M.global_search_picker = function(float)
  local entries = operations.get_all_entries()
  local previewer = buf_doc_previewer

  if plugin_config.previewer_cmd and plugin_config.previewer_cmd then
    previewer = term_doc_previewer
  end

  local picker = pickers.new(plugin_config.telescope, {
    prompt_title = "Select an entry",
    finder = finders.new_table({
      results = entries,
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry.name,
          ordinal = entry.name,
        }
      end,
    }),
    sorter = config.generic_sorter(plugin_config.telescope),
    previewer = previewer,
    attach_mappings = function()
      actions.select_default:replace(function(prompt_bufnr)
        actions.close(prompt_bufnr)
        open_doc(float)
      end)

      return true
    end,
  })

  picker:find()
end

return M
