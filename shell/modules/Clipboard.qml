import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../core"
import "../widgets"

// Clipboard history (cliphist). Type to filter, Enter / click to copy,
// Delete removes an entry. Images show as thumbnails.
OverlayWin {
    id: win
    name: "clipboard"
    dim: 0.30

    property var entries: []   // [{ id, text, image }]
    property string query: ""
    property int sel: 0
    property int thumbGen: 0
    readonly property string thumbDir: Theme.cacheDir + "/clip"
    readonly property var shown: {
        const q = query.trim().toLowerCase();
        return q.length ? entries.filter(e => e.text.toLowerCase().indexOf(q) >= 0) : entries;
    }
    onQueryChanged: sel = 0

    function pick(e) {
        if (!e)
            return;
        Quickshell.execDetached(["sh", "-c", "cliphist decode \"$1\" | wl-copy", "_", e.id]);
        Ui.overlay = "";
    }
    function remove(e) {
        if (!e)
            return;
        Quickshell.execDetached(["sh", "-c", "printf '%s\\t%s\\n' \"$1\" \"$2\" | cliphist delete", "_", e.id, e.raw]);
        win.entries = win.entries.filter(x => x.id !== e.id);
    }

    Process {
        running: true
        command: ["sh", "-c", "cliphist list | head -n 400"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    const t = line.indexOf("\t");
                    if (t <= 0)
                        continue;
                    const id = line.substring(0, t), raw = line.substring(t + 1);
                    const m = raw.match(/^\[\[ binary data .* (png|jpe?g|webp|gif|bmp) (\d+)x(\d+) \]\]$/);
                    out.push({ id: id, raw: raw, image: !!m, text: m ? "Image · " + m[2] + "×" + m[3] : raw });
                }
                win.entries = out;
                thumbs.command = ["sh", "-c", "d=\"$1\"; shift; mkdir -p \"$d\"; for i in \"$@\"; do [ -s \"$d/$i.png\" ] || cliphist decode \"$i\" > \"$d/$i.png\" 2>/dev/null; done", "_", win.thumbDir]
                    .concat(out.filter(e => e.image).slice(0, 60).map(e => e.id));
                thumbs.running = true;
            }
        }
    }
    Process {
        id: thumbs
        onExited: win.thumbGen++
    }

    Card {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.14)
        width: 620
        height: col.implicitHeight + 20
        radius: Theme.rXL
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: col
            x: 10
            y: 10
            width: parent.width - 20
            spacing: 6

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 52
                radius: 22
                color: Theme.alpha(Theme.text, 0.06)
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    spacing: 12
                    Icon { icon: "content_paste"; size: 21; color: Theme.primary }
                    TextInput {
                        id: input
                        Layout.fillWidth: true
                        focus: true
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 17
                        selectionColor: Theme.primary
                        clip: true
                        onTextChanged: win.query = text
                        Component.onCompleted: forceActiveFocus()
                        Keys.onDownPressed: win.sel = Math.min(win.shown.length - 1, win.sel + 1)
                        Keys.onUpPressed: win.sel = Math.max(0, win.sel - 1)
                        Keys.onReturnPressed: win.pick(win.shown[win.sel])
                        Keys.onEnterPressed: win.pick(win.shown[win.sel])
                        Keys.onDeletePressed: e => {
                            if (!input.text.length || e.modifiers & Qt.ShiftModifier)
                                win.remove(win.shown[win.sel]);
                            else
                                e.accepted = false;
                        }
                        T {
                            visible: !input.text.length
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Search clipboard"
                            font.pixelSize: 17
                            color: Theme.textDim
                        }
                    }
                    T { text: win.shown.length + " items"; font.pixelSize: Theme.fsSmall; color: Theme.textDim }
                }
            }

            ListView {
                id: list
                Layout.fillWidth: true
                implicitHeight: Math.min(contentHeight, 480)
                clip: true
                model: win.shown
                currentIndex: win.sel
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 140
                highlight: Rectangle {
                    radius: 14
                    color: Theme.alpha(Theme.primary, 0.14)
                }
                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    width: list.width
                    height: modelData.image ? 84 : 44
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 12
                        Rectangle {
                            visible: row.modelData.image
                            Layout.preferredWidth: 110
                            Layout.preferredHeight: 70
                            radius: 10
                            color: Theme.alpha(Theme.text, 0.06)
                            clip: true
                            Image {
                                anchors.fill: parent
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: false
                                sourceSize: Qt.size(220, 140)
                                source: row.modelData.image ? "file://" + win.thumbDir + "/" + row.modelData.id + ".png?" + win.thumbGen : ""
                            }
                        }
                        T {
                            Layout.fillWidth: true
                            text: row.modelData.text.replace(/\s+/g, " ")
                            maximumLineCount: 1
                            color: row.modelData.image ? Theme.textDim : Theme.text
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        onEntered: win.sel = row.index
                        onClicked: m => m.button === Qt.MiddleButton ? win.remove(row.modelData) : win.pick(row.modelData)
                    }
                }
            }
            T {
                visible: !win.shown.length
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 14
                Layout.bottomMargin: 14
                text: win.entries.length ? "Nothing matches" : "Clipboard history is empty"
                color: Theme.textDim
            }
            T {
                Layout.alignment: Qt.AlignHCenter
                text: "Enter copy  ·  Shift+Del remove  ·  Esc close"
                font.pixelSize: Theme.fsSmall
                color: Theme.alpha(Theme.textDim, 0.7)
            }
        }
    }
}
