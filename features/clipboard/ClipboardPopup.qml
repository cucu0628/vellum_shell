import "." as ClipboardUi
import "../../ui" as SharedUi
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: clipboardWindow

    required property var clipboardController
    property var theme: null
    property bool opened: false
    property string query: ""
    property int selectedIndex: 0
    property bool suppressHoverSelection: false
    readonly property color panelBg: theme ? theme.background : "#15110f"
    readonly property color panelFg: theme ? theme.foreground : "#f1e7d0"
    readonly property color panelAccent: theme ? theme.accent : "#d7472f"
    readonly property color mutedFg: theme && theme.muted ? theme.muted : "#9f8f7c"
    readonly property color inkBg: theme && theme.surface ? theme.surface : "#1b1613"
    readonly property var visibleItems: filterEntries(query)
    readonly property var selectedItem: visibleItems.length > 0 ? visibleItems[Math.max(0, Math.min(selectedIndex, visibleItems.length - 1))] : null

    function resetClipboard() {
        suppressHoverSelection = false;
        query = "";
        searchInput.text = "";
        selectedIndex = 0;
        resultsList.contentY = 0;
    }

    function refreshClipboard() {
        clipboardController.refreshClipboard();
    }

    function filterEntries(value) {
        return clipboardController.filterEntries(value);
    }

    function activateSelected() {
        if (!selectedItem)
            return ;

        clipboardController.activate(selectedItem);
        opened = false;
    }

    function deleteSelected() {
        if (!selectedItem)
            return ;

        clipboardController.remove(selectedItem);
        selectedIndex = Math.max(0, Math.min(selectedIndex, Math.max(visibleItems.length - 1, 0)));
    }

    function ensureSelectedVisible() {
        if (visibleItems.length > 0)
            resultsList.positionViewAtIndex(selectedIndex, ListView.Contain);

    }

    function clampResultsScroll() {
        var maxY = Math.max(0, resultsList.contentHeight - resultsList.height);
        resultsList.contentY = Math.max(0, Math.min(resultsList.contentY, maxY));
    }

    function handleKey(event) {
        if (event.key === Qt.Key_Escape) {
            opened = false;
            event.accepted = true;
        } else if (event.key === Qt.Key_Down || (event.key === Qt.Key_J && event.modifiers === Qt.ControlModifier)) {
            suppressHoverSelection = true;
            selectedIndex = Math.min(selectedIndex + 1, Math.max(visibleItems.length - 1, 0));
            ensureSelectedVisible();
            event.accepted = true;
        } else if (event.key === Qt.Key_Up || (event.key === Qt.Key_K && event.modifiers === Qt.ControlModifier)) {
            suppressHoverSelection = true;
            selectedIndex = Math.max(selectedIndex - 1, 0);
            ensureSelectedVisible();
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            activateSelected();
            event.accepted = true;
        } else if (event.key === Qt.Key_Delete) {
            deleteSelected();
            event.accepted = true;
        }
    }

    onOpenedChanged: {
        if (opened) {
            resetClipboard();
            refreshClipboard();
            focusTimer.start();
        } else {
            resetClipboard();
        }
    }
    onQueryChanged: {
        suppressHoverSelection = false;
        selectedIndex = 0;
        resultsList.contentY = 0;
    }
    onVisibleItemsChanged: {
        selectedIndex = Math.max(0, Math.min(selectedIndex, Math.max(visibleItems.length - 1, 0)));
        clampResultsScroll();
    }
    visible: opened || content.opacity > 0
    color: "transparent"
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.namespace: "quickshell.clipboard"
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: opened ? 1 : 0

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    Timer {
        id: focusTimer

        interval: 80
        onTriggered: searchInput.forceInputFocus()
    }

    MouseArea {
        anchors.fill: parent
        enabled: opened
        onClicked: opened = false
    }

    Item {
        id: content

        anchors.centerIn: parent
        enabled: opened
        width: Math.min(760, clipboardWindow.width - 32)
        height: Math.min(520, clipboardWindow.height - 40)
        opacity: opened ? 1 : 0
        scale: opened ? 1 : 0.985
        transform: Translate {
            y: clipboardWindow.opened ? 0 : 18

            Behavior on y {
                NumberAnimation {
                    duration: clipboardWindow.opened ? 240 : 120
                    easing.type: clipboardWindow.opened ? Easing.OutQuart : Easing.InQuad
                }
            }
        }

        SharedUi.PopupFrame {
            anchors.fill: parent
            theme: clipboardWindow.theme

            MouseArea {
                anchors.fill: parent
                onClicked: (mouse) => {
                    return mouse.accepted = true;
                }
            }

            Column {
                anchors.fill: parent
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                anchors.topMargin: 20
                anchors.bottomMargin: 16
                spacing: 10

                SharedUi.PopupHeader {
                    width: parent.width
                    theme: clipboardWindow.theme
                    title: "Clipboard"
                    subtitle: visibleItems.length + (visibleItems.length === 1 ? " history item" : " history items")

                }

                SharedUi.SearchField {
                    id: searchInput

                    width: parent.width
                    height: 52
                    foreground: clipboardWindow.panelFg
                    accent: clipboardWindow.panelAccent
                    muted: clipboardWindow.mutedFg
                    surface: clipboardWindow.inkBg
                    opened: clipboardWindow.opened
                    placeholder: "Search clipboard..."
                    inputLeftMargin: 44
                    inputVerticalPadding: 12
                    onTextEdited: (text) => {
                        return clipboardWindow.query = text;
                    }
                    onKeyPressed: (event) => {
                        return clipboardWindow.handleKey(event);
                    }
                }

                Item {
                    width: parent.width
                    height: 18

                    Text {
                        anchors.left: parent.left
                        height: parent.height
                        text: "HISTORY  ·  " + visibleItems.length
                        color: panelAccent
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 8
                        font.bold: true
                        font.letterSpacing: 1.8
                    }

                    Text {
                        anchors.right: parent.right
                        height: parent.height
                        text: "↑↓  SELECT     ENTER  PASTE     DEL  REMOVE"
                        color: mutedFg
                        verticalAlignment: Text.AlignVCenter
                        font.family: "monospace"
                        font.pixelSize: 8
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: mutedFg
                    opacity: 0.2
                }

                Item {
                    width: parent.width
                    height: parent.height - 163

                    Item {
                        id: listPane

                        width: parent.width
                        height: parent.height

                        Text {
                            visible: visibleItems.length === 0
                            anchors.centerIn: parent
                            text: query === "" ? "Clipboard history is empty" : "No clipboard matches"
                            color: mutedFg
                            font.pixelSize: 11
                        }

                        ListView {
                            id: resultsList

                            anchors.fill: parent
                            model: clipboardWindow.opened ? visibleItems : []
                            spacing: 4
                            reuseItems: true
                            cacheBuffer: 96
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            visible: visibleItems.length > 0
                            interactive: contentHeight > height

                            delegate: ClipboardUi.ClipboardResultRow {
                                width: resultsList.width
                                entry: modelData
                                controller: clipboardController
                                resultIndex: index
                                selected: index === selectedIndex
                                panelBg: clipboardWindow.panelBg
                                panelFg: clipboardWindow.panelFg
                                panelAccent: clipboardWindow.panelAccent
                                mutedFg: clipboardWindow.mutedFg
                                inkBg: clipboardWindow.inkBg
                                onHovered: (rowIndex) => {
                                    if (!suppressHoverSelection)
                                        selectedIndex = rowIndex;

                                }
                                onActivated: (rowIndex) => {
                                    suppressHoverSelection = false;
                                    selectedIndex = rowIndex;
                                    activateSelected();
                                }
                            }

                        }

                        Rectangle {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            width: 2
                            color: mutedFg
                            opacity: resultsList.interactive ? 0.16 : 0
                        }

                        Rectangle {
                            anchors.right: parent.right
                            width: 2
                            height: resultsList.contentHeight > 0
                                ? Math.max(24, parent.height * resultsList.visibleArea.heightRatio)
                                : 0
                            y: resultsList.visibleArea.yPosition * parent.height
                            color: panelAccent
                            opacity: resultsList.interactive ? 0.9 : 0

                            Behavior on y {
                                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                            }
                        }

                    }

                }

            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: clipboardWindow.opened ? 160 : 110
                easing.type: clipboardWindow.opened ? Easing.OutQuart : Easing.InQuad
            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: clipboardWindow.opened ? 260 : 130
                easing.type: clipboardWindow.opened ? Easing.OutQuart : Easing.InQuad
            }

        }

    }

}
