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

if not app.image then
	app.alert("No image!")
	return
end

-- flatten and copy first
app.command.FlattenLayers({
	["visibleOnly"] = true
})

local imageFlat = app.image:clone()

if not imageFlat then
	app.alert("No flat image, something went wrong...")
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


local function getColour(x, y)
	if not inBounds(x, y) then
		return 0, 0, 0
	end

	local bX = bounds.x
	local bY = bounds.y

	local contents = imageFlat:getPixel(x - bX, y - bY)
	local r = app.pixelColor.rgbaR(contents)
	local g = app.pixelColor.rgbaG(contents)
	local b = app.pixelColor.rgbaB(contents)

	return r, g, b
end


local function isTransparent(x, y)
	if not inBounds(x, y) then
		return true
	end

	local bX = bounds.x
	local bY = bounds.y

	local contents = imageFlat:getPixel(x - bX, y - bY)
	local alpha = app.pixelColor.rgbaA(contents)

	if alpha < 16 then
		return true
	end
end

-- https://stackoverflow.com/questions/47584734/is-there-a-way-to-set-the-clipboard-text-in-lua
local function to_clipboard(text)
	local p = io.popen("clip.exe", "w")
	p:write(text)
	p:close()
end

local function hashColour(r, g, b)
	return r + (g * 256) + (b * 65536)
end

local function unhashColour(hash)
	local r = hash % 256
	local g = math.floor(hash / 256) % 256
	local b = math.floor(hash / 65536) % 256

	return r, g, b
end




-- main bulk here
local iteratableBufferList = {}
local strBuffers = {}
local function newColourBuffer(cHash)
	local r, g, b = unhashColour(cHash)

	local nullSliceVals = {}
	local nullSliceStrings = {}
	for i = 0, 15 do
		nullSliceVals[i] = 0
		nullSliceStrings[i] = "0x0, "
	end

	local rStr = tostring(r)
	local paddedR = rStr .. string.rep(" ", 3 - #rStr)

	local gStr = tostring(g)
	local paddedG = gStr .. string.rep(" ", 3 - #gStr)

	local bStr = tostring(b)
	local paddedB = bStr .. string.rep(" ", 3 - #bStr)

	local colStr = "Color(" .. paddedR .. ", " .. paddedG .. ", " .. paddedB .. ")"

	strBuffers[cHash] = {
		["colStr"] = colStr,
		["sliceVals"] = nullSliceVals,
		["sliceStrings"] = nullSliceStrings,
	}

	iteratableBufferList[#iteratableBufferList + 1] = cHash
end

local function getColourBuffer(cHash)
	if not strBuffers[cHash] then
		newColourBuffer(cHash)
	end

	return strBuffers[cHash]
end

local function addToSlice(cBuff, sliceIdx, sliceAdd)
	local slices = cBuff["sliceVals"]
	slices[sliceIdx] = slices[sliceIdx] + sliceAdd
end

local function computeSliceString(cBuff, sliceIdx)
	local slices = cBuff["sliceVals"]
	local sliceVal = slices[sliceIdx]

	local hexVar = string.format("0x%x,", sliceVal)
	cBuff["sliceStrings"][sliceIdx] = hexVar
end


local function computeSliceStrings(sliceIdx)
	for i = 1, #iteratableBufferList do
		local cHash = iteratableBufferList[i]
		local cBuff = getColourBuffer(cHash)

		computeSliceString(cBuff, sliceIdx)
	end
end

for y = 0, 15 do
	for x = 0, 15 do
		if isTransparent(x, y) then
			goto _cont
		end

		local r, g, b = getColour(x, y)
		local cHash = hashColour(r, g, b)
		local cBuffer = getColourBuffer(cHash)

		local xSlice = 2 ^ (15 - x)

		addToSlice(cBuffer, y, xSlice)

		::_cont::
	end

	computeSliceStrings(y)
end

local strBuffer = {}
strBuffer[#strBuffer + 1] = "{\n"

for i = 1, #iteratableBufferList do
	local cHash = iteratableBufferList[i]
	local cBuffer = getColourBuffer(cHash)

	strBuffer[#strBuffer + 1] = "{"
		strBuffer[#strBuffer + 1] = cBuffer.colStr
	strBuffer[#strBuffer + 1] = ", "

	strBuffer[#strBuffer + 1] = "{"
		strBuffer[#strBuffer + 1] = table.concat(cBuffer.sliceStrings, "", 0)
	strBuffer[#strBuffer + 1] = "}"

	strBuffer[#strBuffer + 1] = "},\n"

end
strBuffer[#strBuffer + 1] = "}\n"

-- obtained, we must undo the flatten now
app.command.Undo()

local finalCont = table.concat(strBuffer, "")
to_clipboard(finalCont)