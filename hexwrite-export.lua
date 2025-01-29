local spr = app.activeSprite
if not spr then
	app.alert("No loaded sprite to export!")
	return
end

local spec = spr.spec
local w, h = spec.width, spec.height
if w ~= 16 or h ~= 16 then
	app.alert("Sprite size isn't 16x16!")
	return
end

local cMode = spec.colorMode
if cMode ~= ColorMode.RGB then
	app.alert("Color mode should be set to RGB!")
	return
end

local image = app.image
if not image then
	app.alert("No image!")
	return
end

local bounds = app.cel.bounds
local function inBounds(x, y)
	local bX = bounds.x
	local bY = bounds.y

	local bXEnd = bounds.w + bX
	local bYEnd = bounds.h + bY
	-- byond

	if x < bX then
		return false
	end

	if y < bY then
		return false
	end

	if x >= bXEnd then
		return false
	end

	if y >= bYEnd then
		return false
	end

	return true
end


local function isTransparent(x, y)
	if not inBounds(x, y) then
		return true
	end

	local bX = bounds.x
	local bY = bounds.y

	local contents = image:getPixel(x - bX, y - bY)
	local alpha = app.pixelColor.rgbaA(contents)

	if alpha < 16 then
		return true
	end
end

-- https://stackoverflow.com/questions/47584734/is-there-a-way-to-set-the-clipboard-text-in-lua
function to_clipboard(text)
	local p = io.popen("clip.exe", "w")
	p:write(text)
	p:close()
end

-- main bulk here
local strBuffer = {}
strBuffer[#strBuffer + 1] = "{"

for y = 0, 15 do
	local sliceVal = 0

	for x = 0, 15 do
		if isTransparent(x, y) then
			goto _cont
		end

		local xSlice = 2 ^ (15 - x)
		sliceVal = sliceVal + xSlice

		::_cont::
	end

	local hexVar = string.format("0x%x, ", sliceVal)
	strBuffer[#strBuffer + 1] = hexVar
end

strBuffer[#strBuffer + 1] = "}"

local finalCont = table.concat(strBuffer, "")
to_clipboard(finalCont)
