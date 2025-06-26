local config = require("codecompanion.config")
local log = require("codecompanion.utils.log")

local M = {}

---Clear a keymap from a specific buffer
---@param keymaps table
---@param bufnr? integer
local function clear_map(keymaps, bufnr)
  bufnr = bufnr or 0
  for _, map in pairs(keymaps) do
    for mode, lhs in pairs(map.modes) do
      vim.keymap.del(mode, lhs, { buffer = bufnr })
    end
  end
end

M.accept_hunk = {
  desc = "Accept a hunk of the diff from the LLM",
  callback = function(inline)
    if inline.diff then
      log:trace("[Inline] Accepting hunk of diff")
      inline.diff:accept_hunk()
    end
  end,
}

M.accept_change = {
  desc = "Accept the change from the LLM",
  callback = function(inline)
    if inline.diff then
      log:trace("[Inline] Accepting diff")
      inline.diff:accept()
      clear_map(config.strategies.inline.keymaps, inline.diff.bufnr)
    end
  end,
}

M.reject_hunk = {
  desc = "Reject a hunk of the diff from the LLM",
  callback = function(inline)
    if inline.diff then
      log:debug("[Inline] Reject hunk of diff")
      inline.diff:reject_hunk()
    end
  end,
}

M.reject_change = {
  desc = "Reject the change from the LLM",
  callback = function(inline)
    if inline.diff then
      log:trace("[Inline] Rejecting diff")
      inline.diff:reject()
      clear_map(config.strategies.inline.keymaps, inline.diff.bufnr)
    end
  end,
}

return M
