import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../core"
import "../widgets"

// Clipboard history (cliphist). Type to filter, Enter / click to copy,
// Delete removes an entry. Images show as thumbnails.
OverlayWin {
    id: win
    name: "clipboard"
    dim: 0.30

    property var entries: []   // [{ id, raw, text, image, size, fmt }]
    property string query: ""
    property int sel: 0
    property int thumbGen: 0
    readonly property string thumbDir: Theme.cacheDir + "/clip"
    readonly property var matches: {
        const q = query.trim().toLowerCase();
        return q.length ? entries.filter(e => e.text.toLowerCase().indexOf(q) >= 0) : entries;
    }
    onQueryChanged: sel = 0

    // rows: text = Theme.row with a 40 px glyph; image = a fixed thumbnail box
    // (whole capture letterboxed), same vertical inset. Both rows give the
    // leading slot the thumbnail's width so the text column starts at one x.
    readonly property int inset: (Theme.row - Theme.ctl) / 2
    readonly property int thumbW: 96
    readonly property int thumbH: 64
    readonly property int imageRow: thumbH + inset * 2
    // the list shows whole rows only (up to 7 text rows' worth)
    readonly property int listH: {
        let h = 0;
        for (const e of matches) {
            const r = e.image ? imageRow : Theme.row;
            if (h + r > 7 * Theme.row)
                break;
            h += r;
        }
        return h;
    }

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
                    out.push(m ? { id: id, raw: raw, image: true, text: "Image " + m[1], size: m[2] + " × " + m[3], fmt: m[1].replace("jpg", "jpeg").toUpperCase() }
                               : { id: id, raw: raw, image: false, text: raw });
                }
                win.entries = out;
                // small JPEG thumbnails for the first 60 images; thumbnails of
                // entries no longer in the history (and old full-size PNGs) go
                thumbs.command = ["sh", "-c",
                    "d=\"${1:?}\"; shift; mkdir -p \"$d\"; rm -f -- \"${d:?}\"/*.png; keep=\" $* \"; " +
                    "for f in \"${d:?}\"/*.jpg; do [ -e \"$f\" ] || continue; b=${f##*/}; b=${b%.jpg}; case \"$keep\" in *\" $b \"*) ;; *) rm -f -- \"$f\";; esac; done; " +
                    "n=0; for i in \"$@\"; do n=$((n+1)); [ $n -gt 60 ] && break; [ -s \"$d/$i.jpg\" ] && continue; " +
                    "cliphist decode \"$i\" 2>/dev/null | nice -n 19 ffmpeg -loglevel quiet -nostdin -y -f image2pipe -i - -vf scale=232:-2 -frames:v 1 -q:v 4 \"$d/$i.jpg\"; done",
                    "_", win.thumbDir].concat(out.filter(e => e.image).map(e => e.id));
                thumbs.running = true;
            }
        }
    }
    Process {
        id: thumbs
        onExited: win.thumbGen++
    }

    Card {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.16)
        width: 640
        height: col.implicitHeight + Theme.padCard * 2
        Behavior on height { enabled: win.settled; Ease { duration: Anim.normal; easing.bezierCurve: Anim.standard } }
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: col
            x: Theme.padCard
            y: Theme.padCard
            width: parent.width - Theme.padCard * 2
            spacing: Theme.spacing

            Field {
                rowAligned: true
                Layout.fillWidth: true
                implicitHeight: 48
                icon: "content_paste"
                placeholder: "Search clipboard"
                fontSize: Theme.fsTitle
                trailing: win.matches.length + " items"
                onTextChanged: win.query = text
                Component.onCompleted: input.forceActiveFocus()
                onNavigate: step => win.sel = Math.max(0, Math.min(win.matches.length - 1, win.sel + step))
                onAccepted: win.pick(win.matches[win.sel])
                onDeletePressed: e => {
                    if (!text.length || e.modifiers & Qt.ShiftModifier) {
                        win.remove(win.matches[win.sel]);
                        e.accepted = true;
                    }
                }
            }

            ListView {
                id: list
                Layout.fillWidth: true
                implicitHeight: win.listH
                visible: win.matches.length > 0
                clip: true
                model: win.matches
                currentIndex: win.sel
                boundsBehavior: Flickable.StopAtBounds
                // an edge fades only while the selected row isn't flush against it
                readonly property real curTop: currentItem ? currentItem.y - contentY : 0
                readonly property real curBottom: currentItem ? currentItem.y + currentItem.height - contentY : 0
                highlightMoveDuration: Anim.fast
                highlightResizeDuration: Anim.fast
                highlight: Rectangle {
                    radius: Theme.rCard
                    color: Theme.alpha(Theme.primary, 0.16)
                }
                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool image: modelData.image
                    readonly property bool on: index === win.sel
                    width: list.width
                    height: image ? win.imageRow : Theme.row
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: win.inset
                        anchors.rightMargin: win.inset
                        spacing: 12
                        Item {
                            implicitWidth: win.thumbW
                            implicitHeight: row.image ? win.thumbH : Theme.ctl
                            ClippingRectangle {
                                visible: row.image
                                anchors.fill: parent
                                radius: Theme.rThumb
                                color: Theme.tonal
                                Image {
                                    anchors.fill: parent
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    cache: false
                                    sourceSize: Qt.size(win.thumbW * 2, win.thumbH * 2)
                                    source: row.image && win.thumbGen > 0 ? "file://" + win.thumbDir + "/" + row.modelData.id + ".jpg?" + win.thumbGen : ""
                                }
                            }
                            Rectangle {
                                visible: !row.image
                                anchors.centerIn: parent
                                width: Theme.ctl
                                height: Theme.ctl
                                radius: Theme.ctl / 2
                                color: row.on ? Theme.alpha(Theme.primary, 0.16) : Theme.tonal
                                Icon {
                                    anchors.fill: parent
                                    icon: row.image ? "" : /^\s*(https?|ftp|file):\/\/\S+\s*$/.test(row.modelData.raw) ? "link" : "notes"
                                    color: row.on ? Theme.primary : Theme.textDim
                                }
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            T {
                                Layout.fillWidth: true
                                text: row.image ? "Image" : row.modelData.text.replace(/\s+/g, " ").trim()
                                maximumLineCount: 1
                                font.weight: row.on ? Font.DemiBold : Font.Medium
                            }
                            T {
                                Layout.fillWidth: true
                                visible: row.image
                                text: row.image ? row.modelData.size + "  ·  " + row.modelData.fmt : ""
                                font.pixelSize: Theme.fsSmall
                                color: Theme.textDim
                            }
                        }
                        Icon {
                            Layout.preferredWidth: Theme.ctl
                            opacity: row.on ? 1 : 0
                            icon: "keyboard_return"
                            color: Theme.primary
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
                // soft edges where rows scroll out of view
                Rectangle {
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    height: Theme.padCard * 2
                    opacity: !list.atYBeginning && list.curTop > 0.5 ? 1 : 0
                    Behavior on opacity { Ease { duration: Anim.fast } }
                    gradient: Gradient {
                        GradientStop { position: 0; color: card.color }
                        GradientStop { position: 1; color: Theme.alpha(card.color, 0) }
                    }
                }
                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: Theme.padCard * 2
                    opacity: !list.atYEnd && list.curBottom < list.height - 0.5 ? 1 : 0
                    Behavior on opacity { Ease { duration: Anim.fast } }
                    gradient: Gradient {
                        GradientStop { position: 0; color: Theme.alpha(card.color, 0) }
                        GradientStop { position: 1; color: card.color }
                    }
                }
            }
            T {
                visible: !win.matches.length
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Theme.pad
                Layout.bottomMargin: Theme.pad
                text: win.entries.length ? "Nothing matches" : "Clipboard history is empty"
                color: Theme.textDim
            }
            KeyHint {
                Layout.alignment: Qt.AlignHCenter
                hints: [
                    { keys: ["keyboard_arrow_up", "keyboard_arrow_down"], label: "Select" },
                    { keys: ["keyboard_return"], label: "Copy" },
                    { keys: ["Shift", "Del"], label: "Remove" },
                    { keys: ["Esc"], label: "Close" }
                ]
            }
        }
    }
}
