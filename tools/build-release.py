#!/usr/bin/env python3
"""Build the release archive from the contents of bundle/.

Run it from anywhere:

    python3 tools/build-release.py

It writes dist/bosnian-macos-keyboard.zip. That is the file to attach to a
GitHub release: the download link in README.md points at that exact name, so
keep the name when you upload it.

Why this script rather than `zip` or `ditto`
--------------------------------------------
Two of the layouts have an en dash in their file name. Info-ZIP's `zip` stores
such names without setting the flag that marks them as UTF-8, so some
unarchivers write them back out mangled -- and a layout whose .icns name no
longer matches its .keylayout name loses its badge. `ditto -c -k` flags the
names correctly but adds a __MACOSX directory of AppleDouble files beside the
bundle.

Writing the entries here avoids both: the UTF-8 flag is set where it is needed,
Finder leavings are skipped, permissions are fixed rather than copied from
whatever the working tree happens to have, and timestamps come from the last
commit that touched bundle/, so the same commit always produces a byte-identical
archive. Set SOURCE_DATE_EPOCH to override the timestamp.

After writing the archive the script reads it back: every CRC is checked, and
the extracted tree is compared file by file against bundle/. It exits non-zero
if anything differs.
"""

import os
import subprocess
import sys
import tempfile
import time
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "bundle")
OUTPUT = os.path.join(ROOT, "dist", "bosnian-macos-keyboard.zip")

# Finder, Spotlight and Time Machine leavings. None of it belongs in a release,
# and a stray .DS_Store inside the bundle would be installed along with it.
SKIP_NAMES = {
    ".DS_Store",
    ".localized",
    "Icon\r",
    ".AppleDouble",
    ".LSOverride",
    ".Spotlight-V100",
    ".DocumentRevisions-V100",
    ".TemporaryItems",
    ".Trashes",
    ".fseventsd",
}
SKIP_PREFIXES = ("._",)

ZIP_EPOCH = 315532800  # 1980-01-01, the earliest date a zip entry can carry


def skipped(name):
    return name in SKIP_NAMES or name.startswith(SKIP_PREFIXES)


def collect(directory):
    """Every file under `directory`, as (absolute path, path inside the archive)."""
    found = []
    for parent, subdirs, files in os.walk(directory):
        subdirs[:] = sorted(d for d in subdirs if not skipped(d))
        for name in sorted(files):
            if skipped(name):
                continue
            full = os.path.join(parent, name)
            if os.path.islink(full):
                raise SystemExit("symlink in bundle/, which the archive cannot carry: " + full)
            found.append((full, os.path.relpath(full, directory)))
    return found


def source_date():
    """Fixed timestamp for every entry, so the archive is reproducible."""
    override = os.environ.get("SOURCE_DATE_EPOCH")
    if override:
        return max(int(override), ZIP_EPOCH)
    try:
        committed = subprocess.run(
            ["git", "-C", ROOT, "log", "-1", "--format=%ct", "--", SOURCE],
            capture_output=True, text=True, check=True,
        ).stdout.strip()
        if committed:
            return max(int(committed), ZIP_EPOCH)
    except (OSError, ValueError, subprocess.CalledProcessError):
        pass  # not a checkout, or bundle/ has never been committed
    return int(time.time())


def build(entries, when):
    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    if os.path.exists(OUTPUT):
        os.remove(OUTPUT)
    # UTC, because a zip entry carries no time zone: local time here would make
    # the archive depend on the machine that built it.
    stamp = time.gmtime(when)[:6]
    with zipfile.ZipFile(OUTPUT, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for full, inside in entries:
            entry = zipfile.ZipInfo(inside, date_time=stamp)
            entry.compress_type = zipfile.ZIP_DEFLATED
            entry.create_system = 3                 # Unix, so the mode below is read
            entry.external_attr = 0o644 << 16       # not whatever the working tree has
            entry.flag_bits |= 0x800                # names are UTF-8
            with open(full, "rb") as handle:
                archive.writestr(entry, handle.read())


def verify(entries):
    """Read the archive back and compare it against bundle/."""
    with zipfile.ZipFile(OUTPUT) as archive:
        damaged = archive.testzip()
        if damaged:
            raise SystemExit("bad CRC in the archive: " + damaged)
        with tempfile.TemporaryDirectory() as unpacked:
            archive.extractall(unpacked)
            for full, inside in entries:
                extracted = os.path.join(unpacked, inside)
                if not os.path.exists(extracted):
                    raise SystemExit("missing from the archive: " + inside)
                with open(full, "rb") as a, open(extracted, "rb") as b:
                    if a.read() != b.read():
                        raise SystemExit("unpacks differently from bundle/: " + inside)
            surplus = {
                os.path.relpath(os.path.join(parent, name), unpacked)
                for parent, _, files in os.walk(unpacked)
                for name in files
            } - {inside for _, inside in entries}
            if surplus:
                raise SystemExit("unexpected in the archive: " + ", ".join(sorted(surplus)))


def main():
    if not os.path.isdir(SOURCE):
        raise SystemExit("no bundle/ directory at " + SOURCE)
    entries = collect(SOURCE)
    if not entries:
        raise SystemExit("bundle/ is empty")

    when = source_date()
    build(entries, when)
    verify(entries)

    print(os.path.relpath(OUTPUT, ROOT))
    print("  %d files, %d bytes, dated %s"
          % (len(entries), os.path.getsize(OUTPUT),
             time.strftime("%Y-%m-%d %H:%M UTC", time.gmtime(when))))
    for _, inside in entries:
        print("  " + inside)
    print("  checked: every CRC, and every file unpacks identical to bundle/")
    return 0


if __name__ == "__main__":
    sys.exit(main())
