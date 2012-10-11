Memento = CreateFrame("Frame")

-- Constants
local BANK_BAGID = NUM_BAG_SLOTS + NUM_BANKBAGSLOTS + 1
local CURRENT_VERSION = GetAddOnMetadata("Memento_ItemCount", "Version")
--local DEBUG = 1
local GREEN = "|cff00ff00%s|r"
local L = MEMENTO_LOCALS
local MAIL_BAGID = BANK_BAGID + 1
local NUM_EQUIPMENT_SLOTS = 19
local RED = "|cffff0000%s|r"
local SILVER = "|cffc7c7cf%s|r"
local TEAL = "|cff00ff9a%s|r"

-- Locals
local currentRealm = GetRealmName()
local currentGuild = nil
local currentPlayer = UnitName("player")
local itemCache = {}


--[[  Events ]]--
-- Handle events
Memento:RegisterEvent("ADDON_LOADED")
Memento:SetScript("OnEvent", function(self, event, ...)
    self:Debug(event)
    if Memento[event] then
        Memento[event](self, ...)
    end
end)

-- Fires when an addon and its saved variables are loaded.
function Memento:ADDON_LOADED(name)
    if not "Memento_ItemCount" == name then
        return
    end
    
    self:UnregisterEvent("ADDON_LOADED")
    -- Load the database to populate the item cache
    Memento:LoadDB()
    
    -- Hook up the tooltip
    GameTooltip:HookScript("OnTooltipSetItem",
        function(self)
            local name, link = self:GetItem()
            if link and GetItemInfo(link) then
                Memento:SetTooltipInfo(self, link)
            end
        end
    )
    
    -- Slash command
    SLASH_MEMENTO1, SLASH_MEMENTO2 = "/mem", "/memento"
    SlashCmdList["MEMENTO"] = function(cmd)
        self:SlashCommand(cmd)
    end
    
    -- Events
    self:RegisterEvent("PLAYER_LOGIN")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
end

-- Fires when the contents of one of the player's containers change.
function Memento:BAG_UPDATE(bagID)
    self:SaveBag(bagID)
    self:UpdateItemCache()
end

-- Fires when the player ends interaction with a bank.
function Memento:BANKFRAME_CLOSED()
    self.atBank = false
end

-- Fires when the player begins interaction with a bank.
function Memento:BANKFRAME_OPENED()
    self.atBank = true
    -- Only need to save the entire bank once. After that, it's upkeep
    if not self.bankSaved then
        self:SaveBank()
        self:UpdateItemCache()
    end
end

-- Fires when information about the contents of guild bank item slots changes
-- or becomes available.
function Memento:GUILDBANKBAGSLOTS_CHANGED()
    if self.atGuildBank then
        self:SaveGuildBank()
        self:UpdateItemCache()
    end
end

-- Fires when the player ends interaction with the guild bank.
function Memento:GUILDBANKFRAME_CLOSED()
    self.atGuildBank = false
end

-- Fires when the player begins interaction with the guild bank.
function Memento:GUILDBANKFRAME_OPENED()
    if not currentGuild then
        self:UpdateCurrentGuild()
    end
    self.atGuildBank = true
end

-- Fires when the player ends interaction with a mailbox.
function Memento:MAIL_CLOSED()
    self.atMail = false
end

-- Fires when information about the contents of the player's inbox changes or
-- becomes available.
function Memento:MAIL_INBOX_UPDATE()
    if self.atMail then
        self:SaveMail()
        self:UpdateItemCache()
    end
end

-- Fires when the player begins interaction with a mailbox.
function Memento:MAIL_SHOW()
    self.atMail = true
end

-- Fires when the contents of a bank slot or bank bag slot are changed.
function Memento:PLAYERBANKSLOTS_CHANGED(slotID)
    -- slotID: 1-28 are the bank slots, 29-35 are the bank bags
    self:Debug(format("slotID: %i changed", slotID))
    self:SaveBank()
    self:UpdateItemCache()
end

-- Fired when the player enters the world, reloads the UI, enters/leaves an
-- instance or battleground, or respawns at a graveyard. Also fires any other
-- time the player sees a loading screen.
function Memento:PLAYER_ENTERING_WORLD()
    -- Only needed for initial item processing and BAG_UPDATE hook
    --self:UnRegisterEvent("PLAYER_ENTERING_WORLD")
    
    -- GuildInfo is nil when first logging in so we set it here
    self:UpdateCurrentGuild()
    
    -- Refresh the item data for all bags
    self:SaveBags()
    self:UpdateItemCache()
    
    -- Register BAG_UPDATE here instead of PLAYER_LOGIN because BAG_UPDATE
    -- fires many times (once for each slot in each container) during the
    -- login / UI load process.
    self:Debug("RegisterEvent: BAG_UPDATE")
    self:RegisterEvent("BAG_UPDATE")
end


-- Fires when information about the player's guild membership changes.
function Memento:PLAYER_GUILD_UPDATE(unitID)
    if "player" == unitID then
        self:UpdateCurrentGuild()
    end
end

-- Fires immediately before PLAYER_ENTERING_WORLD on login and UI reload.
-- But unlike PLAYER_ENTERING_WORLD, this event ONLY fires for login/reload.
function Memento:PLAYER_LOGIN()
    self:RegisterEvent("BANKFRAME_OPENED")
    self:RegisterEvent("BANKFRAME_CLOSED")
    self:RegisterEvent("GUILDBANKBAGSLOTS_CHANGED")
    self:RegisterEvent("GUILDBANKFRAME_OPENED")
    self:RegisterEvent("GUILDBANKFRAME_CLOSED")
    self:RegisterEvent("MAIL_CLOSED")
    self:RegisterEvent("MAIL_INBOX_UPDATE")
    self:RegisterEvent("MAIL_SHOW")
    self:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
end


--[[ DB Functions ]]--
-- Prints (message) to the chatbox if DEBUG is on
function Memento:Debug(message)
    if DEBUG then
        DEFAULT_CHAT_FRAME:AddMessage(format(TEAL, "Memento: ") .. message)
    end
end

-- Prints (message) to the chatbox
function Memento:Print(message)
    DEFAULT_CHAT_FRAME:AddMessage(message)
end

-- Returns the itemID of (link)
function Memento:ItemLinkToID(link)
    return link:match("item:(%d+)")
end

-- Loads the item database
function Memento:LoadDB ()
    --[[
        Database is this format:
        {
            "<RealmName>": {
                "guilds": {
                    "<GuildName>": {
                        tab: {
                            itemID: <count>,
                            ...
                        }, ...
                    }, ...
                },
                "players": {
                    "<PlayerName>": {
                        "bagID": {  -- 0-4: Character's bags
                                    -- 5-11: Bank bags
                                    -- BANK_BAGID: Bank itself
                                    -- MAIL_BAGID: Bank itself
                            itemID: [<count>],
                            ...
                        }, ...
                    }, ...
                }
            }, ...
        }
    ]]
    if not (MementoDB and MementoDB.version) or (2 == DEBUG) then
        MementoDB = {version = CURRENT_VERSION}
    else
        -- Future support for updating database formats
        local curMajor, curMinor = CURRENT_VERSION:match("(%d+)%.(%d+)")
        local major, minor = MementoDB.version:match("(%d+)%.(%d+)")
        
        -- Convert or update the db if needed
        if major ~= curMajor then
            -- TODO: Convert database
            MementoDB = {version = CURRENT_VERSION}
        elseif minor ~= curMinor then
            self:UpdateDB()
        end
        
        -- Set the current version
        if MementoDB.version ~= CURRENT_VERSION then
            MementoDB.version = CURRENT_VERSION
            print(format("Memento: DB updated to v%s", MementoDB.version))
        end
    end
    
    self.DB = MementoDB
    if not self.DB[currentRealm] then
        self:Debug("New realm: " .. currentRealm)
        self.DB[currentRealm] = {
            guilds = {},
            players = {}
        }
    end
    self.realmDB = self.DB[currentRealm]
    
    -- guildDB is handled in PLAYER_ENTER_WORLD --
    
    if not self.realmDB["players"][currentPlayer] then
        self:Debug("New player: " .. currentPlayer)
        self.realmDB["players"][currentPlayer] = {}
    end
    self.playerDB = self.realmDB["players"][currentPlayer]
    
    if not self.DB["options"] then
        self.DB["options"] = {}
    end
    self.options = self.DB["options"]
end

-- Removes all saved data about (name) and returns after the first one found
function Memento:RemoveNameFromDB(name)
    -- Players
    for player, playerDB in pairs(self.realmDB["players"]) do
        if player == name then
            self.realmDB["players"][name] = nil
            return true
        end
    end
    -- Guilds
    for guild, guildDB in pairs(self.realmDB["guilds"]) do
        if guild == name then
            self.realmDB["guilds"][name] = nil
            return true
        end
    end
    -- Realms
    for realm, realmDB in pairs(self.DB) do
        if realm == name then
            self.DB[name] = nil
            return true
        end
    end
    return false
end

-- Saves data about the container (bagID)
function Memento:SaveBag(bagID)
    self:Debug("Saving bagID: " .. bagID)
    
    local bagDB = {}
    local numSlots = GetContainerNumSlots(bagID)
    if not (numSlots > 0) then
        self:Debug(format("bagID: %i has size of %i",
                             tonumber(bagID), numSlots))
    else
        local id, count
        -- Don't forget the bag itself (except backpack)
        if not (0 == bagID) then
            local inventoryID = ContainerIDToInventoryID(bagID)
            id = GetInventoryItemID("player", inventoryID)
            count = GetInventoryItemCount("player", inventoryID)
            bagDB[id] = {count}
        end
        for slot = 1, numSlots do
            id = GetContainerItemID(bagID, slot)
            if id then
                local texture, count, locked, quality, readable,
                      lootable, link = GetContainerItemInfo(bagID, slot)
                if bagDB[id] then
                    count = bagDB[id][1] + count
                end
                bagDB[id] = {count}
            end
        end
    end
    
    self.playerDB[bagID] = bagDB
end

-- Saves data about all the player's bags
function Memento:SaveBags()
    self:Debug("Saving all bags")
    for bagID = 0, NUM_BAG_SLOTS do
        self:SaveBag(bagID)
    end
end

-- Saves data about the player's bank
function Memento:SaveBank()
    self:Debug("Saving bank")
    local bankDB = {}
    
    -- Bank: 40-67, Bank bags: 68-74
    for slot = 40, 74 do
        id = GetInventoryItemID("player", slot)
        if id then
            local count = GetInventoryItemCount("player", slot)
            if bankDB[id] then
                count = bankDB[id][1] + count
            end
            bankDB[id] = {count}
        end
    end
    self.playerDB[BANK_BAGID] = bankDB
    
    -- Bank bags
    for bagID = 1, GetNumBankSlots() do
        self:SaveBag(NUM_BAG_SLOTS + bagID)
    end
    self.bankSaved = true
end

-- Saves data about the guild's bank
function Memento:SaveGuildBank()
    local tabDB = {}
    local tab = GetCurrentGuildBankTab()
    self:Debug("Saving guild tab: " .. tab)
    
    for slot = 1, MAX_GUILDBANK_SLOTS_PER_TAB do
        local link = GetGuildBankItemLink(tab, slot)
        if link then
            local id = self:ItemLinkToID(link)
            local texture, count, locked = GetGuildBankItemInfo(tab, slot)
            if tabDB[id] then
                count = tabDB[id][1] + count
            end
            self:Debug(format("id: %i, count: %i", id, count))
            tabDB[id] = {count}
        end
    end
    
    -- Cleanup any old data first
    if self.guildDB[tab] then
        for k, v in pairs(self.guildDB[tab]) do
            tab[k] = nil
        end
    end
    self.guildDB[tab] = tabDB
end


-- Saves data about the player's mail
function Memento:SaveMail()
    self:Debug("Saving mail")
    local mailDB = {}
    local numItems = GetInboxNumItems()
    
    if numItems then
        for mailID = 1, numItems do
            local packageIcon, stationeryIcon, sender, subject, money,
                  CODAmount, daysLeft, itemCount, wasRead, wasReturned,
                  textCreated, canReply, isGM,
                  itemQuantity = GetInboxHeaderInfo(mailID)
            -- itemCount: Number of attachments
            if itemCount then
                for attachmentIndex = 1, itemCount do
                    local link = GetInboxItemLink(mailID, attachmentIndex)
                    local id = self:ItemLinkToID(link)
                    local name, itemTexture, count, quality,
                          canUse = GetInboxItem(mailID, attachmentIndex)
                    if mailDB[id] then
                        count = mailDB[id][1] + count
                    end
                    mailDB[id] = {count}
                end
            end
        end
    end
    
    self.playerDB[MAIL_BAGID] = mailDB
end

-- Adds the count of (link) to (frame)
function Memento:SetTooltipInfo(frame, link)
    -- NOTE: This is called every ~0.2 seconds by GameTooltip
    
    local itemID = tostring(self:ItemLinkToID(link))
    local cacheData = itemCache[itemID]
    if cacheData then
        for name, countData in pairs(cacheData) do
            local bags, bank, gbank, mail = countData["bags"],
                countData["bank"], countData["gbank"], countData["mail"]
            local info, total = nil, (bags + bank + gbank + mail)
            
            if bags > 0 then
                if info then
                    info = strjoin(",", info, " Bags: " .. bags)
                else
                    info = "Bags: " .. bags
                end
            end
            if bank > 0 then
                if info then
                    info = strjoin(",", info, " Bank: " .. bank)
                else
                    info = "Bank: " .. bank
                end
            end
            if gbank > 0 then
                if info then
                    info = strjoin(",", info, " Guild: " .. gbank)
                else
                    info = "Guild: " .. gbank
                end
            end
            if mail > 0 then
                if info then
                    info = strjoin(",", info, " Mail: " .. mail)
                else
                    info = "Mail: " .. mail
                end
            end
            if info then
                --self:Debug(format("total: %i, bags: %i, bank: %i," ..
                --                  "gbank: %i, mail: %i", total, bags, bank,
                --                  gbank, mail))
                if not (total == bags or total == bank or
                        total == gbank or total == mail) then
                    infoString = format(TEAL, total) ..
                                 format(SILVER, format(" (%s)", info))
                else
                    infoString = format(TEAL, info)
                end
                frame:AddDoubleLine(format(TEAL, name .. ":"), infoString)
            end
        end
    end
    
    if DEBUG or self.options["showItemID"] then
        frame:AddDoubleLine(format(TEAL, "ItemID:"), format(SILVER, itemID))
    end
end

-- Slash command support
function Memento:SlashCommand(cmd)
    local cmdParts = {strsplit(" ", cmd)}
    cmd = strlower(cmdParts[1])
    self:Debug("slash cmd: " .. cmd)
    
    if "itemid" == cmd then
        self.options["showItemID"] = not self.options["showItemID"]
    elseif "rm" == cmd then
        local name = cmdParts[2] or nil
        self:Debug("Name: " .. tostring(name))
        if name then
            local result = self:RemoveNameFromDB(name)
            if result then
                self:Print(format(GREEN, "[Success]: ") .. name .. " removed.")
                self:UpdateItemCache()
            else
                self:Print(format(RED, "[Fail]: ") .. name .. " not found.")
            end
        end
    else
        local showItemID
        if self.options["showItemID"] then
            showItemID = format(GREEN, "Enabled")
        else
            showItemID = format(RED, "Disabled")
        end
        self:Print(format(TEAL, "Memento: ") .. "(/memento, /mem)")
        self:Print("  rm <name> - Removes the player or guild NAME from " ..
                   " the database.")
        self:Print("  showItemID - " ..
                   showItemID ..
                   " - Toggle display of itemID in tooltips.")
    end
end

-- Updates the data structure of the local database
function Memento:UpdateDB()
    -- Future support
end

-- Updates the current guild to the player's current guild
function Memento:UpdateCurrentGuild()
    currentGuild = GetGuildInfo("player")
    if currentGuild then
        if not self.realmDB["guilds"][currentGuild] then
            self:Debug("New guild: " .. currentGuild)
            self.realmDB["guilds"][currentGuild] = {}
        else
            self:Debug("Found guildDB: " .. currentGuild)
        end
        self.guildDB = self.realmDB["guilds"][currentGuild]
    else
        self:Debug("Empty guild: " .. tostring(currentGuild))
    end
end

-- Updates the item cache
function Memento:UpdateItemCache()
    self:Debug("Updating itemCache")
    
    --itemCache[itemID] = {
    --    "<player>|<guild>": {
    --        "bags": <count>,
    --        "bank": <count>,
    --        "gbank": <count>, -- Only used for <guild>
    --        "mail": <count>
    --    }, ...
    --}
    
    -- Returns a new itemCache for a player
    local function newCacheItem()
        return {bags = 0, bank = 0, gbank = 0, mail = 0}
    end
    
    -- Clear out the cache
    itemCache = {}
    
    -- Bags, bank, and mail
    for player, playerDB in pairs(self.realmDB["players"]) do
        for bagID, items in pairs(playerDB) do
            for itemID, itemData in pairs(items) do
                -- Convert to string so we can index it properly in the table
                itemID = tostring(itemID)
                local count = itemData[1]
                if not itemCache[itemID] then
                    itemCache[itemID] = {}
                    itemCache[itemID][player] = newCacheItem()
                end
                if not itemCache[itemID][player] then
                    itemCache[itemID][player] = newCacheItem()
                end
                
                local bagType = "bags"
                -- Mail
                if bagID == MAIL_BAGID then
                    bagType = "mail"
                -- Bank
                elseif bagID > NUM_BAG_SLOTS then
                    bagType = "bank"
                end
                itemCache[itemID][player][bagType] = (
                    count + itemCache[itemID][player][bagType])
            end
        end
    end
    
    -- Guild Bank
    for guild, guildDB in pairs(self.realmDB["guilds"]) do
        for tab, items in pairs(guildDB) do
            for itemID, itemData in pairs(items) do
                -- Convert to string so we can index it properly in the table
                itemID = tostring(itemID)
                local count = itemData[1]
                if not itemCache[itemID] then
                    itemCache[itemID] = {}
                    itemCache[itemID][guild] = newCacheItem()
                end
                if not itemCache[itemID][guild] then
                    itemCache[itemID][guild] = newCacheItem()
                end
                itemCache[itemID][guild]["gbank"] = (
                    count + itemCache[itemID][guild]["gbank"])
            end
        end
    end
end
