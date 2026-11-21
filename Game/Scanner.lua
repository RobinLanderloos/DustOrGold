-- Our own auction prices (docs/adr/0007), only when Auctionator is not
-- installed; with Auctionator nothing here runs and its prices are used
-- (docs/adr/0008):
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
local FRAME_BUDGET_MS = 8          -- time spent reading a full scan per frame
local ROWS_WITHOUT_CLOCK = 200     -- rows per frame when there is no clock to check
local REREAD_GUARD = 60            -- seconds after a read in which the scan is not read again

local isOpen = false
local queue, current, token, found = nil, nil, 0, 0
local materialsTotal, materialsDone = 0, 0
local fullScanRequested = false
local reading = nil                -- { done, total } while a full scan is read
local lastRead = -math.huge
local lastSaidQuarter = 0

local function now() return time and time() or 0 end

-- Auctionator keeps the prices when it is there: no searches, no reading.
local function auctionatorKeepsPrices()
  return ns.Game and ns.Game.HasAuctionator and ns.Game.HasAuctionator() or false
end

local function materialSet()
  local set = {}
  for itemID in pairs(ns.MaterialNames) do set[itemID] = true end
  return set
end

local function refresh()
  if ns.ListWindow then ns.ListWindow.Refresh() end
end

function Scanner.Progress()
  return {
    materials = queue and { done = materialsDone, total = materialsTotal } or nil,
    waiting = fullScanRequested or nil,
    reading = reading,
  }
end

-- Only the scan button changes; the list is not redrawn for every step.
local function progressChanged()
  if ns.ListWindow and ns.ListWindow.ShowScanProgress then
    ns.ListWindow.ShowScanProgress(ns.Display.ScanProgress(Scanner.Progress(), L))
  end
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
  progressChanged()
  refresh()
end

local function materialDone()
  current = nil
  materialsDone = materialsDone + 1
  progressChanged()
end

function searchNext()
  if not queue then return end
  if not isOpen then queue, current = nil, nil; progressChanged(); return end
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
      materialDone()
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
  materialsTotal, materialsDone = #queue, 0
  progressChanged()
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
  materialDone()
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
  materialDone()
  C_Timer.After(0, searchNext)
end

-- Full scans ----------------------------------------------------------------

-- A full scan can hold tens of thousands of listings. They are read for a
-- few milliseconds per frame so the game keeps running, and each row is
-- folded into the result straight away so nothing big is left for the end.
local function readFullScan()
  local total = C_AuctionHouse.GetNumReplicateItems()
  local materials = materialSet()
  local scan = PriceBook.NewScan(materials)
  local keyOfLink = {} -- the same item is often listed many times
  local clock = debugprofilestop
  local index = 0
  reading, lastSaidQuarter = { done = 0, total = total }, 0
  progressChanged()

  local function readRow(i)
    local _, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, itemID, hasAllInfo =
      C_AuctionHouse.GetReplicateItemInfo(i)
    local key
    if hasAllInfo then
      local link = C_AuctionHouse.GetReplicateItemLink(i)
      if link then
        key = keyOfLink[link]
        if key == nil then
          key = PriceBook.Key(link) or false
          keyOfLink[link] = key
        end
      end
    end
    -- Without item data only materials can be keyed safely (they have no suffixes).
    if not key and itemID and materials[itemID] then key = PriceBook.Key(itemID) end
    if key then scan:Add({ key = key, itemID = itemID, count = count, buyout = buyout }) end
  end

  local function finish()
    local prices = scan:Prices()
    local count = 0
    for _ in pairs(prices) do count = count + 1 end
    PriceBook.Store(ns.settings.prices, prices, now())
    reading, lastRead = nil, now()
    ns.Say(L.SAY_FULL_SCAN_READ:format(count))
    progressChanged()
    refresh()
  end

  local function step()
    if clock then
      local stopAt = clock() + FRAME_BUDGET_MS
      while index < total and clock() < stopAt do
        readRow(index)
        index = index + 1
      end
    else
      local last = math.min(index + ROWS_WITHOUT_CLOCK, total)
      while index < last do readRow(index); index = index + 1 end
    end
    reading.done = index
    progressChanged()
    local quarter = total > 0 and math.floor(4 * index / total) or 4
    if quarter > lastSaidQuarter and quarter < 4 then
      lastSaidQuarter = quarter
      ns.Say(L.SAY_FULL_SCAN_PROGRESS:format(quarter * 25))
    end
    if index < total then
      C_Timer.After(0, step)
    else
      finish()
    end
  end
  C_Timer.After(0, step)
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
  progressChanged()
  C_Timer.After(FULL_SCAN_TIMEOUT, function()
    if fullScanRequested then
      fullScanRequested = false
      ns.Say(L.SAY_FULL_SCAN_NO_ANSWER)
      progressChanged()
    end
  end)
  ns.Say(L.SAY_FULL_SCAN_STARTED)
  return true
end

-- /dog scan: materials now, plus a full scan when the server allows one.
function Scanner.Scan()
  if auctionatorKeepsPrices() then
    ns.Say(L.SAY_AUCTIONATOR_SCANS)
    return
  end
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
  if ns.settings.autoScan and not auctionatorKeepsPrices() then Scanner.ScanMaterials() end
end

function handlers.AUCTION_HOUSE_CLOSED()
  isOpen = false
  queue, current = nil, nil
  progressChanged()
end

handlers.COMMODITY_SEARCH_RESULTS_UPDATED = onCommodityResults
handlers.ITEM_SEARCH_RESULTS_UPDATED = onItemResults

-- The event can come more than once for one scan (also when Auctionator
-- asked for it); reading the same scan twice would only cost time.
function handlers.REPLICATE_ITEM_LIST_UPDATE()
  if auctionatorKeepsPrices() then return end
  if reading or now() - lastRead < REREAD_GUARD then return end
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
