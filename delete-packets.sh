#!/bin/sh
# Packets Delete — interactive package removal and cleanup tool for OpenWrt.
# BusyBox ash compatible; supports apk (OpenWrt 25.12+) and opkg (OpenWrt 24.10).
set -u

VERSION="1.0"
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
RELEASE="$(sed -n \"s/^DISTRIB_RELEASE='\\([^']*\\)'.*/\\1/p\" /etc/openwrt_release | head -n 1)"

# Conservative protection: core packages, language package, kernel and all kmods
# are never eligible for selection, including the REMOVE ALL option.
KEEP_EXACT='base-files busybox ca-bundle dnsmasq dropbear firewall4 fstools fwtool libc libgcc libubox libubus logd mtd netifd opkg apk procd procd-seccomp rpcd uci uclient-fetch urandom-seed urngd wpad-basic-mbedtls wpad-basic-openssl wpad-mbedtls wpad-openssl luci luci-base luci-light luci-i18n-base-ru'
is_protected() {
  p="$1"
  for k in $KEEP_EXACT; do [ "$p" = "$k" ] && return 0; done
  case "$p" in kernel*|kmod-*|libubox*|libubus*|libuci*|libblobmsg-json*|libjson-c*|libjson-script*|libubus-lua*) return 0 ;; esac
  return 1
}

list_installed() {
  if [ "$PM" = apk ]; then apk info 2>/dev/null | sed '/^[[:space:]]*$/d' | sort -u
  else opkg list-installed 2>/dev/null | awk '{print $1}' | sort -u; fi
}
pkg_installed() {
  if [ "$PM" = apk ]; then apk info -e "$1" >/dev/null 2>&1
  else opkg list-installed 2>/dev/null | grep -q "^$1 "; fi
}
pkg_description() {
  if [ "$PM" = apk ]; then apk info -d "$1" 2>/dev/null | sed -n '2p' | tr '\n\r\t' '   ' | cut -c1-60
  else opkg info "$1" 2>/dev/null | sed -n 's/^Description: //p' | head -n 1 | tr '\n\r\t' '   ' | cut -c1-60; fi
}

# Stop/remove service files and configuration only for recognized add-on packages.
# Unknown package-owned files are left to apk/opkg; never blanket-delete /etc or /overlay.
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
    zapret|zapret-manager|luci-app-zapret)
      /etc/init.d/zapret stop >/dev/null 2>&1 || true
      /etc/init.d/zapret disable >/dev/null 2>&1 || true
      rm -f /etc/init.d/zapret /etc/config/zapret
      rm -rf /opt/zapret /usr/share/zapret /usr/lib/zapret
      ;;
    zapret2|luci-app-zapret2)
      /etc/init.d/zapret2 stop >/dev/null 2>&1 || true
      /etc/init.d/zapret2 disable >/dev/null 2>&1 || true
      rm -f /etc/init.d/zapret2 /etc/config/zapret2
      rm -rf /opt/zapret2
      ;;
    amneziawg|amneziawg-tools|luci-proto-amneziawg)
      /etc/init.d/amneziawg stop >/dev/null 2>&1 || true
      /etc/init.d/amneziawg disable >/dev/null 2>&1 || true
      rm -f /etc/init.d/amneziawg
      ;;
    luci-app-site-checker|site-checker|luci-app-site_checker)
      rm -f /usr/lib/lua/luci/controller/sitecheck.lua /usr/lib/lua/luci/controller/site_checker.lua
      rm -f /usr/lib/lua/luci/view/sitecheck/index.htm /usr/libexec/sitecheck-check /usr/libexec/sitecheck-check-zapret /usr/libexec/sitecheck-system-sites
      rm -f /usr/share/luci/menu.d/luci-app-site-checker.json /etc/config/sitecheck
      rm -rf /usr/share/site-checker
      ;;
    podkop-vpn-failover|vpn-failover|awg-test)
      /etc/init.d/podkop-vpn-failover stop >/dev/null 2>&1 || true
      /etc/init.d/podkop-vpn-failover disable >/dev/null 2>&1 || true
      /etc/init.d/awg-test stop >/dev/null 2>&1 || true
      /etc/init.d/awg-test disable >/dev/null 2>&1 || true
      rm -f /etc/init.d/podkop-vpn-failover /etc/init.d/awg-test
      rm -f /usr/bin/podkop-vpn-failover /usr/bin/podkop-vpn-failover-control /usr/bin/awg-test
      rm -rf /usr/share/podkop-vpn-failover
      ;;
  esac
}

cleanup_package_caches() {
  if [ "$PM" = apk ]; then
    apk cache clean >/dev/null 2>&1 || true
    rm -rf /var/cache/apk/* 2>/dev/null || true
  else
    rm -rf /tmp/opkg-lists/* 2>/dev/null || true
    rm -f /tmp/opkg-*.ipk 2>/dev/null || true
  fi
  rm -f /tmp/*.apk 2>/dev/null || true
}

remove_one() {
  p="$1"
  if is_protected "$p"; then warn "Защищён системный пакет, пропуск: $p"; return 2; fi
  if ! pkg_installed "$p"; then info "Пакет уже отсутствует: $p"; return 0; fi
  step "Удаление $p"
  cleanup_artifacts "$p"
  if [ "$PM" = apk ]; then apk del "$p"; else opkg remove "$p"; fi
  rc=$?
  if [ "$rc" -ne 0 ]; then err "Пакетный менеджер не смог удалить $p (код $rc)."; return 1; fi
  cleanup_artifacts "$p"
  ok "Удалён: $p"
  return 0
}

clear 2>/dev/null || true
cat <<'BANNER'
+----------------------------------------------------+
|                  PACKETS DELETE                    |
|        Удаление пакетов для OpenWrt                |
+----------------------------------------------------+
BANNER
printf 'Роутер: %s\nOpenWrt: %s\nПакетный менеджер: %s\n\n' "$MODEL" "${RELEASE:-неизвестно}" "$PM"
warn 'УДАЛИТЬ ВСЁ удаляет все незашищённые пакеты. Базовые компоненты, ядро, kmod-* и luci-i18n-base-ru защищены.'

PACKAGES_FILE="$TMP_DIR/packages.txt"
SELECT_FILE="$TMP_DIR/selected.txt"
list_installed > "$PACKAGES_FILE"
[ -s "$PACKAGES_FILE" ] || { err 'Не удалось получить список установленных пакетов.'; exit 1; }

INDEX=0
while IFS= read -r package; do
  [ -n "$package" ] || continue
  INDEX=$((INDEX + 1))
  if is_protected "$package"; then marker='[ЗАЩИЩЁН]'; else marker=''; fi
  desc="$(pkg_description "$package")"
  printf '%4d) %-40s %-11s %s\n' "$INDEX" "$package" "$marker" "$desc"
done < "$PACKAGES_FILE"
printf '\nВсего пакетов: %s\n\n' "$INDEX"
cat <<'MENU'
Выберите действие:
  Введите номера пакетов через пробел или запятую (например: 4 7 12)
  A) УДАЛИТЬ ВСЁ (все незашищённые пакеты)
  Q) Выход без изменений
MENU

while :; do
  printf '\nВаш выбор: '
  if ! IFS= read -r CHOICE; then info 'Ввод завершён. Выход без изменений.'; exit 0; fi
  CHOICE="$(printf '%s' "$CHOICE" | tr '[:lower:]' '[:upper:]')"
  case "$CHOICE" in
    Q|QUIT|EXIT) info 'Выход без изменений.'; exit 0 ;;
    A|ALL) break ;;
  esac
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

: > "$SELECT_FILE"
if [ "$CHOICE" = A ] || [ "$CHOICE" = ALL ]; then
  while IFS= read -r package; do is_protected "$package" || printf '%s\n' "$package" >> "$SELECT_FILE"; done < "$PACKAGES_FILE"
else
  for t in $TOKENS; do
    package="$(sed -n "${t}p" "$PACKAGES_FILE")"
    [ -n "$package" ] || continue
    if is_protected "$package"; then warn "$package защищён и будет пропущен."; else printf '%s\n' "$package" >> "$SELECT_FILE"; fi
  done
fi
sort -u "$SELECT_FILE" -o "$SELECT_FILE"
[ -s "$SELECT_FILE" ] || { info 'Нет доступных для удаления пакетов.'; exit 0; }

printf '\nПлан удаления:\n'
while IFS= read -r package; do printf ' - %s\n' "$package"; done < "$SELECT_FILE"
printf '\nДля подтверждения введите DELETE: '
IFS= read -r CONFIRM || CONFIRM=''
[ "$CONFIRM" = DELETE ] || { info 'Удаление отменено.'; exit 0; }

NEED_REBOOT=0
FAILS=0
REMOVED=0
while IFS= read -r package; do
  [ -n "$package" ] || continue
  case "$package" in kernel*|kmod-*) NEED_REBOOT=1 ;; esac
  if remove_one "$package"; then REMOVED=$((REMOVED + 1)); else rc=$?; [ "$rc" -eq 2 ] || FAILS=$((FAILS + 1)); fi
done < "$SELECT_FILE"

step 'Очистка кеша и временных файлов'
cleanup_package_caches
ok 'Кеш пакетного менеджера очищен.'
printf '\nИТОГ: успешно обработано пакетов: %s; ошибок: %s.\n' "$REMOVED" "$FAILS"
if [ "$NEED_REBOOT" -eq 1 ]; then
  warn 'В выбранном списке были kernel/kmod-пакеты; обычно они защищены, но проверьте сообщения пакетного менеджера. Перезагрузка может потребоваться.'
  printf 'Перезагрузить роутер сейчас? [y/N]: '
  IFS= read -r REBOOT_CHOICE || REBOOT_CHOICE=''
  case "$REBOOT_CHOICE" in y|Y|yes|YES|д|Д|да|ДА) sync; reboot ;; *) info 'Перезагрузка пропущена.' ;; esac
else
  info 'Перезагрузка не требуется: ядро и kernel modules не удалялись.'
fi
exit "$FAILS"
