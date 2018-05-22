//
//  HistoryViewController.swift
//  TaPs
//
//  Created by Redkite - Adrian Marks on 22/03/2018.
//  Copyright © 2018 Red Kite Projects Limited. All rights reserved.
//

import UIKit
import SwiftKeychainWrapper
import IotaKit

struct paidPayee {
    var payeeName: String?  = ""
    var payeeAvatar: UIImage? = nil
    var payeeAmount: String? = ""
    var status: String? = ""
    
}

class PaymentsTableViewCell: UITableViewCell {
    @IBOutlet weak var payeeAvatarView: UIImageView!
    @IBOutlet weak var payeeName: UILabel!
    @IBOutlet weak var payeeAmount: UILabel!
}

var payments: [paidPayee] = []

class HistoryViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
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
    @IBOutlet weak var paidPayeesTable: UITableView!
    
    
    @IBOutlet weak var accountBalance: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        paidPayeesTable.delegate = self
        paidPayeesTable.dataSource = self
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        
        paidPayeesTable.reloadData()
        
        var iotaBalance: Double = 0
        let iota = Iota(node: node)
        
        //Obtain the account balance
        iota.accountData(seed: savedSeed!, { (account) in
            iotaBalance = Double(account.balance)
            DispatchQueue.main.async {
                self.accountBalance.text = IotaUnitsConverter.iotaToString(amount: UInt64(iotaBalance))
            }
            
        }, error: { (error) in
            print("API call to retrieve the no of addresses failed with error -\(error)")
        }, log: { (log) in
            print(log) }
        )
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        print ("No of rows required for payments table = \(payments.count)")
        return payments.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! PaymentsTableViewCell
        
        cell.payeeAvatarView?.layer.masksToBounds = true
        cell.payeeAvatarView?.layer.borderWidth = 0
        cell.payeeAvatarView?.layer.cornerRadius = (cell.payeeAvatarView?.frame.width)! / 2
        
        cell.payeeAvatarView?.image = payments[indexPath.row].payeeAvatar
        cell.payeeName?.text = payments[indexPath.row].payeeName
        cell.payeeAmount?.text = payments[indexPath.row].payeeAmount
        
        return cell
    }
    

}

