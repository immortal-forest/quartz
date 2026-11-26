-- quartz — Hyprland integration (Lua config, Hyprland ≥ 0.55).
--
-- In your hyprland.lua (or any file it loads):
--
--   local quartz = dofile(os.getenv("HOME") .. "/quartz/hypr/quartz.lua")
--   quartz.setup({ mod = "SUPER", autostart = true, clipboard = true })
--
-- Options (all optional):
--   mod          modifier for the shell keys            (default "SUPER")
--   binds        bind the shell keys                     (default true)
--   media_keys   brightness / mic / play-pause keys      (default true)
--   volume_keys  volume up / down / mute keys            (default true)
--   rules        layer rules: no Hyprland anims, frost behind the power menu (default true)
--   autostart    start quartz when Hyprland starts      (default false)
--   clipboard    start the clipboard-history watchers (cliphist) with Hyprland (default false)
--   restart      command for mod+Shift+R                 (default: kill + relaunch quartz)
--   essentials   a complete keymap for windows, workspaces, apps and screenshots,
--                the one the cheatsheet (Super + /) shows   (default false)
--   take_over    quartz's keys replace whatever your config bound on them
--                before (e.g. Hyprland's example: Super + M = quit) instead of
--                being skipped                                (default false)
--   skip         keys quartz leaves alone because your config uses them,
--                written like quartz writes them: { "SUPER + C", "XF86AudioPlay" }
--   gpu          "integrated": run quartz on the integrated GPU (Mesa) on a
--                hybrid laptop, so NVIDIA's GL libraries stay out of it (~125 MB)
--                and the NVIDIA card can sleep                (default: whatever glvnd picks)
--   drm_devices  GPUs Hyprland uses, by PCI address, first = renders the desktop:
--                { "0000:06:00.0", "0000:01:00.0" } → AQ_DRM_DEVICES. PCI addresses
--                (lspci) stay put; /dev/dri/cardN numbers can change between boots.
--   cursor       cursor theme for Hyprland, apps and GTK, e.g. "Bibata-Modern-Ice"
--                (quartz's, in cursors/; install.sh unpacks it)  (default: leave the cursor alone)
--   cursor_size  cursor size in pixels                    (default 24)
--   prefs        apply Settings › Display & input (screen scale, keyboard, touchpad,
--                cursor size) from ~/.local/state/quartz/hyprland.lua  (default true)
--   colors       window borders in the wallpaper's colours, from the file
--                quartz's matugen config writes (~/.config/hypr/quartz-colors.lua)  (default true)
--
-- The shell keys reach quartz through its global shortcuts
-- (hl.dsp.global("quartz:<name>")), so they work even before you click anything.

local M = {}

local function opt(o, k, d)
	if o[k] == nil then return d end
	return o[k]
end

local function g(name) return hl.dsp.global("quartz:" .. name) end

-- "SUPER + comma" and "super+COMMA" are the same key
local function norm(keys) return (keys:gsub("%s", ""):upper()) end

local skipped = {}   -- filled from setup's `skip`
local take_over = false
local function bind(keys, ...)
	if skipped[norm(keys)] then return end
	if take_over then hl.unbind(keys) end
	return hl.bind(keys, ...)
end
-- the essentials keymap: same rules, its own name so install.sh only checks
-- these keys for clashes when the keymap is on
local ebind = bind

-- bind options carrying a description (shown by `hyprctl binds` and other
-- tools); always a fresh table, so shared flag tables are never modified
local function desc(text, flags)
	local t = { description = "quartz: " .. text }
	for k, v in pairs(flags or {}) do t[k] = v end
	return t
end

local function exists(path)
	local f = io.open(path, "r")
	if f then f:close() return true end
	return false
end

-- The command that starts quartz. gpu = "integrated" pins glvnd to Mesa.
local MESA_EGL = "/usr/share/glvnd/egl_vendor.d/50_mesa.json"
local function qs_cmd(gpu)
	local cmd = "qs -c quartz -d"
	if gpu == "integrated" and exists(MESA_EGL) then
		cmd = "env __EGL_VENDOR_LIBRARY_FILENAMES=" .. MESA_EGL .. " __GLX_VENDOR_LIBRARY_NAME=mesa " .. cmd
	end
	return cmd
end

-- /dev/dri/cardN of the GPU at a PCI address, e.g. "0000:06:00.0"
local function drm_card(pci)
	for n = 0, 31 do
		local f = io.open("/sys/class/drm/card" .. n .. "/device/uevent", "r")
		if f then
			local u = f:read("*a")
			f:close()
			if u:find("PCI_SLOT_NAME=" .. pci, 1, true) then return "/dev/dri/card" .. n end
		end
	end
end

function M.binds(mod, restart)
	bind(mod .. " + Space",     g("launcher"),        desc("App launcher"))              -- app launcher
	bind(mod .. " + V",         g("clipboard"),       desc("Clipboard history"))         -- clipboard history
	bind(mod .. " + Escape",    g("power"),           desc("Power menu"))                -- power / session menu
	bind(mod .. " + A",         g("control"),         desc("Control centre"))            -- control centre
	bind(mod .. " + N",         g("control"),         desc("Notifications"))             -- notifications live in the control centre
	bind(mod .. " + SHIFT + N", g("dnd"),             desc("Do not disturb on / off"))   -- do not disturb
	bind(mod .. " + SHIFT + W", g("wifi"),            desc("Wi-Fi"))                     -- control centre › Wi-Fi
	bind(mod .. " + B",         g("bluetooth"),       desc("Bluetooth"))                 -- control centre › Bluetooth
	bind(mod .. " + SHIFT + A", g("sound"),           desc("Sound devices and apps"))    -- control centre › Sound
	bind(mod .. " + D",         g("calendar"),        desc("Calendar"))                  -- calendar
	bind(mod .. " + M",         g("media"),           desc("Now playing"))               -- now playing
	bind(mod .. " + comma",     g("settings"),        desc("Settings"))                  -- quartz settings
	bind(mod .. " + slash",     g("help"),            desc("Keyboard shortcuts"))        -- keyboard cheatsheet
	bind(mod .. " + C",         g("wallpapers"),      desc("Wallpaper picker"))          -- wallpaper picker
	bind(mod .. " + SHIFT + C", g("randomWallpaper"), desc("Random wallpaper"))          -- random wallpaper
	bind(mod .. " + L",         hl.dsp.exec_cmd("loginctl lock-session"), desc("Lock the screen")) -- lock
	bind(mod .. " + SHIFT + R", hl.dsp.exec_cmd(restart), desc("Restart quartz"))        -- restart quartz
end

-- Hardware keys: `locked` keeps them working on the lock screen, `dont_inhibit`
-- gets past fullscreen games, `repeating` steps while held. The brightnessctl
-- fallback (quartz not running) steps the real level linearly and never goes
-- below 2 % of max (-n = max/50 + 1): some panels switch off at the bottom.
-- A complete keymap (essentials = true): windows, workspaces, apps and
-- screenshots, laid out like the cheatsheet (Super + /).
local TERMINAL = "sh -c '${TERMINAL:-$(command -v ghostty kitty foot alacritty wezterm konsole xterm | head -n 1)}'"
local BROWSER = "sh -c 'b=$(xdg-settings get default-web-browser 2>/dev/null); gtk-launch \"${b%.desktop}\" 2>/dev/null || xdg-open https://'"
local SHOT_ALL = "sh -c 'd=$(xdg-user-dir PICTURES 2>/dev/null || echo \"$HOME/Pictures\")/Screenshots; mkdir -p \"$d\"; f=\"$d/$(date +%Y-%m-%d_%H-%M-%S).png\"; grim \"$f\" && wl-copy < \"$f\" && notify-send -i \"$f\" Screenshot \"Saved and copied\"'"

function M.essentials(mod)
	local rep = { repeating = true }
	-- windows
	ebind(mod .. " + Q",         hl.dsp.window.close(),                  desc("Close the window"))         -- close the window
	ebind("ALT + F4",            hl.dsp.window.close(),                  desc("Close the window"))         -- close the window, the old way
	ebind(mod .. " + W",         hl.dsp.window.float({ action = "toggle" }), desc("Float / tile"))          -- float / tile
	ebind("ALT + Return",        hl.dsp.window.fullscreen(),             desc("Fullscreen"))                -- fullscreen
	ebind(mod .. " + G",         hl.dsp.group.toggle(),                  desc("Group / ungroup"))           -- group / ungroup
	ebind(mod .. " + S",         hl.dsp.workspace.toggle_special("scratch"), desc("Scratchpad"))            -- scratchpad
	for _, d in ipairs({ { "left", -30, 0 }, { "right", 30, 0 }, { "up", 0, -30 }, { "down", 0, 30 } }) do
		ebind(mod .. " + " .. d[1],         hl.dsp.focus({ direction = d[1] }), desc("Focus " .. d[1]))
		ebind(mod .. " + SHIFT + " .. d[1], hl.dsp.window.resize({ x = d[2], y = d[3], relative = true }), desc("Resize", rep))
	end
	ebind(mod .. " + mouse:272", hl.dsp.window.drag(),   desc("Move with the mouse", { mouse = true }))   -- move with the mouse
	ebind(mod .. " + mouse:273", hl.dsp.window.resize(), desc("Resize with the mouse", { mouse = true })) -- resize with the mouse
	-- workspaces
	for i = 1, 10 do
		local key, ws = tostring(i % 10), tostring(i)
		ebind(mod .. " + " .. key,         hl.dsp.focus({ workspace = ws }),                      desc("Workspace " .. ws))
		ebind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = ws }),                desc("Move window to workspace " .. ws))
		ebind(mod .. " + ALT + " .. key,   hl.dsp.window.move({ workspace = ws, follow = false }), desc("Send window to workspace " .. ws))
	end
	ebind(mod .. " + CTRL + left",        hl.dsp.focus({ workspace = "r-1" }),       desc("Previous workspace"))       -- previous workspace
	ebind(mod .. " + CTRL + right",       hl.dsp.focus({ workspace = "r+1" }),       desc("Next workspace"))           -- next workspace
	ebind(mod .. " + CTRL + down",        hl.dsp.focus({ workspace = "empty" }),     desc("First empty workspace"))    -- first empty workspace
	ebind(mod .. " + CTRL + ALT + left",  hl.dsp.window.move({ workspace = "r-1" }), desc("Move window to the previous workspace")) -- move window back
	ebind(mod .. " + CTRL + ALT + right", hl.dsp.window.move({ workspace = "r+1" }), desc("Move window to the next workspace"))     -- move window on
	ebind(mod .. " + mouse_down",         hl.dsp.focus({ workspace = "e+1" }),       desc("Next workspace"))           -- scroll: next workspace
	ebind(mod .. " + mouse_up",           hl.dsp.focus({ workspace = "e-1" }),       desc("Previous workspace"))       -- scroll: previous workspace
	-- apps
	ebind(mod .. " + T",         hl.dsp.exec_cmd(TERMINAL),       desc("Terminal"))      -- terminal
	ebind(mod .. " + F",         hl.dsp.exec_cmd(BROWSER),        desc("Web browser"))   -- web browser
	ebind(mod .. " + E",         hl.dsp.exec_cmd("xdg-open " .. os.getenv("HOME")), desc("Files")) -- files
	-- screenshots (hyprshot; grim for all monitors)
	ebind(mod .. " + P",         hl.dsp.exec_cmd("hyprshot -m region"),           desc("Screenshot a region"))         -- screenshot a region
	ebind(mod .. " + CTRL + P",  hl.dsp.exec_cmd("hyprshot -m region -z"),        desc("Screenshot a region, frozen")) -- frozen region
	ebind(mod .. " + ALT + P",   hl.dsp.exec_cmd("hyprshot -m output -m active"), desc("Screenshot this monitor"))     -- this monitor
	ebind("Print",               hl.dsp.exec_cmd(SHOT_ALL),                       desc("Screenshot all monitors"))     -- all monitors
end

function M.media_keys()
	local hw  = { locked = true, dont_inhibit = true }
	local hwr = { locked = true, repeating = true, dont_inhibit = true }
	bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("sh -c 'qs -c quartz ipc call quartz brightness 5 || brightnessctl -n$(($(brightnessctl max) / 50 + 1)) set 5%+'"), desc("Brightness up", hwr)) -- brightness up
	bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("sh -c 'qs -c quartz ipc call quartz brightness -- -5 || brightnessctl -n$(($(brightnessctl max) / 50 + 1)) set 5%-'"), desc("Brightness down", hwr)) -- brightness down
	bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), desc("Microphone mute", hw)) -- mic mute (quartz shows the OSD from Pipewire)
	bind("XF86AudioPlay",         g("mediaToggle"), desc("Play / pause", hw)) -- play / pause
	bind("XF86AudioNext",         g("mediaNext"),   desc("Next track", hw)) -- next track
	bind("XF86AudioPrev",         g("mediaPrev"),   desc("Previous track", hw)) -- previous track
end

function M.volume_keys()
	bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), desc("Mute", { locked = true, dont_inhibit = true })) -- mute
	bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), desc("Volume down", { locked = true, repeating = true, dont_inhibit = true })) -- volume down
	bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"), desc("Volume up", { locked = true, repeating = true, dont_inhibit = true })) -- volume up
end

-- The cursor, everywhere: Hyprland (hyprcursor falls back to XCursor for an
-- XCursor-only theme like Bibata), apps (XCURSOR_*) and GTK (gsettings).
-- XCURSOR_PATH names ~/.local/share/icons first: native-Wayland Qt and Electron
-- apps read cursors through libwayland-cursor, which may not look there, and
-- fall back to a black cursor. setcursor runs on every config load, so a
-- reload re-applies it.
function M.cursor(theme, size)
	local home = os.getenv("HOME")
	size = tostring(size)
	hl.env("XCURSOR_THEME", theme)
	hl.env("XCURSOR_SIZE", size)
	hl.env("HYPRCURSOR_THEME", theme)
	hl.env("HYPRCURSOR_SIZE", size)
	hl.env("XCURSOR_PATH", home .. "/.local/share/icons:" .. home .. "/.icons:/usr/share/icons:/usr/share/pixmaps")
	hl.exec_cmd("hyprctl setcursor '" .. theme .. "' " .. size)
	hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-theme '" .. theme .. "'; gsettings set org.gnome.desktop.interface cursor-size " .. size)
end

-- Settings › Display & input: screen scale, keyboard, touchpad and cursor
-- size, written by quartz to ~/.local/state/quartz/hyprland.lua (a table).
function M.prefs()
	local ok, p = pcall(dofile, os.getenv("HOME") .. "/.local/state/quartz/hyprland.lua")
	if not ok or type(p) ~= "table" then return {} end
	for name, scale in pairs(p.monitors or {}) do
		hl.monitor({ output = name, mode = "preferred", position = "auto", scale = scale })
	end
	local input, touchpad = {}, {}
	if type(p.kb_layout) == "string" and p.kb_layout ~= "" then
		input.kb_layout = p.kb_layout
		if p.kb_layout:find(",") then input.kb_options = "grp:alt_shift_toggle" end
	end
	if type(p.sensitivity) == "number" then input.sensitivity = p.sensitivity end
	if p.natural_scroll ~= nil then touchpad.natural_scroll = p.natural_scroll end
	if p.tap_to_click ~= nil then touchpad.tap_to_click = p.tap_to_click end
	if next(touchpad) then input.touchpad = touchpad end
	if next(input) then hl.config({ input = input }) end
	return p
end

-- Window borders in the wallpaper's colours: matugen writes them (quartz's
-- config/matugen) whenever the wallpaper changes, then reloads Hyprland.
function M.colors()
	local ok, c = pcall(dofile, (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/hypr/quartz-colors.lua")
	if ok and type(c) == "table" and c.active then
		-- two colours = a gradient, which Lua config takes as a table (not a string)
		local function col(v) return type(v) == "table" and { colors = v, angle = 45 } or v end
		hl.config({ general = { col = { active_border = col(c.active), inactive_border = col(c.inactive) } } })
	end
end

-- quartz's surfaces are solid (one colour for the bar and the panels hanging
-- from it), so they need no blur; quartz animates them itself, so Hyprland
-- doesn't. quartz-frost = the power menu's whole-screen frosted backdrop.
function M.rules()
	hl.layer_rule({
		name  = "quartz-bar",
		match = { namespace = "^quartz-bar$" },
		animation = "slide top",
	})
	hl.layer_rule({
		name  = "quartz-surfaces",
		match = { namespace = "^quartz-(panel|toast|osd|overlay)$" },
		no_anim = true,
	})
	-- the settings window: a normal app window, floated and centred, with
	-- quartz's panel radius and no border so it reads as part of the shell;
	-- it's opaque, so nothing gets blurred behind it
	hl.window_rule({
		name  = "quartz-settings",
		match = { class = "^org\\.quickshell$", title = "^Settings · quartz$" },
		float = true,
		center = true,
		rounding = 24,
		border_size = 0,
		no_blur = true,
	})
	hl.layer_rule({
		name  = "quartz-frost",
		match = { namespace = "^quartz-frost$" },
		blur         = true,
		ignore_alpha = false,
		no_anim      = true,
	})
end

function M.setup(o)
	o = o or {}
	local mod = opt(o, "mod", "SUPER")
	local qs = qs_cmd(opt(o, "gpu", nil))
	local restart = opt(o, "restart", "sh -c 'qs kill -c quartz; sleep 0.3; " .. qs .. "'")
	skipped = {}
	for _, k in ipairs(opt(o, "skip", {})) do skipped[norm(k)] = true end
	take_over = opt(o, "take_over", false)
	local drm = opt(o, "drm_devices", nil)
	if drm then
		local cards = {}
		for _, pci in ipairs(drm) do
			local c = drm_card(pci)
			if c then cards[#cards + 1] = c end
		end
		if #cards > 0 then hl.env("AQ_DRM_DEVICES", table.concat(cards, ":")) end
	end
	local prefs = opt(o, "prefs", true) and M.prefs() or {}
	local cursor = opt(o, "cursor", nil)
	if cursor then M.cursor(cursor, prefs.cursor_size or opt(o, "cursor_size", 24)) end
	if opt(o, "binds", true) then M.binds(mod, restart) end
	if opt(o, "essentials", false) then M.essentials(mod) end
	if opt(o, "media_keys", true) then M.media_keys() end
	if opt(o, "volume_keys", true) then M.volume_keys() end
	if opt(o, "rules", true) then M.rules() end
	if opt(o, "colors", true) then M.colors() end
	-- NVIDIA: hardware cursors flicker or vanish on its outputs
	if opt(o, "nvidia_cursor_fix", true) and exists("/proc/driver/nvidia/version") then
		hl.config({ cursor = { no_hardware_cursors = true } })
	end
	if opt(o, "autostart", false) then
		hl.on("hyprland.start", function() hl.exec_cmd(qs) end)
	end
	if opt(o, "clipboard", false) then
		hl.on("hyprland.start", function()
			hl.exec_cmd("wl-paste --type text --watch cliphist store")
			hl.exec_cmd("wl-paste --type image --watch cliphist store")
		end)
	end
end

return M
