-- What a disenchant was worth, against what was expected, and the running
-- total over the log.
local ns, test, eq = ...
local Results, Display, V, M, L = ns.Results, ns.Display, ns.Valuation, ns.Materials, ns.L

local function prices(t) return function(itemID) return t[itemID] end end
local function money(copper) return copper .. "c" end
local function nameOf(itemID) return ns.MaterialNames[itemID] or ("item " .. itemID) end

-- A level 28 green armor piece: 75% Soul Dust x1-2, 20% Greater Astral x1-2,
-- 5% Large Glimmering Shard. Expected value after the 5% cut is 2873.
local band = V.FindBand("armor", 2, 28)
local soulPrices = prices({ [M.SOUL_DUST] = 1000, [M.GREATER_ASTRAL] = 3000, [M.LARGE_GLIMMERING] = 20000 })

test("a disenchant's worth uses the same prices and auction cut as the expected value", function()
  local w = Results.Worth({ [M.SOUL_DUST] = 2 }, band, soulPrices)
  eq(w.actual, 1900, "2 x 1000 minus 5%")
  eq(w.expected, 2873)
end)

test("a lucky shard is worth more than expected", function()
  local w = Results.Worth({ [M.LARGE_GLIMMERING] = 1 }, band, soulPrices)
  eq(w.actual, 19000)
  eq(w.expected, 2873)
end)

test("a lesser essence is priced like in the verdict (a third of the greater when cheaper)", function()
  local low = V.FindBand("weapon", 2, 10)
  local w = Results.Worth({ [M.LESSER_MAGIC] = 3 }, low,
    prices({ [M.LESSER_MAGIC] = 500, [M.GREATER_MAGIC] = 900, [M.STRANGE_DUST] = 100 }))
  eq(w.actual, 855, "3 x 300 minus 5%")
end)

test("without a price for something received, the worth is unknown and says what is missing", function()
  local w = Results.Worth({ [M.SOUL_DUST] = 1, [M.LARGE_GLIMMERING] = 1 }, band,
    prices({ [M.SOUL_DUST] = 1000, [M.GREATER_ASTRAL] = 3000 }))
  eq(w.actual, nil)
  eq(#w.missing, 1)
  eq(w.missing[1], M.LARGE_GLIMMERING)
end)

test("an item outside the table has a worth but no expected value", function()
  local w = Results.Worth({ [M.SOUL_DUST] = 2 }, nil, soulPrices)
  eq(w.actual, 1900)
  eq(w.expected, nil)
end)

test("the result line names what was received, its worth, the expected value and the difference", function()
  local w = { actual = 1900, expected = 2873, missing = {} }
  eq(Display.DisenchantResult("[Belt]", { [M.SOUL_DUST] = 2 }, w, L, nameOf, money),
    "[Belt]: 2x Soul Dust, worth 1900c (expected 2873c, |cffff6060-34%|r)")
end)

test("a result above the expected value shows the difference in green, materials in table order", function()
  local w = { actual = 19950, expected = 2873, missing = {} }
  eq(Display.DisenchantResult("[Belt]", { [M.LARGE_GLIMMERING] = 1, [M.SOUL_DUST] = 1 }, w, L, nameOf, money),
    "[Belt]: 1x Soul Dust, 1x Large Glimmering Shard, worth 19950c (expected 2873c, |cff40ff40+594%|r)")
end)

test("a result line without prices says which are missing", function()
  local w = { missing = { M.LARGE_GLIMMERING } }
  eq(Display.DisenchantResult("[Belt]", { [M.LARGE_GLIMMERING] = 1 }, w, L, nameOf, money),
    "[Belt]: 1x Large Glimmering Shard, no price for Large Glimmering Shard")
end)

test("a result line without an expected value still shows the worth", function()
  local w = { actual = 1900, missing = {} }
  eq(Display.DisenchantResult("[Belt]", { [M.SOUL_DUST] = 2 }, w, L, nameOf, money),
    "[Belt]: 2x Soul Dust, worth 1900c")
end)

test("the luck total adds up records that have both values", function()
  local luck = Results.Luck({
    { actual = 1900, expected = 2873 },
    { actual = 19000, expected = 2873 },
    { actual = 500 }, -- no expected value: left out
    {}, -- recorded before values were kept
  })
  eq(luck.count, 2)
  eq(luck.actual, 20900)
  eq(luck.expected, 5746)
end)

test("the results summary ends with the luck total", function()
  local summary = Results.Compare({ Results.Record({ itemID = 1, kind = "armor", quality = 2, itemLevel = 28,
    requiredLevel = 23 }, { { item = M.SOUL_DUST, count = 2 } }) })
  summary.luck = { count = 1, actual = 1900, expected = 2873 }
  local lines = Results.Lines(summary, nameOf, money)
  eq(lines[#lines], "1 priced disenchants: worth 1900c, expected 2873c (|cffff6060-34%|r)")
end)
