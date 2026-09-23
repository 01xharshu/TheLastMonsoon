"""Keep the agent entrypoint small and the documentation index navigable."""

from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
handoff = ROOT / "CODEX_HANDOFF.md"
text = handoff.read_text()
lines = text.splitlines()
errors = []

if len(lines) > 60 or len(text) > 6000:
    errors.append(
        f"handoff is {len(lines)} lines/{len(text)} characters; "
        "move completed history to docs/agent/history"
    )

for required in ("Updated:", "IN_PROGRESS", "Next:"):
    if required not in text:
        errors.append(f"handoff lacks {required}")

index = ROOT / "docs/README.md"
for target in re.findall(r"\]\(([^)]+)\)", index.read_text()):
    if target.startswith(("http://", "https://", "#")):
        continue
    path = (index.parent / target.split("#", 1)[0]).resolve()
    if not path.exists():
        errors.append(f"broken docs index link: {target}")

if errors:
    for error in errors:
        print("DOCS FAIL:", error)
    raise SystemExit(1)
print(f"DOCS PASS: handoff {len(lines)} lines/{len(text)} characters; index links resolve")
