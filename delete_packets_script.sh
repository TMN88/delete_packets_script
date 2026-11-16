#!/bin/sh
# Packets Delete — remove only components offered by TMN88/install_packets_script.
# BusyBox ash compatible; supports apk (OpenWrt 25.12+) and opkg (OpenWrt 24.10).
set -u

VERSION="1.3.0"
TMP_DIR="/tmp/delete-packets-script-$$"
mkdir -p "$TMP_DIR" || exit 1
trap 'rm -rf "$TMP_DIR"' EXIT HUP INT TERM

C_RESET='' C_CYAN='' C_GREEN='' C_YELLOW='' C_RED='' C_BOLD=''
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_RESET="$(printf '\033[0m')"; C_CYAN="$(printf '\033[96m')"; C_GREEN="$(printf '\033[92m')"
  C_YELLOW="$(printf '\033[93m')"; C_RED="$(printf '\033[91m')"; C_BOLD="$(printf '\033[95m')"
fi
info() { printf '%s[INFO]%s %s\n' "$C_CYAN" "$C_RESET" "$*"; }
ok() { printf '%s[ OK ]%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf '%s[WARN]%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; }
err() { printf '%s[ERR ]%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
step() { printf '\n%s==>%s %s\n' "$C_BOLD" "$C_RESET" "$*"; }

[ "$(id -u)" = 0 ] || { err 'Запустите скрипт от root.'; exit 1; }
[ -r /etc/openwrt_release ] || { err 'Этот скрипт предназначен для OpenWrt.'; exit 1; }
if command -v apk >/dev/null 2>&1; then PM=apk
elif command -v opkg >/dev/null 2>&1; then PM=opkg
else err 'Не найден пакетный менеджер apk/opkg.'; exit 1; fi

MODEL="$(cat /tmp/sysinfo/model 2>/dev/null || printf 'неизвестна')"
RELEASE="$(sed -n "s/^DISTRIB_RELEASE='\([^']*\)'.*/\1/p" /etc/openwrt_release | head -n 1)"

# Only components listed in the selection menu are candidates.
# Each component has package names and/or installer-created files used for detection.
COMPONENTS_FILE="$TMP_DIR/components.tsv"
cat > "$COMPONENTS_FILE" <<'COMPONENTS'
Podkop	luci-i18n-podkop-ru luci-app-podkop podkop	podkop
Forkop	forkop	forkop
Forkozz	luci-i18n-netshift-ru luci-app-netshift netshift	forkozz
YouTube Watchdog	-	youtube-watchdog
Site Checker 2.0	luci-app-site-checker site-checker	luci-app-site-checker
VPN Failover	-	podkop-vpn-failover
AmneziaWG	luci-i18n-amneziawg-ru luci-proto-amneziawg amneziawg-tools kmod-amneziawg amneziawg	awg
COMPONENTS

pkg_installed() {
  p="$1"
  [ -n "$p" ] || return 1
  if [ "$PM" = apk ]; then apk info -e "$p" >/dev/null 2>&1
  else opkg list-installed 2>/dev/null | grep -Fq "$p -"; fi
}
component_detected() {
  case "$1" in
    podkop) pkg_installed podkop || pkg_installed luci-app-podkop || [ -x /etc/init.d/podkop ] || [ -f /etc/config/podkop ] ;;
    forkop) pkg_installed forkop || [ -x /etc/init.d/forkop ] || [ -f /etc/config/forkop ] ;;
    forkozz) pkg_installed netshift || pkg_installed luci-app-netshift || [ -x /usr/bin/netshift ] || [ -x /etc/init.d/netshift ] ;;
    awg) pkg_installed amneziawg-tools || pkg_installed kmod-amneziawg || pkg_installed amneziawg || pkg_installed luci-proto-amneziawg || command -v awg >/dev/null 2>&1 || [ -x /etc/init.d/amneziawg ] ;;
    zapret) pkg_installed luci-app-zapret || pkg_installed zapret || pkg_installed zapret-manager || [ -f /etc/config/zapret ] || [ -x /etc/init.d/zapret ] ;;
    zapret2) pkg_installed zapret2 || pkg_installed luci-app-zapret2 || [ -f /etc/config/zapret2 ] || [ -x /etc/init.d/zapret2 ] || [ -x /opt/zapret2/init.d/openwrt/zapret2 ] ;;
    podkop-vpn-failover) [ -x /usr/bin/podkop-vpn-failover ] || [ -x /usr/bin/podkop-vpn-failover-control ] || [ -x /etc/init.d/podkop-vpn-failover ] || [ -x /usr/bin/awg-test ] || [ -x /etc/init.d/awg-test ] ;;
    luci-app-site-checker) pkg_installed luci-app-site-checker || pkg_installed site-checker || [ -f /usr/lib/lua/luci/controller/sitecheck.lua ] || [ -f /usr/lib/lua/luci/controller/site_checker.lua ] || [ -f /usr/lib/lua/luci/view/sitecheck/index.htm ] || [ -f /usr/libexec/sitecheck-check ] || [ -f /usr/libexec/sitecheck-check-zapret ] || [ -f /usr/libexec/sitecheck-system-sites ] || [ -f /usr/share/luci/menu.d/luci-app-site-checker.json ] || [ -f /etc/config/sitecheck ] ;;
    youtube-watchdog) [ -x /etc/init.d/youtube-watchdog ] || [ -x /usr/bin/youtube-watchdog ] || [ -s /www/luci-static/resources/view/youtube-watchdog/overview.js ] || [ -f /etc/config/youtube-watchdog ] ;;
    luci-themes) pkg_installed luci-theme-footstrap || pkg_installed luci-theme-argon || pkg_installed luci-app-argon-config || pkg_installed luci-theme-aurora ;;
    *) return 1 ;;
  esac
}

# Component-specific non-package files. Never delete broad system directories or all /opt.
cleanup_artifacts() {
  case "$1" in
    podkop)
      /etc/init.d/podkop stop >/dev/null 2>&1 || true
      /etc/init.d/podkop disable >/dev/null 2>&1 || true
      rm -f /etc/init.d/podkop /etc/config/podkop
      rm -rf /usr/share/podkop /usr/lib/python*/site-packages/podkop
      ;;
    forkozz)
      /etc/init.d/netshift stop >/dev/null 2>&1 || true
      /etc/init.d/netshift disable >/dev/null 2>&1 || true
      ;;
    forkop)
      /etc/init.d/forkop stop >/dev/null 2>&1 || true
      /etc/init.d/forkop disable >/dev/null 2>&1 || true
      rm -f /etc/init.d/forkop /etc/config/forkop
      rm -rf /usr/share/forkop /usr/lib/python*/site-packages/forkop
      ;;
    zapret)
      /etc/init.d/zapret stop >/dev/null 2>&1 || true
      /etc/init.d/zapret disable >/dev/null 2>&1 || true
      rm -f /etc/init.d/zapret /etc/config/zapret
      rm -rf /usr/share/zapret /usr/lib/zapret
      ;;
    zapret2)
      /etc/init.d/zapret2 stop >/dev/null 2>&1 || true
      /etc/init.d/zapret2 disable >/dev/null 2>&1 || true
      rm -f /etc/init.d/zapret2 /etc/config/zapret2
      # Remove only the package-based Routerich files; never wipe /opt/zapret2 here.
      ;;
    podkop-vpn-failover)
      /etc/init.d/podkop-vpn-failover stop >/dev/null 2>&1 || true
      /etc/init.d/podkop-vpn-failover disable >/dev/null 2>&1 || true
      /etc/init.d/awg-test stop >/dev/null 2>&1 || true
      /etc/init.d/awg-test disable >/dev/null 2>&1 || true
      rm -f /etc/init.d/podkop-vpn-failover /etc/init.d/awg-test
      rm -f /usr/bin/podkop-vpn-failover /usr/bin/podkop-vpn-failover-control /usr/bin/awg-test
      rm -rf /usr/share/podkop-vpn-failover
      ;;
    luci-app-site-checker)
      rm -f /usr/lib/lua/luci/controller/sitecheck.lua /usr/lib/lua/luci/controller/site_checker.lua
      rm -f /usr/lib/lua/luci/view/sitecheck/index.htm /usr/libexec/sitecheck-check /usr/libexec/sitecheck-check-zapret /usr/libexec/sitecheck-system-sites
      rm -f /usr/share/luci/menu.d/luci-app-site-checker.json /etc/config/sitecheck
      rm -rf /usr/share/site-checker
      ;;
    youtube-watchdog)
      if [ -x /etc/init.d/youtube-watchdog ]; then
        /etc/init.d/youtube-watchdog stop >/dev/null 2>&1 || true
        /etc/init.d/youtube-watchdog disable >/dev/null 2>&1 || true
      fi
      if command -v flock >/dev/null 2>&1 && command -v timeout >/dev/null 2>&1 && [ -d /tmp/youtube-watchdog ]; then
        exec 7>/tmp/youtube-watchdog/install.lock
        timeout 130 flock -n 7 || { warn 'Обновление или удаление Watchdog уже выполняется; его файлы сохранены.'; return 1; }
        exec 9>/tmp/youtube-watchdog/operation.lock
        timeout 130 flock 9 || { warn 'Проверка Watchdog ещё выполняется; его файлы сохранены.'; return 1; }
      fi
      rm -f /usr/bin/youtube-watchdog /usr/libexec/youtube-watchdog-probe \
        /etc/init.d/youtube-watchdog /usr/libexec/rpcd/youtube-watchdog \
        /usr/share/rpcd/acl.d/luci-app-youtube-watchdog.json \
        /usr/share/luci/menu.d/luci-app-youtube-watchdog.json \
        /www/luci-static/resources/view/youtube-watchdog/overview.js \
        /usr/libexec/youtube-watchdog-uninstall /etc/config/youtube-watchdog
      rmdir /www/luci-static/resources/view/youtube-watchdog 2>/dev/null || true
      rmdir /etc/youtube-watchdog 2>/dev/null || true
      rm -f /tmp/youtube-watchdog/state.json /tmp/youtube-watchdog/latched /tmp/youtube-watchdog/restarts /tmp/youtube-watchdog/interval.changed
      rm -f /tmp/luci-indexcache
      rm -rf /tmp/luci-modulecache
      /etc/init.d/rpcd restart >/dev/null 2>&1 || true
      ;;
  esac
}

component_remove_packages() {
  component="$1"; packages="$2"
  # Remove only package names associated with the selected component. Never use --autoremove.
  for p in $packages; do
    [ "$p" = "-" ] && continue
    if pkg_installed "$p"; then
      step "Удаление пакета $p"
      if [ "$PM" = apk ]; then apk del "$p"; else opkg remove "$p"; fi
      rc=$?
      if [ "$rc" -ne 0 ]; then warn "Не удалось удалить $p (код $rc)."; return 1; fi
    fi
  done
  return 0
}

remove_component() {
  label="$1"; packages="$2"; detect="$3"
  if ! component_detected "$detect"; then info "$label не обнаружен; пропуск."; return 0; fi
  step "Удаление компонента: $label"
  case "$detect" in
    podkop|forkop|forkozz|awg|zapret|zapret2|zapret2-classic|podkop-vpn-failover|luci-app-site-checker|youtube-watchdog|luci-themes)
      cleanup_artifacts "$detect" || return 1
      ;;
  esac
  if ! component_remove_packages "$label" "$packages"; then
    warn "$label: часть пакетов могла остаться. Проверьте вывод выше."
    return 1
  fi
  # Clean component artefacts again in case package removal recreated service/config paths.
  case "$detect" in
    podkop|forkop|forkozz|awg|zapret|zapret2|zapret2-classic|podkop-vpn-failover|luci-app-site-checker|youtube-watchdog|luci-themes)
      cleanup_artifacts "$detect"
      ;;
  esac
  ok "$label обработан."
  return 0
}

clear 2>/dev/null || true
cat <<'BANNER'
+----------------------------------------------------+
|                  PACKETS DELETE                    |
| Удаление только компонентов Install Packets Script |
| Версия 1.3.0                                       |
+----------------------------------------------------+
BANNER
printf 'Роутер: %s\nOpenWrt: %s\nПакетный менеджер: %s\n\n' "$MODEL" "${RELEASE:-неизвестно}" "$PM"
warn 'Системные пакеты OpenWrt не отображаются и не удаляются. Доступны только компоненты из меню ниже.'

cat <<'MENU'
Выбери компонент для удаления:
  1) Podkop
  2) Forkop
  3) Forkozz
  4) YouTube Watchdog
  5) Site Checker 2.0
  6) VPN Failover
  7) AmneziaWG
  0) Выход
MENU
while :; do
  printf '\nНомер: '
  if ! IFS= read -r CHOICE; then info 'Ввод завершён. Выход без изменений.'; exit 0; fi
  case "$CHOICE" in
    0) info 'Выход без изменений.'; exit 0 ;;
    1) LABEL='Podkop'; DETECT=podkop ;;
    2) LABEL='Forkop'; DETECT=forkop ;;
    3) LABEL='Forkozz'; DETECT=forkozz ;;
    4) LABEL='YouTube Watchdog'; DETECT=youtube-watchdog ;;
    5) LABEL='Site Checker 2.0'; DETECT=luci-app-site-checker ;;
    6) LABEL='VPN Failover'; DETECT=podkop-vpn-failover ;;
    7) LABEL='AmneziaWG'; DETECT=awg ;;
    *) warn 'Введи номер от 0 до 7.'; continue ;;
  esac
  break
done

packages=''
while IFS="$(printf '\t')" read -r item_label item_packages item_detect; do
  if [ "$item_label" = "$LABEL" ]; then packages="$item_packages"; break; fi
done < "$COMPONENTS_FILE"

if ! component_detected "$DETECT"; then
  info "$LABEL не обнаружен; ничего не удалено."
  exit 0
fi

printf '\nПлан удаления: %s\n' "$LABEL"
for p in $packages; do
  [ "$p" = "-" ] && continue
  pkg_installed "$p" && printf '  пакет: %s\n' "$p"
done
case "$DETECT" in
  youtube-watchdog|podkop-vpn-failover) printf '  файлы выбранного компонента\n' ;;
esac
printf '\nДля подтверждения введите DELETE: '
IFS= read -r CONFIRM || CONFIRM=''
[ "$CONFIRM" = DELETE ] || { info 'Удаление отменено.'; exit 0; }

FAILS=0
DONE=0
if remove_component "$LABEL" "$packages" "$DETECT"; then DONE=1; else FAILS=1; fi

step 'Очистка временных файлов'
if [ "$PM" = apk ]; then apk cache clean >/dev/null 2>&1 || true; rm -rf /var/cache/apk/* 2>/dev/null || true
else rm -rf /tmp/opkg-lists/* 2>/dev/null || true; rm -f /tmp/opkg-*.ipk 2>/dev/null || true
fi
ok 'Очистка кэша выполнена.'
printf '\nИТОГ: обработано компонентов: %s; ошибок: %s.\n' "$DONE" "$FAILS"
info 'Системные пакеты OpenWrt не выбирались для удаления.'
exit "$FAILS"


