// Own one Carbon combination while the isolated runtime check verifies rejection.
import AppKit
import Carbon.HIToolbox

_ = NSApplication.shared
guard CommandLine.arguments.count == 3,
      let key = UInt32(CommandLine.arguments[1]), let modifiers = UInt32(CommandLine.arguments[2]) else { exit(2) }
var reference: EventHotKeyRef?
let status = RegisterEventHotKey(key, modifiers, EventHotKeyID(signature: 0x53544553, id: 1),
                                 GetApplicationEventTarget(), OptionBits(kEventHotKeyExclusive), &reference)
guard status == noErr else { fputs("Registration failed: \(status)\n", stderr); exit(1) }
print("ready")
fflush(stdout)
RunLoop.main.run()
