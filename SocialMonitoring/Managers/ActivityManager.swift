//
//  ActivityMonitor.swift
//  SocialMonitoring
//
//  Created by Alexandr Bahno on 13.01.2026.
//

import Cocoa
import ApplicationServices
import Carbon.HIToolbox
import ScreenCaptureKit
import Combine
import UniformTypeIdentifiers

protocol ActivityManagerProtocol {
    func startMonitoring()
    func stopMonitoring()
}

final class ActivityManager {
    // List of Bundle IDs
    let socialAppBundleIDs = [
        "telegram",    // Telegram
        "whatsapp",    // WhatsApp
        "ciscord",     // Discord
        "ichat",       // iMessage
        "viber"        // Viber
    ]
    private var globalMonitor: Any?
    private var mouseMonitor: Any?
    
    private func handleKeyPress(_ event: NSEvent) {
        guard event.keyCode == kVK_Return else {
            return
        }
        
        let flags = event.modifierFlags
        let isCommandPressed = flags.contains(.command)
        let isShiftPressed = flags.contains(.shift)
        
        // Command + Return
        if isCommandPressed {
            print("Detected: Cmd + Return")
            checkCurrentAppAndScreenshot()
            return
        }
        
        if !isCommandPressed && !isShiftPressed {
            print("Detected: Standard Return")
            checkCurrentAppAndScreenshot()
            return
        }
    }
    
    private func checkCurrentAppAndScreenshot() {
        // Get the frontmost application
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let bundleID = frontApp.bundleIdentifier else { return }
        
        let isAppSocial = socialAppBundleIDs
            .map({bundleID.lowercased().contains($0)})
            .contains(where: {$0})
        
        // Check if the active app is in our "Social" list
        if isAppSocial {
            print("Detected Enter key in social app: \(frontApp.localizedName ?? "Unknown")")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.takeScreenshot(ofAppBundleID: bundleID)
            }
        }
    }
}

// MARK: - ActivityManagerProtocol
extension ActivityManager: ActivityManagerProtocol {
    func startMonitoring() {
        guard globalMonitor == nil else { return }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyPress(event)
        }
        
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            self?.checkCurrentAppAndScreenshot()
        }
    }
    
    func stopMonitoring() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
    }
}

// MARK: - Make screenshot
private extension ActivityManager {
    func takeScreenshot(ofAppBundleID targetBundleID: String) {
        Task {
            do {
                let content = try await SCShareableContent.current
                guard let display = content.displays.first else { return }
                
                let scaleFactor = NSScreen.screens.first { screen in
                    screen.frame.contains(
                        CGPoint(
                            x: display.frame.origin.x,
                            y: display.frame.origin.y
                        )
                    )
                }?.backingScaleFactor ?? 2.0
                
                let appToCapture = content.applications
                    .first { $0.bundleIdentifier == targetBundleID }
                
                let filter = appToCapture
                    .map {
                        SCContentFilter(display: display, including: [$0], exceptingWindows: [])
                    }
                ?? SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
                
                let config = SCStreamConfiguration()
                config.width = Int(CGFloat(display.width) * scaleFactor)
                config.height = Int(CGFloat(display.height) * scaleFactor)
                config.captureResolution = .best
                config.scalesToFit = true
                
                config.colorSpaceName = NSScreen.main?
                    .colorSpace?
                    .cgColorSpace?
                    .name ?? CGColorSpace.displayP3
                
                config.pixelFormat = kCVPixelFormatType_32BGRA
                config.showsCursor = false
                
                let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                
                saveImageToDesktop(cgImage.asNSImage())
            } catch(let error) {
                print(error)
            }
        }
    }
    
    func getFocusedWindowFrame() -> CGRect? {
        let systemWideElement = AXUIElementCreateSystemWide()
        
        var focusedAppRef: AnyObject?
        let appError = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedApplicationAttribute as CFString, &focusedAppRef)
        
        guard appError == .success, let focusedApp = focusedAppRef else {
            print("Error: Could not get focused application.")
            return nil
        }
        let appElement = focusedApp as! AXUIElement
        
        var focusedWindowRef: AnyObject?
        let windowError = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindowRef)
        
        guard windowError == .success, let focusedWindow = focusedWindowRef else {
            print("Error: Could not get focused window (App might not have windows).")
            return nil
        }
        let windowElement = focusedWindow as! AXUIElement
        
        var positionRef: AnyObject?
        let posError = AXUIElementCopyAttributeValue(windowElement, kAXPositionAttribute as CFString, &positionRef)
        
        var position = CGPoint.zero
        if posError == .success {
            _ = AXValueGetValue(positionRef as! AXValue, .cgPoint, &position)
        }
        
        var sizeRef: AnyObject?
        let sizeError = AXUIElementCopyAttributeValue(windowElement, kAXSizeAttribute as CFString, &sizeRef)
        
        var size = CGSize.zero
        if sizeError == .success {
            _ = AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
        }
        
        return CGRect(origin: position, size: size)
    }
}

// MARK: - Save screenshot
private extension ActivityManager {
    func saveImageToDesktop(_ image: NSImage) {
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else { return }
        
        let fileManager = FileManager.default
        let desktopURL = fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let timestamp = Int(Date().timeIntervalSince1970)
        let fileURL = desktopURL.appendingPathComponent("SocialCap_\(timestamp).png")
        
        do {
            try pngData.write(to: fileURL)
            print("Screenshot saved to: \(fileURL.path)")
        } catch {
            print("Failed to save screenshot: \(error)")
        }
    }
}
