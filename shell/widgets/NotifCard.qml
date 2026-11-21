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
    property bool hovered: hover.hovered
    signal hideRequested

    implicitHeight: col.implicitHeight + 26
    radius: 20
    color: toast ? Theme.glassStrong : Theme.card
    border.width: toast ? 1 : 0
    border.color: critical ? Theme.alpha(Theme.error, 0.6) : Theme.hairline

    // swipe to dismiss
    property real dragX: 0
    transform: Translate { x: root.dragX }
    opacity: 1 - Math.min(0.8, Math.abs(dragX) / (width * 0.9))
    Behavior on dragX { enabled: !drag.active; Spring { spring: 3.2; damping: 0.4 } }
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
        onTapped: {
            if (root.defaultAction) {
                root.defaultAction.invoke();
                Ui.closeAll();
            }
        }
    }

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 13
        anchors.leftMargin: 14
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Item {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                Layout.alignment: Qt.AlignTop
                ClippingWrapperRectangle {
                    anchors.fill: parent
                    visible: root.img.length > 0
                    radius: 12
                    color: "transparent"
                    Image {
                        source: root.img
                        sourceSize: Qt.size(80, 80)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    visible: !root.img.length
                    radius: 12
                    color: root.critical ? Theme.errorContainer : Theme.secondaryContainer
                    IconImage {
                        anchors.centerIn: parent
                        visible: root.appIcon.length > 0
                        implicitSize: 24
                        source: root.appIcon
                        asynchronous: true
                    }
                    Icon {
                        anchors.centerIn: parent
                        visible: !root.appIcon.length
                        icon: root.critical ? "priority_high" : Notifs.glyphFor(root.n)
                        fill: 1
                        size: 20
                        color: root.critical ? Theme.errorContainerText : Theme.secondaryContainerText
                    }
                }
                // app badge on top of a picture
                Rectangle {
                    visible: root.img.length > 0 && root.appIcon.length > 0
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: -4
                    width: 20
                    height: 20
                    radius: 10
                    color: Theme.surfaceHigh
                    IconImage {
                        anchors.centerIn: parent
                        implicitSize: 14
                        source: root.appIcon
                        asynchronous: true
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    T {
                        text: root.n?.appName || "Notification"
                        font.pixelSize: Theme.fsSmall
                        font.weight: Font.Medium
                        color: Theme.textDim
                        Layout.maximumWidth: 180
                    }
                    T {
                        text: "· " + Notifs.ago(root.nid, Notifs.now.getTime())
                        font.pixelSize: Theme.fsSmall
                        color: Theme.textDim
                    }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        implicitWidth: 22
                        implicitHeight: 22
                        radius: 11
                        color: Theme.alpha(Theme.text, 0.06)
                        opacity: root.hovered || !root.toast ? 1 : 0
                        Behavior on opacity { Ease { duration: Anim.fast } }
                        Icon {
                            anchors.centerIn: parent
                            icon: "close"
                            size: 14
                            color: Theme.textDim
                        }
                        StateLayer {
                            onClicked: root.toast ? root.hideRequested() : Notifs.dismiss(root.nid)
                        }
                    }
                }
                T {
                    Layout.fillWidth: true
                    text: root.n?.summary ?? ""
                    font.pixelSize: Theme.fsBody + 1
                    font.weight: Font.DemiBold
                    visible: text.length > 0
                }
                T {
                    Layout.fillWidth: true
                    text: root.n?.body ?? ""
                    visible: text.length > 0
                    textFormat: Text.StyledText
                    wrapMode: Text.Wrap
                    maximumLineCount: root.toast ? 4 : 3
                    color: Theme.textDim
                    linkColor: Theme.primary
                    onLinkActivated: l => Qt.openUrlExternally(l)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 52
            visible: root.actions.length > 0
            spacing: 6
            Repeater {
                model: root.actions
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 32
                    radius: 16
                    color: Theme.alpha(Theme.primary, 0.14)
                    T {
                        anchors.centerIn: parent
                        width: parent.width - 16
                        horizontalAlignment: Text.AlignHCenter
                        text: parent.modelData.text
                        font.weight: Font.DemiBold
                        color: Theme.primary
                    }
                    StateLayer {
                        tint: Theme.primary
                        onClicked: {
                            parent.modelData.invoke();
                            if (root.toast)
                                root.hideRequested();
                        }
                    }
                }
            }
        }
    }
}
