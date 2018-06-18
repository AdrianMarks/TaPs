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

var iotaTapPeripheral: CBPeripheral?
var xCharacteristic : CBCharacteristic?
var characteristicASCIIValue = String()

struct payee {
    var payeeDevice: CBPeripheral? = nil
    var payeeName: String?  = ""
    var payeeAvatar: UIImage? = nil
    var payeeAddress: String? = nil
}

struct subscribedCharacteristic {
    var peripheral: CBPeripheral? = nil
    var characteristic: CBCharacteristic?  = nil
}

var payees: [payee] = []
var subscribedCharacteristics: [subscribedCharacteristic] = []
var peripherals: [CBPeripheral] = []
var path = IndexPath()

class CentralManagerHandler: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    //Data
    var centralManager: CBCentralManager!
    var payeeNameBuild: String = ""
    var payeeAvatarBuild: Data = Data()
    var payeeAddressBuild: String = ""
    var payeeReceiptBuild: String = ""
    
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
        print("Now Scanning...")
        self.timer.invalidate()
        centralManager?.scanForPeripherals(withServices: [Service_UUID] , options: [CBCentralManagerScanOptionAllowDuplicatesKey:false])
        Timer.scheduledTimer(timeInterval: 20, target: self, selector: #selector(self.cancelScan), userInfo: nil, repeats: false)
    }
    
    // Called when we want to stop scanning for more TaPs devices
    @objc func cancelScan() {
        centralManager.stopScan()
        print("Scan Stopped")
        Timer.scheduledTimer(timeInterval: 60, target: self, selector: #selector(self.startScan), userInfo: nil, repeats: false)
    }
    
    public func ceaseScanAltogether() {
        if (centralManager != nil) {
            print("Ceased scanning")
            centralManager.stopScan()
        }
    }
    
    // Called when the central manager discovers a peripheral while scanning.
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        
        //Check to make sure we've not already found this peripheral
        if !payees.contains(where: { $0.payeeDevice == peripheral }) {
            
            //Set-up payee record in payees array
            payees.append(payee(payeeDevice: peripheral, payeeName: "", payeeAvatar: UIImage(), payeeAddress: ""))
            
            iotaTapPeripheral = peripheral
            peripherals.append(iotaTapPeripheral!)
            peripheral.delegate = self
        
            //print(peripheral)
            if  iotaTapPeripheral != nil {
                print("Found new peripheral devices with the IOTA TAP service")
                print("Device name: \(peripheral.name!)")
                print("**********************************")
                //print ("Advertisement Data : \(advertisementData)")
                print ("Advertisement Data : \(advertisementData["kCBAdvDataLocalName"] ?? "Unknown")")
            }
            
            //Connect to the peripheral
            connectToDevice()
            
        }
        
    }
    
    //Called to invoke a connection to a peripheral device
    func connectToDevice () {
        centralManager?.connect(iotaTapPeripheral!, options: nil)
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
        
        print("(Payments) Characteristic is - \(characteristic.uuid)")
        
        if characteristic.uuid == nameCharacteristic.uuid {
            
            print("nameCharacteristic is - \(nameCharacteristic.uuid)")
            
            if let payeeNameFragment = String(data: characteristic.value!, encoding: String.Encoding(rawValue: String.Encoding.utf8.rawValue)) {
                
                if payeeNameFragment != "EOM" {
                    payeeNameBuild = payeeNameBuild + payeeNameFragment
                }
                else
                {
                    if let index = payees.index(where: { $0.payeeDevice == peripheral}) {
                        let tempPayeeAvatar = payees[index].payeeAvatar
                        let tempPayeeAddress = payees[index].payeeAddress
                        payees.remove(at: index)
                        payees.append(payee(payeeDevice: peripheral, payeeName: payeeNameBuild, payeeAvatar: tempPayeeAvatar, payeeAddress: tempPayeeAddress ))
                    }
                    payeeNameBuild = ""
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
                    print("PayeeAvatar is - \(String(describing: payeeAvatarBuild))")
                    
                    if let index = payees.index(where: { $0.payeeDevice == peripheral}) {
                        let tempPayeeName = payees[index].payeeName
                        let tempPayeeAddress = payees[index].payeeAddress
                        payees.remove(at: index)
                        payees.append(payee(payeeDevice: peripheral, payeeName: tempPayeeName, payeeAvatar: UIImage(data:payeeAvatarBuild,scale:1.0), payeeAddress: tempPayeeAddress ))
                    }
                    payeeAvatarBuild = Data()
                }
            }
            else
            {
                print("Received: \(String(describing: payeeAvatarFragment))")
                payeeAvatarBuild = payeeAvatarBuild + payeeAvatarFragment
                print("Accumulated payeeAvater - \(String(describing: payeeAvatarBuild))")
            }
            
        }
        
        if characteristic.uuid == addressCharacteristic.uuid {
            
            print("addressCharacteristic is - \(addressCharacteristic.uuid)")
            
            if let payeeAddressFragment = String(data: characteristic.value!, encoding: String.Encoding(rawValue: String.Encoding.utf8.rawValue)) {
                
                if payeeAddressFragment != "EOM" {
                    payeeAddressBuild = payeeAddressBuild + payeeAddressFragment
                }
                else
                {
                    if let index = payees.index(where: { $0.payeeDevice == peripheral}) {
                        let tempPayeeAvatar = payees[index].payeeAvatar
                        let tempPayeeName = payees[index].payeeName
                        payees.remove(at: index)
                        payees.append(payee(payeeDevice: peripheral, payeeName: tempPayeeName, payeeAvatar: tempPayeeAvatar, payeeAddress: payeeAddressBuild ))
                    }
                    payeeAddressBuild = ""
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
                            if CoreDataHandler.saveReceiptDetails(payerName: tempPayeeName!, payerAvatar: (UIImagePNGRepresentation(tempPayeeAvatar!) as Data?)!, amount: Int64(amount)!, message: message, status: "Pending", timestamp: Date(), bundleHash: bundleHash ) {
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
        
        //Remove peripheral from list of known payees
        if let index = payees.index(where: { $0.payeeDevice == peripheral}) {
            payees.remove(at: index)
        }
        
    }
    
    public func cbTidyUp() {
        
        //Clean up Bluetooth connections before going into Background
        for index in 0..<subscribedCharacteristics.count {
            let device = subscribedCharacteristics[index].peripheral
            let characteristic = subscribedCharacteristics[index].characteristic!
            // Unsubscribe from a characteristic
            print("Unsubscribing from Char - \(characteristic) on Device \(String(describing: device))")
            device?.setNotifyValue(false, for: characteristic)
        }
        
        for device in peripherals {
            print("Disconnecting from from Device \(device)")
            centralManager.cancelPeripheralConnection(device)
        }
        
        if (centralManager != nil) {
            print("Stopped scanning")
            centralManager.stopScan()
        }
        
    }
    
}


