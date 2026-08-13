import AppKit
import SwiftUI

/// Experiment: a fake progressive blur across the titlebar strip.
///
/// `titlebarAppearsTransparent` lets content scroll under the titlebar, but
/// AppKit leaves that strip bare, so cards and PDF pages run straight into the
/// window buttons. This lays a masked material over it — full strength at the
/// top, faded to nothing just past the titlebar — which reads as a blur that
/// thins out instead of a band with a hard edge.
enum TitlebarBlur {
    /// The experiment's one switch. Set it to `false` and the overlay is never
    /// installed; any window already showing one drops it on its next update.
    static let isEnabled = true

    // MARK: Knobs
    //
    // Each one moves the effect along a different axis, so they are worth
    // turning one at a time: `material` sets how much blur there is at all,
    // `intensity` how much of it survives the mask, `falloff` and `holdFraction`
    // where it ends and how abruptly.

    /// How much blur and tint the layer has before any masking. Thinner is
    /// subtler: `.ultraThin` barely frosts, `.thick` is close to opaque chrome.
    static let material: Material = .bar

    /// Ceiling on the mask's alpha, so the strongest point of the gradient. Drop
    /// it toward `0` to keep the same shape while letting more content through.
    static let intensity: CGFloat = 0.9

    /// How far past the titlebar the material keeps fading, in points. This is
    /// the room the fade has: raising it spreads the transition over more
    /// distance (softer, but reaching further into the content), and dropping it
    /// toward `0` compresses the fade until the bottom edge reads as a seam.
    static let falloff: CGFloat = 8

    /// The share of the overlay that stays at full `intensity` before the fade
    /// starts, as a fraction of its height. `0` ramps down from the very top the
    /// way a plain linear gradient does; raising it keeps the strip behind the
    /// window buttons solid and crowds the fade into what is left.
    static let holdFraction: CGFloat = 0.15

    /// Stands in until the window can report its own titlebar height.
    static let fallbackTitlebarHeight: CGFloat = 52

    static let overlayIdentifier = NSUserInterfaceItemIdentifier("TitlebarBlurOverlay")
    static let heightConstraintIdentifier = "TitlebarBlurOverlayHeight"

    /// The mask's alpha ramp: flat across `holdFraction`, then smoothstepped to
    /// clear. The curve matters — a straight line leaves a visible corner where
    /// the fade begins, whereas this eases in and out of both ends.
    ///
    /// The colors are arbitrary. `mask` reads the alpha channel alone, so black
    /// here is never drawn; what the window shows is `material` at that alpha.
    static var maskStops: [Gradient.Stop] {
        let hold = min(max(holdFraction, 0), 1)
        let steps = 12

        return [Gradient.Stop(color: .black.opacity(intensity), location: 0)]
            + (0...steps).map { step in
                let progress = CGFloat(step) / CGFloat(steps)
                let eased = progress * progress * (3 - 2 * progress)
                return Gradient.Stop(
                    color: .black.opacity(intensity * (1 - eased)),
                    location: hold + (1 - hold) * progress
                )
            }
    }
}

/// One material layer, masked so it fades out over the titlebar strip.
struct TitlebarBlurView: View {
    var body: some View {
        Rectangle()
            .fill(TitlebarBlur.material)
            .mask {
                LinearGradient(
                    stops: TitlebarBlur.maskStops,
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .allowsHitTesting(false)
            .ignoresSafeArea()
    }
}

/// The overlay covers points the reader and the gallery own, so it answers no
/// hit test at all — clicks and scroll wheels pass straight through it.
private final class TitlebarBlurHostingView: NSHostingView<TitlebarBlurView> {
    required init(rootView: TitlebarBlurView) {
        super.init(rootView: rootView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

extension WindowSplitController {
    /// Shows or hides the blur over the detail column.
    ///
    /// Idempotent: `NSWindow.didUpdateNotification` drives this, and that fires
    /// on every pass of the event loop.
    func setTitlebarBlur(visible: Bool) {
        // The overlay lives in a view the split controller only creates in
        // `viewDidLoad`; before that there is also nothing on screen to cover.
        guard isViewLoaded else { return }

        guard TitlebarBlur.isEnabled else {
            titlebarBlurOverlay?.removeFromSuperview()
            return
        }

        guard visible else {
            titlebarBlurOverlay?.isHidden = true
            return
        }

        let overlay = titlebarBlurOverlay ?? installTitlebarBlurOverlay()
        overlay.isHidden = false

        // The strip is titlebar-only in the reader and titlebar-plus-toolbar in
        // the library, so the height is remeasured rather than assumed.
        let height = titlebarBlurHeight
        if let constraint = overlay.constraints.first(
            where: { $0.identifier == TitlebarBlur.heightConstraintIdentifier }
        ), constraint.constant != height {
            constraint.constant = height
        }
    }

    private var titlebarBlurOverlay: NSView? {
        detailColumnView.subviews.first {
            $0.identifier == TitlebarBlur.overlayIdentifier
        }
    }

    private func installTitlebarBlurOverlay() -> NSView {
        let container = detailColumnView
        let overlay = TitlebarBlurHostingView(rootView: TitlebarBlurView())
        overlay.identifier = TitlebarBlur.overlayIdentifier
        overlay.translatesAutoresizingMaskIntoConstraints = false
        // The overlay exists to fill the titlebar's safe area, so SwiftUI must
        // not inset its content out of exactly the strip it is covering.
        overlay.safeAreaRegions = []
        container.addSubview(overlay)

        let height = overlay.heightAnchor.constraint(
            equalToConstant: titlebarBlurHeight
        )
        height.identifier = TitlebarBlur.heightConstraintIdentifier
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: container.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            height,
        ])
        return overlay
    }

    /// The titlebar strip plus the distance the material spends fading out.
    private var titlebarBlurHeight: CGFloat {
        let container = detailColumnView
        let inset = container.safeAreaInsets.top
        if inset > 0 { return inset + TitlebarBlur.falloff }

        // No safe area yet: ask the window how much of its content view the
        // titlebar and toolbar cover.
        guard
            let window = container.window,
            let contentView = window.contentView
        else {
            return TitlebarBlur.fallbackTitlebarHeight + TitlebarBlur.falloff
        }

        let titlebarHeight = contentView.bounds.height
            - window.contentLayoutRect.height
        return max(titlebarHeight, 0) + TitlebarBlur.falloff
    }
}
