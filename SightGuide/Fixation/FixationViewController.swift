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
    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var blockView: UIView!
    private var fixationItemViews: [FixationItemView] = []
    private var lastTouchedView: FixationItemView?
    private var tmpView: FixationItemView?
    private var lastTouchedViews: [FixationItemView] = []
    
    // audio
    private var beepAudioPlayer: AVAudioPlayer?
    
    // data and state
    public var fromScene: Scene? = nil
    private var scene: Scene?
    private var isRootScene: Bool = true
    public var isFromLabel: Bool = false
    private var isMarking: Bool = false
    private var labeledObjIds: Set<Int> = []
    private var labeledEmptyObjIds: Set<Int> = []
    private var pendingDismiss = false
    private var isBack = false
    private var isFirst = true
    private var audioObjId: Int?
    
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
        
        setupBackgroundImageView()
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
                self.parseAndRenderSubScene(sceneId: fromScene.sceneId)
            } else {
                self.parseAndRenderMainScene()
            }
            self.isRootScene = true
//            self.readSceneName()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        setOrientation(orientation: .portrait)
    }
    
    // MARK: - View
    
    private func setupBackgroundImageView() {
        NetworkRequester.requestFixationImage(sceneId: scene?.sceneId ?? fromScene?.sceneId ?? "", token: LogHelper.UserId) { image in
            print("image!")
            self.backgroundImageView.image = image
        }
    }
    
    private func setupFixationItemViews() {
        for _ in 0..<20 {
            let fixationItemView = FixationItemView.loadFromNib()
            fixationItemView.frame = CGRect(x: 0, y: 0, width: 200, height: 50)
            fixationItemView.isHidden = true
            view.addSubview(fixationItemView)
            fixationItemViews.append(fixationItemView)
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
                let r = max(width, height)
                
                let x = centerX - r / 2
                let y = centerY - r / 2
                fixationItemView.frame = CGRect(x: x, y: y, width: r, height: r)
                
                fixationItemView.dotView.center.x = fixationItemView.bounds.width / 2
                fixationItemView.dotView.center.y = fixationItemView.bounds.height / 2 - 15
                
                fixationItemView.renderSceneItem(item: obj)
                if labeledObjIds.contains(obj.objId) {
                    fixationItemView.displayDot()
                }
                
                if labeledEmptyObjIds.contains(obj.objId){
                    fixationItemView.displayEmptyDot()
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
        
        self.synthesizer.stopSpeaking(at: .immediate)
        beepAudioPlayer?.play()
        self.readLastTouchedView()
        var action = "INPUT Fixation Touch "
        action += itemView.item?.objName ?? ""
        LogHelper.log.info(action)
    }
    
    private func cancelFocusedItemView() {
        lastTouchedView?.setStandardBorder()
        lastTouchedView = nil
        timer?.invalidate()
    }
    
    // MARK: - Audio
    
    private func readText(text: String) {
        let speechUtterance = AVSpeechUtterance(string: text)
        speechUtterance.rate = 0.7
        speechUtterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        synthesizer.speak(speechUtterance)
        var action = "OUTPUT Fixation ReadText "
        action += text
        LogHelper.log.info(action)
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
        synthesizer.stopSpeaking(at: .immediate)
        audioObjId = nil
        AudioHelper.audioPlayer?.stop()
        var text = lastTouchedView?.item?.objName ?? ""
        if isFromLabel {
            text += lastTouchedView?.item?.labelId == nil ? "无" : "已"
            text += "标记"
            text += lastTouchedView?.item?.isRecord == true ? "有" : "无"
            text += "录音。"
            text += lastTouchedView?.item?.text ?? ""
        } else {
            text += lastTouchedView?.item?.text ?? ""
        }
        readText(text: text)
    }
    
    // MARK: - Gestures
    
    private func setupGestures() {
        setupPanGesture()
        setupTapGesture()
    }

    private func setupTapGesture() {
        let doubleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTapItemViewGesture))
        doubleTapGestureRecognizer.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTapGestureRecognizer)
    }
    
    private func setupPanGesture() {
        let twoFingerSwipeLeftGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(handleTwoFingerSwipeLeftGesture))
        twoFingerSwipeLeftGestureRecognizer.direction = .left
        twoFingerSwipeLeftGestureRecognizer.numberOfTouchesRequired = 2
        view.addGestureRecognizer(twoFingerSwipeLeftGestureRecognizer)
        
        let twoFingerSwipeRightGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(handleTwoFingerSwipeLeftGesture))
        twoFingerSwipeRightGestureRecognizer.direction = .right
        twoFingerSwipeRightGestureRecognizer.numberOfTouchesRequired = 2
        view.addGestureRecognizer(twoFingerSwipeRightGestureRecognizer)
        
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        panGestureRecognizer.delegate = self
        view.addGestureRecognizer(panGestureRecognizer)
        panGestureRecognizer.require(toFail: twoFingerSwipeLeftGestureRecognizer)
        panGestureRecognizer.require(toFail: twoFingerSwipeRightGestureRecognizer)
    }
    
    @objc func handlePanGesture(_ gestureRecognizer: UIPanGestureRecognizer) {
        let touchLocation = gestureRecognizer.location(in: view)

        switch gestureRecognizer.state {
        case .began, .changed:
            var action = "Fixation Gesture Pan "
            action += String.init(format: "%.2f, ", touchLocation.x)
            action += String.init(format: "%.2f", touchLocation.y)
            LogHelper.log.verbose(action)
            lastTouchedViews.removeAll()
            for v in fixationItemViews{
                let convertedPoint = v.convert(touchLocation, from: view)
                if v.point(inside: convertedPoint, with: nil),
                   !v.isHidden {
                    lastTouchedViews.append(v)
                }
            }
            
            if lastTouchedViews.count > 0{
                var selectedView: FixationItemView? = nil
                var delta: CGFloat = 99999
                for v in lastTouchedViews{
                    var tmpDelta = pow((v.center.x - touchLocation.x), 2);
                    tmpDelta += pow((v.center.y - touchLocation.y), 2);
                    if tmpDelta < delta {
                        delta = tmpDelta
                        selectedView = v
                    }
                }
                if tmpView != selectedView {
                    guard let selectedView = selectedView else {break}
                    setFocusedItemView(itemView: selectedView)
                    tmpView = selectedView
                }
            }
            else {
                tmpView = nil
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
        
        let twoFingerSwipeRightGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(handleTwoFingerSwipeLeftGesture))
        twoFingerSwipeRightGestureRecognizer.direction = .right
        twoFingerSwipeRightGestureRecognizer.numberOfTouchesRequired = 2
        view.addGestureRecognizer(twoFingerSwipeRightGestureRecognizer)
    }
    
    @objc func handleTwoFingerSwipeLeftGesture() {
        LogHelper.log.verbose("Fixation Gesture TwoFingerSwipe")

        if isRootScene {
            if isFromLabel {
                readText(text: "为您返回标签目录")
                pendingDismiss = true
//                dismiss(animated: true, completion: nil)
            }
        } else {
            // return to root scene
            isRootScene = true
            self.isBack = true
            parseAndRenderMainScene()
            let action = "INPUT Fixation BackToMain"
            LogHelper.log.info(action)

        }
    }

    @objc func handleTapItemViewGesture(_ gestureRecognizer: UIPanGestureRecognizer) {
        LogHelper.log.verbose("Fixation Gesture Tap")

        let touchLocation = gestureRecognizer.location(in: view)

        if let itemView = self.lastTouchedView {
            if
                isFromLabel,
                itemView.item?.labelId != nil,
                itemView.item?.isRecord == true
            {
                AudioHelper.playRecording(
                    sceneID: scene?.sceneId ?? "",
                    objectID: itemView.item?.objId ?? 0)
            } else {
                readText(text: itemView.item?.text ?? "")
            }
        } else {
            if let fixationItemView = view.hitTest(touchLocation, with: nil) as? FixationItemView {
                if tmpView != fixationItemView {
                    setFocusedItemView(itemView: fixationItemView)
                    tmpView = fixationItemView
                }
            }
        }
    }
    
    @objc func handleDoubleTapItemViewGesture() {
        LogHelper.log.verbose("Fixation Gesture DoubleTap")
        
        guard
            isRootScene,
            let itemView = self.lastTouchedView,
            let item = itemView.item
        else { return }
        
        if(!(item.sceneId?.isEmpty ?? true)) {
            isRootScene = false
            parseAndRenderSubScene(sceneId: item.sceneId ?? "")
            let action = "INPUT Fixation EnterSubScene"
            LogHelper.log.info(action)
        }
    }
    
    // MARK: - Mark
    
    private func readSceneName() {
        if self.isBack {
            if scene?.sceneName != nil {
                readText(text: "为您返回\(scene?.sceneName ?? "")")
            }
            self.isBack = false
        }
        else {
            if scene?.sceneName != nil {
                readText(text: "欢迎探索\(scene?.sceneName ?? "")")
            }
            if self.isFirst{
                readText(text: "请将手机横向放置，声音向右")
                self.isFirst = false
            }
        }
    }
    
    // MARK: - Data
    
    private func parseSceneFromJSON(mock: String, sceneId: String) {
        NetworkRequester.postFixationData (
            sceneId: sceneId, token: LogHelper.UserId, completion: { result in
            switch result {
            case .success(let sceneResponse):
                self.scene = sceneResponse
                self.renderFixationItemViews()
                self.readSceneName()
            case .failure(let error):
                print("Error: \(error)")
            }
        })
    }
    
    private func parseAndRenderMainScene() {
        parseSceneFromJSON(mock: "fixation_mock", sceneId: fromScene?.sceneId ?? "")
        renderFixationItemViews()
    }
    
    private func parseAndRenderSubScene(sceneId: String) {
        parseSceneFromJSON(mock: "fixation_subscene_mock", sceneId: sceneId)
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
        print(lastTouchedView?.item?.text == "" ? "我自己" : lastTouchedView?.item?.text)
        if pendingDismiss {
            dismiss(animated: true, completion: nil)
        } else if audioObjId != nil {
            guard
                let item = lastTouchedView?.item
            else { return }
            
            if item.objId != audioObjId{
                return
            }
            
            AudioHelper.playRecording(sceneID: scene?.sceneId ?? "", objectID: item.objId)
            audioObjId = nil
        } else if isFromLabel,
                  let tmpText = lastTouchedView?.item?.text == "" ? "我自己" : lastTouchedView?.item?.text,
                  utterance.speechString.contains(tmpText),
                  let recordName = lastTouchedView?.item?.recordName {
            NetworkRequester.requestLabelAudioAndPlay(token: LogHelper.UserId, recordName: recordName) { localURL in
                if let tmpText = self.lastTouchedView?.item?.text == "" ? "我自己" : self.lastTouchedView?.item?.text,
                    utterance.speechString.contains(tmpText),
                let localURL = localURL {
                    AudioHelper.playFile(url: localURL)
                }
            }
        }
    }
}
