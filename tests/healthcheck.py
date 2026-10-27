#!/usr/bin/env python3
"""Health checks: fresh, stale, corrupted, empty and encrypted artifacts."""
import datetime as dt
import hashlib
import importlib.machinery
import importlib.util
import pathlib
import tempfile

script = pathlib.Path(__file__).resolve().parents[1] / "bin/notelseit-healthcheck"
loader = importlib.machinery.SourceFileLoader("health", str(script))
spec = importlib.util.spec_from_loader(loader.name, loader)
mod = importlib.util.module_from_spec(spec)
loader.exec_module(mod)

now = dt.datetime(2026, 10, 27, 7, tzinfo=dt.timezone.utc)


def make_run(root, when):
    name = "run-" + when.strftime("%Y%m%dT%H%M%S") + "Z-100"
    folder = root / name
    folder.mkdir()
    (folder / "files-0.tar.gz").write_bytes(b"dummy archive")
    (folder / "MANIFEST.tsv").write_text("files\tfiles-0.tar.gz\t/tmp/test\n")
    checks = "".join(hashlib.sha256((folder / file).read_bytes()).hexdigest()
                     + "  " + file + "\n" for file in ("files-0.tar.gz", "MANIFEST.tsv"))
    (folder / "SHA256SUMS").write_text(checks)
    return folder


with tempfile.TemporaryDirectory() as tmp:
    root = pathlib.Path(tmp)
    try:
        mod.check(root, "local", 36, now)
    except ValueError:
        pass
    else:
        raise AssertionError("Empty inventory accepted")
    recent = make_run(root, now - dt.timedelta(hours=2))
    assert mod.check(root, "local", 36, now)["status"] == "ok"
    try:
        mod.check(root, "local", 1, now)
    except ValueError as exc:
        assert "stale" in str(exc)
    else:
        raise AssertionError("Stale backup accepted")
    (recent / "MANIFEST.tsv").write_text("corrupted")
    try:
        mod.check(root, "local", 36, now)
    except ValueError:
        pass
    else:
        raise AssertionError("Corrupted backup accepted")
with tempfile.TemporaryDirectory() as tmp:
    root = pathlib.Path(tmp)
    name = "run-20261027T060000Z-1.tar.age"
    data = root / name
    data.write_bytes(b"encrypted bytes simulated")
    (root / (name + ".sha256")).write_text(hashlib.sha256(data.read_bytes()).hexdigest() + "  " + name + "\n")
    assert mod.check(root, "encrypted", 36, now)["status"] == "ok"
    data.write_bytes(b"tampered")
    try:
        mod.check(root, "encrypted", 36, now)
    except ValueError:
        pass
    else:
        raise AssertionError("Tampered artifact accepted")
print("Healthcheck tests passed")
