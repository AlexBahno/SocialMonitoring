//
//  CGImage+NSImage.swift
//  SocialMonitoring
//
//  Created by Alexandr Bahno on 13.01.2026.
//

import SwiftUI

extension CGImage {
    func asNSImage() -> NSImage {
        return NSImage(
            cgImage: self,
            size: NSSize(width: self.width, height: self.height)
        )
    }
}
