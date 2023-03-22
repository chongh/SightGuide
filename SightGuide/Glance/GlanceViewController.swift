//
//  GlanceViewController.swift
//  SightGuide
//
//  Created by FindTheLamp on 2023/3/18.
//

import AVFoundation
import UIKit

private let CellReuseID = "GlanceCell"

final class GlanceViewController: UIViewController {
    
    // MARK: - Init
    
    // views
    @IBOutlet weak var blockView: UIView!
    @IBOutlet weak var collectionView: UICollectionView!
    
    // audio
    private var fixedPromptAudioPlayer: AVAudioPlayer?
    private let synthesizer = AVSpeechSynthesizer()
    
    // data
    private var scene: Scene?
    private var seenObjs: Set<Int> = []
    private var currentItemIndex = -1
    private var selectedItemIndex: Int? = nil
    
    // timer
    private var timer: Timer?
    
    init() {
        super.init(nibName: "GlanceViewController", bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View controller
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupViewController()
        setupAudioPlayer()
        setupSwipeGesture()
        setupDoubleTapGesture()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        playFixedPrompt()
        
        requestScene()
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        fixedPromptAudioPlayer?.pause()
        synthesizer.pauseSpeaking(at: .immediate)
    }
    
    func refreshViews() {
        collectionView?.reloadData()
    }
    
    // MARK: - Setup
    
    private func setupViewController() {
        collectionView.register(
            UINib(
                nibName: "GlanceCollectionViewCell",
                bundle: nil),
            forCellWithReuseIdentifier: CellReuseID)
    }
    
    private func setupSwipeGesture() {
        let swipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(threeFingerSwipeDownGestureHandler))
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
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(doubleTapWithTwoFingersGestureHandler))
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
    
    // MARK: - Data
    
    func requestScene() {
        NetworkRequester.getScene { result in
            switch result {
            case .success(let sceneResponse):
                var newScene = sceneResponse

                // remove objs with duplicate ID
                newScene.objs = newScene.objs?.filter({ obj in
                    !self.seenObjs.contains(obj.objId)
                })
                
                for obj in newScene.objs ?? [] {
                    self.seenObjs.insert(obj.objId)
                }

                self.updateScene(newScene)
            case .failure(let error):
                print("Error: \(error)")
            }
        }
    }
    
    private func updateScene(_ scene: Scene) {
        selectedItemIndex = nil
        self.scene = scene
        
        self.refreshViews()
        
        if
            let objs = scene.objs,
            objs.count > 0
        {
            if synthesizer.isSpeaking {
                currentItemIndex = -1
                // read item after finish current reading
            } else {
                currentItemIndex = 0
                readCurrentSceneItem()
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                self.requestScene()
            }
        }
    }
    
    // MARK: - Audio
    
    func playFixedPrompt() {
        //        fixedPromptAudioPlayer?.play()
        readText(text: "单指双击物体，上滑为标记喜欢，下滑为不感兴趣")
    }
    
    func readCurrentSceneItem() {
        if currentItemIndex >= scene?.objs?.count ?? 0 {
            requestScene()
            return
        }
        
        collectionView.layoutIfNeeded()
        collectionView.scrollToItem(
            at: IndexPath(item: currentItemIndex, section: 0),
            at: .centeredHorizontally,
            animated: true)
        selectedItemIndex = nil
        
        guard let item = scene?.objs?[currentItemIndex] else { return }
        readText(text: item.text)
    }
    
    private func readText(text: String) {
        let speechUtterance = AVSpeechUtterance(string: text)
        speechUtterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
//        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.speak(speechUtterance)
    }
    
    // MARK: - Actions
    
    @objc func threeFingerSwipeDownGestureHandler() {
        let fixationViewController = FixationViewController()
        fixationViewController.modalPresentationStyle = .fullScreen
        fixationViewController.fromScene = scene
        present(fixationViewController, animated: true, completion: nil)
    }
    
    @objc func doubleTapWithTwoFingersGestureHandler() {
        if synthesizer.isSpeaking {
            synthesizer.pauseSpeaking(at: .immediate)
        } else {
            synthesizer.continueSpeaking()
        }
        
//        guard let audioPlayer = fixedPromptAudioPlayer else { return }
//        if audioPlayer.isPlaying {
//            audioPlayer.pause()
//        } else if audioPlayer.currentTime < audioPlayer.duration {
//            audioPlayer.play()
//        }
    }
    
    @objc func swipeGestureHandler(_ sender: UISwipeGestureRecognizer) {
        guard
            let selectedItemIndex = selectedItemIndex,
            selectedItemIndex < scene?.objs?.count ?? 0,
            let item = scene?.objs?[selectedItemIndex]
        else {
            // no item selected
            return
        }
        
        if sender.direction == .up {
            timer?.invalidate()
            readText(text: "您已标记喜欢")
//            showToast(message: "\(item.objName) 已标记为喜欢")
            NetworkRequester.postLikeGlanceItem(
                objId: item.objId,
                like: 1, completion: { _ in
                    
                })
        } else if sender.direction == .down {
            timer?.invalidate()
            readText(text: "您已选择不感兴趣")
//            showToast(message: "\(item.objName) 已标记为不感兴趣")
            NetworkRequester.postLikeGlanceItem(
                objId: item.objId,
                like: 1, completion: { _ in
                    
                })
        }
    }
}

extension GlanceViewController: UICollectionViewDataSource
{
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return scene?.objs?.count ?? 0;
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CellReuseID, for: indexPath) as! GlanceCollectionViewCell
        if let sceneItem = scene?.objs?[indexPath.item] {
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
        blockView.isHidden = true
        
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { _ in
            self.currentItemIndex += 1
            self.readCurrentSceneItem()
        }
    }
}
