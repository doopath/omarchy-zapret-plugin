import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Popup плагина: состояние zapret2, Start/Stop/Restart, blockcheck и логи.
// Открывается базовым KeyboardPanel (Escape и клик вне окна уже реализованы
// там), а статус и действия берёт у BarWidget.qml через injectPanel().
Panel {
  id: root
  moduleName: "doopath.zapret"
  ipcTarget: "doopath.zapret"
  manageIpc: false

  property var anchorItem: null

  // Ссылка на BarWidget.qml: владелец статуса, опроса и процессов действий.
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  readonly property var host: hostWidget

  readonly property bool installed: host ? host.installed === true : false
  readonly property string serviceState: host ? String(host.serviceState) : "unknown"
  readonly property string activeState: host ? String(host.activeState) : ""
  readonly property string subState: host ? String(host.subState) : ""
  readonly property string uptimeText: host ? String(host.uptimeText) : ""
  readonly property bool busy: host ? host.busy === true : false
  readonly property string busyVerb: host ? String(host.busyVerb) : ""
  readonly property string lastError: host ? String(host.lastError) : ""

  readonly property bool serviceActive: serviceState === "active"
  readonly property bool missing: serviceState === "missing"
  readonly property bool failed: serviceState === "failed"

  readonly property color contentForeground: bar ? bar.foreground : Commons.Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color dim: Qt.darker(contentForeground, 1.45)
  readonly property color accent: Commons.Color.accent
  readonly property color danger: Commons.Color.urgent

  readonly property color statusColor: serviceActive ? accent
    : failed ? danger
    : (missing || serviceState === "unknown") ? dim
    : contentForeground

  readonly property string statusText: {
    if (host && host.probed !== true) return "checking…"
    if (missing) return "not installed"
    if (busy) return (busyVerb !== "" ? busyVerb : "working") + "…"
    if (failed) return "failed"
    var label = activeState !== "" ? activeState : "unknown"
    if (subState !== "" && subState !== activeState) label += " / " + subState
    return label
  }

  // Опциональное чтение стратегии из конфига zapret2. Сам конфиг читается
  // только на открытие панели и при его изменении — не в цикле опроса.
  property string strategy: ""
  // Штатный конфиг пакета приходит с NFQWS2_ENABLE=0: юнит применяет
  // nft-правила, но демона нет, поэтому systemd сразу его останавливает.
  property bool nfqwsEnabled: false

  function open() {
    refreshConfig()
    if (host && typeof host.refresh === "function") host.refresh()
    root.controller.show()
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function refreshConfig() {
    configFile.reload()
  }

  function parseConfig(content) {
    var raw = String(content || "")
    root.nfqwsEnabled = /^[ \t]*NFQWS2_ENABLE=1[ \t]*$/m.test(raw)
    // NFQWS2_OPT в штатном конфиге занимает несколько строк между кавычками.
    // Берём первую содержательную строку как «стратегию» только для показа.
    var match = raw.match(/^[ \t]*NFQWS2_OPT="([\s\S]*?)"/m)
    if (!match) {
      root.strategy = ""
      return
    }
    var lines = match[1].split("\n")
    var value = ""
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim()
      if (line === "" || line.charAt(0) === "#") continue
      value = line
      break
    }
    root.strategy = value.length > 60 ? value.substring(0, 57) + "…" : value
  }

  function act(verb) {
    if (host && typeof host.runAction === "function") host.runAction(verb)
  }

  component InfoRow: Item {
    id: infoRow
    property string label: ""
    property string value: ""
    property color valueColor: root.contentForeground
    width: parent ? parent.width : 0
    implicitHeight: Math.max(infoLabel.implicitHeight, infoValue.implicitHeight)
    Text {
      id: infoLabel
      text: infoRow.label
      color: root.dim
      font.family: root.contentFontFamily
      font.pixelSize: Style.font.bodySmall
    }
    Text {
      id: infoValue
      text: infoRow.value
      color: infoRow.valueColor
      font.family: root.contentFontFamily
      font.pixelSize: Style.font.bodySmall
      horizontalAlignment: Text.AlignRight
      elide: Text.ElideRight
      anchors.right: parent.right
      width: Math.max(0, parent.width - infoLabel.implicitWidth - Style.space(12))
    }
  }

  FileView {
    id: configFile
    path: "/opt/zapret2/config"
    watchChanges: true
    printErrors: false
    onLoaded: root.parseConfig(text())
    onFileChanged: reload()
    onLoadFailed: root.strategy = ""
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()

      Column {
        id: column
        width: parent.width
        spacing: Style.space(10)

        // ---- Шапка: щит + название + состояние -------------------------
        Row {
          id: hero
          width: parent.width
          spacing: Style.space(12)

          Text {
            id: shield
            text: "\uf132"
            color: root.statusColor
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.display
            anchors.verticalCenter: parent.verticalCenter
          }

          Column {
            width: Math.max(0, hero.width - shield.implicitWidth - hero.spacing)
            spacing: Style.space(2)
            anchors.verticalCenter: parent.verticalCenter

            Text {
              textFormat: Text.PlainText
              text: "Zapret 2"
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.heading
              font.bold: true
            }

            Text {
              textFormat: Text.PlainText
              text: root.statusText
              color: root.statusColor
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
              width: parent.width
              elide: Text.ElideRight
            }
          }
        }

        PanelSeparator {
          visible: !root.missing
          foreground: root.contentForeground
        }

        // ---- Состояние и uptime -----------------------------------------
        Column {
          width: parent.width
          spacing: Style.space(4)
          visible: !root.missing

          InfoRow {
            label: "State"
            value: root.statusText
            valueColor: root.statusColor
          }

          InfoRow {
            visible: root.serviceActive && root.uptimeText !== ""
            label: "Uptime"
            value: root.uptimeText
          }
        }

        // ---- Конфиг и стратегия -----------------------------------------
        Column {
          width: parent.width
          spacing: Style.space(4)
          visible: root.installed

          PanelSectionHeader {
            text: "CONFIG"
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
          }

          Text {
            textFormat: Text.PlainText
            text: "/opt/zapret2/config"
            color: root.dim
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.bodySmall
            width: parent.width
            elide: Text.ElideMiddle
          }

          Text {
            visible: root.strategy !== ""
            textFormat: Text.PlainText
            text: root.strategy
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.bodySmall
            width: parent.width
            elide: Text.ElideRight
          }

          // Штатный конфиг не запускает nfqws2: юнит применит правила и тут же
          // завершится. Предупреждаем, иначе Start выглядит как «ничего не делает».
          Text {
            visible: root.strategy !== "" && !root.nfqwsEnabled
            textFormat: Text.PlainText
            text: "NFQWS2_ENABLE=0 — no nfqws2 daemon; Start stops at once"
            color: root.danger
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.bodySmall
            width: parent.width
            wrapMode: Text.Wrap
          }
        }

        // ---- Ошибка последнего действия ---------------------------------
        Text {
          visible: root.lastError !== ""
          textFormat: Text.PlainText
          text: root.lastError
          color: root.danger
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.bodySmall
          width: parent.width
          wrapMode: Text.Wrap
          maximumLineCount: 4
          elide: Text.ElideRight
        }

        // ---- zapret2 не установлен --------------------------------------
        Column {
          width: parent.width
          spacing: Style.space(6)
          visible: root.missing

          Text {
            textFormat: Text.PlainText
            text: "zapret2 is not installed"
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
          }

          Text {
            textFormat: Text.PlainText
            text: "Install it with:"
            color: root.dim
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.bodySmall
          }

          Text {
            textFormat: Text.PlainText
            text: "yay -S zapret2"
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
            font.bold: true
          }
        }

        // ---- Индикатор выполняющейся команды ----------------------------
        Text {
          visible: root.busy
          textFormat: Text.PlainText
          text: "working…"
          color: root.dim
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.bodySmall
        }

        // ---- Start / Stop / Restart ------------------------------------
        Row {
          width: parent.width
          spacing: Style.space(8)
          visible: !root.missing

          Button {
            visible: !root.serviceActive
            width: parent.width
            height: implicitHeight
            text: "Start"
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            fontSize: Style.font.body
            bordered: true
            enabled: root.installed && !root.busy
            opacity: enabled ? 1 : 0.45
            onClicked: root.act("start")
          }

          Button {
            visible: root.serviceActive
            width: (parent.width - parent.spacing) / 2
            text: "Stop"
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            fontSize: Style.font.body
            bordered: true
            enabled: root.installed && !root.busy
            opacity: enabled ? 1 : 0.45
            onClicked: root.act("stop")
          }

          Button {
            visible: root.serviceActive
            width: (parent.width - parent.spacing) / 2
            text: "Restart"
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            fontSize: Style.font.body
            bordered: true
            enabled: root.installed && !root.busy
            opacity: enabled ? 1 : 0.45
            onClicked: root.act("restart")
          }
        }

        // ---- Blockcheck / Logs -----------------------------------------
        Row {
          width: parent.width
          spacing: Style.space(8)
          visible: !root.missing

          Button {
            width: (parent.width - parent.spacing) / 2
            text: "Blockcheck"
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            fontSize: Style.font.body
            bordered: true
            enabled: root.installed && !root.busy
            opacity: enabled ? 1 : 0.45
            onClicked: if (root.host) root.host.openBlockcheck()
          }

          Button {
            width: (parent.width - parent.spacing) / 2
            text: "Logs"
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            fontSize: Style.font.body
            bordered: true
            enabled: root.installed && !root.busy
            opacity: enabled ? 1 : 0.45
            onClicked: if (root.host) root.host.openLogs()
          }
        }
      }
    }
  }
}
