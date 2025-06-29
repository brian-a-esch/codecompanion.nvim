-- Taken from the awesome:
-- https://github.com/S1M0N38/dante.nvim

---@class CodeCompanion.Diff
---@field bufnr number The buffer number of the original buffer
---@field contents string[] The contents of the original buffer
---@field cursor_pos number[] The position of the cursor in the original buffer
---@field filetype string The filetype of the original buffer
---@field id number A unique identifier for the diff instance
---@field winnr number The window number of the original buffer
---@field diff table The table containing the diff buffer and window
---@field algorithm string The diff algorithm used

---@class CodeCompanion.DiffArgs
---@field bufnr number
---@field contents string[]
---@field cursor_pos? number[]
---@field filetype string
---@field id number A unique identifier for the diff instance-
---@field winnr number

local config = require("codecompanion.config")
local hunk_mod = require("codecompanion.utils.hunks")
local log = require("codecompanion.utils.log")
local util = require("codecompanion.utils")

local api = vim.api

---@class CodeCompanion.Diff
local Diff = {}

---@param args CodeCompanion.DiffArgs
function Diff.new(args)
  local self = setmetatable({
    bufnr = args.bufnr,
    contents = args.contents,
    cursor_pos = args.cursor_pos or nil,
    filetype = args.filetype,
    id = args.id,
    winnr = args.winnr,
    algorithm = nil,
  }, { __index = Diff })

  log:trace("Using default diff")
  for _, opt in ipairs(config.display.diff.opts) do
    if type(opt) == "string" then
      local algo_maybe = opt:match("^algorithm:(.+)$")
      if algo_maybe then
        self.algorithm = algo_maybe
        log:debug("Parsed algorithm %s from user diff options", self.algorithm)
      end
    end
  end

  -- Set the diff properties
  vim.cmd("set diffopt=" .. table.concat(config.display.diff.opts, ","))

  local vertical = (config.display.diff.layout == "vertical")

  -- Get current properties
  local buf_opts = {
    ft = util.safe_filetype(self.filetype),
  }
  local win_opts = {
    wrap = vim.wo.wrap,
    lbr = vim.wo.linebreak,
    bri = vim.wo.breakindent,
  }

  --- Minimize the chat buffer window if there's not enough screen estate
  local last_chat = require("codecompanion").last_chat()
  if last_chat and last_chat.ui:is_visible() and config.display.diff.close_chat_at > vim.o.columns then
    last_chat.ui:hide()
  end

  -- Create the diff buffer
  local diff = {
    buf = vim.api.nvim_create_buf(false, true),
    name = "[CodeCompanion] " .. math.random(10000000),
  }
  api.nvim_buf_set_name(diff.buf, diff.name)
  for opt, value in pairs(buf_opts) do
    api.nvim_set_option_value(opt, value, { buf = diff.buf })
  end

  -- Create the diff window
  diff.win = api.nvim_open_win(diff.buf, true, { vertical = vertical, win = self.winnr })
  for opt, value in pairs(win_opts) do
    vim.api.nvim_set_option_value(opt, value, { win = diff.win })
  end
  -- Set the diff buffer to the contents, prior to any modifications
  api.nvim_buf_set_lines(diff.buf, 0, -1, true, self.contents)
  if self.cursor_pos then
    api.nvim_win_set_cursor(diff.win, { self.cursor_pos[1], self.cursor_pos[2] })
  end

  -- Begin diffing
  util.fire("DiffAttached", { diff = "default", bufnr = self.bufnr, id = self.id, winnr = self.winnr })
  api.nvim_set_current_win(diff.win)
  vim.cmd("diffthis")
  api.nvim_set_current_win(self.winnr)
  vim.cmd("diffthis")

  log:trace("Using default diff")
  self.diff = diff

  return self
end

---Accept the diff
---@return nil
function Diff:accept()
  util.fire("DiffAccepted", { diff = "default", bufnr = self.bufnr, id = self.id, accept = true })
end

---Accept hunk of the diff
---@return boolean if all hunks diff have been applied
function Diff:accept_hunk()
  local buf_lines = vim.api.nvim_buf_get_lines(self.bufnr, 0, -1, false)
  local hunks = hunk_mod.get_hunks(buf_lines, self.contents, self.algorithm)
  local hunk = hunk_mod.find_hunk_under_cursor(self.bufnr, hunks)
  log:debug("For apply buffer has %d hunks, found %s under curor", #hunks, hunk)
  if hunk then
    self.contents = hunk_mod.apply_hunks(buf_lines, self.contents, { hunk })
    vim.api.nvim_buf_set_lines(self.diff.buf, 0, -1, true, self.contents)
    vim.cmd("diffupdate")
    if #hunks <= 1 then
      util.fire("DiffAccepted", { diff = "default", bufnr = self.bufnr, id = self.id, accept = true })
      return true
    end
  end

  return false
end

---Reject the diff
---@return nil
function Diff:reject()
  util.fire("DiffRejected", { diff = "default", bufnr = self.bufnr, id = self.id, accept = false })
  return api.nvim_buf_set_lines(self.bufnr, 0, -1, true, self.contents)
end

---Reject hunk of the diff
---@return boolean if all hunks diff have been applied
function Diff:reject_hunk()
  local buf_lines = vim.api.nvim_buf_get_lines(self.bufnr, 0, -1, false)
  local hunks = hunk_mod.get_hunks(buf_lines, self.contents, self.algorithm)
  local hunk = hunk_mod.find_hunk_under_cursor(self.bufnr, hunks)
  log:debug("For reject buffer has %d hunks, found %s under curor", #hunks, hunk)
  if hunk then
    local flipped = hunk_mod.flip_hunks({ hunk })
    local new_buf_lines = hunk_mod.apply_hunks(self.contents, buf_lines, flipped)
    vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, true, new_buf_lines)
    vim.cmd("diffupdate")

    if #hunks <= 1 then
      util.fire("DiffRejected", { diff = "default", bufnr = self.bufnr, id = self.id, accept = false })
      return true
    end
  end

  return false
end

---Close down the diff
---@return nil
function Diff:disable()
  vim.cmd("diffoff")
  api.nvim_buf_delete(self.diff.buf, {})
  util.fire("DiffDetached", { diff = "default", bufnr = self.bufnr, id = self.id, winnr = self.diff.win })
end

return Diff
