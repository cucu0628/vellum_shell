import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

QtObject {
    id: root

    property string password: ""
    property string submittedPassword: ""
    property bool unlockInProgress: false
    property bool failed: false
    property string statusText: "Enter password"
    // A sajat PAM-konfigot (/etc/pam.d/vellum-shell) a setup.sh telepiti, sudo-val.
    // Ha hianyzik, a Quickshell el sem inditja a PamContextet, es a zarolas
    // feloldhatatlan lenne. Ilyenkor a rendszer `login` konfigjat hasznaljuk,
    // ami minden disztribucion megvan (a DMS is igy csinalja).
    property bool forceSystemLogin: false
    readonly property string pamConfig: ownPamConfig.loaded && !forceSystemLogin ? "vellum-shell" : "login"

    property FileView ownPamConfig: FileView {
        path: "/etc/pam.d/vellum-shell"
        printErrors: false
    }

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
        if (!pam.start() && !retryWithSystemLogin()) {
            unlockInProgress = false
            submittedPassword = ""
            failed = true
            statusText = "Authentication unavailable"
        }
    }

    // Ha a sajat konfig megvan, de megsem indul (serult, rossz include), egy
    // masodik probalkozas a `login` konfiggal.
    function retryWithSystemLogin() {
        if (pamConfig === "login") return false
        console.warn("Lock: a vellum-shell PAM-konfig nem indul, visszaesunk a login konfigra")
        forceSystemLogin = true
        return pam.start()
    }

    property PamContext pam: PamContext {
        config: root.pamConfig
        configDirectory: "/etc/pam.d"
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
