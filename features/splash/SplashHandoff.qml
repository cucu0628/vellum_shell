import QtQuick
import Quickshell

// A fo shell oldala: amint az asztal all (a hatterkep minden kijelzon latszik),
// szol az inditokepernyonek, hogy usszon ki. Ha az nem fut -- pl. a shell egy
// temavaltas vagy osszeomlas utan indult ujra --, a hivas csendben elhal.
// Ha a hatterkep nem jon meg (nincs backend, nincs kep), a tartalek idozito szol.
Item {
    id: handoff

    required property string shellDir
    property bool desktopReady: false
    property bool notified: false

    width: 0
    height: 0
    visible: false

    function notify() {
        if (notified || shellDir === "") return
        notified = true
        Quickshell.execDetached([
            "quickshell", "ipc", "--path", shellDir + "/SplashShell.qml",
            "call", "splash", "dismiss"
        ])
    }

    onDesktopReadyChanged: if (desktopReady) settleTimer.restart()

    // A bar es a tobbi felulet az elso kepkockait meg rajzolja: egy kis ido,
    // hogy a lap alatt mar a teljes asztal legyen.
    Timer {
        id: settleTimer

        interval: 250
        onTriggered: handoff.notify()
    }

    Timer {
        running: true
        interval: 6000
        onTriggered: handoff.notify()
    }
}
