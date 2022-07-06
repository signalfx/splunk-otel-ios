/// Copyright (c) 2022 Razeware LLC
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// This project and source code may use libraries or frameworks that are
/// released under various Open-Source licenses. Use of those libraries and
/// frameworks are governed by their own individual licenses.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import Foundation
import Vapor

class FileServer: ObservableObject {
    var app: Application
    let port: Int
    
    @Published var fileURLs: [URL] = []
    
    init(port: Int) {
        self.port = port
        app = Application(.development)
        app.http.server.configuration.hostname = "127.0.0.1"
        app.http.server.configuration.port = port
    }
    
    func start() {
        do {
            app.get("consolelog", ":filename",use: downloadFileHandler)
            app.delete("consolelog",":filename", use: deleteFileHandler)
            try app.run()
        } catch {
            //fatalError(error.localizedDescription)
            print(error.localizedDescription)
        }
    }
    
    func downloadFileHandler(_ req: Request) throws -> Response {
        guard let filename = req.parameters.get("filename") else {
            throw Abort(.badRequest)
        }
        let fileUrl = try URL.documentsDirectory().appendingPathComponent(filename)
        return req.fileio.streamFile(at: fileUrl.path)
    }
    
    func deleteFileHandler(_ req: Request) throws -> Bool {
        guard let filename = req.parameters.get("filename") else {
            throw Abort(.badRequest)
        }
        let fileUrl = try URL.documentsDirectory().appendingPathComponent(filename)
        do {
            try FileManager.default.removeItem(at: fileUrl)
            return true
        } catch {
            return false
        }
    }
    
    
    //  func loadFiles() {
    //    do {
    //      let documentsDirectory = try FileManager.default.url(
    //        for: .documentDirectory,
    //        in: .userDomainMask,
    //        appropriateFor: nil,
    //        create: false)
    //      let fileUrls = try FileManager.default.contentsOfDirectory(
    //        at: documentsDirectory,
    //        includingPropertiesForKeys: nil,
    //        options: .skipsHiddenFiles)
    //      self.fileURLs = fileUrls
    //    } catch {
    //      print(error)
    //    }
    //  }
    //
    //  func deleteFile(at offsets: IndexSet) {
    //    let urlsToDelete = offsets.map { fileURLs[$0] }
    //    fileURLs.remove(atOffsets: offsets)
    //    for url in urlsToDelete {
    //      try? FileManager.default.removeItem(at: url)
    //    }
    //  }
}
