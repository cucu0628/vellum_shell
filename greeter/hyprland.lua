-- Vellum greeter compositor: egy minimalis Hyprland, ami csak a Quickshell
-- greetert futtatja. A greetd inditja a greeter felhasznalokent:
--
--   Hyprland --config /usr/share/vellum-greeter/hyprland.lua
--
-- Ez a fajl root tulajdonu marad. Amit a felhasznalo munkamenetebol tudni kell
-- (monitor-elrendezes, billentyuzetkiosztas), az a layout.conf-bol jon: az a
-- felhasznaloe, ezert adatkent, soronkent ellenorizve olvassuk -- egy
-- felhasznalo altal irhato Lua modul tetszoleges kodot futtatna itt.

local state_dir = "/var/lib/vellum-greeter"
local cache_dir = "/var/cache/vellum-greeter"
local shell_dir = "/usr/share/vellum-greeter"

-- A greeter felhasznalonak nincs (vagy nem irhato) home-ja: minden, amit a
-- Quickshell es a Qt irni akar, a sajat gyorsitotarba kerul.
hl.env("XDG_CACHE_HOME", cache_dir .. "/cache")
hl.env("XDG_STATE_HOME", cache_dir .. "/state")
hl.env("XDG_DATA_HOME", cache_dir .. "/data")
hl.env("XDG_CONFIG_HOME", cache_dir .. "/config")
hl.env("VELLUM_GREETER_DIR", state_dir)
hl.env("VELLUM_GREETER_CACHE", cache_dir)
hl.env("QT_QPA_PLATFORM", "wayland")

-- Ugyanazok a mintak, mint a backend/src/greeter.rs-ben: ami ott nem ment at,
-- az ide meg sem erkezhet, de a fajlt kezzel is at lehet irni.
local function matches(value, pattern)
	return value ~= nil and string.match(value, pattern) ~= nil
end

local function valid_output(value)
	return matches(value, "^[%w%-_%.]+$")
end

local keyboard_value = "^[%w_,:()+%-]*$"

-- A rendszer kiosztasa (`localectl set-x11-keymap` / `set-keymap`): ez akkor
-- is ervenyes, ha a layout.conf meg ures, pl. mert a backend nem futott.
local function system_keyboard()
	local result = { kb_layout = "", kb_variant = "", kb_options = "" }
	local xorg = io.open("/etc/X11/xorg.conf.d/00-keyboard.conf", "r")
	if xorg then
		local text = xorg:read("a") or ""
		xorg:close()
		for key, option in pairs({ kb_layout = "XkbLayout", kb_variant = "XkbVariant", kb_options = "XkbOptions" }) do
			local value = string.match(text, 'Option%s+"' .. option .. '"%s+"([^"]*)"')
			if matches(value, keyboard_value) then
				result[key] = value
			end
		end
	end
	if result.kb_layout == "" then
		local vconsole = io.open("/etc/vconsole.conf", "r")
		if vconsole then
			for line in vconsole:lines() do
				-- Az XKBLAYOUT pontos; a KEYMAP konzolos nev (pl. hu101, de-latin1),
				-- abbol csak a nyelvi elotag hasznalhato.
				local layout = string.match(line, '^XKBLAYOUT="?([%w_,]+)"?$')
					or (result.kb_layout == "" and string.match(line, '^KEYMAP="?(%a+)'))
				if layout then
					result.kb_layout = layout
				end
			end
			vconsole:close()
		end
	end
	return result
end

local keyboard = system_keyboard()
local input_screen = nil

local layout = io.open(state_dir .. "/layout.conf", "r")
if layout then
	for line in layout:lines() do
		local key, value = string.match(line, "^([%w_]+)=(.*)$")
		if key == "monitor" then
			local name, mode, position, scale, transform =
				string.match(value, "^(%S+) (%S+) (%S+) (%S+) (%S+)$")
			if
				valid_output(name)
				and matches(mode, "^%d+x%d+@%d+%.?%d*$")
				and matches(position, "^%-?%d+x%-?%d+$")
				and matches(scale, "^%d+%.?%d*$")
				and matches(transform, "^[0-7]$")
			then
				hl.monitor({
					output = name,
					mode = mode,
					position = position,
					scale = tonumber(scale),
					transform = tonumber(transform),
				})
			end
		elseif key == "disabled" and valid_output(value) then
			hl.monitor({ output = value, disabled = true })
		elseif keyboard[key] ~= nil and value ~= "" and matches(value, keyboard_value) then
			-- A munkamenet kiosztasa felulirja a rendszeret; egy ures sor nem.
			keyboard[key] = value
		end
	end
	layout:close()
end

-- A kurzor a jelszomezo kijelzojen induljon.
local screen_file = io.open(state_dir .. "/input-screen", "r")
if screen_file then
	local value = screen_file:read("l")
	screen_file:close()
	if valid_output(value) then
		input_screen = value
	end
end

hl.config({
	input = {
		kb_layout = keyboard.kb_layout ~= "" and keyboard.kb_layout or "us",
		kb_variant = keyboard.kb_variant,
		kb_options = keyboard.kb_options,
		numlock_by_default = true,
	},
	cursor = {
		default_monitor = input_screen or "",
	},
	misc = {
		disable_hyprland_logo = true,
		disable_splash_rendering = true,
		disable_watchdog_warning = true,
	},
	-- A greeter sajat beuszo animaciot hasznal; a compositor fade-je duplazna.
	animations = {
		enabled = false,
	},
})

-- A greetd csak a greeter kilepese utan inditja a munkamenetet: ha a Quickshell
-- kilep (sikeres belepes vagy hiba), a compositornak is ki kell lepnie. A Lua
-- modban a regi `hyprctl dispatch exit` mar nem dispatcher, csak hibat ad.
hl.on("hyprland.start", function()
	hl.exec_cmd("sh -c 'qs -p " .. shell_dir .. '; hyprctl dispatch "hl.dsp.exit()"\'')
end)
