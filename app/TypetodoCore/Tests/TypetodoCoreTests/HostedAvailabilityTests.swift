import XCTest
@testable import TypetodoCore

/// 一期护栏：没有托管通道时，产品必须完全落在「自带 Key、纯本地」这条路径上。
/// 二期接回服务端时，这些用例会提醒你确认改动没有破坏降级行为。
final class HostedAvailabilityTests: XCTestCase {

    // MARK: - 地址归一

    func testResolvePrefersDefaultsOverride() {
        XCTAssertEqual(HostedAvailability.resolve(defaultsValue: "http://127.0.0.1:8787",
                                                  plistValue: "https://hosted.example.com"),
                       "http://127.0.0.1:8787")
    }

    func testResolveFallsBackToPlistWhenDefaultsEmpty() {
        XCTAssertEqual(HostedAvailability.resolve(defaultsValue: "   ",
                                                  plistValue: "https://hosted.example.com"),
                       "https://hosted.example.com")
    }

    func testResolveTreatsUnsubstitutedBuildVariableAsMissing() {
        // Xcode 没定义该变量时会把 $(VAR) 原样写进 Info.plist
        XCTAssertNil(HostedAvailability.resolve(defaultsValue: nil, plistValue: "$(TYPETODO_HOSTED_API_BASE)"))
    }

    func testResolveReturnsNilWhenNothingConfigured() {
        XCTAssertNil(HostedAvailability.resolve(defaultsValue: nil, plistValue: nil))
        XCTAssertNil(HostedAvailability.resolve(defaultsValue: "", plistValue: "  \n "))
    }

    // MARK: - 一期默认关闭

    func testThisBuildHasNoHostedChannel() {
        // 一期仓库不注入任何服务器地址；这个断言失败说明有人把地址写进了源码。
        XCTAssertNil(HostedAvailability.apiBase)
        XCTAssertFalse(HostedAvailability.isEnabled)
        XCTAssertNil(HostedAvailability.certSHA256)
    }

    func testTrialAndLicenseChannelsAreBothOff() {
        let suiteName = "hosted-availability-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let license = LicenseManager(defaults: defaults)
        XCTAssertFalse(license.isHostedAvailable)
        XCTAssertFalse(license.isActivated)
        XCTAssertFalse(license.hasActiveMembership())

        let trial = TrialManager(defaults: defaults, apiBase: nil)
        XCTAssertFalse(trial.isTrialAvailable)
        XCTAssertFalse(trial.isInTrial)
    }

    // MARK: - 路由必须落到 .none

    func testRoutingFallsBackToNoneWithoutHostedChannel() {
        XCTAssertEqual(HostedRoute.decide(ownKeyConfigured: true,
                                          hostedAvailable: false,
                                          isActivated: false,
                                          hasActiveMembership: false,
                                          isInTrial: true),
                       .none)
        XCTAssertEqual(HostedRoute.decide(ownKeyConfigured: false,
                                          hostedAvailable: false,
                                          isActivated: false,
                                          hasActiveMembership: false,
                                          isInTrial: true),
                       .none)
    }

    func testGlobalRouteIsNoneForBothKeyStates() {
        XCTAssertEqual(HostedRoute.current(ownKeyConfigured: true), .none)
        XCTAssertEqual(HostedRoute.current(ownKeyConfigured: false), .none)
    }

    // MARK: - 二级：配置了通道时行为不变（证明接缝是可用的）

    func testDecidePrefersMemberWhenNoOwnKey() {
        XCTAssertEqual(HostedRoute.decide(ownKeyConfigured: false,
                                          hostedAvailable: true,
                                          isActivated: true,
                                          hasActiveMembership: true,
                                          isInTrial: false),
                       .member)
    }

    func testDecidePrefersOwnKeyUnlessMemberFirst() {
        XCTAssertEqual(HostedRoute.decide(ownKeyConfigured: true,
                                          hostedAvailable: true,
                                          isActivated: true,
                                          hasActiveMembership: true,
                                          isInTrial: false,
                                          memberFirst: false),
                       .none)
        XCTAssertEqual(HostedRoute.decide(ownKeyConfigured: true,
                                          hostedAvailable: true,
                                          isActivated: true,
                                          hasActiveMembership: true,
                                          isInTrial: false,
                                          memberFirst: true),
                       .member)
    }

    func testDecideFallsBackToTrialOnlyWithoutOwnKeyAndNotActivated() {
        XCTAssertEqual(HostedRoute.decide(ownKeyConfigured: false,
                                          hostedAvailable: true,
                                          isActivated: false,
                                          hasActiveMembership: false,
                                          isInTrial: true),
                       .trial)
    }
}
