pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "../../ui" as SharedUi

// Hang: alapertelmezett ki- es bemenet, alkalmazasonkenti kimenet, es a
// hangkartyak profilja. A hangero es az eszkozvalasztas a Quickshell PipeWire
// szolgaltatasabol jon; a profil es az atiranyitas a backend `audio`
// modulja (lasd SoundController). A gyors hangero-allitas tovabbra is az Audio
// popup dolga, itt az van, amihez eddig pavucontrol kellett.
Flickable {
    id: page

    property var backend: null
    property var theme: null

    // A shell vezerloi 100%-nal megallnak (lasd core/AudioSummaryController).
    readonly property real maxVolume: 1.0
    readonly property string muted: theme && theme.muted ? theme.muted : "#958b7a"
    readonly property var audioNodes: Pipewire.ready ? Pipewire.nodes.values.filter((node) => node && node.audio) : []
    readonly property var outputs: audioNodes.filter((node) => !node.isStream && node.isSink)
    readonly property var inputs: audioNodes.filter((node) => !node.isStream && !node.isSink)
    // A kimenet monitorjat rogzito streamek (pl. a cava, egy felvevo "desktop
    // audio" forrasa) nem mikrofonrol vesznek fel: azokat itt nem iranyitjuk.
    readonly property var streams: audioNodes.filter((node) => node.isStream
        && !(node.properties && node.properties["stream.capture.sink"] === "true"))
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    // A globalis lista: a node-onkenti PwNodeLinkTracker a lejatszo streamekre
    // ures listat adott.
    readonly property var linkGroups: Pipewire.ready ? Pipewire.linkGroups.values : []
    readonly property var outputModel: deviceModel(outputs)
    readonly property var inputModel: deviceModel(inputs)

    function nodeTitle(node) {
        if (!node) return ""
        return node.description || node.nickname || node.name || ("Node " + node.id)
    }

    function deviceModel(nodes) {
        var model = []
        for (var i = 0; i < nodes.length; i++)
            model.push({ "label": nodeTitle(nodes[i]), "value": nodes[i].name })
        return model
    }

    // Lejatszasnal a stream a link forrasa, felvetelnel a celja; a masik veg
    // az eszkoz, amin most szol.
    function deviceFor(stream, recording) {
        for (var i = 0; i < linkGroups.length; i++) {
            var group = linkGroups[i]
            var self = recording ? group.target : group.source
            var other = recording ? group.source : group.target
            if (self && other && self.id === stream.id && !other.isStream) return other
        }
        return null
    }

    function nodeByName(nodes, name) {
        for (var i = 0; i < nodes.length; i++) {
            if (nodes[i].name === name) return nodes[i]
        }
        return null
    }

    function percent(node) {
        if (!node || !node.audio) return 0
        return Math.round(Math.max(0, Math.min(maxVolume, node.audio.volume || 0)) * 100)
    }

    function setPercent(node, value) {
        if (node && node.audio) node.audio.volume = Math.max(0, Math.min(maxVolume, value / 100))
    }

    function busLabel(bus) {
        switch (bus) {
        case "usb":
            return "USB"
        case "pci":
            return "Built-in or PCI card"
        case "bluetooth":
            return "Bluetooth"
        default:
            return bus || ""
        }
    }

    function profileModel(device) {
        var model = []
        var profiles = device.profiles || []
        for (var i = 0; i < profiles.length; i++) {
            var profile = profiles[i]
            var label = profile.description || profile.name
            if (profile.available === "no" && profile.name !== "off") label += " (unplugged)"
            model.push({ "label": label, "value": String(profile.index) })
        }
        return model
    }

    contentWidth: width
    contentHeight: column.height
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    // A profilvaltas, egy bedugott eszkoz vagy egy uj Bluetooth fejhallgato
    // node-okat hoz letre es torol: ilyenkor a kartyalista is frissul.
    readonly property int deviceNodeCount: outputs.length + inputs.length
    onDeviceNodeCountChanged: sound.scheduleRefresh()

    SoundController {
        id: sound

        backend: page.backend
    }

    PwObjectTracker {
        objects: page.audioNodes
    }

    Column {
        id: column

        width: page.width
        spacing: 24

        SettingsSection {
            width: parent.width
            theme: page.theme
            title: "Output"
            description: Pipewire.ready ? "Where sound plays by default" : "Waiting for PipeWire"

            SharedUi.SettingRow {
                theme: page.theme
                label: "Output device"
                description: "New sound goes here; applications you moved keep their own output."

                SharedUi.SettingSelect {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    theme: page.theme
                    model: page.outputModel
                    value: page.sink ? page.sink.name : ""
                    placeholder: "No output devices"
                    onActivated: (value) => {
                        var node = page.nodeByName(page.outputs, value)
                        if (node) Pipewire.preferredDefaultAudioSink = node
                    }
                }
            }

            SharedUi.SettingRow {
                theme: page.theme
                label: "Volume"
                enabled: page.sink !== null

                SharedUi.SettingSlider {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    theme: page.theme
                    from: 0
                    to: 100
                    stepSize: 1
                    suffix: "%"
                    value: page.percent(page.sink)
                    onMoved: (value) => page.setPercent(page.sink, value)
                    onCommitted: (value) => page.setPercent(page.sink, value)
                }
            }

            SharedUi.SettingRow {
                theme: page.theme
                label: "Mute output"
                enabled: page.sink !== null

                SharedUi.SettingToggle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    theme: page.theme
                    checked: page.sink && page.sink.audio ? page.sink.audio.muted : false
                    onToggled: (value) => {
                        if (page.sink && page.sink.audio) page.sink.audio.muted = value
                    }
                }
            }
        }

        SettingsSection {
            width: parent.width
            theme: page.theme
            title: "Input"
            description: "The microphone applications record from by default"

            SharedUi.SettingRow {
                theme: page.theme
                label: "Input device"

                SharedUi.SettingSelect {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    theme: page.theme
                    model: page.inputModel
                    value: page.source ? page.source.name : ""
                    placeholder: "No input devices"
                    onActivated: (value) => {
                        var node = page.nodeByName(page.inputs, value)
                        if (node) Pipewire.preferredDefaultAudioSource = node
                    }
                }
            }

            SharedUi.SettingRow {
                theme: page.theme
                label: "Input volume"
                enabled: page.source !== null

                SharedUi.SettingSlider {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    theme: page.theme
                    from: 0
                    to: 100
                    stepSize: 1
                    suffix: "%"
                    value: page.percent(page.source)
                    onMoved: (value) => page.setPercent(page.source, value)
                    onCommitted: (value) => page.setPercent(page.source, value)
                }
            }

            SharedUi.SettingRow {
                theme: page.theme
                label: "Mute microphone"
                enabled: page.source !== null

                SharedUi.SettingToggle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    theme: page.theme
                    checked: page.source && page.source.audio ? page.source.audio.muted : false
                    onToggled: (value) => {
                        if (page.source && page.source.audio) page.source.audio.muted = value
                    }
                }
            }
        }

        SettingsSection {
            width: parent.width
            theme: page.theme
            title: "Applications"
            description: "Send an application to a different device than the default"

            // ScriptModel: egy uj vagy megszuno stream nem epiti ujra a tobbi
            // sort. Sima tombbel minden valtozasnal az egesz lista ujraepult,
            // a tartalom egy pillanatra osszeesett, es a gorgetes visszaugrott.
            Repeater {
                model: ScriptModel {
                    values: page.streams
                }

                SharedUi.SettingRow {
                    id: streamRow

                    required property var modelData

                    readonly property var props: modelData.properties || ({})
                    // Streamnel az `isSink` a lejatszot jelenti (egy kimenetbe jatszik).
                    readonly property bool recording: !modelData.isSink
                    readonly property var device: page.deviceFor(modelData, recording)

                    theme: page.theme
                    label: props["application.name"] || page.nodeTitle(modelData)
                    description: (recording ? "Recording" : "Playing") + (props["media.name"] ? "  ·  " + props["media.name"] : "")
                    enabled: sound.available

                    SharedUi.SettingSelect {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        theme: page.theme
                        model: streamRow.recording ? page.inputModel : page.outputModel
                        value: streamRow.device ? streamRow.device.name : ""
                        placeholder: "Not connected"
                        onActivated: (value) => sound.moveStream(streamRow.modelData.id, value, streamRow.recording)
                    }
                }
            }

            Text {
                width: parent.width
                height: 44
                visible: page.streams.length === 0
                text: "No application is playing or recording sound right now."
                textFormat: Text.PlainText
                color: page.muted
                font.pixelSize: 12
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.WordWrap
            }
        }

        SettingsSection {
            width: parent.width
            theme: page.theme
            title: "Sound cards"
            description: "Pick which outputs a card offers, such as HDMI or analog, stereo or surround"

            Repeater {
                model: sound.devices

                SharedUi.SettingRow {
                    id: cardRow

                    required property var modelData

                    theme: page.theme
                    label: modelData.description
                    description: page.busLabel(modelData.bus)

                    SharedUi.SettingSelect {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        theme: page.theme
                        model: page.profileModel(cardRow.modelData)
                        value: cardRow.modelData.profile === null || cardRow.modelData.profile === undefined
                            ? ""
                            : String(cardRow.modelData.profile)
                        placeholder: "No profiles"
                        onActivated: (value) => sound.setProfile(cardRow.modelData.id, Number(value))
                    }
                }
            }

            Text {
                width: parent.width
                height: 44
                visible: sound.devices.length === 0 && !sound.loading
                text: !sound.available
                    ? "Sound card profiles need the Vellum daemon."
                    : (sound.error !== "" ? sound.error : "No sound cards were found.")
                textFormat: Text.PlainText
                color: page.muted
                font.pixelSize: 12
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.WordWrap
            }
        }

        Text {
            width: parent.width
            visible: sound.error !== "" && sound.devices.length > 0
            text: sound.error
            textFormat: Text.PlainText
            color: page.theme && page.theme.warning ? page.theme.warning : "#c9693f"
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }
    }
}
