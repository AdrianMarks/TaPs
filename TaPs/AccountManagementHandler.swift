//
//  IotaAccountManagementHandler.swift
//  TaPs
//
//  Created by Adrian Marks on 13/06/2018.
//  Copyright © 2018 Red Kite Projects Limited. All rights reserved.
//

import Foundation
import SwiftKeychainWrapper
import IotaKit
import CoreBluetooth
import AudioToolbox

class IotaAccountManagementHandler: NSObject {
    
    //Data
    let iota = Iota(node: node)
    var transfers: [IotaTransfer] = []
    var iotaStorage = IotaStorage()
    
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
    fileprivate var savedImageHash: String? {
        get {
            return KeychainWrapper.standard.string(forKey: TAPConstants.kImageHash)
        }
        set {
            KeychainWrapper.standard.set(newValue!, forKey: TAPConstants.kImageHash)
        }
    }
    fileprivate var savedAvatarName: String? {
        get {
            return KeychainWrapper.standard.string(forKey: TAPConstants.kAvatar)
        }
        set {
            KeychainWrapper.standard.set(newValue!, forKey: TAPConstants.kAvatar)
        }
    }
    
    public func initialise() {
        
            checkOwnReceiptAddress()
            retrieveBalance()
        
            Timer.scheduledTimer(timeInterval: 300, target: self, selector: #selector(self.retrieveBalance), userInfo: nil, repeats: true)
            Timer.scheduledTimer(timeInterval: 60, target: self, selector: #selector(self.checkOwnReceiptAddress), userInfo: nil, repeats: true)
        
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
                        print("API call to retrieve the Balance failed with error -\(error)") }
                )
            }
        }
    }
    
    //Check whether the Received Receipt Address is still valid
    @objc public func checkOwnReceiptAddress() {
        
        if savedAddress?.count == 90 {
            iota.wereAddressesSpentFrom(addresses: [String(savedAddress!.prefix(81))],  { (success) in
                
                if success.contains(true) {
                    print("Receipt address nolonger valid - retrieving a new address")
                    self.retrieveAddress()
                }
            }, { (error) in
                print(error)
                print("Failed to check whether receipt address was valid")
            })
        }
    }
    
    //Retrieve the Address funds are to be sent to
    public func retrieveAddress() {
        
        if savedSeed?.count == 81 {
            self.iota.accountData(seed: savedSeed!, { (account) in
                print("address count - \(account.addresses.count)")
                self.savedAddress = IotaAPIUtils.newAddress(seed: self.savedSeed!, index: account.addresses.count, checksum: true)
                print("The account is \(account)")
                print("The new address is - \(String(describing: self.savedAddress))")
                
                //Attach the address to the tangle - so that it is not used as a remainder address in a subsequent payment
               
                //Pad message to 33 characters
                var packedMessage = "TaPs Receipt Address"
                packedMessage.rightPad(count: 33, character: " ")
                
                //Convert ASCII to Trytes
                let messageTrytes = IotaConverter.trytes(fromAsciiString: packedMessage)
                
                //Setup 0 Value transfer
                let transfer = IotaTransfer(address: self.savedAddress!, value: 0, message: messageTrytes!, tag: "TAPS" )
                
                //Send Transfer
                self.iota.sendTransfers(seed: self.savedSeed!, depth: 3, transfers: [transfer], inputs: nil, remainderAddress: nil , { (success) in
                    
                    //ON SUCCESS
                    
                    print("API call to attach address to tangle succeeded")
                    
                }, error: { (error) in
                    
                    //ON ERROR
                    
                    //Send alert to screen with the returned error message
                    var message = "\(error)"
                    if message.count > 45 {
                        //Use localized description if error message is long
                        message = "\(error.localizedDescription)"
                    }
                    let alertController = UIAlertController(title: "TaPs Error Message", message:
                        message , preferredStyle: UIAlertControllerStyle.alert)
                    alertController.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.default,handler: nil))
                    
                    var rootViewController = UIApplication.shared.keyWindow?.rootViewController
                    
                    if let tabBarController = rootViewController as? UITabBarController {
                        rootViewController = tabBarController.selectedViewController
                    }
                    rootViewController?.present(alertController, animated: true, completion: nil)
                    AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
                    
                    print("API call to attach new Receipt Address to tangle failed with error - \(error)")
                })
                
                dataToSend = ((self.savedAddress)?.data(using: String.Encoding(rawValue: String.Encoding.utf8.rawValue))!)
                transferCharacteristic = addressCharacteristic
                
                //Set fragment length to default
                NOTIFY_MTU = default_MTU
                
                // Reset the index
                sendDataIndex = 0;
                
                // Start sending
                peripheralManager.sendData()
                
            }, error: { (error) in
                print("API call to retrieve the new address failed with error -\(error)")
                
                //Send alert to screen with the returned error message
                var message = "\(error)"
                if message.count > 45 {
                    //Use localized description if error message is long
                    message = "\(error.localizedDescription)"
                }
                let alertController1 = UIAlertController(title: "TaPs Error Message", message:
                    message , preferredStyle: UIAlertControllerStyle.alert)
                alertController1.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.default,handler: nil))
                
                var rootViewController = UIApplication.shared.keyWindow?.rootViewController
                
                if let tabBarController = rootViewController as? UITabBarController {
                    rootViewController = tabBarController.selectedViewController
                }
                rootViewController?.present(alertController1, animated: true, completion: nil)
                AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
                

                //Send alert to screen with the returned error message
                message = "Please check that you are connected to the Internet. If you have just updated your Seed, please also re-enter the Seed once re-connected to the Internet."
     
                let alertController2 = UIAlertController(title: "TaPs Error Message", message:
                    message , preferredStyle: UIAlertControllerStyle.alert)
                alertController2.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.default,handler: nil))
                
                rootViewController = UIApplication.shared.keyWindow?.rootViewController
                
                if let tabBarController = rootViewController as? UITabBarController {
                    rootViewController = tabBarController.selectedViewController
                }
                rootViewController?.present(alertController2, animated: true, completion: nil)
                AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
                
            }, log: { (log) in
                print(log) }
            )
        }
    }
    
    //Check whther transaction is Promotable and if so Promote else Re-attach
    public func attemptPromotion(tailHash: String, bundleHash: String) {
        
        //First check whether Transfer is promotable
        iota.isPromotable(tail: tailHash, { (success) in

            if success == true {
                print("Transfer is promotable")
                
                self.promoteTransfer(tailHash: tailHash, bundleHash: bundleHash )
                
            } else {
                
                print("Transfer no longer promotable - attempting re-attach")
                self.attemptReattach(tailHash: tailHash, bundleHash: bundleHash )
 
            }
        }, { (error) in
            print("Unable to confirm whether or not transfer was promotable")
        })
        
    }

    //Automated Re-attach function
    func attemptReattach(tailHash: String, bundleHash: String) {
        
        //Replay the bundle
        iota.replayBundle(tx: tailHash, depth: 3, { (success) in
            
            print("Reattach succeeded")
            
            //Update the last payment record status to "Promoted"
            DispatchQueue.main.async {
                if CoreDataHandler.updateReattachedPayment(bundleHash: bundleHash) {
                    print("Updated status of payment to 'Reattached' successfully")
                } else {
                    print("Failed updating payment to 'Reattached' status")
                }
            }
            
            //Promote The transfer immediately
            self.promoteTransfer(tailHash: tailHash, bundleHash: bundleHash)
            
        }, error: { (error) in
            print("Unable to Reattach Transactions - error is - \(error)")
        })
        
    }
    
    //Automated Promote function
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
    
    public func attemptTransfer(address: String, amount: UInt64, message: String ) {
        
        //Pad message to 33 characters
        var packedMessage = message
        packedMessage.rightPad(count: 33, character: " ")
    
        //Convert ASCII to Trytes
        let messageTrytes = IotaConverter.trytes(fromAsciiString: packedMessage)! + savedImageHash! + IotaConverter.trytes(fromAsciiString: savedAvatarName!)!
        
        print("Message trytes are - \(String(describing: messageTrytes))")
        
        //Set value transfer details
        let transfer = IotaTransfer(address: address, value: UInt64(amount), message: messageTrytes, tag: "TAPS" )
        
        //Send the Transfer via the IOTA API
        iota.sendTransfers(seed: self.savedSeed!, depth: 3, transfers: [transfer], inputs: nil, remainderAddress: nil , { (success) in
            
            //ON SUCCESS
            
            print("First hash is - \(success[0].hash)")
            print("Last -1 hash is - \(success[success.endIndex - 1].hash)")
            print("Bundle hash is - \(success[0].bundle)")
            print("Timestamp is - \(success[0].attachmentTimestamp)")
            
            let bundleHash = success[0].bundle
            let tailHash = success[success.endIndex - 1].hash
            let timestamp = Date(timeIntervalSince1970: TimeInterval(success[0].attachmentTimestamp) / 1000)
            
            print("Converted Timestamp is - \(timestamp)")
            
            
            //Update the last payment record status to "Pending"
            DispatchQueue.main.async {
                if CoreDataHandler.updatePendingPayment(bundleHash: bundleHash, tailHash: tailHash, timestamp: timestamp) {
                    print("Updated status of payment to 'Pending' successfully")
                } else {
                    print("Failed updating payment to 'Pending' status")
                }
            }
            
            //Promote The transfer immediately
            self.promoteTransfer(tailHash: tailHash, bundleHash: bundleHash)
            
            //Check to see whether the receipt address is still valid or has it just been used for this payment.
            //If it has then retrieve, store and update Centrals with new receipt address
            accountManagement.checkOwnReceiptAddress()
            
        }, error: { (error) in
            
            //ON ERROR
            
            //Send alert to screen with the returned error message
            var message = "\(error)"
            if message.count > 45 {
                //Use localized description if error message is long
                message = "\(error.localizedDescription)"
            }
            let alertController = UIAlertController(title: "TaPs Error Message", message:
                message , preferredStyle: UIAlertControllerStyle.alert)
            alertController.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.default,handler: nil))
            
            var rootViewController = UIApplication.shared.keyWindow?.rootViewController
            
            if let tabBarController = rootViewController as? UITabBarController {
                rootViewController = tabBarController.selectedViewController
            }
            rootViewController?.present(alertController, animated: true, completion: nil)
            AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
            
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
    
    public func findReceipts() {
        
        var foundBundles: [String] = []
        
        if savedAddress?.count == 90 {
            let addresses = [String(savedAddress!.prefix(81))]
            
            iota.findTransactions(addresses: addresses, { (hashes) in
                
                self.iota.trytes(hashes: hashes, { (trytes) in
                
                    //ON SUCCESS
                    
                    for transaction in trytes {
                        
                        if transaction.tag == "TAPS99999999999999999999999" {
                        
                            if !foundBundles.contains(transaction.bundle) {
                                
                                foundBundles.append(transaction.bundle)
                            
                                //Check the Core Data back on the main queue
                                DispatchQueue.main.async {
                                
                                    if !CoreDataHandler.findReceiptDetails(bundleHash: transaction.bundle) {
                                        
                                        print("I was ere! - \(transaction.signatureFragments.substring(from: 0, to: 66))")
                                
                                        let message = IotaConverter.asciiString(fromTrytes: transaction.signatureFragments.substring(from: 0, to: 66))
                                        
                                        print("But was I ere! - \(String(describing: message))")
                                        
                                        let bundleHash = transaction.bundle
                                        let imageHash = transaction.signatureFragments.substring(from: 66, to: 147)
                                        let payerName = IotaConverter.asciiString(fromTrytes: transaction.signatureFragments.substring(from: 147, to: 207))
                                        let amount = transaction.value
                                        let timestamp = Date(timeIntervalSince1970: TimeInterval(transaction.attachmentTimestamp) / 1000)
                                        
                                        //Fix to exclude transfers created before update made to the messageFragment so that it holds the imageHash
                                        if imageHash != "999999999999999999999999999999999999999999999999999999999999999999999999999999999" {
                                            
                                            self.iotaStorage.retrieve(bundleHash: imageHash, { (success) in
                                                
                                                let payeeAvatar:Data = UIImagePNGRepresentation(success)!
                                                
                                                //Update the Core Data back on the main queue
                                                DispatchQueue.main.async {
                                                    
                                                    //Save the receipt details in Core Data
                                                    if CoreDataHandler.saveReceiptDetails(payerName: payerName!, payerAvatar: payeeAvatar, amount: Int64(amount), message: message!, status: "Pending", timestamp: timestamp,
                                                                                          bundleHash: bundleHash, timeToConfirm: 0) {
                                                        print("Receipt data saved successfully")
                                                    } else {
                                                        print("Failed to save Receipt data")
                                                    }
                                                    
                                                    //Limit the payment data stored in Core Data to 10 rows.
                                                    if CoreDataHandler.limitStoredReceipts() {
                                                        print("Successfully limited number of saved receipts")
                                                    } else {
                                                        print("Failed to limit number of saved receipts")
                                                    }
                                                }
                            
                                            }, error: { (error) in
                                                print("Retrieve from Tangle failed with error - \(error)")
                                            })
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                }, error: { (error) in
                    
                    //ON ERROR
                    
                    print("API call to find Trytes failed with error - \(error)")
                    
                })
                
            }, error: { (error) in
                
                //ON ERROR
                
                print("API call to find Receipts failed with error - \(error)")
                
            })
        }
    }
    
}
