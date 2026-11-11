import SwiftUI
import AppKit

/// Dedicated About window for Hoist.
public struct AboutView: View {
    var onClose: () -> Void
    @ObservedObject private var updateChecker = UpdateChecker.shared
    @State private var showQuitConfirmation: Bool = false

    public init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 16) {
            // Icon in soft accent container
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 76, height: 76)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.accentColor.opacity(0.25), lineWidth: 1)
                    )

                if let icon = NSImage(named: "Hoist") ?? NSApp.applicationIconImage {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    Text("🚩")
                        .font(.system(size: 40))
                }
            }
            .shadow(color: Color.accentColor.opacity(0.16), radius: 8, x: 0, y: 3)
            .padding(.top, 4)

            // Title & Version
            VStack(spacing: 4) {
                Text("Hoist")
                    .font(.system(size: 22, weight: .bold))

                HStack(spacing: 8) {
                    Text("Version \(updateChecker.currentVersion)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)

                    Text("•")
                        .foregroundStyle(.secondary.opacity(0.5))

                    Button(action: {
                        updateChecker.checkForUpdates(explicit: true)
                    }) {
                        HStack(spacing: 3) {
                            if updateChecker.isChecking {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 10, height: 10)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            Text("Check for Updates")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .disabled(updateChecker.isChecking)
                    .onHover { inside in
                        if inside {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                }
            }

            // Creator attribution
            VStack(spacing: 5) {
                Text("Created by")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                Text("Anshul Garg")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.primary)

                Button(action: {
                    if let url = URL(string: "http://anshulgarg.in/") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "globe")
                            .font(.system(size: 11))
                        Text("anshulgarg.in")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.12))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .onHover { inside in
                    if inside {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
            .padding(.vertical, 4)

            Divider()

            // Feature Highlights
            VStack(spacing: 5) {
                Text("Menu Bar Country Flag & Clock")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("110+ Flags  •  Local Time  •  Custom Status")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Close button
            Button(action: onClose) {
                Text("Close")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 88, height: 28)
                    .background(Color.accentColor)
                    .cornerRadius(7)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)
            .onHover { inside in
                if inside {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 6)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(width: 340)
        .alert("Quit Hoist?", isPresented: $showQuitConfirmation) {
            Button("Quit Hoist", role: .destructive) {
                NSApp.terminate(nil)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The menu-bar flag will be removed until you relaunch Hoist.")
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("HoistRequestQuitConfirmation"))) { _ in
            showQuitConfirmation = true
        }
    }
}
