-- Records every disenchant the player performs (docs/adr/0001): which item,
-- and what it gave, with what that was worth against the expected value.
--
-- Which item: this client does not lock the item while it is disenchanted
-- (seen in the live client), so the item is found, in order, as
--   1. the slot of DustOrGold's own Disenchant button, when cast through it;
--   2. a locked item, for clients that do lock it;
--   3. the weapon or armor that left the bags: the bags are noted when the
--      cast starts and compared when the materials arrive (again at the next
--      bag update if the item is still shown then).
-- What it gave: the loot window, or the materials that went up in the bags
-- when there is no loot window.
--
-- Each step is written to DustOrGoldDB.trace (the last 40 lines), so a
-- capture that fails in the live client can be read from the saved variables.
local _, ns = ...

local Game = ns.Game
local DISENCHANT = 13262
local MAX_WAIT = 15 -- seconds from the cast to the loot
local BUTTON_WAIT = 5 -- seconds a click on our Disenchant button stays valid
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

local function eachSlot(fn)
  for bag = Enum.BagIndex.Backpack, Enum.BagIndex.ReagentBag do
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and info.hyperlink then fn(bag, slot, info) end
    end
  end
end

-- Every bag slot's link, and separately the weapons and armor among them
-- (the only items that can be disenchanted). Links only: cheap enough to do
-- at every cast.
local function bagLinks()
  local all, gear = {}, {}
  eachSlot(function(bag, slot, info)
    local key = bag .. ":" .. slot
    all[key] = info.hyperlink
    local classID = select(6, C_Item.GetItemInfoInstant(info.hyperlink))
    if classID == nil or classID == Enum.ItemClass.Weapon or classID == Enum.ItemClass.Armor then
      gear[key] = info.hyperlink
    end
  end)
  return all, gear
end

-- Item facts from a link alone: the item may already be gone from the bags.
local function factsOf(link)
  local facts = link and Game.ItemFacts(link, C_TooltipInfo.GetHyperlink(link))
  if facts and facts.kind then return facts end
end

local function lockedItem()
  local found
  eachSlot(function(bag, slot, info)
    if not found and info.isLocked then
      local facts = Game.ItemFacts(info.hyperlink, C_TooltipInfo.GetBagItem(bag, slot))
      if facts and facts.kind then found = { facts = facts, link = info.hyperlink } end
    end
  end)
  return found
end

-- The slot DustOrGold's Disenchant button was last clicked on (ListWindow).
local function buttonItem(gear)
  local target = ns.castTarget
  if not target or GetTime() - target.time > BUTTON_WAIT then return nil end
  ns.castTarget = nil
  local link = gear[target.bag .. ":" .. target.slot]
  local facts = factsOf(link)
  if facts then return { facts = facts, link = link } end
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
  local _, gear = bagLinks()
  pending = { time = GetTime(), before = materialCounts(), gear = gear }
  local found, via = buttonItem(gear), "Disenchant button"
  if not found then found, via = lockedItem(), "locked item" end
  if found then
    pending.facts, pending.link = found.facts, found.link
    trace(("%s (spell %s): %s, from the %s"):format(how, tostring(spellID), tostring(found.link), via))
  else
    trace(("%s (spell %s): item not known yet, will look for the one that leaves the bags"):format(how, tostring(spellID)))
  end
end

-- Fills in the item from what left the bags. True when the item is known.
local function identify(cast)
  if cast.facts then return true end
  local now = bagLinks()
  local key = ns.Results.Vanished(cast.gear, now)
  if not key then return false end
  local link = cast.gear[key]
  local facts = factsOf(link)
  if not facts then
    trace("item " .. tostring(link) .. " left bag slot " .. key .. " but has no item facts")
    cast.gear[key] = nil
    return false
  end
  cast.facts, cast.link = facts, link
  trace("item found: " .. tostring(link) .. " left bag slot " .. key)
  return true
end

-- Records the disenchant with what it gave, and says what it was worth.
local function finish(cast)
  pending = nil
  local record = ns.Results.Record(cast.facts, cast.materials, time and time() or nil)
  local facts = cast.facts
  local band = ns.Valuation.FindBand(facts.kind, facts.quality, facts.itemLevel)
  local worth = ns.Results.Worth(record.materials, band, Game.GetPrice)
  record.actual, record.expected = worth.actual, worth.expected
  local log = ns.settings.log
  log[#log + 1] = record
  trace(("recorded via %s: %d materials, worth %s, expected %s"):format(cast.source, #cast.materials,
    tostring(worth.actual), tostring(worth.expected)))

  if ns.settings.showResults then
    ns.Say(ns.Display.DisenchantResult(tostring(cast.link), record.materials, worth, ns.L,
      Game.MaterialName, Game.Money))
  end
end

-- With the materials known, records as soon as the item is known too.
local function tryFinish(cast)
  if identify(cast) then return finish(cast) end
  if not cast.waitTold then
    cast.waitTold = true
    trace("materials known, item not found yet: looking again at the next bag update")
  end
end

local function fresh(cast)
  if cast and GetTime() - cast.time <= MAX_WAIT then return true end
  if cast then trace("gave up: nothing usable within " .. MAX_WAIT .. " seconds") end
  pending = nil
  return false
end

local handlers = {}

function handlers.UNIT_SPELLCAST_START(_, _, spellID)
  if isDisenchant(spellID) then start(spellID, "cast started") end
end

function handlers.UNIT_SPELLCAST_SUCCEEDED(_, _, spellID)
  if not isDisenchant(spellID) then return end
  -- An instant cast has no start event: note the bags now.
  if not pending then start(spellID, "cast succeeded without a start") end
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

function handlers.LOOT_READY()
  local cast = pending
  if not fresh(cast) or cast.materials then return end
  local materials = received()
  trace("loot window: " .. GetNumLootItems() .. " slots, " .. #materials .. " materials")
  if #materials > 0 then
    cast.materials, cast.source = materials, "loot window"
    tryFinish(cast)
  end
end

-- No loot window: the materials land in the bags directly. Also the second
-- look for the item when it was still shown as the loot arrived.
function handlers.BAG_UPDATE_DELAYED()
  local cast = pending
  if not (cast and cast.succeeded) or not fresh(cast) then return end
  if not cast.materials then
    local gained = ns.Results.Gained(cast.before, materialCounts())
    if #gained == 0 then return end
    trace("bags changed: " .. #gained .. " materials gained")
    cast.materials, cast.source = gained, "bags"
  end
  tryFinish(cast)
end

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
