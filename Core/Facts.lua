-- Plain item facts from what the game reports about an item.
--
-- Pure (docs/adr/0006): the game layer reads the values, this turns them
-- into the item facts Valuation.Evaluate takes.
local _, ns = ...

local Facts = {}
ns.Facts = Facts

-- info:  { isWeapon, isArmor, isCosmetic, quality, itemLevel, sellPrice }
-- lines: the left-hand texts of the item's tooltip
-- texts: { bound = { [text] = true }, cannotDisenchant = text }
function Facts.FromGame(info, lines, texts)
  local kind
  if info.isWeapon then
    kind = "weapon"
  elseif info.isArmor and not info.isCosmetic then
    kind = "armor"
  end

  local isBound, cannotDisenchant = false, false
  for _, text in ipairs(lines) do
    if texts.bound[text] then isBound = true end
    if text == texts.cannotDisenchant then cannotDisenchant = true end
  end

  return {
    kind = kind,
    quality = info.quality,
    itemLevel = info.itemLevel,
    vendorValue = info.sellPrice or 0,
    isBound = isBound,
    cannotDisenchant = cannotDisenchant,
  }
end
