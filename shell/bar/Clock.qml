import QtQuick
import QtQuick.Layouts
import Quickshell
import "../core"
import "../widgets"

// Time + date; opens the calendar.
Rectangle {
    id: root
    property string screenName: ""
    readonly property bool open: Ui.panel === "calendar" && Ui.screen === screenName
    readonly property var kanji: ["日", "月", "火", "水", "木", "金", "土"]

    implicitWidth: row.implicitWidth + 24
    implicitHeight: 28
    radius: 9
    color: open ? Theme.alpha(Theme.primary, 0.16) : "transparent"
    Behavior on color { CAnim {} }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 9
        T {
            text: Qt.formatDateTime(clock.date, Config.opt.use24h ? "HH:mm" : "h:mm AP")
            font.pixelSize: Theme.fsTitle
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }
        Rectangle {
            implicitWidth: 3
            implicitHeight: 3
            radius: 2
            color: Theme.outline
        }
        T {
            text: Qt.formatDateTime(clock.date, "ddd d MMM")
            color: Theme.textDim
            font.weight: Font.Medium
        }
        T {
            visible: Config.opt.japanese
            text: root.kanji[clock.date.getDay()]
            color: Theme.primary
            font.weight: Font.Medium
        }
    }
    StateLayer {
        onClicked: Ui.togglePanel("calendar", root.screenName)
    }
}
