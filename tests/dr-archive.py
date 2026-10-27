#!/usr/bin/env python3
"""Rehashed corruption must still fail DR validation."""
import hashlib
import importlib.machinery
import importlib.util
import io
import pathlib
import tarfile
import tempfile

script = pathlib.Path(__file__).resolve().parents[1] / "bin/notelseit-dr-preflight"
loader = importlib.machinery.SourceFileLoader("dr", str(script))
spec = importlib.util.spec_from_loader(loader.name, loader)
dr = importlib.util.module_from_spec(spec)
loader.exec_module(dr)


def rehash(root):
    (root / "SHA256SUMS").write_text("".join(
        hashlib.sha256((root / name).read_bytes()).hexdigest() + "  " + name + "\n"
        for name in ("files-0.tar.gz", "MANIFEST.tsv")))


with tempfile.TemporaryDirectory() as tmp:
    root = pathlib.Path(tmp)
    archive = root / "files-0.tar.gz"
    (root / "MANIFEST.tsv").write_text("files\tfiles-0.tar.gz\t/test\n")
    with tarfile.open(archive, "w:gz") as out:
        member = tarfile.TarInfo("test.txt")
        member.size = 2
        out.addfile(member, io.BytesIO(b"ok"))
    rehash(root)
    assert dr.check(root) == 1
    original = archive.read_bytes()
    for damaged in (original[:-4], original[:-8] + bytes([original[-8] ^ 1]) + original[-7:]):
        archive.write_bytes(damaged)
        rehash(root)
        try:
            dr.check(root)
        except (OSError, EOFError, ValueError, tarfile.TarError):
            pass
        else:
            raise AssertionError("Invalid gzip trailer accepted")
print("DR archive trailer tests passed")
