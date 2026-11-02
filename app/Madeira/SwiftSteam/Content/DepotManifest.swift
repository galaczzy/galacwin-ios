// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright 2026 Jfishin, 125hz
// Madeira Converter Exception: see LICENSE-EXCEPTION.md
// GalacWin security modifications by galaczzy, 2026; see LICENSE-GALACWIN-EXCEPTION.md.
//
// Derived from Jfishin's Madeira Steam client, used in Madeira with the
// author's permission (see docs/STEAM_SIGNIN.md, "Provenance"). Adapted for
// the owned library and downloads (docs/STEAM_LIBRARY.md).

import Foundation

/// A parsed Steam depot manifest: the files of one depot and their chunks.
struct DepotManifest {
    /// EDepotFileFlag.CustomExecutable: a file Valve's client customizes per user before it runs.
    static let customExecutableFlag: UInt32 = 0x80
    // A malformed CDN response must not create implausibly large files or totals.
    // These limits are deliberately above normal individual game files/depots.
    static let maxFileSize: UInt64 = 1 << 40       // 1 TiB
    static let maxDepotSize: UInt64 = 8 << 40      // 8 TiB
    static let maxChunkSize: UInt32 = 64 << 20     // 64 MiB
    let depotID: UInt32
    let manifestGID: UInt64
    let creationTime: UInt32
    var totalUncompressedSize: UInt64
    var totalCompressedSize: UInt64
    var files: [FileEntry] = []

    struct FileEntry {
        let filename: String
        let size: UInt64
        let flags: UInt32
        var chunks: [ChunkEntry]

        var isDirectory: Bool { flags & 0x40 != 0 }
    }

    struct ChunkEntry {
        let sha: Data           // 20-byte SHA-1 hash (used as chunk ID)
        let crc: UInt32         // Adler-32 checksum of uncompressed data
        let offset: UInt64      // Offset within the file
        let compressedSize: UInt32
        let uncompressedSize: UInt32

        /// Hex string of SHA hash (used in CDN URLs)
        var shaHex: String {
            sha.map { String(format: "%02x", $0) }.joined()
        }
    }

    // MARK: - Parsing

    /// Parse a depot manifest from binary data. Modern CDN payloads have an
    /// 8-byte binary header before the ContentManifestPayload protobuf, and
    /// filenames may be base64(AES-CBC depot-key) — pass depotKey to decode them.
    static func parse(depotID: UInt32, manifestGID: UInt64, data: Data, depotKey: Data? = nil) throws -> DepotManifest {
        guard data.count >= 4 else {
            throw SteamError.manifestFetchFailed("Manifest data too small")
        }

        // SteamPipe's protobuf manifest has distinct payload, metadata and
        // signature sections. Validate their framing and bind the metadata to
        // the CM-selected depot/GID. The signature section can legitimately be
        // empty; this structural check is not a cryptographic authenticity proof.
        var cursor = 0
        func section(_ magic: UInt32) throws -> Data {
            guard data.count - cursor >= 8 else {
                throw SteamError.manifestFetchFailed("Manifest section is truncated")
            }
            let found = data[cursor..<(cursor + 4)].withUnsafeBytes { UInt32(littleEndian: $0.loadUnaligned(as: UInt32.self)) }
            let length = Int(data[(cursor + 4)..<(cursor + 8)].withUnsafeBytes { UInt32(littleEndian: $0.loadUnaligned(as: UInt32.self)) })
            cursor += 8
            guard found == magic, length <= data.count - cursor else {
                throw SteamError.manifestFetchFailed("Manifest section is invalid")
            }
            let bytes = Data(data[cursor..<(cursor + length)])
            cursor += length
            return bytes
        }
        let payload = try section(0x71F617D0)
        let metadata = try section(0x1F4812BE)
        _ = try section(0x1B81B817)
        guard data.count - cursor == 4,
              data[cursor..<(cursor + 4)].withUnsafeBytes({ UInt32(littleEndian: $0.loadUnaligned(as: UInt32.self)) }) == 0x32C415AB else {
            throw SteamError.manifestFetchFailed("Manifest end marker is invalid")
        }
        var metadataDecoder = ProtobufDecoder(metadata)
        var actualDepot: UInt32?
        var actualGID: UInt64?
        while let tag = try metadataDecoder.readTag() {
            switch tag.fieldNumber {
            case 1:
                guard actualDepot == nil, let value = UInt32(exactly: try metadataDecoder.readVarint()) else {
                    throw SteamError.manifestFetchFailed("Manifest depot metadata is invalid")
                }
                actualDepot = value
            case 2:
                guard actualGID == nil else { throw SteamError.manifestFetchFailed("Manifest GID is duplicated") }
                actualGID = try metadataDecoder.readVarint()
            default: try metadataDecoder.skip(wireType: tag.wireType)
            }
        }
        guard actualDepot == depotID, actualGID == manifestGID else {
            throw SteamError.manifestFetchFailed("Manifest identity does not match the request")
        }

        var manifest = DepotManifest(
            depotID: depotID,
            manifestGID: manifestGID,
            creationTime: 0,
            totalUncompressedSize: 0,
            totalCompressedSize: 0
        )

        try parseManifestPayload(data: Data(payload), manifest: &manifest, depotKey: depotKey)

        return manifest
    }

    /// Parse the manifest's serialized file list
    private static func parseManifestPayload(data: Data, manifest: inout DepotManifest, depotKey: Data?) throws {
        // The manifest is a protobuf message: ContentManifestPayload
        // Field 1 (repeated): ContentManifestPayload.FileMapping
        //   Field 1: filename (string)
        //   Field 2: size (uint64)
        //   Field 3: flags (uint32)
        //   Field 6 (repeated): ContentManifestPayload.FileMapping.ChunkData
        //     Field 1: sha (bytes, 20)
        //     Field 2: crc (fixed32)
        //     Field 3: offset (uint64)
        //     Field 4: cb_compressed (uint32)
        //     Field 5: cb_original (uint32)

        var decoder = ProtobufDecoder(data)
        var totalUncompressed: UInt64 = 0
        var totalCompressed: UInt64 = 0

        while let tag = try decoder.readTag() {
            switch tag.fieldNumber {
            case 1: // FileMapping
                let fileData = try decoder.readBytes()
                if let entry = try parseFileEntry(from: fileData, depotKey: depotKey) {
                    let (nextUncompressed, uncompressedOverflow) = totalUncompressed.addingReportingOverflow(entry.size)
                    guard !uncompressedOverflow, nextUncompressed <= maxDepotSize else {
                        throw SteamError.manifestFetchFailed("Manifest depot size exceeds limit")
                    }
                    totalUncompressed = nextUncompressed
                    for chunk in entry.chunks {
                        let (nextCompressed, compressedOverflow) = totalCompressed.addingReportingOverflow(UInt64(chunk.compressedSize))
                        guard !compressedOverflow, nextCompressed <= maxDepotSize else {
                            throw SteamError.manifestFetchFailed("Manifest compressed size exceeds limit")
                        }
                        totalCompressed = nextCompressed
                    }
                    manifest.files.append(entry)
                }
            default:
                try decoder.skip(wireType: tag.wireType)
            }
        }

        manifest.totalUncompressedSize = totalUncompressed
        manifest.totalCompressedSize = totalCompressed
    }

    /// Encrypted filenames are base64'd AES-256-CBC ciphertext (depot key,
    /// embedded IV). Base64 can legitimately contain '/', so don't guard on
    /// separators — attempt the decode and keep it only if the result is sane.
    private static func decryptFilename(_ name: String, depotKey: Data?) -> String {
        let stripped = name.filter { !$0.isWhitespace }
        func fail(_ why: String) -> String {
            SteamLog.trace("filename decrypt failed (\(why))")
            return name
        }
        guard let depotKey else { return fail("no key") }
        guard let cipher = Data(base64Encoded: stripped, options: .ignoreUnknownCharacters),
              cipher.count > 16 else { return fail("b64") }
        guard let plain = try? ContentDecryptor.decryptChunk(encryptedData: cipher, depotKey: depotKey) else { return fail("aes") }
        // Plaintext is NUL-padded after PKCS7 unpadding — strip trailing nulls
        var bytes = plain
        while bytes.last == 0 { bytes.removeLast() }
        guard let decoded = String(data: bytes, encoding: .utf8), !decoded.isEmpty else {
            return fail("utf8")
        }
        guard !decoded.unicodeScalars.contains(where: { $0.value < 0x20 || $0.value == 0x7F }) else { return fail("ctrl") }
        return decoded
    }

    private static func parseFileEntry(from data: Data, depotKey: Data?) throws -> FileEntry? {
        var decoder = ProtobufDecoder(data)
        var filename = ""
        var size: UInt64 = 0
        var flags: UInt32 = 0
        var chunks: [ChunkEntry] = []

        while let tag = try decoder.readTag() {
            switch tag.fieldNumber {
            case 1: filename = try decoder.readString()
            case 2: size = try decoder.readVarint()
            case 3:
                guard let value = UInt32(exactly: try decoder.readVarint()) else {
                    throw SteamError.manifestFetchFailed("Manifest file flags exceed UInt32")
                }
                flags = value
            case 6: // ChunkData
                let chunkData = try decoder.readBytes()
                if let chunk = try parseChunkEntry(from: chunkData) {
                    chunks.append(chunk)
                }
            default: try decoder.skip(wireType: tag.wireType)
            }
        }

        guard !filename.isEmpty else { return nil }
        guard size <= maxFileSize, size <= UInt64(Int64.max) else {
            throw SteamError.manifestFetchFailed("Manifest file size exceeds limit")
        }
        for chunk in chunks {
            guard chunk.offset <= size,
                  UInt64(chunk.uncompressedSize) <= size - chunk.offset else {
                throw SteamError.manifestFetchFailed("Manifest chunk exceeds its file")
            }
        }
        if flags & 0x40 == 0 && flags & 0x200 == 0 && size > 0 {
            var end: UInt64 = 0
            for chunk in chunks.sorted(by: { $0.offset < $1.offset }) {
                guard chunk.offset == end else {
                    throw SteamError.manifestFetchFailed("Manifest file has a missing or overlapping chunk")
                }
                end += UInt64(chunk.uncompressedSize)
            }
            guard end == size else { throw SteamError.manifestFetchFailed("Manifest file is incomplete") }
        }

        let decoded = decryptFilename(filename, depotKey: depotKey)
        // Normalize path separators (Steam uses backslashes)
        let normalizedFilename = decoded.replacingOccurrences(of: "\\", with: "/")

        return FileEntry(filename: normalizedFilename, size: size, flags: flags, chunks: chunks)
    }

    private static func parseChunkEntry(from data: Data) throws -> ChunkEntry? {
        var decoder = ProtobufDecoder(data)
        var sha = Data()
        var crc: UInt32 = 0
        var offset: UInt64 = 0
        var compressedSize: UInt32 = 0
        var uncompressedSize: UInt32 = 0

        while let tag = try decoder.readTag() {
            switch tag.fieldNumber {
            case 1: sha = try decoder.readBytes()
            case 2: crc = try decoder.readFixed32()
            case 3: offset = try decoder.readVarint()
            case 4:
                guard let value = UInt32(exactly: try decoder.readVarint()) else {
                    throw SteamError.manifestFetchFailed("Manifest chunk size exceeds UInt32")
                }
                uncompressedSize = value // cb_original
            case 5:
                guard let value = UInt32(exactly: try decoder.readVarint()) else {
                    throw SteamError.manifestFetchFailed("Manifest chunk size exceeds UInt32")
                }
                compressedSize = value // cb_compressed
            default: try decoder.skip(wireType: tag.wireType)
            }
        }

        guard !sha.isEmpty else { return nil }
        guard sha.count == 20,
              compressedSize > 0, compressedSize <= maxChunkSize,
              uncompressedSize > 0, uncompressedSize <= maxChunkSize else {
            throw SteamError.manifestFetchFailed("Manifest chunk metadata is invalid")
        }

        return ChunkEntry(
            sha: sha,
            crc: crc,
            offset: offset,
            compressedSize: compressedSize,
            uncompressedSize: uncompressedSize
        )
    }
}
