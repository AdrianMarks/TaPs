//
//  PaymentsViewController.swift
//  TaPs
//
//  Created by Redkite - Adrian Marks on 22/03/2018.
//  Copyright © 2018 Red Kite Projects Limited. All rights reserved.
//

import UIKit
import SwiftKeychainWrapper
import CoreBluetooth

class PayeeTableViewCell: UITableViewCell {
    @IBOutlet weak var payeeAvatarView: UIImageView!
    @IBOutlet weak var payeeLabel: UILabel!
}

class PayeesViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    //UI
    @IBOutlet weak var payeesTable: UITableView!
    
    //Data
    var timer1: Timer? = nil
    
    //Keychain Data
    fileprivate var savedSeed: String? {
        get {
            return KeychainWrapper.standard.string(forKey: TAPConstants.kSeed)
        }
        set {
            KeychainWrapper.standard.set(newValue!, forKey: TAPConstants.kSeed)
        }
    }
    
    //View controller functions
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        payeesTable.delegate = self
        payeesTable.dataSource = self
        
        Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(self.refreshScanView), userInfo: nil, repeats: false)
        Timer.scheduledTimer(timeInterval: 10, target: self, selector: #selector(self.refreshScanView), userInfo: nil, repeats: false)
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        
        refreshScanView()

        if timer1 == nil {
            timer1 = Timer.scheduledTimer(timeInterval: 30, target: self, selector: #selector(self.refreshScanView), userInfo: nil, repeats: true)
        }
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if timer1 != nil {
            timer1!.invalidate()
            timer1 = nil
        }

    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // This function is called before the segue
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if savedSeed?.count != 81 {
            
            let title = "Invalid Seed Entered"
            let alertMessage = "You cannot make payments until you have entered a valid Seed in Settings"
            print("Alert message is - \(alertMessage)")
            let alert = UIAlertController(title: title, message: alertMessage, preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
            
            self.present(alert, animated: true)
            
            return
        }
        
        let segueID = segue.identifier
        
        if(segueID! == "makePayment"){
            // get a reference to the second view controller
            let MakePaymentViewController = segue.destination as! MakePaymentViewController
            
            // set a variable in the second view controller with the String to pass
            MakePaymentViewController.receivedPayeePeripheral = payees[path.row].payeePeripheral!
            MakePaymentViewController.receivedPayeeReceiptChar = payees[path.row].payeeReceiptChar!
            MakePaymentViewController.receivedPayeeAddress = payees[path.row].payeeAddress!
            MakePaymentViewController.receivedPayeeName = payees[path.row].payeeName!
            MakePaymentViewController.receivedPayeeAvatar = payees[path.row].payeeAvatar
    
        }
    }
    
    
    //Relod the Payee Table
    @objc func refreshScanView() {
        
        payees = []
        //Loop through payeesBuilt table and for each row where all elements are built transfer the row to the payees table
        for builtPayees in payeesBuilt {
            if builtPayees.payeeName != "" && builtPayees.payeeAvatar.count > 0 && builtPayees.payeeAddress != "" {
                payees.append(builtPayees)
                print("BUILT TRANSFER - Payee Name is \(builtPayees.payeeName!) - Payee Avatar Count is \(builtPayees.payeeAvatar.count) - Payee Address Count is \(builtPayees.payeeAddress!.count)")
            }
        }
        
        print("\nDB1 Build Table  - \(payeesBuild)\n")
        print("\nDB1 Built Table  - \(payeesBuilt)\n")
        print("\nDB1 Payees Table - \(payees)\n")
        print("\nDB1 Peripherals - \(peripherals)\n")
        
        payeesTable.reloadData()
    }
       
    
    //Table view functions
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        print ("No of rows required for payees table = \(payees.count)")
        return payees.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! PayeeTableViewCell
        
        cell.payeeAvatarView?.layer.masksToBounds = true
        cell.payeeAvatarView?.layer.borderWidth = 0
        cell.payeeAvatarView?.layer.cornerRadius = (cell.payeeAvatarView?.frame.width)! / 2
        cell.payeeAvatarView?.image = UIImage(data:payees[indexPath.row].payeeAvatar,scale:1.0)
        
        let payee = payees[indexPath.row].payeeName
        cell.payeeLabel?.text = payee
        
        return cell
    }
    
    internal func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        path = indexPath
        return indexPath
    }
    
    internal func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: path, animated: true)
    }


}
