//
//  AvatarCaptureController.swift
//  AvatarCapture
//
//  Created by John Murphy on 3/28/18.
//  Copyright © 2018 John Murphy. All rights reserved.
//

import UIKit
import QuartzCore
import AVFoundation
import FontAwesome_swift

public protocol AvatarCaptureControllerDelegate: NSObjectProtocol {
    func imageSelected(image: UIImage)
    func imageSelectionCancelled()
}

open class AvatarCaptureController: UIViewController {
    public var delegate: AvatarCaptureControllerDelegate?
    public var image: UIImage?
    
    var previousFrame: CGRect?
    var isCapturing: Bool?
    var avatarView: UIImageView?
    var captureView: UIView?
    var captureSession: AVCaptureSession?
    var stillImageOutput: AVCapturePhotoOutput?
    var captureDevice: AVCaptureDevice?
    var captureVideoPreviewLayer: AVCaptureVideoPreviewLayer?
    var isCapturingImage: Bool?
    var capturedImageView: UIImageView?
    var picker: UIImagePickerController?
    var imageSelectedView: UIView?
    var selectedImage: UIImage?
    var resourceBundle: Bundle?
    
    // MARK: View Controller Overrides
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        isCapturing = false
        
        let singleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(startCapture))
        view.addGestureRecognizer(singleTapGestureRecognizer)
        
        // initialize the avatar view
        avatarView = UIImageView.init(frame: view.frame)
        avatarView?.image = image
        avatarView?.autoresizingMask = UIView.AutoresizingMask(rawValue: UIView.AutoresizingMask.RawValue(UInt8(UIView.AutoresizingMask.flexibleHeight.rawValue) | UInt8(UIView.AutoresizingMask.flexibleWidth.rawValue)))
        avatarView?.contentMode = .scaleAspectFill
        avatarView?.layer.masksToBounds = true
        avatarView?.layer.cornerRadius = view.bounds.width / 2
        view.addSubview(avatarView!)
        
        // get the resource bundle
        let frameworkBundle = Bundle(for: AvatarCaptureController.self)
        let bundleUrl = frameworkBundle.resourceURL?.appendingPathComponent("AvatarCapture.bundle")
        resourceBundle = Bundle(url: bundleUrl!)
        
    }
    
    override open func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        view.frame = (view.superview?.bounds)!
        view.layer.cornerRadius = view.bounds.width / 2
        avatarView?.layer.cornerRadius = view.bounds.width / 2
    }
    
    override open func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: Exposed methods
    @objc open func startCapture() {
        if isCapturing! {
            return
        }
        
        isCapturing = true
        for subView in view.subviews {
            subView.removeFromSuperview()
        }
        previousFrame = view.convert(view.frame, to: nil)
        
        initializeCaptureView()
        
        if let device = getCaptureDevice() {
            let input = try? AVCaptureDeviceInput.init(device: device)
            
            if let input = input {
                captureSession?.addInput(input)
                
                stillImageOutput = AVCapturePhotoOutput()
                captureSession?.addOutput(stillImageOutput!)
                
                addCameraControls()
            }
        }
        
        addOtherControls()
        
        captureSession?.startRunning()
    }
    
    open func endCapture() {
        captureSession?.stopRunning()

        captureVideoPreviewLayer?.removeFromSuperlayer()
        for subview in (captureView?.subviews)! {
            subview.removeFromSuperview()
        }
        
        avatarView = UIImageView.init(frame: CGRect(x: 0,
                                                    y: 0,
                                                    width: (previousFrame?.width)!,
                                                    height: (previousFrame?.height)!))
        avatarView?.image = image
        avatarView?.contentMode = .scaleAspectFill
        avatarView?.layer.masksToBounds = true
        avatarView?.layer.cornerRadius = (avatarView?.frame.width)! / 2
        
        view.addSubview(avatarView!)
        view.layer.cornerRadius = view.frame.width / 2
        
        captureView?.removeFromSuperview()
        isCapturing = false
        
        // save avatar image to file and store path in UserDefaults
        let readWriteFileFS = ReadWriteFileFS()
        if !readWriteFileFS.writeFile(image!, "avatar_saved.jpg") {
            print("Failed to save avatar image!")
        }
        
        // save small avatar image to file and store path in UserDefaults
        let resizedImage = self.resizeImage(image: image!, targetSize: CGSize(width:60.0, height:60.0))
        
        if !readWriteFileFS.writeFile(resizedImage, "small_avatar_saved.jpg") {
            print("Failed to save small avatar image!")
        }
        
    }
    
    @objc open func swapCameras() {
        if isCapturingImage != true {
            let deviceDiscoverySession = AVCaptureDevice.DiscoverySession.init(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .unspecified)
            
            if captureDevice?.position == AVCaptureDevice.Position.back {
                for device in deviceDiscoverySession.devices {
                    if device.position == .front {
                        captureDevice = device
                        break
                    }
                }
            } else if captureDevice?.position == AVCaptureDevice.Position.front {
                for device in deviceDiscoverySession.devices {
                    if device.position == .back {
                        captureDevice = device
                        break
                    }
                }
            }
            
            captureSession?.beginConfiguration()
            let newInput = try? AVCaptureDeviceInput (device: captureDevice!)
            for oldInput in (captureSession?.inputs)! {
                captureSession?.removeInput(oldInput)
            }
            captureSession?.addInput(newInput!)
            captureSession?.commitConfiguration()
        }
    }
    
    @objc open func showImagePicker() {
        picker = UIImagePickerController()
        picker?.sourceType = .photoLibrary
        picker?.delegate = self
        present(picker!, animated: true, completion: nil)
    }
    
    // MARK: Private methods
    func addOtherControls() {
        // library picker button
        var showImagePickerButton = UIButton(frame: CGRect(x:(view.window?.frame.width)! - 40,
                                                          y: (view.window?.frame.height)! - 40 - 27,
                                                          width: 27,
                                                          height: 27))
        showImagePickerButton = setButtonProperties(button: showImagePickerButton, fontSize: 27, icon: .clone, selector: #selector(showImagePicker))
        captureView?.addSubview(showImagePickerButton)
        
        // cancel button
        var cancelButton = UIButton(frame: CGRect(x:view.frame.origin.x + 20,
                                                 y: view.frame.origin.y + 40,
                                                 width: 32,
                                                 height: 32))
        cancelButton = setButtonProperties(button: cancelButton, fontSize: 32, icon: .close, selector: #selector(cancel))
        captureView?.addSubview(cancelButton)
        
        imageSelectedView = UIView.init(frame: (captureView?.frame)!)
        imageSelectedView?.backgroundColor = UIColor.clear
        imageSelectedView?.addSubview(capturedImageView!)
        
        let overlayView = UIView.init(frame: CGRect(x: 0,
                                                    y: (previousFrame?.origin.y)! + (previousFrame?.height)!,
                                                    width: (captureView?.frame.width)!,
                                                    height: 60))
        imageSelectedView?.addSubview(overlayView)
        
        var selectPhotoButton = UIButton(frame: CGRect(x:(previousFrame?.origin.x)!,
                                                      y: 0,
                                                      width: 32,
                                                      height: 32))
        selectPhotoButton = setButtonProperties(button: selectPhotoButton, fontSize: 32, icon: .check, selector: #selector(photoSelected))
        overlayView.addSubview(selectPhotoButton)
        
        var cancelSelectPhotoButton = UIButton(frame: CGRect(x:(previousFrame?.origin.x)! + (previousFrame?.width)! - 32,
                                                            y: 0,
                                                            width: 32,
                                                            height: 32))
        cancelSelectPhotoButton = setButtonProperties(button: cancelSelectPhotoButton, fontSize: 32, icon: .close, selector: #selector(cancelSelectedPhoto))
        overlayView.addSubview(cancelSelectPhotoButton)
    }
    
    func addCameraControls() {
        // shutter button
        let shutterButton = UIButton(frame: CGRect(x:(previousFrame?.origin.x)! + ((previousFrame?.width)! / 2)-50,
                                                   y: (view.window?.frame.height)! - 40 - 100,
                                                   width: 100,
                                                   height: 100))
        
        shutterButton.setImage(UIImage(named: "shutter", in: resourceBundle, compatibleWith: nil), for: .normal)
        shutterButton.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
        shutterButton.layer.cornerRadius = 20
        captureView?.addSubview(shutterButton)
        
        // render swap camera
        var swapCamerasButton = UIButton(frame: CGRect(x:view.frame.origin.x + 20,
                                                      y: (view.window?.frame.height)! - 40 - 25,
                                                      width: 47,
                                                      height: 25))
        
        swapCamerasButton = setButtonProperties(button: swapCamerasButton, fontSize: 25, icon: .refresh, selector: #selector(swapCameras))
        captureView?.addSubview(swapCamerasButton)
    }
    
    func setButtonProperties(button: UIButton, fontSize: Int, icon: FontAwesome, selector: Selector) -> UIButton {
        button.addTarget(self, action: selector, for: .touchUpInside)
        button.titleLabel?.font = UIFont.fontAwesome(ofSize: CGFloat(fontSize))
        button.setTitleColor(UIColor.white, for: .normal)
        button.setTitleColor(UIColor.gray, for: .highlighted)
        button.setTitle(String.fontAwesomeIcon(name: icon), for: .normal)
        
        return button
    }
    
    func getCaptureDevice() -> AVCaptureDevice? {
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession.init(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .front)
        
        for device in deviceDiscoverySession.devices {
            if device.position == .front {
                captureDevice = device
                return device
            }
        }
        
        return nil
    }
    
    func initializeCaptureView() {
        captureView = UIView(frame: (view.window?.frame)!)
        view.window?.addSubview(captureView!)
        
        let shadeView = UIView(frame: (captureView?.frame)!)
        shadeView.alpha = 0.85
        shadeView.backgroundColor = UIColor.black
        captureView?.addSubview(shadeView)
        
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .photo
        
        capturedImageView = UIImageView()
        capturedImageView?.frame = previousFrame!
        capturedImageView?.layer.cornerRadius = (previousFrame?.width)! / 2
        capturedImageView?.layer.masksToBounds = true
        capturedImageView?.backgroundColor = UIColor.clear
        capturedImageView?.isUserInteractionEnabled = true
        capturedImageView?.contentMode = .scaleAspectFill
        
        captureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
        captureVideoPreviewLayer?.videoGravity = .resizeAspectFill
        captureVideoPreviewLayer?.frame = previousFrame!
        captureVideoPreviewLayer?.cornerRadius = (captureVideoPreviewLayer?.frame.width)! / 2
        captureView?.layer.addSublayer(captureVideoPreviewLayer!)
    }
    
    @objc func capturePhoto() {
        isCapturingImage = true
        
        let outputSettings = AVCapturePhotoSettings()
        
        if let _ = stillImageOutput?.connection(with: .video){
            stillImageOutput?.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format:[AVVideoCodecKey:AVVideoCodecJPEG])], completionHandler: nil)
            stillImageOutput?.capturePhoto(with: outputSettings, delegate: self)
        }
    }
    
    @objc func photoSelected() {
        image = selectedImage!
        endCapture()
        delegate?.imageSelected(image: image!)
    }
    
    @objc func cancelSelectedPhoto() {
        imageSelectedView?.removeFromSuperview()
        for view in (captureView?.subviews)! {
            if view.isKind(of: UIButton.self) {
                view.isHidden = false
            }
        }
    }
    
    @objc func cancel() {
        endCapture()
        delegate?.imageSelectionCancelled()
    }
    
}

//Image Resizing - 
extension AvatarCaptureController {
    func resizeImage(image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size
        
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        
        // Figure out what our orientation is, and use that to form the rectangle
        var newSize: CGSize
        if(widthRatio > heightRatio) {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio,  height: size.height * widthRatio)
        }
        
        // This is the rect that we've calculated out and this is what is actually used below
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
        
        // Actually do the resizing to the rect using the ImageContext stuff
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage!
    }
}

// MARK: Delegates
extension AvatarCaptureController: UINavigationControllerDelegate {
    
}

extension AvatarCaptureController: UIImagePickerControllerDelegate {
    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
// Local variable inserted by Swift 4.2 migrator.
let info = convertFromUIImagePickerControllerInfoKeyDictionary(info)

        selectedImage = info[convertFromUIImagePickerControllerInfoKey(UIImagePickerController.InfoKey.originalImage)] as? UIImage
        self.capturedImageView?.image = selectedImage
        
        dismiss(animated: true, completion: {() -> Void in
            for view in (self.captureView?.subviews)! {
                if view.isKind(of: UIButton.self) {
                    view.isHidden = true
                }
            }
            self.captureView?.addSubview(self.imageSelectedView!)
        })
    }
}

extension AvatarCaptureController: AVCapturePhotoCaptureDelegate {
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photoSampleBuffer: CMSampleBuffer?, previewPhoto previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        if let error = error {
            print(error.localizedDescription)
        }
        
        if let sampleBuffer = photoSampleBuffer, let dataImage = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: sampleBuffer, previewPhotoSampleBuffer: sampleBuffer) {
            let isFrontFacing = captureDevice?.position == AVCaptureDevice.Position.front
            
            var capturedImage = UIImage.init(data: dataImage, scale:1)
            
            if isFrontFacing {
                capturedImage = UIImage.init(cgImage: (capturedImage?.cgImage!)!, scale: (capturedImage?.scale)!, orientation: UIImage.Orientation.leftMirrored)
            }
            
            isCapturingImage = false
            capturedImageView?.image = capturedImage
            for view in (captureView?.subviews)! {
                if view.isKind(of: UIButton.self) {
                    view.isHidden = true
                }
            }
            
            captureView?.addSubview(imageSelectedView!)
            selectedImage = capturedImage
        }
    }
}


// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKeyDictionary(_ input: [UIImagePickerController.InfoKey: Any]) -> [String: Any] {
	return Dictionary(uniqueKeysWithValues: input.map {key, value in (key.rawValue, value)})
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKey(_ input: UIImagePickerController.InfoKey) -> String {
	return input.rawValue
}
