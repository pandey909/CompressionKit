# CompressionKit

A modern, high-performance video compression engine for iOS, written in Swift. It utilizes `AVAssetReader` and `AVAssetWriter` for precise target-size compression, frame rate decimation, pixel-baked display orientation preservation, and custom bitrate bounds.

---

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 6.0+

---

## Version

Current version: 1.1.0

Swift Package Manager versions are published through Git tags. Create the release tag later after review:

```bash
git tag 1.1.0
git push origin 1.1.0
```

---

## Installation

Add this package to your project using Swift Package Manager:

1. In Xcode, select **File > Add Package Dependencies...**
2. Enter the repository URL: `https://github.com/your-org/compression-kit.git`

---

## Usage

### 1. Basic Compression

Compress a local video file synchronously using async/await:

```swift
import CompressionKit

let compressor = VideoCompressor()

do {
    let result = try await compressor.compress(
        inputURL: localFileURL,
        mode: .socialOptimized
    )
    print("Compressed output written to: \(result.outputURL)")
} catch {
    print("Compression failed: \(error)")
}
```

### 2. Compression with Progress Updates

Listen to progressive updates (preparing, encoding percentage, finalizing, completed, etc.):

```swift
import CompressionKit

let compressor = VideoCompressor()

do {
    let stream = compressor.compressWithProgress(
        inputURL: localFileURL,
        mode: .socialOptimized
    )
    
    for try await progress in stream {
        switch progress {
        case .preparing:
            print("Preparing video assets...")
        case .readingMetadata:
            print("Reading video dimensions and orientation...")
        case .calculatingSettings:
            print("Calculating optimal target bitrates...")
        case .encoding(let percentage, let elapsedTime, let estimatedRemainingTime):
            let pct = Int(percentage * 100)
            let remaining = estimatedRemainingTime.map { String(format: "%.1fs", $0) } ?? "calculating"
            print("Progress: \(pct)% - Elapsed: \(String(format: "%.1fs", elapsedTime)) - Remaining: \(remaining)")
        case .finalizing:
            print("Finalizing output container...")
        case .validating:
            print("Validating output quality guardrails...")
        case .completed(let result):
            print("Compression completed! Saved \(String(format: "%.1f%%", result.savedPercentage * 100.0))")
            print("Output file size: \(result.compressedSizeBytes) bytes")
        }
    }
} catch {
    print("Compression stream failed: \(error)")
}
```

### 3. Photos Original Video Import Helper

Import original resources directly from the user's Photos library. This bypasses compatible transcode exports and accesses original HEVC/Dolby Vision files:

```swift
import PhotosUI
import CompressionKit

let importer = PhotosVideoImporter()

do {
    // Via itemIdentifier
    let originalURL = try await importer.importOriginalVideo(from: item.itemIdentifier!) { status in
        print("Status: \(status)") // e.g. "Downloading from iCloud... 45%"
    }
    print("Original file copied to sandbox: \(originalURL)")
} catch {
    print("Photos import failed: \(error)")
}
```

---

## Info.plist Permissions

If using the Photos library import/save helpers, add the following keys to your app's `Info.plist`:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>Select videos from your photo library for compression.</string>

<key>NSPhotoLibraryAddUsageDescription</key>
<string>Save compressed videos to your photo library.</string>
```

---

## Package Structure

- `Public`: app-facing compressor entry point.
- `Compression`: reader/writer engine, modes, settings, bitrate calculation, geometry, progress, and validation.
- `Metadata`: video metadata reader and display geometry facts.
- `Photos`: original Photos resource import and Photos picker transferable support.
- `Files`: sandbox file naming and cleanup helpers.
- `Errors`: user-facing and technical compression errors.
- `Logging`: OSLog-backed package logging and app logger bridge.
- `Tests`: unit tests for deterministic compression logic plus optional manual diagnostics.

---

## Compression Modes

- `.highQuality`: Preserves maximum visual clarity (e.g. 4K HEVC for 4K inputs, or 1080p).
- `.balanced`: Good trade-off between quality and file size (e.g. 1080p HEVC at 60 FPS).
- `.socialOptimized`: Targets a `40–60 MB` file size cap for large files. Decimates high frame rates (e.g. 120 FPS to 30 FPS) and scales to `720x1280` portrait. Bakes orientation directly into the pixels.
- `.smallerSize`: Higher compression at `720p 30 FPS` HEVC.
- `.extremeWatchable`: Lower bitrate preset (`540p 30 FPS`), keeping files small but usable.
- `.customTargetSizeMB(Double)`: Compress video aiming for a specific target size in Megabytes.

---

## Orientation Handling

Photos and camera videos often store portrait orientation as track transform metadata instead of physically rotated pixels. The compressor reads the source transform, computes display geometry, and bakes the final orientation into the output frames. This keeps portrait videos upright in social upload pipelines that may ignore transform metadata.

---

## Custom Logging Integration

Inject a custom logger to bridge the package events to your own live log console:

```swift
import CompressionKit

struct CustomLogger: VideoCompressionLogging {
    func log(_ event: CompressionLogEvent) {
        print("[\(event.level.rawValue.uppercased())] \(event.message)")
    }
}

let compressor = VideoCompressor(
    configuration: .init(logger: CustomLogger())
)
```

---

## Error Handling

All errors throw `VideoCompressionError`, which exposes localized user-friendly messages, technical messages, and recovery suggestions:

```swift
do {
    let result = try await compressor.compress(inputURL: url, mode: .balanced)
} catch let error as VideoCompressionError {
    print("User message: \(error.userMessage)")
    print("Technical details: \(error.technicalMessage)")
    print("Fix suggestion: \(error.recoverySuggestion)")
} catch {
    print("Standard error: \(error)")
}
```

---

## Notes about Quality

* **Lossy Compression**: The package uses standard, high-efficiency lossy compression (H.264 & HEVC hardware encoders). It does not claim lossless compression.
* **Social Optimized**: Specifically optimized for fast uploads to social networks (like Instagram, TikTok, and YouTube) by scaling to standard mobile player resolutions and target frame rates (30 FPS), reducing network bandwidth without visible compression artifacts.

---

## Known Limitations

- Compression is lossy by design.
- 4K high-FPS HDR portrait sources are compute-heavy because decode, transform, scale, and color conversion happen per frame.
- `.socialOptimized` favors upload-safe output size and orientation correctness over maximum encoder speed.
- Manual end-to-end video diagnostics require a local fixture path through `COMPRESSION_KIT_DIAGNOSTIC_VIDEO`.

---

## Testing

Run normal package checks:

```bash
swift build
swift test
```

Run the optional manual compression diagnostic:

```bash
COMPRESSION_KIT_DIAGNOSTIC_VIDEO=/path/to/video.mov swift test
```

Normal tests do not depend on local absolute paths.

---

## Why This Is a Swift Package

One `VideoCompressor.swift` file is fine for basic `AVAssetExportSession` preset export. Production video compression has more responsibilities: importing the original Photos resource, reading metadata, calculating target-size bitrates, baking portrait orientation into pixels, handling audio, reporting progress, validating output quality, and exposing reliable errors.

Keeping this logic in a Swift Package keeps the app code smaller, makes compression reusable across apps, and lets the core bitrate, geometry, encoder settings, and validation logic be tested outside the UI.

---

## Performance Note

For 4K high-FPS HDR portrait videos, most processing time is spent in `AVAssetReaderVideoCompositionOutput.copyNextSampleBuffer()`. That step performs video decode, orientation transform, scaling, HDR-to-SDR conversion, and pixel buffer generation. It should not be bypassed for portrait videos unless a separate fast mode proves orientation and upload compatibility remain correct.

---

## Release Notes

### 1.1.0

- Optimized image compression pipeline.
- Introduced dynamic worker pool with clamped parallel tasks to limit memory overhead.
- Cached pre-rendered images to avoid redundant resizing for quality attempts.
- Derived thumbnail directly from successful pre-rendered main image.
- Encapsulated JPEG encoding attempts in autoreleasepools.

### 1.0.0

- Initial stable release.
- Social optimized video compression.
- Original Photos asset import support.
- Orientation-safe video processing.
- Target-size bitrate calculation.
- Metadata reading.
- Progress stream.
- Quality validation.
- Production logging and errors.
