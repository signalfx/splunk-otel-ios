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

import Vapor

@available(iOS 15.0.0, *)
struct FileWebRouteCollection: RouteCollection {
  func boot(routes: RoutesBuilder) throws {
    routes.get(":filename", use: downloadFileHandler)
    routes.get("delete", ":filename", use: deleteFileHandler)
    routes.post(use: uploadFilePostHandler)
  }

//    func filesViewHandler(_ req: Request)  async throws -> View? {
//    let documentsDirectory = try URL.documentsDirectory()
//    let fileUrls = try documentsDirectory.visibleContents()
//    let filenames = fileUrls.map { $0.lastPathComponent }
//    let context = FileContext(filenames: filenames)
//      if #available(iOS 15, *) {
//          return try await req.view.render("files", context)
//      } else {
//          // Fallback on earlier versions
//          return nil
//      }
//  }

  func uploadFilePostHandler(_ req: Request) throws -> Response {
    let fileData = try req.content.decode(FileUploadPostData.self)
    let writeURL = try URL.documentsDirectory().appendingPathComponent(fileData.file.filename)
    try Data(fileData.file.data.readableBytesView).write(to: writeURL)
    notifyFileChange()
    return req.redirect(to: "/")
  }

  func downloadFileHandler(_ req: Request) throws -> Response {
    guard let filename = req.parameters.get("filename") else {
      throw Abort(.badRequest)
    }
    let fileUrl = try URL.documentsDirectory().appendingPathComponent(filename)
    return req.fileio.streamFile(at: fileUrl.path)
  }

  func deleteFileHandler(_ req: Request) throws -> Response {
    guard let filename = req.parameters.get("filename") else {
      throw Abort(.badRequest)
    }
    let fileURL = try URL.documentsDirectory().appendingPathComponent(filename)
    try FileManager.default.removeItem(at: fileURL)
    notifyFileChange()
    return req.redirect(to: "/")
  }

  func notifyFileChange() {
    DispatchQueue.main.async {
      NotificationCenter.default.post(name: .serverFilesChanged, object: nil)
    }
  }
}

struct FileContext: Encodable {
  var filenames: [String]
}

struct FileUploadPostData: Content {
  var file: File
}
