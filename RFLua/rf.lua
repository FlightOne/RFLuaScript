--The MIT License (MIT)
--
--Copyright 2017 RaceFlight
--
--Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
--
--The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
--
--THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

--Version 1.0

--###############################Variables#######################################################
local horizontalCharSpacing = 6
local verticalCharSpacing   = 10
local currentScreen = 1
local currentRow = 4
local rxBuffer  = {}
local xyBuffer  = {}
local CMD_PRINT = 0x12
local CMD_ERASE = 0x13


--FIX would like to move these arrays to a seperate file at some point
--each needs a space for the > to go in
local titleScreenArray = { "  Yaw PIDs", "  Roll PIDs", "  Pitch PIDs", "  Yaw Rate", "  Roll Rate", "  Pitch Rate", "  General", "  VTX" }

--need to preserve a space before all the screen rows so that theres room for the cursor
-- these will need to match what the FC expects, each array will be used to draw a buffered screen, with the data being filled in by the FC and logic and Cursor moving done by FC
-- x9d has max of 5 rows 
local pidScreenArray  = { "  P:","  I:","  D:","  Filter:","  Save and Exit" } --this will be used for multiple pid screens
local rateScreenArray  = { "  Rate:","  Expo:","  Acro:","  DeadBand:","  Save and Exit" } --this will be used for multiple rate screens
local generalScreenArray  = { "  RcSmooth:","  I Limit:","  D Limit:","  CG:","  Save and Exit" } --this will be used for the general page
local vtxScreenArray  = { "  Band:","  Channel:","  Power:","  Exit Pitmode","  Save and Exit" } --this will be used for the VTX page

local rowOffset = {1,2,3,4,5,6,7,8}

--these set the offset based on the length of the string, needs to be subracted by 1 when applied since the screen starts at 0
rowOffset[1] = {string.len(pidScreenArray[1]), string.len(pidScreenArray[2]), string.len(pidScreenArray[3]), string.len(pidScreenArray[4]), string.len(pidScreenArray[5])} 
rowOffset[2] = {string.len(pidScreenArray[1]), string.len(pidScreenArray[2]), string.len(pidScreenArray[3]), string.len(pidScreenArray[4]), string.len(pidScreenArray[5])} 
rowOffset[3] = {string.len(pidScreenArray[1]), string.len(pidScreenArray[2]), string.len(pidScreenArray[3]), string.len(pidScreenArray[4]), string.len(pidScreenArray[5])} 
rowOffset[4] = {string.len(rateScreenArray[1]), string.len(rateScreenArray[2]), string.len(rateScreenArray[3]), string.len(rateScreenArray[4]), string.len(rateScreenArray[5])} 
rowOffset[5] = {string.len(rateScreenArray[1]), string.len(rateScreenArray[2]), string.len(rateScreenArray[3]), string.len(rateScreenArray[4]), string.len(rateScreenArray[5])}
rowOffset[6] = {string.len(rateScreenArray[1]), string.len(rateScreenArray[2]), string.len(rateScreenArray[3]), string.len(rateScreenArray[4]), string.len(rateScreenArray[5])}
rowOffset[7] = {string.len(generalScreenArray[1]), string.len(generalScreenArray[2]), string.len(generalScreenArray[3]), string.len(generalScreenArray[4]), string.len(generalScreenArray[5])} 
rowOffset[8] = {string.len(vtxScreenArray[1]), string.len(vtxScreenArray[2]), string.len(vtxScreenArray[3]), string.len(vtxScreenArray[4]), string.len(vtxScreenArray[5])} 
	

--############################Functions########################################################
local function isempty(s)
  return s == nil or s == ''
end


local function DrawBufferedScreen(screenArray)
	--drawing the pre defined screen
	
	lcd.drawText(0*horizontalCharSpacing,0,titleScreenArray[currentScreen], 0)
	for i=1,5,1 do
		lcd.drawText(0*horizontalCharSpacing,i*verticalCharSpacing,screenArray[i], 0)
	end
end

local function HandleMenuChoice(choice)
	currentScreen = choice
	
	if choice == 1 or choice == 2 or choice == 3 then DrawBufferedScreen(pidScreenArray) -- first 3 menus will use the same 
		elseif choice == 4 or choice == 5 or choice == 6 then DrawBufferedScreen(rateScreenArray) -- next 3 menus will use the same 
		elseif choice == 7 then DrawBufferedScreen(generalScreenArray)
		elseif choice == 8 then DrawBufferedScreen(vtxScreenArray)
	end
end

local function DrawCursor()
	lcd.drawText(0*horizontalCharSpacing,currentRow*verticalCharSpacing,">", 0)
end

local function ChangeData(data)
	lcd.drawText( (rowOffset[currentScreen][currentRow] -1)*horizontalCharSpacing,currentRow*verticalCharSpacing,data, 0)
end

local function ReceiveSport()
	local sId, fId, daId, value = sportTelemetryPop()
	if sId == 0x0D and fId == 0x32 then
		rxBuffer = {}
		rxBuffer[0] = bit32.band(daId,0xFF)
		rxBuffer[1] = bit32.band(bit32.rshift(daId,8),0xFF)
		rxBuffer[2] = bit32.band(value,0xFF)
		rxBuffer[3] = bit32.band(bit32.rshift(value,8 ),0xFF)
		rxBuffer[4] = bit32.band(bit32.rshift(value,16),0xFF)
		rxBuffer[5] = bit32.band(bit32.rshift(value,24),0xFF)
		return true
	else
		return false
	end
end

local function ProcessSport()
	local x=0
	local y=0
	local z=0
	if (rxBuffer[0] == CMD_PRINT) then
		z = rxBuffer[1]
		y = math.floor(z / 24)
		x = (z - (y * 24))
		for i=0,3,1 do
			if isempty(xyBuffer[x+i]) then
				xyBuffer[x+i] = {}
			end
			xyBuffer[x+i][y] = string.char(rxBuffer[2+i])
		end
	elseif (rxBuffer[0] == CMD_ERASE) then
		xyBuffer = {}
	end
end

local function DrawBuffers()
	local textFeature = 0
	for x in pairs(xyBuffer) do
		for y in pairs(xyBuffer[x]) do
			if not isempty(xyBuffer[x][y]) then
				if y==0 then
					textFeature = INVERS
				else
					textFeature = 0
				end
				lcd.drawText(x*horizontalCharSpacing+1, y*verticalCharSpacing+1, xyBuffer[x][y], textFeature)
			end
		end
	end
end

local function DrawScreen()
	lcd.clear()
	lcd.drawFilledRectangle(0, 0, LCD_W, verticalCharSpacing)
	DrawBuffers()
	if getValue("RSSI") == 0 then
		--lcd.drawText(5*horizontalCharSpacing,5*verticalCharSpacing,"No RX Detected", INVERS+BLINK)
		HandleMenuChoice(7)
		DrawCursor()
		ChangeData("50") 
		--lcd.drawText(0,0,titleScreenArray[1], INVERS+BLINK)
		--DrawPidScreen(pidScreenArray)
	end
end

local function RunUi(event)
	if ReceiveSport() then
		ProcessSport()
	end
	DrawScreen()
	return 0
end

local function InitUi(event)
	local ver, radio, maj, minor, rev = getVersion()
	if radio=="x9d" or radio=="x9d+" or radio=="taranisx9e" or radio=="taranisplus" or radio=="taranis" or radio=="x9d-simu" or radio=="x9d+-simu" or radio=="taranisx9e-simu" or radio=="taranisplus-simu" or radio=="taranis-simu" then
		horizontalCharSpacing = 6
		verticalCharSpacing   = 10
	end
	--xyBuffer[0] = {}
	--xyBuffer[0][0] = "RaceFlight One Program Menu"
end

return {init=InitUi, run=RunUi}
