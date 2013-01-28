--===========================================================================--
-- Addon Initialization
--===========================================================================--

-- Initialize addon
local MF = CreateFrame("Frame")
MF.debug = 0

-- Name of the Blizzard Mount Journal addon
local MOUNT_JOURNAL_ADDON = "Blizzard_PetJournal"
local MAX_NUM_FAVORITES = 14
local PLAYER_MOUNT_LEVEL = 20
-- mountFlags
local MOUNT_FLAG_GROUND = 0x01
local MOUNT_FLAG_FLYING = 0x02
local MOUNT_FLAG_UNDERWATER = 0x08

local MACRO_NAME = "MountFavorites"

-- TODO: Localize
MOUNT_FAVORITES_NO_MOUNTS = "No mounts available"
MOUNT_FAVORITES_RANDOM_FAVORITE = "Random Favorite"
MOUNT_FAVORITES_RANDOM_FAVORITE_TOOLTIP = "Summons a random mount from your list of favorites. The mount chosen depends on your Riding skill and location."

function MF:Log(...)
    if 1 == self.debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff7d0aDebug:|r "..tostring(...))
    end
end


function MountFavorites_CreateMountMacro()
    -- Can't work with macros while in combat
    if InCombatLockdown() then
        return
    end
    if GetNumMacros() >= (MAX_ACCOUNT_MACROS or 36) then
        print("Cannot create macro; no macro slots available.")
        return
    end
    -- Having the macro frame open causes issues with Create/EditMacro
    if MacroFrame then
        HideUIPanel(MacroFrame)
    end
    
    --local body = '/run if "RightButton" == GetMouseButtonClicked() then TogglePetJournal(1) else local f=MountFavorites if f then f.MountButton:Click() else print("MountFavorites not loaded!") end end'
    local body = '#show Apprentice Riding\n/click [button:2] CompanionsMicroButton; MountFavoritesMountButton'
    local index = GetMacroIndexByName(MACRO_NAME)
    if 0 == index then
        index = CreateMacro(MACRO_NAME, 0, body, nil)
    end
    return EditMacro(index, MACRO_NAME, "INV_MISC_QUESTIONMARK", body)
    --return EditMacro(index, MACRO_NAME, "ACHIEVEMENT_GUILDPERK_MOUNTUP", body)
end

function MountFavorites_GetFavoriteMountIDs(mountFlags)
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
    local button, mountIDs, n = nil, nil, 1
    mountFlags = mountFlags or MOUNT_FLAG_FLYING
    
    for i=1, MAX_NUM_FAVORITES do
        button = _G["MountFavoritesButton"..i]
        if button.index and bit.band(button.mountFlags, mountFlags) > 0 and IsUsableSpell(button.spellID) then
            if 1 == n then
                mountIDs = {button.index}
            else
                mountIDs[n] = button.index
            end
            n = n + 1
        end
    end
    return mountIDs
end

function MountFavorites_OnEvent(self, event, name)
    if "ADDON_LOADED" == event and name ~= "Blizzard_DebugTools" then
        self:UnregisterEvent("ADDON_LOADED")
        
        -- Force the PetJournal to load
        if not IsAddOnLoaded("Blizzard_PetJournal") then
          -- TODO:
          -- This causes an issue with Squire2's loading process
          --PetJournal_LoadUI()
          --return
        end
        
        -- Adjust the Mount Journal UI
        local mountDisplay = MountJournal.MountDisplay
        local modelFrame = MountJournal.MountDisplay.ModelFrame
        -- Main display frame
        MountJournal.RightInset:SetPoint("BOTTOMLEFT", MountJournal.LeftInset, "BOTTOMRIGHT", 20, 140)
        -- Model
        modelFrame:SetPoint("BOTTOMRIGHT", mountDisplay, "BOTTOMRIGHT", 0, 0)
        -- Rotate buttons
        modelFrame.RotateLeftButton:Hide()
        modelFrame.RotateRightButton:Hide()
        -- Name
        mountDisplay.Name:SetPoint("BOTTOM", mountDisplay, "TOP", 0, -30)
        
        -- TODO: Change the mount name to look better? See the EncounterJournal boss model frame
        --<Texture name="UI-EJ-BossNameShadow" file="Interface\EncounterJournal\UI-EncounterJournalTextures" virtual="true" >
        --    <Size x="395" y="63"/>	
        --    <TexCoords left="0.00195313" right="0.77343750" top="0.26953125" bottom="0.33105469"/>	
        --</Texture>
        --<Layer level="OVERLAY" textureSubLevel="1">
        --	<Texture name="$parentTitleBG" inherits="UI-EJ-BossNameShadow">
        --		<Anchors>
        --			<Anchor point="BOTTOM" x="0" y="0"/>
        --		</Anchors>
        --	</Texture>
        --</Layer>
        --<Layer level="OVERLAY" textureSubLevel="2">
        --    <FontString name="$parentImageTile" inherits="QuestTitleFontBlackShadow" justifyH="CENTER" parentKey="imageTitle">
        --        <Size x="380" y="10"/>
        --        <Anchors>
        --            <Anchor point="BOTTOM" x="0" y="8"/>
        --        </Anchors>
        --    </FontString>
        --</Layer>

        -- If mount journal addon hasn't been loaded, register an event callback to
        -- call this function when it does load.
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
        
        -- Create hooks
        MountJournal:HookScript("OnShow", MountFavorites_OnShow)
        MountJournal:HookScript("OnHide", MountFavorites_OnHide)
        
        -- Default settings
        if type(MountFavoritesDB) ~= "table" then
            MountFavoritesDB = {
                mounts = {}
            }
        end
    elseif "COMPANION_LEARNED" == event or "COMPANION_UNLEARNED" == event or "COMPANION_UPDATE" == event then
        MountFavorites_UpdateButtons()
    end
end

function MountFavorites_OnHide()
    MountFavorites:Hide()
    MountFavorites_SaveFavorites()
end

function MountFavorites_OnLoad()
    -- TODO: Implement these
    self:RegisterEvent("COMPANION_LEARNED")
    self:RegisterEvent("COMPANION_UNLEARNED")
    self:RegisterEvent("COMPANION_UPDATE")
end

function MountFavorites_OnShow()
    -- Set any saved mounts
    local button
    for i=1, MAX_NUM_FAVORITES do
        button = _G["MountFavoritesButton"..i]
        button.spellID = MountFavoritesDB.mounts[i]
    end
    MountFavorites_UpdateButtons()
    MountFavorites:Show()
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
        MountFavoritesDB.mounts[i] = button.spellID
    end
end

function MountFavorites_UpdateButtons()
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
function MountFavoritesButton_OnDragStop(self)
    MountFavorites_SaveFavorites()
end

function MountFavoritesButton_OnMouseUp(self, button)
    -- TODO: Accept certain spells (druid) and items (halloween broom)
    if GetCursorInfo() then
        MountFavoritesButton_OnReceiveDrag(self)
    elseif "LeftButton" == button and self.index then
        MountJournal_Select(self.index)
    elseif "RightButton" == button and self.index then
        CallCompanion("MOUNT", self.index)
    end
end

function MountFavoritesButton_OnReceiveDrag(self)
    -- TODO: Accept certain spells (druid) and items (halloween broom)
    local type, data, subType = GetCursorInfo()
    if "companion" == type and "MOUNT" == subType then
        local lastSpellID = self.spellID
        local _, _, spellID, _, _ = GetCompanionInfo("MOUNT", data)
        self.spellID = spellID
        MountFavorites_UpdateButtons()
        MountFavorites_SaveFavorites()
        
        ClearCursor()
        if lastSpellID then
            PickupSpell(lastSpellID)
        end
    end
end

function MountFavoritesFrame_OnLoad(self)
    -- Create the rest of the favorite buttons
    local button, lastButton
    local offsetX, offsetY = 2, -2 -- 12, -8
    lastButton = MountFavoritesButton1
    lastButton.slot = 1
    for i=2, MAX_NUM_FAVORITES do
        button = CreateFrame("BUTTON", "MountFavoritesButton"..i, MountFavorites, "MountFavoritesButtonTemplate")
        if mod(i, floor(MAX_NUM_FAVORITES / 2)) == 1 then
            button:SetPoint("TOP", _G["MountFavoritesButton"..(i - floor(MAX_NUM_FAVORITES / 2))], "BOTTOM", 0, offsetY)
        else
            button:SetPoint("LEFT", lastButton, "RIGHT", offsetX, 0)
        end
        lastButton = button
        lastButton.slot = i
    end
    MountFavorites_UpdateButtons()
end

function MountFavoritesMountButton_OnClick(self)
    local isFalling, isFlying, isMounted, isSwimming, inVehicle = IsFalling(), IsFlying(), IsMounted(), IsSwimming(), UnitInVehicle("player")
    
    -- Dismount and exit all vehicles
    if isMounted then
        DismissCompanion("MOUNT")
        return
    elseif inVehicle then
        VehicleExit()
        return
    end
    
    -- TODO: Druid hacks?
    -- 33943 - Flight Form
    -- 40120 - Swift Flight Form
    
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
    
    if mountIDs then
        MF:Log("Found " .. #mountIDs .. " mounts")
        CallCompanion("MOUNT", mountIDs[math.random(#mountIDs)])
    else
        UIErrorsFrame:AddMessage(MOUNT_FAVORITES_NO_MOUNTS, 1.0, 0.1, 0.1, 1.0)
    end
end

function MountFavoritesMountButton_OnDragStart(self)
    -- Can't work with macros while in combat
    if not InCombatLockdown() then
        local index = MountFavorites_CreateMountMacro()
        if index then
            ClearCursor()
            PickupMacro(index)
        end
    end
end

function MountFavoritesMountButton_OnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
    GameTooltip:SetMinimumWidth(150);
    GameTooltip:SetText(MOUNT_FAVORITES_RANDOM_FAVORITE, 1, 1, 1)
    GameTooltip:AddLine(MOUNT_FAVORITES_RANDOM_FAVORITE_TOOLTIP, nil, nil, nil, true)
    GameTooltip:Show()
end

------------------------------------------------------------
-- Event Hooks
------------------------------------------------------------
MF:SetScript("OnEvent", MountFavorites_OnEvent)
MF:RegisterEvent("ADDON_LOADED")
