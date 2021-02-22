//
//  CameraRouter.swift
//  VPGCamera
//
//  Created by Minh Nguyen Duc on 1/6/20.
//  Copyright © 2020 ahdenglish. All rights reserved.
//

import Foundation
import UIKit

class CameraRouter {
    
    static func createModule(config: VPGCamearConfiguration) -> CameraViewController {
        let view = storyboard.instantiateViewController(withIdentifier: "CameraViewController1412") as! CameraViewController
        
        let presenter = CameraPresenter()
        let router = CameraRouter()
        let interactor = CameraInteractor()
        
        // Config
        presenter.updateParams(config)
        presenter.interactor = interactor
        presenter.view = view
        presenter.router = router
        view.presenter = presenter
        interactor.output = presenter
        
        return view
    }
    
    static var storyboard: UIStoryboard {
        let bundle = Bundle(for: VPGCameraSDK.self)
        return UIStoryboard(name: "Camera", bundle: bundle)
    }
}

extension CameraRouter: CameraWireframeProtocol {
    
}
