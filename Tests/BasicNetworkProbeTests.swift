import XCTest
@testable import HushCore

final class BasicNetworkProbeTests: XCTestCase {
    private func service(_ addresses: [String] = ["192.168.1.2"], router: String? = "192.168.1.1",
                         physical: Bool = true, active: Bool = true, ipv6: Bool = false) -> BasicNetworkProbe.Service {
        .init(physical: physical, active: active, addresses: addresses, router: router, ipv6: ipv6)
    }

    func testPhysicalLinkWithIPv4AndRouterIsReady() {
        XCTAssertTrue(service().isReady)
        XCTAssertTrue(service(["100.64.1.2"], router: "100.64.1.1").isReady)
    }

    func testDisconnectedOrVirtualServiceIsNotReady() {
        XCTAssertFalse(service(active: false).isReady)
        XCTAssertFalse(service(physical: false).isReady)
        // An active VPN with a Tailnet address and router cannot substitute for Wi-Fi/Ethernet.
        XCTAssertFalse(service(["100.103.122.38"], router: "100.103.122.38", physical: false).isReady)
    }

    func testNeedsRouterAndValidAssignedAddress() {
        XCTAssertFalse(service(router: nil).isReady)
        XCTAssertFalse(service(router: "0.0.0.0").isReady)
        XCTAssertFalse(service(router: "garbage").isReady)
        for address in ["", "0.0.0.0", "127.0.0.1", "169.254.1.2", "224.0.0.1", "255.255.255.255", "not-an-ip"] {
            XCTAssertFalse(service([address]).isReady, address)
        }
        XCTAssertFalse(service([]).isReady)
    }

    func testIPv6WithLinkLocalGatewayIsReadyButLinkLocalOnlyHostIsNot() {
        XCTAssertTrue(service(["2001:db8::2"], router: "fe80::1%en0", ipv6: true).isReady)
        XCTAssertTrue(service(["fd00::2"], router: "fe80::1", ipv6: true).isReady)
        for address in ["", "::", "::1", "ff02::1", "fe80::2%en0", "not-an-ip"] {
            XCTAssertFalse(service([address], router: "fe80::1", ipv6: true).isReady, address)
        }
        XCTAssertFalse(service(["2001:db8::2"], router: "::", ipv6: true).isReady)
        XCTAssertFalse(service(["2001:db8::2"], router: nil, ipv6: true).isReady)
    }
}
