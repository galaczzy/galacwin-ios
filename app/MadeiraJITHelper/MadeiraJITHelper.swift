// SPDX-License-Identifier: GPL-3.0-or-later
// Madeira Converter Exception: see LICENSE-EXCEPTION.md

// Madeira's JIT helper: a classic app extension that Madeira starts by its bundle ID
// (app/Madeira/JITBuiltInHost.swift), so a sideloader's renamed install still finds it.
// One MadeiraJITRequest per extension request, answered when the request completes.

import Foundation
import CryptoKit
import os
#if !targetEnvironment(simulator)
import StikJIT
#endif

#if targetEnvironment(simulator)
private struct DDIPaths {
    static func `default`(in directory: URL) -> DDIPaths { DDIPaths() }
}

private enum StikJIT {
    enum Script { case customBase64(String) }
    struct DeviceSecurityState { let isTXMPresent: Bool? }
    enum PreparationStage { case unavailable }
    enum JITReadiness {
        case unreachable(reason: String)
        case preparationFailed(reason: String)
        case ready(DeviceSecurityState)
    }

    static var isTXMPresent: Bool? { nil }
    static func prepareDevice(pairingFile: URL, paths: DDIPaths,
                              progress: (PreparationStage) -> Void) -> JITReadiness {
        .unreachable(reason: "Built-in JIT is available only on a physical device.")
    }
    static func enableJIT(targetPID: Int32, pairingFile: URL, ddiPaths: DDIPaths,
                          script: Script, forceScript: Bool,
                          preparationProgress: (PreparationStage) -> Void,
                          progress: (String) -> Void) throws {
        throw NSError(domain: "MadeiraJITHelper", code: 100,
                      userInfo: [NSLocalizedDescriptionKey:
                        "Built-in JIT is available only on a physical device."])
    }
    static func resetCachedDDI(at paths: DDIPaths) throws {}
}
#endif

#if !targetEnvironment(simulator)
/// StikJIT 1.9.0 accepts any nonempty cached DDI and otherwise downloads from
/// a moving GitHub branch. Fill and verify its cache before calling it so that
/// neither a changed download nor a modified cached file reaches the mounter.
private enum VerifiedDDI {
    private static let revision = "e2aaeac89ca8fa56c2fa1f144d182994e07a525b"

    private struct FileSpec: Sendable {
        let name: String
        let path: String
        let size: Int64
        let sha256: String
    }

    private final class DownloadResult: @unchecked Sendable {
        var error: Error?
    }

    static func prepare(_ paths: DDIPaths) throws {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let cryptex = version.majorVersion > 26 || (version.majorVersion == 26 && version.minorVersion >= 4)
        let folder = cryptex ? "Xcode_iOS_DDI_Cryptex" : "Xcode_iOS_DDI_Personalized"
        let base = URL(string: "https://raw.githubusercontent.com/doronz88/DeveloperDiskImage/\(revision)/PersonalizedImages/\(folder)/")!
        let files: [FileSpec]
        if cryptex {
            files = [
                .init(name: "BuildManifest.plist", path: paths.manifestPath, size: 804946,
                      sha256: "27385d7582b03b36bb3104e22b520aee0c47d72fecb4e8ecfe12ef5d966c7012"),
                .init(name: "Image.dmg", path: paths.imagePath, size: 15895040,
                      sha256: "873097f695a8b9734e2abc54f795a8874d40ff6fd11208ecb01ef29534c7c176"),
                .init(name: "Image.dmg.trustcache", path: paths.trustcachePath, size: 1895,
                      sha256: "f7f21986074eee03a215aca16ecfc78d6bf183600d8a0d2fb691f9896782e6f0"),
                .init(name: "Image.dmg.cryptex_info", path: paths.cryptexInfoPath, size: 430,
                      sha256: "edf49aef55aacc063d4d7be05b713bb545ce2993b3f62bcc15eccd75e610ee6c"),
                .init(name: "Image.dmg.root_hash", path: paths.rootHashPath, size: 229,
                      sha256: "3543fad2805b88119695c417e12679380b3b5a2742994bbcc839c8e2de5d7302"),
            ]
        } else {
            files = [
                .init(name: "BuildManifest.plist", path: paths.manifestPath, size: 801505,
                      sha256: "8edd4a2f4f4ef1fbd7bfe49785d8badc673d1395d1d94d85b132ca8ab5ecaf54"),
                .init(name: "Image.dmg", path: paths.imagePath, size: 15733248,
                      sha256: "05fd807da5e19f030fa4941f24800c965c6c77982ab572dd5d1ef778fb69f9ca"),
                .init(name: "Image.dmg.trustcache", path: paths.trustcachePath, size: 1895,
                      sha256: "36af60889ff5a737874a26daeb8e1a0139ebfebec6ec2e4d8f6a3c1bf1dce35c"),
            ]
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 120
        configuration.timeoutIntervalForResource = 600
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }
        for file in files {
            if try matches(file, at: URL(fileURLWithPath: file.path)) { continue }
            try download(file, from: base.appendingPathComponent(file.name), session: session)
        }
        if !cryptex {
            for path in [paths.cryptexInfoPath, paths.rootHashPath] where FileManager.default.fileExists(atPath: path) {
                try FileManager.default.removeItem(atPath: path)
            }
        }
    }

    private static func matches(_ file: FileSpec, at url: URL) throws -> Bool {
        let manager = FileManager.default
        guard manager.fileExists(atPath: url.path) else { return false }
        let attributes = try manager.attributesOfItem(atPath: url.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular,
              (attributes[.size] as? NSNumber)?.int64Value == file.size else { return false }
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        let actual = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return actual == file.sha256
    }

    private static func download(_ file: FileSpec, from url: URL, session: URLSession) throws {
        let result = DownloadResult()
        let semaphore = DispatchSemaphore(value: 0)
        let task = session.downloadTask(with: url) { temporaryURL, response, error in
            defer { semaphore.signal() }
            do {
                if let error { throw error }
                guard let temporaryURL, let response = response as? HTTPURLResponse,
                      response.statusCode == 200,
                      try matches(file, at: temporaryURL) else {
                    throw NSError(domain: "GalacWinVerifiedDDI", code: 1,
                                  userInfo: [NSLocalizedDescriptionKey:
                                    "Developer Disk Image download failed verification: \(file.name)"])
                }
                let destination = URL(fileURLWithPath: file.path)
                let manager = FileManager.default
                try manager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                if manager.fileExists(atPath: destination.path) { try manager.removeItem(at: destination) }
                try manager.moveItem(at: temporaryURL, to: destination)
            } catch {
                result.error = error
            }
        }
        task.resume()
        if semaphore.wait(timeout: .now() + 650) == .timedOut {
            task.cancel()
            throw NSError(domain: "GalacWinVerifiedDDI", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Developer Disk Image download timed out."])
        }
        if let error = result.error { throw error }
    }
}
#endif

private enum MadeiraJITWork {
    /// One request at a time, as the XPC handler ran them before.
    static let queue = DispatchQueue(label: "com.galaczzy.galacwin.jit-helper")

    static func handle(_ request: MadeiraJITRequest) -> MadeiraJITRequest.Response {
        let manager = FileManager.default
        let root = manager.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("StikJIT", isDirectory: true)
        let paths = DDIPaths.default(in: root)

        do {
            try manager.createDirectory(at: root, withIntermediateDirectories: true)
            if request.operation == .resetDDI {
                try StikJIT.resetCachedDDI(at: paths)
                return .init(success: true,
                             message: "Developer Disk Image cache reset.",
                             txmPresent: StikJIT.isTXMPresent)
            }

            guard let pairingData = request.pairingData, !pairingData.isEmpty,
                  pairingData.count <= MadeiraJITRequest.maximumPairingFileSize else {
                throw NSError(domain: "MadeiraJITHelper", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "The pairing file was not provided."])
            }
            let pairingURL = root.appendingPathComponent("pairingFile-\(UUID().uuidString).plist")
            try pairingData.write(to: pairingURL, options: [.atomic, .completeFileProtection])
            defer { try? manager.removeItem(at: pairingURL) }
            try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: pairingURL.path)

            switch request.operation {
            case .prepare:
                #if !targetEnvironment(simulator)
                try VerifiedDDI.prepare(paths)
                #endif
                let readiness = StikJIT.prepareDevice(
                    pairingFile: pairingURL, paths: paths,
                    progress: { NSLog("[MadeiraJIT] prepare: %@", String(describing: $0)) })
                switch readiness {
                case .ready(let security):
                    return .init(success: true,
                                 message: "LocalDevVPN is reachable and the Developer Disk Image is ready.",
                                 txmPresent: security.isTXMPresent)
                case .unreachable(let reason), .preparationFailed(let reason):
                    return .init(success: false, message: reason,
                                 txmPresent: StikJIT.isTXMPresent)
                @unknown default:
                    return .init(success: false,
                                 message: "StikJIT returned an unknown preparation state.",
                                 txmPresent: StikJIT.isTXMPresent)
                }
            case .enable:
                guard let targetPID = request.targetPID,
                      let scriptBase64 = request.scriptBase64,
                      !scriptBase64.isEmpty else {
                    throw NSError(domain: "MadeiraJITHelper", code: 2,
                                  userInfo: [NSLocalizedDescriptionKey:
                                    "The target process or Madeira JIT script was not provided."])
                }
                #if !targetEnvironment(simulator)
                try VerifiedDDI.prepare(paths)
                #endif
                try StikJIT.enableJIT(
                    targetPID: targetPID,
                    pairingFile: pairingURL,
                    ddiPaths: paths,
                    script: .customBase64(scriptBase64),
                    forceScript: true,
                    preparationProgress: {
                        NSLog("[MadeiraJIT] prepare: %@", String(describing: $0))
                    },
                    progress: { NSLog("[MadeiraJIT] %@", $0) })
                return .init(success: true,
                             message: "Madeira detached cleanly from its built-in JIT helper.",
                             txmPresent: StikJIT.isTXMPresent)
            case .resetDDI, .probe:
                preconditionFailure("Handled above")
            }
        } catch {
            return .init(success: false, message: error.localizedDescription,
                         txmPresent: StikJIT.isTXMPresent)
        }
    }
}

/// NSExtensionPrincipalClass (Info.plist). The request arrives as JSON in the first input
/// item; the response goes back as JSON in the item the request completes with. Enable
/// completes only when Madeira's script has detached, so the request, and this process,
/// last as long as the debugger does.
@objc(MadeiraJITHelperHandler)
final class MadeiraJITHelperHandler: NSObject, NSExtensionRequestHandling {
    func beginRequest(with context: NSExtensionContext) {
        let info = (context.inputItems.first as? NSExtensionItem)?.userInfo
        let data = info?[MadeiraJITRequest.itemKey] as? Data
        let request = data.flatMap { try? JSONDecoder().decode(MadeiraJITRequest.self, from: $0) }
        // ml1310: the probe never waits behind a running enable request (that one lasts
        // as long as the debugger does), so it has its own queue.
        let queue = request?.operation == .probe ? DispatchQueue.global(qos: .utility) : MadeiraJITWork.queue
        queue.async {
            let response: MadeiraJITRequest.Response
            if let request, request.operation == .probe {
                response = MadeiraExtensionProbeWork.run()
            } else if let request {
                response = MadeiraJITWork.handle(request)
            } else {
                response = .init(success: false, message: "Madeira's JIT helper received no request.",
                                 txmPresent: nil)
            }
            let item = NSExtensionItem()
            item.userInfo = [MadeiraJITRequest.Response.itemKey: (try? JSONEncoder().encode(response)) ?? Data()]
            context.completeRequest(returningItems: [item], completionHandler: nil)
        }
    }
}

/// ml1310: what this extension's own process may map, for running Wine processes in an
/// app extension (docs/NUTSEMU_ANALYSIS.md section 4c, step 7; docs/PROCESS_MODEL_ML1310.md).
/// Read-only and harmless: every reservation is PROT_NONE and given back at once, the
/// exec test maps 16 KB of anonymous memory, changes its protection and unmaps it, and
/// nothing is ever executed or touched.
private enum MadeiraExtensionProbeWork {
    static func run() -> MadeiraJITRequest.Response {
        let task = mach_task_self_
        let page = vm_size_t(vm_page_size)
        let none = vm_prot_t(0), rw = vm_prot_t(3), rwx = vm_prot_t(7)
        let inheritNone = vm_inherit_t(2)   // VM_INHERIT_NONE

        // vm_map: on arm64 the same 64-bit call as mach_vm_map, which iOS hides from Swift.
        func map(_ size: vm_size_t, at: vm_address_t?, maxProt: vm_prot_t) -> kern_return_t {
            var addr = at ?? 0
            let kr = vm_map(task, &addr, size, 0, at == nil ? VM_FLAGS_ANYWHERE : VM_FLAGS_FIXED,
                                 0, 0, 0, none, maxProt, inheritNone)
            if kr == KERN_SUCCESS { vm_deallocate(task, addr, size) }
            return kr
        }
        func gb(_ v: UInt64) -> String { String(format: "%.2fGB", Double(v) / 1_073_741_824) }
        func mb(_ v: UInt64) -> String { "\(v >> 20)MB" }
        func fixed(_ at: vm_address_t) -> String {
            let kr = map(page, at: at, maxProt: rw)
            return kr == KERN_SUCCESS ? "ok" : kr == KERN_NO_SPACE ? "occupied" : "refused(kr=\(kr))"
        }

        // The largest single VM_FLAGS_ANYWHERE reservation, by binary search in 16 MB
        // steps up to 1 TB.
        let step: vm_size_t = 16 << 20
        var lo: vm_size_t = 0, hi: vm_size_t = (1 << 40) / step + 1
        while hi - lo > 1 {
            let mid = (lo + hi) / 2
            if map(mid * step, at: nil, maxProt: rw) == KERN_SUCCESS { lo = mid } else { hi = mid }
        }
        let largest = UInt64(lo * step)
        let rwxKr = map(step, at: nil, maxProt: rwx)

        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let infoKr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(task, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        let vm = infoKr == KERN_SUCCESS
            ? "map=0x\(String(info.min_address, radix: 16))-0x\(String(info.max_address, radix: 16)) " +
              "footprint=\(mb(info.phys_footprint)) limit_remaining=\(mb(info.limit_bytes_remaining))"
            : "task_vm_info=unavailable(kr=\(infoKr))"

        var exec = "mmap-failed"
        let size = Int(page)
        if let p = mmap(nil, size, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0),
           p != UnsafeMutableRawPointer(bitPattern: -1) {
            exec = mprotect(p, size, PROT_READ | PROT_EXEC) == 0
                ? "ok" : "refused(\(String(cString: strerror(errno))))"
            munmap(p, size)
        }

        let message = "pid=\(getpid()) anywhere_max=\(gb(largest)) (16MB steps, PROT_NONE, max RW) " +
            "anywhere16MB_maxRWX=\(rwxKr == KERN_SUCCESS ? "ok" : "refused(kr=\(rwxKr))") " +
            "fixed@0x7000000000=\(fixed(0x70_0000_0000)) fixed@0x14c000000=\(fixed(0x1_4c00_0000)) " +
            "\(vm) available=\(mb(UInt64(os_proc_available_memory()))) mprotect_exec=\(exec)"
        NSLog("[MadeiraJIT] ext-probe: %@", message)
        return .init(success: true, message: message, txmPresent: nil)
    }
}
