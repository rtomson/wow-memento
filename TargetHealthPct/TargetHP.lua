-- Move and adjust the default threat indicator
TargetFrameNumericalThreat:SetPoint("TOP", -15, -4)
TargetFrameNumericalThreat:SetWidth(60)
TargetFrameNumericalThreatBG:SetWidth(48)
TargetFrameNumericalThreatValue:SetFontObject("TextStatusBarText")
TargetFrameNumericalThreatValue:SetPoint("TOP", 0, -6)

-- Create the health pct indicator
pctFrame = CreateFrame("Frame", "$parentHealthPct", TargetFrame)
pctFrame:SetPoint("BOTTOM", TargetFrame, "TOP", -80, -22)
pctFrame:SetWidth(60)
pctFrame:SetHeight(18)

pctFrame.bg = pctFrame:CreateTexture("$parentBG", "BACKGROUND")
pctFrame.bg:SetWidth(48)
pctFrame.bg:SetHeight(14)
pctFrame.bg:SetPoint("TOP", 0, -3)
pctFrame.bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
pctFrame.bg:SetVertexColor(0, 1, 0)

pctFrame.border = pctFrame:CreateTexture("$parentBorder", "ARTWORK")
pctFrame.border:SetAllPoints( pctFrame)
pctFrame.border:SetTexture("Interface\\TargetingFrame\\NumericThreatBorder")
pctFrame.border:SetTexCoord(0.0, 0.765625, 0.0, 0.5625);

pctFrame.text = pctFrame:CreateFontString("$parentValue", "OVERLAY")
pctFrame.text:SetPoint("TOP", 0, -6)
pctFrame.text:SetFontObject("TextStatusBarText")
pctFrame.text:SetJustifyH("CENTER")

pctFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
pctFrame:SetScript("OnShow", function (frame) frame:RegisterEvent("UNIT_HEALTH") end)
pctFrame:SetScript("OnHide", function (frame) frame:UnregisterEvent("UNIT_HEALTH") end)
pctFrame:SetScript("OnEvent", function (frame, event)
    local hp = UnitHealth("target")
    if hp > 0 then
        frame:Show()
        hp = hp / UnitHealthMax("target") * 100
        frame.text:SetFormattedText("%.1f%%", hp)
        if hp <= 20 then
            frame.bg:SetVertexColor(1, 0, 0)
        elseif hp <= 25 then
            frame.bg:SetVertexColor(1, 1, 0)
        else
            frame.bg:SetVertexColor(0, 1, 0)
        end
    else
        frame:Hide()
    end
end)
