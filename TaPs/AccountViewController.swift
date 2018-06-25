//
//  AccountViewController.swift
//  TaPs
//
//  Created by Redkite - Adrian Marks on 22/03/2018.
//  Copyright © 2018 Red Kite Projects Limited. All rights reserved.
//

import UIKit
import IotaKit
import SwiftKeychainWrapper
import CoreBluetooth

class AccountViewController: UIViewController, UITextFieldDelegate {

    //Keychain Data
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
    fileprivate var savedBTStatus: String? {
        get {
            return KeychainWrapper.standard.string(forKey: TAPConstants.kBTStatus)
        }
        set {
            KeychainWrapper.standard.set(newValue!, forKey: TAPConstants.kBTStatus)
        }
    }
    fileprivate var savedAddress: String? {
        get {
            return KeychainWrapper.standard.string(forKey: TAPConstants.kAddress)
        }
        set {
            KeychainWrapper.standard.set(newValue!, forKey: TAPConstants.kAddress)
        }
    }
    
    //Data
    var avatarCaptureController = AvatarCaptureController()
    
    //UI
    @IBOutlet weak var passcodeSwitch: UISwitch!
    @IBOutlet weak var avatarName: UITextField!
    @IBOutlet weak var seed: UITextField!
    @IBOutlet weak var checkSum: UILabel!
    @IBOutlet weak var bluetoothSwitch: UISwitch!

    @IBOutlet weak var avatarView: UIView!
    
    //UI Actions
    @IBAction func cameraButton(_ sender: UIButton) {
        avatarCaptureController.startCapture()
    }
    
    @IBAction func avatarNameChanged(_ sender: Any) {
        savedAvatarName = avatarName.text!
        dataToSend = ((savedAvatarName)?.data(using: String.Encoding(rawValue: String.Encoding.utf8.rawValue))!)!
        transferCharacteristic = nameCharacteristic
        
        //Set fragment length to default
        NOTIFY_MTU = default_MTU
        
        // Reset the index
        sendDataIndex = 0;
        
        // Start sending
        peripheralManager.sendData()
        
    }
    @IBAction func seedEdited(_ sender: Any) {
        
        seed.text = seed.text?.uppercased()
        
        let string = "ABCDEFGHIJKLMNOPQRSTUVWXYZ9"
        let substring = seed.text!.suffix(1)
        if !string.contains(substring) {
            seed.text = String((seed.text?.dropLast())!)
        }
        
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
        
        accountManagement.retrieveAddress()
    
    }
    
    //View controller functions
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Looks for single or multiple taps.
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(AccountViewController.dismissKeyboard))
        
        //Uncomment the line below if you want the tap not to interfere and cancel other interactions.
        //tap.cancelsTouchesInView = false
        
        view.addGestureRecognizer(tap)
        
        // Do any additional setup after loading the view.
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
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        
        //Set up avatar image
        displayAvatar()
        
        //Retrieve Pin Number
        let retrievedPIN = KeychainWrapper.standard.string(forKey: ALConstants.kPincode)
        
        //Check pin status and set switch accordingly
        if (retrievedPIN != nil) {
            passcodeSwitch.isOn = true
        } else {
            passcodeSwitch.isOn = false
        }
        
        //Check Bluetooth status and set switch accordingly
        let retrievedBTStatus = KeychainWrapper.standard.string(forKey: TAPConstants.kBTStatus)
        if (retrievedBTStatus == "On") {
            bluetoothSwitch.isOn = true
        } else {
            bluetoothSwitch.isOn = false
        }
        
        passcodeSwitch.addTarget(self, action: #selector(pinStateChanged), for: UIControlEvents.valueChanged)
        
        bluetoothSwitch.addTarget(self, action: #selector(blueStateChanged), for: UIControlEvents.valueChanged)
        
    }
    
    //Manage change of Passcode switch state
    @objc func pinStateChanged(switchState: UISwitch) {
        
        savedAvatarName = avatarName.text
        
        if switchState.isOn {
            pin(.create)
        } else {
            pin(.deactive)
        }
    }
    
    //set-up and call AppLocker to handle Passcode actions
    func pin(_ mode: ALMode) {
        
        var appearance = ALAppearance()
        appearance.image = avatarCaptureController.image
        appearance.title = savedAvatarName
        appearance.isSensorsEnabled = false
        
        AppLocker.present(with: mode, and: appearance)
    }
    
    //Display Avatars - N.B. This will need altered post development phase
    func displayAvatar() {
        
        let readWriteFileFS = ReadWriteFileFS()
        
        avatarCaptureController = AvatarCaptureController()
        avatarCaptureController.delegate = self
        avatarCaptureController.image = readWriteFileFS.readFile("avatar_saved.jpg")
        avatarView.addSubview((avatarCaptureController.view)!)
        
    }
    
    //Manage change of Accept Payements & Tips switch state
    @objc func blueStateChanged(switchState: UISwitch) {
        
        //Put code to switch on and off Bluetooth here
        if switchState.isOn {
            savedBTStatus = "On"
            peripheralManager.startAdvertising()
            
        } else {
            savedBTStatus = "Off"
            peripheralManager.stopAdvertising()
            print("Stopped Advertising")
        }
        
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

//AvatarCaptureController extensions
extension AccountViewController: AvatarCaptureControllerDelegate {
    func imageSelected(image: UIImage) {
    
        print("Image selected")
        
        let readWriteFileFS = ReadWriteFileFS()

        dataToSend = (UIImagePNGRepresentation(readWriteFileFS.readFile("small_avatar_saved.jpg")) as Data?)!
        transferCharacteristic = imageCharacteristic
        
        //Set fragment length to default
        NOTIFY_MTU = default_MTU
        
        // Reset the index
        sendDataIndex = 0;
        
        // Start sending
        peripheralManager.sendData()
    }
    
    func imageSelectionCancelled() {
        print("Image selection cancelled")
    }
}






