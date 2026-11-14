import Darwin
import Foundation

/// One request per connection over the app's private control socket.
enum AppLink {
    static let bundleID = "com.austinpresley.pleaselookhere.integration"
    private static let responseLimit = 2_097_152

    enum Outcome {
        case reply([String: Any])
        /// The request never reached the app, so the app is not running.
        case stopped
        /// The app may or may not have acted. Never replay this request.
        case uncertain
    }

    static var directory: String? {
        var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
        guard confstr(_CS_DARWIN_USER_TEMP_DIR, &buffer, buffer.count) > 0 else { return nil }
        return String(cString: buffer) + bundleID + ".ctl"
    }

    static func send(_ request: [String: Any]) -> Outcome {
        guard let directory, var body = try? JSONSerialization.data(withJSONObject: request) else { return .uncertain }
        var info = stat()
        guard lstat(directory, &info) == 0 else { return errno == ENOENT ? .stopped : .uncertain }
        guard info.st_uid == getuid(), info.st_mode & S_IFMT == S_IFDIR, info.st_mode & 0o777 == 0o700 else { return .uncertain }

        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        let path = (directory + "/s").utf8CString
        guard path.count <= MemoryLayout.size(ofValue: address.sun_path) else { return .uncertain }
        withUnsafeMutableBytes(of: &address.sun_path) { target in path.withUnsafeBytes { target.copyBytes(from: $0) } }

        let socketFD = socket(AF_UNIX, SOCK_STREAM, 0)
        guard socketFD >= 0 else { return .uncertain }
        defer { close(socketFD) }
        var timeout = timeval(tv_sec: 2, tv_usec: 0)
        setsockopt(socketFD, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(socketFD, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        var noSignal: Int32 = 1
        setsockopt(socketFD, SOL_SOCKET, SO_NOSIGPIPE, &noSignal, socklen_t(MemoryLayout<Int32>.size))
        let connected = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(socketFD, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard connected == 0 else { return errno == ENOENT || errno == ECONNREFUSED ? .stopped : .uncertain }
        var peerUser: uid_t = 0, peerGroup: gid_t = 0
        guard getpeereid(socketFD, &peerUser, &peerGroup) == 0, peerUser == getuid() else { return .uncertain }

        body.append(10)
        var sent = 0
        while sent < body.count {
            let count = body.withUnsafeBytes { write(socketFD, $0.baseAddress!.advanced(by: sent), body.count - sent) }
            if count < 0 && errno == EINTR { continue }
            guard count > 0 else { return .uncertain }
            sent += count
        }

        var response = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while response.count <= responseLimit {
            let count = read(socketFD, &buffer, buffer.count)
            if count < 0 && errno == EINTR { continue }
            guard count > 0 else { return .uncertain }
            if let newline = buffer[..<count].firstIndex(of: 10) {
                response.append(contentsOf: buffer[..<newline])
                guard let object = try? JSONSerialization.jsonObject(with: response) as? [String: Any],
                      object["version"] as? Int == 1, object["ok"] is Bool else { return .uncertain }
                return .reply(object)
            }
            response.append(contentsOf: buffer[..<count])
        }
        return .uncertain
    }
}
