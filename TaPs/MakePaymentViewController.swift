//
//  MakePaymentViewController.swift
//  TaPs
//
//  Created by Redkite - Adrian Marks on 22/03/2018.
//  Copyright © 2018 Red Kite Projects Limited. All rights reserved.
//

import UIKit
import CoreBluetooth

class MakePaymentViewController: UIViewController, UITextFieldDelegate {
  
    //UI
    @IBOutlet weak var payeeLabel: UILabel!
    @IBOutlet weak var payeeAvatar: UIImageView!
    @IBOutlet weak var amountToPay: UITextField!
    @IBOutlet weak var optionalTag: UITextField!
    
    var button = DropDownButton()
    
    //Data
    var centralManager: CBCentralManager!
    
    // This variable will hold the data being passed from the Payments View Controller
    var receivedPayeeName: String = ""
    var receivedPayeeAvatar: UIImage = UIImage()
    var receivedPayeeDevice: CBPeripheral!
    var receivedPayeeAddress: String!
    
    var timer = Timer()
    
    //UI Actions
    @IBAction func optionalTagEdited(_ sender: Any) {
        optionalTag.text = optionalTag.text!.uppercased()
        let string = "ABCDEFGHIJKLMNOPQRSTUVWXYZ9"
        let substring = optionalTag.text!.suffix(1)
        if !string.contains(substring) {
            optionalTag.text = String((optionalTag.text?.dropLast())!)
        }
    }
    
    @IBAction func amountToPayEdited(_ sender: Any) {
        if amountToPay.text!.prefix(1) == "0" {
            amountToPay.text = String((amountToPay.text?.dropFirst())!)
        }
    }
    
    @IBAction func sendItButton(_ sender: Any) {
        print("I want to send - \(String(describing: amountToPay.text!)) \(String(describing: button.titleLabel?.text!)) to address - \(String(describing: receivedPayeeAddress)) with Tag - \(optionalTag.text!))")
        
        payments.append(paidPayee(payeeName: receivedPayeeName, payeeAvatar: receivedPayeeAvatar, payeeAmount: (amountToPay.text!) + " " + (button.titleLabel?.text!)!, status: ""))
    
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
        button.dropView.dropDownOptions = ["I","Ki","Gi","Mi","Ti","Pi"]
        
        optionalTag.delegate = self
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
