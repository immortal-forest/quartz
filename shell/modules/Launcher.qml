import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Hyprland
import "../core"
import "../services"
import "../widgets"

// App launcher: type to search (name, generic name, keywords, fuzzy), arrows
// + Enter to launch, maths gives a result you can copy. Apps you launch often
// rise to the top. Apps start through Hyprland (its environment, own scope).
OverlayWin {
    id: win
    name: "launcher"
    dim: 0.30

    property string query: ""
    property int sel: 0
    readonly property var apps: DesktopEntries.applications.values.filter(e => !e.noDisplay)
    readonly property var launches: Config.opt.launches || {}

    function score(e, q) {
        const n = (e.name || "").toLowerCase();
        let s = 0;
        if (n === q) s = 120;
        else if (n.startsWith(q)) s = 100;
        else if (n.split(/[\s\-_.]+/).some(w => w.startsWith(q))) s = 85;
        else if (n.indexOf(q) >= 0) s = 65;
        else if ((e.genericName || "").toLowerCase().indexOf(q) >= 0) s = 45;
        else if ((e.keywords || []).some(k => k.toLowerCase().startsWith(q))) s = 40;
        else if ((e.comment || "").toLowerCase().indexOf(q) >= 0) s = 20;
        else {
            let i = 0;
            for (const ch of n) if (ch === q[i]) i++;
            if (i === q.length) s = 12;
        }
        return s ? s + Math.min(15, (win.launches[e.id] || 0)) : 0;
    }
    readonly property var results: {
        const q = query.trim().toLowerCase();
        if (!q.length)
            return apps.slice().sort((a, b) => ((win.launches[b.id] || 0) - (win.launches[a.id] || 0)) || a.name.localeCompare(b.name)).slice(0, 40);
        return apps.map(e => ({ e: e, s: score(e, q) })).filter(x => x.s > 0).sort((a, b) => b.s - a.s || a.e.name.localeCompare(b.e.name)).slice(0, 40).map(x => x.e);
    }
    readonly property string calc: {
        const q = query.trim();
        if (!/^[\d\s+\-*/().,%^]+$/.test(q) || !/[+\-*/%^]/.test(q) || !/\d/.test(q))
            return "";
        try {
            const v = Function("return (" + q.replace(/\^/g, "**").replace(/,/g, ".") + ")")();
            return (typeof v === "number" && isFinite(v)) ? String(Math.round(v * 1e10) / 1e10) : "";
        } catch (e) {
            return "";
        }
    }
    onQueryChanged: sel = 0

    function shq(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'"; }
    function launch(e) {
        if (!e)
            return;
        Config.bumpLaunch(e.id);
        let cmd = e.command.map(shq).join(" ");
        if (e.runInTerminal)
            cmd = (Config.opt.terminal || Quickshell.env("TERMINAL") || "kitty") + " -e " + cmd;
        if (e.workingDirectory)
            cmd = "cd " + shq(e.workingDirectory) + " && " + cmd;
        const full = "systemd-run --user --scope --slice=app.slice --collect -q -- sh -c " + shq(cmd);
        Hypr.exec(full);
        Ui.overlay = "";
    }
    function accept() {
        if (calc.length) {
            Quickshell.execDetached(["wl-copy", "--", calc]);
            Ui.overlay = "";
        } else {
            launch(results[sel]);
        }
    }

    Card {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.16)
        width: 640
        height: col.implicitHeight + Theme.padCard * 2
        Behavior on height { enabled: win.settled; Ease { duration: Anim.normal; easing.bezierCurve: Anim.standard } }
        MouseArea { anchors.fill: parent }   // clicks on the card don't close it

        ColumnLayout {
            id: col
            x: Theme.padCard
            y: Theme.padCard
            width: parent.width - Theme.padCard * 2
            spacing: Theme.spacing

            Field {
                rowAligned: true
                id: field
                Layout.fillWidth: true
                implicitHeight: 48
                icon: "search"
                placeholder: "Search apps, or type a sum"
                fontSize: Theme.fsTitle
                text: win.query
                onTextChanged: win.query = text
                Component.onCompleted: input.forceActiveFocus()
                onNavigate: step => win.sel = step > 0 ? (win.sel + 1) % Math.max(1, win.results.length) : Math.max(0, win.sel - 1)
                onAccepted: win.accept()
            }

            // maths: a list row, already selected — Enter copies the result
            Rectangle {
                visible: win.calc.length > 0
                Layout.fillWidth: true
                implicitHeight: Theme.row
                radius: Theme.rCard
                color: Theme.alpha(Theme.primary, 0.16)
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: (Theme.row - Theme.ctl) / 2
                    anchors.rightMargin: (Theme.row - Theme.ctl) / 2
                    spacing: 12
                    Rectangle {
                        implicitWidth: Theme.ctl
                        implicitHeight: Theme.ctl
                        radius: Theme.rThumb
                        color: Theme.alpha(Theme.primary, 0.16)
                        Icon { anchors.fill: parent; icon: "calculate"; fill: 1; color: Theme.primary }
                    }
                    T {
                        Layout.fillWidth: true
                        text: "= " + win.calc
                        font.family: Theme.display
                        font.pixelSize: Theme.fsLarge
                        font.weight: Font.Medium
                        color: Theme.primary
                    }
                    Icon {
                        Layout.preferredWidth: Theme.ctl
                        icon: "keyboard_return"
                        color: Theme.primary
                    }
                }
            }

            ListView {
                id: list
                Layout.fillWidth: true
                implicitHeight: Math.min(contentHeight, 7 * Theme.row)
                visible: win.results.length > 0 && !win.calc.length
                clip: true
                model: win.results
                currentIndex: win.sel
                boundsBehavior: Flickable.StopAtBounds
                // an edge fades only while the selected row isn't flush against it
                readonly property real curTop: currentItem ? currentItem.y - contentY : 0
                readonly property real curBottom: currentItem ? currentItem.y + currentItem.height - contentY : 0
                highlightMoveDuration: Anim.fast
                highlightFollowsCurrentItem: true
                highlight: Rectangle {
                    radius: Theme.rCard
                    color: Theme.alpha(Theme.primary, 0.16)
                }
                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    width: list.width
                    height: Theme.row
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: (Theme.row - Theme.ctl) / 2
                        anchors.rightMargin: (Theme.row - Theme.ctl) / 2
                        spacing: 12
                        AppIcon {
                            size: Theme.ctl
                            name: row.modelData.icon
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            T {
                                Layout.fillWidth: true
                                text: row.modelData.name
                                font.weight: row.index === win.sel ? Font.DemiBold : Font.Medium
                            }
                            T {
                                Layout.fillWidth: true
                                visible: text.length > 0
                                text: row.modelData.comment || row.modelData.genericName || ""
                                font.pixelSize: Theme.fsSmall
                                color: Theme.textDim
                            }
                        }
                        Icon {
                            Layout.preferredWidth: Theme.ctl
                            opacity: row.index === win.sel ? 1 : 0
                            icon: "keyboard_return"
                            color: Theme.primary
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: win.sel = row.index
                        onClicked: win.launch(row.modelData)
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
                visible: !win.results.length && !win.calc.length
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Theme.pad
                Layout.bottomMargin: Theme.pad
                text: "No apps match “" + win.query + "”"
                color: Theme.textDim
            }
            KeyHint {
                Layout.alignment: Qt.AlignHCenter
                hints: win.calc.length
                    ? [{ keys: ["keyboard_return"], label: "Copy" }, { keys: ["Esc"], label: "Close" }]
                    : [{ keys: ["keyboard_arrow_up", "keyboard_arrow_down"], label: "Select" }, { keys: ["keyboard_return"], label: "Open" }, { keys: ["Esc"], label: "Close" }]
            }
        }
    }
}
