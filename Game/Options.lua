-- The settings panel (Options > AddOns > DustOrGold), also /dog config.
local addonName, ns = ...

local L = ns.L
local category

local function help(widget, title, text)
  widget:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(title)
    GameTooltip:AddLine(text, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function build()
  local panel = CreateFrame("Frame")
  panel:Hide() -- so OnShow fires the first time the settings show it
  panel.name = addonName

  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText(addonName)
  title:SetTextColor(unpack(ns.Skin.accent))
  local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
  sub:SetText(L.OPTION_COMMANDS)

  local alt = ns.Skin.Check(ns.Skin.Create("CheckButton", nil, panel, ns.Skin.TEMPLATES.Check))
  alt:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", -2, -16)
  alt.Text:SetText(L.OPTION_ALT)
  alt:SetScript("OnClick", function(self)
    ns.settings.hasEnchanterAlt = self:GetChecked() and true or false
  end)
  help(alt, L.OPTION_ALT, L.OPTION_ALT_HELP)

  local buttonAll = ns.Skin.Check(ns.Skin.Create("CheckButton", nil, panel, ns.Skin.TEMPLATES.Check))
  buttonAll:SetPoint("TOPLEFT", alt, "BOTTOMLEFT", 0, -2)
  buttonAll.Text:SetText(L.OPTION_BUTTON_ALL)
  buttonAll:SetScript("OnClick", function(self)
    ns.settings.buttonOnAll = self:GetChecked() and true or false
    if ns.ListWindow then ns.ListWindow.Refresh() end
  end)
  help(buttonAll, L.OPTION_BUTTON_ALL, L.OPTION_BUTTON_ALL_HELP)

  local minimap = ns.Skin.Check(ns.Skin.Create("CheckButton", nil, panel, ns.Skin.TEMPLATES.Check))
  minimap:SetPoint("TOPLEFT", buttonAll, "BOTTOMLEFT", 0, -2)
  minimap.Text:SetText(L.OPTION_MINIMAP)
  minimap:SetScript("OnClick", function(self)
    ns.settings.minimap.hide = not self:GetChecked()
    if ns.MinimapButton then ns.MinimapButton.Update() end
  end)
  help(minimap, L.OPTION_MINIMAP, L.OPTION_MINIMAP_HELP)

  local results = ns.Skin.Check(ns.Skin.Create("CheckButton", nil, panel, ns.Skin.TEMPLATES.Check))
  results:SetPoint("TOPLEFT", minimap, "BOTTOMLEFT", 0, -2)
  results.Text:SetText(L.OPTION_RESULTS)
  results:SetScript("OnClick", function(self)
    ns.settings.showResults = self:GetChecked() and true or false
  end)
  help(results, L.OPTION_RESULTS, L.OPTION_RESULTS_HELP)

  local label = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  label:SetPoint("TOPLEFT", results, "BOTTOMLEFT", 4, -14)
  label:SetText(L.OPTION_MARGIN)

  local margin = ns.Skin.Input(ns.Skin.Create("EditBox", nil, panel, ns.Skin.TEMPLATES.Input))
  margin:SetSize(50, 22)
  margin:SetPoint("LEFT", label, "RIGHT", 12, 0)
  margin:SetAutoFocus(false)
  margin:SetMaxLetters(5)
  local function showMargin()
    margin:SetText(("%d"):format(ns.settings.margin * 100 + 0.5))
  end
  local function applyMargin()
    local value = ns.Settings.ParseMargin(margin:GetText())
    if value then ns.settings.margin = value end
    showMargin()
    margin:ClearFocus()
  end
  margin:SetScript("OnEnterPressed", applyMargin)
  margin:SetScript("OnEditFocusLost", applyMargin)
  margin:SetScript("OnEscapePressed", function(self) showMargin(); self:ClearFocus() end)
  help(margin, L.OPTION_MARGIN, L.OPTION_MARGIN_HELP)

  panel:SetScript("OnShow", function()
    alt:SetChecked(ns.settings.hasEnchanterAlt)
    buttonAll:SetChecked(ns.settings.buttonOnAll)
    minimap:SetChecked(not ns.settings.minimap.hide)
    results:SetChecked(ns.settings.showResults)
    showMargin()
  end)

  category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
  Settings.RegisterAddOnCategory(category)
end

function ns.OpenOptions()
  if category then Settings.OpenToCategory(category:GetID()) end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
  local ok, err = pcall(build)
  if not ok then ns.Say("the settings panel could not be built: " .. tostring(err)) end
end)
