script_name("dmginfo")
script_description("Damage Informer")
script_version("1.8.04")
script_authors("akacross")
script_url("https://akacross.net/")

-- Script Information
local scriptPath = thisScript().path
local scriptName = thisScript().name
local scriptVersion = thisScript().version

-- Dependency Manager
local function safeRequire(module)
    local success, result = pcall(require, module)
    return success and result or nil, result
end

-- Requirements
local dependencies = {
    {name = 'moonloader', var = 'moonloader', extras = {dlstatus = 'download_status', flag = 'font_flag'}},
    {name = 'ffi', var = 'ffi'},
	{name = 'lfs', var = 'lfs'},
	{name = 'ssl.https', var = 'https'},
    {name = 'windows.message', var = 'wm'},
    {name = 'mimgui', var = 'imgui'},
    {name = 'encoding', var = 'encoding'},
    {name = 'samp.events', var = 'sampev'},
    {name = 'fAwesome6', var = 'fa'}
}

local loadedModules, statusMessages = {}, {success = {}, failed = {}}
for _, dep in ipairs(dependencies) do
    local loadedModule, errorMsg = safeRequire(dep.name)
    loadedModules[dep.var] = loadedModule
    table.insert(statusMessages[loadedModule and "success" or "failed"], loadedModule and dep.name or string.format("%s (%s)", dep.name, errorMsg))
end

-- Assign loaded modules to local variables
for var, module in pairs(loadedModules) do
    _G[var] = module
end

-- Assign extra fields
for _, dep in ipairs(dependencies) do
    if dep.extras and loadedModules[dep.var] then
        for extraVar, extraField in pairs(dep.extras) do
            _G[extraVar] = loadedModules[dep.var][extraField]
        end
    end
end

-- Print status messages
print("Loaded modules: " .. table.concat(statusMessages.success, ", "))
if #statusMessages.failed > 0 then
    print("Failed to load modules: " .. table.concat(statusMessages.failed, ", "))
end

-- Encoding
encoding.default = 'CP1251'
local u8 = encoding.UTF8

-- Paths
local workingDir = getWorkingDirectory()
local scriptName = thisScript().name
local scriptPath = thisScript().path

local configDir = workingDir .. '\\config\\'
local resourceDir = workingDir .. '\\resource\\'
local audioDir = resourceDir .. "audio\\"
local audioPath =  audioDir .. scriptName .. "\\"
local cfg = configDir .. scriptName .. '.ini'

-- URLs
local url = "https://raw.githubusercontent.com/akacross/dmginfo/main/"
local script_url = url .. "dmginfo.lua"
local update_url = url .. "dmginfo.txt"
local sounds_url = url .. "resource/audio/dmginfo/"

-- Libs
local ped, h = playerPed, playerHandle

local blank_dmg = {}
local dmg = {
    GIVE = {
        toggle = true,
        stacked = true,
        font = 'Aerial',
        fontsize = 12,
        fontflag = {true, false, true, true},
        color = -1,
        time = 3,
        audio = {
            toggle = true,
            sound = "sound1.mp3",
            volume = 0.10
        }
    },
    TAKE = {
        toggle = true,
        stacked = true,
        font = 'Aerial',
        fontsize = 12,
        fontflag = {true, false, true, true},
        color = -1,
        time = 3,
        audio = {
            toggle = true,
            sound = "sound2.mp3",
            volume = 0.10
        }
    },
    autosave = false
}

local new, str, sizeof = imgui.new, ffi.string, ffi.sizeof
local menu = new.bool(false)
local mainc = imgui.ImVec4(0.98, 0.26, 0.26, 1.00)
local buttonSizeSmall = imgui.ImVec2(45, 37.5)
local buttonSizeLarge = imgui.ImVec2(91, 37.5)

local fontid = {}

-- Damage Data Structure
local damageData = {
    GIVE = {},
    TAKE = {}
}

-- Bullet Sync Data Structure
local bulletSyncData = {
    SEND = nil,
    RECEIVE = {}
}

local soundsList = {
	"sound1.mp3", "sound2.mp3", "sound3.mp3", "sound4.mp3", "sound5.mp3", "sound6.mp3", "sound7.mp3", "sound8.mp3", "roblox.mp3", "mw2.mp3", "bingbong.mp3"
}

local soundId = {
    GIVE = nil,
    TAKE = nil
}

local audioPaths = {}
local audioExtensions = {
    mp3 = true, mp4 = true, wav = true, m4a = true, flac = true, ogg = true, 
    mp2 = true, amr = true, wma = true, aac = true, aiff = true, m4r = true
}

function main()
	for _, path in pairs({configDir, resourceDir, audioDir, audioPath}) do

		createDirectory(path)
	end

	blank_dmg = dmg
	if doesFileExist(cfg) then
		loadIni()
	else
		blankIni()
	end

	if dmg.autoupdate then
		update_script(false)
	end
	
	for action, _ in pairs({GIVE = true, TAKE = true}) do
		createfont(action)
	end

	downloadSounds()
	
	while not isSampAvailable() do wait(100) end

	sampRegisterChatCommand("dmginfo", function()
		menu[0] = not menu[0]
	end)

	wait(-1)
end

-- Damage Render
function onD3DPresent()
    if isPauseMenuActive() or sampIsDialogActive() or sampIsScoreboardOpen() or isSampfuncsConsoleActive() or sampGetChatDisplayMode() == 0 then
        return
    end

    lua_thread.create(function()
        for action, data in pairs(damageData) do
            local dmgConfig = dmg[action]
            if not dmgConfig or not dmgConfig.toggle then
                goto continue  -- Skip to the next action
            end

            for id, userData in pairs(data) do
                for k = #userData.DamageEntries, 1, -1 do
                    local v = userData.DamageEntries[k]
                    if os.time() > v.time then
                        table.remove(userData.DamageEntries, k)
                    else
                        local px, py, pz = getCharCoordinates(ped)
                        local x, y, z = v.pos.x, v.pos.y, v.pos.z
                        if isLineOfSightClear(px, py, pz, x, y, z, false, false, false, false, false)
                        and isPointOnScreen(x, y, z, 0.0) then

                            local sx, sy = convert3DCoordsToScreen(x, y, z)
                            local damageText = string.format("%s%.1f", action == "GIVE" and '+' or '-', dmgConfig.stacked and v.stacked or v.damage)

                            if fontid[action] then
                                local widthText = renderGetFontDrawTextLength(fontid[action], damageText)
                                local heightText = renderGetFontDrawHeight(fontid[action])
                                renderFontDrawText(fontid[action], damageText, sx - (widthText / 2), sy - (heightText / 2), dmgConfig.color)
                            end
                        end
                    end
                end
            end
            ::continue::
        end
    end)
end

-- OnSendBulletSync Event Handler
function sampev.onSendBulletSync(data)
    bulletSyncData.SEND = {
        targetId = data.targetId,
        target = { x = data.target.x, y = data.target.y, z = data.target.z }
    }
end

-- OnBulletSync Event Handler
function sampev.onBulletSync(playerId, data)
    local _, localPed = sampGetPlayerIdByCharHandle(ped)
    if localPed ~= playerId then
        bulletSyncData.RECEIVE[playerId] = {
            targetId = data.targetId,
            target = { x = data.target.x, y = data.target.y, z = data.target.z }
        }
    end
end

-- OnSendGiveDamage Event Handler
function sampev.onSendGiveDamage(targetID, damage, weapon, _)
    lua_thread.create(handleDamageEvent, "GIVE", targetID, damage, weapon)
end

-- OnSendTakeDamage Event Handler
function sampev.onSendTakeDamage(senderID, damage, weapon, _)
    lua_thread.create(handleDamageEvent, "TAKE", senderID, damage, weapon)
end

-- Damage Event Handler
function handleDamageEvent(action, id, damage, weapon)
    -- Check if the action is enabled
    if not dmg[action].toggle then
        goto continue
    end
    
    -- Ignore Damage less than 1
    if damage < 1 then
        goto continue
    end

    -- Use Bullet Sync data to get reliable information
    local bulletData = nil
    if action == "GIVE" then
        bulletData = bulletSyncData.SEND
    elseif action == "TAKE" then
        bulletData = bulletSyncData.RECEIVE[id]
    end

    -- Get Target Position
    local px, py, pz
    if bulletData then
        id = bulletData.targetId
        px, py, pz = bulletData.target.x, bulletData.target.y, bulletData.target.z
    else
        if weapon >= 0 and weapon <= 18 then
            local result, playerHandle = sampGetCharHandleBySampPlayerId(id)
            if result then
                local x, y, z = getCharCoordinates(action == "GIVE" and playerHandle or ped)
                px, py, pz = x, y, z
            else
                print("[DEBUG] Invalid player ID.", id)
                goto continue
            end
        elseif weapon == 54 then
            if id == 65535 and action == "TAKE" then
                local x, y, z = getCharCoordinates(ped)
                px, py, pz = x, y, z - 0.9
            else
                goto continue
            end
        else
            print("[DEBUG] No Bullet Sync data available, cannot proceed.")
            goto continue
        end
    end

    -- Fix Damage for Weapon ID 34
    damage = weapon == 34 and 34.3 or damage

    -- Create Damage Data
    local data = damageData[action]
    if not data[id] then
        data[id] = {
            DamageEntries = {},
            StackedDamage = 0,
            PreviousDamage = 0
        }
    end
    local userData = data[id]
    
    -- Update stacked damage
    if userData.StackedDamage > 200 then
        userData.StackedDamage = 0
    end
    userData.StackedDamage = userData.StackedDamage + damage
    
    -- Remove old damage entry if stacking
    if dmg[action].stacked then
        for k, v in pairs(userData.DamageEntries) do
            if v.stacked then
                table.remove(userData.DamageEntries, k)
                break
            end
        end
    end

    -- Create new damage entry
    table.insert(userData.DamageEntries, {
        damage = damage,
        stacked = userData.StackedDamage,
        time = os.time() + dmg[action].time,
        pos = {x = px, y = py, z = pz}
    })

    -- Play Sound
    playActionSound(action)

    -- Reset Bullet Sync Data
    if action == "GIVE" then
        bulletSyncData.SEND = nil
    elseif action == "TAKE" then
        bulletSyncData.RECEIVE[id] = nil
    end

    ::continue::
end

-- OnWindowMessage
function onWindowMessage(msg, wparam, lparam)
    if wparam == VK_ESCAPE and menu[0] then
        if msg == wm.WM_KEYDOWN then
            consumeWindowMessage(true, false)
        end
        if msg == wm.WM_KEYUP then
            menu[0] = false
        end
    end
end

-- OnInitialize
imgui.OnInitialize(function()
	apply_custom_style()

	scanGameFolder(audioPath, audioPaths)

	local config = imgui.ImFontConfig()
	config.MergeMode = true
    config.PixelSnapH = true
    config.GlyphMinAdvanceX = 14
    local builder = imgui.ImFontGlyphRangesBuilder()
    local list = {
		"GEAR",
		"POWER_OFF",
		"FLOPPY_DISK",
		"REPEAT",
		"ERASER",
		"RETWEET"
	}
	for _, b in ipairs(list) do
		builder:AddText(fa(b))
	end
	defaultGlyphRanges1 = imgui.ImVector_ImWchar()
	builder:BuildRanges(defaultGlyphRanges1)
	imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(fa.get_font_data_base85("solid"), 14, config, defaultGlyphRanges1[0].Data)

	imgui.GetIO().IniFilename = nil
end)

imgui.OnFrame(function() return menu[0] end,
function()
    local width, height = getScreenResolution()
    imgui.SetNextWindowPos(imgui.ImVec2(width / 2, height / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.Begin(string.format("%s %s Settings - v%s", fa.GEAR, scriptName:capitalizeFirst(), scriptVersion), menu, 
        imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize + imgui.WindowFlags.AlwaysAutoResize)
        
        -- Left Panel
        imgui.BeginChild("##1", imgui.ImVec2(95, 270), false)
			-- Left Panel Buttons
			local buttons = {
				{action = "GIVE", label = fa.POWER_OFF .. '##GIVE', toggle = dmg.GIVE.toggle, size = buttonSizeSmall, tooltip = "Give damage toggle", onClick = function() dmg.GIVE.toggle = not dmg.GIVE.toggle end},
				{action = "TAKE", label = fa.POWER_OFF .. '##TAKE', toggle = dmg.TAKE.toggle, size = buttonSizeSmall, tooltip = "Take damage toggle", onClick = function() dmg.TAKE.toggle = not dmg.TAKE.toggle end},
				{action = "SAVE", label = fa.FLOPPY_DISK .. '##save', toggle = false, size = buttonSizeLarge, tooltip = "Save the Script", onClick = saveIni},
				{action = "RELOAD", label = fa.REPEAT .. '##reload', toggle = false, size = buttonSizeLarge, tooltip = "Reload the Script", onClick = loadIni},
				{action = "RESET", label = fa.ERASER .. '##reset', toggle = false, size = buttonSizeLarge, tooltip = "Reset the Script to default settings", onClick = blankIni},
				{action = "UPDATE", label = fa.RETWEET .. ' Update', toggle = false, size = buttonSizeLarge, tooltip = "Update the script", onClick = function() update_script(true) end},
			}

			for idx, btn in ipairs(buttons) do
				if idx <= 2 then
					-- Position the first two buttons side by side
					local offsetX = (idx - 1) * 46 -- Adjust spacing as needed
					imgui.SetCursorPos(imgui.ImVec2(1 + offsetX, 1))
					createButton(btn.label, btn.toggle, btn.size, btn.tooltip, btn.onClick)
				else
					-- Position the remaining buttons vertically
					local posY = 40 + (idx - 3) * 38
					imgui.SetCursorPos(imgui.ImVec2(1, posY))
					createButton(btn.label, btn.toggle, btn.size, btn.tooltip, btn.onClick)
				end
			end

			-- Checkboxes for Autosave and Autoupdate
			local checkboxes = {
				{label = 'Autosave', key = 'autosave'}
			}

			for idx, cb in ipairs(checkboxes) do
				local posY = 203 + (idx - 1) * 41
				imgui.SetCursorPos(imgui.ImVec2(5, posY))
				local currentValue = dmg[cb.key]
				if imgui.Checkbox(cb.label, new.bool(currentValue)) then
					dmg[cb.key] = not dmg[cb.key]
				end
			end
        imgui.EndChild()

        -- Right Panel
        imgui.SetCursorPos(imgui.ImVec2(100, 25))
        imgui.BeginChild("##3", imgui.ImVec2(345, 270), true)
			renderFontSettings("GIVE")
			renderFontSettings("TAKE")
        imgui.EndChild()
    imgui.End()
end)

function renderFontSettings(action)
    local dmgAction = dmg[action]

    -- Font Name Input
    imgui.PushItemWidth(95)
    local text = new.char[30](dmgAction.font)
    if imgui.InputText('##font'..action, text, sizeof(text), imgui.InputTextFlags.EnterReturnsTrue) then
        dmgAction.font = u8:decode(str(text))
        createfont(action)
    end
    imgui.PopItemWidth()
    if imgui.IsItemHovered() then
        imgui.SetTooltip('Change the font')
    end

    -- Font Flags Combo
    imgui.SameLine()
    local flagChoices = {'Bold', 'Italics', 'Border', 'Shadow'}
    imgui.PushItemWidth(60)
    if imgui.BeginCombo("##flags"..action, 'Flags') then
        for k, flag in ipairs(flagChoices) do
            if imgui.Checkbox(flag, new.bool(dmgAction.fontflag[k])) then
                dmgAction.fontflag[k] = not dmgAction.fontflag[k]
                createfont(action)
            end
        end
        imgui.EndCombo()
    end
    imgui.PopItemWidth()

    -- Color Picker
    imgui.SameLine()
    imgui.PushItemWidth(95)
    local tcolor = new.float[4](convertColor(dmgAction.color, true, true, false))
    if imgui.ColorEdit4('Color##'..action, tcolor, imgui.ColorEditFlags.NoInputs + imgui.ColorEditFlags.NoLabel) then
        dmgAction.color = joinARGB(tcolor[3], tcolor[0], tcolor[1], tcolor[2], true)
    end
    imgui.PopItemWidth()
    imgui.SameLine()
    imgui.Text('Color')
    if imgui.IsItemHovered() then
        imgui.SetTooltip('Color of text')
    end

    -- Stacked Checkbox
    imgui.SameLine()
    if imgui.Checkbox('Stacked##'..action, new.bool(dmgAction.stacked)) then
        dmgAction.stacked = not dmgAction.stacked
    end
    if imgui.IsItemHovered() then
        imgui.SetTooltip('Stacked Damage Per-Player')
    end

    -- Font Size Controls
    imgui.BeginGroup()
        if imgui.Button('+##'..action) and dmgAction.fontsize < 72 then
            dmgAction.fontsize = dmgAction.fontsize + 1
            createfont(action)
        end
        imgui.SameLine()
        imgui.Text(tostring(dmgAction.fontsize))
        imgui.SameLine()
        if imgui.Button('-##'..action) and dmgAction.fontsize > 4 then
            dmgAction.fontsize = dmgAction.fontsize - 1
            createfont(action)
        end
    imgui.EndGroup()
    if imgui.IsItemHovered() then
        imgui.SetTooltip('Size of text')
    end
    imgui.SameLine()
    imgui.Text('Fontsize')

    -- Display Time Controls
    imgui.BeginGroup()
        if imgui.Button('+##2'..action) and dmgAction.time < 10 then
            dmgAction.time = dmgAction.time + 1
            createfont(action)
        end
        imgui.SameLine()
        imgui.Text(tostring(dmgAction.time))
        imgui.SameLine()
        if imgui.Button('-##2'..action) and dmgAction.time > 1 then
            dmgAction.time = dmgAction.time - 1
            createfont(action)
        end
    imgui.EndGroup()
    if imgui.IsItemHovered() then
        imgui.SetTooltip('Displayed time')
    end
    imgui.SameLine()
    imgui.Text('Time')

    -- Sound Dropdown
    sound_dropdownmenu(action)
end

function sound_dropdownmenu(action)
    local audioConfig = dmg[action].audio

    if imgui.Checkbox('##3'..action, new.bool(audioConfig.toggle)) then
        audioConfig.toggle = not audioConfig.toggle
    end
    imgui.SameLine()
    if audioConfig.toggle then
        imgui.PushItemWidth(150)
            if imgui.BeginCombo("##sounds"..action, audioConfig.sound) then
                for _, v in ipairs(audioPaths) do
                    if matchAudioFiles(v.File) then
                        if imgui.Selectable(u8(v.File), v.File == audioConfig.sound) then
                            audioConfig.sound = v.File
                            playActionSound(action)
                        end
                    end
                end
                imgui.EndCombo()
            end
        imgui.PopItemWidth()
        imgui.SameLine()
        imgui.PushItemWidth(150)
        local volume = new.float[1](audioConfig.volume * 100)
        if imgui.SliderFloat('##Volume##' .. action, volume, 0, 100, "Volume: %.0f%%") then
            audioConfig.volume = volume[0] / 100
        end
        imgui.PopItemWidth()

        if imgui.IsItemHovered() then
            imgui.SetTooltip('Volume Control')
        end
    else
        imgui.Text('Disabled')
    end
end

function onScriptTerminate(scr, quitGame)
	if scr == script.this then
		if dmg.autosave then
			saveIni()
		end
	end
end

function blankIni()
	dmg = blank_dmg
	saveIni()
	loadIni()
end

function loadIni()
	local f = io.open(cfg, "r")
	if f then
		dmg = decodeJson(f:read("*all"))
		f:close()
	end
end

function saveIni()
    if type(dmg) == "table" then
        local f = io.open(cfg, "w")
        if f then
            f:write(encodeJson(dmg))
            f:close()
        end
    end
end

function createfont(action)
    local flagids = {flag.BOLD, flag.ITALICS, flag.BORDER, flag.SHADOW}
    local flags = 0
    local font_flags = dmg[action].fontflag

    if not font_flags then
        error("Font flags not found for action: " .. tostring(action))
    end

    for i, fid in ipairs(flagids) do
        if font_flags[i] then
            flags = flags + fid
        end
    end

    fontid[action] = renderCreateFont(dmg[action].font, dmg[action].fontsize, flags)
end

function playActionSound(action)
    if not dmg[action].audio.toggle then
        goto continue
    end

    local soundFile = audioPath .. (dmg[action].audio.sound or "")
    if not doesFileExist(soundFile) then
        formattedAddChatMessage(string.format("Error missing sound file: %s", soundFile))
        goto continue
    end

    soundId[action] = loadAudioStream(soundFile)
    if not soundId[action] then
        formattedAddChatMessage(string.format("Error playing sound: %s", soundFile))
        goto continue
    end

    local volume = dmg[action].audio.volume or 1.0 -- Default volume if not specified
    setAudioStreamVolume(soundId[action], volume)
    setAudioStreamState(soundId[action], 1)

    ::continue::
end

function scanGameFolder(path, tables)
    for file in lfs.dir(path) do
        if file ~= "." and file ~= ".." then
			local file_extension = string.match(file, "([^\\%.]+)$")
            if file_extension then
                table.insert(tables, {Path = path, File = file})
            end
        end
    end
end

function matchAudioFiles(f)
    local ext = f:match("%.([^%.]+)$")
    return ext and audioExtensions[ext:lower()] or false
end

function downloadSounds()
	for k, v in pairs(soundsList) do
		if not doesFileExist(audioPath .. v) then
			downloadUrlToFile(sounds_url .. v, audioPath .. v, function(id, status)
				if status == dlstatus.STATUS_ENDDOWNLOADDATA then
					formattedAddChatMessage(string.format("%s Downloaded", v))
				end
			end)
		end
	end
end

-- Convert Color
function convertColor(color, normalize, includeAlpha, hexColor)
    if type(color) ~= "number" then
        error("Invalid color value. Expected a number.")
    end

    local r = bit.band(bit.rshift(color, 16), 0xFF)
    local g = bit.band(bit.rshift(color, 8), 0xFF)
    local b = bit.band(color, 0xFF)
    local a = includeAlpha and bit.band(bit.rshift(color, 24), 0xFF) or 255

    if normalize then
        r, g, b, a = r / 255, g / 255, b / 255, a / 255
    end

    if hexColor then
        return includeAlpha and string.format("%02X%02X%02X%02X", a, r, g, b) or string.format("%02X%02X%02X", r, g, b)
    else
        return includeAlpha and {r, g, b, a} or {r, g, b}
    end
end

-- Join ARGB
function joinARGB(a, r, g, b, normalized)
    if normalized then
        a, r, g, b = math.floor(a * 255), math.floor(r * 255), math.floor(g * 255), math.floor(b * 255)
    end

    local function clamp(value)
        return math.max(0, math.min(255, value))
    end

    return bit.bor(bit.lshift(clamp(a), 24), bit.lshift(clamp(r), 16), bit.lshift(clamp(g), 8), clamp(b))
end

-- Formatted Add Chat Message
function formattedAddChatMessage(string)
    sampAddChatMessage(string.format("{ABB2B9}[%s]{FFFFFF} %s", scriptName:capitalizeFirst(), string), -1)
end

-- Capitalize First Letter
function string:capitalizeFirst()
    return self:gsub("^%l", string.upper)
end

function createButton(label, toggle, size, tooltip, onClick)
	local colorNormal = toggle and imgui.ImVec4(0.15, 0.59, 0.18, 0.7) or imgui.ImVec4(1, 0.19, 0.19, 0.5)
	local colorHover = toggle and imgui.ImVec4(0.15, 0.59, 0.18, 0.5) or imgui.ImVec4(1, 0.19, 0.19, 0.3)
	local colorActive = toggle and imgui.ImVec4(0.15, 0.59, 0.18, 0.4) or imgui.ImVec4(1, 0.19, 0.19, 0.2)

	if imgui.CustomButton(label, colorNormal, colorHover, colorActive, size) then
		onClick()
	end

	if imgui.IsItemHovered() then
		imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(8, 8))
		imgui.SetTooltip(tooltip)
		imgui.PopStyleVar()
	end
end

function imgui.CustomButton(name, color, colorHovered, colorActive, size)
    local clr = imgui.Col
    imgui.PushStyleColor(clr.Button, color)
    imgui.PushStyleColor(clr.ButtonHovered, colorHovered)
    imgui.PushStyleColor(clr.ButtonActive, colorActive)
    if not size then size = imgui.ImVec2(0, 0) end
    local result = imgui.Button(name, size)
    imgui.PopStyleColor(3)
    return result
end

function apply_custom_style()
	imgui.SwitchContext()
	local ImVec4 = imgui.ImVec4
	local ImVec2 = imgui.ImVec2
	local style = imgui.GetStyle()
	style.WindowRounding = 0
	style.WindowPadding = ImVec2(8, 8)
	style.WindowTitleAlign = ImVec2(0.5, 0.5)
	style.FrameRounding = 0
	style.ItemSpacing = ImVec2(8, 4)
	style.ScrollbarSize = 10
	style.ScrollbarRounding = 3
	style.GrabMinSize = 10
	style.GrabRounding = 0
	style.Alpha = 1
	style.FramePadding = ImVec2(4, 3)
	style.ItemInnerSpacing = ImVec2(4, 4)
	style.TouchExtraPadding = ImVec2(0, 0)
	style.IndentSpacing = 21
	style.ColumnsMinSpacing = 6
	style.ButtonTextAlign = ImVec2(0.5, 0.5)
	style.DisplayWindowPadding = ImVec2(0, 0)
	style.DisplaySafeAreaPadding = ImVec2(4, 4)
	style.AntiAliasedLines = true
	style.CurveTessellationTol = 1.25
	
	local colors = style.Colors
	local clr = imgui.Col
	colors[clr.FrameBg]                = ImVec4(mainc.x, mainc.y, mainc.z, 0.54)
    colors[clr.FrameBgHovered]         = ImVec4(mainc.x, mainc.y, mainc.z, 0.40)
    colors[clr.FrameBgActive]          = ImVec4(mainc.x, mainc.y, mainc.z, 0.67)
    colors[clr.TitleBg]                = ImVec4(mainc.x, mainc.y, mainc.z, 0.6)
    colors[clr.TitleBgActive]          = ImVec4(mainc.x, mainc.y, mainc.z, 0.8)
    colors[clr.TitleBgCollapsed]       = ImVec4(mainc.x, mainc.y, mainc.z, 0.40)
	colors[clr.CheckMark]              = ImVec4(mainc.x + 0.13, mainc.y + 0.13, mainc.z + 0.13, 0.8)
	colors[clr.SliderGrab]             = ImVec4(mainc.x, mainc.y, mainc.z, 1.00)
	colors[clr.SliderGrabActive]       = ImVec4(mainc.x, mainc.y, mainc.z, 1.00)
	colors[clr.Button]                 = ImVec4(mainc.x, mainc.y, mainc.z, 0.40)
	colors[clr.ButtonHovered]          = ImVec4(mainc.x, mainc.y, mainc.z, 0.63)
	colors[clr.ButtonActive]           = ImVec4(mainc.x, mainc.y, mainc.z, 0.8)
	colors[clr.Header]                 = ImVec4(mainc.x, mainc.y, mainc.z, 0.40)
	colors[clr.HeaderHovered]          = ImVec4(mainc.x, mainc.y, mainc.z, 0.63)
	colors[clr.HeaderActive]           = ImVec4(mainc.x, mainc.y, mainc.z, 0.8)
	colors[clr.Separator]              = colors[clr.Border]
	colors[clr.SeparatorHovered]       = ImVec4(0.75, 0.10, 0.10, 0.78)
	colors[clr.SeparatorActive]        = ImVec4(0.75, 0.10, 0.10, 1.00)
	colors[clr.ResizeGrip]             = ImVec4(mainc.x, mainc.y, mainc.z, 0.8)
    colors[clr.ResizeGripHovered]      = ImVec4(mainc.x, mainc.y, mainc.z, 0.63)
    colors[clr.ResizeGripActive]       = ImVec4(mainc.x, mainc.y, mainc.z, 0.8)
	colors[clr.TextSelectedBg]         = ImVec4(0.98, 0.26, 0.26, 0.35)
	colors[clr.Text]                   = ImVec4(1.00, 1.00, 1.00, 1.00)
	colors[clr.TextDisabled]           = ImVec4(0.50, 0.50, 0.50, 1.00)
	colors[clr.WindowBg]               = ImVec4(0.06, 0.06, 0.06, 0.94)
	colors[clr.PopupBg]                = ImVec4(0.08, 0.08, 0.08, 0.94)
	colors[clr.Border]                 = ImVec4(0.06, 0.06, 0.06, 0.00)
	colors[clr.BorderShadow]           = ImVec4(0.00, 0.00, 0.00, 0.00)
	colors[clr.MenuBarBg]              = ImVec4(0.14, 0.14, 0.14, 1.00)
	colors[clr.ScrollbarBg]            = ImVec4(0.02, 0.02, 0.02, 0.53)
	colors[clr.ScrollbarGrab]          = ImVec4(mainc.x, mainc.y, mainc.z, 0.8)
	colors[clr.ScrollbarGrabHovered]   = ImVec4(0.41, 0.41, 0.41, 1.00)
	colors[clr.ScrollbarGrabActive]    = ImVec4(0.51, 0.51, 0.51, 1.00)
	colors[clr.PlotLines]              = ImVec4(0.61, 0.61, 0.61, 1.00)
	colors[clr.PlotLinesHovered]       = ImVec4(1.00, 0.43, 0.35, 1.00)
	colors[clr.PlotHistogram]          = ImVec4(0.90, 0.70, 0.00, 1.00)
	colors[clr.PlotHistogramHovered]   = ImVec4(1.00, 0.60, 0.00, 1.00)
end
