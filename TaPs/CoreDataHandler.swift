//
//  CoreDataHandler.swift
//  TaPs
//
//  Created by Adrian Marks on 25/05/2018.
//  Copyright © 2018 Red Kite Projects Limited. All rights reserved.
//

import UIKit
import CoreData

class CoreDataHandler: NSObject {
    
    class func getContext() -> NSManagedObjectContext {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        
        return appDelegate.persistentContainer.viewContext
    }
    
    //********
    //PAYMENTS
    //********
    
    class func savePaymentDetails(payeeName: String, payeeAvatar: Data, amount: Int64, message: String, status: String, timestamp: Date, bundleHash: String, tailHash: String, timeToConfirm: Double ) -> Bool {
    
        let context = getContext()
        let entity = NSEntityDescription.entity(forEntityName: "Payment", in: context )
        let managedObject = NSManagedObject(entity: entity!, insertInto: context)
    
        managedObject.setValue(payeeName,       forKey: "payeeName")
        managedObject.setValue(payeeAvatar,     forKey: "payeeAvatar")
        managedObject.setValue(amount,          forKey: "amount")
        managedObject.setValue(message,         forKey: "message")
        managedObject.setValue(status,          forKey: "status")
        managedObject.setValue(timestamp,       forKey: "timestamp")
        managedObject.setValue(bundleHash,      forKey: "bundleHash")
        managedObject.setValue(tailHash,        forKey: "tailHash")
        managedObject.setValue(timeToConfirm,   forKey: "timeToConfirm")
        
        do {
            try context.save()
            return true
        } catch {
            return false
        }
    }
        
    class func fetchPayments() -> [Payment]? {
        let context = getContext()
        var payment:[Payment]? = nil
        
        do {
            payment = try context.fetch(Payment.fetchRequest())
            return payment
        } catch {
            return payment
        }
    }
    
    class func limitStoredPayments () -> Bool {
    
        let context = getContext()
        let fetchRequest: NSFetchRequest<Payment> = Payment.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        var i = 0
        if let result = try? context.fetch(fetchRequest) {
            for object in result {
                i += 1
                if i > 10 {
                    context.delete(object)
                }
            }
        } else {
            return false
        }
        
        do {
            try context.save()
            return true
        } catch {
            return false
        }
    }
    
    class func paymentActiveStatus() -> Bool {
        let context = getContext()
        
        let fetchRequest: NSFetchRequest<Payment> = Payment.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        do {
            if let payment = try context.fetch(fetchRequest).first {
                print ("Payment status is \(String(describing: payment.status))")
                if (payment.status == "Pending" || payment.status == "Promoted" ||  payment.status == "Reattached" || payment.status == "Submitted") {
                    return true
                }
            }
        } catch {
            return false
        }
        return false
    }
    
    class func updateFailedPayment() -> Bool {
        let context = getContext()
        
        let fetchRequest: NSFetchRequest<Payment> = Payment.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        if let result = try? context.fetch(fetchRequest) {
            let payment = result[0]
            payment.setValue("Failed", forKey: "status")
        }
        
        do {
            try context.save()
            return true
        } catch {
            return false
        }
    }
    
    class func updatePendingPayment(bundleHash: String, tailHash: String, timestamp: Date ) -> Bool {

        let context = getContext()
        
        let fetchRequest: NSFetchRequest<Payment> = Payment.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        if let result = try? context.fetch(fetchRequest) {
            let payment = result[0]
            payment.setValue("Pending",        forKey: "status")
            payment.setValue(bundleHash,       forKey: "bundleHash")
            payment.setValue(tailHash,         forKey: "tailHash")
            payment.setValue(timestamp,        forKey: "timestamp")
        }
        
        do {
            try context.save()
            return true
        } catch {
            return false
        }
    }
    
    class func updatePromotedPayment(bundleHash: String) -> Bool {
        
        let context = getContext()
        
        let fetchRequest: NSFetchRequest<Payment> = Payment.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        if let result = try? context.fetch(fetchRequest) {
            let payment = result[0]
            payment.setValue("Promoted",        forKey: "status")
            payment.setValue(bundleHash,       forKey: "bundleHash")
        }
        
        do {
            try context.save()
            return true
        } catch {
            return false
        }
    }
    
    class func updateReattachedPayment(bundleHash: String) -> Bool {
        
        let context = getContext()
        
        let fetchRequest: NSFetchRequest<Payment> = Payment.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        if let result = try? context.fetch(fetchRequest) {
            let payment = result[0]
            payment.setValue("Reattached",        forKey: "status")
            payment.setValue(bundleHash,       forKey: "bundleHash")
        }
        
        do {
            try context.save()
            return true
        } catch {
            return false
        }
    }
    
    class func updateConfirmedPayment(bundleHash: String) -> Bool {
        let context = getContext()
        
        let fetchRequest: NSFetchRequest<Payment> = Payment.fetchRequest()
        
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        // create an NSPredicate to get the specific instance
        let predicate = NSPredicate(format: "bundleHash = %@", bundleHash)
        fetchRequest.predicate = predicate
        
        if let result = try? context.fetch(fetchRequest) {
            let payment = result[0]
            
            let timeToConfirm = Date().timeIntervalSince(payment.timestamp!)
            
            payment.setValue("Confirmed", forKey: "status")
            payment.setValue(timeToConfirm, forKey: "timeToConfirm")
        }
        
        do {
            try context.save()
            return true
        } catch {
            return false
        }
    }
    
    //********
    //RECEIPTS
    //********
    
    class func findReceiptDetails(bundleHash: String ) -> Bool {
        
        let context = getContext()
        
        let fetchRequest: NSFetchRequest<Receipt> = Receipt.fetchRequest()
        // create an NSPredicate to get the specific instance
        let predicate = NSPredicate(format: "bundleHash = %@", bundleHash)
        fetchRequest.predicate = predicate
        
        if let result = try? context.fetch(fetchRequest) {
            
            if result == [] {
                return false
            }
            else {
                return true
            }
        }
        else {
            print ("Failed to execute Find receipts request")
            return true
        }

    }
    
    class func saveReceiptDetails(payerName: String, payerAvatar: Data, amount: Int64, message: String, status: String, timestamp: Date, bundleHash: String, timeToConfirm: Double ) -> Bool {
        
        let context = getContext()
        let entity = NSEntityDescription.entity(forEntityName: "Receipt", in: context )
        let managedObject = NSManagedObject(entity: entity!, insertInto: context)
        
        
        managedObject.setValue(payerName,       forKey: "payerName")
        managedObject.setValue(payerAvatar,     forKey: "payerAvatar")
        managedObject.setValue(amount,          forKey: "amount")
        managedObject.setValue(message,         forKey: "message")
        managedObject.setValue(status,          forKey: "status")
        managedObject.setValue(timestamp,       forKey: "timestamp")
        managedObject.setValue(bundleHash,      forKey: "bundleHash")
        managedObject.setValue(timeToConfirm,   forKey: "timeToConfirm")
        
        do {
            try context.save()
            return true
        } catch {
            return false
        }
    }
    
    class func fetchReceipts() -> [Receipt]? {
        let context = getContext()
        var receipt:[Receipt]? = nil
        
        do {
            receipt = try context.fetch(Receipt.fetchRequest())
            return receipt
        } catch {
            return receipt
        }
    }
    
    class func deleteReceipt(bundleHash: String) -> Bool {
        let context = getContext()
        
        let fetchRequest: NSFetchRequest<Receipt> = Receipt.fetchRequest()
        // create an NSPredicate to get the specific instance
        let predicate = NSPredicate(format: "bundleHash = %@", bundleHash)
        fetchRequest.predicate = predicate
        
        if let result = try? context.fetch(fetchRequest) {
            let receipt = result[0]
            context.delete(receipt)
            return true
        }
        else {
            return false
        }
        
    }
    
    class func limitStoredReceipts () -> Bool {
        
        let context = getContext()
        let fetchRequest: NSFetchRequest<Receipt> = Receipt.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        var i = 0
        if let result = try? context.fetch(fetchRequest) {
            for object in result {
                i += 1
                if i > 10 {
                    context.delete(object)
                }
            }
        } else {
            return false
        }
        
        do {
            try context.save()
            return true
        } catch {
            return false
        }
    }
    
    class func updateConfirmedReceipt(bundleHash: String) -> Bool {
        let context = getContext()
        
        let fetchRequest: NSFetchRequest<Receipt> = Receipt.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        // create an NSPredicate to get the specific instance
        let predicate = NSPredicate(format: "bundleHash = %@", bundleHash)
        fetchRequest.predicate = predicate
        
        if let result = try? context.fetch(fetchRequest) {
            for receipt in result {
                let timeToConfirm = Date().timeIntervalSince(receipt.timestamp!)
                receipt.setValue("Confirmed", forKey: "status")
                receipt.setValue(timeToConfirm, forKey: "timeToConfirm")
            }
        }
        
        do {
            try context.save()
            return true
        } catch {
            return false
        }
    }
    
    //*************
    //CLEAR HISTORY
    //*************
    
    
    class func deleteHistory() -> Bool {
        let context = getContext()
        
        let fetchRequest1: NSFetchRequest<Receipt> = Receipt.fetchRequest()
        
        if let result = try? context.fetch(fetchRequest1) {
            for object in result {
                context.delete(object)
            }
        } else {
            return false
        }
        
        let fetchRequest2: NSFetchRequest<Payment> = Payment.fetchRequest()
        
        if let result = try? context.fetch(fetchRequest2) {
            for object in result {
                context.delete(object)
            }
        } else {
            return false
        }
        
        do {
            try context.save()
            return true
        } catch {
            return false
        }
    }
    
    
    
}
