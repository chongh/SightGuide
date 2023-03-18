//
//  GlanceViewController.swift
//  SightGuide
//
//  Created by FindTheLamp on 2023/3/18.
//

import UIKit
import AVFoundation

private let CellReuseID = "GlanceCell"

final class GlanceViewController: UIViewController {
    
    // Init
    
    init() {
        super.init(nibName: "GlanceViewController", bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // View controller
    
    // views
    @IBOutlet weak var collectionView: UICollectionView!
    
    // audio
    private var fixedPromptAudioPlayer: AVAudioPlayer?
    private let synthesizer = AVSpeechSynthesizer()
    
    // data
    private var scene: Scene?
    private var currentItemIndex = 0
    private var selectedItemIndex: Int? = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupViewController()
        setupAudioPlayer()
        setupSwipeGesture()
        setupDoubleTapGesture()
        
        parseSceneFromJSON()
        collectionView?.reloadData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        playFixedPrompt()
    }
    
    // Setup
    
    private func setupViewController() {
        collectionView.register(
            UINib(
                nibName: "GlanceCollectionViewCell",
                bundle: nil),
            forCellWithReuseIdentifier: CellReuseID)
    }
    
    private func setupSwipeGesture() {
        let swipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(threeFingerSwipeDown))
        swipeGesture.direction = .down
        swipeGesture.numberOfTouchesRequired = 3
        view.addGestureRecognizer(swipeGesture)
        
        let swipeUpGesture = UISwipeGestureRecognizer(target: self, action: #selector(swipeGestureHandler(_:)))
        swipeUpGesture.direction = .up
        view.addGestureRecognizer(swipeUpGesture)
        
        let swipeDownGesture = UISwipeGestureRecognizer(target: self, action: #selector(swipeGestureHandler(_:)))
        swipeDownGesture.direction = .down
        view.addGestureRecognizer(swipeDownGesture)
    }
    
    private func setupDoubleTapGesture() {
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(doubleTapWithTwoFingers))
        doubleTapGesture.numberOfTapsRequired = 2
        doubleTapGesture.numberOfTouchesRequired = 2
        view.addGestureRecognizer(doubleTapGesture)
    }
    
    private func setupAudioPlayer() {
        if let audioPath = Bundle.main.path(forResource: "glance_fixed_prompt", ofType: "m4a") {
            do {
                fixedPromptAudioPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: audioPath))
                fixedPromptAudioPlayer?.delegate = self
            } catch {
                print("Error initializing audio player: \(error)")
            }
        }
        
        synthesizer.delegate = self
    }
    
    // Data
    
    func parseSceneFromJSON() {
        if let url = Bundle.main.url(forResource: "glance_mock", withExtension: "json") {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                scene = try decoder.decode(Scene.self, from: data)
            } catch {
                print("Error parsing JSON: \(error)")
            }
        }
    }
    
    // Audio
    
    func playFixedPrompt() {
        fixedPromptAudioPlayer?.play()
    }
    
    func readCurrentSceneItem() {
        if currentItemIndex >= scene?.objs.count ?? 0 {
            return
        }
        
        collectionView.layoutIfNeeded()
        collectionView.scrollToItem(
            at: IndexPath(item: currentItemIndex, section: 0),
            at: .centeredHorizontally,
            animated: true)
        selectedItemIndex = nil
        
        guard let item = scene?.objs[currentItemIndex] else { return }
        readText(text: item.text)
    }
    
    private func readText(text: String) {
        let speechUtterance = AVSpeechUtterance(string: text)
        speechUtterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        synthesizer.speak(speechUtterance)
    }
    
    // Actions
    
    @objc func threeFingerSwipeDown() {
        let fixationViewController = FixationViewController()
        fixationViewController.modalPresentationStyle = .fullScreen
        present(fixationViewController, animated: true, completion: nil)
    }
    
    @objc func doubleTapWithTwoFingers() {
        if synthesizer.isSpeaking {
            synthesizer.pauseSpeaking(at: .immediate)
        } else {
            synthesizer.continueSpeaking()
        }
        
        guard let audioPlayer = fixedPromptAudioPlayer else { return }
        if audioPlayer.isPlaying {
            audioPlayer.pause()
        } else if audioPlayer.currentTime < audioPlayer.duration {
            audioPlayer.play()
        }
    }
    
    @objc func swipeGestureHandler(_ sender: UISwipeGestureRecognizer) {
        guard
            let selectedItemIndex = selectedItemIndex,
            let item = scene?.objs[selectedItemIndex]
        else {
            // no item selected
            return
        }
        
        if sender.direction == .up {
            showToast(message: "\(item.objName) 已标记为喜欢")
        } else if sender.direction == .down {
            showToast(message: "\(item.objName) 已标记为不感兴趣")
        }
    }
}

extension GlanceViewController: UICollectionViewDataSource
{
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return scene?.objs.count ?? 0;
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CellReuseID, for: indexPath) as! GlanceCollectionViewCell
        if let sceneItem = scene?.objs[indexPath.item] {
            cell.renderSceneItem(item: sceneItem)
            cell.doubleTapAction = { [weak self] in
                self?.selectedItemIndex = indexPath.item
            }
        }
        return cell
    }
    
    
}

extension GlanceViewController: UICollectionViewDelegateFlowLayout
{
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return collectionView.bounds.size
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
}

extension GlanceViewController: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            // fixed prompt finished playing
            readCurrentSceneItem()
        }
    }
}

extension GlanceViewController: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.currentItemIndex += 1
            self.readCurrentSceneItem()
        }
    }
}
