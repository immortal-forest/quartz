import QtQuick
import QtQuick.Layouts
import Quickshell
import "../core"
import "../widgets"

// Keyboard cheatsheet (Super + /). Type what you want to do ("wallpaper",
// "screenshot", "shutdown"): the shortcuts that do it stay, and matching
// settings appear above them as links into the settings window (Enter opens
// the first). Esc, a click outside or Super + / again closes it.
OverlayWin {
    id: win
    name: "help"
    dim: 0.45

    property string query: ""
    readonly property bool searching: query.trim().length > 0
    readonly property var groupsShown: Binds.groups.map(g => ({
            title: g.title,
            icon: g.icon,
            keys: searching ? g.keys.filter(k => Binds.matches([k[0], g.title, k[2] || "", k[1].join(" ")].join(" "), query)) : g.keys
        })).filter(g => g.keys.length > 0)
    // groups packed into balanced columns (each goes to the shortest column), so
    // nothing leaves a gap and the whole sheet fits without scrolling
    readonly property int ncols: card.width > 1180 ? 3 : card.width > 760 ? 2 : 1
    readonly property var columns: {
        const cols = [], h = [];
        for (let i = 0; i < ncols; i++) {
            cols.push([]);
            h.push(0);
        }
        for (const g of groupsShown) {
            let k = 0;
            for (let i = 1; i < ncols; i++)
                if (h[i] < h[k])
                    k = i;
            cols[k].push(g);
            h[k] += g.keys.length + 2;
        }
        return cols.filter(c => c.length);
    }
    readonly property var settingsShown: searching ? Binds.settings.filter(st => Binds.matches(st.label + " " + st.words + " " + st.section, query)) : []
    function openSetting(st) {
        if (st)
            Ui.openSettings(st.section);
    }

    Card {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.08)
        width: Math.min(parent.width - 96, 1320)
        height: Math.min(parent.height - y - 48, Theme.pad * 3 + head.height + Theme.spacing + field.height + body.implicitHeight)
        Behavior on height { enabled: win.settled; Ease { duration: Anim.normal } }
        MouseArea { anchors.fill: parent }

        RowLayout {
            id: head
            x: Theme.pad + 4
            y: Theme.pad
            width: parent.width - Theme.pad * 2 - 8
            height: Theme.ctl
            spacing: 12
            Icon {
                icon: "keyboard"
                size: 24
                fill: 1
                color: Theme.primary
            }
            T {
                Layout.fillWidth: true
                text: "Keyboard shortcuts"
                font.pixelSize: Theme.fsLarge
                font.weight: Font.Medium
            }
            Keycap { key: "Esc" }
            T {
                text: "Close"
                font.pixelSize: Theme.fsSmall
                color: Theme.textDim
            }
        }

        Field {
            id: field
            x: Theme.pad
            y: head.y + head.height + Theme.spacing
            width: parent.width - Theme.pad * 2
            implicitHeight: 48
            icon: "search"
            placeholder: "What do you want to do? Try wallpaper, screenshot, volume"
            fontSize: Theme.fsTitle
            onTextChanged: win.query = text
            onAccepted: win.openSetting(win.settingsShown[0])
            Component.onCompleted: input.forceActiveFocus()
        }

        Flickable {
            id: flick
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: field.bottom
            anchors.bottom: parent.bottom
            anchors.margins: Theme.pad
            contentHeight: body.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: body
                width: flick.width
                spacing: Theme.pad

                // settings that match the search: links into the settings window
                Rectangle {
                    visible: win.settingsShown.length > 0
                    Layout.fillWidth: true
                    implicitHeight: setCol.implicitHeight + Theme.padCard * 2
                    radius: Theme.rCard
                    color: Theme.card
                    ColumnLayout {
                        id: setCol
                        x: Theme.padCard
                        y: Theme.padCard
                        width: parent.width - Theme.padCard * 2
                        spacing: 2
                        RowLayout {
                            Layout.leftMargin: 4
                            Layout.bottomMargin: 6
                            spacing: 8
                            Icon { icon: "settings"; size: 18; color: Theme.primary }
                            Section { text: "Settings" }
                        }
                        Repeater {
                            model: win.settingsShown
                            delegate: Rectangle {
                                id: st
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                implicitHeight: Theme.row
                                radius: Theme.rCard
                                color: index === 0 ? Theme.alpha(Theme.primary, 0.12) : "transparent"
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: (Theme.row - Theme.ctl) / 2
                                    anchors.rightMargin: 16
                                    spacing: 12
                                    Rectangle {
                                        implicitWidth: Theme.ctl
                                        implicitHeight: Theme.ctl
                                        radius: Theme.pill(height)
                                        color: Theme.tonal
                                        Icon { anchors.centerIn: parent; icon: st.modelData.icon; color: Theme.primary }
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        T { Layout.fillWidth: true; text: st.modelData.label; font.weight: Font.Medium }
                                        T {
                                            Layout.fillWidth: true
                                            text: "Settings › " + st.modelData.section.charAt(0).toUpperCase() + st.modelData.section.slice(1)
                                            font.pixelSize: Theme.fsSmall
                                            color: Theme.textDim
                                        }
                                    }
                                    Keycap {
                                        visible: st.index === 0
                                        key: "icon:keyboard_return"
                                    }
                                    Icon { icon: "arrow_forward"; size: 18; color: Theme.primary }
                                }
                                StateLayer {
                                    tint: Theme.primary
                                    onClicked: win.openSetting(st.modelData)
                                }
                            }
                        }
                    }
                }

                // the shortcuts in balanced columns, filtered by the search
                GridLayout {
                    Layout.fillWidth: true
                    rows: 1
                    columns: Math.max(1, win.columns.length)
                    columnSpacing: Theme.pad
                    uniformCellWidths: true
                    Repeater {
                        model: win.columns
                        delegate: ColumnLayout {
                            id: column
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignTop
                            spacing: Theme.pad
                            Repeater {
                                model: column.modelData
                                delegate: Rectangle {
                                    id: grp
                                    required property var modelData
                                    Layout.fillWidth: true
                                    implicitHeight: list.implicitHeight + Theme.padCard * 2
                                    radius: Theme.rCard
                                    color: Theme.card

                                    ColumnLayout {
                                        id: list
                                        x: Theme.padCard
                                        y: Theme.padCard
                                        width: parent.width - Theme.padCard * 2
                                        spacing: 0
                                        RowLayout {
                                            Layout.fillWidth: true
                                            Layout.leftMargin: 4
                                            Layout.bottomMargin: 4
                                            implicitHeight: 28
                                            spacing: 8
                                            Icon { icon: grp.modelData.icon; size: 18; color: Theme.primary }
                                            Section { text: grp.modelData.title }
                                        }
                                        Repeater {
                                            model: grp.modelData.keys
                                            delegate: RowLayout {
                                                id: kr
                                                required property var modelData
                                                Layout.fillWidth: true
                                                Layout.leftMargin: 4
                                                implicitHeight: 34
                                                spacing: 4
                                                T {
                                                    Layout.fillWidth: true
                                                    Layout.rightMargin: 8
                                                    text: kr.modelData[0]
                                                }
                                                Repeater {
                                                    model: kr.modelData[1]
                                                    delegate: Keycap {
                                                        required property string modelData
                                                        key: modelData
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    visible: win.searching && !win.groupsShown.length && !win.settingsShown.length
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 24
                    Layout.bottomMargin: 24
                    spacing: 6
                    Icon { Layout.alignment: Qt.AlignHCenter; icon: "search_off"; size: 28; color: Theme.textDim }
                    T { Layout.alignment: Qt.AlignHCenter; text: "Nothing for “" + win.query.trim() + "”"; color: Theme.textDim }
                }
            }
        }
    }
}
