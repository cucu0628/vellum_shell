import QtQuick
import Quickshell.Services.Pipewire

Item {
    id: controller

    // A hangero felso hatara 100%: e folott a PipeWire szoftveresen erositi a
    // jelet, ami torzit. A shell vezerloi eddig engednek, es amit mas allit e
    // fole (billentyu, wpctl, pavucontrol), azt az alapertelmezett kimeneten
    // visszahuzza.
    readonly property real maxVolume: 1.0
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property int volumePercent: sink && sink.audio
        ? Math.round(Math.max(0, Math.min(maxVolume, sink.audio.volume || 0)) * 100)
        : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property string deviceName: sink ? (sink.description || sink.nickname || sink.name || "") : ""

    width: 0
    height: 0
    visible: false

    function stepVolume(increase) {
        if (!sink || !sink.audio) return
        sink.audio.volume = Math.max(0, Math.min(maxVolume,
            (sink.audio.volume || 0) + (increase ? 0.05 : -0.05)))
    }

    function toggleMute() {
        if (sink && sink.audio) sink.audio.muted = !sink.audio.muted
    }

    function toggleMicMute() {
        if (source && source.audio) source.audio.muted = !source.audio.muted
    }

    function clampSink() {
        if (sink && sink.audio && sink.audio.volume > maxVolume + 0.001)
            sink.audio.volume = maxVolume
    }

    onSinkChanged: clampSink()

    Connections {
        target: controller.sink ? controller.sink.audio : null

        function onVolumesChanged() {
            controller.clampSink()
        }
    }

    PwObjectTracker {
        objects: [controller.sink, controller.source].filter(node => node !== null && node !== undefined)
    }
}
