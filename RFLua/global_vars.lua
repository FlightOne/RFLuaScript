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

--FIX would like to move these arrays to a seperate file at some point
--first byte command rest of bytes differ depending on command 
--if command is change screen, second byte is screen rest is data
--if command is print data second byte is row rest is data
--if command is exit screen exits

--each needs a space for the > to go in
local titleScreenArray = { "  Yaw PIDs", "  Roll PIDs", "  Pitch PIDs", "  Yaw Rate", "  Roll Rate", "  Pitch Rate", "  General", "  VTX", "Raceflight One Program Menu" } 

--need to preserve a space before all the screen rows so that theres room for the cursor
-- these will need to match what the FC expects, each array will be used to draw a buffered screen, with the data being filled in by the FC and logic and Cursor moving done by FC
-- x9d has max of 5 rows 
local pidScreenArray  = { "  P:","  I:","  D:","  Filter:","  Save and Exit" } --this will be used for multiple pid screens
local rateScreenArray  = { "  Rate:","  Expo:","  Acro:","  DeadBand:","  Save and Exit" } --this will be used for multiple rate screens
local generalScreenArray  = { "  RcSmooth:","  I Limit:","  D Limit:","  CG:","  Save and Exit" } --this will be used for the general page
local vtxScreenArray  = { "  Band:","  Channel:","  Power:","  Exit Pitmode","  Save and exit" } --this will be used for the VTX page
local idleScreenArray =  { "Welcome","Place the Sticks in the bottom ","Towards the center","To enter Programming Mode"," " }

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

gRF1VarStruct = {}

gRF1VarStruct["titleScreenArray"] = { "  Yaw PIDs", "  Roll PIDs", "  Pitch PIDs", "  Yaw Rate", "  Roll Rate", "  Pitch Rate", "  General", "  VTX", "Raceflight One Program Menu" } 

gRF1VarStruct["pidScreenArray"]  = { "  P:","  I:","  D:","  Filter:","  Save and Exit" } --this will be used for multiple pid screens
gRF1VarStruct["rateScreenArray"]  = { "  Rate:","  Expo:","  Acro:","  DeadBand:","  Save and Exit" } --this will be used for multiple rate screens
local generalScreenArray  = { "  RcSmooth:","  I Limit:","  D Limit:","  CG:","  Save and Exit" } --this will be used for the general page
local vtxScreenArray  = { "  Band:","  Channel:","  Power:","  Exit Pitmode","  Save and exit" } --this will be used for the VTX page
local idleScreenArray =  { "Welcome","Place the Sticks in the bottom ","Towards the center","To enter Programming Mode"," " }
