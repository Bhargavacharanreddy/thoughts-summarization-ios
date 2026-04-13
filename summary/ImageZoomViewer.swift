import SwiftUI

struct ImageZoomViewer: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 6.0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        SimultaneousGesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    let delta = value / lastScale
                                    lastScale = value
                                    scale = min(max(scale * delta, minScale), maxScale)
                                }
                                .onEnded { _ in
                                    lastScale = 1.0
                                    if scale < minScale {
                                        withAnimation(.spring()) { scale = minScale; offset = .zero }
                                    }
                                },
                            DragGesture()
                                .onChanged { value in
                                    let newOffset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                    // When not zoomed, downward drag dismisses
                                    if scale <= 1.05 {
                                        offset = CGSize(width: 0, height: max(0, value.translation.height))
                                    } else {
                                        offset = newOffset
                                    }
                                }
                                .onEnded { value in
                                    if scale <= 1.05 && value.translation.height > 80 {
                                        dismiss()
                                    } else if scale <= 1.05 {
                                        withAnimation(.spring()) { offset = .zero }
                                        lastOffset = .zero
                                    } else {
                                        lastOffset = offset
                                        clampOffset(geo: geo)
                                    }
                                }
                        )
                    )
                    .gesture(
                        TapGesture(count: 2).onEnded {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                if scale > 1.05 {
                                    scale = 1.0; offset = .zero; lastOffset = .zero
                                } else {
                                    scale = 2.5
                                }
                            }
                        }
                    )

                // Close button
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 30))
                                .foregroundStyle(.white.opacity(0.8))
                                .shadow(radius: 4)
                        }
                        .padding(20)
                    }
                    Spacer()
                }
            }
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
    }

    private func clampOffset(geo: GeometryProxy) {
        let maxX = max(0, (geo.size.width * scale - geo.size.width) / 2)
        let maxY = max(0, (geo.size.height * scale - geo.size.height) / 2)
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            offset = CGSize(
                width: min(max(offset.width, -maxX), maxX),
                height: min(max(offset.height, -maxY), maxY)
            )
        }
        lastOffset = offset
    }
}
