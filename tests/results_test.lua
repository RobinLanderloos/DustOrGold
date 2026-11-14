-- The results log: recording disenchants and checking them against the table.
local ns, test, eq = ...
local Results, M = ns.Results, ns.Materials

local function facts(overrides)
  local f = { itemID = 727, kind = "weapon", quality = 2, itemLevel = 10, requiredLevel = 5 }
  for k, v in pairs(overrides or {}) do f[k] = v end
  return f
end

test("a record holds the item's facts and what was received", function()
  local r = Results.Record(facts(), { { item = M.LESSER_MAGIC, count = 2 } }, 1700000000)
  eq(r.itemID, 727)
  eq(r.kind, "weapon")
  eq(r.quality, 2)
  eq(r.itemLevel, 10)
  eq(r.requiredLevel, 5)
  eq(r.time, 1700000000)
  eq(r.materials[M.LESSER_MAGIC], 2)
end)

test("the same material in two loot slots is added up", function()
  local r = Results.Record(facts(), { { item = M.STRANGE_DUST, count = 1 }, { item = M.STRANGE_DUST, count = 2 } })
  eq(r.materials[M.STRANGE_DUST], 3)
end)

local function record(materials, overrides)
  local received = {}
  for item, count in pairs(materials) do received[#received + 1] = { item = item, count = count } end
  return Results.Record(facts(overrides), received)
end

test("records are summarised per band with observed against expected shares", function()
  local records = {
    record({ [M.LESSER_MAGIC] = 1 }),
    record({ [M.LESSER_MAGIC] = 2 }),
    record({ [M.LESSER_MAGIC] = 1 }),
    record({ [M.STRANGE_DUST] = 2 }),
  }
  local summary = Results.Compare(records)
  eq(#summary.bands, 1)
  local band = summary.bands[1]
  eq(band.kind, "weapon"); eq(band.quality, 2); eq(band.min, 5); eq(band.max, 15)
  eq(band.samples, 4)
  local byItem = {}
  for _, m in ipairs(band.materials) do byItem[m.item] = m end
  eq(byItem[M.LESSER_MAGIC].observed, 0.75)
  eq(byItem[M.LESSER_MAGIC].expected, 0.80)
  eq(byItem[M.STRANGE_DUST].observed, 0.25)
  eq(byItem[M.STRANGE_DUST].expected, 0.20)
  eq(#band.unexpected, 0)
end)

test("a material the table does not list for the band is called out", function()
  local summary = Results.Compare({ record({ [M.SOUL_DUST] = 1 }) })
  local band = summary.bands[1]
  eq(#band.unexpected, 1)
  eq(band.unexpected[1].item, M.SOUL_DUST)
  eq(band.unexpected[1].times, 1)
end)

test("a disenchanted item the table has no band for is counted", function()
  local summary = Results.Compare({ record({ [M.STRANGE_DUST] = 1 }, { itemLevel = 3, requiredLevel = 1 }) })
  eq(#summary.bands, 0)
  eq(summary.outsideTable, 1)
end)

test("when the two levels point at different bands, the result decides which one fits", function()
  -- item level 18 is band 16-20 (Greater Magic Essence); required level 13 is band 5-15 (Lesser Magic)
  local summary = Results.Compare({
    record({ [M.GREATER_MAGIC] = 1 }, { itemLevel = 18, requiredLevel = 13 }),
    record({ [M.LESSER_MAGIC] = 1 }, { itemLevel = 18, requiredLevel = 13 }),
    record({ [M.LESSER_MAGIC] = 1 }, { itemLevel = 19, requiredLevel = 14 }),
    record({ [M.LESSER_MAGIC] = 1 }, { itemLevel = 10, requiredLevel = 5 }), -- same band either way
  })
  eq(summary.levels.itemLevel, 1)
  eq(summary.levels.requiredLevel, 2)
end)

test("summary lines read like a report", function()
  local summary = Results.Compare({ record({ [M.LESSER_MAGIC] = 1 }), record({ [M.SOUL_DUST] = 1 }) })
  local lines = Results.Lines(summary, function(id) return ns.MaterialNames[id] end)
  local text = table.concat(lines, "\n")
  eq(lines[1], "uncommon weapon, item level 5-15: 2 disenchants")
  eq(text:find("Lesser Magic Essence 50% (table 80%)", 1, true) ~= nil, true, "observed against table")
  eq(text:find("not in the table: Soul Dust x1", 1, true) ~= nil, true, "unexpected material")
end)

test("an empty log says so", function()
  local lines = Results.Lines(Results.Compare({}), tostring)
  eq(#lines, 1)
  eq(lines[1], "no disenchants recorded yet")
end)
