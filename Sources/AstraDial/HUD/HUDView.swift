import AppKit
import SwiftUI

struct HUDView: View {
    @Bindable var state: HUDState

    var body: some View {
        ZStack {
            if state.isWheelOpen {
                WheelView(state: state)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
            } else if let toast = state.toast {
                ToastView(toast: toast)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .frame(width: WheelHUD.size.width, height: WheelHUD.size.height)
        .animation(.spring(duration: 0.22), value: state.isWheelOpen)
        .animation(.easeOut(duration: 0.18), value: state.toast == nil)
        .environment(\.colorScheme, .dark)
    }
}

private struct WheelView: View {
    let state: HUDState

    private let diameter: CGFloat = 300
    private let ringRadius: CGFloat = 108
    private let ringWidth: CGFloat = 64

    var body: some View {
        let count = state.modes.count
        let slice = 1.0 / Double(count)
        let highlighted = state.modes[state.highlighted]

        ZStack {
            HUDMaterial()
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.12), lineWidth: 1))

            // Highlight wedge, centred on the highlighted slot.
            Circle()
                .trim(from: 0, to: slice)
                .stroke(Color.accentColor.opacity(0.9), style: StrokeStyle(lineWidth: ringWidth, lineCap: .butt))
                .frame(width: ringRadius * 2, height: ringRadius * 2)
                .rotationEffect(.degrees(-90 + 360 * slice * (Double(state.cursor) - 0.5)))
                .animation(.snappy(duration: 0.16), value: state.cursor)

            ForEach(Array(state.modes.enumerated()), id: \.element) { index, mode in
                let angle = 2 * Double.pi * Double(index) / Double(count)
                let isHighlighted = index == state.highlighted
                ZStack(alignment: .topTrailing) {
                    Image(systemName: mode.symbol)
                        .font(.system(size: 21, weight: .semibold))
                        .frame(width: 40, height: 40)
                    if mode == state.activeMode {
                        Circle().fill(.white).frame(width: 6, height: 6).offset(x: 2, y: 2)
                    }
                }
                .foregroundStyle(isHighlighted ? Color.white : Color.white.opacity(0.65))
                .scaleEffect(isHighlighted ? 1.12 : 1)
                .offset(x: ringRadius * sin(angle), y: -ringRadius * cos(angle))
                .animation(.snappy(duration: 0.16), value: isHighlighted)
            }

            VStack(spacing: 3) {
                Text(highlighted.title)
                    .font(.system(size: 19, weight: .semibold))
                    .contentTransition(.opacity)
                Text(highlighted == state.activeMode ? "Current mode" : "Press to switch")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.white)
            .animation(.easeOut(duration: 0.12), value: state.highlighted)
        }
        .frame(width: diameter, height: diameter)
    }
}

private struct ToastView: View {
    let toast: HUDState.Toast

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: toast.mode.symbol)
                .font(.system(size: 34, weight: .semibold))
            if let level = toast.level {
                LevelBar(level: level)
                Text("\(level)%")
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            } else {
                Text(toast.mode.title)
                    .font(.system(size: 15, weight: .semibold))
            }
        }
        .foregroundStyle(.white)
        .frame(width: 160, height: toast.level == nil ? 120 : 136)
        .background(HUDMaterial().clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous)))
    }
}

private struct LevelBar: View {
    let level: Int

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.18))
                Capsule().fill(.white).frame(width: proxy.size.width * CGFloat(level) / 100)
            }
        }
        .frame(width: 112, height: 6)
        .animation(.easeOut(duration: 0.1), value: level)
    }
}

/// The dark translucent material macOS uses for its own HUDs.
private struct HUDMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
