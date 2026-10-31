import QtQuick
import Quickshell.Hyprland
import "../../ui" as SharedUi

Row {
    id: root

    required property var theme
    required property var visibleWorkspaceIds
    required property var occupiedWorkspaceIds
    property bool settingsOpen: false
    // A sav kepernyoje. A jelolo az ezen a monitoron lathato munkateruletet
    // mutatja, nem a globalisan fokuszaltat: igy minden sav a sajat kijelzojet
    // irja le.
    property var screen: null
    readonly property var monitor: screen ? Hyprland.monitorFor(screen) : null
    readonly property bool monitorFocused: monitor !== null && Hyprland.focusedMonitor === monitor
    readonly property int shownWorkspaceId: monitor && monitor.activeWorkspace
        ? monitor.activeWorkspace.id
        : (Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1)

    signal settingsClicked()

    height: parent.height

    Rectangle {
        id: menuItem
        // Ugyanannyi, mint egy munkaterulet-cella: a logo es az 1-es kozott sem
        // nagyobb a koz, mint a szamok kozott.
        width: 25
        height: parent.height
        color: "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }

        SharedUi.BarPill {
            theme: root.theme
            hovered: menuMouse.containsMouse
            active: root.settingsOpen
        }

        // A fokuszalt munkaterulet jeloloje. Egyetlen elem, ami a valtaskor
        // atcsuszik az uj szamra -- ugyanaz a mozgas, mint a dashboard tabjainal.
        // A menuelem gyereke, hogy a szamok alatta maradjanak.
        Rectangle {
            readonly property int focusedIndex: root.visibleWorkspaceIds.indexOf(root.shownWorkspaceId)
            // A fokuszalt cella tenyleges helye a sorban (a menuelem a sor
            // elejen all, igy a koordinatak egyeznek): nem fix lepeskozbol
            // szamolunk, hanem a cellabol, hogy a jelolo pontosan alatta legyen.
            // A `count` figyelese miatt ujraszamolodik, amikor a cellak letrejonnek --
            // az itemAt() magatol nem jelez.
            readonly property Item focusedCell: focusedIndex >= 0 && workspaceRepeater.count > focusedIndex
                ? workspaceRepeater.itemAt(focusedIndex)
                : null

            // A szamjegy rajzolatanak kozepere all, nem a cella kozepere: a
            // betuk szubpixeles simitasa miatt csak igy latszik kozepen.
            x: focusedCell ? focusedCell.x + focusedCell.glyphCenter - width / 2 : menuItem.width
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: 3
            anchors.bottomMargin: 3
            width: 22
            radius: 6
            color: root.theme.accent
            // A fokuszalt monitoron eros, a masikon halvany.
            opacity: focusedIndex < 0 ? 0 : (root.monitorFocused ? 0.18 : 0.07)

            Behavior on x { NumberAnimation { duration: 280; easing.type: Easing.OutQuint } }
            Behavior on opacity { NumberAnimation { duration: 140 } }
        }

        SharedUi.ShellLogo {
            anchors.centerIn: parent
            size: 14
            color: root.settingsOpen ? root.theme.accent : root.theme.foreground
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        MouseArea {
            id: menuMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.settingsClicked()
        }
    }

    Repeater {
        id: workspaceRepeater
        model: root.visibleWorkspaceIds

        Rectangle {
            required property int modelData
            property int wsId: modelData
            // Ezen a monitoron lathato; `isFocused` csak ha a monitor is fokuszban van.
            property bool isShown: root.shownWorkspaceId === wsId
            property bool isFocused: isShown && root.monitorFocused
            property bool isOccupied: root.occupiedWorkspaceIds.indexOf(wsId) !== -1
            // A szamjegy tenyleges rajzolatanak kozepe a cellan belul.
            readonly property real glyphCenter: wsLabel.x + wsMetrics.tightBoundingRect.x
                + wsMetrics.tightBoundingRect.width / 2

            width: 25
            height: parent.height
            color: "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }

            SharedUi.BarPill {
                anchors.leftMargin: 2
                anchors.rightMargin: 2
                theme: root.theme
                hovered: wsMouse.containsMouse && !parent.isShown
            }

            // A szamjegyek rajzolata nem a betuhely kozepen all (a "2" peldaul
            // jobbra huz), es felkoveren ez meg erosebb. Ezert a tenyleges
            // rajzolat kozepet igazitjuk a cella kozepere, nem a betuhelyet.
            TextMetrics {
                id: wsMetrics
                font: wsLabel.font
                text: wsLabel.text
            }

            Text {
                id: wsLabel
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: Math.round(wsMetrics.advanceWidth / 2
                    - (wsMetrics.tightBoundingRect.x + wsMetrics.tightBoundingRect.width / 2))
                text: parent.wsId.toString()
                color: parent.isFocused ? root.theme.accent : root.theme.foreground
                opacity: parent.isShown || parent.isOccupied || wsMouse.containsMouse ? 1 : 0.62
                font.weight: parent.isShown ? Font.DemiBold : Font.Normal
                font.pixelSize: 12
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            }

            MouseArea {
                id: wsMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Hyprland.dispatch(Hyprland.usingLua
                    ? "hl.dsp.focus({ workspace = " + parent.wsId + " })"
                    : "workspace " + parent.wsId)
            }
        }
    }
}
