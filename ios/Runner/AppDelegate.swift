import UIKit
import Flutter
import NetworkExtension
import WireGuardKit
import WireGuardKitC
import WireGuardKitGo
import WireGuardNetworkExtension

fileprivate let l = L("App")

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  
  fileprivate var tunnelProvider: NETunnelProviderManager
  
  override init() {
    tunnelProvider = NETunnelProviderManager()
  }
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    self.addConfig()
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  func addConfig() {
    
    var config = InterfaceConfiguration(
      privateKey: PrivateKey(base64Key: "mIWKevXKBlBxXEAtzJJtLOU0TjSduvvm9rUQpvdPBkM=")!
    )
    config.addresses = [IPAddressRange(from: "10.200.200.185")!]
    config.dns = [DNSServer(address: IPv4Address("116.203.231.122")!)]
    config.listenPort = 51820
    
    var peerConfig = PeerConfiguration(
      publicKey: PublicKey(base64Key: "9Xhc/RmDmmyy54+F/mhSh1KEV0/bjD6ruAp934pmlDk=")!
    )
    peerConfig.allowedIPs = [IPAddressRange(from: "0.0.0.0/0")!]
    peerConfig.endpoint = Endpoint(
      host: "wghongkong01.spidervpnservers.com",
      port: 443
    )
    
    tunnelProvider.setTunnelConfiguration(TunnelConfiguration.init(
      name: "Spider VPN",
      interface: config,
      peers: [peerConfig]
    ))
    
    tunnelProvider.isEnabled = true
    
    tunnelProvider.saveToPreferences { [weak self] error in
      if error != nil {
        l.i("Failed to save config to preferences")
        return
      }
      
      l.i("Save config to preferences successfully")

      guard self != nil else { return }
      
      self?.startTunnel()
    }
    
  }
  
  func startTunnel() {

    // Check if tunnel is disabled and if so re-enable
    guard tunnelProvider.isEnabled else {
        l.i("Tunnel is disabled: Re-enabling")
        tunnelProvider.isEnabled = true
        tunnelProvider.saveToPreferences { [weak self] error in
            guard let self = self else { return }
            
            if error != nil {
                l.i("Error saving tunnel: \(error!)")
                return
            }
            
            l.i("Tunnel re-enabled and saved")
            self.startTunnel()
            
        }
        return
    }
    
    // Start the tunnel
    do {
      l.i("Attempting to start tunnel")
      let activationAttemptId = UUID().uuidString
      try (tunnelProvider.connection as? NETunnelProviderSession)?.startTunnel(options: ["activationAttemptId": activationAttemptId])
      l.i("Tunnel started")
    } catch let error {
      
      guard let systemError = error as? NEVPNError else {
        l.i("Failed to start tunnel: Unknown error. We can handle only the NEVPNError")
        return
      }
      
      // Note: We are not concerned if the configuration is invalid on first attempt - second should succeed;
      guard systemError.code == NEVPNError.configurationInvalid || systemError.code == NEVPNError.configurationStale else {
        l.i("Failed to start tunnel: Unknown error. We can handle only a) invalid configuration b) configuration stale, but this is - \(error)")
        return
      }
      
      l.i("Going to reload tunnel config and start it: this is well-known error - \(error)")
      
      tunnelProvider.loadFromPreferences { [weak self] error in
        guard let self = self else { return }
        if error != nil {
          l.i("Failed to reload tunnel: \(error!)")
          return
        }
        l.i("Tunnel reloaded")
        self.startTunnel()
      }
    }
    
  }
  
}

