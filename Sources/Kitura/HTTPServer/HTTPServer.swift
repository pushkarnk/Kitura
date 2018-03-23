import NIO
import NIOHTTP1

public class HTTPServer {
    
    public var delegate: ServerDelegate!

    public private(set) var port: Int?

    public var allowPortReuse: Bool = false

    let eventLoopGroup = MultiThreadedEventLoopGroup(numThreads: System.coreCount)
   
    private let maxPendingConnections = 100

    public init() { }

    public init(with router: ServerDelegate) { 
        self.delegate = router
    }

    public func listen(on: Int, errorHandler: ((Swift.Error) -> Void)? = nil) { 
        self.port = on 

        let bootstrap = ServerBootstrap(group: eventLoopGroup)
            .serverChannelOption(ChannelOptions.backlog, value: 100)
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: allowPortReuse ? 1 : 0)
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline().then { _ in
                    channel.pipeline.add(handler: HTTPHandler(router: self.delegate))
                }
            }
            .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
            

        let serverChannel = try! bootstrap.bind(host: "127.0.0.1", port: port!)
            .wait()
        try! serverChannel.closeFuture.wait()
    }

    public static func listen(port: Int, delegate: Router, errorHandler: ((Swift.Error) -> Void)? = nil) -> HTTPServer {
        let server = HTTPServer(with: delegate)
        server.listen(on: port, errorHandler: errorHandler)
        return server
    }

    public func stop() { 
        try! eventLoopGroup.syncShutdownGracefully()
    }
}

public class HTTPHandler: ChannelInboundHandler {
     let router: ServerDelegate 
     var serverRequest: HTTPServerRequest!
     var serverResponse: HTTPServerResponse!

     public init(router: ServerDelegate) {
         self.router = router
     }

     public typealias InboundIn = HTTPServerRequestPart
     public typealias OutboundOut = HTTPServerResponsePart

     public func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
         let request = self.unwrapInboundIn(data)

         switch request {
         case .head(let header):
             serverRequest = HTTPServerRequest(ctx: ctx, header: header)
         case .body(let buffer):
             serverRequest.setBuffer(buffer: buffer)           
         case .end(_):
             serverResponse = HTTPServerResponse(ctx: ctx, handler: self)
             router.handle(request: serverRequest, response: serverResponse)
         }
     }
}
