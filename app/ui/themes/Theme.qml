pragma Singleton
import QtQuick

QtObject {
    property string selectedTheme: "umbra"
    property bool reducedMotion: false

    readonly property var themes: ({
        umbra: {
            canvas: "#151419", rail: "#1c1b22", surface: "#211f28", raised: "#2a2733",
            line: "#393541", ink: "#f5f1fb", muted: "#b5afc2", accent: "#c1aff7",
            accentText: "#261941", hover: "#302c39", selected: "#382c51", danger: "#ffb8bb"
        },
        midnight: {
            canvas: "#111820", rail: "#16202a", surface: "#1b2733", raised: "#233242",
            line: "#33475b", ink: "#edf6ff", muted: "#afc2d5", accent: "#9ed1ff",
            accentText: "#142b43", hover: "#293b4e", selected: "#294763", danger: "#ffb9c3"
        },
        snow: {
            canvas: "#f5f4f8", rail: "#edebf3", surface: "#ffffff", raised: "#f7f5fa",
            line: "#dfdbe7", ink: "#24202c", muted: "#60586d", accent: "#65469b",
            accentText: "#ffffff", hover: "#f0eaf8", selected: "#ebe3fa", danger: "#972f43"
        },
        forest: {
            canvas: "#111c18", rail: "#17251f", surface: "#1c2c25", raised: "#23382e",
            line: "#395347", ink: "#ecf6ef", muted: "#adc5b7", accent: "#a0e6c4",
            accentText: "#12372b", hover: "#2a4237", selected: "#2b5141", danger: "#ffb8bf"
        },
        graphite: {
            canvas: "#191a1c", rail: "#212224", surface: "#26282b", raised: "#2e3135",
            line: "#41454b", ink: "#f2f3f5", muted: "#b9c0ca", accent: "#d3dbe6",
            accentText: "#252a33", hover: "#363a40", selected: "#3d454f", danger: "#ffb8bb"
        }
    })

    readonly property var tokens: themes[selectedTheme] || themes.umbra
    readonly property bool dark: selectedTheme !== "snow"
    readonly property color canvas: tokens.canvas
    readonly property color rail: tokens.rail
    readonly property color surface: tokens.surface
    readonly property color raised: tokens.raised
    readonly property color line: tokens.line
    readonly property color ink: tokens.ink
    readonly property color muted: tokens.muted
    readonly property color accent: tokens.accent
    readonly property color accentText: tokens.accentText
    readonly property color hover: tokens.hover
    readonly property color tint: tokens.selected
    readonly property color danger: tokens.danger
    readonly property color overlay: dark ? "#80000000" : "#700f0b19"
    readonly property int radius: 10
    readonly property int duration: reducedMotion ? 0 : 150

    function entryInk(accents, id) {
        const swatch = accents.find(item => item.id === id)
        return swatch ? (dark ? swatch.dark : swatch.light) : accent
    }
}
