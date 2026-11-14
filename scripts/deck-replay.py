#!/usr/bin/env python3
"""Replay Stream Deck events into the plugin executable against a running app.

The app must be a disposable test instance. A replay does not close hardware
acceptance. Usage: deck-replay.py --app <bundle> --plugin <binary> --out <dir>
"""
import argparse, base64, hashlib, json, os, pathlib, socket, struct, subprocess, sys, threading, time

GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
PREFIX = "com.austinpresley.lookhereplease."


class Deck:
    def __init__(self):
        self.server = socket.create_server(("127.0.0.1", 0))
        self.port = self.server.getsockname()[1]
        self.images = {}
        self.inspector = []

    def accept(self):
        self.client, _ = self.server.accept()
        self.client.settimeout(10)
        request = b""
        while b"\r\n\r\n" not in request:
            request += self.client.recv(4096)
        key = next(line.split(b":", 1)[1].strip() for line in request.split(b"\r\n") if line.lower().startswith(b"sec-websocket-key"))
        accept = base64.b64encode(hashlib.sha1(key + GUID.encode()).digest()).decode()
        self.client.sendall(f"HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: {accept}\r\n\r\n".encode())
        return self.read()

    def exact(self, count):
        data = b""
        while len(data) < count:
            chunk = self.client.recv(count - len(data))
            if not chunk:
                raise ConnectionError("plugin disconnected")
            data += chunk
        return data

    def read(self):
        first, second = self.exact(2)
        length = second & 127
        if length == 126:
            length = struct.unpack(">H", self.exact(2))[0]
        elif length == 127:
            length = struct.unpack(">Q", self.exact(8))[0]
        mask = self.exact(4) if second & 128 else b"\0\0\0\0"
        data = bytes(value ^ mask[index % 4] for index, value in enumerate(self.exact(length)))
        return json.loads(data)

    def send(self, message):
        data = json.dumps(message).encode()
        header = bytes([0x81]) + (bytes([len(data)]) if len(data) < 126 else bytes([126]) + struct.pack(">H", len(data)))
        self.client.sendall(header + data)

    def event(self, name, context, payload=None, action=None):
        message = {"event": name, "context": context, "action": action or context, "payload": payload or {}}
        self.send(message)

    def next_image(self, context, timeout):
        """Wait for the next setImage on one key, keeping others."""
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            self.client.settimeout(max(deadline - time.monotonic(), 0.01))
            try:
                message = self.read()
            except (TimeoutError, socket.timeout):
                return None
            if message.get("event") == "sendToPropertyInspector":
                self.inspector.append(message["payload"])
            if message.get("event") != "setImage":
                continue
            image = message["payload"]["image"].split(",", 1)[1]
            self.images.setdefault(message["context"], []).append(image)
            if message["context"] == context:
                return image
        return None

    def settle(self, seconds):
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            self.client.settimeout(max(deadline - time.monotonic(), 0.01))
            try:
                message = self.read()
            except (TimeoutError, socket.timeout):
                return
            if message.get("event") == "sendToPropertyInspector":
                self.inspector.append(message["payload"])
            if message.get("event") == "setImage":
                self.images.setdefault(message["context"], []).append(message["payload"]["image"].split(",", 1)[1])


class ControlProxy:
    """Fault injection around the real isolated app, never a replacement app model."""
    def __init__(self):
        directory = pathlib.Path(subprocess.check_output(["getconf", "DARWIN_USER_TEMP_DIR"], text=True).strip()) / "com.austinpresley.pleaselookhere.integration.ctl"
        self.path = directory / "s"
        self.upstream = directory / "x"
        self.requests = []
        self.fault = None
        self.fail_reads = False
        self.omit_thumbnails = False
        self.running = True

    def __enter__(self):
        assert not self.upstream.exists(), "A replay proxy is already active"
        self.path.rename(self.upstream)
        self.server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.server.bind(str(self.path))
        os.chmod(self.path, 0o600)
        self.server.listen()
        self.server.settimeout(.2)
        self.thread = threading.Thread(target=self.run, daemon=True)
        self.thread.start()
        return self

    def run(self):
        while self.running:
            try:
                connection, _ = self.server.accept()
            except socket.timeout:
                continue
            except OSError:
                return
            with connection:
                connection.settimeout(4)
                body = b""
                while b"\n" not in body:
                    chunk = connection.recv(4096)
                    if not chunk:
                        break
                    body += chunk
                if not body:
                    continue
                request = json.loads(body)
                operation = request["operation"]
                self.requests.append(request)
                if self.fail_reads and operation in ("status", "styles"):
                    continue
                with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as app:
                    app.settimeout(4)
                    app.connect(str(self.upstream))
                    app.sendall(body)
                    response = b""
                    while b"\n" not in response:
                        response += app.recv(65536)
                if operation in ("toggle", "cycle-pointer", "cycle-tool", "tool") and self.fault:
                    fault, self.fault = self.fault, None
                    if fault in ("delay", "delay-drop"):
                        time.sleep(.7)
                    if fault in ("drop", "delay-drop"):
                        continue
                if operation == "styles" and self.omit_thumbnails:
                    reply = json.loads(response)
                    for style in reply.get("styles", []):
                        style.pop("thumbnail", None)
                    response = json.dumps(reply).encode() + b"\n"
                try:
                    connection.sendall(response)
                except (BrokenPipeError, ConnectionResetError):
                    pass

    def __exit__(self, *_):
        self.running = False
        self.thread.join(timeout=6)
        self.server.close()
        self.path.unlink(missing_ok=True)
        self.upstream.rename(self.path)


def replay_current_pointer(args, deck, ctl, state, wait_state, check):
    """Compare real websocket setImage frames with rendered observed-state fixtures."""
    out = pathlib.Path(args.out)
    pointer = PREFIX + "pointer"
    expected_dir = out / "expected"
    expected_dir.mkdir(exist_ok=True)
    catalog = {}

    def refresh_catalog():
        nonlocal catalog
        catalog = {item["id"]: item for item in ctl({"operation": "styles"})["styles"]}

    def expected(name, observed=None, **fields):
        fixture = {"state": observed or state(), **fields}
        thumb = catalog.get(fixture["state"]["style"], {}).get("thumbnail")
        if thumb and "thumbnail" not in fields:
            fixture["thumbnail"] = thumb
        spec, png = expected_dir / (name + ".json"), expected_dir / (name + ".png")
        spec.write_text(json.dumps(fixture, indent=2))
        subprocess.run([args.plugin, "--render-key", str(spec), "--output", str(png)], check=True, timeout=10)
        return base64.b64encode(png.read_bytes()).decode()

    def matches(name, target, seconds=4, context=pointer):
        start = len(deck.images.get(context, []))
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            # Include the last received frame, since a safe read may already have delivered it.
            frames = deck.images.get(context, [])
            if frames and frames[-1] == target:
                (out / (name + ".png")).write_bytes(base64.b64decode(target))
                check(name, True)
                return True
            deck.next_image(context, min(.2, max(.01, deadline - time.monotonic())))
        check(name, False, f"{len(deck.images.get(context, [])) - start} new frames; expected rendered bitmap")
        return False

    ctl({"operation": "enable-pointer", "style": "robot", "enabled": True})
    refresh_catalog()
    # Only a toggle key is visible: thumbnail loading cannot depend on Select Pointer.
    deck.event("willAppear", pointer, {"settings": {"style": "gone", "activate": False}})
    matches("current-hand-off", expected("current-hand-off"))
    for style in ("robot", "laser", "custom-s019"):
        reply = ctl({"operation": "style", "style": style})
        assert reply["ok"], reply
        observed = reply["state"]
        matches(style + "-off", expected(style + "-off", observed))
        deck.event("keyDown", pointer)
        deck.event("keyUp", pointer)
        check(style + " toggles on without selecting", wait_state(lambda s: s["active"] and s["style"] == style))
        matches(style + "-on", expected(style + "-on"))
        deck.event("keyDown", pointer)
        deck.event("keyUp", pointer)
        check(style + " toggles off without selecting", wait_state(lambda s: not s["active"] and s["style"] == style))
        matches(style + "-off-again", expected(style + "-off-again"))

    # Replacing a selected custom asset with the same ID must update an already-visible key.
    custom_path = pathlib.Path(args.hands) / "custom-s019.png"
    original = custom_path.read_bytes()
    original_frame = deck.images[pointer][-1]
    replacement = pathlib.Path(__file__).resolve().parents[1] / "docs/assets/hands/chrome.png"
    try:
        custom_path.write_bytes(replacement.read_bytes())
        time.sleep(1.2)
        refresh_catalog()
        matches("custom-replaced", expected("custom-replaced"), 5)
        check("same-id artwork actually changed", deck.images[pointer][-1] != original_frame)
        custom_path.unlink()
        check("missing selected custom uses app fallback", wait_state(lambda s: s["style"] == "lavender" and "custom-s019" not in s["enabledPointers"]))
        matches("missing-custom-fallback", expected("missing-custom-fallback"))
    finally:
        custom_path.write_bytes(original)
    check("restored custom is enabled without stealing selection", wait_state(lambda s: "custom-s019" in s["enabledPointers"] and s["style"] == "lavender"))
    ctl({"operation": "style", "style": "robot"})
    ctl({"operation": "on"})
    ctl({"operation": "enable-pointer", "style": "robot", "enabled": False})
    check("enabled-set fallback keeps activation", state()["active"] and state()["style"] == "lavender")
    matches("disabled-selected-fallback", expected("disabled-selected-fallback"))
    deck.event("keyDown", pointer)
    deck.event("keyUp", pointer)
    check("toggle preserves enabled-set fallback", wait_state(lambda s: not s["active"] and s["style"] == "lavender"))
    matches("fallback-off", expected("fallback-off"))

    refresh_catalog()
    with ControlProxy() as proxy:
        before = state()
        proxy.fault = "delay"
        started = time.monotonic()
        deck.event("keyDown", pointer)
        pending = expected("pending-pressed", before, transient="pending", pressed=True)
        matches("pending-pressed", pending, .5)
        check("pending feedback arrives before command reply", time.monotonic() - started < .7)
        # A repeated physical press while pending gets a border but queues no late toggle.
        deck.event("keyDown", pointer)
        deck.event("keyUp", pointer)
        matches("pending-released", expected("pending-released", before, transient="pending"), .5)
        after = {**before, "active": True}
        matches("accepted", expected("accepted", after, transient="accepted"), 2)
        matches("observed-on", expected("observed-on", after))
        check("pending repeated press sends one toggle", sum(r["operation"] == "toggle" for r in proxy.requests) == 1)

        proxy.fault = "drop"
        deck.event("keyDown", pointer)
        deck.event("keyUp", pointer)
        matches("uncertain", expected("uncertain", after, link="reconnecting", transient="uncertain"), 1)
        check("dropped acknowledgment can still mutate once", not state()["active"])
        matches("observed-off-after-uncertain", expected("observed-off-after-uncertain"), 4)
        check("uncertain mutation was never replayed", sum(r["operation"] == "toggle" for r in proxy.requests) == 2)

        # A thumbnail-read problem must not substitute a generic or different hand.
        proxy.omit_thumbnails = True
        matches("artwork-unavailable-off", expected("artwork-unavailable-off", thumbnail=False), 5)
        proxy.omit_thumbnails = False
        matches("artwork-restored-off", expected("artwork-restored-off"), 5)

        before = state()
        proxy.fail_reads = True
        matches("stale", expected("stale", before, link="reconnecting"), 3)
        matches("no-reply", expected("no-reply", before, link="unavailable"), 6)
        proxy.fail_reads = False
        matches("read-recovered", expected("read-recovered", before), 4)
        check("safe read recovery sends no mutation", sum(r["operation"] == "toggle" for r in proxy.requests) == 2)
        (out / "proxy-requests.json").write_text(json.dumps(proxy.requests, indent=2))

    # Existing fixed-selection action remains app-validated; no new toggle override is added.
    select = PREFIX + "select-pointer"
    deck.event("willAppear", select, {"settings": {"style": "robot", "activate": True}})
    deck.settle(.5)
    for style, reason in [("robot", "Disabled"), ("custom-s019-missing", "Missing")]:
        deck.event("didReceiveSettings", select, {"settings": {"style": style, "activate": True}})
        deck.settle(.2)
        before = state()
        deck.event("keyDown", select)
        deck.event("keyUp", select)
        target = expected(reason.lower() + "-rejection", before, action=select, settings={"style": style, "activate": True},
                          styleNames={k: v["name"] for k, v in catalog.items()}, transient="rejected", reason=reason,
                          thumbnail=catalog.get(style, {}).get("thumbnail", False))
        matches(reason.lower() + "-rejection", target, 1, context=select)
        after = state()
        check(reason.lower() + " fixed action rejects without selection or activation", before["style"] == after["style"] and before["active"] == after["active"])
    deck.event("willDisappear", select)
    ctl({"operation": "enable-pointer", "style": "robot", "enabled": True})


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--app", required=True)
    parser.add_argument("--plugin", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--suite", default=os.environ.get("TINYHAND_DEFAULTS_SUITE"))
    parser.add_argument("--hands", default=os.environ.get("TH_HANDS_DIR"))
    parser.add_argument("--current-pointer", action="store_true", help="Exercise S-019 artwork and fault handling before the base replay")
    args = parser.parse_args()
    binary = str(pathlib.Path(args.app) / "Contents/MacOS/TinyHand")
    out = pathlib.Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    results = []

    def check(name, passed, detail=""):
        results.append({"check": name, "passed": bool(passed), "detail": detail})
        print(("PASS " if passed else "FAIL ") + name + (f" ({detail})" if detail else ""))

    def ctl(request):
        output = subprocess.run([binary, "--ctl", json.dumps({"version": 1, **request})], capture_output=True, text=True, timeout=10).stdout
        return json.loads(output)

    def state():
        # A status read can be refused while the app is busy activating. That is
        # transport noise here, not a result, so read again.
        for attempt in range(20):
            reply = ctl({"operation": "status"})
            if "state" in reply:
                return reply["state"]
            print(f"status retry {attempt + 1}: {reply.get('error')}", flush=True)
            time.sleep(0.1)
        raise RuntimeError("status never answered")

    def wait_state(predicate, timeout=6.0):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if predicate(state()):
                return True
            time.sleep(0.05)
        return False

    def press(context):
        deck.event("keyDown", context)
        deck.event("keyUp", context)

    # Verify the running process, not merely this runner's environment, before mutations.
    if not args.suite or not args.hands or not pathlib.Path(args.hands).is_dir():
        sys.exit("Provide a disposable --suite and --hands, or matching environment variables.")
    safety = ctl({"operation": "test-shortcuts", "request": {}})
    if safety.get("shortcuts", {}).get("defaultsSuite") != args.suite:
        sys.exit("Refusing to mutate an app outside the requested isolated defaults suite.")
    initial = state()
    if initial["active"] or not initial["interact"]:
        sys.exit("Start from a fresh test instance: pointer off and Interact on.")

    deck = Deck()
    plugin = subprocess.Popen([args.plugin, "-port", str(deck.port), "-pluginUUID", "replay", "-registerEvent", "registerPlugin", "-info", "{}"])
    try:
        registration = deck.accept()
        check("plugin registers", registration == {"event": "registerPlugin", "uuid": "replay"}, str(registration))
        if args.current_pointer:
            replay_current_pointer(args, deck, ctl, state, wait_state, check)
        pointer, interact, select = PREFIX + "pointer", PREFIX + "interact", PREFIX + "select-pointer"
        deck.event("willAppear", pointer, {"settings": {}})
        deck.event("willAppear", interact, {"settings": {}})
        deck.event("willAppear", select, {"settings": {"style": "robot", "activate": False}})
        # A fresh app is still preloading thumbnails, which briefly blocks control requests.
        deck.settle(4.0)
        for context in (pointer, interact, select):
            check("key rendered " + context.rsplit(".", 1)[1], deck.images.get(context))

        before = len(deck.images[pointer])
        started = time.monotonic()
        deck.event("keyDown", pointer)
        acknowledged = deck.next_image(pointer, 2)
        check("press draws feedback", acknowledged, f"{(time.monotonic() - started) * 1000:.0f} ms to first image")
        deck.event("keyUp", pointer)
        check("key toggled the app on", wait_state(lambda s: s["active"]))
        deck.settle(1.0)
        check("feedback frames follow the acknowledgement", len(deck.images[pointer]) - before >= 2, f"{len(deck.images[pointer]) - before} frames")

        count = len(deck.images[pointer])
        started = time.monotonic()
        ctl({"operation": "off"})
        changed = deck.next_image(pointer, 2.5)
        check("external pointer change reaches the key", changed and len(deck.images[pointer]) > count, f"{(time.monotonic() - started) * 1000:.0f} ms")

        press(select)
        check("key selected the configured pointer", wait_state(lambda s: s["style"] == "robot"))
        check("activate false kept the pointer off", not state()["active"])
        deck.settle(1.0)
        count = len(deck.images[select])
        ctl({"operation": "style", "style": "lavender"})
        check("external pointer selection reaches the key", deck.next_image(select, 2.5) and len(deck.images[select]) > count)

        denied = not state()["accessibility"]
        press(interact)
        deck.settle(1.0)
        if denied:
            check("denied permission leaves Interact on", state()["interact"])
        else:
            check("Interact key changed the app", wait_state(lambda s: not s["interact"]))
            press(interact)
            check("Interact key restored the app", wait_state(lambda s: s["interact"]))

        deck.event("didReceiveSettings", select, {"settings": {"style": "gone", "activate": False}})
        deck.settle(0.8)
        selected = state()["style"]
        press(select)
        deck.settle(0.8)
        check("rejected selection changes nothing", state()["style"] == selected)

        count = len(deck.images[pointer])
        ctl({"operation": "on"})
        deck.settle(1.0)
        check("sent state before quit", state()["active"])
        subprocess.run(["osascript", "-e", 'tell application id "com.austinpresley.pleaselookhere.integration" to quit'], timeout=30, check=True)
        deck.settle(3.5)
        check("stopped app reaches the key", len(deck.images[pointer]) > count)
        press(pointer)
        deck.settle(0.6)
        (out / "stopped.png").write_bytes(base64.b64decode(deck.images[pointer][-1]))
        deck.event("sendToPlugin", select, {"request": "styles"})
        deck.settle(0.6)
        check("open inspector is told the app is unavailable", deck.inspector and deck.inspector[-1]["available"] is False, str(len(deck.inspector)))
        deck.inspector.clear()
        subprocess.run(["open", "-n", "--env", "TINYHAND_TEST_MODE=1", "--env", "TINYHAND_DEFAULTS_SUITE=" + args.suite,
                        "--env", "TH_HANDS_DIR=" + args.hands, args.app], check=True)
        deadline = time.monotonic() + 20
        recovered = False
        while time.monotonic() < deadline:
            deck.settle(0.5)
            try:
                recovered = bool(ctl({"operation": "status"}).get("ok"))
            except Exception:
                recovered = False
            if recovered:
                break
        check("app relaunched", recovered)
        count = len(deck.images[pointer])
        deck.settle(3.0)
        check("key recovers without a press", len(deck.images[pointer]) > count)
        # The first catalog read can time out while a fresh app preloads, so allow for its retries.
        deadline = time.monotonic() + 20
        while time.monotonic() < deadline and not (deck.inspector and deck.inspector[-1]["available"] is True):
            deck.settle(0.5)
        check("open inspector fills in after recovery", deck.inspector and deck.inspector[-1]["available"] is True and len(deck.inspector[-1]["styles"]) > 0,
              f"{len(deck.inspector)} updates, {time.monotonic() - deadline + 20:.1f} s")
        check("nothing was replayed after restart", not state()["active"])
    finally:
        plugin.terminate()
        for context, images in deck.images.items():
            name = context.rsplit(".", 1)[1]
            for index, image in enumerate(images):
                (out / f"{name}-{index:02d}.png").write_bytes(base64.b64decode(image))
        (out / "results.json").write_text(json.dumps(results, indent=2) + "\n")
    failed = [item for item in results if not item["passed"]]
    print(f"{len(results) - len(failed)} of {len(results)} checks passed")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
