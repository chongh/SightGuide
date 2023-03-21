//
//  FixationViewController.swift
//  SightGuide
//
//  Created by FindTheLamp on 2023/3/18.
//

import AVFoundation
import UIKit

class FixationViewController: UIViewController, AVAudioRecorderDelegate {
    
    // MARK: - Init
    
    private let synthesizer = AVSpeechSynthesizer()
    
    // views
    private var fixationItemViews: [FixationItemView] = []
    private var lastTouchedView: FixationItemView?
    
    // audio
    private var beepAudioPlayer: AVAudioPlayer?
    
    // data and state
    public var fromScene: Scene? = nil
    private var scene: Scene?
    private var isRootScene: Bool = true
    private var isMarking: Bool = false
    private var labeledObjIds: Set<Int> = []
    private var pendingDismiss = false
    
    // timer
    private var timer: Timer?
    private var lastDoubleTapTimestamp: TimeInterval?
    
    init() {
        super.init(nibName: "FixationViewController", bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View Controller
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setOrientation(orientation: .landscapeRight)
        setupGestures()
        setupAudioPlayer()
        
        setupFixationItemViews()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if
                let fromScene = self.fromScene,
                !fromScene.sceneId.hasSuffix("_1")
            {
                self.parseAndRenderSubScene()
            } else {
                self.parseAndRenderMainScene()
            }
            self.isRootScene = true
            self.readSceneName()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        setOrientation(orientation: .portrait)
    }
    
    // MARK: - View
    
    private func setupFixationItemViews() {
        for _ in 0..<20 {
            let fixationItemView = FixationItemView.loadFromNib()
            fixationItemView.frame = CGRect(x: 0, y: 0, width: 200, height: 50)
            fixationItemView.isHidden = true
            view.addSubview(fixationItemView)
            fixationItemViews.append(fixationItemView)
            
            let doubleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTapItemViewGesture))
            doubleTapGestureRecognizer.numberOfTapsRequired = 2
            fixationItemView.addGestureRecognizer(doubleTapGestureRecognizer)
            
            let singleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTapItemViewGesture(_:)))
            fixationItemView.addGestureRecognizer(singleTapGestureRecognizer)
            singleTapGestureRecognizer.require(toFail: doubleTapGestureRecognizer)
        }
    }
    
    private func renderFixationItemViews() {
        guard let objs = scene?.objs else { return }
        
        cancelFocusedItemView()
        
        for (index, fixationItemView) in fixationItemViews.enumerated() {
            if index < objs.count {
                let obj = objs[index]
                let screenWidth = UIScreen.main.bounds.width
                let screenHeight = UIScreen.main.bounds.height
                let scaleX = screenWidth / 48
                let scaleY = screenHeight / 36
                
                let centerX = (obj.position?.x0 ?? 0) * scaleX + screenWidth / 2
                let centerY = (obj.position?.y0 ?? 0) * scaleY * -1 + screenHeight / 2
                let width = (obj.position?.w ?? 0) * scaleX
                let height = (obj.position?.h ?? 0) * scaleY
                
                let x = centerX - width / 2
                let y = centerY - height / 2
                fixationItemView.frame = CGRect(x: x, y: y, width: width, height: height)
                
                fixationItemView.renderSceneItem(item: obj)
                if labeledObjIds.contains(obj.objId) {
                    fixationItemView.displayDot()
                }
                
                fixationItemView.isHidden = false
            } else {
                fixationItemView.isHidden = true
            }
        }
    }
    
    private func setFocusedItemView(itemView: FixationItemView) {
        lastTouchedView?.setStandardBorder()
        itemView.setThickenedBorder()
        lastTouchedView = itemView
        
        beepAudioPlayer?.play()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { _ in
            self.readLastTouchedView()
        }
    }
    
    private func cancelFocusedItemView() {
        lastTouchedView?.setStandardBorder()
        lastTouchedView = nil
        timer?.invalidate()
    }
    
    // MARK: - Audio
    
    private func readText(text: String) {
        let speechUtterance = AVSpeechUtterance(string: text)
        speechUtterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        synthesizer.speak(speechUtterance)
    }
    
    private func setupAudioPlayer() {
        if let audioPath = Bundle.main.path(forResource: "beep", ofType: "wav") {
            do {
                beepAudioPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: audioPath))
            } catch {
                print("Error initializing audio player: \(error)")
            }
        }
        
        synthesizer.delegate = self
    }
    
    private func readLastTouchedView() {
        var text = lastTouchedView?.item?.objName ?? ""
        if fromScene != nil {
            text += lastTouchedView?.item?.labelId == nil ? "无" : "有"
            text += "标签"
        }
        readText(text: text)
    }
    
    // MARK: - Gestures
    
    private func setupGestures() {
        setupPanGesture()
        setupSwipeGesture()
        setupTwoFingerSwipeLeftGesture()
        setupMarkGestures()
    }
    
    private func setupSwipeGesture() {
        let swipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleThreeFingerSwipeUpGesture))
        swipeGesture.direction = .up
        swipeGesture.numberOfTouchesRequired = 3
        swipeGesture.delegate = self
        view.addGestureRecognizer(swipeGesture)
    }
    
    @objc func handleThreeFingerSwipeUpGesture() {
        dismiss(animated: true, completion: nil)
    }
    
    private func setupPanGesture() {
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        panGestureRecognizer.delegate = self
        view.addGestureRecognizer(panGestureRecognizer)
    }
    
    @objc func handlePanGesture(_ gestureRecognizer: UIPanGestureRecognizer) {
        let touchLocation = gestureRecognizer.location(in: view)
        
        switch gestureRecognizer.state {
        case .began, .changed:
            if let fixationItemView = view.hitTest(touchLocation, with: nil) as? FixationItemView {
                if lastTouchedView != fixationItemView {
                    setFocusedItemView(itemView: fixationItemView)
                }
            } else {
                // lose focus if move finger to outside the item view
                cancelFocusedItemView()
            }
        case .ended, .cancelled, .failed:
            // won't lose focus if user's finger leave screen without moving outside the item view
            timer?.invalidate()
        default:
            break
        }
    }
    
    private func setupTwoFingerSwipeLeftGesture() {
        let twoFingerSwipeLeftGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(handleTwoFingerSwipeLeftGesture))
        twoFingerSwipeLeftGestureRecognizer.direction = .left
        twoFingerSwipeLeftGestureRecognizer.numberOfTouchesRequired = 2
        view.addGestureRecognizer(twoFingerSwipeLeftGestureRecognizer)
    }
    
    @objc func handleTwoFingerSwipeLeftGesture() {
        if isRootScene {
            if fromScene != nil {
                readText(text: "为您返回标签目录")
//                pendingDismiss = true
                dismiss(animated: true, completion: nil)
            }
        } else {
            // return to root scene
            isRootScene = true
            parseAndRenderMainScene()
            readText(text: "为您返回\(scene?.sceneName ?? "")")
        }
    }
    
    @objc func handleTapItemViewGesture(_ sender: UITapGestureRecognizer) {
        if let itemView = sender.view as? FixationItemView {
            if
                fromScene != nil,
                itemView.item?.labelId != nil
            {
                AudioHelper.playRecording(
                    sceneID: scene?.sceneId ?? "",
                    objectID: itemView.item?.objId ?? 0)
            } else {
                readText(text: itemView.item?.text ?? "")
            }
        }
    }
    
    @objc func handleDoubleTapItemViewGesture(_ sender: UITapGestureRecognizer) {
        guard
            isRootScene,
            let itemView = sender.view as? FixationItemView,
            let item = itemView.item
        else { return }
        
        if (!(item.sceneId?.isEmpty ?? true)) {
            isRootScene = false
            parseAndRenderSubScene()
            readSceneName()
        }
    }
    
    private func setupMarkGestures() {
        let doubleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTapGesture))
        doubleTapGestureRecognizer.numberOfTapsRequired = 1
        doubleTapGestureRecognizer.numberOfTouchesRequired = 2
        view.addGestureRecognizer(doubleTapGestureRecognizer)
        
        let longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleDoubleLongPressGesture))
        longPressGestureRecognizer.numberOfTouchesRequired = 2
        longPressGestureRecognizer.minimumPressDuration = 3
        view.addGestureRecognizer(longPressGestureRecognizer)
    }
    
    @objc func handleDoubleTapGesture(_ gesture: UITapGestureRecognizer) {
        lastDoubleTapTimestamp = Date().timeIntervalSince1970
    }
    
    @objc func handleDoubleLongPressGesture(_ gesture: UILongPressGestureRecognizer) {
        guard let lastDoubleTapTimestamp = lastDoubleTapTimestamp else { return }
        
        if gesture.state == .began {
            if Date().timeIntervalSince1970 - lastDoubleTapTimestamp <= 5 {
                markFocusedItemView()
            }
        } else if gesture.state == .ended || gesture.state == .cancelled {
            endMarkFocusedItemView()
        }
    }
    
    // MARK: - Mark
    
    func markFocusedItemView() {
        guard
            lastTouchedView != nil,
            lastTouchedView?.item?.type != 0
        else {
            return
        }
        
        isMarking = true
        readText(text: "您已标记，继续长按可录音添加标签")
    }
    
    func endMarkFocusedItemView() {
        isMarking = false
        AudioHelper.endRecording()
        
        guard
            let item = lastTouchedView?.item
        else { return }
        readText(text: "您已为\(item.objName)\(item.labelId != nil || labeledObjIds.contains(item.objId) ? "修改" : "制作")录音标签")
        
        labeledObjIds.insert(item.objId)
        lastTouchedView?.displayDot()
    }
    
    func startRecording() {
        guard
            isMarking,
            let item = lastTouchedView?.item
        else { return }
        
        AudioHelper.startRecording(
            sceneID: scene?.sceneId ?? "",
            objectID: item.objId)
    }
    
    private func readSceneName() {
        readText(text: "欢迎探索\(scene?.sceneName ?? "")")
    }
    
    // MARK: - Data
    
    private func parseSceneFromJSON(mock: String) {
        if let url = Bundle.main.url(forResource: mock, withExtension: "json") {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                scene = try decoder.decode(Scene.self, from: data)
            } catch {
                print("Error parsing JSON: \(error)")
            }
        }
    }
    
    private func parseAndRenderMainScene() {
        parseSceneFromJSON(mock: "fixation_mock")
        renderFixationItemViews()
    }
    
    private func parseAndRenderSubScene() {
        parseSceneFromJSON(mock: "fixation_subscene_mock")
        renderFixationItemViews()
    }
    
    // MARK: - Landscape
    
    override var shouldAutorotate: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscapeRight
    }
    
    private func setOrientation(orientation: UIInterfaceOrientationMask) {
        (UIApplication.shared.delegate as? AppDelegate)?.orientation = orientation
        
        let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        windowScene?.requestGeometryUpdate(.iOS(interfaceOrientations: orientation))
        
        UIApplication.navigationTopViewController()?.setNeedsUpdateOfSupportedInterfaceOrientations()
    }
}

extension FixationViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

extension FixationViewController: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        if pendingDismiss {
            dismiss(animated: true, completion: nil)
        } else if isMarking {
            startRecording()
        }
    }
}
