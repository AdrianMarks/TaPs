//
//  ReceiptsViewController.swift
//  TaPs
//
//  Created by Redkite - Adrian Marks on 22/03/2018.
//  Copyright © 2018 Red Kite Projects Limited. All rights reserved.
//

import UIKit
import SwiftKeychainWrapper
import IotaKit
import CoreData

class ReceiptsTableViewCell: UITableViewCell {
    @IBOutlet weak var payerAvatarView: UIImageView!
    @IBOutlet weak var payerName: UILabel!
    @IBOutlet weak var receiptAmount: UILabel!
    @IBOutlet weak var receiptDate: UILabel!
    @IBOutlet weak var receiptMessage: UILabel!
    @IBOutlet weak var receiptStatus: UILabel!
    @IBOutlet weak var timeToConfirm: UILabel!
}

class ReceiptsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, NSFetchedResultsControllerDelegate {
    
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
    @IBOutlet weak var paidPayersTable: UITableView!
    @IBOutlet weak var accountBalance: UILabel!
    
    //Data
    var timer1 = Timer()
    var timer2 = Timer()
    
    //NSFetchedResults
    fileprivate lazy var fetchedResultsController: NSFetchedResultsController<Receipt> = {
        // Create Fetch Request
        let fetchRequest: NSFetchRequest<Receipt> = Receipt.fetchRequest()
        
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
        
        paidPayersTable.delegate = self
        paidPayersTable.dataSource = self
        
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
        paidPayersTable.reloadData()
    }
    
    //Update the account balance
    @objc func updateBalance() {
        accountBalance.text = savedBalance
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let receipts = fetchedResultsController.fetchedObjects else {return 0}
        print ("No of rows required for receipts table = \(receipts.count)")
        return receipts.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "PayersCell", for: indexPath) as? ReceiptsTableViewCell else {
            fatalError("Unexpected Index Path")
        }
        
        tableView.rowHeight = 90
        let receipt = fetchedResultsController.object(at: indexPath)
        
        cell.payerAvatarView?.layer.masksToBounds = true
        cell.payerAvatarView?.layer.borderWidth = 0
        cell.payerAvatarView?.layer.cornerRadius = (cell.payerAvatarView?.frame.width)! / 2
        
        cell.payerAvatarView?.image = UIImage(data:receipt.payerAvatar!,scale:1.0)
        cell.payerName?.text = receipt.payerName
        
        let date = receipt.timestamp
        let dayTimePeriodFormatter = DateFormatter()
        dayTimePeriodFormatter.dateFormat = "dd MMM YYYY hh:mm a"
        let dateString = dayTimePeriodFormatter.string(from: date!)
        cell.receiptDate?.text = dateString
        
        let time = receipt.timeToConfirm
        if time > 0 {
            cell.timeToConfirm?.text = stringFromTimeInterval(interval: TimeInterval(time))
        }
        else
        {
            cell.timeToConfirm?.text = "--:--"
        }
        
        cell.receiptAmount?.text = IotaUnitsConverter.iotaToString(amount: UInt64(receipt.amount))
        cell.receiptMessage?.text = receipt.message
        
        if receipt.status == "Pending" {
            let iota = Iota(node: node)
            if receipt.bundleHash != nil {
                iota.findTransactions(bundles: [receipt.bundleHash!], { (success) in
                    iota.latestInclusionStates(hashes: success, { (success) in
                        if success.contains(true) {
                            DispatchQueue.main.async {
                                if CoreDataHandler.updateConfirmedReceipt(bundleHash: receipt.bundleHash!) {
                                    print("Updated status of payment to 'Confirmed' successfully")
                                } else {
                                    print("Failed updating payment on IOTA API confimed")
                                }
                            }
                        }
                        
                        print("Inclusion Status - \(success)")
                        print("Payment BundleHash - \(receipt.bundleHash!)")
                    } , { (error) in
                        print("Failed to retrieve inclusion state for \(receipt.message!)")
                    })
                } , error: { (error) in
                    print("Failed to retrieve transaction hashes for \(receipt.bundleHash!)")
                    
                })
            }
        }
        
        cell.receiptStatus?.text = receipt.status
        if receipt.status == "Confirmed" {
            cell.receiptStatus?.textColor = UIColor(red: 0.0588, green: 0.6196, blue: 0.5059, alpha: 1.0)
        } else if receipt.status == "Pending" {
            cell.receiptStatus?.textColor = UIColor.blue
        }
        
        return cell
    }
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        paidPayersTable.beginUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            paidPayersTable.insertRows(at: [newIndexPath!], with: .fade)
        case .delete:
            paidPayersTable.deleteRows(at: [indexPath!], with: .fade)
        case .update:
            paidPayersTable.reloadRows(at: [indexPath!], with: .fade)
        case .move:
            paidPayersTable.moveRow(at: indexPath!, to: newIndexPath!)
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        paidPayersTable.endUpdates()
    }
    
}
