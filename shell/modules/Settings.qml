import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import "../core"
import "../services"
import "../widgets"

// quartz settings: a plain app window (Hyprland floats, centres and rounds it by
// class + title — keep the title in sync with hypr/quartz.lua).
// Sidebar of sections on the left, grouped rows on the right, every row says
// in plain words what it does. Changes are saved at once (Config). Esc or
// closing the window puts it away.
FloatingWindow {
    id: win
    title: "Settings · quartz"
    color: Theme.surfaceLow
    implicitWidth: 1000
    implicitHeight: 680
    minimumSize: Qt.size(720, 500)
    onVisibleChanged: if (!visible) Ui.settings = false
    Component.onCompleted: {
        System.check();   // pick up night light / power mode installed since
        Binds.refresh();  // the shortcuts Hyprland really has
    }
    property bool confirmReset: false

    property string section: Ui.settingsSection
    readonly property var current: sections.find(x => x.key === section) || sections[0]
    // sidebar search: jumps to the section a setting lives in
    property string query: ""
    readonly property var found: query.trim().length ? Binds.settings.filter(st => Binds.matches(st.label + " " + st.words + " " + st.section, query)) : []
    readonly property var sections: [
        { key: "general", icon: "tune", label: "General", about: "The clock and calendar, the lock screen, your terminal and where to find help" },
        { key: "appearance", icon: "palette", label: "Appearance", about: "Light or dark, your accent colour, corners, motion and how big text is" },
        { key: "bar", icon: "toolbar", label: "Bar", about: "Choose what the bar at the top shows" },
        { key: "notifications", icon: "notifications", label: "Notifications", about: "Pop-ups, quiet time and the notification history" },
        { key: "sound", icon: "volume_up", label: "Sound & display", about: "Volume, microphone, brightness, night light, power mode, Wi-Fi and Bluetooth" },
        { key: "wallpaper", icon: "wallpaper", label: "Wallpaper", about: "Change it, let it change by itself, pick the folder and the transition" },
        { key: "shortcuts", icon: "keyboard", label: "Shortcuts", about: "Every key quartz and Hyprland use" },
        { key: "about", icon: "info", label: "About", about: "Where your settings live, resetting them, and restarting quartz" }
    ]

    // a titled card of rows, rows separated by hairlines
    component Group: ColumnLayout {
        id: grp
        property string title: ""
        default property alias rows: box.data
        Layout.fillWidth: true
        spacing: Theme.spacing
        Section {
            visible: grp.title.length > 0
            Layout.leftMargin: 4
            text: grp.title
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: box.implicitHeight + Theme.spacing
            radius: Theme.rCard
            color: Theme.card
            ColumnLayout {
                id: box
                x: 0
                y: Theme.spacing / 2
                width: parent.width
                spacing: 0
            }
        }
    }

    // one setting: icon disc, title + description, a control on the right
    component SettingRow: Item {
        id: row
        property string icon: ""
        property string title: ""
        property string subtitle: ""
        default property alias control: slot.data
        Layout.fillWidth: true
        implicitHeight: Math.max(Theme.row + 12, texts.implicitHeight + 28)
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.padCard
            anchors.rightMargin: Theme.pad
            spacing: 14
            Rectangle {
                implicitWidth: Theme.ctl
                implicitHeight: Theme.ctl
                radius: Theme.pill(height)
                color: Theme.tonal
                Icon {
                    anchors.centerIn: parent
                    icon: row.icon
                    color: Theme.primary
                }
            }
            ColumnLayout {
                id: texts
                Layout.fillWidth: true
                spacing: 2
                T {
                    Layout.fillWidth: true
                    text: row.title
                    font.weight: Font.Medium
                }
                T {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: row.subtitle
                    font.pixelSize: Theme.fsSmall
                    color: Theme.textDim
                    wrapMode: Text.Wrap
                }
            }
            Item {
                id: slot
                implicitWidth: childrenRect.width
                implicitHeight: childrenRect.height
            }
        }
    }
    component Divider: Rectangle {
        Layout.fillWidth: true
        Layout.leftMargin: Theme.padCard + Theme.ctl + 14
        implicitHeight: 1
        color: Theme.hairline
    }

    // a card holding a row of choices (chips), filling the width
    component Choices: Item {
        id: ch
        property var options: []        // [[value, label], …]
        property var value
        signal picked(var v)
        Layout.fillWidth: true
        implicitHeight: Theme.ctl + Theme.padCard * 2
        RowLayout {
            anchors.fill: parent
            anchors.margins: Theme.padCard
            spacing: Theme.spacing
            Repeater {
                model: ch.options
                delegate: Chip {
                    required property var modelData
                    Layout.fillWidth: true
                    text: modelData[1]
                    selected: ch.value === modelData[0]
                    onClicked: ch.picked(modelData[0])
                }
            }
        }
    }

    // a setting with a slider: icon disc, title, then the slider filling the row
    component SliderRow: Item {
        id: sl
        property string icon: ""
        property string title: ""
        default property alias control: sslot.data
        Layout.fillWidth: true
        implicitHeight: Theme.row + 8
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.padCard
            anchors.rightMargin: Theme.pad
            spacing: 14
            Rectangle {
                implicitWidth: Theme.ctl
                implicitHeight: Theme.ctl
                radius: Theme.pill(height)
                color: Theme.tonal
                Icon { anchors.centerIn: parent; icon: sl.icon; color: Theme.primary }
            }
            T {
                Layout.preferredWidth: 150
                text: sl.title
                font.weight: Font.Medium
            }
            Item {
                id: sslot
                Layout.fillWidth: true
                implicitHeight: Theme.ctl
            }
        }
    }

    // a keyboard shortcut line: action on the left, keycaps on the right
    component Shortcut: Item {
        id: sc
        property string label: ""
        property var keys: []
        Layout.fillWidth: true
        implicitHeight: Theme.ctl + 4
        T {
            anchors.left: parent.left
            anchors.leftMargin: Theme.pad
            anchors.verticalCenter: parent.verticalCenter
            text: sc.label
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: Theme.pad
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Repeater {
                model: sc.keys
                delegate: Keycap {
                    required property string modelData
                    key: modelData
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: Ui.settings = false

        // ── sidebar ──
        Item {
            id: side
            width: 248
            height: parent.height
            Rectangle {
                anchors.right: parent.right
                width: 1
                height: parent.height
                color: Theme.hairline
            }

            ColumnLayout {
                x: Theme.pad
                y: 24
                width: parent.width - Theme.pad * 2
                spacing: 4

                RowLayout {
                    Layout.leftMargin: 6
                    Layout.bottomMargin: 16
                    implicitHeight: Theme.ctl
                    spacing: 10
                    Icon {
                        icon: "settings"
                        size: 24
                        fill: 1
                        color: Theme.primary
                    }
                    T {
                        text: "Settings"
                        font.pixelSize: Theme.fsLarge
                        font.weight: Font.Medium
                    }
                }
                Field {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 8
                    icon: "search"
                    placeholder: "Find a setting"
                    onTextChanged: win.query = text
                    onAccepted: if (win.found.length) { Ui.settingsSection = win.found[0].section; text = ""; }
                }
                // search results: each jumps to its section
                Repeater {
                    model: win.found
                    delegate: Rectangle {
                        id: hit
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: hitCol.implicitHeight + 16
                        radius: Theme.rCard
                        color: "transparent"
                        ColumnLayout {
                            id: hitCol
                            x: 16
                            y: 8
                            width: parent.width - 32
                            spacing: 0
                            T { Layout.fillWidth: true; text: hit.modelData.label; font.weight: Font.Medium }
                            T {
                                Layout.fillWidth: true
                                text: (win.sections.find(x => x.key === hit.modelData.section) || {}).label || ""
                                font.pixelSize: Theme.fsSmall
                                color: Theme.textDim
                            }
                        }
                        StateLayer {
                            tint: Theme.primary
                            onClicked: Ui.settingsSection = hit.modelData.section
                        }
                    }
                }
                T {
                    visible: win.query.trim().length > 0 && !win.found.length
                    Layout.leftMargin: 16
                    text: "Nothing matches"
                    color: Theme.textDim
                }
                Repeater {
                    model: win.query.trim().length ? [] : win.sections
                    delegate: Rectangle {
                        id: nav
                        required property var modelData
                        readonly property bool on: win.section === modelData.key
                        Layout.fillWidth: true
                        implicitHeight: Theme.ctl + 4
                        radius: Theme.pill(height)
                        color: on ? Theme.alpha(Theme.primary, 0.16) : "transparent"
                        Behavior on color { CAnim {} }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            spacing: 12
                            Icon {
                                icon: nav.modelData.icon
                                fill: nav.on ? 1 : 0
                                color: nav.on ? Theme.primary : Theme.textDim
                            }
                            T {
                                Layout.fillWidth: true
                                text: nav.modelData.label
                                font.weight: nav.on ? Font.DemiBold : Font.Medium
                                color: nav.on ? Theme.primary : Theme.text
                            }
                        }
                        StateLayer {
                            tint: Theme.primary
                            onClicked: Ui.settingsSection = nav.modelData.key
                        }
                    }
                }
            }
        }

        // ── content ──
        Flickable {
            id: flick
            anchors.left: side.right
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            contentHeight: page.implicitHeight + 56
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: page
                x: 32
                y: 24
                width: Math.min(flick.width - 64, 720)
                spacing: 24
                opacity: 1
                // a section switch fades the page in
                Behavior on opacity { Ease { duration: Anim.fast } }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.rightMargin: Theme.ctl
                    spacing: 2
                    T {
                        Layout.preferredHeight: Theme.ctl
                        text: win.current.label
                        font.pixelSize: Theme.fsLarge + 2
                        font.weight: Font.Medium
                    }
                    T {
                        Layout.fillWidth: true
                        text: win.current.about
                        color: Theme.textDim
                        wrapMode: Text.Wrap
                    }
                }

                // ── General ──
                Group {
                    visible: win.section === "general"
                    title: "Clock & screen"
                    SettingRow {
                        icon: "schedule"
                        title: "24-hour clock"
                        subtitle: "Show 13:00 instead of 1:00 PM"
                        Switch { checked: Config.opt.use24h; onToggled: Config.opt.use24h = !Config.opt.use24h }
                    }
                    Divider {}
                    SettingRow {
                        icon: "timer"
                        title: "Show seconds"
                        subtitle: "Seconds on the clock in the bar"
                        Switch { checked: Config.opt.clockSeconds; onToggled: Config.opt.clockSeconds = !Config.opt.clockSeconds }
                    }
                    Divider {}
                    SettingRow {
                        icon: "calendar_month"
                        title: "Week starts on"
                        subtitle: "The first column of the calendar"
                        RowLayout {
                            spacing: 6
                            Repeater {
                                model: [["locale", "Automatic"], ["monday", "Monday"], ["sunday", "Sunday"]]
                                delegate: Chip {
                                    required property var modelData
                                    small: true
                                    text: modelData[1]
                                    selected: Config.opt.weekStart === modelData[0]
                                    onClicked: Config.opt.weekStart = modelData[0]
                                }
                            }
                        }
                    }
                    Divider {}
                    SettingRow {
                        icon: "coffee"
                        title: "Stay awake"
                        subtitle: "Keep the screen on and don't lock it when you're idle"
                        Switch { checked: Config.opt.caffeine; onToggled: Config.opt.caffeine = !Config.opt.caffeine }
                    }
                }
                Group {
                    visible: win.section === "general"
                    title: "Lock screen"
                    SettingRow {
                        icon: "lock"
                        title: "Lock the screen"
                        subtitle: "Locks now. Super + L does the same, any time"
                        Button { small: true; filled: false; icon: "lock"; text: "Lock now"; onClicked: { Ui.settings = false; Quickshell.execDetached(["loginctl", "lock-session"]); } }
                    }
                    Divider {}
                    SettingRow {
                        icon: "music_note"
                        title: "Show what's playing"
                        subtitle: "Song controls on the lock screen"
                        Switch { checked: Config.opt.lockMedia; onToggled: Config.opt.lockMedia = !Config.opt.lockMedia }
                    }
                }
                Group {
                    visible: win.section === "general"
                    title: "Apps"
                    SettingRow {
                        icon: "terminal"
                        title: "Terminal"
                        subtitle: "Opens apps that run in a terminal. Leave empty to use your default"
                        Field {
                            implicitWidth: 200
                            placeholder: Quickshell.env("TERMINAL") || "kitty"
                            text: Config.opt.terminal
                            input.onEditingFinished: Config.opt.terminal = text.trim()
                        }
                    }
                }
                Group {
                    visible: win.section === "general"
                    title: "Help"
                    SettingRow {
                        icon: "waving_hand"
                        title: "Welcome guide"
                        subtitle: "The six keys that get you around"
                        Button { small: true; filled: false; text: "Show"; onClicked: Ui.showWelcome() }
                    }
                    Divider {}
                    SettingRow {
                        icon: "keyboard"
                        title: "Keyboard shortcuts"
                        subtitle: "Search everything quartz can do. Super + / opens it anywhere"
                        Button { small: true; filled: false; text: "Open"; onClicked: { Ui.settings = false; Ui.toggleOverlay("help"); } }
                    }
                }

                // ── Appearance ──
                Group {
                    visible: win.section === "appearance"
                    title: "Colours"
                    SettingRow {
                        icon: Config.opt.light ? "light_mode" : "dark_mode"
                        title: "Light mode"
                        subtitle: "Light surfaces with dark text. Colours still come from your wallpaper"
                        Switch { checked: Config.opt.light; onToggled: Config.opt.light = !Config.opt.light }
                    }
                    Divider {}
                    SettingRow {
                        icon: "format_paint"
                        title: "Theme apps from the wallpaper"
                        subtitle: "Terminals, window borders and cava take the wallpaper's colours too"
                        Switch { checked: Config.opt.themeApps; onToggled: Config.opt.themeApps = !Config.opt.themeApps }
                    }
                }
                Group {
                    visible: win.section === "appearance"
                    title: "Accent colour"
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: accentRow.implicitHeight + Theme.padCard * 2
                        RowLayout {
                            id: accentRow
                            x: Theme.padCard
                            y: Theme.padCard
                            width: parent.width - Theme.padCard * 2
                            spacing: 10
                            Chip {
                                text: "From wallpaper"
                                selected: !Config.opt.accent.length
                                onClicked: Config.opt.accent = ""
                            }
                            Repeater {
                                // seed colours: matugen builds the whole palette from one
                                model: ["#d93a3a", "#e8772e", "#d9a521", "#3f9a4a", "#1f9e9a", "#3b7de0", "#7a55d6", "#d04a8f"]
                                delegate: Rectangle {
                                    id: sw
                                    required property string modelData
                                    readonly property bool on: Config.opt.accent === modelData
                                    implicitWidth: Theme.ctl - 4
                                    implicitHeight: Theme.ctl - 4
                                    radius: Theme.pill(height)
                                    color: modelData
                                    border.width: on ? 3 : 0
                                    border.color: Theme.text
                                    Icon {
                                        anchors.centerIn: parent
                                        visible: sw.on
                                        icon: "check"
                                        size: 18
                                        color: "white"
                                    }
                                    StateLayer {
                                        tint: "white"
                                        onClicked: Config.opt.accent = sw.modelData
                                    }
                                }
                            }
                            Item { Layout.fillWidth: true }
                        }
                    }
                }
                Group {
                    visible: win.section === "appearance"
                    title: "Colour style"
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: styleFlow.implicitHeight + Theme.padCard * 2
                        Flow {
                            id: styleFlow
                            x: Theme.padCard
                            y: Theme.padCard
                            width: parent.width - Theme.padCard * 2
                            spacing: Theme.spacing
                            Repeater {
                                model: [["content", "Natural"], ["tonal-spot", "Soft"], ["vibrant", "Vibrant"], ["expressive", "Playful"], ["fidelity", "True to image"], ["monochrome", "Monochrome"]]
                                delegate: Chip {
                                    required property var modelData
                                    text: modelData[1]
                                    selected: Config.opt.scheme === modelData[0]
                                    onClicked: Config.opt.scheme = modelData[0]
                                }
                            }
                        }
                    }
                }
                Group {
                    visible: win.section === "appearance"
                    title: "Corners"
                    Choices {
                        options: [[0, "Square"], [1, "Rounded"], [2, "Round"]]
                        value: Config.opt.roundness
                        onPicked: v => Config.opt.roundness = v
                    }
                }
                Group {
                    visible: win.section === "appearance"
                    title: "Motion"
                    Choices {
                        options: [[2, "Full"], [1, "Reduced"], [0, "Off"]]
                        value: Config.opt.motion
                        onPicked: v => Config.opt.motion = v
                    }
                }
                Group {
                    visible: win.section === "appearance"
                    title: "Text size"
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: Theme.ctl + Theme.padCard * 2
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.padCard
                            spacing: Theme.spacing
                            Repeater {
                                model: ["Default", "Large", "Larger"]
                                delegate: Chip {
                                    required property string modelData
                                    required property int index
                                    Layout.fillWidth: true
                                    text: modelData
                                    selected: Config.opt.textSize === index
                                    onClicked: Config.opt.textSize = index
                                }
                            }
                        }
                    }
                }

                // ── Bar ──
                Group {
                    visible: win.section === "bar"
                    title: "What the bar shows"
                    SettingRow {
                        icon: "looks_one"
                        title: "Workspace numbers"
                        subtitle: "Numbered workspaces instead of dots"
                        Switch { checked: Config.opt.workspaceNumbers; onToggled: Config.opt.workspaceNumbers = !Config.opt.workspaceNumbers }
                    }
                    Divider {}
                    SettingRow {
                        icon: "web_asset"
                        title: "Window title"
                        subtitle: "The app and title of the window you're using"
                        Switch { checked: Config.opt.barTitle; onToggled: Config.opt.barTitle = !Config.opt.barTitle }
                    }
                    Divider {}
                    SettingRow {
                        icon: "music_note"
                        title: "What's playing"
                        subtitle: "The current song or video, with its cover"
                        Switch { checked: Config.opt.barMedia; onToggled: Config.opt.barMedia = !Config.opt.barMedia }
                    }
                    Divider {}
                    SettingRow {
                        icon: "calendar_today"
                        title: "Date"
                        subtitle: "The date beside the time"
                        Switch { checked: Config.opt.barDate; onToggled: Config.opt.barDate = !Config.opt.barDate }
                    }
                    Divider {}
                    SettingRow {
                        icon: "battery_android_frame_5"
                        title: "Battery percentage"
                        subtitle: "The number next to the battery icon"
                        Switch { checked: Config.opt.batteryPercent; onToggled: Config.opt.batteryPercent = !Config.opt.batteryPercent }
                    }
                }

                // ── Notifications ──
                Group {
                    visible: win.section === "notifications"
                    title: "Pop-ups"
                    SettingRow {
                        icon: "do_not_disturb_on"
                        title: "Do not disturb"
                        subtitle: "No pop-ups. Notifications still wait in the control centre"
                        Switch { checked: Config.opt.dnd; onToggled: Config.opt.dnd = !Config.opt.dnd }
                    }
                    Divider {}
                    SettingRow {
                        icon: "timer"
                        title: "How long pop-ups stay"
                        subtitle: "Hovering one keeps it open"
                        RowLayout {
                            spacing: 6
                            Repeater {
                                model: [["short", "Short"], ["normal", "Normal"], ["long", "Long"]]
                                delegate: Chip {
                                    required property var modelData
                                    small: true
                                    text: modelData[1]
                                    selected: Config.opt.popupTime === modelData[0]
                                    onClicked: Config.opt.popupTime = modelData[0]
                                }
                            }
                        }
                    }
                }
                Group {
                    visible: win.section === "notifications"
                    title: "History"
                    SettingRow {
                        icon: "clear_all"
                        title: "Clear all notifications"
                        subtitle: Notifs.count === 1 ? "1 notification in the control centre" : Notifs.count + " notifications in the control centre"
                        Button { small: true; filled: false; text: "Clear"; enabled: Notifs.count > 0; opacity: enabled ? 1 : 0.5; onClicked: Notifs.clearAll() }
                    }
                }

                // ── Sound & display ──
                Group {
                    visible: win.section === "sound"
                    title: "Sound"
                    SliderRow {
                        icon: Audio.muted ? "volume_off" : "volume_up"
                        title: "Volume"
                        QSlider {
                            anchors.fill: parent
                            icon: Audio.muted ? "volume_off" : "volume_up"
                            value: Audio.muted ? 0 : Audio.volume
                            onMoved: v => Audio.setVolume(v)
                            onIconClicked: Audio.toggleMute()
                        }
                    }
                    Divider {}
                    SliderRow {
                        icon: Audio.micIcon
                        title: "Microphone"
                        QSlider {
                            anchors.fill: parent
                            icon: Audio.micIcon
                            value: Audio.micMuted ? 0 : Audio.micVolume
                            onMoved: v => Audio.setMic(v)
                            onIconClicked: Audio.toggleMic()
                        }
                    }
                    Divider {}
                    SettingRow {
                        icon: "speaker"
                        title: "Play sound through"
                        subtitle: Audio.name(Audio.sink)
                        Button { small: true; filled: false; text: "Choose…"; onClicked: { Ui.settings = false; Ui.togglePanel("control", "", "audio"); } }
                    }
                    Divider {}
                    SettingRow {
                        icon: "headphones"
                        title: "Switch to headphones when they connect"
                        subtitle: "Bluetooth headphones and speakers take over the sound"
                        Switch { checked: Config.opt.audioFollow; onToggled: Config.opt.audioFollow = !Config.opt.audioFollow }
                    }
                }
                Group {
                    visible: win.section === "sound" && Brightness.available
                    title: "Display"
                    SliderRow {
                        icon: Brightness.icon
                        title: "Brightness"
                        QSlider {
                            anchors.fill: parent
                            icon: Brightness.icon
                            value: Brightness.value
                            onMoved: v => Brightness.set(v)
                        }
                    }
                }
                Group {
                    visible: win.section === "sound"
                    title: "Night light"
                    SettingRow {
                        icon: "nightlight"
                        title: "Night light"
                        subtitle: System.hasNightLight ? "Warmer colours that are easier on the eyes at night" : "Needs hyprsunset: sudo pacman -S hyprsunset"
                        Switch {
                            enabled: System.hasNightLight
                            opacity: enabled ? 1 : 0.4
                            checked: Config.opt.nightLight
                            onToggled: Config.opt.nightLight = !Config.opt.nightLight
                        }
                    }
                    Divider { visible: System.hasNightLight }
                    SliderRow {
                        visible: System.hasNightLight
                        icon: "thermostat"
                        title: "Warmth"
                        QSlider {
                            anchors.fill: parent
                            icon: "wb_twilight"
                            showValue: false
                            // left = mild (5500 K), right = very warm (2500 K)
                            value: (5500 - Config.opt.nightTemp) / 3000
                            onMoved: v => Config.opt.nightTemp = Math.round((5500 - v * 3000) / 100) * 100
                        }
                    }
                }
                Group {
                    visible: win.section === "sound"
                    title: "Power mode"
                    SettingRow {
                        visible: !System.hasPowerProfiles
                        icon: "bolt"
                        title: "Power mode"
                        subtitle: "Needs power-profiles-daemon: sudo pacman -S power-profiles-daemon"
                    }
                    Choices {
                        visible: System.hasPowerProfiles
                        options: [[PowerProfile.PowerSaver, "Battery saver"], [PowerProfile.Balanced, "Balanced"]].concat(System.hasPerformance ? [[PowerProfile.Performance, "Performance"]] : [])
                        value: System.profile
                        onPicked: v => System.setProfile(v)
                    }
                }
                Group {
                    visible: win.section === "sound"
                    title: "Connections"
                    SettingRow {
                        icon: "wifi"
                        title: "Wi-Fi"
                        subtitle: Net.label
                        Button { small: true; filled: false; text: "Open"; onClicked: { Ui.settings = false; Ui.togglePanel("control", "", "wifi"); } }
                    }
                    Divider {}
                    SettingRow {
                        icon: "bluetooth"
                        title: "Bluetooth"
                        subtitle: Bt.label
                        Button { small: true; filled: false; text: "Open"; onClicked: { Ui.settings = false; Ui.togglePanel("control", "", "bluetooth"); } }
                    }
                }

                // ── Wallpaper ──
                Group {
                    visible: win.section === "wallpaper"
                    title: "Wallpaper"
                    SettingRow {
                        icon: "image"
                        title: "Change wallpaper"
                        subtitle: "The whole desktop takes the new wallpaper's colours"
                        RowLayout {
                            spacing: Theme.spacing
                            Button { small: true; filled: false; icon: "shuffle"; text: "Random"; onClicked: Wallpaper.random() }
                            Button { small: true; text: "Choose…"; onClicked: { Ui.settings = false; Ui.toggleOverlay("wallpapers"); } }
                        }
                    }
                    Divider {}
                    SettingRow {
                        icon: "autorenew"
                        title: "Change automatically"
                        subtitle: "A new random wallpaper every so often"
                        RowLayout {
                            spacing: 6
                            Repeater {
                                model: [[0, "Off"], [15, "15 min"], [30, "30 min"], [60, "1 hour"]]
                                delegate: Chip {
                                    required property var modelData
                                    small: true
                                    text: modelData[1]
                                    selected: Config.opt.autoWallpaper === modelData[0]
                                    onClicked: Config.opt.autoWallpaper = modelData[0]
                                }
                            }
                        }
                    }
                    Divider {}
                    SettingRow {
                        icon: "folder"
                        title: "Wallpaper folder"
                        subtitle: "Its sub-folders become filters in the picker"
                        Field {
                            implicitWidth: 220
                            text: Config.opt.wallpaperDir.replace(Quickshell.env("HOME"), "~")
                            input.onEditingFinished: {
                                const t = text.trim().replace(/^~/, Quickshell.env("HOME"));
                                if (t.length && t !== Config.opt.wallpaperDir) {
                                    Config.opt.wallpaperDir = t;
                                    Wallpaper.scan();
                                }
                            }
                        }
                    }
                }
                Group {
                    visible: win.section === "wallpaper"
                    title: "Transition"
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: Theme.ctl + Theme.padCard * 2
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.padCard
                            spacing: Theme.spacing
                            Repeater {
                                model: ["grow", "wipe", "wave", "outer", "fade"]
                                delegate: Chip {
                                    required property string modelData
                                    Layout.fillWidth: true
                                    text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                                    selected: Config.opt.transition === modelData
                                    onClicked: Config.opt.transition = modelData
                                }
                            }
                        }
                    }
                }

                // ── Shortcuts (the same list as the Super + / cheatsheet) ──
                Button {
                    visible: win.section === "shortcuts"
                    filled: false
                    icon: "search"
                    text: "Search shortcuts and settings (Super + /)"
                    onClicked: { Ui.settings = false; Ui.toggleOverlay("help"); }
                }
                Repeater {
                    model: win.section === "shortcuts" ? Binds.visibleGroups : []
                    delegate: Group {
                        id: kg
                        required property var modelData
                        title: modelData.title
                        Repeater {
                            model: kg.modelData.keys
                            delegate: Shortcut {
                                required property var modelData
                                label: modelData[0]
                                keys: modelData[1]
                            }
                        }
                    }
                }

                // ── About ──
                Group {
                    visible: win.section === "about"
                    title: "quartz"
                    SettingRow {
                        icon: "diamond"
                        title: "quartz"
                        subtitle: "A calm, complete desktop shell for Hyprland, built with Quickshell"
                    }
                    Divider {}
                    SettingRow {
                        icon: "folder_open"
                        title: "Your settings"
                        subtitle: "~/.local/state/quartz/config.json"
                        Button { small: true; filled: false; text: "Show"; onClicked: Quickshell.execDetached(["xdg-open", Quickshell.env("HOME") + "/.local/state/quartz"]) }
                    }
                    Divider {}
                    SettingRow {
                        icon: "settings_backup_restore"
                        title: "Reset all settings"
                        subtitle: win.confirmReset ? "Everything goes back to how quartz started. Your wallpaper stays" : "Back to the defaults, if something looks off"
                        RowLayout {
                            spacing: Theme.spacing
                            Button { visible: win.confirmReset; small: true; filled: false; text: "Cancel"; onClicked: win.confirmReset = false }
                            Button {
                                small: true
                                filled: win.confirmReset
                                text: win.confirmReset ? "Yes, reset" : "Reset…"
                                onClicked: {
                                    if (win.confirmReset) {
                                        Config.reset();
                                        win.confirmReset = false;
                                    } else {
                                        win.confirmReset = true;
                                    }
                                }
                            }
                        }
                    }
                    Divider {}
                    SettingRow {
                        icon: "restart_alt"
                        title: "Restart quartz"
                        subtitle: "Reloads the bar and panels. Your windows stay as they are"
                        Button { small: true; filled: false; text: "Restart"; onClicked: Quickshell.reload(true) }
                    }
                }
            }
        }
    }
    IconBtn {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 20
        anchors.topMargin: 24
        icon: "close"
        onClicked: Ui.settings = false
    }

    onSectionChanged: {
        flick.contentY = 0;
        page.opacity = 0;
        page.opacity = 1;
    }
}
