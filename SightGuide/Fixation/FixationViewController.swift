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
        NetworkRequester.requestFixationImage(sceneId: scene?.sceneId ?? fromScene?.sceneId ?? "") { image in
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
            
//            let doubleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTapItemViewGesture))
//            doubleTapGestureRecognizer.numberOfTapsRequired = 2
//            fixationItemView.addGestureRecognizer(doubleTapGestureRecognizer)
//
//            let singleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTapItemViewGesture(_:)))
//            fixationItemView.addGestureRecognizer(singleTapGestureRecognizer)
//            guard let doubleTapGestureRecognizer = self.doubleTapGestureRecognizer else { return }
//            guard let doubleTapDoubleFingerGestureRecognizer = self.doubleTapDoubleFingerGestureRecognizer else { return }
//            singleTapGestureRecognizer.require(toFail: doubleTapGestureRecognizer)
//            singleTapGestureRecognizer.require(toFail: doubleTapDoubleFingerGestureRecognizer)
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
//        timer?.invalidate()
//        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
//            self.readLastTouchedView()
//        }
        self.readLastTouchedView()
        var action = "INPUT Fixation Touch "
        action += itemView.item?.objName ?? ""
        NetworkRequester.requestCreateLog(
            action: action,
            completion: { result in
                print(result)
            })
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
        NetworkRequester.requestCreateLog(
            action: action,
            completion: { result in
                print(result)
            })
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
        if isFromLabel {
            text += lastTouchedView?.item?.labelId == nil ? "无" : "已"
            text += "标记"
            text += lastTouchedView?.item?.isRecord == true ? "有" : "无"
            text += "录音"
        } else {
            text += lastTouchedView?.item?.text ?? ""
        }
        readText(text: text)
    }
    
    // MARK: - Gestures
    
    private func setupGestures() {
        setupPanGesture()
        setupSwipeGesture()
        setupTwoFingerSwipeLeftGesture()
        setupMarkGestures()
        setupTapGesture()
    }

    private func setupTapGesture() {
        let doubleTapDoubleFingerGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTapGesture))
        doubleTapDoubleFingerGestureRecognizer.numberOfTapsRequired = 1
        doubleTapDoubleFingerGestureRecognizer.numberOfTouchesRequired = 2
        view.addGestureRecognizer(doubleTapDoubleFingerGestureRecognizer)
        
        let doubleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTapItemViewGesture))
        doubleTapGestureRecognizer.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTapGestureRecognizer)
        doubleTapGestureRecognizer.require(toFail: doubleTapDoubleFingerGestureRecognizer)
        
//        let singleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTapItemViewGesture(_:)))
//        view.addGestureRecognizer(singleTapGestureRecognizer)
//        singleTapGestureRecognizer.require(toFail: doubleTapGestureRecognizer)
//        singleTapGestureRecognizer.require(toFail: doubleTapDoubleFingerGestureRecognizer)
    }
    
    private func setupSwipeGesture() {
        let swipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleThreeFingerSwipeUpGesture))
        swipeGesture.direction = .left
        swipeGesture.numberOfTouchesRequired = 3
        swipeGesture.delegate = self
        view.addGestureRecognizer(swipeGesture)
    }
    
    @objc func handleThreeFingerSwipeUpGesture() {
        if isFromLabel == false{
            readText(text: "您已回到边走边听")
        }
        pendingDismiss = true
        var action = "INPUT Fixation BackToGlance"
        NetworkRequester.requestCreateLog(
            action: action,
            completion: { result in
                print(result)
            })
    }
    
    private func setupPanGesture() {
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        panGestureRecognizer.delegate = self
        view.addGestureRecognizer(panGestureRecognizer)
    }
    
//    @objc func handlePanGesture(_ gestureRecognizer: UIPanGestureRecognizer) {
//        let touchLocation = gestureRecognizer.location(in: view)
//
//        switch gestureRecognizer.state {
//        case .began, .changed:
//            if let fixationItemView = view.hitTest(touchLocation, with: nil) as? FixationItemView {
//                if tmpView != fixationItemView {
//                    setFocusedItemView(itemView: fixationItemView)
//                    tmpView = fixationItemView
//                }
//            }
//            else {
//                // lose focus if move finger to outside the item view
////                cancelFocusedItemView()
//                tmpView = nil
//            }
//        case .ended, .cancelled, .failed:
//            // won't lose focus if user's finger leave screen without moving outside the item view
//            timer?.invalidate()
//        default:
//            break
//        }
//    }
    
    @objc func handlePanGesture(_ gestureRecognizer: UIPanGestureRecognizer) {
        let touchLocation = gestureRecognizer.location(in: view)

        switch gestureRecognizer.state {
        case .began, .changed:
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

//            if let fixationItemView = view.point(inside: touchLocation, with: nil) as? FixationItemView {
//                if tmpView != fixationItemView {
//                    setFocusedItemView(itemView: fixationItemView)
//                    tmpView = fixationItemView
//                }
//            }
//            else {
//                // lose focus if move finger to outside the item view
////                cancelFocusedItemView()
//                tmpView = nil
//            }
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
            if isFromLabel {
                readText(text: "为您返回标签目录")
                pendingDismiss = true
//                dismiss(animated: true, completion: nil)
            }
        } else {
            // return to root scene
            isRootScene = true
            parseAndRenderMainScene()
            self.isBack = true
//            readText(text: "为您返回\(scene?.sceneName ?? "")")
            var action = "INPUT Fixation BackToMain"
            NetworkRequester.requestCreateLog(
                action: action,
                completion: { result in
                    print(result)
                })
        }
    }
    
//    @objc func handleTapItemViewGesture(_ sender: UITapGestureRecognizer) {
//        if let itemView = sender.view as? FixationItemView {
//            if
//                isFromLabel,
//                itemView.item?.labelId != nil,
//                itemView.item?.isRecord == true
//            {
//                AudioHelper.playRecording(
//                    sceneID: scene?.sceneId ?? "",
//                    objectID: itemView.item?.objId ?? 0)
//            } else {
//                if self.lastTouchedView == itemView{
//                    readText(text: itemView.item?.text ?? "")
//                }
//            }
//        }
//    }

    @objc func handleTapItemViewGesture(_ gestureRecognizer: UIPanGestureRecognizer) {
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
//        guard
//            isRootScene,
//            let itemView = sender.view as? FixationItemView,
//            let item = itemView.item
//        else { return }
//
//        if self.lastTouchedView == itemView{
//            if (!(item.sceneId?.isEmpty ?? true)) {
//                isRootScene = false
//                parseAndRenderSubScene(sceneId: item.sceneId ?? "")
//    //            readSceneName()
//            }
//        }
        
        guard
            isRootScene,
            let itemView = self.lastTouchedView,
            let item = itemView.item
        else { return }
        
        if(!(item.sceneId?.isEmpty ?? true)) {
            isRootScene = false
            parseAndRenderSubScene(sceneId: item.sceneId ?? "")
            var action = "INPUT Fixation EnterSubScene"
            NetworkRequester.requestCreateLog(
                action: action,
                completion: { result in
                    print(result)
                })
        }
    }
    
    private func setupMarkGestures() {
        let longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleDoubleLongPressGesture))
        longPressGestureRecognizer.numberOfTouchesRequired = 2
        longPressGestureRecognizer.minimumPressDuration = 1
        view.addGestureRecognizer(longPressGestureRecognizer)
    }
    
    @objc func handleDoubleTapGesture(_ gesture: UITapGestureRecognizer) {
        lastDoubleTapTimestamp = Date().timeIntervalSince1970
    }
    
    @objc func handleDoubleLongPressGesture(_ gesture: UILongPressGestureRecognizer) {
        guard let lastDoubleTapTimestamp = lastDoubleTapTimestamp else { return }
        
        if gesture.state == .began {
            if Date().timeIntervalSince1970 - lastDoubleTapTimestamp <= 3 {
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
        var action = "INPUT Fixation LabelStart"
        NetworkRequester.requestCreateLog(
            action: action,
            completion: { result in
                print(result)
            })
    }
    
    func endMarkFocusedItemView() {
        isMarking = false
        
        guard
            let item = lastTouchedView?.item
        else { return }
        
        if AudioHelper.isRecording() {
            AudioHelper.endRecording()
            
            readText(text: "您已为\(item.objName)\(item.labelId != nil || labeledObjIds.contains(item.objId) || labeledEmptyObjIds.contains(item.objId) ? "修改" : "制作")录音标签")
            
            if labeledEmptyObjIds.contains(item.objId){
                labeledEmptyObjIds.remove(item.objId)
            }
            
            labeledObjIds.insert(item.objId)
            lastTouchedView?.displayDot()
            
            uploadLabelVoice(objectID: item.objId, objectName: item.objName, objectText: item.text)
            var action = "INPUT Fixation RecordFinish "
            action += item.objName
            NetworkRequester.requestCreateLog(
                action: action,
                completion: { result in
                    print(result)
                })
        } else {
            readText(text: "您已为\(item.objName)\(item.labelId != nil || labeledObjIds.contains(item.objId) || labeledEmptyObjIds.contains(item.objId) ? "修改" : "制作")标签")
            
            if labeledObjIds.contains(item.objId){
                labeledObjIds.remove(item.objId)
            }
            
            labeledEmptyObjIds.insert(item.objId)
            lastTouchedView?.displayEmptyDot()
            
            self.createLabel(
                objectID: item.objId,
                objectName: item.objName,
                objectText: item.text,
                recordName: nil)
            var action = "INPUT Fixation LabelFinish "
            action += item.objName
            NetworkRequester.requestCreateLog(
                action: action,
                completion: { result in
                    print(result)
                })
        }
    }
    
    func startRecording() {
        guard
            isMarking,
            let item = lastTouchedView?.item
        else { return }
        
        AudioHelper.startRecording(
            sceneID: scene?.sceneId ?? "",
            objectID: item.objId)
        var action = "INPUT Fixation RecordStart"
        NetworkRequester.requestCreateLog(
            action: action,
            completion: { result in
                print(result)
            })
    }
    
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
                readText(text: "请将手机横向放置")
                self.isFirst = false
            }
        }
    }
    
    // MARK: - Data
    
    private func parseSceneFromJSON(mock: String, sceneId: String) {
//        if let url = Bundle.main.url(forResource: mock, withExtension: "json") {
//            do {
//                let data = try Data(contentsOf: url)
//                let decoder = JSONDecoder()
//                scene = try decoder.decode(Scene.self, from: data)
//            } catch {
//                print("Error parsing JSON: \(error)")
//            }
//        }
        
        NetworkRequester.postFixationData (
            sceneId: sceneId, completion: { result in
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
    
    private func uploadLabelVoice(objectID: Int, objectName: String, objectText: String) {
        NetworkRequester.requestUploadLabelVoice(
            sceneID: scene?.sceneId ?? "",
            objectID: objectID) { recordName, error in
                if let error = error {
                    print(error)
                    return
                }
                
                self.createLabel(
                    objectID: objectID,
                    objectName: objectName,
                    objectText: objectText,
                    recordName: recordName)
            }
    }
    
    private func createLabel(
        objectID: Int,
        objectName: String,
        objectText: String,
        recordName: String?)
    {
        NetworkRequester.requestCreateLabel(
            sceneID: self.scene?.sceneId ?? "",
            sceneName: self.scene?.sceneName ?? "",
            objectID: objectID,
            objectName: objectName,
            objectText: objectText,
            recordName: recordName ?? "",
            completion: { result in
                print(result)
            })
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
