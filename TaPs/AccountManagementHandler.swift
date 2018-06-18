//
//  AccountBalanceUtility.swift
//  TaPs
//
//  Created by Adrian Marks on 13/06/2018.
//  Copyright © 2018 Red Kite Projects Limited. All rights reserved.
//

import Foundation
import SwiftKeychainWrapper
import IotaKit

class AccountManagementHandler: NSObject {
    
    //Data
    let iota = Iota(node: node)
    
    //Keychain Data
    fileprivate var savedSeed: String? {
        get {
            return KeychainWrapper.standard.string(forKey: TAPConstants.kSeed)
        }
        set {
            KeychainWrapper.standard.set(newValue!, forKey: TAPConstants.kSeed)
        }
    }
    fileprivate var savedBalance: String? {
        get {
            return KeychainWrapper.standard.string(forKey: TAPConstants.kBalance)
        }
        set {
            KeychainWrapper.standard.set(newValue!, forKey: TAPConstants.kBalance)
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
    
    public func initialise() {
        
        checkAddress()
        retrieveBalance()
        
        Timer.scheduledTimer(timeInterval: 300, target: self, selector: #selector(self.retrieveBalance), userInfo: nil, repeats: true)
        Timer.scheduledTimer(timeInterval: 60, target: self, selector: #selector(self.checkAddress), userInfo: nil, repeats: true)
    }
    
    //Update the account balance
    @objc func retrieveBalance() {
    
        if savedSeed?.count == 81 {
            //Do this call to Iota using the DCG queue so it runs concurrently
            DispatchQueue.global(qos: .userInitiated).async {
                //Obtain the account balance
                self.iota.accountData(seed: self.savedSeed!, { (account) in

                    //Update the UI back on the main queue
                    DispatchQueue.main.async {
                        self.savedBalance = IotaUnitsConverter.iotaToString(amount: UInt64(account.balance))
                    }
                    
                    }, error: { (error) in
                        print("API call to retrieve the no of addresses failed with error -\(error)") }
                )
            }
        }
    }
    
    @objc public func checkAddress() {
        
        iota.wereAddressesSpentFrom(addresses: [String(savedAddress!.prefix(81))],  { (success) in
            print(success)
            if success.contains(true) {
                print("Receipt address nolonger valid - retrieving a new address")
                self.retrieveAddress()
            } else {
                print("Address is still valid")
            }
        }, { (error) in
            print(error)
            print("Failed to check whether receipt address was valid")
        })
    }
    
    //Update the account balance
    public func retrieveAddress() {
        
        if savedSeed?.count == 81 {
            self.iota.accountData(seed: savedSeed!, { (account) in
                print("address count - \(account.addresses.count)")
                self.savedAddress = IotaAPIUtils.newAddress(seed: self.savedSeed!, index: account.addresses.count, checksum: true)
                print("The account is \(account)")
                print("The new address is - \(String(describing: self.savedAddress))")
                
                dataToSend = ((self.savedAddress)?.data(using: String.Encoding(rawValue: String.Encoding.utf8.rawValue))!)
                transferCharacteristic = addressCharacteristic
                
                print("Data to Send - \(String(describing: dataToSend))")
                
                // Reset the index
                sendDataIndex = 0;
                
                // Start sending
                peripheralManager.sendData()
                
            }, error: { (error) in
                print("API call to retrieve the no of addresses failed with error -\(error)")
            }, log: { (log) in
                print(log) }
            )
        }
    }
}
