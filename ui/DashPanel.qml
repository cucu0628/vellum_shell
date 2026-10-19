import QtQuick

// Egy csendes, keret nelkuli szekcio a dashboardon: halvany felulet, egy
// visszafogott cim, es semmi mas -- a tartalom adja a hangsulyt.
Rectangle {
    id: panel

    property var theme: null
    property string title: ""
    property string trailing: ""
    property real contentSpacing: 10
    // Kattinthato kartya: hoverre kicsit kivilagosodik, a fejlecben egy
    // "kinagyit" jel jelenik meg, kattintasra `clicked`. A tartalom sajat
    // vezerloi (pl. honapvalto nyilak) tovabbra is elsobbseget kapnak.
    property bool clickable: false
    // Kinagyitott nezet: a fejlec jobb szelen bezaro gomb.
    property bool closable: false
    default property alias content: body.data

    signal clicked()
    signal closeRequested()

    readonly property string background: theme ? theme.background : "#11130f"
    readonly property string foreground: theme ? theme.foreground : "#e8ddc7"
    readonly property string accent: theme ? theme.accent : "#b7372f"
    readonly property string surface: theme && theme.surface ? theme.surface : "#191b16"
    readonly property string muted: theme && theme.muted ? theme.muted : "#958b7a"
    readonly property real bodyHeight: body.height

    // Ugyanaz a kerekites, mint a dashboard lejatszosavjan.
    radius: 10
    color: clickable && cardMouse.containsMouse ? Qt.lighter(surface, 1.12) : surface
    clip: true

    Behavior on color { ColorAnimation { duration: 120; easing.type: Easing.OutCubic } }

    // A tartalom alatt: csak oda kattintva hat, ahol a tartalom nem vezerlo.
    MouseArea {
        id: cardMouse

        anchors.fill: parent
        enabled: panel.clickable
        hoverEnabled: true
        cursorShape: panel.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: panel.clicked()
    }

    Item {
        id: head

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 12
        height: 16
        visible: panel.title !== "" || panel.trailing !== "" || panel.closable

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: panel.title
            color: panel.muted
            font.pixelSize: 10
            font.letterSpacing: 1
            font.weight: Font.DemiBold
        }

        Text {
            anchors.right: headAction.visible ? headAction.left : parent.right
            anchors.rightMargin: headAction.visible ? 8 : 0
            anchors.verticalCenter: parent.verticalCenter
            text: panel.trailing
            color: panel.muted
            font.pixelSize: 10
            visible: panel.trailing !== ""
        }

        // Kinagyitas jele (hoverre) vagy a bezaro gomb.
        Rectangle {
            id: headAction

            anchors.right: parent.right
            anchors.rightMargin: -6
            anchors.verticalCenter: parent.verticalCenter
            width: 28
            height: 28
            radius: 6
            visible: panel.closable || panel.clickable
            opacity: panel.closable || cardMouse.containsMouse ? 1 : 0
            color: panel.closable && closeMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

            Behavior on opacity { NumberAnimation { duration: 120 } }

            Text {
                anchors.centerIn: parent
                text: panel.closable ? "󰅖" : "󰁌"
                color: panel.closable && closeMouse.containsMouse ? panel.foreground : panel.muted
                font.family: "Symbols Nerd Font Mono"
                font.pixelSize: 13
            }

            Pressable {
                id: closeMouse

                anchors.fill: parent
                enabled: panel.closable
                theme: panel.theme
                accessibleName: qsTr("Close details")
                onClicked: panel.closeRequested()
            }
        }
    }

    Item {
        id: body

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: head.bottom
        anchors.bottom: parent.bottom
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: panel.contentSpacing
        anchors.bottomMargin: 12
    }
}
