//
//  IotaStorage.swift
//  TaPs
//
//  Created by Redkite - Adrian Marks on 28/06/2018.
//  Copyright © 2018 Red Kite Projects Limited. All rights reserved.
//

import SwiftKeychainWrapper
import CoreBluetooth
import IotaKit

class IotaStorage: NSObject {
    
    //Data
    let iota = Iota(node: node)
    let messageLength = 2187
    let storageSeed = "".rightPadded(count: 81, character: "9")
    var transfers: [IotaTransfer] = []
    
    //Keychain Data
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
    
    public override init() {
        super.init()
    }
    
    /// Save an image file in the Tangle
    ///
    /// - Parameters:
    ///   - image: image to be saved.
    ///   - success: Success block.
    ///   - error: Error block.
    public func save(image: UIImage, _ success: @escaping (_ bundleHash: String) -> Void, error: @escaping (Error) -> Void) {
        
        //Convert the image to Trytes
        let imageData:Data = UIImagePNGRepresentation(image)!
        let imageStrBase64 = imageData.base64EncodedString()
        
        let imageTrytes = IotaConverter.trytes(fromAsciiString: imageStrBase64)
        
        var index = 0
        var offset = messageLength
        transfers = []
        
        //Chop the trytes up into message sized chuncks - 2187 tryes max
        while index < (imageTrytes?.count)! {
            
            let message = imageTrytes?.substring(from: index, to: offset)
            
            index += messageLength
            offset = index + messageLength
            if offset > (imageTrytes?.count)! { offset = (imageTrytes?.count)!}
            
            //Store each chunck in a Transfer message with 0 value
            let transfer = IotaTransfer(address: savedAddress!, value: 0, message: message!, tag: "TAPSSTORAGE" )
            
            transfers.append(transfer)
        
        }
        
        //Send the Transfer
        iota.sendTransfers(seed: storageSeed , depth: 3, transfers: transfers, inputs: nil, remainderAddress: nil , { (result) in

            success(result[0].bundle)
            
        }, error: { (error) in
            
            print("Unable to store image - error is - \(error)")
            
        })
        
    }
    
    /// Retrieve an image file from the Tangle
    ///
    /// - Parameters:
    ///   - bundleHash: bundleHash of the Transactions containing the saved image.
    ///   - success: Success block.
    ///   - error: Error block.
    public func retrieve(bundleHash: String, _ success: @escaping (_ image: UIImage) -> Void, error: @escaping (Error) -> Void) {
        
        //Use bundleHash to retrieve the transactions
        iota.findTransactions(bundles: [bundleHash], { (hashes) in
            
            print("Hashes are - \(hashes)")
            
            self.iota.trytes(hashes: hashes, { (trytes) in
                
                var imageTrytes = ""
                
                for transaction in trytes.sorted(by: { $0.currentIndex < $1.currentIndex }) {
                    
                    imageTrytes += transaction.signatureFragments
                }
                
                print("Image Trytes count - \(imageTrytes.count)")
                
                if imageTrytes.count > 0 {
                    //Make sure we have an even number of trytes before converting back to Ascii
                    if imageTrytes.count % 2 != 0 { imageTrytes += "9" }
                    let imageStrBase64 = IotaConverter.asciiString(fromTrytes: imageTrytes)
                    
                    print("Image Data - \(imageStrBase64!.count)")
                    
                    //Convert string to image data
                    let imageData = Data(base64Encoded: imageStrBase64!, options: Data.Base64DecodingOptions.ignoreUnknownCharacters)!
                    
                    //Return image
                    success(UIImage(data: imageData)!)
                } else {
                    error(IotaAPIError("Error retrieving Image hashes"))
                    return
                }
                
            }, error: { (error) in
                print("Unable to find Trytes - error is - \(error)")
            })
            
        }, error: { (error) in
            print("Unable to find Transactions - error is - \(error)")
        })
        
    }

}

