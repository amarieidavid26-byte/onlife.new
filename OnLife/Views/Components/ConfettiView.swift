import SwiftUI

struct ConfettiView: View {
    @State private var isAnimating = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<30) { index in
                    ConfettiPiece(index: index, isAnimating: $isAnimating, screenHeight: geometry.size.height)
                }
            }
            .onAppear {
                isAnimating = true
            }
        }
    }
}

struct ConfettiPiece: View {
    let index: Int
    @Binding var isAnimating: Bool
    let screenHeight: CGFloat

    @State private var yOffset: CGFloat = -50
    @State private var xOffset: CGFloat = 0
    @State private var rotation: Double = 0
    @State private var opacity: Double = 1.0

    var body: some View {
        Circle()
            .fill(randomColor)
            .frame(width: randomSize, height: randomSize)
            .offset(x: xOffset, y: yOffset)
            .rotationEffect(.degrees(rotation))
            .opacity(opacity)
            .onAppear {
                startAnimation()
            }
    }

    var randomColor: Color {
        let colors = [
            OnLifeColors.sage,
            OnLifeColors.amber,
            Color.yellow,
            Color.green,
            Color.blue,
            Color.purple
        ]
        return colors[index % colors.count]
    }

    var randomSize: CGFloat {
        CGFloat.random(in: 6...12)
    }

    var randomXStart: CGFloat {
        CGFloat.random(in: -150...150)
    }

    var randomXEnd: CGFloat {
        randomXStart + CGFloat.random(in: -100...100)
    }

    func startAnimation() {
        let delay = Double.random(in: 0...0.5)
        let duration = Double.random(in: 2.0...3.0)

        xOffset = randomXStart

        withAnimation(.easeOut(duration: duration).delay(delay)) {
            yOffset = screenHeight + 100
            xOffset = randomXEnd
            rotation = Double.random(in: 360...720)
        }

        withAnimation(.easeIn(duration: duration * 0.3).delay(delay + duration * 0.7)) {
            opacity = 0
        }
    }
}
