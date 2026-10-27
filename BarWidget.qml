import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Состояние сервиса zapret2 в баре и точка входа для popup.
//
// Статус читается без root через `systemctl show` раз в 2.5 с; действия идут
// строго через root-helper /usr/local/bin/zapret-ctl, которому sudoers разрешает
// пять фиксированных подкоманд. Никакие строки пользователя в shell не
// подставляются.
BarWidget {
  id: root
  moduleName: "doopath.zapret"

  readonly property string helperPath: "/usr/local/bin/zapret-ctl"
  readonly property string serviceName: "zapret2"

  // ---- Состояние, обновляемое опросом -------------------------------------
  property bool probed: false
  property string activeState: ""
  property string subState: ""
  property string loadState: ""
  property bool binaryPresent: false
  property int uptimeSeconds: -1

  // ---- Действие в полёте ---------------------------------------------------
  property bool busy: false
  property string busyVerb: ""
  property string lastError: ""

  readonly property bool installed: probed && binaryPresent
    && loadState !== "" && loadState !== "not-found"
  readonly property bool isActive: activeState === "active"
  readonly property string serviceState: {
    if (!probed) return "unknown"
    if (!installed) return "missing"
    if (subState === "failed" || activeState === "failed") return "failed"
    if (isActive) return "active"
    return "inactive"
  }

  readonly property string uptimeText: {
    if (uptimeSeconds < 0) return ""
    var rest = uptimeSeconds
    var days = Math.floor(rest / 86400)
    rest -= days * 86400
    var hours = Math.floor(rest / 3600)
    rest -= hours * 3600
    var minutes = Math.floor(rest / 60)
    if (days > 0) return days + "d " + hours + "h"
    if (hours > 0) return hours + "h " + minutes + "m"
    if (minutes > 0) return minutes + "m"
    return "just now"
  }

  readonly property color barForeground: bar ? bar.foreground : Commons.Color.foreground
  readonly property color stateColor: {
    if (serviceState === "active") return Commons.Color.accent
    if (serviceState === "failed") return bar ? bar.urgent : Commons.Color.urgent
    if (serviceState === "missing") return Qt.darker(barForeground, 2.2)
    if (serviceState === "inactive") return Qt.darker(barForeground, 1.55)
    return barForeground
  }

  readonly property string tooltipText: {
    var head = "Zapret 2"
    if (serviceState === "missing") return head + " · not installed\nInstall: yay -S zapret2"
    if (serviceState === "unknown") return head + " · checking…"
    var status = busy ? busyVerb + "…" : serviceState
    if (!busy && isActive && uptimeText !== "") status += " · up " + uptimeText
    var verb = isActive ? "stop" : "start"
    return head + " · " + status + "\nLeft: menu · Right: " + verb + " · Middle: restart"
  }

  // ---- Опрос статуса -------------------------------------------------------
  function refresh() {
    if (statusProc.running || busy) return
    statusProc.running = true
  }

  function applyStatus(output) {
    var props = ({})
    var lines = String(output || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i]
      var eq = line.indexOf("=")
      if (eq <= 0) continue
      props[line.substring(0, eq)] = line.substring(eq + 1)
    }
    activeState = String(props.ActiveState || "")
    subState = String(props.SubState || "")
    loadState = String(props.LoadState || "")
    binaryPresent = props.Binary === "present"
    var up = parseInt(props.UptimeSeconds, 10)
    uptimeSeconds = isNaN(up) ? -1 : up
    probed = true
  }

  // ---- Действия ------------------------------------------------------------
  function runAction(verb) {
    if (!installed || busy) return
    if (verb !== "start" && verb !== "stop" && verb !== "restart") return
    busy = true
    busyVerb = verb
    lastError = ""
    actionProc.command = ["sudo", "-n", root.helperPath, verb]
    actionProc.running = true
  }

  function toggleService() {
    if (!installed || busy) return
    runAction(isActive ? "stop" : "start")
  }

  function openLogs() {
    if (!installed) return
    launchTerminal("logs")
  }

  function openBlockcheck() {
    if (!installed) return
    launchTerminal("blockcheck")
  }

  // Терминал запускает ровно ту команду, которую разрешает sudoers; ничего
  // пользовательского сюда не попадает. shellQuote не даёт bash -lc разбить её.
  function launchTerminal(verb) {
    if (!bar) return
    bar.run("omarchy-launch-floating-terminal-with-presentation "
      + Util.shellQuote("sudo -n " + root.helperPath + " " + verb))
  }

  // ---- Popup-контракт (см. doopath.clock) ---------------------------------
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function open() {
    refresh()
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function togglePanel() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Process {
    id: statusProc
    command: ["bash", "-c",
      "systemctl show " + root.serviceName + " -p ActiveState,SubState,ActiveEnterTimestamp,LoadState; "
      + "if [[ -x /opt/zapret2/nfq2/nfqws2 || -x /usr/bin/nfqws2 ]]; then echo Binary=present; else echo Binary=missing; fi; "
      + "enter=$(systemctl show " + root.serviceName + " -p ActiveEnterTimestamp --value); "
      + "if [[ -n $enter ]]; then started=$(date -d \"$enter\" +%s 2>/dev/null || true); "
      + "if [[ -n ${started:-} ]]; then echo UptimeSeconds=$(( $(date +%s) - started )); fi; fi"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyStatus(text)
    }
    onExited: if (!root.probed) root.probed = true
  }

  Process {
    id: actionProc
    stdout: StdioCollector { id: actionOut; waitForEnd: true }
    stderr: StdioCollector { id: actionErr; waitForEnd: true }
    onExited: function(exitCode) {
      var err = String(actionErr.text || "").trim()
      var out = String(actionOut.text || "").trim()
      var verb = root.busyVerb
      root.busy = false
      if (exitCode !== 0) {
        if (err !== "") root.lastError = err
        else if (out !== "") root.lastError = out
        else root.lastError = "zapret-ctl " + verb + " failed (exit " + exitCode + ")"
      } else {
        root.lastError = ""
      }
      root.busyVerb = ""
      // Немедленное обновление всех мониторов, не дожидаясь следующего тика.
      root.broadcast("refresh")
    }
  }

  Timer {
    // Не чаще одного опроса в 2.5 с.
    interval: 2500
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: "doopath.zapret"

    function toggle(): void { root.toggleService() }
    function refresh(): void { root.broadcast("refresh") }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\uf132"
    foreground: root.stateColor
    tooltipText: root.tooltipText

    onPressed: function(b) {
      if (b === Qt.RightButton) root.toggleService()
      else if (b === Qt.MiddleButton) root.runAction("restart")
      else root.togglePanel()
    }
  }
}
