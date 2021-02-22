//
//  CornerView.swift
//  VPGCamera
//
//  Created by Minh Nguyen Duc on 1/7/20.
//  Copyright © 2020 ahdenglish. All rights reserved.
//

import Foundation
import UIKit

import UIKit

class CornerView: UIView {
    var color = UIColor.white {
        didSet {
            setNeedsDisplay()
        }
    }
    var radius: CGFloat = 5 {
        didSet {
            setNeedsDisplay()
        }
    }
    var thickness: CGFloat = 5 {
        didSet {
            setNeedsDisplay()
        }
    }
    var length: CGFloat = 20 {
        didSet {
            setNeedsDisplay()
        }
    }
    
    override func setNeedsLayout() {
        super.setNeedsLayout()
        
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        color.set()

        let t2Val = thickness / 2
        let path = UIBezierPath()
        // Top left
        path.move(to: CGPoint(x: t2Val, y: length + radius + t2Val))
        path.addLine(to: CGPoint(x: t2Val, y: radius + t2Val))
        path.addArc(withCenter: CGPoint(x: radius + t2Val, y: radius + t2Val), radius: radius, startAngle: CGFloat.pi, endAngle: CGFloat.pi * 3 / 2, clockwise: true)
        path.addLine(to: CGPoint(x: length + radius + t2Val, y: t2Val))

        // Top right
        path.move(to: CGPoint(x: frame.width - t2Val, y: length + radius + t2Val))
        path.addLine(to: CGPoint(x: frame.width - t2Val, y: radius + t2Val))
        path.addArc(withCenter: CGPoint(x: frame.width - radius - t2Val, y: radius + t2Val), radius: radius, startAngle: 0, endAngle: CGFloat.pi * 3 / 2, clockwise: false)
        path.addLine(to: CGPoint(x: frame.width - length - radius - t2Val, y: t2Val))

        // Bottom left
        path.move(to: CGPoint(x: t2Val, y: frame.height - length - radius - t2Val))
        path.addLine(to: CGPoint(x: t2Val, y: frame.height - radius - t2Val))
        path.addArc(withCenter: CGPoint(x: radius + t2Val, y: frame.height - radius - t2Val), radius: radius, startAngle: CGFloat.pi, endAngle: CGFloat.pi / 2, clockwise: false)
        path.addLine(to: CGPoint(x: length + radius + t2Val, y: frame.height - t2Val))

        // Bottom right
        path.move(to: CGPoint(x: frame.width - t2Val, y: frame.height - length - radius - t2Val))
        path.addLine(to: CGPoint(x: frame.width - t2Val, y: frame.height - radius - t2Val))
        path.addArc(withCenter: CGPoint(x: frame.width - radius - t2Val, y: frame.height - radius - t2Val), radius: radius, startAngle: 0, endAngle: CGFloat.pi / 2, clockwise: true)
        path.addLine(to: CGPoint(x: frame.width - length - radius - t2Val, y: frame.height - t2Val))

        path.lineWidth = thickness
        path.stroke()
    }
}
