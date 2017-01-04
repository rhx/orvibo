//
//  main.swift
//  orvibo
//
//  Created by Rene Hexel on 3/1/17.
//  Copyright © 2017 Rene Hexel. All rights reserved.
//
import Foundation
import Dispatch
import COrvibo

#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

/// Print command usage and exit the program
///
/// - Parameter rv: exit value (e.g. EXIT_SUCCESS)
/// - Returns: never
func usage(_ rv: Int32 = EXIT_FAILURE) -> Never {
    print("Usage: \(CommandLine.arguments.first!) [-b port] [-t seconds] [-u port] <mac>")
    print("Options:\t-b port\tbroadcast on the given UDP port")
    print("        \t-t seconds\tconnection timeout in seconds")
    print("        \t-u port\tlisten at the given UDP port")
    exit(rv)
}

/// Output the given string, adding '\n'
///
/// - Parameters:
///   - s: the string to print / output
///   - file: pointer to the output file (`stdout` if none is given)
func output(_ s: String, file: UnsafeMutablePointer<FILE> = stdout) {
    fputs("\(s)\n", file)
    fflush(file)
}

var broadcastPort: UInt16?
var listenPort: UInt16?
var timeout: Int?

while let (opt, param) = get_opt("b:t:u:") {
    switch opt {
    case "b":
        guard param != nil, let p = UInt16(param!) else { usage() }
        broadcastPort = p
    case "t":
        guard param != nil, let t = Int(param!) else { usage() }
        timeout = t
    case "u":
        guard param != nil, let p = UInt16(param!) else { usage() }
        listenPort = p
    case "?": fallthrough
    default:
        usage()
    }
}
guard CommandLine.arguments.count == Int(optind) + 1 else { usage() }

let mac = CommandLine.arguments.last!
guard let socket = Orvibo(mac) else {
    fatalError("Cannot create socket for \(mac)")
}

socket.onStateChange {
    let status = $0.getStatus($1)
    output(status)
}

socket.onDiscovery() {
    output("Discovered \(mac) at \($0.ip)")
    $0.subscribe()
}

socket.onSubscription() { socket, _ in
    output("Subscribed, state = \(socket.state.rawValue)")
    DispatchQueue.main.async {
        var line = readLine()
        while let cmd = line {
            let (response, done) = socket.handle(command: cmd)
            if let status = response { output(status) }
            guard !done else { break }
            line = readLine()
        }
        socket.unsubscribeAndExit()
    }
}

socket.onUnsubscription() {
    output("Unsubscribed from \($0).")
}

if let t = timeout {
    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(t)) {
        if socket.stage != .subscribed {
            output("Connection timeout!", file: stderr)
            socket.unsubscribeAndExit()
        }
    }
}

socket.discover()

dispatchMain()
