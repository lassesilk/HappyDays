//
//  MainCollectionViewController.swift
//  HappyDays
//
//  Created by Lasse Silkoset on 16/05/2020.
//  Copyright © 2020 Lasse Silkoset. All rights reserved.
//

import UIKit
import AVFoundation
import Photos
import Speech
import CoreSpotlight
import MobileCoreServices

class MainCollectionViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout, UISearchBarDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, AVAudioRecorderDelegate {
    
    fileprivate let MemoryCellId = "MemoryCell"
    
    var memories = [URL]()
    var activeMemory: URL!
    var audioRecorder: AVAudioRecorder?
    var recordingURL: URL!
    var audioPlayer: AVAudioPlayer?
    var filteredMemories = [URL]()
    var searchQuery: CSSearchQuery?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        setupNavBar()
        
        recordingURL = getDocumentsDirectory().appendingPathComponent("recording.m4a")
        
        loadMemories()
    }
    
    fileprivate func checkPermissions() {
        let photosAuthorized = PHPhotoLibrary.authorizationStatus() == .authorized
        let recordingAuthorized = AVAudioSession.sharedInstance().recordPermission == .granted
        let transcribeAuthorized = SFSpeechRecognizer.authorizationStatus() == .authorized
        
        let auth = photosAuthorized && recordingAuthorized && transcribeAuthorized
        
        if auth == false {
            let permissionsVC = ViewController()
            navigationController?.present(permissionsVC, animated: true, completion: nil)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        checkPermissions()
    }
    
    fileprivate func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        
        return documentsDirectory
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        filterMemories(text: searchText)
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    func filterMemories(text: String) {
        guard text.count > 0 else {
            filteredMemories = memories

            UIView.performWithoutAnimation {
                collectionView?.reloadSections(IndexSet(integer: 1))
            }

            return
        }

        var allItems = [CSSearchableItem]()

        searchQuery?.cancel()

        let queryString = "contentDescription == \"*\(text)*\"c"
        searchQuery = CSSearchQuery(queryString: queryString, attributes: nil)

        searchQuery?.foundItemsHandler = { items in
            allItems.append(contentsOf: items)
        }

        searchQuery?.completionHandler = { error in
            DispatchQueue.main.async { [unowned self] in
                self.activateFilter(matches: allItems)
            }
        }

        searchQuery?.start()
    }

    func activateFilter(matches: [CSSearchableItem]) {
        filteredMemories = matches.map { item in
            return URL(fileURLWithPath: item.uniqueIdentifier)
        }

        UIView.performWithoutAnimation {
            collectionView?.reloadSections(IndexSet(integer: 1))
        }
    }
    
    fileprivate func loadMemories() {
        
        memories.removeAll()
        
        guard let files = try? FileManager.default.contentsOfDirectory(at: getDocumentsDirectory(), includingPropertiesForKeys: nil, options: []) else { return }
        
        for file in files {
            let fileName = file.lastPathComponent
            
            //Checking if file ends with ".thumb" so we dont count each memory more than once
            if fileName.hasSuffix(".thumb") {
                //get the root name of the memory (i.e, without its path extension)
                let noExtension = fileName.replacingOccurrences(of: ".thumb", with: "")
                //create a full path from the memory
                let memoryPath = getDocumentsDirectory().appendingPathComponent(noExtension)
                //add it to our array
                memories.append(memoryPath)
            }
        }
        
        filteredMemories = memories
        
        collectionView.reloadSections(IndexSet(integer: 1))
    }
    
    @objc fileprivate func addTapped() {
        let vc = UIImagePickerController()
        vc.modalPresentationStyle = .formSheet
        vc.delegate = self
        navigationController?.present(vc, animated: true, completion: nil)
    }
    
    @objc fileprivate func memoryLongPress(sender: UILongPressGestureRecognizer) {
        
        if sender.state == .began {
            let cell = sender.view as! MemoryCell
            
            if let index = collectionView.indexPath(for: cell) {
                activeMemory = filteredMemories[index.row]
                recordMemory()
            }
        }  else if sender.state == .ended {
            finishRecording(success: true)
        }
    }
    
    fileprivate func recordMemory() {
        
        audioPlayer?.stop()
        
        collectionView.backgroundColor = UIColor(red: 0.5, green: 0, blue: 0, alpha: 1)
        
        let recordingSession = AVAudioSession.sharedInstance()
        
        do {
            try recordingSession.setCategory(AVAudioSession.Category.playAndRecord, options: .defaultToSpeaker)
            
            let settings = [AVFormatIDKey: Int(kAudioFormatMPEG4AAC), AVSampleRateKey: 44100, AVNumberOfChannelsKey: 2,  AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue]
            
            audioRecorder = try AVAudioRecorder(url: recordingURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
        } catch let error {
            print("Failed to record: ", error)
            
            finishRecording(success: false)
        }
    }
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            finishRecording(success: false)
        }
    }
    
    fileprivate func finishRecording(success: Bool) {
        collectionView.backgroundColor = UIColor.white
        
        audioRecorder?.stop()
        
        if success {
            do {
                let memoryAudioURL = activeMemory.appendingPathExtension("m4a")
                let fm = FileManager.default
                
                if fm.fileExists(atPath: memoryAudioURL.path) {
                    try fm.removeItem(at: memoryAudioURL)
                }
                
                try fm.moveItem(at: recordingURL, to: memoryAudioURL)
                
                transcribeAudio(memory: activeMemory)
                
            } catch let error {
                print("Failure finishing recording: ", error)
            }
        }
    }
    
    fileprivate func transcribeAudio(memory: URL) {
        
        let audio = audioURL(for: memory)
        let transcription = transcriptionURL(for: memory)
        
        let recognizer = SFSpeechRecognizer()
        let request = SFSpeechURLRecognitionRequest(url: audio)
       
        
        recognizer?.recognitionTask(with: request, resultHandler: { [unowned self] (result, error) in
            
            guard let result = result else {
                print("There was an error i oversetter : ", error ?? "")
                AlertService.addAlert(title: "Error", message: "Error Transcribing", in: self, handler: nil)
                return
            }
            
            if result.isFinal {
                let text = result.bestTranscription.formattedString
                
                do {
                    try text.write(to: transcription, atomically: true, encoding: String.Encoding.utf8)
                    self.indexMemory(memory: memory, text: text)
                } catch {
                    print("failed to save transcription")
                }
            }
        })
        
    }
    
    func indexMemory(memory: URL, text: String) {
        let attributeSet = CSSearchableItemAttributeSet(itemContentType: kUTTypeText as String)
        attributeSet.title = "Happy Days Memory"
        attributeSet.contentDescription = text
        attributeSet.thumbnailURL = thumbnailURL(for: memory)

        let item = CSSearchableItem(uniqueIdentifier: memory.path, domainIdentifier: "com.hackingwithswift", attributeSet: attributeSet)
        item.expirationDate = Date.distantFuture

        CSSearchableIndex.default().indexSearchableItems([item]) { error in
            if let error = error {
                print("Indexing error: \(error.localizedDescription)")
            } else {
                print("Search item successfully indexed: \(text)")
            }
        }
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        dismiss(animated: true, completion: nil)
        
        
        if let possibleImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
            saveNewMemory(image: possibleImage)
            loadMemories()
        }
    }
    
    fileprivate func saveNewMemory(image: UIImage) {
        let memoryName = "memory-\(Date().timeIntervalSince1970)"
        
        let imageName = memoryName + ".jpg"
        let thumbnailName = memoryName + ".thumb"
        
        do {
            let imagePath = getDocumentsDirectory().appendingPathComponent(imageName)
            
            if let jpegData = image.jpegData(compressionQuality: 80) {
                
                try jpegData.write(to: imagePath, options: [.atomicWrite])
            }
            
            if let thumbnail = resize(image: image, to: 200) {
                 let imagePath = getDocumentsDirectory().appendingPathComponent(thumbnailName)
                
                if let jpegData = thumbnail.jpegData(compressionQuality: 80) {
                    try jpegData.write(to: imagePath, options: [.atomicWrite])
                }
            }
            
        } catch {
            print("Failed to save to disk")
        }
    }
    
    fileprivate func resize(image: UIImage, to width: CGFloat) -> UIImage? {
        let scale = width / image.size.width
        
        let height = image.size.height * scale
        
        UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: height), false, 0)
        
        image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        
        UIGraphicsEndImageContext()
        
        return newImage
    }
    
    fileprivate func imageURL(for memory: URL) -> URL {
        return memory.appendingPathExtension("jpg")
    }
    
    fileprivate func thumbnailURL(for memory: URL) -> URL {
        return memory.appendingPathExtension("thumb")
    }
    
    fileprivate func audioURL(for memory: URL) -> URL {
        return memory.appendingPathExtension("m4a")
    }
    
    fileprivate func transcriptionURL(for memory: URL) -> URL {
        return memory.appendingPathExtension("txt")
    }
    
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let memory = filteredMemories[indexPath.row]
        let fm = FileManager.default
        
        do {
            let audioName = audioURL(for: memory)
            let transcriptionName = transcriptionURL(for: memory)
            
            if fm.fileExists(atPath: audioName.path) {
                audioPlayer = try AVAudioPlayer(contentsOf: audioName)
                audioPlayer?.play()
            }
            
            if fm.fileExists(atPath: transcriptionName.path) {
                let contents = try String(contentsOf: transcriptionName)
                
                AlertService.addAlert(title: "Transcription", message: contents, in: self, handler: nil)
                print("Transcription: ", contents)
            }
            
        } catch {
            print("Error loading audio")
        }
    }
    
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 20
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 20
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 200, height: 200)
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == 0 {
            return 0
        } else {
            return filteredMemories.count
        }
    }
    
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MemoryCellId, for: indexPath) as! MemoryCell
        let memory = filteredMemories[indexPath.row]
        let imageName = thumbnailURL(for: memory).path
        let image = UIImage.init(contentsOfFile: imageName)
        
        cell.imageView.image = image
        
        if cell.gestureRecognizers == nil {
            let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(memoryLongPress))
            recognizer.minimumPressDuration = 0.25
            cell.addGestureRecognizer(recognizer)
            
            cell.layer.borderColor = UIColor.white.cgColor
            cell.layer.borderWidth = 3
            cell.layer.cornerRadius = 10
        }
        
        return cell
    }
    
//    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
//        return collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "Header", for: indexPath)
//    }
//
//    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
//        if section == 1 {
//            return CGSize.zero
//        } else {
//            return CGSize(width: 0, height: 50)
//        }
//    }
    
    fileprivate func setupCollectionView() {
        title = "HappyDays"
        collectionView.register(MemoryCell.self, forCellWithReuseIdentifier: MemoryCellId)
        
        collectionView.backgroundColor = .white
    }
    
    fileprivate func setupNavBar() {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.obscuresBackgroundDuringPresentation = true
        
        navigationItem.hidesSearchBarWhenScrolling = false
        navigationItem.searchController = searchController
        navigationItem.searchController?.searchBar.isHidden = false
        navigationItem.searchController?.searchBar.placeholder = "Søk"
        navigationItem.searchController?.searchBar.delegate = self
        //  navigationItem.searchController?.searchBar.tintColor = .white
        // navigationItem.searchController?.searchBar.searchTextField.textColor = .white
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addTapped))
    }
    
}
