//
//  CVPixelBuffer+Extension.swift
//  VPGCamera
//
//  Created by Minh Nguyen Duc on 1/17/20.
//  Copyright © 2020 ahdenglish. All rights reserved.
//

import Foundation
import CoreGraphics
import CoreImage

extension CVPixelBuffer {
    func copy() -> CVPixelBuffer {
        precondition(CFGetTypeID(self) == CVPixelBufferGetTypeID(), "copy() cannot be called on a non-CVPixelBuffer")
        let ioSurfaceProps = [
            "IOSurfaceOpenGLESFBOCompatibility": true as CFBoolean,
            "IOSurfaceOpenGLESTextureCompatibility": true as CFBoolean,
            "IOSurfaceCoreAnimationCompatibility": true as CFBoolean
        ] as CFDictionary

        let options = [
            String(kCVPixelBufferMetalCompatibilityKey): true as CFBoolean,
            String(kCVPixelBufferIOSurfacePropertiesKey): ioSurfaceProps
        ] as CFDictionary

        var _copy : CVPixelBuffer?
        CVPixelBufferCreate(
            nil,
            CVPixelBufferGetWidth(self),
            CVPixelBufferGetHeight(self),
            CVPixelBufferGetPixelFormatType(self),
            options,
            &_copy)

        guard let copy = _copy else { fatalError() }
        
        CVBufferPropagateAttachments(self as CVBuffer, copy as CVBuffer)
        
        CVPixelBufferLockBaseAddress(self, CVPixelBufferLockFlags.readOnly)
        CVPixelBufferLockBaseAddress(copy, CVPixelBufferLockFlags(rawValue: 0))
        
        let copyBaseAddress = CVPixelBufferGetBaseAddress(copy)
        let currBaseAddress = CVPixelBufferGetBaseAddress(self)
        
        memcpy(copyBaseAddress, currBaseAddress, CVPixelBufferGetDataSize(self))
        
        CVPixelBufferUnlockBaseAddress(copy, CVPixelBufferLockFlags(rawValue: 0))
        CVPixelBufferUnlockBaseAddress(self, CVPixelBufferLockFlags.readOnly)
        
        // let's make sure they have the same average color
//        let originalImage = CIImage(cvPixelBuffer: self)
//        let copiedImage = CIImage(cvPixelBuffer: copy)
//
//        let averageColorOriginal = originalImage.averageColour()
//        let averageColorCopy = copiedImage.averageColour()
//
//        assert(averageColorCopy == averageColorOriginal)
//        debugPrint("average frame color: \(averageColorCopy)")
        
        return copy
    }
}
