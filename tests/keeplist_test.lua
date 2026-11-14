-- The keep list: items the player never wants a verdict on.
local ns, test, eq = ...
local KeepList = ns.KeepList

local LINK = "|cff1eff00|Hitem:2140:0:0:0:0:0:0:0:20|h[Carving Knife]|h|r"

test("an item ID is read from an item link, an item string or a number", function()
  eq(KeepList.ItemID(LINK), 2140)
  eq(KeepList.ItemID("item:2140"), 2140)
  eq(KeepList.ItemID("2140"), 2140)
  eq(KeepList.ItemID(2140), 2140)
end)

test("text that names no item gives no ID", function()
  eq(KeepList.ItemID("carving knife"), nil)
  eq(KeepList.ItemID(""), nil)
  eq(KeepList.ItemID(nil), nil)
end)

test("a kept item is on the list until it is removed", function()
  local keep = {}
  eq(KeepList.Contains(keep, 2140), false)
  KeepList.Add(keep, 2140)
  eq(KeepList.Contains(keep, 2140), true)
  eq(KeepList.Contains(keep, 9999), false)
  KeepList.Remove(keep, 2140)
  eq(KeepList.Contains(keep, 2140), false)
end)

test("the kept items are listed in a stable order", function()
  local keep = {}
  KeepList.Add(keep, 300); KeepList.Add(keep, 100); KeepList.Add(keep, 200)
  local ids = KeepList.List(keep)
  eq(#ids, 3)
  eq(ids[1], 100); eq(ids[2], 200); eq(ids[3], 300)
end)
