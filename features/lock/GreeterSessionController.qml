import QtQuick
import Quickshell.Services.Greetd

// A greetd beszelgetes. A felulet jelszo-elso: a felhasznalo eloszor begepeli
// a jelszot, es csak az Enter inditja a munkamenetet -- igy a greeter ugyanugy
// viselkedik, mint a zarolokepernyo. Ha a PAM meg valamit ker (OTP, uj jelszo),
// az a mezo helyorzojeben jelenik meg, es a kovetkezo Enter arra valaszol.
QtObject {
    id: root

    readonly property bool available: Greetd.available
    property bool busy: false
    property bool failed: false
    property string statusText: "Enter password"
    // Egy masodik PAM-kerdes szovege, amire a felhasznalo valaszat varjuk.
    property string prompt: ""
    readonly property bool awaitingAnswer: prompt !== ""

    property string pendingSecret: ""
    property bool hasPendingSecret: false

    signal readyToLaunch()
    signal launched()
    signal rejected()

    function reset() {
        cancel()
        failed = false
        statusText = "Enter password"
    }

    function submit(user, secret) {
        failed = false
        busy = true
        statusText = "Checking..."

        if (awaitingAnswer) {
            prompt = ""
            Greetd.respond(secret)
            return
        }

        if (Greetd.state !== GreetdState.Inactive) Greetd.cancelSession()
        pendingSecret = secret
        hasPendingSecret = true
        Greetd.createSession(user)
    }

    function cancel() {
        forgetSecret()
        prompt = ""
        busy = false
        if (Greetd.available && Greetd.state !== GreetdState.Inactive) Greetd.cancelSession()
    }

    // `quit` hamis: a kilepest a greeter maga intezi, a felengedo animacio utan.
    function launch(command, environment) {
        statusText = "Starting session..."
        Greetd.launch(command, environment, false)
    }

    function forgetSecret() {
        pendingSecret = ""
        hasPendingSecret = false
    }

    function fail(message) {
        forgetSecret()
        prompt = ""
        busy = false
        failed = true
        statusText = message
        rejected()
    }

    property Connections greetd: Connections {
        target: Greetd

        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (responseRequired) {
                // Az elso titkos kerdes a mar begepelt jelszo.
                if (root.hasPendingSecret && !echoResponse) {
                    var secret = root.pendingSecret
                    root.forgetSecret()
                    Greetd.respond(secret)
                    return
                }

                root.forgetSecret()
                root.busy = false
                root.prompt = message !== "" ? message : "Response"
                root.statusText = root.prompt
                return
            }

            if (message !== "") {
                root.statusText = message
                root.failed = error
            }
        }

        function onAuthFailure(message) {
            root.fail("Wrong password")
        }

        function onError(error) {
            root.fail(error !== "" ? error : "Sign-in failed")
        }

        function onReadyToLaunch() {
            root.readyToLaunch()
        }

        function onLaunched() {
            root.launched()
        }
    }
}
