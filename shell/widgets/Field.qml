import QtQuick
import QtQuick.Layouts
import "../core"

// Pill text field: a leading icon, the input, a placeholder, optional trailing
// text. Overlays use the tall size (48), inline forms Theme.ctl.
Rectangle {
    id: root
    property string icon: ""
    property string placeholder: ""
    property string trailing: ""
    property bool password: false
    property int fontSize: Theme.fsBody
    property alias input: input
    property alias text: input.text
    signal accepted
    signal navigate(int step)          // ↓ / Tab = +1, ↑ = -1
    signal deletePressed(var event)    // set event.accepted to swallow it

    implicitHeight: Theme.ctl
    radius: Theme.pill(height)
    color: Theme.tonal
    border.width: input.activeFocus && root.password ? 2 : 0
    border.color: Theme.primary

    // rowAligned: icon + text line up with the list rows under the field
    // (their 40 px leading element sits (row - ctl) / 2 in, text 12 px after it)
    property bool rowAligned: false

    RowLayout {
        anchors.fill: parent
        readonly property real iconSize: root.height >= 48 ? 22 : Theme.icon
        // no slot: the icon's centre = the rounded end's centre; the trailing text
        // then sits as far in as the icon's ink
        anchors.leftMargin: root.rowAligned ? (Theme.row - Theme.ctl) / 2 : root.icon.length ? Math.round((root.height - iconSize) / 2) : 16
        anchors.rightMargin: root.icon.length ? Math.round((root.height - iconSize) / 2 + 2) : 16
        spacing: root.rowAligned ? 12 : 10
        Item {
            visible: root.icon.length > 0
            implicitWidth: root.rowAligned ? Theme.ctl : ic.implicitWidth
            implicitHeight: ic.implicitHeight
            Icon {
                id: ic
                anchors.centerIn: parent
                icon: root.icon
                size: root.height >= 48 ? 22 : Theme.icon
                color: input.activeFocus ? Theme.primary : Theme.textDim
            }
        }
        TextInput {
            id: input
            Layout.fillWidth: true
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: root.fontSize
            selectionColor: Theme.primary
            selectedTextColor: Theme.primaryText
            echoMode: root.password ? TextInput.Password : TextInput.Normal
            clip: true
            Keys.onDownPressed: root.navigate(1)
            Keys.onUpPressed: root.navigate(-1)
            Keys.onTabPressed: root.navigate(1)
            Keys.onReturnPressed: root.accepted()
            Keys.onEnterPressed: root.accepted()
            Keys.onDeletePressed: e => {
                e.accepted = false;
                root.deletePressed(e);
            }
            T {
                visible: !input.text.length
                anchors.verticalCenter: parent.verticalCenter
                text: root.placeholder
                font.pixelSize: root.fontSize
                color: Theme.textDim
            }
        }
        T {
            visible: root.trailing.length > 0
            text: root.trailing
            font.pixelSize: Theme.fsSmall
            color: Theme.textDim
        }
    }
    MouseArea {
        anchors.fill: parent
        z: -1
        cursorShape: Qt.IBeamCursor
        onClicked: input.forceActiveFocus()
    }
}
