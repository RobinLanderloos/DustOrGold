-- /dog: the list window, the settings, the keep list and the debug report.
local _, ns = ...

local Game, L, KeepList = ns.Game, ns.L, ns.KeepList

local captured -- while set, everything said is also stored for the debug report

local function say(text)
  print("|cff40ff40DustOrGold:|r " .. text)
  if captured then captured[#captured + 1] = text end
end
ns.Say = say

local function yesNo(value)
  if value == nil then return "n/a" end
  return value and "yes" or "no"
end

-- Reports are also kept in the saved settings (after a /reload they are in
-- the saved variables file), because chat cannot be copied out of the game.
local function startReport()
  captured = { "build " .. tostring((select(2, GetBuildInfo()))) .. ", interface " .. tostring((select(4, GetBuildInfo()))) }
end

local function endReport()
  ns.settings.report = captured
  ns.settings.debug = nil -- older name of the same field
  captured = nil
end

-- What the addon sees: the character, the price source, and one item.
local function debug(link)
  startReport()
  local signals = Game.DisenchantSignals()
  say(("can disenchant: %s (spellbook %s, player spell %s, profession %s)"):format(
    yesNo(Game.CanDisenchant()), yesNo(signals.spellbook), yesNo(signals.playerSpell), yesNo(signals.profession)))
  say("Auctionator prices: " .. yesNo(Game.HasPriceSource()))
  local dust = ns.Materials.STRANGE_DUST
  local price = Game.GetPrice(dust)
  say(("%s price: %s"):format(Game.MaterialName(dust), price and (price .. " copper") or "none"))

  if not link then
    say("add an item link to inspect an item: /dog debug [shift-click an item]")
  else
    local data = C_TooltipInfo.GetHyperlink(link)
    local result, facts, reason = Game.Evaluate(link, data)
    if not facts then
      say("no item data yet for " .. link .. ", try again")
    else
      say(("%s: kind %s, quality %s, item level %s, required level %s, vendor %s copper"):format(
        link, tostring(facts.kind), tostring(facts.quality), tostring(facts.itemLevel),
        tostring(facts.requiredLevel), tostring(facts.vendorValue)))
      say(("bound: %s, cannot disenchant: %s, kept: %s"):format(
        yesNo(facts.isBound), yesNo(facts.cannotDisenchant), yesNo(facts.isKept)))
      if result then
        say("verdict: " .. result.verdict ..
          (result.disenchantValue and (", disenchant " .. result.disenchantValue .. " copper") or ""))
      else
        say("no verdict: " .. Game.ReasonText(reason, facts))
      end
    end
  end
  endReport()
end

local function itemArgument(rest)
  local itemID = KeepList.ItemID(rest)
  if not itemID then say(L.SAY_NEED_LINK) end
  return itemID, rest:match("|c.-|h|r") or ("item " .. tostring(itemID))
end

local commands = {}

commands[""] = function()
  if ns.ListWindow then ns.ListWindow.Toggle() end
end

commands.help = function()
  for _, line in ipairs(L.HELP) do say(line) end
end

commands.margin = function(rest)
  if rest ~= "" then
    local margin = ns.Settings.ParseMargin(rest)
    if not margin then return say(L.SAY_MARGIN_BAD) end
    ns.settings.margin = margin
  end
  say(L.SAY_MARGIN:format(ns.settings.margin * 100 + 0.5))
end

commands.alt = function(rest)
  if rest == "on" then ns.settings.hasEnchanterAlt = true end
  if rest == "off" then ns.settings.hasEnchanterAlt = false end
  say(ns.settings.hasEnchanterAlt and L.SAY_ALT_ON or L.SAY_ALT_OFF)
end

commands.button = function(rest)
  if rest == "on" then ns.settings.buttonOnAll = true end
  if rest == "off" then ns.settings.buttonOnAll = false end
  say(ns.settings.buttonOnAll and L.SAY_BUTTON_ON or L.SAY_BUTTON_OFF)
end

commands.minimap = function(rest)
  if rest == "on" then ns.settings.minimap.hide = false end
  if rest == "off" then ns.settings.minimap.hide = true end
  if ns.MinimapButton then ns.MinimapButton.Update() end
  say(ns.settings.minimap.hide and L.SAY_MINIMAP_OFF or L.SAY_MINIMAP_ON)
end

commands.keep = function(rest)
  local itemID, name = itemArgument(rest)
  if not itemID then return end
  KeepList.Add(ns.settings.keep, itemID)
  say(L.SAY_KEPT:format(name))
end

commands.unkeep = function(rest)
  local itemID, name = itemArgument(rest)
  if not itemID then return end
  KeepList.Remove(ns.settings.keep, itemID)
  say(L.SAY_UNKEPT:format(name))
end

commands.keeps = function()
  local ids = KeepList.List(ns.settings.keep)
  if #ids == 0 then return say(L.SAY_NO_KEEPS) end
  say(L.SAY_KEEPS)
  for _, itemID in ipairs(ids) do
    local _, link = C_Item.GetItemInfo(itemID)
    say("  " .. (link or ("item " .. itemID)))
  end
end

commands.config = function()
  if ns.OpenOptions then ns.OpenOptions() end
end

commands.results = function()
  startReport()
  local summary = ns.Results.Compare(ns.settings.log)
  for _, line in ipairs(ns.Results.Lines(summary, Game.MaterialName)) do say(line) end
  endReport()
end

-- Debug mode stays on through a /reload until /dog debug off.
commands.debug = function(rest)
  if rest == "off" then
    ns.debug, ns.settings.debugMode = false, false
    return say(L.SAY_DEBUG_OFF)
  end
  local wasOn = ns.debug
  ns.debug, ns.settings.debugMode = true, true
  if not wasOn then say(L.SAY_DEBUG_ON) end
  debug(rest:match("|c.-|h|r") or (rest ~= "" and rest) or nil)
end

SLASH_DUSTORGOLD1 = "/dog"
SLASH_DUSTORGOLD2 = "/dustorgold"
SlashCmdList.DUSTORGOLD = function(message)
  local command, rest = (message or ""):match("^%s*(%S*)%s*(.-)%s*$")
  local run = commands[command:lower()] or commands.help
  run(rest)
  if ns.ListWindow then ns.ListWindow.Refresh() end
end
