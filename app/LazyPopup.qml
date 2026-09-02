import QtQuick

Item {
    id: lazyPopup

    property Component popupComponent
    property bool opened: false
    property bool loaded: false
    property bool unloadOnClose: true
    property var screen: null
    property string mode: ""
    readonly property var popup: popupLoader.item

    // Amig a popup egy muveletet vezet (pl. temaalkalmazas), nem bontjuk le.
    //
    // Enelkul a 300 ms-os unload timer megsemmisitette a controllert, mielott a
    // backend valasza megerkezett volna: a callback egy mar nem letezo
    // objektumba futott, es a hibakezeles -- a visszaallitas az eredeti temara --
    // sosem futott le.
    readonly property bool busy: popup && popup.busy === true

    width: 0
    height: 0
    visible: false

    onOpenedChanged: {
        if (opened) {
            unloadTimer.stop()
            loaded = true
            if (popup) popup.opened = true
        } else {
            if (popup) popup.opened = false
            if (unloadOnClose) unloadTimer.restart()
        }
    }

    onScreenChanged: {
        if (popup && screen !== null) popup.screen = screen
    }

    Timer {
        id: unloadTimer
        interval: 300
        onTriggered: {
            if (lazyPopup.opened) return
            if (lazyPopup.busy) {
                // Meg fut valami: varunk vele, nem hagyjuk el a callbackjet.
                restart()
                return
            }
            if (lazyPopup.popup && lazyPopup.popup.releaseResources)
                lazyPopup.popup.releaseResources()
            lazyPopup.loaded = false
        }
    }

    Loader {
        id: popupLoader
        active: lazyPopup.loaded
        asynchronous: true
        sourceComponent: lazyPopup.popupComponent

        onLoaded: {
            item.opened = lazyPopup.opened
            if (lazyPopup.screen !== null) item.screen = lazyPopup.screen
        }
    }

    Connections {
        target: popupLoader.item
        enabled: popupLoader.item !== null
        ignoreUnknownSignals: true

        function onOpenedChanged() {
            if (popupLoader.item.opened !== lazyPopup.opened)
                lazyPopup.opened = popupLoader.item.opened
        }

        function onScreenChanged() {
            if (popupLoader.item.screen !== lazyPopup.screen)
                lazyPopup.screen = popupLoader.item.screen
        }
    }
}
