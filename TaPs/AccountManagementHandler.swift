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

class IotaAccountManagementHandler: NSObject {
    
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
        
        if savedAddress != nil {
            iota.wereAddressesSpentFrom(addresses: [String(savedAddress!.prefix(81))],  { (success) in
      
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
                
                //Set fragment length to default
                NOTIFY_MTU = default_MTU
                
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
    
    //***** May be better to remove this now MainNet is working well *****
    public func attemptPromotion(tailHash: String, bundleHash: String) {
        
        //First check whether Transfer is promotable
        iota.isPromotable(tail: tailHash, { (success) in

            if success == true {
                print("Transfer is promotable")
                
                self.promoteTransfer(tailHash: tailHash, bundleHash: bundleHash )
                
            } else {
                
                print("Transfer no longer promotable - attempting re-attach")
                
                self.attemptReattach(bundleHash: bundleHash)
 
            }
        }, { (error) in
            print("Unable to confirm whether or not transfer was promotable")
        })
        
    }

    //***** May be better to remove this now MainNet is working well *****
    func attemptReattach(bundleHash: String) {
        
        /*
        //Reattach the Trytes
        iota.findTransactions(bundles: [bundleHash], { (hashes) in

            self.iota.trytes(hashes: hashes, { (trytes) in
                
                self.iota.sendTrytes(trytes: trytes, { (success) in
                    
                    print("Reattach Successful")
                    
                    //Update the last payment record status to "Reattached"
                    DispatchQueue.main.async {
                        if CoreDataHandler.updateReattachedPayment(bundleHash: bundleHash) {
                            print("Updated status of payment to 'Reattached' successfully")
                        } else {
                            print("Failed updating payment to 'Reattached' status")
                        }
                    }
                    
                }, error: { (error) in
                    print("Send Trytes failed - error is - \(error)")
                })
                
            }, error: { (error) in
                print("Unable to find Trytes - error is - \(error)")
            })
            
        }, error: { (error) in
            print("Unable to find Transactions - error is - \(error)")
        })
        */
        
    }
    
    //***** May be better to remove this now MainNet is working well *****
    func promoteTransfer(tailHash: String, bundleHash: String) {
        
        //Promoter the Transfer
        iota.promoteTransaction(hash: tailHash, { (success) in
                print("Promotion succeeded")

                //Update the last payment record status to "Promoted"
                DispatchQueue.main.async {
                    if CoreDataHandler.updatePromotedPayment(bundleHash: bundleHash) {
                        print("Updated status of payment to 'Promoted' successfully")
                    } else {
                        print("Failed updating payment to 'Promoted' status")
                    }
                }
            
            }, error: { (error) in
                print("Promotion failed with error - \(error)")
        })
        
    }
    
    public func attemptTransfer(address: String, amount: UInt64, message: String) {
        
        //Convert ASCII to Trytes
        let messageTrytes = IotaConverter.trytes(fromAsciiString: message)
        
        print("Message trytes are - \(String(describing: messageTrytes))")
        
        //Set transfer details
        let transfer = IotaTransfer(address: address, value: UInt64(amount), message: messageTrytes!, tag: "TAPS" )
        
        //Send the Transfer via the IOTA API
        iota.sendTransfers(seed: self.savedSeed!, transfers: [transfer], inputs: nil, remainderAddress: nil , { (success) in
            
            //ON SUCCESS
            
            print("First hash is - \(success[0].hash)")
            print("Last -1 hash is - \(success[success.endIndex - 1].hash)")
            print("Bundle hash is - \(success[0].bundle)")
            
            let bundleHash = success[0].bundle
            let tailHash = success[success.endIndex - 1].hash
            
            //Update the last payment record status to "Pending"
            DispatchQueue.main.async {
                if CoreDataHandler.updatePendingPayment(bundleHash: bundleHash, tailHash: tailHash) {
                    print("Updated status of payment to 'Pending' successfully")
                } else {
                    print("Failed updating payment to 'Pending' status")
                }
            }
            
            //Check to see whether the receipt address is still valid or has it just been used for this payment.
            //If it has then retrieve, store and update Centrals with new receipt address
            accountManagement.checkAddress()
            
            //Send Receipt to Payee
            print("attempting to send Receipt to Payee")
            DispatchQueue.main.async {
                
                //Send BundleHash and Message and Amount in one Bluetooth message
                var packedMessage: String = message
                packedMessage.rightPad(count: 33, character: " ")
                dataToSend = ((bundleHash + packedMessage + String(amount)).data(using: String.Encoding(rawValue: String.Encoding.utf8.rawValue))!)
                transferCharacteristic = receiptCharacteristic
                
                //Set fragment length to default
                NOTIFY_MTU = default_MTU
                
                // Reset the index
                sendDataIndex = 0;
                
                // Start sending
                peripheralManager.sendData()
            }
            
        }, error: { (error) in
            
            //ON ERROR
            
            //Send alert to screen with the returned error message
            let message = "\(error)"
            let alertController = UIAlertController(title: "TaPs Error Message", message:
                message , preferredStyle: UIAlertControllerStyle.alert)
            alertController.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.default,handler: nil))
            
            var rootViewController = UIApplication.shared.keyWindow?.rootViewController
            
            if let tabBarController = rootViewController as? UITabBarController {
                rootViewController = tabBarController.selectedViewController
            }
            rootViewController?.present(alertController, animated: true, completion: nil)
            
            //Update the last payment record status to "Failed
            DispatchQueue.main.async {
                if CoreDataHandler.updateFailedPayment() {
                    print("Updated status of payment to 'failed' successfully")
                } else {
                    print("Failed updating payment on IOTA API failure")
                }
            }
            
            print("API call to send transfer failed with error - \(error)")
        })
        
    }
    
}
