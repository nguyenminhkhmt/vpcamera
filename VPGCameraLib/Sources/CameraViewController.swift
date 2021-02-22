//
//  ViewController.swift
//  VPGCamera
//
//  Created by Minh Nguyen Duc on 1/6/20.
//  Copyright © 2020 ahdenglish. All rights reserved.
//

import UIKit
import AVKit

class CameraViewController: UIViewController {
    
    var presenter: CameraPresentationProtocol?
    
    @IBOutlet fileprivate weak var contentView: UIView!
    @IBOutlet fileprivate weak var previewRoiIv: UIImageView!
    @IBOutlet fileprivate weak var containerChartView: UIView!
    
    private var previewLayer: CALayer?
    private var maskLayer = [CAShapeLayer]()
    private var completionBlock: (() -> Void)? = nil
    
    let detailsView: CornerView = {
        let detailsView = CornerView()
        detailsView.backgroundColor = .clear
        detailsView.alpha = 1.0
        detailsView.frame = CGRect.zero
        return detailsView
    }()
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    let chartView: LineChartView = {
        let chartView = LineChartView()
        chartView.backgroundColor = UIColor.white
        return chartView
    }()
    
    let lineChartData: LineChartData = {
        return LineChartData()
    }()
    
    private var dataRGBH: [[Double]] = [[], [], [], []]
    
    private func updateChart() {
        var chartEntries: [[ChartDataEntry]] = [[], [], [], []]
        
        for (i, array) in dataRGBH.enumerated() {
            for j in 0..<array.count {
                let value = ChartDataEntry(x: Double(j), y: array[j])
                chartEntries[i].append(value)
            }
        }
        
        let colors = [UIColor.red, UIColor.green, UIColor.blue, UIColor.black]
        let labels = ["R", "G", "B", "H"]
        let data = LineChartData()
        
        for (i, chartEntry) in chartEntries.enumerated() {
            let line = LineChartDataSet(entries: chartEntry, label: labels[i])
            line.colors = [colors[i]]
            line.mode = .linear
            line.drawCirclesEnabled = false
            line.drawValuesEnabled = false
            data.addDataSet(line)
        }
        
        chartView.data = data
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        presenter?.onDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        presenter?.onViewDidAppear()
    }

    func setupUI() {
        chartView.translatesAutoresizingMaskIntoConstraints = false
        containerChartView.addSubview(chartView)
        let views = ["chartView": chartView]
        let hconstraints = NSLayoutConstraint.constraints(withVisualFormat: "H:|[chartView]|", metrics: nil, views: views)
        NSLayoutConstraint.activate(hconstraints)

        let vconstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|[chartView]|", metrics: nil, views: views)
        NSLayoutConstraint.activate(vconstraints)
        
        chartView.chartDescription?.enabled = false
        chartView.gridBackgroundColor = .clear
        chartView.drawGridBackgroundEnabled = false
        chartView.noDataText = "Cannot detect your face."
        
        let leftAxis = chartView.leftAxis
        leftAxis.drawGridLinesEnabled = false
        leftAxis.setLabelCount(2, force: true)
        let limitLine = ChartLimitLine(limit: 0.5, label: "")
        limitLine.lineColor = .lightGray
        limitLine.lineWidth = 0.5
        leftAxis.addLimitLine(limitLine)
        leftAxis.axisMaximum = 1
        leftAxis.axisMinimum = 0
        
        let rightAxis = chartView.rightAxis
        rightAxis.drawGridLinesEnabled = false
        rightAxis.drawLabelsEnabled = false
        
        let xAxis = chartView.xAxis
        xAxis.drawGridLinesEnabled = false
        xAxis.drawLabelsEnabled = false
        xAxis.avoidFirstLastClippingEnabled = true
        
        previewRoiIv.contentMode = .scaleAspectFill
        previewRoiIv.backgroundColor = .white
        previewRoiIv.isHidden = true
    }
    
    func setupNotifies() {
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(appMovedToBackground), name: UIApplication.willResignActiveNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(appMovedToBackground), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    @objc func appMovedToBackground() {
        presenter?.onDismiss()
    }
    
    @objc func appBecomeActive() {
        presenter?.onResume()
    }
    
    @objc func stopManual(completion: @escaping () -> Void) {
        completionBlock = completion
        presenter?.onStopManual()
    }
}

extension CameraViewController: CameraViewProtocol {
    func displayLoading(message: String?) {
//        DispatchQueue.main.async {
//            UIView.showProgress(message)
//        }
    }
    
    func hideLoading() {
//        DispatchQueue.main.async {
//            UIView.hideProgress()
//        }
    }
    
    func displayEndCamera() {
        debugPrint("Stop camera")
        completionBlock?()
    }
    
    internal func displayCameraPreviewLayer(_ layer: CALayer) {
        previewLayer = layer
        if layer.superlayer == nil {
            contentView.layer.addSublayer(layer)
        }
        layer.frame = contentView.frame
        DispatchQueue.main.async { [weak self] in
            layer.frame = self?.contentView.frame ?? CGRect.zero
        }
        
        view.addSubview(detailsView)
        view.bringSubviewToFront(detailsView)
    }
    
    internal func displayCameraError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: { (_) in
            alert.dismiss(animated: true, completion: nil)
        }))
        present(alert, animated: true, completion: nil)
    }
    
    internal func displayNotice(_ message: String) {
        let alert = UIAlertController(title: "Notice!", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: { (_) in
            alert.dismiss(animated: true, completion: nil)
        }))
        present(alert, animated: true, completion: nil)
    }
    
    internal func displayCameraSettingIntruction() {
        let message = "Please open camera setting and enable camera access to continue using this function"
        let alert = UIAlertController(title: "Cannot access camera!", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: { [weak self](_) in
            alert.dismiss(animated: true, completion: nil)
            self?.displayCameraSetting()
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { [weak self](_) in
            alert.dismiss(animated: true, completion: nil)
            self?.presenter?.onCancelCameraSetting()
        }))
        present(alert, animated: true, completion: nil)
    }
    
    internal func displayCameraSetting() {
        if let appSettingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(appSettingsURL, options: [:], completionHandler: nil)
        } else {
            displayCameraError("Cannot open camera setting!")
        }
    }
    
    internal func update(with faceRect: CGRect) {
        DispatchQueue.main.async { [weak self] in
            self?.detailsView.alpha = 1.0
            self?.detailsView.thickness = 5
            self?.detailsView.length = 10
            self?.detailsView.frame = faceRect
        }
    }
    
    internal func updateNoFace() {
        DispatchQueue.main.async { [weak self] in
            self?.detailsView.alpha = 0
            self?.resetChartData()
        }
    }
    
    private func resetChartData() {
        self.chartView.data = nil
        self.dataRGBH = [[], [], [], []]
        containerChartView.isHidden = true
    }
    
    internal func updateRealtimeFaceImage(_ image: UIImage) {
        DispatchQueue.main.async { [weak self] in
            self?.previewRoiIv.image = image
        }
    }
    
    internal func updateRealtimeColor(_ color: UIColor, hue: CGFloat) {
        DispatchQueue.main.async { [unowned self] in
            var r: CGFloat = 0
            var g: CGFloat = 0
            var b: CGFloat = 0
            var a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            
            let maxPoint = 30
            let values = [r, g, b, hue]
            for (i, value) in values.enumerated() {
                self.dataRGBH[i].append(Double(value))
                if self.dataRGBH[i].count > maxPoint {
                    self.dataRGBH[i].removeFirst()
                }
            }
            self.containerChartView.isHidden = false
            self.updateChart()
        }
    }
    
    internal func updateCameraIsReady() {
        setupNotifies()
    }
    
    internal func updateDisableIdleApplication(enable: Bool) {
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = enable
        }
    }
    
    func playVideoURL(_ url: URL) {
        let player = AVPlayer(url: url)
        let playerViewController = AVPlayerViewController()
        playerViewController.player = player
        self.present(playerViewController, animated: true) {
            playerViewController.player?.play()
        }
    }
    
    // Create a new layer drawing the bounding box
    private func createLayer(in rect: CGRect) -> CAShapeLayer{
        
        let mask = CAShapeLayer()
        mask.frame = rect
        mask.cornerRadius = 10
        mask.opacity = 0.75
        mask.borderColor = UIColor.yellow.cgColor
        mask.borderWidth = 2.0
        
        maskLayer.append(mask)
        previewLayer?.insertSublayer(mask, at: 1)
        
        return mask
    }
    
    func drawFaceboundingBox(faceRect: CGRect) {
        _ = createLayer(in: faceRect)
    }
    
    func removeMask() {
        for mask in maskLayer {
            mask.removeFromSuperlayer()
        }
        maskLayer.removeAll()
    }
}
