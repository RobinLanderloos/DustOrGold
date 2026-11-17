-- Tests for the pure calculation files. Run from the project root:
--   luajit tests/run.lua
local ns = {}
for _, file in ipairs({ "Locales/enUS.lua", "Core/Table.lua", "Core/Valuation.lua", "Core/Facts.lua", "Core/Display.lua",
  "Core/Settings.lua", "Core/KeepList.lua", "Core/BagReport.lua", "Core/Results.lua", "Core/PriceBook.lua" }) do
  local chunk = loadfile(file)
  if chunk then chunk("DustOrGold", ns) end
end

local V, M = ns.Valuation, ns.Materials
local passed, failed = 0, 0

local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL  " .. name .. "\n      " .. tostring(err))
  end
end

local function eq(actual, expected, what)
  if actual ~= expected then
    error((what or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local function prices(t)
  return function(itemID) return t[itemID] end
end

-- A level 28 green armor piece: 75% Soul Dust x1-2, 20% Greater Astral x1-2,
-- 5% Large Glimmering Shard.
local soulPrices = { [M.SOUL_DUST] = 1000, [M.GREATER_ASTRAL] = 3000, [M.LARGE_GLIMMERING] = 20000 }
-- 0.75*1.5*1000 + 0.20*1.5*3000 + 0.05*1*20000 = 1125 + 900 + 1000 = 3025; minus 5% = 2873.75
local SOUL_VALUE = 2873

local function green(overrides)
  local item = { kind = "armor", quality = 2, itemLevel = 28, vendorValue = 1000 }
  for k, v in pairs(overrides or {}) do item[k] = v end
  return item
end

local function enchanter(overrides)
  local context = { getPrice = prices(soulPrices), canDisenchant = true, hasEnchanterAlt = true }
  for k, v in pairs(overrides or {}) do context[k] = v end
  return context
end

-- The table itself ----------------------------------------------------------

test("every band's chances add up to 1", function()
  for kind, byQuality in pairs(ns.DisenchantTable) do
    for quality, bands in pairs(byQuality) do
      for _, band in ipairs(bands) do
        local sum = 0
        for _, d in ipairs(band.drops) do sum = sum + d.chance end
        if math.abs(sum - 1) > 1e-9 then
          error(kind .. " q" .. quality .. " " .. band.min .. "-" .. band.max .. " sums to " .. sum)
        end
      end
    end
  end
end)

test("the display order lists every material once", function()
  local seen, count = {}, 0
  for _, itemID in ipairs(ns.MaterialOrder) do
    if seen[itemID] then error("listed twice: " .. itemID) end
    if not ns.MaterialNames[itemID] then error("not a material: " .. itemID) end
    seen[itemID] = true
    count = count + 1
  end
  for itemID in pairs(ns.MaterialNames) do
    if not seen[itemID] then error("missing from the order: " .. itemID) end
  end
  eq(count, 24)
end)

test("bands do not overlap and every drop is a known material", function()
  for kind, byQuality in pairs(ns.DisenchantTable) do
    for quality, bands in pairs(byQuality) do
      local previousMax = 0
      for _, band in ipairs(bands) do
        if band.min <= previousMax then error(kind .. " q" .. quality .. " overlaps at " .. band.min) end
        previousMax = band.max
        for _, d in ipairs(band.drops) do
          if not ns.MaterialNames[d.item] then error("unknown material " .. tostring(d.item)) end
          if d.min > d.max then error("min above max for " .. d.item) end
        end
      end
    end
  end
end)

test("armor leans to dust, weapons to essence", function()
  local armor = V.FindBand("armor", 2, 28).drops
  local weapon = V.FindBand("weapon", 2, 28).drops
  eq(armor[1].item, M.SOUL_DUST); eq(armor[1].chance, 0.75)
  eq(weapon[1].item, M.SOUL_DUST); eq(weapon[1].chance, 0.20)
  eq(weapon[2].item, M.GREATER_ASTRAL); eq(weapon[2].chance, 0.75)
end)

test("band edges", function()
  eq(V.FindBand("armor", 2, 4), nil, "below the first band")
  eq(V.FindBand("armor", 2, 5).min, 5)
  eq(V.FindBand("armor", 2, 15).max, 15)
  eq(V.FindBand("armor", 2, 16).min, 16)
  eq(V.FindBand("armor", 3, 10), nil, "rare below 11")
  eq(V.FindBand("armor", 4, 39), nil, "epic below 40")
  eq(V.FindBand("armor", 2, 101), nil, "above the table")
end)

test("level 60 gear above item level 65 still has a band", function()
  -- Vanilla has nothing beyond Illusion Dust, Eternal essences, Brilliant
  -- shards and Nexus Crystals, so the top bands run on.
  eq(V.FindBand("armor", 2, 70).drops[1].item, M.ILLUSION_DUST)
  eq(V.FindBand("weapon", 3, 72).drops[1].item, M.LARGE_BRILLIANT)
  eq(V.FindBand("armor", 4, 88).drops[1].item, M.NEXUS_CRYSTAL)
end)

test("no band for other kinds and qualities", function()
  eq(V.FindBand(nil, 2, 28), nil)
  eq(V.FindBand("armor", 1, 28), nil)
  eq(V.FindBand("armor", 5, 60), nil)
  eq(V.FindBand("armor", 2, nil), nil)
end)

-- Material prices -----------------------------------------------------------

test("lesser essence uses a third of the greater when that is lower", function()
  eq(V.MaterialPrice(M.LESSER_ASTRAL, prices({ [M.LESSER_ASTRAL] = 500, [M.GREATER_ASTRAL] = 900 })), 300)
end)

test("lesser essence keeps its own price when that is lower", function()
  eq(V.MaterialPrice(M.LESSER_ASTRAL, prices({ [M.LESSER_ASTRAL] = 200, [M.GREATER_ASTRAL] = 900 })), 200)
end)

test("lesser essence without its own price falls back to the greater", function()
  eq(V.MaterialPrice(M.LESSER_ASTRAL, prices({ [M.GREATER_ASTRAL] = 900 })), 300)
end)

test("greater essence and dust are not converted", function()
  eq(V.MaterialPrice(M.GREATER_ASTRAL, prices({ [M.LESSER_ASTRAL] = 1, [M.GREATER_ASTRAL] = 900 })), 900)
  eq(V.MaterialPrice(M.SOUL_DUST, prices({})), nil)
end)

-- Disenchant Value ----------------------------------------------------------

test("expected value after the auction cut", function()
  local value, missing = V.DisenchantValue(V.FindBand("armor", 2, 28), prices(soulPrices))
  eq(value, SOUL_VALUE)
  eq(#missing, 0)
end)

test("a missing price for a common drop gives no value", function()
  local value, missing = V.DisenchantValue(V.FindBand("armor", 2, 28),
    prices({ [M.SOUL_DUST] = 1000, [M.LARGE_GLIMMERING] = 20000 }))
  eq(value, nil)
  eq(#missing, 1)
  eq(missing[1], M.GREATER_ASTRAL)
end)

test("a missing price for a 0.5% drop does not block the value", function()
  local value = V.DisenchantValue(V.FindBand("armor", 3, 58), prices({ [M.LARGE_BRILLIANT] = 10000 }))
  eq(value, math.floor(0.995 * 10000 * 0.95))
end)

test("quantity ranges are averaged", function()
  local value = V.DisenchantValue(V.FindBand("weapon", 4, 42), prices({ [M.SMALL_RADIANT] = 1000 }))
  eq(value, 2850) -- 3 shards on average, minus 5%
end)

-- Verdicts ------------------------------------------------------------------

test("disenchant wins clearly", function()
  local r = V.Evaluate(green({ vendorValue = 1000 }), enchanter())
  eq(r.verdict, V.DISENCHANT)
  eq(r.disenchantValue, SOUL_VALUE)
  eq(r.vendorValue, 1000)
end)

test("vendor wins clearly", function()
  eq(V.Evaluate(green({ vendorValue = 5000 }), enchanter()).verdict, V.VENDOR)
end)

test("within the margin is a close call, on both sides", function()
  eq(V.Evaluate(green({ vendorValue = 2600 }), enchanter()).verdict, V.CLOSE) -- disenchant 10% higher
  eq(V.Evaluate(green({ vendorValue = 3200 }), enchanter()).verdict, V.CLOSE) -- disenchant 10% lower
end)

test("the margin is adjustable", function()
  eq(V.Evaluate(green({ vendorValue = 2600 }), enchanter({ margin = 0 })).verdict, V.DISENCHANT)
  eq(V.Evaluate(green({ vendorValue = 3200 }), enchanter({ margin = 0 })).verdict, V.VENDOR)
end)

test("an item vendors will not buy is a disenchant", function()
  eq(V.Evaluate(green({ vendorValue = 0 }), enchanter()).verdict, V.DISENCHANT)
  local r = V.Evaluate({ kind = "armor", quality = 2, itemLevel = 28 }, enchanter())
  eq(r.verdict, V.DISENCHANT)
  eq(r.vendorValue, 0)
end)

test("missing prices give 'no price', never 'vendor'", function()
  local r = V.Evaluate(green(), enchanter({ getPrice = prices({}) }))
  eq(r.verdict, V.NO_PRICE)
  eq(r.disenchantValue, nil)
  eq(#r.missing, 3)
end)

test("items that cannot be disenchanted get no verdict", function()
  eq(V.Evaluate(green({ quality = 1 }), enchanter()), nil)
  eq(V.Evaluate(green({ kind = false }), enchanter()), nil)
  eq(V.Evaluate(green({ cannotDisenchant = true }), enchanter()), nil)
  eq(V.Evaluate(green({ itemLevel = 3 }), enchanter()), nil)
end)

test("only uncommon to epic weapons and armor could ever be disenchanted", function()
  eq(V.CouldBeDisenchanted({ kind = "armor", quality = 2 }), true)
  eq(V.CouldBeDisenchanted({ kind = "weapon", quality = 4 }), true)
  eq(V.CouldBeDisenchanted({ kind = "weapon", quality = 3, itemLevel = 99 }), true, "even outside the table")
  eq(V.CouldBeDisenchanted({ kind = "armor", quality = 1 }), false)
  eq(V.CouldBeDisenchanted({ kind = "armor", quality = 0 }), false)
  eq(V.CouldBeDisenchanted({ kind = "armor", quality = 5 }), false)
  eq(V.CouldBeDisenchanted({ kind = nil, quality = 3 }), false)
  eq(V.CouldBeDisenchanted(nil), false)
end)

test("kept items get no verdict", function()
  eq(V.Evaluate(green({ isKept = true }), enchanter()), nil)
end)

test("no verdict comes with the reason", function()
  local function why(item, context) return select(2, V.Evaluate(item, context or enchanter())) end
  eq(why(green({ isKept = true })), "kept")
  eq(why(green({ cannotDisenchant = true })), "cannotDisenchant")
  eq(why(green({ quality = 1 })), "notDisenchantable")
  eq(why(green({ kind = false })), "notDisenchantable")
  eq(why(green({ itemLevel = 3 })), "outsideTable")
  eq(why(green({ isBound = true }), enchanter({ canDisenchant = false })), "bound")
  eq(why(green(), enchanter({ canDisenchant = false, hasEnchanterAlt = false })), "noEnchanter")
  eq(why(green()), nil, "an item with a verdict has no reason")
end)

-- The item's own auction price (information next to the verdict, docs/adr/0003)

test("the item's auction price is compared after the auction cut", function()
  local cmp = V.CompareAuction(10000, { vendorValue = 5000, disenchantValue = 8000 })
  eq(cmp.price, 10000)
  eq(cmp.net, 9500)
  eq(cmp.beatsVendor, true)
  eq(cmp.beatsAll, true)
end)

test("an auction price can beat the vendor but not the disenchant", function()
  local cmp = V.CompareAuction(6000, { vendorValue = 5000, disenchantValue = 8000 })
  eq(cmp.beatsVendor, true)
  eq(cmp.beatsAll, false)
end)

test("the cut can make an auction price lose to the vendor", function()
  local cmp = V.CompareAuction(5200, { vendorValue = 5000 })
  eq(cmp.net, 4940)
  eq(cmp.beatsVendor, false)
  eq(cmp.beatsAll, false)
end)

test("without a disenchant value, it can only be said to beat the vendor", function()
  local cmp = V.CompareAuction(9000, { vendorValue = 5000 })
  eq(cmp.beatsVendor, true)
  eq(cmp.beatsAll, false)
end)

test("no auction price means no comparison", function()
  eq(V.CompareAuction(nil, { vendorValue = 5000 }), nil)
  eq(V.CompareAuction(9000, nil), nil)
end)

test("a missing price is a verdict of its own, never 'no verdict'", function()
  local result, reason = V.Evaluate(green(), enchanter({ getPrice = prices({}) }))
  eq(result.verdict, V.NO_PRICE)
  eq(reason, nil)
end)

-- Who can act (docs/adr/0004) ----------------------------------------------

test("an enchanter gets a verdict on a soulbound item", function()
  eq(V.Evaluate(green({ isBound = true }), enchanter()).verdict, V.DISENCHANT)
end)

test("a non-enchanter gets a verdict on an item that can be mailed", function()
  eq(V.Evaluate(green(), enchanter({ canDisenchant = false })).verdict, V.DISENCHANT)
end)

test("a non-enchanter gets no verdict on a soulbound item", function()
  local result, reason = V.Evaluate(green({ isBound = true }), enchanter({ canDisenchant = false }))
  eq(result, nil)
  eq(reason, "bound")
end)

test("a soulbound item cannot be listed, so its auction price is ignored", function()
  local result = V.Evaluate(green({ isBound = true }), enchanter())
  eq(result.verdict, V.DISENCHANT, "the enchanter still gets the verdict")
  eq(V.CompareAuction(50000, result), nil)
end)

test("a non-enchanter without an enchanter alt gets no verdict", function()
  eq(V.Evaluate(green(), enchanter({ canDisenchant = false, hasEnchanterAlt = false })), nil)
end)

-- Further test files get the namespace and the helpers.
for _, file in ipairs({ "tests/facts_test.lua", "tests/display_test.lua",
  "tests/settings_test.lua", "tests/keeplist_test.lua", "tests/bagreport_test.lua",
  "tests/results_test.lua", "tests/pricebook_test.lua", "tests/worth_test.lua" }) do
  local chunk = loadfile(file)
  if chunk then chunk(ns, test, eq) end
end

print(string.format("%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
