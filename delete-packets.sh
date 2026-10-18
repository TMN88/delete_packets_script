#!/bin/sh
# Packets Delete — remove only components offered by TMN88/install_packets_script.
# BusyBox ash compatible; supports apk (OpenWrt 25.12+) and opkg (OpenWrt 24.10).
set -u

VERSION="1.1"
TMP_DIR="/tmp/delete-packets-$$"
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

# Only components explicitly offered by install_packets_script are candidates.
# Each component has package names and/or installer-created files used for detection.
COMPONENTS_FILE="$TMP_DIR/components.tsv"
cat > "$COMPONENTS_FILE" <<'COMPONENTS'
Podkop	podkop	podkop
Forkop	forkop	forkop
AmneziaWG	amneziawg-tools kmod-amneziawg amneziawg luci-proto-amneziawg	awg
Zapret Manager	zapret-manager luci-app-zapret zapret	zapret
Zapret2 Routerich	zapret2 luci-app-zapret2 luci-i18n-zapret2-ru	zapret2
Zapret2 classic (manual install)		zapret2-classic
AWG Test / Podkop VPN Failover		podkop-vpn-failover
Site Checker	luci-app-site-checker site-checker	luci-app-site-checker
Русская локализация LuCI	luci-i18n-base-ru	luci-ru
USB modules	kmod-usb-core kmod-usb-storage kmod-usb3 kmod-usb2 kmod-usb-xhci-hcd kmod-usb-xhci-mtk kmod-usb-dwc3	usb-modules
COMPONENTS

pkg_installed() {
  p="$1"
  [ -n "$p" ] || return 1
  if [ "$PM" = apk ]; then apk info -e "$p" >/dev/null 2>&1
  else opkg list-installed 2>/dev/null | grep -Fq "$p -"; fi
}
component_detected() {
  case "$1" in
    podkop) pkg_installed podkop || [ -x /etc/init.d/podkop ] || [ -f /etc/config/podkop ] ;;
    forkop) pkg_installed forkop || [ -x /etc/init.d/forkop ] || [ -f /etc/config/forkop ] ;;
    awg) pkg_installed amneziawg-tools || pkg_installed kmod-amneziawg || pkg_installed amneziawg || pkg_installed luci-proto-amneziawg || command -v awg >/dev/null 2>&1 || [ -x /etc/init.d/amneziawg ] ;;
    zapret) pkg_installed luci-app-zapret || pkg_installed zapret || pkg_installed zapret-manager || [ -f /etc/config/zapret ] || [ -x /etc/init.d/zapret ] ;;
    zapret2) pkg_installed zapret2 || pkg_installed luci-app-zapret2 || [ -f /etc/config/zapret2 ] || [ -x /etc/init.d/zapret2 ] || [ -x /opt/zapret2/init.d/openwrt/zapret2 ] ;;
    zapret2-classic) [ -x /opt/zapret2/install_easy.sh ] || [ -d /opt/zapret2/common ] ;;
    podkop-vpn-failover) [ -x /usr/bin/podkop-vpn-failover ] || [ -x /usr/bin/podkop-vpn-failover-control ] || [ -x /etc/init.d/podkop-vpn-failover ] || [ -x /usr/bin/awg-test ] || [ -x /etc/init.d/awg-test ] ;;
    luci-app-site-checker) pkg_installed luci-app-site-checker || pkg_installed site-checker || [ -f /usr/lib/lua/luci/controller/sitecheck.lua ] || [ -f /usr/lib/lua/luci/controller/site_checker.lua ] || [ -f /usr/lib/lua/luci/view/sitecheck/index.htm ] || [ -f /usr/libexec/sitecheck-check ] || [ -f /usr/libexec/sitecheck-check-zapret ] || [ -f /usr/libexec/sitecheck-system-sites ] || [ -f /usr/share/luci/menu.d/luci-app-site-checker.json ] || [ -f /etc/config/sitecheck ] ;;
    luci-ru) pkg_installed luci-i18n-base-ru ;;
    usb-modules) pkg_installed kmod-usb-core && pkg_installed kmod-usb-storage && { pkg_installed kmod-usb3 || pkg_installed kmod-usb2 || pkg_installed kmod-usb-xhci-hcd || pkg_installed kmod-usb-xhci-mtk || pkg_installed kmod-usb-dwc3; } ;;
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
    zapret2-classic)
      /opt/zapret2/init.d/openwrt/zapret2 stop >/dev/null 2>&1 || true
      /opt/zapret2/init.d/openwrt/zapret2 disable >/dev/null 2>&1 || true
      rm -f /etc/init.d/zapret2
      # Explicitly selected classic install only: package manager is not responsible for /opt/zapret2.
      printf 'Удалить каталог /opt/zapret2, включая его конфигурацию? [y/N]: '
      IFS= read -r CONF_OPT || CONF_OPT=''
      case "$CONF_OPT" in y|Y|yes|YES|д|Д|да|ДА) rm -rf /opt/zapret2 ;; *) info 'Каталог /opt/zapret2 оставлен без изменений.' ;; esac
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
  esac
}

component_remove_packages() {
  component="$1"; packages="$2"
  # Remove only package names associated with the selected component. Never use --autoremove.
  for p in $packages; do
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
    podkop|forkop|awg|zapret|zapret2|zapret2-classic|podkop-vpn-failover|luci-app-site-checker)
      cleanup_artifacts "$detect"
      ;;
  esac
  if ! component_remove_packages "$label" "$packages"; then
    warn "$label: часть пакетов могла остаться. Проверьте вывод выше."
    return 1
  fi
  # Clean component artefacts again in case package removal recreated service/config paths.
  case "$detect" in
    podkop|forkop|awg|zapret|zapret2|zapret2-classic|podkop-vpn-failover|luci-app-site-checker)
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
+----------------------------------------------------+
BANNER
printf 'Роутер: %s\nOpenWrt: %s\nПакетный менеджер: %s\n\n' "$MODEL" "${RELEASE:-неизвестно}" "$PM"
warn 'Системные пакеты OpenWrt не отображаются и не удаляются. Будут предложены только известные компоненты из install_packets_script.'

printf 'Компоненты, обнаруженные на роутере:\n'
INDEX=0
: > "$TMP_DIR/detected.tsv"
while IFS="$(printf '\t')" read -r label packages detect; do
  [ -n "$label" ] || continue
  if component_detected "$detect"; then
    INDEX=$((INDEX + 1))
    printf '%s\t%s\t%s\n' "$INDEX" "$label" "$detect" >> "$TMP_DIR/detected.tsv"
    printf ' %2d) %s\n' "$INDEX" "$label"
  fi
done < "$COMPONENTS_FILE"

if [ "$INDEX" -eq 0 ]; then
  info 'Установленные компоненты из списка не обнаружены. Ничего удалять.'
  exit 0
fi

cat <<'MENU'

Выберите действие:
  Введите номера компонентов через пробел или запятую (например: 1 3)
  A) Удалить ВСЕ обнаруженные компоненты из этого установщика
  Q) Выход без изменений
MENU
while :; do
  printf '\nВаш выбор: '
  if ! IFS= read -r CHOICE; then info 'Ввод завершён. Выход без изменений.'; exit 0; fi
  CHOICE="$(printf '%s' "$CHOICE" | tr '[:lower:]' '[:upper:]')"
  case "$CHOICE" in Q|QUIT|EXIT) info 'Выход без изменений.'; exit 0 ;; A|ALL) break ;; esac
  TOKENS="$(printf '%s' "$CHOICE" | tr ',' ' ')"
  VALID=1; SEEN=0
  for t in $TOKENS; do
    SEEN=1
    case "$t" in ''|*[!0-9]*) VALID=0; break ;; esac
    [ "$t" -ge 1 ] 2>/dev/null && [ "$t" -le "$INDEX" ] 2>/dev/null || { VALID=0; break; }
  done
  if [ "$VALID" = 1 ] && [ "$SEEN" = 1 ]; then break; fi
  warn 'Некорректный выбор. Используйте номера из списка, A или Q.'
done

: > "$TMP_DIR/selected.tsv"
if [ "$CHOICE" = A ] || [ "$CHOICE" = ALL ]; then
  cp "$TMP_DIR/detected.tsv" "$TMP_DIR/selected.tsv"
else
  for t in $TOKENS; do sed -n "${t}p" "$TMP_DIR/detected.tsv" >> "$TMP_DIR/selected.tsv"; done
fi

printf '\nПлан удаления компонентов:\n'
while IFS="$(printf '\t')" read -r n label detect; do
  printf ' - %s\n' "$label"
  # Show exact package list, but do not imply every package is definitely installed.
  while IFS="$(printf '\t')" read -r clabel packages cdetect; do
    [ "$clabel" = "$label" ] || continue
    for p in $packages; do pkg_installed "$p" && printf '     пакет: %s\n' "$p"; done
  done < "$COMPONENTS_FILE"
  [ "$detect" = zapret2-classic ] && printf '     сторонние файлы: /opt/zapret2 (отдельное подтверждение)
'
done < "$TMP_DIR/selected.tsv"
printf '\nДля подтверждения введите DELETE: '
IFS= read -r CONFIRM || CONFIRM=''
[ "$CONFIRM" = DELETE ] || { info 'Удаление отменено.'; exit 0; }

FAILS=0
DONE=0
while IFS="$(printf '\t')" read -r n label detect; do
  packages=''
  while IFS="$(printf '\t')" read -r clabel cpkg cdetect; do
    if [ "$clabel" = "$label" ]; then packages="$cpkg"; break; fi
  done < "$COMPONENTS_FILE"
  if remove_component "$label" "$packages" "$detect"; then DONE=$((DONE + 1)); else FAILS=$((FAILS + 1)); fi
done < "$TMP_DIR/selected.tsv"

step 'Очистка временных файлов'
if [ "$PM" = apk ]; then apk cache clean >/dev/null 2>&1 || true; rm -rf /var/cache/apk/* 2>/dev/null || true
else rm -rf /tmp/opkg-lists/* 2>/dev/null || true; rm -f /tmp/opkg-*.ipk 2>/dev/null || true
fi
ok 'Очистка кэша выполнена.'
printf '\nИТОГ: обработано компонентов: %s; ошибок: %s.\n' "$DONE" "$FAILS"
info 'Системные пакеты OpenWrt не выбирались для удаления.'
exit "$FAILS"
