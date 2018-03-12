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

--PROTOCOL 
--When requesting data, dataid is currentscreen and row combined, with currentscreen being last 8bits row first 8bits, making 255 max number of screens and rows
--16bits of value will be the command
--fc will respond with the same dataid as well as the value to fill in

local BUILD_NUMBER = 3
--#############################Commmand defines#####################################
local CMD_CHANGE_SCREEN = 1
local CMD_CHANGE_DATA  =  2
local CMD_EXIT  = 3 
local CMD_CLEAR_SCREEN  = 4
local CMD_REQUEST_DATA  = 5
local CMD_ADD_DATA  = 6 
local CMD_SUBTRACT_DATA = 7
local CMD_RECEIVE_COMPLETE  = 8
local CMD_PUSH_DATA  = 9 
local REPLYID = 0x32 -- 50
local REQUESTID = 0x30  --48 in dec 
local SENSORID = 0x0D --13 in dec
local CMD_PRINT = 0x12 -- these are legacy
local CMD_ERASE = 0x13 -- these are legacy
local LUAMAXROWS = 6
--############################# General defines##################################################
local LUA_STATUS_IDLE = 0
local LUA_STATUS_EDITING = 1
local LUA_STATUS_SAVING = 2
local LUA_STATUS_FILL_SCREEN = 3
--#############################  Psuedo defines##################################################
-- these are only set once during init based on the radio type
local textSize = SMLSIZE
local horizontalCharSpacing = 6
local verticalCharSpacing   = 10
local leftSideOffset = 0
local rowNumberOffset = 0
--###############################Variables#######################################################

local debugVar = "blah"

local requestFillScreen=0
local replyReceived=0
local currentRequestedRow = 0

local currentScreen = 1
local currentRow = 1
local lastRow = 1

local luaStatus = LUA_STATUS_IDLE

local dataCombined = 1
local replyCheckSumLua = 0
local tempNumVar = 0
local luaSendData = 0

--These are also legacy
local rxBuffer  = {}
local xyBuffer  = {}

--used for testing
local testRXData = {0,0,CMD_CLEAR_SCREEN,4,2,0}
local dataCombined = ( (bit32.lshift(testRXData[6],8)) + testRXData[5]) --turns the two 1 byte numbers into 1 16 bit number

--each needs a space for the > to go in
local titleScreenArray = { "  Yaw PIDs 1/8", "  Roll PIDs 2/8", "  Pitch PIDs 3/8", "  Yaw Rate 4/8", "  Roll Rate 5/8", "  Pitch Rate 6/8", "  General 7/8", "  VTX 8/8", "Raceflight One Program Menu" } 


local pidDataArray = { 20,20,20,20,20}
--need to preserve a space before all the screen rows so that theres room for the cursor
-- these will need to match what the FC expects, each array will be used to draw a buffered screen, with the data being filled in by the FC and logic and Cursor moving done by FC
-- x9d has max of 6 rows 
local pidScreenArray  = { "   P: ", "   I:", "   D: ", "   Filter:", "   GA: ", "   Save and Exit" } --this will be used for multiple pid screens
local rateScreenArray  = { "    Rate:", "   Expo:", "   Acro:", "   DeadBand:", "  ", "   Save and Exit" } --this will be used for multiple rate screens
local generalScreenArray  = { "   RcSmooth:", "   I Limit:", "   D Limit:", "   CG:", "  ", "   Save and Exit" } --this will be used for the general page
local vtxScreenArray  = { "   Band:", "   Channel:", "   Power:", "   Exit Pitmode", "  ", "   Save and exit" } --this will be used for the VTX page
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

local function PushLuaData()
	
	
	local sId, fId, daId, value = sportTelemetryPop() -- polling for the telem packet
	
	if fId == REPLYID   then
		--lcd.drawText(16*horizontalCharSpacing,(0 + rowNumberOffset),"PUSH", INVERS)
		rxBuffer = {}
		rxBuffer[1] = bit32.band(daId,0xFF)
		rxBuffer[2] = bit32.band(bit32.rshift(daId,8),0xFF)
		rxBuffer[3] = bit32.band(value,0xFF)
		rxBuffer[4] = bit32.band(bit32.rshift(value,8 ),0xFF)
		rxBuffer[5] = bit32.band(bit32.rshift(value,16),0xFF)
		rxBuffer[6] = bit32.band(bit32.rshift(value,24),0xFF)
		dataCombined = ( (bit32.lshift(rxBuffer[6],8)) + rxBuffer[5]) --turns the two 1 byte numbers into 1 16 bit number
		
		--ChangeData(dataCombined, currentRequestedRow) --Renders data to screen
		replyReceived = 1 --tells us we got a packet and it should be processed
	end


	if sendData and luaStatus == LUA_STATUS_SAVING then
		
		if replyReceived then
			--pidDataArray[currentRequestedRow] = rxBuffer[3] -- we se the requested row to the latest data
			replyReceived = 0
			currentRequestedRow = currentRequestedRow + 1
			tempNumVar = currentRequestedRow + bit32.lshift(currentScreen,8)
			--luaSendData = CMD_PUSH_DATA + bit32.lshift(pidDataArray[currentRequestedRow],8)
			luaSendData = CMD_PUSH_DATA + bit32.lshift(8,8)
			sportTelemetryPush(SENSORID,REQUESTID,tempNumVar,luaSendData) -- we supply the screen and row we are on and the FC returns the data for that row
		else
			tempNumVar = currentRequestedRow + bit32.lshift(currentScreen,8)
			--luaSendData = CMD_PUSH_DATA + bit32.lshift(pidDataArray[currentRequestedRow],8)
			luaSendData = CMD_PUSH_DATA + bit32.lshift(8,8)
			sportTelemetryPush(SENSORID,REQUESTID,tempNumVar,luaSendData) -- we supply the screen and row we are on and the FC returns the data for that row
			--lcd.drawText(16*horizontalCharSpacing,(0 + rowNumberOffset),"polling", INVERS)
			debugVar = "pushing"
		end

		if currentRequestedRow > LUAMAXROWS then 
			requestFillScreen=0
			replyReceived=0
			currentRequestedRow = 0
			sportTelemetryPush(SENSORID,REQUESTID,currentScreen,CMD_RECEIVE_COMPLETE) -- lets the fc know that the screen is done drawing
		end
	end
end


local function RequestFullScreen()
	

	local sId, fId, daId, value = sportTelemetryPop() -- polling for the telem packet
	lcd.drawText(13*horizontalCharSpacing,(1 + rowNumberOffset)*verticalCharSpacing,tostring(sId), 0)
	lcd.drawText(13*horizontalCharSpacing,(2 + rowNumberOffset)*verticalCharSpacing,tostring(fId), 0)
	lcd.drawText(13*horizontalCharSpacing,(3 + rowNumberOffset)*verticalCharSpacing,tostring(rxBuffer[1]), 0)
	lcd.drawText(13*horizontalCharSpacing,(4 + rowNumberOffset)*verticalCharSpacing,tostring(rxBuffer[3]), 0)
	lcd.drawText(13*horizontalCharSpacing,(5 + rowNumberOffset)*verticalCharSpacing,tostring(rxBuffer[4]), 0)
	lcd.drawText(13*horizontalCharSpacing,(6 + rowNumberOffset)*verticalCharSpacing,tostring(rxBuffer[5]), 0)
	lcd.drawText(13*horizontalCharSpacing,(7 + rowNumberOffset)*verticalCharSpacing,tostring(rxBuffer[6]), 0)
	if fId == REPLYID  then
		--lcd.drawText(16*horizontalCharSpacing,(0 + rowNumberOffset),"reply", INVERS)
		debugVar = "reply"
		rxBuffer = {}
		rxBuffer[1] = bit32.band(daId,0xFF)
		rxBuffer[2] = bit32.band(bit32.rshift(daId,8),0xFF)
		rxBuffer[3] = bit32.band(value,0xFF)
		rxBuffer[4] = bit32.band(bit32.rshift(value,8 ),0xFF)
		rxBuffer[5] = bit32.band(bit32.rshift(value,16),0xFF)
		rxBuffer[6] = bit32.band(bit32.rshift(value,24),0xFF)
		dataCombined = ( (bit32.lshift(rxBuffer[6],8)) + rxBuffer[5]) --turns the two 1 byte numbers into 1 16 bit number
		pidDataArray[currentRequestedRow] = rxBuffer[3]
		--ChangeData(dataCombined, currentRequestedRow) --Renders data to screen
		replyReceived = 1
	end

	if requestFillScreen and luaStatus == LUA_STATUS_IDLE then
		
		if replyReceived then
			tempNumVar = currentRequestedRow + bit32.lshift(currentScreen,8)
			pidDataArray[currentRequestedRow] = rxBuffer[3] -- we se the requested row to the latest data
			replyReceived = 0
			currentRequestedRow = currentRequestedRow + 1
			sportTelemetryPush(SENSORID,REQUESTID,tempNumVar,CMD_REQUEST_DATA) -- we supply the screen and row we are on and the FC returns the data for that row
		else
			tempNumVar = currentRequestedRow + bit32.lshift(currentScreen,8)
			sportTelemetryPush(SENSORID,REQUESTID,tempNumVar,CMD_REQUEST_DATA) -- we supply the screen and row we are on and the FC returns the data for that row
			--lcd.drawText(16*horizontalCharSpacing,(0 + rowNumberOffset),"polling", INVERS)
			debugVar = "polling"
		end

		if currentRequestedRow > LUAMAXROWS then 
			requestFillScreen=0
			replyReceived=0
			currentRequestedRow = 0
			sportTelemetryPush(SENSORID,REQUESTID,currentScreen,CMD_RECEIVE_COMPLETE) -- lets the fc know that the screen is done drawing
		end
	end
end


local function PollAndFillData()
	

	--used for debugging
	lcd.drawText(13*horizontalCharSpacing,(1 + rowNumberOffset)*verticalCharSpacing,tostring(sId), 0)
	lcd.drawText(13*horizontalCharSpacing,(2 + rowNumberOffset)*verticalCharSpacing,tostring(fId), 0)
	lcd.drawText(13*horizontalCharSpacing,(3 + rowNumberOffset)*verticalCharSpacing,tostring(rxBuffer[1]), 0)
	lcd.drawText(13*horizontalCharSpacing,(4 + rowNumberOffset)*verticalCharSpacing,tostring(rxBuffer[3]), 0)
	lcd.drawText(13*horizontalCharSpacing,(5 + rowNumberOffset)*verticalCharSpacing,tostring(rxBuffer[4]), 0)
	lcd.drawText(13*horizontalCharSpacing,(6 + rowNumberOffset)*verticalCharSpacing,tostring(rxBuffer[5]), 0)
	lcd.drawText(13*horizontalCharSpacing,(7 + rowNumberOffset)*verticalCharSpacing,tostring(rxBuffer[6]), 0)


	local sId, fId, daId, value = sportTelemetryPop() -- polling for the telem packet
	
	if fId == REPLYID   then
		lcd.drawText(16*horizontalCharSpacing,(0 + rowNumberOffset),"reply", INVERS)
		rxBuffer = {}
		rxBuffer[1] = bit32.band(daId,0xFF)
		rxBuffer[2] = bit32.band(bit32.rshift(daId,8),0xFF)
		rxBuffer[3] = bit32.band(value,0xFF)
		rxBuffer[4] = bit32.band(bit32.rshift(value,8 ),0xFF)
		rxBuffer[5] = bit32.band(bit32.rshift(value,16),0xFF)
		rxBuffer[6] = bit32.band(bit32.rshift(value,24),0xFF)
		dataCombined = ( (bit32.lshift(rxBuffer[6],8)) + rxBuffer[5]) --turns the two 1 byte numbers into 1 16 bit number
		
		--ChangeData(dataCombined, currentRequestedRow) --Renders data to screen
		replyReceived = 1 --tells us we got a packet and it should be processed
	end
	if requestFillScreen then

		if replyReceived then --if we got a reply then lets set the data 
			pidDataArray[currentRequestedRow] = rxBuffer[3] -- we se the requested row to the latest data
			requestFillScreen=0
			replyReceived=0
			sportTelemetryPush(SENSORID,REQUESTID,currentScreen,CMD_RECEIVE_COMPLETE) -- lets the fc know that the screen is done drawing
			return
		else -- if we have not reveived a valid packet yet then send a request packet again
			tempNumVar = currentRequestedRow + bit32.lshift(currentScreen,8)
			sportTelemetryPush(SENSORID,REQUESTID,tempNumVar,CMD_REQUEST_DATA) -- we supply the screen and row we are on and the FC returns the data for that row
		end
	end
end

local function ValidateScreenAndRow()
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

	--return(passedScreen,passedRow)
end

local function ChangeData(data, passedCurrentRow)
	lcd.drawText( ((rowOffset[currentScreen][passedCurrentRow]) -1)*horizontalCharSpacing,(passedCurrentRow + rowNumberOffset)*verticalCharSpacing,data, textSize)
end

local function FillPIDData()
	lcd.drawText( ((rowOffset[currentScreen][1]) -2)*horizontalCharSpacing,(1 +rowNumberOffset)*verticalCharSpacing,tostring(pidDataArray[1]), textSize)
	lcd.drawText( ((rowOffset[currentScreen][2]) -2)*horizontalCharSpacing,(2 + rowNumberOffset)*verticalCharSpacing,tostring(pidDataArray[2]), textSize)
	lcd.drawText( ((rowOffset[currentScreen][3]) -2)*horizontalCharSpacing,(3 + rowNumberOffset)*verticalCharSpacing,tostring(pidDataArray[3]), textSize)
	lcd.drawText( ((rowOffset[currentScreen][4]) -2)*horizontalCharSpacing,(4 + rowNumberOffset)*verticalCharSpacing,tostring(pidDataArray[4]), textSize)
	lcd.drawText( ((rowOffset[currentScreen][5]) -2)*horizontalCharSpacing,(5 + rowNumberOffset)*verticalCharSpacing,tostring(pidDataArray[5]), textSize)
end


local function HandleKeyEvents(passedevent)
	--Right now this is just looking for a key release to act

	if luaStatus == LUA_STATUS_EDITING then --we are editing so we need to increase and decrease the data
		if passedevent == EVT_MINUS_FIRST or passedevent == EVT_ROT_LEFT then
			tempNumVar = currentRow + bit32.lshift(currentScreen,8)
			sportTelemetryPush(SENSORID,REQUESTID,tempNumVar,CMD_SUBTRACT_DATA)		

			if(requestFillScreen == 0) then
				requestFillScreen = 1
				--replyReceived=0
				currentRequestedRow=currentRow
			end 
		end
		if passedevent == EVT_PLUS_FIRST or passedevent == EVT_ROT_RIGHT then
			tempNumVar = currentRow + bit32.lshift(currentScreen,8)
			sportTelemetryPush(SENSORID,REQUESTID,tempNumVar,CMD_ADD_DATA)		
			if(requestFillScreen == 0) then
				requestFillScreen = 1
				--replyReceived=0
				currentRequestedRow=currentRow
			end
		end
	end

	if luaStatus == LUA_STATUS_IDLE then --idle means we need to navigate the menus
		if passedevent == EVT_MINUS_FIRST or passedevent == EVT_ROT_LEFT then
			currentRow = currentRow + 1	
		
		elseif passedevent == EVT_PLUS_FIRST or passedevent == EVT_ROT_RIGHT then
			currentRow = currentRow - 1	
		

		elseif passedevent == EVT_ENTER_BREAK or passedevent == EVT_ROT_BREAK then
			if currentRow == 6 then
				luaStatus = LUA_STATUS_SAVING
				sendData = 1
				currentRequestedRow = 0
			else
				luaStatus = LUA_STATUS_EDITING
			end
		

		elseif passedevent == EVT_PAGE_LONG  or passedevent == EVT_PAGEUP_FIRST  then
			currentScreen = currentScreen - 1
			killEvents(passedevent);
		

		elseif passedevent == EVT_PAGE_BREAK  or passedevent == EVT_PAGEDN_FIRST  then
			currentScreen = currentScreen + 1
		
		end
		

	end
	
	if passedevent == EVT_EXIT_BREAK then --this runs outside of the ifs so we can always exit from editing mode 
		luaStatus = LUA_STATUS_IDLE	
	end

	ValidateScreenAndRow()
end

local function DrawBufferedScreen(screenArray)
	--drawing the pre defined screen
	lcd.drawText(0*horizontalCharSpacing,(0 + rowNumberOffset),titleScreenArray[currentScreen], INVERS)
	
	for i=1,6,1 do
		lcd.drawText((0 + leftSideOffset) *horizontalCharSpacing,(i + rowNumberOffset)*verticalCharSpacing,screenArray[i], textSize)
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
		lcd.drawText((leftSideOffset + 0)*horizontalCharSpacing,(lastRow + rowNumberOffset)*verticalCharSpacing," ", textSize)	
	end
	if luaStatus == LUA_STATUS_IDLE then
		lcd.drawText((leftSideOffset + 0)*horizontalCharSpacing,(currentRow + rowNumberOffset)*verticalCharSpacing,">", textSize)
	end

	if luaStatus == LUA_STATUS_EDITING then
		lcd.drawText((leftSideOffset + 0)*horizontalCharSpacing,(currentRow + rowNumberOffset)*verticalCharSpacing,"*", textSize)
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
					textFeature = textSize --INVERS
				else
					textFeature = textSize
				end
				lcd.drawText(x*horizontalCharSpacing+1, y*verticalCharSpacing+1, xyBuffer[x][y], textFeature)
			end
		end
	end
end

local function RunUi(event)

	--ProccessCommand()
	HandleKeyEvents(event)
	HandleMenuChoice(currentScreen)
	DrawCursor()
	FillPIDData()
	RequestFullScreen()
	PushLuaData()
	--PollAndFillData()
	lcd.drawText(16*horizontalCharSpacing,(0 + rowNumberOffset),debugVar, INVERS)

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
		textSize = SMLSIZE
		rowNumberOffset = 0
		leftSideOffset = 0
	elseif radio=="x10" or radio=="x10s" or radio=="x10-simu" or radio=="x10s-simu" then 
		horizontalCharSpacing = 12
		verticalCharSpacing   = 20
		textSize = 0
		rowNumberOffset = 0
		leftSideOffset=1 --this is for the horus since it cuts off the cursor with out an extra space, adds padding to the left side
	end
	--xyBuffer[0] = {}
	--xyBuffer[0][0] = "RaceFlight One Program Menu"
end

return {init=InitUi, run=RunUi}
