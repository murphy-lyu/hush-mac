import Foundation

@main enum VerifyNetwork {
    @MainActor static func main() async {
        do {
            let basic = NetworkReadiness(timeout: 40, requiredSuccesses: 1, conditionName: "基础网络就绪", probe: BasicNetworkProbe.check)
            defer { basic.reset() }
            let basicReady = try await basic.waitUntilReady(whileNeeded: { true }) { count in
                print("Physical link/IP/router consecutive successes: \(count)/\(basic.requiredSuccesses)")
            }
            guard basicReady else { exit(1) }
            let gate = NetworkReadiness(timeout: 40)
            defer { gate.reset() }
            let ready = try await gate.waitUntilReady(whileNeeded: { true }) { count in
                print("HTTPS consecutive successes: \(count)/\(gate.requiredSuccesses)")
            }
            guard ready else { exit(1) }
            print("PASS: physical-link gate followed by production HTTPS gate")
        } catch {
            print("FAIL: \(error.localizedDescription)")
            exit(1)
        }
    }
}
