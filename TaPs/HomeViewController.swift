//
//  HomeViewController.swift
//  TaPs
//
//  Created by Redkite - Adrian Marks on 22/03/2018.
//  Copyright © 2018 Red Kite Projects Limited. All rights reserved.
//

import UIKit
import SwiftKeychainWrapper
import CoreBluetooth
import IotaKit


class HomeViewController: UIViewController {
    
    //Keychain Data
    fileprivate var savedImageHash: String? {
        get {
            return KeychainWrapper.standard.string(forKey: TAPConstants.kImageHash)
        }
        set {
            KeychainWrapper.standard.set(newValue!, forKey: TAPConstants.kImageHash)
        }
    }
    
    //Data
    fileprivate var retrievedPIN = KeychainWrapper.standard.string(forKey: ALConstants.kPincode)
    fileprivate var retrievedAvatarName = KeychainWrapper.standard.string(forKey: TAPConstants.kAvatar)
    fileprivate var retrievedSeed = KeychainWrapper.standard.string(forKey: TAPConstants.kSeed)
    fileprivate var retrievedAddress = KeychainWrapper.standard.string(forKey: TAPConstants.kAddress)
    fileprivate var retrievedImageHash = KeychainWrapper.standard.string(forKey: TAPConstants.kImageHash)
    
    var iotaStorage = IotaStorage()
    
    //View controller functinos
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Save default small_avatar imageHash if not set.
        if savedImageHash == nil {
        
            let image = #imageLiteral(resourceName: "small_avatar")
                
            iotaStorage.save(image: image, { (success) in
                print("Saved default small_avatar image to Tangle successfully!")
                print("BundleHash is - \(success)")
                
                DispatchQueue.main.async {
                    print("Saving default small_avatar Image Hash - \(self.savedImageHash!)")
                    self.savedImageHash = success
                    
                    dataToSend = ((self.savedImageHash)?.data(using: String.Encoding(rawValue: String.Encoding.utf8.rawValue))!)!
                    transferCharacteristic = imageCharacteristic
                    
                    //Set fragment length to default
                    NOTIFY_MTU = default_MTU
                    
                    // Reset the index
                    sendDataIndex = 0;
                    
                    // Start sending
                    peripheralManager.sendData()
                }
                
            }, error: { (error) in
                print("Save to Tangle failed with error - \(error)")
            })
        
        }
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        
        print("Retrieved PIN is \(retrievedPIN ?? "set to nil" )")
        print("Retrieved Avatar Name is \(retrievedAvatarName ?? "set to nil" )")
        print("Retrieved Seed is \(retrievedSeed ?? "set to nil" )")
        print("Retrieved Seed LENGTH is \(retrievedSeed?.count ?? 0 )")
        print("Retrieved Address is \(retrievedAddress ?? "set to nil" )")
        print("Retrieved Image Hash is \(retrievedImageHash ?? "set to nil" )")
        
        Thread.sleep(forTimeInterval: 1.5)
        
        let selectedVC: UITabBarController = storyboard?.instantiateViewController(withIdentifier: "tabBarController") as! UITabBarController
        UIApplication.shared.keyWindow?.rootViewController = selectedVC
        
        if (retrievedSeed == "" || retrievedSeed == nil) {
            selectedVC.selectedIndex = 3
        } else {
            selectedVC.selectedIndex = 0
        }
        
        present(selectedVC, animated: false, completion: nil)
        
    }

}

