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
    l.i("init")
        
    tunnelProvider = NETunnelProviderManager()
    
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
      name: "test-tunel",
      interface: config,
      peers: [peerConfig]
    ))
    
    tunnelProvider.isEnabled = true
    
    do {
      try (tunnelProvider.connection as? NETunnelProviderSession)?.startTunnel(
        //options: ["activationAttemptId": 1]
      )
    } catch let error {
      l.i(error.localizedDescription)
      
      guard let systemError = error as? NEVPNError else {
        l.i("Failed to activate tunnel: Error: \(error)")
        return
      }
      
      switch systemError.code {
      case NEVPNError.configurationInvalid:
        l.i("error - configurationInvalid")
      case NEVPNError.configurationDisabled:
        l.i("error - configurationDisabled")
      case NEVPNError.configurationReadWriteFailed:
        l.i("error - configurationReadWriteFailed")
      case NEVPNError.configurationStale:
        l.i("error - configurationStale")
      case NEVPNError.configurationUnknown:
        l.i("error - configurationUnknown")
      case NEVPNError.connectionFailed:
        l.i("error - connectionFailed")
        
      default:
        l.i("error - some error happens - \(error)")
      }
    
    }
    
  }
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    
    
    
      
    
    
  }
}

