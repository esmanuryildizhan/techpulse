#!/usr/bin/env python3
"""`flutter create` ile oluşturulan Android/iOS klasörlerine TechPulse ayarlarını uygular.

Yaptıkları (hepsi tekrar çalıştırılabilir; ikinci çalıştırmada bir şey değiştirmez):
  * AndroidManifest.xml: INTERNET izni, uygulama adı "TechPulse", https bağlantılarını açma sorgusu
  * build.gradle(.kts): sabit hata ayıklama anahtarıyla imzalama (güncellemeler üst üste kurulabilsin)
  * iOS Info.plist: görünen ad "TechPulse"

Kullanım:  python3 tools/patch_platforms.py app
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

APP_NAME = "TechPulse"

INTERNET = '<uses-permission android:name="android.permission.INTERNET"/>'
HTTPS_QUERY = (
    '<intent>\n'
    '            <action android:name="android.intent.action.VIEW"/>\n'
    '            <data android:scheme="https"/>\n'
    '        </intent>'
)

SIGNING_KTS = """    signingConfigs {
        getByName("debug") {
            // Sabit anahtar: her derleme aynı imzayı taşır, yeni APK eskisinin üstüne kurulabilir.
            storeFile = file("../../android-config/debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
    }
"""

SIGNING_GROOVY = """    signingConfigs {
        debug {
            storeFile file("../../android-config/debug.keystore")
            storePassword "android"
            keyAlias "androiddebugkey"
            keyPassword "android"
        }
    }
"""


def patch_manifest(path: Path) -> list[str]:
    text = path.read_text(encoding="utf-8")
    changes = []
    if "android.permission.INTERNET" not in text:
        text = re.sub(r"(<manifest[^>]*>)", r"\1\n    " + INTERNET, text, count=1)
        changes.append("INTERNET izni")
    new_text = re.sub(r'android:label="[^"]*"', f'android:label="{APP_NAME}"', text, count=1)
    if new_text != text:
        text = new_text
        changes.append("uygulama adı")
    if 'android:scheme="https"' not in text:
        if "<queries>" in text:
            text = text.replace("<queries>", "<queries>\n        " + HTTPS_QUERY, 1)
        else:
            text = text.replace("</manifest>", "    <queries>\n        " + HTTPS_QUERY + "\n    </queries>\n</manifest>", 1)
        changes.append("https sorgusu")
    path.write_text(text, encoding="utf-8")
    return changes


def patch_gradle(app_dir: Path, keystore: Path) -> list[str]:
    changes = []
    android_app = app_dir / "android" / "app"
    if not keystore.exists():
        raise SystemExit(f"İmza anahtarı bulunamadı: {keystore}")
    kts = android_app / "build.gradle.kts"
    groovy = android_app / "build.gradle"
    gradle = kts if kts.exists() else groovy
    if not gradle.exists():
        raise SystemExit(f"Gradle dosyası bulunamadı: {gradle}")
    text = gradle.read_text(encoding="utf-8")
    if "debug.keystore" not in text:
        block = SIGNING_KTS if gradle.suffix == ".kts" else SIGNING_GROOVY
        text, count = re.subn(r"(\nandroid\s*\{\n)", r"\1" + block.replace("\\", "\\\\"), text, count=1)
        if count != 1:
            raise SystemExit("build.gradle içinde 'android {' bloğu bulunamadı")
        gradle.write_text(text, encoding="utf-8")
        changes.append("imzalama ayarı")
    return changes


def patch_ios(app_dir: Path) -> list[str]:
    plist = app_dir / "ios" / "Runner" / "Info.plist"
    if not plist.exists():
        return []
    text = plist.read_text(encoding="utf-8")
    new_text = re.sub(
        r"(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)", rf"\g<1>{APP_NAME}\g<2>", text, count=1
    )
    if new_text != text:
        plist.write_text(new_text, encoding="utf-8")
        return ["iOS görünen adı"]
    return []


def main() -> None:
    app_dir = Path(sys.argv[1] if len(sys.argv) > 1 else "app").resolve()
    manifest = app_dir / "android" / "app" / "src" / "main" / "AndroidManifest.xml"
    if not manifest.exists():
        raise SystemExit(f"AndroidManifest.xml bulunamadı: {manifest}")
    changes = patch_manifest(manifest)
    changes += patch_gradle(app_dir, app_dir / "android-config" / "debug.keystore")
    changes += patch_ios(app_dir)
    print("Uygulanan ayarlar:", ", ".join(changes) if changes else "yok (zaten uygulanmış)")


if __name__ == "__main__":
    main()
