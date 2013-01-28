
local MAJOR, MINOR = "LibMounts-1.0", tonumber("20121017183220") or 99999999999999 -- dev version should ovewrite normal version
local lib = LibStub:NewLibrary(MAJOR, MINOR)

if not lib then return end

-- define our constants
local AIR, GROUND, WATER, AHNQIRAJ, VASHJIR = "air", "ground", "water", "Temple of Ahn'Qiraj", "Vashj'ir"
-- make them available for lib users
lib.AIR, lib.GROUND, lib.WATER, lib.AHNQIRAJ, lib.VASHJIR = AIR, GROUND, WATER, AHNQIRAJ, VASHJIR

lib.data = LibStub("LibMounts-1.0_Data")

lib.frame = lib.frame or CreateFrame('frame')
lib.frame:SetScript("OnEvent", function(self, event, ...) if lib[event] then return lib[event](lib, event, ...) end end)
lib.frame:RegisterEvent('COMPANION_LEARNED')
lib.frame:RegisterEvent('ADDON_LOADED')

lib.classified_mounts = {}

function lib:COMPANION_LEARNED()
	for i=1, GetNumCompanions("MOUNT"), 1 do
		local creatureID, creatureName, spellID, icon, active, mountFlags = GetCompanionInfo("MOUNT", i)
		if not lib.classified_mounts[spellID] then
			lib.classified_mounts[spellID] =  true
			if not lib.data.specialSpeed[spellID] and not lib.data.specialLocation[spellID] then -- make sure we are dealing with proper mounts
				-- check for adjusted mount Flag
				mountFlags = lib.data.adjustedMountFlags[spellID] or mountFlags
				--[[ mountFlags, according to http://www.wowpedia.org/API_GetCompanionInfo
					0x1: Ground 
					0x2: Can fly 
					0x4: Floats above ground (all mounts seem to have this flag)
					0x8: Underwater 
					0x10: Can jump (turtles cannot) 
				]]
				-- ground and can jump => GROUND
				if bit.band(mountFlags, 0x11) == 0x11 then 
					lib.data[GROUND][spellID] = true
				end
				-- air => AIR
				if bit.band(mountFlags, 0x02) == 0x02 then 
					lib.data[AIR][spellID] = true
				end
				-- Underwater but neither ground, air nor can jump => WATER
				if bit.band(mountFlags, 0x1B) == 0x08 then 
					lib.data[WATER][spellID] = true
				end
			end
		end
	end
end

lib.not_logged_in = true

function lib:ADDON_LOADED(event, addon)
	lib.frame:UnregisterEvent("ADDON_LOADED")
	lib.ADDON_LOADED = nil
	if IsLoggedIn() then lib:PLAYER_LOGIN() else lib.frame:RegisterEvent("PLAYER_LOGIN") end
end

function lib:PLAYER_LOGIN()
	lib:COMPANION_LEARNED()
	lib.not_logged_in = nil
end

local earlylogingwaringing
local function assertMount(id)
	if lib.not_logged_in then -- here to fix racing conditon where we do not know if libmounts PLAYER_LOGIN was called before or after then addons
		if not lib.classified_mounts[id] then
			lib:COMPANION_LEARNED()
		end
	end
	local found
	for k, t in pairs(lib.data) do
		if k ~= "specialSpeed" and t[id] then
			found = true
		end
	end
	if not found then
		local name = GetSpellInfo(id)
		if name then
			if not_logged_in and not earlylogingwaringing then
				if not earlylogingwaringing then
					print("|cFF33FF99LibMounts-1.0|r: Your mount addon tried to get info about your mounts before PLAYER_LOGIN")
					earlylogingwaringing = true
				end
			else
				print("|cFF33FF99LibMounts-1.0|r: You have not learned how to summon |cFFFF2222"..name.."|r as such LibMounts does not know anything about it.")
			end
		else
			print("|cFF33FF99LibMounts-1.0|r: |cFFFF2222"..id.."|r is not a valid Mount Spell ID")
		end
	end
end
--- Retrieves Mount Information including type, speed and location restrictions
-- @param id Spell id of a Mount
-- @usage local ground, air, water, speed, location = LibStub("LibMounts-1.0"):GetMountInfo(id)
-- @return **ground** <<color 00f>>boolean<</color>> true if mount is primarily a ground mount (or can switch between ground and air only modes)
-- @return **air** <<color 00f>>boolean<</color>> true if mount is primarily an air mount (or can switch between air and ground only modes)
-- @return **water** <<color 00f>>boolean<</color>> true if mount is primarily a water mount
-- @return **speed** <<color 00f>>number<</color>> speed of mount if non standard (will always be slower than standard)
-- @return **location** <<color 00f>>string<</color>> location this mount is restricted to (valid returns are "Temple of Ahn'Qiraj" for the bug mounts and "Vashj'ir" for the Seahorse)
-- @return **passagners** <<color 00f>>number<</color>> number of additional passangers a mount can carry. returns nil if 0
function lib:GetMountInfo(id)
	assertMount(id)
	if lib.data["specialLocation"][id] then
		return unpack(lib.data["specialLocation"][id])
	else
		return lib.data["ground"][id], lib.data["air"][id], lib.data["water"][id], lib.data["specialSpeed"][id], nil, lib.data["specialPassenger"][id]
	end
end

lib.normalTypes = {
	[GROUND:lower()] = "ground",
	[AIR:lower()] = "air",
	[WATER:lower()] = "water",
}
lib.specialTypes = {
	[AHNQIRAJ:lower()] = "Temple of Ahn'Qiraj",
	[VASHJIR:lower()] = "Vashj'ir",
}
--- Retrieves a hash table of all mounts in the db of a certain type
-- @param MountType acceptable types include: ground, air, water, Temple of Ahn'Qiraj, Vashj'ir
-- @param table optional table you want the mounts to be stored in
-- @usage local mounts = LibStub("LibMounts-1.0"):GetMountList(type)
-- @return **mountTable** <<color 00f>>hash table<</color>> returns a hash table of mount ID's from the given mount type (mounts with special speeds are not returned)
function lib:GetMountList(MountType, uT)
	if lib.not_logged_in then -- here to fix racing conditon where we do not know if libmounts PLAYER_LOGIN was called before or after then addons (if called before PLAYER_LOGIN then return will be mostly empty)
		lib:COMPANION_LEARNED()
	end
	local t = uT or {}
	MountType = MountType:lower()
	local normalType = lib.normalTypes[MountType]
	if normalType then
		for id in pairs(lib.data[normalType]) do
			if not lib.data.specialSpeed[id] then
				t[id] = true
			end
		end
	else
		local specialType = lib.specialTypes[MountType]
		if specialType then
			for id, pack in pairs(lib.data.specialLocation) do
				if pack[5] == specialType then
					t[id] = true
				end
			end
		end
	end
	return t
end

--- Retrieves array of Main Mount Types (do not edit this table you have been warned)
-- @usage local MainMountTypes = LibStub("LibMounts-1.0"):GetSpecialMountTypes()
-- @return **MainMountTypes** <<color 00f>>table<</color>> array of Main Mount Types
lib.maintable = {AIR, GROUND, WATER}
lib.mainproxy = {}
setmetatable(lib.mainproxy, {
	__index = lib.maintable,
	__newindex = function (t,k,v)
		error("attempt to change the Main Mount Types Table", 2)
	end
})
function lib:GetMainMountTypes()
	return lib.mainproxy
end

--- Retrieves array of Special Mount Types (do not edit this table you have been warned)
-- @usage local SpecialMountTypes = LibStub("LibMounts-1.0"):GetSpecialMountTypes()
-- @return **SpecialMountTypes** <<color 00f>>table<</color>> array of Special Mount Types
lib.specialtable = {AHNQIRAJ, VASHJIR}
lib.specialproxy = {}
setmetatable(lib.specialproxy, {
	__index = lib.specialtable,
	__newindex = function (t,k,v)
		error("attempt to change the Main Mount Types Table", 2)
	end
})
function lib:GetSpecialMountTypes()
	return lib.specialproxy
end

--- Register for a LibMount-1.0 callback
-- The callback will always be called with the event as the first argument
-- Any arguments to the event will be passed on after that.
-- @name lib.RegisterCallback
-- @class function
-- @paramsig addon, event[, callback]
-- @param addon your addon table/object
-- @param event The event to register for. Currently available: "MOUNT_TYPE_UPDATE" (has primary, secondary and tertiary currently usable mount types as first, second and third arg(lib does not care if the player has mounts for the returned categories))
-- @param callback The callback function to call when the event is triggered (funcref or method, defaults to a method with the event name)
-- @usage LibStub("LibMounts-1.0").RegisterCallback(addon, "MOUNT_TYPE_UPDATE", function(...) print(...) end)

--- Unregister a callback.
-- @name lib.UnregisterCallback
-- @class function
-- @paramsig addon, event
-- @param addon your addon table/object
-- @param event The event to unregister
-- @usage LibStub("LibMounts-1.0").UnregisterCallback(addon, "MOUNT_TYPE_UPDATE")

--- Unregister all callbacks.
-- @name lib.UnregisterAllCallbacks
-- @class function
-- @paramsig addon
-- @param addon your addon table/object
-- @usage LibStub("LibMounts-1.0").UnregisterAllCallbacks(addon)
lib.callbacks = lib.callbacks or LibStub("CallbackHandler-1.0"):New(lib)

-- pull in all the localized names from the client
if not lib.Wintergrasp then -- get our localized names
	SetMapByID(501) -- Wintergrasp
	lib.Wintergrasp = select(GetCurrentMapZone(), GetMapZones(GetCurrentMapContinent()))
	for id=1, GetNumWorldPVPAreas() do
		if select(2, GetWorldPVPAreaInfo(id)) == lib.Wintergrasp then
			lib.WintergraspPVPid = id
			break
		end
	end
end

if not lib.vashzones then
	lib.vashzones = {}
	SetMapByID(613) -- Vashj'ir
	lib.vashzones[select(GetCurrentMapZone(), GetMapZones(GetCurrentMapContinent()))] = true
	SetMapByID(614) -- Abyssal Depths
	lib.vashzones[select(GetCurrentMapZone(), GetMapZones(GetCurrentMapContinent()))] = true
	SetMapByID(610) -- Kelp'thar Forest
	lib.vashzones[select(GetCurrentMapZone(), GetMapZones(GetCurrentMapContinent()))] = true
	SetMapByID(615) -- Shimmering Expanse
	lib.vashzones[select(GetCurrentMapZone(), GetMapZones(GetCurrentMapContinent()))] = true
end


function lib:PLAYER_REGEN_DISABLED()
	lib.frame:UnregisterEvent('SPELL_UPDATE_USABLE')
end

function lib:PLAYER_REGEN_ENABLED()
	lib.frame:RegisterEvent('SPELL_UPDATE_USABLE')
	lib:SPELL_UPDATE_USABLE()
end

-- This is our selection function can probably be optimized somehow but this is in a failry easily readbale format
function lib:SPELL_UPDATE_USABLE(...)
	local newstatePrimary, newstateSecondary, newstateTertiary
	if IsIndoors() then
		newstatePrimary = nil
		newstateSecondary = nil
	elseif lib.vashzones[GetRealZoneText()] then -- if we are in vashj
		if IsSwimming() or IsSubmerged() then
			if IsUsableSpell(75207) then
				if IsSubmerged() then -- check if we can air mount on the surface Spell id is that of the Black Proto-Drake
					newstatePrimary = VASHJIR
					newstateSecondary = WATER
					newstateTertiary = GROUND
				else
					newstatePrimary = AIR
					newstateSecondary = VASHJIR
					newstateTertiary = WATER
				end
			else
				newstatePrimary = WATER
				newstateSecondary = GROUND
			end
		elseif IsFlyableArea() and IsUsableSpell(60025) and IsUsableSpell(43688) then -- makes sure that air and ground mounts are sumonable here otherwise we are in a cave
			newstatePrimary = AIR
			newstateSecondary = GROUND
		elseif IsUsableSpell(43688) then
			newstatePrimary = GROUND
			newstateSecondary = nil
		end
	elseif IsSwimming() then
		if IsUsableSpell(59976) then -- check if we can air mount on the surface Spell id is that of the Black Proto-Drake
			newstatePrimary = AIR
			newstateSecondary = WATER
			newstateTertiary = GROUND
		else
			newstatePrimary = WATER
			newstateSecondary = GROUND
		end
	elseif IsFlyableArea() and IsUsableSpell(60025) then -- we use the check since azeroth is flyable but not if you do not have the cata expansion
		newstatePrimary = AIR
		newstateSecondary = GROUND
	elseif IsUsableSpell(26054) then -- use a bugmount to see if we are in AQ
		newstatePrimary = AHNQIRAJ
		newstateSecondary = GROUND
	elseif IsUsableSpell(43688) then -- specifically check a ground mount
		newstatePrimary = GROUND
		newstateSecondary = nil
	end
	
	-- Wintergrasp fix since blizzard can't makeup their minds
	if lib.Wintergrasp == GetRealZoneText() and IsOutdoors() then
		if select(3,GetWorldPVPAreaInfo(lib.WintergraspPVPid)) then
			newstatePrimary = GROUND
			newstateSecondary = nil
		else
			newstatePrimary = AIR
			newstateSecondary = GROUND
		end
	end
	
	-- check if anything changed and fire and update if it did
	if newstatePrimary ~= lib.statePrimary or newstateSecondary ~= lib.stateSecondary  or newstateTertiary ~= lib.stateTertiary then
		lib.statePrimary = newstatePrimary
		lib.stateSecondary = newstateSecondary
		lib.stateTertiary = newstateTertiary
		--print("LibMounts States", newstatePrimary, newstateSecondary, newstateTertiary)
		lib.callbacks:Fire("MOUNT_TYPE_UPDATE", newstatePrimary, newstateSecondary, newstateTertiary)
	end
end
lib.UPDATE_WORLD_STATES = lib.SPELL_UPDATE_USABLE

function lib.callbacks:OnUsed(target, eventname)
	if eventname == "MOUNT_TYPE_UPDATE" then
		lib.frame:RegisterEvent("SPELL_UPDATE_USABLE")
		lib.frame:RegisterEvent("UPDATE_WORLD_STATES")
		lib.frame:RegisterEvent("PLAYER_REGEN_DISABLED")
		lib.frame:RegisterEvent("PLAYER_REGEN_ENABLED")
		lib:SPELL_UPDATE_USABLE()
	end
end

function lib.callbacks:OnUnused(target, eventname)
	if eventname == "MOUNT_TYPE_UPDATE" then
		lib.frame:UnregisterEvent("SPELL_UPDATE_USABLE")
		lib.frame:UnregisterEvent("UPDATE_WORLD_STATES")
		lib.frame:UnregisterEvent("PLAYER_REGEN_DISABLED")
		lib.frame:UnregisterEvent("PLAYER_REGEN_ENABLED")
	end
end

--- forces a currently usable mount type update and also returns primary and secondary currently usable mount types
-- @usage local primary, secondary = LibStub("LibMounts-1.0"):GetCurrentMountType()
-- @return **primary** <<color 00f>>string<</color>> Primary currently usable mount type
-- @return **secondary** <<color 00f>>string<</color>> Secondary currently usable mount type
-- @return **tertiary** <<color 00f>>string<</color>> Tertiary currently usable mount type
function lib:GetCurrentMountType()
	lib:SPELL_UPDATE_USABLE()
	return lib.statePrimary, lib.stateSecondary, lib.stateTertiary
end


--- Checks if the mount has Profession restrictions and if we meet those restrictions
-- @param id Spell id of a Mount
-- @usage local summanable, profession, level = LibStub("LibMounts-1.0"):GetProfessionRestriction(id)
-- @return **summanable** <<color 00f>>boolean<</color>> true if we meet the Profession Restrictions and can summon the mount
-- @return **profession** <<color 00f>>string<</color>> Localized Profession name. Nil if the mount has no restrictions
-- @return **level** <<color 00f>>number<</color>> Required Profession level
function lib:GetProfessionRestriction(id)
	if lib.data["professionRestricted"][id] then
		local name = GetSpellInfo(lib.data["professionRestricted"][id][1])
		local level = lib.data["professionRestricted"][id][2]
		local prof1, prof2 = GetProfessions()
		if prof1 then
			local name1, _, rank1 = GetProfessionInfo(prof1)
			if name == name1 then
				return (rank1 >= level), name, level
			end
		end
		if prof2 then
			local name2, _, rank2 = GetProfessionInfo(prof2)
			if name == name2 then
				return (rank2 >= level), name, level
			end
		end
		return false, name, level
	else
		return true
	end
end
