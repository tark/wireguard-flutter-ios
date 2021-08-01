//
//  NETunnelProviderManager.swift
//  Runner
//
//  Created by Airon on 01.08.2021.
//

import NetworkExtension
import WireGuardKit

fileprivate let l = L("NETunnelProviderManager")

extension NETunnelProviderManager {
  private static var cachedConfigKey: UInt8 = 0

  var tunnelConfiguration: TunnelConfiguration? {
    if let cached = objc_getAssociatedObject(self, &NETunnelProviderManager.cachedConfigKey) as? TunnelConfiguration {
      return cached
    }
    let config = (protocolConfiguration as? NETunnelProviderProtocol)?.asTunnelConfiguration(called: localizedDescription)
    if config != nil {
      objc_setAssociatedObject(self, &NETunnelProviderManager.cachedConfigKey, config, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
    return config
  }

  func setTunnelConfiguration(_ tunnelConfiguration: TunnelConfiguration) {
    l.i("setTunnelConfiguration")

    protocolConfiguration = NETunnelProviderProtocol(
      tunnelConfiguration: tunnelConfiguration,
      previouslyFrom: protocolConfiguration
    )

    l.i("setTunnelConfiguration - 1")

    localizedDescription = tunnelConfiguration.name

    l.i("setTunnelConfiguration - 2")

    objc_setAssociatedObject(
      self,
      &NETunnelProviderManager.cachedConfigKey,
      tunnelConfiguration,
      objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC
    )

    l.i("setTunnelConfiguration - 3")

  }

  func isEquivalentTo(_ tunnel: TunnelContainer) -> Bool {
    l.i("isEquivalentTo")
    return localizedDescription == tunnel.name && tunnelConfiguration == tunnel.tunnelConfiguration
  }
}
