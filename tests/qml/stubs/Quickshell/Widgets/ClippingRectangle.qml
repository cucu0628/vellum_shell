import QtQuick

// Tesztcsonk a Quickshell ClippingRectangle-jehez. Az igazi tipus a quickshell
// binarisba van forditva, ezert a qmltestrunner nem tolti be; a tesztekhez
// eleg egy vagott Rectangle, ami a gyerekeit ugyanugy hordozza.
Rectangle {
    clip: true
}
