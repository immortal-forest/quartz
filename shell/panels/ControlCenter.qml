import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import "../core"
import "../services"
import "../widgets"
import "../bar"

// The control centre: quick settings + notifications on one sheet, with
// pages for Wi-Fi, Bluetooth, sound devices and quartz's own settings.
PanelWin {
    id: win
    name: "control"
    side: "right"
    cardWidth: 404
    contentHeight: stack.height

    component PageHeader: RowLayout {
        id: ph
        property string title: ""
        property bool hasSwitch: false
        property bool checked: false
        signal toggled
        Layout.fillWidth: true
        spacing: 8
        IconBtn {
            icon: "arrow_back"
            size: 36
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

    component Row2: Rectangle {
        id: r2
        property string icon: ""
        property string title: ""
        property string subtitle: ""
        property bool active: false
        property bool expanded: false
        property bool busy: false
        default property alias extra: extraCol.data
        signal clicked
        Layout.fillWidth: true
        implicitHeight: head.implicitHeight + (expanded ? extraCol.implicitHeight + 10 : 0) + 16
        radius: 16
        color: expanded ? Theme.card : "transparent"
        clip: true
        Behavior on implicitHeight { Ease { duration: Anim.slow; easing.bezierCurve: Anim.emphasized } }
        Behavior on color { CAnim {} }
        RowLayout {
            id: head
            x: 10
            y: 8
            width: parent.width - 20
            spacing: 12
            Rectangle {
                implicitWidth: 36
                implicitHeight: 36
                radius: 18
                color: r2.active ? Theme.primary : Theme.alpha(Theme.text, 0.07)
                Behavior on color { CAnim {} }
                Icon {
                    anchors.centerIn: parent
                    icon: r2.icon
                    size: 19
                    fill: r2.active ? 1 : 0
                    color: r2.active ? Theme.primaryText : Theme.text
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                T {
                    Layout.fillWidth: true
                    text: r2.title
                    font.weight: r2.active ? Font.DemiBold : Font.Normal
                }
                T {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: r2.subtitle
                    font.pixelSize: Theme.fsSmall
                    color: r2.active ? Theme.primary : Theme.textDim
                }
            }
            Icon {
                visible: r2.busy
                icon: "progress_activity"
                size: 18
                color: Theme.primary
                RotationAnimator on rotation {
                    running: r2.busy
                    from: 0
                    to: 360
                    duration: 900
                    loops: Animation.Infinite
                }
            }
        }
        StateLayer {
            height: head.implicitHeight + 16
            anchors.fill: undefined
            width: parent.width
            radius: 16
            onClicked: r2.clicked()
        }
        ColumnLayout {
            id: extraCol
            x: 58
            y: head.implicitHeight + 16
            width: parent.width - 68
            spacing: 8
            opacity: r2.expanded ? 1 : 0
            Behavior on opacity { Ease {} }
        }
    }

    component PillBtn: Rectangle {
        id: pb
        property string text: ""
        property bool filled: true
        signal clicked
        implicitHeight: 32
        implicitWidth: lbl.implicitWidth + 28
        radius: 16
        color: filled ? Theme.primary : Theme.alpha(Theme.text, 0.08)
        T {
            id: lbl
            anchors.centerIn: parent
            text: pb.text
            font.weight: Font.DemiBold
            color: pb.filled ? Theme.primaryText : Theme.text
        }
        StateLayer {
            tint: pb.filled ? Theme.primaryText : Theme.text
            onClicked: pb.clicked()
        }
    }

    Item {
        id: stack
        width: parent.width
        height: (Ui.page === "wifi" ? wifiPage : Ui.page === "bluetooth" ? btPage : Ui.page === "audio" ? audioPage : Ui.page === "settings" ? settingsPage : mainPage).implicitHeight + 32

        // Shared-axis: the main sheet slides left as a page comes in from the right.
        component Page: ColumnLayout {
            id: pg
            property string key: "main"
            readonly property bool current: Ui.page === key
            x: 16 + (current ? 0 : (key === "main" ? -36 : 36))
            y: 16
            width: stack.width - 32
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
                spacing: 6
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    T {
                        text: Qt.formatDateTime(Notifs.now, "dddd")
                        font.family: Theme.display
                        font.pixelSize: Theme.fsLarge
                        font.weight: Font.Medium
                    }
                    T {
                        readonly property var dev: UPower.displayDevice
                        readonly property bool bat: dev?.isLaptopBattery ?? false
                        readonly property real secs: UPower.onBattery ? (dev?.timeToEmpty ?? 0) : (dev?.timeToFull ?? 0)
                        text: Qt.formatDateTime(Notifs.now, "d MMMM") + (bat && secs > 0 ? "  ·  " + Math.floor(secs / 3600) + " h " + Math.round(secs % 3600 / 60) + " min " + (UPower.onBattery ? "left" : "to full") : "")
                        color: Theme.textDim
                        font.pixelSize: Theme.fsSmall
                    }
                }
                IconBtn {
                    icon: "screenshot_region"
                    onClicked: {
                        Ui.closeAll();
                        Quickshell.execDetached(["sh", "-c", "sleep 0.35; hyprshot -m region"]);
                    }
                }
                IconBtn {
                    icon: "wallpaper"
                    onClicked: Ui.toggleOverlay("wallpapers")
                }
                IconBtn {
                    icon: "settings"
                    onClicked: Ui.page = "settings"
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
                showValue: true
                onMoved: v => Audio.setVolume(v)
                onIconClicked: Audio.toggleMute()
            }
            QSlider {
                Layout.fillWidth: true
                visible: Brightness.available
                icon: Brightness.icon
                value: Brightness.value
                showValue: true
                onMoved: v => Brightness.set(v)
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 8
                rowSpacing: 8
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
                    icon: Audio.micMuted ? "mic_off" : "mic"
                    title: "Microphone"
                    subtitle: Audio.micMuted ? "Muted" : "On"
                    active: !Audio.micMuted
                    more: true
                    onToggled: Audio.toggleMic()
                    onOpened: Ui.page = "audio"
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
                    subtitle: Config.opt.caffeine ? "Screen stays on" : "Off"
                    active: Config.opt.caffeine
                    onToggled: Config.opt.caffeine = !Config.opt.caffeine
                }
                Tile {
                    Layout.fillWidth: true
                    icon: "speaker"
                    title: "Sound"
                    subtitle: Audio.name(Audio.sink)
                    more: true
                    onToggled: Ui.page = "audio"
                    onOpened: Ui.page = "audio"
                }
            }

            MediaCard {
                Layout.fillWidth: true
                visible: Media.hasTrack
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                T {
                    Layout.fillWidth: true
                    text: "Notifications"
                    font.weight: Font.DemiBold
                    color: Theme.textDim
                }
                T {
                    visible: Notifs.count > 0
                    text: "Clear all"
                    font.weight: Font.DemiBold
                    color: Theme.primary
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifs.clearAll()
                    }
                }
            }
            Item {
                Layout.fillWidth: true
                implicitHeight: Notifs.count === 0 ? 72 : Math.min(list.contentHeight, 340)
                Behavior on implicitHeight { Ease { duration: Anim.slow; easing.bezierCurve: Anim.emphasized } }
                ColumnLayout {
                    anchors.centerIn: parent
                    visible: Notifs.count === 0
                    spacing: 4
                    Icon {
                        Layout.alignment: Qt.AlignHCenter
                        icon: "notifications_paused"
                        size: 26
                        color: Theme.textDim
                    }
                    T {
                        text: "You're all caught up"
                        color: Theme.textDim
                    }
                }
                ListView {
                    id: list
                    anchors.fill: parent
                    clip: true
                    spacing: 8
                    model: Notifs.history
                    boundsBehavior: Flickable.StopAtBounds
                    delegate: NotifCard {
                        required property int nid
                        width: list.width
                    }
                    add: Transition {
                        ParallelAnimation {
                            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Anim.normal }
                            NumberAnimation { property: "scale"; from: 0.95; to: 1; duration: Anim.slow; easing.type: Easing.OutBack }
                        }
                    }
                    displaced: Transition {
                        NumberAnimation { property: "y"; duration: Anim.slow; easing.type: Easing.BezierSpline; easing.bezierCurve: Anim.emphasized }
                    }
                    remove: Transition {
                        ParallelAnimation {
                            NumberAnimation { property: "opacity"; to: 0; duration: Anim.fast }
                            NumberAnimation { property: "x"; to: 60; duration: Anim.normal; easing.type: Easing.BezierSpline; easing.bezierCurve: Anim.accel }
                        }
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
                implicitHeight: 44
                radius: 14
                color: Theme.alpha(Theme.primary, 0.12)
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    spacing: 10
                    Icon { icon: "lan"; fill: 1; color: Theme.primary }
                    T { text: "Connected over Ethernet"; color: Theme.primary; font.weight: Font.Medium }
                }
            }
            Flickable {
                Layout.fillWidth: true
                implicitHeight: Math.min(netCol.implicitHeight, 420)
                contentHeight: netCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                visible: Net.wifiOn
                ColumnLayout {
                    id: netCol
                    width: parent.width
                    spacing: 2
                    Repeater {
                        model: Net.networks
                        delegate: Row2 {
                            id: nr
                            required property var modelData
                            property string err: ""
                            readonly property bool locked: Net.secured(modelData)
                            icon: Net.bars(Net.norm(modelData.signalStrength))
                            title: modelData.name
                            subtitle: err.length ? err : modelData.connected ? "Connected" : modelData.stateChanging ? "Connecting…" : modelData.known ? "Saved" : locked ? "Secured" : "Open"
                            active: modelData.connected
                            busy: modelData.stateChanging
                            onClicked: {
                                if (!modelData.connected && (modelData.known || !locked)) {
                                    err = "";
                                    modelData.connect();
                                } else {
                                    expanded = !expanded;
                                    if (expanded && !modelData.connected)
                                        pw.forceActiveFocus();
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
                            Rectangle {
                                visible: !nr.modelData.connected && nr.locked
                                Layout.fillWidth: true
                                implicitHeight: 38
                                radius: 12
                                color: Theme.alpha(Theme.text, 0.07)
                                border.width: pw.activeFocus ? 2 : 0
                                border.color: Theme.primary
                                TextInput {
                                    id: pw
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    verticalAlignment: TextInput.AlignVCenter
                                    echoMode: TextInput.Password
                                    color: Theme.text
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fsBody
                                    selectionColor: Theme.primary
                                    clip: true
                                    onAccepted: connectBtn.clicked()
                                    T {
                                        visible: !pw.text.length
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Password"
                                        color: Theme.textDim
                                    }
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Item { Layout.fillWidth: true }
                                PillBtn {
                                    visible: nr.modelData.known
                                    text: "Forget"
                                    filled: false
                                    onClicked: { nr.modelData.forget(); nr.expanded = false; }
                                }
                                PillBtn {
                                    visible: nr.modelData.connected
                                    text: "Disconnect"
                                    filled: false
                                    onClicked: { nr.modelData.disconnect(); nr.expanded = false; }
                                }
                                PillBtn {
                                    id: connectBtn
                                    visible: !nr.modelData.connected
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
            Flickable {
                Layout.fillWidth: true
                implicitHeight: Math.min(btCol.implicitHeight, 420)
                contentHeight: btCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                visible: Bt.on
                ColumnLayout {
                    id: btCol
                    width: parent.width
                    spacing: 2
                    Repeater {
                        model: Bt.devices
                        delegate: Row2 {
                            id: br
                            required property var modelData
                            property bool wantConnect: false
                            readonly property bool changing: modelData.state === BluetoothDeviceState.Connecting || modelData.state === BluetoothDeviceState.Disconnecting || modelData.pairing
                            icon: Bt.deviceIcon(modelData)
                            title: modelData.name
                            subtitle: modelData.connected ? ("Connected" + (modelData.batteryAvailable ? " · " + Math.round(modelData.battery * (modelData.battery > 1 ? 1 : 100)) + "%" : "")) : modelData.pairing ? "Pairing…" : changing ? "Connecting…" : modelData.paired ? "Paired" : ""
                            active: modelData.connected
                            busy: changing
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
                                spacing: 6
                                Item { Layout.fillWidth: true }
                                PillBtn {
                                    text: "Forget"
                                    filled: false
                                    onClicked: { br.modelData.forget(); br.expanded = false; }
                                }
                                PillBtn {
                                    text: "Disconnect"
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
            T { text: "Output"; font.weight: Font.DemiBold; color: Theme.textDim }
            Repeater {
                model: Audio.sinks
                delegate: Row2 {
                    required property var modelData
                    icon: modelData.name.indexOf("bluez") >= 0 ? "headphones" : modelData.name.indexOf("hdmi") >= 0 ? "tv" : "speaker"
                    title: Audio.name(modelData)
                    active: modelData === Audio.sink
                    onClicked: Audio.useSink(modelData)
                }
            }
            T { text: "Input"; font.weight: Font.DemiBold; color: Theme.textDim; Layout.topMargin: 4 }
            QSlider {
                Layout.fillWidth: true
                icon: Audio.micIcon
                value: Audio.micMuted ? 0 : Audio.micVolume
                showValue: true
                onMoved: v => Audio.setMic(v)
                onIconClicked: Audio.toggleMic()
            }
            Repeater {
                model: Audio.sources.length > 1 ? Audio.sources : []
                delegate: Row2 {
                    required property var modelData
                    icon: "mic"
                    title: Audio.name(modelData)
                    active: modelData === Audio.source
                    onClicked: Audio.useSource(modelData)
                }
            }
            T {
                visible: Audio.streams.length > 0
                text: "Apps"
                font.weight: Font.DemiBold
                color: Theme.textDim
                Layout.topMargin: 4
            }
            Repeater {
                model: Audio.streams
                delegate: RowLayout {
                    id: sr
                    required property var modelData
                    readonly property string app: modelData.properties["application.name"] ?? modelData.description ?? modelData.name
                    Layout.fillWidth: true
                    spacing: 10
                    AppIcon {
                        size: 26
                        name: sr.modelData.properties["application.icon-name"] ?? (sr.app ?? "")
                        glyph: "music_note"
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        T { text: sr.app; font.pixelSize: Theme.fsSmall; color: Theme.textDim; Layout.fillWidth: true }
                        QSlider {
                            Layout.fillWidth: true
                            implicitHeight: 28
                            icon: sr.modelData.audio.muted ? "volume_off" : "volume_up"
                            value: sr.modelData.audio.muted ? 0 : sr.modelData.audio.volume
                            onMoved: v => { sr.modelData.audio.muted = false; sr.modelData.audio.volume = v; }
                            onIconClicked: sr.modelData.audio.muted = !sr.modelData.audio.muted
                        }
                    }
                }
            }
        }

        // ──────────────────────────── Settings ────────────────────────────
        Page {
            id: settingsPage
            key: "settings"

            component SetRow: RowLayout {
                id: sr2
                property string title: ""
                property string subtitle: ""
                property bool checked: false
                signal toggled
                Layout.fillWidth: true
                Layout.topMargin: 2
                spacing: 12
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    T { text: sr2.title; Layout.fillWidth: true }
                    T {
                        text: sr2.subtitle
                        visible: text.length > 0
                        font.pixelSize: Theme.fsSmall
                        color: Theme.textDim
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }
                }
                Switch {
                    checked: sr2.checked
                    onToggled: sr2.toggled()
                }
            }

            PageHeader { title: "quartz" }
            SetRow {
                title: "24-hour clock"
                checked: Config.opt.use24h
                onToggled: Config.opt.use24h = !Config.opt.use24h
            }
            SetRow {
                title: "Workspace numbers"
                subtitle: "Numbers instead of dots in the bar"
                checked: Config.opt.workspaceNumbers
                onToggled: Config.opt.workspaceNumbers = !Config.opt.workspaceNumbers
            }
            SetRow {
                title: "Theme apps from the wallpaper"
                subtitle: "Terminals, Hyprland borders, cava… follow the wallpaper colours"
                checked: Config.opt.themeApps
                onToggled: Config.opt.themeApps = !Config.opt.themeApps
            }
            SetRow {
                title: "Japanese accents"
                subtitle: "Kanji weekday in the bar, Japanese date on the lock screen"
                checked: Config.opt.japanese
                onToggled: Config.opt.japanese = !Config.opt.japanese
            }
            T { text: "Wallpaper transition"; Layout.topMargin: 4 }
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: ["grow", "wipe", "wave", "outer", "fade"]
                    delegate: Rectangle {
                        required property string modelData
                        readonly property bool on: Config.opt.transition === modelData
                        Layout.fillWidth: true
                        implicitHeight: 32
                        radius: 16
                        color: on ? Theme.secondaryContainer : Theme.alpha(Theme.text, 0.06)
                        Behavior on color { CAnim {} }
                        T {
                            anchors.centerIn: parent
                            text: parent.modelData.charAt(0).toUpperCase() + parent.modelData.slice(1)
                            font.weight: parent.on ? Font.DemiBold : Font.Normal
                            color: parent.on ? Theme.secondaryContainerText : Theme.textDim
                        }
                        StateLayer { onClicked: Config.opt.transition = parent.modelData }
                    }
                }
            }
            T {
                Layout.fillWidth: true
                Layout.topMargin: 4
                text: "Wallpapers from " + Config.opt.wallpaperDir.replace(Quickshell.env("HOME"), "~") + "  ·  settings live in ~/.local/state/quartz/config.json"
                font.pixelSize: Theme.fsSmall
                color: Theme.textDim
                wrapMode: Text.Wrap
            }
        }
    }
}
