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

class MakePaymentViewController: UIViewController, UITextFieldDelegate, DropDownDelegate {
    
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
    @IBOutlet weak var validity: UILabel!
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var sendItButton: UIButton!
    
    var button = DropDownButton()
    let dropView = DropDownView()
    
    // These variables will hold the data being passed from the Payees View Controller
    var receivedPayeeName: String = ""
    var receivedPayeeAvatar: Data = Data()
    var receivedPayeeDevice: CBPeripheral!
    var receivedPayeeAddress: String!
    var timer = Timer()
    
    @IBAction func amountToPayEdited(_ sender: Any) {
        
        //Ensure amount is entered in a valid format and conforms to the limits of teh units entered
        
        formatAmount()
        
        validateAmount()
        
    }
    
    func formatAmount() {
        
        let firstChar = amountToPay.text!.prefix(1)
        let lastChar = amountToPay.text!.suffix(1)
        let remainChar = amountToPay.text!.dropLast()
        
        print("First char - \(firstChar)")
        print("Last char - \(lastChar)")
        print("Remain char - \(remainChar)")
        
        //Remove decimal points when units are in Iota
        if (lastChar == "." && (button.titleLabel?.text!)! == "I") {
            amountToPay.text = String((amountToPay.text?.dropLast())!)
            return
        }
        
        //Don't allow leading "0" when units are in Iota
        if (firstChar == "0" && (button.titleLabel?.text!)! == "I") {
            amountToPay.text = String((amountToPay.text?.dropLast())!)
            return
        }
        
        //Remove extra leading zeros
        if firstChar == "0" && lastChar == "0" && !(remainChar.contains(".") || remainChar != "0" || remainChar.count == 0) {
            amountToPay.text = String((amountToPay.text?.dropLast())!)
            return
        }
        
        //Only allow "." after leading "0"
        if firstChar == "0" && lastChar != "." && remainChar.count == 1 {
            amountToPay.text = String((amountToPay.text?.dropLast())!)
            return
        }
        
        //If "." already exists don't allow any more "."
        if lastChar == "." && remainChar.contains(".") {
            amountToPay.text = String((amountToPay.text?.dropLast())!)
            return
        }
        
        //Add zero to leading decimal points
        if firstChar == "." {
            amountToPay.text = "0."
            return
        }
    }
    
    public func validateAmount() {
        
        validity.text = ""
        sendItButton.isEnabled = false
        
        guard let amount = Double(amountToPay.text!) else {
            return
        }
        
        print("The amount is - \(amount)")
        
        let units = button.titleLabel?.text!
        var fromUnit: IotaUnits = IotaUnits.Mi
        
        switch units {
            
        case "I":
            print("I")
            fromUnit = IotaUnits.i
            if !amount.isInteger { validity.text = "Invalid" }
        case "Ki":
            print("Ki")
            fromUnit = IotaUnits.Ki
            if !(amount * 1000).isInteger { validity.text = "Invalid" }
        case "Mi":
            print("Mi")
            fromUnit = IotaUnits.Mi
            if !(amount * 1000000).isInteger { validity.text = "Invalid" }
        case "Gi":
            print("Gi")
            fromUnit = IotaUnits.Gi
            if !(amount * 1000000000).isInteger { validity.text = "Invalid" }
            
        default:
            validity.text = "Invalid"
            print("Unexpected Unit Type")
            
        }
        
        //Debug
        if amount > Double(0) && validity.text == "" {
            sendItButton.isEnabled = true
            let amountInIota = IotaUnitsConverter.convert(amount: Float(amount), fromUnit: fromUnit, toUnit: IotaUnits.i  )
            print("Amount in Iota - \(amountInIota)")
        }
        
    }
    
    func dropDownPressed(string: String) {
        button.setTitle(string, for: .normal)
        button.dismissDropDown()
        validateAmount()
    }
    
    @IBAction func messageEdited(_ sender: Any) {
        
        let char = String(message.text!.suffix(1))
        if char.count != 0 {
            //Remove extended ASCII character
            if  Character(char).ascii == nil {
                message.text = String((message.text?.dropLast())!)
            }
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
        payeeAvatar.image = UIImage(data:receivedPayeeAvatar,scale:1.0)
        
        //Set validity text for enetered Amount to null
        validity.text = ""
        
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
        
        //Set Send It Now button to disabled until a value is entered
        sendItButton.isEnabled = false
        sendItButton.setTitleColor(UIColor.gray, for: .disabled)
        
        //Setup delegates
        message.delegate = self
        button.dropView.delegate = self
        
    }
    
    @IBAction func sendItButton(_ sender: Any) {
        
        print("I want to send - \(String(describing: amountToPay.text!)) \(String(describing: button.titleLabel?.text!)) to address - \(String(describing: receivedPayeeAddress)) with Message - \(message.text!) and with Tag - TAPS ")
        
        //Shouldn't be needed but left in for now just in case
        if validity.text == "Invalid" {
            let title = "Invalid Amount"
            let alertMessage = "The amount entered is invalid for this Unit type."
            print("Alert message is - \(alertMessage)")
            let alert = UIAlertController(title: title, message: alertMessage, preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
                
            self.present(alert, animated: true)
            
            return
        }
        
        //Shouldn't be needed but left in for now just in case
        if Double(amountToPay.text!) == 0 || amountToPay.text! == "" {
            let title = "Invalid Amount"
            let alertMessage = "Amount of Iota to send must be greater than zero."
            print("Alert message is - \(alertMessage)")
            let alert = UIAlertController(title: title, message: alertMessage, preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
            
            self.present(alert, animated: true)
            
            return
        }
        
        //Alert the user to what they are about to do
        let title = "Payment Details"
        let units = button.titleLabel?.text!
        let alertMessage = "You are about to try to send \(amountToPay.text!) \(units!) to \(payeeLabel.text!). Are you sure you want to proceed?"
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
        
        //Calculate amount to pay in Iota from input amount and units label
        let index = button.dropView.dropDownOptions.index(of: (button.titleLabel?.text!)!)
        let multiplier = pow(1000, index!)
        let intMultiplier = NSDecimalNumber(decimal: multiplier)
        let amount = Int(amountToPay.text!)! * Int(truncating: intMultiplier)
        
        print ("The amount of iotas is - \(amount)")
        
        //Assume success and store the record in core data - payment
        if CoreDataHandler.savePaymentDetails(payeeName: self.receivedPayeeName, payeeAvatar: self.receivedPayeeAvatar, amount: Int64(amount), message: self.message.text!, status: "Submitted", timestamp: Date(), bundleHash: "", tailHash: "" ) {
            print("Payment data saved sussfully")
        } else {
            print("Failed to save payment data")
        }
        
        //Limit the payment data stored in Core Data to 10 rows.
        if CoreDataHandler.limitStoredPayments() {
            print("Successfully limited number of saved payments")
        } else {
            print("Failed to limit number of saved payments")
        }
        
        //Attempt the transfer
        accountManagement.attemptTransfer(address: receivedPayeeAddress, amount: UInt64(amount), message: message.text! )
        
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


