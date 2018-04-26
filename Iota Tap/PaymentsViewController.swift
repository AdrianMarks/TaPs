//
//  PaymentsViewController.swift
//  Iota Tap
//
//  Created by Redkite - Adrian Marks on 22/03/2018.
//  Copyright © 2018 Red Kite Projects Limited. All rights reserved.
//

import UIKit
import SwiftKeychainWrapper

class PaymentsViewController: UIViewController {

    fileprivate var savedIndex: Int? {
        get {
            return KeychainWrapper.standard.integer(forKey: TAPConstants.kIndex)
        }
        set {
            KeychainWrapper.standard.set(newValue!, forKey: TAPConstants.kIndex)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        
        savedIndex = 0
    
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

