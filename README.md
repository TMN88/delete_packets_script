# Delete Packets Script for OpenWrt

Интерактивный деинсталлятор компонентов OpenWrt.

## Запуск

Подключись к роутеру по SSH под `root` и выполни:

```sh
wget -O /tmp/delete_packets_script.sh https://raw.githubusercontent.com/TMN88/delete_packets_script/main/delete_packets_script.sh && sh /tmp/delete_packets_script.sh
```

## Меню

При каждом запуске показывается один и тот же список:

1. Podkop
2. Forkop
3. Forkozz
4. YouTube Watchdog
5. Site Checker 2.0
6. VPN Failover
7. AmneziaWG
0. Выход

За один запуск выбирается один компонент. Если он не обнаружен, скрипт сообщает об этом и ничего не удаляет. Перед удалением показывается план; продолжение требует ввести `DELETE`.

## Ограничения

- Удаляются только пакеты, перечисленные для выбранного компонента. Системные пакеты не предлагаются; `--autoremove` не используется.
- Podkop удаляется в порядке `luci-i18n-podkop-ru`, `luci-app-podkop`, `podkop`, чтобы сначала убрать зависимый LuCI-компонент.
- Для Forkozz удаляются только `luci-i18n-netshift-ru`, `luci-app-netshift` и `netshift`; `sing-box` и конфигурация NetShift сохраняются.
- Перед запуском рекомендуется сделать резервную копию. Настройки интерфейсов AmneziaWG могут сохраниться.
- У Watchdog сохраняются вручную добавленные SSH-ключи; удаляются только файлы самого компонента.
- Скрипт рассчитан на BusyBox `ash`, `opkg` (OpenWrt 24.10) и `apk` (OpenWrt 25.12+). Функциональная проверка на физическом роутере не проводилась.

