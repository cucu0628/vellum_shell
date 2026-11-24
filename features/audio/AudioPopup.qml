import "." as AudioUi
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import "../../ui" as SharedUi

// A savbol lenyilo hangpanel. Harom reteg, fontossag szerint lefele:
// a kimenet (nev + valto, alatta a vastag fo csuszka a spektrummal), a
// mikrofon egyetlen sorban, vegul a hangot ado alkalmazasok. Nincsenek
// szakaszcimkek es kartyak: a csoportokat a sorrend es egy-egy elvalaszto
// valasztja el, a sorokat a sajat ikonjuk azonositja.
PanelWindow {
    id: audioWindow

    property var theme: null
    property bool opened: false
    property int barHeight: 26
    // A cava teljes spektruma (0..100); ures, ha nem szol zene.
    property var cavaSpectrum: []
    property bool outputPickerOpen: false
    property bool inputPickerOpen: false
    // A hangero felso hatara 100% (lasd core/AudioSummaryController): a
    // csuszkak teljes hossza ennyi, a gorgetes es a huzas sem megy folee.
    readonly property real maxVolume: 1.0
    readonly property color panelBg: theme ? theme.background : "#11130f"
    readonly property color panelFg: theme ? theme.foreground : "#e8ddc7"
    readonly property color panelAccent: theme ? theme.accent : "#b7372f"
    readonly property color mutedFg: theme && theme.muted ? theme.muted : "#958b7a"
    readonly property color inkBg: theme && theme.surface ? theme.surface : "#191b16"
    readonly property var audioNodes: Pipewire.ready ? Pipewire.nodes.values.filter((node) => {
        return node && node.audio;
    }) : []
    readonly property var outputDevices: audioNodes.filter((node) => {
        return !node.isStream && node.isSink;
    })
    readonly property var inputDevices: audioNodes.filter((node) => {
        return !node.isStream && !node.isSink;
    })
    // Streamnel a Quickshell `isSink`-je azt jelenti, hogy a stream egy
    // kimenetbe (sinkbe) jatszik: a lejatszo alkalmazas `isSink`, a felvevo nem.
    readonly property var playbackStreams: audioNodes.filter((node) => {
        return node.isStream && node.isSink;
    })
    // A kimenet monitorjat rogzito streamek (pl. a cava, egy "desktop audio"
    // forras) nem a mikrofont hasznaljak: azokat nem mutatjuk felvevokent.
    readonly property var recordingStreams: audioNodes.filter((node) => {
        return node.isStream && !node.isSink && !(node.properties && node.properties["stream.capture.sink"] === "true");
    })
    readonly property var currentOutput: currentDevice(outputDevices, true)
    readonly property var currentInput: currentDevice(inputDevices, false)
    readonly property string micUsers: streamNames(recordingStreams)
    readonly property bool inputMuted: currentInput && currentInput.audio ? currentInput.audio.muted : false

    // Az alkalmazasikonok feloldasa dragabb (temakereses, desktop-bejegyzesek):
    // a kulcs a stream azonosito tulajdonsagaibol all, igy egyszer fut le.
    property var iconCache: ({})

    function nodeTitle(node) {
        if (!node)
            return "Unknown";

        return node.description || node.nickname || node.name || ("Node " + node.id);
    }

    function nodeSubtitle(node) {
        if (!node)
            return "";

        var props = node.properties || {
        };
        return props["media.name"] || props["application.name"] || "";
    }

    function streamIcon(node) {
        if (!node)
            return "";

        var props = node.properties || {
        };
        var candidates = [props["application.icon-name"], props["application.process.binary"], props["application.name"], node.name].filter((value) => {
            return value && value !== "";
        });
        var key = candidates.join("|");
        if (iconCache[key] !== undefined)
            return iconCache[key];

        var path = "";
        for (var i = 0; i < candidates.length && path === ""; i++) {
            path = Quickshell.iconPath(candidates[i], true) || Quickshell.iconPath(candidates[i].toLowerCase(), true) || "";
        }
        for (var j = 0; j < candidates.length && path === ""; j++) {
            var entry = DesktopEntries.heuristicLookup(candidates[j]);
            if (entry && entry.icon)
                path = Quickshell.iconPath(entry.icon, true) || "";

        }
        iconCache[key] = path;
        return path;
    }

    // A mikrofont hasznalo alkalmazasok nevei, ismetles nelkul.
    function streamNames(streams) {
        var names = [];
        for (var i = 0; i < streams.length; i++) {
            var props = streams[i].properties || {
            };
            var name = props["application.name"] || nodeTitle(streams[i]);
            if (names.indexOf(name) === -1)
                names.push(name);

        }
        return names.join(", ");
    }

    // Eszkoz jele a PipeWire nevebol: fejhallgato, HDMI/kijelzo, USB, Bluetooth.
    function deviceGlyph(node, input) {
        var name = ((node && node.name) || "").toLowerCase() + " " + ((node && node.description) || "").toLowerCase();
        if (input)
            return name.indexOf("bluez") !== -1 ? "󰋎" : "󰍬";

        if (name.indexOf("bluez") !== -1 || name.indexOf("headphone") !== -1 || name.indexOf("headset") !== -1)
            return "󰋋";

        if (name.indexOf("hdmi") !== -1 || name.indexOf("displayport") !== -1)
            return "󰍹";

        return "󰓃";
    }

    function currentDevice(devices, output) {
        for (var i = 0; i < devices.length; i++) {
            if (output ? isDefaultOutput(devices[i]) : isDefaultInput(devices[i]))
                return devices[i];

        }
        return devices.length > 0 ? devices[0] : null;
    }

    function percent(node) {
        if (!node || !node.audio)
            return 0;

        return Math.round(Math.max(0, Math.min(maxVolume, node.audio.volume || 0)) * 100);
    }

    function volumeRatio(node) {
        if (!node || !node.audio)
            return 0;

        return Math.max(0, Math.min(1, (node.audio.volume || 0) / maxVolume));
    }

    function setVolume(node, value) {
        if (!node || !node.audio)
            return ;

        node.audio.volume = Math.max(0, Math.min(maxVolume, value));
    }

    function setVolumeFromX(node, x, width) {
        var clampedX = Math.max(0, Math.min(width, x));
        setVolume(node, (clampedX / Math.max(1, width)) * maxVolume);
    }

    function wheelVolume(node, wheel) {
        if (!node || !node.audio)
            return ;

        setVolume(node, (node.audio.volume || 0) + (wheel.angleDelta.y > 0 ? 0.05 : -0.05));
        wheel.accepted = true;
    }

    function toggleMute(node) {
        if (!node || !node.audio)
            return ;

        node.audio.muted = !node.audio.muted;
    }

    function isDefaultOutput(node) {
        return Pipewire.defaultAudioSink && node && Pipewire.defaultAudioSink.id === node.id;
    }

    function isDefaultInput(node) {
        return Pipewire.defaultAudioSource && node && Pipewire.defaultAudioSource.id === node.id;
    }

    function setDefaultOutput(node) {
        if (node)
            Pipewire.preferredDefaultAudioSink = node;

        outputPickerOpen = false;
    }

    function setDefaultInput(node) {
        if (node)
            Pipewire.preferredDefaultAudioSource = node;

        inputPickerOpen = false;
    }

    // A Settings Hang oldala: profilok, alkalmazasonkenti kimenet. Az ablakot a
    // shell nyitja (PopupCoordinator), ez a popup csak jelez.
    signal advancedRequested()

    onOpenedChanged: {
        if (!opened) {
            outputPickerOpen = false;
            inputPickerOpen = false;
        }
    }
    onOutputPickerOpenChanged: if (outputPickerOpen) inputPickerOpen = false
    onInputPickerOpenChanged: if (inputPickerOpen) outputPickerOpen = false
    visible: opened || sheet.reveal > 0
    color: "transparent"
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.namespace: "quickshell.audio"
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    PwObjectTracker {
        objects: audioWindow.audioNodes
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    MouseArea {
        anchors.fill: parent
        enabled: audioWindow.opened
        onClicked: audioWindow.opened = false
    }

    Item {
        id: content

        focus: audioWindow.opened
        Keys.onEscapePressed: {
            if (audioWindow.outputPickerOpen || audioWindow.inputPickerOpen) {
                audioWindow.outputPickerOpen = false;
                audioWindow.inputPickerOpen = false;
            } else {
                audioWindow.opened = false;
            }
        }
        anchors.right: parent.right
        anchors.rightMargin: 0
        enabled: audioWindow.opened
        // A sav aljahoz tapad: a panel a savbol nyilik le, nem lebeg alatta.
        y: audioWindow.barHeight
        width: Math.min(400, parent.width - 20)
        height: Math.min(parent.height - audioWindow.barHeight - 12, panelColumn.implicitHeight + 36)
        clip: true

        SharedUi.PopupFrame {
            id: sheet

            rightEar: false
            squareRight: true
            shown: audioWindow.opened
            anchors.fill: parent
            theme: audioWindow.theme

            MouseArea {
                anchors.fill: parent
                enabled: audioWindow.opened
                onClicked: (mouse) => {
                    return mouse.accepted = true;
                }
            }

            Flickable {
                anchors.fill: parent
                anchors.margins: 16
                anchors.bottomMargin: 20
                clip: true
                contentWidth: width
                contentHeight: panelColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height

                Column {
                    id: panelColumn

                    width: parent.width

                    SharedUi.PopupHeader {
                        width: parent.width
                        theme: audioWindow.theme
                        title: "Audio"
                        subtitle: Pipewire.ready ? "" : "Waiting for PipeWire"
                        trailingWidth: 84

                        SharedUi.HeaderChip {
                            anchors.fill: parent
                            anchors.bottomMargin: 6
                            theme: audioWindow.theme
                            label: "Advanced"
                            accessibleName: qsTr("Open sound settings")
                            onClicked: audioWindow.advancedRequested()
                        }

                    }

                    Text {
                        width: parent.width
                        height: 44
                        visible: Pipewire.ready && !audioWindow.currentOutput
                        verticalAlignment: Text.AlignVCenter
                        text: qsTr("No output devices found.")
                        color: audioWindow.mutedFg
                        font.pixelSize: 12
                    }

                    // Kimenet: a nev a valtoval, alatta a fo csuszka.
                    Column {
                        width: parent.width
                        visible: audioWindow.currentOutput !== null

                        AudioUi.DeviceRow {
                            width: parent.width
                            controller: audioWindow
                            node: audioWindow.currentOutput
                            input: false
                            canPick: audioWindow.outputDevices.length > 1
                            pickerOpen: audioWindow.outputPickerOpen
                            onPickerToggled: audioWindow.outputPickerOpen = !audioWindow.outputPickerOpen
                        }

                        AudioUi.DevicePicker {
                            width: parent.width
                            controller: audioWindow
                            devices: audioWindow.outputDevices
                            input: false
                            open: audioWindow.outputPickerOpen
                            onChosen: audioWindow.outputPickerOpen = false
                        }

                        Item {
                            width: 1
                            height: 8
                        }

                        AudioUi.MasterFader {
                            width: parent.width
                            controller: audioWindow
                            node: audioWindow.currentOutput
                            spectrum: audioWindow.cavaSpectrum
                        }

                    }

                    // Mikrofon: egyetlen sor, a sajat csuszkajaval. Ha egy
                    // alkalmazas hasznalja, a sor alcime nevezi meg.
                    Column {
                        width: parent.width
                        visible: audioWindow.currentInput !== null

                        SharedUi.GroupDivider {
                            width: parent.width
                            theme: audioWindow.theme
                        }

                        AudioUi.DeviceRow {
                            width: parent.width
                            controller: audioWindow
                            node: audioWindow.currentInput
                            input: true
                            showSlider: true
                            canPick: audioWindow.inputDevices.length > 1
                            pickerOpen: audioWindow.inputPickerOpen
                            subtitle: audioWindow.micUsers === "" ? "" : (audioWindow.inputMuted ? qsTr("Muted for %1") : qsTr("In use by %1")).arg(audioWindow.micUsers)
                            subtitleColor: audioWindow.inputMuted ? audioWindow.mutedFg : audioWindow.panelAccent
                            onPickerToggled: audioWindow.inputPickerOpen = !audioWindow.inputPickerOpen
                        }

                        AudioUi.DevicePicker {
                            width: parent.width
                            controller: audioWindow
                            devices: audioWindow.inputDevices
                            input: true
                            open: audioWindow.inputPickerOpen
                            onChosen: audioWindow.inputPickerOpen = false
                        }

                    }

                    // A hangot ado alkalmazasok, a sajat ikonjukkal.
                    Column {
                        width: parent.width
                        visible: audioWindow.playbackStreams.length > 0

                        SharedUi.GroupDivider {
                            width: parent.width
                            theme: audioWindow.theme
                        }

                        // ScriptModel: a PipeWire-csomopontok azonossag szerint
                        // egyeznek, igy egy hangero- vagy allapotvaltozas nem
                        // epiti ujra a sorokat.
                        Repeater {
                            model: ScriptModel { values: audioWindow.playbackStreams }

                            delegate: AudioUi.StreamRow {
                                required property var modelData

                                width: panelColumn.width
                                controller: audioWindow
                                node: modelData
                            }

                        }

                    }

                }

            }

        }

        Behavior on height {
            NumberAnimation {
                duration: 210
                easing.type: Easing.OutCubic
            }

        }

    }

}
