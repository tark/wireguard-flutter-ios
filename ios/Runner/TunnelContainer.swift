//
//  TunnelContaienr.swift
//  Runner
//
//  Created by Airon on 01.08.2021.
//

import Foundation
import WireGuardKit
import NetworkExtension
import WireGuardNetworkExtension

fileprivate let l = L("TunnelContainer")

class TunnelContainer: NSObject {
  @objc dynamic var name: String
  @objc dynamic var status: TunnelStatus
  
  @objc dynamic var isActivateOnDemandEnabled: Bool
  
  var isAttemptingActivation = false {
    didSet {
      if isAttemptingActivation {
        self.activationTimer?.invalidate()
        let activationTimer = Timer(timeInterval: 5 /* seconds */, repeats: true) { [weak self] _ in
          guard let self = self else { return }
          wg_log(.debug, message: "Status update notification timeout for tunnel '\(self.name)'. Tunnel status is now '\(self.tunnelProvider.connection.status)'.")
          switch self.tunnelProvider.connection.status {
          case .connected, .disconnected, .invalid:
            self.activationTimer?.invalidate()
            self.activationTimer = nil
          default:
            break
          }
          self.refreshStatus()
        }
        self.activationTimer = activationTimer
        RunLoop.main.add(activationTimer, forMode: .common)
      }
    }
  }
  var activationAttemptId: String?
  var activationTimer: Timer?
  var deactivationTimer: Timer?
  
  fileprivate var tunnelProvider: NETunnelProviderManager
  
  var tunnelConfiguration: TunnelConfiguration? {
    return tunnelProvider.tunnelConfiguration
  }
  
//  var onDemandOption: ActivateOnDemandOption {
//    return ActivateOnDemandOption(from: tunnelProvider)
//  }
  
  #if os(macOS)
  var isTunnelAvailableToUser: Bool {
    return (tunnelProvider.protocolConfiguration as? NETunnelProviderProtocol)?.providerConfiguration?["UID"] as? uid_t == getuid()
  }
  #endif
  
  init(tunnel: NETunnelProviderManager) {
    l.i("init")
    name = tunnel.localizedDescription ?? "Unnamed"
    let status = TunnelStatus(from: tunnel.connection.status)
    self.status = status
    isActivateOnDemandEnabled = tunnel.isOnDemandEnabled
    tunnelProvider = tunnel
    super.init()
  }
  
  func getRuntimeTunnelConfiguration(completionHandler: @escaping ((TunnelConfiguration?) -> Void)) {
    l.i("getRuntimeTunnelConfiguration")
    guard status != .inactive, let session = tunnelProvider.connection as? NETunnelProviderSession else {
      completionHandler(tunnelConfiguration)
      return
    }
    guard nil != (try? session.sendProviderMessage(Data([ UInt8(0) ]), responseHandler: {
      guard self.status != .inactive, let data = $0, let base = self.tunnelConfiguration, let settings = String(data: data, encoding: .utf8) else {
        completionHandler(self.tunnelConfiguration)
        return
      }
      completionHandler((try? TunnelConfiguration(fromUapiConfig: settings, basedOn: base)) ?? self.tunnelConfiguration)
    })) else {
      completionHandler(tunnelConfiguration)
      return
    }
  }
  
  func refreshStatus() {
    l.i("refreshStatus")
    if status == .restarting {
      return
    }
    status = TunnelStatus(from: tunnelProvider.connection.status)
    isActivateOnDemandEnabled = tunnelProvider.isOnDemandEnabled
  }
  
  fileprivate func startActivation(recursionCount: UInt = 0, lastError: Error? = nil) {
    l.i("startActivation")
    
    l.i("startActivation - \(String(describing: tunnelConfiguration?.interface))")
    l.i("startActivation - \(String(describing: tunnelConfiguration?.interface.addresses))")
    
    if recursionCount >= 8 {
      l.i("startActivation: Failed after 8 attempts. Giving up with \(lastError!)")
      return
    }
    
    l.i("startActivation: Entering (tunnel: \(name))")
    
    status = .activating // Ensure that no other tunnel can attempt activation until this tunnel is done trying
    
    guard tunnelProvider.isEnabled else {
      // In case the tunnel had gotten disabled, re-enable and save it,
      // then call this function again.
      l.i("startActivation: Tunnel is disabled. Re-enabling and saving")
      tunnelProvider.isEnabled = true
      tunnelProvider.saveToPreferences { [weak self] error in
        guard let self = self else { return }
        if error != nil {
          l.i("startActivation: Error saving tunnel after re-enabling: \(error!)")
          return
        }
        l.i("startActivation: Tunnel saved after re-enabling, invoking startActivation")
        self.startActivation(
          recursionCount: recursionCount + 1,
          lastError: NEVPNError(NEVPNError.configurationUnknown)
        )
      }
      return
    }
    
    // Start the tunnel
    do {
      l.i("startActivation: Starting tunnel")
      isAttemptingActivation = true
      let activationAttemptId = UUID().uuidString
      self.activationAttemptId = activationAttemptId
      try (tunnelProvider.connection as? NETunnelProviderSession)?.startTunnel(
        options: ["activationAttemptId": activationAttemptId]
      )
      l.i("startActivation: Success")
    } catch let error {
      isAttemptingActivation = false
      guard let systemError = error as? NEVPNError else {
        l.i("startActivation: Failed to activate tunnel: Error: \(error)")
        status = .inactive
        return
      }
      guard systemError.code == NEVPNError.configurationInvalid || systemError.code == NEVPNError.configurationStale else {
        l.i("Failed to activate tunnel: VPN Error: \(error)")
        status = .inactive
        return
      }
      l.i("startActivation: Will reload tunnel and then try to start it.")
      tunnelProvider.loadFromPreferences { [weak self] error in
        guard let self = self else { return }
        if error != nil {
          l.i("startActivation: Error reloading tunnel: \(error!)")
          self.status = .inactive
          return
        }
        l.i("startActivation: Tunnel reloaded, invoking startActivation")
        self.startActivation(recursionCount: recursionCount + 1, lastError: systemError)
      }
    }
  }
  
  fileprivate func startDeactivation() {
    l.i("startDeactivation \(name)")
    (tunnelProvider.connection as? NETunnelProviderSession)?.stopTunnel()
  }
}
