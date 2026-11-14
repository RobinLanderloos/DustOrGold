-- Turning what the game reports about an item into plain item facts.
local ns, test, eq = ...
local Facts = ns.Facts

local texts = {
  bound = { ["Soulbound"] = true, ["Binds when picked up"] = true },
  cannotDisenchant = "Cannot be disenchanted",
}

local function info(overrides)
  local t = { isArmor = true, quality = 2, itemLevel = 28, sellPrice = 1000 }
  for k, v in pairs(overrides or {}) do t[k] = v end
  return t
end

test("armor and weapons get their kind", function()
  eq(Facts.FromGame(info(), {}, texts).kind, "armor")
  eq(Facts.FromGame(info({ isArmor = false, isWeapon = true }), {}, texts).kind, "weapon")
end)

test("other items and cosmetic armor have no kind", function()
  eq(Facts.FromGame(info({ isArmor = false }), {}, texts).kind, nil)
  eq(Facts.FromGame(info({ isCosmetic = true }), {}, texts).kind, nil)
end)

test("quality, item level and sell price carry over", function()
  local facts = Facts.FromGame(info({ quality = 3, itemLevel = 44, sellPrice = 2500 }), {}, texts)
  eq(facts.quality, 3)
  eq(facts.itemLevel, 44)
  eq(facts.vendorValue, 2500)
end)

test("an item without a sell price has a Vendor Value of zero", function()
  eq(Facts.FromGame(info({ sellPrice = false }), {}, texts).vendorValue, 0)
end)

test("a soulbound or bind-on-pickup line makes the item bound", function()
  eq(Facts.FromGame(info(), { "Sturdy Belt", "Soulbound", "Waist" }, texts).isBound, true)
  eq(Facts.FromGame(info(), { "Sturdy Belt", "Binds when picked up" }, texts).isBound, true)
  eq(Facts.FromGame(info(), { "Sturdy Belt", "Binds when equipped" }, texts).isBound, false)
end)

test("the game's 'cannot be disenchanted' line is picked up", function()
  eq(Facts.FromGame(info(), { "Sturdy Belt", "Cannot be disenchanted" }, texts).cannotDisenchant, true)
  eq(Facts.FromGame(info(), { "Sturdy Belt" }, texts).cannotDisenchant, false)
end)

test("facts from the game produce a verdict end to end", function()
  local facts = Facts.FromGame(info(), { "Sturdy Belt", "Soulbound" }, texts)
  local M = ns.Materials
  local result = ns.Valuation.Evaluate(facts, {
    getPrice = function(id)
      return ({ [M.SOUL_DUST] = 1000, [M.GREATER_ASTRAL] = 3000, [M.LARGE_GLIMMERING] = 20000 })[id]
    end,
    canDisenchant = true,
  })
  eq(result.verdict, ns.Valuation.DISENCHANT)
end)
