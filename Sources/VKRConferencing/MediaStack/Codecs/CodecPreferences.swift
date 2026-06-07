import Foundation

/// Codec choices for the test bench — match §1.9 of the thesis verbatim.
///
///   • Opus for audio. Mandatory in WebRTC. ~2.5 ms encoder latency, built-in
///     PLC. Bitrate range 6–510 kbps.
///   • H.264 for video. Universal hardware acceleration on iOS, predictable
///     latency, available on every device we tested in §4.2.
///
/// VP8 / VP9 / AV1 are listed only as fallbacks — the thesis dataset is
/// collected with H.264 to ensure parity with the Android counterpart, where
/// H.264 hardware-encode is on every device since Android 7.
enum AudioCodec: String { case opus, g722 }
enum VideoCodec: String { case h264, vp8, vp9, av1 }

struct CodecPreferences {
    let audio: AudioCodec
    let video: VideoCodec

    static let `default` = CodecPreferences(audio: .opus, video: .h264)
}
