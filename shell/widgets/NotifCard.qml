import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import "../core"
import "../services"

// One notification. In a toast, X / timeout only hides the toast (it stays in
// the centre); swiping sideways dismisses it for good.
Rectangle {
    id: root
    required property int nid
    property bool toast: false
    readonly property var n: Notifs.get(nid)
    readonly property string img: Notifs.imageFor(n)
    readonly property string appIcon: Notifs.iconFor(n)
    readonly property var actions: (n?.actions ?? []).filter(a => a.identifier !== "default" && (a.text ?? "").length)
    readonly property var defaultAction: (n?.actions ?? []).find(a => a.identifier === "default") ?? null
    readonly property bool critical: n?.urgency === NotificationUrgency.Critical
    // who sent it: the app name, else the name of its desktop entry (terminals
    // and scripts often send none)
    readonly property var entry: n ? (n.desktopEntry ? DesktopEntries.byId(n.desktopEntry) : null) : null
    readonly property string appLabel: (n?.appName ?? "") || (entry?.name ?? "") || "Notification"
    property bool hovered: hover.hovered
    signal hideRequested

    // a screenshot (local image + a screenshot tool / summary) gets file actions
    readonly property string file: img.startsWith("file://") ? decodeURIComponent(img.substring(7)) : ""
    readonly property bool shot: file.length > 0 && /screen ?shot|hyprshot|grim|flameshot|spectacle|satty|swappy/i.test((n?.summary ?? "") + " " + (n?.appName ?? ""))
    property bool armDelete: false
    property bool copied: false
    Timer { id: disarm; interval: 3000; onTriggered: root.armDelete = false }
    Timer { id: uncopy; interval: 1600; onTriggered: root.copied = false }

    readonly property int inset: toast ? Theme.pad : Theme.padCard
    implicitHeight: col.implicitHeight + inset * 2
    radius: toast ? Theme.rSurface : Theme.rCard
    color: critical ? Theme.mix(toast ? Theme.glassStrong : Theme.card, Theme.errorContainer, 0.22) : toast ? Theme.glassStrong : Theme.card
    border.width: toast || critical ? 1 : 0
    border.color: critical ? Theme.alpha(Theme.error, 0.5) : Theme.hairline

    // a click opens it: a shallow dip
    scale: tap.pressed && root.defaultAction ? 0.98 : 1
    Behavior on scale { Ease { duration: Anim.fast } }

    // swipe to dismiss
    property real dragX: 0
    transform: Translate { x: root.dragX }
    opacity: 1 - Math.min(0.8, Math.abs(dragX) / (width * 0.9))
    Behavior on dragX { enabled: !drag.active; Spring { baseSpring: 3.2; baseDamping: 0.4 } }
    DragHandler {
        id: drag
        target: null
        xAxis.enabled: true
        yAxis.enabled: false
        onTranslationChanged: root.dragX = translation.x
        onActiveChanged: {
            if (!active) {
                if (Math.abs(root.dragX) > root.width * 0.35) {
                    root.dragX = root.dragX > 0 ? root.width * 1.2 : -root.width * 1.2;
                    Qt.callLater(() => Notifs.dismiss(root.nid));
                } else {
                    root.dragX = 0;
                }
            }
        }
    }
    HoverHandler { id: hover }
    TapHandler {
        id: tap
        onTapped: {
            if (root.defaultAction) {
                root.defaultAction.invoke();
                Ui.closeAll();
            }
        }
    }

    // The picture: shown beside the text (square) or as a preview under it (wide / tall).
    Image {
        id: probe
        visible: false
        source: root.img
        sourceSize: Qt.size(640, 640)
        fillMode: Image.PreserveAspectFit
        asynchronous: true
    }
    readonly property real imgW: probe.status === Image.Ready ? probe.implicitWidth : 0
    readonly property real imgH: probe.status === Image.Ready ? probe.implicitHeight : 0
    // wide or tall pictures (screenshots, photos) get the big preview; square
    // ones are icons or avatars, however large they're sent, and stay small
    readonly property real ratio: imgH > 0 ? imgW / imgH : 1
    readonly property bool preview: imgW > 0 && (ratio > 1.25 || ratio < 0.8) && Math.max(imgW, imgH) >= 160
    readonly property bool avatar: imgW > 0 && !preview

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: root.inset
        spacing: 8

        // app · time
        RowLayout {
            Layout.fillWidth: true
            Layout.rightMargin: Theme.ctlSmall
            spacing: 8
            Rectangle {
                implicitWidth: 22
                implicitHeight: 22
                radius: 7
                color: root.appIcon.length ? "transparent" : root.critical ? Theme.alpha(Theme.error, 0.18) : Theme.alpha(Theme.primary, 0.18)
                IconImage {
                    anchors.fill: parent
                    visible: root.appIcon.length > 0
                    source: root.appIcon
                    asynchronous: true
                }
                Icon {
                    anchors.centerIn: parent
                    visible: !root.appIcon.length
                    icon: root.critical ? "priority_high" : Notifs.glyphFor(root.n)
                    size: 15
                    fill: 1
                    color: root.critical ? Theme.error : Theme.primary
                }
            }
            T {
                text: root.appLabel
                font.pixelSize: Theme.fsSmall
                font.weight: Font.DemiBold
                color: Theme.textDim
                Layout.maximumWidth: 220
            }
            Item { Layout.fillWidth: true }
        }

        // summary + body, avatar on the right
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: 2
                T {
                    Layout.fillWidth: true
                    text: root.n?.summary ?? ""
                    font.pixelSize: Theme.fsBody + 1
                    font.weight: Font.DemiBold
                    color: root.critical ? Theme.error : Theme.text
                    visible: text.length > 0
                }
                T {
                    Layout.fillWidth: true
                    text: root.n?.body ?? ""
                    visible: text.length > 0
                    textFormat: Text.StyledText
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    maximumLineCount: root.toast ? 4 : 3
                    color: Theme.textDim
                    linkColor: Theme.primary
                    lineHeight: 1.1
                    onLinkActivated: l => Qt.openUrlExternally(l)
                }
            }
            ClippingRectangle {
                visible: root.avatar
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
                Layout.alignment: Qt.AlignTop
                radius: Theme.rThumb
                color: Theme.tonal
                Image {
                    anchors.fill: parent
                    source: root.avatar ? root.img : ""
                    sourceSize: Qt.size(96, 96)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }
        }

        // big picture (screenshots, photos)
        ClippingRectangle {
            visible: root.preview
            Layout.fillWidth: true
            // sized from the card's width (always known), not its own (assigned
            // by the layout after measuring) — else the card under-reports its
            // height and the next notification covers its buttons
            Layout.preferredHeight: root.preview ? Math.min(180, Math.round((root.width - root.inset * 2) * root.imgH / root.imgW)) : 0
            radius: Theme.rThumb
            color: Theme.tonal
            Image {
                anchors.fill: parent
                source: root.preview ? root.img : ""
                sourceSize: Qt.size(640, 640)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }

        Flow {
            Layout.fillWidth: true
            Layout.topMargin: 2
            visible: root.shot || root.actions.length > 0
            spacing: 6

            ActChip {
                visible: root.shot
                icon: "image"
                text: "Open"
                primary: true
                onClicked: {
                    Quickshell.execDetached(["xdg-open", root.file]);
                    Ui.closeAll();
                }
            }
            ActChip {
                visible: root.shot
                icon: root.copied ? "check" : "content_copy"
                text: root.copied ? "Copied" : "Copy"
                onClicked: {
                    Quickshell.execDetached(["sh", "-c", "wl-copy --type image/png < \"$1\"", "_", root.file]);
                    root.copied = true;
                    uncopy.restart();
                }
            }
            ActChip {
                visible: root.shot
                icon: "delete"
                text: root.armDelete ? "Delete?" : "Delete"
                danger: true
                onClicked: {
                    if (!root.armDelete) {
                        root.armDelete = true;
                        disarm.restart();
                        return;
                    }
                    // to the trash, not gone for good
                    Quickshell.execDetached(["sh", "-c", "gio trash -- \"$1\" 2>/dev/null || rm -f -- \"$1\"", "_", root.file]);
                    Notifs.dismiss(root.nid);
                }
            }
            Repeater {
                model: root.actions
                delegate: ActChip {
                    required property var modelData
                    required property int index
                    text: modelData.text
                    primary: index === 0 && !root.shot
                    onClicked: {
                        modelData.invoke();
                        if (root.toast)
                            root.hideRequested();
                    }
                }
            }
        }
    }

    // top-right: how long ago, which turns into ✕ while the pointer is on the card
    Item {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: root.inset - 3
        anchors.rightMargin: root.inset - 4
        width: 28
        height: 28
        T {
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            opacity: root.hovered ? 0 : 1
            text: Notifs.ago(root.nid, Notifs.now.getTime())
            font.pixelSize: Theme.fsSmall
            color: Theme.textDim
            Behavior on opacity { Ease { duration: Anim.fast } }
        }
        IconBtn {
            anchors.fill: parent
            size: 28
            iconSize: 16
            icon: "close"
            fg: Theme.textDim
            opacity: root.hovered ? 1 : 0
            enabled: root.hovered
            Behavior on opacity { Ease { duration: Anim.fast } }
            onClicked: root.toast ? root.hideRequested() : Notifs.dismiss(root.nid)
        }
    }
}
