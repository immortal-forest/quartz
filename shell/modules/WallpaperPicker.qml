import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
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
    readonly property var matches: {
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

    // thumbnails sit half a gap inside their cells; the grid reaches out by
    // that much so the outer thumbnails line up with the header and chips
    readonly property int half: Theme.spacing / 2

    Card {
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 1180)
        height: Math.min(parent.height - 120, 760)
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.pad
            spacing: Theme.spacing

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacing
                ColumnLayout {
                    spacing: 0
                    T {
                        text: "Wallpapers"
                        font.family: Theme.display
                        font.pixelSize: Theme.fsLarge
                        font.weight: Font.Medium
                    }
                    T {
                        text: !Wallpaper.scanned ? "Looking for wallpapers…"
                            : win.matches.length === Wallpaper.files.length ? Wallpaper.files.length + " wallpapers"
                            : win.matches.length + " of " + Wallpaper.files.length
                        font.pixelSize: Theme.fsSmall
                        color: Theme.textDim
                    }
                }
                Item { Layout.fillWidth: true }
                Field {
                    Layout.preferredWidth: 280
                    implicitHeight: 48
                    icon: "search"
                    placeholder: "Search"
                    fontSize: Theme.fsTitle
                    onTextChanged: win.query = text
                    Component.onCompleted: input.forceActiveFocus()
                }
                Button {
                    Layout.preferredHeight: 48
                    icon: "shuffle"
                    text: "Surprise me"
                    onClicked: {
                        const pool = win.matches.length ? win.matches : Wallpaper.files;
                        if (!pool.length)
                            return;
                        Ui.overlay = "";
                        Wallpaper.set(pool[Math.floor(Math.random() * pool.length)]);
                    }
                }
            }

            Rectangle {
                visible: !Wallpaper.available
                Layout.fillWidth: true
                implicitHeight: 48
                radius: Theme.rCard
                color: Theme.alpha(Theme.error, 0.14)
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.padCard
                    anchors.rightMargin: Theme.padCard
                    spacing: 12
                    Icon { icon: "error"; fill: 1; color: Theme.error }
                    T {
                        Layout.fillWidth: true
                        text: "awww isn't installed, so picking a wallpaper won't change it yet. Install it with: sudo pacman -S awww"
                        color: Theme.error
                        font.weight: Font.Medium
                    }
                }
            }

            ListView {
                Layout.fillWidth: true
                implicitHeight: Theme.ctlSmall
                orientation: ListView.Horizontal
                spacing: Theme.spacing
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: [""].concat(Wallpaper.folders)
                delegate: Chip {
                    required property string modelData
                    small: true
                    text: modelData.length ? modelData : "All"
                    selected: win.folder === modelData
                    onClicked: win.folder = modelData
                }
            }

            GridView {
                id: grid
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: -win.half
                Layout.rightMargin: -win.half
                Layout.topMargin: -win.half
                Layout.bottomMargin: -win.half
                clip: true
                readonly property int cols: Math.max(2, Math.floor(width / 240))
                cellWidth: Math.floor(width / cols)
                cellHeight: Math.round(cellWidth * 0.625)
                cacheBuffer: cellHeight * 2
                boundsBehavior: Flickable.StopAtBounds
                model: win.matches
                delegate: Item {
                    id: cell
                    required property string modelData
                    readonly property bool current: modelData === Wallpaper.current
                    property bool miss: false
                    width: grid.cellWidth
                    height: grid.cellHeight
                    Connections {
                        target: Wallpaper
                        function onThumbGenChanged() { cell.miss = false; }
                    }
                    ClippingRectangle {
                        id: frame
                        anchors.fill: parent
                        anchors.margins: win.half
                        radius: Theme.rThumb
                        color: Theme.tonal
                        scale: ma.containsMouse ? 1.03 : 1
                        Behavior on scale { Spring { baseSpring: 4; baseDamping: 0.45; epsilon: 0.003 } }
                        Image {
                            anchors.fill: parent
                            source: cell.miss ? "file://" + cell.modelData : Wallpaper.thumb(cell.modelData)
                            sourceSize: Qt.size(Math.round(grid.cellWidth * 1.6), Math.round(grid.cellHeight * 1.6))
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            opacity: status === Image.Ready ? 1 : 0
                            Behavior on opacity { Ease {} }
                            onStatusChanged: if (status === Image.Error && !cell.miss) cell.miss = true
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.rThumb
                            color: "transparent"
                            border.width: cell.current ? 3 : 0
                            border.color: Theme.primary
                        }
                        Rectangle {
                            visible: cell.current
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: Theme.spacing
                            width: 28
                            height: 28
                            radius: 14
                            color: Theme.primary
                            Icon { anchors.centerIn: parent; icon: "check"; size: 18; color: Theme.primaryText }
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

            KeyHint {
                Layout.alignment: Qt.AlignHCenter
                hints: [
                    { keys: ["mouse"], label: "Set wallpaper" },
                    { keys: ["Esc"], label: "Close" }
                ]
            }
        }
    }
}
