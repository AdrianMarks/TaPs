//
//  HomeViewController.swift
//  Iota Tap
//
//  Created by Redkite - Adrian Marks on 22/03/2018.
//  Copyright © 2018 Red Kite Projects Limited. All rights reserved.
//

import UIKit
import SwiftKeychainWrapper

class HomeViewController: UIViewController {
    
    fileprivate var retrievedPIN = KeychainWrapper.standard.string(forKey: ALConstants.kPincode)
    fileprivate var retrievedAvatarName = KeychainWrapper.standard.string(forKey: TAPConstants.kAvatar)
    fileprivate var retrievedSeed = KeychainWrapper.standard.string(forKey: TAPConstants.kSeed)
    fileprivate var retrievedIndex = KeychainWrapper.standard.integer(forKey: TAPConstants.kIndex)
    
    // retrieve avatar image
    

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        
        Thread.sleep(forTimeInterval: 2.0)
        
        print("Retrieved PIN is \(retrievedPIN ?? "set to nil" )")
        print("Retrieved Avatar Name is \(retrievedAvatarName ?? "set to nil" )")
        print("Retrieved Seed is \(retrievedSeed ?? "set to nil" )")
        print("Retrieved Seed LENGTH is \(retrievedSeed?.count ?? 0 )")
        print("Retrieved Index is \(String(describing: retrievedIndex))")
        
        let selectedVC: UITabBarController = storyboard?.instantiateViewController(withIdentifier: "tabBarController") as! UITabBarController
        UIApplication.shared.keyWindow?.rootViewController = selectedVC
        if (retrievedSeed == nil) {
            selectedVC.selectedIndex = 2
        } else {
            selectedVC.selectedIndex = retrievedIndex!
        }
        
        present(selectedVC, animated: false, completion: nil)
        
        if (retrievedPIN != nil) {
            pin(.validate)
        }
        
    }
    
    func pin(_ mode: ALMode) {
        
        var appearance = ALAppearance()
        let readWriteFileFS = ReadWriteFileFS()
        appearance.image = readWriteFileFS.readFile("avatar_saved.jpg")
        appearance.title = retrievedAvatarName
        appearance.isSensorsEnabled = false
        
        AppLocker.present(with: mode, and: appearance)
    }

}

