local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local previewers = require('telescope.previewers')
local utils = require('telescope.previewers.utils')
local config = require('telescope.config').values
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')

local log = require('plenary.log'):new()
log.level = 'debug'

local M = {}

local watch_path = nil

local function check_rewind_status()
  local handle = io.popen("rewind status -j")
  local result = handle:read("*a")
  handle:close()

  local parsed = vim.json.decode(result)

  if not parsed.watch_details or not parsed.watch_details.path then
    return false, "Not inside a Rewind directory"
  end

  watch_path = parsed.watch_details.path
  return true, nil
end

local function time_ago(timestamp)
  local now = os.time()
  local diff = now - timestamp

  if diff < 60 then
    return diff .. " seconds ago"
  elseif diff < 3600 then
    local minutes = math.floor(diff / 60)
    return minutes .. " minute" .. (minutes == 1 and "" or "s") .. " ago"
  elseif diff < 86400 then
    local hours = math.floor(diff / 3600)
    return hours .. " hour" .. (hours == 1 and "" or "s") .. " ago"
  elseif diff < 2592000 then
    local days = math.floor(diff / 86400)
    return days .. " day" .. (days == 1 and "" or "s") .. " ago"
  else
    local months = math.floor(diff / 2592000)
    return months .. " month" .. (months == 1 and "" or "s") .. " ago"
  end
end

M.Rewind = function(opts)
  local is_rewind_dir, error_msg = check_rewind_status()

  if not is_rewind_dir then
    print(error_msg)
    return
  end

  local filename = vim.fn.expand('%:t')

  local handle = io.popen("rewind rollback " .. filename .. " -j")
  local result = handle:read("*a")
  handle:close()

  local ok, parsed = pcall(vim.json.decode, result)
  if not ok or not parsed or not parsed.versions or #parsed.versions == 0 then
    print("No versions found for " .. filename .. " in the database")
    return
  end
  
  local versions = parsed.versions

  pickers.new(opts, {
    finder = finders.new_table({
      results = versions,
      entry_maker = function(entry)
        return {
          value = entry,
          display = string.format("v%s - %s (%s)%s",
            entry.version,
            time_ago(entry.timestamp_unix),
            entry.size,
            entry.tags and #entry.tags > 0 and (" [" .. entry.tags[1] .. "]") or ""
          ),
          ordinal = entry.file_path .. " " .. entry.timestamp_unix,
        }
      end,
    }),
    sorter = config.generic_sorter(opts),
    attach_mappings = function(prompt_bufnr, _)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)

        local cmd = string.format("rewind rollback %s -v %s", filename, selection.value.version)
        vim.fn.system(cmd)
        print("Rolled back " .. filename .. " to version " .. selection.value.version)
      end)
      return true
    end,
    previewer = previewers.new_buffer_previewer({
      title = "Rewind Version",
      define_preview = function(self, entry)
        if entry.value.storage_path then
          local version_file_path = watch_path .. "/.rewind/versions/" .. entry.value.storage_path
          local file = io.open(version_file_path, "r")
          if file then
            local content = file:read("*a")
            file:close()
            local lines = vim.split(content, "\n")
            vim.api.nvim_buf_set_lines(
              self.state.bufnr,
              0,
              -1,
              true,
              lines
            )
            local file_extension = vim.fn.fnamemodify(entry.value.file_path, ":e")
            if file_extension ~= "" then
              vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", file_extension)
            end
          else
            vim.api.nvim_buf_set_lines(
              self.state.bufnr,
              0,
              0,
              true,
              { "Error: Could not read version file at " .. version_file_path }
            )
          end
        else
          vim.api.nvim_buf_set_lines(
            self.state.bufnr,
            0,
            0,
            true,
            vim.tbl_flatten({ vim.split(vim.inspect(entry.value), "\n") }))
          utils.highlighter(self.state.bufnr, "markdown")
        end
      end
    })
  }):find()
end

M.RewindTag = function(opts)
  local is_rewind_dir, error_msg = check_rewind_status()

  if not is_rewind_dir then
    print(error_msg)
    return
  end

  local filename = vim.fn.expand('%:t')

  local handle = io.popen("rewind rollback " .. filename .. " -j")
  local result = handle:read("*a")
  handle:close()

  local ok, parsed = pcall(vim.json.decode, result)
  if not ok or not parsed or not parsed.versions or #parsed.versions == 0 then
    print("No versions found for " .. filename .. " in the database")
    return
  end
  
  local versions = parsed.versions

  local tagged_versions = {}
  for _, version in ipairs(versions) do
    if version.tags and #version.tags > 0 then
      table.insert(tagged_versions, version)
    end
  end

  if #tagged_versions == 0 then
    print("No tagged versions found for " .. filename)
    return
  end

  pickers.new(opts, {
    finder = finders.new_table({
      results = tagged_versions,
      entry_maker = function(entry)
        return {
          value = entry,
          display = string.format("%s - v%s - %s (%s)",
            entry.tags[1],
            entry.version,
            time_ago(entry.timestamp_unix),
            entry.size
          ),
          ordinal = entry.tags[1] .. " " .. entry.file_path .. " " .. entry.timestamp_unix,
        }
      end,
    }),
    sorter = config.generic_sorter(opts),
    attach_mappings = function(prompt_bufnr, _)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)

        local cmd = string.format("rewind rollback %s -v %s", filename, selection.value.version)
        vim.fn.system(cmd)
        print("Rolled back " .. filename .. " to tag '" .. selection.value.tags[1] .. "' (version " .. selection.value.version .. ")")
      end)
      return true
    end,
    previewer = previewers.new_buffer_previewer({
      title = "Rewind Tagged Version",
      define_preview = function(self, entry)
        if entry.value.storage_path then
          local version_file_path = watch_path .. "/.rewind/versions/" .. entry.value.storage_path
          local file = io.open(version_file_path, "r")
          if file then
            local content = file:read("*a")
            file:close()
            local lines = vim.split(content, "\n")
            vim.api.nvim_buf_set_lines(
              self.state.bufnr,
              0,
              -1,
              true,
              lines
            )
            local file_extension = vim.fn.fnamemodify(entry.value.file_path, ":e")
            if file_extension ~= "" then
              vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", file_extension)
            end
          else
            vim.api.nvim_buf_set_lines(
              self.state.bufnr,
              0,
              0,
              true,
              { "Error: Could not read version file at " .. version_file_path }
            )
          end
        else
          vim.api.nvim_buf_set_lines(
            self.state.bufnr,
            0,
            0,
            true,
            vim.tbl_flatten({ vim.split(vim.inspect(entry.value), "\n") }))
          utils.highlighter(self.state.bufnr, "markdown")
        end
      end
    })
  }):find()
end

-- Setup function to initialize the plugin
M.setup = function(opts)
  opts = opts or {}
  -- Register the commands
  vim.api.nvim_create_user_command('Rewind', M.Rewind, {})
  vim.api.nvim_create_user_command('RewindTag', M.RewindTag, {})
end

return M
