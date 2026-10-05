import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: page

    property real marginLeft: 0
    property real marginRight: 55
    property real marginTop: 0
    property real marginBottom: 0
    property real sectionSpacing: 6

    readonly property string themePy: Quickshell.env("HOME") + "/.config/43pr/bin/theme.py"

    // what `theme.py list --json` reports
    property var info: ({ mode: "", appearance: "dark", matugen_type: "auto",
                          matugen_contrast: 0, matugen_swatch: null, presets: [] })
    property bool busy: applyProc.running
    property string pending: ""          // id of the option being applied

    readonly property var schemeTypes: [
        { id: "auto", label: "AUTO" },
        { id: "scheme-tonal-spot", label: "TONAL" },
        { id: "scheme-neutral", label: "NEUTRAL" },
        { id: "scheme-content", label: "CONTENT" },
        { id: "scheme-fidelity", label: "FIDELITY" },
        { id: "scheme-expressive", label: "EXPRESSIVE" },
        { id: "scheme-vibrant", label: "VIBRANT" },
        { id: "scheme-rainbow", label: "RAINBOW" },
        { id: "scheme-fruit-salad", label: "FRUIT SALAD" },
        { id: "scheme-monochrome", label: "MONO" }
    ]
    readonly property var contrasts: [
        { value: -1, label: "MIN" },
        { value: -0.5, label: "SOFT" },
        { value: 0, label: "STANDARD" },
        { value: 0.5, label: "HIGH" }
    ]

    Process {
        id: listProc
        command: ["python3", page.themePy, "list", "--json"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    page.info = JSON.parse(text)
                } catch (e) {
                    console.warn("ThemesPage: bad theme list: " + e)
                }
            }
        }
        stderr: StdioCollector { onStreamFinished: {} }
    }

    Process {
        id: applyProc
        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "") console.warn("theme.py: " + text.trim())
        }
        onExited: {
            page.pending = ""
            listProc.running = true
        }
    }

    function run(tag, args) {
        if (applyProc.running) return
        page.pending = tag
        applyProc.command = ["python3", page.themePy].concat(args)
        applyProc.running = true
    }

    // ---------- components ----------

    component SectionTitle: Column {
        required property string title
        width: parent.width
        spacing: 8
        Text {
            text: parent.title
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 16
            font.letterSpacing: 3
        }
        Rectangle { width: parent.width; height: 1; color: Theme.border }
    }

    component Swatch: Row {
        property var colors: []
        spacing: 4
        Repeater {
            model: parent.colors || []
            Rectangle {
                required property string modelData
                width: 14
                height: 14
                radius: 4
                color: modelData
                border.width: 1
                border.color: Theme.alpha(Theme.text, 0.15)
            }
        }
    }

    // big selectable row: name + description + palette preview
    component ThemeCard: Rectangle {
        id: card
        property string title: ""
        property string subtitle: ""
        property var colors: []
        property bool active: false
        property bool working: false
        signal picked()

        width: parent.width
        height: 58
        radius: Theme.radius
        color: active ? Theme.alpha(Theme.accent, 0.10)
                      : hover.containsMouse ? Theme.alpha(Theme.accent, 0.05) : "transparent"
        border.width: 1
        border.color: active || hover.containsMouse ? Theme.accent : Theme.border

        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.right: sw.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            Text {
                width: parent.width
                text: (card.active ? "● " : "") + card.title.toUpperCase()
                color: card.active ? Theme.accent : Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.bold: true
                font.letterSpacing: 2
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: card.working ? "applying…" : card.subtitle
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }

        Swatch {
            id: sw
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            colors: card.colors
        }

        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: card.picked()
        }
    }

    // small option pill
    component Chip: Rectangle {
        id: chip
        property string label: ""
        property bool active: false
        signal picked()

        width: chipText.implicitWidth + 24
        height: 30
        radius: Theme.radius
        color: active ? Theme.alpha(Theme.accent, 0.15)
                      : chipHover.containsMouse ? Theme.alpha(Theme.accent, 0.06) : "transparent"
        border.width: 1
        border.color: active || chipHover.containsMouse ? Theme.accent : Theme.border

        Text {
            id: chipText
            anchors.centerIn: parent
            text: chip.label
            color: chip.active ? Theme.accent : Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.bold: true
            font.letterSpacing: 1
        }

        MouseArea {
            id: chipHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.picked()
        }
    }

    component OptionRow: Row {
        property string label: ""
        default property alias chips: flow.data
        width: parent.width
        spacing: 12
        Text {
            width: 84
            height: 30
            verticalAlignment: Text.AlignVCenter
            text: parent.label
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.letterSpacing: 2
        }
        Flow {
            id: flow
            width: parent.width - 96
            spacing: 6
        }
    }

    // ---------- layout ----------

    Flickable {
        id: flick

        anchors.fill: parent
        anchors.leftMargin: page.marginLeft
        anchors.rightMargin: page.marginRight
        anchors.topMargin: page.marginTop
        anchors.bottomMargin: page.marginBottom

        contentWidth: width
        contentHeight: content.height

        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            background: Rectangle {
                color: Theme.alpha(Theme.border, 0.3)
                radius: width / 2
            }
            contentItem: Rectangle {
                color: Theme.accent
                radius: width / 2
            }
        }

        Column {
            id: content

            width: flick.width
            spacing: 14

            Text {
                text: "THEMES"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 19
                font.letterSpacing: 3
            }

            Rectangle { width: parent.width; height: 1; color: Theme.border }

            SectionTitle { title: "MATUGEN" }

            Column {
                width: parent.width
                spacing: 10

                ThemeCard {
                    title: "From wallpaper"
                    subtitle: "Colours follow the current wallpaper"
                    colors: page.info.matugen_swatch || []
                    active: page.info.mode === "wallpaper"
                    working: page.pending === "matugen"
                    onPicked: page.run("matugen", ["auto"])
                }

                OptionRow {
                    label: "SCHEME"
                    Repeater {
                        model: page.schemeTypes
                        Chip {
                            required property var modelData
                            label: modelData.label
                            active: page.info.matugen_type === modelData.id
                            onPicked: page.run("matugen", ["matugen", "--type", modelData.id])
                        }
                    }
                }

                OptionRow {
                    label: "CONTRAST"
                    Repeater {
                        model: page.contrasts
                        Chip {
                            required property var modelData
                            label: modelData.label
                            active: Math.abs(page.info.matugen_contrast - modelData.value) < 0.01
                            onPicked: page.run("matugen", ["matugen", "--contrast", String(modelData.value)])
                        }
                    }
                }

                OptionRow {
                    label: "MODE"
                    Chip {
                        label: "DARK"
                        active: page.info.appearance === "dark"
                        onPicked: page.run("matugen", ["matugen", "--mode", "dark"])
                    }
                    Chip {
                        label: "LIGHT"
                        active: page.info.appearance === "light"
                        onPicked: page.run("matugen", ["matugen", "--mode", "light"])
                    }
                }
            }

            Item { width: 1; height: 4 }

            SectionTitle { title: "PRESETS" }

            Column {
                width: parent.width
                spacing: page.sectionSpacing

                Repeater {
                    model: page.info.presets || []
                    ThemeCard {
                        required property var modelData
                        title: modelData.name
                        subtitle: modelData.description
                        colors: modelData.swatch
                        active: modelData.active
                        working: page.pending === modelData.id
                        onPicked: page.run(modelData.id, ["preset", modelData.id])
                    }
                }
            }

            Item { width: 1; height: 8 }
        }
    }
}
