import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets
import "../../ui" as SharedUi

// A felugro ertesites. Ugyanaz a lenyilo lap, mint a sav panelei: a jobb felso
// sarokban a sav aljahoz tapad, onnan csuszik le. A kepernyo szelen nincs ful.
Item {
    id: toast

    property var theme: null
    property var notification: null
    property var actions: []
    property bool shown: false
    property bool animateTransitions: true
    readonly property real reveal: frame.reveal
    readonly property var visibleActions: {
        var result = []
        for (var i = 0; i < actions.length; i++) {
            var action = actions[i]
            if (action && toast.cleanText(action.text) !== "") result.push(action)
        }
        return result
    }
    readonly property bool hasDefaultAction: {
        for (var i = 0; i < actions.length; i++) {
            if (actions[i] && actions[i].identifier === "default") return true
        }
        return false
    }
    readonly property bool critical: notification !== null && notification.urgency === NotificationUrgency.Critical
    readonly property string panelFg: theme ? theme.foreground : "#f1e7d0"
    readonly property string panelAccent: theme ? theme.accent : "#d7472f"
    readonly property string mutedFg: theme && theme.muted ? theme.muted : "#9f8f7c"
    readonly property string inkBg: theme && theme.surface ? theme.surface : "#1b1613"
    readonly property color accentColor: panelAccent

    signal activated()
    signal actionRequested(var action)
    signal dismissed()
    signal hoverChanged(bool hovered)

    function cleanText(value) {
        return (value || "").toString().replace(/<[^>]*>/g, "").replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").trim();
    }

    // A test 360 px; a bal oldali ful ehhez jon hozza.
    width: 360 + frame.cornerRadius
    height: Math.max(84, toastBody.implicitHeight + 32)
    // A lap a sav mogul csuszik le; a sajat teruletere vagjuk, kulonben az
    // ertesitesi kozpont (teljes kepernyos ablak) alatt a sav ele kerulne.
    clip: true

    SharedUi.PopupFrame {
        id: frame

        anchors.fill: parent
        theme: toast.theme
        rightEar: false
        squareRight: true
        shown: toast.shown
        animated: toast.animateTransitions

        // Kritikus ertesitesnel egy halvany akcentes tonus az egesz lapon.
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(toast.accentColor.r, toast.accentColor.g, toast.accentColor.b, 0.08)
            visible: toast.critical
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: toast.hasDefaultAction ? Qt.PointingHandCursor : Qt.ArrowCursor
            onEntered: toast.hoverChanged(true)
            onExited: toast.hoverChanged(false)
            onClicked: {
                if (toast.hasDefaultAction) toast.activated()
            }
        }

        ClippingRectangle {
            id: iconBox

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: 16
            anchors.topMargin: 16
            width: 40
            height: 40
            radius: 8
            color: toast.inkBg

            Image {
                id: notifyImage

                anchors.fill: parent
                anchors.margins: notifyImage.isPicture ? 0 : 7
                readonly property bool isPicture: toast.notification !== null && toast.notification.image !== ""
                source: toast.shown && toast.notification && toast.notification.image !== ""
                    ? toast.notification.image
                    : (toast.shown && toast.notification && toast.notification.appIcon !== ""
                        ? Quickshell.iconPath(toast.notification.appIcon, true) : "")
                sourceSize: Qt.size(96, 96)
                visible: source !== ""
                fillMode: isPicture ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                asynchronous: true
                cache: false
                smooth: true
            }

            Text {
                anchors.centerIn: parent
                text: toast.critical ? "󰀦" : "󰂚"
                color: toast.critical ? toast.panelAccent : toast.mutedFg
                font.family: "Symbols Nerd Font Mono"
                font.pixelSize: 17
                visible: notifyImage.source.toString() === ""
            }
        }

        Column {
            id: toastBody

            anchors.left: iconBox.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 44
            anchors.top: parent.top
            anchors.topMargin: 16
            spacing: 3

            Row {
                width: parent.width
                spacing: 8

                Text {
                    text: toast.notification ? toast.cleanText(toast.notification.appName || "Notification") : ""
                    textFormat: Text.PlainText
                    color: toast.mutedFg
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, parent.width - (criticalLabel.visible ? criticalLabel.width + 8 : 0))
                }

                Text {
                    id: criticalLabel
                    text: qsTr("Critical")
                    color: toast.panelAccent
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    visible: toast.critical
                }
            }

            Text {
                width: parent.width
                text: toast.notification ? toast.cleanText(toast.notification.summary) : ""
                textFormat: Text.PlainText
                color: toast.panelFg
                font.pixelSize: 13
                font.weight: Font.Medium
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Text {
                width: parent.width
                text: toast.notification ? toast.cleanText(toast.notification.body) : ""
                textFormat: Text.PlainText
                color: toast.mutedFg
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                visible: text !== ""
            }

            Flow {
                width: parent.width
                spacing: 6
                topPadding: 6
                visible: toast.visibleActions.length > 0

                Repeater {
                    model: toast.visibleActions

                    SharedUi.HeaderChip {
                        required property var modelData

                        width: Math.min(160, implicitWidth)
                        theme: toast.theme
                        label: toast.cleanText(modelData.text)
                        onClicked: toast.actionRequested(modelData)
                    }
                }
            }
        }

        Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 10
            anchors.rightMargin: 10
            width: 28
            height: 28
            radius: 6
            color: dismissMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

            Text {
                anchors.centerIn: parent
                text: "󰅖"
                color: dismissMouse.containsMouse ? toast.panelFg : toast.mutedFg
                font.family: "Symbols Nerd Font Mono"
                font.pixelSize: 13
            }

            SharedUi.Pressable {
                id: dismissMouse

                anchors.fill: parent
                theme: toast.theme
                accessibleName: qsTr("Dismiss notification")
                onClicked: toast.dismissed()
            }
        }
    }
}
