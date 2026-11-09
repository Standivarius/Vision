import AppKit
import SwiftUI

// Standivarius Doxa Setup is a guided companion, not a display driver.
// No elevated privileges, third-party app redistribution or background service.
private enum DoxaStyle {
    static let burgundy = Color(red: 0.61, green: 0.07, blue: 0.19)
    static let ink = Color(red: 0.15, green: 0.13, blue: 0.17)
    static let muted = Color(red: 0.39, green: 0.38, blue: 0.42)
    static let cream = Color(red: 0.976, green: 0.969, blue: 0.957)
    static let sidebar = Color(red: 0.15, green: 0.12, blue: 0.17)
    static let line = Color(red: 0.89, green: 0.87, blue: 0.86)
}

private enum SetupStep: Int, CaseIterable, Identifiable {
    case connect, instantView, displays
    var id: Int { rawValue }
    var number: String { "\(rawValue + 1)" }
    var label: String {
        switch self {
        case .connect: return "Connect Doxa"
        case .instantView: return "Install InstantView"
        case .displays: return "Set up screens"
        }
    }
    var subtitle: String {
        switch self {
        case .connect: return "Power and USB-C data"
        case .instantView: return "Official display software"
        case .displays: return "Permissions and arrangement"
        }
    }
    var symbol: String {
        switch self {
        case .connect: return "cable.connector"
        case .instantView: return "square.and.arrow.down"
        case .displays: return "display.2"
        }
    }
}

private enum DoxaAction {
    static let vendorDownload = URL(string: "https://www.siliconmotion.com/downloads/SM770-drivers.html")!
    static let screenRecording = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
    static let displays = URL(string: "x-apple.systempreferences:com.apple.Displays-Settings.extension")!

    static func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
    static func openApplications() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications", isDirectory: true))
    }
}

private struct DiagnosticSnapshot {
    let instantViewPath: URL?
    let instantViewRunning: Bool
    let visibleMacScreens: Int
    let macVersion: String
    let instantViewVersion: String?

    static func scan() -> Self {
        let apps = [
            "/Applications/macOS InstantView.app",
            "/Applications/InstantView.app",
            "/Applications/SMI InstantView.app"
        ]
        let knownApp = apps.first(where: { FileManager.default.fileExists(atPath: $0) })
        let path = knownApp.map { URL(fileURLWithPath: $0, isDirectory: true) }
        let running = NSWorkspace.shared.runningApplications.contains { application in
            let name = (application.localizedName ?? "").lowercased()
            return name.contains("instantview")
        }
        let info = path.flatMap { Bundle(url: $0)?.infoDictionary }
        return Self(
            instantViewPath: path,
            instantViewRunning: running,
            visibleMacScreens: NSScreen.screens.count,
            macVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            instantViewVersion: info?["CFBundleShortVersionString"] as? String
        )
    }
}

private struct SetupCard<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.system(size: 17, weight: .semibold)).foregroundStyle(DoxaStyle.ink)
            content
        }
        .padding(23)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(DoxaStyle.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 15))
    }
}

private struct InstructionRow: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(DoxaStyle.burgundy)
                .frame(width: 23)
            Text(text)
                .foregroundStyle(DoxaStyle.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 13))
    }
}

private struct DiagnosticRow: View {
    let title: String
    let detail: String
    let status: Bool?
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: status == nil ? "info.circle" : (status! ? "checkmark.circle.fill" : "minus.circle"))
                .foregroundStyle(status == true ? Color.green : DoxaStyle.muted)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(detail).font(.system(size: 12)).foregroundStyle(DoxaStyle.muted)
            }
            Spacer()
        }
    }
}

private struct SetupView: View {
    @State private var step: SetupStep = .connect
    @State private var snapshot = DiagnosticSnapshot.scan()
    @State private var recordingAcknowledged = false
    @State private var cableAcknowledged = false
    @State private var showHelp = false

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            VStack(alignment: .leading, spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        pageHeading
                        switch step {
                        case .connect: connectionPage
                        case .instantView: instantViewPage
                        case .displays: displaysPage
                        }
                        footer
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 26)
                    .frame(maxWidth: 800, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(DoxaStyle.cream)
        }
        .frame(minWidth: 925, minHeight: 640)
        .foregroundStyle(DoxaStyle.ink)
        .sheet(isPresented: $showHelp) { helpSheet }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("STANDIVARIUS")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(3.2)
                .foregroundStyle(Color.white.opacity(0.8))
                .padding(.bottom, 6)
            Text("DOXA")
                .font(.system(size: 34, weight: .light, design: .rounded))
                .tracking(4)
                .foregroundStyle(.white)
            Text("SETUP FOR MAC")
                .font(.system(size: 10, weight: .medium))
                .tracking(2.0)
                .foregroundStyle(Color.white.opacity(0.55))
                .padding(.top, 3)
                .padding(.bottom, 42)

            ForEach(SetupStep.allCases) { entry in
                Button { step = entry } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Text(entry.number)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .frame(width: 26, height: 26)
                            .background(step == entry ? Color.white.opacity(0.22) : Color.white.opacity(0.09))
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.label).font(.system(size: 13, weight: .semibold))
                            Text(entry.subtitle)
                                .font(.system(size: 11))
                                .foregroundStyle(Color.white.opacity(0.55))
                        }
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(step == entry ? DoxaStyle.burgundy : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Step \(entry.number): \(entry.label)")
                .padding(.bottom, 7)
            }
            Spacer()
            Button { showHelp = true } label: {
                Label("Offline help", systemImage: "questionmark.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.84))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 18)
            Text("v0.1.0 · Guided installation")
                .font(.system(size: 10))
                .foregroundStyle(Color.white.opacity(0.5))
        }
        .padding(24)
        .frame(width: 255)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(DoxaStyle.sidebar)
    }

    private var header: some View {
        HStack {
            Text("Doxa installation")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DoxaStyle.muted)
            Spacer()
            Button {
                snapshot = DiagnosticSnapshot.scan()
            } label: { Label("Refresh checks", systemImage: "arrow.clockwise") }
                .controlSize(.small)
                .buttonStyle(.bordered)
                .help("Read-only status: does not install drivers or change settings.")
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 19)
        .background(.white)
    }

    private var pageHeading: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("STEP \(step.number) OF 3")
                .font(.system(size: 11, weight: .bold))
                .tracking(2)
                .foregroundStyle(DoxaStyle.burgundy)
            Text(step.label)
                .font(.system(size: 31, weight: .semibold, design: .rounded))
            Text(step.subtitle)
                .font(.system(size: 14))
                .foregroundStyle(DoxaStyle.muted)
        }
        .padding(.bottom, 4)
    }

    private var connectionPage: some View {
        VStack(alignment: .leading, spacing: 17) {
            SetupCard("Connect Doxa to your Mac") {
                InstructionRow(icon: "bolt", text: "Connect Doxa to a suitable power source, if your model requires external power.")
                InstructionRow(icon: "cable.connector", text: "Connect the USB-C data cable between Doxa and your Mac. Check that you are using the data port, not only the power port.")
                InstructionRow(icon: "laptopcomputer", text: "Keep Doxa connected while installing the display software.")
                Toggle("Doxa power and USB-C data are connected", isOn: $cableAcknowledged)
                    .toggleStyle(.checkbox)
                    .padding(.top, 6)
            }
            SetupCard("What to expect") {
                Text("A USB cable alone does not prove the Doxa displays are active. macOS needs Silicon Motion InstantView to create the additional display surfaces.")
                    .font(.system(size: 13))
                    .foregroundStyle(DoxaStyle.muted)
            }
            Button("Next: Install InstantView") { step = .instantView }
                .buttonStyle(.borderedProminent)
                .tint(DoxaStyle.burgundy)
            // Connection acknowledgement is advisory: never block access to instructions.
        }
    }

    private var instantViewPage: some View {
        VStack(alignment: .leading, spacing: 17) {
            SetupCard("Install Silicon Motion InstantView") {
                Text("InstantView is the official SM770 display application. Standivarius does not bundle, silently download or modify it.")
                    .font(.system(size: 13))
                Button { DoxaAction.open(DoxaAction.vendorDownload) } label: {
                    Label("Open official InstantView download", systemImage: "arrow.up.right.square")
                }
                .buttonStyle(.borderedProminent)
                .tint(DoxaStyle.burgundy)
                Text("On the manufacturer's page, choose the current macOS InstantView release for SM77x. Install it using Silicon Motion's own instructions.")
                    .font(.system(size: 12))
                    .foregroundStyle(DoxaStyle.muted)
            }
            SetupCard("InstantView status on this Mac") {
                DiagnosticRow(
                    title: snapshot.instantViewPath == nil ? "Installation not confirmed" : "InstantView found",
                    detail: snapshot.instantViewPath == nil ?
                        "The application was not found in common Applications locations. It may be installed elsewhere." :
                        (snapshot.instantViewVersion.map { "Installed version \($0)." } ?? "Application found in Applications."),
                    status: snapshot.instantViewPath == nil ? nil : true
                )
                DiagnosticRow(
                    title: snapshot.instantViewRunning ? "InstantView is running" : "InstantView not currently detected as running",
                    detail: "This checks the application process name only; it does not verify display operation.",
                    status: snapshot.instantViewRunning ? true : nil
                )
                HStack(spacing: 10) {
                    if let url = snapshot.instantViewPath {
                        Button("Open InstantView") { launchInstantView(url) }.buttonStyle(.bordered)
                    } else {
                        Button("Open Applications folder") { DoxaAction.openApplications() }.buttonStyle(.bordered)
                    }
                    Button("Recheck") { snapshot = DiagnosticSnapshot.scan() }.buttonStyle(.bordered)
                }
            }
            Button("Next: Set up screens") { step = .displays }
                .buttonStyle(.borderedProminent)
                .tint(DoxaStyle.burgundy)
        }
    }

    private var displaysPage: some View {
        VStack(alignment: .leading, spacing: 17) {
            SetupCard("Give InstantView permission") {
                Text("InstantView needs Screen & System Audio Recording permission to render the content shown on USB displays. Standivarius Doxa Setup does not request or receive this permission.")
                    .font(.system(size: 13))
                Button { DoxaAction.open(DoxaAction.screenRecording) } label: {
                    Label("Open macOS screen recording settings", systemImage: "hand.raised")
                }
                .buttonStyle(.bordered)
                InstructionRow(icon: "lock.shield", text: "Find InstantView in Privacy & Security, enable the permission yourself, then quit and reopen InstantView when macOS asks.")
                Toggle("I enabled the permission for InstantView", isOn: $recordingAcknowledged)
                    .toggleStyle(.checkbox)
                Text("This is your acknowledgement, not an automatic permission check.")
                    .font(.system(size: 11))
                    .foregroundStyle(DoxaStyle.muted)
            }
            SetupCard("Arrange your displays") {
                HStack(spacing: 18) {
                    ForEach(1...4, id: \.self) { index in
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(index == 1 ? DoxaStyle.ink : DoxaStyle.burgundy.opacity(0.75))
                                .frame(width: index == 1 ? 84 : 65, height: index == 1 ? 53 : 44)
                                .overlay(Image(systemName: "desktopcomputer").font(.system(size: 16)).foregroundStyle(.white))
                            Text(index == 1 ? "Mac" : "Doxa \(index-1)")
                                .font(.system(size: 11, weight: .medium))
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                Text("Illustrative arrangement only. Real display numbering depends on macOS.")
                    .font(.system(size: 11))
                    .foregroundStyle(DoxaStyle.muted)
                Button { DoxaAction.open(DoxaAction.displays) } label: {
                    Label("Open macOS Displays settings", systemImage: "display.2")
                }
                .buttonStyle(.borderedProminent)
                .tint(DoxaStyle.burgundy)
                Text("In Displays, select Extend rather than Mirror, and arrange the screens to match their physical positions.")
                    .font(.system(size: 12))
                    .foregroundStyle(DoxaStyle.muted)
            }
            SetupCard("Read-only system check") {
                DiagnosticRow(
                    title: "\(snapshot.visibleMacScreens) active screen(s) reported by macOS",
                    detail: "This includes the Mac's own display and any unrelated monitors. It does not identify three Doxa panels.",
                    status: nil
                )
                DiagnosticRow(
                    title: snapshot.instantViewRunning ? "InstantView running" : "InstantView process not detected",
                    detail: "Screen Recording permission and Extended mode must be checked in macOS settings.",
                    status: snapshot.instantViewRunning ? true : nil
                )
                Button("Refresh display check") { snapshot = DiagnosticSnapshot.scan() }
                    .buttonStyle(.bordered)
            }
        }
    }

    private var footer: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle").foregroundStyle(DoxaStyle.muted)
            Text("This assistant never installs a driver or grants macOS privacy permissions. Display verification requires checking the actual screens.")
                .foregroundStyle(DoxaStyle.muted)
        }
        .font(.system(size: 11))
        .padding(.top, 4)
    }

    private var helpSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Doxa help for Mac").font(.system(size: 22, weight: .semibold))
            Text("If the Doxa screens are blank:")
                .font(.system(size: 14, weight: .semibold))
            InstructionRow(icon: "1.circle", text: "Check Doxa power and the USB-C data connection.")
            InstructionRow(icon: "2.circle", text: "Install or update InstantView from Silicon Motion's official page.")
            InstructionRow(icon: "3.circle", text: "Confirm InstantView's Screen Recording permission, and reopen it when asked.")
            InstructionRow(icon: "4.circle", text: "Open Displays to check Extend mode and screen arrangement.")
            Text("Online AI Help for Mac has not yet been validated. No diagnostics, screenshots or personal data are transmitted by this setup companion.")
                .font(.system(size: 12))
                .foregroundStyle(DoxaStyle.muted)
            HStack {
                Button("Official InstantView page") { DoxaAction.open(DoxaAction.vendorDownload) }
                Spacer()
                Button("Close") { showHelp = false }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(30)
        .frame(width: 540)
    }

    private func launchInstantView(_ url: URL) {
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
            if let error = error {
                NSLog("InstantView launch failed: %@", error.localizedDescription)
            }
            DispatchQueue.main.async {
                snapshot = DiagnosticSnapshot.scan()
            }
        }
    }
}

@main
struct StandivariusDoxaSetupApp: App {
    var body: some Scene {
        WindowGroup("Standivarius Doxa Setup") {
            SetupView()
        }
        .windowResizability(.contentSize)
    }
}
