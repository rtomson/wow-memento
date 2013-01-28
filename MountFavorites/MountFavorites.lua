--===========================================================================--
-- Addon Initialization
--===========================================================================--

local addonName, addon = ...
local L = addon.L

local _G = _G
local GetCompanionInfo = _G.GetCompanionInfo
local GetNumCompanions = _G.GetNumCompanions
--local IsMounted = _G.IsMounted
--local DismissCompanion = _G.DismissCompanion
--local UnitInVehicle = _G.UnitInVehicle
--local VehicleExit = _G.VehicleExit

local LibMounts = LibStub("LibMounts-1.0")
MountFavorites_LibMounts = LibMounts
local AIR, GROUND, WATER = LibMounts.AIR, LibMounts.GROUND, LibMounts.WATER

local MOUNT_JOURNAL_ADDON = "Blizzard_PetJournal"
local MAX_ACCOUNT_MACROS = MAX_ACCOUNT_MACROS or 36
local MAX_NUM_FAVORITES = 14
local PLAYER_MOUNT_LEVEL = 20

local MOUNT_FLAG_GROUND = 0x01
local MOUNT_FLAG_FLYING = 0x02
local MOUNT_FLAG_UNDERWATER = 0x08

-- Bindings
_G["BINDING_NAME_CLICK MountFavorites.MountButton"] = L["Random Favorite"]
BINDING_HEADER_MOUNT_FAVORITES = L["Mount Favorites"]


--------------------------------------------------
-- Debug
--------------------------------------------------
local function Log(...)
    if MountFavoritesDB and MountFavoritesDB.debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff7d0aDebug:|r "..tostring(...))
    end
end


--------------------------------------------------
-- MountJournal modifications
--------------------------------------------------
local function MountFavorites_ModifyMountJournalFrame()
    -- Modifies the Mount Journal to make room for our UI
    local mj = MountJournal
    local md = mj.MountDisplay
    local mf = md.ModelFrame
    
    mj.RightInset:SetPoint("BOTTOMLEFT", mj.LeftInset, "BOTTOMRIGHT", 20, 140)
    mf:SetPoint("BOTTOMRIGHT", md, "BOTTOMRIGHT", 0, 0)
    mf.RotateLeftButton:Hide()
    mf.RotateRightButton:Hide()
    md.Name:SetPoint("BOTTOM", md, "TOP", 0, -30)
    
    MountFavoritesMountButtonLabel:SetText(L["Mount Favorites"])
end


--------------------------------------------------
-- Macro settings
--------------------------------------------------
local MACRO_NAME, MACRO_ICON, MACRO_BODY = addonName, "Spell_Nature_Swiftness", string.format([[
/run if MountFavorites then MountFavorites_Mount()else UIErrorsFrame:AddMessage("%s",1,0.1,0.1)end
]], L["MountFavorites addon not loaded!"])

local function MountFavorites_SetupMacro()
    if InCombatLockdown() then
        return
    end
    if GetNumMacros() >= MAX_ACCOUNT_MACROS then
        DEFAULT_CHAT_FRAME:AddMessage(L["Cannot create macro; no macro slots available."])
        return
    end
    -- Having the macro frame open causes issues with CreateMacro/EditMacro
    if MacroFrame then
        HideUIPanel(MacroFrame)
    end
    
    local index = GetMacroIndexByName(MACRO_NAME)
    if 0 == index then
        return CreateMacro(MACRO_NAME, MACRO_ICON, MACRO_BODY, nil)
    else
        return EditMacro(index, MACRO_NAME, MACRO_ICON, MACRO_BODY)
    end
end


--------------------------------------------------
-- Main mount function
--------------------------------------------------
function MountFavorites_GetFavoriteMountIDs(flags)
    -- mountFlags - A bitfield that indicates mount capabilities
    -- 0x01 - Ground mount
    -- 0x02 - Flying mount
    -- 0x04 - Usable at the water's surface
    -- 0x08 - Usable underwater
    -- 0x10 - Can jump (the turtle mount cannot, for example)
    
    -- GetCompanionInfo Examples
    -- Flying:          32158, "Albino Drake",      60025, _,  7 (0000 0111)
    -- Swimming:        40054, "Abyssal Seahorse",  75207, _, 12 (0000 1100)
    -- Ground:          24379, "Amani War Bear",    43688, _, 29 (0001 1101)
	-- Ground/Flying:   33857, "Argent Hippogryph", 63844, _, 31 (0001 1111)
    local mountIDs = {}
    flags = flags or MOUNT_FLAG_FLYING
    
    for i=1, MAX_NUM_FAVORITES do
        if MountFavoritesDB.mounts[i] then
            local mountType, mountID = unpack(MountFavoritesDB.mounts[i])
            if "mount" == mountType then
                local index = MountFavorites_FindMountSpell(mountID)
                local _, _, _, _, _, mountFlags = GetCompanionInfo("MOUNT", index)
                if bit.band(flags, mountFlags) > 0 and IsUsableSpell(mountID) then
                    table.insert(mountIDs, index)
                end
            end
        end
    end
    return mountIDs
end

function MountFavorites_OnLoad(self)
    -- Events
    self:RegisterEvent("COMPANION_LEARNED")
    self:RegisterEvent("COMPANION_UNLEARNED")
    self:RegisterEvent("SPELL_UPDATE_USABLE")
    --self:RegisterEvent("WORLD_MAP_UPDATE")
    
    -- If mount journal addon hasn't been loaded, register an event callback to
    -- call this function when it does load.
    --[[
    if (not IsAddOnLoaded(MOUNT_JOURNAL_ADDON)) then
        self:Disable()
        MF:Log("Registering event to enable addon after mount journal has loaded")
        self:RegisterEvent("ADDON_LOADED", 
            function(eventName, addonName)
                if addonName == MOUNT_JOURNAL_ADDON then
                    MF:Log("Mount journal Loaded")
                    self:UnregisterEvent("ADDON_LOADED")
                    self:Enable()
                end
            end
        )
        return
    end
    ]]
    
    -- Hooks
    MountJournal:HookScript("OnShow", MountFavorites_OnShow)
    --MountJournal:HookScript("OnHide", MountFavorites_OnHide)
    
    -- Setup buttons
    local lastButton = MountFavoritesButton1
    for i=1, MAX_NUM_FAVORITES do
        local button = _G["MountFavoritesButton"..i]
        if not button then
            button = CreateFrame("BUTTON", "MountFavoritesButton"..i, MountFavorites, "MountFavoritesButtonTemplate")
            if mod(i, floor(MAX_NUM_FAVORITES / 2)) == 1 then
                button:SetPoint("TOP", _G["MountFavoritesButton"..(i - floor(MAX_NUM_FAVORITES / 2))], "BOTTOM", 0, -2)
            else
                button:SetPoint("LEFT", lastButton, "RIGHT", 2, 0)
            end
        end
        button.slot = i
        lastButton = button
    end
    
    -- DB settings
    if type(MountFavoritesDB) ~= "table" then
        MountFavoritesDB = {
            mounts = {}
        }
    end
    
    -- Make room for our UI
    MountFavorites_ModifyMountJournalFrame()
    
    --MountFavorites_UpdateButtons()
end

function MountFavorites_OnEvent(self, event)
    --Log(time()..": "..event)
    if "SPELL_UPDATE_USABLE" == event and MountFavorites:IsVisible() then
        MountFavorites_Update()
    end
end

function MountFavorites_OnShow()
    -- Set any saved mounts
    --local button
    --for i=1, MAX_NUM_FAVORITES do
    --    button = _G["MountFavoritesButton"..i]
    --    button.spellID = MountFavoritesDB.mounts[i]
    --end
    MountFavorites_Update()
    MountFavorites:Show()
end

local function MountFavorites_ResetButton(index)
    local button = _G["MountFavoritesButton"..index]
    if button then
        button.icon:SetTexture(nil)
        button.lock:Hide()
        button.mountType = nil
        button.mountID = nil
    end
end

function MountFavorites_Update()
    -- Update the button attributes
    for i=1, MAX_NUM_FAVORITES do
        local button = _G["MountFavoritesButton"..i]
        local mountType, mountID
        if MountFavoritesDB.mounts[i] then
            mountType, mountID = unpack(MountFavoritesDB.mounts[i])
        end
        if "mount" == mountType or "spell" == mountType then
            local icon, mountFlags
            if "mount" == mountType then
                local index = MountFavorites_FindMountSpell(mountID)
                _, _, _, icon, _, mountFlags = GetCompanionInfo("MOUNT", index)
                button.mountFlags = mountFlags
                button.mountIndex = index
            else
                _, _, icon = GetSpellInfo(mountID)
            end
            button.icon:SetTexture(icon)
            button.mountID = mountID
            button.mountType = mountType
            
            -- Check if we can use this mount
            if IsUsableSpell(mountID) then
                button.additionalText = nil
                button.icon:SetDesaturated(0)
                button.icon:SetAlpha(1.0)
                button.lock:Hide()
            else
                button.additionalText = MOUNT_JOURNAL_CANT_USE
                button.icon:SetDesaturated(1)
                button.icon:SetAlpha(0.5)
                button.lock:Show()
            end
        elseif "item" == mountType then
            -- TODO: Make this compatible with items like Magic Broom
            MountFavorites_ResetButton(i)
        else
            MountFavorites_ResetButton(i)
        end
    end
end

function MountFavorites_FindMountSpell(spellID)
    for i=1, GetNumCompanions("MOUNT") do
        local _, _, _spellID, _, _ = GetCompanionInfo("MOUNT", i)
        if _spellID == spellID then
            return i
        end
    end
    return nil
end

function MountFavorites_SaveFavorites()
    local button
    for i=1, MAX_NUM_FAVORITES do
        button = _G["MountFavoritesButton"..i]
        if button.mountType then
            MountFavoritesDB.mounts[i] = {button.mountType, button.mountID}
        else
            MountFavoritesDB.mounts[i] = nil
        end
    end
end

function MountFavorites_UpdateButtons2()
    local numMounts = 0
    local playerLevel = UnitLevel("player")
    
    for i=1, MAX_NUM_FAVORITES do
        local button, index
        
        button = _G["MountFavoritesButton"..i]
        index = button.index or MountFavorites_FindMountSpell(button.spellID)
        
        if index then
            local creatureID, creatureName, spellID, icon, active, mountFlags = GetCompanionInfo("MOUNT", index)
            
            button.icon:SetTexture(icon)
            button.index = index
            button.spellID = spellID
            button.mountFlags = mountFlags
            
            -- Check if the player can use the mount
            --button:SetEnabled(1)
            if playerLevel >= PLAYER_MOUNT_LEVEL and IsUsableSpell(spellID) then
                button.additionalText = nil
                button.icon:SetDesaturated(0)
                button.icon:SetAlpha(1.0)
                button.lock:Hide()
                numMounts = numMounts + 1
            else
                button.additionalText = MOUNT_JOURNAL_CANT_USE
                button.icon:SetDesaturated(1)
                button.icon:SetAlpha(0.5)
                button.lock:Show()
            end
        else
            button.icon:SetTexture(nil)
            button.lock:Hide()
            button.spellID = nil
        end
    end
    
    if playerLevel >= PLAYER_MOUNT_LEVEL and numMounts > 0 then
        MountFavorites.MountButton:SetEnabled(1)
    else
        MountFavorites.MountButton:SetEnabled(0)
    end
    
    -- Mount macro texture
    -- TODO: Get riding skill icon
    MountFavoritesMountButton.icon:SetTexture("Interface\\Icons\\spell_nature_swiftness")
end


------------------------------------------------------------
-- UI functions
------------------------------------------------------------
function MountFavoritesButton_OnDragStart(self)
    if "mount" == self.mountType or "spell" == self.mountType then
        PickupSpell(self.mountID)
        MountFavorites_ResetButton(self.slot)
    end
end

function MountFavoritesButton_OnDragStop(self)
    MountFavorites_SaveFavorites()
end

function MountFavoritesButton_OnMouseUp(self, button)
    -- TODO: Accept certain spells (druid) and items (halloween broom)
    if GetCursorInfo() then
        MountFavoritesButton_OnReceiveDrag(self)
    elseif "LeftButton" == button and self.mountIndex then
        MountJournal_Select(self.mountIndex)
    elseif "RightButton" == button and self.mountIndex then
        CallCompanion("MOUNT", self.mountIndex)
    end
end

function MountFavoritesButton_OnReceiveDrag(self)
    -- TODO: Accept certain spells (druid) and items (halloween broom)
    local prevType, prevID = self.mountType, self.mountID
    local type, data, subType = GetCursorInfo()
    if "companion" == type and "MOUNT" == subType then
        local _, _, spellID, _, _ = GetCompanionInfo("MOUNT", data)
        self.mountType = "mount"
        self.mountID = spellID
        MountFavorites_SaveFavorites()
        MountFavorites_Update()
    else
        return
    end
    
    -- Pickup the previous item
    ClearCursor()
    if "mount" == prevType or "spell" == prevType then
        PickupSpell(prevID)
    end
end

function MountFavoritesMountButton_OnClick(self)
    MountFavorites_Mount()
end

function MountFavorites_Mount()
    -- local isFalling, isFlying, isMounted, isSwimming, inVehicle = IsFalling(), IsFlying(), IsMounted(), IsSwimming(), UnitInVehicle("player")
    
    -- Dismount and exit all vehicles
    if IsMounted() then
        DismissCompanion("MOUNT")
        return
    elseif UnitInVehicle("player") then
        VehicleExit()
        return
    end
    
    -- TODO: Druid hacks?
    -- 33943 - Flight Form
    -- 40120 - Swift Flight Form
    
    local primary, secondary, tertiary = LibMounts:GetCurrentMountType()
    if not primary then
        if IsSwimming() then
            primary, secondary = WATER, GROUND
        else
            primary = GROUND
        end
    end
    
    -- TODO: isFalling?
    local mountIDs
    if IsModifiedClick("CHATLINK") then
        -- Force a ground mount if the CHATLINK (shift) key is held
        mountIDs = MountFavorites_GetFavoriteMountIDs(MOUNT_FLAG_GROUND)
    elseif isSwimming then
        mountIDs = MountFavorites_GetFavoriteMountIDs(MOUNT_FLAG_UNDERWATER)
    else
        mountIDs = MountFavorites_GetFavoriteMountIDs(MOUNT_FLAG_FLYING)
    end
    
    if mountIDs and #mountIDs > 0 then
        Log("Found " .. #mountIDs .. " mounts")
        CallCompanion("MOUNT", mountIDs[math.random(#mountIDs)])
    else
        UIErrorsFrame:AddMessage(L["No mounts available."], 1.0, 0.1, 0.1, 1.0)
    end
end

function MountFavoritesMountButton_OnDragStart(self)
    local index = MountFavorites_SetupMacro()
    if index then
        ClearCursor()
        PickupMacro(index)
    end
end

function MountFavoritesMountButton_OnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
    GameTooltip:SetMinimumWidth(150);
    GameTooltip:SetText(L["Random Favorite"], 1, 1, 1)
    GameTooltip:AddLine(L["Summons a random mount from your list of favorites. The mount chosen depends on your Riding skill and location."], nil, nil, nil, true)
    GameTooltip:Show()
end
