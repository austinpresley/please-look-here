#!/usr/bin/env python3
"""S-020: real plugin/app replay. A simulated host is not a physical key test."""
import argparse
import base64
import importlib.util
import json
import pathlib
import subprocess
import sys
import time

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("deck_replay", pathlib.Path(__file__).with_name("deck-replay.py"))
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("app", "plugin", "suite", "hands", "out"):
        parser.add_argument("--" + name, required=True)
    args = parser.parse_args()
    out = pathlib.Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    binary = str(pathlib.Path(args.app) / "Contents/MacOS/TinyHand")
    results = []

    def ctl(op, **fields):
        data = subprocess.run([binary, "--ctl", json.dumps({"version": 1, "operation": op, **fields})], capture_output=True, text=True, timeout=10)
        return json.loads(data.stdout)

    def state():
        return ctl("status")["state"]

    def check(name, passed):
        results.append({"check": name, "passed": bool(passed)})
        print(("PASS " if passed else "FAIL ") + name, flush=True)
        assert passed, name

    def wait(predicate, seconds=8):
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            if predicate():
                return True
            time.sleep(.05)
        return False

    safety = ctl("test-shortcuts", request={})
    if safety.get("shortcuts", {}).get("defaultsSuite") != args.suite or not pathlib.Path(args.hands).is_dir():
        raise SystemExit("Refusing to mutate outside the disposable suite and hand directory")
    check("cycle API advertised", "cycle-pointer" in state()["capabilities"])
    initial = state()
    check("fresh isolated off/Interact state", not initial["active"] and initial["interact"])
    deck = base.Deck()
    plugin = subprocess.Popen([args.plugin, "-port", str(deck.port), "-pluginUUID", "cycle-replay", "-registerEvent", "registerPlugin"])
    cycle = base.PREFIX + "choose-pointer"
    catalog = {}

    def refresh():
        nonlocal catalog
        catalog = {s["id"]: s for s in ctl("styles")["styles"]}
        return [s for s, v in catalog.items() if v["selectable"]]

    def press(context=cycle):
        deck.event("keyDown", context)
        deck.event("keyUp", context)

    def frame(name, observed=None, **fields):
        observed = observed or state()
        fixture = {"action": cycle, "state": observed, **fields}
        thumb = catalog.get(observed["style"], {}).get("thumbnail")
        if thumb and "thumbnail" not in fields:
            fixture["thumbnail"] = thumb
        directory = out / "expected"
        directory.mkdir(exist_ok=True)
        src, png = directory / (name + ".json"), directory / (name + ".png")
        src.write_text(json.dumps(fixture, indent=2))
        subprocess.run([args.plugin, "--render-key", str(src), "--output", str(png)], check=True)
        return base64.b64encode(png.read_bytes()).decode()

    def matches(name, expected, seconds=5, context=cycle):
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            if deck.images.get(context, [None])[-1] == expected:
                (out / (name + ".png")).write_bytes(base64.b64decode(expected))
                check(name, True)
                return
            deck.next_image(context, .1)
        check(name, False)

    def stable(name):
        matches(name, frame(name))

    try:
        check("plugin registers", deck.accept() == {"event": "registerPlugin", "uuid": "cycle-replay"})
        choices = refresh()
        check("full set includes unpinned custom and excludes missing", "custom-s019" in choices and "custom-s019-missing" not in choices and len(choices) > len(state()["quickPointers"]))
        # Fixed-looking stray settings on a NEW cycle UUID do not become a subset.
        deck.event("willAppear", cycle, {"settings": {"style": "gone", "activate": True}})
        stable("current-off")
        ctl("enable-pointer", style="robot", enabled=False)
        choices = refresh()
        check("disabled excluded", "robot" not in choices)
        ctl("style", style=choices[-1])
        for index, target in enumerate(choices):
            press()
            check(f"full-library step {index + 1}: {target}", wait(lambda: state()["style"] == target))
            deck.settle(.03)
        check("full wrap preserves off and Interact", not state()["active"] and state()["interact"])
        stable("full-wrap")

        ctl("on")
        press()
        check("cycling active pointer preserves activation", wait(lambda: state()["style"] == choices[0]) and state()["active"])
        ctl("off")
        for target in choices:
            if target != "laser":
                ctl("enable-pointer", style=target, enabled=False)
        press()
        check("single enabled choice stays laser", wait(lambda: state()["style"] == "laser"))
        stable("single-laser")
        for target in choices:
            ctl("enable-pointer", style=target, enabled=True)
        choices = refresh()
        stable("enabled-set-changed-visible")

        # Manifest removal/restoration uses the same ID and library slot.
        hands = pathlib.Path(args.hands)
        manifest = hands / "hands.json"
        original_manifest = manifest.read_bytes()
        custom_path = hands / "custom-s019.png"
        original_image = custom_path.read_bytes()
        before_custom = choices[choices.index("custom-s019") - 1]
        ctl("style", style=before_custom)
        manifest.write_text(json.dumps([v for v in json.loads(original_manifest) if v["id"] != "custom-s019"]))
        try:
            press()
            check("deleted custom never enters cycle", wait(lambda: state()["style"] == "laser"))
        finally:
            manifest.write_bytes(original_manifest)
        check("restored manifest eligible without stealing current", wait(lambda: "custom-s019" in state()["enabledPointers"]) and state()["style"] == "laser")
        ctl("style", style=before_custom)
        press()
        check("restored custom cycles in its library position", wait(lambda: state()["style"] == "custom-s019"))
        refresh()
        stable("custom-restored")
        custom_path.unlink()
        try:
            check("missing current repaired while visible", wait(lambda: state()["style"] == "lavender"))
            ctl("style", style=before_custom)
            press()
            check("missing image skipped", wait(lambda: state()["style"] == "laser"))
        finally:
            custom_path.write_bytes(original_image)
        check("image restoration does not steal selection", wait(lambda: "custom-s019" in state()["enabledPointers"]) and state()["style"] == "laser")
        refresh()
        stable("asset-restored-visible")

        with base.ControlProxy() as proxy:
            def count():
                return sum(r["operation"] == "cycle-pointer" for r in proxy.requests)
            def wrapped(start, amount):
                return choices[(choices.index(start) + amount) % len(choices)]

            before = state()
            proxy.fault = "delay"
            for _ in range(7):
                press()
            matches("rapid-pending", frame("rapid-pending", before, transient="pending"), .5)
            target = wrapped(before["style"], 7)
            check("seven rapid complete presses advance seven times", wait(lambda: state()["style"] == target) and count() == 7)
            stable("rapid-seven-acknowledged")
            check("cycle payload contains no stale style or activation", all(set(r) == {"version", "operation"} for r in proxy.requests if r["operation"] == "cycle-pointer"))
            before_count, before = count(), state()
            proxy.fault = "delay"
            deck.event("keyDown", cycle)
            for _ in range(5):
                deck.event("keyDown", cycle)
            matches("held-pending", frame("held-pending", before, transient="pending", pressed=True), .5)
            deck.event("keyUp", cycle)
            check("duplicate keyDown without release advances once", wait(lambda: state()["style"] == wrapped(before["style"], 1)) and count() == before_count + 1)
            stable("held-released")

            # Different visible cycle keys share one FIFO and app-owned current state.
            second = "second-cycle-key"
            deck.event("willAppear", second, {"settings": {}}, action=cycle)
            before_count, before = count(), state()
            proxy.fault = "delay"
            press(); press(second); press()
            check("two keys serialize three complete presses", wait(lambda: state()["style"] == wrapped(before["style"], 3)) and count() == before_count + 3)
            deck.event("willDisappear", second)
            stable("multiple-keys-acknowledged")

            ctl("style", style="lavender")
            stable("external-current-before-queued-set")
            before_count, before = count(), state()
            proxy.fault = "delay"
            press(); press()
            matches("changing-set-pending", frame("changing-set-pending", before, transient="pending"), .5)
            # Connect this external edit during the held first reply. The second
            # cycle has not been sent yet and must resolve the changed app set.
            ctl("enable-pointer", style="glove", enabled=False)
            check("queued cycle resolves changed enabled set and repaired current", wait(lambda: state()["style"] == "coral") and count() == before_count + 2)
            ctl("enable-pointer", style="glove", enabled=True)
            choices = refresh()
            stable("changing-set-acknowledged")

            before_count, before = count(), state()
            proxy.fault = "delay-drop"
            proxy.fail_reads = True
            press(); press(); press()
            matches("uncertain-pauses-queue", frame("uncertain-pauses-queue", before, link="reconnecting", transient="uncertain"), 1.5)
            deck.settle(1.0)
            check("uncertain sent once and unsent intents paused during read failure", count() == before_count + 1)
            proxy.fail_reads = False
            check("safe status resumes only two unsent intents", wait(lambda: state()["style"] == wrapped(before["style"], 3), 12) and count() == before_count + 3)
            stable("uncertain-recovered")
            deck.settle(2.5)
            check("uncertain mutation never retried", count() == before_count + 3)

            before_count, before = count(), state()
            proxy.fault = "delay"
            press(); press(); press()
            deck.event("willDisappear", cycle)
            deck.settle(1.5)
            check("page departure cancels unsent presses", count() == before_count + 1 and state()["style"] == wrapped(before["style"], 1))
            deck.event("willAppear", cycle, {"settings": {}}, action=cycle)
            stable("page-return")
            deck.settle(3)
            frames = len(deck.images[cycle])
            deck.settle(3)
            check("unchanged catalogs do not resend images", len(deck.images[cycle]) == frames)
            (out / "proxy-requests.json").write_text(json.dumps(proxy.requests, indent=2))

        # Invalid wire fields cannot change activation or selection.
        before = state()
        for fields in ({"activate": True}, {"style": "robot"}, {"enabled": False}):
            reply = ctl("cycle-pointer", **fields)
            check("invalid cycle fields reject atomically " + str(fields), not reply["ok"] and reply["state"]["style"] == before["style"] and reply["state"]["active"] == before["active"])
        stable("final-off")
        # A stopped app cancels unsent input, rather than applying it on restart.
        before = state()
        subprocess.run(["osascript", "-e", 'tell application id "com.austinpresley.pleaselookhere.integration" to quit'], check=True, timeout=30)
        deck.settle(3)
        press(); press()
        matches("stopped-cycle-rejection", frame("stopped-cycle-rejection", before, link="stopped", transient="rejected", reason="Not running"), 2)
        deck.settle(2.5)
        matches("stopped-cycle-idle", frame("stopped-cycle-idle", before, link="stopped"))
        command = ["open", "-n", "--env", "TINYHAND_TEST_MODE=1", "--env", "TINYHAND_DEFAULTS_SUITE=" + args.suite,
                   "--env", "TH_HANDS_DIR=" + args.hands, args.app]
        subprocess.run(command, check=True)
        def ready():
            try:
                return ctl("test-shortcuts", request={}).get("shortcuts", {}).get("defaultsSuite") == args.suite
            except (ValueError, KeyError):
                return False
        check("same isolated suite recovers", wait(ready, 20))
        deck.settle(3)
        check("stopped cycle presses never replay after restart", state()["style"] == before["style"] and not state()["active"])
        stable("restarted-current")

    finally:
        plugin.terminate()
        plugin.wait(timeout=5)
        for context, images in deck.images.items():
            name = context.rsplit(".", 1)[-1]
            for index, value in enumerate(images):
                (out / f"{name}-{index:03d}.png").write_bytes(base64.b64decode(value))
        (out / "results.json").write_text(json.dumps(results, indent=2))
    print(f"{len(results)}/{len(results)} checks passed", flush=True)


if __name__ == "__main__":
    main()
