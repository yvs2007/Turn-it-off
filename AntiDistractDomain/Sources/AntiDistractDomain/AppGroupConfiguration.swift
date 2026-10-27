import Foundation

/// Identifiers shared by the app and both extensions. Change `appGroupIdentifier` to match
/// the App Group you created in the Apple Developer portal, in exactly one place.
public enum AppGroupConfiguration {
    public static let appGroupIdentifier = "group.com.example.antidistract"

    /// Name of the `ManagedSettingsStore` the monitor extension writes shields into.
    /// The app uses the same name so it can clear shields if it ever needs to.
    public static let managedSettingsStoreName = "antidistract"

    /// Subsystem for `os.Logger` across all targets.
    public static let loggingSubsystem = "com.example.antidistract"
}
