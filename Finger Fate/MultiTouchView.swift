import SwiftUI
import UIKit

struct MultiTouchView: UIViewRepresentable {
    let onChange: ([TouchID: CGPoint]) -> Void

    func makeUIView(context: Context) -> TrackingView {
        let view = TrackingView()
        view.onChange = onChange
        return view
    }

    func updateUIView(_ uiView: TrackingView, context: Context) {
        uiView.onChange = onChange
    }
}

final class TrackingView: UIView {
    var onChange: (([TouchID: CGPoint]) -> Void)?
    private var activeTouches: [TouchID: UITouch] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            activeTouches[ObjectIdentifier(touch)] = touch
        }
        publish()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        publish()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        remove(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        remove(touches)
    }

    private func remove(_ touches: Set<UITouch>) {
        for touch in touches {
            activeTouches.removeValue(forKey: ObjectIdentifier(touch))
        }
        publish()
    }

    private func publish() {
        let points = activeTouches.mapValues { $0.location(in: self) }
        onChange?(points)
    }
}
