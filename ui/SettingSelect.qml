pragma ComponentBehavior: Bound

import QtQuick

// Legordulo valaszto. Nem QtQuick.Controls Popup, hanem a szulo felett lebego
// sajat lista: a shell sehol nem hasznal Controls-t, es igy a temazasa is a
// tobbi elemevel egyezik.
//
// A `model` string lista, vagy `{ label, value }` objektumok listaja.
//
// Billentyuzetrol: Space/Enter/Le nyit, a nyilak lepnek a listaban, az Enter
// valaszt, az Escape zar. Nyitas nelkul is lehet lepkedni az ertekek kozott --
// ez a legrovidebb ut, ha a felhasznalo tudja, mit keres.
Item {
    id: select

    property var theme: null
    property var model: []
    property string value: ""
    property string placeholder: "--"
    property bool expanded: false
    property int maxVisibleRows: 8
    property bool searchable: false
    property bool dropUp: false
    property string searchText: ""
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

    function open() {
        if (!select.enabled || select.model.length === 0) return
        select.searchText = ""
        select.highlightedIndex = Math.max(0, select.visibleIndexOfValue(select.value))
        select.expanded = true
        if (select.searchable)
            Qt.callLater(function() { searchInput.forceActiveFocus(); })
    }

    function close() {
        select.expanded = false
        select.searchText = ""
        select.forceActiveFocus()
    }

    // Lepes a listaban. Zarva ez azonnal valaszt is: igy a nyilakkal vegig
    // lehet menni az ertekeken anelkul, hogy a listat ki kellene nyitni.
    function step(delta) {
        if (!select.enabled || select.model.length === 0) return

        if (!select.expanded) {
            var at = select.indexOfValue(select.value)
            var next = Math.max(0, Math.min(select.model.length - 1, (at < 0 ? 0 : at) + delta))
            if (next !== at) select.activated(select.entryValue(select.model[next]))
            return
        }

        if (select.visibleModel.length === 0) return
        var from = select.highlightedIndex < 0 ? select.visibleIndexOfValue(select.value) : select.highlightedIndex
        select.highlightedIndex = Math.max(0, Math.min(select.visibleModel.length - 1, (from < 0 ? 0 : from) + delta))
    }

    function chooseHighlighted() {
        if (select.highlightedIndex < 0 || select.highlightedIndex >= select.visibleModel.length) return
        var chosen = select.entryValue(select.visibleModel[select.highlightedIndex])
        select.close()
        select.activated(chosen)
    }

    // Nyitva az Enter valaszt, zarva nyit.
    function activate() {
        if (select.expanded) select.chooseHighlighted()
        else select.open()
    }

    onValueChanged: if (!expanded) highlightedIndex = indexOfValue(value)
    onExpandedChanged: if (!expanded) highlightedIndex = indexOfValue(value)
    onVisibleModelChanged: {
        if (!expanded)
            return;

        highlightedIndex = visibleModel.length > 0 ? 0 : -1;
    }

    implicitWidth: 240
    implicitHeight: 30
    // A lenyilo lista kilog az elembol, ezert nem szabad levagni.
    clip: false

    activeFocusOnTab: enabled
    Keys.onSpacePressed: (event) => { select.activate(); event.accepted = true }
    Keys.onReturnPressed: (event) => { select.activate(); event.accepted = true }
    Keys.onEnterPressed: (event) => { select.activate(); event.accepted = true }
    Keys.onEscapePressed: (event) => {
        if (!select.expanded) return
        select.close()
        event.accepted = true
    }
    Keys.onUpPressed: (event) => { select.step(-1); event.accepted = true }
    Keys.onDownPressed: (event) => {
        if (select.expanded) select.step(1)
        else select.open()
        event.accepted = true
    }
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Home) { select.highlightedIndex = 0; event.accepted = true }
        else if (event.key === Qt.Key_End) { select.highlightedIndex = select.model.length - 1; event.accepted = true }
    }

    Accessible.role: Accessible.ComboBox
    Accessible.name: select.accessibleName
    Accessible.description: select.accessibleDescription
    Accessible.onPressAction: select.activate()

    Rectangle {
        id: box

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 30
        color: select.surface
        border.color: select.expanded ? select.accent : select.muted
        border.width: 1

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 10
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
            text: select.expanded ? "▴" : "▾"
            color: select.accent
            font.pixelSize: 10
        }

        FocusRing {
            theme: select.theme
            active: select.activeFocus
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (select.expanded) select.close();
                else select.open();
            }
        }

    }

    Rectangle {
        id: dropdown

        anchors.top: select.dropUp ? undefined : box.bottom
        anchors.topMargin: select.dropUp ? 0 : 2
        anchors.bottom: select.dropUp ? box.top : undefined
        anchors.bottomMargin: select.dropUp ? 2 : 0
        anchors.right: box.right
        width: box.width
        height: (select.searchable ? 34 : 0)
            + Math.min(select.maxVisibleRows, Math.max(1, select.visibleModel.length)) * 26 + 2
        visible: select.expanded && select.model.length > 0
        color: select.background
        border.color: select.accent
        border.width: 1
        z: 50

        Rectangle {
            id: searchBox

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 1
            height: select.searchable ? 33 : 0
            visible: select.searchable
            color: select.surface

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 9
                anchors.verticalCenter: parent.verticalCenter
                text: "⌕"
                color: select.accent
                font.pixelSize: 13
            }

            TextInput {
                id: searchInput

                anchors.left: parent.left
                anchors.leftMargin: 30
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
                verticalAlignment: TextInput.AlignVCenter
                text: select.searchText
                color: select.foreground
                font.pixelSize: 11
                onTextEdited: select.searchText = text
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
                    text: "Search applications..."
                    color: select.muted
                    font.pixelSize: 11
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: select.muted
                opacity: 0.18
            }
        }

        ListView {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: searchBox.bottom
            anchors.bottom: parent.bottom
            anchors.leftMargin: 1
            anchors.rightMargin: 1
            anchors.bottomMargin: 1
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
                height: 26
                color: optionMouse.containsMouse || option.highlighted || option.current
                    ? select.surface
                    : "transparent"
                border.color: option.highlighted ? select.accent : "transparent"
                border.width: 1

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 9
                    anchors.right: parent.right
                    anchors.rightMargin: 9
                    anchors.verticalCenter: parent.verticalCenter
                    text: select.entryLabel(option.modelData)
                    color: option.current ? select.accent : select.foreground
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: optionMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        select.close();
                        select.activated(select.entryValue(option.modelData));
                    }
                }

            }

        }

        Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: searchBox.bottom
            anchors.bottom: parent.bottom
            visible: select.visibleModel.length === 0
            text: "No matching applications."
            color: select.muted
            font.pixelSize: 10
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

    }

}
