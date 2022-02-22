//
/*
Copyright 2021 Splunk Inc.

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
import WebKit
import SplunkRum

class ViewController: UIViewController, WKUIDelegate, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet var tableView: UITableView!
    let cellReuseIdentifier = "cell"
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellReuseIdentifier)
        tableView.delegate = self
        tableView.dataSource = self
    }
        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            return 100
        }
        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell: UITableViewCell = (self.tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier) as UITableViewCell?)!
            cell.textLabel?.text = "Row \((indexPath as NSIndexPath).row)"
            cell.textLabel?.layer.shadowColor = UIColor.black.cgColor
            cell.textLabel?.layer.shadowRadius = 3.0
            cell.textLabel?.layer.shadowOpacity = 1.0
            cell.textLabel?.layer.shadowOffset = CGSize(width: 4, height: 4)
            cell.textLabel?.layer.masksToBounds = false
            return cell
        }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        }
    override func viewDidAppear(_ animated: Bool) {
      sleep(5)
    }

    @IBAction func clickMe() {
        print("I was clicked!")
        SplunkRum.setScreenName("CustomScreenName")

        let webview = WKWebView(frame: .zero)
        webview.uiDelegate = self
        let url = URL(string: "http://127.0.0.1:8989/page.html")
        let req = URLRequest(url: url!)
        view = webview
        SplunkRum.integrateWithBrowserRum(webview)
        webview.load(req)
    }

}
