import SwiftUI

/// Renders the captured frame inside a Polaroid-style frame. The photo area
/// matches the user's current window mask:
///   - Default (16:9 rectangle)
///   - Square (1:1)
///   - Circle (1:1 with circular clip)
///
/// `photoOpacity`, `photoScale`, and `dateRevealProgress` drive the editor's
/// entrance animations — photo "develops" inside the frame and the date
/// stroke-reveals from left to right.
struct PolaroidSnapView: View {
    let image: NSImage
    let dateText: String?
    let mirrored: Bool
    let includeFrame: Bool
    let maskStyle: MaskStyle
    var photoOpacity: Double = 1.0
    var photoScale: CGFloat = 1.0
    var dateRevealProgress: CGFloat = 1.0

    private let outerHorizontal: CGFloat = 16
    private let outerTop: CGFloat = 16
    private let outerBottom: CGFloat = 84

    /// Photo area dimensions for each mask style. We keep the long side fixed
    /// so the polaroid is roughly the same overall width across styles.
    private var photoSize: CGSize {
        switch maskStyle {
        case .defaultChrome:
            // 16:9 rectangle
            return CGSize(width: 340, height: 340 * 9.0 / 16.0)
        case .square, .circle:
            return CGSize(width: 320, height: 320)
        }
    }

    private var photoShape: AnyShape {
        switch maskStyle {
        case .circle: return AnyShape(Circle())
        default:      return AnyShape(Rectangle())
        }
    }

    var body: some View {
        if includeFrame {
            VStack(spacing: 0) {
                ZStack {
                    Rectangle().fill(Color(white: 0.92))
                    photo
                        .opacity(photoOpacity)
                        .scaleEffect(photoScale)
                }
                .frame(width: photoSize.width, height: photoSize.height)
                .clipShape(photoShape)
                .padding(.top, outerTop)
                .padding(.horizontal, outerHorizontal)

                ZStack {
                    if let dateText {
                        Text(dateText)
                            .font(.custom("Marker Felt", size: 30))
                            .foregroundStyle(.black)
                            .padding(.bottom, 6)
                            .mask(
                                GeometryReader { geo in
                                    Rectangle()
                                        .frame(width: geo.size.width * dateRevealProgress)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            )
                    }
                }
                .frame(maxWidth: .infinity, minHeight: outerBottom, alignment: .center)
            }
            .frame(width: photoSize.width + outerHorizontal * 2,
                   height: photoSize.height + outerTop + outerBottom)
            .background(Color.white)
        } else {
            photo
                .opacity(photoOpacity)
                .scaleEffect(photoScale)
                .frame(width: photoSize.width, height: photoSize.height)
                .clipShape(photoShape)
        }
    }

    private var photo: some View {
        Image(nsImage: image)
            .resizable()
            .scaleEffect(x: mirrored ? -1 : 1, y: 1)
            .aspectRatio(contentMode: .fill)
            .frame(width: photoSize.width, height: photoSize.height)
            .clipped()
    }
}
