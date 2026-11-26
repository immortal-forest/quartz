-- quartz: clean Hyprland config (Hyprland ≥ 0.55, Lua).
-- install.sh puts this in ~/.config/hypr/hyprland.lua and adds quartz's block
-- at the end: every key, quartz's rules, autostart and your graphics settings.
-- There are no binds in here on purpose, so the keys are exactly the ones
-- Super + / shows. Options: https://wiki.hypr.land/configuring/

-- Screens: every monitor at its preferred mode, laid out left to right.
-- For a fixed layout: hyprctl monitors, then e.g.
-- hl.monitor({ output = "eDP-1", mode = "2560x1600@165", position = "0x0", scale = 1.25 })
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

-- The session: tells apps and portals they're on Hyprland, on Wayland
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- Apps on Wayland: Qt, GTK, Firefox and Electron (Chrome, VS Code, Discord …)
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
-- Qt apps take quartz's wallpaper colours through qt6ct, when it's installed
do
	local f = io.open("/usr/bin/qt6ct", "r")
	if f then
		f:close()
		hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
	end
end

-- Started with the session: the environment for portals and user services,
-- password prompts (polkit), and hypridle (dim, lock, screen off, sleep when
-- you're away: ~/.config/hypr/hypridle.conf)
hl.on("hyprland.start", function()
	hl.exec_cmd("dbus-update-activation-environment --systemd --all")
	hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE")
	hl.exec_cmd("systemctl --user start hyprpolkitagent")
	hl.exec_cmd("hypridle")
end)

hl.config({
	general = {
		gaps_in = 4,
		gaps_out = 10,
		border_size = 2,
		col = {
			active_border = "rgba(ffffffcc)",
			inactive_border = "rgba(80808044)",
		},
		resize_on_border = true,
		allow_tearing = true, -- lets games that ask for it skip vsync (window rule: immediate = true)
		layout = "dwindle",
	},
	decoration = {
		rounding = 12,
		rounding_power = 2,
		shadow = { enabled = false },
		blur = {
			enabled = true,
			size = 6,
			passes = 3,
			new_optimizations = true,
			ignore_opacity = true,
		},
	},
	animations = { enabled = true },
	dwindle = { preserve_split = true },
	xwayland = { force_zero_scaling = true }, -- X11 apps sharp (not blurry) on a scaled screen
	input = {
		kb_layout = "us", -- your layout, e.g. "de" or "us,ru" (kb_options = "grp:alt_shift_toggle")
		numlock_by_default = true,
		follow_mouse = 1,
		scroll_factor = 0.5, -- calmer wheel and touchpad scrolling
		emulate_discrete_scroll = 1,
		touchpad = { natural_scroll = true },
	},
	misc = {
		disable_hyprland_logo = true,
		disable_splash_rendering = true,
		force_default_wallpaper = 0,
		vrr = 1, -- the screen refreshes only when something changes; if it flickers, use 2 (fullscreen only)
		focus_on_activate = true, -- a clicked notification or link raises its app's window
		initial_workspace_tracking = 0, -- a new window opens where you are now, not where you launched it
		key_press_enables_dpms = true, -- any key or mouse move wakes a blanked screen
		mouse_move_enables_dpms = true,
	},
})

-- Three fingers left / right on the touchpad: switch workspace
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- Motion: one family of curves (Material 3) so everything moves alike. Things
-- arrive fast and land softly (decel), leave quickly (accel); no overshoot.
-- speed is in tenths of a second.
hl.curve("decel", { type = "bezier", points = { { 0.05, 0.7 }, { 0.1, 1 } } })
hl.curve("accel", { type = "bezier", points = { { 0.3, 0 }, { 0.8, 0.15 } } })
hl.curve("standard", { type = "bezier", points = { { 0.2, 0 }, { 0, 1 } } })
hl.animation({ leaf = "global", enabled = true, speed = 4, bezier = "standard" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4, bezier = "decel", style = "popin 90%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2.5, bezier = "accel", style = "popin 90%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4, bezier = "decel", style = "slide" })
hl.animation({ leaf = "border", enabled = true, speed = 4, bezier = "standard" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 3, bezier = "decel" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 2.5, bezier = "accel" })
hl.animation({ leaf = "fadeSwitch", enabled = true, speed = 3, bezier = "standard" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 3, bezier = "decel", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 2, bezier = "accel", style = "fade" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4.5, bezier = "decel", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4.5, bezier = "decel", style = "slidevert" })

-- Windows
hl.window_rule({ -- apps can't maximise themselves over the layout
	name = "suppress-maximize",
	match = { class = ".*" },
	suppress_event = "maximize",
})
hl.window_rule({ -- file pickers and settings dialogs float
	name = "float-dialogs",
	match = { class = "^(xdg-desktop-portal-gtk|qt5ct|qt6ct|org.pulseaudio.pavucontrol|nm-connection-editor|blueman-manager)$" },
	float = true,
})
hl.window_rule({ name = "float-firefox-library", match = { class = "^(firefox|zen)$", title = "^Library$" }, float = true })
hl.window_rule({ -- Spotify asks for focus whenever the tray restarts; keep the hint, not the jump
	name = "spotify-no-activate-focus",
	match = { class = "^spotify$" },
	focus_on_activate = false,
})
hl.window_rule({ -- XWayland drag-and-drop helpers don't steal focus
	name = "fix-xwayland-drags",
	match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
	no_focus = true,
})
