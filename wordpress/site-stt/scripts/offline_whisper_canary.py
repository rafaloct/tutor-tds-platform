#!/usr/bin/env python3
"""Canário offline do STT de DITADO DO SITE (nunca vídeos).

Aceita somente áudio WAV fornecido explicitamente e produz relatório local.
A execução na GPU é opcional: a interface do WordPress NÃO depende desse script.
"""
import argparse
import json
import re
import subprocess
import sys
import unicodedata
from pathlib import Path


def normalize(text: str) -> list[str]:
    stripped = unicodedata.normalize("NFD", text.casefold())
    stripped = "".join(c for c in stripped if unicodedata.category(c) != "Mn")
    return re.findall(r"[a-z0-9]+", stripped)


def word_error_rate(reference: str, hypothesis: str) -> float:
    ref, hyp = normalize(reference), normalize(hypothesis)
    if not ref:
        return 0.0 if not hyp else 1.0
    previous = list(range(len(hyp) + 1))
    for i, expected in enumerate(ref, 1):
        row = [i]
        for j, actual in enumerate(hyp, 1):
            row.append(min(
                previous[j] + 1, row[j - 1] + 1,
                previous[j - 1] + (expected != actual),
            ))
        previous = row
    return previous[-1] / len(ref)


def gpu_free_mib() -> int | None:
    try:
        output = subprocess.check_output(
            ["nvidia-smi", "--query-gpu=memory.free", "--format=csv,noheader,nounits"],
            text=True, timeout=5,
        ).strip().splitlines()
        return int(output[0]) if output else None
    except (OSError, subprocess.CalledProcessError, ValueError, subprocess.TimeoutExpired):
        return None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--audio", type=Path, required=True, help="WAV de teste, NUNCA aula/vídeo")
    parser.add_argument("--reference", required=True, help="Transcrição esperada do WAV de teste")
    parser.add_argument("--model", default="base", help="Whisper multilingual (tiny/base/small), padrão base")
    parser.add_argument("--device", choices=["cuda", "cpu"], default="cuda")
    parser.add_argument("--min-free-mib", type=int, default=4096)
    parser.add_argument("--cache", type=Path, default=Path("models"))
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--allow-model-download", action="store_true")
    parser.add_argument("--max-wer", type=float, default=0.35, help="Limite de erro para aprovação do canário")
    args = parser.parse_args()
    if not args.audio.is_file() or args.audio.suffix.lower() != ".wav":
        parser.error("Audio WAV de teste obrigatório.")
    if args.device == "cuda":
        free = gpu_free_mib()
        if free is None or free < args.min_free_mib:
            print(f"BLOCKED: GPU livre={free} MiB, mínimo {args.min_free_mib} MiB.",file=sys.stderr)
            return 2
    try:
        from faster_whisper import WhisperModel
    except ImportError:
        print("BLOCKED: instalar faster-whisper em um venv isolado.", file=sys.stderr)
        return 2
    model = WhisperModel(
        args.model, device=args.device,
        compute_type="int8_float16" if args.device == "cuda" else "int8",
        download_root=str(args.cache),
        local_files_only=not args.allow_model_download,
        cpu_threads=2, num_workers=1,
    )
    segments, info = model.transcribe(
        str(args.audio), language="pt", beam_size=3, vad_filter=False,
        condition_on_previous_text=False,
    )
    transcript = " ".join(segment.text.strip() for segment in segments).strip()
    metric = word_error_rate(args.reference, transcript)
    report = {
        "scope": "site-live-dictation-canary-only",
        "model": args.model, "device": args.device,
        "language_expected": "pt-BR", "language_detected": info.language,
        "reference": args.reference, "hypothesis": transcript,
        "word_error_rate": round(metric, 5),
        "acceptance_max_wer": args.max_wer,
        "status": "PASS" if metric <= args.max_wer else "BLOCKED",
        "gpu_free_before_mib": gpu_free_mib() if args.device == "cuda" else None,
        "note": "Amostra sintética não comprova acurácia em sotaques, ruído ou dispositivos reais.",
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False))
    return 0 if transcript and metric <= args.max_wer else 2


if __name__ == "__main__":
    sys.exit(main())
