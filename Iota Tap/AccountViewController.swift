//
//  AccountViewController.swift
//  Iota Tap
//
//  Created by Redkite - Adrian Marks on 22/03/2018.
//  Copyright © 2018 Red Kite Projects Limited. All rights reserved.
//

import UIKit
import IotaKit
import SwiftKeychainWrapper

enum TAPConstants {
    static let kAvatar = "avatar"
    static let kSeed = "seed"
    static let kIndex = "index"
    static let kBTStatus = "bluetooth"
}

class AccountViewController: UIViewController, UITextFieldDelegate {
    
    var avatarCaptureController = AvatarCaptureController()
    
    fileprivate var savedAvatarName: String? {
        get {
            return KeychainWrapper.standard.string(forKey: TAPConstants.kAvatar)
        }
        set {
            KeychainWrapper.standard.set(newValue!, forKey: TAPConstants.kAvatar)
        }
    }
    fileprivate var savedSeed: String? {
        get {
            return KeychainWrapper.standard.string(forKey: TAPConstants.kSeed)
        }
        set {
            KeychainWrapper.standard.set(newValue!, forKey: TAPConstants.kSeed)
        }
    }
    fileprivate var savedIndex: Int? {
        get {
            return KeychainWrapper.standard.integer(forKey: TAPConstants.kIndex)
        }
        set {
            KeychainWrapper.standard.set(newValue!, forKey: TAPConstants.kIndex)
        }
    }
    fileprivate var savedBTStatus: String? {
        get {
            return KeychainWrapper.standard.string(forKey: TAPConstants.kBTStatus)
        }
        set {
            KeychainWrapper.standard.set(newValue!, forKey: TAPConstants.kBTStatus)
        }
    }
    
    @IBOutlet weak var passcodeSwitch: UISwitch!
    
    @IBOutlet weak var avatarName: UITextField!

    @IBOutlet weak var seed: UITextField!
    
    @IBOutlet weak var checkSum: UILabel!
    
    @IBOutlet weak var bluetoothSwitch: UISwitch!
    
    @IBOutlet var avatar: UIImageView!

    @IBAction func cameraButton(_ sender: UIButton) {
        avatarCaptureController.startCapture()
    }
    
    @IBAction func avatarNameChanged(_ sender: Any) {
        savedAvatarName = avatarName.text
    }
    
    @IBAction func seedEdited(_ sender: Any) {
        
        seed.text = seed.text?.uppercased()
        
        if (seed.text?.count == 81) {
            let fullCheckSum: String = IotaChecksum.calculateChecksum(address: seed.text!)
            checkSum.text = String(fullCheckSum.suffix(3))
        }
        else if ((seed.text?.count)! <= 80 && (seed.text?.count)! > 0) {
            checkSum.text = "<81"
        }
        else if ((seed.text?.count)! > 81) {
            checkSum.text = ">81"
        }
        else {
            checkSum.text = "CHK"
        }
        
    }
    
    @IBAction func seedChanged(_ sender: Any) {
        savedSeed = seed.text
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Looks for single or multiple taps.
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(AccountViewController.dismissKeyboard))
        
        //Uncomment the line below if you want the tap not to interfere and cancel other interactions.
        //tap.cancelsTouchesInView = false
        
        view.addGestureRecognizer(tap)
        
        // Do any additional setup after loading the view.
        avatarCaptureController = AvatarCaptureController()
        avatarCaptureController.delegate = self
        let readWriteFileFS = ReadWriteFileFS()
        avatarCaptureController.image = readWriteFileFS.readFile("avatar_saved.jpg")
        avatar.addSubview((avatarCaptureController.view)!)
        
        avatarName.text = savedAvatarName
        seed.text = savedSeed
        
        if (seed.text?.count == 81) {
            let fullCheckSum: String = IotaChecksum.calculateChecksum(address: seed.text!)
            checkSum.text = String(fullCheckSum.suffix(3))
        }
        else if ((seed.text?.count)! <= 80 && (seed.text?.count)! > 0) {
            checkSum.text = "<81"
        }
        else if ((seed.text?.count)! > 81) {
            checkSum.text = ">81"
        }
        else {
            checkSum.text = "CHK"
        }
        
        avatarName.delegate = self
        seed.delegate = self
        
    }
    
    override open func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        
        //Check pin status and set switch accordingly
        let retrievedPIN = KeychainWrapper.standard.string(forKey: ALConstants.kPincode)
        if (retrievedPIN != nil) {
            passcodeSwitch.isOn = true
        } else {
            passcodeSwitch.isOn = false
        }
        
        //Check bluetooth status and set switch accordingly
        let retrievedBTStatus = KeychainWrapper.standard.string(forKey: TAPConstants.kBTStatus)
        if (retrievedBTStatus == "On") {
            bluetoothSwitch.isOn = true
        } else {
            bluetoothSwitch.isOn = false
        }
        
        passcodeSwitch.addTarget(self, action: #selector(pinStateChanged), for: UIControlEvents.valueChanged)
        
        bluetoothSwitch.addTarget(self, action: #selector(blueStateChanged), for: UIControlEvents.valueChanged)
        
        savedIndex = 2
        
    }
    
    @objc func pinStateChanged(switchState: UISwitch) {
        
        savedAvatarName = avatarName.text
        
        if switchState.isOn {
            pin(.create)
        } else {
            pin(.deactive)
        }
    }
    
    @objc func blueStateChanged(switchState: UISwitch) {
        
        //Put code to switch on and off Bluetooth here
        if switchState.isOn {
           savedBTStatus = "On"
        } else {
           savedBTStatus = "Off"
        }
        
        
    }
    
    func pin(_ mode: ALMode) {
        
        var appearance = ALAppearance()
        appearance.image = avatarCaptureController.image
        appearance.title = savedAvatarName
        appearance.isSensorsEnabled = false
        
        AppLocker.present(with: mode, and: appearance)
    }
    
    //Calls this function when the tap is recognized.
    @objc func dismissKeyboard() {
        //Causes the view (or one of its embedded text fields) to resign the first responder status.
        view.endEditing(true)

    }

    //Calls this function when the Return/Done key is pressed.
    func textFieldShouldReturn(_ scoreText: UITextField) -> Bool {
        self.view.endEditing(true)
        return true
    }

}

extension AccountViewController: AvatarCaptureControllerDelegate {
    func imageSelected(image: UIImage) {
        print("image Selected")
    }
    
    func imageSelectionCancelled() {
        print("image selection cancelled")
    }
}

