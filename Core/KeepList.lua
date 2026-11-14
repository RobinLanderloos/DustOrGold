-- The keep list: a set of item IDs that never get a verdict
-- (docs/adr/0005). Pure (docs/adr/0006).
local _, ns = ...

local KeepList = {}
ns.KeepList = KeepList

-- The item ID in an item link, an "item:123" string or a bare number.
function KeepList.ItemID(text)
  if type(text) == "number" then return text end
  if type(text) ~= "string" then return nil end
  return tonumber(text:match("item:(%d+)") or text:match("^%s*(%d+)%s*$"))
end

function KeepList.Add(keep, itemID)
  keep[itemID] = true
end

function KeepList.Remove(keep, itemID)
  keep[itemID] = nil
end

function KeepList.Contains(keep, itemID)
  return keep[itemID] == true
end

function KeepList.List(keep)
  local ids = {}
  for itemID in pairs(keep) do ids[#ids + 1] = itemID end
  table.sort(ids)
  return ids
end
