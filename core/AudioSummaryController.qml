import QtQuick
import Quickshell.Services.Pipewire

Item {
    id: controller

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property int volumePercent: sink && sink.audio
        ? Math.round(Math.max(0, Math.min(1.5, sink.audio.volume || 0)) * 100)
        : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false

    width: 0
    height: 0
    visible: false

    function stepVolume(increase) {
        if (!sink || !sink.audio) return
        sink.audio.volume = Math.max(0, Math.min(1.5,
            (sink.audio.volume || 0) + (increase ? 0.05 : -0.05)))
    }

    function toggleMute() {
        if (sink && sink.audio) sink.audio.muted = !sink.audio.muted
    }

    function toggleMicMute() {
        if (source && source.audio) source.audio.muted = !source.audio.muted
    }

    PwObjectTracker {
        objects: [controller.sink, controller.source].filter(node => node !== null && node !== undefined)
    }
}
