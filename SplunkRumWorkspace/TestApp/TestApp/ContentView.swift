//
//  ContentView.swift
//  TestApp
//
//  Created by jbley on 2/5/21.
//

import SwiftUI

struct ContentView: View {
    func network() -> Void {
        print("network!")
        let url = URL(string:"http://127.0.0.1:7878/data")!
        let task = URLSession.shared.dataTask(with: url) {(data, response:URLResponse?, error) in
            guard let data = data else { return }
            print("got some data")
            print(data)
            
        }
        task.resume()
    }
    func throwy() -> Void {
        NSException(name: NSExceptionName(rawValue: "IllegalFormatError"), reason: "Could not parse input", userInfo: nil).raise()
        print("should not reach here")
    }
    
    var body: some View {
        Button(action:{
            self.network()
        }) {
            Text("Network!")
        }
        Text("")
            .padding()
        Button(action:{
            self.throwy()
        }) {
            Text("Throw!")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
