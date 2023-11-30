local M = {}

local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local previewers = require("telescope.previewers")
local state = require("telescope.state")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local config = require("telescope.config").values
local entry_display = require("telescope.pickers.entry_display")

local list = require("nvim-devdocs.list")
local notify = require("nvim-devdocs.notify")
local operations = require("nvim-devdocs.operations")
local transpiler = require("nvim-devdocs.transpiler")
local plugin_state = require("nvim-devdocs.state")
local plugin_config = require("nvim-devdocs.config")

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

---@param prompt string
---@param entries RegisteryEntry[]
---@param on_attach function
---@return Picker
local function new_registery_picker(prompt, entries, on_attach)
  return pickers.new(plugin_config.options.telescope, {
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
    sorter = config.generic_sorter(plugin_config.options.telescope),
    previewer = metadata_previewer,
    attach_mappings = on_attach,
  })
end

local doc_previewer = previewers.new_buffer_previewer({
  title = "Preview",
  keep_last_buf = true,
  define_preview = function(self, entry)
    local bufnr = self.state.bufnr

    operations.read_entry_async(entry.value, function(filtered_lines)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, filtered_lines)

      if plugin_config.options.previewer_cmd and plugin_config.options.picker_cmd then
        plugin_state.set("preview_lines", filtered_lines)
        operations.render_cmd(bufnr, true)
      else
        vim.bo[bufnr].ft = "markdown"
      end
    end)
  end,
})

local function open_doc(selection, float)
  local bufnr = state.get_global_key("last_preview_bufnr")

  if plugin_config.options.picker_cmd or not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    bufnr = vim.api.nvim_create_buf(false, true)
    local lines = plugin_state.get("preview_lines") or operations.read_entry(selection.value)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  end

  plugin_state.set("last_mode", float and "float" or "normal")
  operations.open(selection.value, bufnr, float)
end

M.installation_picker = function()
  local non_installed = list.get_non_installed_registery()

  if not non_installed then return end

  local picker = new_registery_picker("Install documentation", non_installed, function()
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
  local installed = list.get_installed_registery()

  if not installed then return end

  local picker = new_registery_picker("Uninstall documentation", installed, function()
    actions.select_default:replace(function(prompt_bufnr)
      local selection = action_state.get_selected_entry()
      local alias = selection.value.slug:gsub("~", "-")

      actions.close(prompt_bufnr)
      operations.uninstall(alias)
    end)
    return true
  end)

  picker:find()
end

M.update_picker = function()
  local updatable = list.get_updatable_registery()

  if not updatable then return end

  local picker = new_registery_picker("Update documentation", updatable, function()
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

---@param entries DocEntry[]
---@param float? boolean
M.open_picker = function(entries, float)
  local displayer = entry_display.create({
    separator = " ",
    items = {
      { remaining = true },
      { remaining = true },
    },
  })

  local picker = pickers.new(plugin_config.options.telescope, {
    prompt_title = "Select an entry",
    finder = finders.new_table({
      results = entries,
      entry_maker = function(entry)
        return {
          value = entry,
          display = function()
            return displayer({
              { string.format("[%s]", entry.alias), "markdownH1" },
              { entry.name, "markdownH2" },
            })
          end,
          ordinal = string.format("[%s] %s", entry.alias, entry.name),
        }
      end,
    }),
    sorter = config.generic_sorter(plugin_config.options.telescope),
    previewer = doc_previewer,
    attach_mappings = function()
      actions.select_default:replace(function(prompt_bufnr)
        actions.close(prompt_bufnr)

        local selection = action_state.get_selected_entry()

        if selection then
          plugin_state.set("current_doc", selection.value.alias)
          open_doc(selection, float)
        end
      end)
      return true
    end,
  })

  picker:find()
end

---@param alias string
---@param float? boolean
M.open_picker_alias = function(alias, float)
  local entries = list.get_doc_entries({ alias })

  if not entries then return end

  if vim.tbl_isempty(entries) then
    notify.log_err(alias .. " documentation is not installed")
  else
    plugin_state.set("current_doc", alias)
    M.open_picker(entries, float)
  end
end

return M
