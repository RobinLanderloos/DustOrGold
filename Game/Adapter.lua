-- Reads the game: item facts, material prices, and whether this character
-- can disenchant. Everything the pure files need from the client goes
-- through here.
local addonName, ns = ...

local Game = {}
ns.Game = Game

local DISENCHANT_SPELL = 13262
local ENCHANTING_SKILL_LINE = 333

-- Defaults until the saved settings load; then the saved table replaces this.
ns.settings = ns.Settings.Normalize(nil)

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, _, name)
  if name ~= addonName then return end
  self:UnregisterEvent("ADDON_LOADED")
  DustOrGoldDB = ns.Settings.Normalize(DustOrGoldDB)
  ns.settings = DustOrGoldDB
  ns.debug = DustOrGoldDB.debugMode == true
end)

local function isSecret(value)
  return issecretvalue and issecretvalue(value) or false
end

-- Tooltip texts that mean the item can no longer be mailed.
local boundTexts
local function getTexts()
  if not boundTexts then
    boundTexts = {}
    for _, name in ipairs({
      "ITEM_SOULBOUND", "ITEM_BIND_ON_PICKUP", "ITEM_BIND_QUEST",
      "ITEM_ACCOUNTBOUND", "ITEM_BNETACCOUNTBOUND", "ITEM_BIND_TO_ACCOUNT", "ITEM_BIND_TO_BNETACCOUNT",
    }) do
      local text = _G[name]
      if type(text) == "string" then boundTexts[text] = true end
    end
  end
  return { bound = boundTexts, cannotDisenchant = ITEM_DISENCHANT_NOT_DISENCHANTABLE }
end

local function leftTexts(data)
  local lines = {}
  for _, line in ipairs(data and data.lines or {}) do
    local text = line.leftText
    if type(text) == "string" and not isSecret(text) then lines[#lines + 1] = text end
  end
  return lines
end

-- Item facts for an item, or nil while the game has no data for it yet.
-- item is a link or an item ID; data is the tooltip data for that item.
function Game.ItemFacts(item, data)
  local _, _, quality, baseLevel, requiredLevel, _, _, _, _, _, sellPrice, classID, subclassID =
    C_Item.GetItemInfo(item)
  if not quality then return nil end

  local itemLevel = C_Item.GetDetailedItemLevelInfo and C_Item.GetDetailedItemLevelInfo(item) or baseLevel
  local facts = ns.Facts.FromGame({
    isWeapon = classID == Enum.ItemClass.Weapon,
    isArmor = classID == Enum.ItemClass.Armor,
    isCosmetic = classID == Enum.ItemClass.Armor and subclassID == Enum.ItemArmorSubclass.Cosmetic,
    quality = quality,
    itemLevel = itemLevel,
    sellPrice = sellPrice,
  }, leftTexts(data), getTexts())
  facts.requiredLevel = requiredLevel
  facts.itemID = C_Item.GetItemInfoInstant(item)
  facts.isKept = facts.itemID ~= nil and ns.KeepList.Contains(ns.settings.keep, facts.itemID)
  return facts
end

local function auctionator()
  local api = Auctionator and Auctionator.API and Auctionator.API.v1
  return api and api.GetAuctionPriceByItemID and api or nil
end

function Game.HasPriceSource()
  return auctionator() ~= nil
end

-- Copper for one of an item, or nil.
function Game.GetPrice(itemID)
  local api = auctionator()
  if not api then return nil end
  local ok, price = pcall(api.GetAuctionPriceByItemID, addonName, itemID)
  return ok and price or nil
end

-- The item's own auction price and its age in days, or nil. By link first,
-- so items with random suffixes ("of the Eagle") get their own price.
function Game.ItemAuctionPrice(item)
  local api = auctionator()
  if not api then return nil end
  local price, age
  if type(item) == "string" and api.GetAuctionPriceByItemLink then
    local ok, value = pcall(api.GetAuctionPriceByItemLink, addonName, item)
    price = ok and value or nil
    if api.GetAuctionAgeByItemLink then
      local okAge, days = pcall(api.GetAuctionAgeByItemLink, addonName, item)
      age = okAge and days or nil
    end
  end
  if not price then
    local itemID = type(item) == "number" and item or C_Item.GetItemInfoInstant(item)
    if itemID then
      price = Game.GetPrice(itemID)
      if price and api.GetAuctionAgeByItemID then
        local okAge, days = pcall(api.GetAuctionAgeByItemID, addonName, itemID)
        age = okAge and days or nil
      end
    end
  end
  if type(price) ~= "number" or price <= 0 then return nil end
  return price, type(age) == "number" and age or nil
end

-- Days since the oldest price among a band's drops was seen, or nil.
function Game.OldestPriceAge(band)
  local api = auctionator()
  if not (api and api.GetAuctionAgeByItemID) then return nil end
  local oldest
  for _, d in ipairs(band.drops) do
    local ok, age = pcall(api.GetAuctionAgeByItemID, addonName, d.item)
    if ok and type(age) == "number" and (not oldest or age > oldest) then oldest = age end
  end
  return oldest
end

-- Which signals say this character can disenchant. Forever reportedly keeps
-- Disenchant out of the spellbook, so the profession counts too; which one
-- works is checked in-game (docs/issues/010).
function Game.DisenchantSignals()
  local signals = {}
  if C_SpellBook and C_SpellBook.IsSpellKnown then
    local ok, known = pcall(C_SpellBook.IsSpellKnown, DISENCHANT_SPELL)
    signals.spellbook = ok and known == true
  end
  if IsPlayerSpell then
    local ok, known = pcall(IsPlayerSpell, DISENCHANT_SPELL)
    signals.playerSpell = ok and known == true
  end
  if GetProfessions and GetProfessionInfo then
    signals.profession = false
    -- The first profession slot can be empty, so no ipairs here.
    local slots = { GetProfessions() }
    for i = 1, select("#", GetProfessions()) do
      local index = slots[i]
      if index then
        local ok, _, _, _, _, _, _, skillLine = pcall(GetProfessionInfo, index)
        if ok and skillLine == ENCHANTING_SKILL_LINE then signals.profession = true end
      end
    end
  end
  return signals
end

function Game.CanDisenchant()
  for _, known in pairs(Game.DisenchantSignals()) do
    if known then return true end
  end
  return false
end

function Game.Context()
  return {
    getPrice = Game.GetPrice,
    margin = ns.settings.margin,
    hasEnchanterAlt = ns.settings.hasEnchanterAlt,
    canDisenchant = Game.CanDisenchant(),
  }
end

-- Evaluates an item. Returns the result (nil for no verdict), the facts, and
-- the reason when there is no verdict.
function Game.Evaluate(item, data)
  local facts = Game.ItemFacts(item, data)
  if not facts then return nil, nil end
  local result, reason = ns.Valuation.Evaluate(facts, Game.Context())
  return result, facts, reason
end

-- The reason for no verdict, as text.
function Game.ReasonText(reason, facts)
  local text = ns.L.REASON[reason] or tostring(reason)
  if reason == "outsideTable" then text = text:format(tostring(facts and facts.itemLevel)) end
  return text
end

-- Every bag item with its evaluation, for the bag report.
function Game.BagEntries()
  local entries = {}
  local context = Game.Context()
  for bag = Enum.BagIndex.Backpack, Enum.BagIndex.ReagentBag do
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and info.hyperlink then
        local facts = Game.ItemFacts(info.hyperlink, C_TooltipInfo.GetBagItem(bag, slot))
        if facts then
          facts.isBound = facts.isBound or info.isBound == true
          local result, reason = ns.Valuation.Evaluate(facts, context)
          entries[#entries + 1] = {
            link = info.hyperlink, icon = info.iconFileID, bag = bag, slot = slot,
            facts = facts, result = result, reason = reason,
            auction = result and ns.Valuation.CompareAuction(Game.ItemAuctionPrice(info.hyperlink), result),
          }
        end
      end
    end
  end
  return entries
end

function Game.Money(copper)
  return C_CurrencyInfo.GetCoinTextureString(copper)
end

-- The game's name for a material, with the English name until it is cached.
function Game.MaterialName(itemID)
  return C_Item.GetItemNameByID(itemID) or ns.MaterialNames[itemID] or ("item:" .. itemID)
end
