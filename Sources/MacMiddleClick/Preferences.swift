import Foundation

enum Preferences {
    private static let defaults = UserDefaults.standard

    static func registerDefaults() {
        defaults.register(defaults: ["enabled": true, "fingers": 3, "tapEnabled": true, "clickEnabled": true])
    }

    static var enabled: Bool {
        get { defaults.bool(forKey: "enabled") }
        set { defaults.set(newValue, forKey: "enabled") }
    }

    /// How many fingers make a middle click: 3 or 4.
    static var fingers: Int {
        get { min(max(defaults.integer(forKey: "fingers"), 3), 4) }
        set { defaults.set(newValue, forKey: "fingers") }
    }

    /// Whether a quick tap with `fingers` fingers makes a middle click.
    static var tapEnabled: Bool {
        get { defaults.bool(forKey: "tapEnabled") }
        set { defaults.set(newValue, forKey: "tapEnabled") }
    }

    /// Whether pressing the trackpad with `fingers` fingers makes a middle click.
    static var clickEnabled: Bool {
        get { defaults.bool(forKey: "clickEnabled") }
        set { defaults.set(newValue, forKey: "clickEnabled") }
    }
}
