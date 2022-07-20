import UIKit

class CreshOnViewDidloadVC: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        let null = UnsafePointer<UInt8>(bitPattern: 0)
        let derefNull = null!.pointee
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
