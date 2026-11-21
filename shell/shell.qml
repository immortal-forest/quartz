//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "core"
import "services"
import "widgets"
import "bar"
import "panels"
import "modules"

// quartz — a light Quickshell rice for Hyprland.
// Per screen: the bar, its dropdowns and the full-screen overlays, each created
// only while open. Shell-wide: notifications, OSD, lock, keybinds and IPC.
ShellRoot {
    id: shell

    // A LazyLoader that keeps its window alive through the exit animation:
    // `keep` latches on when wanted; the window clears it (lingering → false).
    component Slot: LazyLoader {
        id: slot
        property bool want: false
        property bool keep: false
        onWantChanged: if (want) keep = true
        active: want || keep
        readonly property Connections _done: Connections {
            target: slot.item
            function onLingeringChanged() { if (slot.item && !slot.item.lingering) slot.keep = false; }
        }
    }

    Variants {
        model: Quickshell.screens
        Scope {
            id: scope
            required property var modelData
            readonly property string sn: modelData.name

            Bar {
                id: bar
                scr: scope.modelData
            }

            Slot {
                want: (Ui.panel === "control" && Ui.screen === scope.sn)
                ControlCenter { scr: scope.modelData; barWin: bar }
            }
            Slot {
                want: (Ui.panel === "calendar" && Ui.screen === scope.sn)
                CalendarPanel { scr: scope.modelData; barWin: bar }
            }
            Slot {
                want: (Ui.panel === "media" && Ui.screen === scope.sn)
                MediaPanel { scr: scope.modelData; barWin: bar }
            }
            Slot {
                want: (Ui.panel === "tray" && Ui.screen === scope.sn)
                TrayMenu { scr: scope.modelData; barWin: bar }
            }

            Slot {
                want: (Ui.overlay === "launcher" && Ui.screen === scope.sn)
                Launcher { scr: scope.modelData }
            }
            Slot {
                want: (Ui.overlay === "power" && Ui.screen === scope.sn)
                PowerMenu { scr: scope.modelData }
            }
            Slot {
                want: (Ui.overlay === "clipboard" && Ui.screen === scope.sn)
                Clipboard { scr: scope.modelData }
            }
            Slot {
                want: (Ui.overlay === "wallpapers" && Ui.screen === scope.sn)
                WallpaperPicker { scr: scope.modelData }
            }
        }
    }

    Slot {
        want: Notifs.toasts.count > 0
        Toasts {}
    }
    Osd {}
    Lock { id: locker }

    // Create these at startup instead of on first use: the wallpaper service
    // (awww daemon + palette) and Hypr (asks Hyprland which config flavour runs,
    // so the first workspace click / app launch already speaks the right one).
    Component.onCompleted: {
        Wallpaper.available;
        Hypr.lua;
    }

    // ── keybinds (Hyprland: hl.dsp.global("quartz:<name>")) ──
    GlobalShortcut { appid: "quartz"; name: "launcher"; description: "App launcher"; onPressed: Ui.toggleOverlay("launcher") }
    GlobalShortcut { appid: "quartz"; name: "clipboard"; description: "Clipboard history"; onPressed: Ui.toggleOverlay("clipboard") }
    GlobalShortcut { appid: "quartz"; name: "power"; description: "Power menu"; onPressed: Ui.toggleOverlay("power") }
    GlobalShortcut { appid: "quartz"; name: "wallpapers"; description: "Wallpaper picker"; onPressed: Ui.toggleOverlay("wallpapers") }
    GlobalShortcut { appid: "quartz"; name: "randomWallpaper"; description: "Random wallpaper"; onPressed: Wallpaper.random() }
    GlobalShortcut { appid: "quartz"; name: "control"; description: "Control centre"; onPressed: Ui.togglePanel("control") }
    GlobalShortcut { appid: "quartz"; name: "wifi"; description: "Wi-Fi"; onPressed: Ui.togglePanel("control", "", "wifi") }
    GlobalShortcut { appid: "quartz"; name: "bluetooth"; description: "Bluetooth"; onPressed: Ui.togglePanel("control", "", "bluetooth") }
    GlobalShortcut { appid: "quartz"; name: "sound"; description: "Sound devices + mixer"; onPressed: Ui.togglePanel("control", "", "audio") }
    GlobalShortcut { appid: "quartz"; name: "settings"; description: "quartz settings"; onPressed: Ui.togglePanel("control", "", "settings") }
    GlobalShortcut { appid: "quartz"; name: "calendar"; description: "Calendar"; onPressed: Ui.togglePanel("calendar") }
    GlobalShortcut { appid: "quartz"; name: "media"; description: "Now playing"; onPressed: Ui.togglePanel("media") }
    GlobalShortcut { appid: "quartz"; name: "mediaToggle"; description: "Play / pause"; onPressed: Media.toggle() }
    GlobalShortcut { appid: "quartz"; name: "mediaNext"; description: "Next track"; onPressed: Media.next() }
    GlobalShortcut { appid: "quartz"; name: "mediaPrev"; description: "Previous track"; onPressed: Media.previous() }

    // ── scripting: qs -c quartz ipc call quartz <fn> ──
    IpcHandler {
        target: "quartz"
        function launcher(): void { Ui.toggleOverlay("launcher"); }
        function clipboard(): void { Ui.toggleOverlay("clipboard"); }
        function power(): void { Ui.toggleOverlay("power"); }
        function wallpapers(): void { Ui.toggleOverlay("wallpapers"); }
        function randomWallpaper(): void { Wallpaper.random(); }
        function setWallpaper(path: string): void { Wallpaper.set(path); }
        // name: control | calendar | media, or control:<page> (wifi, bluetooth, audio, settings)
        function panel(name: string): void {
            const parts = name.split(":");
            Ui.togglePanel(parts[0], "", parts[1] || "main");
        }
        function brightness(delta: int): void { Brightness.step(delta / 100); }
        function volume(delta: int): void { Audio.setVolume(Audio.volume + delta / 100); }
        function mic(): void { Audio.toggleMic(); }
        function dnd(): void { Config.opt.dnd = !Config.opt.dnd; }
        function lock(): void { locker.lockNow(); }
        function close(): void { Ui.closeAll(); }
    }
}
