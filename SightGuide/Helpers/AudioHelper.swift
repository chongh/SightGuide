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
            
            let audioFileURL = audioFileURL(sceneID: sceneID, objectID: objectID)
            
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
    
    static func isRecording() -> Bool {
        audioRecorder?.isRecording ?? false
    }
    
    static func endRecording() {
        guard let recorder = audioRecorder else { return }
        recorder.stop()
    }
    
    static func playRecording(sceneID: String, objectID: Int) {
        let audioFileURL = audioFileURL(sceneID: sceneID, objectID: objectID)
        playFile(url: audioFileURL)
    }
    
    static func playFile(url: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            print("Error playing audio: \(error.localizedDescription)")
        }
    }
    
    static func audioFileURL(sceneID: String, objectID: Int) -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory.appendingPathComponent("scene_\(sceneID)_obj_\(objectID).m4a")
    }
    
    static func convertDataToM4A(
        inputData: Data,
        recordName: String,
        outputURL: URL,
        completion: @escaping (Bool) -> Void)
    {
        guard let tempFileURL = createTempFileFromData(
            inputData: inputData,
            recordName: recordName) else
        {
            completion(false)
            return
        }
        
        let asset = AVAsset(url: tempFileURL)
        let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A)
        
        guard let exportSessionUnwrapped = exportSession else {
            completion(false)
            return
        }
        
        exportSessionUnwrapped.outputFileType = .m4a
        exportSessionUnwrapped.outputURL = outputURL
        
        exportSessionUnwrapped.exportAsynchronously {
            switch exportSessionUnwrapped.status {
            case .completed:
                completion(true)
            case .failed, .cancelled:
                completion(false)
            default:
                break
            }
        }
    }
    
    static func createTempFileFromData(inputData: Data, recordName: String) -> URL? {
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileName = recordName + ".m4a"
        let tempFileURL = tempDirectory.appendingPathComponent(fileName)
        
        do {
            try inputData.write(to: tempFileURL)
            return tempFileURL
        } catch {
            print("Error writing data to temp file: \(error)")
            return nil
        }
    }
}
