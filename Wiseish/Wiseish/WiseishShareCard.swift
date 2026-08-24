import SwiftUI
import UIKit

struct WiseishSharePayload: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct WiseishActivityView: UIViewControllerRepresentable {
    let image: UIImage

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [image], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

@MainActor
enum WiseishShareCardRenderer {
    static func render(quote: WiseishQuote, date: Date = .now) -> UIImage? {
        let renderer = ImageRenderer(content: WiseishShareCardView(quote: quote, date: date))
        renderer.proposedSize = ProposedViewSize(width: 1_080, height: 1_350)
        renderer.scale = 1
        return renderer.uiImage
    }
}

private struct WiseishShareCardView: View {
    let quote: WiseishQuote
    let date: Date

    private let paper = Color(red: 0.96, green: 0.92, blue: 0.85)
    private let lightPaper = Color(red: 1.00, green: 0.98, blue: 0.94)
    private let ink = Color(red: 0.16, green: 0.15, blue: 0.13)
    private let softInk = Color(red: 0.44, green: 0.41, blue: 0.37)
    private let mustard = Color(red: 0.85, green: 0.66, blue: 0.23)

    var body: some View {
        ZStack {
            paper

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    HStack(spacing: 0) {
                        Text("Wise")
                        Text("–").foregroundStyle(mustard)
                        Text("ish")
                    }
                    .font(.system(size: 52, weight: .bold, design: .serif))

                    Spacer()

                    Text(date, format: .dateTime.year().month().day())
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(softInk)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 30) {
                    Text("TODAY, PERHAPS")
                        .font(.system(size: 20, weight: .bold))
                        .tracking(4)
                        .foregroundStyle(softInk)

                    Text(quote.text)
                        .font(.system(size: 70, weight: .semibold, design: .serif))
                        .lineSpacing(22)
                        .minimumScaleFactor(0.55)
                        .lineLimit(5)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("# \(quote.theme)")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(softInk)
                }
                .padding(58)
                .background(lightPaper, in: RoundedRectangle(cornerRadius: 32))
                .overlay(alignment: .top) {
                    HStack(spacing: 16) {
                        ForEach(0..<4, id: \.self) { _ in
                            Capsule()
                                .fill(mustard)
                                .frame(width: 20, height: 58)
                                .overlay(Capsule().stroke(ink, lineWidth: 5))
                                .rotationEffect(.degrees(8))
                        }
                    }
                    .offset(y: -28)
                }
                .shadow(color: ink.opacity(0.12), radius: 30, y: 18)

                Spacer()

                HStack(alignment: .bottom) {
                    Text("考えすぎた頭を、\n少しだけゆるめる。")
                        .font(.system(size: 27, weight: .semibold, design: .serif))
                        .lineSpacing(8)
                        .foregroundStyle(softInk)

                    Spacer()

                    Image("Ish")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 260, height: 260)
                }
            }
            .padding(72)
        }
        .foregroundStyle(ink)
        .frame(width: 1_080, height: 1_350)
    }
}
