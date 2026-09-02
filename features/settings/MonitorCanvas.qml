pragma ComponentBehavior: Bound

import QtQuick

// Windows-szeru kijelzo-elrendezes. A monitorokat kicsinyitve rajzoljuk, es
// huzassal lehet athelyezni oket. Elengedeskor a legkozelebbi elhez pattannak,
// hogy ne maradjon res vagy atfedes -- a Hyprland ilyet elfogadna, de a
// gyakorlatban mindig hibanak bizonyul.
Item {
    id: canvas

    clip: true

    property var theme: null
    property var monitors: []
    // A huzas alatti pozicio felulirasa: output -> { x, y }. A commit utan urul.
    property var overrides: ({})
    property string selectedOutput: ""
    // Huzas kozben a kezdeti keretezest rogzitjuk, hogy a vaszon ne mozduljon
    // el a pointer alatt. Elengedes utan mar az elonezeti elrendezest meretezzuk.
    property bool dragActive: false
    property var dragBounds: null

    readonly property string foreground: theme ? theme.foreground : "#e8ddc7"
    readonly property string accent: theme ? theme.accent : "#b7372f"
    readonly property string muted: theme && theme.muted ? theme.muted : "#958b7a"
    readonly property string surface: theme && theme.surface ? theme.surface : "#1b1613"

    // A zoom alapja csak a backendtol kapott elrendezes. Huzas kozben ezt nem
    // szabad az override-okkal ujraszamolni, kulonben a teljes vaszon elmozdul
    // a pointer alatt.
    readonly property var baseLayout: {
        var boxes = [];
        for (var i = 0; i < monitors.length; i++) {
            var monitor = monitors[i];
            if (monitor.disabled)
                continue;

            // A Hyprland a logikai meretet a skalaval osztva adja vissza; az
            // elrendezes ugyanebben a logikai terben ertelmes.
            var scale = monitor.scale > 0 ? monitor.scale : 1;
            boxes.push({
                "name": monitor.name,
                "x": monitor.x,
                "y": monitor.y,
                "width": Math.round(monitor.width / scale),
                "height": Math.round(monitor.height / scale)
            });
        }
        return boxes;
    }

    // Elemenkent a tenyleges (esetleg huzott) pozicio es meret.
    readonly property var layout: {
        var boxes = [];
        for (var i = 0; i < baseLayout.length; i++) {
            var base = baseLayout[i];
            var override = overrides[base.name];
            boxes.push({
                "name": base.name,
                "x": override ? override.x : base.x,
                "y": override ? override.y : base.y,
                "width": base.width,
                "height": base.height
            });
        }
        return boxes;
    }

    readonly property var bounds: dragActive && dragBounds
        ? dragBounds
        : calculateBounds(layout)

    function calculateBounds(boxes) {
        if (boxes.length === 0)
            return {
                "minX": 0,
                "minY": 0,
                "width": 1,
                "height": 1
            };

        var minX = boxes[0].x;
        var minY = boxes[0].y;
        var maxX = boxes[0].x + boxes[0].width;
        var maxY = boxes[0].y + boxes[0].height;
        for (var i = 1; i < boxes.length; i++) {
            minX = Math.min(minX, boxes[i].x);
            minY = Math.min(minY, boxes[i].y);
            maxX = Math.max(maxX, boxes[i].x + boxes[i].width);
            maxY = Math.max(maxY, boxes[i].y + boxes[i].height);
        }
        return {
            "minX": minX,
            "minY": minY,
            "width": Math.max(1, maxX - minX),
            "height": Math.max(1, maxY - minY)
        };
    }

    function beginDrag() {
        dragBounds = calculateBounds(layout);
        dragActive = true;
    }

    function endDrag() {
        dragActive = false;
        dragBounds = null;
    }

    // Egy kozos meretarany mindket tengelyre, hogy a kepernyok aranya ne torzuljon.
    readonly property real zoom: Math.min((width - 40) / bounds.width, (height - 40) / bounds.height)
    readonly property real offsetX: (width - bounds.width * zoom) / 2 - bounds.minX * zoom
    readonly property real offsetY: (height - bounds.height * zoom) / 2 - bounds.minY * zoom

    signal selected(string output)
    signal moved(string output, int x, int y)
    signal previewCleared

    function boxFor(name) {
        for (var i = 0; i < layout.length; i++) {
            if (layout[i].name === name)
                return layout[i];

        }
        return null;
    }

    function setOverride(name, x, y) {
        // Egyszerre egy elrendezes-modositast tartunk elonezetben. Ha a
        // felhasznalo masik kijelzot kezd huzni Apply elott, az elozo huzas
        // helyett az uj lesz a fuggoben levo valtoztatas.
        var next = {};
        next[name] = {
            "x": x,
            "y": y
        };
        overrides = next;
    }

    function clearOverrides() {
        overrides = ({});
    }

    // A huzott kijelzot a legkozelebbi szomszed elehez igazitja, ha 120 logikai
    // pixelen belul van. Ket tengelyen kulon dontunk, igy sarokba is illeszkedik.
    function snap(name, rawX, rawY, originX, originY) {
        var moving = boxFor(name);
        if (!moving)
            return {
                "x": rawX,
                "y": rawY
            };

        var threshold = 120;
        var x = rawX;
        var y = rawY;

        for (var i = 0; i < layout.length; i++) {
            var other = layout[i];
            if (other.name === name)
                continue;

            var candidatesX = [other.x + other.width, other.x - moving.width, other.x];
            for (var a = 0; a < candidatesX.length; a++) {
                if (Math.abs(rawX - candidatesX[a]) < threshold) {
                    x = candidatesX[a];
                    break;
                }
            }

            var candidatesY = [other.y + other.height, other.y - moving.height, other.y];
            for (var b = 0; b < candidatesY.length; b++) {
                if (Math.abs(rawY - candidatesY[b]) < threshold) {
                    y = candidatesY[b];
                    break;
                }
            }
        }

        // Az elpattintas utan sem maradhat ket monitor egymason. A fo huzasi
        // tengely donti el, hogy vizszintesen vagy fuggolegesen valasztjuk szet
        // oket; a kozeppont pedig azt, melyik kulso oldalra keruljon.
        for (var j = 0; j < layout.length; j++) {
            var neighbour = layout[j];
            if (neighbour.name === name)
                continue;

            var overlapsX = x < neighbour.x + neighbour.width && x + moving.width > neighbour.x;
            var overlapsY = y < neighbour.y + neighbour.height && y + moving.height > neighbour.y;
            if (!overlapsX || !overlapsY)
                continue;

            var horizontalDrag = Math.abs(rawX - originX) >= Math.abs(rawY - originY);
            if (horizontalDrag) {
                var movingCenterX = rawX + moving.width / 2;
                var neighbourCenterX = neighbour.x + neighbour.width / 2;
                x = movingCenterX < neighbourCenterX
                    ? neighbour.x - moving.width
                    : neighbour.x + neighbour.width;
            } else {
                var movingCenterY = rawY + moving.height / 2;
                var neighbourCenterY = neighbour.y + neighbour.height / 2;
                y = movingCenterY < neighbourCenterY
                    ? neighbour.y - moving.height
                    : neighbour.y + neighbour.height;
            }
        }

        return {
            "x": Math.round(x),
            "y": Math.round(y)
        };
    }

    Rectangle {
        anchors.fill: parent
        color: canvas.surface
        opacity: 0.35
        border.color: canvas.muted
        border.width: 1
    }

    Text {
        anchors.centerIn: parent
        visible: canvas.layout.length === 0
        text: "No active displays"
        color: canvas.muted
        font.pixelSize: 11
    }

    Repeater {
        // A modell huzas kozben nem valtozhat: ha az override-bol kepzett uj
        // tomb lenne itt, a Repeater eldobna a delegate-et es vele az aktiv
        // pointer grabet meg az egermozdulat felengedese elott.
        model: canvas.baseLayout

        Rectangle {
            id: screenBox

            required property var modelData

            readonly property bool isSelected: screenBox.modelData.name === canvas.selectedOutput
            readonly property var currentBox: canvas.boxFor(screenBox.modelData.name) || screenBox.modelData

            x: canvas.offsetX + screenBox.currentBox.x * canvas.zoom
            y: canvas.offsetY + screenBox.currentBox.y * canvas.zoom
            width: Math.max(24, screenBox.modelData.width * canvas.zoom)
            height: Math.max(18, screenBox.modelData.height * canvas.zoom)
            color: screenBox.isSelected ? Qt.rgba(0, 0, 0, 0.25) : "transparent"
            border.color: screenBox.isSelected ? canvas.accent : canvas.muted
            border.width: screenBox.isSelected ? 2 : 1

            Column {
                anchors.centerIn: parent
                spacing: 2

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: screenBox.modelData.name
                    color: screenBox.isSelected ? canvas.accent : canvas.foreground
                    font.pixelSize: 11
                    font.bold: true
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: screenBox.modelData.width + " × " + screenBox.modelData.height
                    color: canvas.muted
                    font.family: "monospace"
                    font.pixelSize: 9
                }

            }

            MouseArea {
                id: dragArea

                property real pressCanvasX: 0
                property real pressCanvasY: 0
                property int originX: 0
                property int originY: 0
                property bool dragged: false

                anchors.fill: parent
                cursorShape: pressed && dragged ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                onPressed: (mouse) => {
                    var point = dragArea.mapToItem(canvas, mouse.x, mouse.y);
                    canvas.beginDrag();
                    canvas.selected(screenBox.modelData.name);
                    pressCanvasX = point.x;
                    pressCanvasY = point.y;
                    originX = screenBox.currentBox.x;
                    originY = screenBox.currentBox.y;
                    dragged = false;
                }
                onPositionChanged: (mouse) => {
                    if (!pressed)
                        return ;

                    var point = dragArea.mapToItem(canvas, mouse.x, mouse.y);
                    // Egy sima kivalasztashoz is tartozik nehany tort pixeles
                    // pointermozgas. Csak a tenyleges huzast tekintjuk
                    // monitorelrendezes-valtoztatasnak.
                    var canvasDx = point.x - pressCanvasX;
                    var canvasDy = point.y - pressCanvasY;
                    if (!dragged && Math.sqrt(canvasDx * canvasDx + canvasDy * canvasDy) < 4)
                        return ;

                    dragged = true;
                    var dx = canvasDx / canvas.zoom;
                    var dy = canvasDy / canvas.zoom;
                    canvas.setOverride(screenBox.modelData.name, Math.round(originX + dx), Math.round(originY + dy));
                }
                onReleased: {
                    if (!dragged) {
                        canvas.endDrag();
                        return ;
                    }

                    var box = canvas.boxFor(screenBox.modelData.name);
                    if (!box) {
                        canvas.endDrag();
                        return ;
                    }

                    var snapped = canvas.snap(screenBox.modelData.name, box.x, box.y, originX, originY);
                    if (snapped.x === originX && snapped.y === originY) {
                        canvas.clearOverrides();
                        canvas.endDrag();
                        canvas.previewCleared();
                        return ;
                    }
                    canvas.setOverride(screenBox.modelData.name, snapped.x, snapped.y);
                    canvas.endDrag();
                    canvas.moved(screenBox.modelData.name, snapped.x, snapped.y);
                }
                onCanceled: {
                    canvas.endDrag();
                    if (!dragged)
                        return ;

                    canvas.clearOverrides();
                    canvas.previewCleared();
                }
            }

        }

    }

}
