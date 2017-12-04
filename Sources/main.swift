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

var broadcast: UDPSocket?
var broadcastPort: UInt16?
var listenPort: UInt16?
var listen: UDPSocket?
var orvibo: Orvibo?
var timeout: Int?

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

/// Output the given string to UDP (if non-nil) and file, adding '\n'
///
/// - Parameters:
///   - s: the string to print / output
///   - file: pointer to the output file (`stdout` if none is given)
func output(_ s: String, file: UnsafeMutablePointer<FILE> = stdout) {
    let message = "\(s)\n"
    if let p = broadcastPort {
        if !(broadcast?.send(message, port: p) ?? false) {
            print("Cannot send message '\(s)' to port \(p): \(String(cString: strerror(errno)))")
        }
    }
    fputs(message, file)
    fflush(file)
}

while let (opt, param) = get_opt("b:t:u:") {
    switch opt {
    case "b":
        guard param != nil, let p = UInt16(param!) else { usage() }
        broadcastPort = p
        do {
            broadcast = try UDPSocket(port: p)
        } catch SocketError.error(let errno) {
            fatalError("Cannot create UDP broadbast socket for port \(p): \(String(cString: strerror(errno)))")
        } catch {
            fatalError("Unknown error trying to create UDP broadbast socket for port \(p): \(String(cString: strerror(errno)))")
        }
    case "t":
        guard param != nil, let t = Int(param!) else { usage() }
        timeout = t
    case "u":
        guard param != nil, let p = UInt16(param!) else { usage() }
        listenPort = p
        do {
            let background = DispatchQueue.global(qos: .userInteractive)
            listen = try UDPSocket(bind: "0.0.0.0", port: p)
            listen?.onRead(queue: background) {
                guard let content = $0.0, content.count > 1 else { return }
                let lines = content.split(separator: 10, omittingEmptySubsequences: true)
                guard !lines.isEmpty else { return }
                for entry in lines {
                    let nullTerminated = entry.map { CChar($0) } + [0]
                    guard let cmd = nullTerminated.withUnsafeBufferPointer({ String(validatingUTF8: $0.baseAddress!) }) else { return }
                    DispatchQueue.main.async {
                        guard let (response, done) = orvibo?.handle(command: cmd) else { return }
                        if let status = response { output(status) }
                        if done { orvibo?.unsubscribeAndExit() }
                    }
                }
            }
        } catch SocketError.error(let errno) {
            fatalError("Cannot create UDP listen socket for port \(p): \(String(cString: strerror(errno)))")
        } catch {
            fatalError("Unknown error trying to create UDP listen socket for port \(p): \(String(cString: strerror(errno)))")
        }
    case "?": fallthrough
    default:
        usage()
    }
}
guard CommandLine.arguments.count == Int(optind) + 1 else { usage() }

let mac = CommandLine.arguments.last!
orvibo = Orvibo(mac)
guard let socket = orvibo else {
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
    let background = DispatchQueue.global(qos: .userInteractive)
    background.async {
        var line = readLine()
        var finished = false
        while let cmd = line {
            DispatchQueue.main.sync {
                let (response, done) = socket.handle(command: cmd)
                if let status = response { output(status) }
                finished = done
            }
            guard !finished else { break }
            line = readLine()
        }
        if finished || broadcastPort == nil {
            DispatchQueue.main.async {
                socket.unsubscribeAndExit()
            }
        }
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
