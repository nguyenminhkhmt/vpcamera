//
//  VPGCameraSDK.swift
//  VPGCamera
//
//  Created by Minh Nguyen Duc on 1/18/20.
//  Copyright © 2020 ahdenglish. All rights reserved.
//

import Foundation
import UIKit

public struct VPGCamearConfiguration {
    var captureTime: Float = 25
    var isUsingFrontCamera: Bool = true
    var outputFileName: String?
    var uniquePatientCode: String?
    var serialNo: String?
    var patientId: Int?
    var isRequiredFace: Bool = true
    
    public init() {}
    
    public init(captureTime: Float = 25,
                isUsingFrontCamera: Bool = true,
                isRequiredFace: Bool = false,
                outputFileName: String,
                uniquePatientCode: String,
                serialNo: String?,
                patientId: Int?) {
        self.captureTime = captureTime
        self.isUsingFrontCamera = isUsingFrontCamera
        self.isRequiredFace = isRequiredFace
        self.outputFileName = outputFileName
        self.uniquePatientCode = uniquePatientCode
        self.serialNo = serialNo
        self.patientId = patientId
    }
}

public protocol VPGCameraSDKDelegate: class {
    func cameraDidStart()
    func cameraDidCompleted(isSuccess: Bool, outputUrl: URL?)
    func cameraDidCompleted(isSuccess: Bool, jsonString: String?)
}

public class VPGCameraSDK {
    static var shared: VPGCameraSDK!
    
    var cameraConfig: VPGCamearConfiguration = VPGCamearConfiguration()
    weak var delegate: VPGCameraSDKDelegate?
    
    private var strongCameraVC: CameraViewController?
    
    public init(cameraConfig: VPGCamearConfiguration,
                delegate: VPGCameraSDKDelegate?) {
        self.cameraConfig = cameraConfig
        self.delegate = delegate
        
        VPGCameraSDK.shared = self
    }
    
    /// Start Camera function
    public func startInView(_ parentView: UIView) {
        if let vc = strongCameraVC {
            if vc.presenter?.isReadyToRestart ?? false {
                strongCameraVC = nil
            } else {
                debugPrint("Cannot restart camera right now. Please stop first.")
                return
            }
        }
        
        let view = CameraRouter.createModule(config: cameraConfig)
        parentView.addSubview(view.view)
        strongCameraVC = view
        self.delegate?.cameraDidStart()
    }
    
    /// Stop CameraFunction
    public func stop() {
        if let vc = strongCameraVC {
            vc.stopManual { [weak self] in
                self?.strongCameraVC = nil
            }
        }
    }
}
