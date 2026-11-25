#!/usr/bin/env python3
"""TechPulse makine çevirisi: İngilizce metinleri Türkçeye çevirir.

Model: Helsinki-NLP/opus-mt-tc-big-en-tr (OPUS-MT, Helsinki Üniversitesi, CC BY 4.0).
Model GitHub Actions sunucusunun işlemcisinde çalışır; dış bir servise, hesaba veya
API anahtarına gerek yoktur.

Girdi (stdin):  {"texts": ["...", "..."]}
Çıktı (stdout): {"model": "...", "translations": ["...", "..."], "seconds": 12.3}
Boş metinler boş döner; sıra korunur.
"""
from __future__ import annotations

import json
import os
import sys
import time

MODEL = os.environ.get("MT_MODEL", "Helsinki-NLP/opus-mt-tc-big-en-tr")
BATCH = int(os.environ.get("MT_BATCH", "16"))
BEAMS = int(os.environ.get("MT_BEAMS", "4"))


def log(message: str) -> None:
    print(message, file=sys.stderr, flush=True)


def main() -> int:
    started = time.time()
    request = json.load(sys.stdin)
    texts = [t if isinstance(t, str) else "" for t in request.get("texts", [])]
    out = [""] * len(texts)
    todo = [i for i, t in enumerate(texts) if t.strip()]
    if not todo:
        json.dump({"model": MODEL, "translations": out, "seconds": 0}, sys.stdout, ensure_ascii=False)
        return 0

    import torch
    from transformers import AutoModelForSeq2SeqLM, AutoTokenizer

    torch.set_num_threads(max(1, os.cpu_count() or 1))
    log(f"Model yükleniyor: {MODEL}")
    tokenizer = AutoTokenizer.from_pretrained(MODEL)
    model = AutoModelForSeq2SeqLM.from_pretrained(MODEL)
    model.eval()
    log(f"{len(todo)} metin çevriliyor (parti {BATCH}, ışın {BEAMS})")

    # Benzer uzunluktaki metinleri aynı partiye koymak dolguyu (padding) azaltır, hızı artırır.
    todo.sort(key=lambda i: len(texts[i]))
    with torch.inference_mode():
        for start in range(0, len(todo), BATCH):
            indices = todo[start : start + BATCH]
            encoded = tokenizer(
                [texts[i] for i in indices],
                return_tensors="pt",
                padding=True,
                truncation=True,
                max_length=256,
            )
            generated = model.generate(**encoded, num_beams=BEAMS, max_new_tokens=256)
            decoded = tokenizer.batch_decode(generated, skip_special_tokens=True)
            for i, text in zip(indices, decoded):
                out[i] = " ".join(text.split())
            if (start // BATCH) % 10 == 0:
                log(f"  {min(start + BATCH, len(todo))}/{len(todo)}")

    seconds = round(time.time() - started, 1)
    log(f"Çeviri bitti: {seconds} sn")
    json.dump({"model": MODEL, "translations": out, "seconds": seconds}, sys.stdout, ensure_ascii=False)
    return 0


if __name__ == "__main__":
    sys.exit(main())
