function TargetHealthPct_OnLoad (self)
    -- Move and adjust the default threat indicator
    local threatFrame = TargetFrameNumericalThreat
    threatFrame:SetPoint("TOP", -15, -4)
    threatFrame:SetWidth(60)
    threatFrame.bg:SetWidth(48)
    threatFrame.text:SetFontObject("TextStatusBarText")
    threatFrame.text:SetPoint("TOP", 0, -6)
    
    self:RegisterEvent("PLAYER_TARGET_CHANGED")
    self:RegisterEvent("UNIT_HEALTH")
end

function TargetHealthPct_OnEvent (self, event, ...)
    if not "target" == ... then
        return
    end
    
    local unitCurrHP, unitHPMax = UnitHealth("target"), UnitHealthMax("target")
    local unitHPPercent = unitCurrHP / unitHPMax
    if unitHPPercent > 0 then
        if unitHPPercent <= 0.2 then
            self.bg:SetVertexColor(1.0, 0.0, 0.0)
        elseif unitHPPercent <= 0.25 then
            self.bg:SetVertexColor(1.0, 1.0, 0.0)
        else
            self.bg:SetVertexColor(0.0, 1.0, 0.0)
        end
        self.text:SetFormattedText("%.1f%%", unitHPPercent * 100)
    end
end
