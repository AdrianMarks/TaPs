//
//  PeripheralManagerHandler.swift
//  TaPs
//
//  Created by Redkite - Adrian Marks on 22/03/2018.
//  Copyright © 2018 Red Kite Projects Limited. All rights reserved.
//

import SwiftKeychainWrapper
import CoreBluetooth
import IotaKit

class PeripheralManagerHandler: NSObject, CBPeripheralManagerDelegate {

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

    //Data
    var peripheralManager: CBPeripheralManager?
    var payeeReceiptBuild: String = ""
    var iotaStorage = IotaStorage()
    
    override init() {
        super.init()
        
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        print("Peripheral Manager Initialised")
    }
    
    public func initialise() {
        
    }

    //MARK: Core Bluetooth Peripheral Manager functions
    //Called when the peripheral manager changes state
    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        
        switch peripheral.state {
        case .unknown:
            print("peripheral.state is .unknown")
        case .resetting:
            print("peripheral.state is .resetting")
        case .unsupported:
            print("peripheral.state is .unsupported")
        case .unauthorized:
            print("peripheral.state is .unauthorized")
        case .poweredOff:
            print("peripheral.state is .poweredOff")
        case .poweredOn:
            print("peripheral.state is .poweredOn")
            
            receiptCharacteristic.value = nil
            nameCharacteristic.value = nil
            imageCharacteristic.value = nil
            addressCharacteristic.value = nil
            service.characteristics = [ receiptCharacteristic, nameCharacteristic, addressCharacteristic, imageCharacteristic]
            peripheralManager?.add(service)
            
            //Check if bluetooth status is and if so start advertising
            let retrievedBTStatus = KeychainWrapper.standard.string(forKey: TAPConstants.kBTStatus)
            if (retrievedBTStatus == "On") {
                self.startAdvertising()
            }
            
        }
    }
    
    //Called when the peripheral adds a service
    public func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error = error {
            print("error: \(error)")
            return
        }
        
        print("Service: \(service)")
    }
    
    //Called when the peripheral starts advertising its presence
    public func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            print("Failed… error: \(error)")
            return
        }
        print("Started Advertising")
    }
    
    /** Sends the next amount of data to the connected central
     */
    public func sendData() {
        if sendingEOM {
            // send it
            let didSend = peripheralManager?.updateValue(
                "EOM".data(using: String.Encoding.utf8)!,
                for: transferCharacteristic!,
                onSubscribedCentrals: nil
            )
            
            // Did it send?
            if (didSend == true) {
                
                // It did, so mark it as sent
                sendingEOM = false
                
                print("Sent: EOM")
            }
            
            // It didn't send, so we'll exit and wait for peripheralManagerIsReadyToUpdateSubscribers to call sendData again
            return
        }
        
        // We're not sending an EOM, so we're sending data
        
        // Is there any left to send?
        guard sendDataIndex! < (dataToSend?.count)! else {
            // No data left.  Do nothing
            return
        }
        
        // There's data left, so send until the callback fails, or we're done.
        var didSend = true
        
        while didSend {
            // Make the next chunk
            
            // Work out how big it should be
            var amountToSend = dataToSend!.count - sendDataIndex!;
            
            // Can't be longer than 20 bytes
            if (amountToSend > NOTIFY_MTU) {
                amountToSend = NOTIFY_MTU;
            }
            
            // Copy out the data we want
            let chunk = dataToSend!.withUnsafeBytes{(body: UnsafePointer<UInt8>) in
                return Data(
                    bytes: body + sendDataIndex!,
                    count: amountToSend
                )
            }
            
            // Send it
            didSend = (peripheralManager!.updateValue(
                chunk as Data,
                for: transferCharacteristic!,
                onSubscribedCentrals: nil
            ))
            
            // If it didn't work, drop out and wait for the callback
            if (!didSend) {
                return
            }
            
            // It did send, so update our index
            sendDataIndex! += amountToSend;
            
            // Was it the last one?
            if (sendDataIndex! >= dataToSend!.count) {
                
                // It was - send an EOM
                
                // Set this so if the send fails, we'll send it next time
                sendingEOM = true
                
                // Send it
                let eomSent = peripheralManager?.updateValue(
                    "EOM".data(using: String.Encoding.utf8)!,
                    for: transferCharacteristic!,
                    onSubscribedCentrals: nil
                )
                
                if (eomSent)! {
                    // It sent, we're all done
                    sendingEOM = false
                    print("Sent: EOM")
                }
                
                return
            }
        }
    }
    
    /** This callback comes in when the PeripheralManager is ready to send the next chunk of data.
     *  This is to ensure that packets will arrive in the order they are sent
     */
    public func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        // Start sending again
        sendData()
    }
    
    //Check when someone subscribes to our characteristic.
    public func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        
        //Set maximum CB transfer fregment length
        NOTIFY_MTU = central.maximumUpdateValueLength
        if default_MTU < NOTIFY_MTU {default_MTU = NOTIFY_MTU }
        
        print("Device \(central) subscribed to characteristic - \(characteristic.uuid)")
        
        //******* Check Charateristic and set dataToSend and transferCharacteristic accordingly ******
        if characteristic.uuid.isEqual(imageCharacteristic_UUID) {
            dataToSend =  ((savedImageHash)?.data(using: String.Encoding(rawValue: String.Encoding.utf8.rawValue))!)!
            transferCharacteristic = imageCharacteristic
            
            // Reset the index
            sendDataIndex = 0;
            
            // Start sending
            sendData()
        }
        else if characteristic.uuid.isEqual(nameCharacteristic_UUID) {
            dataToSend = ((savedAvatarName)?.data(using: String.Encoding(rawValue: String.Encoding.utf8.rawValue))!)!
            transferCharacteristic = nameCharacteristic
            
            // Reset the index
            sendDataIndex = 0
            
            // Start sending
            sendData()
        }
        else if characteristic.uuid.isEqual(addressCharacteristic_UUID) {
            dataToSend = ((savedAddress)?.data(using: String.Encoding(rawValue: String.Encoding.utf8.rawValue))!)!
            transferCharacteristic = addressCharacteristic
            
            // Reset the index
            sendDataIndex = 0
            
            // Start sending
            sendData()
        }
        
    }
    
    //Receive Receipt
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
   
        print("Write request received")
        
        for request in requests
        {
            if request.characteristic.uuid.isEqual(receiptCharacteristic.uuid) {
                
                if let payeeReceiptFragment = String(data: request.value!, encoding: String.Encoding(rawValue: String.Encoding.utf8.rawValue)) {
                    
                    if payeeReceiptFragment != "EOM" {
                        payeeReceiptBuild = payeeReceiptBuild + payeeReceiptFragment
                    }
                    else
                    {
                        if payeeReceiptBuild != "" {
                            let bundleHash = String(payeeReceiptBuild.prefix(81))
                            let imageHash = payeeReceiptBuild.substring(from: 81, to: 162)
                            let payerNameLength = Int(payeeReceiptBuild.substring(from: 162, to: 164))
                            let payerName = payeeReceiptBuild.substring(from: 164, to: (164 + payerNameLength!))
                            let message = payeeReceiptBuild.substring(from: (164 + payerNameLength!), to: (197 + payerNameLength!))
                            let amount = payeeReceiptBuild.substring(from: (197 + payerNameLength!), to: payeeReceiptBuild.count)
                            
                            print("Retrieved Receipt for this Device Successfully!")
                            
                            print("Attempting Avatar Retrieve")
                            
                            iotaStorage.retrieve(bundleHash: imageHash, { (success) in
                                
                                print("Avatar Retrieve was successful")
                                
                                let tempPayeeAvatar:Data = UIImagePNGRepresentation(success)!
                                
                                //Update the UIImage View back on the main queue
                                DispatchQueue.main.async {
                                    
                                    //Save the receipt details in Core Data
                                    if CoreDataHandler.saveReceiptDetails(payerName: payerName, payerAvatar: tempPayeeAvatar, amount: Int64(amount)!, message: message, status: "Pending", timestamp: Date(),
                                                                          bundleHash: bundleHash, timeToConfirm: 0) {
                                        print("Receipt data saved sussfully")
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
                        payeeReceiptBuild = ""
                    }
                    
                    print("Payee Receipt Fragment = \(payeeReceiptFragment)")
                    peripheralManager?.respond(to: requests[0], withResult: .success)
                }
            }
        }
    }
    
    //Log when someone unsubscribes from our characteristic.
    public func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        print("Device \(central) unsubscribed from characteristic - \(characteristic.uuid)")
    }
    
    //start advertising the selected service
    public func startAdvertising() {
        
        if (savedSeed?.count == 81 && savedAddress?.count == 90) {
            peripheralManager?.startAdvertising([CBAdvertisementDataServiceUUIDsKey:[Service_UUID],
                                             CBAdvertisementDataLocalNameKey: advertisementData])
        }
    }
    
    //Stop advertising
    public func stopAdvertising() {
        peripheralManager?.stopAdvertising()
    }

}

