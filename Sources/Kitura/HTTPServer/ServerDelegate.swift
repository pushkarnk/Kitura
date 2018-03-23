public protocol ServerDelegate: class {
    func handle(request: ServerRequest, response: ServerResponse)
}
