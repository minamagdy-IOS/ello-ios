//
//  UIImageViewExtensions.swift
//  Ello
//
//  Created by Colin Gray on 5/20/2015.
//  Copyright (c) 2015 Ello. All rights reserved.
//

import SVGKit

extension UIImageView {

    func setImage(interfaceImage: Interface.Image, degree: Double) {
        self.image = interfaceImage.normalImage
        if degree != 0 {
            let radians = (degree * M_PI) / 180.0
            self.transform = CGAffineTransformMakeRotation(CGFloat(radians))
        }
    }

}
