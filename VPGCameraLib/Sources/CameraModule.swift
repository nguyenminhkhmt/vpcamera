//
//  CameraModule.swift
//  VPGCamera
//
//  Created by Minh Nguyen Duc on 1/6/20.
//  Copyright © 2020 ahdenglish. All rights reserved.
//

import Foundation
import QuartzCore
import UIKit

protocol CameraPresentationProtocol: class {
    var isReadyToRestart: Bool {set get}
    
    func onDidLoad()
    func onViewDidAppear()
    func onDismiss()
    func onResume()
    func onStopManual()
    func onTappedButtonRotate()
    func onCancelCameraSetting()
    func updateParams(_ config: VPGCamearConfiguration)
}

protocol CameraViewProtocol: class {
    func displayCameraPreviewLayer(_ layer: CALayer)
    func displayNotice(_ message: String)
    func displayCameraError(_ message: String)
    func displayCameraSettingIntruction()
    func update(with faceRect: CGRect)
    func updateNoFace()
    func updateRealtimeFaceImage(_ image: UIImage)
    func updateRealtimeColor(_ color: UIColor, hue: CGFloat)
    func updateCameraIsReady()
    func updateDisableIdleApplication(enable: Bool)
    func displayLoading(message: String?)
    func hideLoading()
    func displayEndCamera()
}

protocol CameraUseCasePrototol: class {
    func calculateVideoBox(frameSize: CGSize, apertureSize: CGSize) -> CGRect
    func calculateFaceRect(facePosition: CGPoint, faceBounds: CGRect, clearAperture: CGRect, parentFrameSize: CGSize) -> CGRect
    func calculateAverageColor(inputImage: CIImage) -> UIColor?
    func calculateHueValue(from color: UIColor) -> CGFloat
    func calculateRGB(from color: UIColor) -> (CGFloat, CGFloat, CGFloat, CGFloat)
    
    func storeData(_ recordSession: RecordSessionModel, path: String, fileName: String) -> URL
    func generatePath(from recordSession: RecordSessionModel) -> String
    func cleanupStorage(path: String)
}

protocol CameraInteractorOutputProtocol: class {
    
}

protocol CameraWireframeProtocol: class {
    
}
