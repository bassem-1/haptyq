import Foundation
import HapticCore
import Network

// Local-only web UI for poking the trackpad actuator: http://127.0.0.1:<port>

let port = UInt16(CommandLine.arguments.dropFirst().first ?? "") ?? 47823
guard let actuator = Actuator() else { print("No actuator"); exit(1) }
let player = PatternPlayer(actuator: actuator)
let fireQueue = DispatchQueue(label: "haptics.web.fire", qos: .userInteractive)
let proximity = ProximityEngine(actuator: actuator)

// MARK: HTTP

struct Request {
    let method: String
    let path: String
    let query: [String: String]
    let body: Data
}

func parse(_ data: Data) -> Request? {
    guard let sep = data.range(of: Data("\r\n\r\n".utf8)),
          let head = String(data: data[..<sep.lowerBound], encoding: .utf8) else { return nil }
    let lines = head.components(separatedBy: "\r\n")
    let parts = lines[0].split(separator: " ")
    guard parts.count >= 2 else { return nil }
    let comps = URLComponents(string: String(parts[1]))
    var query: [String: String] = [:]
    for item in comps?.queryItems ?? [] { query[item.name] = item.value ?? "" }
    var length = 0
    for line in lines.dropFirst() where line.lowercased().hasPrefix("content-length:") {
        length = Int(line.split(separator: ":")[1].trimmingCharacters(in: .whitespaces)) ?? 0
    }
    let body = data[sep.upperBound...]
    guard body.count >= length else { return nil } // need more bytes
    return Request(method: String(parts[0]), path: comps?.path ?? "/", query: query, body: Data(body.prefix(length)))
}

func respond(_ conn: NWConnection, _ status: String, _ type: String, _ body: Data) {
    var head = "HTTP/1.1 \(status)\r\nContent-Type: \(type)\r\nContent-Length: \(body.count)\r\n"
    head += "Cache-Control: no-store\r\nConnection: close\r\n\r\n"
    conn.send(content: Data(head.utf8) + body, completion: .contentProcessed { _ in conn.cancel() })
}

func json(_ conn: NWConnection, _ obj: Any, status: String = "200 OK") {
    let data = (try? JSONSerialization.data(withJSONObject: obj)) ?? Data("{}".utf8)
    respond(conn, status, "application/json", data)
}

func handle(_ req: Request, _ conn: NWConnection) {
    switch (req.method, req.path) {
    case ("GET", "/"):
        respond(conn, "200 OK", "text/html; charset=utf-8", Data(page.utf8))

    case ("GET", "/api/patterns"):
        let enc = JSONEncoder()
        let list = Library.load().values.sorted { $0.name < $1.name }
        respond(conn, "200 OK", "application/json", (try? enc.encode(list)) ?? Data("[]".utf8))

    case ("POST", "/api/fire"):
        guard let id = Int32(req.query["id"] ?? "") else { return json(conn, ["error": "id required"], status: "400 Bad Request") }
        let f1 = Float(req.query["f1"] ?? "") ?? 0, f2 = Float(req.query["f2"] ?? "") ?? 0
        var ok = false
        fireQueue.sync { ok = actuator.fire(id: id, f1: f1, f2: f2) }
        json(conn, ["ok": ok, "id": id, "fallback": !ok])

    case ("POST", "/api/play"):
        let pattern: Pattern?
        if let name = req.query["name"] {
            pattern = Library.load()[name]
        } else {
            pattern = try? JSONDecoder().decode(Pattern.self, from: req.body)
        }
        guard let pattern else { return json(conn, ["error": "unknown pattern"], status: "400 Bad Request") }
        player.play(pattern)
        json(conn, ["ok": true, "name": pattern.name, "pulses": pattern.pulses.count])

    case ("POST", "/api/prox"):
        // d < 0 means "no target" (cursor left the playground).
        let d = Double(req.query["d"] ?? "") ?? -1
        proximity.update(distance: d < 0 ? nil : d)
        json(conn, ["ok": true])

    case ("GET", "/api/proximity"):
        respond(conn, "200 OK", "application/json", (try? JSONEncoder().encode(proximity.config)) ?? Data("{}".utf8))

    case ("POST", "/api/proximity"):
        guard let cfg = try? JSONDecoder().decode(ProximityConfig.self, from: req.body) else {
            return json(conn, ["error": "bad config"], status: "400 Bad Request")
        }
        proximity.config = cfg
        do { try cfg.save(); json(conn, ["ok": true, "path": ProximityConfig.url.path]) }
        catch { json(conn, ["error": "\(error)"], status: "500 Internal Server Error") }

    default:
        respond(conn, "404 Not Found", "text/plain", Data("not found".utf8))
    }
}

func receive(_ conn: NWConnection, _ buffer: Data = Data()) {
    conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, done, err in
        var buf = buffer
        if let data { buf.append(data) }
        if let req = parse(buf) { return handle(req, conn) }
        if done || err != nil || buf.count > 1_000_000 { return conn.cancel() }
        receive(conn, buf)
    }
}

// MARK: Listener (loopback only)

let params = NWParameters.tcp
params.requiredLocalEndpoint = NWEndpoint.hostPort(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: port)!)
params.allowLocalEndpointReuse = true
let listener = try NWListener(using: params)
listener.newConnectionHandler = { conn in
    conn.start(queue: .global(qos: .userInitiated))
    receive(conn)
}
listener.stateUpdateHandler = { state in
    switch state {
    case .ready: print("haptic-web: open http://127.0.0.1:\(port)"); fflush(stdout)
    case .failed(let e): print("listener failed: \(e)"); exit(1)
    default: break
    }
}
listener.start(queue: .main)
dispatchMain()
