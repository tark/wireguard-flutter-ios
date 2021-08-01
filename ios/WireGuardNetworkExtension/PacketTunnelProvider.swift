//
//  PacketTunnelProvider.swift
//  WireGuardNetworkExtension
//
//  Created by Airon on 01.08.2021.
//

import NetworkExtension
import WireGuardKit

fileprivate let l = L("PacketTunnelProvider")

class PacketTunnelProvider: NEPacketTunnelProvider {
  
  private lazy var adapter: WireGuardAdapter = {
    return WireGuardAdapter(with: self) { logLevel, message in
      l.i(message)
    }
  }()
  
  override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
    let activationAttemptId = options?["activationAttemptId"] as? String
    //let errorNotifier = ErrorNotifier(activationAttemptId: activationAttemptId)
    
    //Logger.configureGlobal(tagged: "NET", withFilePath: FileManager.logFileURL?.path)
    
    l.i("Starting tunnel from the " + (activationAttemptId == nil ? "OS directly, rather than the app" : "app"))
    
    guard let tunnelProviderProtocol = self.protocolConfiguration as? NETunnelProviderProtocol,
          let tunnelConfiguration = tunnelProviderProtocol.asTunnelConfiguration() else {
      //errorNotifier.notify(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)
      completionHandler(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)
      return
    }
    
    // Start the tunnel
    adapter.start(tunnelConfiguration: tunnelConfiguration) { adapterError in
      guard let adapterError = adapterError else {
        let interfaceName = self.adapter.interfaceName ?? "unknown"
        
        l.i("Tunnel interface is \(interfaceName)")
        
        completionHandler(nil)
        return
      }
      
      switch adapterError {
      case .cannotLocateTunnelFileDescriptor:
        l.i("Starting tunnel failed: could not determine file descriptor")
        //errorNotifier.notify(PacketTunnelProviderError.couldNotDetermineFileDescriptor)
        completionHandler(PacketTunnelProviderError.couldNotDetermineFileDescriptor)
        
      case .dnsResolution(let dnsErrors):
        let hostnamesWithDnsResolutionFailure = dnsErrors.map { $0.address }
          .joined(separator: ", ")
        l.i("DNS resolution failed for the following hostnames: \(hostnamesWithDnsResolutionFailure)")
        //errorNotifier.notify(PacketTunnelProviderError.dnsResolutionFailure)
        completionHandler(PacketTunnelProviderError.dnsResolutionFailure)
        
      case .setNetworkSettings(let error):
        l.i("Starting tunnel failed with setTunnelNetworkSettings returning \(error.localizedDescription)")
        //errorNotifier.notify(PacketTunnelProviderError.couldNotSetNetworkSettings)
        completionHandler(PacketTunnelProviderError.couldNotSetNetworkSettings)
        
      case .startWireGuardBackend(let errorCode):
        l.i("Starting tunnel failed with wgTurnOn returning \(errorCode)")
        //errorNotifier.notify(PacketTunnelProviderError.couldNotStartBackend)
        completionHandler(PacketTunnelProviderError.couldNotStartBackend)
        
      case .invalidState:
        // Must never happen
        fatalError()
      }
    }
  }
  
  override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
    l.i("Stopping tunnel")
    
    adapter.stop { error in
      //ErrorNotifier.removeLastErrorFile()
      
      if let error = error {
        l.i("Failed to stop WireGuard adapter: \(error.localizedDescription)")
      }
      completionHandler()
      
      #if os(macOS)
      // HACK: This is a filthy hack to work around Apple bug 32073323 (dup'd by us as 47526107).
      // Remove it when they finally fix this upstream and the fix has been rolled out to
      // sufficient quantities of users.
      exit(0)
      #endif
    }
  }
  
  override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)? = nil) {
    guard let completionHandler = completionHandler else { return }
    
    if messageData.count == 1 && messageData[0] == 0 {
      adapter.getRuntimeConfiguration { settings in
        var data: Data?
        if let settings = settings {
          data = settings.data(using: .utf8)!
        }
        completionHandler(data)
      }
    } else {
      completionHandler(nil)
    }
  }
  
  override func sleep(completionHandler: @escaping () -> Void) {
    // Add code here to get ready to sleep.
    completionHandler()
  }
  
  override func wake() {
    // Add code here to wake up.
  }
}
