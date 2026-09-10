import QtQuick
import QtTest
import "../../ui" as SharedUi

TestCase {
    name: "Pressable"
    when: windowShown
    width: 200
    height: 100

    SharedUi.Pressable {
        id: button
        width: 100
        height: 40
        accessibleName: "Test action"
        property int activations: 0
        onClicked: activations++
    }

    function init() {
        button.activations = 0;
        button.forceActiveFocus();
        verify(button.activeFocus);
    }

    function test_space_activates() {
        keyClick(Qt.Key_Space);
        compare(button.activations, 1);
    }

    function test_return_activates() {
        keyClick(Qt.Key_Return);
        compare(button.activations, 1);
    }

}
