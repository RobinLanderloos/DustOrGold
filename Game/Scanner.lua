-- Our own auction prices (docs/adr/0007):
--  * when the auction house opens, search the disenchanting materials one by
--    one (no 15-minute limit) and price each by the cheapest batch;
--  * whenever a full scan arrives, whoever asked for it (Auctionator does
--    too), record every listing: batch prices for materials, the cheapest
--    listing of each exact item for gear;
--  * /dog scan does both on demand.
local _, ns = ...

local PriceBook, L = ns.PriceBook, ns.L

local Scanner = {}
ns.Scanner = Scanner

local SEARCH_TIMEOUT = 5          -- seconds to wait for one material's results
local FULL_SCAN_COOLDOWN = 15 * 60 -- the server allows one full scan per 15 minutes
local FULL_SCAN_TIMEOUT = 60
local BATCH = 500                  -- full scan rows read per frame

local isOpen = false
local queue, current, token, found = nil, nil, 0, 0
local fullScanRequested = false

local function now() return time and time() or 0 end

local function materialSet()
  local set = {}
  for itemID in pairs(ns.MaterialNames) do set[itemID] = true end
  return set
end

local function refresh()
  if ns.ListWindow then ns.ListWindow.Refresh() end
end

local function sorts()
  local order = Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price or 0
  return { { sortOrder = order, reverseSort = false } }
end

-- Material searches ---------------------------------------------------------

local searchNext

local function store(itemID, listings)
  local price = PriceBook.BatchPrice(listings, PriceBook.MATERIAL_BATCH)
  if price then
    PriceBook.Store(ns.settings.prices, { [PriceBook.Key(itemID)] = price }, now())
    found = found + 1
  end
end

local function finishSearches()
  queue, current = nil, nil
  ns.Say(L.SAY_MATERIALS_SCANNED:format(found))
  refresh()
end

function searchNext()
  if not queue then return end
  if not isOpen then queue, current = nil, nil; return end
  if #queue == 0 then return finishSearches() end
  if C_AuctionHouse.IsThrottledMessageSystemReady and not C_AuctionHouse.IsThrottledMessageSystemReady() then
    C_Timer.After(0.3, searchNext)
    return
  end

  current = table.remove(queue, 1)
  token = token + 1
  local myToken, itemID = token, current
  C_Timer.After(SEARCH_TIMEOUT, function()
    if token == myToken and current == itemID then -- no answer: move on
      current = nil
      searchNext()
    end
  end)
  C_AuctionHouse.SendSearchQuery(C_AuctionHouse.MakeItemKey(itemID), sorts(), false)
end

function Scanner.ScanMaterials()
  if not isOpen then return false end
  if queue then return true end -- already running
  queue, found = {}, 0
  for itemID in pairs(ns.MaterialNames) do queue[#queue + 1] = itemID end
  table.sort(queue)
  searchNext()
  return true
end

local function onCommodityResults(itemID)
  if not current or itemID ~= current then return end
  local listings = {}
  for i = 1, C_AuctionHouse.GetNumCommoditySearchResults(itemID) do
    local info = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, i)
    if info then listings[#listings + 1] = { unitPrice = info.unitPrice, quantity = info.quantity } end
  end
  store(itemID, listings)
  current = nil
  C_Timer.After(0, searchNext)
end

-- A material the auction house does not treat as a commodity answers here.
local function onItemResults(itemKey)
  if not current or type(itemKey) ~= "table" or itemKey.itemID ~= current then return end
  local listings = {}
  for i = 1, C_AuctionHouse.GetNumItemSearchResults(itemKey) do
    local info = C_AuctionHouse.GetItemSearchResultInfo(itemKey, i)
    if info and info.buyoutAmount and info.quantity and info.quantity > 0 then
      listings[#listings + 1] = { unitPrice = info.buyoutAmount / info.quantity, quantity = info.quantity }
    end
  end
  store(current, listings)
  current = nil
  C_Timer.After(0, searchNext)
end

-- Full scans ----------------------------------------------------------------

local function readFullScan()
  local total = C_AuctionHouse.GetNumReplicateItems()
  local materials = materialSet()
  local rows = {}
  local index = 0

  local function step()
    local last = math.min(index + BATCH, total) - 1
    for i = index, last do
      local info = { C_AuctionHouse.GetReplicateItemInfo(i) }
      local count, buyout, itemID, hasAllInfo = info[3], info[10], info[17], info[18]
      local key
      if hasAllInfo then key = PriceBook.Key(C_AuctionHouse.GetReplicateItemLink(i)) end
      -- Without item data only materials can be keyed safely (they have no suffixes).
      if not key and itemID and materials[itemID] then key = PriceBook.Key(itemID) end
      if key then rows[#rows + 1] = { key = key, itemID = itemID, count = count, buyout = buyout } end
    end
    index = last + 1
    if index < total then
      C_Timer.After(0, step)
      return
    end
    local prices = PriceBook.FromScan(rows, materials)
    local count = 0
    for _ in pairs(prices) do count = count + 1 end
    PriceBook.Store(ns.settings.prices, prices, now())
    ns.Say(L.SAY_FULL_SCAN_READ:format(count))
    refresh()
  end
  step()
end

function Scanner.RequestFullScan()
  local last = ns.settings.lastFullScan or 0
  local wait = FULL_SCAN_COOLDOWN - (now() - last)
  if wait > 0 then
    ns.Say(L.SAY_FULL_SCAN_WAIT:format(math.ceil(wait / 60)))
    return false
  end
  fullScanRequested = true
  C_AuctionHouse.ReplicateItems()
  C_Timer.After(FULL_SCAN_TIMEOUT, function()
    if fullScanRequested then
      fullScanRequested = false
      ns.Say(L.SAY_FULL_SCAN_NO_ANSWER)
    end
  end)
  ns.Say(L.SAY_FULL_SCAN_STARTED)
  return true
end

-- /dog scan: materials now, plus a full scan when the server allows one.
function Scanner.Scan()
  if not isOpen then
    ns.Say(L.SAY_OPEN_AH)
    return
  end
  Scanner.ScanMaterials()
  Scanner.RequestFullScan()
end

function Scanner.IsOpen() return isOpen end

-- Events ----------------------------------------------------------------------

local handlers = {}

function handlers.AUCTION_HOUSE_SHOW()
  isOpen = true
  if ns.settings.autoScan then Scanner.ScanMaterials() end
end

function handlers.AUCTION_HOUSE_CLOSED()
  isOpen = false
  queue, current = nil, nil
end

handlers.COMMODITY_SEARCH_RESULTS_UPDATED = onCommodityResults
handlers.ITEM_SEARCH_RESULTS_UPDATED = onItemResults

function handlers.REPLICATE_ITEM_LIST_UPDATE()
  fullScanRequested = false
  ns.settings.lastFullScan = now()
  readFullScan()
end

local frame = CreateFrame("Frame")
for event in pairs(handlers) do frame:RegisterEvent(event) end
frame:SetScript("OnEvent", function(_, event, ...)
  local ok, err = pcall(handlers[event], ...)
  if not ok and ns.debug then ns.Say("[scan] " .. event .. " failed: " .. tostring(err)) end
end)
