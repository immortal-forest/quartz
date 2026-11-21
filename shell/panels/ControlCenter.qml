import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import "../core"
import "../services"
import "../widgets"
import "../bar"

// The control centre: quick settings + notifications on one sheet, with
// pages for Wi-Fi, Bluetooth and sound devices (settings live in their own window).
PanelWin {
    id: win
    name: "control"
    side: "right"
    cardWidth: 480
    contentHeight: stack.height

    // the whole sheet stays within ~80 % of the space under the bar; the
    // notification list gets what's left and scrolls inside it
    readonly property real maxSheet: Math.round(((scr?.height ?? 1000) - Theme.barHeight - Theme.gap) * 0.8)

    property string uptime: ""
    FileView {
        id: up
        path: "/proc/uptime"
        onLoaded: {
            const m = Math.floor(parseFloat(text()) / 60);
            win.uptime = m >= 60 ? Math.floor(m / 60) + " h " + (m % 60) + " min" : m + " min";
        }
    }
    onWantChanged: if (want) up.reload()
    Component.onCompleted: up.reload()

    component PageHeader: RowLayout {
        id: ph
        property string title: ""
        property bool hasSwitch: false
        property bool checked: false
        signal toggled
        Layout.fillWidth: true
        Layout.bottomMargin: 4
        spacing: 12
        IconBtn {
            icon: "arrow_back"
            onClicked: Ui.page = "main"
        }
        T {
            Layout.fillWidth: true
            text: ph.title
            font.pixelSize: Theme.fsLarge
            font.family: Theme.display
            font.weight: Font.Medium
        }
        Switch {
            visible: ph.hasSwitch
            checked: ph.checked
            onToggled: ph.toggled()
        }
    }

    // One list row (Wi-Fi network, Bluetooth device, sound device, setting):
    // a 40 px icon disc, title + subtitle, a trailing glyph / spinner / switch.
    // Rows with `extra` children expand into a card holding them.
    component ListRow: Rectangle {
        id: lr
        property string icon: ""
        property string title: ""
        property string subtitle: ""
        property bool active: false
        property bool expanded: false
        property bool busy: false
        property string trailing: ""
        property bool hasSwitch: false
        property bool checked: false
        property real battery: -1          // 0–1: a battery meter beside the trailing icon
        default property alias extra: extraCol.data
        signal clicked
        readonly property real inset: (Theme.row - Theme.ctl) / 2
        Layout.fillWidth: true
        implicitHeight: Theme.row + (expanded ? extraCol.implicitHeight + Theme.padCard : 0)
        radius: Theme.rCard
        color: expanded ? Theme.card : "transparent"
        clip: true
        Behavior on implicitHeight { Ease { duration: Anim.slow; easing.bezierCurve: Anim.emphasized } }
        Behavior on color { CAnim {} }
        StateLayer {
            anchors.fill: undefined
            width: parent.width
            height: Theme.row
            radius: Theme.rCard
            onClicked: lr.clicked()
        }
        RowLayout {
            x: lr.inset
            width: parent.width - lr.inset * 2
            height: Theme.row
            spacing: 12
            Rectangle {
                implicitWidth: Theme.ctl
                implicitHeight: Theme.ctl
                radius: Theme.pill(height)
                color: lr.active ? Theme.primary : Theme.tonal
                Behavior on color { CAnim {} }
                Icon {
                    anchors.centerIn: parent
                    icon: lr.icon
                    fill: lr.active ? 1 : 0
                    color: lr.active ? Theme.primaryText : Theme.text
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                T {
                    Layout.fillWidth: true
                    text: lr.title
                    font.weight: lr.active ? Font.DemiBold : Font.Medium
                }
                T {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: lr.subtitle
                    font.pixelSize: Theme.fsSmall
                    color: lr.active ? Theme.primary : Theme.textDim
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                }
            }
            Icon {
                visible: lr.busy
                icon: "progress_activity"
                color: Theme.primary
                RotationAnimator on rotation {
                    running: lr.busy
                    from: 0
                    to: 360
                    duration: 900
                    loops: Animation.Infinite
                }
            }
            RowLayout {
                visible: lr.battery >= 0
                spacing: 2
                Icon {
                    icon: lr.battery <= 0.15 ? "battery_android_frame_alert" : lr.battery >= 0.95 ? "battery_android_frame_full" : "battery_android_frame_" + Math.max(1, Math.min(6, Math.round(lr.battery * 6)))
                    size: 18
                    color: lr.battery <= 0.15 ? Theme.error : Theme.textDim
                }
                T {
                    text: Math.round(lr.battery * 100) + "%"
                    font.pixelSize: Theme.fsSmall
                    font.features: { "tnum": 1 }
                    color: lr.battery <= 0.15 ? Theme.error : Theme.textDim
                }
            }
            Icon {
                visible: !lr.busy && lr.trailing.length > 0
                // ink at the row's inset, mirroring the icon disc on the left
                tight: true
                Layout.rightMargin: 4
                icon: lr.trailing
                size: 18
                color: lr.active ? Theme.primary : Theme.textDim
                // a chevron turns to show the row is open
                rotation: lr.trailing === "expand_more" && lr.expanded ? 180 : 0
                Behavior on rotation { Ease { duration: Anim.normal; easing.bezierCurve: Anim.emphasized } }
            }
            Switch {
                visible: lr.hasSwitch
                checked: lr.checked
                onToggled: lr.clicked()
            }
        }
        ColumnLayout {
            id: extraCol
            x: lr.inset + Theme.ctl + 12
            y: Theme.row
            width: parent.width - x - Theme.padCard
            spacing: Theme.spacing
            opacity: lr.expanded ? 1 : 0
            Behavior on opacity { Ease {} }
        }
    }

    Item {
        id: stack
        width: parent.width
        height: (Ui.page === "wifi" ? wifiPage : Ui.page === "bluetooth" ? btPage : Ui.page === "audio" ? audioPage : mainPage).implicitHeight + Theme.pad * 2

        // Shared-axis: the main sheet slides left as a page comes in from the right.
        component Page: ColumnLayout {
            id: pg
            property string key: "main"
            readonly property bool current: Ui.page === key
            x: Theme.pad + (current ? 0 : (key === "main" ? -36 : 36))
            y: Theme.pad
            width: stack.width - Theme.pad * 2
            spacing: 12
            opacity: current ? 1 : 0
            visible: opacity > 0.01
            Behavior on x { Ease { duration: Anim.slow; easing.bezierCurve: Anim.emphasized } }
            Behavior on opacity { Ease { duration: pg.current ? Anim.slow : Anim.fast } }
        }

        // ───────────────────────────── main ─────────────────────────────
        Page {
            id: mainPage
            key: "main"

            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 4
                spacing: Theme.spacing
                Rectangle {
                    implicitWidth: Theme.ctl
                    implicitHeight: Theme.ctl
                    radius: Theme.pill(height)
                    color: Theme.alpha(Theme.primary, 0.18)
                    T {
                        anchors.centerIn: parent
                        text: (Quickshell.env("USER") || "?").charAt(0).toUpperCase()
                        font.pixelSize: Theme.fsTitle
                        font.weight: Font.DemiBold
                        color: Theme.primary
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    spacing: 0
                    T {
                        Layout.fillWidth: true
                        text: Quickshell.env("USER") || ""
                        font.pixelSize: Theme.fsTitle
                        font.weight: Font.DemiBold
                    }
                    T {
                        Layout.fillWidth: true
                        readonly property var dev: UPower.displayDevice
                        readonly property bool bat: dev?.isLaptopBattery ?? false
                        readonly property real secs: UPower.onBattery ? (dev?.timeToEmpty ?? 0) : (dev?.timeToFull ?? 0)
                        readonly property string batText: !bat ? "" : secs > 0 ? Math.floor(secs / 3600) + " h " + Math.round(secs % 3600 / 60) + " min " + (UPower.onBattery ? "left" : "to full") : ""
                        text: ["Up " + win.uptime, batText].filter(x => x.length).join("  ·  ")
                        color: Theme.textDim
                        font.pixelSize: Theme.fsSmall
                    }
                }
                IconBtn {
                    icon: "settings"
                    onClicked: Ui.openSettings()
                }
                IconBtn {
                    icon: "power_settings_new"
                    base: Theme.alpha(Theme.error, 0.16)
                    fg: Theme.error
                    onClicked: Ui.toggleOverlay("power")
                }
            }

            QSlider {
                Layout.fillWidth: true
                icon: Audio.muted ? "volume_off" : "volume_up"
                value: Audio.muted ? 0 : Audio.volume
                onMoved: v => Audio.setVolume(v)
                onIconClicked: Audio.toggleMute()
            }
            QSlider {
                Layout.fillWidth: true
                visible: Brightness.available
                icon: Brightness.icon
                value: Brightness.value
                onMoved: v => Brightness.set(v)
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                columns: 2
                columnSpacing: Theme.spacing
                rowSpacing: Theme.spacing
                uniformCellWidths: true
                Tile {
                    Layout.fillWidth: true
                    icon: Net.wiredUp ? "lan" : Net.wifiOn ? "wifi" : "wifi_off"
                    title: Net.wiredUp ? "Ethernet" : "Wi-Fi"
                    subtitle: Net.label
                    active: Net.wiredUp || (Net.wifiOn && !!Net.active)
                    more: true
                    onToggled: Net.setWifi(!Net.wifiOn)
                    onOpened: Ui.page = "wifi"
                }
                Tile {
                    Layout.fillWidth: true
                    visible: Bt.present
                    icon: Bt.icon
                    title: "Bluetooth"
                    subtitle: Bt.label
                    active: Bt.on
                    more: true
                    onToggled: Bt.setOn(!Bt.on)
                    onOpened: Ui.page = "bluetooth"
                }
                Tile {
                    Layout.fillWidth: true
                    icon: "speaker"
                    title: "Sound"
                    subtitle: Audio.shortName(Audio.sink)
                    more: true
                    onToggled: Ui.page = "audio"
                    onOpened: Ui.page = "audio"
                }
                Tile {
                    Layout.fillWidth: true
                    icon: Audio.micMuted ? "mic_off" : "mic"
                    title: "Microphone"
                    subtitle: Audio.micMuted ? "Muted" : "On"
                    active: !Audio.micMuted
                    onToggled: Audio.toggleMic()
                }
                Tile {
                    Layout.fillWidth: true
                    icon: "do_not_disturb_on"
                    title: "Do not disturb"
                    subtitle: Config.opt.dnd ? "On" : "Off"
                    active: Config.opt.dnd
                    onToggled: Config.opt.dnd = !Config.opt.dnd
                }
                Tile {
                    Layout.fillWidth: true
                    icon: "coffee"
                    title: "Stay awake"
                    subtitle: Config.opt.caffeine ? "On" : "Off"
                    active: Config.opt.caffeine
                    onToggled: Config.opt.caffeine = !Config.opt.caffeine
                }
            }

            // quick actions: labelled, one slim row instead of a row of tiles
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacing
                Button {
                    Layout.fillWidth: true
                    filled: false
                    icon: "screenshot_region"
                    text: "Screenshot"
                    onClicked: {
                        Ui.closeAll();
                        Quickshell.execDetached(["sh", "-c", "sleep 0.35; command -v hyprshot >/dev/null && exec hyprshot -m region; " +
                            "d=$(xdg-user-dir PICTURES 2>/dev/null || echo \"$HOME/Pictures\")/Screenshots; mkdir -p \"$d\"; f=\"$d/$(date +%Y-%m-%d_%H-%M-%S).png\"; " +
                            "g=$(slurp) && grim -g \"$g\" \"$f\" && wl-copy < \"$f\" && notify-send -i \"$f\" Screenshot \"Saved and copied\""]);
                    }
                }
                Button {
                    Layout.fillWidth: true
                    filled: false
                    icon: "wallpaper"
                    text: "Wallpaper"
                    onClicked: Ui.toggleOverlay("wallpapers")
                }
            }

            MediaCard {
                Layout.fillWidth: true
                live: win.shown
                visible: Media.hasTrack
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: Theme.spacing
                Section {
                    Layout.fillWidth: true
                    text: Notifs.count > 0 ? "Notifications · " + Notifs.count : "Notifications"
                }
                Button {
                    visible: Notifs.count > 0
                    small: true
                    filled: false
                    icon: "clear_all"
                    text: "Clear all"
                    onClicked: Notifs.clearAll()
                }
            }
            Item {
                id: notifArea
                Layout.fillWidth: true
                // y = everything above it, so this never depends on its own height
                readonly property real room: Math.max(Theme.row * 2, win.maxSheet - Theme.pad * 2 - y)
                implicitHeight: Notifs.count === 0 ? Theme.row : Math.min(notifCol.implicitHeight, room)
                Behavior on implicitHeight { enabled: win.settled; Ease { duration: Anim.slow; easing.bezierCurve: Anim.emphasized } }
                Rectangle {
                    anchors.fill: parent
                    visible: Notifs.count === 0
                    radius: Theme.rCard
                    color: Theme.card
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 10
                        Icon {
                            icon: "done_all"
                            color: Theme.textDim
                        }
                        T {
                            text: "No notifications"
                            color: Theme.textDim
                        }
                    }
                }
                // a Column in a Flickable (not a ListView): the cards change height
                // after they appear, and a ListView under-measured them and cut
                // the last one's buttons with a straight edge
                Flickable {
                    id: notifFlick
                    anchors.fill: parent
                    visible: Notifs.count > 0
                    clip: true
                    contentHeight: notifCol.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    Column {
                        id: notifCol
                        width: notifFlick.width
                        spacing: Theme.spacing
                        move: Transition {
                            NumberAnimation { properties: "y"; duration: Anim.slow; easing.type: Easing.BezierSpline; easing.bezierCurve: Anim.emphasized }
                        }
                        Repeater {
                            model: Notifs.history
                            delegate: NotifCard {
                                width: notifCol.width
                            }
                        }
                    }
                }
                // soft haze where the list scrolls on past the edge (as in the launcher)
                Rectangle {
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    height: 28
                    visible: Notifs.count > 0
                    opacity: notifFlick.contentY > 1 ? 1 : 0
                    Behavior on opacity { Ease { duration: Anim.fast } }
                    gradient: Gradient {
                        GradientStop { position: 0; color: win.card.color }
                        GradientStop { position: 1; color: Theme.alpha(win.card.color, 0) }
                    }
                }
                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 40
                    visible: Notifs.count > 0
                    opacity: notifFlick.contentHeight > notifFlick.height + 1 && !notifFlick.atYEnd ? 1 : 0
                    Behavior on opacity { Ease { duration: Anim.fast } }
                    gradient: Gradient {
                        GradientStop { position: 0; color: Theme.alpha(win.card.color, 0) }
                        GradientStop { position: 1; color: win.card.color }
                    }
                }
            }
        }

        // ───────────────────────────── Wi-Fi ─────────────────────────────
        Page {
            id: wifiPage
            key: "wifi"
            onCurrentChanged: Net.scan(current && win.want)

            PageHeader {
                title: "Wi-Fi"
                hasSwitch: true
                checked: Net.wifiOn
                onToggled: Net.setWifi(!Net.wifiOn)
            }
            Rectangle {
                Layout.fillWidth: true
                visible: Net.wiredUp
                implicitHeight: Theme.ctl + 8
                radius: Theme.rCard
                color: Theme.alpha(Theme.primary, 0.12)
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.padCard + 4
                    spacing: 12
                    Icon { icon: "lan"; fill: 1; color: Theme.primary }
                    T { text: "Connected over Ethernet"; color: Theme.primary; font.weight: Font.Medium }
                }
            }
            T {
                visible: !Net.wifiOn
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 12
                Layout.bottomMargin: 12
                text: "Wi-Fi is off"
                color: Theme.textDim
            }
            Flickable {
                Layout.fillWidth: true
                Layout.leftMargin: -(Theme.row - Theme.ctl) / 2
                Layout.rightMargin: -(Theme.row - Theme.ctl) / 2
                implicitHeight: Math.min(netCol.implicitHeight, 448)
                contentHeight: netCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                visible: Net.wifiOn
                ColumnLayout {
                    id: netCol
                    width: parent.width
                    spacing: 2
                    Repeater {
                        model: wifiPage.current ? Net.networks : []   // built only while the page is open
                        delegate: ListRow {
                            id: nr
                            required property var modelData
                            property string err: ""
                            readonly property bool locked: Net.secured(modelData)
                            icon: Net.bars(Net.norm(modelData.signalStrength))
                            title: modelData.name
                            subtitle: err.length ? err : modelData.connected ? "Connected" : modelData.stateChanging ? "Connecting…" : modelData.known ? "Saved" : locked ? "Secured" : "Open"
                            active: modelData.connected
                            busy: modelData.stateChanging
                            trailing: modelData.connected ? "check" : locked ? "lock" : ""
                            onClicked: {
                                if (!modelData.connected && (modelData.known || !locked)) {
                                    err = "";
                                    modelData.connect();
                                } else {
                                    expanded = !expanded;
                                    if (expanded && !modelData.connected)
                                        pw.input.forceActiveFocus();
                                }
                            }
                            Connections {
                                target: nr.modelData
                                function onConnectionFailed(reason) {
                                    nr.err = "Couldn't connect" + (nr.locked ? " — check the password" : "");
                                    nr.expanded = nr.locked;
                                }
                                function onConnectedChanged() { if (nr.modelData.connected) { nr.err = ""; nr.expanded = false; } }
                            }
                            Field {
                                id: pw
                                visible: !nr.modelData.connected && nr.locked
                                Layout.fillWidth: true
                                icon: "key"
                                placeholder: "Password"
                                password: true
                                onAccepted: connectBtn.clicked()
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.spacing
                                Button {
                                    visible: nr.modelData.known
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    small: true
                                    icon: "delete"
                                    text: "Forget"
                                    filled: false
                                    fg: Theme.error
                                    onClicked: { nr.modelData.forget(); nr.expanded = false; }
                                }
                                Button {
                                    visible: nr.modelData.connected
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    small: true
                                    icon: "link_off"
                                    text: "Disconnect"
                                    filled: false
                                    onClicked: { nr.modelData.disconnect(); nr.expanded = false; }
                                }
                                Button {
                                    id: connectBtn
                                    visible: !nr.modelData.connected
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    small: true
                                    icon: "link"
                                    text: "Connect"
                                    onClicked: {
                                        nr.err = "";
                                        if (nr.locked && !nr.modelData.known && pw.text.length)
                                            nr.modelData.connectWithPsk(pw.text);
                                        else
                                            nr.modelData.connect();
                                    }
                                }
                            }
                        }
                    }
                    T {
                        visible: Net.networks.length === 0
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 12
                        Layout.bottomMargin: 12
                        text: "Looking for networks…"
                        color: Theme.textDim
                    }
                }
            }
        }

        // ─────────────────────────── Bluetooth ───────────────────────────
        Page {
            id: btPage
            key: "bluetooth"
            onCurrentChanged: Bt.scan(current && win.want)

            PageHeader {
                title: "Bluetooth"
                hasSwitch: true
                checked: Bt.on
                onToggled: Bt.setOn(!Bt.on)
            }
            T {
                visible: !Bt.on
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 12
                Layout.bottomMargin: 12
                text: "Bluetooth is off"
                color: Theme.textDim
            }
            Flickable {
                Layout.fillWidth: true
                Layout.leftMargin: -(Theme.row - Theme.ctl) / 2
                Layout.rightMargin: -(Theme.row - Theme.ctl) / 2
                implicitHeight: Math.min(btCol.implicitHeight, 448)
                contentHeight: btCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                visible: Bt.on
                ColumnLayout {
                    id: btCol
                    width: parent.width
                    spacing: 2
                    Repeater {
                        model: btPage.current ? Bt.devices : []
                        delegate: ListRow {
                            id: br
                            required property var modelData
                            property bool wantConnect: false
                            readonly property bool changing: modelData.state === BluetoothDeviceState.Connecting || modelData.state === BluetoothDeviceState.Disconnecting || modelData.pairing
                            icon: Bt.deviceIcon(modelData)
                            title: modelData.name
                            battery: modelData.connected && modelData.batteryAvailable ? (modelData.battery > 1 ? modelData.battery / 100 : modelData.battery) : -1
                            subtitle: modelData.connected ? (expanded ? "Connected" : "Connected · tap for options") : modelData.pairing ? "Pairing…" : changing ? "Connecting…" : modelData.paired ? "Paired · tap to connect" : "Tap to pair"
                            active: modelData.connected
                            busy: changing
                            trailing: modelData.connected ? "expand_more" : ""
                            onClicked: {
                                if (modelData.connected)
                                    expanded = !expanded;
                                else if (modelData.paired)
                                    modelData.connect();
                                else {
                                    wantConnect = true;
                                    modelData.trusted = true;
                                    modelData.pair();
                                }
                            }
                            Connections {
                                target: br.modelData
                                function onPairedChanged() {
                                    if (br.modelData.paired && br.wantConnect) {
                                        br.wantConnect = false;
                                        br.modelData.connect();
                                    }
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.spacing
                                Button {
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    small: true
                                    icon: "delete"
                                    text: "Forget"
                                    filled: false
                                    fg: Theme.error
                                    onClicked: { br.modelData.forget(); br.expanded = false; }
                                }
                                Button {
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    small: true
                                    icon: "link_off"
                                    text: "Disconnect"
                                    filled: false
                                    onClicked: { br.modelData.disconnect(); br.expanded = false; }
                                }
                            }
                        }
                    }
                    T {
                        visible: Bt.devices.length === 0
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 12
                        Layout.bottomMargin: 12
                        text: "Searching for devices…"
                        color: Theme.textDim
                    }
                }
            }
        }

        // ───────────────────────────── Sound ─────────────────────────────
        Page {
            id: audioPage
            key: "audio"

            PageHeader { title: "Sound" }
            Section { text: "Output" }
            QSlider {
                Layout.fillWidth: true
                icon: Audio.muted ? "volume_off" : "volume_up"
                value: Audio.muted ? 0 : Audio.volume
                onMoved: v => Audio.setVolume(v)
                onIconClicked: Audio.toggleMute()
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: -(Theme.row - Theme.ctl) / 2
                Layout.rightMargin: -(Theme.row - Theme.ctl) / 2
                spacing: 2
                Repeater {
                    model: audioPage.current ? Audio.sinks : []
                    delegate: ListRow {
                        required property var modelData
                        icon: modelData.name.indexOf("bluez") >= 0 ? "headphones" : modelData.name.indexOf("hdmi") >= 0 ? "tv" : "speaker"
                        // what it is first ("Speakers"), the chip's long name under it
                        title: Audio.shortName(modelData)
                        subtitle: Audio.shortName(modelData) !== Audio.name(modelData) ? Audio.name(modelData).replace(/ (Analog|Digital) (Stereo|Mono|Surround.*)$/i, "") : ""
                        active: modelData === Audio.sink
                        trailing: active ? "check" : ""
                        onClicked: Audio.useSink(modelData)
                    }
                }
            }
            Section { text: "Input"; Layout.topMargin: 4 }
            QSlider {
                Layout.fillWidth: true
                icon: Audio.micIcon
                value: Audio.micMuted ? 0 : Audio.micVolume
                onMoved: v => Audio.setMic(v)
                onIconClicked: Audio.toggleMic()
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: -(Theme.row - Theme.ctl) / 2
                Layout.rightMargin: -(Theme.row - Theme.ctl) / 2
                visible: Audio.sources.length > 1
                spacing: 2
                Repeater {
                    model: audioPage.current && Audio.sources.length > 1 ? Audio.sources : []
                    delegate: ListRow {
                        required property var modelData
                        icon: "mic"
                        // what it is first ("Speakers"), the chip's long name under it
                        title: Audio.shortName(modelData)
                        subtitle: Audio.shortName(modelData) !== Audio.name(modelData) ? Audio.name(modelData).replace(/ (Analog|Digital) (Stereo|Mono|Surround.*)$/i, "") : ""
                        active: modelData === Audio.source
                        trailing: active ? "check" : ""
                        onClicked: Audio.useSource(modelData)
                    }
                }
            }
            Section {
                visible: Audio.streams.length > 0
                text: "Apps"
                Layout.topMargin: 4
            }
            Repeater {
                model: audioPage.current ? Audio.streams : []
                delegate: RowLayout {
                    id: sr
                    required property var modelData
                    readonly property string app: modelData.properties["application.name"] ?? modelData.description ?? modelData.name
                    Layout.fillWidth: true
                    spacing: 12
                    AppIcon {
                        size: Theme.ctl
                        name: sr.modelData.properties["application.icon-name"] ?? (sr.app ?? "")
                        glyph: "music_note"
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        T { text: sr.app; font.pixelSize: Theme.fsSmall; color: Theme.textDim; Layout.fillWidth: true }
                        QSlider {
                            Layout.fillWidth: true
                            implicitHeight: Theme.ctlSmall
                            icon: sr.modelData.audio.muted ? "volume_off" : "volume_up"
                            value: sr.modelData.audio.muted ? 0 : sr.modelData.audio.volume
                            onMoved: v => { sr.modelData.audio.muted = false; sr.modelData.audio.volume = v; }
                            onIconClicked: sr.modelData.audio.muted = !sr.modelData.audio.muted
                        }
                    }
                }
            }
        }
    }
}
