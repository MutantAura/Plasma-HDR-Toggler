import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // [{ name, hdr: "enabled"|"disabled"|"incapable", busy }]
    property var displays: []
    property var info: ({})   // connector -> { label, peak }
    property string error: ""
    readonly property string infoScript: Qt.resolvedUrl("../scripts/info.py").toString().replace("file://", "")
    readonly property int hdrCount: displays.filter(d => d.hdr === "enabled").length

    Plasmoid.icon: "video-display-brightness"
    toolTipMainText: i18n("HDR Toggle")
    toolTipSubText: hdrCount > 0 ? i18np("HDR on for %1 display", "HDR on for %1 displays", hdrCount) : i18n("HDR off")

    function stripAnsi(s) { return s.replace(/\x1b\[[0-9;]*m/g, "") }

    function parse(text) {
        const result = []
        let cur = null
        for (const raw of stripAnsi(text).split("\n")) {
            const head = raw.match(/^Output:\s+\d+\s+(\S+)/)
            if (head) {
                cur = { name: head[1], hdr: "incapable", busy: false, connected: false, enabled: false }
                result.push(cur)
                continue
            }
            if (!cur) continue
            const line = raw.trim()
            if (line === "connected") cur.connected = true
            else if (line === "enabled") cur.enabled = true
            else if (line.startsWith("HDR:")) cur.hdr = line.substring(4).trim().split(/\s+/)[0]
        }
        return result.filter(d => d.connected && d.enabled)
    }

    function refresh() {
        runner.run("python3 " + infoScript)
        runner.run("kscreen-doctor -o")
    }

    function setHdr(name, on) {
        displays = displays.map(d => d.name === name ? Object.assign({}, d, { busy: true }) : d)
        // Like System Settings, switch wide colour gamut together with HDR in a single
        // config change; HDR without WCG leaves SDR content washed out.
        const verb = on ? "enable" : "disable"
        runner.run("kscreen-doctor output." + name + ".hdr." + verb + " output." + name + ".wcg." + verb)
    }

    P5Support.DataSource {
        id: runner
        engine: "executable"
        connectedSources: []
        function run(cmd) { connectSource(cmd) }
        onNewData: (source, data) => {
            disconnectSource(source)
            if (source.startsWith("python3 ")) {
                try { root.info = JSON.parse(data["stdout"]) } catch (e) { }
            } else if (source === "kscreen-doctor -o") {
                if (data["exit code"] === 0) {
                    root.error = ""
                    root.displays = root.parse(data["stdout"])
                } else {
                    root.error = data["stderr"] || i18n("kscreen-doctor failed")
                }
            } else {
                // A toggle finished; give KWin a moment to apply, then re-read.
                settle.restart()
            }
        }
    }

    Timer { id: settle; interval: 700; onTriggered: root.refresh() }
    Timer { interval: 5000; running: root.expanded; repeat: true; onTriggered: root.refresh() }
    Component.onCompleted: refresh()
    onExpandedChanged: if (expanded) refresh()

    fullRepresentation: ColumnLayout {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 18
        Layout.maximumWidth: Kirigami.Units.gridUnit * 22
        Layout.minimumWidth: Kirigami.Units.gridUnit * 14
        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents.Label {
            Layout.fillWidth: true
            visible: root.error !== ""
            text: root.error
            color: Kirigami.Theme.negativeTextColor
            wrapMode: Text.Wrap
        }
        PlasmaComponents.Label {
            Layout.fillWidth: true
            visible: root.error === "" && root.displays.length === 0
            text: i18n("No connected displays found.")
            opacity: 0.7
        }

        Repeater {
            model: root.displays
            delegate: RowLayout {
                id: row
                required property var modelData
                readonly property bool capable: modelData.hdr !== "incapable"
                readonly property bool on: modelData.hdr === "enabled"
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                QQC2.CheckBox {
                    checked: row.on
                    enabled: row.capable && !row.modelData.busy
                    // Don't let the checkbox's own binding drift from the real state.
                    onToggled: { root.setHdr(row.modelData.name, checked); checked = Qt.binding(() => row.on) }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    PlasmaComponents.Label {
                        text: root.info[row.modelData.name]?.label ?? row.modelData.name
                        font.bold: true
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        opacity: 0.75
                        font: Kirigami.Theme.smallFont
                        text: {
                            if (!row.capable) return i18n("HDR not supported")
                            const peak = root.info[row.modelData.name]?.peak
                            const state = row.on ? i18n("HDR on") : i18n("HDR off")
                            return peak ? i18n("%1 · max %2 nits", state, peak) : state
                        }
                    }
                }
                QQC2.BusyIndicator { visible: row.modelData.busy; running: visible; implicitWidth: Kirigami.Units.iconSizes.small; implicitHeight: implicitWidth }
            }
        }
    }
}
