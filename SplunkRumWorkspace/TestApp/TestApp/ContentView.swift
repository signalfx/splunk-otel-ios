//
//  ContentView.swift
//  TestApp
//
//  Created by jbley on 2/5/21.
//

import SwiftUI

struct ContentView: View {
    func networkRequest() {
        print("network (req)!")
        let url = URL(string: "http://127.0.0.1:7878/data")!
        var req = URLRequest(url: url)
        req.httpMethod = "HEAD"
        let task = URLSession.shared.dataTask(with: req) {(data, _: URLResponse?, _) in
            guard let data = data else { return }
            print("got some data")
            print(data)

        }
        task.resume()
    }
    func network() {
        print("network!")
        let url = URL(string: "http://127.0.0.1:7878/data")!
        let task = URLSession.shared.dataTask(with: url) {(data, _: URLResponse?, _) in
            guard let data = data else { return }
            print("got some data")
            print(data)

        }
        task.resume()
    }
    func throwy() {
        NSException(name: NSExceptionName(rawValue: "IllegalFormatError"), reason: "Could not parse input", userInfo: nil).raise()
        print("should not reach here")
    }

    var body: some View {
        Button(action: {
            self.network()
        }) {
            Text("Network (url)!")
        }
        Text("")
            .padding()
        Button(action: {
            self.throwy()
        }) {
            Text("Throw!")
        }
        Text("")
            .padding()
        Button(action: {
            self.networkRequest()
        }) {
            Text("Network (req)!")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
