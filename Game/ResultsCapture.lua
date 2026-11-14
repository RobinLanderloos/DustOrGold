-- Records every disenchant the player performs (docs/adr/0001): which item,
-- and what it gave. The item being disenchanted is the one locked in the bags
-- while the cast runs; what it gave is the loot window that follows.
local _, ns = ...

local Game = ns.Game
local DISENCHANT = 13262
local MAX_WAIT = 15 -- seconds from the cast to the loot
local pending

local function trace(text)
  if ns.debug then ns.Say("[log] " .. text) end
end

-- The disenchantable item locked in the bags, as item facts.
local function lockedItem()
  for bag = Enum.BagIndex.Backpack, Enum.BagIndex.ReagentBag do
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and info.isLocked and info.hyperlink then
        local facts = Game.ItemFacts(info.hyperlink, C_TooltipInfo.GetBagItem(bag, slot))
        if facts and facts.kind then return facts, info.hyperlink end
      end
    end
  end
end

local function received()
  local list = {}
  for i = 1, GetNumLootItems() do
    local itemID = ns.KeepList.ItemID(GetLootSlotLink(i))
    local _, _, count = GetLootSlotInfo(i)
    if itemID and type(count) == "number" and count > 0 then
      list[#list + 1] = { item = itemID, count = count }
    end
  end
  return list
end

local handlers = {}

function handlers.UNIT_SPELLCAST_START(_, _, spellID)
  if spellID ~= DISENCHANT then return end
  local facts, link = lockedItem()
  pending = { facts = facts, link = link, time = GetTime() }
  trace("cast started on " .. tostring(link))
end

function handlers.UNIT_SPELLCAST_SUCCEEDED(_, _, spellID)
  if spellID ~= DISENCHANT then return end
  -- An instant cast has no start event, so look for the item now.
  if not (pending and pending.facts) then
    local facts, link = lockedItem()
    pending = { facts = facts, link = link, time = GetTime() }
  end
  pending.succeeded = true
  trace("cast succeeded on " .. tostring(pending.link))
end

local function cancel(_, _, spellID)
  if spellID ~= DISENCHANT then return end
  pending = nil
  trace("cast stopped")
end
handlers.UNIT_SPELLCAST_FAILED = cancel
handlers.UNIT_SPELLCAST_INTERRUPTED = cancel

function handlers.LOOT_READY()
  local cast = pending
  pending = nil
  if not cast or GetTime() - cast.time > MAX_WAIT then return end
  if not cast.facts then
    return trace("loot after a disenchant, but the item was not found in the bags")
  end
  local materials = received()
  if #materials == 0 then return trace("loot after a disenchant, but no materials in it") end

  local record = ns.Results.Record(cast.facts, materials, time and time() or nil)
  local log = ns.settings.log
  log[#log + 1] = record

  if ns.debug then
    local parts = {}
    for _, m in ipairs(materials) do parts[#parts + 1] = m.count .. "x " .. Game.MaterialName(m.item) end
    ns.Say(ns.L.SAY_RECORDED:format(tostring(cast.link), table.concat(parts, ", ")))
  end
end

local frame = CreateFrame("Frame")
for _, event in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED",
                         "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED" }) do
  frame:RegisterUnitEvent(event, "player")
end
frame:RegisterEvent("LOOT_READY")
frame:SetScript("OnEvent", function(_, event, ...)
  local ok, err = pcall(handlers[event], ...)
  if not ok then trace(event .. " failed: " .. tostring(err)) end
end)
