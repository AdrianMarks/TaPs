//
//  MakePaymentViewController.swift
//  TaPs
//
//  Created by Redkite - Adrian Marks on 22/03/2018.
//  Copyright © 2018 Red Kite Projects Limited. All rights reserved.
//

import UIKit
import CoreBluetooth
import IotaKit
import SwiftKeychainWrapper

class MakePaymentViewController: UIViewController, UITextFieldDelegate {
  
    //Keychain Data
    fileprivate var savedSeed: String? {
        get {
            return KeychainWrapper.standard.string(forKey: TAPConstants.kSeed)
        }
        set {
            KeychainWrapper.standard.set(newValue!, forKey: TAPConstants.kSeed)
        }
    }

    //UI
    @IBOutlet weak var payeeLabel: UILabel!
    @IBOutlet weak var payeeAvatar: UIImageView!
    @IBOutlet weak var amountToPay: UITextField!
    @IBOutlet weak var message: UITextField!
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var sendItButton: UIButton!
    
    var button = DropDownButton()

    // These variables will hold the data being passed from the Payees View Controller
    var receivedPayeeName: String = ""
    var receivedPayeeAvatar: UIImage = UIImage()
    var receivedPayeeDevice: CBPeripheral!
    var receivedPayeeAddress: String!
    
    var timer = Timer()
    
    //Remove leading zeros and decimal points from Amount entry
    @IBAction func amountToPayEdited(_ sender: Any) {
        if amountToPay.text!.prefix(1) == "0" {
            amountToPay.text = String((amountToPay.text?.dropFirst())!)
        }
        if amountToPay.text!.prefix(1) == "." {
            amountToPay.text = String((amountToPay.text?.dropFirst())!)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        //Looks for single or multiple taps.
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(MakePaymentViewController.dismissKeyboard))
        
        //Uncomment the line below if you want the tap not to interfere and cancel other interactions.
        tap.cancelsTouchesInView = false
        
        view.addGestureRecognizer(tap)
        
        // Used the values sent from the Payments View Controller to set the PayeeLabel and PayeeAvatar
        payeeLabel.text = receivedPayeeName
        payeeAvatar.layer.masksToBounds = true
        payeeAvatar.layer.borderWidth = 0
        payeeAvatar.layer.cornerRadius = payeeAvatar.frame.width / 2
        payeeAvatar.image = receivedPayeeAvatar
        
        //Configure Units drop down button
        button = DropDownButton.init(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        button.layer.cornerRadius = 5
        button.setTitle("Mi", for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        
        //Add Units button to the view controller
        self.view.addSubview(button)
        
        //Setup drop down button constrainst
        self.view.addConstraint(NSLayoutConstraint(item: button, attribute: .leading, relatedBy: .equal, toItem: amountToPay, attribute: .trailing, multiplier: 1, constant: 10))
        button.centerYAnchor.constraint(equalTo: amountToPay.centerYAnchor).isActive = true
        button.widthAnchor.constraint(equalToConstant: 50).isActive = true
        button.heightAnchor.constraint(equalToConstant: 30).isActive = true
        
        //Set the Units down down button's options
        button.dropView.dropDownOptions = ["I","Ki","Mi","Gi"]
        
        message.delegate = self
    }
    
    @IBAction func sendItButton(_ sender: Any) {
        
        print("I want to send - \(String(describing: amountToPay.text!)) \(String(describing: button.titleLabel?.text!)) to address - \(String(describing: receivedPayeeAddress)) with Message - \(message.text!) and with Tag - TAPS ")
        
        //Alert the user to what they are about to do
        
        let title = "Payment Details"
        let units = button.titleLabel?.text!
        let alertMessage = "You are about to send \(amountToPay.text!) \(units!) to \(payeeLabel.text!). Are you sure you want to proceed?"
        print("Alert message is - \(alertMessage)")
        let alert = UIAlertController(title: title, message: alertMessage, preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: { action in
            
            print("I selected 'Yes' to make payment")
            
            //Make the payment, store the payment details and send receipt to Payee
            self.makePayment()
            
            //Transfer to the Payments View Controller
            let selectedVC: UITabBarController = self.storyboard?.instantiateViewController(withIdentifier: "tabBarController") as! UITabBarController
            UIApplication.shared.keyWindow?.rootViewController = selectedVC
            selectedVC.selectedIndex = 1
            self.present(selectedVC, animated: false, completion: nil)
            
            }
        ))
        alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: { action in
            print("I selected 'No' to make payment")
            }
        ))
        
        self.present(alert, animated: true)
        
    }
    
    func makePayment() {
        
        //Assume success and store the record in core data - payment
        //Calculate amount to pay in Iota from input amount and units label
        let index = button.dropView.dropDownOptions.index(of: (button.titleLabel?.text!)!)
        let multiplier = pow(1000, index!)
        let intMultiplier = NSDecimalNumber(decimal: multiplier)
        let amount = Int(amountToPay.text!)! * Int(truncating: intMultiplier)
        
        print ("The index is - \(String(describing: index))")
        print ("The amount of iotas is - \(amount)")
        
        //Save the payment details in Core Data
        if CoreDataHandler.savePaymentDetails(payeeName: self.receivedPayeeName, payeeAvatar: (UIImagePNGRepresentation(self.receivedPayeeAvatar as UIImage) as Data?)!, amount: Int64(amount), message: self.message.text!, status: "Submitted", timestamp: Date(), bundleHash: "", tailHash: "" ) {
            print("Data saved sussfully")
        } else {
            print("Failed to save data")
        }
        
        //Limit the payment data stored in Core Data to 10 rows.
        if CoreDataHandler.limitStoredPayments() {
            print("Successfully limited number of saved payments")
        } else {
            print("Failed to limit number of saved payments")
        }
        
        //Convert ASCII to Trytes
        let messageTrytes = IotaConverter.trytes(fromAsciiString: message.text!)
        
        print("Message trytes are - \(String(describing: messageTrytes))")
        
        //Set up the Iota API details
        let iota = Iota(node: node)
        let transfer = IotaTransfer(address: receivedPayeeAddress, value: UInt64(amount), message: messageTrytes!, tag: "TAPS" )
        
        print("This is the transfer - \(transfer)")
        
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
            
            //Automatically promote the transaction
            iota.promoteTransaction(hash: tailHash, { (success) in
                
                //Update the last payment record status to "Promoted"
                DispatchQueue.main.async {
                    if CoreDataHandler.updatePromotedPayment(bundleHash: bundleHash) {
                        print("Updated status of payment to 'Promoted' successfully")
                    } else {
                        print("Failed updating payment to 'Promoted' status")
                    }
                }
                
                print("First round of promotion succeeded")
                
                //Automatically promote AGAIN the transaction
                //Temporary measure while MainNet is performaing badly!!
                iota.promoteTransaction(hash: tailHash, { (success) in
                    print("Second round of promotion succeeded")
                }, error: { (error) in
                    print("Second round of promotion Failed")
                })
                
            }, error: { (error) in
                print("Promotion Failed")
            })
            
            //Send Receipt to Payee
            print("attempting to send Receipt to Payee")
            DispatchQueue.main.async {
                
                //Send BundleHash and Message and Amount in one Bluetooth message
                var packedMessage: String = self.message.text!
                packedMessage.rightPad(count: 33, character: " ")
                dataToSend = ((bundleHash + packedMessage + self.amountToPay.text!).data(using: String.Encoding(rawValue: String.Encoding.utf8.rawValue))!)
                transferCharacteristic = receiptCharacteristic
                
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
    
    //Calls this function when the tap is recognized.
    @objc func dismissKeyboard() {
        //Causes the view (or one of its embedded text fields) to resign the first responder status.
        self.view.endEditing(true)
        
    }
    
    //Calls this function when the Return/Done key is pressed.
    func textFieldShouldReturn(_ scoreText: UITextField) -> Bool {
        self.view.endEditing(true)
        return true
    }

}


