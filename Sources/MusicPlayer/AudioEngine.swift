import Foundation
import AVFoundation

final class AudioEngine: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    var onPlaybackFinished: (() -> Void)?
    
    var isPlaying: Bool {
        player?.isPlaying ?? false
    }
    
    var currentTime: TimeInterval {
        get { player?.currentTime ?? 0 }
        set { player?.currentTime = newValue }
    }
    
    var duration: TimeInterval {
        player?.duration ?? 0
    }
    
    func load(url: URL) throws {
        player?.stop()
        player = try AVAudioPlayer(contentsOf: url)
        player?.delegate = self
        player?.prepareToPlay()
    }
    
    func play() {
        player?.play()
    }
    
    func pause() {
        player?.pause()
    }
    
    func stop() {
        player?.stop()
        player = nil
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully _: Bool) {
        onPlaybackFinished?()
    }
}
