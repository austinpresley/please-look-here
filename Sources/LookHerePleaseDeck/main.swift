import AppKit

let arguments = CommandLine.arguments

func value(after flag: String) -> String? {
    arguments.firstIndex(of: flag).flatMap { $0 + 1 < arguments.count ? arguments[$0 + 1] : nil }
}

if let directory = value(after: "--render-assets") {
    try KeyArt.writeAssets(to: URL(fileURLWithPath: directory))
    exit(0)
}

// Render one observed-state fixture through the same model/art path as a key.
if let path = value(after: "--render-key"), let output = value(after: "--output") {
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    let fixture = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    let observed = Observed(fixture["state"] as? [String: Any])
    let link: Link
    switch fixture["link"] as? String {
    case "stopped": link = .stopped
    case "unavailable": link = .unavailable
    case "checking": link = .checking
    case "reconnecting": link = observed.map(Link.reconnecting) ?? .unavailable
    default: link = observed.map(Link.connected) ?? .checking
    }
    let transient: Transient?
    switch fixture["transient"] as? String {
    case "pending": transient = .pending
    case "accepted": transient = .accepted
    case "uncertain": transient = .uncertain
    case "rejected": transient = .rejected(fixture["reason"] as? String ?? "Failed")
    default: transient = nil
    }
    let action = (fixture["action"] as? String).flatMap(DeckAction.init(rawValue:)) ?? .pointer
    let face = KeyModel.face(action: action, settings: KeySettings(fixture["settings"] as? [String: Any]), link: link,
                             styleNames: fixture["styleNames"] as? [String: String] ?? [:], transient: transient, pressed: fixture["pressed"] as? Bool ?? false)
    let thumbnail = (fixture["thumbnail"] as? String).flatMap { NSImage(contentsOfFile: $0)?.cgImage(forProposedRect: nil, context: nil, hints: nil) }
    guard let png = KeyArt.png(face, image: thumbnail) else { exit(1) }
    try png.write(to: URL(fileURLWithPath: output))
    exit(0)
}

if let path = value(after: "--render-sheet") {
    let thumbnail = value(after: "--thumbnail").flatMap { NSImage(contentsOfFile: $0)?.cgImage(forProposedRect: nil, context: nil, hints: nil) }
    try KeyArt.writeSheet(to: URL(fileURLWithPath: path), thumbnail: thumbnail)
    exit(0)
}

guard let portText = value(after: "-port"), let port = Int(portText),
      let uuid = value(after: "-pluginUUID"), let event = value(after: "-registerEvent") else {
    print("Stream Deck starts this plugin. It needs -port, -pluginUUID and -registerEvent.")
    exit(2)
}

let plugin = DeckPlugin(port: port, pluginUUID: uuid, registerEvent: event)
plugin.start()
dispatchMain()
