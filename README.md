# Delete Packets Script for OpenWrt

Интерактивный деинсталлятор компонентов из [TMN88/install_packets_script](https://github.com/TMN88/install_packets_script).

## Запуск

Подключись к роутеру по SSH под `root` и выполни:

```sh
wget -O /tmp/delete_packets_script.sh https://raw.githubusercontent.com/TMN88/delete_packets_script/main/delete_packets_script.sh && sh /tmp/delete_packets_script.sh
```

## Компоненты

- Podkop
- Forkop
- AmneziaWG
- Zapret Manager
- Zapret2 Routerich и классический Zapret2, установленный вручную в `/opt/zapret2`
- AWG Test / Podkop VPN Failover
- Site Checker 2.0
- YouTube Watchdog
- темы LuCI: Footstrap, Argon и Aurora
- русская локализация LuCI

На экране отображаются только обнаруженные компоненты. Можно выбрать несколько номеров, `A` для всех обнаруженных или `Q` для выхода. Перед удалением показывается план; продолжение требует ввести `DELETE`.

## Ограничения

- Удаляются только пакеты, перечисленные для выбранного компонента. Системные пакеты не предлагаются; `--autoremove` не используется.
- Podkop удаляется в порядке `luci-i18n-podkop-ru`, `luci-app-podkop`, `podkop`, чтобы сначала убрать зависимый LuCI-компонент.
- Удаление классического Zapret2 из `/opt/zapret2` требует отдельного подтверждения.
- Скрипт удаляет конфиги, принадлежащие Podkop, Forkop, Zapret, Watchdog и Site Checker. Настройки интерфейсов AmneziaWG могут сохраниться; проверь их отдельно, если хочешь удалить их вручную. Перед запуском рекомендуется сделать резервную копию.
- У Watchdog сохраняются вручную добавленные SSH-ключи; удаляются только файлы самого компонента.
- Скрипт рассчитан на BusyBox `ash`, `opkg` (OpenWrt 24.10) и `apk` (OpenWrt 25.12+). Функциональная проверка на физическом роутере не проводилась.

