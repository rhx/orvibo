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

func outputStatus(_ on: Bool) {
    let status = on ? "On\n" : "Off\n"
    fputs(status, stdout)
    fflush(stdout)
}

socket.onStateChange {
    outputStatus($1)
}

socket.onDiscovery() {
    fputs("Discovered \(mac) at \($0.ip)\n", stdout)
    fflush(stdout)
    $0.subscribe()
}

socket.onSubscription() { socket, _ in
    fputs("Subscribed, state = \(socket.state.rawValue)\n", stdout)
    fflush(stdout)
    let mainQueue = DispatchQueue.main
    mainQueue.async {
        var done = false
        var line = readLine()
        while let cmd = line, !done {
            switch cmd.lowercased() {
            case "q": fallthrough
            case "quit":
                done = true
                continue
            case "on":
                socket.on = true
            case "off":
                socket.on = false
            case "p": fallthrough
            case "ping":
                let onOff = socket.getState()
                outputStatus(onOff)
            default:
                fputs("Unknown command '\(cmd)'", stderr)
                fflush(stderr)
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
    fputs("Unsubscribed from \($0).\n", stdout)
    fflush(stdout)
}

socket.discover()

dispatchMain()
