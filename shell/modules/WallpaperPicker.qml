import QtQuick
import QtQuick.Layouts
import Quickshell
import "../core"
import "../services"
import "../widgets"

// Wallpaper picker: folders as chips, a thumbnail grid, search. Picking one
// closes the picker and awww grows the new wallpaper out from that spot.
OverlayWin {
    id: win
    name: "wallpapers"
    dim: 0.45

    property string folder: ""
    property string query: ""
    readonly property var shown: {
        const q = query.trim().toLowerCase();
        return Wallpaper.files.filter(f => (!folder.length || Wallpaper.folderOf(f) === folder)
            && (!q.length || f.toLowerCase().substring(Config.opt.wallpaperDir.length).indexOf(q) >= 0));
    }
    Component.onCompleted: if (!Wallpaper.scanned) Wallpaper.scan()

    function pick(path, item) {
        const p = item.mapToItem(null, item.width / 2, item.height / 2);
        Ui.overlay = "";
        Wallpaper.set(path, p.x / win.width, p.y / win.height);
    }

    Card {
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 1180)
        height: Math.min(parent.height - 120, 760)
        radius: Theme.rXL
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                T {
                    text: "Wallpapers"
                    font.family: Theme.display
                    font.pixelSize: 24
                    font.weight: Font.Medium
                }
                T {
                    text: win.shown.length + (Wallpaper.scanned ? "" : " …")
                    color: Theme.textDim
                    Layout.alignment: Qt.AlignBottom
                    Layout.bottomMargin: 3
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    implicitWidth: 260
                    implicitHeight: 38
                    radius: 19
                    color: Theme.alpha(Theme.text, 0.06)
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 8
                        Icon { icon: "search"; size: 18; color: Theme.textDim }
                        TextInput {
                            id: input
                            Layout.fillWidth: true
                            focus: true
                            color: Theme.text
                            font.family: Theme.font
                            font.pixelSize: Theme.fsBody
                            clip: true
                            onTextChanged: win.query = text
                            Component.onCompleted: forceActiveFocus()
                            T {
                                visible: !input.text.length
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Search"
                                color: Theme.textDim
                            }
                        }
                    }
                }
                Rectangle {
                    implicitWidth: rl.implicitWidth + 28
                    implicitHeight: 38
                    radius: 19
                    color: Theme.primary
                    RowLayout {
                        id: rl
                        anchors.centerIn: parent
                        spacing: 6
                        Icon { icon: "shuffle"; size: 18; color: Theme.primaryText }
                        T { text: "Surprise me"; font.weight: Font.DemiBold; color: Theme.primaryText }
                    }
                    StateLayer {
                        tint: Theme.primaryText
                        onClicked: {
                            const pool = win.shown.length ? win.shown : Wallpaper.files;
                            if (!pool.length)
                                return;
                            Ui.overlay = "";
                            Wallpaper.set(pool[Math.floor(Math.random() * pool.length)]);
                        }
                    }
                }
            }

            Rectangle {
                visible: !Wallpaper.available
                Layout.fillWidth: true
                implicitHeight: 44
                radius: 14
                color: Theme.errorContainer
                T {
                    anchors.centerIn: parent
                    text: "awww isn't installed, so wallpapers can't be changed yet — run: sudo pacman -S awww"
                    color: Theme.errorContainerText
                    font.weight: Font.Medium
                }
            }

            ListView {
                Layout.fillWidth: true
                implicitHeight: 34
                orientation: ListView.Horizontal
                spacing: 6
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: [""].concat(Wallpaper.folders)
                delegate: Rectangle {
                    required property string modelData
                    readonly property bool on: win.folder === modelData
                    implicitWidth: lbl.implicitWidth + 26
                    height: 34
                    radius: 17
                    color: on ? Theme.secondaryContainer : Theme.alpha(Theme.text, 0.06)
                    Behavior on color { CAnim {} }
                    T {
                        id: lbl
                        anchors.centerIn: parent
                        text: parent.modelData.length ? parent.modelData : "All"
                        font.weight: parent.on ? Font.DemiBold : Font.Normal
                        color: parent.on ? Theme.secondaryContainerText : Theme.textDim
                    }
                    StateLayer { onClicked: win.folder = parent.modelData }
                }
            }

            GridView {
                id: grid
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                readonly property int cols: Math.max(2, Math.floor(width / 230))
                cellWidth: Math.floor(width / cols)
                cellHeight: Math.round(cellWidth * 0.625)
                cacheBuffer: cellHeight * 2
                boundsBehavior: Flickable.StopAtBounds
                model: win.shown
                delegate: Item {
                    id: cell
                    required property string modelData
                    readonly property bool current: modelData === Wallpaper.current
                    width: grid.cellWidth
                    height: grid.cellHeight
                    Rectangle {
                        id: frame
                        anchors.fill: parent
                        anchors.margins: 5
                        radius: 14
                        color: Theme.alpha(Theme.text, 0.06)
                        clip: true
                        scale: ma.containsMouse ? 1.03 : 1
                        Behavior on scale { Spring { spring: 4; damping: 0.45; epsilon: 0.003 } }
                        Image {
                            anchors.fill: parent
                            source: "file://" + cell.modelData
                            sourceSize: Qt.size(Math.round(grid.cellWidth * 1.6), Math.round(grid.cellHeight * 1.6))
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            opacity: status === Image.Ready ? 1 : 0
                            Behavior on opacity { Ease {} }
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: 14
                            color: "transparent"
                            border.width: cell.current ? 3 : 0
                            border.color: Theme.primary
                        }
                        Rectangle {
                            visible: cell.current
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 8
                            width: 26
                            height: 26
                            radius: 13
                            color: Theme.primary
                            Icon { anchors.centerIn: parent; icon: "check"; size: 17; color: Theme.primaryText }
                        }
                    }
                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.pick(cell.modelData, cell)
                    }
                }
            }
        }
    }
}
