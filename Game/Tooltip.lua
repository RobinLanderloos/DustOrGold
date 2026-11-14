-- The verdict line on item tooltips, and the material breakdown while Shift
-- is held.
local _, ns = ...

local Game, Display, L = ns.Game, ns.Display, ns.L

local function onItemTooltip(tooltip, data)
  if not data or not data.id then return end
  if issecretvalue and (issecretvalue(data.id) or issecretvalue(data.hyperlink)) then return end

  local item = type(data.hyperlink) == "string" and data.hyperlink or data.id
  local result = Game.Evaluate(item, data)
  if not result then return end

  -- Plain text for money: the money frame errors in instance combat once tainted.
  local text, color = Display.VerdictLine(result, L, Game.Money, Game.OldestPriceAge(result.band))
  tooltip:AddLine(text, color[1], color[2], color[3])

  -- The item's own auction price, as information next to the verdict.
  local price, age = Game.ItemAuctionPrice(item)
  local auction = ns.Valuation.CompareAuction(price, result)
  if auction then
    local auctionText, auctionColor = Display.AuctionLine(auction, L, Game.Money, age)
    tooltip:AddLine(auctionText, auctionColor[1], auctionColor[2], auctionColor[3])
  end

  if IsShiftKeyDown() then
    for _, line in ipairs(Display.BreakdownLines(result.band, L, Game.MaterialName)) do
      tooltip:AddLine(line, 0.8, 0.8, 0.8)
    end
  end
end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
  -- A failure here must never break someone's tooltip.
  local ok, err = pcall(onItemTooltip, tooltip, data)
  if not ok and ns.debug then print("|cffff6060DustOrGold:|r " .. tostring(err)) end
end)
