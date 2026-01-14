//
//  ContentView.swift
//  SocialMonitoring
//
//  Created by Alexandr Bahno on 13.01.2026.
//

import SwiftUI
import ScreenCaptureKit
import Combine

struct ContentView<PermissionMangerWrapper>:
    View where PermissionMangerWrapper: PermissionManagerProtocol {
    
    @ObservedObject var permissionManager: PermissionMangerWrapper
    @State private var showPermissionAlert = false
    
    let activityMonitor: ActivityManagerProtocol
    
    var body: some View {
        VStack {
            if !permissionManager.arePermissionsGranted {
                permissionNotGrantedView
            } else {
                mainView
            }
        }
        .onAppear {
            permissionManager.askForPermissions()
            if permissionManager.arePermissionsGranted {
                activityMonitor.startMonitoring()
            }
        }
    }
    
    @ViewBuilder
    var permissionNotGrantedView: some View {
        Text("Permissions are not granted. Please allow access to your camera and microphone in settings.")
        
        Button {
            permissionManager.openSettings()
        } label: {
            Text("Open Settings")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white)
                .padding(8)
        }
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.blue)
        }
    }
    
    @ViewBuilder
    var mainView: some View {
        Text("Open a messanger and send message\n(press return or return+command) then screenshot will be taken and saved to desktop.")
            .font(.system(size: 28, weight: .medium))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
    }
}
