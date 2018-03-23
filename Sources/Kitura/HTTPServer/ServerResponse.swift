import NIO
import NIOHTTP1
import Foundation

public protocol ServerResponse: class {
    
    var statusCode: HTTPResponseStatus? { get set }
    
    var headers : HTTPHeaders { get set }
    
    func write(from string: String) throws
    
    func write(from data: Data) throws
    
    func end(text: String) throws
    
    func end() throws
    
    func reset()
}

public class HTTPServerResponse : ServerResponse {
    private let ctx: ChannelHandlerContext 
    private let handler: HTTPHandler 

    public init(ctx: ChannelHandlerContext, handler: HTTPHandler) {
        self.ctx = ctx
        self.handler = handler
    }
    
    public var headers = HTTPHeaders()
  

    private var _statusCode = HTTPResponseStatus.ok.code

    public var statusCode: HTTPResponseStatus? {
        get {
            return HTTPResponseStatus(statusCode: Int(_statusCode))
        }
        set(newValue) {
            if let newValue = newValue {
                _statusCode = newValue.code
            }
        }
    }

    public func write(from string: String) throws {
        try write(from: string.data(using: .utf8)!)
    }

    public func write(from data: Data) throws {
        var buffer = ctx.channel.allocator.buffer(capacity: 100)
        buffer.write(string: String(data: data, encoding: .utf8)!)
        let request = handler.serverRequest!
        let httpVersion = HTTPVersion(major: request.httpVersionMajor!, minor: request.httpVersionMinor!)
        let response = HTTPResponseHead(version: httpVersion, status: .ok, headers: headers)
        ctx.write(handler.wrapOutboundOut(.head(response)), promise: nil)
        ctx.write(handler.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
        _ = ctx.writeAndFlush(handler.wrapOutboundOut(.end(nil)))
    }

    public func end(text: String) throws {
        try write(from: text)
        try end()
    }

    public func end() throws {
        ctx.flush()
        _ = ctx.close()
    }

    public func reset() { }
} 
