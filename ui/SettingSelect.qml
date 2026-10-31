pragma ComponentBehavior: Bound

import QtQuick

// Legordulo valaszto. Nem QtQuick.Controls Popup, hanem sajat lista: a shell
// sehol nem hasznal Controls-t, es igy a temazasa is a tobbi elemevel egyezik.
//
// Nyitva a lista az ablak gyokerelemere kerul at. Igy a gorgetheto oldal
// `clip`-je nem vagja le, es a kesobbi szakaszok sem rajzolodnak ra. Arra
// nyilik, amerre tobb hely van, es a kulso kattintas, a gorgetes, a fokusz
// elvesztese vagy az ablak atmeretezese bezarja.
//
// A `model` string lista, vagy `{ label, value }` objektumok listaja.
//
// Billentyuzetrol: Space/Enter/Fel/Le nyit, a nyilak lepnek a listaban, a
// Home/End az elejere/vegere ugrik, az Enter valaszt, az Escape zar. Zarva a
// nyilak nem valtoztatnak erteket: a kijelzo-beallitasok azonnal ervenybe
// lepnek, egy veletlen lepes ne valtson felbontast.
Item {
    id: select

    property var theme: null
    property var model: []
    property string value: ""
    property string placeholder: "--"
    property bool expanded: false
    property int maxVisibleRows: 8
    property bool searchable: false
    property string searchText: ""
    property string searchPlaceholder: "Search..."
    property string emptyText: "No matches."
    // Amit a kepernyoolvaso mond. A SettingRow magatol atadja a sor cimket.
    property string accessibleName: ""
    property string accessibleDescription: ""

    // A nyitott listaban kiemelt sor. Zarva mindig az aktualis ertek.
    property int highlightedIndex: -1

    readonly property string foreground: theme ? theme.foreground : "#e8ddc7"
    readonly property string accent: theme ? theme.accent : "#b7372f"
    readonly property string muted: theme && theme.muted ? theme.muted : "#958b7a"
    readonly property string surface: theme && theme.surface ? theme.surface : "#1b1613"
    readonly property string background: theme ? theme.background : "#11130f"
    readonly property string currentLabel: labelFor(value)
    readonly property var visibleModel: {
        var needle = searchText.trim().toLowerCase();
        if (!searchable || needle === "")
            return model;

        var terms = needle.split(/\s+/);
        var result = [];
        for (var i = 0; i < model.length; i++) {
            var haystack = (entryLabel(model[i]) + " " + entryValue(model[i])).toLowerCase();
            var matches = true;
            for (var j = 0; j < terms.length; j++) {
                if (haystack.indexOf(terms[j]) < 0) {
                    matches = false;
                    break;
                }
            }
            if (matches)
                result.push(model[i]);
        }
        return result;
    }

    // Ide kerul a nyitott lista. Ablak nelkul (pl. elonezetben) marad a
    // vezerlo gyereke, ahogy korabban.
    readonly property Item overlayHost: select.Window.contentItem
    readonly property bool windowActive: select.Window.active
    readonly property int rowHeight: 30
    readonly property int searchHeight: searchable ? 38 : 0
    // A lista belso margoja: a lekerekitett sarkok ne vagjak a szelso sorokat.
    readonly property int listPadding: 4

    // A lista helye a gazdaelemben; nyitaskor szamoljuk ki.
    property real anchorX: 0
    property real anchorY: 0
    property bool openUpward: false
    property int fittingRows: maxVisibleRows

    signal activated(string value)

    function entryValue(entry) {
        return entry && entry.value !== undefined ? entry.value.toString() : (entry || "").toString();
    }

    function entryLabel(entry) {
        return entry && entry.label !== undefined ? entry.label.toString() : (entry || "").toString();
    }

    function labelFor(wanted) {
        for (var i = 0; i < model.length; i++) {
            if (entryValue(model[i]) === wanted)
                return entryLabel(model[i]);

        }
        return wanted === "" ? placeholder : wanted;
    }

    function indexOfValue(wanted) {
        for (var i = 0; i < model.length; i++) {
            if (entryValue(model[i]) === wanted) return i
        }
        return -1
    }

    function visibleIndexOfValue(wanted) {
        for (var i = 0; i < visibleModel.length; i++) {
            if (entryValue(visibleModel[i]) === wanted) return i
        }
        return -1
    }

    // A lista helye es magassaga: arra nyilik, amerre tobb sor fer el, es
    // legalabb harom sort mutat akkor is, ha egyik iranyban sincs eleg hely.
    function place() {
        var host = dropdown.parent
        var origin = box.mapToItem(host, 0, 0)
        var margin = 8
        var below = host.height - (origin.y + box.height + 2) - margin
        var above = origin.y - 2 - margin
        var wanted = select.searchHeight + Math.min(select.maxVisibleRows, Math.max(1, select.model.length)) * select.rowHeight + 2 * select.listPadding

        select.openUpward = below < wanted && above > below
        var room = select.openUpward ? above : below
        select.fittingRows = Math.max(3, Math.min(select.maxVisibleRows,
            Math.floor((room - select.searchHeight - 2 * select.listPadding) / select.rowHeight)))
        select.anchorX = origin.x
        select.anchorY = origin.y
    }

    function revealHighlighted() {
        if (select.highlightedIndex >= 0)
            optionList.positionViewAtIndex(select.highlightedIndex, ListView.Contain)
    }

    function open() {
        if (!select.enabled || select.model.length === 0) return
        select.searchText = ""
        select.highlightedIndex = Math.max(0, select.visibleIndexOfValue(select.value))
        select.expanded = true
        select.place()
        select.forceActiveFocus()
        Qt.callLater(function() {
            if (!select.expanded) return
            select.revealHighlighted()
            if (select.searchable) searchInput.forceActiveFocus()
        })
    }

    // `keepFocus`: billentyuzetrol vagy valasztassal zarva a fokusz a
    // vezerlon marad; ha a fokusz mar mashova kerult, nem rantjuk vissza.
    function close(keepFocus) {
        if (!select.expanded) return
        select.expanded = false
        select.searchText = ""
        if (keepFocus !== false) select.forceActiveFocus()
    }

    function step(delta) {
        if (!select.expanded || select.visibleModel.length === 0) return
        var from = select.highlightedIndex < 0 ? select.visibleIndexOfValue(select.value) : select.highlightedIndex
        select.highlightedIndex = Math.max(0, Math.min(select.visibleModel.length - 1, (from < 0 ? 0 : from) + delta))
        select.revealHighlighted()
    }

    function jumpTo(index) {
        if (!select.expanded || select.visibleModel.length === 0) return
        select.highlightedIndex = Math.max(0, Math.min(select.visibleModel.length - 1, index))
        select.revealHighlighted()
    }

    function choose(entry) {
        var chosen = select.entryValue(entry)
        select.close()
        if (chosen !== select.value) select.activated(chosen)
    }

    function chooseHighlighted() {
        if (select.highlightedIndex < 0 || select.highlightedIndex >= select.visibleModel.length) return
        select.choose(select.visibleModel[select.highlightedIndex])
    }

    // Nyitva az Enter valaszt, zarva nyit.
    function activate() {
        if (select.expanded) select.chooseHighlighted()
        else select.open()
    }

    // A kereso is a vezerlohoz tartozik: ha a fokusz a ketto kozul valamelyiken
    // van, a lista nyitva marad.
    function closeIfFocusLeft() {
        Qt.callLater(function() {
            if (select.expanded && !select.activeFocus && !searchInput.activeFocus)
                select.close(false)
        })
    }

    onValueChanged: if (!expanded) highlightedIndex = indexOfValue(value)
    onExpandedChanged: if (!expanded) highlightedIndex = indexOfValue(value)
    onVisibleModelChanged: {
        if (!expanded)
            return;

        if (searchText.trim() === "")
            highlightedIndex = visibleModel.length > 0 ? Math.max(0, visibleIndexOfValue(value)) : -1;
        else
            highlightedIndex = visibleModel.length > 0 ? 0 : -1;
    }
    onEnabledChanged: if (!enabled) close(false)
    onWindowActiveChanged: if (!windowActive) close(false)
    onActiveFocusChanged: if (!activeFocus) closeIfFocusLeft()

    Connections {
        target: select.expanded ? select.overlayHost : null

        function onWidthChanged() { select.close(false) }
        function onHeightChanged() { select.close(false) }
    }

    implicitWidth: 240
    implicitHeight: 32

    activeFocusOnTab: enabled
    Keys.onSpacePressed: (event) => { select.activate(); event.accepted = true }
    Keys.onReturnPressed: (event) => { select.activate(); event.accepted = true }
    Keys.onEnterPressed: (event) => { select.activate(); event.accepted = true }
    Keys.onEscapePressed: (event) => {
        if (!select.expanded) return
        select.close()
        event.accepted = true
    }
    Keys.onUpPressed: (event) => {
        if (select.expanded) select.step(-1)
        else select.open()
        event.accepted = true
    }
    Keys.onDownPressed: (event) => {
        if (select.expanded) select.step(1)
        else select.open()
        event.accepted = true
    }
    Keys.onPressed: (event) => {
        if (!select.expanded) return
        if (event.key === Qt.Key_Home) { select.jumpTo(0); event.accepted = true }
        else if (event.key === Qt.Key_End) { select.jumpTo(select.visibleModel.length - 1); event.accepted = true }
        else if (event.key === Qt.Key_PageUp) { select.step(-select.fittingRows); event.accepted = true }
        else if (event.key === Qt.Key_PageDown) { select.step(select.fittingRows); event.accepted = true }
    }

    Accessible.role: Accessible.ComboBox
    Accessible.name: select.accessibleName
    Accessible.description: select.accessibleDescription
    Accessible.onPressAction: select.activate()

    // Ugyanaz a kerek mezo, mint a SearchField: vekony keret, ami nyitva sem
    // vastagodik, csak akcentes lesz.
    Rectangle {
        id: box

        readonly property color accentColor: select.accent
        readonly property color mutedColor: select.muted
        readonly property bool hovered: boxMouse.containsMouse

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 32
        radius: 8
        color: box.hovered && !select.expanded ? Qt.lighter(select.surface, 1.25) : select.surface
        border.width: 1
        border.color: select.expanded
            ? Qt.rgba(box.accentColor.r, box.accentColor.g, box.accentColor.b, 0.55)
            : Qt.rgba(box.mutedColor.r, box.mutedColor.g, box.mutedColor.b, box.hovered ? 0.34 : 0.22)

        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.right: chevron.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: select.currentLabel
            color: select.foreground
            font.pixelSize: 12
            elide: Text.ElideRight
        }

        Text {
            id: chevron

            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: "󰅀"
            color: select.expanded ? select.accent : select.muted
            font.family: "Symbols Nerd Font Mono"
            font.pixelSize: 12
            rotation: select.expanded ? 180 : 0

            Behavior on rotation { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }

        FocusRing {
            theme: select.theme
            active: select.activeFocus
            cornerRadius: box.radius
        }

        MouseArea {
            id: boxMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (select.expanded) select.close();
                else select.open();
            }
        }

    }

    // Nyitott lista alatt az egesz ablakot lefedi: a lista melle kattintas
    // vagy gorgetes csak bezarja a listat, nem er el az alatta levo vezerlokig.
    MouseArea {
        parent: select.expanded && select.overlayHost ? select.overlayHost : select
        anchors.fill: parent
        visible: select.expanded && select.overlayHost !== null
        z: 9998
        acceptedButtons: Qt.AllButtons
        onPressed: (mouse) => {
            select.close();
            mouse.accepted = true;
        }
        onWheel: (wheel) => {
            select.close();
            wheel.accepted = true;
        }
    }

    Rectangle {
        id: dropdown

        parent: select.expanded && select.overlayHost ? select.overlayHost : select
        x: select.anchorX
        y: select.openUpward
            ? select.anchorY - height - 4
            : select.anchorY + box.height + 4
        width: box.width
        height: select.searchHeight
            + Math.min(select.fittingRows, Math.max(1, select.visibleModel.length)) * select.rowHeight + 2 * select.listPadding
        visible: select.expanded && select.model.length > 0
        radius: 10
        color: select.background
        border.color: Qt.rgba(1, 1, 1, 0.1)
        border.width: 1
        z: 9999

        // A lista sajat esemenyei: a keret es az ures resz se zarja be.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onWheel: (wheel) => { wheel.accepted = true }
        }

        Rectangle {
            id: searchBox

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 1
            height: select.searchable ? 37 : 0
            visible: select.searchable
            radius: 9
            color: "transparent"

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: "⌕"
                color: select.accent
                font.pixelSize: 13
            }

            TextInput {
                id: searchInput

                anchors.left: parent.left
                anchors.leftMargin: 32
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
                verticalAlignment: TextInput.AlignVCenter
                text: select.searchText
                color: select.foreground
                font.pixelSize: 12
                onTextEdited: select.searchText = text
                onActiveFocusChanged: if (!activeFocus) select.closeIfFocusLeft()
                Keys.onUpPressed: (event) => {
                    select.step(-1);
                    event.accepted = true;
                }
                Keys.onDownPressed: (event) => {
                    select.step(1);
                    event.accepted = true;
                }
                Keys.onReturnPressed: (event) => {
                    select.chooseHighlighted();
                    event.accepted = true;
                }
                Keys.onEnterPressed: (event) => {
                    select.chooseHighlighted();
                    event.accepted = true;
                }
                Keys.onTabPressed: (event) => {
                    select.close();
                    event.accepted = true;
                }
                Keys.onEscapePressed: (event) => {
                    if (select.searchText !== "")
                        select.searchText = "";
                    else
                        select.close();
                    event.accepted = true;
                }

                Text {
                    anchors.fill: parent
                    visible: searchInput.text === ""
                    verticalAlignment: Text.AlignVCenter
                    text: select.searchPlaceholder
                    color: select.muted
                    font.pixelSize: 12
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: select.muted
                opacity: 0.14
            }
        }

        ListView {
            id: optionList

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: searchBox.bottom
            anchors.bottom: parent.bottom
            anchors.margins: select.listPadding
            clip: true
            model: select.visibleModel
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            delegate: Rectangle {
                id: option

                required property var modelData

                required property int index

                readonly property bool current: select.entryValue(option.modelData) === select.value
                readonly property bool highlighted: select.highlightedIndex === option.index

                width: ListView.view.width
                height: select.rowHeight
                radius: 6
                color: option.highlighted ? Qt.rgba(1, 1, 1, 0.07) : "transparent"

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.right: checkMark.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: select.entryLabel(option.modelData)
                    color: option.current ? select.accent : select.foreground
                    font.pixelSize: 12
                    font.weight: option.current ? Font.Medium : Font.Normal
                    elide: Text.ElideRight
                }

                Text {
                    id: checkMark

                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    visible: option.current
                    text: "󰄬"
                    color: select.accent
                    font.family: "Symbols Nerd Font Mono"
                    font.pixelSize: 12
                }

                // Az eger es a billentyuzet ugyanazt a kiemelest mozgatja, igy
                // egyszerre csak egy sor latszik kivalasztottnak.
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: select.highlightedIndex = option.index
                    onClicked: select.choose(option.modelData)
                }

            }

        }

        Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: searchBox.bottom
            anchors.bottom: parent.bottom
            visible: select.visibleModel.length === 0
            text: select.emptyText
            color: select.muted
            font.pixelSize: 11
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

    }

}
