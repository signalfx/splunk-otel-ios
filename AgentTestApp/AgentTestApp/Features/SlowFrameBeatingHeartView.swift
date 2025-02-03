//
/*
Copyright 2024 Splunk Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

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

