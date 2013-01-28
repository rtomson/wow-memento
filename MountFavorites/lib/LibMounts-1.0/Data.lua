
--[===[@debug@
local DataVersion = 99999999999999 -- number larger than anything else so that dev version wil always overwite other versions
--@end-debug@]===]
--@non-debug@
local DataVersion = 20121017183220
--@end-non-debug@
local lib = LibStub:NewLibrary("LibMounts-1.0_Data", DataVersion)
if not lib then return end
lib["air"] = {}
lib["water"] = {}
lib["ground"] = {}
lib["specialSpeed"] = {
	[30174] = 0, -- Riding Turtle
}
lib["specialLocation"] = { --ground, air, water, speed, location, passangers
	[26054] = {true, nil, nil, nil, "Temple of Ahn'Qiraj"},
	[25953] = {true, nil, nil, nil, "Temple of Ahn'Qiraj"},
	[26056] = {true, nil, nil, nil, "Temple of Ahn'Qiraj"},
	[26055] = {true, nil, nil, nil, "Temple of Ahn'Qiraj"},
	[75207] = {nil, nil, true, nil, "Vashj'ir"},--Abyssal Seahorse
}
lib["specialPassenger"] = {
	[61467] = 2, -- Grand Black War Mammoth (horde)
	[61465] = 2, -- Grand Black War Mammoth (alliance)
	[61469] = 2, -- Grand Ice Mammoth (horde)
	[61470] = 2, -- Grand Ice Mammoth (alliance)
	[61447] = 2, -- Traveler's Tundra Mammoth (horde)
	[61425] = 2, -- Traveler's Tundra Mammoth (alliance)
	[55531] = 1, -- Mechano-hog
	[60424] = 1, -- Mekgineer's Chopper
	[75973] = 1, -- X-53 Touring Rocket
}
local TAILORING_ID = 110426
local ENGINEERING_ID = 110403
lib["professionRestricted"] = {
	[61451] = { TAILORING_ID, 300 }, --Flying Carpet
	[61309] = { TAILORING_ID, 425 }, --Magnificent Flying Carpet
	[75596] = { TAILORING_ID, 425 }, --Frosty Flying Carpet
	[44151] = { ENGINEERING_ID, 375 }, --Turbo-Charged Flying Machine
	[44153] = { ENGINEERING_ID, 300 }, --Flying Machine
}
lib["adjustedMountFlags"] = {
	[64731] = 0x08, --Sea Turtle lets force this one to be a swimming mount :)
}
