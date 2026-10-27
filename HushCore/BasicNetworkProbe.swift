import Foundation
import SystemConfiguration
import Darwin

/// Local link + assigned address + router on the same physical service.
/// No DNS lookup, internet request, VPN or proxy is required.
enum BasicNetworkProbe {
    struct Service {
        let physical: Bool
        let active: Bool
        let addresses: [String]
        let router: String?
        let ipv6: Bool

        var isReady: Bool {
            guard physical, active, let router,
                  BasicNetworkProbe.isUsable(router, ipv6: ipv6, router: true) else { return false }
            return addresses.contains { BasicNetworkProbe.isUsable($0, ipv6: ipv6, router: false) }
        }
    }

    static func check(timeout: TimeInterval) async throws -> Bool {
        try Task.checkCancellation()
        guard let store = SCDynamicStoreCreate(nil, "com.murphy.hush.network" as CFString, nil, nil) else { return false }
        let interfaces = SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] ?? []
        let physicalNames = Set(interfaces.compactMap { interface -> String? in
            guard let name = SCNetworkInterfaceGetBSDName(interface) as String?,
                  let type = SCNetworkInterfaceGetInterfaceType(interface) as String?,
                  [kSCNetworkInterfaceTypeEthernet as String, kSCNetworkInterfaceTypeIEEE80211 as String].contains(type)
            else { return nil }
            return name
        })
        for family in ["IPv4", "IPv6"] {
            let keys = SCDynamicStoreCopyKeyList(store, "State:/Network/Service/.*/\(family)" as CFString) as? [String] ?? []
            for key in keys {
                guard let state = SCDynamicStoreCopyValue(store, key as CFString) as? [String: Any],
                      let name = state["InterfaceName"] as? String else { continue }
                let link = SCDynamicStoreCopyValue(store, "State:/Network/Interface/\(name)/Link" as CFString) as? [String: Any]
                let service = Service(physical: physicalNames.contains(name), active: link?["Active"] as? Bool == true,
                                      addresses: state["Addresses"] as? [String] ?? [], router: state["Router"] as? String,
                                      ipv6: family == "IPv6")
                if service.isReady { return true }
            }
        }
        return false
    }

    private static func isUsable(_ address: String, ipv6: Bool, router: Bool) -> Bool {
        if ipv6 {
            var parsed = in6_addr()
            let raw = String(address.prefix { $0 != "%" })
            guard inet_pton(AF_INET6, raw, &parsed) == 1 else { return false }
            let bytes = withUnsafeBytes(of: parsed) { Array($0) }
            guard !bytes.allSatisfy({ $0 == 0 }),
                  !(bytes.dropLast().allSatisfy({ $0 == 0 }) && bytes.last == 1), bytes[0] != 0xff else { return false }
            // A link-local IPv6 router is normal, but a link-local-only host isn't ready.
            return router || !(bytes[0] == 0xfe && bytes[1] & 0xc0 == 0x80)
        }
        var parsed = in_addr()
        guard inet_pton(AF_INET, address, &parsed) == 1 else { return false }
        let bytes = withUnsafeBytes(of: parsed) { Array($0) }
        return bytes[0] != 0 && bytes[0] != 127 && bytes[0] < 224 && !(bytes[0] == 169 && bytes[1] == 254)
    }
}
