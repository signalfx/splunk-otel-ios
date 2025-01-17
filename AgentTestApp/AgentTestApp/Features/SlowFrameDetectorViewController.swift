//
//  MRUM SDK, © 2024 CISCO
//

import SwiftUI
import UIKit

class SlowFrameDetectorViewController: UIViewController {

    @IBOutlet var slowFramesButton: UIButton!
    @IBOutlet var frozenFramesButton: UIButton!
    @IBOutlet var beatingHeartView: SlowFrameBeatingHeartView!

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    @IBAction func slowFramesClick(_ sender: UIButton) {
        // Sleep for 0.5 seconds on the main thread
        print("Sleeping for 0.5 seconds to force slow frames")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.001) {
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    @IBAction func frozenFramesClick(_ sender: UIButton) {
        // Sleep for 1 second on the main thread
        print("Sleeping for 2 seconds to force frozen frames")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.001) {
            Thread.sleep(forTimeInterval: 2.0)
        }
    }
}


