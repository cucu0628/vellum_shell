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
    readonly property string panelBg: theme ? theme.background : "#15110f"
    readonly property string panelFg: theme ? theme.foreground : "#f1e7d0"
    readonly property string panelAccent: theme ? theme.accent : "#d7472f"
    readonly property string mutedFg: theme && theme.muted ? theme.muted : "#9f8f7c"
    readonly property string inkBg: theme && theme.surface ? theme.surface : "#1b1613"
    readonly property color hoverBg: Qt.rgba(1, 1, 1, 0.075)
    readonly property color lineBg: Qt.rgba(1, 1, 1, 0.055)
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
        return props["application.name"] || props["media.name"] || node.name || "";
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

        return Math.round(Math.max(0, Math.min(1.5, node.audio.volume || 0)) * 100);
    }

    function volumeRatio(node) {
        if (!node || !node.audio)
            return 0;

        return Math.max(0, Math.min(1, (node.audio.volume || 0) / 1.5));
    }

    function setVolume(node, ratio) {
        if (!node || !node.audio)
            return ;

        node.audio.volume = Math.max(0, Math.min(1.5, ratio));
    }

    function setVolumeFromX(node, x, width) {
        var clampedX = Math.max(0, Math.min(width, x));
        setVolume(node, (clampedX / Math.max(1, width)) * 1.5);
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
        width: Math.min(560, parent.width - 20)
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
                    spacing: 8

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

                    AudioUi.SectionHeader {
                        width: parent.width
                        controller: audioWindow
                        title: "OUTPUT"
                    }

                    Repeater {
                        model: currentOutputDevices

                        delegate: AudioUi.DeviceCard {
                            width: panelColumn.width
                            controller: audioWindow
                            node: modelData
                            input: false
                            active: audioWindow.isDefaultOutput(modelData)
                            others: otherOutputDevices
                            expanded: outputPickerOpen
                            onToggleExpanded: outputPickerOpen = !outputPickerOpen
                        }

                    }

                    AudioUi.EmptyCard {
                        width: parent.width
                        controller: audioWindow
                        visible: outputDevices.length === 0
                        height: visible ? 48 : 0
                        message: Pipewire.ready ? "No output devices" : "PipeWire is not ready"
                    }

                    AudioUi.SectionHeader {
                        width: parent.width
                        controller: audioWindow
                        title: "INPUT"
                    }

                    Repeater {
                        model: currentInputDevices

                        delegate: AudioUi.DeviceCard {
                            width: panelColumn.width
                            controller: audioWindow
                            node: modelData
                            input: true
                            active: audioWindow.isDefaultInput(modelData)
                            others: otherInputDevices
                            expanded: inputPickerOpen
                            onToggleExpanded: inputPickerOpen = !inputPickerOpen
                        }

                    }

                    AudioUi.EmptyCard {
                        width: parent.width
                        controller: audioWindow
                        visible: inputDevices.length === 0
                        height: visible ? 48 : 0
                        message: Pipewire.ready ? "No input devices" : "PipeWire is not ready"
                    }

                    // Lejatszo es felvevo alkalmazasok egy listaban.
                    AudioUi.SectionHeader {
                        width: parent.width
                        controller: audioWindow
                        title: "APPS"
                        visible: playbackStreams.length + recordingStreams.length > 0
                        height: visible ? 24 : 0
                    }

                    Column {
                        width: parent.width
                        spacing: 2
                        visible: playbackStreams.length + recordingStreams.length > 0

                        Repeater {
                            model: playbackStreams

                            delegate: AudioUi.StreamRow {
                                width: parent.width
                                controller: audioWindow
                                node: modelData
                                input: false
                            }

                        }

                        Repeater {
                            model: recordingStreams

                            delegate: AudioUi.StreamRow {
                                width: parent.width
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
