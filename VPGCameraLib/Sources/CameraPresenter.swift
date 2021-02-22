//
//  CameraPresenter.swift
//  VPGCamera
//
//  Created by Minh Nguyen Duc on 1/6/20.
//  Copyright © 2020 ahdenglish. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit
import Vision
import CoreMotion

// MARK: - CameraPresenter

class CameraPresenter: NSObject {
    
    weak var view: CameraViewProtocol?
    var interactor: CameraUseCasePrototol!
    var router: CameraWireframeProtocol?
    
    static let requireFrameRate: Int = 30
    static let waitingTime1: CGFloat = 3
    static let waitingTime2: CGFloat = 10
    private static let defaultTimeForCaptureFrame: Float = 25
    private var timeForCaptureFrame: Float = 25
    
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private lazy var captureSession = AVCaptureSession()
    private var stage: CameraStage = .none {
        didSet {
            debugPrint("Stage: \(stage)")
        }
    }
    
    private var isUsingFrontCamera = true
    private var isRequiredFace = false
    private var fileName: String = "output.json"
    private var uniquePatientCode: String? = "uniquePatientCode"
    private var serialNo: String? = "serialNo"
    private var patientId: Int? = 12345678
    
    private lazy var sessionQueue = DispatchQueue(label: "Camera.sessionQueue")
    private lazy var roiQueue = OperationQueue()
    private lazy var roiQueuePreview = OperationQueue()
    private lazy var extractFrameQueue = OperationQueue()
    
    private var timerT1: Timer?
    private var timerT2: Timer?
    private var timerT3: Timer?
    
    private var recordSession: RecordSessionModel!
    private var listFrame: [Frame] = []
    private var listMotion: [Double] = []
    private let group = DispatchGroup()
    
    private var faceDetectionRequest: VNRequest!
    private var requests = [VNRequest]()
    private var frameCount: Int = 0
    private var rawDataArray: [(URL, CGImagePropertyOrientation, [VNImageOption: Any])] = []
    
    private var motionManager: CMMotionManager!
    
    private var isConfigAF: Bool = false
    private var isConfigAE: Bool = false
    private var isConfigWB: Bool = false
    
    var isReadyToRestart: Bool = false
}

// MARK: - PresentationProtocol
extension CameraPresenter: CameraPresentationProtocol {
    func updateParams(_ config: VPGCamearConfiguration) {
        self.isUsingFrontCamera = config.isUsingFrontCamera
        self.isRequiredFace = config.isRequiredFace
        self.timeForCaptureFrame = config.captureTime
        self.patientId = config.patientId
        self.serialNo = config.serialNo
        self.uniquePatientCode = config.uniquePatientCode
        self.fileName = config.outputFileName ?? "output.json"
    }
    
    func onCancelCameraSetting() {
        VPGCameraSDK.shared.delegate?.cameraDidCompleted(isSuccess: false, outputUrl: nil)
    }
    
    func onDidLoad() {
        captureSession.sessionPreset = .medium
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        
        faceDetectionRequest = VNDetectFaceRectanglesRequest()
        requests = [faceDetectionRequest]
        
        view?.displayCameraPreviewLayer(previewLayer)
        
        roiQueue.qualityOfService = .background
        roiQueuePreview.qualityOfService = .userInteractive
        extractFrameQueue.qualityOfService = .background
        
        motionManager = CMMotionManager()
        motionManager.startAccelerometerUpdates()
    }
    
    func onViewDidAppear() {
        let authStatus = AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
        switch authStatus {
        case .authorized:
            startCameraPreview()
        default:
            let captureDevice = AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInWideAngleCamera, for: AVMediaType.video, position: AVCaptureDevice.Position.front)

            if captureDevice != nil {
                AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler: { [weak self] granted in
                    if granted {
                        self?.startCameraPreview()
                    } else {
                        DispatchQueue.main.async {
                            self?.view?.displayCameraSettingIntruction()
                        }
                    }
                })
            } else {
                // iDevice cannot access camera.
                view?.displayCameraError("iDevice cannot access camera, please check camera again!")
            }
        }
    }
    
    func startCameraPreview() {
        setUpCaptureSessionOutput()
        setUpCaptureSessionInput()
        startSession()
        view?.updateCameraIsReady()
        processFromStartingPoint()
    }
    
    func onTappedButtonRotate() {
        switchCameraFace()
    }
    
    func onDismiss() {
        stopSession()
    }
    
    func onResume() {
        startSession()
    }
    
    func onStopManual() {
        if stage == .captureFrame {
            resetAllTimer()
            processOutputData()
        } else {
            VPGCameraSDK.shared.delegate?.cameraDidCompleted(isSuccess: false, outputUrl: nil)
            view?.displayEndCamera()
            isReadyToRestart = true
        }
    }
}

// MARK: - OutputProtocol
extension CameraPresenter: CameraInteractorOutputProtocol {}

// MARK: - Main
extension CameraPresenter {
    private func captureDevice(forPosition position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        return AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        ).devices.first(where: { $0.position == position })
    }
    
    // MARK: - Observe camera's values
    private func configObserverCamera(device: AVCaptureDevice) {
        if isConfigAF {
            device.addObserver(self, forKeyPath: CameraObserverKeys.adjustingFocus.rawValue, options: [.new], context: nil)
        }
        if isConfigAE {
            device.addObserver(self, forKeyPath: CameraObserverKeys.adjustingExposure.rawValue, options: [.new], context: nil)
        }
        if isConfigWB {
            device.addObserver(self, forKeyPath: CameraObserverKeys.adjustingWhiteBalance.rawValue, options: [.new], context: nil)
        }
    }
    
    private func removeConfigObserverCamera(device: AVCaptureDevice) {
        if isConfigAF {
            device.removeObserver(self, forKeyPath: CameraObserverKeys.adjustingFocus.rawValue)
        }
        if isConfigAE {
            device.removeObserver(self, forKeyPath: CameraObserverKeys.adjustingExposure.rawValue)
        }
        if isConfigWB {
            device.removeObserver(self, forKeyPath: CameraObserverKeys.adjustingWhiteBalance.rawValue)
        }
    }
    
    // MARK: - Config camera
    private func setUpCaptureSessionInput() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            let cameraPosition: AVCaptureDevice.Position = self.isUsingFrontCamera ? .front : .back
            guard let device = self.captureDevice(forPosition: cameraPosition) else { return }

            do {
                let input = try AVCaptureDeviceInput(device: device)
                
                try device.lockForConfiguration()
                self.captureSession.beginConfiguration()
                
                if let currentInput = self.captureSession.inputs.filter({ $0 is AVCaptureDeviceInput }).first {
                    self.captureSession.removeInput(currentInput)
                }

                if self.captureSession.canAddInput(input) == true {
                    self.captureSession.addInput(input)
                    
                    DispatchQueue.main.async {
                        let statusBarOrientation = UIApplication.shared.statusBarOrientation
                        var initialVideoOrientation: AVCaptureVideoOrientation = .portrait
                        if statusBarOrientation != .unknown {
                            if let videoOrientation = statusBarOrientation.videoOrientation {
                                initialVideoOrientation = videoOrientation
                            }
                        }
                        self.previewLayer.connection?.videoOrientation = initialVideoOrientation
                    }
                }

                // Set the input device on the capture session.
                if device.supportsSessionPreset(.vga640x480) == true {
                    self.captureSession.sessionPreset = .vga640x480
                } else if device.supportsSessionPreset(.medium) == true {
                    self.captureSession.sessionPreset = .medium
                }
                
                self.captureSession.automaticallyConfiguresCaptureDeviceForWideColor = true
                self.captureSession.commitConfiguration()
                
                if device.isLowLightBoostSupported == true {
                    device.automaticallyEnablesLowLightBoostWhenAvailable = true
                }
                device.unlockForConfiguration()
                
                self.configureCameraForFrameRate(device: device)
            } catch {
                debugPrint(error.localizedDescription)
                self.view?.displayCameraError(error.localizedDescription)
            }
        }
    }
    
    private func setUpCaptureSessionOutput() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.captureSession.beginConfiguration()
            self.captureSession.sessionPreset = AVCaptureSession.Preset.medium
            
            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String : NSNumber(value: kCVPixelFormatType_32BGRA)]
            output.alwaysDiscardsLateVideoFrames = true
            
            let outputQueue = DispatchQueue(label: "Camera.videoDataOutputQueue")
            output.setSampleBufferDelegate(self, queue: outputQueue)
            
            guard self.captureSession.canAddOutput(output) else {
                self.captureSession.commitConfiguration()
                return
            }
            
            self.captureSession.addOutput(output)
            self.captureSession.commitConfiguration()
        }
    }
    
    private func configureCameraForFrameRate(device: AVCaptureDevice) {
        let requireDuration = CMTime(value: 1, timescale: CMTimeScale(CameraPresenter.requireFrameRate))
        
        do {
            try device.lockForConfiguration()
            // Set the device's min/max frame duration.
            device.activeVideoMinFrameDuration = requireDuration
            device.activeVideoMaxFrameDuration = requireDuration
            
            device.unlockForConfiguration()
        } catch {
            debugPrint(error.localizedDescription)
        }
    }
    
    private func configFocusAndExposeCamera(resetFlag: Bool = false, lockFlag: Bool = false, completion: (() -> Void)? = nil) {
        sessionQueue.async { [weak self] in
            guard let self = self else {
                completion?()
                return
            }
            let cameraPosition: AVCaptureDevice.Position = self.isUsingFrontCamera ? .front : .back
            guard let device = self.captureDevice(forPosition: cameraPosition) else {
                completion?()
                return
            }
            
            do {
                try device.lockForConfiguration()
                self.captureSession.beginConfiguration()
                
                // autofocus settings and focus on middle point
                var configCounting = 0
                let centerPoint = CGPoint(x: 0.5, y: 0.5)
                
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusPointOfInterest = centerPoint
                    if resetFlag {
                        device.focusMode = .continuousAutoFocus
                    }
                    if lockFlag {
                        device.focusMode = .locked
                    }
                    configCounting += 1
                    self.isConfigAF = true
                }
                
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposurePointOfInterest = centerPoint
                    if resetFlag {
                        device.exposureMode = .continuousAutoExposure
                    }
                    if lockFlag {
                        device.exposureMode = .locked
                    }
                    configCounting += 1
                    self.isConfigAE = true
                }
                
                if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                    if resetFlag {
                        device.whiteBalanceMode = .continuousAutoWhiteBalance
                    }
                    if lockFlag {
                        device.whiteBalanceMode = .locked
                    }
                    configCounting += 1
                    self.isConfigWB = true
                }
                
                self.captureSession.commitConfiguration()
                device.unlockForConfiguration()
                
                if configCounting == 0 {
                    self.processWithNoConfigAutoFocus()
                }
            } catch {
                debugPrint(error.localizedDescription)
                self.view?.displayCameraError(error.localizedDescription)
            }
            
            completion?()
        }
    }
    
    private func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.captureSession.startRunning()
        }
    }

    private func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.captureSession.stopRunning()
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard stage == .configAutoFocus else { return }
        guard let key = keyPath, let changes = change else { return }
        
        if let _ = CameraObserverKeys.allCases.first(where: {$0.rawValue == key}) {
            if let newValue = changes[.newKey] as? Int {
                if newValue == 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                        self?.checkCameraStableForFaceDetect()
                    }
                }
            }
        }
    }
    
    private func checkCameraStableForFaceDetect() {
        let cameraPosition: AVCaptureDevice.Position = self.isUsingFrontCamera ? .front : .back
        guard let device = self.captureDevice(forPosition: cameraPosition) else { return }
        
        if !device.isAdjustingFocus, !device.isAdjustingExposure, !device.isAdjustingWhiteBalance {
            processLockFocusPoint()
        }
    }
    
    // MARK: - VPGCamera logic step by step
    private func processFromStartingPoint() {
        if isRequiredFace {
            guard stage != .firstFace else { return }
            stage = .firstFace
            
            resetCurrentData()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.resetCurrentData()
                self.processAutoFocus()
            }
        }
    }
    
    private func resetCurrentData() {
        resetAllTimer()
        view?.updateNoFace()
        view?.updateDisableIdleApplication(enable: true)
        
        roiQueue.cancelAllOperations()
        roiQueuePreview.cancelAllOperations()
        extractFrameQueue.cancelAllOperations()
        
        frameCount = 0
        listFrame.removeAll()
        listMotion.removeAll()
        
        isConfigAE = false
        isConfigAF = false
        isConfigWB = false
        isReadyToRestart = false
    }
    
    private func processAutoFocus() {
        if isRequiredFace {
            guard stage == .firstFace else { return }
            stage = .configAutoFocus
        } else {
            guard stage == .none else { return }
            stage = .configAutoFocus
        }
        
        resetCurrentData()
        view?.displayLoading(message: "Config AF/AE/WB...")
        
        configFocusAndExposeCamera(resetFlag: true) { [weak self] in
            guard let self = self else { return }
            let cameraPosition: AVCaptureDevice.Position = self.isUsingFrontCamera ? .front : .back
            guard let device = self.captureDevice(forPosition: cameraPosition) else { return }
            self.configObserverCamera(device: device)
        }
        
        if timerT2 == nil || timerT2?.isValid == false {
            let timer = Timer(timeInterval: TimeInterval(CameraPresenter.waitingTime2), repeats: false, block: {
                [weak self] (_) in
                guard let self = self else { return }
                self.stage = .none
                self.processFromStartingPoint()
            })
            timerT2 = timer
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    private func processDetectFace() {
        guard stage == .lockFocus else { return }
        stage = .detectFace
        view?.hideLoading()
    }
    
    private func processNoFaceDetected() {
        guard stage == .captureFrame || stage == .detectFace else { return }
        if stage == .captureFrame {
            processOutputData()
            return
        }
        
        if timerT1 == nil || timerT1?.isValid == false {
            let seconds = stage == .captureFrame ? CameraPresenter.waitingTime1 : CameraPresenter.waitingTime2
            let timer = Timer(timeInterval: TimeInterval(seconds), repeats: false, block: {
                [weak self] (timer) in
                guard let self = self else { return }
                self.stage = .none
                self.processFromStartingPoint()
            })
            timerT1 = timer
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    private func processLockFocusPoint() {
        guard stage == .configAutoFocus else { return }
        
        if stage == .configAutoFocus {
            let cameraPosition: AVCaptureDevice.Position = isUsingFrontCamera ? .front : .back
            guard let device = captureDevice(forPosition: cameraPosition) else { return }
            removeConfigObserverCamera(device: device)
        }
        
        stage = .lockFocus
        
        resetCurrentData()
        
        configFocusAndExposeCamera(lockFlag: true)
        
        if isRequiredFace {
            processDetectFace()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.processCaptureFrame()
                self.view?.hideLoading()
            }
        }
    }
    
    private func resetAllTimer() {
        [timerT1, timerT2, timerT3].forEach { (timer) in
            timer?.invalidate()
        }
    }
    
    private func processCaptureFrame() {
        if isRequiredFace {
            guard stage == .detectFace else { return }
        } else {
            guard stage == .lockFocus else { return }
        }
        
        resetCurrentData()
        
        recordSession = RecordSessionModel()
        recordSession.isFront = isUsingFrontCamera
        
        stage = .captureFrame
        
        view?.updateDisableIdleApplication(enable: true)
        
        let maxTimeCapture = min(timeForCaptureFrame, CameraPresenter.defaultTimeForCaptureFrame)
        let timer = Timer(timeInterval: TimeInterval(maxTimeCapture), repeats: false, block: {
            [weak self] (_) in
            guard let self = self else { return }
            self.processOutputData()
        })
        timerT3 = timer
        RunLoop.main.add(timer, forMode: .common)
    }
    
    private func processOutputData() {
        guard stage == .captureFrame else { return }
        stage = .outputData
        
        let endDate = Date()
        let duration = endDate.timeIntervalSince(self.recordSession.createdOn)
        let fakeVideoFileName = "\(Int(self.recordSession.createdOn.timeIntervalSince1970)).mp4"
        let path = interactor.generatePath(from: self.recordSession)
        
        stopSession()
        view?.updateNoFace()
        view?.displayLoading(message: "Exporting frames...")
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.group.wait()
            debugPrint(self.listFrame.count)
            self.recordSession.patientID = self.patientId
            self.recordSession.uniquePatientCode = self.uniquePatientCode
            self.recordSession.serialNo = self.serialNo
            self.recordSession.frames = self.listFrame
            self.recordSession.motion = self.listMotion
            self.recordSession.from = 1
            self.recordSession.similarity = 0
            self.recordSession.totalFrames = self.listFrame.count
            self.recordSession.fps = CameraPresenter.requireFrameRate
            self.recordSession.duration = Int(duration)
            self.recordSession.videoName = "/\(path)/\(fakeVideoFileName)"
            let url = self.interactor.storeData(self.recordSession, path: path, fileName: self.fileName)
            self.view?.hideLoading()
            
            self.processDone(with: url)
        }
    }
    
    private func processDone(with url: URL) {
        guard stage == .outputData else { return }
        stage = .done
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            VPGCameraSDK.shared.delegate?.cameraDidCompleted(isSuccess: true, outputUrl: url)
            
            let encoder = JSONEncoder()
            do {
                let data = try encoder.encode(self.recordSession)
                let jsonString = String(data: data, encoding: .utf8)
                VPGCameraSDK.shared.delegate?.cameraDidCompleted(isSuccess: true, jsonString: jsonString)
            } catch {
                // NOP
            }
            
            // Cleanup
            let path = self.interactor.generatePath(from: self.recordSession)
            self.interactor.cleanupStorage(path: path)
            self.view?.displayEndCamera()
            self.isReadyToRestart = true
        }
    }
    
    private func processWithNoConfigAutoFocus() {
        debugPrint("iDevice front or back doesnot support autoFocus mode.")
    }
    
    func switchCameraFace() {
        // Stop observer if need
        if stage == .configAutoFocus {
            let cameraPosition: AVCaptureDevice.Position = isUsingFrontCamera ? .front : .back
            guard let device = captureDevice(forPosition: cameraPosition) else { return }
            removeConfigObserverCamera(device: device)
        }
        
        stage = .none
        isUsingFrontCamera = !isUsingFrontCamera
        startCameraPreview()
    }
}

// MARK: - DataOutputSampleBuffer
extension CameraPresenter: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard stage == .firstFace || stage == .detectFace || stage == .captureFrame else { return }
        handleBuffer(sampleBuffer)
    }
    
    func handleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
            let exifOrientation = CGImagePropertyOrientation(rawValue: exifOrientationFromDeviceOrientation()) else { return }
        
        var requestOptions: [VNImageOption: Any] = [:]
        if let cameraIntrinsicData = CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil) {
            requestOptions = [.cameraIntrinsics : cameraIntrinsicData]
        }
        
        let copyPixelBuffer = pixelBuffer.copy()
        let ciImage = CIImage(cvImageBuffer: copyPixelBuffer)
        
        if stage == .firstFace {
            let results = self.executeRequestFaceDetect(ciImage, orientation: exifOrientation, options: requestOptions)
            if results.count > 0 {
                processAutoFocus()
            }
            return
        }
        
        if self.stage == .detectFace {
            let results = self.executeRequestFaceDetect(ciImage, orientation: exifOrientation, options: requestOptions)
            _ = checkFaceExist(results)
            return
        }
        
        let stepCount = 3
        var isNeedPreview = false
        var queue: OperationQueue = roiQueue
        if frameCount % stepCount == 0 {
            isNeedPreview = true
            queue = roiQueuePreview
        }
        
        frameCount += 1
        let id = frameCount
        group.enter()
        
        var m: Double = 0
        if let accelerometerData = motionManager.accelerometerData {
            let x = accelerometerData.acceleration.x
            let y = accelerometerData.acceleration.y
            let z = accelerometerData.acceleration.z
            let g = 9.8
            m = (x * x + y * y + z * z) / (g * g)
        }
        
        queue.addOperation { [unowned self] in
            if self.isRequiredFace {
                let results = self.executeRequestFaceDetect(ciImage, orientation: exifOrientation, options: requestOptions)
                if self.checkFaceExist(results), let face = results.first {
                    let rect = self.calculateRoiBounds(face, isNeedPreview: isNeedPreview)
                    self.extractFrameInfo(id: id, motion: m, image: ciImage, facebounds: rect, isNeedPreview: isNeedPreview) {
                        self.group.leave()
                    }
                } else {
                    self.group.leave()
                }
            } else {
                let rect = self.previewLayer.frame
                self.extractFrameInfo(id: id, motion: m, image: ciImage, facebounds: rect, isNeedPreview: isNeedPreview) {
                    self.group.leave()
                }
            }
        }
    }
    
    /// Step 1
    private func executeRequestFaceDetect(_ ciImage: CIImage,
                                          orientation: CGImagePropertyOrientation,
                                          options: [VNImageOption : Any]) -> [VNFaceObservation] {
        try! VNImageRequestHandler(ciImage: ciImage, orientation: orientation, options: options).perform(requests)
        guard let results = faceDetectionRequest.results as? [VNFaceObservation] else { return [] }
        return results
    }
    
    /// Step 2
    private func checkFaceExist(_ list: [VNFaceObservation]) -> Bool {
        if list.count == 0 {
            DispatchQueue.main.async {
                self.processNoFaceDetected()
            }
            return false
        } else {
            DispatchQueue.main.async {
                self.processCaptureFrame()
            }
            return true
        }
    }
    
    /// Step 3
    private func calculateRoiBounds(_ face: VNFaceObservation, isNeedPreview: Bool = false) -> CGRect {
        let frame = previewLayer.frame
        let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -frame.height)
        let translate = CGAffineTransform.identity.scaledBy(x: frame.width, y: frame.height)
        let facebounds = face.boundingBox.applying(translate).applying(transform)
        if isNeedPreview, stage == .captureFrame {
            view?.update(with: facebounds)
        }
        
        return facebounds
    }
    
    /// Step 4.1
    private func extractFrameInfo(id: Int, motion: Double, image: CIImage, facebounds: CGRect, isNeedPreview: Bool = false, completed: @escaping () -> Void) {
        if isNeedPreview {
            if let color = self.cropBuffer(id: id, motion: motion, ciImage: image, rect: facebounds) {
                if stage == .captureFrame {
                    self.calculateColorToDisplay(color)
                }
            }
            completed()
            return
        }
        
        extractFrameQueue.addOperation { [weak self] in
            _ = self?.cropBuffer(id: id, motion: motion, ciImage: image, rect: facebounds)
            completed()
        }
    }
    
    /// Step 4.2
    private func calculateColorToDisplay(_ color: UIColor) {
        let hue = interactor.calculateHueValue(from: color)
        view?.updateRealtimeColor(color, hue: hue)
    }
    
    private func cropBuffer(id: Int, motion: Double, ciImage: CIImage, rect: CGRect, isNeedPreview: Bool = false) -> UIColor? {
        let newCIImage = ciImage.cropped(to: rect)
        if let color = interactor.calculateAverageColor(inputImage: newCIImage) {
            // Export new frame
            let (r, g, b, _) = interactor.calculateRGB(from: color)
            let x = Double(rect.origin.x)
            let y = Double(rect.origin.y)
            let w = Double(rect.size.width)
            let h = Double(rect.size.height)
            
            let roi = [x, y, w, h]
            let newFrame = Frame(id: id, faceDetected: 1, r: Double(r*255.0), g: Double(g*255.0), b: Double(b*255.0), roi: roi)
            listFrame.append(newFrame)
            listMotion.append(motion)
            return color
        }
        
        return nil
    }
    
    private func exifOrientationFromDeviceOrientation() -> UInt32 {
        enum DeviceOrientation: UInt32 {
            case top0ColLeft = 1
            case top0ColRight = 2
            case bottom0ColRight = 3
            case bottom0ColLeft = 4
            case left0ColTop = 5
            case right0ColTop = 6
            case right0ColBottom = 7
            case left0ColBottom = 8
        }
        var exifOrientation: DeviceOrientation
        
        switch UIDevice.current.orientation {
        case .portraitUpsideDown:
            exifOrientation = .left0ColBottom
        case .landscapeLeft:
            exifOrientation = isUsingFrontCamera ? .bottom0ColRight : .top0ColLeft
        case .landscapeRight:
            exifOrientation = isUsingFrontCamera ? .top0ColLeft : .bottom0ColRight
        default:
            exifOrientation = isUsingFrontCamera ? .left0ColTop : .right0ColTop
        }
        return exifOrientation.rawValue
    }
}
