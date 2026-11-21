# quartz

A light, calm desktop shell for **Hyprland**, built with **Quickshell**. One
floating bar and a control centre. Everything else stays out of the way until
you call it, and comes in with soft, springy motion. The whole shell takes its
colours from your wallpaper.

## What you get

- **Floating bar** of frosted glass, lined up with your window gaps: workspaces
  (dots; the active one stretches into a pill), the focused window, the clock,
  what's playing, the tray and your status icons.
- **Control centre**: volume and brightness sliders, tiles for Wi-Fi,
  Bluetooth, microphone, Do not disturb and Stay awake. Pages for:
  - **Wi-Fi**: connect, type a password, forget
  - **Bluetooth**: pair, connect, see battery
  - **Sound**: output and input devices, volume per app
  - **Settings**
- **Notifications**: pop-ups that pause while you hover them, with action
  buttons and swipe-to-dismiss. Critical ones stay until handled. The history
  lives in the control centre.
- **Launcher**: fuzzy app search. Type a sum and Enter copies the answer. Apps
  you open often float to the top.
- **Clipboard history** with image previews.
- **Wallpaper picker**:
  - folders as filters, search and *Surprise me*
  - the new wallpaper grows out from where you clicked
  - the whole shell recolours to match (Material 3, via matugen)
- **Lock screen**: blurred wallpaper, a big clock, what's playing, and a
  password field. It also locks on `loginctl lock-session`, so idle and suspend
  lock it too.
- **More panels**: calendar, now playing (with seeking), a power menu, and an
  on-screen indicator for volume, brightness and mic.
- **Light**: a panel only exists while it's open. At rest quartz uses about 1%
  of one CPU core and about 60 MB of its own memory.
- **Japanese accents** (optional, off by default): a kanji weekday in the bar
  and a Japanese date on the lock screen.

## Requirements

| What | Arch package |
|---|---|
| Hyprland, Lua or classic config | `hyprland` |
| Quickshell ≥ 0.3 | `quickshell` |
| Colours from the wallpaper | `matugen` |
| Wallpapers | `awww` |
| Clipboard | `wl-clipboard`, `cliphist` (run `wl-paste --watch cliphist store`) |
| Brightness | `brightnessctl` |
| Audio | `wireplumber` (Pipewire) |
| Wi-Fi / Bluetooth / battery | `networkmanager`, `bluez`, `upower` |
| Fonts | `adwaita-fonts`, `ttf-material-symbols-variable`, and [Outfit](https://fonts.google.com/specimen/Outfit) |
| Optional | `hyprshot` (screenshot button), `playerctl` |

## Install

```sh
git clone https://github.com/immortal-forest/quartz ~/quartz
~/quartz/install.sh
```

The installer checks the list above and links the shell to
`~/.config/quickshell/quartz`. It doesn't edit your Hyprland config. Add quartz
to it yourself, using one of the snippets below.

### Lua config (`hyprland.lua`)

```lua
local quartz = dofile(os.getenv("HOME") .. "/quartz/hypr/quartz.lua")
quartz.setup({ mod = "SUPER", autostart = true })
```

This binds the keys below, adds the frosted-glass blur rules and starts quartz
with Hyprland. Options are at the top of [`hypr/quartz.lua`](hypr/quartz.lua):
you can skip the media or volume keys, pick another modifier, or skip
autostart.

### Classic `hyprland.conf`

```ini
exec-once = qs -c quartz -d

bind = SUPER, SPACE,  global, quartz:launcher
bind = SUPER, V,      global, quartz:clipboard
bind = SUPER, ESCAPE, global, quartz:power
bind = SUPER, A,      global, quartz:control
bind = SUPER, K,      global, quartz:wifi
bind = SUPER, D,      global, quartz:calendar
bind = SUPER, M,      global, quartz:media
bind = SUPER, COMMA,  global, quartz:settings
bind = SUPER, C,      global, quartz:wallpapers
bind = SUPER SHIFT, C, global, quartz:randomWallpaper
bind = SUPER, L,      exec, loginctl lock-session
bindl = , XF86AudioPlay, global, quartz:mediaToggle
bindl = , XF86AudioNext, global, quartz:mediaNext
bindl = , XF86AudioPrev, global, quartz:mediaPrev
bindel = , XF86MonBrightnessUp,   exec, qs -c quartz ipc call quartz brightness 5
bindel = , XF86MonBrightnessDown, exec, qs -c quartz ipc call quartz brightness -- -5
```

For the frosted glass, add blur layer rules for the namespaces `quartz-bar`,
`quartz-panel`, `quartz-toast`, `quartz-osd`, `quartz-overlay` and
`quartz-frost` (ignore-alpha about 0.5). The layer-rule syntax depends on your
Hyprland version. The Lua snippet above has been tested; this classic one hasn't.

## Keys

| Key | |
|---|---|
| Super + Space | Launcher |
| Super + A / N | Control centre (and notifications) |
| Super + K | Wi-Fi |
| Super + D | Calendar |
| Super + M | Now playing |
| Super + V | Clipboard |
| Super + C / Shift+C | Wallpapers / a random one |
| Super + , | Settings |
| Super + Esc | Power menu |
| Super + L | Lock |

In the bar: click the clock for the calendar, or the status icons for the
control centre. Scroll on the workspaces to switch, or on the status icons to
change the volume. Right-click a tray icon for its menu.

## Settings

Open them from the gear in the control centre:

- 24-hour clock
- numbers instead of dots for workspaces
- theme your apps from the wallpaper
- Japanese accents
- the wallpaper transition (grow, wipe, wave, outer, fade)

Everything is saved in `~/.local/state/quartz/config.json`, which also holds:

- `wallpaperDir` (default `~/wallpapers`; its top-level folders become the
  picker's filters)
- `terminal` (for terminal apps; empty means `$TERMINAL`)

*Theme apps from the wallpaper* runs your own matugen config on each new
wallpaper, so any templates you have there (terminals, borders, …) follow
along.

## Scripting

```sh
qs -c quartz ipc call quartz launcher            # also: clipboard, power, wallpapers, lock, close
qs -c quartz ipc call quartz panel control:wifi  # control[:wifi|bluetooth|audio|settings], calendar, media
qs -c quartz ipc call quartz setWallpaper ~/wallpapers/x.jpg
qs -c quartz ipc call quartz randomWallpaper
qs -c quartz ipc call quartz volume 5            # brightness 5, mic, dnd
```

## Notes

- The lock screen checks your password with the PAM service `login`.
- If quartz dies while locked, the screen stays locked. That's the session-lock
  protocol doing its job.
