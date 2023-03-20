//
//  AudioRecorder.swift
//  SightGuide
//
//  Created by FindTheLamp on 2023/3/20.
//

import AVFoundation
import Foundation

final class AudioHelper {
    
    static var audioRecorder: AVAudioRecorder?
    static var audioPlayer: AVAudioPlayer?
    
    static func startRecording(sceneID: String, objectID: Int) {
        let recordingSession = AVAudioSession.sharedInstance()
        do {
            try recordingSession.setCategory(.playAndRecord, mode: .default)
            try recordingSession.setActive(true)
            
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let audioFileURL = documentsDirectory.appendingPathComponent("scene_\(sceneID)_obj_\(objectID).m4a")
            print(audioFileURL)
            
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 2,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: audioFileURL, settings: settings)
//            audioRecorder?.delegate = self
            audioRecorder?.prepareToRecord()
            audioRecorder?.record()
        } catch {
            print("Failed to start recording: \(error.localizedDescription)")
        }
    }
    
    static func endRecording() {
        guard let recorder = audioRecorder else { return }
        recorder.stop()
    }
    
    static func playRecording(sceneID: String, objectID: Int) {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFileURL = documentsDirectory.appendingPathComponent("scene_\(sceneID)_obj_\(objectID).m4a")
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioFileURL)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            print("Error playing audio: \(error.localizedDescription)")
        }
    }
}
