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
    property int barHeight: 26
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
        } else if (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier)) {
            if (selectedItem)
                clipboardController.togglePin(selectedItem);

            event.accepted = true;
        }
    }

    onOpenedChanged: {
        // Alaphelyzet nyitaskor, nem zaraskor: a felcsuszo lapon meg a zaras
        // elotti lista marad.
        if (opened) {
            resetClipboard();
            refreshClipboard();
            focusTimer.start();
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
    visible: opened || sheet.reveal > 0
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

        // Kozepen, a sav aljahoz tapadva: a kereso is a savbol nyilik le.
        anchors.horizontalCenter: parent.horizontalCenter
        y: clipboardWindow.barHeight
        enabled: opened
        width: Math.min(720, clipboardWindow.width - 32)
        // A lap a tartalomhoz igazodik: 16 felso margo + 40 keresosor +
        // 12 terkoz + 1 vonal + 12 terkoz + lista + 12 also margo = 93 + lista.
        // Talalatokkal a labsor (12 terkoz + 16) is megjelenik. Egy sor 48 px,
        // koztuk 2; uresen a lista helyen egy 44 px-es uzenet all.
        height: Math.min(520, clipboardWindow.height - clipboardWindow.barHeight - 12,
            visibleItems.length > 0 ? 93 + 28 + visibleItems.length * 50 - 2 : 93 + 44)
        Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
        clip: true

        SharedUi.PopupFrame {
            id: sheet

            anchors.fill: parent
            theme: clipboardWindow.theme
            shown: clipboardWindow.opened

            MouseArea {
                anchors.fill: parent
                onClicked: (mouse) => {
                    return mouse.accepted = true;
                }
            }

            Column {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                anchors.topMargin: 16
                anchors.bottomMargin: 12
                spacing: 12

                // Kereso es a torles egy sorban; a darabszam a labsorba kerult.
                Item {
                    width: parent.width
                    height: 40

                    SharedUi.SearchField {
                        id: searchInput

                        anchors.left: parent.left
                        anchors.right: clearChip.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        foreground: clipboardWindow.panelFg
                        accent: clipboardWindow.panelAccent
                        muted: clipboardWindow.mutedFg
                        surface: clipboardWindow.inkBg
                        opened: clipboardWindow.opened
                        placeholder: "Search clipboard..."
                        onTextEdited: (text) => {
                            return clipboardWindow.query = text;
                        }
                        onKeyPressed: (event) => {
                            return clipboardWindow.handleKey(event);
                        }
                    }

                    // Az elozmeny torlese; a rogzitett elemek maradnak.
                    SharedUi.HeaderChip {
                        id: clearChip

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        enabled: clipboardController.entries.length > clipboardController.pinnedCount
                        theme: clipboardWindow.theme
                        label: "Clear"
                        accessibleName: qsTr("Clear clipboard history, keep pinned items")
                        onClicked: clipboardController.clear()
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: mutedFg
                    opacity: 0.14
                }

                // A lista kitolti, ami a fejresz es a labsor kozott marad.
                Item {
                    width: parent.width
                    height: Math.max(0, parent.height - y - (footer.visible ? footer.height + parent.spacing : 0))

                    Text {
                        visible: visibleItems.length === 0
                        anchors.centerIn: parent
                        text: !clipboardController.available && clipboardController.entries.length === 0
                            ? "The clipboard service is not running"
                            : (query === "" ? "Copy something and it will show up here" : "No clipboard matches")
                        color: mutedFg
                        font.pixelSize: 11
                    }

                    ListView {
                        id: resultsList

                        anchors.fill: parent
                        model: clipboardWindow.visible ? visibleItems : []
                        spacing: 2
                        reuseItems: true
                        cacheBuffer: 96
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        visible: visibleItems.length > 0
                        interactive: contentHeight > height

                        delegate: ClipboardUi.ClipboardResultRow {
                            width: resultsList.width - (resultsList.interactive ? 8 : 0)
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

                    // Csak a csuszka latszik, savja nincs.
                    Rectangle {
                        anchors.right: parent.right
                        width: 2
                        radius: 1
                        height: resultsList.contentHeight > 0
                            ? Math.max(24, parent.height * resultsList.visibleArea.heightRatio)
                            : 0
                        y: resultsList.visibleArea.yPosition * parent.height
                        color: mutedFg
                        opacity: resultsList.visible && resultsList.interactive ? 0.5 : 0

                        Behavior on y {
                            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                        }
                    }

                }

                // Uresen elmarad: az uzenet mar mindent elmond.
                Item {
                    id: footer

                    visible: visibleItems.length > 0
                    width: parent.width
                    height: 16

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            var total = clipboardController.entries.length
                            var text = total + (total === 1 ? " item" : " items")
                            var pinned = clipboardController.pinnedCount
                            return pinned > 0 ? text + "  ·  " + pinned + " pinned" : text
                        }
                        color: mutedFg
                        font.pixelSize: 10
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "↵ paste   ctrl+p pin   del remove   esc close"
                        color: mutedFg
                        font.family: "monospace"
                        font.pixelSize: 9
                    }

                }

            }

        }

    }

}
