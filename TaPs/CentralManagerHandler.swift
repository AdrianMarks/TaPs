//
//  CentralManagerHandler.swift
//  TaPs
//
//  Created by Redkite - Adrian Marks on 22/03/2018.
//  Copyright © 2018 Red Kite Projects Limited. All rights reserved.
//

import SwiftKeychainWrapper
import CoreBluetooth
import IotaKit

var xCharacteristic : CBCharacteristic?
var characteristicASCIIValue = String()

struct payee {
    var payeeDevice: CBPeripheral? = nil
    var payeeDeviceName: String? = ""
    var payeeName: String?  = ""
    var payeeAvatar: Data = Data()
    var payeeAddress: String? = nil
    var timestamp: Date = Date()
}

struct subscribedCharacteristic {
    var peripheral: CBPeripheral? = nil
    var characteristic: CBCharacteristic?  = nil
}

var payees: [payee] = []
var payeesBuild: [payee] = []
var payeesBuilt: [payee] = []
var subscribedCharacteristics: [subscribedCharacteristic] = []
var peripherals: [CBPeripheral] = []
var path = IndexPath()

class CentralManagerHandler: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    //Data
    var centralManager: CBCentralManager!
    var payeeReceiptBuild: String = ""
    var scanCount: Int = 0
    
    var timer = Timer()
    
    override init() {
        super.init()
        
        centralManager = CBCentralManager(delegate: self, queue: nil)
        print("Central Manager Initialised")
    }
    
    public func initialise() {
        
    }
    
    //Core Bluetooth Central Manager functions
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
        switch central.state {
        case .unknown:
            print("central.state is .unknown")
        case .resetting:
            print("central.state is .resetting")
        case .unsupported:
            print("central.state is .unsupported")
        case .unauthorized:
            print("central.state is .unauthorized")
        case .poweredOff:
            print("central.state is .poweredOff")
        case .poweredOn:
            print("central.state is .poweredOn")
            
            startScan()
            
        }
    }
    
    // Called when we want to start scanning for more TaPs devices
    @objc func startScan() {
        print("Started Scanning")
        self.timer.invalidate()
        
        //Remove aged peripherals in case they've just gone away
        disconnectAgedPeripherals()
        
        centralManager?.scanForPeripherals(withServices: [Service_UUID] , options: [CBCentralManagerScanOptionAllowDuplicatesKey:false])
        Timer.scheduledTimer(timeInterval: 60, target: self, selector: #selector(self.cancelScan), userInfo: nil, repeats: false)
    }
    
    // Called when we want to stop scanning for more TaPs devices
    @objc func cancelScan() {
        centralManager.stopScan()
        print("Stopped Scanning")
        Timer.scheduledTimer(timeInterval: 60, target: self, selector: #selector(self.startScan), userInfo: nil, repeats: false)
    }
    
    public func ceaseScanAltogether() {
        if (centralManager != nil) {
            print("Ceased Scanning Altogether")
            centralManager.stopScan()
        }
    }
    
    // Called when the central manager discovers a peripheral while scanning.
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        
        print("Discovered peripheral")
        
        //Check to make sure we've not already found this peripheral
        if !payeesBuild.contains(where: { $0.payeeDevice?.identifier == peripheral.identifier }) {
            
            //Set-up payee record in payees array and payeesBuild
            payeesBuild.append(payee(payeeDevice: peripheral, payeeDeviceName: peripheral.name ?? "Unknown", payeeName: "", payeeAvatar: Data(), payeeAddress: "", timestamp: Date() ))
            payeesBuilt.append(payee(payeeDevice: peripheral, payeeDeviceName: peripheral.name ?? "Unknown", payeeName: "", payeeAvatar: Data(), payeeAddress: "", timestamp: Date() ))
            
            peripherals.append(peripheral)
            peripheral.delegate = self
        
            //print(peripheral)
            //if  iotaTapPeripheral != nil {
                print("Found new peripheral devices with the IOTA TAP service")
                print("Device name: \(peripheral.name ?? "Unknown")")
                print("**********************************")
                //print ("Advertisement Data : \(advertisementData)")
                print ("Advertisement Data : \(advertisementData["kCBAdvDataLocalName"] ?? "Unknown")")
            //}
            
            //Connect to the peripheral
            connectToDevice(peripheral: peripheral)
            
        }
        
    }
    
    //Called to invoke a connection to a peripheral device
    func connectToDevice (peripheral: CBPeripheral) {
        centralManager?.connect(peripheral, options: nil)
    }
    
    //Called when a connection is successfully created with a peripheral.
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("**********************************")
        print("Connection complete")
        
        //Discovery callback
        peripheral.delegate = self
        
        //Only look for services that matches required uuid
        peripheral.discoverServices([Service_UUID])
        
    }
    
    //Called when the central manager fails to create a connection with a peripheral.
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        if error != nil {
            print("Failed to connect to peripheral")
            return
        }
    }
    
    /*
     Invoked when you discover the peripheral’s available services.
     This method is invoked when your app calls the discoverServices(_:) method. If the services of the peripheral are successfully discovered, you can access them through the peripheral’s services property. If successful, the error parameter is nil. If unsuccessful, the error parameter returns the cause of the failure.
     */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("**********************************")
        
        if ((error) != nil) {
            print("Error discovering services: \(error!.localizedDescription)")
            return
        }

        //Check for services and the discover the Characteristics
        guard let services = peripheral.services else {
            return
        }
        //We need to discover the all characteristic
        for service in services {
            
            peripheral.discoverCharacteristics(nil, for: service)
            
        }
        print("No of Services found: \(services.count)")
        print("Discovered Services: \(services)")
        
    }
    
    /*
     Invoked when you discover the characteristics of a specified service.
     This method is invoked when your app calls the discoverCharacteristics(_:for:) method. If the characteristics of the specified service are successfully discovered, you can access them through the service's characteristics property. If successful, the error parameter is nil. If unsuccessful, the error parameter returns the cause of the failure.
     */
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        print("**********************************")
        
        if ((error) != nil) {
            print("Error discovering services: \(error!.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else {
            return
        }
        
        print("Found \(characteristics.count) characteristics!")
        
        for characteristic in characteristics {
            
            //Subscribe to each characteristic
            if (characteristic.uuid == nameCharacteristic.uuid || characteristic.uuid == imageCharacteristic.uuid  || characteristic.uuid == addressCharacteristic.uuid  || characteristic.uuid == receiptCharacteristic.uuid) {
                print("Found valid characteristics! - \(characteristic.uuid)")
                subscribedCharacteristics.append(subscribedCharacteristic(peripheral: peripheral, characteristic: characteristic))
                
                peripheral.setNotifyValue(true, for: characteristic)
            }
            
        }
        
    }
    
    /* Getting Values From Characteristic
     This func assumes data may come in multiple fragments and recombines the data accordingly
     */
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        print("**********************************")
        
        if ((error) != nil) {
            print("Error recieving characteristic value : \(error!.localizedDescription)")
            print(error!)
            return
        }
        
        if characteristic.uuid == nameCharacteristic.uuid {
            
            print("nameCharacteristic is - \(nameCharacteristic.uuid)")
            
            if let payeeNameFragment = String(data: characteristic.value!, encoding: String.Encoding(rawValue: String.Encoding.utf8.rawValue)) {
                
                if payeeNameFragment != "EOM" {
                    if let index = payeesBuild.index(where: { $0.payeeDevice == peripheral}) {
                        let tempPayeeAvatar = payeesBuild[index].payeeAvatar
                        let tempPayeeAddress = payeesBuild[index].payeeAddress
                        let tempPayeeDeviceName = payeesBuild[index].payeeDeviceName
                        var tempPayeeName = payeesBuild[index].payeeName
                        tempPayeeName = tempPayeeName! + payeeNameFragment
                        payeesBuild.remove(at: index)
                        payeesBuild.append(payee(payeeDevice: peripheral, payeeDeviceName: tempPayeeDeviceName, payeeName: tempPayeeName, payeeAvatar: tempPayeeAvatar, payeeAddress: tempPayeeAddress, timestamp: Date() ))
                    }
                }
                else
                {
                    if let payeesIndex = payeesBuilt.index(where: { $0.payeeDevice == peripheral}) {
                        let payeesBuildIndex = payeesBuild.index(where: { $0.payeeDevice == peripheral})
                        let tempPayeeAvatar = payeesBuilt[payeesIndex].payeeAvatar
                        let tempPayeeAddress = payeesBuilt[payeesIndex].payeeAddress
                        let tempPayeeDeviceName = payeesBuilt[payeesIndex].payeeDeviceName
                        let tempPayeeName = payeesBuild[payeesBuildIndex!].payeeName
                        payeesBuilt.remove(at: payeesIndex)
                        payeesBuilt.append(payee(payeeDevice: peripheral, payeeDeviceName: tempPayeeDeviceName, payeeName: tempPayeeName, payeeAvatar: tempPayeeAvatar, payeeAddress: tempPayeeAddress, timestamp: Date() ))
                        payeesBuild[payeesBuildIndex!].payeeName = ""
                        print("BUILT NAME - Payee Device Name is \(tempPayeeDeviceName!) - Payee Name is \(tempPayeeName!) - Payee Avatar Count is \(tempPayeeAvatar.count) - Payee Address Count is \(tempPayeeAddress!.count)")
                    }
                    print("Payee Name End of Message found")
                }
                
                print("Payee Name Fragment = \(payeeNameFragment)")
                
            }
            
        }
        
        if characteristic.uuid == imageCharacteristic.uuid {
            
            print("imageCharacteristic is - \(imageCharacteristic.uuid)")
            
            let payeeAvatarFragment = characteristic.value!
            
            if let payeeAvatarFragmentString = String(data: characteristic.value!, encoding: String.Encoding(rawValue: String.Encoding.utf8.rawValue)) {
                if payeeAvatarFragmentString == "EOM" {
                    
                    print("Payee Avatar End of Message found")
                    
                    if let payeesIndex = payeesBuilt.index(where: { $0.payeeDevice == peripheral}) {
                        let payeesBuildIndex = payeesBuild.index(where: { $0.payeeDevice == peripheral})
                        let tempPayeeName = payeesBuilt[payeesIndex].payeeName
                        let tempPayeeAddress = payeesBuilt[payeesIndex].payeeAddress
                        let tempPayeeDeviceName = payeesBuilt[payeesIndex].payeeDeviceName
                        let tempPayeeAvatar = payeesBuild[payeesBuildIndex!].payeeAvatar
                        payeesBuilt.remove(at: payeesIndex)
                        payeesBuilt.append(payee(payeeDevice: peripheral, payeeDeviceName: tempPayeeDeviceName, payeeName: tempPayeeName, payeeAvatar: tempPayeeAvatar, payeeAddress: tempPayeeAddress, timestamp: Date() ))
                        payeesBuild[payeesBuildIndex!].payeeAvatar = Data()
                        print("PayeeAvatar is - \(String(describing: tempPayeeAvatar))")
                        print("BUILT AVATAR - Payee Device Name is \(tempPayeeDeviceName!) - Payee Name is \(tempPayeeName!) - Payee Avatar Count is \(tempPayeeAvatar.count) - Payee Address Count is \(tempPayeeAddress!.count)")
                    }
                }
            }
            else
            {
                if let index = payeesBuild.index(where: { $0.payeeDevice == peripheral}) {
                    let tempPayeeName = payeesBuild[index].payeeName
                    let tempPayeeAddress = payeesBuild[index].payeeAddress
                    let tempPayeeDeviceName = payeesBuild[index].payeeDeviceName
                    var tempPayeeAvatar = payeesBuild[index].payeeAvatar
                    tempPayeeAvatar = tempPayeeAvatar + payeeAvatarFragment
                    payeesBuild.remove(at: index)
                    payeesBuild.append(payee(payeeDevice: peripheral, payeeDeviceName: tempPayeeDeviceName, payeeName: tempPayeeName, payeeAvatar: tempPayeeAvatar, payeeAddress: tempPayeeAddress, timestamp: Date() ))
                    print("Accumulated payeeAvater - \(String(describing: tempPayeeAvatar)) - for Device Name - \(tempPayeeDeviceName!)")
                }
                print("Received: \(String(describing: payeeAvatarFragment))")
            }
            
        }
        
        if characteristic.uuid == addressCharacteristic.uuid {
            
            print("addressCharacteristic is - \(addressCharacteristic.uuid)")
            
            if let payeeAddressFragment = String(data: characteristic.value!, encoding: String.Encoding(rawValue: String.Encoding.utf8.rawValue)) {
                
                if payeeAddressFragment != "EOM" {
                    if let index = payeesBuild.index(where: { $0.payeeDevice == peripheral}) {
                        let tempPayeeAvatar = payeesBuild[index].payeeAvatar
                        let tempPayeeName = payeesBuild[index].payeeName
                        let tempPayeeDeviceName = payeesBuild[index].payeeDeviceName
                        var tempPayeeAddress = payeesBuild[index].payeeAddress
                        tempPayeeAddress = tempPayeeAddress! + payeeAddressFragment
                        payeesBuild.remove(at: index)
                        payeesBuild.append(payee(payeeDevice: peripheral, payeeDeviceName: tempPayeeDeviceName, payeeName: tempPayeeName, payeeAvatar: tempPayeeAvatar, payeeAddress: tempPayeeAddress, timestamp: Date() ))
                    }
                }
                else
                {
                    if let payeesIndex = payeesBuilt.index(where: { $0.payeeDevice == peripheral}) {
                        let payeesBuildIndex = payeesBuild.index(where: { $0.payeeDevice == peripheral})
                        let tempPayeeAvatar = payeesBuilt[payeesIndex].payeeAvatar
                        let tempPayeeName = payeesBuilt[payeesIndex].payeeName
                        let tempPayeeDeviceName = payeesBuilt[payeesIndex].payeeDeviceName
                        let tempPayeeAddress = payeesBuild[payeesBuildIndex!].payeeAddress
                        payeesBuilt.remove(at: payeesIndex)
                        payeesBuilt.append(payee(payeeDevice: peripheral, payeeDeviceName: tempPayeeDeviceName, payeeName: tempPayeeName, payeeAvatar: tempPayeeAvatar, payeeAddress: tempPayeeAddress, timestamp: Date() ))
                        payeesBuild[payeesBuildIndex!].payeeAddress = ""
                        print("BUILT ADDRESS - Payee Device Name is \(tempPayeeDeviceName!) - Payee Name is \(tempPayeeName!) - Payee Avatar Count is \(tempPayeeAvatar.count) - Payee Address Count is \(tempPayeeAddress!.count)")
                    }
                    print("Payee Address End of Message found")
                }
                
                print("Payee Address Fragment = \(payeeAddressFragment)")
                
            }
            
        }
        
        if characteristic.uuid == receiptCharacteristic.uuid {
            
            print("receiptCharacteristic is - \(receiptCharacteristic.uuid)")
            
            if let payeeReceiptFragment = String(data: characteristic.value!, encoding: String.Encoding(rawValue: String.Encoding.utf8.rawValue)) {
                
                if payeeReceiptFragment != "EOM" {
                    payeeReceiptBuild = payeeReceiptBuild + payeeReceiptFragment
                }
                else
                {
                    if payeeReceiptBuild != "" {
                        if let index = payees.index(where: { $0.payeeDevice == peripheral}) {
                            let tempPayeeAvatar = payees[index].payeeAvatar
                            let tempPayeeName = payees[index].payeeName
                            
                            let bundleHash = String(payeeReceiptBuild.prefix(81))
                            let message = payeeReceiptBuild.substring(from: 81, to: 114)
                            let amount = payeeReceiptBuild.substring(from: 114, to: payeeReceiptBuild.count)
                            
                            //Save the receipt details in Core Data
                            if CoreDataHandler.saveReceiptDetails(payerName: tempPayeeName!, payerAvatar: tempPayeeAvatar, amount: Int64(amount)!, message: message, status: "Pending", timestamp: Date(), bundleHash: bundleHash, timeToConfirm: 0) {
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
                    }
                    payeeReceiptBuild = ""
                }
                
                print("Payee Receipt Fragment = \(payeeReceiptFragment)")
                
            }
            
        }
        
        //What does this do?
        NotificationCenter.default.post(name:NSNotification.Name(rawValue: "Notify"), object: nil)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        print("**********************************")
        
        if (error != nil) {
            print("Error changing notification state:\(String(describing: error?.localizedDescription))")
        }
        
        if (characteristic.isNotifying) {
            print ("Subscribed. Notification has begun for: \(characteristic.uuid)")
        }
        else
        {
            print ("Subscribed. Notification has stopped for: \(characteristic.uuid)")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        print("Service has been modified")
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected")
        
        print("BUILT - Clearing down Build and Built arrays")
        //Remove peripheral from list of known payeesBuilt and payeesBuild arrays
        if let index = payeesBuild.index(where: { $0.payeeDevice == peripheral}) {
            print("Removing - \(payeesBuild[index].payeeName!) from payeesBuild")
            payeesBuild.remove(at: index)
            if let index = payeesBuilt.index(where: { $0.payeeDevice == peripheral}) {
                print("Removing - \(payeesBuilt[index].payeeName!) from payeesBuilt")
                payeesBuilt.remove(at: index)
            }
        }
        
    }
    
    public func unsubscribeAll() {
        
        print("Unsubscribing from all peripherals")
        
        for device in peripherals {

            //Unsubscribe from existing characteristics for this peripheral
            for index in 0..<(subscribedCharacteristics.count) {
                if device == subscribedCharacteristics[index].peripheral {
                    let characteristic = subscribedCharacteristics[index].characteristic!
                    // Unsubscribe from a characteristic
                    print("Unsubscribing from Char - \(characteristic) on Device \(String(describing: device))")
                    device.setNotifyValue(false, for: characteristic)
                }
            }
            
            //Then diconnect from the peripheral and remove the peripheral from the list of peripherals
            centralManager.cancelPeripheralConnection(device)
    
        }
        
        if (centralManager != nil) {
            print("Stopped Scanning")
            centralManager.stopScan()
        }
        
    }
    
    public func disconnectAgedPeripherals() {
        
        print("Disconnecting from aged peripherals")
        print("Peripherals contains - \(peripherals)")
        
        //Clean up Bluetooth connections where the device hasn't been active for more than 300 seconds
        //First unsubscribe all Characteristics and then disconnect Peripheral else when we re-subscribe nothing will happen
        for device in peripherals {
            if let index = payeesBuild.index(where: { $0.payeeDevice == device}) {
                print("Time interval for \(payeesBuild[index].payeeName!) is - \(Date().timeIntervalSince(payeesBuild[index].timestamp))")
                print("Subscribed Characteristic Count - \(subscribedCharacteristics.count)")
                if (Date().timeIntervalSince(payeesBuild[index].timestamp) > 300 && subscribedCharacteristics.count > 0) {

                    //Unsubscribe from existing characteristics for this peripheral
                    for index in 0..<(subscribedCharacteristics.count) {
                        if device == subscribedCharacteristics[index].peripheral {
                            let characteristic = subscribedCharacteristics[index].characteristic!
                            // Unsubscribe from a characteristic
                            print("Unsubscribing from Char - \(characteristic) on Device \(String(describing: device))")
                            device.setNotifyValue(false, for: characteristic)
                        }
                    }
                    
                    subscribedCharacteristics = subscribedCharacteristics.filter() { $0.peripheral !== device }
                    
                    //Then diconnect from the peripheral and remove the peripheral from the list of peripherals
                    centralManager.cancelPeripheralConnection(device)
                    peripherals = peripherals.filter() { $0 !== device }
                    
                }
            }
        }
        
        
    }
    
}


