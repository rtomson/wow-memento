-- Move the pet list down
PetJournalListScrollFrame:SetPoint("TOPLEFT", PetJournalLeftInset, 3, -60)

-- Create the pet type buttons
for petType, suffix in ipairs(PET_TYPE_SUFFIX) do
    local btn = CreateFrame("Button", "PJ_QuickFamilyButton"..petType, PetJournalLeftInset)
    btn:SetSize(24, 24)
    btn:SetPoint("TOPLEFT", PetJournalLeftInset, 6 + 25 * (petType-1), -33)
    
    local background = btn:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\PetBattles\\PetBattleHud")
    background:SetTexCoord(0.92089844, 0.95410156, 0.34960938, 0.41601563)
    background:SetSize(23, 23)
    background:SetAllPoints()
    btn.Background = background
    
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\PetBattles\\PetIcon-"..suffix)
    icon:SetTexCoord(0.79687500, 0.49218750, 0.50390625, 0.65625000)
    icon:SetSize(22, 22)
    icon:SetPoint("CENTER")
    btn.Icon = icon
    
    local status = btn:CreateTexture(nil, "OVERLAY")
    status:Hide()
    status:SetTexture("Interface\\PetBattles\\PetBattleHud")
    status:SetTexCoord(0.94921875, 0.99414063, 0.67382813, 0.76367188)
    status:SetSize(30, 30)
    status:SetPoint("CENTER")
    btn.ActiveStatus = status
    
    local highlight = btn:CreateTexture("Highlight", "OVERLAY")
    highlight:SetTexture("Interface\\PetBattles\\PetBattleHud")
    highlight:SetTexCoord(0.94921875, 0.99414063, 0.67382813, 0.76367188)
    highlight:SetSize(30, 30)
    highlight:SetPoint("CENTER")
    highlight:Hide()
    btn:SetHighlightTexture(highlight, "BLEND")
    
    btn.isActive = false
    btn.petType = petType
    
    btn:RegisterForClicks("LeftButtonUp")
    btn:SetScript("OnMouseUp",
        function(self)
            for petType, suffix in ipairs(PET_TYPE_SUFFIX) do
                local btn = _G["PJ_QuickFamilyButton"..petType]
                btn.ActiveStatus:Hide()
                if not self == btn then
                    btn.isActive = false
                end
            end
            
            if false == self.isActive then
                btn.ActiveStatus:Show()
                C_PetJournal.ClearAllPetTypesFilter()
                C_PetJournal.SetPetTypeFilter(self.petType, true)
            else
                C_PetJournal.AddAllPetTypesFilter()
            end
            self.isActive = not self.isActive
        end
    )
end