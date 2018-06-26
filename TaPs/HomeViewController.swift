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


class HomeViewController: UIViewController {
    
    //Data
    fileprivate var retrievedPIN = KeychainWrapper.standard.string(forKey: ALConstants.kPincode)
    fileprivate var retrievedAvatarName = KeychainWrapper.standard.string(forKey: TAPConstants.kAvatar)
    fileprivate var retrievedSeed = KeychainWrapper.standard.string(forKey: TAPConstants.kSeed)
    fileprivate var retrievedAddress = KeychainWrapper.standard.string(forKey: TAPConstants.kAddress)
    
    //View controller functinos
    override func viewDidLoad() {
        super.viewDidLoad()
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

