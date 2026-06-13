import Foundation
import Network

/// Swift Network.framework MCP listener; routes through legacy `LKOsAppMCPHandler` until full Swift port.
@objc(LKOsAppMCPServer)
public final class LKOsAppMCPServerSwift: NSObject {
    @objc public static let shared = LKOsAppMCPServerSwift()

    private let queue = DispatchQueue(label: "lookin.osapp.mcp.swift")
    private let requestQueue = DispatchQueue(
        label: "lookin.osapp.mcp.requests",
        attributes: .concurrent
    )
    private var listener: NWListener?
    private let handler = LKOsAppMCPHandler()
    private var bridge: LKOsAppMCPDataSourceSwiftBridge?

    private override init() {
        super.init()
    }

    /// ObjC entry — `id<LKOsAppMCPDataSource>` (baseline) or `LookinMacMCPDataSource` (Swift client).
    @objc(startOnPort:dataSource:)
    public func start(onPort port: UInt16, dataSource: NSObject) {
        if let swiftSource = dataSource as? LookinMacMCPDataSource {
            start(port: port, swiftDataSource: swiftSource)
            return
        }
        if let objcSource = dataSource as? LKOsAppMCPDataSource {
            start(port: port, objcDataSource: objcSource)
            return
        }
        NSLog("[LookinMCP] dataSource must conform to LKOsAppMCPDataSource or LookinMacMCPDataSource")
    }

    public func start(port: UInt16, swiftDataSource: LookinMacMCPDataSource) {
        let bridge = LKOsAppMCPDataSourceSwiftBridge(swift: swiftDataSource)
        beginListening(on: port, dataSource: bridge, bridge: bridge)
    }

    public func start(port: UInt16, objcDataSource: LKOsAppMCPDataSource) {
        beginListening(on: port, dataSource: objcDataSource, bridge: nil)
    }

    private func beginListening(
        on port: UInt16,
        dataSource: LKOsAppMCPDataSource,
        bridge: LKOsAppMCPDataSourceSwiftBridge?
    ) {
        queue.sync {
            guard listener == nil else { return }

            self.bridge = bridge
            handler.dataSource = dataSource

            let params = NWParameters.tcp
            guard let nwPort = NWEndpoint.Port(rawValue: port),
                  let listener = try? NWListener(using: params, on: nwPort) else {
                NSLog("[LookinMCP] failed to create listener on port %u", port)
                return
            }

            listener.newConnectionHandler = { [weak self] connection in
                self?.accept(connection: connection)
            }
            listener.stateUpdateHandler = { state in
                if case .ready = state {
                    NSLog("[LookinMCP] listening on port %u", port)
                } else if case .failed(let error) = state {
                    NSLog("[LookinMCP] listener failed: %@", error.localizedDescription)
                }
            }
            listener.start(queue: queue)
            self.listener = listener
        }
    }

    @objc public func stop() {
        queue.async { [self] in
            self.listener?.cancel()
            self.listener = nil
            self.bridge = nil
            self.handler.dataSource = nil
        }
    }

    private func accept(connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, _, error in
            guard let self else {
                connection.cancel()
                return
            }
            guard let data, error == nil,
                  let requestStr = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }
            // Handle on the concurrent request queue so long-running requests (select-inspect-target,
            // refresh-launch-targets) don't block fast queries like /status.
            self.requestQueue.async {
                self.handleRequestString(requestStr, connection: connection)
            }
        }
    }

    private func handleRequestString(_ requestStr: String, connection: NWConnection) {
        guard let parsed = LKOsAppMCPHTTPParser.parseRequest(requestStr) else {
            send(LKOsAppMCPHTTPResponse.error("Bad request", statusCode: 400), on: connection)
            return
        }

        var statusCode: Int = 0
        let body = handler.handleMethod(
            parsed.method,
            path: parsed.path,
            body: parsed.body,
            statusCode: &statusCode
        )
        let response = LKOsAppMCPHTTPResponse(statusCode: statusCode > 0 ? statusCode : 500, body: body)
        send(response, on: connection)
    }

    private func send(_ response: LKOsAppMCPHTTPResponse, on connection: NWConnection) {
        connection.send(content: response.httpData, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
