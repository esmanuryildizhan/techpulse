#!/usr/bin/env bash
# Android emülatöründe yayın APK'sını kurar, açar, sekmeleri gezer, ekran görüntüsü alır
# ve uygulama çöktü mü diye sistem kayıtlarını (logcat) kontrol eder.
# Kullanım: bash tools/emulator_smoke.sh TechPulse.apk cikti-klasoru
set -euo pipefail

APK="$1"
OUT="$2"
PKG="com.techpulse.techpulse"
mkdir -p "$OUT"

adb wait-for-device
adb shell 'while [ "$(getprop sys.boot_completed)" != "1" ]; do sleep 1; done'
adb install -r "$APK"
adb logcat -c

shot() {
  sleep "$2"
  adb exec-out screencap -p > "$OUT/$1.png"
  echo "ekran görüntüsü: $1"
}
tap() { adb shell input tap "$1" "$2"; }

read -r W H < <(adb shell wm size | tr -d '\r' | awk -F'[ x]' '/Physical/ {print $3, $4}')
echo "ekran: ${W}x${H}"
NAV_Y=$((H * 2210 / 2400))
col() { echo $((W * (2 * $1 + 1) / 8)); }

adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 > /dev/null
shot 01_gundem 15

tap $((W / 2)) $((H * 650 / 2400))
shot 02_haber_detayi 4
adb shell input keyevent 4
sleep 2

tap "$(col 1)" "$NAV_Y"
shot 03_yz_radari 8

tap "$(col 2)" "$NAV_Y"
shot 04_guvenlik 8

tap "$(col 0)" "$NAV_Y"
sleep 2
tap "$(col 3)" "$NAV_Y"
shot 05_kaydedilenler 4

adb logcat -d > "$OUT/logcat.txt"
if grep -q "FATAL EXCEPTION" "$OUT/logcat.txt"; then
  echo "HATA: uygulama çöktü"
  grep -A 30 "FATAL EXCEPTION" "$OUT/logcat.txt" | head -60
  exit 1
fi
if ! adb shell pidof "$PKG" > /dev/null; then
  echo "HATA: uygulama çalışmıyor"
  exit 1
fi
grep -E "flutter|TechPulse" "$OUT/logcat.txt" | tail -40 || true
echo "Duman testi başarılı."
