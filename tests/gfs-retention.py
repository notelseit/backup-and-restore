#!/usr/bin/env python3
"""GFS boundary and fail-closed behavior, no destructive operations."""
import datetime as dt
import hashlib
import importlib.machinery
import importlib.util
import pathlib
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "bin/notelseit-retention-gfs"
loader = importlib.machinery.SourceFileLoader("gfs", str(SCRIPT))
spec = importlib.util.spec_from_loader(loader.name, loader)
gfs = importlib.util.module_from_spec(spec)
loader.exec_module(gfs)


def runid(value, pid=1):
    return "run-" + value.strftime("%Y%m%dT%H%M%S") + f"Z-{pid}"


def main():
    # ISO 2026-W53 and 2027-W53 year boundaries; months use UTC.
    dates = [
        dt.datetime(2025, 12, 28, 23),
        dt.datetime(2025, 12, 29, 0),
        dt.datetime(2025, 12, 31, 22),
        dt.datetime(2026, 1, 1, 0),
        dt.datetime(2026, 1, 1, 2),
        dt.datetime(2026, 1, 4, 23),
        dt.datetime(2026, 1, 5, 0),
        dt.datetime(2026, 2, 1, 0),
        dt.datetime(2026, 3, 1, 0),
    ]
    names = [runid(date) for date in dates]
    keep, ordered = gfs.choose(names, 2, 2, 2)
    assert ordered[0] == runid(dates[-1])
    assert runid(dates[-1]) in keep
    assert sum("daily" in x for x in keep.values()) == 2
    assert sum("weekly" in x for x in keep.values()) == 2
    assert sum("monthly" in x for x in keep.values()) == 2
    # More than one run in a day should not use two daily slots.
    same = [runid(dt.datetime(2026, 1, 2, 10)), runid(dt.datetime(2026, 1, 2, 9))]
    chosen, _ = gfs.choose(same, 2, 1, 1)
    assert len(chosen) == 1
    try:
        gfs.timestamp("run-20260230T000000Z-1")
    except ValueError:
        pass
    else:
        raise AssertionError("Invalid date not blocked")

    with tempfile.TemporaryDirectory() as tmp:
        root = pathlib.Path(tmp)
        for date in dates:
            path = root / runid(date)
            path.mkdir()
            archive = path / "files-0.tar.gz"
            archive.write_bytes(b"synthetic archive, checksums tested")
            manifest = path / "MANIFEST.tsv"
            manifest.write_text("files\tfiles-0.tar.gz\t/tmp/source\n")
            checks = path / "SHA256SUMS"
            checks.write_text("".join(
                hashlib.sha256(file.read_bytes()).hexdigest() + "  " + file.name + "\n"
                for file in (archive, manifest)
            ))
        cmd = [sys.executable, str(SCRIPT), "--backup-root", str(root), "--type", "local",
               "--daily", "2", "--weekly", "2", "--monthly", "2"]
        res = subprocess.run(cmd, text=True, capture_output=True, check=True)
        assert "CANDIDATE_ONLY" in res.stdout
        assert len(list(root.glob("run-*"))) == len(dates), "Planner deleted runs"
        # An incomplete run must block the entire plan.
        (root / ".incomplete-run-20260302T000000Z-1").mkdir()
        res = subprocess.run(cmd, text=True, capture_output=True)
        assert res.returncode != 0 and "BLOCKED" in res.stderr
        (root / ".incomplete-run-20260302T000000Z-1").rmdir()
        # Corrupted content also blocks the entire plan.
        (root / names[0] / "MANIFEST.tsv").write_text("changed\n")
        res = subprocess.run(cmd, text=True, capture_output=True)
        assert res.returncode != 0 and "BLOCKED" in res.stderr
    print("GFS date boundaries, retention limits, and fail-closed tests passed")


if __name__ == "__main__":
    main()
