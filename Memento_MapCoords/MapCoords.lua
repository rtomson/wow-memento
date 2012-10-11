
function showCoord(num)
	return format("%1.1f", floor(num * 1000 + 0.5) / 10)
end

local mapExpanded = not (WORLDMAP_SETTINGS.size == WORLDMAP_WINDOWED_SIZE);

hooksecurefunc("WorldMap_ToggleSizeUp", function()
	mapExpanded = true
end)

hooksecurefunc("WorldMap_ToggleSizeDown", function()
	mapExpanded = false
end)

function MapCoordsPlayer_OnUpdate()
	local posX, posY = GetPlayerMapPosition("player")
	if ( posX == 0 and posY == 0 ) then
		MapCoordsPlayerPortraitCoords:SetText("n/a")
	else
		MapCoordsPlayerPortraitCoords:SetText(showCoord(posX) .. ", " .. showCoord(posY))
	end
end

function MapCoordsWorldMap_OnUpdate()
	local output = ""
	local scale = WorldMapDetailFrame:GetEffectiveScale()
	local width = WorldMapDetailFrame:GetWidth()
	local height = WorldMapDetailFrame:GetHeight()
	local centerX, centerY = WorldMapDetailFrame:GetCenter()
	local x, y = GetCursorPosition()
	-- Tweak coords so they are accurate
	local adjustedX = (x / scale - (centerX - (width / 2))) / width
    local adjustedY = (centerY + (height / 2) - y / scale) / height		

	-- Cursor output
	if (adjustedX >= 0 and adjustedY >= 0 and adjustedX <= 1 and adjustedY <= 1) then
        output = "Cursor: " .. showCoord(adjustedX) .. ", " .. showCoord(adjustedY)
    end
    -- Separator
    if (output ~= "") then
        output = output .. "    "
    end
    -- Player output
	local px, py = GetPlayerMapPosition("player")
    output = output .. "Player: " .. showCoord(px) .. ", " .. showCoord(py)
	if (mapExpanded) then
		MapCoordsWorldMap:SetPoint("BOTTOM", WorldMapFrame, "BOTTOM", 0, 10)
		MapCoordsWorldMap:SetTextColor(GameFontNormal:GetTextColor())
	else if (WORLDMAP_SETTINGS.advanced) then
		MapCoordsWorldMap:SetPoint("BOTTOM", WorldMapFrame, "BOTTOM", 0, 35)
		MapCoordsWorldMap:SetTextColor(1, 1, 1, 1)
	else
		MapCoordsWorldMap:SetPoint("BOTTOM", WorldMapFrame, "BOTTOM", 0, 22)
		MapCoordsWorldMap:SetTextColor(1, 1, 1, 1)
	end
	end
	MapCoordsWorldMap:SetText(output)
end
