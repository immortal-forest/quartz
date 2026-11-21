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
--   skip         keys quartz leaves alone because your config uses them,
--                written like quartz writes them: { "SUPER + C", "XF86AudioPlay" }
--   gpu          "integrated": run quartz on the integrated GPU (Mesa) on a
--                hybrid laptop, so NVIDIA's GL libraries stay out of it (~125 MB)
--                and the NVIDIA card can sleep                (default: whatever glvnd picks)
--   drm_devices  GPUs Hyprland uses, by PCI address, first = renders the desktop:
--                { "0000:06:00.0", "0000:01:00.0" } → AQ_DRM_DEVICES. PCI addresses
--                (lspci) stay put; /dev/dri/cardN numbers can change between boots.
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

local skipped = {} -- filled from setup's `skip`
local function bind(keys, ...)
	if skipped[norm(keys)] then return end
	return hl.bind(keys, ...)
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
	bind(mod .. " + Space",     g("launcher"))        -- app launcher
	bind(mod .. " + V",         g("clipboard"))       -- clipboard history
	bind(mod .. " + Escape",    g("power"))           -- power / session menu
	bind(mod .. " + A",         g("control"))         -- control centre
	bind(mod .. " + N",         g("control"))         -- notifications live in the control centre
	bind(mod .. " + K",         g("wifi"))            -- control centre › Wi-Fi
	bind(mod .. " + D",         g("calendar"))        -- calendar
	bind(mod .. " + M",         g("media"))           -- now playing
	bind(mod .. " + comma",     g("settings"))        -- quartz settings
	bind(mod .. " + slash",     g("help"))            -- keyboard cheatsheet
	bind(mod .. " + C",         g("wallpapers"))      -- wallpaper picker
	bind(mod .. " + SHIFT + C", g("randomWallpaper")) -- random wallpaper
	bind(mod .. " + L",         hl.dsp.exec_cmd("loginctl lock-session")) -- lock
	bind(mod .. " + SHIFT + R", hl.dsp.exec_cmd(restart))                -- restart quartz
end

-- Hardware keys: `locked` keeps them working on the lock screen, `dont_inhibit`
-- gets past fullscreen games, `repeating` steps while held. The brightnessctl
-- fallback (quartz not running) steps the real level linearly and never goes
-- below 2 % of max (-n = max/50 + 1): some panels switch off at the bottom.
function M.media_keys()
	local hw  = { locked = true, dont_inhibit = true }
	local hwr = { locked = true, repeating = true, dont_inhibit = true }
	bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("sh -c 'qs -c quartz ipc call quartz brightness 5 || brightnessctl -n$(($(brightnessctl max) / 50 + 1)) set 5%+'"), hwr) -- brightness up
	bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("sh -c 'qs -c quartz ipc call quartz brightness -- -5 || brightnessctl -n$(($(brightnessctl max) / 50 + 1)) set 5%-'"), hwr) -- brightness down
	bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), hw) -- mic mute (quartz shows the OSD from Pipewire)
	bind("XF86AudioPlay",         g("mediaToggle"), hw) -- play / pause
	bind("XF86AudioNext",         g("mediaNext"),   hw) -- next track
	bind("XF86AudioPrev",         g("mediaPrev"),   hw) -- previous track
end

function M.volume_keys()
	bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, dont_inhibit = true }) -- mute
	bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true, dont_inhibit = true }) -- volume down
	bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true, dont_inhibit = true }) -- volume up
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
	local drm = opt(o, "drm_devices", nil)
	if drm then
		local cards = {}
		for _, pci in ipairs(drm) do
			local c = drm_card(pci)
			if c then cards[#cards + 1] = c end
		end
		if #cards > 0 then hl.env("AQ_DRM_DEVICES", table.concat(cards, ":")) end
	end
	if opt(o, "binds", true) then M.binds(mod, restart) end
	if opt(o, "media_keys", true) then M.media_keys() end
	if opt(o, "volume_keys", true) then M.volume_keys() end
	if opt(o, "rules", true) then M.rules() end
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
