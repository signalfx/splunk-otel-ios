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

    // MARK: - Constants

    // Data model:
    //
    //   - Each array must have the same number of elements.
    //   - These strings will be the data for the table view cells and drive the segue.
    //   - Segues declared in the storyboard.

    /// Names for the table view cells.
    let displayName: [String] = [
        "Network Calls",
        "Crashes",
        "Test API Sample Calls",
        "Slow Frame Renders",
        "Sample Next Task"
    ]

    ///  Segues declared in the storyboard.
    let segueName: [String] = [
        "NetworkCalls",
        "Crashes",
        "TestApiCalls",
        "SlowFrameRenders",
        "PlaceHolder"
    ]

    /// Cell reuse id (cells that scroll out of view can be reused).
    let cellReuseIdentifier = "cell"


    // MARK: - UI Outlets

    @IBOutlet
    private var tableView: UITableView!


    // MARK: - View lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Register the table view cell class and its reuse id
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellReuseIdentifier)

        // This view controller itself will provide the delegate methods and row data for the table view.
        tableView.delegate = self
        tableView.dataSource = self
    }


    // MARK: - UITableViewDataSource methods

    /// Number of rows in table view.
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        displayName.count
    }

    /// Create a cell for each table view row.
    func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Create a new cell if needed or reuse an old one
        let cell: UITableViewCell = (tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier) as UITableViewCell?) ?? UITableViewCell()

        // Set the text from the data model
        cell.textLabel?.text = displayName[indexPath.row]

        return cell
    }


    // MARK: - UITableViewDelegate methods

    /// method to run when table view cell is tapped
    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        print("You tapped row \(indexPath.row), for \(displayName[indexPath.row])")

        performSegue(withIdentifier: segueName[indexPath.row], sender: self)
    }
}
