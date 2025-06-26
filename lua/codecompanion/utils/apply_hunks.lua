local M = {}

---Applies the hunks from buf_lines into ref_lines 
---@param buf_lines table<string>
---@param ref_lines table<string>
---@param hunks table per MiniDiff-hunk-specification
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

return M
