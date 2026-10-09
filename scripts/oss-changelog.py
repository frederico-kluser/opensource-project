#!/usr/bin/env python3
"""oss-changelog.py — gera a secção do CHANGELOG (Keep a Changelog) a partir dos
Commits Convencionais desde a última tag. O CHANGELOG é GERADO, nunca reescrito à mão.

Uso:
  python3 oss-changelog.py                 # imprime a secção da próxima versão
  python3 oss-changelog.py --write         # insere em CHANGELOG.md (cria se faltar)
  python3 oss-changelog.py --json          # para agentes
  python3 oss-changelog.py --version 1.4.0 # força o número da versão
  python3 oss-changelog.py --include-all   # inclui também commits fora do padrão

Depende de `scripts/oss-version.py` (cálculo do SemVer) — mantenha-os juntos.
Exit codes: 0 sucesso · 2 uso inválido · 3 erro de git/versão · 5 sem commits para lançar
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from datetime import date
from pathlib import Path

HERE = Path(__file__).resolve().parent

SECTION_BY_TYPE = {
    "feat": ("Features", 2),
    "fix": ("Bug Fixes", 3),
    "perf": ("Performance", 4),
    "refactor": ("Refactoring", 5),
    "docs": ("Documentation", 6),
    "style": ("Style", 7),
    "test": ("Tests", 8),
    "build": ("Build & CI", 9),
    "ci": ("Build & CI", 9),
    "revert": ("Reverts", 10),
    "chore": ("Chores", 11),
}
HEADER_RE = re.compile(r"^(?P<type>[a-zA-Z]+)(?:\((?P<scope>[^)]*)\))?(?P<bang>!)?:\s*(?P<desc>\S.*)$")


def die(msg: str, code: int) -> None:
    print(f"Erro: {msg}", file=sys.stderr)
    sys.exit(code)


def git(*args: str) -> str:
    try:
        out = subprocess.run(["git", *args], capture_output=True, text=True, check=True)
    except FileNotFoundError:
        die("git não está instalado — Solução: instale o git e repita", 3)
    except subprocess.CalledProcessError as exc:
        die(f"git {' '.join(args)} falhou ({exc.stderr.strip() or 'sem detalhe'}) — "
            "Solução: confirme que está dentro de um repositório git", 3)
    return out.stdout.rstrip("\n")


def version_data(from_tag: str | None, bump: str | None) -> dict:
    cmd = [sys.executable, str(HERE / "oss-version.py"), "next", "--json"]
    if from_tag:
        cmd += ["--from-tag", from_tag]
    if bump:
        cmd += ["--bump", bump]
    out = subprocess.run(cmd, capture_output=True, text=True)
    if out.returncode != 0:
        die(f"oss-version.py falhou: {out.stderr.strip()} — "
            "Solução: corra `python3 scripts/oss-version.py next` para ver o detalhe", 3)
    return json.loads(out.stdout)


def commit_shas() -> dict[str, str]:
    """subject -> sha curto (primeira ocorrência)."""
    raw = git("log", "--pretty=format:%h%x00%s")
    mapping: dict[str, str] = {}
    for line in raw.splitlines():
        if "\x00" in line:
            sha, subject = line.split("\x00", 1)
            mapping.setdefault(subject.strip(), sha.strip())
    return mapping


def repo_url() -> str | None:
    try:
        url = subprocess.run(["git", "remote", "get-url", "origin"],
                             capture_output=True, text=True, check=True).stdout.strip()
    except subprocess.CalledProcessError:
        return None
    m = re.search(r"(?:github\.com[:/])([\w.-]+/[\w.-]+?)(?:\.git)?$", url)
    return f"https://github.com/{m.group(1)}/commit" if m else None


def entry(commit: dict, shas: dict[str, str], base_url: str | None, with_links: bool) -> str:
    scope = commit.get("scope")
    desc = commit.get("subject", "")
    m = HEADER_RE.match(desc)
    if m:
        desc = m.group("desc").rstrip(".")
        scope = (m.group("scope") or "").strip() or scope
    sha = shas.get(commit.get("subject", ""), "")
    head = f"**{scope}:** {desc}" if scope else desc
    if sha and with_links and base_url:
        return f"- {head} ([{sha}]({base_url}/{sha}))"
    return f"- {head} ({sha})" if sha else f"- {head}"


def render(data: dict, shas: dict[str, str], base_url: str | None,
           with_links: bool, include_all: bool) -> str:
    version = data["next_version"]
    lines = [f"## [{version}] - {date.today().isoformat()}", ""]
    groups: dict[str, list[str]] = {}

    for c in data.get("breaking", []):
        groups.setdefault("⚠ Breaking Changes", []).append(entry(c, shas, base_url, with_links))
    for c in data.get("features", []):
        groups.setdefault("Features", []).append(entry(c, shas, base_url, with_links))
    for c in data.get("fixes", []):
        groups.setdefault("Bug Fixes", []).append(entry(c, shas, base_url, with_links))
    for c in data.get("other", []):
        section = SECTION_BY_TYPE.get(c.get("type") or "", ("Chores", 11))[0]
        groups.setdefault(section, []).append(entry(c, shas, base_url, with_links))
    if include_all:
        for c in data.get("non_conventional", []):
            groups.setdefault("Outros (fora do padrão)", []).append(f"- {c['subject']}")

    order = ["⚠ Breaking Changes", "Features", "Bug Fixes"] + sorted(
        (s for s in groups if s not in ("⚠ Breaking Changes", "Features", "Bug Fixes")),
        key=lambda s: next((o for n, o in SECTION_BY_TYPE.values() if n == s), 99),
    )
    for section in order:
        if section in groups:
            lines.append(f"### {section}")
            lines.extend(groups[section])
            lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def write_changelog(section: str, path: Path) -> None:
    if not path.exists():
        path.write_text(f"# Changelog\n\nTodas as datas notáveis deste projeto.\n"
                        f"O formato baseia-se em [Keep a Changelog](https://keepachangelog.com/)"
                        f" e o versionamento segue [SemVer](https://semver.org/).\n\n"
                        f"## [Unreleased]\n\n{section}", encoding="utf-8")
        print(f"Criado {path}")
        return
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines(keepends=True)
    insert_at = None
    for i, line in enumerate(lines):
        if line.startswith("## [Unreleased]"):
            for j in range(i + 1, len(lines)):
                if lines[j].startswith("## ["):
                    insert_at = j
                    break
            if insert_at is None:
                insert_at = len(lines)
            break
    if insert_at is None:
        for i, line in enumerate(lines):
            if line.startswith("# "):
                insert_at = i + 1
                break
    if insert_at is None:
        insert_at = 0
    lines[insert_at:insert_at] = [section, "\n"]
    path.write_text("".join(lines), encoding="utf-8")
    print(f"Atualizado {path}")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--from-tag", help="tag base (predef.: última tag)")
    ap.add_argument("--version", help="força o número da versão")
    ap.add_argument("--bump", choices=["major", "minor", "patch", "none"])
    ap.add_argument("--write", action="store_true", help="insere no CHANGELOG.md")
    ap.add_argument("--file", default="CHANGELOG.md", help="ficheiro de destino")
    ap.add_argument("--include-all", action="store_true",
                    help="inclui commits fora do padrão Convencional")
    ap.add_argument("--no-links", action="store_true", help="sem links para commits")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    data = version_data(args.from_tag, args.bump)
    if args.version:
        data["next_version"] = args.version.lstrip("v")
    if data["counts"]["breaking"] + data["counts"]["feat"] + data["counts"]["fix"] == 0 \
            and not args.include_all and data["bump"] == "none":
        print("Erro: não há commits com impacto em versão desde a última tag — "
              "Solução: use --include-all para documentar o resto, ou --bump para forçar",
              file=sys.stderr)
        return 5

    shas = commit_shas()
    base_url = repo_url()
    section = render(data, shas, base_url, not args.no_links, args.include_all)

    if args.json:
        print(json.dumps({"version": data["next_version"], "section": section,
                          "counts": data["counts"]}, indent=2, ensure_ascii=False))
    else:
        print(section, end="")
    if args.write:
        write_changelog(section, Path(args.file))
    return 0


if __name__ == "__main__":
    sys.exit(main())
