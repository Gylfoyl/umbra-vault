import QtQuick
import "../themes"

Canvas {
    id: icon
    property string name
    property color ink: Theme.accent
    implicitWidth: 20
    implicitHeight: 20
    Accessible.ignored: true
    onNameChanged: requestPaint()
    onInkChanged: requestPaint()

    onPaint: {
        const c = getContext("2d")
        c.reset()
        c.scale(width / 24, height / 24)
        c.strokeStyle = ink
        c.lineWidth = 1.65
        c.lineJoin = "round"
        c.lineCap = "round"
        function line(points) {
            c.beginPath()
            c.moveTo(points[0], points[1])
            for (let i = 2; i < points.length; i += 2)
                c.lineTo(points[i], points[i + 1])
            c.stroke()
        }
        function circle(x, y, radius) {
            c.beginPath()
            c.arc(x, y, radius, 0, 2 * Math.PI)
            c.stroke()
        }
        switch (name) {
        case "vault":
            line([12, 2, 21, 6, 21, 13, 18, 18, 12, 22, 6, 18, 3, 13, 3, 6, 12, 2])
            line([8, 10, 8, 15, 16, 15, 16, 10, 8, 10])
            c.beginPath()
            c.arc(12, 10, 2.5, Math.PI, 2 * Math.PI)
            c.stroke()
            break
        case "grid":
            for (const x of [4, 13])
                for (const y of [4, 13])
                    c.strokeRect(x, y, 7, 7)
            break
        case "star":
            line([12, 3, 14.7, 8.8, 21, 9.8, 16.5, 14.2, 17.5, 21,
                  12, 17.8, 6.5, 21, 7.5, 14.2, 3, 9.8, 9.3, 8.8, 12, 3])
            break
        case "key":
            circle(8, 9, 4.5)
            line([11.5, 12, 20, 20, 22, 18, 19, 15, 17, 17])
            break
        case "note":
            line([5, 3, 15, 3, 19, 7, 19, 21, 5, 21, 5, 3])
            line([14, 3, 14, 8, 19, 8])
            line([8, 12, 16, 12])
            line([8, 16, 15, 16])
            break
        case "settings":
            line([9, 3, 15, 3, 16, 7, 20, 8, 22, 12, 20, 16, 16, 17,
                  15, 21, 9, 21, 8, 17, 4, 16, 2, 12, 4, 8, 8, 7, 9, 3])
            circle(12, 12, 3)
            break
        case "lock":
            c.strokeRect(5, 10, 14, 11)
            c.beginPath()
            c.arc(12, 10, 4, Math.PI, 2 * Math.PI)
            c.stroke()
            line([12, 14, 12, 17])
            break
        case "search":
            circle(10, 10, 5.5)
            line([14, 14, 20, 20])
            break
        case "plus":
            line([12, 5, 12, 19])
            line([5, 12, 19, 12])
            break
        case "spark":
            line([12, 2, 14.5, 9.5, 22, 12, 14.5, 14.5, 12, 22, 9.5, 14.5,
                  2, 12, 9.5, 9.5, 12, 2])
            break
        case "eye":
            c.beginPath()
            c.moveTo(2, 12)
            c.quadraticCurveTo(12, -1, 22, 12)
            c.quadraticCurveTo(12, 25, 2, 12)
            c.stroke()
            circle(12, 12, 3)
            break
        case "hide":
            line([3, 3, 21, 21])
            c.beginPath()
            c.moveTo(2, 12)
            c.quadraticCurveTo(4, 9, 7, 8)
            c.moveTo(10, 7)
            c.quadraticCurveTo(16, 5, 22, 12)
            c.quadraticCurveTo(20, 15, 17, 16)
            c.moveTo(14, 17)
            c.quadraticCurveTo(7, 18, 2, 12)
            c.stroke()
            break
        case "copy":
            c.strokeRect(8, 8, 12, 12)
            line([16, 5, 5, 5, 5, 16])
            break
        case "edit":
            line([4, 20, 5, 15, 16, 4, 20, 8, 9, 19, 4, 20])
            line([14, 6, 18, 10])
            break
        case "trash":
            line([4, 6, 20, 6])
            line([9, 6, 9, 3, 15, 3, 15, 6])
            line([6, 6, 7, 21, 17, 21, 18, 6])
            line([10, 10, 10, 17])
            line([14, 10, 14, 17])
            break
        case "arrow":
            line([19, 12, 5, 12, 11, 6])
            line([5, 12, 11, 18])
            break
        case "close":
            line([5, 5, 19, 19])
            line([5, 19, 19, 5])
            break
        case "chevron":
            line([5, 9, 12, 16, 19, 9])
            break
        case "picture":
            c.strokeRect(3, 4, 18, 16)
            circle(9, 9, 1.5)
            line([4, 18, 10, 13, 13, 15, 17, 11, 20, 15])
            break
        case "palette":
            c.beginPath()
            c.arc(12, 12, 8, 0, 2 * Math.PI)
            c.stroke()
            circle(8, 10, 1)
            circle(12, 7, 1)
            circle(16, 10, 1)
            circle(15, 15, 1)
            break
        case "more":
            for (const x of [5, 12, 19])
                circle(x, 12, 0.8)
            break
        case "sidebar":
            c.strokeRect(3, 5, 18, 14)
            line([9, 5, 9, 19])
            break
        case "folder":
            line([3, 6, 10, 6, 12, 8, 21, 8, 21, 19, 3, 19, 3, 6])
            break
        }
    }
}
