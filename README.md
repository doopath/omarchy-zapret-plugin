# doopath.zapret

Нативный плагин бара [Omarchy](https://omarchy.org/) для управления системным
сервисом **zapret2** (`bol-van/zapret2`, AUR-пакет `zapret2`).

В баре — иконка-щит с состоянием сервиса, по левому клику — popup с
Start / Stop / Restart / Blockcheck / Logs, по правому — toggle, по среднему —
restart. Горячая клавиша по умолчанию — `SUPER + SHIFT + Z`.

Плагин **не настраивает** zapret2 и не переключает стратегии. Он управляет
только юнитом `zapret2.service` и запускает два его инструмента: blockcheck и
journalctl.

## Возможности

- Состояние сервиса в баре: `active` (акцентный цвет), `inactive`
  (приглушённый), `failed` (красный), `missing` (серый, zapret2 не установлен).
- Tooltip: состояние, uptime, подсказки по кнопкам мыши.
- Popup: `ActiveState/SubState`, uptime с `ActiveEnterTimestamp`, путь к
  конфигу `/opt/zapret2/config` и первая строка `NFQWS2_OPT` как «стратегия».
- Start / Stop / Restart через root-helper без запроса пароля.
- Blockcheck и Logs — в плавающем терминале Omarchy.
- Режим «не установлен»: кнопки скрыты, показывается `yay -S zapret2`.
- Ошибки helper'а (stderr, exit code) видны в popup, а не проглатываются.
- Опрос статуса не чаще одного раза в 2.5 с; popup не плодит окна.

## Требования

- Omarchy 4.x с шеллом `omarchy-shell` (Quickshell).
- Установленный AUR-пакет `zapret2`:
  - бинарь `/opt/zapret2/nfq2/nfqws2` (симлинк `/usr/bin/nfqws2`),
  - конфиг `/opt/zapret2/config`,
  - `/opt/zapret2/blockcheck2.sh`,
  - юнит `zapret2.service`.
- root-helper `/usr/local/bin/zapret-ctl` и правило sudoers
  `/etc/sudoers.d/zapret-ctl` (ставится скриптом из этого репозитория).

## Установка

### 1. Root-helper и sudoers

```bash
cd /home/doopath/Files/code/omarchy-zapret-plugin
sudo ./scripts/install-helper.sh
```

Скрипт идемпотентен: копирует `scripts/zapret-ctl` в
`/usr/local/bin/zapret-ctl` (`root:root 0755`), подставляет пользователя,
запустившего `sudo`, в `scripts/zapret-ctl.sudoers`, проверяет файл через
`visudo -cf` и устанавливает его в `/etc/sudoers.d/zapret-ctl` (`root:root
0440`).

Проверка:

```bash
visudo -cf /etc/sudoers.d/zapret-ctl
/usr/local/bin/zapret-ctl status        # без sudo
sudo -n -l /usr/local/bin/zapret-ctl start # NOPASSWD без фактического запуска
```

`status` намеренно **не** входит в sudoers: `systemctl is-active` читается
без root. Разрешены только `start`, `stop`, `restart`, `logs`, `blockcheck`.

### 2. Плагин

Из git (рекомендуется, копия в `~/.config/omarchy/plugins/`):

```bash
omarchy plugin add https://github.com/doopath/omarchy-zapret-plugin.git --enable --yes
```

Локально из этого репозитория:

```bash
omarchy plugin add file:///home/doopath/Files/code/omarchy-zapret-plugin --enable --yes
```

Для разработки можно симлинком:

```bash
ln -s /home/doopath/Files/code/omarchy-zapret-plugin \
      ~/.config/omarchy/plugins/doopath.zapret
omarchy-shell shell rescanPlugins
omarchy plugin enable doopath.zapret right
```

Симлинк работает, но шелл пишет предупреждение
`Module path ... is outside of the config folder`, а hot-reload изменений через
симлинк ненадёжен. После правок в этом режиме:

```bash
omarchy-shell shell rescanPlugins
# если код не подхватился:
omarchy restart shell
```

Для обычной эксплуатации используйте `omarchy plugin add` — он кладёт
настоящую копию в конфиг и hot-reload работает штатно.

Проверка:

```bash
omarchy plugin validate .
omarchy plugin list | grep doopath.zapret
omarchy-shell shell ping
```

### 3. Горячая клавиша

В `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + SHIFT + Z", "Zapret toggle", "omarchy-shell doopath.zapret toggle")
```

Затем:

```bash
hyprctl reload
hyprctl configerrors
```

`SUPER + SHIFT + Z` на момент написания свободна. Если занята — выберите
другую комбинацию и обновите bindings.lua. Плагин не устанавливает клавишу
автоматически.

## Использование

| Действие | Результат |
| --- | --- |
| Левый клик по щиту | открыть/закрыть popup |
| Правый клик | toggle: Start, если не active; Stop, если active |
| Средний клик | Restart |
| `SUPER + SHIFT + Z` | то же, что `omarchy-shell doopath.zapret toggle` |
| `Esc` / клик вне popup | закрыть popup |

IPC:

```bash
omarchy-shell doopath.zapret toggle    # старт/стоп сервиса
omarchy-shell doopath.zapret refresh   # принудительный опрос статуса
omarchy-shell doopath.zapret open      # открыть popup
omarchy-shell doopath.zapret close     # закрыть popup
```

Helper (CLI):

```bash
zapret-ctl status      # без root, exit-код systemctl is-active
sudo zapret-ctl start
sudo zapret-ctl stop
sudo zapret-ctl restart
sudo zapret-ctl logs       # journalctl -u zapret2 -f -n 200
sudo zapret-ctl blockcheck # /opt/zapret2/blockcheck2.sh
```

## Конфиг zapret2 и VPN — важно

Плагин управляет сервисом, но **не** настраивает zapret2. Стратегия обхода
DPI живёт в `/opt/zapret2/config` и в область ответственности плагина не
входит.

Что нужно знать:

- AUR-пакет приходит с `NFQWS2_ENABLE=0`. В этом состоянии `systemctl start`
  применяет nftables-правила, но демона `nfqws2` нет, поэтому systemd сразу
  останавливает юнит. Popup предупреждает об этом строкой
  `NFQWS2_ENABLE=0 — no nfqws2 daemon; Start stops at once`.
- Для реальной работы нужно выставить `NFQWS2_ENABLE=1` и подобрать рабочий
  `NFQWS2_OPT` (blockcheck). **Штатная стратегия из пакета может ломать VPN и
  обычный интернет** — на этой машине она конфликтовала с Happ/VLESS.
  Сначала подберите параметры, только потом запускайте сервис.
- Сервис специально остаётся `disabled`: автозапуска нет, запуск — только
  вручную или из плагина.
- Плагин не редактирует `/etc/nftables.conf`, `ufw` и не вызывает
  `nft flush`. `ExecStop` юнита сам снимает свои цепочки/правила.
- Upstream оставляет после Stop пустую таблицу `inet zapret2` с сетами (в
  комментарии к коду: «leave ifsets and ipsets because they may be used by
  custom rules»). Активных правил там нет; `nft list ruleset | grep zapret`
  может показать таблицу и сеты. Не делайте `nft flush ruleset` из-за этого.
- Если вы не используете кастомные правила zapret, пустую таблицу можно
  удалить точечно: `sudo nft delete table inet zapret2` (это не flush).

## Troubleshooting

**В popup `sudo: a password is required`.** Helper или sudoers не установлены
(либо установлены для другого пользователя):

```bash
sudo ./scripts/install-helper.sh
sudo -n /usr/local/bin/zapret-ctl stop
visudo -cf /etc/sudoers.d/zapret-ctl
```

Убедитесь, что в `/etc/sudoers` включён `@includedir /etc/sudoers.d` и нет
`Defaults requiretty`. Скрипт установки предупреждает, если include отсутствует.

**`Unit zapret2.service not found` / состояние `missing`.** Пакет не установлен
или нет бинаря:

```bash
pacman -Q zapret2
ls -l /opt/zapret2/nfq2/nfqws2 /usr/bin/nfqws2
systemctl show zapret2 -p LoadState
yay -S zapret2
```

После установки пакета статус подхватится в течение 2.5 с; при необходимости
`omarchy-shell doopath.zapret refresh`.

**Start «ничего не делает», сервис сразу inactive.** Смотрите
`NFQWS2_ENABLE` в `/opt/zapret2/config` и журнал:

```bash
grep -n NFQWS2_ENABLE /opt/zapret2/config
sudo -n /usr/local/bin/zapret-ctl logs
```

**Пропал интернет / VPN после включения zapret.** Выключите сервис правым
кликом или `omarchy-shell doopath.zapret toggle`, затем подбирайте стратегию
через blockcheck. Не оставляйте дефолтный `NFQWS2_OPT` при активном VPN.

**Blockcheck/Logs не открываются, а окно мигает.** Проверьте, что
`omarchy-launch-floating-terminal-with-presentation` и терминал по умолчанию
(`xdg-terminal-exec`) работают, и что helper отвечает:

```bash
omarchy-launch-floating-terminal-with-presentation 'sudo -n /usr/local/bin/zapret-ctl logs'
```

**Клавиша не работает.** Проверьте binding и ошибки конфига:

```bash
omarchy menu keybindings --print
hyprctl configerrors
omarchy-shell doopath.zapret toggle
```

**Плагин не появился.** `omarchy plugin list | grep doopath.zapret`; затем
`omarchy-shell shell rescanPlugins`. Логи шелла:
`journalctl --user -b | grep omarchy-shell` (в этой системе журнал юнита
`zapret2` и логи шелла читаются без root; если у вас иначе — используйте
`sudo -n /usr/local/bin/zapret-ctl logs` и `journalctl --user`).

## Удаление

```bash
omarchy plugin disable doopath.zapret
omarchy plugin remove doopath.zapret --yes
sudo ./scripts/uninstall-helper.sh
```

Если ставили симлинком — `omarchy plugin remove` его разлинкует, сам репозиторий
не тронется. Уберите строку с `o.bind("SUPER + SHIFT + Z", ...)` из
`~/.config/hypr/bindings.lua` и выполните `hyprctl reload`.

Сам zapret2 плагин не удаляет. Если он больше не нужен:

```bash
sudo pacman -Rns zapret2
```

(`pre_remove` пакета выполнит `systemctl disable --now zapret2`.)

## Безопасность

- Плагины Omarchy выполняются без песочницы в процессе `omarchy-shell`; код
  плагина маленький, без сети, без `eval` и без подстановки пользовательских
  строк в shell.
- В QML вызывается только `sudo -n /usr/local/bin/zapret-ctl <verb>`; список
  verb'ов захардкожен, аргументы дальше не передаются.
- Helper: `set -euo pipefail`, фиксированный `PATH`, `case "$1"`, проверка
  `$# -eq 1`, никакого `eval`, `status` без root, `logs`/`blockcheck` через
  `exec`.
- sudoers разрешает ровно пять команд. `pkexec` на каждый клик не используется,
  общий sudo не выдаётся.
- Сервис не включается в автозапуск, `/etc/nftables.conf` и `ufw` не
  изменяются.

## Разработка

Структура:

```
manifest.json            # манифест плагина (schemaVersion 1)
BarWidget.qml            # иконка, опрос, IPC, действия
Panel.qml                # popup
scripts/zapret-ctl       # root-helper
scripts/zapret-ctl.sudoers
scripts/install-helper.sh
scripts/uninstall-helper.sh
```

Проверки:

```bash
omarchy plugin validate .
bash -n scripts/zapret-ctl scripts/install-helper.sh scripts/uninstall-helper.sh
visudo -cf scripts/zapret-ctl.sudoers   # синтаксис шаблона (без установки)
```

`qmllint` из состава Qt не разбирает сигнатуры `IpcHandler`
(`function toggle(): void`) и падает даже на штатных плагинах Omarchy — это
ограничение qmlformat/Qt, а не ошибка плагина.

После правок QML:

```bash
omarchy-shell shell rescanPlugins
# надёжнее:
omarchy restart shell
journalctl --user -b | grep -E "doopath.zapret|QQml|ReferenceError"
```

## Проверено на этой машине

- Omarchy 4.0.6-1, Quickshell 0.3.2, Hyprland 0.56.2.
- zapret2 1.0.6-1 (AUR), собран локально.
- `omarchy plugin validate .` — OK, плагин виден в `omarchy plugin list`,
  включён в правой секции бара.
- Start/Stop через helper: 227 мс / 23 мс, без пароля; состояние в popup
  совпадает с `systemctl show`.
- После Start в `nft list ruleset` появляются правила zapret (6 совпадений),
  после Stop активных правил нет (остаётся пустая таблица `inet zapret2` —
  поведение upstream).
- Logs: плавающий терминал открылся с живым `journalctl -u zapret2 -f -n 200` (запуск через ту же команду, что вызывает кнопка плагина).
- Keybind зарегистрирован, `hyprctl configerrors` пуст.
- Состояние `missing` проверено до установки zapret2: кнопки скрыты, видна
  подсказка `yay -S zapret2`.

### Расхождения с исходным ТЗ (зафиксировано)

1. Бинарь zapret2 лежит в `/opt/zapret2/nfq2/nfqws2`, а не в
   `/opt/zapret2/nfqws2`; `/usr/bin/nfqws2` — симлинк на него. Плагин проверяет
   оба пути.
2. `NFQWS2_OPT` в штатном конфиге — многострочный (значение в кавычках на
   несколько строк), а не одна строка. Popup берёт первую содержательную
   строку.
3. `journalctl -u zapret2` на этой машине читается без root (факт из ТЗ о
   запрете не подтвердился). Helper всё равно запускает логи от root — так
   работает на системах с закрытым журналом.
4. Штатный конфиг AUR содержит `NFQWS2_ENABLE=0`: сервис без демона сразу
   завершается. Плагин показывает предупреждение в popup.
5. Штатная стратегия zapret2 ломает интернет и Happ/VLESS на этой машине.
   Конфиг возвращён в исходное состояние (`NFQWS2_ENABLE=0`), сервис выключен.
   Blockcheck не запускался, чтобы не создавать тестовый трафик и не трогать
   VPN; путь helper'а и сам скрипт проверены.

## Лицензия

MIT. См. [LICENSE](LICENSE).
