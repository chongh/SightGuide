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
            fixationViewController.fromScene = data?.data[indexPath.item]
            fixationViewController.isFromLabel = true
            fixationViewController.modalPresentationStyle = .fullScreen
            present(fixationViewController, animated: true, completion: nil)

            indexPathPendingExpand = nil
        }
    }
    
    @objc func swipeGestureHandler(_ sender: UISwipeGestureRecognizer) {
        self.synthesizer.stopSpeaking(at: .immediate)
        if sender.direction == .up {
            if self.currentItemIndex > -2 {
                self.currentItemIndex -= 1
            }
            readCurrentSceneItem()
        } else if sender.direction == .down {
            if self.currentItemIndex < self.data?.data.count ?? 0 {
                self.currentItemIndex += 1
            }
            readCurrentSceneItem()
        }
    }
    
    // MARK: - Data
    
    private func requestData() {
        NetworkRequester.requestMemoryLabels(token: LogHelper.UserId) { result in
            switch result {
            case .success(let response):
                self.data = response
                self.collectionView.reloadData()
                self.currentItemIndex = -2
                self.currentSectionIndex = 0
//                self.readCurrentSceneItem()
            case .failure(let error):
                print("Error: \(error)")
            }
        }
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
        if currentItemIndex < -1 || currentItemIndex >= data?.data.count ?? 0 {
            return
        }

        if currentItemIndex == -1 {
            beepAudioPlayer?.play()

            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                self.readText(text: "用户" + LogHelper.UserId)
            }
            lastSelectedIndexPath = nil
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CellID, for: IndexPath(item: currentItemIndex, section: 0)) as! MemoryCollectionViewCell
            beepAudioPlayer?.play()

            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                self.readText(text: self.data?.data[self.currentItemIndex].sceneName ?? "")
            }
        }
    }
}

extension MemoryViewController: UICollectionViewDataSource {
    
    // Number of sections
    func numberOfSections(in collectionView: UICollectionView) -> Int {
//        return data?.data.count ?? 0
        return 1
    }
    
    // Number of items in each section
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
//        return data?.data[section].labels?.count ?? 0
        return data?.data.count ?? 0
    }
    
    // Configure each cell
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CellID, for: indexPath) as! MemoryCollectionViewCell
        if let scene = data?.data[indexPath.item] {
            cell.renderScene(scene: scene)
        }
        return cell
    }
    
    // Configure the header view for each section
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: SectionHeaderID, for: indexPath) as! MemorySectionHeaderView
            header.configureTitle(title: "用户" + LogHelper.UserId)
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
//        if let indexPath = lastSelectedIndexPath {
//            if let recordName = data?.data[indexPath.section].labels?[indexPath.item].recordName {
//                NetworkRequester.requestLabelAudioAndPlay(
//                    token: LogHelper.UserId,
//                    recordName: recordName) { localURL in
//                        if self.lastSelectedIndexPath == indexPath,
//                        let localURL = localURL {
//                            AudioHelper.playFile(url: localURL)
//                        }
//                    }
//            }
//        } else if let indexPath = indexPathPendingExpand {
        if let indexPath = indexPathPendingExpand {
            let fixationViewController = FixationViewController()
            fixationViewController.fromScene = data?.data[indexPath.item]
            fixationViewController.isFromLabel = true
            fixationViewController.modalPresentationStyle = .fullScreen
            present(fixationViewController, animated: true, completion: nil)
            
            indexPathPendingExpand = nil
        }
    }
}
