-- The disenchant table: what an item yields, by kind, quality and item level.
--
-- Pure data, no game calls (docs/adr/0006). Seeded from the long-standing
-- vanilla community numbers; NOT yet confirmed for WoW Forever. The results
-- log exists to check it (docs/adr/0001).
local _, ns = ...

-- Item IDs of the materials, with an English name used only until the game
-- has the localized name cached.
local M = {
  STRANGE_DUST     = 10940,
  SOUL_DUST        = 11083,
  VISION_DUST      = 11137,
  DREAM_DUST       = 11176,
  ILLUSION_DUST    = 16204,
  LESSER_MAGIC     = 10938,
  GREATER_MAGIC    = 10939,
  LESSER_ASTRAL    = 10998,
  GREATER_ASTRAL   = 11082,
  LESSER_MYSTIC    = 11134,
  GREATER_MYSTIC   = 11135,
  LESSER_NETHER    = 11174,
  GREATER_NETHER   = 11175,
  LESSER_ETERNAL   = 16202,
  GREATER_ETERNAL  = 16203,
  SMALL_GLIMMERING = 10978,
  LARGE_GLIMMERING = 11084,
  SMALL_GLOWING    = 11138,
  LARGE_GLOWING    = 11139,
  SMALL_RADIANT    = 11177,
  LARGE_RADIANT    = 11178,
  SMALL_BRILLIANT  = 14343,
  LARGE_BRILLIANT  = 14344,
  NEXUS_CRYSTAL    = 20725,
}

ns.MaterialNames = {
  [M.STRANGE_DUST] = "Strange Dust",
  [M.SOUL_DUST] = "Soul Dust",
  [M.VISION_DUST] = "Vision Dust",
  [M.DREAM_DUST] = "Dream Dust",
  [M.ILLUSION_DUST] = "Illusion Dust",
  [M.LESSER_MAGIC] = "Lesser Magic Essence",
  [M.GREATER_MAGIC] = "Greater Magic Essence",
  [M.LESSER_ASTRAL] = "Lesser Astral Essence",
  [M.GREATER_ASTRAL] = "Greater Astral Essence",
  [M.LESSER_MYSTIC] = "Lesser Mystic Essence",
  [M.GREATER_MYSTIC] = "Greater Mystic Essence",
  [M.LESSER_NETHER] = "Lesser Nether Essence",
  [M.GREATER_NETHER] = "Greater Nether Essence",
  [M.LESSER_ETERNAL] = "Lesser Eternal Essence",
  [M.GREATER_ETERNAL] = "Greater Eternal Essence",
  [M.SMALL_GLIMMERING] = "Small Glimmering Shard",
  [M.LARGE_GLIMMERING] = "Large Glimmering Shard",
  [M.SMALL_GLOWING] = "Small Glowing Shard",
  [M.LARGE_GLOWING] = "Large Glowing Shard",
  [M.SMALL_RADIANT] = "Small Radiant Shard",
  [M.LARGE_RADIANT] = "Large Radiant Shard",
  [M.SMALL_BRILLIANT] = "Small Brilliant Shard",
  [M.LARGE_BRILLIANT] = "Large Brilliant Shard",
  [M.NEXUS_CRYSTAL] = "Nexus Crystal",
}

-- Three lesser essences combine into one greater (docs/adr/0003).
ns.GreaterEssenceOf = {
  [M.LESSER_MAGIC]   = M.GREATER_MAGIC,
  [M.LESSER_ASTRAL]  = M.GREATER_ASTRAL,
  [M.LESSER_MYSTIC]  = M.GREATER_MYSTIC,
  [M.LESSER_NETHER]  = M.GREATER_NETHER,
  [M.LESSER_ETERNAL] = M.GREATER_ETERNAL,
}

local UNCOMMON, RARE, EPIC = 2, 3, 4

-- Uncommon items follow one pattern per band: a dust, an essence and a shard.
-- Armor leans to dust, weapons to essence. Each tier is { item, min, max }.
local uncommonBands = {
  -- minLevel, maxLevel, dust,                        essence,                       shard,                shard chance
  {  5, 15, { M.STRANGE_DUST, 1, 2 },  { M.LESSER_MAGIC, 1, 2 },    nil,                 0    },
  { 16, 20, { M.STRANGE_DUST, 2, 3 },  { M.GREATER_MAGIC, 1, 2 },   M.SMALL_GLIMMERING,  0.05 },
  { 21, 25, { M.STRANGE_DUST, 4, 6 },  { M.LESSER_ASTRAL, 1, 2 },   M.SMALL_GLIMMERING,  0.10 },
  { 26, 30, { M.SOUL_DUST, 1, 2 },     { M.GREATER_ASTRAL, 1, 2 },  M.LARGE_GLIMMERING,  0.05 },
  { 31, 35, { M.SOUL_DUST, 2, 5 },     { M.LESSER_MYSTIC, 1, 2 },   M.SMALL_GLOWING,     0.05 },
  { 36, 40, { M.VISION_DUST, 1, 2 },   { M.GREATER_MYSTIC, 1, 2 },  M.LARGE_GLOWING,     0.05 },
  { 41, 45, { M.VISION_DUST, 2, 5 },   { M.LESSER_NETHER, 1, 2 },   M.SMALL_RADIANT,     0.05 },
  { 46, 50, { M.DREAM_DUST, 1, 2 },    { M.GREATER_NETHER, 1, 2 },  M.LARGE_RADIANT,     0.05 },
  { 51, 55, { M.DREAM_DUST, 2, 5 },    { M.LESSER_ETERNAL, 1, 2 },  M.SMALL_BRILLIANT,   0.05 },
  { 56, 60, { M.ILLUSION_DUST, 1, 2 }, { M.GREATER_ETERNAL, 1, 2 }, M.LARGE_BRILLIANT,   0.05 },
  -- Vanilla has no higher materials, so the last band covers all level 60 gear.
  { 61, 100, { M.ILLUSION_DUST, 2, 5 }, { M.GREATER_ETERNAL, 2, 3 }, M.LARGE_BRILLIANT,  0.05 },
}

-- The main material is dust for armor and essence for weapons. Its chance and
-- the other material's chance depend on how much the shard takes.
local SPLIT = {
  [0]    = { 0.80, 0.20 },
  [0.05] = { 0.75, 0.20 },
  [0.10] = { 0.75, 0.15 },
}

local function drop(tier, chance)
  return { item = tier[1], min = tier[2], max = tier[3], chance = chance }
end

local function uncommon(kind)
  local bands = {}
  for _, b in ipairs(uncommonBands) do
    local dust, essence, shard, shardChance = b[3], b[4], b[5], b[6]
    local main, other = SPLIT[shardChance][1], SPLIT[shardChance][2]
    local drops
    if kind == "armor" then
      drops = { drop(dust, main), drop(essence, other) }
    else
      drops = { drop(dust, other), drop(essence, main) }
    end
    if shard then
      drops[#drops + 1] = { item = shard, min = 1, max = 1, chance = shardChance }
    end
    bands[#bands + 1] = { min = b[1], max = b[2], drops = drops }
  end
  return bands
end

local function single(minLevel, maxLevel, item, minCount, maxCount)
  return {
    min = minLevel, max = maxLevel,
    drops = { { item = item, min = minCount or 1, max = maxCount or 1, chance = 1 } },
  }
end

-- Rare and epic items give the same results for armor and weapons.
local rare = {
  single(11, 25, M.SMALL_GLIMMERING),
  single(26, 30, M.LARGE_GLIMMERING),
  single(31, 35, M.SMALL_GLOWING),
  single(36, 40, M.LARGE_GLOWING),
  single(41, 45, M.SMALL_RADIANT),
  single(46, 50, M.LARGE_RADIANT),
  single(51, 55, M.SMALL_BRILLIANT),
  {
    min = 56, max = 100, -- vanilla community tables stop at 65; nothing else can drop above it
    drops = {
      { item = M.LARGE_BRILLIANT, min = 1, max = 1, chance = 0.995 },
      { item = M.NEXUS_CRYSTAL,   min = 1, max = 1, chance = 0.005 },
    },
  },
}

local epic = {
  single(40, 45, M.SMALL_RADIANT, 2, 4),
  single(46, 50, M.LARGE_RADIANT, 2, 4),
  single(51, 55, M.SMALL_BRILLIANT, 2, 4),
  single(56, 60, M.NEXUS_CRYSTAL),
  single(61, 100, M.NEXUS_CRYSTAL, 1, 2), -- raid epics run past 80 (Naxxramas)
}

ns.Materials = M

-- DisenchantTable[kind][quality] is a list of bands:
--   { min = itemLevel, max = itemLevel, drops = { { item, min, max, chance } } }
-- chance is 0..1 and the chances of a band add up to 1.
ns.DisenchantTable = {
  armor  = { [UNCOMMON] = uncommon("armor"),  [RARE] = rare, [EPIC] = epic },
  weapon = { [UNCOMMON] = uncommon("weapon"), [RARE] = rare, [EPIC] = epic },
}
