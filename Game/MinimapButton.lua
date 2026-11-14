-- The minimap button: left-click opens the list, right-click the settings,
-- drag to move it around the minimap. Its angle and whether it is hidden are
-- saved settings.
local addonName, ns = ...

local L, Settings = ns.L, ns.Settings
local DISENCHANT = 13262
local FALLBACK_ICON = "Interface\\Icons\\INV_Enchant_Disenchant"

local MinimapButton = {}
ns.MinimapButton = MinimapButton

local button

local function radius()
  return (Minimap:GetWidth() / 2) + 10
end

local function place()
  local x, y = Settings.MinimapOffset(ns.settings.minimap.angle, radius())
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- While dragging, follow the cursor around the minimap.
local function follow()
  local centerX, centerY = Minimap:GetCenter()
  local cursorX, cursorY = GetCursorPosition()
  local scale = Minimap:GetEffectiveScale()
  ns.settings.minimap.angle = Settings.MinimapAngle(cursorX / scale - centerX, cursorY / scale - centerY)
  place()
end

local function build()
  button = CreateFrame("Button", "DustOrGoldMinimapButton", Minimap)
  button:SetSize(31, 31)
  button:SetFrameStrata("MEDIUM")
  button:SetFrameLevel(8)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")
  button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  local background = button:CreateTexture(nil, "BACKGROUND")
  background:SetSize(20, 20)
  background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  background:SetPoint("TOPLEFT", 7, -5)

  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetSize(17, 17)
  icon:SetPoint("TOPLEFT", 7, -6)
  icon:SetTexture(C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(DISENCHANT) or FALLBACK_ICON)
  icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)

  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetSize(53, 53)
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetPoint("TOPLEFT")

  button:SetScript("OnClick", function(_, mouseButton)
    if mouseButton == "RightButton" then
      if ns.OpenOptions then ns.OpenOptions() end
    elseif ns.ListWindow then
      ns.ListWindow.Toggle()
    end
  end)
  button:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", follow)
  end)
  button:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
  end)
  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText(addonName)
    GameTooltip:AddLine(L.MINIMAP_TOOLTIP_LEFT, 1, 1, 1)
    GameTooltip:AddLine(L.MINIMAP_TOOLTIP_RIGHT, 1, 1, 1)
    GameTooltip:AddLine(L.MINIMAP_TOOLTIP_DRAG, 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Shows or hides the button to match the settings.
function MinimapButton.Update()
  if not Minimap then return end
  if not button then build() end
  place()
  button:SetShown(not ns.settings.minimap.hide)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
  local ok, err = pcall(MinimapButton.Update)
  if not ok then ns.Say("the minimap button could not be built: " .. tostring(err)) end
end)
