//
//  TextUtility.swift
//  TaPs
//
//  Created by Redkite - Adrian Marks on 10/05/2018.
//  Copyright © 2018 Red Kite Projects Limited. All rights reserved.
//

import Foundation
import UIKit

private var __maxLengths = [UITextField: Int]()

extension UITextField {
    @IBInspectable var maxLength: Int {
        get {
            guard let l = __maxLengths[self] else {
                return 150 // (global default-limit. or just, Int.max)
            }
            return l
        }
        set {
            __maxLengths[self] = newValue
            addTarget(self, action: #selector(fix), for: .editingChanged)
        }
    }
    @objc func fix(textField: UITextField) {
        let t = textField.text
        textField.text = t?.safelyLimitedTo(length: maxLength)
    }
}

extension String
{
    func safelyLimitedTo(length n: Int)->String {
        if (self.count <= n) {
            return self
        }
        return String( Array(self).prefix(upTo: n) )
    }
    
    mutating func rightPad(count: Int, character: Character) {
        if self.count >= count { return }
        for _ in self.count..<count {
            self.append(character)
        }
    }
    
    func rightPadded(count: Int, character: Character) -> String {
        var str = self
        if str.count >= count { return str }
        for _ in self.count..<count {
            str.append(character)
        }
        return str
    }
    
    func substring(from: Int, to: Int) -> String {
        let start = index(startIndex, offsetBy: from)
        let end = index(start, offsetBy: to - from)
        return String(self[start ..< end])
    }
    
}

extension StringProtocol {
    var ascii: [UInt32] {
        return unicodeScalars.filter{$0.isASCII}.map{$0.value}
    }
}

extension Character {
    var ascii: UInt32? {
        return String(self).unicodeScalars.filter{$0.isASCII}.first?.value
    }
}
