import SwiftUI

/// Auth is intentionally stubbed — the thesis test bench logs every device in
/// as a deterministic identity so call routing is reproducible across runs.
/// A real product would wire OAuth / OIDC here.
struct AuthView: View {
    var body: some View {
        ContentUnavailableView(
            "Bench mode",
            systemImage: "person.crop.circle.badge.checkmark",
            description: Text("Auth is stubbed. The bench logs the device in as `bench-<UDID>` so call routing is reproducible across runs.")
        )
    }
}
