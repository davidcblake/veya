#!/usr/bin/env python3
"""Pick the iPhone simulator CI should test against.

Reads `xcrun simctl list devices available --json` on stdin and prints the UDID
of an iPhone on the newest installed iOS runtime.

Chosen at run time rather than hard-coded because GitHub changes the simulator
lineup between runner images. A stale device name fails with a message that does
not obviously mean "that iPhone no longer exists here", and that is an expensive
thing to debug on a Mac runner.

Every unexpected shape is skipped rather than raised. A traceback here would
fail the build with a Python error about JSON, which tells you nothing about the
Swift you were trying to test.
"""

import json
import sys

RUNTIME_MARKER = "SimRuntime.iOS-"


def runtime_version(runtime_identifier: str) -> tuple[int, ...] | None:
    """Sortable version from a runtime id like `…SimRuntime.iOS-26-5` -> (26, 5).

    `None` when the tail is not all numbers — Apple has used other shapes for
    beta runtimes, and one odd entry should not take the whole job down when
    another perfectly good runtime is installed.
    """
    tail = runtime_identifier.split(RUNTIME_MARKER)[-1]
    try:
        return tuple(int(part) for part in tail.split("-"))
    except ValueError:
        return None


def choose(devices_by_runtime: dict[str, list[dict]]) -> tuple[str, str, str] | None:
    """Return (udid, device name, runtime) for an iPhone on the newest iOS runtime."""
    newest_version: tuple[int, ...] | None = None
    candidates: list[tuple[dict, str]] = []

    for runtime, devices in devices_by_runtime.items():
        if RUNTIME_MARKER not in runtime:
            continue
        version = runtime_version(runtime)
        if version is None:
            continue

        # A device without a udid cannot be a destination, so it is not a
        # candidate — rather than a KeyError three lines later.
        iphones = [
            device
            for device in devices
            if "iPhone" in device.get("name", "") and device.get("udid")
        ]
        if not iphones:
            continue

        if newest_version is None or version > newest_version:
            newest_version = version
            candidates = [(device, runtime) for device in iphones]
        elif version == newest_version:
            candidates.extend((device, runtime) for device in iphones)

    if not candidates:
        return None

    # Deterministic rather than whichever the JSON happened to list first, so a
    # failing test can be re-run on the same device instead of a different one.
    device, runtime = min(candidates, key=lambda pair: pair[0]["name"])
    return device["udid"], device["name"], runtime


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError as error:
        print(f"simctl did not return readable JSON: {error}", file=sys.stderr)
        return 1

    picked = choose(payload.get("devices", {}))
    if picked is None:
        print("No iPhone simulator is available on this runner.", file=sys.stderr)
        return 1

    udid, name, runtime = picked
    print(f"Using {name} on {runtime}", file=sys.stderr)
    print(udid)
    return 0


if __name__ == "__main__":
    sys.exit(main())
