-- The list window: every bag item with a verdict, grouped, with totals.
-- Advice only: there is no sell button (docs/adr/0005).
local _, ns = ...

local Game, L, Display, V = ns.Game, ns.L, ns.Display, ns.Valuation

local ListWindow = {}
ns.ListWindow = ListWindow

local WIDTH, HEIGHT, ROW_HEIGHT, HEADER_GAP = 640, 600, 18, 10
local MIN_WIDTH, MIN_HEIGHT, MAX_WIDTH, MAX_HEIGHT = 380, 240, 1400, 1200
local SCROLL_INSET = 34 -- frame width minus the scroll child's width
local DISENCHANT = 13262
local frame, content, emptyText
local rows = {}
local showMaterials = false -- the window shows bag items, or the materials and their prices

-- One secure button casts Disenchant on the row under the mouse. It is only
-- placed, set and shown out of combat, and hidden before combat starts.
local castButton

local function hideCast()
  if castButton and not InCombatLockdown() then
    castButton:Hide()
    castButton:ClearAllPoints()
    castButton.row = nil
  end
end

local function buildCast()
  castButton = CreateFrame("Button", "DustOrGoldCastButton", UIParent, "SecureActionButtonTemplate")
  castButton.isDustOrGoldRow = true -- its tooltip shows the materials and prices
  castButton:RegisterForClicks("AnyUp", "AnyDown")
  castButton:SetAttribute("type", "spell")
  castButton:SetAttribute("spell", DISENCHANT)
  castButton:SetFrameStrata("TOOLTIP")
  local highlight = castButton:CreateTexture(nil, "HIGHLIGHT")
  highlight:SetAllPoints()
  highlight:SetColorTexture(1, 1, 1, 0.15)
  castButton:SetScript("OnEnter", function(self)
    if not self.row then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetBagItem(self.row.bag, self.row.slot)
    GameTooltip:AddLine(L.ROW_CLICK, 0.25, 1, 0.25)
    GameTooltip:Show()
  end)
  castButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
    hideCast()
  end)
  -- Tells the results log which item is being disenchanted (ResultsCapture).
  castButton:HookScript("PreClick", function(self)
    if self.row then ns.castTarget = { bag = self.row.bag, slot = self.row.slot, time = GetTime() } end
  end)
  castButton:Hide()
end

local function showCast(row)
  if InCombatLockdown() then return false end
  if not castButton then buildCast() end
  castButton:ClearAllPoints()
  castButton:SetAllPoints(row)
  castButton:SetAttribute("target-bag", row.bag)
  castButton:SetAttribute("target-slot", row.slot)
  castButton.row = row
  castButton:Show()
  return true
end

local function headerText(group)
  local count = #group.rows
  if group.verdict == ns.BagReport.OTHER then
    return L.GROUP_OTHER:format(count)
  elseif group.verdict == ns.BagReport.AUCTION then
    return L.GROUP_AUCTION:format(count, Game.Money(group.auctionTotal))
  elseif group.verdict == V.VENDOR then
    return L.GROUP_VENDOR:format(count, Game.Money(group.vendorTotal))
  elseif group.verdict == V.DISENCHANT then
    return L.GROUP_DISENCHANT:format(count, Game.Money(group.disenchantTotal))
  elseif group.verdict == V.CLOSE then
    return L.GROUP_CLOSE:format(count, Game.Money(group.vendorTotal), Game.Money(group.disenchantTotal))
  end
  return L.GROUP_NO_PRICE:format(count, Game.Money(group.vendorTotal))
end

local function rowText(entry)
  local result = entry.result
  if not result then return L.ROW_NO_VERDICT:format(Game.ReasonText(entry.reason, entry.facts)) end
  local text
  if result.disenchantValue then
    text = L.ROW_VALUES:format(Game.Money(result.vendorValue), Game.Money(result.disenchantValue))
  else
    text = L.ROW_VENDOR_ONLY:format(Game.Money(result.vendorValue))
  end
  local auction = entry.auction
  if auction then
    local part = L.ROW_AUCTION:format(Game.Money(auction.net))
    if auction.beatsAll then
      local c = Display.Colors.auction
      part = ("|cff%02x%02x%02x%s|r"):format(c[1] * 255, c[2] * 255, c[3] * 255, part)
    end
    text = text .. part
  end
  return text
end

-- A row is a button so it can show the item's tooltip.
local function getRow(index)
  local row = rows[index]
  if not row then
    row = CreateFrame("Button", nil, content)
    row.isDustOrGoldRow = true -- its tooltip shows the materials and prices
    row:SetHeight(ROW_HEIGHT)
    ns.Skin.Row(row)
    row.right = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.right:SetPoint("RIGHT", -4, 0)
    row.right:SetJustifyH("RIGHT")
    row.right:SetWordWrap(false)
    -- The item name gives way to the values when the window is narrow.
    row.left = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.left:SetPoint("LEFT", 4, 0)
    row.left:SetPoint("RIGHT", row.right, "LEFT", -8, 0)
    row.left:SetJustifyH("LEFT")
    row.left:SetWordWrap(false)
    row:SetScript("OnEnter", function(self)
      if self.itemID then -- a material in the materials view
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(self.itemID)
        GameTooltip:Show()
        return
      end
      if not self.bag then return end
      if self.canCast and showCast(self) then return end -- the cast button shows the tooltip
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetBagItem(self.bag, self.slot)
      GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    rows[index] = row
  end
  return row
end

local function place(row, y, height)
  row:ClearAllPoints()
  row:SetPoint("TOPLEFT", 0, -y)
  row:SetPoint("RIGHT", content, "RIGHT", 0, 0)
  row:SetHeight(height)
  row:Show()
end

-- The materials view: every material with its price, source and age.
local function drawMaterials()
  local list = Display.MaterialRows(L, Game.MaterialName, Game.PriceWithAge, Game.Money)
  local known = 0
  for _, m in ipairs(list) do if m.hasPrice then known = known + 1 end end

  local header = getRow(1)
  place(header, 0, ROW_HEIGHT + 2)
  header.bag, header.slot, header.itemID, header.canCast = nil, nil, nil, false
  header.left:SetFontObject("GameFontNormal")
  header.left:SetText(L.MATERIALS_TITLE:format(known, #list))
  header.left:SetTextColor(unpack(ns.Skin.accent))
  header.right:SetText("")

  local y = ROW_HEIGHT + 2
  for i, m in ipairs(list) do
    local row = getRow(i + 1)
    place(row, y, ROW_HEIGHT)
    row.bag, row.slot, row.itemID, row.canCast = nil, nil, m.item, false
    row.left:SetFontObject("GameFontHighlightSmall")
    row.left:SetText("  " .. m.name)
    local shade = m.hasPrice and 1 or 0.6
    row.left:SetTextColor(shade, shade, shade)
    row.right:SetText(m.note)
    y = y + ROW_HEIGHT
  end

  for i = #list + 2, #rows do rows[i]:Hide() end
  content:SetHeight(y)
  emptyText:Hide()
end

local function draw()
  hideCast() -- the slots may have changed under it
  if showMaterials then return drawMaterials() end
  -- Debug mode also lists items without a verdict, so the Disenchant button
  -- can be tried on items the game will refuse to disenchant.
  local groups = ns.BagReport.Build(Game.BagEntries(), { includeOthers = ns.debug })
  local canDisenchant = Game.CanDisenchant()
  local icon = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(DISENCHANT)
  local marker = icon and ("|T" .. icon .. ":14|t ") or "* "
  local index, y = 0, 0

  for _, group in ipairs(groups) do
    local color = Display.Colors[group.verdict] or Display.Colors.noprice
    index = index + 1
    local header = getRow(index)
    y = y + (index > 1 and HEADER_GAP or 0)
    place(header, y, ROW_HEIGHT + 2)
    header.bag, header.slot, header.itemID, header.canCast = nil, nil, nil, false
    header.left:SetFontObject("GameFontNormal")
    header.left:SetText(headerText(group))
    header.left:SetTextColor(color[1], color[2], color[3])
    header.right:SetText("")
    y = y + ROW_HEIGHT + 2

    for _, entry in ipairs(group.rows) do
      index = index + 1
      local row = getRow(index)
      place(row, y, ROW_HEIGHT)
      row.bag, row.slot, row.itemID = entry.bag, entry.slot, nil
      row.canCast = ns.BagReport.CanCast(group.verdict, entry.facts,
        { canDisenchant = canDisenchant, buttonOnAll = ns.settings.buttonOnAll })
      row.left:SetFontObject("GameFontHighlightSmall")
      row.left:SetTextColor(1, 1, 1)
      row.left:SetText((row.canCast and ("  " .. marker) or "  ") .. entry.link)
      row.right:SetText(rowText(entry))
      y = y + ROW_HEIGHT
    end
  end

  for i = index + 1, #rows do rows[i]:Hide() end
  content:SetHeight(math.max(y, 1))
  emptyText:SetShown(index == 0)
end

-- Size and position are kept in the saved settings.
local function saveLayout()
  local point, _, relativePoint, x, y = frame:GetPoint()
  ns.settings.window = {
    width = math.floor(frame:GetWidth() + 0.5), height = math.floor(frame:GetHeight() + 0.5),
    point = point, relativePoint = relativePoint, x = x, y = y,
  }
end

local function restoreLayout()
  local saved = ns.settings.window
  local width = saved and math.min(math.max(saved.width, MIN_WIDTH), MAX_WIDTH) or WIDTH
  local height = saved and math.min(math.max(saved.height, MIN_HEIGHT), MAX_HEIGHT) or HEIGHT
  frame:SetSize(width, height)
  frame:ClearAllPoints()
  if saved and saved.point and saved.x and saved.y then
    frame:SetPoint(saved.point, UIParent, saved.relativePoint or saved.point, saved.x, saved.y)
  else
    frame:SetPoint("CENTER")
  end
end

local function build()
  frame = ns.Skin.Create("Frame", "DustOrGoldListFrame", UIParent, ns.Skin.TEMPLATES.Window)
  ns.Skin.Window(frame)
  frame:SetFrameStrata("HIGH")
  frame:SetMovable(true)
  frame:SetResizable(true)
  if frame.SetResizeBounds then
    frame:SetResizeBounds(MIN_WIDTH, MIN_HEIGHT, MAX_WIDTH, MAX_HEIGHT)
  end
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    saveLayout()
  end)
  frame:SetClampedToScreen(true)
  restoreLayout()

  -- Drag the bottom-right corner to resize.
  local grip = CreateFrame("Button", nil, frame)
  ns.Skin.Grip(grip)
  grip:SetPoint("BOTTOMRIGHT", -3, 3)
  grip:SetScript("OnMouseDown", function()
    -- Anchored by its centre, the window would grow on both sides at once,
    -- twice as fast as the mouse. Pin the top-left corner where it is now.
    local left, top = frame:GetLeft(), frame:GetTop()
    if left and top then
      frame:ClearAllPoints()
      frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    end
    frame:StartSizing("BOTTOMRIGHT")
  end)
  grip:SetScript("OnMouseUp", function()
    frame:StopMovingOrSizing()
    saveLayout()
  end)
  if frame.TitleText then frame.TitleText:SetText(L.WINDOW_TITLE) end
  tinsert(UISpecialFrames, "DustOrGoldListFrame") -- Escape closes it

  local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 10, -32)
  scroll:SetPoint("BOTTOMRIGHT", -20, 42)
  ns.Skin.ScrollBar(scroll)
  local footer = ns.Skin.Divider(frame)
  footer:SetPoint("BOTTOMLEFT", 1, 36)
  footer:SetPoint("BOTTOMRIGHT", -1, 36)

  local scan = ns.Skin.Button(ns.Skin.Create("Button", nil, frame, ns.Skin.TEMPLATES.Button))
  scan:SetSize(150, 22)
  scan:SetPoint("BOTTOMLEFT", 12, 10)
  scan:SetText(L.SCAN_BUTTON)
  scan:SetScript("OnClick", function() if ns.Scanner then ns.Scanner.Scan() end end)
  frame.scanButton = scan
  -- With Auctionator installed its prices are used and there is nothing to scan.
  local ownScans = not ns.Game.HasAuctionator()
  scan:SetShown(ownScans)

  -- Switches between the bag items and the materials with their prices.
  local view = ns.Skin.Button(ns.Skin.Create("Button", nil, frame, ns.Skin.TEMPLATES.Button))
  view:SetSize(110, 22)
  if ownScans then
    view:SetPoint("LEFT", scan, "RIGHT", 6, 0)
  else
    view:SetPoint("BOTTOMLEFT", 12, 10)
  end
  view:SetText(L.MATERIALS_BUTTON)
  view:SetScript("OnClick", function(self)
    showMaterials = not showMaterials
    self:SetText(showMaterials and L.BAGS_BUTTON or L.MATERIALS_BUTTON)
    ListWindow.Refresh()
  end)
  frame.viewButton = view
  content = CreateFrame("Frame", nil, scroll)
  content:SetSize(frame:GetWidth() - SCROLL_INSET, 1)
  scroll:SetScrollChild(content)
  -- The rows follow the window's width.
  frame:SetScript("OnSizeChanged", function(self, width)
    content:SetWidth(math.max((width or self:GetWidth()) - SCROLL_INSET, 1))
  end)

  emptyText = frame:CreateFontString(nil, "ARTWORK", "GameFontDisable")
  emptyText:SetPoint("CENTER")
  emptyText:SetText(L.NOTHING_TO_SHOW)

  frame:SetScript("OnShow", function()
    if ns.Scanner then ListWindow.ShowScanProgress(ns.Display.ScanProgress(ns.Scanner.Progress(), L)) end
    ListWindow.Refresh()
  end)
  frame:SetScript("OnHide", hideCast)
  frame:RegisterEvent("BAG_UPDATE_DELAYED")
  frame:RegisterEvent("PLAYER_REGEN_DISABLED") -- fires just before combat lockdown
  frame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then hideCast() else ListWindow.Refresh() end
  end)
  frame:Hide()
end

function ListWindow.Refresh()
  if not (frame and frame:IsShown()) then return end
  local ok, err = pcall(draw)
  if not ok then ns.Say("the list could not be drawn: " .. tostring(err)) end
end

-- The scan button shows what a running scan is doing (text from
-- Display.ScanProgress), and its own label again when idle.
function ListWindow.ShowScanProgress(text)
  if not (frame and frame.scanButton) then return end
  frame.scanButton:SetText(text or L.SCAN_BUTTON)
  frame.scanButton:SetEnabled(text == nil)
end

function ListWindow.Toggle()
  if not frame then
    local ok, err = pcall(build)
    if not ok then
      frame = nil
      return ns.Say("the list window could not be built: " .. tostring(err))
    end
  end
  frame:SetShown(not frame:IsShown())
end
