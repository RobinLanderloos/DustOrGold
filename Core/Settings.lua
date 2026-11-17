-- Saved settings: defaults and input parsing. Pure (docs/adr/0006).
local _, ns = ...

local Settings = {}
ns.Settings = Settings

Settings.DEFAULT_MINIMAP_ANGLE = 200 -- degrees, 0 is to the right, counter-clockwise

-- Where the minimap button sits for an angle in degrees, as x, y from the
-- minimap's centre.
function Settings.MinimapOffset(angle, radius)
  local radians = math.rad(angle)
  return math.cos(radians) * radius, math.sin(radians) * radius
end

-- The angle in degrees (0 to 360) of a point relative to the minimap's centre.
function Settings.MinimapAngle(dx, dy)
  return math.deg(math.atan2(dy, dx)) % 360
end

-- Fills in what is missing or broken in the stored settings and returns the
-- same table, so the game keeps saving it.
function Settings.Normalize(stored)
  local s = type(stored) == "table" and stored or {}
  if type(s.margin) ~= "number" or s.margin < 0 or s.margin > 1 then
    s.margin = ns.Valuation.DEFAULT_MARGIN
  end
  if type(s.hasEnchanterAlt) ~= "boolean" then s.hasEnchanterAlt = true end
  if type(s.keep) ~= "table" then s.keep = {} end
  if type(s.log) ~= "table" then s.log = {} end
  if type(s.debugMode) ~= "boolean" then s.debugMode = false end
  if type(s.buttonOnAll) ~= "boolean" then s.buttonOnAll = false end
  if type(s.prices) ~= "table" then s.prices = {} end
  if type(s.autoScan) ~= "boolean" then s.autoScan = true end
  if type(s.showResults) ~= "boolean" then s.showResults = true end
  if type(s.minimap) ~= "table" then s.minimap = {} end
  if type(s.minimap.angle) ~= "number" then s.minimap.angle = Settings.DEFAULT_MINIMAP_ANGLE end
  if type(s.minimap.hide) ~= "boolean" then s.minimap.hide = false end
  local w = s.window
  if type(w) ~= "table" or type(w.width) ~= "number" or type(w.height) ~= "number" then
    s.window = nil
  end
  return s
end

-- "25" or "25%" to 0.25; nil when it is not a percentage from 0 to 100.
function Settings.ParseMargin(text)
  local number = tonumber((tostring(text or ""):gsub("%%", ""):match("^%s*(.-)%s*$")))
  if not number or number < 0 or number > 100 then return nil end
  return number / 100
end
