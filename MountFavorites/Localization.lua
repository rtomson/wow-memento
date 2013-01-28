local addonName, addon = ...

local L = setmetatable({}, {
    __index = function(self, key)
        if key ~= nil then
            rawset(self, key, tostring(key))
        end
        return tostring(key)
    end,
})
addon.L = L

------------------------ enUS ------------------------
L["Cannot create macro; no macro slots available."] = true
L["Mount Favorites"] = true
L["MountFavorites addon not loaded!"] = true
L["No mounts available."] = true
L["Random Favorite"] = true
L["Summons a random mount from your list of favorites. The mount chosen depends on your Riding skill and location."] = true

-- Replace remaining true values by their key
for k,v in pairs(L) do if v == true then L[k] = k end end