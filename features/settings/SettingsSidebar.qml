pragma ComponentBehavior: Bound

import QtQuick
import "../../ui" as SharedUi

// Oldalsav: fejlec, kereso, csoportositott oldallista, alul a daemon allapota.
//
// A kereso az oldalak cimeben, leirasaban es kulcsszavaiban keres (pl. "blur"
// -> Windows, "touchpad" -> Input); Enterre az elso talalat nyilik. A lista
// elemei Tab-bal es a Fel/Le nyilakkal is bejarhatok.
Rectangle {
    id: sidebar

    property var theme: null
    property string activePage: ""
    // [{ id, label, icon, group, description, keywords }]
    property var pages: []
    property bool backendOnline: true
    property bool backendChecking: false
    property string query: ""

    readonly property string foreground: theme ? theme.foreground : "#e8ddc7"
    readonly property string accent: theme ? theme.accent : "#b7372f"
    readonly property string muted: theme && theme.muted ? theme.muted : "#958b7a"
    readonly property string surface: theme && theme.surface ? theme.surface : "#1b1613"
    readonly property string warning: theme && theme.warning ? theme.warning : "#c9693f"
    readonly property color accentColor: accent

    readonly property var matchingPages: {
        var terms = query.trim().toLowerCase().split(/\s+/).filter(term => term !== "")
        if (terms.length === 0) return pages
        var result = []
        for (var i = 0; i < pages.length; i++) {
            var entry = pages[i]
            var haystack = (entry.label + " " + entry.description + " " + (entry.keywords || "")).toLowerCase()
            var matches = true
            for (var j = 0; j < terms.length; j++) {
                if (haystack.indexOf(terms[j]) < 0) {
                    matches = false
                    break
                }
            }
            if (matches) result.push(entry)
        }
        return result
    }

    // A csoportok a lista sorrendjeben, csak a talalatot tartalmazok.
    readonly property var groups: {
        var result = []
        var index = ({})
        for (var i = 0; i < matchingPages.length; i++) {
            var name = matchingPages[i].group || ""
            if (index[name] === undefined) {
                index[name] = result.length
                result.push({ "name": name, "pages": [] })
            }
            result[index[name]].pages.push(matchingPages[i])
        }
        return result
    }

    signal selected(string page)

    function focusSearch() {
        searchField.forceInputFocus()
        searchField.selectAll()
    }

    color: surface

    Item {
        id: masthead

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 68

        SharedUi.ShellLogo {
            id: mark

            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            size: 28
            color: sidebar.accent
        }

        Text {
            anchors.left: mark.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: mark.verticalCenter
            text: "Settings"
            color: sidebar.foreground
            font.family: "serif"
            font.pixelSize: 20
            font.weight: Font.Medium
            elide: Text.ElideRight
        }
    }

    SharedUi.SearchField {
        id: searchField

        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.top: masthead.bottom
        height: 36
        placeholder: "Search settings"
        foreground: sidebar.foreground
        accent: sidebar.accent
        muted: sidebar.muted
        surface: Qt.rgba(1, 1, 1, 0.05)
        inputLeftMargin: 32
        inputVerticalPadding: 8
        onTextEdited: (text) => sidebar.query = text
        onKeyPressed: (event) => {
            if (event.key === Qt.Key_Escape && searchField.text !== "") {
                searchField.text = ""
                event.accepted = true
            } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && sidebar.matchingPages.length > 0) {
                sidebar.selected(sidebar.matchingPages[0].id)
                event.accepted = true
            } else if (event.key === Qt.Key_Down) {
                var first = navigation.firstEntry()
                if (first) first.forceActiveFocus()
                event.accepted = true
            }
        }
    }

    Flickable {
        id: navigationScroll

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: searchField.bottom
        anchors.topMargin: 8
        anchors.bottom: footer.top
        contentWidth: width
        contentHeight: navigation.height + 8
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: navigation

            function firstEntry() {
                var stack = [navigation]
                while (stack.length > 0) {
                    var node = stack.shift()
                    for (var i = 0; i < node.children.length; i++) {
                        var child = node.children[i]
                        if (child.objectName === "settingsNavEntry" && child.visible) return child
                        stack.push(child)
                    }
                }
                return null
            }

            width: navigationScroll.width
            spacing: 4

            Repeater {
                model: sidebar.groups

                Column {
                    id: group

                    required property var modelData

                    width: navigation.width
                    spacing: 2

                    Text {
                        x: 24
                        height: 28
                        visible: group.modelData.name !== ""
                        verticalAlignment: Text.AlignBottom
                        bottomPadding: 6
                        text: group.modelData.name.toUpperCase()
                        color: sidebar.muted
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1
                    }

                    Repeater {
                        model: group.modelData.pages

                        Rectangle {
                            id: entry

                            required property var modelData

                            readonly property bool current: entry.modelData.id === sidebar.activePage
                            readonly property bool hovered: entryPress.containsMouse

                            x: 12
                            width: navigation.width - 24
                            height: 40
                            radius: 8
                            color: entry.current
                                ? Qt.rgba(sidebar.accentColor.r, sidebar.accentColor.g, sidebar.accentColor.b, entry.hovered ? 0.18 : 0.13)
                                : (entry.hovered ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
                            scale: entryPress.pressed ? 0.98 : 1

                            Behavior on color { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }
                            Behavior on scale { SpringAnimation { spring: 9; damping: 0.55; epsilon: 0.0005 } }

                            Text {
                                id: glyph

                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                width: 20
                                horizontalAlignment: Text.AlignHCenter
                                text: entry.modelData.icon
                                color: entry.current ? sidebar.accent : sidebar.muted
                                font.family: "Symbols Nerd Font Mono"
                                font.pixelSize: 16

                                Behavior on color { ColorAnimation { duration: 140 } }
                            }

                            Text {
                                anchors.left: glyph.right
                                anchors.leftMargin: 12
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: entry.modelData.label
                                color: sidebar.foreground
                                font.pixelSize: 13
                                font.weight: entry.current ? Font.Medium : Font.Normal
                                elide: Text.ElideRight
                            }

                            SharedUi.Pressable {
                                id: entryPress

                                objectName: "settingsNavEntry"
                                anchors.fill: parent
                                theme: sidebar.theme
                                focusRadius: entry.radius
                                accessibleRole: Accessible.PageTab
                                accessibleName: entry.modelData.label
                                accessibleDescription: entry.modelData.description
                                onClicked: sidebar.selected(entry.modelData.id)

                                // Fel/Le a szomszedos oldalra lep; a lista szelen
                                // a fokusz a keresobe ter vissza, nem szokik ki
                                // a tartalomba.
                                Keys.onUpPressed: (event) => {
                                    var previous = entryPress.nextItemInFocusChain(false)
                                    if (previous && previous.objectName === "settingsNavEntry") previous.forceActiveFocus()
                                    else searchField.forceInputFocus()
                                    event.accepted = true
                                }
                                Keys.onDownPressed: (event) => {
                                    var next = entryPress.nextItemInFocusChain(true)
                                    if (next && next.objectName === "settingsNavEntry") next.forceActiveFocus()
                                    event.accepted = true
                                }
                            }
                        }
                    }
                }
            }
        }

        Text {
            x: 24
            y: 12
            width: navigationScroll.width - 48
            visible: sidebar.matchingPages.length === 0
            text: "No settings match “" + sidebar.query.trim() + "”."
            textFormat: Text.PlainText
            color: sidebar.muted
            font.pixelSize: 11
            wrapMode: Text.WordWrap
        }
    }

    // A daemon allapota: nelkule a Hyprland-oldalak csak olvashatok.
    Item {
        id: footer

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 48

        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.top: parent.top
            height: 1
            color: sidebar.muted
            opacity: 0.14
        }

        Rectangle {
            id: statusDot

            anchors.left: parent.left
            anchors.leftMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            width: 8
            height: 8
            radius: 4
            color: sidebar.backendChecking ? sidebar.muted : (sidebar.backendOnline ? sidebar.accent : sidebar.warning)
        }

        Text {
            anchors.left: statusDot.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: sidebar.backendChecking
                ? "Connecting to the daemon…"
                : (sidebar.backendOnline ? "Vellum daemon connected" : "Daemon offline · read-only")
            color: sidebar.muted
            font.pixelSize: 11
            elide: Text.ElideRight
        }
    }

    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: sidebar.muted
        opacity: 0.14
    }
}
