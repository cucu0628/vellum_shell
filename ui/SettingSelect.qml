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

    function open() {
        if (!select.enabled || select.model.length === 0) return
        select.highlightedIndex = Math.max(0, select.indexOfValue(select.value))
        select.expanded = true
    }

    function close() {
        select.expanded = false
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

        var from = select.highlightedIndex < 0 ? select.indexOfValue(select.value) : select.highlightedIndex
        select.highlightedIndex = Math.max(0, Math.min(select.model.length - 1, (from < 0 ? 0 : from) + delta))
    }

    function chooseHighlighted() {
        if (select.highlightedIndex < 0 || select.highlightedIndex >= select.model.length) return
        var chosen = select.entryValue(select.model[select.highlightedIndex])
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

        anchors.top: box.bottom
        anchors.topMargin: 2
        anchors.right: box.right
        width: box.width
        height: Math.min(select.maxVisibleRows, Math.max(1, select.model.length)) * 26 + 2
        visible: select.expanded && select.model.length > 0
        color: select.background
        border.color: select.accent
        border.width: 1
        z: 50

        ListView {
            anchors.fill: parent
            anchors.margins: 1
            clip: true
            model: select.model
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
                        select.expanded = false;
                        select.activated(select.entryValue(option.modelData));
                    }
                }

            }

        }

    }

}
