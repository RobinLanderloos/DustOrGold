-- Records every disenchant the player performs (docs/adr/0001): which item,
-- and what it gave. The item being disenchanted is the one locked in the bags
-- while the cast runs. What it gave is the loot window that follows, or, when
-- the materials go straight into the bags without one, the materials whose
-- counts went up after the cast.
--
-- Each step is also written to DustOrGoldDB.trace (the last 40 lines), so a
-- capture that fails in the live client can be read from the saved variables.
local _, ns = ...

local Game = ns.Game
local DISENCHANT = 13262
local MAX_WAIT = 15 -- seconds from the cast to the loot
local TRACE_LINES = 40
local pending

local function trace(text)
  local list = ns.settings and ns.settings.trace
  if type(list) == "table" then
    list[#list + 1] = (date and date("%H:%M:%S ") or "") .. text
    while #list > TRACE_LINES do table.remove(list, 1) end
  end
  if ns.debug then ns.Say("[log] " .. text) end
end

-- Disenchant by ID, or by name in case the client uses another ID for it.
local disenchantName
local function isDisenchant(spellID)
  if spellID == DISENCHANT then return true end
  if not spellID or not (C_Spell and C_Spell.GetSpellName) then return false end
  disenchantName = disenchantName or C_Spell.GetSpellName(DISENCHANT)
  return disenchantName ~= nil and C_Spell.GetSpellName(spellID) == disenchantName
end

local function itemCount(itemID)
  if C_Item and C_Item.GetItemCount then return C_Item.GetItemCount(itemID) or 0 end
  if GetItemCount then return GetItemCount(itemID) or 0 end
  return 0
end

-- How many of each material are in the bags now.
local function materialCounts()
  local counts = {}
  for _, item in ipairs(ns.MaterialOrder) do counts[item] = itemCount(item) end
  return counts
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

local function start(spellID, how)
  local facts, link = lockedItem()
  pending = { facts = facts, link = link, time = GetTime(), before = materialCounts() }
  trace(how .. " (spell " .. tostring(spellID) .. ") on " .. tostring(link or "no locked item found"))
end

-- Records the disenchant with what it gave, and says what it was worth.
local function finish(cast, materials, source)
  pending = nil
  if not cast.facts then
    return trace("materials via " .. source .. ", but the disenchanted item was not found in the bags")
  end
  local record = ns.Results.Record(cast.facts, materials, time and time() or nil)
  local facts = cast.facts
  local band = ns.Valuation.FindBand(facts.kind, facts.quality, facts.itemLevel)
  local worth = ns.Results.Worth(record.materials, band, Game.GetPrice)
  record.actual, record.expected = worth.actual, worth.expected
  local log = ns.settings.log
  log[#log + 1] = record
  trace(("recorded via %s: %d materials, worth %s, expected %s"):format(source, #materials,
    tostring(worth.actual), tostring(worth.expected)))

  if ns.settings.showResults then
    ns.Say(ns.Display.DisenchantResult(tostring(cast.link), record.materials, worth, ns.L,
      Game.MaterialName, Game.Money))
  end
end

local handlers = {}

function handlers.UNIT_SPELLCAST_START(_, _, spellID)
  if isDisenchant(spellID) then start(spellID, "cast started") end
end

function handlers.UNIT_SPELLCAST_SUCCEEDED(_, _, spellID)
  if not isDisenchant(spellID) then return end
  -- An instant cast has no start event, so look for the item now.
  if not (pending and pending.facts) then start(spellID, "cast succeeded without a start") end
  pending.succeeded = true
  trace("cast succeeded")
end

local function cancel(_, _, spellID)
  if not isDisenchant(spellID) then return end
  pending = nil
  trace("cast stopped")
end
handlers.UNIT_SPELLCAST_FAILED = cancel
handlers.UNIT_SPELLCAST_INTERRUPTED = cancel

local function fresh(cast)
  return cast and GetTime() - cast.time <= MAX_WAIT
end

function handlers.LOOT_READY()
  local cast = pending
  if not cast then return end
  if not fresh(cast) then pending = nil; return end
  local materials = received()
  trace("loot window: " .. GetNumLootItems() .. " slots, " .. #materials .. " materials")
  if #materials > 0 then finish(cast, materials, "loot window") end
end

-- No loot window: the materials land in the bags directly.
function handlers.BAG_UPDATE_DELAYED()
  local cast = pending
  if not (cast and cast.succeeded) then return end
  if not fresh(cast) then
    pending = nil
    return trace("no materials arrived within " .. MAX_WAIT .. " seconds")
  end
  local gained = ns.Results.Gained(cast.before, materialCounts())
  trace("bags changed: " .. #gained .. " materials gained")
  if #gained > 0 then finish(cast, gained, "bags") end
end

-- Temporary spy while the capture is being made to work in the live client:
-- every spell event of the player and every loot event, registered the plain
-- way (not per unit), with the spell's ID and name. Remove once verified.
local spy = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_START",
                         "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED", "LOOT_READY", "LOOT_OPENED" }) do
  spy:RegisterEvent(event)
end
spy:SetScript("OnEvent", function(_, event, unit, ...)
  local args = { ... }
  pcall(function()
    if event == "PLAYER_LOGIN" then
      return trace("spy: loaded, Disenchant is " .. tostring(C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(DISENCHANT)))
    end
    if event:find("^LOOT") then return trace("spy: " .. event .. " slots=" .. tostring(GetNumLootItems())) end
    if unit ~= "player" then return end
    -- SENT has (unit, target, castGUID, spellID); the others (unit, castGUID, spellID).
    local spellID = event == "UNIT_SPELLCAST_SENT" and args[3] or args[2]
    local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
    trace(("spy: %s %s %s"):format(event:gsub("UNIT_SPELLCAST_", ""), tostring(spellID), tostring(name)))
  end)
end)

local frame = CreateFrame("Frame")
for _, event in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED",
                         "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED" }) do
  frame:RegisterUnitEvent(event, "player")
end
frame:RegisterEvent("LOOT_READY")
frame:RegisterEvent("BAG_UPDATE_DELAYED")
frame:SetScript("OnEvent", function(_, event, ...)
  local ok, err = pcall(handlers[event], ...)
  if not ok then trace(event .. " failed: " .. tostring(err)) end
end)
