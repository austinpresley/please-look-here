#!/usr/bin/env python3
"""S-021 real plugin/app replay. Simulated Keypad events do not test hardware/dials."""
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
TOOLS = ["pen", "rectangle", "arrow", "text", "number", "eraser", "highlighter"]


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
        reply = subprocess.run([binary, "--ctl", json.dumps({"version": 1, "operation": op, **fields})], capture_output=True, text=True, timeout=10)
        return json.loads(reply.stdout)

    def state():
        return ctl("status")["state"]

    def check(name, passed):
        results.append({"check": name, "passed": bool(passed)})
        print(("PASS " if passed else "FAIL ") + name, flush=True)
        assert passed, name

    def wait(predicate, seconds=10):
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            if predicate():
                return True
            time.sleep(.05)
        return False

    def restart(deny=False):
        if subprocess.run(["pgrep", "-f", "^" + binary + "$"], capture_output=True).returncode == 0:
            subprocess.run(["osascript", "-e", 'tell application id "com.austinpresley.pleaselookhere.integration" to quit'], check=True, timeout=30)
        for _ in range(100):
            if subprocess.run(["pgrep", "-f", "^" + binary + "$"], capture_output=True).returncode:
                break
            time.sleep(.1)
        else:
            raise RuntimeError("App did not exit")
        command = ["open", "-n", "--env", "TINYHAND_TEST_MODE=1", "--env", "TINYHAND_DEFAULTS_SUITE=" + args.suite,
                   "--env", "TH_HANDS_DIR=" + args.hands, "--env", "TINYHAND_TEST_DENY_ACCESSIBILITY=" + ("1" if deny else "0"), args.app]
        subprocess.run(command, check=True)
        def ready():
            try:
                response = ctl("test-shortcuts", request={})
                return response.get("shortcuts", {}).get("defaultsSuite") == args.suite and response["state"]["accessibility"] == (not deny)
            except (ValueError, KeyError):
                return False
        check("same disposable suite ready, denied=" + str(deny), wait(ready, 20))

    safety = ctl("test-shortcuts", request={})
    if safety.get("shortcuts", {}).get("defaultsSuite") != args.suite or not pathlib.Path(args.hands).is_dir():
        raise SystemExit("Refusing to mutate outside the disposable suite and hand directory")
    check("tool API advertised and actual grants retained", "cycle-tool" in state()["capabilities"] and state()["accessibility"] and state()["screenRecording"])
    ctl("off"); ctl("interact", enabled=True); ctl("style", style="lavender")
    deck = base.Deck()
    action = base.PREFIX + "choose-tool"
    context = action
    plugin = subprocess.Popen([args.plugin, "-port", str(deck.port), "-pluginUUID", "tool-replay", "-registerEvent", "registerPlugin"])
    settings = {}

    def press(key=context):
        deck.event("keyDown", key); deck.event("keyUp", key)

    def configure(choice):
        nonlocal settings
        settings = {"tool": choice}
        deck.event("didReceiveSettings", context, {"settings": settings}, action=action)

    def frame(name, observed=None, key_settings=None, **fields):
        fixture = {"action": action, "settings": settings if key_settings is None else key_settings, "state": observed or state(), **fields}
        directory = out / "expected"
        directory.mkdir(exist_ok=True)
        src, png = directory / (name + ".json"), directory / (name + ".png")
        src.write_text(json.dumps(fixture, indent=2))
        subprocess.run([args.plugin, "--render-key", str(src), "--output", str(png)], check=True, timeout=10)
        return base64.b64encode(png.read_bytes()).decode()

    def matches(name, target, seconds=6, key=context):
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            if deck.images.get(key, [None])[-1] == target:
                (out / (name + ".png")).write_bytes(base64.b64decode(target))
                check(name, True)
                return
            deck.next_image(key, .1)
        check(name, False)

    def stable(name):
        matches(name, frame(name))

    def reset(tool="pen", active=False, interact=False):
        check("external select " + tool, ctl("tool", tool=tool)["ok"])
        ctl("on" if active else "off")
        ctl("interact", enabled=interact)

    def unchanged(before, after):
        return all(before[k] == after[k] for k in ("tool", "style", "active", "interact"))

    try:
        check("plugin registers", deck.accept() == {"event": "registerPlugin", "uuid": "tool-replay"})
        deck.event("willAppear", context, {"settings": {}}, action=action)
        reset(interact=True)
        stable("external-off-interact")
        for active in (False, True):
            reset(TOOLS[-1], active, True)
            for tool in TOOLS:
                press()
                check("cycle to " + tool + ", active=" + str(active), wait(lambda: state()["tool"] == tool and not state()["interact"]))
                check("cycle preserves pointer selection/activation", state()["active"] == active and state()["style"] == "lavender")
                stable("cycle-" + tool + ("-on" if active else "-off"))
        for tool in TOOLS:
            configure(tool)
            ctl("interact", enabled=True)
            press()
            check("fixed " + tool + " selects and leaves Interact", wait(lambda: state()["tool"] == tool and not state()["interact"]))
            stable("fixed-" + tool)
        reset("text", False, True)
        stable("fixed-number-keeps-target-on-external-text-off-interact")

        # Differently configured keys must remain distinguishable against ONE
        # acknowledged app state. Keep all fixed keys plus cycle visible.
        configure("cycle")
        fixed_keys = {tool: "fixed-key-" + tool for tool in TOOLS}
        for tool, key in fixed_keys.items():
            deck.event("willAppear", key, {"settings": {"tool": tool}}, action=action)
        simultaneous = []

        def simultaneous_frames(name, observed, pending=None):
            images = {}
            files = {}
            for tool, key in [("cycle", context), *fixed_keys.items()]:
                filename = name + "-" + tool
                fields = {"transient": "pending"} if tool == pending else {}
                target = frame(filename, observed, {"tool": tool}, **fields)
                matches(filename, target, .5 if pending else 6, key=key)
                images[tool] = target
                files[tool] = filename + ".png"
            check(name + " fixed identities remain distinct in the same state", len({images[t] for t in TOOLS}) == len(TOOLS))
            simultaneous.append({"name": name, "state": observed, "pending": pending, "frames": files})
            (out / "simultaneous-frame-manifest.json").write_text(json.dumps(simultaneous, indent=2))

        reset("pen", True)
        simultaneous_frames("same-state-pen-ready", state())
        reset("rectangle", True)
        simultaneous_frames("same-state-external-rectangle-ready", state())
        reset("arrow", False, True)
        simultaneous_frames("same-state-external-arrow-off-interact", state())
        reset("pen", True)
        simultaneous_frames("same-state-before-fixed-number", state())
        with base.ControlProxy() as fixed_proxy:
            before = state()
            fixed_proxy.fault = "delay"
            press(fixed_keys["number"])
            # Check pending before rendering the other five expectations, so the
            # 700 ms delayed reply cannot hide the actual outstanding frame.
            matches("same-state-pending-number", frame("same-state-pending-number", before, {"tool": "number"}, transient="pending"), .5, key=fixed_keys["number"])
            simultaneous_frames("same-state-fixed-number-pending", before, pending="number")
            check("fixed number accepted once", wait(lambda: state()["tool"] == "number") and len([r for r in fixed_proxy.requests if r["operation"] == "tool"]) == 1)
            simultaneous_frames("same-state-fixed-number-acknowledged", state())
            (out / "fixed-identity-proxy-requests.json").write_text(json.dumps(fixed_proxy.requests, indent=2))
        for key in fixed_keys.values():
            deck.event("willDisappear", key)

        for value in ("bogus", "", None, 1, True, ["pen"], {"tool": "pen"}):
            configure(value)
            before = state(); press()
            matches("invalid-choice-" + str(len(results)), frame("invalid-choice", before, transient="rejected", reason="Choose Tool"))
            check("invalid saved choice never mutates " + repr(value), unchanged(before, state()))
        configure("cycle")

        with base.ControlProxy() as proxy:
            def mutations():
                return [r for r in proxy.requests if r["operation"] in ("cycle-tool", "tool", "cycle-pointer")]
            def advance(start, count):
                return TOOLS[(TOOLS.index(start) + count) % len(TOOLS)]
            reset("pen", True, True)
            stable("before-rapid")
            begin, before = len(mutations()), state()
            proxy.fault = "delay"
            for _ in range(7): press()
            matches("rapid-pending", frame("rapid-pending", before, transient="pending"), .5)
            check("seven rapid complete presses advance seven times", wait(lambda: len(mutations()) == begin + 7 and state()["tool"] == advance(before["tool"], 7)))
            stable("rapid-complete")
            check("cycle requests have no sampled tool", all(set(r) == {"version", "operation"} for r in mutations()[begin:]))

            begin, before = len(mutations()), state()
            proxy.fault = "delay"
            deck.event("keyDown", context)
            for _ in range(4): deck.event("keyDown", context)
            matches("held-pending", frame("held-pending", before, transient="pending", pressed=True), .5)
            deck.event("keyUp", context)
            check("held duplicate downs advance once", wait(lambda: state()["tool"] == advance(before["tool"], 1)) and len(mutations()) == begin + 1)
            stable("held-released")

            reset("pen", True, True); stable("before-mixed")
            pointer = "mixed-pointer"
            deck.event("willAppear", pointer, {"settings": {}}, action=base.PREFIX + "choose-pointer")
            begin = len(mutations()); proxy.fault = "delay"
            press(); configure("number"); press(); configure("arrow"); press(); press(pointer)
            check("mixed keys finish four immutable intents", wait(lambda: len(mutations()) == begin + 4 and state()["tool"] == "arrow"))
            sent = mutations()[begin:]
            check("settings change affects future presses only", [r["operation"] for r in sent] == ["cycle-tool", "tool", "tool", "cycle-pointer"] and [r.get("tool") for r in sent] == [None, "number", "arrow", None])
            stable("mixed-acknowledged")
            deck.event("willDisappear", pointer)

            # Another client changes the current tool between queued cycles.
            configure("cycle"); reset("pen", True); stable("before-external-current")
            begin, before = len(mutations()), state(); proxy.fault = "delay"
            press(); press()
            matches("external-current-pending", frame("external-current-pending", before, transient="pending"), .5)
            ctl("tool", tool="text")
            check("queued cycle reads external current tool atomically", wait(lambda: state()["tool"] == "number") and len(mutations()) == begin + 3)
            stable("external-current-acknowledged")

            begin, before = len(mutations()), state()
            proxy.fault = "delay-drop"; proxy.fail_reads = True
            press(); press(); press()
            matches("uncertain-paused", frame("uncertain-paused", before, link="reconnecting", transient="uncertain"), 1.5)
            deck.settle(1)
            check("dropped result never resends while reads fail", len(mutations()) == begin + 1)
            proxy.fail_reads = False
            check("safe read resumes only two unsent intents", wait(lambda: len(mutations()) == begin + 3 and state()["tool"] == advance(before["tool"], 3), 15))
            stable("uncertain-recovered"); deck.settle(2)
            check("no late uncertain mutation replay", len(mutations()) == begin + 3)

            # Fixed commands share deliberate-press FIFO and are not coalesced.
            configure("text"); begin = len(mutations()); proxy.fault = "delay"
            for _ in range(3): press()
            check("three rapid fixed presses acknowledged separately", wait(lambda: len(mutations()) == begin + 3 and state()["tool"] == "text"))
            stable("fixed-rapid")
            before = state(); begin = len(mutations()); proxy.fault = "delay-drop"; proxy.fail_reads = True
            press()
            matches("fixed-uncertain", frame("fixed-uncertain", before, link="reconnecting", transient="uncertain"), 1.5)
            proxy.fail_reads = False
            stable("fixed-uncertain-recovered"); deck.settle(2)
            check("uncertain fixed selection never retries", len(mutations()) == begin + 1)

            configure("cycle"); before = state(); begin = len(mutations()); proxy.fault = "delay"
            press(); press(); press()
            deck.event("willDisappear", context)
            deck.settle(1.3)
            check("page departure cancels unsent tool presses", len(mutations()) == begin + 1 and state()["tool"] == advance(before["tool"], 1))
            deck.event("willAppear", context, {"settings": {"tool": "cycle"}}, action=action)
            stable("page-return")
            before = state(); begin = len(mutations()); proxy.fault = "delay"
            press(); press()
            deck.event("willDisappear", context)
            configure("number")
            deck.event("willAppear", context, {"settings": settings}, action=action)
            deck.settle(1.4)
            check("replacement key cancels old unsent command", len(mutations()) == begin + 1)
            matches("replacement-no-old-receipt", frame("replacement-no-old-receipt"))
            before = state()
            proxy.fail_reads = True
            matches("stale", frame("stale", before, link="reconnecting"), 4)
            matches("no-reply", frame("no-reply", before, link="unavailable"), 7)
            proxy.fail_reads = False
            stable("read-recovered")
            (out / "proxy-requests.json").write_text(json.dumps(proxy.requests, indent=2))

        before = state()
        for op, fields in [("cycle-tool", {"tool": "pen"}), ("cycle-tool", {"activate": True}), ("tool", {"tool": "cycle"})]:
            reply = ctl(op, **fields)
            check("invalid wire request rejects atomically " + str(fields), not reply["ok"] and unchanged(before, reply["state"]))

        # Test-only denial reports a real app rejection without revoking macOS grants.
        ctl("interact", enabled=True); ctl("off")
        restart(deny=True)
        stable("permission-off-interact")
        for choice in ["cycle"] + TOOLS:
            configure(choice); before = state(); press()
            matches("permission-rejected-" + choice, frame("permission-rejected-" + choice, before, transient="rejected", reason="Allow Drawing"))
            check("permission denial preserves tool/activation/Interact " + choice, unchanged(before, state()))
        # Off/capture and missing permission reason ordering is unit-tested without
        # taking a screenshot of Austin's desktop.
        configure("cycle")
        subprocess.run(["osascript", "-e", 'tell application id "com.austinpresley.pleaselookhere.integration" to quit'], check=True, timeout=30)
        deck.settle(3)
        press(); press()
        matches("stopped-rejected", frame("stopped-rejected", before, link="stopped", transient="rejected", reason="Not running"), 2)
        deck.settle(2.2)
        matches("stopped-idle", frame("stopped-idle", before, link="stopped"))
        # Already stopped; start with a bounded readiness check through restart.
        restart()
        deck.settle(3)
        check("stopped tool presses never replay", unchanged(before, state()))
        stable("reconnected")
    finally:
        plugin.terminate(); plugin.wait(timeout=5)
        for key, images in deck.images.items():
            name = key.rsplit(".", 1)[-1]
            for index, value in enumerate(images):
                (out / f"{name}-{index:03d}.png").write_bytes(base64.b64decode(value))
        (out / "results.json").write_text(json.dumps(results, indent=2))
    print(f"{len(results)}/{len(results)} checks passed", flush=True)


if __name__ == "__main__":
    main()
