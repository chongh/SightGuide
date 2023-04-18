//
//  GlanceViewController.swift
//  SightGuide
//
//  Created by FindTheLamp on 2023/3/18.
//

import AVFoundation
import UIKit
import CoreLocation
import os

private let CellReuseID = "GlanceCell"

final class GlanceViewController: UIViewController {
    
    // MARK: - Init
    
    // views
    @IBOutlet weak var blockView: UIView!
    @IBOutlet weak var collectionView: UICollectionView!
    
    // audio
    private var fixedPromptAudioPlayer: AVAudioPlayer?
    private let synthesizer = AVSpeechSynthesizer()
    private var isFirst = true
    private var voiceDelayTime: Double? = nil
    
    // data
    private var scene: Scene?
    private var seenObjs: Set<Int> = []
    private var currentItemIndex = -1
    private var selectedItemIndex: Int? = nil
    private var like = 0
    
    // gesture
    private var pressStartLocation: CGPoint? = nil
    private var pressStartTime: TimeInterval?
    private var isLongPress = false
    
    // timer
    private var timer: Timer?
    private var refreshTimer : Timer?
    
    // motion
    let locationManager = CLLocationManager()
    private var currentAngle: Double = 0
    private var initAngle: Double = 0
    
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
//        setupPressGesture()
        setupSwipeGesture()
        setupDoubleTapGesture()
        setupLocationManager()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if isFirst{
            playFixedPrompt()
        }
        
        requestScene()
        let action = "INPUT Glance Enter"
        LogHelper.log.info(action)

    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        fixedPromptAudioPlayer?.pause()
        synthesizer.pauseSpeaking(at: .immediate)
        timer?.invalidate()
        refreshTimer?.invalidate()
        locationManager.stopUpdatingHeading()
        locationManager.stopUpdatingLocation()
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
//        let clickGesture = UITapGestureRecognizer(target: self, action: #selector(clickGestureHandler))
//        clickGesture.numberOfTapsRequired = 1
//        view.addGestureRecognizer(clickGesture)
        
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(doubleTapWithTwoFingersGestureHandler))
        doubleTapGesture.numberOfTapsRequired = 2
        doubleTapGesture.numberOfTouchesRequired = 2
        view.addGestureRecognizer(doubleTapGesture)
    }
    
//    private func setupPressGesture() {
//        let longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(longPressGestureHandler))
//        longPressGestureRecognizer.numberOfTouchesRequired = 1
//        longPressGestureRecognizer.minimumPressDuration = 0.5
//        longPressGestureRecognizer.cancelsTouchesInView = false
//        view.addGestureRecognizer(longPressGestureRecognizer)
//    }
    
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
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.requestAlwaysAuthorization()
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.startUpdatingHeading()
        locationManager.startUpdatingLocation()
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
        initAngle = currentAngle
        selectedItemIndex = nil
        self.scene = scene
        
        self.refreshViews()
        refreshTimer?.invalidate()
        if
            let objs = scene.objs,
            objs.count > 0
        {
            if synthesizer.isSpeaking {
                currentItemIndex = -1
                print("is speaking")
                // read item after finish current reading
            } else {
                currentItemIndex = 0
                readCurrentSceneItem()
            }
        } else {
//            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
//                self.requestScene()
//            }
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                self.requestScene()
            }
        }
    }
    
    // MARK: - Audio
    
    func playFixedPrompt() {
        //        fixedPromptAudioPlayer?.play()
        isFirst = false
        self.voiceDelayTime = 1
        readText(text: "单指长按物体，上滑为标记喜欢，下滑为不感兴趣")
    }
    
    func readCurrentSceneItem() {
        if currentItemIndex >= 1,
        like == 0
        {
            self.selectedItemIndex = currentItemIndex - 1
            guard
                let selectedItemIndex = selectedItemIndex,
                selectedItemIndex < scene?.objs?.count ?? 0,
                let item = scene?.objs?[selectedItemIndex]
            else {
                // no item selected
                return
            }
            NetworkRequester.postLikeGlanceItem(
                objId: item.objId,
                like: 0,
                sceneId: scene?.sceneId, completion: { _ in
                    
                })
        }
        
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
        like = 0
        
        if currentItemIndex == 0 {
            readText(text: "新场景开始")
        }
        
        guard let item = scene?.objs?[currentItemIndex] else { return }
//        readText(text: item.text)
        if let angles = item.angles,
           angles.count > 1 {
            var positions: [String] = []
            for angle in angles{
                let position = getPosition(angle1: angle, angle2: currentAngle, angle3: initAngle)
                if !positions.contains(position) {
                    positions.append(position)
                }
            }
            if positions.count > 1 {
                var objText = positions.joined(separator: ",")
                var surroundCount = 0
                if objText.contains("前") {
                    surroundCount += 1
                }
                if objText.contains("后") {
                    surroundCount += 1
                }
                if objText.contains("左") {
                    surroundCount += 1
                }
                if objText.contains("右") {
                    surroundCount += 1
                }
                if positions.count > 2,
                   surroundCount > 2 {
                    objText = "周围有"
                    let name = item.processedName ?? item.objName
                    objText += name.split(separator: "_")[0]
                    readText(text: objText)
                } else {
                    objText += "都有"
                    let name = item.processedName ?? item.objName
                    objText += name.split(separator: "_")[0]
                    readText(text: objText)
                }

            } else {
                var objText = positions.joined(separator: ",")
                objText += "有"
                objText += item.processedName ?? item.objName
                readText(text: objText)
            }
            
        } else {
            var objText = getPosition(angle1: item.angle, angle2: currentAngle, angle3: initAngle)
            objText += "有"
            objText += item.processedName ?? item.objName
            readText(text: objText)
        }
        
        if LogHelper.params?.glanceType == 2{
            requestScene()
        }
    }

    private func readText(text: String) {
        let speechUtterance = AVSpeechUtterance(string: text)
        speechUtterance.rate = 0.7
        speechUtterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
//        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.speak(speechUtterance)
        var action = "OUTPUT Glance ReadText "
        action += text
        LogHelper.log.info(action)
    }
    
    private func getPosition(angle1: Double, angle2: Double, angle3: Double) -> String {
        var deltaAngle = angle2 - angle3
        if deltaAngle < -180 {
            deltaAngle = deltaAngle + 360
        } else if deltaAngle > 180 {
            deltaAngle = deltaAngle - 360
        }
        
        var objAngle = angle1 - deltaAngle
        if objAngle < -180 {
            objAngle = objAngle + 360
        } else if objAngle > 180 {
            objAngle = objAngle - 360
        }
        
        if objAngle < -157.5 {
            return "后方"
        } else if objAngle < -112.5 {
            return "左后方"
        } else if objAngle < -67.5 {
            return "左边"
        } else if objAngle < -22.5 {
            return "左前方"
        } else if objAngle < 22.5 {
            return "前方"
        } else if objAngle < 67.5 {
            return "右前方"
        } else if objAngle < 112.5 {
            return "右边"
        } else if objAngle < 157.5 {
            return "右后方"
        } else {
            return "后方"
        }
    }
    
    // MARK: - Actions
    
    @objc func threeFingerSwipeDownGestureHandler() {
        LogHelper.log.verbose("Glance Gesture ThreeFingerSwipe")
        
        let fixationViewController = FixationViewController()
        fixationViewController.modalPresentationStyle = .fullScreen
        fixationViewController.fromScene = scene
        timer?.invalidate()
        refreshTimer?.invalidate()
        present(fixationViewController, animated: true, completion: nil)
        let action = "INPUT Fixation Enter"
        LogHelper.log.info(action)
    }
    
//    @objc func clickGestureHandler() {
//        if self.currentItemIndex >= 0 {
//            self.selectedItemIndex = self.currentItemIndex
//        }
//    }

//    @objc func longPressGestureHandler(_ sender: UILongPressGestureRecognizer) {
//        let currentLocation = sender.location(in: view)
//        if sender.state == .began {
//            pressStartLocation = currentLocation
//            pressStartTime = Date().timeIntervalSince1970
//            isLongPress = true
//        }
//        else if sender.state == .ended {
//            if isLongPress{
//                selectedItemIndex = currentItemIndex
//                guard
//                    let selectedItemIndex = selectedItemIndex,
//                    selectedItemIndex < scene?.objs?.count ?? 0,
//                    let item = scene?.objs?[selectedItemIndex],
//                    let y = pressStartLocation?.y
//                else {
//                    // no item selected
//                    return
//                }
//                if currentLocation.y - y > 100 {
//                    // down
//                    timer?.invalidate()
//                    self.voiceDelayTime = 1
//                    readText(text: "您已选择不感兴趣")
//                    like = -1
//        //            showToast(message: "\(item.objName) 已标记为不感兴趣")
//                    NetworkRequester.postLikeGlanceItem(
//                        objId: item.objId,
//                        like: 1, completion: { _ in
//
//                        })
//                }
//                else if currentLocation.y - y < -100
//                {
//                    // up
//                    timer?.invalidate()
//                    self.voiceDelayTime = 1
//                    readText(text: "您已标记喜欢")
//                    like = 1
//        //            showToast(message: "\(item.objName) 已标记为喜欢")
//                    NetworkRequester.postLikeGlanceItem(
//                        objId: item.objId,
//                        like: 1, completion: { _ in
//
//                        })
//                }
//            }
//            pressStartTime = nil
//            pressStartLocation = nil
//            isLongPress = false
//            selectedItemIndex = nil
//        }
//    }
    
    @objc func doubleTapWithTwoFingersGestureHandler() {
        LogHelper.log.verbose("Glance Gesture TwoFingersDoubleTap")
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
        var action = "Glance Gesture Swipe "
        if sender.direction == .up {
            action += "up "
        } else if sender.direction == .down {
            action += "down "
        }
        action += String(self.currentItemIndex)
        LogHelper.log.verbose(action)
        
        if self.currentItemIndex >= 0{
            self.selectedItemIndex = self.currentItemIndex
        }
        else {
            return
        }
        guard
            let selectedItemIndex = selectedItemIndex,
            selectedItemIndex < scene?.objs?.count ?? 0,
            let item = scene?.objs?[selectedItemIndex],
            self.like == 0
        else {
            // no item selected
            return
        }
        
        if sender.direction == .up {
            timer?.invalidate()
            self.voiceDelayTime = 1
            readText(text: "您已标记喜欢")
            like = 1
//            showToast(message: "\(item.objName) 已标记为喜欢")
            NetworkRequester.postLikeGlanceItem(
                objId: item.objId,
                like: 1,
                sceneId: scene?.sceneId ,completion: { _ in
                    
                })
            var action = "INPUT Glance Like "
            action += item.objName
            LogHelper.log.info(action)
            self.selectedItemIndex = nil
        } else if sender.direction == .down {
            timer?.invalidate()
            self.voiceDelayTime = 1
            readText(text: "您已选择不感兴趣")
            like = -1
//            showToast(message: "\(item.objName) 已标记为不感兴趣")
            NetworkRequester.postLikeGlanceItem(
                objId: item.objId,
                like: -1,
                sceneId: scene?.sceneId, completion: { _ in
                    
                })
            var action = "INPUT Glance Dislike "
            action += item.objName
            LogHelper.log.info(action)
            self.selectedItemIndex = nil
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
//            self.selectedItemIndex = indexPath.item
//            cell.doubleTapAction = { [weak self] in
//                self?.selectedItemIndex = indexPath.item
//            }
//            }
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
        timer = Timer.scheduledTimer(withTimeInterval: self.voiceDelayTime ?? 7, repeats: false) { _ in
            self.currentItemIndex += 1
            self.readCurrentSceneItem()
            self.voiceDelayTime = nil
        }
    }
}

extension GlanceViewController: CLLocationManagerDelegate {
    // 定位成功
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        currentAngle = newHeading.magneticHeading
        var action = "Glance Angle "
        action += String(currentAngle)
        LogHelper.log.verbose(action)
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations.last ?? CLLocation.init()
        var action = "Glance Location "
        action += location.description
        LogHelper.log.verbose(action)
    }

    // 定位失败
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print(error.localizedDescription)
    }
}
