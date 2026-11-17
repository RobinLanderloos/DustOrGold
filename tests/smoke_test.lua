-- Load check: runs every file the manifest lists, in order, against a small
-- stand-in for the game, then shows a tooltip. It catches a missing file, a
-- syntax error or a nil call before logging in. It does not prove the real
-- client behaves like the stand-in (docs/issues/010 does that).
--   luajit tests/smoke_test.lua
local files = {}
for line in io.lines("DustOrGold.toc") do
  line = line:gsub("%s+$", "")
  if line ~= "" and not line:match("^#") then files[#files + 1] = (line:gsub("\\", "/")) end
end

local SOUL_DUST, GREATER_ASTRAL, LARGE_GLIMMERING = 11083, 11082, 11084
local items = {
  -- name, link, quality, item level, required level, _, _, _, _, _, sell price, class, subclass
  ["belt"]  = { "Sturdy Belt", "belt", 2, 28, 23, nil, nil, nil, nil, nil, 1000, 4, 2 },
  ["bread"] = { "Bread", "bread", 1, 5, 1, nil, nil, nil, nil, nil, 25, 0, 5 },
}

local postCall
local shift = false
local enchanter = true
local prices = { [SOUL_DUST] = 1000, [GREATER_ASTRAL] = 3000, [LARGE_GLIMMERING] = 20000 }
local itemPrices = {} -- the items' own auction prices, by link

_G.Enum = {
  ItemClass = { Weapon = 2, Armor = 4 },
  ItemArmorSubclass = { Cosmetic = 5 },
  TooltipDataType = { Item = 0 },
}
_G.ITEM_SOULBOUND = "Soulbound"
_G.ITEM_BIND_ON_PICKUP = "Binds when picked up"
_G.ITEM_DISENCHANT_NOT_DISENCHANTABLE = "Cannot be disenchanted"
-- A widget that accepts any call: it remembers scripts, events, text and
-- whether it is shown, and hands out more widgets for Create* calls.
local widgets = {}
local function newWidget(parent)
  local w = { shown = true, scripts = {}, events = {}, parentWidget = parent }
  widgets[#widgets + 1] = w
  return setmetatable(w, { __index = function(self, key)
    if key == "Text" or key == "TitleText" then
      local child = newWidget(); rawset(self, key, child); return child
    end
    if key == "SetScript" then return function(s, name, fn) s.scripts[name] = fn end end
    if key == "RegisterEvent" or key == "RegisterUnitEvent" then return function(s, name) s.events[name] = true end end
    if key == "SetAttribute" then
      return function(s, name, v) rawset(s, "attrs", rawget(s, "attrs") or {}); s.attrs[name] = v end
    end
    if key == "UnregisterEvent" then return function(s, name) s.events[name] = nil end end
    if key == "SetText" then return function(s, text) s.text = text end end
    if key == "GetText" then return function(s) return s.text end end
    if key == "SetChecked" then return function(s, v) s.checked = v end end
    if key == "GetChecked" then return function(s) return s.checked end end
    if key == "IsShown" then return function(s) return s.shown end end
    if key == "Show" then return function(s) s.shown = true; if s.scripts.OnShow then s.scripts.OnShow(s) end end end
    if key == "Hide" then return function(s) s.shown = false end end
    if key == "SetShown" then return function(s, v) if v then s:Show() else s:Hide() end end end
    if key == "GetID" then return function() return 1 end end
    if key == "SetSize" then return function(s, w, h) rawset(s, "width", w); rawset(s, "height", h) end end
    if key == "SetWidth" then return function(s, w) rawset(s, "width", w) end end
    if key == "GetWidth" then return function(s) return rawget(s, "width") or 0 end end
    if key == "GetHeight" then return function(s) return rawget(s, "height") or 0 end end
    if key == "SetPoint" then
      return function(s, ...) if not rawget(s, "point") then rawset(s, "point", { ... }) end end
    end
    if key == "ClearAllPoints" then return function(s) rawset(s, "point", nil) end end
    if key == "GetPoint" then
      return function(s)
        local p = rawget(s, "point") or {}
        if type(p[2]) == "table" then return p[1], p[2], p[3], p[4], p[5] end
        return p[1], nil, p[1], p[2] or 0, p[3] or 0
      end
    end
    if type(key) == "string" and key:match("^Create") then return function(s) return newWidget(s) end end
    -- Like a real frame: unknown methods do nothing, unset fields are nil.
    if type(key) == "string" and key:match("^%u") then return function() end end
    return nil
  end })
end
local function fire(event, ...)
  for _, w in ipairs(widgets) do
    if w.events[event] and w.scripts.OnEvent then w.scripts.OnEvent(w, event, ...) end
  end
end
-- Shown only when it and every parent are shown, as in the game.
local function visible(w)
  while w do
    if not rawget(w, "shown") then return false end
    w = rawget(w, "parentWidget")
  end
  return true
end
local function shownTexts()
  local texts = {}
  for _, w in ipairs(widgets) do
    local text = rawget(w, "text")
    if visible(w) and type(text) == "string" then texts[#texts + 1] = text end
  end
  return table.concat(texts, "\n")
end

_G.CreateFrame = function(_, name, parent)
  local w = newWidget(parent)
  rawset(w, "name", name)
  return w
end
-- Timers wait until the test runs them, as the game would on later frames.
local timers = {}
_G.C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
local function runTimers()
  local guard = 0
  while #timers > 0 and guard < 100000 do
    table.remove(timers, 1)()
    guard = guard + 1
  end
end
_G.date = function() return "2026-11-14 12:00" end

-- The auction house: commodity listings per item, and a full scan.
local ahListings = {}  -- [itemID] = { { unitPrice, quantity } }
local searches = {}
local replicate = {}   -- { { link, itemID, count, buyout, hasAllInfo } }
local replicateRequests = 0
_G.Enum.AuctionHouseSortOrder = { Price = 0 }
_G.C_AuctionHouse = {
  IsThrottledMessageSystemReady = function() return true end,
  MakeItemKey = function(itemID) return { itemID = itemID } end,
  SendSearchQuery = function(itemKey)
    searches[#searches + 1] = itemKey.itemID
    fire("COMMODITY_SEARCH_RESULTS_UPDATED", itemKey.itemID)
  end,
  GetNumCommoditySearchResults = function(itemID) return #(ahListings[itemID] or {}) end,
  GetCommoditySearchResultInfo = function(itemID, i) return ahListings[itemID][i] end,
  GetNumItemSearchResults = function() return 0 end,
  ReplicateItems = function() replicateRequests = replicateRequests + 1 end,
  GetNumReplicateItems = function() return #replicate end,
  GetReplicateItemInfo = function(i)
    local r = replicate[i + 1]
    local t = {}
    t[3], t[10], t[17], t[18] = r.count, r.buyout, r.itemID, r.hasAllInfo
    return unpack(t, 1, 18)
  end,
  GetReplicateItemLink = function(i) return replicate[i + 1].link end,
}

_G.Minimap = newWidget()
Minimap:SetSize(140, 140)
rawset(Minimap, "GetCenter", function() return 500, 500 end)
rawset(Minimap, "GetEffectiveScale", function() return 1 end)
local cursorX, cursorY = 500, 600
_G.GetCursorPosition = function() return cursorX, cursorY end
_G.UIParent = newWidget()
_G.GameTooltip = newWidget()
_G.UISpecialFrames = {}
_G.tinsert = table.insert
_G.GetBuildInfo = function() return "1.60.1", "70938", "Nov 1 2026", 16001 end
_G.Settings = {
  RegisterCanvasLayoutCategory = function() return newWidget() end,
  RegisterAddOnCategory = function() end,
  OpenToCategory = function() end,
}
_G.Enum.BagIndex = { Backpack = 0, ReagentBag = 5 }
local beltLocked, beltBound = false, true
local beltGone = false -- the belt has left the bags (disenchanted)
_G.C_Container = {
  GetContainerNumSlots = function(bag) return bag == 0 and 2 or 0 end,
  GetContainerItemInfo = function(_, slot)
    if slot == 1 then
      if beltGone then return nil end
      return { hyperlink = "belt", isBound = beltBound, isLocked = beltLocked }
    end
    return { hyperlink = "bread" }
  end,
}
local inCombat = false
_G.InCombatLockdown = function() return inCombat end
_G.C_Spell = { GetSpellTexture = function() return 136244 end }
local now = 100
_G.GetTime = function() return now end
_G.time = function() return 1763100000 end
local loot = {}
bagCounts = {} -- materials in the bags, by item ID
_G.GetNumLootItems = function() return #loot end
_G.GetLootSlotLink = function(i) return loot[i] and ("|cffffffff|Hitem:" .. loot[i][1] .. "::::|h[x]|h|r") end
_G.GetLootSlotInfo = function(i) return 133, "x", loot[i] and loot[i][2] end
_G.DustOrGoldDB = { margin = 0.5 }

_G.C_Item = {
  GetItemInfoInstant = function(item) return ({ belt = 1001, bread = 1002 })[item] end,
  GetItemInfo = function(item)
    return unpack(items[item] or items[({ [1001] = "belt", [1002] = "bread" })[item]] or {}, 1, 13)
  end,
  GetDetailedItemLevelInfo = function(item) return items[item] and items[item][4] end,
  GetItemNameByID = function() return nil end,
  GetItemCount = function(id) return bagCounts[id] or 0 end,
}
_G.C_CurrencyInfo = { GetCoinTextureString = function(copper) return copper .. "c" end }
_G.C_SpellBook = { IsSpellKnown = function() return false end }
_G.GetProfessions = function() return nil, 2 end
_G.GetProfessionInfo = function() return "Enchanting", nil, 1, 75, 0, 0, enchanter and 333 or 164 end
_G.C_TooltipInfo = {
  GetHyperlink = function() return { lines = {} } end,
  GetBagItem = function() return { lines = {} } end,
}
_G.TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) postCall = fn end }
_G.IsShiftKeyDown = function() return shift end
_G.SlashCmdList = {}
_G.Auctionator = { API = { v1 = {
  GetAuctionPriceByItemID = function(caller, id) assert(caller == "DustOrGold"); return prices[id] end,
  GetAuctionAgeByItemID = function(_, id) return id == SOUL_DUST and 4 or 0 end,
  GetAuctionPriceByItemLink = function(caller, link) assert(caller == "DustOrGold"); return itemPrices[link] end,
  GetAuctionAgeByItemLink = function() return 0 end,
} } }

local ns = {}
for _, file in ipairs(files) do
  local chunk, err = loadfile(file)
  if not chunk then error("manifest lists a file that does not load: " .. tostring(err)) end
  chunk("DustOrGold", ns)
end
assert(postCall, "no tooltip hook was registered")

local said = {}
local realPrint = print
_G.print = function(text) said[#said + 1] = tostring(text) end
fire("ADDON_LOADED", "SomeOtherAddon")
fire("ADDON_LOADED", "DustOrGold")
fire("PLAYER_LOGIN")
local storedMargin = DustOrGoldDB.margin
DustOrGoldDB.margin = 0.20

local function show(item, lines, owner)
  local shown = {}
  local data = { id = 1, hyperlink = item, lines = {} }
  for _, text in ipairs(lines or {}) do data.lines[#data.lines + 1] = { leftText = text } end
  postCall({
    AddLine = function(_, text) shown[#shown + 1] = text end,
    GetOwner = function() return owner end,
  }, data)
  return shown
end

local failed = 0
local function check(name, condition, detail)
  if not condition then
    failed = failed + 1
    realPrint("FAIL  " .. name .. (detail and ("\n      " .. detail) or ""))
  end
end
local function slash(message)
  said = {}
  local ok, err = pcall(SlashCmdList.DUSTORGOLD, message)
  return ok, ok and table.concat(said, "\n") or tostring(err)
end

check("saved settings are loaded and completed", storedMargin == 0.5 and DustOrGoldDB.hasEnchanterAlt == true
  and type(DustOrGoldDB.keep) == "table")
check("the settings panel builds without complaint", not table.concat(said, "\n"):find("could not be built"),
  table.concat(said, "\n"))

-- Settings and the keep list through the slash command
local ok, out = slash("margin 35")
check("/dog margin sets the margin", ok and DustOrGoldDB.margin == 0.35 and out:find("35%%") ~= nil, out)
ok, out = slash("margin lots")
check("/dog margin refuses nonsense", ok and DustOrGoldDB.margin == 0.35, out)
slash("margin 20")
ok, out = slash("keep item:1001")
check("/dog keep puts the item on the keep list", ok and DustOrGoldDB.keep[1001] == true, out)
check("a kept item shows no line", #show("belt") == 0)
ok, out = slash("keeps")
check("/dog keeps lists it", ok and out:find("belt", 1, true) ~= nil, out)
ok, out = slash("unkeep item:1001")
check("/dog unkeep gives the verdict back", ok and #show("belt") == 1, out)
ok, out = slash("alt off")
check("/dog alt off is saved", ok and DustOrGoldDB.hasEnchanterAlt == false, out)
slash("alt on")
ok, out = slash("help")
check("/dog help lists the commands", ok and out:find("/dog keep", 1, true) ~= nil, out)

-- The list window
ok, out = slash("")
check("/dog opens the list window", ok and not out:find("could not"), out)
local texts = shownTexts()
check("the list groups the belt under disenchant with a total",
  texts:find("Disenchant these (1): about 2873c", 1, true) ~= nil, texts)
check("the list shows the row's values", texts:find("vendor 1000c  /  disenchant ~2873c", 1, true) ~= nil, texts)
check("the bread is not listed", texts:find("bread", 1, true) == nil, texts)
slash("keep item:1001")
fire("BAG_UPDATE_DELAYED")
check("a kept item leaves the list", shownTexts():find("Nothing in your bags has a verdict.", 1, true) ~= nil, shownTexts())
slash("unkeep item:1001")
slash("")
check("/dog closes the list window again", not shownTexts():find("Disenchant these", 1, true), shownTexts())

-- The disenchant button (docs/issues/007)
slash("")
local function find(predicate)
  for _, w in ipairs(widgets) do if predicate(w) then return w end end
end
local beltRow = find(function(w) return rawget(w, "bag") == 0 and rawget(w, "slot") == 1 and w.scripts.OnEnter end)
check("the belt has a row the mouse can enter", beltRow ~= nil)
check("the belt's row is marked as clickable", beltRow and beltRow.canCast == true)
if beltRow then beltRow.scripts.OnEnter(beltRow) end
local cast = find(function(w) local a = rawget(w, "attrs"); return a and a.spell == 13262 end)
check("hovering the row puts the Disenchant button over it",
  cast and cast.shown and cast.attrs.type == "spell" and cast.attrs["target-bag"] == 0 and cast.attrs["target-slot"] == 1)
fire("PLAYER_REGEN_DISABLED")
check("the button is hidden when combat starts", cast and not cast.shown)
inCombat = true
if beltRow then beltRow.scripts.OnEnter(beltRow) end
check("the button is not shown during combat", cast and not cast.shown)
inCombat = false

enchanter = false
fire("BAG_UPDATE_DELAYED")
check("a non-enchanter gets no clickable rows",
  find(function(w) return visible(w) and rawget(w, "canCast") == true end) == nil)
enchanter = true
fire("BAG_UPDATE_DELAYED")

-- The results log (docs/issues/008)
DustOrGoldDB.log = {}
beltLocked = true
fire("UNIT_SPELLCAST_START", "player", "cast-1", 13262)
now = now + 3
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 13262)
beltLocked = false
loot = { { 10940, 2 }, { 11083, 1 } }
said = {}
fire("LOOT_READY")
local log = DustOrGoldDB.log
local afterLoot = table.concat(said, "\n")
check("the line after a disenchant says what had no price", afterLoot:find("no price for Strange Dust", 1, true) ~= nil, afterLoot)
check("the record keeps the expected value", log[1] and log[1].expected == 2873 and log[1].actual == nil,
  log[1] and tostring(log[1].expected))
check("a disenchant is recorded once", #log == 1, "records: " .. #log)
check("the record names the item and its levels",
  log[1] and log[1].itemID == 1001 and log[1].itemLevel == 28 and log[1].requiredLevel == 23 and log[1].kind == "armor")
check("the record holds the materials received",
  log[1] and log[1].materials[10940] == 2 and log[1].materials[11083] == 1)
fire("LOOT_READY")
check("later loot is not added to it", #log == 1)

fire("UNIT_SPELLCAST_START", "player", "cast-2", 8690) -- another spell
fire("LOOT_READY")
check("loot after another spell is not recorded", #log == 1)

beltLocked = true
fire("UNIT_SPELLCAST_START", "player", "cast-3", 13262)
fire("UNIT_SPELLCAST_INTERRUPTED", "player", "cast-3", 13262)
beltLocked = false
fire("LOOT_READY")
check("an interrupted disenchant is not recorded", #log == 1)

beltLocked = true
fire("UNIT_SPELLCAST_START", "player", "cast-4", 13262)
beltLocked = false
now = now + 60
fire("LOOT_READY")
check("loot long after the cast is not recorded", #log == 1)

-- A priced disenchant: its worth against the expected value
beltLocked = true
fire("UNIT_SPELLCAST_START", "player", "cast-5", 13262)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-5", 13262)
beltLocked = false
loot = { { 11083, 2 } }
said = {}
fire("LOOT_READY")
afterLoot = table.concat(said, "\n")
check("the line after a disenchant shows its worth and the expected value",
  afterLoot:find("2x Soul Dust, worth", 1, true) ~= nil and afterLoot:find("expected", 1, true) ~= nil, afterLoot)
check("the record keeps both values", log[2] and log[2].actual == 1900 and log[2].expected == 2873,
  log[2] and (tostring(log[2].actual) .. " / " .. tostring(log[2].expected)))
ok, out = slash("results")
check("/dog results ends with the running total", out:find("1 priced disenchants", 1, true) ~= nil, out)
ok, out = slash("results off")
check("/dog results off turns the line off", DustOrGoldDB.showResults == false, out)
beltLocked = true
fire("UNIT_SPELLCAST_START", "player", "cast-6", 13262)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-6", 13262)
beltLocked = false
said = {}
fire("LOOT_READY")
check("with the line off nothing is said, but it is still recorded", #log == 3 and not table.concat(said, "\n"):find("worth", 1, true),
  table.concat(said, "\n"))
slash("results on")

-- No loot window: the materials go straight into the bags
beltLocked = true
fire("UNIT_SPELLCAST_START", "player", "cast-7", 13262)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-7", 13262)
beltLocked = false
loot = {}
fire("LOOT_READY")
check("an empty loot window does not end the capture", #log == 3)
bagCounts[11083] = 2
said = {}
fire("BAG_UPDATE_DELAYED")
afterLoot = table.concat(said, "\n")
check("materials that arrive in the bags are recorded", #log == 4 and log[4].materials[11083] == 2,
  "records: " .. #log)
check("and get the line after the disenchant", afterLoot:find("2x Soul Dust, worth", 1, true) ~= nil, afterLoot)
fire("BAG_UPDATE_DELAYED")
check("a later bag change is not recorded again", #log == 4)
local traced = table.concat(DustOrGoldDB.trace or {}, "\n")
check("each step is traced in the saved variables", traced:find("recorded via bags", 1, true) ~= nil, traced)

-- This client does not lock the item: it is the one that leaves the bags
loot = { { 11083, 1 } }
fire("UNIT_SPELLCAST_START", "player", "cast-8", 13262)
beltGone = true
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-8", 13262)
fire("LOOT_READY")
check("an unlocked item is found by leaving the bags", #log == 5 and log[5].itemID == 1001, "records: " .. #log)
beltGone = false

-- Still shown in the bags when the loot window opens: found at the next bag update
fire("UNIT_SPELLCAST_START", "player", "cast-9", 13262)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-9", 13262)
fire("LOOT_READY")
check("an item still in the bags at loot time waits", #log == 5)
beltGone = true
fire("BAG_UPDATE_DELAYED")
check("and is recorded once it leaves the bags", #log == 6 and log[6].itemID == 1001, "records: " .. #log)
beltGone = false

-- Cast through DustOrGold's own button: its slot is known straight away
ns.castTarget = { bag = 0, slot = 1, time = now }
fire("UNIT_SPELLCAST_START", "player", "cast-10", 13262)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-10", 13262)
fire("LOOT_READY")
check("an item cast on through the Disenchant button is known without a bag change",
  #log == 7 and log[7].itemID == 1001, "records: " .. #log)
traced = table.concat(DustOrGoldDB.trace or {}, "\n")
check("the trace says how the item was found", traced:find("from the Disenchant button", 1, true) ~= nil
  and traced:find("left bag slot 0:1", 1, true) ~= nil, traced)

-- The window's size
local window = find(function(w) return rawget(w, "name") == "DustOrGoldListFrame" end)
check("the window opens at the larger default size", window and window:GetWidth() == 640 and window:GetHeight() == 600)
local grip = find(function(w) return w.scripts.OnMouseDown and rawget(w, "parentWidget") == window end)
check("the window has a resize grip", grip ~= nil)
if window and grip then
  rawset(window, "GetLeft", function() return 300 end)
  rawset(window, "GetTop", function() return 800 end)
  grip.scripts.OnMouseDown(grip)
  local p = rawget(window, "point")
  check("grabbing the grip pins the window's top-left corner where it is",
    p and p[1] == "TOPLEFT" and p[3] == "BOTTOMLEFT" and p[4] == 300 and p[5] == 800,
    p and table.concat({ tostring(p[1]), tostring(p[3]), tostring(p[4]), tostring(p[5]) }, " "))
  window:SetSize(900, 720)
  if window.scripts.OnSizeChanged then window.scripts.OnSizeChanged(window, 900, 720) end
  grip.scripts.OnMouseUp(grip)
end
check("the new size is saved", DustOrGoldDB.window and DustOrGoldDB.window.width == 900 and DustOrGoldDB.window.height == 720)
local content = beltRow and rawget(beltRow, "parentWidget")
check("the rows follow the window's width", content and content:GetWidth() == 900 - 34,
  content and tostring(content:GetWidth()))

-- Debug mode lists everything, with the button only where the game will refuse
ok, out = slash("debug")
check("debug mode is switched on and saved", ok and DustOrGoldDB.debugMode == true, out)
texts = shownTexts()
check("debug mode lists the items without a verdict", texts:find("Debug: no verdict (1)", 1, true) ~= nil, texts)
local breadRow = find(function(w) return visible(w) and rawget(w, "slot") == 2 end)
check("an item the game cannot disenchant gets the button in debug mode", breadRow and breadRow.canCast == true)
check("a row without a verdict says why", texts:find("no verdict: not an uncommon to epic weapon or armor", 1, true) ~= nil, texts)
slash("keep item:1001")
local keptRow = find(function(w) return visible(w) and rawget(w, "slot") == 1 end)
check("a kept green is listed in debug mode but never gets the button",
  keptRow and keptRow.canCast == false and shownTexts():find("Debug: no verdict (2)", 1, true) ~= nil, shownTexts())
slash("unkeep item:1001")
ok, out = slash("debug off")
check("debug mode is switched off and saved", ok and DustOrGoldDB.debugMode == false, out)
check("without debug mode the extra group is gone", not shownTexts():find("Debug: no verdict", 1, true))

-- The setting that puts the button on every disenchantable item
prices[11082] = nil -- no price for Greater Astral Essence: the belt goes to "no price data"
fire("BAG_UPDATE_DELAYED")
local noPriceRow = find(function(w) return visible(w) and rawget(w, "slot") == 1 end)
check("an item without auction data is listed under no price data",
  shownTexts():find("No price data (1)", 1, true) ~= nil and noPriceRow and noPriceRow.canCast == false, shownTexts())
ok, out = slash("button on")
check("/dog button on is saved", ok and DustOrGoldDB.buttonOnAll == true, out)
check("with the setting on, the no-price item gets the button", noPriceRow and noPriceRow.canCast == true)
slash("button off")
check("with the setting off, it does not", noPriceRow and noPriceRow.canCast == false)
prices[11082] = 3000
fire("BAG_UPDATE_DELAYED")

-- The minimap button
local minimapButton = find(function(w) return rawget(w, "name") == "DustOrGoldMinimapButton" end)
check("the minimap button is on the minimap", minimapButton and rawget(minimapButton, "parentWidget") == Minimap
  and visible(minimapButton))
if minimapButton then
  local windowShown = window:IsShown()
  minimapButton.scripts.OnClick(minimapButton, "LeftButton")
  check("left-click toggles the list", window:IsShown() ~= windowShown)
  minimapButton.scripts.OnClick(minimapButton, "LeftButton")
  local opened = false
  local realOpen = ns.OpenOptions
  ns.OpenOptions = function() opened = true end
  minimapButton.scripts.OnClick(minimapButton, "RightButton")
  ns.OpenOptions = realOpen
  check("right-click opens the settings", opened)
  minimapButton.scripts.OnDragStart(minimapButton)
  local onUpdate = minimapButton.scripts.OnUpdate
  if onUpdate then onUpdate(minimapButton) end
  minimapButton.scripts.OnDragStop(minimapButton)
  check("dragging moves it and saves the angle", math.floor(DustOrGoldDB.minimap.angle + 0.5) == 90,
    tostring(DustOrGoldDB.minimap.angle))
end
ok, out = slash("minimap off")
check("/dog minimap off hides it", ok and DustOrGoldDB.minimap.hide == true and minimapButton and not visible(minimapButton), out)
slash("minimap on")
check("/dog minimap on brings it back", minimapButton and visible(minimapButton))

-- The item's own auction price
itemPrices.belt = 5000 -- 4750 after the cut: more than vendor (1000) and disenchant (2873)
fire("BAG_UPDATE_DELAYED")
check("a soulbound item is never put in the auction group",
  not shownTexts():find("Auction these", 1, true) and not shownTexts():find("auction ~", 1, true), shownTexts())
check("a soulbound item's tooltip has no auction line", #show("belt", { "Soulbound" }) == 1)
beltBound = false
shown = show("belt")
check("the tooltip shows the item's auction price after the cut",
  shown[2] == "Auction: 4750c after the cut, better than vendor and disenchant", table.concat(shown, " | "))
fire("BAG_UPDATE_DELAYED")
check("the list shows it next to the row's values",
  shownTexts():find("disenchant ~2873c|cff", 1, true) ~= nil and shownTexts():find("auction ~4750c", 1, true) ~= nil,
  shownTexts())
check("the list moves it to its own auction group with a total",
  shownTexts():find("Auction these (1): about 4750c after the cut", 1, true) ~= nil
    and not shownTexts():find("Disenchant these", 1, true), shownTexts())
local auctionRow = find(function(w) return visible(w) and rawget(w, "slot") == 1 end)
check("an item in the auction group gets no Disenchant button", auctionRow and auctionRow.canCast == false)
check("the tooltip's verdict line itself does not change", shown[1] == "Disenchant: 2873c  (vendor 1000c)  [price 4 days old]", shown[1])
itemPrices.belt = 1020 -- 969 after the cut: less than the vendor
check("an auction price below the vendor says so",
  show("belt")[2] == "Auction: 969c after the cut, less than vendor")
itemPrices.belt = nil
check("without an auction price there is no auction line", #show("belt") == 1)
beltBound = true
fire("BAG_UPDATE_DELAYED")

-- Our own auction prices (docs/adr/0007)
ok, out = slash("scan")
check("/dog scan away from the auction house says to open it", ok and out:find("open the auction house first", 1, true) ~= nil, out)

ahListings[GREATER_ASTRAL] = { { unitPrice = 2000, quantity = 3 }, { unitPrice = 2500, quantity = 30 } }
ahListings[SOUL_DUST] = { { unitPrice = 500, quantity = 50 } }
said = {}
fire("AUCTION_HOUSE_SHOW")
runTimers()
check("opening the auction house searches every material", #searches == 24, "searches: " .. #searches)
check("it says how many materials it found", table.concat(said, "\n"):find("material prices updated (2 found", 1, true) ~= nil,
  table.concat(said, "\n"))
-- Greater Astral: 3 x 2000 + 7 x 2500 = 23500 / 10
check("a material's own price is its batch price", DustOrGoldDB.prices["i:11082"] and DustOrGoldDB.prices["i:11082"].p == 2350)
-- Own prices win: Soul Dust 500 (was 1000 from Auctionator), Greater Astral 2350 (was 3000),
-- Large Glimmering still 20000 from Auctionator.
-- 0.75 x 1.5 x 500 + 0.20 x 1.5 x 2350 + 0.05 x 20000 = 562.5 + 705 + 1000 = 2267.5, minus 5%
shown = show("belt")
check("the verdict uses our own prices first, Auctionator's for the rest",
  shown[1] and shown[1]:find("Disenchant: 2154c", 1, true) ~= nil, table.concat(shown, " | "))

-- A full scan, whoever asked for it
replicate = {
  { link = "|cff1eff00|Hitem:727::::::::13:1490:::1:12759|h[Shortsword]|h|r", itemID = 727, count = 1, buyout = 9000, hasAllInfo = true },
  { link = "|cff1eff00|Hitem:727::::::::13:1490:::1:12759|h[Shortsword]|h|r", itemID = 727, count = 1, buyout = 7000, hasAllInfo = true },
  { link = nil, itemID = 10940, count = 20, buyout = 1600, hasAllInfo = false },
  { link = nil, itemID = 4000, count = 1, buyout = 100, hasAllInfo = false }, -- gear without data: skipped
}
-- Enough plain listings that reading takes several frames.
for i = 1, 1000 do
  replicate[#replicate + 1] = { link = nil, itemID = 5000 + i, count = 1, buyout = 100, hasAllInfo = false }
end
local scanButton = find(function(w) return w.scripts.OnClick and (rawget(w, "text") == "Scan auction house") end)
check("the window has a scan button", scanButton ~= nil)
said = {}
fire("REPLICATE_ITEM_LIST_UPDATE")
check("the scan is read on later frames, not inside the event", #timers > 0 and not table.concat(said, "\n"):find("full scan read", 1, true))
table.remove(timers, 1)()
local midText = scanButton and rawget(scanButton, "text") or ""
check("the scan button shows the reading percentage", midText:match("^Reading scan %d+%%$") ~= nil, midText)
check("one frame reads only part of the scan", midText ~= "Reading scan 100%", midText)
fire("REPLICATE_ITEM_LIST_UPDATE") -- the same scan announced again
runTimers()
local saidText = table.concat(said, "\n")
check("chat shows the reading progress in quarters", saidText:find("reading the full scan: 50%", 1, true) ~= nil, saidText)
check("a scan announced twice is read once", select(2, saidText:gsub("full scan read:", "")) == 1, saidText)
check("the scan button is back to its label when done", scanButton and rawget(scanButton, "text") == "Scan auction house")
check("a full scan records gear by exact item", DustOrGoldDB.prices["i:727:b12759"] and DustOrGoldDB.prices["i:727:b12759"].p == 7000)
check("a full scan records materials even without item data", DustOrGoldDB.prices["i:10940"] and DustOrGoldDB.prices["i:10940"].p == 80)
check("a full scan skips gear it cannot key", DustOrGoldDB.prices["i:4000"] == nil)
check("it says how many prices it recorded", table.concat(said, "\n"):find("full scan read: 2 prices", 1, true) ~= nil,
  table.concat(said, "\n"))

ok, out = slash("scan")
runTimers()
check("/dog scan right after a full scan waits for the 15 minutes", replicateRequests == 0 and out:find("15 minutes", 1, true) ~= nil, out)
DustOrGoldDB.lastFullScan = 0
slash("scan")
runTimers()
check("/dog scan asks for a full scan when allowed", replicateRequests == 1)
fire("AUCTION_HOUSE_CLOSED")
ok, out = slash("autoscan off")
check("/dog autoscan off is saved", ok and DustOrGoldDB.autoScan == false, out)
searches = {}
fire("AUCTION_HOUSE_SHOW")
runTimers()
check("with autoscan off, opening the auction house searches nothing", #searches == 0)
fire("AUCTION_HOUSE_CLOSED")
slash("autoscan on")
-- Back to Auctionator's prices for the checks below
DustOrGoldDB.prices = {}

-- Material data: in the tooltip from the list, and in the materials view
shown = show("belt", nil, { isDustOrGoldRow = true })
check("hovering an item in the list shows the materials without Shift",
  #shown == 4 and shown[2] == "  75% Soul Dust x1-2  (1000c each, Auctionator, 4 days old)", table.concat(shown, " | "))
check("elsewhere the materials still need Shift", #show("belt", nil, { isDustOrGoldRow = false }) == 1)
local viewButton = find(function(w) return rawget(w, "text") == "Materials" and w.scripts.OnClick end)
check("the window has a Materials button", viewButton ~= nil)
if viewButton then viewButton.scripts.OnClick(viewButton) end
texts = shownTexts()
check("the materials view shows how many prices are known", texts:find("Material prices (3 of 24 known)", 1, true) ~= nil, texts)
check("it lists each material with its price note",
  texts:find("Soul Dust", 1, true) ~= nil and texts:find("1000c each, Auctionator, 4 days old", 1, true) ~= nil
    and texts:find("Nexus Crystal", 1, true) ~= nil and texts:find("no price", 1, true) ~= nil, texts)
check("the bag groups are hidden in the materials view", not texts:find("Disenchant these", 1, true), texts)
check("the button now leads back to the bag items", viewButton and rawget(viewButton, "text") == "Bag items")
local dustRow = find(function(w) return visible(w) and rawget(w, "itemID") == 10940 end)
check("a material's row shows its item tooltip on hover", dustRow ~= nil and dustRow.canCast == false)
if dustRow then dustRow.scripts.OnEnter(dustRow) end
if viewButton then viewButton.scripts.OnClick(viewButton) end
check("clicking again goes back to the bag items", shownTexts():find("Disenchant these", 1, true) ~= nil, shownTexts())

-- The comparison (docs/issues/009)
ok, out = slash("results")
check("/dog results summarises the band", ok and out:find("uncommon armor, item level 26-30: 7 disenchants", 1, true) ~= nil, out)
check("/dog results calls out a material the table does not list",
  out:find("not in the table: Strange Dust x1", 1, true) ~= nil, out)
check("the results report is kept in the saved settings",
  type(DustOrGoldDB.report) == "table" and table.concat(DustOrGoldDB.report, "\n"):find("26-30", 1, true) ~= nil)

local shown = show("belt")
check("an enchanter sees one verdict line", #shown == 1, table.concat(shown, " | "))
check("the line carries the verdict, both values and the price age",
  shown[1] == "Disenchant: 2873c  (vendor 1000c)  [price 4 days old]", shown[1])

shift = true
shown = show("belt")
check("Shift adds the breakdown with prices", #shown == 4
  and shown[2] == "  75% Soul Dust x1-2  (1000c each, Auctionator, 4 days old)", table.concat(shown, " | "))
shift = false

check("an item that cannot be disenchanted shows nothing", #show("bread") == 0)
check("the game's 'cannot be disenchanted' line shows nothing", #show("belt", { "Cannot be disenchanted" }) == 0)
check("an item the game has no data for shows nothing", #show("unknown") == 0)

enchanter = false
check("a non-enchanter sees no line on a soulbound item", #show("belt", { "Soulbound" }) == 0)
check("a non-enchanter sees a line on an item that can be mailed", #show("belt") == 1)
enchanter = true

prices[GREATER_ASTRAL] = nil
check("a missing price reads 'no price data'", show("belt")[1] == "Disenchant: no price data")

_G.Auctionator = nil
shown = show("belt")
check("without Auctionator there is no error and no verdict is claimed", shown[1] == "Disenchant: no price data", shown[1])

ok, out = slash("debug belt")
check("the debug command runs", ok, out)
check("the debug command reports the item", out:find("item level 28, required level 23", 1, true) ~= nil, out)
check("the debug report is kept in the saved settings",
  type(DustOrGoldDB.report) == "table" and table.concat(DustOrGoldDB.report, "\n"):find("item level 28", 1, true) ~= nil)
_G.print = realPrint

io.write(failed == 0 and "load check passed\n" or (failed .. " load checks failed\n"))
os.exit(failed == 0 and 0 or 1)
