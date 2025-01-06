//
//  MRUM SDK, © 2024 CISCO
//

import UIKit

class SlowFrameBeatingHeartView: UIView {
    private let heartImageView = UIImageView()

    // manual animation -- see below for why
    private var timer: Timer?
    private var scaleDirection: CGFloat = -1.0

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        startAnimation()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
        startAnimation()
    }

    func dealloc() {
        stopAnimation()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        heartImageView.frame = bounds
    }

    private func setupView() {
        heartImageView.image = UIImage(systemName: "heart.fill")
        heartImageView.tintColor = .red
        heartImageView.contentMode = .scaleAspectFit
        heartImageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(heartImageView)
    }

    func startAnimation() {
        // Even with 0.04 it's still not the smoothest but
        // it serves the purpose.
        timer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { [weak self] _ in
            self?.updateAnimation()
        }
    }

    func stopAnimation() {
        timer?.invalidate()
        timer = nil
    }

    private func updateAnimation() {

        // Use a manually conducted animation so that we can
        // keep it on the main thread and witness the results of
        // the main thread stall in the UI. If we instead used a
        // built-in animation here, Apple would put it on a
        // background worker thread and it would not (reliably)
        // pause when the main thread pauses, such as during a
        // sleep on the main thread, so the results would not
        // be visible or clearly shown in this test app.

        // get the scale component of the transform matrix
        let currentScale = heartImageView.transform.a

        let scaleStep: CGFloat = 0.01
        var newScale = currentScale + (scaleStep * scaleDirection)

        if newScale <= 0.5 {
            newScale = 0.5
            scaleDirection = 1.0
        } else if newScale >= 1.0 {
            newScale = 1.0
            scaleDirection = -1.0
        }

        heartImageView.transform = CGAffineTransform(scaleX: newScale, y: newScale)
    }
}

