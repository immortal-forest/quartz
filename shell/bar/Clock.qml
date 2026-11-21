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

    implicitWidth: row.implicitWidth + Theme.padCard * 2
    implicitHeight: Theme.barItem
    radius: Theme.rBarItem
    color: open ? Theme.alpha(Theme.primary, 0.16) : "transparent"
    Behavior on color { CAnim {} }

    SystemClock {
        id: clock
        precision: Config.opt.clockSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Theme.spacing
        T {
            text: Qt.formatDateTime(clock.date, Config.opt.use24h ? (Config.opt.clockSeconds ? "HH:mm:ss" : "HH:mm") : (Config.opt.clockSeconds ? "h:mm:ss AP" : "h:mm AP"))
            font.pixelSize: Theme.fsTitle
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }
        Rectangle {
            visible: Config.opt.barDate
            implicitWidth: 4
            implicitHeight: 4
            radius: 2
            color: Theme.outline
        }
        T {
            visible: Config.opt.barDate
            text: Qt.formatDateTime(clock.date, "ddd d MMM")
            color: Theme.textDim
            font.weight: Font.Medium
        }
    }
    StateLayer {
        onClicked: Ui.togglePanel("calendar", root.screenName)
    }
}
