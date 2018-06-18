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
    
    //View controller functions
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        payeesTable.delegate = self
        payeesTable.dataSource = self
        
        Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(self.refreshScanView), userInfo: nil, repeats: false)
        Timer.scheduledTimer(timeInterval: 10, target: self, selector: #selector(self.refreshScanView), userInfo: nil, repeats: false)
        Timer.scheduledTimer(timeInterval: 60, target: self, selector: #selector(self.refreshScanView), userInfo: nil, repeats: true)
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // This function is called before the segue
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        let segueID = segue.identifier
        
        if(segueID! == "makePayment"){
            // get a reference to the second view controller
            let MakePaymentViewController = segue.destination as! MakePaymentViewController
            
            // set a variable in the second view controller with the String to pass
            MakePaymentViewController.receivedPayeeDevice = payees[path.row].payeeDevice!
            MakePaymentViewController.receivedPayeeAddress = payees[path.row].payeeAddress!
            MakePaymentViewController.receivedPayeeName = payees[path.row].payeeName!
            MakePaymentViewController.receivedPayeeAvatar = payees[path.row].payeeAvatar!
    
        }
    }
    
    
    //Relod the Payee Table
    @objc func refreshScanView() {
        payeesTable.reloadData()
    }
       
    
    //Table view functions
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        print ("No of rows required for payees table = \(payees.count)")
        return payees.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        print("indexPath.row is - \(indexPath.row)")
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! PayeeTableViewCell
        
        cell.payeeAvatarView?.layer.masksToBounds = true
        cell.payeeAvatarView?.layer.borderWidth = 0
        cell.payeeAvatarView?.layer.cornerRadius = (cell.payeeAvatarView?.frame.width)! / 2
        cell.payeeAvatarView?.image = payees[indexPath.row].payeeAvatar
        
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
