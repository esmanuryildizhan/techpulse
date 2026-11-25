#!/usr/bin/env bash
# Android emülatöründe yayın APK'sını kurar, ilk açılış ekranını geçer, sekmeleri ve haber ayrıntısını gezer,
# ekran görüntüsü alır
# ve uygulama çöktü mü diye sistem kayıtlarını (logcat) kontrol eder.
# Kullanım: bash tools/emulator_smoke.sh TechPulse.apk cikti-klasoru
set -euo pipefail

APK="$1"
OUT="$2"
PKG="com.techpulse.techpulse"
mkdir -p "$OUT"

adb wait-for-device
adb shell 'while [ "$(getprop sys.boot_completed)" != "1" ]; do sleep 1; done'
adb shell settings put global hide_error_dialogs 1 || true
sleep 20 # açılıştan sonra sistem uygulamalarının yerleşmesini bekle
adb install -r "$APK"
adb logcat -c

# Emülatörde bazen sistemin kendi uygulamaları (ör. Pixel Launcher) "yanıt vermiyor" penceresi açar ve
# dokunuşları yutar. Böyle bir pencere varsa "Wait" ile kapatılır; uygulamamızla ilgisi yoktur.
dismiss_system_dialog() {
  local xml
  adb shell uiautomator dump /sdcard/ui.xml > /dev/null 2>&1 || return 0
  xml=$(adb shell cat /sdcard/ui.xml | tr -d '\r')
  if grep -q "responding" <<< "$xml"; then
    local b
    b=$(grep -o '<node [^>]*text="Wait"[^>]*>' <<< "$xml" | head -1 | grep -o 'bounds="[^"]*"' || true)
    if [ -n "$b" ]; then
      local nums x1 y1 x2 y2
      nums=$(echo "$b" | grep -o '[0-9]\+' | tr '\n' ' ')
      read -r x1 y1 x2 y2 <<< "$nums"
      adb shell input tap $(((x1 + x2) / 2)) $(((y1 + y2) / 2))
    else
      adb shell input keyevent 4
    fi
    echo "sistem penceresi kapatıldı"
    sleep 2
  fi
}

shot() {
  sleep "$2"
  dismiss_system_dialog
  adb exec-out screencap -p > "$OUT/$1.png"
  echo "ekran görüntüsü: $1"
}
tap() { adb shell input tap "$1" "$2"; }

read -r W H < <(adb shell wm size | tr -d '\r' | awk -F'[ x]' '/Physical/ {print $3, $4}')
echo "ekran: ${W}x${H}"
NAV_Y=$((H * 2222 / 2400))
col() { echo $((W * (2 * $1 + 1) / 8)); }

# Ekrandaki yazıyı erişilebilirlik ağacında (uiautomator) bulup ortasına dokunur; bulamazsa verilen koordinata dokunur.
tap_text() {
  local text="$1" fx="$2" fy="$3" bounds=""
  dismiss_system_dialog
  if adb shell uiautomator dump /sdcard/ui.xml > /dev/null 2>&1; then
    bounds=$(adb shell cat /sdcard/ui.xml | tr -d '\r' | grep -o "<node [^>]*=\"[^\"]*${text}[^\"]*\"[^>]*>" | head -1 \
      | grep -o 'bounds="\[[0-9]*,[0-9]*\]\[[0-9]*,[0-9]*\]"' | head -1 || true)
  fi
  if [ -n "$bounds" ]; then
    local nums
    nums=$(echo "$bounds" | grep -o '[0-9]\+' | tr '\n' ' ')
    read -r x1 y1 x2 y2 <<< "$nums" # (here-string satır sonu ekler; read hata kodu döndürmez)
    tap $(((x1 + x2) / 2)) $(((y1 + y2) / 2))
    echo "dokunuldu: $text"
  else
    tap "$fx" "$fy"
    echo "yedek koordinata dokunuldu: $text"
  fi
}
swipe_up() { dismiss_system_dialog; adb shell input swipe $((W / 2)) $((H * 75 / 100)) $((W / 2)) $((H * 30 / 100)) 450; }

adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 > /dev/null
shot 01_karsilama 15

tap_text "Tüm konularla başla" $((W / 2)) $((H * 2235 / 2400))
shot 02_ana_sayfa 14
swipe_up
shot 03_ana_sayfa_devami 4
swipe_up
shot 04_son_gelismeler 4
adb shell input swipe $((W / 2)) $((H * 25 / 100)) $((W / 2)) $((H * 90 / 100)) 300
adb shell input swipe $((W / 2)) $((H * 25 / 100)) $((W / 2)) $((H * 90 / 100)) 300
sleep 2

tap $((W / 2)) $((H * 800 / 2400))
shot 05_haber_detayi 5
swipe_up
shot 06_haber_detayi_devami 3
swipe_up
shot 07_haber_detayi_kaynak 3
adb shell input keyevent 4
sleep 2

tap_text "Keşfet" "$(col 1)" "$NAV_Y"
shot 08_kesfet 6
swipe_up
shot 09_kesfet_devami 4

tap_text "Kaydedilenler" "$(col 2)" "$NAV_Y"
shot 10_kaydedilenler 4

tap_text "Profil" "$(col 3)" "$NAV_Y"
shot 11_profil 4

tap_text "Ana Sayfa" "$(col 0)" "$NAV_Y"
sleep 2

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
