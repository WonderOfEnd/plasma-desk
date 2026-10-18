import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Effects
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC3
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

// desk theme switcher: an icon on the panel; a click opens theme cards (preview, icon,
// name). Clicking a card applies the theme.
PlasmoidItem {
    id: root

    readonly property var cfg: Plasmoid.configuration
    property var themes: []
    property string current: ""
    property bool currentDirty: false
    property bool loading: false
    property string switching: ""
    property string lang: Qt.locale().name.startsWith("ru") ? "ru" : "en"

    // Strings follow desk's language (desk json reports it), English by default.
    readonly property var ru: ({
        "Desktop Themes": "Темы рабочего стола",
        "Now: %1": "Сейчас: %1",
        "Themes": "Темы",
        "Now": "Сейчас",
        "Switching…": "Переключаю…",
        "“%1” has unsaved changes": "В «%1» есть несохранённые изменения",
        "The current desktop is not saved as a theme": "Текущий стол не сохранён как тема",
        "Save": "Сохранить",
        "New theme, rename, delete…": "Новая тема, переименование, удаление…"
    })
    function tr(s, a) { const t = (lang === "ru" && ru[s]) || s; return a === undefined ? t : t.arg(a) }

    preferredRepresentation: compactRepresentation
    toolTipMainText: tr("Desktop Themes")
    toolTipSubText: current ? tr("Now: %1", current) : ""

    function q(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }

    // ⚠️ Applying a theme restarts plasmashell, and this widget lives inside it: a child
    // process of the shell would die with it halfway through. systemd-run starts desk as a
    // separate user unit, outside plasmashell's cgroup.
    function detached(args) { return "systemd-run --user --collect --quiet " + cfg.desk + " " + args }

    P5Support.DataSource {
        id: sh
        engine: "executable"
        onNewData: (source, data) => {
            disconnectSource(source)
            if (source === root.listCmd) {
                root.loading = false
                try {
                    const j = JSON.parse(data.stdout)
                    root.themes = j.themes
                    root.current = j.current
                    if (j.lang) root.lang = j.lang
                    root.currentDirty = j.themes.some(t => t.current && t.dirty)
                } catch (e) { root.themes = [] }
            } else if (source.indexOf(" save ") >= 0) {
                root.refresh()
            }
        }
        function exec(cmd) { connectSource(cmd) }
    }
    readonly property string listCmd: cfg.desk + " json"

    function refresh() { loading = true; sh.exec(listCmd) }
    function applyTheme(name) {
        if (name === current || switching) return
        switching = name
        sh.exec(detached("apply " + q(name)))
    }

    onExpandedChanged: function() { if (root.expanded) refresh() }
    Component.onCompleted: refresh()

    compactRepresentation: MouseArea {
        id: area
        hoverEnabled: true
        Layout.minimumWidth: root.cfg.iconSize + 2 * Kirigami.Units.smallSpacing
        Layout.preferredWidth: Layout.minimumWidth
        Layout.fillHeight: true
        onClicked: root.expanded = !root.expanded
        Kirigami.Icon {
            anchors.centerIn: parent
            width: root.cfg.iconSize; height: width
            source: "desk-themes-symbolic"
            isMask: true
            color: Kirigami.Theme.textColor
            opacity: area.containsMouse || root.expanded ? 1 : 0.85
        }
    }

    fullRepresentation: Item {
        id: panel
        // With more themes: three columns and smaller cards, so the popup does not grow too tall.
        readonly property int cols: root.themes.length > 6 ? 3 : 2
        readonly property int cardW: cols == 3 ? 208 : 232
        readonly property int cardH: Math.round(cardW * 0.56)
        Layout.preferredWidth: cardW * cols + Kirigami.Units.largeSpacing * (cols + 1)
        Layout.preferredHeight: header.height + grid.implicitHeight + footer.implicitHeight + Kirigami.Units.largeSpacing * 4
        Layout.minimumWidth: Layout.preferredWidth
        Layout.minimumHeight: Layout.preferredHeight

        RowLayout {
            id: header
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: Kirigami.Units.largeSpacing }
            Kirigami.Heading {
                text: root.tr("Themes")
                level: 3
                Layout.fillWidth: true
            }
            PC3.BusyIndicator {
                visible: root.loading
                implicitWidth: Kirigami.Units.iconSizes.small; implicitHeight: implicitWidth
            }
        }

        GridLayout {
            id: grid
            anchors { top: header.bottom; left: parent.left; right: parent.right; margins: Kirigami.Units.largeSpacing }
            columns: panel.cols
            columnSpacing: Kirigami.Units.largeSpacing
            rowSpacing: Kirigami.Units.largeSpacing

            Repeater {
                model: root.themes
                delegate: MouseArea {
                    id: card
                    required property var modelData
                    readonly property bool isCurrent: modelData.current
                    Layout.preferredWidth: panel.cardW
                    Layout.preferredHeight: panel.cardH
                    hoverEnabled: true
                    cursorShape: isCurrent ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: root.applyTheme(modelData.name)
                    scale: containsMouse && !isCurrent ? 1.03 : 1.0
                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                    // Rounded-corner mask: clip only cuts rectangles.
                    Rectangle {
                        id: cardMask
                        anchors.fill: parent
                        radius: 12
                        visible: false
                        layer.enabled: true
                    }
                    Rectangle {
                        id: frame
                        anchors.fill: parent
                        radius: 12
                        color: "#20252f"
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: cardMask
                            maskThresholdMin: 0.5
                            maskSpreadAtMin: 1.0
                        }

                        Image {
                            anchors.fill: parent
                            source: card.modelData.preview ? "file://" + card.modelData.preview : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize: Qt.size(480, 270)
                        }
                        // Darkening at the bottom under the caption.
                        Rectangle {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                            height: parent.height * 0.55
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "#00000000" }
                                GradientStop { position: 1.0; color: "#c8000000" }
                            }
                        }
                        Rectangle {
                            anchors.fill: parent
                            color: "#000000"
                            opacity: card.containsMouse || card.isCurrent ? 0 : 0.12
                            Behavior on opacity { NumberAnimation { duration: 140 } }
                        }
                        RowLayout {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 12 }
                            spacing: 8
                            Image {
                                visible: card.modelData.icon !== ""
                                source: card.modelData.icon ? "file://" + card.modelData.icon : ""
                                sourceSize: Qt.size(20, 20)
                                Layout.preferredWidth: 20; Layout.preferredHeight: 20
                            }
                            Text {
                                Layout.fillWidth: true
                                text: card.modelData.name
                                color: "#ffffff"
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                        }
                        // "Now" badge on the applied theme.
                        Rectangle {
                            visible: card.isCurrent
                            anchors { top: parent.top; right: parent.right; margins: 10 }
                            radius: height / 2
                            color: Kirigami.Theme.highlightColor
                            implicitHeight: nowLabel.implicitHeight + 6
                            implicitWidth: nowLabel.implicitWidth + 16
                            Text {
                                id: nowLabel
                                anchors.centerIn: parent
                                text: root.tr("Now")
                                color: Kirigami.Theme.highlightedTextColor
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                            }
                        }
                        // Switching to this theme is in progress.
                        Rectangle {
                            anchors.fill: parent
                            visible: root.switching === card.modelData.name
                            color: "#99000000"
                            ColumnLayout {
                                anchors.centerIn: parent
                                PC3.BusyIndicator { Layout.alignment: Qt.AlignHCenter }
                                Text { text: root.tr("Switching…"); color: "#ffffff"; font.pixelSize: 13 }
                            }
                        }
                    }
                    // Border over the picture: accent for the current theme, faint white on hover.
                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: "transparent"
                        border.width: card.isCurrent ? 2 : 1
                        border.color: card.isCurrent ? Kirigami.Theme.highlightColor
                                     : (card.containsMouse ? "#80ffffff" : "#26ffffff")
                    }
                }
            }
        }

        RowLayout {
            id: footer
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: Kirigami.Units.largeSpacing }
            PC3.Label {
                Layout.fillWidth: true
                text: root.currentDirty ? root.tr("“%1” has unsaved changes", root.current)
                    : (root.current ? "" : root.tr("The current desktop is not saved as a theme"))
                opacity: 0.75
                elide: Text.ElideRight
            }
            PC3.Button {
                visible: root.currentDirty
                text: root.tr("Save")
                icon.name: "document-save"
                onClicked: sh.exec(root.cfg.desk + " save " + root.q(root.current))
            }
            PC3.ToolButton {
                icon.name: "configure"
                display: QQC2.AbstractButton.IconOnly
                QQC2.ToolTip.text: root.tr("New theme, rename, delete…")
                QQC2.ToolTip.visible: hovered
                onClicked: { root.expanded = false; sh.exec(root.detached("gui")) }
            }
        }
    }
}
