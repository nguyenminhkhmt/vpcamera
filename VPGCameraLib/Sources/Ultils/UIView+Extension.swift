//
//  UIView+Extension.swift
//  VPGCamera
//
//  Created by Minh Nguyen Duc on 1/12/20.
//  Copyright © 2020 ahdenglish. All rights reserved.
//

import Foundation
import UIKit

extension UIView {
    class func showProgress(_ status: String? = nil) {
        let activityData = ActivityData(message: status)
        NVActivityIndicatorPresenter.sharedInstance.startAnimating(activityData)
    }

    class func hideProgress() {
        DispatchQueue.main.async {
            NVActivityIndicatorPresenter.sharedInstance.stopAnimating()
        }
    }
}
