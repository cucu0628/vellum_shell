import QtQuick
import Quickshell.Io

Item {
    id: controller

    required property string shellDir
    property string pendingMode: ""
    // Egy fuggo (pl. beragadt) kijeloles nem blokkolhatja a kovetkezo Printet:
    // ilyenkor leallitjuk, es a leallas utan indul az uj.
    property bool restartPending: false

    function start() {
        captureProcess.command = [shellDir + "/scripts/screenshot-capture", pendingMode]
        captureProcess.running = true
    }

    width: 0
    height: 0
    visible: false

    function capture(mode) {
        pendingMode = mode
        captureDelay.restart()
    }

    Timer {
        id: captureDelay
        interval: 40
        onTriggered: {
            if (captureProcess.running) {
                controller.restartPending = true
                captureProcess.running = false
                return
            }
            controller.start()
        }
    }

    Process {
        id: captureProcess

        onRunningChanged: {
            if (!running && controller.restartPending) {
                controller.restartPending = false
                controller.start()
            }
        }
    }
}
