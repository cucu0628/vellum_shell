import "." as LauncherUi
import "../../ui" as SharedUi
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: launcherWindow

    property var theme: null
    required property string homeDir
    required property string shellDir
    property bool opened: false
    property int barHeight: 26
    property string query: ""
    property int selectedIndex: 0
    property string calcResult: ""
    property bool suppressHoverSelection: false
    property var applications: []
    property var projects: []
    property var delayedActionCommand: []
    // A Terminal=true bejegyzesek gazdaja: a core TerminalController, vagyis a
    // Settings > Default apps-ban valasztott terminal. Nelkule a kitty marad.
    property var terminal: null
    // A visszafordithatatlan muveletek elso Enterre csak kijelolodnek; a
    // masodik inditja el oket. -1, ha nincs ilyen fuggoben.
    property int pendingConfirmIndex: -1
    readonly property string panelBg: theme ? theme.background : "#15110f"
    readonly property string panelFg: theme ? theme.foreground : "#f1e7d0"
    readonly property string panelAccent: theme ? theme.accent : "#d7472f"
    readonly property string mutedFg: theme && theme.muted ? theme.muted : "#9f8f7c"
    readonly property string inkBg: theme && theme.surface ? theme.surface : "#1b1613"
    // Az egyetlen megmaradt prefix. A projektek azert kulon mod, mert a talalat
    // egy konyvtar, nem inditando muvelet -- kulonben minden mappanev
    // beleszolna az alkalmazaskeresesbe.
    readonly property bool projectMode: query.trim().startsWith(">")
    readonly property bool hasQuery: query.trim() !== ""
    readonly property string projectQuery: projectMode ? query.trim().slice(1).trim() : ""
    // Prefix helyett alakfelismeres: ami matek kifejezesnek nez ki, az a qalc-hoz
    // megy. Igy a szamolas nem kulon mod, csak egy talalat a kozos listaban.
    readonly property string calcExpression: projectMode ? "" : mathExpression(query)
    readonly property string modeTitle: projectMode ? "Projects" : (hasQuery ? "Search" : "Applications")
    readonly property var searchResults: buildResults(query)
    readonly property var visibleItems: projectMode ? projectItems() : searchResults
    readonly property bool listVisible: hasQuery || visibleItems.length > 0
    readonly property real resultsHeight: visibleItems.length > 0 ? visibleItems.length * 46 - 2 : 44

    function refreshApplications() {
        applications = DesktopEntries.applications.values.slice();
    }

    function refreshProjects() {
        if (projectsProcess.running)
            return ;

        projectsProcess.command = ["find", homeDir + "/Projects", "-mindepth", "1", "-maxdepth", "1", "-type", "d", "!", "-name", ".*", "-print"];
        projectsProcess.running = true;
    }

    function parseProjects(output) {
        var lines = (output || "").trim().split("\n");
        var result = [];
        for (var i = 0; i < lines.length; i++) {
            var path = lines[i].trim();
            if (path === "")
                continue;

            result.push({
                "type": "project",
                "title": path.slice(path.lastIndexOf("/") + 1),
                "subtitle": path,
                "path": path
            });
        }
        result.sort((a, b) => a.title.localeCompare(b.title));
        projects = result;
    }

    function resetLauncher() {
        suppressHoverSelection = false;
        query = "";
        searchField.text = "";
        selectedIndex = 0;
        calcResult = "";
        resultsList.contentY = 0;
        calcTimer.stop();
        clearConfirm();
    }

    function normalize(value) {
        return (value || "").toString().toLowerCase().replace(/[^a-z0-9]+/g, " ").trim();
    }

    function words(value) {
        var normalized = normalize(value);
        return normalized === "" ? [] : normalized.split(/\s+/);
    }

    function scoreApp(app, queryWords) {
        var name = normalize(app.name);
        var generic = normalize(app.genericName);
        var comment = normalize(app.comment);
        var id = normalize(app.id);
        var haystack = (name + " " + generic + " " + comment + " " + id).trim();
        var score = appStatScore(app);
        for (var i = 0; i < queryWords.length; i++) {
            var word = queryWords[i];
            if (name === word)
                score += 130;
            else if (name.startsWith(word))
                score += 90;
            else if (name.indexOf(word) >= 0)
                score += 55;
            else if (generic.indexOf(word) >= 0)
                score += 30;
            else if (id.indexOf(word) >= 0)
                score += 20;
            else if (haystack.indexOf(word) >= 0)
                score += 10;
            else
                return 0;
        }
        return score;
    }

    // Az egyetlen osszefesulo pont: alkalmazas, muvelet, emoji es szamolas
    // ugyanabba a pontszamozott listaba kerul, es egyszer rendezodik.
    function buildResults(value) {
        if (projectMode)
            return [];

        var queryWords = words(value);
        var browsingApps = queryWords.length === 0;

        var matches = [];
        // A szamolas eredmenye mindig legfelul all: ha a lekerdezes egyaltalan
        // matek volt, akkor azt kerestuk.
        if (calcResult !== "")
            matches.push({
            "item": {
                "type": "calc",
                "title": calcResult,
                "subtitle": calcExpression
            },
            "score": 100000
        });

        var apps = applications;
        for (var i = 0; i < apps.length; i++) {
            var app = apps[i];
            var score = browsingApps ? appStatScore(app) + 1 : scoreApp(app, queryWords);
            if (score > 0)
                matches.push({
                "app": app,
                "score": score
            });

        }
        if (browsingApps) {
            matches.sort((a, b) => {
                return b.score - a.score || itemSortName(a).localeCompare(itemSortName(b));
            });
            var browsingResult = [];
            for (var b = 0; b < matches.length && b < 50; b++) browsingResult.push({
                "type": "app",
                "app": matches[b].app
            })
            var browsingActions = launcherActions.items;
            for (var ba = 0; ba < browsingActions.length; ba++) browsingResult.push({
                "type": "action",
                "action": browsingActions[ba]
            })
            return browsingResult;
        }
        var actions = launcherActions.items;
        for (var a = 0; a < actions.length; a++) {
            var actionScore = scoreAction(actions[a], queryWords);
            if (actionScore > 0)
                matches.push({
                "item": {
                    "type": "action",
                    "action": actions[a]
                },
                "score": actionScore
            });

        }
        var emojis = emojiData.items;
        for (var e = 0; e < emojis.length; e++) {
            var emojiScore = scoreEmoji(emojis[e], queryWords);
            if (emojiScore > 0)
                matches.push({
                "item": {
                    "type": "emoji",
                    "emoji": emojis[e]
                },
                "score": emojiScore
            });

        }
        matches.sort((a, b) => {
            return b.score - a.score || itemSortName(a).localeCompare(itemSortName(b));
        });
        var result = [];
        for (var j = 0; j < matches.length && j < 50; j++) result.push(matches[j].item || {
            "type": "app",
            "app": matches[j].app
        })
        return result;
    }

    // Prefix nelkul kell eldonteni, hogy a beirt szoveg szamolas-e. Csak akkor
    // az, ha szammal, zarojellel vagy ismert fuggvennyel kezdodik, ES van benne
    // operator vagy zarojel -- egy puszta "2024" evszam igy nem lesz talalat.
    function mathExpression(value) {
        var text = (value || "").trim();
        if (text.length < 3)
            return "";

        if (!/^[0-9(.+-]/.test(text) && !/^(sqrt|sin|cos|tan|log|ln|abs|exp|pow)\b/i.test(text))
            return "";

        if (!/[+\-*\/^%()]/.test(text))
            return "";

        // Betuk csak fuggveny- vagy mertekegysegnevkent fordulhatnak elo; egy
        // "grep -r foo/bar" alaku szoveg igy nem megy at a qalc-on.
        return /^[0-9a-z\s.,+\-*\/^%()]+$/i.test(text) ? text : "";
    }

    function appStatScore(app) {
        return frecencyStore.score(app);
    }

    function itemSortName(match) {
        if (match.app)
            return match.app.name;

        if (match.item && match.item.type === "action")
            return match.item.action.name;

        if (match.item && match.item.type === "emoji")
            return match.item.emoji.name;

        return "";
    }

    function scoreAction(action, queryWords) {
        if (queryWords.length === 0)
            return 0;

        var name = normalize(action.name);
        var haystack = normalize(action.name + " " + action.terms.join(" "));
        var score = 15;
        for (var i = 0; i < queryWords.length; i++) {
            var word = queryWords[i];
            if (name === word)
                score += 140;
            else if (name.startsWith(word))
                score += 100;
            else if (haystack.indexOf(word) >= 0)
                score += 45;
            else
                return 0;
        }
        return score;
    }

    // Szandekosan szigorubb az alkalmazas-pontozasnal: laza reszszo-egyezesre
    // nem adunk talalatot, kulonben minden "fi" kezdetu keresesbe beleszolna
    // egy emoji. Csak egesz szavas vagy erteles prefix egyezes szamit.
    function scoreEmoji(emoji, queryWords) {
        if (queryWords.length === 0)
            return 0;

        var name = normalize(emoji.name);
        var nameWords = name === "" ? [] : name.split(" ");
        var keywords = words(emoji.keywords);
        var score = 0;
        for (var i = 0; i < queryWords.length; i++) {
            var word = queryWords[i];
            if (name === word)
                score += 120;
            else if (nameWords.indexOf(word) >= 0)
                score += 90;
            else if (word.length >= 3 && name.startsWith(word))
                score += 80;
            else if (keywords.indexOf(word) >= 0)
                score += 60;
            else
                return 0;
        }
        return score;
    }

    function projectItems() {
        var queryWords = words(projectQuery);
        var result = [];
        for (var i = 0; i < projects.length; i++) {
            var project = projects[i];
            var haystack = normalize(project.title + " " + project.path);
            var matches = true;
            for (var j = 0; j < queryWords.length; j++) {
                if (haystack.indexOf(queryWords[j]) === -1) {
                    matches = false;
                    break;
                }
            }
            if (matches)
                result.push(project);
        }
        return result;
    }

    function itemTitle(item) {
        if (!item)
            return "";

        if (item.type === "app")
            return item.app ? (item.app.name || item.app.id || "Application") : "Application";

        if (item.type === "action")
            return item.action ? item.action.name : "";

        if (item.type === "emoji")
            return item.emoji ? item.emoji.emoji + "  " + item.emoji.name : "";

        return item.title || "";
    }

    function itemSubtitle(item) {
        if (!item)
            return "";

        if (item.type === "app")
            return item.app ? (item.app.genericName || item.app.comment || item.app.id || "") : "";

        if (item.type === "action")
            return item.action ? item.action.subtitle : "";

        if (item.type === "emoji")
            return item.emoji ? "Copy " + item.emoji.name : "";

        return item.subtitle || "";
    }

    function itemIcon(item) {
        if (!item)
            return "";

        if (item.type === "calc")
            return "󰃬";

        if (item.type === "hint")
            return "󰋼";

        if (item.type === "project")
            return "󰉋";

        if (item.type === "action")
            return item.action ? item.action.icon : "";

        if (item.type === "emoji")
            return item.emoji ? item.emoji.emoji : "";

        return "";
    }

    // A Quickshell `execute()` nem tud a Terminal=true bejegyzesekkel mit
    // kezdeni: TTY nelkul inditja el oket, igy az nvim es minden mas TUI ablak
    // nelkul, arva folyamatkent maradna a hatterben. Ezeket sajat
    // terminalablakban inditjuk.
    function launchApp(app) {
        if (app.runInTerminal === true) {
            var command = terminalArgv(app);
            if (command.length > 0) {
                Quickshell.execDetached(command);
                return ;
            }
        }
        app.execute();
    }

    // A `command` a mar szetbontott, mezokodok (%f, %U, ...) nelkuli parancs.
    // Ha a Quickshell nem tudta ertelmezni az Exec sort, a nyers szoveg a
    // tartalek -- olyankor a shell bontja szet.
    function terminalArgv(app) {
        var parsed = app.command || [];
        var command = [];
        for (var i = 0; i < parsed.length; i++) {
            command.push(parsed[i]);
        }
        if (command.length > 0)
            return terminalCommand(command);

        var exec = (app.execString || "").replace(/%[fFuUdDnNickvm]/g, "").replace(/%%/g, "%").trim();
        if (exec === "")
            return [];

        return terminalCommand(["sh", "-c", exec]);
    }

    function terminalCommand(command) {
        return terminal ? terminal.argv(command) : ["kitty", "--"].concat(command);
    }

    // A muveleteket lecsatolva inditjuk, nem `Process`-kent: a Quickshell a
    // sajat gyerekfolyamatait leallaskor kilovi, a "refresh shell" pedig eppen
    // ezt a peldanyt allitja le. Managed gyerekkent a script a `kill` es az uj
    // peldany inditasa kozott halt meg -- innen jott a "neha nem indul ujra".
    // A popup 300 ms utani lebontasa (LazyPopup) ugyanigy elvitte volna.
    function runAction(command) {
        if (!command || command.length === 0)
            return ;

        Quickshell.execDetached(command);
    }

    function activateSelected() {
        if (visibleItems.length === 0)
            return ;

        var index = Math.max(0, Math.min(selectedIndex, visibleItems.length - 1));
        var item = visibleItems[index];
        if (item.type === "app") {
            launchApp(item.app);
            frecencyStore.record(item.app.id || item.app.name);
            opened = false;
        } else if (item.type === "calc" && calcResult !== "") {
            copyProcess.command = ["wl-copy", "--", calcResult];
            copyProcess.running = true;
            opened = false;
        } else if (item.type === "project" && item.path) {
            Quickshell.execDetached(["code", item.path]);
            opened = false;
        } else if (item.type === "action") {
            // A kikapcsolas-jellegu muveleteknel az elso Enter csak felvillantja
            // a sort; a masodik inditja el. A varakozas 2.2 masodperc utan jar le.
            if (item.action.confirm === true && pendingConfirmIndex !== index) {
                pendingConfirmIndex = index;
                confirmTimer.restart();
                return ;
            }
            clearConfirm();
            if (item.action.delay === true) {
                delayedActionCommand = item.action.command;
                opened = false;
                delayedActionTimer.restart();
            } else {
                runAction(item.action.command);
                opened = false;
            }
        } else if (item.type === "emoji") {
            copyProcess.command = ["wl-copy", "--", item.emoji.emoji];
            copyProcess.running = true;
            opened = false;
        }
    }

    function clearConfirm() {
        confirmTimer.stop();
        pendingConfirmIndex = -1;
    }

    function shellQuote(value) {
        return "'" + value.replace(/'/g, "'\\''") + "'";
    }

    function modeActive(prefix) {
        return prefix === ">" ? projectMode : !projectMode;
    }

    function selectMode(prefix) {
        searchField.text = prefix;
        query = prefix;
        searchField.forceInputFocus();
    }

    function cycleMode(reverse) {
        var prefixes = ["", ">"];
        var current = 0;
        for (var i = 0; i < prefixes.length; i++) {
            if (modeActive(prefixes[i])) {
                current = i;
                break;
            }
        }
        var direction = reverse ? -1 : 1;
        selectMode(prefixes[(current + direction + prefixes.length) % prefixes.length]);
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
        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            cycleMode(event.key === Qt.Key_Backtab || (event.modifiers & Qt.ShiftModifier));
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
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
        }
    }

    // Alaphelyzet nyitaskor, nem zaraskor: a felcsuszo lapon meg a zaras
    // elotti talalatok maradnak, nem egy kiurult lista.
    onOpenedChanged: {
        if (opened) {
            resetLauncher();
            refreshApplications();
            refreshProjects();
            focusTimer.start();
        }
    }
    Component.onCompleted: {
        refreshApplications();
        refreshProjects();
    }
    onQueryChanged: {
        suppressHoverSelection = false;
        selectedIndex = 0;
        resultsList.contentY = 0;
        clearConfirm();
    }
    // A szamolast a kifejezes valtozasa inditja, nem a nyers lekerdezese. Az
    // `onQueryChanged`-ben olvasva a `calcExpression` meg a korabbi erteket adna:
    // a szarmaztatott binding ujraertekelese es a valtozaskezelo sorrendje nem
    // garantalt.
    onCalcExpressionChanged: {
        // A regi eredmeny nem tartozik az uj kifejezeshez, ezert azonnal megy.
        calcResult = "";
        if (calcExpression === "") {
            calcTimer.stop();
            return ;
        }
        calcTimer.restart();
    }
    // A megerositesre varo sorrol ellepve a varakozas ervenyet veszti: kulonben
    // a kijeloles mar mashol lenne, de a regi sor meg "AGAIN"-t mutatna.
    onSelectedIndexChanged: clearConfirm()
    onVisibleItemsChanged: {
        selectedIndex = Math.max(0, Math.min(selectedIndex, Math.max(visibleItems.length - 1, 0)));
        clampResultsScroll();
    }
    visible: opened || sheet.reveal > 0
    color: "transparent"
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.namespace: "quickshell.launcher"
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
        onTriggered: searchField.forceInputFocus()
    }

    Timer {
        id: confirmTimer

        interval: 2200
        onTriggered: launcherWindow.pendingConfirmIndex = -1
    }

    Timer {
        id: calcTimer

        interval: 120
        onTriggered: {
            calcProcess.command = ["qalc", "-t", calcExpression];
            calcProcess.running = true;
        }
    }

    Timer {
        id: delayedActionTimer

        interval: 260
        onTriggered: {
            if (!launcherWindow.delayedActionCommand || launcherWindow.delayedActionCommand.length === 0)
                return;

            var command = launcherWindow.delayedActionCommand;
            launcherWindow.delayedActionCommand = [];
            launcherWindow.runAction(command);
        }
    }

    Process {
        id: calcProcess

        stdout: StdioCollector {
            onStreamFinished: calcResult = (this.text || "").trim().split("\n")[0] || ""
        }

    }

    Process {
        id: copyProcess
    }

    Process {
        id: projectsProcess

        stdout: StdioCollector {
            onStreamFinished: launcherWindow.parseProjects(this.text || "")
        }
    }

    LauncherUi.LauncherActions {
        id: launcherActions
        homeDir: launcherWindow.homeDir
        shellDir: launcherWindow.shellDir
        terminal: launcherWindow.terminal
    }

    LauncherUi.EmojiData {
        id: emojiData
    }

    LauncherUi.FrecencyStore {
        id: frecencyStore
    }

    LauncherUi.DesktopIconResolver {
        id: iconResolver
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
        y: launcherWindow.barHeight
        enabled: opened
        width: Math.min(720, launcherWindow.width - 32)
        // Csak a keresosor: 16 felso margo + 40 sor + 12 also margo = 68.
        // Listaval meg: 12 terkoz + 1 vonal + 12 terkoz a lista folott,
        // alatta 12 terkoz + 16 labsor = 121 + lista.
        height: listVisible ? Math.min(520, launcherWindow.height - launcherWindow.barHeight - 12, 121 + Math.max(44, resultsHeight)) : 68
        clip: true

        SharedUi.PopupFrame {
            id: sheet

            anchors.fill: parent
            theme: launcherWindow.theme
            shown: launcherWindow.opened

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

                // Kereso es modvalaszto egy sorban: a ket mod ket csendes chip.
                Item {
                    width: parent.width
                    height: 40

                    SharedUi.SearchField {
                        id: searchField

                        anchors.left: parent.left
                        anchors.right: modeSwitch.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        opened: launcherWindow.opened
                        indicator: projectMode ? ">" : "⌕"
                        placeholder: projectMode ? "Search projects in ~/Projects..." : "Search apps, actions and emoji..."
                        surface: inkBg
                        foreground: panelFg
                        accent: panelAccent
                        muted: mutedFg
                        onTextEdited: (text) => {
                            return query = text;
                        }
                        onKeyPressed: (event) => {
                            return handleKey(event);
                        }
                    }

                    Row {
                        id: modeSwitch

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Repeater {
                            model: [{
                                "label": "Search",
                                "prefix": ""
                            }, {
                                "label": "Projects",
                                "prefix": ">"
                            }]

                            SharedUi.HeaderChip {
                                required property var modelData

                                theme: launcherWindow.theme
                                label: modelData.label
                                checkable: true
                                checked: modeActive(modelData.prefix)
                                accessibleName: qsTr("%1 mode").arg(modelData.label)
                                onClicked: selectMode(modelData.prefix)
                            }

                        }

                    }

                }

                Rectangle {
                    visible: listVisible
                    width: parent.width
                    height: 1
                    color: mutedFg
                    opacity: 0.14
                }

                // A lista kitolti, ami a fejresz es a labsor kozott marad.
                Item {
                    visible: listVisible
                    width: parent.width
                    height: Math.max(0, parent.height - y - footer.height - parent.spacing)

                    Text {
                        visible: visibleItems.length === 0
                        anchors.centerIn: parent
                        text: projectMode ? "No projects found in ~/Projects" : "No results"
                        color: mutedFg
                        font.pixelSize: 11
                    }

                    ListView {
                        id: resultsList

                        anchors.fill: parent
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        visible: visibleItems.length > 0
                        interactive: contentHeight > height
                        model: launcherWindow.visible ? visibleItems : []
                        spacing: 2
                        reuseItems: true
                        cacheBuffer: 92

                        delegate: LauncherUi.LauncherResultRow {
                            width: ListView.view.width - (resultsList.interactive ? 8 : 0)
                            result: modelData
                            resultIndex: index
                            selected: index === selectedIndex
                            pendingConfirm: index === pendingConfirmIndex
                            hoverSelectionEnabled: !suppressHoverSelection
                            title: itemTitle(modelData)
                            subtitle: itemSubtitle(modelData)
                            glyph: itemIcon(modelData)
                            appIconSource: modelData.type === "app" ? iconResolver.resolve(modelData.app) : ""
                            appFallbackIcon: iconResolver.fallbackIcon(modelData.app)
                            foregroundColor: panelFg
                            accentColor: panelAccent
                            mutedColor: mutedFg
                            selectionColor: inkBg
                            onHoverRequested: (rowIndex) => {
                                selectedIndex = rowIndex;
                            }
                            onActivationRequested: (rowIndex) => {
                                suppressHoverSelection = false;
                                selectedIndex = rowIndex;
                                activateSelected();
                            }
                        }

                    }

                    // Csak a csuszka latszik, savja nincs: gorgetheto listanal
                    // ennyi jelzes eleg.
                    Rectangle {
                        anchors.right: parent.right
                        width: 2
                        radius: 1
                        height: resultsList.visible && resultsList.contentHeight > 0 ? Math.max(24, parent.height * resultsList.visibleArea.heightRatio) : 0
                        y: resultsList.visible ? resultsList.visibleArea.yPosition * parent.height : 0
                        color: mutedFg
                        opacity: resultsList.visible && resultsList.interactive ? 0.5 : 0

                        Behavior on y {
                            NumberAnimation {
                                duration: 140
                                easing.type: Easing.OutCubic
                            }

                        }

                    }

                }

                Item {
                    id: footer

                    visible: listVisible
                    width: parent.width
                    height: 16

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: modeTitle + "  ·  " + visibleItems.length
                        color: mutedFg
                        font.pixelSize: 10
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "↑↓ select   ↵ open   tab mode   esc close"
                        color: mutedFg
                        font.family: "monospace"
                        font.pixelSize: 9
                    }

                }

            }

        }

        Behavior on height {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }

        }

    }

}
