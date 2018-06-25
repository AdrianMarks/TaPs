//
//  PaymentsViewController.swift
//  TaPs
//
//  Created by Redkite - Adrian Marks on 22/03/2018.
//  Copyright © 2018 Red Kite Projects Limited. All rights reserved.
//

import UIKit
import SwiftKeychainWrapper
import IotaKit
import CoreData

class PaymentsTableViewCell: UITableViewCell {
    @IBOutlet weak var payeeAvatarView: UIImageView!
    @IBOutlet weak var payeeName: UILabel!
    @IBOutlet weak var payeeAmount: UILabel!
    @IBOutlet weak var paymentDate: UILabel!
    @IBOutlet weak var message: UILabel!
    @IBOutlet weak var paymentStatus: UILabel!
    @IBOutlet weak var timeToConfirm: UILabel!
}

class PaymentsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, NSFetchedResultsControllerDelegate {
    
    //Keychain Data
    fileprivate var savedSeed: String? {
        get {
            return KeychainWrapper.standard.string(forKey: TAPConstants.kSeed)
        }
        set {
            KeychainWrapper.standard.set(newValue!, forKey: TAPConstants.kSeed)
        }
    }
    fileprivate var savedBalance: String? {
        get {
            return KeychainWrapper.standard.string(forKey: TAPConstants.kBalance)
        }
        set {
            KeychainWrapper.standard.set(newValue!, forKey: TAPConstants.kBalance)
        }
    }
    
    //UI
    @IBOutlet weak var paidPayeesTable: UITableView!
    @IBOutlet weak var accountBalance: UILabel!
    
    //Data
    var timer1 = Timer()
    var timer2 = Timer()
    
    //NSFetchedResults
    fileprivate lazy var fetchedResultsController: NSFetchedResultsController<Payment> = {
        // Create Fetch Request
        let fetchRequest: NSFetchRequest<Payment> = Payment.fetchRequest()
        
        // Configure Fetch Request
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        // Create Fetched Results Controller
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: CoreDataHandler.getContext(), sectionNameKeyPath: nil, cacheName: nil)
        
        // Configure Fetched Results Controller
        fetchedResultsController.delegate = self
        
        return fetchedResultsController
    }()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        //Fetch payment details on load
        do {
            try self.fetchedResultsController.performFetch()
        } catch {
            let fetchError = error as NSError
            print("Unable to Perform Fetch Request")
            print("\(fetchError), \(fetchError.localizedDescription)")
        }
        
        paidPayeesTable.delegate = self
        paidPayeesTable.dataSource = self
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        
        refreshTableView()
        updateBalance()
        
        timer1 = Timer.scheduledTimer(timeInterval: 30, target: self, selector: #selector(self.refreshTableView), userInfo: nil, repeats: true)
        timer2 = Timer.scheduledTimer(timeInterval: 30, target: self, selector: #selector(self.updateBalance), userInfo: nil, repeats: true)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        timer1.invalidate()
        timer2.invalidate()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //Reload the Payee Table
    @objc func refreshTableView() {
        paidPayeesTable.reloadData()
    }
    
    //Update the account balance
    @objc func updateBalance() {
        accountBalance.text = savedBalance
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let payments = fetchedResultsController.fetchedObjects else {return 0}
        print ("No of rows required for payments table = \(payments.count)")
        return payments.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "PayeesCell", for: indexPath) as? PaymentsTableViewCell else {
            fatalError("Unexpected Index Path")
        }
        
        tableView.rowHeight = 90
        let payment = fetchedResultsController.object(at: indexPath)
        
        cell.payeeAvatarView?.layer.masksToBounds = true
        cell.payeeAvatarView?.layer.borderWidth = 0
        cell.payeeAvatarView?.layer.cornerRadius = (cell.payeeAvatarView?.frame.width)! / 2
        
        cell.payeeAvatarView?.image = UIImage(data:payment.payeeAvatar!,scale:1.0)
        cell.payeeName?.text = payment.payeeName
        
        let date = payment.timestamp
        let dayTimePeriodFormatter = DateFormatter()
        dayTimePeriodFormatter.dateFormat = "dd MMM YYYY hh:mm a"
        let dateString = dayTimePeriodFormatter.string(from: date!)
        cell.paymentDate?.text = dateString
        
        let time = payment.timeToConfirm
        if time > 0 {
            cell.timeToConfirm?.text = stringFromTimeInterval(interval: TimeInterval(time))
        }
        else
        {
            cell.timeToConfirm?.text = "--:--"
        }
        
        cell.payeeAmount?.text = IotaUnitsConverter.iotaToString(amount: UInt64(payment.amount))
        cell.message?.text = payment.message
        
        if (payment.status == "Pending" || payment.status == "Promoted") {
            let iota = Iota(node: node)
            if payment.bundleHash != nil {
                iota.findTransactions(bundles: [payment.bundleHash!], { (success) in
                    iota.latestInclusionStates(hashes: success, { (success) in
                        if success.contains(true) {
                            DispatchQueue.main.async {
                                if CoreDataHandler.updateConfirmedPayment(bundleHash: payment.bundleHash!) {
                                    print("Updated status of payment to 'Confirmed' successfully")
                                } else {
                                    print("Failed updating status of payment to 'Confirmed'")
                                }
                            }
                        }
                        
                        print("Inclusion Status - \(success)")
                        print("Payment BundleHash - \(payment.bundleHash!)")
                    } , { (error) in
                        print("Failed to retrieve inclusion state for \(payment.message!)")
                    })
                } , error: { (error) in
                    print("Failed to retrieve transaction hashes for \(payment.bundleHash!)")
                })
            }
        }
        
        cell.paymentStatus?.text = payment.status
        if payment.status == "Confirmed" {
            cell.paymentStatus?.textColor = UIColor(red: 0.0588, green: 0.6196, blue: 0.5059, alpha: 1.0)
        } else if payment.status == "Failed" {
            cell.paymentStatus?.textColor = UIColor.red
        } else if payment.status == "Pending" {
            cell.paymentStatus?.textColor = UIColor.blue
        } else if payment.status == "Promoted" {
            cell.paymentStatus?.textColor = UIColor.blue
        } else if payment.status == "Submitted" {
            cell.paymentStatus?.textColor = UIColor.black
        }
        
        return cell
    }
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        paidPayeesTable.beginUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            paidPayeesTable.insertRows(at: [newIndexPath!], with: .fade)
        case .delete:
            paidPayeesTable.deleteRows(at: [indexPath!], with: .fade)
        case .update:
            paidPayeesTable.reloadRows(at: [indexPath!], with: .fade)
        case .move:
            paidPayeesTable.moveRow(at: indexPath!, to: newIndexPath!)
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        paidPayeesTable.endUpdates()
    }
    
}
