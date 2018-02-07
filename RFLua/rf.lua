--The MIT License (MIT)
--
--Copyright 2017 RaceFlight
--
--Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
--
--The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
--
--THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

--Version 2.0

--###############################Variables#######################################################
local horizontalCharSpacing = 6
local verticalCharSpacing   = 10
local currentScreen = 1
local currentRow = 1
local lastRow = 1
local rxBuffer  = {}
local xyBuffer  = {}
local dataCombined = 1
local CMD_PRINT = 0x12
local CMD_ERASE = 0x13


local CMD_CHANGE_SCREEN = 1
local CMD_CHANGE_DATA  =  2
local CMD_EXIT  = 3 
	

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
		elseif choice == 9 then DrawBufferedScreen(idleScreenArray)
	end
end

local function DrawCursor() --this will draw the cursor based on current row
	if currentRow ~= lastRow then
		lcd.drawText(0*horizontalCharSpacing,lastRow*verticalCharSpacing," ", 0)	
	end
	lcd.drawText(0*horizontalCharSpacing,currentRow*verticalCharSpacing,">", 0)
	lastRow = currentRow
end

local function ChangeData(data)
	lcd.drawText( ((rowOffset[currentScreen][currentRow]) -1)*horizontalCharSpacing,currentRow*verticalCharSpacing,data, 0)
end

local function ReceiveSport()
	local sId, fId, daId, value = sportTelemetryPop()
	--local sId = 0x0D
	--local fId = 0x32
	--local daId = 0x32
	--local value = 1
	--if sId == 0x0D and fId == 0x32 then
	if fId == 0x32 then
		rxBuffer = {}
		rxBuffer[1] = bit32.band(daId,0xFF)
		rxBuffer[2] = bit32.band(bit32.rshift(daId,8),0xFF)
		rxBuffer[3] = bit32.band(value,0xFF)
		rxBuffer[4] = bit32.band(bit32.rshift(value,8 ),0xFF)
		rxBuffer[5] = bit32.band(bit32.rshift(value,16),0xFF)
		rxBuffer[6] = bit32.band(bit32.rshift(value,24),0xFF)
		dataCombined = ( (bit32.lshift(rxBuffer[6],8)) + rxBuffer[5]) --turns the two 1 byte numbers into 1 16 bit number
		return true
	else
		return false
	end
end

local function ProccessCommand()
	if currentRow < 0 then 
		currentRow = 5
	end

	if currentRow > 5 then 
		currentRow = 1
	end

	if currentScreen > 8 then 
		currentScreen = 1
	end

	if currentScreen < 1 then 
		currentScreen = 8
	end
	if rxBuffer[3] == 1 then
		--we are changing screens
		--set first row based off last 2 bytes
		-- fc will then send 4 more packets which will set the 4 next lines
		lcd.clear()
		lcd.drawFilledRectangle(0, 0, LCD_W, verticalCharSpacing)
		HandleMenuChoice(rxBuffer[4])
		currentScreen = rxBuffer[4]
		currentRow = 1
		ChangeData(dataCombined) --turns the two 1 byte numbers into 1 16 bit number
		currentRow = 0
	end
	if rxBuffer[3] == 2 then
		--we are changing data
		-- 2nd byte is the row to set and last two bytes are the data
		currentRow=rxBuffer[4]
		ChangeData( dataCombined)

	end	
	if rxBuffer[3] == 3  then --or rxBuffer[3] == 0
		--we are exiting
		--set screen to init
		lcd.clear()
		lcd.drawFilledRectangle(0, 0, LCD_W, verticalCharSpacing)
		HandleMenuChoice(9) --9 is ldle
	end
end
local function ProcessSport()
	local x=0
	local y=0
	local z=0
	if (rxBuffer[1] == CMD_PRINT) then
		z = rxBuffer[2]
		y = math.floor(z / 24)
		x = (z - (y * 24))
		for i=0,3,1 do
			if isempty(xyBuffer[x+i]) then
				xyBuffer[x+i] = {}
			end
			xyBuffer[x+i][y] = string.char(rxBuffer[2+i])
		end
	elseif (rxBuffer[1] == CMD_ERASE) then
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
		lcd.drawText(5*horizontalCharSpacing,5*verticalCharSpacing,"No RX Detected", INVERS+BLINK)
		--ProccessCommand()
	end
end

local function RunUi(event)


	if ReceiveSport() then
		ProccessCommand()
		HandleMenuChoice(currentScreen)
		DrawCursor()
	end
	if getValue("RSSI") == 0 then
		lcd.clear()
		lcd.drawFilledRectangle(0, 0, LCD_W, verticalCharSpacing)
		lcd.drawText(5*horizontalCharSpacing,5*verticalCharSpacing,"No RX Detected", INVERS+BLINK)
	end
	return 0
end

local function InitUi(event)
	local ver, radio, maj, minor, rev = getVersion()
	if radio=="x9d" or radio=="x9d+" or radio=="taranisx9e" or radio=="taranisplus" or radio=="taranis" or radio=="x9d-simu" or radio=="x9d+-simu" or radio=="taranisx9e-simu" or radio=="taranisplus-simu" or radio=="taranis-simu" then
		horizontalCharSpacing = 6
		verticalCharSpacing   = 10
	end
	if radio=="x9d" or radio=="x9d+" or radio=="taranisx9e" or radio=="taranisplus" or radio=="taranis" or radio=="x9d-simu" or radio=="x9d+-simu" or radio=="taranisx9e-simu" or radio=="taranisplus-simu" or radio=="taranis-simu" then
		horizontalCharSpacing = 6
		verticalCharSpacing   = 10
	end
	--xyBuffer[0] = {}
	--xyBuffer[0][0] = "RaceFlight One Program Menu"
end

return {init=InitUi, run=RunUi}
