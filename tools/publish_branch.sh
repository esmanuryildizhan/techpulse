#!/usr/bin/env bash
# Bir klasörün içeriğini, geçmişi olmayan tek bir commit olarak bir dala zorla gönderir.
# CI çıktılarını (ekran görüntüleri, APK, veri anlık görüntüsü) depoda görünür kılmak için kullanılır.
# Kullanım: GITHUB_TOKEN=... bash tools/publish_branch.sh <dal> <klasör> "<mesaj>"
set -euo pipefail
BRANCH="$1"
SRC="$2"
MESSAGE="$3"
if [ ! -d "$SRC" ] || [ -z "$(ls -A "$SRC")" ]; then
  echo "Gönderilecek dosya yok: $SRC"
  exit 0
fi
WORK="$(mktemp -d)"
cp -R "$SRC"/. "$WORK"/
cd "$WORK"
git init -q -b "$BRANCH"
git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git add -A
git commit -q -m "$MESSAGE"
git push -q -f "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git" "HEAD:refs/heads/$BRANCH"
echo "$BRANCH dalına gönderildi: $(git ls-files | wc -l) dosya"
