import QtQuick

// Kozos kattinthato felulet a sajat rajzolasu vezerlokhoz. Egy helyen adja a
// pointer-, billentyuzet-, fokusz- es akadalymentessegi viselkedest.
Item {
    id: pressable

    property var theme: null
    property string accessibleName: ""
    property string accessibleDescription: ""
    property int accessibleRole: Accessible.Button
    property int acceptedButtons: Qt.LeftButton
    readonly property alias containsMouse: pointer.containsMouse

    signal clicked(var event)
    signal wheel(var event)

    function activate() {
        if (enabled)
            clicked({ "button": Qt.LeftButton });
    }

    activeFocusOnTab: enabled && visible
    Keys.onSpacePressed: (event) => { activate(); event.accepted = true; }
    Keys.onReturnPressed: (event) => { activate(); event.accepted = true; }
    Keys.onEnterPressed: (event) => { activate(); event.accepted = true; }

    Accessible.role: accessibleRole
    Accessible.name: accessibleName
    Accessible.description: accessibleDescription
    Accessible.onPressAction: activate()

    MouseArea {
        id: pointer

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: pressable.acceptedButtons
        cursorShape: Qt.PointingHandCursor
        onClicked: event => pressable.clicked(event)
        onWheel: event => pressable.wheel(event)
    }

    FocusRing {
        z: 1
        theme: pressable.theme
        active: pressable.activeFocus
    }
}
