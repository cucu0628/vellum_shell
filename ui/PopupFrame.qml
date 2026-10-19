import QtQuick

// A popupok kozos hattere. Alapertelmezesben a felso sav folytatasa: ugyanaz a
// szin, a sav aljanal homoru ivvel (a "ful") no ki belole, az also sarkai a
// Hyprland-ablakokhoz illo kerekitest kapnak. Igy a panel a savbol nyilo
// fioknak latszik, nem alatta lebego kartyanak.
//
// Nyitaskor a lap teljes meretben csuszik le a sav mogul (a szulo vagja le a
// sav feletti reszt), a tartalom pedig kicsit kesobb usztatva jelenik meg.
// A magassagot nem animaljuk: igy a tartalom nem tordelodik ujra minden
// kepkockaban, es az also kerete sem "huzodik" a lappal.
//
// A fulek a szulo szelessegebol veszik el a helyet: a lap testje a ket ful
// kozott van. A kepernyo szelere tapado panelnel azon az oldalon a ful
// elmarad (leftEar/rightEar: false).
//
// `edge: "bottom"` a tukorkep: a lap a kepernyo aljahoz tapad, onnan csuszik
// fel, a felso sarkai kerekek, a fulek alul vannak (pl. az Appearance dokk).
Item {
    id: frame

    property var theme: null
    // false: kulonallo (pl. kozepre tett) panel, minden sarka kerekitett,
    // minden oldalan kerettel, fulek nelkul.
    property bool attached: true
    // Melyik kepernyoszelhez tapad: "top" (a sav ala) vagy "bottom".
    property string edge: "top"
    readonly property bool fromBottom: edge === "bottom"
    property bool leftEar: true
    property bool rightEar: true
    // A kepernyo szelere tapado oldalon a szabad sarok is szogletes marad, igy a
    // lap a kepernyoszellel egy vonalban er veget (pl. a jobb oldali panelek).
    property bool squareLeft: false
    property bool squareRight: false
    // A lap lathato-e. A szulo popup `opened` allapotat kell ide kotni.
    property bool shown: true
    // 0 = a sav mogott, 1 = teljesen lenyitva.
    property real reveal: 0
    // false: a lap animacio nelkul all at (pl. ha egy masik panel veszi at a helyet).
    property bool animated: true
    // A Hyprland `decoration:rounding` erteke; a panel sarkai ehhez igazodnak.
    property int cornerRadius: 12
    default property alias content: contentLayer.data

    readonly property string background: theme ? theme.background : "#11130f"
    // A kontur szine. Kulonallo panelnel allapotot is jelezhet (pl. polkit).
    property color edgeColor: Qt.rgba(1, 1, 1, 0.08)
    readonly property int leftInset: attached && leftEar ? cornerRadius : 0
    readonly property int rightInset: attached && rightEar ? cornerRadius : 0

    function syncReveal() {
        revealAnimation.stop()
        if (!animated) {
            reveal = shown ? 1 : 0
            return
        }
        revealAnimation.to = shown ? 1 : 0
        revealAnimation.duration = shown ? 340 : 200
        revealAnimation.easing.type = shown ? Easing.OutQuint : Easing.InCubic
        revealAnimation.start()
    }

    onShownChanged: syncReveal()
    // Lusta betoltesnel a popup mar nyitva jon letre: kulon el kell inditani
    // a nyitast, kulonben az elso megjelenes animacio nelkul ugrana be.
    Component.onCompleted: syncReveal()

    NumberAnimation {
        id: revealAnimation

        target: frame
        property: "reveal"
    }

    Item {
        id: sheet

        x: frame.leftInset
        width: frame.width - frame.leftInset - frame.rightInset
        height: frame.height
        // Teljesen elrejtve nem rajzolunk: a "sav moge csusztatott" lap kulonben
        // ott maradna a sav folott, ha a szulo nem vagja le.
        visible: frame.reveal > 0
        // Kulonallo panel nem a sav mogul jon, csak finoman a helyere usztat.
        opacity: frame.attached ? 1 : frame.reveal
        transform: Translate {
            y: !frame.attached
                ? (1 - frame.reveal) * -12
                : (frame.fromBottom ? 1 : -1) * (1 - frame.reveal) * frame.height
        }

        // Egy pixellel nagyobb, kerekitett lap a test mogott: a szabad oldalakon
        // halvany kontur lesz belole. A tapado oldalon a fulek magassagaig nem
        // er el, hogy a kepernyoszel (vagy a sav) menten ne fusson vonal.
        Rectangle {
            readonly property bool roundTop: !frame.attached || frame.fromBottom
            readonly property bool roundBottom: !frame.attached || !frame.fromBottom

            // A tapado oldalon csak akkor all meg a kontur, ha ott ful folytatja.
            readonly property int earGap: frame.attached && (frame.leftEar || frame.rightEar) ? frame.cornerRadius : 0

            x: -1
            y: frame.attached && !frame.fromBottom ? earGap : -1
            width: parent.width + 2
            height: frame.attached && frame.fromBottom
                ? parent.height + 1 - earGap
                : parent.height + 1 - y
            color: frame.edgeColor
            topLeftRadius: roundTop && !frame.squareLeft ? frame.cornerRadius + 1 : 0
            topRightRadius: roundTop && !frame.squareRight ? frame.cornerRadius + 1 : 0
            bottomLeftRadius: roundBottom && !frame.squareLeft ? frame.cornerRadius + 1 : 0
            bottomRightRadius: roundBottom && !frame.squareRight ? frame.cornerRadius + 1 : 0
        }

        Rectangle {
            id: body

            readonly property bool roundTop: !frame.attached || frame.fromBottom
            readonly property bool roundBottom: !frame.attached || !frame.fromBottom

            anchors.fill: parent
            color: frame.background
            topLeftRadius: roundTop && !frame.squareLeft ? frame.cornerRadius : 0
            topRightRadius: roundTop && !frame.squareRight ? frame.cornerRadius : 0
            bottomLeftRadius: roundBottom && !frame.squareLeft ? frame.cornerRadius : 0
            bottomRightRadius: roundBottom && !frame.squareRight ? frame.cornerRadius : 0

            // A tema elo elonezetenel (Appearance) a szin puhan valt.
            Behavior on color { ColorAnimation { duration: 190; easing.type: Easing.OutCubic } }
        }

        Item {
            id: contentLayer

            anchors.fill: parent
            clip: true
            // A tartalom a lap utan erkezik: a mozgas elso harmadaban meg atlatszo,
            // es nehany pixellel feljebbrol ul a helyere.
            opacity: Math.max(0, Math.min(1, (frame.reveal - 0.3) / 0.7))
            transform: Translate {
                y: (1 - frame.reveal) * (frame.fromBottom ? 8 : -8)
            }
        }
    }

    // A homoru atmenet a sav aljabol a lap oldalaba. Nem attetszoseggel jelenik
    // meg, hanem a merete koveti a lap lathato reszet: amig a lap lekerekitett
    // alja meg a sav kozeleben jar, nincs ful; utana a kovetkezo nehany tiz
    // pixelen 0-rol teljes meretre no -- zaraskor ugyanez visszafele. Igy a ful
    // sosem logg "szellemkent" egy felig lathato lap folott.
    readonly property real earScale: attached
        ? Math.max(0, Math.min(1, (reveal * height - cornerRadius) / (cornerRadius * 3)))
        : 0

    Repeater {
        model: frame.attached ? [frame.leftEar, frame.rightEar] : []

        Canvas {
            id: ear

            required property int index
            required property bool modelData
            readonly property bool isLeft: index === 0
            readonly property color fill: body.color
            readonly property color stroke: frame.edgeColor

            visible: modelData && frame.earScale > 0
            x: isLeft ? frame.leftInset - frame.cornerRadius : frame.width - frame.rightInset
            y: frame.fromBottom ? frame.height - frame.cornerRadius : 0
            width: frame.cornerRadius
            height: frame.cornerRadius
            // A teljes meretu ivet a lap oldala es a kepernyoszel talalkozasahoz
            // huzzuk ossze: az alakja allando, csak a merete valtozik.
            transform: Scale {
                origin.x: ear.isLeft ? ear.width : 0
                origin.y: frame.fromBottom ? ear.height : 0
                xScale: frame.earScale
                yScale: frame.earScale
            }

            onFillChanged: requestPaint()
            onStrokeChanged: requestPaint()
            onWidthChanged: requestPaint()
            Component.onCompleted: requestPaint()

            onPaint: {
                var ctx = getContext("2d")
                var r = width
                ctx.reset()
                ctx.fillStyle = fill
                ctx.beginPath()
                if (frame.fromBottom && isLeft) {
                    // A kepernyo alja y = r, a lap oldala x = r; a kor kozepe (0, 0).
                    ctx.moveTo(r, 0)
                    ctx.lineTo(r, r)
                    ctx.lineTo(0, r)
                    ctx.arc(0, 0, r, Math.PI / 2, 0, true)
                } else if (frame.fromBottom) {
                    // Tukorkep: a lap oldala x = 0, a kor kozepe (r, 0).
                    ctx.moveTo(0, 0)
                    ctx.lineTo(0, r)
                    ctx.lineTo(r, r)
                    ctx.arc(r, 0, r, Math.PI / 2, Math.PI, false)
                } else if (isLeft) {
                    // A sav alja (0,0)-(r,0), a lap oldala x = r; a kor kozepe (0, r).
                    ctx.moveTo(0, 0)
                    ctx.lineTo(r, 0)
                    ctx.lineTo(r, r)
                    ctx.arc(0, r, r, 0, -Math.PI / 2, true)
                } else {
                    // Tukorkep: a lap oldala x = 0, a kor kozepe (r, r).
                    ctx.moveTo(r, 0)
                    ctx.lineTo(0, 0)
                    ctx.lineTo(0, r)
                    ctx.arc(r, r, r, Math.PI, Math.PI * 1.5, false)
                }
                ctx.closePath()
                ctx.fill()

                // A lap oldalan futo 1 px-es kontur az iven folytatodik: ugyanazzal
                // a szinnel, fel pixellel beljebb, igy nincs lepcso a talalkozasnal.
                var c = r - 0.5
                ctx.strokeStyle = stroke
                ctx.lineWidth = 1
                ctx.beginPath()
                if (frame.fromBottom && isLeft) ctx.arc(0, 0, c, 0, Math.PI / 2, false)
                else if (frame.fromBottom) ctx.arc(r, 0, c, Math.PI / 2, Math.PI, false)
                else if (isLeft) ctx.arc(0, r, c, -Math.PI / 2, 0, false)
                else ctx.arc(r, r, c, Math.PI, Math.PI * 1.5, false)
                ctx.stroke()
            }
        }
    }
}
