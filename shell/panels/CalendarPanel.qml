import QtQuick
import QtQuick.Layouts
import Quickshell
import "../core"
import "../services"
import "../widgets"

// Month calendar under the clock. Scroll or use the arrows to change month.
PanelWin {
    id: win
    name: "calendar"
    side: "center"
    cardWidth: 360
    contentHeight: col.implicitHeight + Theme.pad * 2

    readonly property date today: Notifs.now
    property int offset: 0
    readonly property date month: new Date(today.getFullYear(), today.getMonth() + offset, 1)
    readonly property int firstDow: Config.opt.weekStart === "monday" ? 1 : Config.opt.weekStart === "sunday" ? 0 : Qt.locale().firstDayOfWeek % 7
    readonly property var cells: {
        const y = month.getFullYear(), m = month.getMonth();
        const lead = (month.getDay() - firstDow + 7) % 7;
        const out = [];
        for (let i = 0; i < 42; i++) {
            const d = new Date(y, m, 1 - lead + i);
            out.push({ day: d.getDate(), inMonth: d.getMonth() === m,
                       today: d.toDateString() === today.toDateString(), weekend: d.getDay() === 0 || d.getDay() === 6 });
        }
        return out;
    }

    ColumnLayout {
        id: col
        x: Theme.pad
        y: Theme.pad
        width: parent.width - Theme.pad * 2
        spacing: 12

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            T {
                text: Qt.formatDateTime(win.today, "dddd")
                font.family: Theme.display
                font.pixelSize: Theme.fsLarge
                font.weight: Font.Medium
            }
            T {
                text: Qt.formatDateTime(win.today, "d MMMM yyyy")
                font.pixelSize: Theme.fsSmall
                color: Theme.textDim
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            T {
                Layout.fillWidth: true
                text: Qt.formatDateTime(win.month, "MMMM yyyy")
                font.weight: Font.DemiBold
                font.pixelSize: Theme.fsTitle
            }
            IconBtn {
                visible: win.offset !== 0
                icon: "today"
                size: Theme.ctlSmall
                onClicked: win.offset = 0
            }
            IconBtn {
                icon: "chevron_left"
                size: Theme.ctlSmall
                onClicked: win.offset--
            }
            IconBtn {
                icon: "chevron_right"
                size: Theme.ctlSmall
                onClicked: win.offset++
            }
        }

        // 7 equal columns: weekday letters, then 6 weeks
        Grid {
            id: grid
            Layout.fillWidth: true
            columns: 7
            readonly property real cw: width / 7
            Repeater {
                model: 7
                delegate: T {
                    required property int index
                    width: grid.cw
                    height: 28
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.locale().dayName((index + win.firstDow) % 7, Locale.NarrowFormat)
                    font.pixelSize: Theme.fsSmall
                    font.weight: Font.DemiBold
                    color: Theme.textDim
                }
            }
            Repeater {
                model: 42
                delegate: Item {
                    id: cell
                    required property int index
                    readonly property var c: win.cells[index]
                    width: grid.cw
                    height: Theme.ctl + 2
                    Rectangle {
                        anchors.centerIn: parent
                        width: Theme.ctl - 2
                        height: Theme.ctl - 2
                        radius: Theme.pill(height)
                        color: cell.c.today ? Theme.primary : "transparent"
                    }
                    T {
                        anchors.centerIn: parent
                        text: cell.c.day
                        font.features: { "tnum": 1 }
                        font.weight: cell.c.today ? Font.Bold : Font.Medium
                        color: cell.c.today ? Theme.primaryText : !cell.c.inMonth ? Theme.alpha(Theme.textDim, 0.4) : cell.c.weekend ? Theme.textDim : Theme.text
                    }
                }
            }
        }
    }
    WheelHandler {
        target: null
        onWheel: e => win.offset += e.angleDelta.y > 0 ? -1 : 1
    }
}
