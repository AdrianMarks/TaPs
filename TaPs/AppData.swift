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

let kService_UUID = "F643B47F-E2CD-412F-B4D1-7077600A8D77"
let imageCharacteristic_uuid = "19607F25-FDEC-42C7-A8E9-5817F936E231"
let nameCharacteristic_uuid = "DFFD3395-C909-4555-8634-98B06BAEEDF0"
let addressCharacteristic_uuid = "C1F206AB-3675-4E13-890D-4A6C1F218607"

let advertisementData = "TaPs Device"

let NOTIFY_MTU = 132
let Service_UUID = CBUUID(string: kService_UUID)
let nameCharacteristic_UUID = CBUUID(string: nameCharacteristic_uuid)
let imageCharacteristic_UUID = CBUUID(string: imageCharacteristic_uuid)
let addressCharacteristic_UUID = CBUUID(string: addressCharacteristic_uuid)

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
