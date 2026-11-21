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
        width: 600
        height: col.implicitHeight + 20
        radius: Theme.rXL
        Behavior on height { Ease { duration: Anim.normal; easing.bezierCurve: Anim.standard } }
        MouseArea { anchors.fill: parent }   // clicks on the card don't close it

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
                    Icon {
                        icon: "search"
                        size: 22
                        color: Theme.primary
                    }
                    TextInput {
                        id: input
                        Layout.fillWidth: true
                        focus: true
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 17
                        selectionColor: Theme.primary
                        selectedTextColor: Theme.primaryText
                        clip: true
                        text: win.query
                        onTextChanged: win.query = text
                        Component.onCompleted: forceActiveFocus()
                        Keys.onDownPressed: win.sel = Math.min(win.results.length - 1, win.sel + 1)
                        Keys.onUpPressed: win.sel = Math.max(0, win.sel - 1)
                        Keys.onTabPressed: win.sel = (win.sel + 1) % Math.max(1, win.results.length)
                        Keys.onReturnPressed: win.accept()
                        Keys.onEnterPressed: win.accept()
                        T {
                            visible: !input.text.length
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Search apps, or type a sum"
                            font.pixelSize: 17
                            color: Theme.textDim
                        }
                    }
                }
            }

            Rectangle {
                visible: win.calc.length > 0
                Layout.fillWidth: true
                implicitHeight: 58
                radius: 18
                color: Theme.primaryContainer
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    spacing: 12
                    Icon { icon: "calculate"; size: 22; fill: 1; color: Theme.primaryContainerText }
                    T {
                        Layout.fillWidth: true
                        text: "= " + win.calc
                        font.family: Theme.display
                        font.pixelSize: 22
                        font.weight: Font.Medium
                        color: Theme.primaryContainerText
                    }
                    T { text: "Enter to copy"; font.pixelSize: Theme.fsSmall; color: Theme.alpha(Theme.primaryContainerText, 0.7) }
                }
            }

            ListView {
                id: list
                Layout.fillWidth: true
                implicitHeight: Math.min(contentHeight, 7 * 54)
                visible: win.results.length > 0 && !win.calc.length
                clip: true
                model: win.results
                currentIndex: win.sel
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 160
                highlightFollowsCurrentItem: true
                highlight: Rectangle {
                    radius: 16
                    color: Theme.alpha(Theme.primary, 0.14)
                }
                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    width: list.width
                    height: 54
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 14
                        spacing: 14
                        AppIcon {
                            size: 34
                            name: row.modelData.icon
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            T {
                                Layout.fillWidth: true
                                text: row.modelData.name
                                font.pixelSize: Theme.fsTitle
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
                            visible: row.index === win.sel
                            icon: "keyboard_return"
                            size: 16
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
            }

            T {
                visible: !win.results.length && !win.calc.length
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 14
                Layout.bottomMargin: 14
                text: "No apps match “" + win.query + "”"
                color: Theme.textDim
            }
        }
    }
}
