import Foundation

/// 托管通道（免费试用 / 年付会员）的总开关。
///
/// **一期（自带 Key、纯本地）为关闭状态**：不激活、不试用、不向任何服务器发请求。
/// 关掉之后，`AIPolisher` / `CloudASRTranscriber` 里的通道判定一律走 `.none`，
/// 也就是「用用户自己的 Key 直连模型厂商」——一期唯一的工作路径。
///
/// 这里刻意**不删除**试用/会员的实现：那套代码已经包含二期的完整契约
/// （`HostedRoute.decide` 纯函数判定、`MembershipInfo` DTO、`ActivationError` 错误码、
/// `trial_expired` / `insufficient_quota` 等服务器错误码映射、证书固定）。
/// 二期接回服务端时只要让 `apiBase` 返回一个值即可，调用方一行不用改。
///
/// 取值优先级：UserDefaults `hosted.apiBase`（本地联调） > Info.plist `TypetodoHostedAPIBase`（构建注入）。
/// 两者都没有 → 关闭。
public enum HostedAvailability {
    /// 构建期注入用的 Info.plist 键（由 `build.sh` 从不入库的 `local.build.env` 写入）。
    public static let infoPlistKey = "TypetodoHostedAPIBase"
    /// 本地联调用的 UserDefaults 覆盖键。
    public static let defaultsKey = "hosted.apiBase"

    /// 自签证书指纹（二期部署时注入，用于固定证书）。没有则走系统信任链。
    public static let certInfoPlistKey = "TypetodoHostedCertSHA256"

    /// 当前构建的托管服务器地址；`nil` = 没有托管通道。
    public static var apiBase: String? {
        resolve(defaultsValue: UserDefaults.standard.string(forKey: defaultsKey),
                plistValue: Bundle.main.object(forInfoDictionaryKey: infoPlistKey) as? String)
    }

    /// 自签证书的 SHA-256 指纹（大写十六进制，冒号可省）。
    public static var certSHA256: String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: certInfoPlistKey) as? String else { return nil }
        let v = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return (v.isEmpty || v.hasPrefix("$(")) ? nil : v
    }

    /// 是否具备托管通道（试用或会员任一可用）。
    public static var isEnabled: Bool { apiBase != nil }

    /// 纯函数，便于测试：把「UserDefaults 覆盖」与「Info.plist 注入」归一到最终地址。
    ///
    /// - 空白串、以及 Xcode 未展开的 `$(VAR)` 占位符一律视为没有配置
    ///   （构建时变量没定义时 Xcode 会把字面量原样留在 plist 里）。
    public static func resolve(defaultsValue: String?, plistValue: String?) -> String? {
        for raw in [defaultsValue, plistValue] {
            guard let v = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty else { continue }
            if v.hasPrefix("$(") { continue }
            return v
        }
        return nil
    }
}
