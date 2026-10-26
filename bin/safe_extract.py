#!/usr/bin/env python3
"""Validate and extract an untrusted tar.gz into a newly created empty staging dir.

Explicitly refuses symbolic links, hardlinks, sparse files, devices, FIFOs, traversal,
absolute paths and PAX global headers. Does not restore owner or special permissions.
"""
import os
import pathlib
import sys
import tarfile

def main():
    if len(sys.argv) != 3:
        raise SystemExit("Usage: safe_extract.py ARCHIVE DESTINATION")
    archive = pathlib.Path(sys.argv[1])
    dest = pathlib.Path(sys.argv[2])
    if not dest.is_dir() or dest.is_symlink() or any(dest.iterdir()):
        raise ValueError("Destination must be an existing empty non-symlink directory")
    # Forbid symlinks in any destination ancestor; keeps destination location predictable.
    for parent in (dest, *dest.parents):
        if parent.is_symlink():
            raise ValueError("Symlink destination ancestors forbidden")
    with tarfile.open(archive, "r:gz") as tf:
        members = tf.getmembers()
        if len(members) > 100000:
            raise ValueError("Archive contains too many members")
        seen = set()
        total = 0
        for member in members:
            raw = member.name
            if raw.startswith("/") or "\\x00" in raw or any(part == ".." for part in raw.split("/")):
                raise ValueError("Unsafe archive path")
            rel = pathlib.PurePosixPath(raw)
            if rel.is_absolute() or str(rel) in ("", "."):
                if member.isdir() and raw in (".", "./"):
                    continue
                raise ValueError("Invalid archive path")
            if not (member.isfile() or member.isdir()) or member.pax_headers.get("GNU.sparse.map"):
                raise ValueError("Archive member type not allowed")
            if str(rel) in seen:
                raise ValueError("Repeated archive path")
            seen.add(str(rel))
            total += member.size
            if total > 20 * 1024**3:
                raise ValueError("Expanded archive too large (20 GiB limit)")
        for member in members:
            if member.name in (".", "./") and member.isdir():
                continue
            rel = pathlib.PurePosixPath(member.name)
            path = dest.joinpath(*rel.parts)
            if member.isdir():
                path.mkdir(parents=True, exist_ok=True, mode=0o700)
            else:
                path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
                fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
                with os.fdopen(fd, "wb") as out:
                    src = tf.extractfile(member)
                    if src is None:
                        raise ValueError("Missing member data")
                    while chunk := src.read(1024 * 1024):
                        out.write(chunk)

if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, tarfile.TarError) as exc:
        print(f"Unsafe or invalid backup archive: {exc}", file=sys.stderr)
        sys.exit(1)
