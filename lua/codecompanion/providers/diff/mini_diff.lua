---Utilising the awesome:
---https://github.com/echasnovski/mini.diff

local apply_hunks = require("codecompanion.utils.apply_hunks")
local log = require("codecompanion.utils.log")
local util = require("codecompanion.utils")

local ok, diff = pcall(require, "mini.diff")
if not ok then
  return log:error("Failed to load mini.diff: %s", diff)
end

local api = vim.api

local current_source

---@class CodeCompanion.MiniDiff
---@field bufnr number The buffer number of the original buffer
---@field contents string[] The contents of the original buffer
---@field id number A unique identifier for the diff instance
---@field aug string Autocommand group for MiniDiff events
---@field seen_event boolean If we have seen a MiniDiffUpdated event
local MiniDiff = {}

---@param args CodeCompanion.DiffArgs
function MiniDiff.new(args)
  local self = setmetatable({
    bufnr = args.bufnr,
    contents = args.contents,
    id = args.id,
    aug = vim.api.nvim_create_augroup("codecompanion_minidiff_" .. tostring(args.id), { clear = true }),
    seen_event = false,
  }, { __index = MiniDiff })

  -- Capture the current source before we disable it
  if vim.b.minidiff_summary then
    current_source = vim.b.minidiff_summary["source_name"]
  end
  diff.disable(self.bufnr)

  -- Change the buffer source
  vim.b[self.bufnr].minidiff_config = {
    source = {
      name = "codecompanion",
      attach = function(bufnr)
        util.fire("DiffAttached", { diff = "mini_diff", bufnr = bufnr, id = self.id })
        diff.set_ref_text(bufnr, self.contents)
        diff.toggle_overlay(self.bufnr)
      end,
      detach = function(bufnr)
        util.fire("DiffDetached", { diff = "mini_diff", bufnr = bufnr, id = self.id })
        self:teardown()
      end,
      apply_hunks = function(bufnr, hunks)
        local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
        log:debug("Applying hunks %s", hunks)
        self.contents = apply_hunks.apply_hunks(lines, self.contents, hunks)
        diff.set_ref_text(bufnr, self.contents)
      end
    },
  }

  vim.api.nvim_create_autocmd('User', {
    group = self.aug,
    pattern = 'MiniDiffUpdated',
    callback = function(_)
      if not self.seen_event then
        vim.fn.setqflist(diff.export('qf'), 'a')
      else
        vim.fn.setqflist(diff.export('qf'), 'u')
      end
      self.seen_event = true
    end,
  })

  diff.enable(self.bufnr)
  log:trace("Using mini.diff")

  return self
end

---Finds the hunk associated with the current cursor position in the buffer
local function find_hunk_under_cursor(bufnr)
  local cursor_buf = vim.api.nvim_get_current_buf()
  if cursor_buf ~= bufnr then
    log:debug("cursor not on buf to find hunk")
    return nil
  end

  local row, _ = unpack(vim.api.nvim_win_get_cursor(0))
  local data = diff.get_buf_data(bufnr)
  if not data then
    log:debug("Minidiff returned no data?")
    return nil
  end

  local hunks = data.hunks
  for _, hunk in ipairs(hunks) do
    if hunk.buf_start <= row and row <= hunk.buf_start + hunk.buf_count then
      return hunk
    end
  end

  log:debug("Found no mindiff hunks on line %d out of hunks %s", row, hunks)
  return nil
end
---Accept hunk of the diff
---@return nil
function MiniDiff:accept_hunk()
  -- BAE what event to fire here?
  --util.fire("DiffAccepted", { diff = "mini_diff", bufnr = self.bufnr, id = self.id, accept = true })
  local hunk = find_hunk_under_cursor(self.bufnr)
  if hunk then
    diff.do_hunks(self.bufnr, 'apply', { line_start = hunk.buf_start, line_end = hunk.buf_start + hunk.buf_count })
  end
end

---Accept the diff
---@return nil
function MiniDiff:accept()
  util.fire("DiffAccepted", { diff = "mini_diff", bufnr = self.bufnr, id = self.id, accept = true })
  vim.b[self.bufnr].minidiff_config = nil
  diff.disable(self.bufnr)
end

---Accept hunk of the diff
---@return nil
function MiniDiff:reject_hunk()
  -- BAE what to fire here?
  --util.fire("DiffAccepted", { diff = "mini_diff", bufnr = self.bufnr, id = self.id, accept = true })
  local hunk = find_hunk_under_cursor(self.bufnr)
  if hunk then
    diff.do_hunks(self.bufnr, 'reset', { line_start = hunk.buf_start, line_end = hunk.buf_start + hunk.buf_count })
  end
end

---Reject the diff
---@return nil
function MiniDiff:reject()
  util.fire("DiffRejected", { diff = "mini_diff", bufnr = self.bufnr, id = self.id, accept = false })
  api.nvim_buf_set_lines(self.bufnr, 0, -1, true, self.contents)

  vim.b[self.bufnr].minidiff_config = nil
  diff.disable(self.bufnr)
end

---Close down mini.diff
---@return nil
function MiniDiff:teardown()
  -- Revert the source
  if current_source then
    vim.api.nvim_clear_autocmds({ group = self.aug })
    vim.b[self.bufnr].minidiff_config = diff.gen_source[current_source]()
    diff.enable(self.bufnr)
    current_source = nil
  end
end

return MiniDiff
