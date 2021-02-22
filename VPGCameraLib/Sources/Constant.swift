//
//  Constant.swift
//  VPGCamera
//
//  Created by Minh Nguyen Duc on 1/17/20.
//  Copyright © 2020 ahdenglish. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation

enum CameraObserverKeys: String, CaseIterable {
    case adjustingFocus
    case adjustingExposure
    case adjustingWhiteBalance
}

enum VideoRecorderError: Error, LocalizedError {
    case notRecording
    case notReadyForData
    case recordingFailed
}

enum Result<T, E> {
    case value(T)
    case error(E)
}

enum CameraStage {
    case none
    case firstFace
    case configAutoFocus
    case lockFocus
    case detectFace
    case captureFrame
    case outputData
    case done
}

// Extension for Orientation
extension UIDeviceOrientation {
    var videoOrientation: AVCaptureVideoOrientation? {
        switch self {
        case .portrait: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft: return .landscapeRight
        case .landscapeRight: return .landscapeLeft
        default: return nil
        }
    }
}

extension UIInterfaceOrientation {
    var videoOrientation: AVCaptureVideoOrientation? {
        switch self {
        case .portrait: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft: return .landscapeLeft
        case .landscapeRight: return .landscapeRight
        default: return nil
        }
    }
}
