//
//  MemoryViewController.swift
//  SightGuide
//
//  Created by FindTheLamp on 2023/3/18.
//

import AVFoundation
import UIKit

private let CellID = "MemoryCollectionViewCell"
private let SectionHeaderID = "MemorySectionHeaderView"

final class MemoryViewController: UIViewController {
    
    // MARK: - Init
    
    // views
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var blockView: UIView!
    
    // audio
    private let synthesizer = AVSpeechSynthesizer()
    private var beepAudioPlayer: AVAudioPlayer?
    
    // data
    private var data: MemoryResponse?
    private var lastSelectedIndexPath: IndexPath?
    private var indexPathPendingExpand: IndexPath?
    
    private var currentSectionIndex = -1
    private var currentItemIndex = -1
    
    // timer
    private var timer: Timer?
    
    init() {
        super.init(nibName: "MemoryViewController", bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View Controller
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        readText(text: "请选择标签")
        
        setupCollectionView()
        setupAudioPlayer()
        //        setupPanGesture()
        setupSwipeGesture()
        setupTapGesture()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    private func setupCollectionView() {
        collectionView.register(
            UINib(nibName: CellID, bundle: nil),
            forCellWithReuseIdentifier: CellID)
        collectionView.register(
            UINib(nibName: SectionHeaderID, bundle: nil),
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: SectionHeaderID)
        
        requestData()
    }
    
    // MARK: - Gestures
    
    //    private func setupPanGesture() {
    //        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
    //        panGestureRecognizer.delegate = self
    //        view.addGestureRecognizer(panGestureRecognizer)
    //    }
    
    private func setupSwipeGesture() {
        let swipeUpGesture = UISwipeGestureRecognizer(target: self, action: #selector(swipeGestureHandler(_:)))
        swipeUpGesture.direction = .up
        view.addGestureRecognizer(swipeUpGesture)

        let swipeDownGesture = UISwipeGestureRecognizer(target: self, action: #selector(swipeGestureHandler(_:)))
        swipeDownGesture.direction = .down
        view.addGestureRecognizer(swipeDownGesture)
    }
    
    private func setupTapGesture() {
        let doubleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTapItemViewGesture))
        doubleTapGestureRecognizer.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTapGestureRecognizer)
    }
    
    @objc func handleDoubleTapItemViewGesture() {
        if currentItemIndex <= -1{
            return
        }
        readText(text: "为您展开场景标签")
        indexPathPendingExpand = IndexPath(item: currentItemIndex, section: currentSectionIndex)
        
        if let indexPath = indexPathPendingExpand {
            let fixationViewController = FixationViewController()
            fixationViewController.fromScene = data?.data[indexPath.section]
            fixationViewController.isFromLabel = true
            fixationViewController.modalPresentationStyle = .fullScreen
            present(fixationViewController, animated: true, completion: nil)

            indexPathPendingExpand = nil
        }
    }
    
    //    @objc func handlePanGesture(_ gestureRecognizer: UIPanGestureRecognizer) {
    //        let touchLocation = gestureRecognizer.location(in: view)
    //
    //        switch gestureRecognizer.state {
    //        case .began, .changed:
    //            if let memoryCell = (view.hitTest(touchLocation, with: nil) as? InnerView)?.cell {
    //                if
    //                    let indexPath = collectionView.indexPath(for: memoryCell),
    //                    indexPath != lastSelectedIndexPath
    //                {
    //                    lastSelectedIndexPath = indexPath
    //
    //                    self.synthesizer.stopSpeaking(at: .immediate)
    //                    AudioHelper.audioPlayer?.stop()
    //                    beepAudioPlayer?.play()
    //
    //                    timer?.invalidate()
    //                    timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
    //                        self.readMemory(indexPath: indexPath)
    //                    }
    //                }
    //            } else {
    //                timer?.invalidate()
    //                lastSelectedIndexPath = nil
    //            }
    //        case .ended, .cancelled, .failed:
    //            timer?.invalidate()
    //            lastSelectedIndexPath = nil
    //        default:
    //            break
    //        }
    //    }
    
    @objc func swipeGestureHandler(_ sender: UISwipeGestureRecognizer) {
        self.synthesizer.stopSpeaking(at: .immediate)
        if sender.direction == .up {
            if self.currentItemIndex + 1 >= self.data?.data[self.currentSectionIndex].labels?.count ?? 0 {
                if self.currentSectionIndex + 1 >= self.data?.data.count ?? 0 {
                    print("end")
                    return
                }
                else {
                    self.currentSectionIndex += 1
                    self.currentItemIndex = -1
                }
            }
            else {
                self.currentItemIndex += 1
            }
            readCurrentSceneItem()
        } else if sender.direction == .down {
            if self.currentItemIndex == -2 {
                // init do not handle down
                return
            }
            if self.currentItemIndex == -1 {
                if self.currentSectionIndex == 0 {
                    print("begin")
                    return
                }
                else {
                    self.currentSectionIndex -= 1
                    self.currentItemIndex = self.data?.data[self.currentSectionIndex].labels?.count ?? 0
                    self.currentItemIndex -= 1
                }
            }
            else {
                self.currentItemIndex -= 1
            }
            readCurrentSceneItem()
        }
    }
    
//    private func handleDoubleTapCell(indexPath: IndexPath) {
//        readText(text: "为您展开场景标签")
//        indexPathPendingExpand = indexPath
//    }
    
    
    // MARK: - Data
    
    private func requestData() {
        let mock = LogHelper.UserId + "/memory_mock"
        if let url = Bundle.main.url(forResource: mock, withExtension: "json") {
            do {
                let response = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                self.data = try decoder.decode(MemoryResponse.self, from: response)
                self.collectionView.reloadData()
                self.currentItemIndex = -2
                self.currentSectionIndex = 0
            } catch {
                print("Error parsing JSON: \(error)")
            }
        }
        
//        NetworkRequester.requestMemoryLabels(userId: LogHelper.UserId) { result in
//            switch result {
//            case .success(let response):
//                self.data = response
//                self.collectionView.reloadData()
//                self.currentItemIndex = -2
//                self.currentSectionIndex = 0
////                self.readCurrentSceneItem()
//            case .failure(let error):
//                print("Error: \(error)")
//            }
//        }
    }
    
    // MARK: - Audio
    
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
    
    private func readText(text: String) {
        let speechUtterance = AVSpeechUtterance(string: text)
        speechUtterance.rate = 0.7
        speechUtterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        synthesizer.speak(speechUtterance)
        LogHelper.log.info("memory" + text)
    }
    
    private func readMemory(indexPath: IndexPath) {
        lastSelectedIndexPath = indexPath

        readText(text: data?.data[indexPath.section].labels?[indexPath.item].labelName ?? "")
        if data?.data[indexPath.section].labels?[indexPath.item].duration ?? 0 == 0{
            readText(text: data?.data[indexPath.section].labels?[indexPath.item].labelText ?? "")
        }
    }
    
    private func readCurrentSceneItem() {
        if currentItemIndex < -1 {
            return
        }
        print(currentSectionIndex)
        print(currentItemIndex)
        
        if currentItemIndex == -1 {
            // header
//            let cell = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader , withReuseIdentifier: SectionHeaderID, for: IndexPath(index: currentSectionIndex)) as! MemorySectionHeaderView
            print(data?.data[currentSectionIndex].sceneName ?? "")
            beepAudioPlayer?.play()
            
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                self.readText(text: self.data?.data[self.currentSectionIndex].sceneName ?? "")
            }
            lastSelectedIndexPath = nil
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CellID, for: IndexPath(item: currentItemIndex, section: currentSectionIndex)) as! MemoryCollectionViewCell
            print(data?.data[currentSectionIndex].labels?[currentItemIndex].labelName ?? "")
            beepAudioPlayer?.play()
            
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                self.readMemory(indexPath: IndexPath(item: self.currentItemIndex, section: self.currentSectionIndex))
            }
        }
    }
}

extension MemoryViewController: UICollectionViewDataSource {
    
    // Number of sections
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return data?.data.count ?? 0
    }
    
    // Number of items in each section
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return data?.data[section].labels?.count ?? 0
    }
    
    // Configure each cell
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CellID, for: indexPath) as! MemoryCollectionViewCell
        if let label = data?.data[indexPath.section].labels?[indexPath.item] {
            cell.renderLabel(label: label)
//            cell.doubleTapAction = {
//                self.handleDoubleTapCell(indexPath: indexPath)
//            }
        }
        return cell
    }
    
    // Configure the header view for each section
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: SectionHeaderID, for: indexPath) as! MemorySectionHeaderView
            header.configureTitle(title: data?.data[indexPath.section].sceneName ?? "")
            return header
        }
        return UICollectionReusableView()
    }
}

extension MemoryViewController: UICollectionViewDelegateFlowLayout {
    
    // Cell size
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.bounds.width, height: 50)
    }
    
    // Spacing between cells
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 10
    }
    
    // Spacing between lines
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 20
    }
    
    // Header size
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.bounds.width, height: 50)
    }
}

extension MemoryViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

extension MemoryViewController: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        if let indexPath = lastSelectedIndexPath {
            if let recordName = data?.data[indexPath.section].labels?[indexPath.item].recordName {
//                NetworkRequester.requestLabelAudioAndPlay(
//                    sceneID: data?.data[indexPath.section].sceneId ?? "",
//                    labelID: data?.data[indexPath.section].labels?[indexPath.item].labelId ?? 0,
//                    recordName: recordName) { localURL in
//                        if self.lastSelectedIndexPath == indexPath,
//                        let localURL = localURL {
//                            AudioHelper.playFile(url: localURL)
//                        }
//                    }
                if self.lastSelectedIndexPath == indexPath {
                    let mock = LogHelper.UserId + "/" + recordName.split(separator: ".")[0]
                    if let localUrl = Bundle.main.url(forResource: mock, withExtension: "m4a") {
                        AudioHelper.playFile(url: localUrl)
                    } else {
                        print("!!!" + mock)
                    }
                }
            }
//            else {
//                AudioHelper.playRecording(
//                    sceneID: data?.data[indexPath.section].sceneId ?? "",
//                    objectID: data?.data[indexPath.section].labels?[indexPath.item].labelId ?? 0)
//            }
        } else if let indexPath = indexPathPendingExpand {
            let fixationViewController = FixationViewController()
            fixationViewController.fromScene = data?.data[indexPath.section]
            fixationViewController.isFromLabel = true
            fixationViewController.modalPresentationStyle = .fullScreen
            present(fixationViewController, animated: true, completion: nil)
            
            indexPathPendingExpand = nil
        }
    }
}

//extension MemoryViewController: AVSpeechSynthesizerDelegate {
//    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
//        
//        timer?.invalidate()
//        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { _ in
//            self.currentItemIndex += 1
//            self.readCurrentSceneItem()
//        }
//    }
//}
