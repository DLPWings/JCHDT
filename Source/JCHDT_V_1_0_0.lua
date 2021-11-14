--[[ 
MIT License

Copyright (c) [2020] [Juan de la Parra - DLP Wings]

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE. ]]





-- Config
local fuelAlarm = 30 --Default 30%
local fuelAlarmRepeat = 10000 --milliseconds
local alternatingDelay = 3000 --Delay for alternating values display

-- App variables
local sensorId = 0
local demoMode = false
local alternateRPM = true
local alternateEGT = true
local alternateBattV = true
local alternateBatt = true
local demoModeCtrl

local resetReminder
local resetReminderFile
local resetDone = false

local booleanSelect = {"Yes", "No"}


--Timers
local lastTime=0
local alternating=0
--Alarm
local fuelAlarmFile
local fuelAlarmPlayed = false
local alarmVoice = true
local fuelAlarmArmed = false
local lastAlarm = 0
--Telemetry Variables
local RPMValue = 0
local EGTValue = 0
local ECUVValue = 0
--local PumpValue = 0
local EcuBattValue = 0
local FuelValue = 0
--local SpeedValue = 0
local StatusCode = 0
local MessageCode = 0
local TotalTime = 0
local ServiceTime = 0


-- Create an arrow
local renShape=lcd.renderer()
local largeHandle = {
{ 1, -46},
{ -1, -46},
{-3, -18},
{ 0, -18},
{ 3, -18}
}
local alarmHandle = {
    { 5, -48},
    { -5, -48},
    { 0, -36}
    }
local mediumHandle = {
    { 1, -39},
    { -1, -39},
    {-3, -16},
    { 0, -16},
    { 3, -16}
    }
local smallHandle = {
    { 1, -25},
    { -1, -25},
    {-2, -10},
    { 0, -10},
    { 2, -10}
    }
local heading = 0
local jclogo
collectgarbage()

local function drawShape(col, row, shape, rotation)
    sinShape = math.sin(rotation)
    cosShape = math.cos(rotation)
    renShape:reset()
    for index, point in pairs(shape) do
    renShape:addPoint(
    col + (point[1] * cosShape - point[2] * sinShape + 0.5),
    row + (point[1] * sinShape + point[2] * cosShape + 0.5)
    )
    end
    renShape:renderPolygon()
    end


--Form functions
local function sensorChanged(value)
    if(value and value >=0) then
        sensorId=sensorsAvailable[value].id
    else
        sensorId = 0
    end
    system.pSave("SensorId",sensorId)
end

local function fuelAlarmChanged(value)
    fuelAlarm = value
    system.pSave("FuelAlarm",value)
end

local function fuelAlarmRepeatChanged(value)
    fuelAlarmRepeat = value*1000
    system.pSave("FuelAlarmRepeat",fuelAlarmRepeat)
end



local function fuelAlarmFileChanged(value)
	fuelAlarmFile=value
	system.pSave("FuelAlarmFile",value)
end

local function resetReminderFileChanged(value)
	resetReminderFile=value
	system.pSave("ResetReminderFile",value)
end

local function alarmVoiceValueChanged(value)
    alarmVoice = value
    system.pSave("AlarmVoice",alarmVoice)
end

local function resetReminderChanged(value)
    resetReminder = value
    system.pSave("ResetReminder",resetReminder)
end

local function alternatingDelayChanged(value)
    alternatingDelay = value*100
    system.pSave("AlternatingDelay",alternatingDelay)
end

local function demoModeChanged(value)
    demoMode = not value
    form.setValue(demoModeCtrl,demoMode)
    if demoMode then system.pSave("DemoMode",1) else system.pSave("DemoMode",0) end
end

local function alternateRPMChanged(value)
    alternateRPM = value
    system.pSave("AlternateRPM",alternateRPM)
end

local function alternateEGTChanged(value)
    alternateEGT = value
    system.pSave("AlternateEGT",alternateEGT)
end

local function alternateBattVChanged(value)
    alternateBattV = value
    system.pSave("AlternateBattV",alternateBattV)
end

local function alternateBattChanged(value)
    alternateBatt = value
    system.pSave("AlternateBatt",alternateBatt)
end

local function comma_value(amount)
    local formatted = amount
    local k
    while true do  
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if (k==0) then
            break
        end
    end
    return formatted
end

local function decodeStatus(statusID)

    if statusID == 10 then     return "Stop"
    elseif statusID == 20 then return "Glow Test"
    elseif statusID == 30 then return "Starter Test"
    elseif statusID == 31 then return "Prime Fuel"
    elseif statusID == 32 then return "Prime Burner"
    elseif statusID == 40 then return "Manual Cooling"
    elseif statusID == 41 then return "Auto Cooling"
    elseif statusID == 51 then return "Igniter Heat"
    elseif statusID == 52 then return "Ignition"
    elseif statusID == 53 then return "Preheat"
    elseif statusID == 54 then return "Switchover"
    elseif statusID == 55 then return "To Idle"
    elseif statusID == 56 then return "Running"
    elseif statusID == 62 then return "Stop Error"
    else                       return "No Data"
    end
end

local function decodeMessage(messageID)

    if messageID == 1 then     return "Ignition Error"
    elseif messageID == 2 then return "Preheat Error"
    elseif messageID == 3 then return "Switchover Error"
    elseif messageID == 4 then return "Starter Motor Error"
    elseif messageID == 5 then return "To Idle Error"
    elseif messageID == 6 then return "Acceleration Error"
    elseif messageID == 7 then return "Igniter Bad"
    elseif messageID == 8 then return "Min Pump Ok"
    elseif messageID == 9 then return "Max Pump Ok"
    elseif messageID == 10 then return "Low RX Battery"
    elseif messageID == 11 then return "Low ECU Battery"
    elseif messageID == 12 then return "No RX"
    elseif messageID == 13 then return "Trim Down"
    elseif messageID == 14 then return "Trim Up"
    elseif messageID == 15 then return "Failsafe"
    elseif messageID == 16 then return "Full"
    elseif messageID == 17 then return "RX Setup Error"
    elseif messageID == 18 then return "Temp Sensor Error"
    elseif messageID == 19 then return "Turbine Comm Error"
    elseif messageID == 20 then return "Max Temp"
    elseif messageID == 21 then return "Max Amperes"
    elseif messageID == 22 then return "Low RPM"
    elseif messageID == 23 then return "RPM Sensor Error"
    elseif messageID == 24 then return "Max Pump"
    else                        return "No Data"
    end
end

local function checkDemoMode()
    if demoMode then
        FuelValue = 100*((system.getInputs( "P5" ) + 1.0)/2)
        RPMValue = math.floor((((system.getInputs( "P6" ) + 1.0)/2)*150) * 1000)
        EGTValue = 1000*((system.getInputs( "P7" ) + 1.0)/2)
        EcuBattValue = 100*((system.getInputs( "P8" ) + 1.0)/2)
        ECUVValue = 12.6*((system.getInputs( "P8" ) + 1.0)/2)
        --SpeedValue = 500*((system.getInputs( "P2" ) + 1.0)/2)
        --PumpValue = 3700*((system.getInputs( "P1" ) + 1.0)/2)         
        StatusCode = system.getInputs( "SB" )
        if StatusCode == 1 then 
            StatusCode = 56 
            MessageCode = 8
        end
        if StatusCode == -1 then 
            StatusCode = 10 
            MessageCode = 13
        end
        TotalTime = "26:23:45"
        ServiceTime = "01:23"
    end
 
end

local function checkFuelAlarmFlags()
    if(StatusCode == 56 and FuelValue > fuelAlarm) then fuelAlarmArmed = true end
    if(StatusCode == 10) then 
        fuelAlarmArmed = false 
        fuelAlarmPlayed = false
        resetDone = false
    end 
end

local function checkFuelAlarm()
    if (fuelAlarm ~= 0 and FuelValue ~= -1) then 
        if(fuelAlarmArmed and FuelValue <= fuelAlarm) then
            if fuelAlarmRepeat == 0 and fuelAlarmPlayed then 
                --Prevent further repetitions
            elseif system.getTimeCounter() - lastAlarm > fuelAlarmRepeat then
                if fuelAlarmFile ~= "" then system.playFile(fuelAlarmFile,AUDIO_QUEUE) end
                if alarmVoice then system.playNumber(FuelValue,0,"%") end
                system.messageBox("Warning: LOW FUEL",3)
                lastAlarm = system.getTimeCounter()
                fuelAlarmPlayed = true
            end
        end
    end
end

local function checkReminderAlert()

    if(StatusCode == 56 and resetReminder == 1) then
        if (resetDone == false and FuelValue < 95) then
            system.messageBox("Reset fuel consumption!",5)
            if resetReminderFile ~= "" then system.playFile(resetReminderFile,AUDIO_QUEUE) end
            resetDone = true
        else
            resetDone = true
        end
    end
end

local function initSettingsForm(formID)

    local sensorsAvailable = {}
    local available = system.getSensors();
    local list={}

    local curIndex=-1
    local descr = ""
    for index,sensor in ipairs(available) do 
        if(sensor.param == 0) then
            list[#list+1] = sensor.label
            sensorsAvailable[#sensorsAvailable+1] = sensor
            if(sensor.id==sensorId ) then
                curIndex=#sensorsAvailable
            end 
        end 
    end

    -- sensor select
    form.addRow(2)
    form.addLabel({label="Select sensor",width=120})
    form.addSelectbox (list, curIndex,true,sensorChanged,{width=190})

     --Fuel Warning
    form.addSpacer(100,10)
    form.addLabel({label="Alarms",font=FONT_BOLD})  
    form.addRow(3)
    form.addLabel({label="Fuel warning  [%]", width=130})
    form.addLabel({label="(0=Disabled)", width=80, font=FONT_MINI})
    form.addIntbox(fuelAlarm,0,99,30,0,1,fuelAlarmChanged) 
    form.addRow(2)
    form.addLabel({label="    File",width=190})
    form.addAudioFilebox(fuelAlarmFile or "",fuelAlarmFileChanged)
    form.addRow(2)
    form.addLabel({label="    Repeat every [s]", width=190})
    form.addIntbox(fuelAlarmRepeat/1000,0,60,10,0,1,fuelAlarmRepeatChanged,{width=120})
    form.addRow(2)
    form.addLabel({label="    Announce value by voice", width=240})
    form.addSelectbox (booleanSelect, alarmVoice,false,alarmVoiceValueChanged)
    form.addRow(2)
    form.addLabel({label="Fuel consumption reset reminder", width=240})
    form.addSelectbox (booleanSelect, resetReminder,false,resetReminderChanged)
    form.addRow(2)
    form.addLabel({label="    File",width=190})
    form.addAudioFilebox(resetReminderFile or "",resetReminderFileChanged)    

    form.addSpacer(100,10)
    form.addLabel({label="Alternating display",font=FONT_BOLD})
    
    form.addRow(2)
    form.addLabel({label="Show RPM", width=190})
    form.addSelectbox (booleanSelect, alternateRPM,false,alternateRPMChanged)

    form.addRow(2)
    form.addLabel({label="Show EGT [°C]", width=190})
    form.addSelectbox (booleanSelect, alternateEGT,false,alternateEGTChanged)
    
    form.addRow(2)
    form.addLabel({label="Show ECU batt [V]", width=190})
    form.addSelectbox (booleanSelect, alternateBattV,false,alternateBattVChanged)

    form.addRow(2)    
    form.addLabel({label="Show ECU batt [%]", width=190})
    form.addSelectbox (booleanSelect, alternateBatt,false,alternateBattChanged)
    
    form.addRow(2)
    form.addLabel({label="Change display every [s]", width=190})
    form.addIntbox(alternatingDelay/100,10,100,30,1,1,alternatingDelayChanged,{width=120})

    --Demo Mode
    form.addSpacer(100,10)
    form.addRow(2)
    form.addLabel({label="Demo mode enabled", width=274})
    demoModeCtrl = form.addCheckbox(demoMode,demoModeChanged)
    
    
    collectgarbage()
end

local function printFullDisplay(width, height)
    local lbl, val
    checkDemoMode()
    checkFuelAlarmFlags()
    checkReminderAlert()


    lcd.drawImage(0, 0, jcLogo)


    --[[print("W="..width.." H="..height..", MAXI "..lcd.getTextHeight(FONT_MAXI)..", BIG "..lcd.getTextHeight(FONT_BIG))
    print("NORMAL "..lcd.getTextHeight(FONT_NORMAL)..", BOLD "..lcd.getTextHeight(FONT_BOLD))
    print("MINI "..lcd.getTextHeight(FONT_MINI))]]

    lcd.setColor(0x22,0x2B,0x00,255)
    lbl = decodeStatus(StatusCode)
    lcd.drawText(160 - (lcd.getTextWidth(FONT_BIG,lbl))/2,117 ,lbl,FONT_BIG)
    lbl = decodeMessage(MessageCode)
    lcd.drawText(160 - (lcd.getTextWidth(FONT_NORMAL,lbl))/2,135 ,lbl,FONT_NORMAL)
    

    lcd.setColor(0xFF,0x55,0x55,255)
    drawShape(159, (56), alarmHandle, math.rad(260+fuelAlarm*2))   
    --ren:renderPolyline(4)

    lcd.setColor(240,240,240,255)

    --Fuel Gauge  
    val=FuelValue    
    lbl = string.format("%d", val)
    if val == -1 then
        lbl = "_"
        val=160
    end
    drawShape(159, (56), largeHandle, math.rad(260+val*2))
    lcd.drawText((160 - (lcd.getTextWidth(FONT_MAXI,lbl))/2),(67) ,lbl,FONT_MAXI)

    --RPM Gauge
    val=math.floor(RPMValue/1000)    
    lbl = string.format("%d", val)
    if val == -1 then
        lbl = "_"
        val=240
    end    
    drawShape(56, (63), mediumHandle, math.rad(260+val*1.33))
    lcd.drawText((57 - (lcd.getTextWidth(FONT_BIG,lbl))/2),80 ,lbl,FONT_BIG) 


    --EGT Gauge
    val=EGTValue   
    lbl = string.format("%d", val)
    if val == -1 then
        lbl = "_"
        val=1600
    end      
    drawShape(242, 78, smallHandle, math.rad(260 + val/5))
    lcd.drawText((243 - (lcd.getTextWidth(FONT_BOLD,lbl))/2), 87, lbl, FONT_BOLD)
    
    --Batt Gauge
    val=EcuBattValue
    lbl = string.format("%.1fV", ECUVValue)
    if val == -1 then
        lbl = "_"
        val=160
    end   
    drawShape(284, 32, smallHandle, math.rad(260+val*2))
    lcd.drawText((287 - (lcd.getTextWidth(FONT_BOLD,lbl))/2), 39, lbl, FONT_BOLD)

    lcd.setColor(0,0,0,255)
    --print(TotalTime)
    lbl = TotalTime
    lcd.drawText((280 - (lcd.getTextWidth(FONT_MINI,lbl))/2),(121) ,lbl,FONT_MINI)
    lbl = ServiceTime
    lcd.drawText((280 - (lcd.getTextWidth(FONT_MINI,lbl))/2),(143) ,lbl,FONT_MINI)

       
       --lcd.drawText(148 - lcd.getTextWidth(FONT_MINI,"FUEL %"),0,"FUEL %",FONT_MINI)
    --lcd.drawText(2,8,decodeStatus(StatusCode),FONT_BOLD)
    --lcd.drawText(2,30,decodeMessage(MessageCode),FONT_NORMAL)
    --lcd.drawImage(1,51,":graph")

    checkFuelAlarm()
    collectgarbage()

end

local function printDoubleDisplay(width, height)


    checkDemoMode()
    checkFuelAlarmFlags()
    checkReminderAlert()

    --Fuel gauge  
    local fuelLbl = string.format("%d", FuelValue)
    if FuelValue == -1 then fuelLbl = "- " end
    lcd.drawText(148 - lcd.getTextWidth(FONT_MAXI,fuelLbl),5 ,fuelLbl,FONT_MAXI)
    lcd.drawText(148 - lcd.getTextWidth(FONT_MINI,"FUEL %"),0,"FUEL %",FONT_MINI)

    --Status / Message 
    lcd.drawText(2,35,decodeStatus(StatusCode),FONT_BOLD)
    lcd.drawText(2,52,decodeMessage(MessageCode),FONT_MINI)

    --Alternating values
    local lbl
    if alternating == 1 then
        lbl = comma_value(math.floor(RPMValue))
        if RPMValue == -1 then lbl = "-" end 
        lcd.drawText(2,0,"RPM",FONT_MINI)
        lcd.drawText(2,10,lbl,FONT_BIG)
    end
    if alternating == 2 then
        lbl = string.format("%d°C",math.floor(EGTValue))
        if EGTValue == -1 then lbl = " -" end
        lcd.drawText(2,0,"EGT",FONT_MINI)
        lcd.drawText(2,10,lbl,FONT_BIG)
    end
    if alternating == 3 then
        lbl = string.format("%.2f V", ECUVValue)
        if ECUVValue == -1 then lbl = "  -" end
        lcd.drawText(2,0,"ECU Batt",FONT_MINI)
        lcd.drawText(2,10,lbl,FONT_BIG)
    end
    if alternating == 4 then
        lbl = string.format("%d%%",EcuBattValue)
        if EcuBattValue == -1 then lbl = "   -" end
        lcd.drawText(2,0,"ECU Batt",FONT_MINI)
        lcd.drawText(2,10,lbl,FONT_BIG)
    end

    checkFuelAlarm()
    collectgarbage()
end


local function init()
    -- sensor id
    sensorId = system.pLoad("SensorId",0)
    
    if sensorId == 0 then
        local available = system.getSensors()
        for index,sensor in ipairs(available) do
            if((sensor.id & 0xFFFF) == 0xA40C and (sensor.id & 0xFF0000) ~= 0) then -- Fill default sensor ID
                sensorId = sensor.id
                break
            end 
        end
    end

    --Load Settings
    fuelAlarm = system.pLoad("FuelAlarm",30)
    fuelAlarmFile = system.pLoad("FuelAlarmFile","")
    fuelAlarmRepeat = system.pLoad("FuelAlarmRepeat",10000)
    demoMode = system.pLoad("DemoMode",0)
    if demoMode == 0 then demoMode = false else demoMode = true end

    alternateRPM = system.pLoad("AlternateRPM",1)
    alternateEGT = system.pLoad("AlternateEGT",1)
    alternateBattV = system.pLoad("AlternateBattV",1)
    alternateBatt = system.pLoad("AlternateBatt",1)
    alarmVoice = system.pLoad("AlarmVoice", 1)
    resetReminder = system.pLoad("ResetReminder",1)
    resetReminderFile = system.pLoad("ResetReminderFile","")

    alternatingDelay = system.pLoad("AlternatingDelay",3000)

    system.registerTelemetry( 1, "Jet Central HDT", 4, printFullDisplay)
    system.registerTelemetry( 2, "Jet Central MFD", 2, printDoubleDisplay)

    system.registerForm(1,MENU_TELEMETRY,"Jet Central HDT",initSettingsForm,nil,nil)
    jcLogo = lcd.loadImage("Apps/JetCentral/CF.png")
    collectgarbage()
end
  
local function loop()
    local sensor
    local newTime = system.getTimeCounter()

    -- RPM
    sensor = system.getSensorByID(sensorId,1)
    if( sensor and sensor.valid ) then RPMValue = sensor.value else RPMValue = -1 end

    -- EGT
    sensor = system.getSensorByID(sensorId,2)
    if( sensor and sensor.valid ) then EGTValue = sensor.value else EGTValue = -1 end

    -- EcuV
    sensor = system.getSensorByID(sensorId,3)
    if( sensor and sensor.valid ) then ECUVValue = sensor.value else ECUVValue = -1 end

    -- EcuBatt
    sensor = system.getSensorByID(sensorId,5)
    if( sensor and sensor.valid ) then EcuBattValue = sensor.value else EcuBattValue = -1 end

    -- Fuel
    sensor = system.getSensorByID(sensorId,6)
    if( sensor and sensor.valid ) then FuelValue = sensor.value else FuelValue = -1 end

    -- Status
    sensor = system.getSensorByID(sensorId,8)
    if( sensor and sensor.valid ) then StatusCode = sensor.value else StatusCode = 0 end

    -- Message
    sensor = system.getSensorByID(sensorId,9)
    if( sensor and sensor.valid ) then MessageCode = sensor.value else MessageCode = 0 end
 
    -- Total Time
    sensor = system.getSensorByID(sensorId,10)
    if( sensor and sensor.valid ) then 
        TotalTime = string.format("%d:%02d:%02d", sensor.valHour, sensor.valMin, sensor.valSec) 
    else 
        TotalTime = "--:--:--" 
    end

    -- Service Time
    sensor = system.getSensorByID(sensorId,11)
    if( sensor and sensor.valid ) then 
        ServiceTime = string.format("%d:%02d", sensor.valHour, sensor.valMin) 
    else 
        ServiceTime = "--:--" 
    end

    if newTime-lastTime > alternatingDelay then
        lastTime = newTime
        alternating = alternating + 1
        if alternating > 4 then alternating = 0 end

        if alternating == 1 and alternateRPM == 2 then alternating = 2 end
        if alternating == 2 and alternateEGT == 2 then alternating = 3 end
        if alternating == 3 and alternateBattV == 2 then alternating = 4 end
        if alternating == 4 and alternateBatt == 2 then alternating = 0 end
        if alternating == 0 and alternateRPM == 1 then alternating = 1 end
        if alternating == 0 and alternateEGT == 1 then alternating = 2 end
        if alternating == 0 and alternateBattV == 1 then alternating = 3 end
        if alternating == 0 and alternateBatt ==1 then alternating = 4 end
    end
    
    collectgarbage()
end
return {init=init, loop=loop, author="DLPWings", version="1.00",name="Jet Central HDT"}
