import QtQuick
import Quickshell
import Quickshell.Services.Pam

QtObject {
    id: root

    property string password: ""
    property string submittedPassword: ""
    property bool unlockInProgress: false
    property bool failed: false
    property string statusText: "Enter password"

    signal succeeded()

    function reset() {
        password = ""
        submittedPassword = ""
        unlockInProgress = false
        failed = false
        statusText = "Enter password"
    }

    function tryUnlock() {
        if (password === "" || unlockInProgress) return
        submittedPassword = password
        unlockInProgress = true
        failed = false
        statusText = "Checking..."
        if (!pam.start()) {
            unlockInProgress = false
            submittedPassword = ""
            failed = true
            statusText = "Authentication unavailable"
        }
    }

    property PamContext pam: PamContext {
        config: "vellum-shell"
        user: Quickshell.env("USER")

        onPamMessage: {
            if (responseRequired) respond(root.submittedPassword)
        }

        onCompleted: (result) => {
            root.unlockInProgress = false
            if (result === PamResult.Success) {
                root.succeeded()
            } else {
                root.submittedPassword = ""
                root.password = ""
                root.failed = true
                root.statusText = result === PamResult.MaxTries ? "Too many attempts" : "Wrong password"
            }
        }

        onError: (error) => {
            root.unlockInProgress = false
            root.submittedPassword = ""
            root.password = ""
            root.failed = true
            root.statusText = PamError.toString(error)
        }
    }
}
