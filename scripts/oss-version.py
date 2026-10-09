#!/usr/bin/env python3
"""oss-version.py — SemVer CALCULADO a partir dos Commits Convencionais desde a última tag.

Regras (as mesmas do Gate 4 da skill):
  feat              -> MINOR
  fix               -> PATCH
  ! / BREAKING CHANGE -> MAJOR
  resto (docs/style/refactor/perf/test/build/ci/chore/revert) -> nenhum

Uso:
  python3 oss-version.py next                 # próximo versão (legível)
  python3 oss-version.py next --json          # para agentes
  python3 oss-version.py next --bump patch    # força um bump (exige justificação ao utilizador)
  python3 oss-version.py next --pre beta      # pré-lançamento: 1.2.3-beta
  python3 oss-version.py current              # versão atual (última tag)
  python3 oss-version.py check-msg "feat(x): adiciona y"   # valida 1 mensagem

Exit codes: 0 sucesso · 2 uso inválido · 3 não é repo git · 4 mensagem inválida
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys

HEADER_RE = re.compile(
    r"^(?P<type>[a-zA-Z]+)(?:\((?P<scope>[^)]*)\))?(?P<bang>!)?:\s*(?P<desc>\S.*)$"
)
BREAKING_RE = re.compile(r"^BREAKING[ -]CHANGE:\s*.+$", re.MULTILINE)
TAG_RE = re.compile(r"^v?(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?$")

TYPES_SEMVER = {"feat": "minor", "fix": "patch"}
KNOWN_TYPES = (
    "feat", "fix", "docs", "style", "refactor", "perf",
    "test", "build", "ci", "chore", "revert",
)


def die(msg: str, code: int) -> None:
    print(f"Erro: {msg}", file=sys.stderr)
    sys.exit(code)


def git(*args: str) -> str:
    try:
        out = subprocess.run(
            ["git", *args], capture_output=True, text=True, check=True
        )
    except FileNotFoundError:
        die("git não está instalado — Solução: instale o git e repita", 3)
    except subprocess.CalledProcessError as exc:
        die(
            f"git {' '.join(args)} falhou ({exc.stderr.strip() or 'sem detalhe'}) — "
            "Solução: confirme que está dentro de um repositório git",
            3,
        )
    return out.stdout.rstrip("\n")


def last_tag() -> str | None:
    out = subprocess.run(
        ["git", "describe", "--tags", "--abbrev=0", "--match", "v[0-9]*"],
        capture_output=True, text=True,
    )
    if out.returncode != 0 or not out.stdout.strip():
        out = subprocess.run(
            ["git", "describe", "--tags", "--abbrev=0"],
            capture_output=True, text=True,
        )
    tag = out.stdout.strip()
    return tag or None


def parse_commits(range_ref: str | None) -> list[dict]:
    spec = f"{range_ref}..HEAD" if range_ref else "HEAD"
    raw = git("log", "--pretty=format:%s%x00%b%x1e", spec)
    commits: list[dict] = []
    for record in raw.split("\x1e"):
        record = record.strip("\n")
        if not record.strip():
            continue
        parts = record.split("\x00", 1)
        subject = parts[0].strip()
        body = parts[1].strip() if len(parts) > 1 else ""
        m = HEADER_RE.match(subject)
        entry = {
            "subject": subject,
            "type": m.group("type").lower() if m else None,
            "scope": (m.group("scope") or "").strip() if m else None,
            "breaking": bool(m and m.group("bang")) or bool(BREAKING_RE.search(body)),
            "conventional": bool(m and m.group("type").lower() in KNOWN_TYPES),
        }
        commits.append(entry)
    return commits


def compute(commits: list[dict], current: str, force: str | None = None,
            pre: str | None = None) -> dict:
    m = TAG_RE.match(current) or TAG_RE.match("0.0.0")
    major, minor, patch = int(m.group(1)), int(m.group(2)), int(m.group(3))

    breaking = [c for c in commits if c["breaking"]]
    features = [c for c in commits if c["type"] == "feat" and not c["breaking"]]
    fixes = [c for c in commits if c["type"] == "fix" and not c["breaking"]]
    others = [
        c for c in commits
        if not c["breaking"] and c["type"] not in ("feat", "fix") and c["conventional"]
    ]
    non_conv = [c for c in commits if not c["conventional"]]

    if force:
        bump = force
    elif breaking:
        bump = "major"
    elif features:
        bump = "minor"
    elif fixes:
        bump = "patch"
    else:
        bump = "none"

    if bump == "major":
        major, minor, patch = major + 1, 0, 0
    elif bump == "minor":
        minor, patch = minor + 1, 0
    elif bump == "patch":
        patch += 1

    nxt = f"{major}.{minor}.{patch}" + (f"-{pre}" if pre else "")
    return {
        "current_tag": current,
        "current_version": current.lstrip("v"),
        "next_version": nxt,
        "next_tag": f"v{nxt}",
        "bump": bump,
        "counts": {
            "breaking": len(breaking),
            "feat": len(features),
            "fix": len(fixes),
            "other": len(others),
            "non_conventional": len(non_conv),
        },
        "breaking": breaking,
        "features": features,
        "fixes": fixes,
        "other": others,
        "non_conventional": non_conv,
    }


def cmd_next(args: argparse.Namespace) -> int:
    tag = args.from_tag or last_tag() or "v0.0.0"
    commits = parse_commits(None if tag == "v0.0.0" and not args.from_tag else tag)
    result = compute(commits, tag, force=args.bump, pre=args.pre)

    if args.json:
        print(json.dumps(result, indent=2, ensure_ascii=False))
        return 0

    print(f"Versão atual : {result['current_version']}  (tag {tag})")
    print(f"Bump         : {result['bump']}")
    print(f"Próxima      : {result['next_version']}  (tag {result['next_tag']})")
    c = result["counts"]
    print(
        f"Commits      : {c['breaking']} breaking · {c['feat']} feat · "
        f"{c['fix']} fix · {c['other']} outros · {c['non_conventional']} fora do padrão"
    )
    if result["non_conventional"]:
        print("\nFora do padrão (corrija antes do release — Gate 1):")
        for cm in result["non_conventional"]:
            print(f"  - {cm['subject']}")
    if result["bump"] == "none":
        print("\nNota: nenhum commit com impacto em versão (feat/fix/BREAKING).")
        print("      Use --bump para forçar, com justificação explícita ao utilizador.")
    return 0


def cmd_current(_args: argparse.Namespace) -> int:
    tag = last_tag()
    print(tag.lstrip("v") if tag else "0.0.0 (sem tags)")
    return 0


def cmd_check_msg(args: argparse.Namespace) -> int:
    if args.file:
        try:
            with open(args.file, encoding="utf-8") as fh:
                msg = fh.read()
        except OSError as exc:
            die(f"não consegui ler {args.file}: {exc} — Solução: passe um caminho válido", 2)
    elif args.message:
        msg = args.message
    else:
        msg = sys.stdin.read()
    subject = msg.splitlines()[0].strip() if msg.strip() else ""
    problems: list[str] = []
    m = HEADER_RE.match(subject)
    if not subject:
        problems.append("mensagem vazia")
    elif not m:
        problems.append(
            "cabeçalho sem o formato `tipo(escopo)!: descrição` (ex.: `feat(auth): adiciona login`)"
        )
    else:
        if m.group("type").lower() not in KNOWN_TYPES:
            problems.append(
                f"tipo `{m.group('type')}` desconhecido; use: {', '.join(KNOWN_TYPES)}"
            )
        if len(subject) > 72:
            problems.append(f"cabeçalho com {len(subject)} chars (máx. 72)")
        if not m.group("desc")[0].islower() and not m.group("desc")[0].isupper():
            problems.append("descrição deve começar por letra")
    if problems:
        for p in problems:
            print(f"Erro: mensagem de commit inválida: {p} — "
                  "Solução: use `tipo(escopo)!: descrição` (Conventional Commits)", file=sys.stderr)
        return 4
    print(f"OK: `{subject}` é um commit convencional válido"
          + (" (BREAKING CHANGE)" if m and (m.group("bang") or BREAKING_RE.search(msg)) else ""))
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd")

    nxt = sub.add_parser("next", help="calcula a próxima versão")
    nxt.add_argument("--from-tag", help="tag base (predef.: última tag v[0-9]*)")
    nxt.add_argument("--bump", choices=["major", "minor", "patch", "none"],
                     help="força um bump (exige justificação ao utilizador)")
    nxt.add_argument("--pre", help="sufixo de pré-lançamento (alpha/beta/rc)")
    nxt.add_argument("--json", action="store_true")
    nxt.set_defaults(func=cmd_next)

    cur = sub.add_parser("current", help="mostra a versão atual")
    cur.set_defaults(func=cmd_current)

    chk = sub.add_parser("check-msg", help="valida uma mensagem de commit")
    chk.add_argument("message", nargs="?", help="mensagem (ou --file / stdin)")
    chk.add_argument("--file", help="ficheiro com a mensagem (ex.: $1 do hook commit-msg)")
    chk.set_defaults(func=cmd_check_msg)

    args = ap.parse_args()
    if not getattr(args, "func", None):
        args = ap.parse_args(["next"] + sys.argv[1:])
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
