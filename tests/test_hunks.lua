local h = require("tests.helpers")
local m = require("codecompanion.utils.hunks")

local function perform_test(buf_lines, ref_lines)
  local hunks = m.get_hunks(buf_lines, ref_lines, "histogram")
  local applied = m.apply_hunks(buf_lines, ref_lines, hunks)
  local reset = m.apply_hunks(ref_lines, buf_lines, m.flip_hunks(hunks))

  -- Not a generally true statements, but for purposes of tests it is
  h.eq(buf_lines, applied)
  h.eq(ref_lines, reset)
  return hunks
end

describe("Hunks", function()
  it("no change", function()
    -- Contents don't need to be the same, could have unapplied hunks
    local buf = { "a", "b", "c", "y" }
    local ref = { "a", "b", "c", "z", "z" }
    local result = m.apply_hunks(buf, ref, {})
    h.eq(result, { "a", "b", "c", "z", "z" })
  end)

  it("add", function()
    local buf = { "a", "b", "y", "y", "c" }
    local ref = { "a", "b", "c" }
    perform_test(buf, ref)
  end)

  it("delete", function()
    local buf = { "a", "b", "c" }
    local ref = { "a", "b", "x", "x", "c" }
    perform_test(buf, ref)
  end)

  it("change", function()
    local buf = { "a", "B", "B", "c" }
    local ref = { "a", "b", "c" }
    perform_test(buf, ref)
  end)

  it("change single", function()
    local buf = { "a", "B", "c" }
    local ref = { "a", "b", "c" }
    perform_test(buf, ref)
  end)
end)
