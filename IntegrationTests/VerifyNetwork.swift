import Foundation

@main enum VerifyNetwork {
    @MainActor static func main() async {
        do {
            let basic = NetworkReadiness(timeout: 40, conditionName: "基础网络就绪", probe: BasicNetworkProbe.check)
            let basicReady = try await basic.waitUntilReady(whileNeeded: { true }) { count in
                print("Physical link/IP/router consecutive successes: \(count)/3")
            }
            guard basicReady else { exit(1) }
            let gate = NetworkReadiness(timeout: 40)
            let ready = try await gate.waitUntilReady(whileNeeded: { true }) { count in
                print("HTTPS consecutive successes: \(count)/3")
            }
            guard ready else { exit(1) }
            print("PASS: physical-link gate followed by production HTTPS gate")
        } catch {
            print("FAIL: \(error.localizedDescription)")
            exit(1)
        }
    }
}
