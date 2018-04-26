//
//  ReadWriteFileFS.swift
//  Iota Tap
//
//  Created by Redkite - Adrian Marks on 24/04/2018.
//  Copyright © 2018 Red Kite Projects Limited. All rights reserved.
//

import Foundation
import UIKit

class ReadWriteFileFS{
    
    func writeFile(_ image: UIImage, _ imgName: String) -> Bool{
        let imageData = UIImageJPEGRepresentation(image, 1)
        let relativePath = imgName
        let path = self.documentsPathForFileName(name: relativePath)
        
        do {
            try imageData?.write(to: path, options: .atomic)
        } catch {
            return false
        }
        return true
    }
    
    func readFile(_ name: String) -> UIImage{
        let fullPath = self.documentsPathForFileName(name: name)
        var image = UIImage()
        
        if FileManager.default.fileExists(atPath: fullPath.path){
            image = UIImage(contentsOfFile: fullPath.path)!
        }else{
            image = UIImage(named: "avatar.png")!  //a default place holder image from apps asset folder
        }
        return image
    }
}

extension ReadWriteFileFS{
    func documentsPathForFileName(name: String) -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let path = paths[0]
        let fullPath = path.appendingPathComponent(name)
        return fullPath
    }
}
