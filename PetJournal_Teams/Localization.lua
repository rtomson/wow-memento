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
L["Hide Pet Battle Teams"] = true
L["Show Pet Battle Teams"] = true

-- Replace remaining true values by their key
for k,v in pairs(L) do if v == true then L[k] = k end end