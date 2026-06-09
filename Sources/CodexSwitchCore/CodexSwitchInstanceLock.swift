import Darwin
import Foundation

public final class CodexSwitchInstanceLock {
    private let lockFile: String
    private var fileDescriptor: Int32 = -1

    public init(codexDir: String? = nil) {
        let resolvedCodexDir = codexDir ?? "\(FileManager.default.homeDirectoryForCurrentUser.path)/.codex"
        lockFile = "\(resolvedCodexDir)/codex-switch.lock"
    }

    deinit {
        release()
    }

    public func acquire() throws -> Bool {
        if fileDescriptor >= 0 { return true }

        let directory = URL(fileURLWithPath: lockFile).deletingLastPathComponent().path
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)

        let fd = open(lockFile, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard fd >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }

        if flock(fd, LOCK_EX | LOCK_NB) == 0 {
            fileDescriptor = fd
            return true
        }

        let code = POSIXErrorCode(rawValue: errno) ?? .EWOULDBLOCK
        close(fd)
        if code == .EWOULDBLOCK { return false }
        throw POSIXError(code)
    }

    public func release() {
        guard fileDescriptor >= 0 else { return }
        flock(fileDescriptor, LOCK_UN)
        close(fileDescriptor)
        fileDescriptor = -1
    }
}
