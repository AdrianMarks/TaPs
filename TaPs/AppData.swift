//
//  appData.swift
//  Iota Tap
//
//  Created by Redkite - Adrian Marks on 22/03/2018.
//  Copyright © 2018 Red Kite Projects Limited. All rights reserved.
//

import CoreBluetooth

public var sendingEOM = false;
public var transferCharacteristic: CBMutableCharacteristic?
public var dataToSend: Data?
public var sendDataIndex: Int?
public var sendShortDataIndex: Int?
public var node = "https://redkite-iota.com:443"

enum TAPConstants {
    static let kAvatar = "avatar"
    static let kSeed = "seed"
    static let kIndex = "index"
    static let kBTStatus = "bluetooth"
    static let kAddress = "address"
    static let kBalance = "balance"
}

let device_UUID = UUID().uuidString
let kService_UUID = "F643B47F-E2CD-412F-B4D1-7077600A8D77"
let imageCharacteristic_uuid = "19607F25-FDEC-42C7-A8E9-5817F936E231"
let nameCharacteristic_uuid = "DFFD3395-C909-4555-8634-98B06BAEEDF0"
let addressCharacteristic_uuid = "C1F206AB-3675-4E13-890D-4A6C1F218607"
let deviceCharacteristic_uuid = "13B3E4DC-2C8D-4AEA-9DE4-2C04736BD25D"
let receiptCharacteristic_uuid = "60BD4755-F29E-41F0-87A8-3BDE05B4A13C"

let advertisementData = "TaPs Device"

var default_MTU = 182
var NOTIFY_MTU = 182

let Service_UUID = CBUUID(string: kService_UUID)
let nameCharacteristic_UUID = CBUUID(string: nameCharacteristic_uuid)
let imageCharacteristic_UUID = CBUUID(string: imageCharacteristic_uuid)
let addressCharacteristic_UUID = CBUUID(string: addressCharacteristic_uuid)
let deviceCharacteristic_UUID = CBUUID(string: deviceCharacteristic_uuid)
let receiptCharacteristic_UUID = CBUUID(string: receiptCharacteristic_uuid)

let service = CBMutableService(type: Service_UUID, primary: true)

let properties: CBCharacteristicProperties = [.notify, .read ]
let permissions: CBAttributePermissions = [.readable ]

let nameCharacteristic = CBMutableCharacteristic(
    type: nameCharacteristic_UUID,
    properties: properties,
    value: nil,
    permissions: permissions)

let imageCharacteristic = CBMutableCharacteristic(
    type: imageCharacteristic_UUID,
    properties: properties,
    value: nil,
    permissions: permissions)

let addressCharacteristic = CBMutableCharacteristic(
    type: addressCharacteristic_UUID,
    properties: properties,
    value: nil,
    permissions: permissions)

let deviceCharacteristic = CBMutableCharacteristic(
    type: deviceCharacteristic_UUID,
    properties: properties,
    value: nil,
    permissions: permissions)

let receiptCharacteristic = CBMutableCharacteristic(
    type: receiptCharacteristic_UUID,
    properties: properties,
    value: nil,
    permissions: permissions)
