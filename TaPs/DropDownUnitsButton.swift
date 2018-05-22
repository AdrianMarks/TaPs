//
//  DropDownUnitsButton.swift
//  TaPs
//
//  Created by Adrian Marks on 21/05/2018.
//  Copyright © 2018 Red Kite Projects Limited. All rights reserved.
//

import Foundation
import UIKit

protocol DropDownDelegate {
    func dropDownPressed(string : String)
}

class DropDownButton: UIButton, DropDownDelegate {
    
    func dropDownPressed(string: String) {
        self.setTitle(string, for: .normal)
        self.dismissDropDown()
    }
    
    var dropView = DropDownView()
    
    var height = NSLayoutConstraint()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.backgroundColor = UIColor(red: 0.0588, green: 0.6196, blue: 0.5059, alpha: 1.0)
        
        dropView = DropDownView.init(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        dropView.delegate = self
        dropView.translatesAutoresizingMaskIntoConstraints = false
        
    }
    
    override func didMoveToSuperview() {
        
        //If statement is a bit of a botch - otherwise this function is called when returning from Make Payment viewConntroller
        if self.superview != nil {
            self.superview?.addSubview(dropView)
            self.superview?.bringSubview(toFront: dropView)
            dropView.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
            dropView.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
            dropView.widthAnchor.constraint(equalTo: self.widthAnchor).isActive = true
            height = dropView.heightAnchor.constraint(equalToConstant: 0)
        }
    }
    
    var isOpen = false
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isOpen == false {
            
            isOpen = true
            
            NSLayoutConstraint.deactivate([self.height])
            
            if self.dropView.dropDownTableView.contentSize.height > 350 {
                self.height.constant = 350
            } else {
                self.height.constant = self.dropView.dropDownTableView.contentSize.height
            }
            
            NSLayoutConstraint.activate([self.height])
            
            UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.5, options: .curveEaseInOut, animations: {
                self.dropView.layoutIfNeeded()
                self.dropView.center.y += self.dropView.frame.height / 2
            }, completion: nil )
            
        } else {
            
            isOpen = false
            
            NSLayoutConstraint.deactivate([self.height])
            self.height.constant = 0
            NSLayoutConstraint.activate([self.height])
            
            UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.5, options: .curveEaseInOut, animations: {
                self.dropView.center.y -= self.dropView.frame.height / 2
                self.dropView.layoutIfNeeded()
            }, completion: nil )
            
        }
    }
    
    func dismissDropDown() {
        isOpen = false
        
        NSLayoutConstraint.deactivate([self.height])
        self.height.constant = 0
        NSLayoutConstraint.activate([self.height])
        
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.5, options: .curveEaseInOut, animations: {
            self.dropView.center.y -= self.dropView.frame.height / 2
            self.dropView.layoutIfNeeded()
        }, completion: nil )
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class DropDownView: UIView, UITableViewDelegate, UITableViewDataSource {
    
    var dropDownOptions = [String]()
    var dropDownTableView = UITableView()
    
    var delegate : DropDownDelegate!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        dropDownTableView.backgroundColor = UIColor(red: 0.0588, green: 0.6196, blue: 0.5059, alpha: 1.0)
        self.backgroundColor = UIColor(red: 0.0588, green: 0.6196, blue: 0.5059, alpha: 1.0)
        
        dropDownTableView.delegate = self
        dropDownTableView.dataSource = self
        
        dropDownTableView.translatesAutoresizingMaskIntoConstraints = false
        
        self.addSubview(dropDownTableView)
        
        dropDownTableView.leftAnchor.constraint(equalTo: self.leftAnchor).isActive = true
        dropDownTableView.rightAnchor.constraint(equalTo: self.rightAnchor).isActive = true
        dropDownTableView.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        dropDownTableView.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dropDownOptions.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        cell.textLabel?.text = dropDownOptions[indexPath.row]
        cell.backgroundColor = UIColor(red: 0.0588, green: 0.6196, blue: 0.5059, alpha: 1.0)
        cell.textLabel?.textColor = UIColor.white
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.delegate.dropDownPressed(string: dropDownOptions[indexPath.row])
        self.dropDownTableView.deselectRow(at: indexPath, animated: true)
    }
    
}

