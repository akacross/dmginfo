script_name("Dmginfo")
script_author("akacross")
script_url("https://akacross.net/")

local script_version = 1.2

if getMoonloaderVersion() >= 27 then
	require 'libstd.deps' {
	   'fyp:mimgui',
	   'fyp:fa-icons-4',
	   --'donhomka:mimgui-addons',
	   'donhomka:extensions-lite'
	}
end

require"lib.moonloader"
require"lib.sampfuncs"
require"extensions-lite"

local imgui, ffi = require 'mimgui', require 'ffi'
local new, str, sizeof = imgui.new, ffi.string, ffi.sizeof
local vk = require 'vkeys'
local mem = require 'memory'
local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8
local lfs = require 'lfs'
--local mimgui_addons = require 'mimgui_addons'
local faicons = require 'fa-icons'
local ti = require 'tabler_icons'
local ped, h = playerPed, playerHandle
local sampev = require 'lib.samp.events'
local flag = require ('moonloader').font_flag
local path = getWorkingDirectory() .. '\\config\\'
local cfg = path .. 'dmginfo.ini'
local dlstatus = require('moonloader').download_status
local https = require 'ssl.https'
local audiopath = getGameDirectory() .. "\\moonloader\\resource\\audio\\dmginfo"
local script_path = thisScript().path
local script_url = "https://raw.githubusercontent.com/akacross/dmginfo/main/dmginfo.lua"
local update_url = "https://raw.githubusercontent.com/akacross/dmginfo/main/dmginfo.txt"

local function loadIconicFont(fontSize)
    local config = imgui.ImFontConfig()
    config.MergeMode = true
    config.PixelSnapH = true
    local iconRanges = imgui.new.ImWchar[3](ti.min_range, ti.max_range, 0)
    imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(ti.get_font_data_base85(), fontSize, config, iconRanges)
end

local blank = {}
local dmg = {
	toggle = {true,true},
	autosave = false,
	font = {'Aerial','Aerial'},
	fontsize = {12,12},
	fontflag = {{true, false, true, true},{true, false, true, true}},
	color = {-1, -1},
	time = {3, 3},
	audio = {
		toggle = {true,true,false,false},
		sounds = {
			"sound1.mp3",
			"sound2.mp3",
			"sound3.mp3",
			"sound4.mp3"
		},
		paths = {
			audiopath .. "\\sound1.mp3",
			audiopath .. "\\sound2.mp3",
			audiopath .. "\\sound3.mp3",
			audiopath .. "\\sound4.mp3"
		},
		volumes = {
			0.10,
			0.10,
			0.10,
			0.10,
		}
	},
}
local main_window_state = new.bool(false)
local mainc = imgui.ImVec4(0.92, 0.27, 0.92, 1.0)
local fontid = {}
local giveDamage = {}
local takeDamage = {}
local update = false
local paths = {}

function main()
	blank = table.deepcopy(dmg)
	if not doesDirectoryExist(path) then createDirectory(path) end
	if doesFileExist(cfg) then loadIni() else blankIni() end

	repeat wait(0) until isSampAvailable()
	repeat wait(0) until sampGetGamestate() == 3
	
	update_script()

	paths = scanGameFolder(audiopath, paths)

	for i = 1, 2 do
		createfont(i)
	end

	sampRegisterChatCommand("dmg", function() 
		if not update then
			main_window_state[0] = not main_window_state[0] 
		else
			sampAddChatMessage("{ABB2B9}[dmginfo]{FFFFFF} The update is in progress.. Please wait..", -1)
		end
	end)
	
	while true do wait(0)
		if update then
			lua_thread.create(function() 
				wait(10000) 
				thisScript():reload()
				update = false
			end)
		end
	end
end

function apply_custom_style()
   local style = imgui.GetStyle()
   local colors = style.Colors
   local clr = imgui.Col
   local ImVec4 = imgui.ImVec4
   style.WindowRounding = 1.5
   style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
   style.FrameRounding = 1.0
   style.ItemSpacing = imgui.ImVec2(4.0, 4.0)
   style.ScrollbarSize = 13.0
   style.ScrollbarRounding = 0
   style.GrabMinSize = 8.0
   style.GrabRounding = 1.0
   style.WindowBorderSize = 0.0
   style.WindowPadding = imgui.ImVec2(4.0, 4.0)
   style.FramePadding = imgui.ImVec2(2.5, 3.5)
   style.ButtonTextAlign = imgui.ImVec2(0.5, 0.35)

   colors[clr.Text]                   = ImVec4(1.00, 1.00, 1.00, 1.00)
   colors[clr.TextDisabled]           = ImVec4(0.7, 0.7, 0.7, 1.0)
   colors[clr.WindowBg]               = ImVec4(0.07, 0.07, 0.07, 1.0)
   colors[clr.PopupBg]                = ImVec4(0.08, 0.08, 0.08, 0.94)
   colors[clr.Border]                 = ImVec4(mainc.x, mainc.y, mainc.z, 0.4)
   colors[clr.BorderShadow]           = ImVec4(0.00, 0.00, 0.00, 0.00)
   colors[clr.FrameBg]                = ImVec4(mainc.x, mainc.y, mainc.z, 0.7)
   colors[clr.FrameBgHovered]         = ImVec4(mainc.x, mainc.y, mainc.z, 0.4)
   colors[clr.FrameBgActive]          = ImVec4(mainc.x, mainc.y, mainc.z, 0.9)
   colors[clr.TitleBg]                = ImVec4(mainc.x, mainc.y, mainc.z, 1.0)
   colors[clr.TitleBgActive]          = ImVec4(mainc.x, mainc.y, mainc.z, 1.0)
   colors[clr.TitleBgCollapsed]       = ImVec4(mainc.x, mainc.y, mainc.z, 0.79)
   colors[clr.MenuBarBg]              = ImVec4(0.14, 0.14, 0.14, 1.00)
   colors[clr.ScrollbarBg]            = ImVec4(0.02, 0.02, 0.02, 0.53)
   colors[clr.ScrollbarGrab]          = ImVec4(mainc.x, mainc.y, mainc.z, 0.8)
   colors[clr.ScrollbarGrabHovered]   = ImVec4(0.41, 0.41, 0.41, 1.00)
   colors[clr.ScrollbarGrabActive]    = ImVec4(0.51, 0.51, 0.51, 1.00)
   colors[clr.CheckMark]              = ImVec4(mainc.x + 0.13, mainc.y + 0.13, mainc.z + 0.13, 1.00)
   colors[clr.SliderGrab]             = ImVec4(0.28, 0.28, 0.28, 1.00)
   colors[clr.SliderGrabActive]       = ImVec4(0.35, 0.35, 0.35, 1.00)
   colors[clr.Button]                 = ImVec4(mainc.x, mainc.y, mainc.z, 0.8)
   colors[clr.ButtonHovered]          = ImVec4(mainc.x, mainc.y, mainc.z, 0.63)
   colors[clr.ButtonActive]           = ImVec4(mainc.x, mainc.y, mainc.z, 1.0)
   colors[clr.Header]                 = ImVec4(mainc.x, mainc.y, mainc.z, 0.6)
   colors[clr.HeaderHovered]          = ImVec4(mainc.x, mainc.y, mainc.z, 0.43)
   colors[clr.HeaderActive]           = ImVec4(mainc.x, mainc.y, mainc.z, 0.8)
   colors[clr.Separator]              = colors[clr.Border]
   colors[clr.SeparatorHovered]       = ImVec4(0.26, 0.59, 0.98, 0.78)
   colors[clr.SeparatorActive]        = ImVec4(0.26, 0.59, 0.98, 1.00)
   colors[clr.ResizeGrip]             = ImVec4(mainc.x, mainc.y, mainc.z, 0.8)
   colors[clr.ResizeGripHovered]      = ImVec4(mainc.x, mainc.y, mainc.z, 0.63)
   colors[clr.ResizeGripActive]       = ImVec4(mainc.x, mainc.y, mainc.z, 1.0)
   colors[clr.PlotLines]              = ImVec4(0.61, 0.61, 0.61, 1.00)
   colors[clr.PlotLinesHovered]       = ImVec4(1.00, 0.43, 0.35, 1.00)
   colors[clr.PlotHistogram]          = ImVec4(0.90, 0.70, 0.00, 1.00)
   colors[clr.PlotHistogramHovered]   = ImVec4(1.00, 0.60, 0.00, 1.00)
   colors[clr.TextSelectedBg]         = ImVec4(0.26, 0.59, 0.98, 0.35)
end

-- imgui.OnInitialize() called only once, before the first render
imgui.OnInitialize(function()
	apply_custom_style() -- apply custom style
	local defGlyph = imgui.GetIO().Fonts.ConfigData.Data[0].GlyphRanges
	imgui.GetIO().Fonts:Clear() -- clear the fonts
	local font_config = imgui.ImFontConfig() -- each font has its own config
	font_config.SizePixels = 14.0;
	font_config.GlyphExtraSpacing.x = 0.1
	-- main font
	local def = imgui.GetIO().Fonts:AddFontFromFileTTF(getFolderPath(0x14) .. '\\arialbd.ttf', font_config.SizePixels, font_config, defGlyph)

	local config = imgui.ImFontConfig()
	config.MergeMode = true
	config.PixelSnapH = true
	config.FontDataOwnedByAtlas = false
	config.GlyphOffset.y = 1.0 -- offset 1 pixel from down
	local fa_glyph_ranges = new.ImWchar[3]({ faicons.min_range, faicons.max_range, 0 })
	-- icons
	local faicon = imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(faicons.get_font_data_base85(), font_config.SizePixels, config, fa_glyph_ranges)

	loadIconicFont(14)

	imgui.GetIO().ConfigWindowsMoveFromTitleBarOnly = true
	imgui.GetIO().IniFilename = nil
end)

imgui.OnFrame(function() return main_window_state[0] end,
function()
	local width, height = getScreenResolution()
	imgui.SetNextWindowPos(imgui.ImVec2(width / 2, height / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
	
	imgui.Begin(ti.ICON_SETTINGS .. string.format("%s Settings - Version: %s", script.this.name,script.this.version), main_window_state, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize)
	
		if imgui.Button(ti.ICON_DEVICE_FLOPPY.. 'Save') then
			saveIni()
		end 
		imgui.SameLine()
		if imgui.Button(ti.ICON_FILE_UPLOAD.. 'Load') then
			loadIni()
		end 
		imgui.SameLine()
		if imgui.Button(ti.ICON_ERASER .. 'Reset') then
			blankIni()
		end 
		imgui.SameLine()
		if imgui.Button(ti.ICON_REFRESH .. 'Update') then
			update_script()
			sampAddChatMessage("{ABB2B9}[dmginfo]{FFFFFF} Checking for updates!", -1)
		end 
		imgui.SameLine()
		if imgui.Checkbox('Autosave', new.bool(dmg.autosave)) then 
			dmg.autosave = not dmg.autosave 
			saveIni() 
		end  
		
			local names = {'Give:', 'Take:', 'Kill:', 'Death:'}
			for i = 1, 4 do
				if i >= 1 and i <= 2 then
					imgui.NewLine()	
					imgui.SameLine(4) 
					imgui.Text(names[i]) 
				
					
					if imgui.Checkbox('##'..i, new.bool(dmg.toggle[i])) then 
						dmg.toggle[i] = not dmg.toggle[i]
					end  
					imgui.SameLine()
				
					if dmg.toggle[i] then
						
						imgui.PushItemWidth(95) 
						text = new.char[30](dmg.font[i])
						if imgui.InputText('##font'..i, text, sizeof(text), imgui.InputTextFlags.EnterReturnsTrue) then
							dmg.font[i] = u8:decode(str(text))
							createfont(i)
						end
						imgui.PopItemWidth()
						
						imgui.SameLine()
						local choices2 = {'Bold', 'Italics', 'Border', 'Shadow'}
						imgui.PushItemWidth(60)
						if imgui.BeginCombo("##flags"..i, 'Flags') then
							for k = i, #choices2 do
								if imgui.Checkbox(choices2[k], new.bool(dmg.fontflag[i][k])) then
									dmg.fontflag[i][k] = not dmg.fontflag[i][k]
									createfont(i)
								end
							end
							imgui.EndCombo()
						end
						imgui.PopItemWidth()
						
						imgui.SameLine()	
						imgui.PushItemWidth(95) 
						tcolor = new.float[4](hex2rgba(dmg.color[i]))
						if imgui.ColorEdit4('##color'..i, tcolor, imgui.ColorEditFlags.NoInputs + imgui.ColorEditFlags.NoLabel) then 
							dmg.color[i] = join_argb(tcolor[3] * 255, tcolor[0] * 255, tcolor[1] * 255, tcolor[2] * 255) 
						end 
						imgui.PopItemWidth()
						
						if imgui.IsItemHovered() then
							imgui.SetTooltip('Color of text')
						end
						
						imgui.SameLine()
						imgui.BeginGroup()
							if imgui.Button('+##'..i) and dmg.fontsize[i] < 72 then 
								dmg.fontsize[i] = dmg.fontsize[i] + 1 
								createfont(i)
							end
							
							imgui.SameLine()
							imgui.Text(tostring(dmg.fontsize[i]))
							imgui.SameLine()
							
							if imgui.Button('-##'..i) and dmg.fontsize[i] > 4 then 
								dmg.fontsize[i] = dmg.fontsize[i] - 1 
								createfont(i)
							end
						imgui.EndGroup()
						imgui.SameLine() 
						
						if imgui.IsItemHovered() then
							imgui.SetTooltip('Size of text')
						end
						
						imgui.SameLine()
						imgui.BeginGroup()
							if imgui.Button('+##2'..i) and dmg.time[i] < 10 then 
								dmg.time[i] = dmg.time[i] + 1 
								createfont(i)
							end
							
							imgui.SameLine()
							imgui.Text(tostring(dmg.time[i]))
							imgui.SameLine()
							
							if imgui.Button('-##2'..i) and dmg.time[i] > 1 then 
								dmg.time[i] = dmg.time[i] - 1 
								createfont(i)
							end
						imgui.EndGroup()
						
						if imgui.IsItemHovered() then
							imgui.SetTooltip('Displayed time')
						end
						
						sound_dropdownmenu(i)
					else
						imgui.Text('Disabled') 
					end
				end
				
				if i == 3 or i == 4 then	
					imgui.NewLine()	
					imgui.SameLine(4) 
					imgui.Text(names[i])
					sound_dropdownmenu(i)
				end
			end
	imgui.End()
end)

function sound_dropdownmenu(i)
	if imgui.Checkbox('##3'..i, new.bool(dmg.audio.toggle[i])) then 
		dmg.audio.toggle[i] = not dmg.audio.toggle[i]
	end  
	imgui.SameLine()
	
	if dmg.audio.toggle[i] then
	
		imgui.PushItemWidth(150)
			if imgui.BeginCombo("##sounds"..i, dmg.audio.sounds[i]) then
				for k, v in pairs(paths) do
					k = tostring(k)
					if k:match(".+%.mp3") or k:match(".+%.mp4") or k:match(".+%.wav") or k:match(".+%.m4a") or k:match(".+%.flac") or k:match(".+%.m4r") or k:match(".+%.ogg") or k:match(".+%.mp2") or k:match(".+%.amr") or k:match(".+%.wma") or k:match(".+%.aac") or k:match(".+%.aiff") then
						if imgui.Selectable(u8(k), true) then 
							dmg.audio.sounds[i] = k
							dmg.audio.paths[i] = v
							if doesFileExist(dmg.audio.paths[i]) then
								sound_play = loadAudioStream(dmg.audio.paths[i])
								setAudioStreamVolume(sound_play, dmg.audio.volumes[i])
								setAudioStreamState(sound_play, 1)
							else 
								sampAddChatMessage("{ABB2B9}[dmginfo]{FFFFFF} Error missing sound file.")
							end
						end
					end
				end
				imgui.EndCombo()
			end
		imgui.PopItemWidth()
		
		imgui.SameLine()
		
		imgui.PushItemWidth(150)
		local volume = new.float[1](dmg.audio.volumes[i])
		if imgui.SliderFloat(u8'##Volume##' .. i, volume, 0, 1) then
			dmg.audio.volumes[i] = volume[0]
		end
		imgui.PopItemWidth()
		
		if imgui.IsItemHovered() then
			imgui.SetTooltip('Volume Control')
		end
		
		
	else
		imgui.Text('Disabled') 
	end
	
end

function scanGameFolder(path, tables)
    for file in lfs.dir(path) do
        if file ~= "." and file ~= ".." then
            local f = path..'\\'..file
            --print ("\t "..f)
			--local file3 = string.gsub(file_extension, "(.+)%..+", "Test")
			local file_extension = string.match(file, "([^\\%.]+)$") -- Avoids double "extension" file names from being included and seen as "audiofile"
            if file_extension:match("mp3") or file_extension:match("mp4") or file_extension:match("wav") or file_extension:match("m4a") or file_extension:match("flac") or file_extension:match("m4r") or file_extension:match("ogg")
			or file_extension:match("mp2") or file_extension:match("amr") or file_extension:match("wma") or file_extension:match("aac") or file_extension:match("aiff") then
				table.insert(tables, file)
                tables[file] = f
            end 
            if lfs.attributes(f, "mode") == "directory" then
                tables = scanGameFolder(f, tables)
            end 
        end
    end
    return tables
end

function onD3DPresent()
	for k, v in pairs(giveDamage) do
		if os.time() > v["time"] then
			table.remove(giveDamage, k)
		else
			if not isPauseMenuActive() and not sampIsDialogActive() and not sampIsScoreboardOpen() and not isSampfuncsConsoleActive() and sampGetChatDisplayMode() > 0 and dmg.toggle[1] then
				local px, py, pz = getCharCoordinates(ped)
				local x, y, z = v["pos"].x, v["pos"].y, v["pos"].z
				if isLineOfSightClear(px, py, pz, x, y, z, false, false, false, false, false) and isPointOnScreen(x, y, z, 0.0) then
					local sx, sy = convert3DCoordsToScreen(x, y, z)
					renderFontDrawText(fontid[1], '+' .. tostring(math.floor(v["damage"])), sx, sy, v["color"])
				end
			end
		end
	end

	for k, v in pairs(takeDamage) do
		if os.time() > v["time"] then
			table.remove(takeDamage, k)
		else
			if not isPauseMenuActive() and not sampIsDialogActive() and not sampIsScoreboardOpen() and not isSampfuncsConsoleActive() and sampGetChatDisplayMode() > 0 and dmg.toggle[2] then
				local px, py, pz = getCharCoordinates(ped)
				local x, y, z = v["pos"].x, v["pos"].y, v["pos"].z
				if isLineOfSightClear(px, py, pz, x, y, z, false, false, false, false, false) and isPointOnScreen(x, y, z, 0.0) then
					local sx, sy = convert3DCoordsToScreen(x, y, z)
					renderFontDrawText(fontid[2], '-' .. tostring(math.floor(v["damage"])), sx, sy, v["color"])
				end
			end
		end
	end
end

function sampev.onSendGiveDamage(targetID, damage, weapon, Bodypart)
	if math.floor(damage) ~= 0 then
		if dmg.toggle[1] then
			local result, playerhandle = sampGetCharHandleBySampPlayerId(targetID)
			if result then
				local px, py, pz = getCharCoordinates(playerhandle)
				local tbl = {
					["color"] = dmg.color[1],
					["damage"] = damage,
					["time"] = os.time() + dmg.time[1],
					["pos"] = {
						x = px,
						y = py,
						z = pz
					}
				}
				table.insert(giveDamage, tbl);
			end

			if dmg.audio.toggle[1] then
				if doesFileExist(dmg.audio.paths[1]) then
					sound_give = loadAudioStream(dmg.audio.paths[1])
					setAudioStreamVolume(sound_give, dmg.audio.volumes[1])
					setAudioStreamState(sound_give, 1)
				else
					sampAddChatMessage("{ABB2B9}[dmginfo]{FFFFFF} Error missing sound file.")
				end
			end
		end
	end
end

function sampev.onSendTakeDamage(senderID, damage, weapon, Bodypart)
	if math.floor(damage) ~= 0 then
		if dmg.toggle[2] then
			local px, py, pz = getCharCoordinates(ped)
			local tbl = {
				["color"] = dmg.color[2],
				["damage"] = damage,
				["time"] = os.time() + dmg.time[2],
				["pos"] = {
					x = px,
					y = py,
					z = pz
				}
			}
			table.insert(takeDamage, tbl);

			if dmg.audio.toggle[2] then
				if doesFileExist(dmg.audio.paths[2]) then
					sound_take = loadAudioStream(dmg.audio.paths[2])
					setAudioStreamVolume(sound_take, dmg.audio.volumes[2])
					setAudioStreamState(sound_take, 1)
				else
					sampAddChatMessage("{ABB2B9}[dmginfo]{FFFFFF} Error missing sound file.")
				end
			end
		end
	end
end

function sampev.onPlayerDeathNotification(killerid, killedid, reason)
	local res, id = sampGetPlayerIdByCharHandle(PLAYER_PED)
	if res then
		if killerid == id then
			if dmg.audio.toggle[3] then
				if doesFileExist(dmg.audio.paths[3]) then
					sound_kill = loadAudioStream(dmg.audio.paths[3])
					setAudioStreamVolume(sound_kill, dmg.audio.volumes[3])
					setAudioStreamState(sound_kill, 1)
				else
					sampAddChatMessage("{ABB2B9}[dmginfo]{FFFFFF} Error missing sound file.")
				end
			end
		end
		if killedid == id then
			if dmg.audio.toggle[4] then
				if doesFileExist(dmg.audio.paths[4]) then
					sound_death = loadAudioStream(dmg.audio.paths[4])
					setAudioStreamVolume(sound_death, dmg.audio.volumes[4])
					setAudioStreamState(sound_death, 1)
				else
					sampAddChatMessage("{ABB2B9}[dmginfo]{FFFFFF} Error missing sound file.")
				end
			end
		end
	end
end

function onScriptTerminate(scr, quitGame)
	if scr == script.this then
		if dmg.autosave then
			saveIni()
		end
	end
end

function createfont(id)
	local flags, flagids = {}, {flag.BOLD,flag.ITALICS,flag.BORDER,flag.SHADOW}
	for i = 1, 4 do
		flags[i] = dmg.fontflag[id][i] and flagids[i] or 0
	end
	fontid[id] = renderCreateFont(dmg.font[id], dmg.fontsize[id], flags[1] + flags[2] + flags[3] + flags[4])
end

function blankIni()
	dmg = table.deepcopy(blank)
	saveIni()
	loadIni()
end

function loadIni()
	local f = io.open(cfg, "r") if f then dmg = decodeJson(f:read("*all")) f:close() end
end

function saveIni()
	if type(dmg) == "table" then local f = io.open(cfg, "w") f:close() if f then local f = io.open(cfg, "r+") f:write(encodeJson(dmg)) f:close() end end
end

function hex2rgba(rgba)
	local a = bit.band(bit.rshift(rgba, 24),	0xFF)
	local r = bit.band(bit.rshift(rgba, 16),	0xFF)
	local g = bit.band(bit.rshift(rgba, 8),		0xFF)
	local b = bit.band(rgba, 0xFF)
	return r / 255, g / 255, b / 255, a / 255
end

function hex2rgba_int(rgba)
	local a = bit.band(bit.rshift(rgba, 24),	0xFF)
	local r = bit.band(bit.rshift(rgba, 16),	0xFF)
	local g = bit.band(bit.rshift(rgba, 8),		0xFF)
	local b = bit.band(rgba, 0xFF)
	return r, g, b, a
end

function hex2rgb(rgba)
	local a = bit.band(bit.rshift(rgba, 24),	0xFF)
	local r = bit.band(bit.rshift(rgba, 16),	0xFF)
	local g = bit.band(bit.rshift(rgba, 8),		0xFF)
	local b = bit.band(rgba, 0xFF)
	return r / 255, g / 255, b / 255
end

function hex2rgb_int(rgba)
	local a = bit.band(bit.rshift(rgba, 24),	0xFF)
	local r = bit.band(bit.rshift(rgba, 16),	0xFF)
	local g = bit.band(bit.rshift(rgba, 8),		0xFF)
	local b = bit.band(rgba, 0xFF)
	return r, g, b
end

function join_argb(a, r, g, b)
	local argb = b  -- b
	argb = bit.bor(argb, bit.lshift(g, 8))  -- g
	argb = bit.bor(argb, bit.lshift(r, 16)) -- r
	argb = bit.bor(argb, bit.lshift(a, 24)) -- a
	return argb
end

function join_argb_int(a, r, g, b)
	local argb = b * 255
    argb = bit.bor(argb, bit.lshift(g * 255, 8))
    argb = bit.bor(argb, bit.lshift(r * 255, 16))
    argb = bit.bor(argb, bit.lshift(a, 24))
    return argb
end

function update_script()
	update_text = https.request(update_url)
	update_version = update_text:match("version: (.+)")
	if tonumber(update_version) > script_version then
		sampAddChatMessage("{ABB2B9}[dmginfo]{FFFFFF} New version found! The update is in progress..", -1)
		downloadUrlToFile(script_url, script_path, function(id, status)
			if status == dlstatus.STATUS_ENDDOWNLOADDATA then
				sampAddChatMessage("{ABB2B9}[dmginfo]{FFFFFF} The update was successful!", -1)
				update = true
			end
		end)
	end
end