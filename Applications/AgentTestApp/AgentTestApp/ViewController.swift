//
//  ViewController.swift
//  AgentTestApp
//
//  Created by mickelsn on 11/1/22.
//

import UIKit

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    // Data model: These strings will be the data for the table view cells and drive the segue
    //             Each array must have the same number of elements
    let displayName: [String] = ["Network Calls", "Crashes", "Test API Sample Calls", "Sample Next Task"] // Can be any descriptive text
    let segueName: [String] = ["NetworkCalls", "Crashes", "TestApiCalls", "SlowFrameRenders", "PlaceHolder"] //  Segues declared in the storyboard

    // cell reuse id (cells that scroll out of view can be reused)
    let cellReuseIdentifier = "cell"

    // don't forget to hook this up from the storyboard
    @IBOutlet var tableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Register the table view cell class and its reuse id
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellReuseIdentifier)

        // This view controller itself will provide the delegate methods and row data for the table view.
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

