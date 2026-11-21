-- quartz — Hyprland integration (Lua config, Hyprland ≥ 0.55).
--
-- In your hyprland.lua (or any file it loads):
--
--   local quartz = dofile(os.getenv("HOME") .. "/quartz/hypr/quartz.lua")
--   quartz.setup({ mod = "SUPER", autostart = true })
--
-- Options (all optional):
--   mod          modifier for the shell keys            (default "SUPER")
--   binds        bind the shell keys                     (default true)
--   media_keys   brightness / mic / play-pause keys      (default true)
--   volume_keys  volume up / down / mute keys            (default true)
--   rules        frosted-glass blur layer rules          (default true)
--   autostart    start quartz when Hyprland starts      (default false)
--   restart      command for mod+Shift+R                 (default: kill + relaunch quartz)
--
-- The shell keys reach quartz through its global shortcuts
-- (hl.dsp.global("quartz:<name>")), so they work even before you click anything.

local M = {}

local function opt(o, k, d)
	if o[k] == nil then return d end
	return o[k]
end

local function g(name) return hl.dsp.global("quartz:" .. name) end

function M.binds(mod, restart)
	hl.bind(mod .. " + Space",     g("launcher"))        -- app launcher
	hl.bind(mod .. " + V",         g("clipboard"))       -- clipboard history
	hl.bind(mod .. " + Escape",    g("power"))           -- power / session menu
	hl.bind(mod .. " + A",         g("control"))         -- control centre
	hl.bind(mod .. " + N",         g("control"))         -- notifications live in the control centre
	hl.bind(mod .. " + K",         g("wifi"))            -- control centre › Wi-Fi
	hl.bind(mod .. " + D",         g("calendar"))        -- calendar
	hl.bind(mod .. " + M",         g("media"))           -- now playing
	hl.bind(mod .. " + comma",     g("settings"))        -- quartz settings
	hl.bind(mod .. " + C",         g("wallpapers"))      -- wallpaper picker
	hl.bind(mod .. " + SHIFT + C", g("randomWallpaper")) -- random wallpaper
	hl.bind(mod .. " + L",         hl.dsp.exec_cmd("loginctl lock-session")) -- lock
	hl.bind(mod .. " + SHIFT + R", hl.dsp.exec_cmd(restart))                -- restart quartz
end

-- Hardware keys: `locked` keeps them working on the lock screen, `dont_inhibit`
-- gets past fullscreen games, `repeating` steps while held.
function M.media_keys()
	local hw  = { locked = true, dont_inhibit = true }
	local hwr = { locked = true, repeating = true, dont_inhibit = true }
	hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("sh -c 'qs -c quartz ipc call quartz brightness 5 || brightnessctl -e4 -n2 set 5%+'"), hwr)
	hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("sh -c 'qs -c quartz ipc call quartz brightness -- -5 || brightnessctl -e4 -n2 set 5%-'"), hwr)
	hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), hw) -- quartz shows the OSD from Pipewire
	hl.bind("XF86AudioPlay",         g("mediaToggle"), hw)
	hl.bind("XF86AudioNext",         g("mediaNext"),   hw)
	hl.bind("XF86AudioPrev",         g("mediaPrev"),   hw)
end

function M.volume_keys()
	hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, dont_inhibit = true })
	hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true, dont_inhibit = true })
	hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true, dont_inhibit = true })
end

-- Frosted glass behind quartz's surfaces. ignore_alpha 0.5 blurs only the
-- solid-ish glass (not shadows or scrims); quartz animates its own panels, so
-- they get no Hyprland animation. quartz-frost = whole-screen frost (power menu).
function M.rules()
	hl.layer_rule({
		name  = "quartz-bar",
		match = { namespace = "^quartz-bar$" },
		blur         = true,
		ignore_alpha = 0.3,
		animation    = "slide top",
	})
	hl.layer_rule({
		name  = "quartz-surfaces",
		match = { namespace = "^quartz-(panel|toast|osd|overlay)$" },
		blur         = true,
		ignore_alpha = 0.5,
		no_anim      = true,
	})
	hl.layer_rule({
		name  = "quartz-frost",
		match = { namespace = "^quartz-frost$" },
		blur         = true,
		ignore_alpha = false,
	})
end

function M.setup(o)
	o = o or {}
	local mod = opt(o, "mod", "SUPER")
	local restart = opt(o, "restart", "sh -c 'qs kill -c quartz; sleep 0.3; qs -c quartz -d'")
	if opt(o, "binds", true) then M.binds(mod, restart) end
	if opt(o, "media_keys", true) then M.media_keys() end
	if opt(o, "volume_keys", true) then M.volume_keys() end
	if opt(o, "rules", true) then M.rules() end
	if opt(o, "autostart", false) then
		hl.on("hyprland.start", function() hl.exec_cmd("qs -c quartz -d") end)
	end
end

return M
