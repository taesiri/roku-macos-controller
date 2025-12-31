import AppKit
import SwiftUI

struct RokuMenuView: View {
    @ObservedObject var viewModel: RokuViewModel
    @State private var textToType = ""
    @State private var isVisible = false

    private let theme = RokuTheme()
    private let grid = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        ZStack {
            background
            VStack(alignment: .leading, spacing: 14) {
                header
                deviceRow
                actionsGrid
                appsRow
                navigationPad
                typingRow
                statusRow
            }
            .padding(16)
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1.0 : 0.98)
        }
        .frame(width: 360)
        .onAppear {
            withAnimation(.easeOut(duration: 0.18)) {
                isVisible = true
            }
        }
        .onDisappear {
            isVisible = false
        }
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(LinearGradient(
                colors: [theme.canvasTop, theme.canvasBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 8)
            .padding(6)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Roku Control")
                    .font(.custom("Avenir Next Demi Bold", size: 16))
                    .foregroundStyle(theme.ink)
                Text("Menu bar remote")
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(theme.subtle)
            }
            Spacer()
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(theme.subtle)
                    .frame(width: 24, height: 24)
                    .background(theme.card)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var deviceRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "wifi")
                    .foregroundStyle(theme.accent)
                TextField("Roku IP", text: $viewModel.hostInput)
                    .textFieldStyle(.plain)
                    .font(.custom("Avenir Next", size: 12))
            }
            .padding(8)
            .background(theme.field)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Button("Use") { viewModel.applyHostInput() }
                .buttonStyle(RokuPrimaryButtonStyle(theme: theme))

            Button {
                viewModel.discover()
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .buttonStyle(RokuIconButtonStyle(theme: theme))

            Button {
                viewModel.refreshApps()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(RokuIconButtonStyle(theme: theme))
        }
    }

    private var actionsGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Actions")
            LazyVGrid(columns: grid, spacing: 10) {
                ActionButton(title: "Power", systemImage: "power", style: .danger, theme: theme) {
                    viewModel.keypress("Power")
                }
                ActionButton(title: "Home", systemImage: "house.fill", style: .secondary, theme: theme) {
                    viewModel.keypress("Home")
                }
                ActionButton(title: "Back", systemImage: "arrow.uturn.left", style: .ghost, theme: theme) {
                    viewModel.keypress("Back")
                }
                ActionButton(title: "Play", systemImage: "playpause.fill", style: .primary, theme: theme) {
                    viewModel.keypress("Play")
                }
                ActionButton(title: "Vol-", systemImage: "speaker.wave.1.fill", style: .ghost, theme: theme) {
                    viewModel.keypress("VolumeDown")
                }
                ActionButton(title: "Vol+", systemImage: "speaker.wave.3.fill", style: .ghost, theme: theme) {
                    viewModel.keypress("VolumeUp")
                }
                ActionButton(title: "Mute", systemImage: "speaker.slash.fill", style: .secondary, theme: theme) {
                    viewModel.keypress("VolumeMute")
                }
                ActionButton(title: "Rev", systemImage: "backward.fill", style: .ghost, theme: theme) {
                    viewModel.keypress("Rev")
                }
                ActionButton(title: "Fwd", systemImage: "forward.fill", style: .ghost, theme: theme) {
                    viewModel.keypress("Fwd")
                }
            }
        }
        .padding(12)
        .background(theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }

    private var appsRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Apps")
            HStack(spacing: 10) {
                Button {
                    viewModel.launchApp(named: "Netflix", fallbackId: "12")
                } label: {
                    Label("Netflix", systemImage: "film")
                }
                .buttonStyle(RokuPrimaryButtonStyle(theme: theme))

                Button {
                    viewModel.launchApp(named: "YouTube", fallbackId: "837")
                } label: {
                    Label("YouTube", systemImage: "play.rectangle.fill")
                }
                .buttonStyle(RokuSecondaryButtonStyle(theme: theme))
            }
        }
        .padding(12)
        .background(theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }

    private var navigationPad: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Navigation")
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(theme.field)
                VStack(spacing: 10) {
                    Button { viewModel.keypress("Up") } label: {
                        Image(systemName: "chevron.up")
                    }
                    .buttonStyle(RokuDPadButtonStyle(theme: theme))

                    HStack(spacing: 12) {
                        Button { viewModel.keypress("Left") } label: {
                            Image(systemName: "chevron.left")
                        }
                        .buttonStyle(RokuDPadButtonStyle(theme: theme))

                        Button { viewModel.keypress("Select") } label: {
                            Text("OK")
                                .font(.custom("Avenir Next Demi Bold", size: 12))
                        }
                        .buttonStyle(RokuDPadPrimaryButtonStyle(theme: theme))

                        Button { viewModel.keypress("Right") } label: {
                            Image(systemName: "chevron.right")
                        }
                        .buttonStyle(RokuDPadButtonStyle(theme: theme))
                    }

                    Button { viewModel.keypress("Down") } label: {
                        Image(systemName: "chevron.down")
                    }
                    .buttonStyle(RokuDPadButtonStyle(theme: theme))
                }
                .padding(.vertical, 10)
            }
            .frame(height: 150)
        }
    }

    private var typingRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Type")
            HStack(spacing: 8) {
                TextField("Text", text: $textToType)
                    .textFieldStyle(.plain)
                    .font(.custom("Avenir Next", size: 12))
                    .padding(8)
                    .background(theme.field)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Button("Send") {
                    let value = textToType
                    textToType = ""
                    viewModel.typeText(value)
                }
                .buttonStyle(RokuPrimaryButtonStyle(theme: theme))
            }
        }
    }

    private var statusRow: some View {
        HStack {
            Image(systemName: "dot.radiowaves.left.and.right")
                .foregroundStyle(theme.accent)
            Text(viewModel.status)
                .font(.custom("Avenir Next", size: 11))
                .foregroundStyle(theme.subtle)
                .lineLimit(1)
            Spacer()
        }
        .padding(8)
        .background(theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.custom("Avenir Next Demi Bold", size: 12))
            .foregroundStyle(theme.subtle)
    }
}

struct RokuTheme {
    let canvasTop = Color(red: 0.96, green: 0.96, blue: 0.98)
    let canvasBottom = Color(red: 0.92, green: 0.94, blue: 0.97)
    let card = Color(red: 0.99, green: 0.99, blue: 0.98)
    let field = Color(red: 0.94, green: 0.95, blue: 0.97)
    let ink = Color(red: 0.15, green: 0.17, blue: 0.20)
    let subtle = Color(red: 0.44, green: 0.47, blue: 0.52)
    let accent = Color(red: 0.16, green: 0.52, blue: 0.60)
    let danger = Color(red: 0.82, green: 0.29, blue: 0.25)
}

enum RokuActionStyle {
    case primary
    case secondary
    case ghost
    case danger
}

struct ActionButton: View {
    let title: String
    let systemImage: String
    let style: RokuActionStyle
    let theme: RokuTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(title)
                    .font(.custom("Avenir Next Demi Bold", size: 11))
            }
            .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(RokuActionButtonStyle(theme: theme, style: style))
    }
}

struct RokuActionButtonStyle: ButtonStyle {
    let theme: RokuTheme
    let style: RokuActionStyle

    func makeBody(configuration: Configuration) -> some View {
        switch style {
        case .primary:
            RokuPrimaryButtonStyle(theme: theme).makeBody(configuration: configuration)
        case .secondary:
            RokuSecondaryButtonStyle(theme: theme).makeBody(configuration: configuration)
        case .ghost:
            RokuGhostButtonStyle(theme: theme).makeBody(configuration: configuration)
        case .danger:
            RokuDangerButtonStyle(theme: theme).makeBody(configuration: configuration)
        }
    }
}

struct RokuPrimaryButtonStyle: ButtonStyle {
    let theme: RokuTheme
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("Avenir Next Demi Bold", size: 12))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(theme.accent)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct RokuSecondaryButtonStyle: ButtonStyle {
    let theme: RokuTheme
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("Avenir Next Demi Bold", size: 12))
            .foregroundStyle(theme.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(theme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(theme.accent.opacity(0.25), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct RokuGhostButtonStyle: ButtonStyle {
    let theme: RokuTheme
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("Avenir Next", size: 12))
            .foregroundStyle(theme.subtle)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(theme.card.opacity(0.8))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct RokuDangerButtonStyle: ButtonStyle {
    let theme: RokuTheme
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("Avenir Next Demi Bold", size: 12))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(theme.danger)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct RokuIconButtonStyle: ButtonStyle {
    let theme: RokuTheme
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(theme.ink)
            .frame(width: 30, height: 30)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(theme.card)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct RokuDPadButtonStyle: ButtonStyle {
    let theme: RokuTheme
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(theme.ink)
            .frame(width: 44, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(theme.card)
                    .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct RokuDPadPrimaryButtonStyle: ButtonStyle {
    let theme: RokuTheme
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.white)
            .frame(width: 56, height: 36)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(theme.accent)
                    .shadow(color: theme.accent.opacity(0.35), radius: 8, x: 0, y: 4)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
