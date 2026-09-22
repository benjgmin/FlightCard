import SwiftUI
import PDFKit

/// The official FAA airport diagram, same chart pilots use in the cockpit.
struct AirportDiagramView: View {
    let icao: String

    @Environment(\.dismiss) private var dismiss
    @State private var document: PDFDocument?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.panel.ignoresSafeArea()
                if let document {
                    PDFKitView(document: document)
                        .ignoresSafeArea(edges: .bottom)
                } else if let errorMessage {
                    ContentUnavailableView("No diagram", systemImage: "map",
                                           description: Text(errorMessage))
                } else {
                    VStack(spacing: 12) {
                        ProgressView().tint(Theme.cyan)
                        Text("Loading the FAA chart index")
                            .font(.footnote)
                            .foregroundStyle(Theme.dim)
                    }
                }
            }
            .navigationTitle("\(icao) airport diagram")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        do {
            let url = try await DiagramService.shared.diagramURL(for: icao)
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let pdf = PDFDocument(data: data) else {
                throw DiagramError.badResponse
            }
            document = pdf
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> ZoomablePDFView {
        let view = ZoomablePDFView()
        view.document = document
        view.displayMode = .singlePage
        view.displaysPageBreaks = false
        view.backgroundColor = .clear

        let doubleTap = UITapGestureRecognizer(target: context.coordinator,
                                               action: #selector(Coordinator.doubleTapped(_:)))
        doubleTap.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTap)
        return view
    }

    func updateUIView(_ view: ZoomablePDFView, context: Context) {
        if view.document !== document {
            view.document = document
        }
    }

    final class Coordinator: NSObject {
        /// Zoom to 3x on the tapped spot, or back out to fit.
        @objc func doubleTapped(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view as? PDFView,
                  let page = view.currentPage else { return }
            let fit = view.scaleFactorForSizeToFit
            if view.scaleFactor > fit * 1.1 {
                view.scaleFactor = fit
                return
            }
            let location = gesture.location(in: view)
            let pagePoint = view.convert(location, to: page)
            view.scaleFactor = min(fit * 3, view.maxScaleFactor)
            // Center the zoom on where the user tapped.
            let size = CGSize(width: view.bounds.width / view.scaleFactor,
                              height: view.bounds.height / view.scaleFactor)
            let target = CGRect(x: pagePoint.x - size.width / 2, y: pagePoint.y - size.height / 2,
                                width: size.width, height: size.height)
            view.go(to: target, on: page)
        }
    }
}

/// Opens fit-to-screen, can't shrink past that, and zooms up to 6x.
final class ZoomablePDFView: PDFView {
    private var lastFit: CGFloat = 0

    override func layoutSubviews() {
        super.layoutSubviews()
        let fit = scaleFactorForSizeToFit
        // Only act when the fit size actually changes (first layout, rotation).
        guard fit > 0, abs(fit - lastFit) > 0.001 else { return }
        let wasAtFit = lastFit == 0 || abs(scaleFactor - lastFit) < 0.01
        lastFit = fit
        minScaleFactor = fit
        maxScaleFactor = fit * 6
        if wasAtFit {
            scaleFactor = fit
        }
    }
}
