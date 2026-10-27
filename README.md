# doopath.zapret

[![Лицензия: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![Omarchy](https://img.shields.io/badge/Omarchy-4.x-1793d1)
![zapret2](https://img.shields.io/badge/zapret2-AUR-orange)

**Zapret 2 в баре Omarchy.** Иконка-щит показывает состояние сервиса, левый клик
открывает панель управления, правый — запускает или останавливает обход DPI.

Плагин управляет только юнитом `zapret2.service` и запускает два его
инструмента — blockcheck и журнал. Стратегии обхода и конфиг zapret2 остаются
за вами.

## Содержание

- [Возможности](#возможности)
- [Требования](#требования)
- [Установка](#установка)
- [Использование](#использование)
- [Настройка zapret2](#настройка-zapret2)
- [Обновление](#обновление)
- [Удаление](#удаление)
- [Диагностика](#диагностика)
- [Безопасность](#безопасность)
- [Разработка](#разработка)
- [Лицензия](#лицензия)

## Возможности

- **Состояние в баре.** Щит меняет цвет: работает, остановлен, упал, не
  установлен. В подсказке — uptime и расшифровка кнопок мыши.
- **Панель по клику.** `ActiveState/SubState`, uptime, путь к конфигу и первая
  строка текущей стратегии `NFQWS2_OPT`.
- **Start / Stop / Restart без пароля.** Через root-helper, которому sudoers
  разрешает ровно пять фиксированных команд.
- **Blockcheck и логи** — в плавающем терминале Omarchy, не покидая рабочий
  стол.
- **Режим «не установлен».** Если пакета нет, кнопки скрыты, а в панели
  показана команда установки.
- **Ошибки видны.** stderr и код возврата helper'а выводятся в панели, а не
  проглатываются.
- **Экономично.** Статус опрашивается не чаще раза в 2.5 с, панель одна и не
  плодит окон.

| Вид щита | Состояние | Значение |
| --- | --- | --- |
| акцентный цвет | `active` | сервис работает |
| приглушённый | `inactive` | сервис остановлен |
| красный | `failed` | юнит завершился с ошибкой |
| серый | `missing` | zapret2 не установлен |

## Требования

- **Omarchy 4.x** с шеллом `omarchy-shell` (Quickshell).
- **AUR-пакет [`zapret2`](https://aur.archlinux.org/packages/zapret2)** (upstream
  [bol-van/zapret2](https://github.com/bol-van/zapret2)): бинарь `nfqws2`, конфиг
  `/opt/zapret2/config`, скрипт `/opt/zapret2/blockcheck2.sh` и юнит
  `zapret2.service`.
- **Root-helper** `/usr/local/bin/zapret-ctl` и правило
  `/etc/sudoers.d/zapret-ctl` — ставятся скриптом из репозитория.

Проверено на Omarchy 4.0.6, Quickshell 0.3.2, Hyprland 0.56.2 и zapret2 1.0.6.

## Установка

### 1. Пакет zapret2

```bash
yay -S zapret2
```

Пакет приходит выключенным: `NFQWS2_ENABLE=0`, автозапуска нет. Это нормально —
включим сервис после настройки стратегии, см. [Настройка zapret2](#настройка-zapret2).
Плагин установится и без пакета — покажет состояние `missing` и подсказку.

### 2. Плагин

```bash
omarchy plugin add https://github.com/doopath/omarchy-zapret-plugin.git --enable --yes
```

Команда клонирует плагин в `~/.config/omarchy/plugins/doopath.zapret` и сразу
включает его в правой секции бара.

Если плагин уже добавлен, но выключен:

```bash
omarchy plugin enable doopath.zapret right
```

### 3. Root-helper

```bash
sudo ~/.config/omarchy/plugins/doopath.zapret/scripts/install-helper.sh
```

Скрипт идемпотентен. Он:

1. копирует `zapret-ctl` в `/usr/local/bin/zapret-ctl` (`root:root 0755`);
2. подставляет пользователя, вызвавшего `sudo`, в шаблон sudoers;
3. проверяет файл через `visudo -cf` и кладёт его в
   `/etc/sudoers.d/zapret-ctl` (`root:root 0440`).

Запускайте именно через `sudo` из своей пользовательской сессии, а не из
root-шелла: правило привязывается к пользователю, который вызвал `sudo`.

Проверка:

```bash
sudo visudo -cf /etc/sudoers.d/zapret-ctl
/usr/local/bin/zapret-ctl status           # без sudo
sudo -n -l /usr/local/bin/zapret-ctl start # NOPASSWD, команда не запускается
```

`status` намеренно не входит в sudoers: `systemctl is-active` читается без
root. Разрешены только `start`, `stop`, `restart`, `logs` и `blockcheck`.

### 4. Горячая клавиша (необязательно)

Плагин не ставит клавишу автоматически. Добавьте в
`~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + SHIFT + Z", "Zapret toggle", "omarchy-shell doopath.zapret toggle")
```

Затем примените конфиг:

```bash
hyprctl reload
hyprctl configerrors
```

Если комбинация занята, выберите другую. Проверить занятые клавиши:

```bash
omarchy menu keybindings --print
```

## Использование

### Мышь

| Действие | Результат |
| --- | --- |
| Левый клик по щиту | открыть / закрыть панель |
| Правый клик | Start, если сервис не `active`; Stop, если `active` |
| Средний клик | Restart |
| `Esc` или клик вне панели | закрыть панель |

### Панель

В панели видны состояние и uptime сервиса, путь `/opt/zapret2/config` и
текущая стратегия. Если в конфиге `NFQWS2_ENABLE=0`, панель предупреждает, что
запускать нечего: юнит применит правила и сразу завершится.

Кнопки:

- **Start / Stop / Restart** — управление юнитом;
- **Blockcheck** — запуск `/opt/zapret2/blockcheck2.sh` в плавающем терминале;
- **Logs** — `journalctl -u zapret2 -f -n 200` в плавающем терминале.

Ошибка последнего действия (например, `sudo: a password is required`) остаётся
в панели до следующего действия.

### IPC

```bash
omarchy-shell doopath.zapret toggle    # запустить / остановить сервис
omarchy-shell doopath.zapret refresh   # принудительно обновить статус
omarchy-shell doopath.zapret open      # открыть панель (алиас: show)
omarchy-shell doopath.zapret close     # закрыть панель (алиас: hide)
```

### Helper из терминала

```bash
zapret-ctl status       # без root, код возврата как у systemctl is-active
sudo zapret-ctl start
sudo zapret-ctl stop
sudo zapret-ctl restart
sudo zapret-ctl logs       # journalctl -u zapret2 -f -n 200
sudo zapret-ctl blockcheck # /opt/zapret2/blockcheck2.sh
```

## Настройка zapret2

Плагин **не** настраивает zapret2. Всё, что касается обхода DPI, живёт в
`/opt/zapret2/config`.

Минимальный порядок первого запуска:

1. Откройте конфиг:

   ```bash
   sudoedit /opt/zapret2/config
   ```

2. Включите демон:

   ```ini
   NFQWS2_ENABLE=1
   ```

3. Подберите рабочий `NFQWS2_OPT`. Удобнее всего кнопкой **Blockcheck** в
   панели: она запускает штатный подбор стратегии.
4. Нажмите **Start** и проверьте обычный интернет и VPN.
5. Только после этого оставляйте сервис включённым.

Важно:

- **Штатная стратегия из пакета может ломать VPN и обычный интернет.** Сначала
  подберите `NFQWS2_OPT`, потом запускайте. Если доступ уже пропал — остановите
  сервис правым кликом или `omarchy-shell doopath.zapret toggle`.
- **Автозапуска нет.** Сервис остаётся `disabled`: запуск только вручную или из
  плагина.
- **Плагин не трогает firewall.** `/etc/nftables.conf` и `ufw` не изменяются,
  `nft flush` не вызывается. `ExecStop` юнита сам снимает свои правила.
- **После Stop может остаться пустая таблица `inet zapret2`** с сетами — это
  поведение upstream, активных правил там нет. Не делайте
  `nft flush ruleset`. Если кастомных правил zapret нет, таблицу можно удалить
  точечно:

  ```bash
  sudo nft delete table inet zapret2
  ```

## Обновление

```bash
omarchy plugin update doopath.zapret
```

После обновления переустановите helper, если менялись файлы в `scripts/`:

```bash
sudo ~/.config/omarchy/plugins/doopath.zapret/scripts/install-helper.sh
```

## Удаление

Сначала уберите helper, затем плагин:

```bash
sudo ~/.config/omarchy/plugins/doopath.zapret/scripts/uninstall-helper.sh
omarchy plugin disable doopath.zapret
omarchy plugin remove doopath.zapret --yes
```

Не забудьте удалить строку `o.bind("SUPER + SHIFT + Z", ...)` из
`~/.config/hypr/bindings.lua` и выполнить `hyprctl reload`.

Плагин не удаляет сам zapret2. Если пакет больше не нужен:

```bash
sudo pacman -Rns zapret2
```

## Диагностика

**В панели `sudo: a password is required`.**

Helper или sudoers не установлены, либо правило выдано другому пользователю.
Переустановите и проверьте:

```bash
sudo ~/.config/omarchy/plugins/doopath.zapret/scripts/install-helper.sh
sudo -n /usr/local/bin/zapret-ctl stop
sudo visudo -cf /etc/sudoers.d/zapret-ctl
```

Убедитесь, что в `/etc/sudoers` есть `@includedir /etc/sudoers.d` и нет
`Defaults requiretty`. Установщик предупредит, если include отсутствует.

**Состояние `missing` или `Unit zapret2.service not found`.**

Пакет не установлен либо нет бинаря:

```bash
pacman -Q zapret2
ls -l /opt/zapret2/nfq2/nfqws2 /usr/bin/nfqws2
systemctl show zapret2 -p LoadState
yay -S zapret2
```

Статус подхватится в течение 2.5 с; при необходимости обновите вручную:

```bash
omarchy-shell doopath.zapret refresh
```

**Start «ничего не делает», сервис сразу становится `inactive`.**

Скорее всего, в конфиге `NFQWS2_ENABLE=0` — демона нет, systemd сразу
останавливает юнит. Проверьте конфиг и журнал:

```bash
grep -n NFQWS2_ENABLE /opt/zapret2/config
sudo zapret-ctl logs
```

**После включения пропал интернет или VPN.**

Остановите сервис правым кликом или командой:

```bash
omarchy-shell doopath.zapret toggle
```

Затем подберите другую стратегию через Blockcheck. Не оставляйте дефолтный
`NFQWS2_OPT` при активном VPN.

**Blockcheck или Logs не открываются, окно мигает.**

Проверьте, что работают запуск терминала и сам helper:

```bash
omarchy-launch-floating-terminal-with-presentation \
  'sudo -n /usr/local/bin/zapret-ctl logs'
```

Если команда не открывает терминал, проблема в `xdg-terminal-exec` или
настройке терминала Omarchy, а не в плагине.

**Горячая клавиша не работает.**

```bash
omarchy menu keybindings --print
hyprctl configerrors
omarchy-shell doopath.zapret toggle
```

**Плагин не появился в баре.**

```bash
omarchy plugin list --json | grep doopath.zapret
omarchy-shell shell rescanPlugins
journalctl --user -b | grep omarchy-shell
```

## Безопасность

- Плагины Omarchy работают без песочницы внутри `omarchy-shell`. Код плагина
  небольшой, без сети, `eval` и подстановки пользовательских строк в shell.
- Из QML вызывается только `sudo -n /usr/local/bin/zapret-ctl <verb>`; список
  команд захардкожен, аргументы дальше не передаются.
- Helper написан на `set -euo pipefail`, использует фиксированный `PATH`,
  проверяет число аргументов и разбирает команду через `case`. `status`
  работает без root, `logs` и `blockcheck` запускаются через `exec`.
- Sudoers разрешает ровно пять команд. Общий sudo не выдаётся, `pkexec` на
  каждый клик не используется.
- Сервис не добавляется в автозапуск, `/etc/nftables.conf` и `ufw` не
  изменяются.

## Разработка

Структура проекта:

```
manifest.json                 # манифест плагина (schemaVersion 1)
BarWidget.qml                 # иконка, опрос статуса, IPC, действия
Panel.qml                     # панель управления
scripts/zapret-ctl            # root-helper
scripts/zapret-ctl.sudoers    # шаблон правила sudoers
scripts/install-helper.sh     # установка helper'а
scripts/uninstall-helper.sh   # удаление helper'а
```

Локальная установка симлинком:

```bash
ln -s "$PWD" ~/.config/omarchy/plugins/doopath.zapret
omarchy-shell shell rescanPlugins
omarchy plugin enable doopath.zapret right
```

Симлинк удобен для правок, но шелл предупреждает, что путь лежит вне конфига, а
hot-reload через него ненадёжен. После изменений:

```bash
omarchy-shell shell rescanPlugins
# если код не подхватился:
omarchy restart shell
```

Проверки перед коммитом:

```bash
omarchy plugin validate .
bash -n scripts/zapret-ctl scripts/install-helper.sh scripts/uninstall-helper.sh
visudo -cf scripts/zapret-ctl.sudoers
```

`qmllint` из состава Qt не разбирает сигнатуры `IpcHandler` и падает даже на
штатных плагинах Omarchy — это ограничение инструмента, а не ошибка плагина.

## Лицензия

MIT. См. [LICENSE](LICENSE).
