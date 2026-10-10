#!/usr/bin/env python3
"""Rebuild Goal 4.1 fixtures from unchanged original C and authentic WAD bytes."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
DEFAULT_OUTPUT = ROOT / "test/fixtures/phase4_video"
SOURCE = ROOT / "original/DOOM/linuxdoom-1.10"
NAMES = ["STBAR", "STTNUM0", "STFST00", "STCFN033", "AMMNUM0", "WIMAP0"]


def sha(data):
    return hashlib.sha256(data).hexdigest()


def source_function(path, name):
    text = path.read_text()
    match = re.search(r"\b" + re.escape(name) + r"\s*\(", text)
    assert match, name
    start = text.rfind("\n", 0, match.start()) + 1
    # Declaration-only includes are not expanded; each name's first occurrence
    # in these translation units is its definition.
    opening = text.index("{", match.end())
    depth = 1
    closing = opening + 1
    while depth:
        if text[closing] == "{": depth += 1
        elif text[closing] == "}": depth -= 1
        closing += 1
    contents = text[start:closing]
    return {"function": name, "source": str(path.relative_to(ROOT)),
            "lineStart": text.count("\n", 0, start)+1,
            "lineEnd": text.count("\n", 0, closing)+1,
            "sourceSpanSha256": sha(contents.encode())}


def synthetic_patch():
    # Gaps, an empty column, multiple independent posts, literal zero and255.
    columns = [bytes([0, 2, 0, 0, 255, 0, 5, 2, 0, 17, 31, 0, 255]),
               bytes([255]), bytes([1, 1, 0, 43, 0, 4, 3, 0, 61, 79, 97, 0, 255]),
               bytes([2, 4, 0, 113, 131, 149, 167, 0, 255])]
    offset = 8 + 4 * len(columns)
    offsets = []
    for col in columns:
        offsets.append(offset)
        offset += len(col)
    return struct.pack("<hhhh", 4, 8, -3, 2) + struct.pack("<4I", *offsets) + b"".join(columns)


def build_cases():
    cases = []

    def add(name, op, x=0, y=0, scrn=0, width=0, height=0, destx=0,
            desty=0, destscrn=0, patch=-1, seed=19, screen4_height=32, error=0):
        values = [op, x, y, scrn, width, height, destx, desty, destscrn,
                  patch, seed, screen4_height, error]
        cases.append({"name": name, "inputs": values})

    add("init-four-contiguous-screen-buffers", 0)
    add("mark-normal", 1, 10, 20, width=30, height=40)
    add("mark-single-pixel", 1, 7, 11, width=1, height=1)
    add("mark-zero-size-original-two-points", 1, 7, 11)
    add("mark-negative-coordinate-unrestricted", 1, -20, -30, width=7, height=9)
    add("copy-cross-screen-nonzero-destination", 2, 11, 27, 1, 17, 13, 151, 93, 0)
    add("copy-destination-screen2-still-marks-dirty", 2, 0, 0, 0, 320, 32, 0, 0, 2)
    add("copy-status-backing-to-screen0", 2, 0, 0, 4, 320, 32, 0, 168, 0)
    add("copy-screen0-to-status-backing", 2, 0, 168, 0, 320, 32, 0, 0, 4)
    add("copy-rowwise-overlap-cascades-down", 2, 0, 0, 0, 320, 4, 0, 1, 0)
    add("copy-rowwise-overlap-up", 2, 0, 1, 0, 320, 4, 0, 0, 0)
    add("copy-zero-width", 2, 10, 20, 0, 0, 3, 13, 27, 1)
    add("copy-zero-height", 2, 10, 20, 0, 3, 0, 13, 27, 1)
    add("copy-invalid-source-coordinate", 2, -1, 0, 0, 1, 1, error=1)
    add("copy-invalid-destination-coordinate", 2, 0, 0, 0, 1, 1, 320, 0, 1, error=1)
    add("copy-invalid-source-screen", 2, 0, 0, -1, 1, 1, error=1)
    add("copy-invalid-destination-screen", 2, 0, 0, 0, 1, 1, destscrn=5, error=1)
    for patch, name in enumerate(NAMES):
        if name == "STBAR":
            x, y = 0, 168
        elif name == "WIMAP0":
            x, y = 0, 0
        else:
            x, y = 20, 30
        add(f"patch-{name}", 3, x, y, patch=patch)
        add(f"patch-flipped-{name}", 4, x, y, patch=patch)
    add("patch-STBAR-status-backing", 3, 0, 0, 4, patch=0)
    add("patch-direct-STTNUM0", 5, 27, 164, patch=1)
    add("patch-other-screen-no-dirty", 3, 50, 50, 2, patch=1)
    add("patch-synthetic-transparent-posts-signed-offsets", 3, 7, 12, patch=6)
    add("patch-synthetic-flipped", 4, 7, 12, patch=6)
    add("patch-synthetic-right-bottom-exact-edge", 3, 313, 194, patch=6)
    add("patch-offset-causes-negative-origin-ignored", 3, 0, 0, patch=6)
    add("patch-left-offscreen-ignored-whole-patch", 3, -4, 30, patch=6)
    add("patch-right-offscreen-ignored-whole-patch", 3, 314, 30, patch=6)
    add("patch-bottom-offscreen-ignored-whole-patch", 3, 7, 195, patch=6)
    add("patch-invalid-screen-ignored", 3, 7, 12, -1, patch=6)
    add("patch-flipped-offscreen-fatal", 4, -4, 30, patch=6, error=1)
    add("patch-flipped-invalid-screen-fatal", 4, 7, 12, 5, patch=6, error=1)
    add("patch-direct-offscreen-ignored", 5, -4, 30, patch=6)
    add("drawblock-screen0", 6, 89, 113, 0, 27, 19)
    add("drawblock-screen3-still-marks-dirty", 6, 10, 20, 3, 8, 5)
    add("drawblock-status-backing", 6, 0, 0, 4, 320, 32)
    add("drawblock-right-bottom-edge", 6, 313, 191, 0, 7, 9)
    add("drawblock-zero-width", 6, 30, 40, 0, 0, 7)
    add("drawblock-zero-height", 6, 30, 40, 0, 7, 0)
    add("drawblock-invalid-coordinate", 6, 319, 199, 0, 2, 1, error=1)
    add("drawblock-invalid-screen", 6, 0, 0, 5, 2, 1, error=1)
    add("getblock-screen0-no-dirty", 7, 89, 113, 0, 27, 19)
    add("getblock-status-backing", 7, 0, 0, 4, 320, 32)
    add("getblock-right-bottom-edge", 7, 313, 191, 3, 7, 9)
    add("getblock-zero-width", 7, 30, 40, 0, 0, 7)
    add("getblock-zero-height", 7, 30, 40, 0, 7, 0)
    add("getblock-invalid-coordinate", 7, 319, 199, 0, 2, 1, error=1)
    add("getblock-invalid-screen", 7, 0, 0, -1, 2, 1, error=1)
    return cases


def decode_output(data, cases):
    position = 0
    packed = bytearray()
    for case in cases:
        dirty = list(struct.unpack_from(">4i", data, position)); position += 16
        error, = struct.unpack_from(">I", data, position); position += 4
        assert error == case["inputs"][12], (case["name"], error)
        hashes = []
        for _ in range(6):
            size, = struct.unpack_from(">I", data, position); position += 4
            contents = data[position:position+size]; position += size
            assert len(contents) == size
            hashes.append(sha(contents))
        case["dirtybox"] = dirty
        case["sha256"] = hashes
        packed += struct.pack(">17i", *(case["inputs"] + dirty))
        packed += b"".join(bytes.fromhex(h) for h in hashes)
    gamma = data[position:]
    assert len(gamma) == 1280
    assert len(packed) == len(cases)*260
    return bytes(packed), gamma


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--bundle", type=Path, default=ROOT / "artifacts/local/wad/bundle.json")
    parser.add_argument("--resources", type=Path, default=ROOT / "artifacts/local/wad/resources.bin")
    parser.add_argument("--check", action="store_true", help="rebuild in temporary directory and compare committed fixture bytes")
    args = parser.parse_args()
    output = args.output.resolve()
    with tempfile.TemporaryDirectory(prefix="doom-video-native-") as temporary:
        tmp = Path(temporary)
        built = tmp / "fixtures"; built.mkdir()
        manifest = json.loads(args.bundle.read_text())
        resource = args.resources.read_bytes()
        assert sha(resource) == manifest["blobSha256"]
        patches = []
        for name in NAMES:
            matches = [l for l in manifest["lumps"] if bytes.fromhex(l["nameHex"]).rstrip(b"\0").decode() == name]
            assert len(matches) == 1
            lump = matches[0]
            contents = resource[lump["offset"]:lump["offset"]+lump["length"]]
            path = f"patch-{len(patches)}.bin"; (built/path).write_bytes(contents)
            patches.append({"id": len(patches), "name": name, "path": path,
                            "lumpId": lump["id"], "resourceOffset": lump["offset"],
                            "length": len(contents), "sha256": sha(contents),
                            "dimensionsOffsets": list(struct.unpack("<4h", contents[:8]))})
        contents = synthetic_patch(); (built / "patch-6.bin").write_bytes(contents)
        patches.append({"id": 6, "name": "SYNTHETIC", "path": "patch-6.bin", "length": len(contents),
                        "sha256": sha(contents), "dimensionsOffsets": list(struct.unpack("<4h", contents[:8])),
                        "license": "Project test fixture; transparent multi-post columns, signed offsets"})
        cases = build_cases()
        inputs = struct.pack(">I", len(cases)) + b"".join(struct.pack(">13i", *case["inputs"]) for case in cases)
        (tmp / "inputs.bin").write_bytes(inputs)
        results = []
        compiler = shutil.which("clang") or shutil.which("cc")
        assert compiler
        commands = []
        for label, flags in [("O0", ["-O0"]), ("O2", ["-O2"]),
                             ("sanitized", ["-O1", "-g", "-fsanitize=address,undefined", "-fno-sanitize=array-bounds", "-fno-omit-frame-pointer"])]:
            binary = tmp / label
            command = [compiler, "-std=c11", "-DRANGECHECK", "-include", str(HERE/"compat.h"),
                       *flags, str(SOURCE/"v_video.c"), str(SOURCE/"m_bbox.c"), str(HERE/"host.c"), "-o", str(binary)]
            subprocess.run(command, check=True, capture_output=True)
            env = os.environ.copy()
            env["ASAN_OPTIONS"] = "detect_leaks=0:halt_on_error=1"
            env["UBSAN_OPTIONS"] = "halt_on_error=1:print_stacktrace=1"
            result = subprocess.run([str(binary), str(tmp/"inputs.bin"), str(built)], capture_output=True, env=env)
            if result.returncode:
                raise RuntimeError(f"{label} native failure {result.returncode}: {result.stderr.decode(errors='replace')}")
            results.append(result.stdout)
            commands.append({"profile": label, "flags": flags, "caseCount": len(cases), "outputSha256": sha(result.stdout),
                             "expectedRangecheckStderrSha256": sha(result.stderr), "returnCode": result.returncode})
        assert results[0] == results[1] == results[2], "O0/O2/sanitized native output mismatch"
        vectors, gamma = decode_output(results[0], cases)
        (built / "cases.bin").write_bytes(vectors)
        (built / "gamma.bin").write_bytes(gamma)
        metadata = {"schemaVersion": 1, "caseBytes": 260, "caseCount": len(cases),
                    "inputFields": ["op", "x", "y", "scrn", "width", "height", "destx", "desty", "destscrn", "patchId", "seed", "screen4Height", "expectedError"],
                    "dirtyFields": ["top", "bottom", "left", "right"],
                    "hashFields": ["screen0", "screen1", "screen2", "screen3", "screen4", "getBlock"],
                    "operations": ["V_Init", "V_MarkRect", "V_CopyRect", "V_DrawPatch", "V_DrawPatchFlipped", "V_DrawPatchDirect", "V_DrawBlock", "V_GetBlock"],
                    "casesSha256": sha(vectors), "gammaSha256": sha(gamma), "cases": cases}
        (built/"cases.json").write_text(json.dumps(metadata, indent=2)+"\n")
        (built/"patches.json").write_text(json.dumps({"provenance": manifest["provenance"], "resourceBlobSha256": manifest["blobSha256"], "patches": patches}, indent=2)+"\n")
        source_hashes = {f"original/DOOM/linuxdoom-1.10/{name}": sha((SOURCE/name).read_bytes()) for name in ["v_video.c", "v_video.h", "m_bbox.c", "r_defs.h", "i_system.c"]}
        source_hashes.update({f"tools/reference/video/{name}": sha((HERE/name).read_bytes()) for name in ["compat.h", "host.c", "reference.py"]})
        evidence = {"schemaVersion": 1, "status": "passed", "upstreamCommit": manifest["provenance"]["upstreamCommit"],
                    "sourceSha256": source_hashes, "profiles": commands, "exactAgreement": True,
                    "functionMapping": [source_function(SOURCE/"v_video.c", name) for name in metadata["operations"]] + [source_function(SOURCE/"m_bbox.c", name) for name in ["M_ClearBox", "M_AddToBox"]] + [source_function(SOURCE/"i_system.c", "I_AllocLow")],
                    "rangecheck": True, "caseCount": len(cases), "bufferPixelsComparedPerProfile": len(cases)*(4*64000+320*32),
                    "compiler": subprocess.check_output([compiler,"--version"], text=True).splitlines()[0],
                    "sanitizerScope": "ASan and UBSan enabled; array-bounds alone disabled for original patch_t.columnofs[8] variable-sized WAD extension. All actual byte accesses remain ASan-checked. Leak detection disabled (unsupported by Apple runtime); this gate makes no leak-safety claim.",
                    "excludedUndefinedCases": ["same-row overlapping memcpy", "negative dimensions causing unbounded size_t copies", "posts extending outside physical screen buffers", "signed int arithmetic overflow"],
                    "hostAdaptations": ["Only host/platform declarations in compatibility prelude; original v_video.c and m_bbox.c compiled unchanged", "I_AllocLow calloc is equivalent to original malloc followed by memset zero; caller then fills explicit reproducible indexed8 pattern", "screen4 is caller-owned 320x32 status backing; not allocated by V_Init", "I_Error captured with longjmp only for known rangecheck failures", "M_ClearBox called by fixture after V_Init; original V_Init does not initialize dirtybox"]}
        (built/"native.json").write_text(json.dumps(evidence,indent=2)+"\n")
        shutil.copyfile(ROOT/"test/fixtures/wad/COPYING.txt", built/"COPYING.txt")
        if args.check:
            expected = sorted(p.name for p in built.iterdir())
            assert expected == sorted(p.name for p in output.iterdir()), "fixture file list changed"
            for path in built.iterdir():
                assert path.read_bytes() == (output/path.name).read_bytes(), f"fixture changed: {path.name}"
        else:
            output.mkdir(parents=True, exist_ok=True)
            for path in built.iterdir(): shutil.copyfile(path, output/path.name)
        print(json.dumps({"status": "passed", "cases": len(cases), "profiles": 3, "casesSha256": sha(vectors), "exactAgreement": True}))


if __name__ == "__main__":
    main()
