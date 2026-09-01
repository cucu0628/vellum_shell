import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Item {
    id: toast

    property var theme: null
    property var notification: null
    property var actions: []
    property bool shown: false
    property bool animateTransitions: true
    readonly property bool hasDefaultAction: {
        for (var i = 0; i < actions.length; i++) {
            if (actions[i] && actions[i].identifier === "default") return true
        }
        return false
    }
    readonly property string panelBg: theme ? theme.background : "#15110f"
    readonly property string panelFg: theme ? theme.foreground : "#f1e7d0"
    readonly property string panelAccent: theme ? theme.accent : "#d7472f"
    readonly property string mutedFg: theme && theme.muted ? theme.muted : "#9f8f7c"
    readonly property string inkBg: theme && theme.surface ? theme.surface : "#1b1613"

    signal activated()
    signal actionRequested(var action)
    signal dismissed()
    signal hoverChanged(bool hovered)

    function cleanText(value) {
        return (value || "").toString().replace(/<[^>]*>/g, "").replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").trim();
    }

    width: 360
    height: shown ? Math.max(94, toastBody.implicitHeight + 28) : 0
    opacity: shown ? 1 : 0
    clip: true

    Rectangle {
        anchors.fill: parent
        color: toast.panelBg
        border.color: toast.panelAccent
        border.width: 1
        radius: 0

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 3
            color: toast.panelAccent
            opacity: toast.notification && toast.notification.urgency === NotificationUrgency.Low ? 0.45 : 1
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

        Row {
            anchors.fill: parent
            anchors.margins: 14
            anchors.leftMargin: 18
            spacing: 12

            Rectangle {
                width: 42
                height: 42
                anchors.verticalCenter: parent.verticalCenter
                color: toast.inkBg
                border.color: toast.mutedFg
                border.width: 1
                radius: 0
                clip: true

                Image {
                    id: notifyImage

                    anchors.fill: parent
                    anchors.margins: 7
                    source: toast.shown && toast.notification && toast.notification.image !== "" ? toast.notification.image : (toast.shown && toast.notification && toast.notification.appIcon !== "" ? Quickshell.iconPath(toast.notification.appIcon, true) : "")
                    sourceSize: Qt.size(96, 96)
                    visible: source !== ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: false
                    smooth: true
                }

                Text {
                    anchors.centerIn: parent
                    text: toast.notification && toast.notification.urgency === NotificationUrgency.Critical ? "󰀦" : "󰂚"
                    color: toast.panelAccent
                    font.pixelSize: 17
                    visible: notifyImage.source === ""
                }

            }

            Column {
                id: toastBody

                width: parent.width - 54
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5

                Row {
                    width: parent.width
                    height: 14
                    spacing: 8

                    Text {
                        text: toast.notification ? toast.cleanText(toast.notification.appName || "Notification").toUpperCase() : "NOTIFICATION"
                        color: toast.panelAccent
                        font.pixelSize: 9
                        font.letterSpacing: 3
                        font.bold: true
                        elide: Text.ElideRight
                        width: parent.width - 140
                    }

                    Text {
                        text: toast.notification && toast.notification.urgency === NotificationUrgency.Critical ? "CRITICAL" : ""
                        color: toast.panelAccent
                        font.pixelSize: 9
                        font.bold: true
                        horizontalAlignment: Text.AlignRight
                        width: 62
                    }

                    Item {
                        width: 62
                        height: 1
                    }

                }

                Text {
                    width: parent.width
                    text: toast.notification ? toast.cleanText(toast.notification.summary) : ""
                    color: toast.panelFg
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Text {
                    width: parent.width
                    text: toast.notification ? toast.cleanText(toast.notification.body) : ""
                    color: toast.mutedFg
                    opacity: 1
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    visible: text !== ""
                }

                Flow {
                    width: parent.width
                    spacing: 5
                    visible: toast.actions.length > 0

                    Repeater {
                        model: toast.actions

                        Rectangle {
                            property var action: modelData

                            width: Math.min(148, Math.max(58, actionText.implicitWidth + 18))
                            height: 23
                            color: actionMouse.containsMouse ? toast.panelAccent : toast.inkBg
                            border.color: toast.panelAccent
                            border.width: 1

                            Text {
                                id: actionText

                                anchors.centerIn: parent
                                width: parent.width - 12
                                text: parent.action && parent.action.text !== "" ? parent.action.text.toUpperCase() : (parent.action && parent.action.identifier === "default" ? "OPEN" : "ACTION")
                                color: actionMouse.containsMouse ? toast.panelBg : toast.panelAccent
                                font.pixelSize: 8
                                font.bold: true
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                            }

                            MouseArea {
                                id: actionMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: toast.hoverChanged(true)
                                onExited: toast.hoverChanged(false)
                                onClicked: mouse => {
                                    mouse.accepted = true
                                    toast.actionRequested(parent.action)
                                }
                            }
                        }
                    }
                }

            }

        }

        Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 9
            width: 58
            height: 21
            color: dismissMouse.containsMouse ? toast.panelAccent : toast.inkBg
            border.color: toast.panelAccent
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "DISMISS"
                color: dismissMouse.containsMouse ? toast.panelBg : toast.panelAccent
                font.pixelSize: 8
                font.bold: true
                font.letterSpacing: 1
            }

            MouseArea {
                id: dismissMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: toast.dismissed()
            }

        }

    }

    Behavior on height {
        enabled: toast.animateTransitions

        NumberAnimation {
            duration: 210
            easing.type: Easing.OutCubic
        }

    }

    Behavior on opacity {
        enabled: toast.animateTransitions

        NumberAnimation {
            duration: 160
            easing.type: Easing.OutCubic
        }

    }

}
