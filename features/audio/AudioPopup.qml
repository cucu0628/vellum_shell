import "." as AudioUi
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import "../../ui" as SharedUi

PanelWindow {
    id: audioWindow

    property var theme: null
    property bool opened: false
    property int barHeight: 26
    property bool outputPickerOpen: false
    property bool inputPickerOpen: false
    // A hangero felso hatara 100% (lasd core/AudioSummaryController): a
    // csuszkak teljes hossza ennyi, a gorgetes es a huzas sem megy folee.
    readonly property real maxVolume: 1.0
    readonly property string panelBg: theme ? theme.background : "#15110f"
    readonly property string panelFg: theme ? theme.foreground : "#f1e7d0"
    readonly property string panelAccent: theme ? theme.accent : "#d7472f"
    readonly property string mutedFg: theme && theme.muted ? theme.muted : "#9f8f7c"
    readonly property string inkBg: theme && theme.surface ? theme.surface : "#1b1613"
    readonly property var audioNodes: Pipewire.ready ? Pipewire.nodes.values.filter((node) => {
        return node && node.audio;
    }) : []
    readonly property var outputDevices: audioNodes.filter((node) => {
        return !node.isStream && node.isSink;
    })
    readonly property var inputDevices: audioNodes.filter((node) => {
        return !node.isStream && !node.isSink;
    })
    readonly property var playbackStreams: audioNodes.filter((node) => {
        return node.isStream && !node.isSink;
    })
    readonly property var recordingStreams: audioNodes.filter((node) => {
        return node.isStream && node.isSink;
    })
    readonly property var currentOutputDevices: currentDevices(outputDevices, true)
    readonly property var currentInputDevices: currentDevices(inputDevices, false)
    readonly property var otherOutputDevices: otherDevices(outputDevices, currentOutputDevices.length > 0 ? currentOutputDevices[0] : null)
    readonly property var otherInputDevices: otherDevices(inputDevices, currentInputDevices.length > 0 ? currentInputDevices[0] : null)
    readonly property int streamCount: playbackStreams.length + recordingStreams.length

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

    function currentDevices(devices, output) {
        for (var i = 0; i < devices.length; i++) {
            if (output ? isDefaultOutput(devices[i]) : isDefaultInput(devices[i]))
                return [devices[i]];

        }
        return devices.length > 0 ? [devices[0]] : [];
    }

    function otherDevices(devices, current) {
        var result = [];
        for (var i = 0; i < devices.length; i++) {
            if (!current || devices[i].id !== current.id)
                result.push(devices[i]);

        }
        return result;
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

    function launchAdvanced() {
        launcher.command = ["pavucontrol"];
        launcher.running = true;
    }

    onOpenedChanged: {
        if (!opened) {
            outputPickerOpen = false;
            inputPickerOpen = false;
        }
    }
    visible: opened || sheet.reveal > 0
    color: "transparent"
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.namespace: "quickshell.audio"
    WlrLayershell.exclusiveZone: -1

    PwObjectTracker {
        objects: audioWindow.audioNodes
    }

    Process {
        id: launcher
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

        anchors.right: parent.right
        anchors.rightMargin: 0
        enabled: audioWindow.opened
        // A sav aljahoz tapad: a panel a savbol nyilik le, nem lebeg alatta.
        y: audioWindow.barHeight
        width: Math.min(420, parent.width - 20)
        height: Math.min(parent.height - audioWindow.barHeight - 12, panelColumn.implicitHeight + 32)
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
                clip: true
                contentWidth: width
                contentHeight: panelColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height

                Column {
                    id: panelColumn

                    width: parent.width
                    spacing: 12

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
                            accessibleName: qsTr("Open advanced audio settings")
                            onClicked: launchAdvanced()
                        }

                    }

                    // Kimenet: szakaszcim a valto gombbal, alatta az eszkozkartya.
                    Column {
                        width: parent.width
                        spacing: 4

                        SharedUi.SectionBar {
                            width: parent.width
                            theme: audioWindow.theme
                            title: "OUTPUT"

                            SharedUi.HeaderChip {
                                visible: otherOutputDevices.length > 0
                                theme: audioWindow.theme
                                label: outputPickerOpen ? "Done" : "Change"
                                checked: outputPickerOpen
                                accessibleName: qsTr("Choose output device")
                                onClicked: outputPickerOpen = !outputPickerOpen
                            }

                        }

                        // ScriptModel: a PipeWire-csomopontok azonossag szerint
                        // egyeznek, igy egy hangero- vagy allapotvaltozas nem
                        // epiti ujra a kartyakat es sorokat.
                        Repeater {
                            model: ScriptModel { values: currentOutputDevices }

                            delegate: AudioUi.DeviceCard {
                                width: panelColumn.width
                                controller: audioWindow
                                node: modelData
                                input: false
                                others: otherOutputDevices
                                expanded: outputPickerOpen
                            }

                        }

                        AudioUi.EmptyCard {
                            width: parent.width
                            controller: audioWindow
                            visible: outputDevices.length === 0
                            height: visible ? 52 : 0
                            message: Pipewire.ready ? "No output devices" : "PipeWire is not ready"
                        }

                    }

                    Column {
                        width: parent.width
                        spacing: 4

                        SharedUi.SectionBar {
                            width: parent.width
                            theme: audioWindow.theme
                            title: "INPUT"

                            SharedUi.HeaderChip {
                                visible: otherInputDevices.length > 0
                                theme: audioWindow.theme
                                label: inputPickerOpen ? "Done" : "Change"
                                checked: inputPickerOpen
                                accessibleName: qsTr("Choose input device")
                                onClicked: inputPickerOpen = !inputPickerOpen
                            }

                        }

                        Repeater {
                            model: ScriptModel { values: currentInputDevices }

                            delegate: AudioUi.DeviceCard {
                                width: panelColumn.width
                                controller: audioWindow
                                node: modelData
                                input: true
                                others: otherInputDevices
                                expanded: inputPickerOpen
                            }

                        }

                        AudioUi.EmptyCard {
                            width: parent.width
                            controller: audioWindow
                            visible: inputDevices.length === 0
                            height: visible ? 52 : 0
                            message: Pipewire.ready ? "No input devices" : "PipeWire is not ready"
                        }

                    }

                    // Lejatszo es felvevo alkalmazasok egy listaban.
                    Column {
                        width: parent.width
                        spacing: 4
                        visible: audioWindow.streamCount > 0

                        SharedUi.SectionBar {
                            width: parent.width
                            theme: audioWindow.theme
                            title: "APPS"
                            detail: String(audioWindow.streamCount)
                        }

                        Repeater {
                            model: ScriptModel { values: playbackStreams }

                            delegate: AudioUi.StreamRow {
                                width: panelColumn.width
                                controller: audioWindow
                                node: modelData
                                input: false
                            }

                        }

                        Repeater {
                            model: ScriptModel { values: recordingStreams }

                            delegate: AudioUi.StreamRow {
                                width: panelColumn.width
                                controller: audioWindow
                                node: modelData
                                input: true
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
