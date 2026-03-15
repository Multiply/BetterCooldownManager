local _, BCDM = ...

local function ShouldSkin()
    if not BCDM.db.profile.CooldownManager.Enable then return false end
    if C_AddOns.IsAddOnLoaded("ElvUI") and ElvUI[1].private.skins.blizzard.cooldownManager then return false end
    if C_AddOns.IsAddOnLoaded("MasqueBlizzBars") then return false end
    return true
end

local function NudgeViewer(viewerName, xOffset, yOffset)
    local viewerFrame = _G[viewerName]
    if not viewerFrame then return end
    local point, relativeTo, relativePoint, currentX, currentY = viewerFrame:GetPoint(1)
    viewerFrame:ClearAllPoints()
    viewerFrame:SetPoint(point, relativeTo, relativePoint, currentX + xOffset, currentY + yOffset)
end

local function FetchCooldownTextRegion(cooldown)
    if not cooldown then return end
    for _, region in ipairs({ cooldown:GetRegions() }) do
        if region:GetObjectType() == "FontString" then
            return region
        end
    end
end

local function ApplyCooldownText(cooldownViewer)
    local CooldownManagerDB = BCDM.db.profile
    local GeneralDB = CooldownManagerDB.General
    local CooldownTextDB = CooldownManagerDB.CooldownManager.General.CooldownText
    local Viewer = _G[cooldownViewer]
    if not Viewer then return end
    for _, icon in ipairs({ Viewer:GetChildren() }) do
        if icon and icon.Cooldown then
            local textRegion = FetchCooldownTextRegion(icon.Cooldown)
            if textRegion then
                if CooldownTextDB.ScaleByIconSize then
                    local iconWidth = icon:GetWidth()
                    local scaleFactor = iconWidth / 36
                    textRegion:SetFont(BCDM.Media.Font, CooldownTextDB.FontSize * scaleFactor, GeneralDB.Fonts.FontFlag)
                else
                    textRegion:SetFont(BCDM.Media.Font, CooldownTextDB.FontSize, GeneralDB.Fonts.FontFlag)
                end
                textRegion:SetTextColor(CooldownTextDB.Colour[1], CooldownTextDB.Colour[2], CooldownTextDB.Colour[3], 1)
                textRegion:ClearAllPoints()
                textRegion:SetPoint(CooldownTextDB.Layout[1], icon, CooldownTextDB.Layout[2], CooldownTextDB.Layout[3], CooldownTextDB.Layout[4])
                if GeneralDB.Fonts.Shadow.Enabled then
                    textRegion:SetShadowColor(GeneralDB.Fonts.Shadow.Colour[1], GeneralDB.Fonts.Shadow.Colour[2], GeneralDB.Fonts.Shadow.Colour[3], GeneralDB.Fonts.Shadow.Colour[4])
                    textRegion:SetShadowOffset(GeneralDB.Fonts.Shadow.OffsetX, GeneralDB.Fonts.Shadow.OffsetY)
                else
                    textRegion:SetShadowColor(0, 0, 0, 0)
                    textRegion:SetShadowOffset(0, 0)
                end
            end
        end
    end
end

local function Position()
    local cooldownManagerSettings = BCDM.db.profile.CooldownManager
    for _, viewerName in ipairs(BCDM.CooldownManagerViewers) do
        local viewerSettings = cooldownManagerSettings[BCDM.CooldownManagerViewerToDBViewer[viewerName]]
        local viewerFrame = _G[viewerName]
        if viewerFrame and (viewerName == "UtilityCooldownViewer" or viewerName == "BuffIconCooldownViewer") then
            viewerFrame:ClearAllPoints()
            local anchorParent = viewerSettings.Layout[2] == "NONE" and UIParent or _G[viewerSettings.Layout[2]]
            viewerFrame:SetPoint(viewerSettings.Layout[1], anchorParent, viewerSettings.Layout[3], viewerSettings.Layout[4], viewerSettings.Layout[5])
            viewerFrame:SetFrameStrata("LOW")
        elseif viewerFrame then
            viewerFrame:ClearAllPoints()
            viewerFrame:SetPoint(viewerSettings.Layout[1], UIParent, viewerSettings.Layout[3], viewerSettings.Layout[4], viewerSettings.Layout[5])
            viewerFrame:SetFrameStrata("LOW")
        end
        NudgeViewer(viewerName, -0.1, 0)
    end
end

local function StyleIcons()
    if not ShouldSkin() then return end
    local cooldownManagerSettings = BCDM.db.profile.CooldownManager
    for _, viewerName in ipairs(BCDM.CooldownManagerViewers) do
        local viewerSettings = cooldownManagerSettings[BCDM.CooldownManagerViewerToDBViewer[viewerName]]
        local iconWidth, iconHeight = BCDM:GetIconDimensions(viewerSettings)
        for _, childFrame in ipairs({_G[viewerName]:GetChildren()}) do
            if childFrame then
                if childFrame.Icon then
                    BCDM:StripTextures(childFrame.Icon)
                    local iconZoomAmount = cooldownManagerSettings.General.IconZoom * 0.5
                    BCDM:ApplyIconTexCoord(childFrame.Icon, iconWidth, iconHeight, iconZoomAmount)
                end
                if childFrame.Cooldown then
                    local borderSize = cooldownManagerSettings.General.BorderSize
                    childFrame.Cooldown:ClearAllPoints()
                    childFrame.Cooldown:SetPoint("TOPLEFT", childFrame, "TOPLEFT", borderSize, -borderSize)
                    childFrame.Cooldown:SetPoint("BOTTOMRIGHT", childFrame, "BOTTOMRIGHT", -borderSize, borderSize)
                    childFrame.Cooldown:SetSwipeColor(0, 0, 0, 0.8)
                    childFrame.Cooldown:SetDrawEdge(false)
                    childFrame.Cooldown:SetDrawSwipe(true)
                    childFrame.Cooldown:SetSwipeTexture("Interface\\Buttons\\WHITE8X8")
                end
                if childFrame.CooldownFlash then childFrame.CooldownFlash:SetAlpha(0) end
                if childFrame.DebuffBorder then childFrame.DebuffBorder:SetAlpha(0) end
                childFrame:SetSize(iconWidth, iconHeight)
                BCDM:AddBorder(childFrame)
                if not childFrame.layoutIndex then childFrame:SetShown(false) end
            end
        end
    end
end

local function SetHooks()
    hooksecurefunc(EditModeManagerFrame, "EnterEditMode", function() if InCombatLockdown() then return end Position() BCDM:UpdateTrackedBars() end)
    hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function() if InCombatLockdown() then return end BCDM.LEMO:LoadLayouts() Position() BCDM:UpdateTrackedBars() end)
    hooksecurefunc(CooldownViewerSettings, "RefreshLayout", function() if InCombatLockdown() then return end BCDM:UpdateBCDM() end)
end

local function StyleChargeCount()
    local cooldownManagerSettings = BCDM.db.profile.CooldownManager
    local generalSettings = BCDM.db.profile.General
    for _, viewerName in ipairs(BCDM.CooldownManagerViewers) do
        for _, childFrame in ipairs({ _G[viewerName]:GetChildren() }) do
            if childFrame and childFrame.ChargeCount and childFrame.ChargeCount.Current then
                local currentChargeText = childFrame.ChargeCount.Current
                currentChargeText:SetFont(BCDM.Media.Font, cooldownManagerSettings[BCDM.CooldownManagerViewerToDBViewer[viewerName]].Text.FontSize, generalSettings.Fonts.FontFlag)
                currentChargeText:ClearAllPoints()
                currentChargeText:SetPoint(cooldownManagerSettings[BCDM.CooldownManagerViewerToDBViewer[viewerName]].Text.Layout[1], childFrame, cooldownManagerSettings[BCDM.CooldownManagerViewerToDBViewer[viewerName]].Text.Layout[2], cooldownManagerSettings[BCDM.CooldownManagerViewerToDBViewer[viewerName]].Text.Layout[3], cooldownManagerSettings[BCDM.CooldownManagerViewerToDBViewer[viewerName]].Text.Layout[4])
                currentChargeText:SetTextColor(cooldownManagerSettings[BCDM.CooldownManagerViewerToDBViewer[viewerName]].Text.Colour[1], cooldownManagerSettings[BCDM.CooldownManagerViewerToDBViewer[viewerName]].Text.Colour[2], cooldownManagerSettings[BCDM.CooldownManagerViewerToDBViewer[viewerName]].Text.Colour[3], 1)
                if generalSettings.Fonts.Shadow.Enabled then
                    currentChargeText:SetShadowColor(generalSettings.Fonts.Shadow.Colour[1], generalSettings.Fonts.Shadow.Colour[2], generalSettings.Fonts.Shadow.Colour[3], generalSettings.Fonts.Shadow.Colour[4])
                    currentChargeText:SetShadowOffset(generalSettings.Fonts.Shadow.OffsetX, generalSettings.Fonts.Shadow.OffsetY)
                else
                    currentChargeText:SetShadowColor(0, 0, 0, 0)
                    currentChargeText:SetShadowOffset(0, 0)
                end
                currentChargeText:SetDrawLayer("OVERLAY")
            end
        end
        for _, childFrame in ipairs({ _G[viewerName]:GetChildren() }) do
            if childFrame and childFrame.Applications then
                local applicationsText = childFrame.Applications.Applications
                applicationsText:SetFont(BCDM.Media.Font, cooldownManagerSettings[BCDM.CooldownManagerViewerToDBViewer[viewerName]].Text.FontSize, generalSettings.Fonts.FontFlag)
                applicationsText:ClearAllPoints()
                applicationsText:SetPoint(cooldownManagerSettings[BCDM.CooldownManagerViewerToDBViewer[viewerName]].Text.Layout[1], childFrame, cooldownManagerSettings[BCDM.CooldownManagerViewerToDBViewer[viewerName]].Text.Layout[2], cooldownManagerSettings[BCDM.CooldownManagerViewerToDBViewer[viewerName]].Text.Layout[3], cooldownManagerSettings[BCDM.CooldownManagerViewerToDBViewer[viewerName]].Text.Layout[4])
                applicationsText:SetTextColor(cooldownManagerSettings[BCDM.CooldownManagerViewerToDBViewer[viewerName]].Text.Colour[1], cooldownManagerSettings[BCDM.CooldownManagerViewerToDBViewer[viewerName]].Text.Colour[2], cooldownManagerSettings[BCDM.CooldownManagerViewerToDBViewer[viewerName]].Text.Colour[3], 1)
                if generalSettings.Fonts.Shadow.Enabled then
                    applicationsText:SetShadowColor(generalSettings.Fonts.Shadow.Colour[1], generalSettings.Fonts.Shadow.Colour[2], generalSettings.Fonts.Shadow.Colour[3], generalSettings.Fonts.Shadow.Colour[4])
                    applicationsText:SetShadowOffset(generalSettings.Fonts.Shadow.OffsetX, generalSettings.Fonts.Shadow.OffsetY)
                else
                    applicationsText:SetShadowColor(0, 0, 0, 0)
                    applicationsText:SetShadowOffset(0, 0)
                end
                applicationsText:SetDrawLayer("OVERLAY")
            end
        end
    end
end

local centerBuffsUpdateThrottle = 0.01
local nextcenterBuffsUpdate = 0

local function CenterBuffs()
    local currentTime = GetTime()
    if currentTime < nextcenterBuffsUpdate then return end
    nextcenterBuffsUpdate = currentTime + centerBuffsUpdateThrottle
    local visibleBuffIcons = {}

    for _, childFrame in ipairs({ BuffIconCooldownViewer:GetChildren() }) do
        if childFrame and childFrame.Icon and childFrame:IsShown() then
            table.insert(visibleBuffIcons, childFrame)
        end
    end

    table.sort(visibleBuffIcons, function(a, b) return (a.layoutIndex or 0) < (b.layoutIndex or 0) end)

    local visibleCount = #visibleBuffIcons
    if visibleCount == 0 then return 0 end

    local iconWidth = visibleBuffIcons[1]:GetWidth()
    local iconHeight = visibleBuffIcons[1]:GetHeight()
    local startX = 0
    local startY = 0
    local iconSpacing = 0

    if BuffIconCooldownViewer.isHorizontal then
        iconSpacing = BuffIconCooldownViewer.childXPadding or 0
        local totalWidth = (visibleCount * iconWidth) + ((visibleCount - 1) * iconSpacing)
        startX = -totalWidth / 2 + iconWidth / 2
    else
        iconSpacing = BuffIconCooldownViewer.childYPadding or 0
        local totalHeight = (visibleCount * iconHeight) + ((visibleCount - 1) * iconSpacing)
        startY = totalHeight / 2 - iconHeight / 2
    end

    for index, iconFrame in ipairs(visibleBuffIcons) do
        if BuffIconCooldownViewer.isHorizontal then
            iconFrame:ClearAllPoints()
            iconFrame:SetPoint("CENTER", BuffIconCooldownViewer, "CENTER", startX + (index - 1) * (iconWidth + iconSpacing), 0)
        else
            iconFrame:ClearAllPoints()
            iconFrame:SetPoint("CENTER", BuffIconCooldownViewer, "CENTER", 0, startY - (index - 1) * (iconHeight + iconSpacing))
        end
    end

    return visibleCount
end

local centerBuffsEventFrame = CreateFrame("Frame")

local function SetupCenterBuffs()
    local buffsSettings = BCDM.db.profile.CooldownManager.Buffs

    if buffsSettings.CenterBuffs then
        centerBuffsEventFrame:SetScript("OnUpdate", CenterBuffs)
    else
        centerBuffsEventFrame:SetScript("OnUpdate", nil)
        centerBuffsEventFrame:Hide()
    end
end

local function CenterWrappedRows(viewerName)
    local viewer = _G[viewerName]
    if not viewer then return end

    local iconLimit = viewer.iconLimit
    if not iconLimit or iconLimit <= 0 then return end

    local visibleIcons = {}
    for _, childFrame in ipairs({ viewer:GetChildren() }) do
        if childFrame and childFrame:IsShown() and childFrame.layoutIndex then
            table.insert(visibleIcons, childFrame)
        end
    end

    table.sort(visibleIcons, function(a, b) return (a.layoutIndex or 0) < (b.layoutIndex or 0) end)

    local visibleCount = #visibleIcons
    if visibleCount == 0 then return end

    local iconWidth = visibleIcons[1]:GetWidth()
    local iconHeight = visibleIcons[1]:GetHeight()
    local iconSpacing = viewer.childXPadding or 0
    local rowSpacing = viewer.childYPadding or 0
    local rowHeight = (iconHeight > 0 and iconHeight or iconWidth) + rowSpacing

    local basePoint, _, _, _, baseY = visibleIcons[1]:GetPoint(1)
    if not basePoint or not baseY then return end
    local anchorPoint = "TOP"
    local relativePoint = "TOP"
    local yDirection = -1
    if basePoint and basePoint:find("BOTTOM") then
        anchorPoint = "BOTTOM"
        relativePoint = "BOTTOM"
        yDirection = 1
    end

    local rowCount = math.ceil(visibleCount / iconLimit)
    for rowIndex = 1, rowCount do
        local rowStart = (rowIndex - 1) * iconLimit + 1
        local rowEnd = math.min(rowStart + iconLimit - 1, visibleCount)
        local rowIcons = rowEnd - rowStart + 1
        local rowWidth = (rowIcons * iconWidth) + ((rowIcons - 1) * iconSpacing)
        local startX = -rowWidth / 2 + iconWidth / 2
        local rowY = baseY + yDirection * (rowIndex - 1) * rowHeight

        for index = rowStart, rowEnd do
            local iconFrame = visibleIcons[index]
            iconFrame:ClearAllPoints()
            iconFrame:SetPoint(anchorPoint, viewer, relativePoint, startX + (index - rowStart) * (iconWidth + iconSpacing), rowY)
        end
    end
end

local function CenterWrappedIcons()
    local cooldownManagerSettings = BCDM.db.profile.CooldownManager
    local essentialSettings = cooldownManagerSettings.Essential
    local utilitySettings = cooldownManagerSettings.Utility

    if essentialSettings and essentialSettings.CenterHorizontally then CenterWrappedRows("EssentialCooldownViewer") end
    if utilitySettings and utilitySettings.CenterHorizontally then CenterWrappedRows("UtilityCooldownViewer") end
end

local function FetchTrackedBarColour()
    local BuffBarDB = BCDM.db.profile.CooldownManager.BuffBar
    if BuffBarDB.ColourByClass then
        local _, class = UnitClass("player")
        local classColour = RAID_CLASS_COLORS[class]
        if classColour then
            return classColour.r, classColour.g, classColour.b, 1
        end
    end
    return BuffBarDB.ForegroundColour[1], BuffBarDB.ForegroundColour[2], BuffBarDB.ForegroundColour[3], BuffBarDB.ForegroundColour[4]
end

local function StyleTrackedBars()
    if not ShouldSkin() then return end
    local BuffBarDB = BCDM.db.profile.CooldownManager.BuffBar
    local GeneralDB = BCDM.db.profile.General
    local borderSize = BCDM.db.profile.CooldownManager.General.BorderSize
    local viewerFrame = _G["BuffBarCooldownViewer"]
    if not viewerFrame then return end

    local r, g, b, a = FetchTrackedBarColour()
    local iconZoom = BCDM.db.profile.CooldownManager.General.IconZoom * 0.5

    for _, barFrame in ipairs({ viewerFrame:GetChildren() }) do
        if barFrame then
            -- Blizzard structure: barFrame.Bar (StatusBar), barFrame.Icon (frame containing .Icon texture),
            -- barFrame.Bar.Name (FontString), barFrame.Bar.Duration (FontString),
            -- barFrame.Bar.BarBG (background texture), barFrame.Bar.Pip (pip texture),
            -- barFrame.DebuffBorder
            local statusBar = barFrame.Bar
            local iconFrame = barFrame.Icon
            local iconTexture = iconFrame and iconFrame.Icon
            local nameText = statusBar and statusBar.Name
            local timeText = statusBar and statusBar.Duration

            barFrame:SetHeight(BuffBarDB.Height)

            if statusBar then
                statusBar:SetStatusBarTexture(BCDM.Media.Foreground)
                statusBar:SetStatusBarColor(r, g, b, a)

                -- Hide the Blizzard background and pip textures
                if statusBar.BarBG then statusBar.BarBG:Hide() end
                if statusBar.Pip then statusBar.Pip:Hide() end
            end

            if barFrame.DebuffBorder then barFrame.DebuffBorder:SetAlpha(0) end

            if iconFrame then
                if BuffBarDB.Icon.Enabled then
                    iconFrame:Show()
                    iconFrame:SetSize(BuffBarDB.Height, BuffBarDB.Height)
                    if iconTexture then
                        BCDM:StripTextures(iconTexture)
                        iconTexture:SetTexCoord(iconZoom, 1 - iconZoom, iconZoom, 1 - iconZoom)
                    end
                    iconFrame:ClearAllPoints()
                    if statusBar then
                        if BuffBarDB.Icon.Layout == "RIGHT" then
                            iconFrame:SetPoint("TOPRIGHT", barFrame, "TOPRIGHT", -borderSize, -borderSize)
                            iconFrame:SetPoint("BOTTOMRIGHT", barFrame, "BOTTOMRIGHT", -borderSize, borderSize)
                            statusBar:ClearAllPoints()
                            statusBar:SetPoint("TOPLEFT", barFrame, "TOPLEFT", borderSize, -borderSize)
                            statusBar:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMLEFT", 0, 0)
                        else
                            iconFrame:SetPoint("TOPLEFT", barFrame, "TOPLEFT", borderSize, -borderSize)
                            iconFrame:SetPoint("BOTTOMLEFT", barFrame, "BOTTOMLEFT", borderSize, borderSize)
                            statusBar:ClearAllPoints()
                            statusBar:SetPoint("TOPLEFT", iconFrame, "TOPRIGHT", 0, 0)
                            statusBar:SetPoint("BOTTOMRIGHT", barFrame, "BOTTOMRIGHT", -borderSize, borderSize)
                        end
                    end
                    BCDM:AddBorder(iconFrame)
                else
                    iconFrame:Hide()
                    if statusBar then
                        statusBar:ClearAllPoints()
                        statusBar:SetPoint("TOPLEFT", barFrame, "TOPLEFT", borderSize, -borderSize)
                        statusBar:SetPoint("BOTTOMRIGHT", barFrame, "BOTTOMRIGHT", -borderSize, borderSize)
                    end
                end
            elseif statusBar then
                statusBar:ClearAllPoints()
                statusBar:SetPoint("TOPLEFT", barFrame, "TOPLEFT", borderSize, -borderSize)
                statusBar:SetPoint("BOTTOMRIGHT", barFrame, "BOTTOMRIGHT", -borderSize, borderSize)
            end

            if nameText then
                if BuffBarDB.Text.SpellName.Enabled then
                    nameText:Show()
                    nameText:SetFont(BCDM.Media.Font, BuffBarDB.Text.SpellName.FontSize, GeneralDB.Fonts.FontFlag)
                    nameText:SetTextColor(BuffBarDB.Text.SpellName.Colour[1], BuffBarDB.Text.SpellName.Colour[2], BuffBarDB.Text.SpellName.Colour[3], 1)
                    nameText:ClearAllPoints()
                    nameText:SetPoint(BuffBarDB.Text.SpellName.Layout[1], statusBar, BuffBarDB.Text.SpellName.Layout[2], BuffBarDB.Text.SpellName.Layout[3], BuffBarDB.Text.SpellName.Layout[4])
                    if GeneralDB.Fonts.Shadow.Enabled then
                        nameText:SetShadowColor(GeneralDB.Fonts.Shadow.Colour[1], GeneralDB.Fonts.Shadow.Colour[2], GeneralDB.Fonts.Shadow.Colour[3], GeneralDB.Fonts.Shadow.Colour[4])
                        nameText:SetShadowOffset(GeneralDB.Fonts.Shadow.OffsetX, GeneralDB.Fonts.Shadow.OffsetY)
                    else
                        nameText:SetShadowColor(0, 0, 0, 0)
                        nameText:SetShadowOffset(0, 0)
                    end
                else
                    nameText:Hide()
                end
            end

            if timeText then
                if BuffBarDB.Text.Duration.Enabled then
                    timeText:Show()
                    timeText:SetFont(BCDM.Media.Font, BuffBarDB.Text.Duration.FontSize, GeneralDB.Fonts.FontFlag)
                    timeText:SetTextColor(BuffBarDB.Text.Duration.Colour[1], BuffBarDB.Text.Duration.Colour[2], BuffBarDB.Text.Duration.Colour[3], 1)
                    timeText:ClearAllPoints()
                    timeText:SetPoint(BuffBarDB.Text.Duration.Layout[1], statusBar, BuffBarDB.Text.Duration.Layout[2], BuffBarDB.Text.Duration.Layout[3], BuffBarDB.Text.Duration.Layout[4])
                    if GeneralDB.Fonts.Shadow.Enabled then
                        timeText:SetShadowColor(GeneralDB.Fonts.Shadow.Colour[1], GeneralDB.Fonts.Shadow.Colour[2], GeneralDB.Fonts.Shadow.Colour[3], GeneralDB.Fonts.Shadow.Colour[4])
                        timeText:SetShadowOffset(GeneralDB.Fonts.Shadow.OffsetX, GeneralDB.Fonts.Shadow.OffsetY)
                    else
                        timeText:SetShadowColor(0, 0, 0, 0)
                        timeText:SetShadowOffset(0, 0)
                    end
                else
                    timeText:Hide()
                end
            end

            -- Apply backdrop to the bar frame
            if barFrame.SetBackdrop then
                barFrame:SetBackdrop(BCDM.BACKDROP)
                if borderSize > 0 then
                    barFrame:SetBackdropBorderColor(0, 0, 0, 1)
                else
                    barFrame:SetBackdropBorderColor(0, 0, 0, 0)
                end
                barFrame:SetBackdropColor(BuffBarDB.BackgroundColour[1], BuffBarDB.BackgroundColour[2], BuffBarDB.BackgroundColour[3], BuffBarDB.BackgroundColour[4])
            end
        end
    end
end

local function PositionTrackedBars()
    local BuffBarDB = BCDM.db.profile.CooldownManager.BuffBar
    local viewerFrame = _G["BuffBarCooldownViewer"]
    if not viewerFrame then return end
    viewerFrame:ClearAllPoints()
    local anchorParent = BuffBarDB.Layout[2] == "NONE" and UIParent or _G[BuffBarDB.Layout[2]]
    if not anchorParent then anchorParent = UIParent end
    viewerFrame:SetPoint(BuffBarDB.Layout[1], anchorParent, BuffBarDB.Layout[3], BuffBarDB.Layout[4], BuffBarDB.Layout[5])
    viewerFrame:SetFrameStrata("LOW")
    NudgeViewer("BuffBarCooldownViewer", -0.1, 0)
end


function BCDM:SkinCooldownManager()
    local LEMO = BCDM.LEMO
    LEMO:LoadLayouts()
    C_CVar.SetCVar("cooldownViewerEnabled", 1)
    StyleIcons()
    StyleChargeCount()
    Position()
    SetHooks()
    SetupCenterBuffs()
    StyleTrackedBars()
    PositionTrackedBars()
    if EssentialCooldownViewer and EssentialCooldownViewer.RefreshLayout then hooksecurefunc(EssentialCooldownViewer, "RefreshLayout", function() CenterWrappedIcons() end) end
    if UtilityCooldownViewer and UtilityCooldownViewer.RefreshLayout then hooksecurefunc(UtilityCooldownViewer, "RefreshLayout", function() CenterWrappedIcons() end) end
    if BuffBarCooldownViewer and BuffBarCooldownViewer.RefreshLayout then hooksecurefunc(BuffBarCooldownViewer, "RefreshLayout", function() if InCombatLockdown() then return end StyleTrackedBars() PositionTrackedBars() end) end
    for _, viewerName in ipairs(BCDM.CooldownManagerViewers) do
        C_Timer.After(0.1, function() ApplyCooldownText(viewerName) end)
    end

    C_Timer.After(1, function()
        if not InCombatLockdown() then
            LEMO:ApplyChanges()
        end
    end)
end

function BCDM:UpdateTrackedBars()
    if not ShouldSkin() then return end
    StyleTrackedBars()
    PositionTrackedBars()
end

function BCDM:UpdateCooldownViewer(viewerType)
    local cooldownManagerSettings = BCDM.db.profile.CooldownManager
    local cooldownViewerFrame = _G[BCDM.DBViewerToCooldownManagerViewer[viewerType]]
    local viewerSettings = cooldownManagerSettings[viewerType]
    local iconWidth, iconHeight = BCDM:GetIconDimensions(viewerSettings)
    if viewerType == "Custom" then BCDM:UpdateCustomCooldownViewer() return end
    if viewerType == "AdditionalCustom" then BCDM:UpdateAdditionalCustomCooldownViewer() return end
    if viewerType == "Item" then BCDM:UpdateCustomItemBar() return end
    if viewerType == "Trinket" then BCDM:UpdateTrinketBar() return end
    if viewerType == "ItemSpell" then BCDM:UpdateCustomItemsSpellsBar() return end
    if viewerType == "BuffBar" then BCDM:UpdateTrackedBars() return end
    if viewerType == "Buffs" then SetupCenterBuffs() end

    for _, childFrame in ipairs({cooldownViewerFrame:GetChildren()}) do
        if childFrame then
            if childFrame.Icon and ShouldSkin() then
                BCDM:StripTextures(childFrame.Icon)
                BCDM:ApplyIconTexCoord(childFrame.Icon, iconWidth, iconHeight, cooldownManagerSettings.General.IconZoom)
            end
            if childFrame.Cooldown then
                childFrame.Cooldown:ClearAllPoints()
                childFrame.Cooldown:SetPoint("TOPLEFT", childFrame, "TOPLEFT", 1, -1)
                childFrame.Cooldown:SetPoint("BOTTOMRIGHT", childFrame, "BOTTOMRIGHT", -1, 1)
                childFrame.Cooldown:SetSwipeColor(0, 0, 0, 0.8)
                childFrame.Cooldown:SetDrawEdge(false)
                childFrame.Cooldown:SetDrawSwipe(true)
                childFrame.Cooldown:SetSwipeTexture("Interface\\Buttons\\WHITE8X8")
            end
            if childFrame.CooldownFlash then childFrame.CooldownFlash:SetAlpha(0) end
            childFrame:SetSize(iconWidth, iconHeight)
        end
    end

    StyleIcons()

    Position()

    StyleChargeCount()

    ApplyCooldownText(BCDM.DBViewerToCooldownManagerViewer[viewerType])

    BCDM:UpdatePowerBarWidth()
    BCDM:UpdateSecondaryPowerBarWidth()
    BCDM:UpdateCastBarWidth()
end

function BCDM:UpdateCooldownViewers()
    BCDM:UpdateCooldownViewer("Essential")
    BCDM:UpdateCooldownViewer("Utility")
    BCDM:UpdateCooldownViewer("Buffs")
    BCDM:UpdateTrackedBars()
    BCDM:UpdateCustomCooldownViewer()
    BCDM:UpdateAdditionalCustomCooldownViewer()
    BCDM:UpdateCustomItemBar()
    BCDM:UpdateCustomItemsSpellsBar()
    BCDM:UpdateTrinketBar()
    BCDM:UpdatePowerBar()
    BCDM:UpdateSecondaryPowerBar()
    BCDM:UpdateCastBar()
end
