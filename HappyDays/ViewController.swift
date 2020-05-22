//
//  ViewController.swift
//  HappyDays
//
//  Created by Lasse Silkoset on 16/05/2020.
//  Copyright © 2020 Lasse Silkoset. All rights reserved.
//

import UIKit
import AVFoundation
import Photos
import Speech

class ViewController: UIViewController {
    
    let descriptionLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 22)
        label.text = "In order to work fully, Happy Days needs to read your photo library, record your voice, and transcribe what you said. When you click the button below you will be asked to grant those permissions, but you can change your mind later in Settings."
        return label
    }()
    
    lazy var continueButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Continue", for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 32)
        btn.addTarget(self, action: #selector(handleContinueTapped), for: .touchUpInside)
        return btn
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        view.backgroundColor = .white
        
        title = "Welcome"
        setupLayout()
    }
    
    fileprivate func requestPhotoPermissions() {
        PHPhotoLibrary.requestAuthorization { [weak self] (authStatus) in
            
            DispatchQueue.main.async {
                if authStatus == .authorized {
                    self?.requestRecordPermission()
                } else {
                    self?.descriptionLabel.text = "Photos permissions was declined; Please enable it in settings and tap continue again"
                }
            }
        }
    }
    
    fileprivate func requestRecordPermission() {
        
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] (allowed) in
            
            DispatchQueue.main.async {
                if allowed {
                    self?.requestTranscribePermissions()
                } else {
                    self?.descriptionLabel.text = "Recording permission was declined; Please enable it in settings and try again."
                }
            }
        }
    }
    
    fileprivate func requestTranscribePermissions() {
        SFSpeechRecognizer.requestAuthorization { [weak self] (authStatus) in
            
            DispatchQueue.main.async {
                if authStatus == .authorized {
                self?.authorizationComplete()
            } else {
                    self?.descriptionLabel.text = "Transcription permission was declined; Please enable it in settings and try again."
                }
            }
        }
    }
    
    fileprivate func authorizationComplete() {
        
        dismiss(animated: true, completion: nil)
    }
    
    @objc fileprivate func handleContinueTapped() {
        requestPhotoPermissions()
    }
    
    fileprivate func setupLayout() {
        let stack = UIStackView(arrangedSubviews: [descriptionLabel, continueButton])
        stack.axis = .vertical
        stack.spacing = 46
        
        view.addSubview(stack)
        stack.anchor(top: nil, leading: view.leadingAnchor, bottom: nil, trailing: view.trailingAnchor, padding: .init(top: 0, left: 16, bottom: 0, right: 16))
        stack.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
    }


}

