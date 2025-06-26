local h = require("tests.helpers")
local m = require('codecompanion.utils.apply_hunks')

describe("Apply Hunks", function()
  it("no change", function ()
    -- Contents don't need to be the same, could have unapplied hunks
    local result = m.apply_hunks({"a", "b", "c", "y"}, {"a", "b", "c", "z", "z"}, {})
    h.eq(result, {"a", "b", "c", "z", "z"})
  end)

  it("add", function ()
    local hunks = {
      { buf_start = 3, buf_count = 2, ref_start = 2, ref_count = 0, type = "add"},
    }
    local result = m.apply_hunks({"a", "b", "y", "y", "c"}, {"a", "b", "c"}, hunks)
    h.eq(result, {"a", "b", "y", "y", "c"})
  end)

  it("delete", function ()
    local hunks = {
      { buf_start = 2, buf_count = 0, ref_start = 3, ref_count = 2, type = "delete"},
    }
    local result = m.apply_hunks({"a", "b", "c"}, {"a", "b", "x", "x", "c"}, hunks)
    h.eq(result, {"a", "b", "c"})
  end)

  it("change", function ()
    local hunks = {
      { buf_start = 2, buf_count = 2, ref_start = 2, ref_count = 1, type = "change"},
    }
    local result = m.apply_hunks({"a", "B", "B", "c"}, {"a", "b", "c"}, hunks)
    h.eq(result, {"a", "B", "B", "c"})
  end)

  it("change single", function ()
    local hunks = {
      { buf_start = 2, buf_count = 1, ref_start = 2, ref_count = 1, type = "change"},
    }
    local result = m.apply_hunks({"a", "B", "C"}, {"a", "b", "c"}, hunks)
    h.eq(result, {"a", "B", "c"})
  end)
end)
