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


--##############################REF#################################################
--sportTelemetryPush(0x0D,0x30,20,20) -- should justy make the data id a checksum

local BUILD_NUMBER = 3
--#############################Commmand defines#####################################
local CMD_CHANGE_SCREEN = 1
local CMD_CHANGE_DATA  =  2
local CMD_EXIT  = 3 
local CMD_CLEAR_SCREEN  = 4
local CMD_REQUEST_DATA  = 5
local CMD_ADD_DATA  = 6
local CMD_SUBTRACT_DATA  = 7 
local REPLYID = 0x30 --48 in dec
local REQUESTID = 0x32 
local SENSORID = 0x0D --13 in dec

--###############################Variables#######################################################
local horizontalCharSpacing = 6
local verticalCharSpacing   = 10
local currentScreen = 1
local currentRow = 1
local luaStatus = "idle"
local lastRow = 1
local rxBuffer  = {}
local xyBuffer  = {}
local dataCombined = 1
local CMD_PRINT = 0x12
local CMD_ERASE = 0x13
local replyCheckSumLua = 0
local tempNumVar = 0

local testRXData = {0,0,CMD_CLEAR_SCREEN,4,2,0}
local dataCombined = ( (bit32.lshift(testRXData[6],8)) + testRXData[5]) --turns the two 1 byte numbers into 1 16 bit number

--FIX would like to move these arrays to a seperate file at some point
--first byte command rest of bytes differ depending on command 
--if command is change screen, second byte is screen rest is data
--if command is print data second byte is row rest is data
--if command is exit screen exits

--each needs a space for the > to go in
local titleScreenArray = { "  Yaw PIDs", "  Roll PIDs", "  Pitch PIDs", "  Yaw Rate", "  Roll Rate", "  Pitch Rate", "  General", "  VTX", "Raceflight One Program Menu" } 


local pidDataArray = { 20,20,20,20,20}
--need to preserve a space before all the screen rows so that theres room for the cursor
-- these will need to match what the FC expects, each array will be used to draw a buffered screen, with the data being filled in by the FC and logic and Cursor moving done by FC
-- x9d has max of 6 rows 
local pidScreenArray  = { "  P:", "  I:", "  D:", "  Filter:", "  GA", "  Save and Exit" } --this will be used for multiple pid screens
local rateScreenArray  = { "  Rate:", "  Expo:", "  Acro:", "  DeadBand:", "  ", "  Save and Exit" } --this will be used for multiple rate screens
local generalScreenArray  = { "  RcSmooth:", "  I Limit:", "  D Limit:", "  CG:", "  ", "  Save and Exit" } --this will be used for the general page
local vtxScreenArray  = { "  Band:", "  Channel:", "  Power:", "  Exit Pitmode", "  ", "  Save and exit" } --this will be used for the VTX page
local idleScreenArray =  { "Welcome", "Place the Sticks in the bottom ", "Towards the center", "To enter Programming Mode", " " , " " }

local rowOffset = {1,2,3,4,5,6,7,8}

--these set the offset based on the length of the string, needs to be subracted by 1 when applied since the screen starts at 0
rowOffset[1] = {string.len(pidScreenArray[1]), string.len(pidScreenArray[2]), string.len(pidScreenArray[3]), string.len(pidScreenArray[4]), string.len(pidScreenArray[5]), string.len(pidScreenArray[6])} 
rowOffset[2] = {string.len(pidScreenArray[1]), string.len(pidScreenArray[2]), string.len(pidScreenArray[3]), string.len(pidScreenArray[4]), string.len(pidScreenArray[5]), string.len(pidScreenArray[6]) } 
rowOffset[3] = {string.len(pidScreenArray[1]), string.len(pidScreenArray[2]), string.len(pidScreenArray[3]), string.len(pidScreenArray[4]), string.len(pidScreenArray[5]) , string.len(pidScreenArray[6])} 
rowOffset[4] = {string.len(rateScreenArray[1]), string.len(rateScreenArray[2]), string.len(rateScreenArray[3]), string.len(rateScreenArray[4]), string.len(rateScreenArray[5]) , string.len(rateScreenArray[6])} 
rowOffset[5] = {string.len(rateScreenArray[1]), string.len(rateScreenArray[2]), string.len(rateScreenArray[3]), string.len(rateScreenArray[4]), string.len(rateScreenArray[5]), string.len(rateScreenArray[6])}
rowOffset[6] = {string.len(rateScreenArray[1]), string.len(rateScreenArray[2]), string.len(rateScreenArray[3]), string.len(rateScreenArray[4]), string.len(rateScreenArray[5]), string.len(rateScreenArray[6])}
rowOffset[7] = {string.len(generalScreenArray[1]), string.len(generalScreenArray[2]), string.len(generalScreenArray[3]), string.len(generalScreenArray[4]), string.len(generalScreenArray[5]), string.len(generalScreenArray[6])} 
rowOffset[8] = {string.len(vtxScreenArray[1]), string.len(vtxScreenArray[2]), string.len(vtxScreenArray[3]), string.len(vtxScreenArray[4]), string.len(vtxScreenArray[5]), string.len(vtxScreenArray[6])} 
	

--############################Functions########################################################
local function isempty(s)
  return s == nil or s == ''
end

local function ChangeData(data)
	lcd.drawText( ((rowOffset[currentScreen][currentRow]) -1)*horizontalCharSpacing,currentRow*verticalCharSpacing,data, SMLSIZE)
end

local function FillPIDData()
	lcd.drawText( ((rowOffset[currentScreen][1]) -1)*horizontalCharSpacing,1*verticalCharSpacing,pidDataArray[1], SMLSIZE)
	lcd.drawText( ((rowOffset[currentScreen][2]) -1)*horizontalCharSpacing,2*verticalCharSpacing,pidDataArray[2], SMLSIZE)
	lcd.drawText( ((rowOffset[currentScreen][3]) -1)*horizontalCharSpacing,3*verticalCharSpacing,pidDataArray[3], SMLSIZE)
	lcd.drawText( ((rowOffset[currentScreen][4]) -1)*horizontalCharSpacing,4*verticalCharSpacing,pidDataArray[4], SMLSIZE)
	lcd.drawText( ((rowOffset[currentScreen][5]) -1)*horizontalCharSpacing,5*verticalCharSpacing,pidDataArray[5], SMLSIZE)
end


local function HandleKeyEvents(passedevent)
	--Right now this is just looking for a key release to act

	if luaStatus == "editing" then --we are editing so we need to increase and decrease the data
		if passedevent == EVT_MINUS_FIRST then
			pidDataArray[currentRow] = pidDataArray[currentRow] - 1 
		end
		if passedevent == EVT_PLUS_FIRST then
			pidDataArray[currentRow] = pidDataArray[currentRow] + 1
		end
	end

	if luaStatus == "idle" then --idle means we need to navigate the menus
		if passedevent == EVT_MINUS_FIRST then
			currentRow = currentRow + 1	
		end
		if passedevent == EVT_PLUS_FIRST then
			currentRow = currentRow - 1	
		end

		if passedevent == EVT_ENTER_BREAK then
			if currentRow == 6 then
				luaStatus = "saving"
			else
				luaStatus = "editing"
			end
		end

		if passedevent == EVT_PAGE_BREAK then
			currentScreen = currentScreen + 1
		end
	end
	
	if passedevent == EVT_EXIT_BREAK then --this runs outside of the ifs so we can always exit from editing mode 
		luaStatus = "idle"	
	end

end

local function DrawBufferedScreen(screenArray)
	--drawing the pre defined screen
	lcd.drawText(0*horizontalCharSpacing,0,titleScreenArray[currentScreen], SMLSIZE)
	
	for i=1,6,1 do
		lcd.drawText(0*horizontalCharSpacing,i*verticalCharSpacing,screenArray[i], SMLSIZE)
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
		lcd.drawText(0*horizontalCharSpacing,lastRow*verticalCharSpacing," ", SMLSIZE)	
	end
	if luaStatus == "idle" then
		lcd.drawText(0*horizontalCharSpacing,currentRow*verticalCharSpacing,">", SMLSIZE)
	end

	if luaStatus == "editing" then
		lcd.drawText(0*horizontalCharSpacing,currentRow*verticalCharSpacing,"*", SMLSIZE)
	end

	lastRow = currentRow
end

local function ReceiveSport()
	local sId, fId, daId, value = sportTelemetryPop()
	--local sId = 0x0D
	--local fId = 0x32
	--local daId = 0x32
	--local value = 1
	--if sId == 0x0D and fId == 0x32 then
	if fId == REQUESTID then
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
	if currentRow < 1 then 
		currentRow = 6
	end

	if currentRow > 6 then 
		currentRow = 1
	end

	if currentScreen > 8 then 
		currentScreen = 1
	end

	if currentScreen < 1 then 
		currentScreen = 8
	end

	if testRXData[3] == CMD_CHANGE_SCREEN then
		--we are changing screens
		--set first row based off last 2 bytes
		-- fc will then send 4 more packets which will set the 4 next lines
		lcd.clear()
		lcd.drawFilledRectangle(0, 0, LCD_W, verticalCharSpacing)
		HandleMenuChoice(testRXData[4])
		currentScreen = testRXData[4]
		currentRow = 1
		ChangeData(dataCombined) --turns the two 1 byte numbers into 1 16 bit number
		currentRow = 0
		--replyCheckSumLua = (rxBuffer[1] + rxBuffer[2]+ rxBuffer[2]+ rxBuffer[3]+ rxBuffer[4]+ rxBuffer[5]+ rxBuffer[6])/6
		--sportTelemetryPush(SENSORID,REPLYID,replyCheckSumLua,CMD_CHANGE_SCREEN) -- should justy make the data id a checksum respond so the FC knows we got the data and proccessed it

	elseif testRXData[3] == CMD_CHANGE_DATA then
		--we are changing data
		-- 2nd byte is the row to set and last two bytes are the data
		currentRow=testRXData[4]
		ChangeData( dataCombined)
	elseif testRXData[3] == CMD_EXIT  then 
		--we are exiting
		--set screen to init
		lcd.clear()
		lcd.drawFilledRectangle(0, 0, LCD_W, verticalCharSpacing)
		HandleMenuChoice(9) --9 is ldle
	elseif testRXData[3] == CMD_CLEAR_SCREEN  then 
		--we are cleairng the screen
		lcd.clear()
		lcd.drawFilledRectangle(0, 0, LCD_W, verticalCharSpacing)
		--replyCheckSumLua = (rxBuffer[1] + rxBuffer[2]+ rxBuffer[2]+ rxBuffer[3]+ rxBuffer[4]+ rxBuffer[5]+ rxBuffer[6])/6
		--sportTelemetryPush(SENSORID,REPLYID,replyCheckSumLua,CMD_CLEAR_SCREEN) -- should justy make the data id a checksum respond so the FC knows we got the data and proccessed it
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
					textFeature = SMLSIZE
				end
				lcd.drawText(x*horizontalCharSpacing+1, y*verticalCharSpacing+1, xyBuffer[x][y], textFeature)
			end
		end
	end
end

local function RunUi(event)

	ProccessCommand()
	HandleKeyEvents(event)
	HandleMenuChoice(currentScreen)
	DrawCursor()
	FillPIDData()

	--if getValue("RSSI") == 0 then
	--	lcd.clear()
	--	lcd.drawFilledRectangle(0, 0, LCD_W, verticalCharSpacing)
	--	lcd.drawText(5*horizontalCharSpacing,5*verticalCharSpacing,"No RX Detected", INVERS+BLINK)
	--end

	--lcd.drawText(8*horizontalCharSpacing,0,BUILD_NUMBER, SMLSIZE) -- use this for debugging so you can see the build number
	return 0
end

local function InitUi()
	local ver, radio, maj, minor, rev = getVersion()
	if radio=="x9d" or radio=="x9d+" or radio=="taranisx9e" or radio=="taranisplus" or radio=="taranis" or radio=="x9d-simu" or radio=="x9d+-simu" or radio=="taranisx9e-simu" or radio=="taranisplus-simu" or radio=="taranis-simu" then
		horizontalCharSpacing = 6
		verticalCharSpacing   = 8
	end
	--xyBuffer[0] = {}
	--xyBuffer[0][0] = "RaceFlight One Program Menu"
end

return {init=InitUi, run=RunUi}
