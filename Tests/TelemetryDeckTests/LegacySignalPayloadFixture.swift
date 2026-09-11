import Foundation

@testable import TelemetryDeck

// Frozen 2.14.2 payload builder (58f436299d3f6710bcedc18aff26480aaf1879fc).
// This independent oracle guards all legacy/current keys and values when changing execution ownership.
// Do not refactor it to use the new split metadata helpers.
extension DefaultSignalPayload {
    @MainActor
    static var legacyParameters: [String: String] {
        var parameters: [String: String] = [
            // deprecated names
            "platform": Self.platform,
            "systemVersion": Self.systemVersion,
            "majorSystemVersion": Self.majorSystemVersion,
            "majorMinorSystemVersion": Self.majorMinorSystemVersion,
            "appVersion": Self.appVersion,
            "buildNumber": Self.buildNumber,
            "isSimulator": "\(Self.isSimulator)",
            "isDebug": "\(Self.isDebug)",
            "isTestFlight": "\(Self.isTestFlight)",
            "isAppStore": "\(Self.isAppStore)",
            "modelName": Self.modelName,
            "architecture": Self.architecture,
            "operatingSystem": Self.operatingSystem,
            "targetEnvironment": Self.targetEnvironment,
            "locale": Self.locale,
            "region": Self.region,
            "appLanguage": Self.appLanguage,
            "preferredLanguage": Self.preferredLanguage,
            "telemetryClientVersion": sdkVersion,

            // new names
            "TelemetryDeck.AppInfo.buildNumber": Self.buildNumber,
            "TelemetryDeck.AppInfo.version": Self.appVersion,
            "TelemetryDeck.AppInfo.versionAndBuildNumber": "\(Self.appVersion) (build \(Self.buildNumber))",

            "TelemetryDeck.Device.architecture": Self.architecture,
            "TelemetryDeck.Device.modelName": Self.modelName,
            "TelemetryDeck.Device.operatingSystem": Self.operatingSystem,
            "TelemetryDeck.Device.orientation": Self.orientation,
            "TelemetryDeck.Device.platform": Self.platform,
            "TelemetryDeck.Device.screenResolutionHeight": Self.screenResolutionHeight,
            "TelemetryDeck.Device.screenResolutionWidth": Self.screenResolutionWidth,
            "TelemetryDeck.Device.screenScaleFactor": Self.screenScaleFactor,
            "TelemetryDeck.Device.systemMajorMinorVersion": Self.majorMinorSystemVersion,
            "TelemetryDeck.Device.systemMajorVersion": Self.majorSystemVersion,
            "TelemetryDeck.Device.systemVersion": Self.systemVersion,
            "TelemetryDeck.Device.timeZone": Self.timeZone,

            "TelemetryDeck.RunContext.isAppStore": "\(Self.isAppStore)",
            "TelemetryDeck.RunContext.isDebug": "\(Self.isDebug)",
            "TelemetryDeck.RunContext.isSimulator": "\(Self.isSimulator)",
            "TelemetryDeck.RunContext.isTestFlight": "\(Self.isTestFlight)",
            "TelemetryDeck.RunContext.language": Self.appLanguage,
            "TelemetryDeck.RunContext.locale": Self.locale,
            "TelemetryDeck.RunContext.targetEnvironment": Self.targetEnvironment,

            "TelemetryDeck.SDK.name": "SwiftSDK",
            "TelemetryDeck.SDK.nameAndVersion": "SwiftSDK \(sdkVersion)",
            "TelemetryDeck.SDK.version": sdkVersion,

            "TelemetryDeck.UserPreference.colorScheme": Self.colorScheme,
            "TelemetryDeck.UserPreference.language": Self.preferredLanguage,
            "TelemetryDeck.UserPreference.layoutDirection": Self.layoutDirection,
            "TelemetryDeck.UserPreference.region": Self.region,
        ]

        parameters.merge(self.accessibilityParameters, uniquingKeysWith: { $1 })
        parameters.merge(self.calendarParameters, uniquingKeysWith: { $1 })

        if let extensionIdentifier = Self.extensionIdentifier {
            // deprecated name
            parameters["extensionIdentifier"] = extensionIdentifier

            // new name
            parameters["TelemetryDeck.RunContext.extensionIdentifier"] = extensionIdentifier
        }

        // Pirate Metrics
        if #available(watchOS 7, *) {
            parameters.merge(
                [
                    "TelemetryDeck.Acquisition.firstSessionDate": SessionManager.shared.firstSessionDate,
                    "TelemetryDeck.Retention.averageSessionSeconds": "\(SessionManager.shared.averageSessionSeconds)",
                    "TelemetryDeck.Retention.distinctDaysUsed": "\(SessionManager.shared.distinctDaysUsed.count)",
                    "TelemetryDeck.Retention.distinctDaysUsedLastMonth": "\(SessionManager.shared.distinctDaysUsedLastMonthCount)",
                    "TelemetryDeck.Retention.totalSessionsCount": "\(SessionManager.shared.totalSessionsCount)",
                ],
                uniquingKeysWith: { $1 }
            )

            if let previousSessionSeconds = SessionManager.shared.previousSessionSeconds {
                parameters["TelemetryDeck.Retention.previousSessionSeconds"] = "\(previousSessionSeconds)"
            }
        }

        return parameters
    }
}
