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
    var payeePeripheral: CBPeripheral? = nil
    var payeeReceiptChar: CBCharacteristic? = nil
    var payeeName: String?  = ""
    var payeeAvatar: Data = Data()
    var payeeAddress: String? = nil
    var timestamp: Date = Date()
}

struct payeeBuild {
    var payeePeripheral: CBPeripheral? = nil
    var payeeName: String?  = ""
    var payeeImageHash: String? = ""
    var payeeAddress: String? = nil
    var timestamp: Date = Date()
}

struct subscribedCharacteristic {
    var peripheral: CBPeripheral? = nil
    var characteristic: CBCharacteristic?  = nil
}

var payees: [payee] = []
var payeesBuild: [payeeBuild] = []
var payeesBuilt: [payee] = []
var subscribedCharacteristics: [subscribedCharacteristic] = []
var peripherals: [CBPeripheral] = []
var path = IndexPath()

class CentralManagerHandler: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    //Data
    var centralManager: CBCentralManager!
    var iotaStorage = IotaStorage()
    var doWrite = false
    
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
        
        //Remove aged peripherals in case they've just gone away
        disconnectAgedPeripherals()
        
        centralManager?.scanForPeripherals(withServices: [Service_UUID] , options: [CBCentralManagerScanOptionAllowDuplicatesKey:false])
        Timer.scheduledTimer(timeInterval: 30, target: self, selector: #selector(self.cancelScan), userInfo: nil, repeats: false)
    }
    
    // Called when we want to stop scanning for more TaPs devices
    @objc func cancelScan() {
        centralManager.stopScan()
        print("Stopped Scanning")
        Timer.scheduledTimer(timeInterval: 30, target: self, selector: #selector(self.startScan), userInfo: nil, repeats: false)
    }
    
    // Called when we want to stop scanning altogether
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
        if !payeesBuild.contains(where: { $0.payeePeripheral?.identifier == peripheral.identifier }) {
            
            //Set-up payee record in payees array and payeesBuild
            payeesBuild.append(payeeBuild(payeePeripheral: peripheral, payeeName: "", payeeImageHash: "", payeeAddress: "", timestamp: Date() ))
            payeesBuilt.append(payee(payeePeripheral: peripheral, payeeReceiptChar: nil, payeeName: "", payeeAvatar: Data(), payeeAddress: "", timestamp: Date() ))
            
            peripherals.append(peripheral)
            peripheral.delegate = self
        
            print("Found new peripheral devices with the IOTA TAP service")
            print("Device name: \(peripheral.name ?? "Unknown")")
            print("**********************************")
            //print ("Advertisement Data : \(advertisementData)")
            print ("Advertisement Data : \(advertisementData["kCBAdvDataLocalName"] ?? "Unknown")")
            
            //Connect to the peripheral
            connectToDevice(peripheral: peripheral)
            
        }
        
        print("Peripherals discovered so far - \(peripherals)")
        
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
            if (characteristic.uuid == nameCharacteristic.uuid || characteristic.uuid == imageCharacteristic.uuid  || characteristic.uuid == addressCharacteristic.uuid ) {
                print("Found valid characteristics! - \(characteristic.uuid)")
                subscribedCharacteristics.append(subscribedCharacteristic(peripheral: peripheral, characteristic: characteristic))
                
                peripheral.setNotifyValue(true, for: characteristic)
            }
            
            if (characteristic.uuid == receiptCharacteristic.uuid) {
                
                if let payeesIndex = payeesBuilt.index(where: { $0.payeePeripheral?.identifier == peripheral.identifier}) {
                    let tempPayeeReceiptChar = characteristic
                    let tempPayeeAvatar = payeesBuilt[payeesIndex].payeeAvatar
                    let tempPayeeAddress = payeesBuilt[payeesIndex].payeeAddress
                    let tempPayeeName = payeesBuilt[payeesIndex].payeeName
                    payeesBuilt.remove(at: payeesIndex)
                    payeesBuilt.append(payee(payeePeripheral: peripheral, payeeReceiptChar: tempPayeeReceiptChar, payeeName: tempPayeeName, payeeAvatar: tempPayeeAvatar, payeeAddress: tempPayeeAddress, timestamp: Date() ))
                }
                
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
            
            if let payeeNameFragment = String(data: characteristic.value!, encoding: String.Encoding(rawValue: String.Encoding.utf8.rawValue)) {
                
                if payeeNameFragment != "EOM" {
                    if let index = payeesBuild.index(where: { $0.payeePeripheral?.identifier == peripheral.identifier}) {
                        let tempPayeeImageHash = payeesBuild[index].payeeImageHash
                        let tempPayeeAddress = payeesBuild[index].payeeAddress
                        var tempPayeeName = payeesBuild[index].payeeName
                        tempPayeeName = tempPayeeName! + payeeNameFragment
                        payeesBuild.remove(at: index)
                        payeesBuild.append(payeeBuild(payeePeripheral: peripheral, payeeName: tempPayeeName, payeeImageHash: tempPayeeImageHash, payeeAddress: tempPayeeAddress, timestamp: Date() ))
                    }
                }
                else
                {
                    if let payeesIndex = payeesBuilt.index(where: { $0.payeePeripheral?.identifier == peripheral.identifier}) {
                        let payeesBuildIndex = payeesBuild.index(where: { $0.payeePeripheral?.identifier == peripheral.identifier})
                        let tempPayeeAvatar = payeesBuilt[payeesIndex].payeeAvatar
                        let tempPayeeAddress = payeesBuilt[payeesIndex].payeeAddress
                        let tempPayeeReceiptChar = payeesBuilt[payeesIndex].payeeReceiptChar
                        let tempPayeeName = payeesBuild[payeesBuildIndex!].payeeName
                        payeesBuilt.remove(at: payeesIndex)
                        payeesBuilt.append(payee(payeePeripheral: peripheral, payeeReceiptChar: tempPayeeReceiptChar, payeeName: tempPayeeName, payeeAvatar: tempPayeeAvatar, payeeAddress: tempPayeeAddress, timestamp: Date() ))
                        payeesBuild[payeesBuildIndex!].payeeName = ""
                    }
                    print("Payee Name End of Message found")
                }
                
                print("Payee Name Fragment = \(payeeNameFragment)")
                
            }
            
        }
        
        if characteristic.uuid == imageCharacteristic.uuid {
            
            if let payeeImageHashFragment = String(data: characteristic.value!, encoding: String.Encoding(rawValue: String.Encoding.utf8.rawValue)) {
                
                if payeeImageHashFragment != "EOM" {
                    if let index = payeesBuild.index(where: { $0.payeePeripheral?.identifier == peripheral.identifier}) {
                        let tempPayeeName = payeesBuild[index].payeeName
                        let tempPayeeAddress = payeesBuild[index].payeeAddress
                        var tempPayeeImageHash = payeesBuild[index].payeeImageHash
                        tempPayeeImageHash = tempPayeeImageHash! + payeeImageHashFragment
                        payeesBuild.remove(at: index)
                        payeesBuild.append(payeeBuild(payeePeripheral: peripheral, payeeName: tempPayeeName, payeeImageHash: tempPayeeImageHash, payeeAddress: tempPayeeAddress, timestamp: Date() ))
                    }
                } else {
                    if let payeesIndex = payeesBuilt.index(where: { $0.payeePeripheral?.identifier == peripheral.identifier}) {
                        let payeesBuildIndex = payeesBuild.index(where: { $0.payeePeripheral?.identifier == peripheral.identifier})
                        let tempPayeeName = payeesBuilt[payeesIndex].payeeName
                        let tempPayeeAddress = payeesBuilt[payeesIndex].payeeAddress
                        let tempPayeeReceiptChar = payeesBuilt[payeesIndex].payeeReceiptChar
                        let tempPayeeImageHash = payeesBuild[payeesBuildIndex!].payeeImageHash
                        
                        let iotaStorage = IotaStorage()
                        
                        print("Attempting Retrieve")
                        
                        iotaStorage.retrieve(bundleHash: tempPayeeImageHash!, { (success) in
                            
                            print("Retrieve was successful")
                            
                            let tempPayeeAvatar:Data = UIImagePNGRepresentation(success)!
                            
                            //Update the UIImage View back on the main queue
                            DispatchQueue.main.async {
                                
                                let payeesIndex = payeesBuilt.index(where: { $0.payeePeripheral?.identifier == peripheral.identifier})
                                    
                                print("PAYEES INDEX - \(payeesIndex!)")
                                
                                payeesBuilt.remove(at: payeesIndex!)
                                payeesBuilt.append(payee(payeePeripheral: peripheral, payeeReceiptChar: tempPayeeReceiptChar, payeeName: tempPayeeName, payeeAvatar: tempPayeeAvatar , payeeAddress: tempPayeeAddress, timestamp: Date() ))
                            }
                            
                        }, error: { (error) in
                            print("Retrieve from Tangle failed with error - \(error)")
                        })

                        payeesBuild[payeesBuildIndex!].payeeImageHash = ""
                       
                    }
                    print("Payee Image Hash End of Message found")
                }
    
                print("Received: \(String(describing: payeeImageHashFragment))")
            }
            
        }
        
        if characteristic.uuid == addressCharacteristic.uuid {
            
            if let payeeAddressFragment = String(data: characteristic.value!, encoding: String.Encoding(rawValue: String.Encoding.utf8.rawValue)) {
                
                if payeeAddressFragment != "EOM" {
                    if let index = payeesBuild.index(where: { $0.payeePeripheral?.identifier == peripheral.identifier}) {
                        let tempPayeeImageHash = payeesBuild[index].payeeImageHash
                        let tempPayeeName = payeesBuild[index].payeeName
                        var tempPayeeAddress = payeesBuild[index].payeeAddress
                        tempPayeeAddress = tempPayeeAddress! + payeeAddressFragment
                        payeesBuild.remove(at: index)
                        payeesBuild.append(payeeBuild(payeePeripheral: peripheral, payeeName: tempPayeeName, payeeImageHash: tempPayeeImageHash, payeeAddress: tempPayeeAddress, timestamp: Date() ))
                    }
                }
                else
                {
                    if let payeesIndex = payeesBuilt.index(where: { $0.payeePeripheral?.identifier == peripheral.identifier}) {
                        let payeesBuildIndex = payeesBuild.index(where: { $0.payeePeripheral?.identifier == peripheral.identifier})
                        let tempPayeeAvatar = payeesBuilt[payeesIndex].payeeAvatar
                        let tempPayeeName = payeesBuilt[payeesIndex].payeeName
                        let tempPayeeReceiptChar = payeesBuilt[payeesIndex].payeeReceiptChar
                        let tempPayeeAddress = payeesBuild[payeesBuildIndex!].payeeAddress
                        payeesBuilt.remove(at: payeesIndex)
                        payeesBuilt.append(payee(payeePeripheral: peripheral, payeeReceiptChar: tempPayeeReceiptChar, payeeName: tempPayeeName, payeeAvatar: tempPayeeAvatar, payeeAddress: tempPayeeAddress, timestamp: Date() ))
                        payeesBuild[payeesBuildIndex!].payeeAddress = ""
                    }
                    print("Payee Address End of Message found")
                }
                
                print("Payee Address Fragment = \(payeeAddressFragment)")
                
            }
            
            
            
        }
        
        //What does this do?
        NotificationCenter.default.post(name:NSNotification.Name(rawValue: "Notify"), object: nil)
    }
    
    /** write the next amount of data to the selected peripheral
     */
    public func writeData(peripheral: CBPeripheral) {
        
        print("Write data started")
        
        doWrite = true
        
        while doWrite {
            // Make the next chunk
            
            // Work out how big it should be
            var amountToSend = dataToWrite!.count - writeDataIndex!;
            
            if (amountToSend > NOTIFY_MTU) {
                amountToSend = NOTIFY_MTU;
            }
            
            // Copy out the data we want
            let chunk = dataToWrite!.withUnsafeBytes{(body: UnsafePointer<UInt8>) in
                return Data(
                    bytes: body + writeDataIndex!,
                    count: amountToSend
                )
            }
            
            // Write it
            print("Writing data chunk \(chunk)")
            
            peripheral.writeValue(
                chunk as Data,
                for: writeCharacteristic!,
                type: CBCharacteristicWriteType.withoutResponse
            )
            
            // Update our index
            writeDataIndex! += amountToSend;
            
            // Was it the last one?
            if (writeDataIndex! >= dataToWrite!.count) {
                
                print("Reached end of data to write")
                // It was - write an EOM
                
                // Write it
                peripheral.writeValue(
                    "EOM".data(using: String.Encoding.utf8)!,
                    for: writeCharacteristic!,
                    type: CBCharacteristicWriteType.withoutResponse
                )
                
                doWrite = false
            }
        }
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
        
        //Remove peripheral from list of known payeesBuilt and payeesBuild arrays
        if let index = payeesBuild.index(where: { $0.payeePeripheral?.identifier == peripheral.identifier}) {
            payeesBuild.remove(at: index)
            if let index = payeesBuilt.index(where: { $0.payeePeripheral?.identifier == peripheral.identifier}) {
                payeesBuilt.remove(at: index)
            }
        }
        
    }
    
    public func unsubscribeAll() {
        
        print("Unsubscribing from all peripherals")
        
        for peripheral in peripherals {

            //Unsubscribe from existing characteristics for this peripheral
            for index in 0..<(subscribedCharacteristics.count) {
                if peripheral.identifier == subscribedCharacteristics[index].peripheral?.identifier {
                    let characteristic = subscribedCharacteristics[index].characteristic!
                    // Unsubscribe from a characteristic
                    print("Unsubscribing from Char - \(characteristic) on Peripheral Identifier \(String(describing: peripheral.identifier))")
                    peripheral.setNotifyValue(false, for: characteristic)
                }
            }
            
            //Then diconnect from the peripheral and remove the peripheral from the list of peripherals
            centralManager.cancelPeripheralConnection(peripheral)
    
        }
        
        if (centralManager != nil) {
            print("Stopped Scanning")
            centralManager.stopScan()
        }
        
    }
    
    public func disconnectAgedPeripherals() {
        
        print("Disconnecting from aged peripherals")
        
        //Clean up Bluetooth connections where the device hasn't been active for more than 300 seconds
        //First unsubscribe all Characteristics and then disconnect Peripheral else when we re-subscribe nothing will happen
        for peripheral in peripherals {
            if let index = payeesBuild.index(where: { $0.payeePeripheral?.identifier == peripheral.identifier}) {
                
                if (Date().timeIntervalSince(payeesBuild[index].timestamp) > 300 && subscribedCharacteristics.count > 0) {

                    //Unsubscribe from existing characteristics for this peripheral
                    for index in 0..<(subscribedCharacteristics.count) {
                        if peripheral == subscribedCharacteristics[index].peripheral {
                            let characteristic = subscribedCharacteristics[index].characteristic!
                            // Unsubscribe from a characteristic
                            print("Unsubscribing from Char - \(characteristic) on Device \(String(describing: peripheral))")
                            peripheral.setNotifyValue(false, for: characteristic)
                        }
                    }
                    
                    subscribedCharacteristics = subscribedCharacteristics.filter() { $0.peripheral !== peripheral }
                    
                    //Then diconnect from the peripheral and remove the peripheral from the list of peripherals
                    centralManager.cancelPeripheralConnection(peripheral)
                    peripherals = peripherals.filter() { $0 !== peripheral }
                    
                    //Remove peripheral from list of known payeesBuilt and payeesBuild arrays
                    if let index = payeesBuild.index(where: { $0.payeePeripheral?.identifier == peripheral.identifier}) {
                        payeesBuild.remove(at: index)
                        if let index = payeesBuilt.index(where: { $0.payeePeripheral?.identifier == peripheral.identifier}) {
                            payeesBuilt.remove(at: index)
                        }
                    }
                }
            }
        }
    }
}


