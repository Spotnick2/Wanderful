"""Check the dry-run zip against the runtime manifest and the pinned library."""
import os
from pathlib import Path
import re
import sys
import zipfile

root = Path(__file__).resolve().parent.parent
lib = Path(os.environ.get("LIBGLASS", root.parent / "LibGlass"))
xml = re.sub(r"<!--.*?-->", "", (lib / "LibGlass-1.0.xml").read_text(), flags=re.S)
scripts = re.findall(r'<Script\s+file="([^"]+)"', xml)
assert scripts, "Library XML has no scripts"
library = ["LibGlass-1.0.xml", "LICENSE"] + [s.replace("\\", "/") for s in scripts]
library += [p.relative_to(lib).as_posix() for p in (lib / "Media").glob("*.tga")]
assert len(library) == 31, "Expected r9 XML, two scripts, license and 27 textures"
toc = (root / "Wanderful.toc").read_text()
owned = ["Wanderful.toc"] + [line.strip().replace("\\", "/") for line in toc.splitlines()
    if line.strip().endswith(".lua") and not line.startswith("#")]
expected = {"Wanderful/" + f for f in owned}
expected |= {"Wanderful/Libs/LibGlass-1.0/" + f for f in library}
# The packager generates this unless manual-changelog is configured.
optional = {"Wanderful/CHANGELOG.md"}
paths = [Path(sys.argv[1])] if len(sys.argv) > 1 else list((root / ".release").glob("*.zip"))
assert len(paths) == 1, f"Expected one package, found {paths}"
with zipfile.ZipFile(paths[0]) as archive:
    actual = [n for n in archive.namelist() if not n.endswith("/")]
    assert len(actual) == len(set(actual)), "Duplicate zip entries"
    assert set(actual) - optional == expected, (
        f"Missing: {sorted(expected - set(actual))}\nExtra: {sorted(set(actual) - expected - optional)}")
    for f in library:
        packaged = archive.read("Wanderful/Libs/LibGlass-1.0/" + f)
        source = (lib / f).read_bytes()
        if f.endswith((".lua", ".xml")):
            packaged, source = packaged.replace(b"\r", b""), source.replace(b"\r", b"")
        assert packaged == source, f"Packaged library differs from pinned checkout: {f}"
    version = re.search(rb"(?m)^## Version: ([^\r\n]+)", archive.read("Wanderful/Wanderful.toc"))
    assert version and version[1] not in (b"@project-version@", b"dev"), "Unsubstituted version"
print(f"Package passed: {len(expected)} runtime files, including 31 LibGlass files.")