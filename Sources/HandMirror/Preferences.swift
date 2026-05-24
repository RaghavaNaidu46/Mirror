import Foundation
import SwiftUI
import Combine

/// UserDefaults-backed preferences. Uses `@Published` properties so SwiftUI views
/// holding an `@ObservedObject` reference can use the `$preferences.foo` projected
/// bindings directly. Each setter persists to UserDefaults in `didSet`.
final class Preferences: ObservableObject {
    static let shared = Preferences()
    private let defaults = UserDefaults.standard

    // MARK: - Stored

    @Published var selectedCameraID: String      { didSet { defaults.set(selectedCameraID, forKey: K.selectedCameraID) } }
    @Published var mirrorHorizontally: Bool      { didSet { defaults.set(mirrorHorizontally, forKey: K.mirrorHorizontally) } }
    @Published var windowShape: String           { didSet { defaults.set(windowShape, forKey: K.windowShape) } }
    @Published var windowSize: Double            { didSet { defaults.set(windowSize, forKey: K.windowSize) } }
    @Published var alwaysOnTop: Bool             { didSet { defaults.set(alwaysOnTop, forKey: K.alwaysOnTop) } }
    @Published var openOnLaunch: Bool            { didSet { defaults.set(openOnLaunch, forKey: K.openOnLaunch) } }
    @Published var launchAtLogin: Bool           { didSet { defaults.set(launchAtLogin, forKey: K.launchAtLogin) } }
    @Published var onboardingComplete: Bool      { didSet { defaults.set(onboardingComplete, forKey: K.onboardingComplete) } }
    /// Flips to true the first time a non-Pro user tries the detached
    /// window. First trial is 30s; every subsequent attempt is 10s.
    @Published var detachTrialActivated: Bool    { didSet { defaults.set(detachTrialActivated, forKey: K.detachTrialActivated) } }

    @Published var menuBarIconName: String       { didSet { defaults.set(menuBarIconName, forKey: K.menuBarIconName) } }
    @Published var showInDock: Bool              { didSet { defaults.set(showInDock, forKey: K.showInDock) } }

    @Published var maskStyle: String             { didSet { defaults.set(maskStyle, forKey: K.maskStyle) } }
    @Published var maskZoom: Double              { didSet { defaults.set(maskZoom, forKey: K.maskZoom) } }
    @Published var maskRotation: Double          { didSet { defaults.set(maskRotation, forKey: K.maskRotation) } }

    @Published var snapsEnabled: Bool            { didSet { defaults.set(snapsEnabled, forKey: K.snapsEnabled) } }
    @Published var snapsIncludeFrame: Bool       { didSet { defaults.set(snapsIncludeFrame, forKey: K.snapsIncludeFrame) } }
    @Published var snapsIncludeDate: Bool        { didSet { defaults.set(snapsIncludeDate, forKey: K.snapsIncludeDate) } }
    @Published var snapsAutoSave: Bool           { didSet { defaults.set(snapsAutoSave, forKey: K.snapsAutoSave) } }
    @Published var snapsSaveLocation: String     { didSet { defaults.set(snapsSaveLocation, forKey: K.snapsSaveLocation) } }
    @Published var snapsFreeRemaining: Int       { didSet { defaults.set(snapsFreeRemaining, forKey: K.snapsFreeRemaining) } }

    @Published var micCheckEnabled: Bool         { didSet { defaults.set(micCheckEnabled, forKey: K.micCheckEnabled) } }
    @Published var micCheckShowOnHover: Bool     { didSet { defaults.set(micCheckShowOnHover, forKey: K.micCheckShowOnHover) } }

    @Published var notchTriggerEnabled: Bool     { didSet { defaults.set(notchTriggerEnabled, forKey: K.notchTriggerEnabled) } }
    @Published var hideMenuBarIconOnNotch: Bool  { didSet { defaults.set(hideMenuBarIconOnNotch, forKey: K.hideMenuBarIconOnNotch) } }

    @Published var reactionsTriggersVisible: Bool { didSet { defaults.set(reactionsTriggersVisible, forKey: K.reactionsTriggersVisible) } }

    @Published var smartWindowEnabled: Bool      { didSet { defaults.set(smartWindowEnabled, forKey: K.smartWindowEnabled) } }

    @Published var centerStageEnabled: Bool      { didSet { defaults.set(centerStageEnabled, forKey: K.centerStageEnabled) } }

    // MARK: - Init

    private init() {
        // Register defaults once so first reads return our defaults, not zero/empty.
        defaults.register(defaults: [
            K.mirrorHorizontally: true,
            K.windowShape: WindowShape.circle.rawValue,
            K.windowSize: 220.0,
            K.alwaysOnTop: true,
            K.menuBarIconName: MenuBarIcon.defaultIcon.rawValue,
            K.maskStyle: MaskStyle.defaultChrome.rawValue,
            K.maskZoom: 1.0,
            K.maskRotation: 0.0,
            K.snapsIncludeFrame: true,
            K.snapsIncludeDate: true,
            K.snapsFreeRemaining: 5,
            K.centerStageEnabled: true,
        ])

        selectedCameraID = defaults.string(forKey: K.selectedCameraID) ?? ""
        mirrorHorizontally = defaults.bool(forKey: K.mirrorHorizontally)
        windowShape = defaults.string(forKey: K.windowShape) ?? WindowShape.circle.rawValue
        windowSize = defaults.double(forKey: K.windowSize)
        alwaysOnTop = defaults.bool(forKey: K.alwaysOnTop)
        openOnLaunch = defaults.bool(forKey: K.openOnLaunch)
        launchAtLogin = defaults.bool(forKey: K.launchAtLogin)
        onboardingComplete = defaults.bool(forKey: K.onboardingComplete)
        detachTrialActivated = defaults.bool(forKey: K.detachTrialActivated)

        menuBarIconName = defaults.string(forKey: K.menuBarIconName) ?? MenuBarIcon.defaultIcon.rawValue
        showInDock = defaults.bool(forKey: K.showInDock)

        maskStyle = defaults.string(forKey: K.maskStyle) ?? MaskStyle.defaultChrome.rawValue
        maskZoom = defaults.double(forKey: K.maskZoom)
        maskRotation = defaults.double(forKey: K.maskRotation)

        snapsEnabled = defaults.bool(forKey: K.snapsEnabled)
        snapsIncludeFrame = defaults.bool(forKey: K.snapsIncludeFrame)
        snapsIncludeDate = defaults.bool(forKey: K.snapsIncludeDate)
        snapsAutoSave = defaults.bool(forKey: K.snapsAutoSave)
        snapsSaveLocation = defaults.string(forKey: K.snapsSaveLocation) ?? ""
        snapsFreeRemaining = defaults.integer(forKey: K.snapsFreeRemaining)

        micCheckEnabled = defaults.bool(forKey: K.micCheckEnabled)
        micCheckShowOnHover = defaults.bool(forKey: K.micCheckShowOnHover)

        notchTriggerEnabled = defaults.bool(forKey: K.notchTriggerEnabled)
        hideMenuBarIconOnNotch = defaults.bool(forKey: K.hideMenuBarIconOnNotch)

        reactionsTriggersVisible = defaults.bool(forKey: K.reactionsTriggersVisible)
        smartWindowEnabled = defaults.bool(forKey: K.smartWindowEnabled)
        centerStageEnabled = defaults.bool(forKey: K.centerStageEnabled)
    }

    func resetOnboarding() { onboardingComplete = false }

    /// Mirror window dimensions, derived from `windowSize` and the active
    /// `maskStyle`. The Default mask is a horizontal rectangle; Square and
    /// Circle are 1:1. The caller uses this for both SwiftUI `.frame` and for
    /// sizing the popover / detached window.
    var currentMirrorSize: CGSize {
        let s = CGFloat(windowSize)
        switch MaskStyle(rawValue: maskStyle) ?? .defaultChrome {
        case .defaultChrome: return CGSize(width: s * 16.0 / 9.0, height: s)
        case .square, .circle: return CGSize(width: s, height: s)
        }
    }

    private enum K {
        static let selectedCameraID = "selectedCameraID"
        static let mirrorHorizontally = "mirrorHorizontally"
        static let windowShape = "windowShape"
        static let windowSize = "windowSize"
        static let alwaysOnTop = "alwaysOnTop"
        static let openOnLaunch = "openOnLaunch"
        static let launchAtLogin = "launchAtLogin"
        static let onboardingComplete = "onboardingComplete"
        static let detachTrialActivated = "detachTrialActivated"
        static let menuBarIconName = "menuBarIconName"
        static let showInDock = "showInDock"
        static let maskStyle = "maskStyle"
        static let maskZoom = "maskZoom"
        static let maskRotation = "maskRotation"
        static let snapsEnabled = "snapsEnabled"
        static let snapsIncludeFrame = "snapsIncludeFrame"
        static let snapsIncludeDate = "snapsIncludeDate"
        static let snapsAutoSave = "snapsAutoSave"
        static let snapsSaveLocation = "snapsSaveLocation"
        static let snapsFreeRemaining = "snapsFreeRemaining"
        static let micCheckEnabled = "micCheckEnabled"
        static let micCheckShowOnHover = "micCheckShowOnHover"
        static let notchTriggerEnabled = "notchTriggerEnabled"
        static let hideMenuBarIconOnNotch = "hideMenuBarIconOnNotch"
        static let reactionsTriggersVisible = "reactionsTriggersVisible"
        static let smartWindowEnabled = "smartWindowEnabled"
        static let centerStageEnabled = "centerStageEnabled"
    }
}

enum WindowShape: String, CaseIterable, Identifiable {
    case circle, roundedSquare, square, polaroid
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .circle:        return "Circle"
        case .roundedSquare: return "Rounded Square"
        case .square:        return "Square"
        case .polaroid:      return "Polaroid"
        }
    }
}

enum MaskStyle: String, CaseIterable, Identifiable {
    case defaultChrome, square, circle
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .defaultChrome: return "Default"
        case .square:        return "Square"
        case .circle:        return "Circle"
        }
    }
}

enum MenuBarIcon: String, CaseIterable, Identifiable {
    case defaultIcon, classic, lens, aperture, brioche, gem, lumen, oneEighty, iSee, continueIcon
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .defaultIcon:  return "Default"
        case .classic:      return "Classic"
        case .lens:         return "Lens"
        case .aperture:     return "Aperture"
        case .brioche:      return "Brioche"
        case .gem:          return "Gem"
        case .lumen:        return "Lumen"
        case .oneEighty:    return "180"
        case .iSee:         return "iSee"
        case .continueIcon: return "Continue"
        }
    }
    var symbolName: String {
        switch self {
        case .defaultIcon:  return "video.fill"
        case .classic:      return "video"
        case .lens:         return "circle.circle.fill"
        case .aperture:     return "camera.aperture"
        case .brioche:      return "oval.fill"
        case .gem:          return "diamond.fill"
        case .lumen:        return "capsule.fill"
        case .oneEighty:    return "video.bubble.left"
        case .iSee:         return "eye.fill"
        case .continueIcon: return "circle.grid.2x2.fill"
        }
    }
}

