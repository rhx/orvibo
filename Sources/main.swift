import Foundation
import Dispatch
import COrvibo

#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

guard CommandLine.arguments.count == 2 else {
    print("Usage: \(CommandLine.arguments.first!) <mac>")
    exit(EXIT_FAILURE)
}

let mac = CommandLine.arguments.last!
guard let socket = Orvibo(mac) else {
    fatalError("Cannot create socket for \(mac)")
}

socket.onStateChange {
    print($1 ? "On" : "Off")
}

socket.onDiscovery() {
    print("Discovered \(mac) at \($0.ip)")
    $0.subscribe()
}

socket.onSubscription() { socket, _ in
    print("Subscribed, state = \(socket.state.rawValue)")
    let mainQueue = DispatchQueue.main
    mainQueue.async {
        var done = false
        var line = readLine()
        while let cmd = line, !done {
            switch cmd.lowercased() {
            case "q":
                fallthrough
            case "quit":
                done = true
                continue
            case "on":
                socket.on = true
            case "off":
                socket.on = false
            default:
                print("Unknown command '\(cmd)'")
            }
            line = readLine()
        }
        socket.unsubscribe()
        mainQueue.asyncAfter(deadline: .now() + .milliseconds(100)) {
            socket.destroy()
            orvibo_stop()
            exit(EXIT_SUCCESS)
        }
    }
}

socket.onUnsubscription() {
    print("Unsubscribed from \($0).")
}

socket.discover()

dispatchMain()
