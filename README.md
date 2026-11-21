# quartz

A light, calm desktop shell for **Hyprland**, built with **Quickshell**. One
floating bar, and panels that unfold out of it: each one hangs right under the
bar item that opened it and joins the bar as one surface. Everything else stays
out of the way until you call it. The whole shell takes its colours from your
wallpaper.

## What you get

- **Floating bar**, lined up with your window gaps: workspaces (numbered, or
  dots), the focused window, the clock, what's playing, the tray and your
  status icons. Click one and its panel unfolds from right under it.
- **Control centre**: volume and brightness sliders, tiles for Wi-Fi,
  Bluetooth, microphone, Do not disturb and Stay awake. Pages for:
  - **Wi-Fi**: connect, type a password, forget
  - **Bluetooth**: pair, connect, see battery
  - **Sound**: output and input volume, devices, volume per app
- **Notifications**: pop-ups that pause while you hover them, with action
  buttons and swipe-to-dismiss. Screenshots show a preview with Open / Copy /
  Delete. Critical ones are tinted red and stay until handled. The history
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
- **Settings window**: a small app window (General, Appearance, Wallpaper,
  Shortcuts) instead of a page buried in a panel.
- **One design system**: every surface is built from the same sizes, radii,
  type scale (Outfit) and colour roles in `shell/core/Theme.qml`.

## Requirements

| What | Arch package |
|---|---|
| Hyprland, Lua or classic config | `hyprland` |
| Quickshell ≥ 0.3 | `quickshell` |
| Colours from the wallpaper | `matugen` |
| Wallpapers | `awww` (without it, quartz hands wallpaper changes to `setwall` if you have one), `ffmpeg` (picker thumbnails) |
| Clipboard | `wl-clipboard`, `cliphist` |
| Brightness | `brightnessctl` |
| Audio | `wireplumber` (PipeWire) |
| Wi-Fi / Bluetooth / battery | `networkmanager`, `bluez`, `upower` |
| Lock screen | `glib2`, `systemd`, `util-linux` (already on almost every system) |
| Fonts | `ttf-material-symbols-variable` and [Outfit](https://fonts.google.com/specimen/Outfit) |
| Optional | `hyprshot` (screenshot button), `playerctl`, `hyprsunset` (Night light), `power-profiles-daemon` (Power mode) |

## Install

```sh
git clone https://github.com/immortal-forest/quartz ~/quartz
~/quartz/install.sh
```

The installer walks through eight steps, says what each one does and asks
before it changes anything:

1. Checks the programs and fonts above.
2. Looks at your processor and graphics chips and suggests what suits them:
   microcode, the video-decoding driver, NVIDIA's settings, and on a hybrid
   laptop the built-in GPU for the desktop and quartz (`prime-run` for games).
3. On Arch, offers to install what's missing (`sudo pacman -S --needed …`, AUR
   packages through `yay` or `paru` if you have one). It shows each command
   first. On other distros it lists the packages and carries on.
4. Downloads the Outfit font into `~/.local/share/fonts` if it's missing.
5. Links `shell/` to `~/.config/quickshell/quartz`. Anything already there is
   moved aside, not deleted.
6. Adds quartz to your Hyprland config, `hyprland.lua` or `hyprland.conf`. It
   backs the file up first and puts everything in one block between
   `>>> quartz >>>` marker lines, so you can see it and it never repeats. Keys
   your config already uses stay yours: quartz skips them and lists them.
7. Asks for your wallpaper folder (default `~/wallpapers`) and writes it to
   `~/.local/state/quartz/config.json`, but only if that file doesn't exist yet.
8. Reloads Hyprland and starts quartz.

Running it again only does what isn't done yet.

| Option | |
|---|---|
| `--dry-run` | show every step and command, change nothing |
| `--yes` | don't ask, take the default answer each time |
| `--uninstall` | remove the link and the Hyprland block. Packages, fonts, settings and wallpapers stay. |
| `--help` | the short version of this |

To set things up by hand instead, use one of the snippets below.

### Lua config (`hyprland.lua`)

```lua
local quartz = dofile(os.getenv("HOME") .. "/quartz/hypr/quartz.lua")
quartz.setup({ mod = "SUPER", autostart = true, clipboard = true })
```

This binds the keys below and adds quartz's layer rules: no Hyprland animations
on its surfaces, frost behind the power menu, and the settings window floated,
centred and borderless. It also starts quartz and the clipboard-history watchers
with Hyprland. The options are at the top of [`hypr/quartz.lua`](hypr/quartz.lua).
You can pick another modifier, skip the media or volume keys, or skip autostart.
`skip = { "SUPER + C" }` leaves a key to your own config. On a hybrid laptop,
`gpu = "integrated"` runs quartz on the built-in GPU, and
`drm_devices = { "<pci>", … }` sets which GPU draws the desktop.

### Classic `hyprland.conf`

```ini
exec-once = qs -c quartz -d
exec-once = wl-paste --type text --watch cliphist store
exec-once = wl-paste --type image --watch cliphist store

bind = SUPER, SPACE,  global, quartz:launcher
bind = SUPER, V,      global, quartz:clipboard
bind = SUPER, ESCAPE, global, quartz:power
bind = SUPER, A,      global, quartz:control
bind = SUPER, N,      global, quartz:control
bind = SUPER SHIFT, N, global, quartz:dnd
bind = SUPER, K,      global, quartz:wifi
bind = SUPER, B,      global, quartz:bluetooth
bind = SUPER SHIFT, A, global, quartz:sound
bind = SUPER, D,      global, quartz:calendar
bind = SUPER, M,      global, quartz:media
bind = SUPER, COMMA,  global, quartz:settings
bind = SUPER, SLASH,  global, quartz:help
bind = SUPER, C,      global, quartz:wallpapers
bind = SUPER SHIFT, C, global, quartz:randomWallpaper
bind = SUPER, L,      exec, loginctl lock-session
bindl = , XF86AudioPlay, global, quartz:mediaToggle
bindl = , XF86AudioNext, global, quartz:mediaNext
bindl = , XF86AudioPrev, global, quartz:mediaPrev
bindel = , XF86MonBrightnessUp,   exec, qs -c quartz ipc call quartz brightness 5
bindel = , XF86MonBrightnessDown, exec, qs -c quartz ipc call quartz brightness -- -5
```

Also turn off Hyprland's layer animations for the namespaces `quartz-panel`,
`quartz-toast`, `quartz-osd` and `quartz-overlay` (quartz animates them
itself), blur `quartz-frost`, and float and centre the window titled
`Settings · quartz` (class `org.quickshell`). The rule syntax depends on your
Hyprland version. The Lua snippet above has been tested; this classic one
hasn't.

## Keys

| Key | |
|---|---|
| Super + Space | Launcher |
| Super + A / N | Control centre (and notifications) |
| Super + Shift + N | Do not disturb on / off |
| Super + K / B | Wi-Fi / Bluetooth |
| Super + Shift + A | Sound devices and apps |
| Super + D | Calendar |
| Super + M | Now playing |
| Super + V | Clipboard |
| Super + C / Shift+C | Wallpapers / a random one |
| Super + , | Settings |
| Super + / | Every shortcut, searchable ("wallpaper", "screenshot", "light mode"…) |
| Super + Esc | Power menu |
| Super + L | Lock |

With `essentials = true` (the installer turns it on for a fresh Hyprland
config) quartz also brings a full keymap: Super + Q close, Super + W float,
Alt + Enter fullscreen, Super + arrows focus, Super + 1–0 workspaces, Super +
T / F / E terminal, browser, files, Super + P screenshots, and more. Super + /
lists every key Hyprland really has bound, with a search.

In the bar: click the clock for the calendar, or the status icons for the
control centre. Scroll on the workspaces to switch, or on the status icons to
change the volume. Right-click a tray icon for its menu.

## Settings

Open the settings window from the gear in the control centre, or Super + , .
Every option says in plain words what it does, and the search box finds any of
them. The first time quartz starts, a short welcome guide shows the six keys
that get you around (Settings › General brings it back).

- **General**: 24-hour clock, seconds, which day the week starts on, stay
  awake, lock now, what's playing on the lock screen, your terminal, the
  welcome guide and the shortcut cheatsheet
- **Appearance**: light or dark, accent colour (from the wallpaper or one of
  eight), colour style, corners (square / rounded / round), motion (full /
  reduced / off), text size, theme your apps from the wallpaper
- **Bar**: numbered workspaces or dots, window title, what's playing, date,
  battery percentage
- **Notifications**: do not disturb, how long pop-ups stay, clear them all
- **Sound & display**: volume, microphone, output device, brightness, night
  light (needs `hyprsunset`), power mode (needs `power-profiles-daemon`),
  Wi-Fi and Bluetooth
- **Wallpaper**: change it, change it automatically (15 min / 30 min / 1 h),
  the folder, the transition
- **Shortcuts** and **About** (where settings live, reset all, restart quartz)

Everything is saved in `~/.local/state/quartz/config.json`.

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
- Caches live in `~/.cache/quartz` and look after themselves:
  - `thumbs/`: 480 px wallpaper thumbnails, keyed by path and modification
    time. Only missing ones are made (low priority, in the background); ones
    for deleted or changed wallpapers are removed.
  - `palettes/`: the colours matugen worked out per wallpaper, mode, style and
    accent, so switching back is instant. The newest 200 are kept.
  - `clip/`: small JPEG previews of clipboard images, removed once the entry
    leaves your clipboard history.
- At rest quartz does nothing: no polling, no timers, no redraws. The control
  centre is built once in the background so it opens smoothly, and is unmapped
  while hidden.
