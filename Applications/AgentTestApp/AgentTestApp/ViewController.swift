//
/*
Copyright 2025 Splunk Inc.

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

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    // Data model: These strings will be the data for the table view cells and drive the segue
    //             Each array must have the same number of elements
    let displayName: [String] = ["Network Calls", "Crashes", "Test API Sample Calls", "Slow Frame Renders", "Sample Next Task"] // Can be any descriptive text
    let segueName: [String] = ["NetworkCalls", "Crashes", "TestApiCalls", "SlowFrameRenders", "PlaceHolder"] //  Segues declared in the storyboard

    // cell reuse id (cells that scroll out of view can be reused)
    let cellReuseIdentifier = "cell"

    // don't forget to hook this up from the storyboard
    @IBOutlet var tableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Register the table view cell class and its reuse id
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellReuseIdentifier)

        // This view controller itself will provide the delegate methods and row data for the table view
        tableView.delegate = self
        tableView.dataSource = self
    }

    // number of rows in table view
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return displayName.count
    }

    // create a cell for each table view row
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        // create a new cell if needed or reuse an old one
        let cell: UITableViewCell = (self.tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier) as UITableViewCell?)!

        // set the text from the data model
        cell.textLabel?.text = displayName[indexPath.row]

        return cell
    }

    // method to run when table view cell is tapped
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print("You tapped row \(indexPath.row), for \(displayName[indexPath.row])")

        performSegue(withIdentifier: segueName[indexPath.row], sender: self)
    }
}

