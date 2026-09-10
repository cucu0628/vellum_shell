import QtQuick
import QtTest
import "../../features/notifications" as Notifications
import "../../features/clipboard" as Clipboard

TestCase {
    name: "UntrustedText"
    when: windowShown
    width: 800
    height: 300

    readonly property string markup: '<a href="https://example.invalid/">untrusted</a>'

    Component {
        id: notificationComponent
        Notifications.NotificationEntryRow { width: 700 }
    }

    Component {
        id: clipboardComponent
        Clipboard.ClipboardResultRow { width: 700 }
    }

    function checkText(item, expected) {
        var count = 0
        if (item.text !== undefined && item.text === expected) {
            compare(item.textFormat, Text.PlainText)
            compare(item.linkAt(1, item.height / 2), "")
            count++
        }
        for (var i = 0; i < item.children.length; i++)
            count += checkText(item.children[i], expected)
        return count
    }

    function test_notification_text_is_literal() {
        var row = createTemporaryObject(notificationComponent, this, {
            entry: {appName: markup, summary: markup, body: markup, icon: "",
                time: "12:00", actions: [{text: markup}]}
        })
        verify(row !== null)
        verify(checkText(row, markup) >= 2)
        verify(checkText(row, markup.toUpperCase()) >= 1)
    }

    function test_clipboard_text_is_literal() {
        var row = createTemporaryObject(clipboardComponent, this, {
            entry: {title: markup, subtitle: "Clipboard history", isImage: false}
        })
        verify(row !== null)
        verify(checkText(row, markup) >= 1)
    }
}
