local M = {}

---@class CodeCompanion.HunkSpec follows the MiniDiff-hunk-specification
---@field buf_start number start of hunk buffer lines. First line is 1. Can be 0 if first reference lines are deleted.
---@field buf_count number number of buffer lines, 0 if reference lines are deleted.
---@field ref_start number start of hunk reference lines. First line is 1. Can be 0 if lines are added before first reference line.
---@field ref_count number number of reference lines, 0 in case buffer lines are added.
---@field type "add" | "change" | "delete"

---Applies the hunks from buf_lines into ref_lines
---@param buf_lines string[] buffer content
---@param ref_lines string[] reference content
---@param hunks CodeCompanion.HunkSpec[] hunks to apply
---@return string[] new ref_lines content
function M.apply_hunks(buf_lines, ref_lines, hunks)
  local final_lines = {}
  local ref_idx = 1

  for _, h in ipairs(hunks) do
    -- Add unchanged lines before this hunk
    for i = ref_idx, h.ref_start - 1 do
      table.insert(final_lines, ref_lines[i])
    end
    if h.type == "add" then
      table.insert(final_lines, ref_lines[h.ref_start])
      for i = 0, h.buf_count - 1 do
        table.insert(final_lines, buf_lines[h.buf_start + i])
      end
      assert(h.ref_count == 0)
      ref_idx = h.ref_start + 1
    elseif h.type == "change" then
      for i = 0, h.buf_count - 1 do
        table.insert(final_lines, buf_lines[h.buf_start + i])
      end
      ref_idx = h.ref_start + h.ref_count
    else
      assert(h.type == "delete")
      ref_idx = h.ref_start + h.ref_count
    end
  end
  -- Add remaining unchanged lines
  while ref_idx <= #ref_lines do
    table.insert(final_lines, ref_lines[ref_idx])
    ref_idx = ref_idx + 1
  end
  return final_lines
end

---Computes the hunks between buf_lines and ref_lines
---@param buf_lines string[] buffer content
---@param ref_lines string[] reference content
---@param algorithm string? algorithm choice for vim.diff
---@return CodeCompanion.HunkSpec[] hunks found in diff
function M.get_hunks(buf_lines, ref_lines, algorithm)
  local diff_opts = { result_type = "indices" }
  if algorithm then
    diff_opts["algorithm"] = algorithm
  end
  local hunks = vim.diff(table.concat(buf_lines, "\n"), table.concat(ref_lines, "\n"), diff_opts)

  local res = {}
  assert(type(hunks) == "table")
  for _, h in ipairs(hunks) do
    local hunk_type = h[4] == 0 and "add" or (h[2] == 0 and "delete" or "change")
    table.insert(res, { buf_start = h[1], buf_count = h[2], ref_start = h[3], ref_count = h[4], type = hunk_type })
  end
  return res
end

---Flips hunks to make apply_hunks work for reversed direction
---@param hunks CodeCompanion.HunkSpec[] original hunks
---@return CodeCompanion.HunkSpec[] hunks to be applied in other direction
function M.flip_hunks(hunks)
  local flipped_hunks = {}
  for _, h in ipairs(hunks) do
    table.insert(flipped_hunks, {
      buf_start = h.ref_start,
      buf_count = h.ref_count,
      ref_start = h.buf_start,
      ref_count = h.buf_count,
      -- Flip add and delete, keep change
      type = h.type == "change" and "change" or h.type == "add" and "delete" or "add",
    })
  end
  return flipped_hunks
end

---Finds the hunk associated with the current cursor position
---@param bufnr number buffer we're diffing
---@param hunks CodeCompanion.HunkSpec[] hunks to search through
---@return CodeCompanion.HunkSpec?
function M.find_hunk_under_cursor(bufnr, hunks)
  local cursor_buf = vim.api.nvim_get_current_buf()
  if cursor_buf ~= bufnr then
    return nil
  end

  local row, _ = unpack(vim.api.nvim_win_get_cursor(0))
  for _, hunk in ipairs(hunks) do
    if hunk.buf_start <= row and row <= hunk.buf_start + hunk.buf_count then
      return hunk
    end
  end

  return nil
end

return M
