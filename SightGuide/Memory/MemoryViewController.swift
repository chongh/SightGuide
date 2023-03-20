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
    
    // audio
    private let synthesizer = AVSpeechSynthesizer()
    private var beepAudioPlayer: AVAudioPlayer?
    
    // data
    private var data: MemoryResponse?
    private var lastSelectedIndexPath: IndexPath?
    private var indexPathPendingExpand: IndexPath?
    
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
        setupPanGesture()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        collectionView.reloadData()
    }
    
    private func setupCollectionView() {
        collectionView.register(
            UINib(nibName: CellID, bundle: nil),
            forCellWithReuseIdentifier: CellID)
        collectionView.register(
            UINib(nibName: SectionHeaderID, bundle: nil),
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: SectionHeaderID)
        
        parseDataFromJSON(mock: "memory_mock")
        collectionView.reloadData()
    }
    
    // MARK: - Gestures
    
    private func setupPanGesture() {
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        panGestureRecognizer.delegate = self
        view.addGestureRecognizer(panGestureRecognizer)
    }
    
    @objc func handlePanGesture(_ gestureRecognizer: UIPanGestureRecognizer) {
        let touchLocation = gestureRecognizer.location(in: view)
        
        switch gestureRecognizer.state {
        case .began, .changed:
            if let memoryCell = (view.hitTest(touchLocation, with: nil) as? InnerView)?.cell {
                if
                    let indexPath = collectionView.indexPath(for: memoryCell),
                    indexPath != lastSelectedIndexPath
                {
                    lastSelectedIndexPath = indexPath
                    
                    beepAudioPlayer?.play()
                    
                    timer?.invalidate()
                    timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { _ in
                        self.readMemory(indexPath: indexPath)
                    }
                }
            } else {
                timer?.invalidate()
                lastSelectedIndexPath = nil
            }
        case .ended, .cancelled, .failed:
            timer?.invalidate()
            lastSelectedIndexPath = nil
        default:
            break
        }
    }
    
    private func handleDoubleTapCell(indexPath: IndexPath) {
        readText(text: "为您展开场景标签")
        indexPathPendingExpand = indexPath
    }
    
    // MARK: - Data
    
    private func parseDataFromJSON(mock: String) {
        if let url = Bundle.main.url(forResource: mock, withExtension: "json") {
            do {
                let response = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                data = try decoder.decode(MemoryResponse.self, from: response)
            } catch {
                print("Error parsing JSON: \(error)")
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
        speechUtterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        synthesizer.speak(speechUtterance)
    }
    
    private func readMemory(indexPath: IndexPath) {
        readText(text: data?.data[indexPath.section].labels?[indexPath.item].labelName ?? "")
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
            cell.doubleTapAction = {
                self.handleDoubleTapCell(indexPath: indexPath)
            }
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
            AudioHelper.playRecording(
                sceneID: data?.data[indexPath.section].sceneId ?? "",
                objectID: data?.data[indexPath.section].labels?[indexPath.item].labelId ?? 0)
        } else if let indexPath = indexPathPendingExpand {
            let fixationViewController = FixationViewController()
            fixationViewController.fromScene = data?.data[indexPath.section]
            fixationViewController.modalPresentationStyle = .fullScreen
            present(fixationViewController, animated: true, completion: nil)
            
            indexPathPendingExpand = nil
        }
    }
}
