//
//  command.swift
//  orvibo
//
//  Created by Rene Hexel on 5/1/17.
//  Copyright © 2017, 2019 Rene Hexel. All rights reserved.
//
import Foundation

public extension Orvibo {
    /// Parse and handle simple commands
    ///
    /// - Parameter command: "q", "on", "off", or "p"
    /// - Returns: response string and whether to exit the program
    func handle(command: String) -> (response: String?, done: Bool) {
        switch command.lowercased() {
        case "q": fallthrough
        case "quit":
            return (response: nil, done: true)
        case "on":
            guard setState(on: true) else { break }
            return (response: command, done: false)
        case "off":
            guard setState(on: false) else { break }
            return (response: command, done: false)
        case "p": fallthrough
        case "ping":
            let onOff = getStatus()
            return (response: onOff, done: false)
        default:
            return (response: "Unknown command '\(command)'", done: false)
        }
        return (response: nil, done: false)
    }

    /// Return the socket status as a string
    ///
    /// - Parameter status: the status to output (defaults to calling `getState()`)
    /// - Returns: "On" if the power has been determined to be on, "Off" otherwise
    func getStatus(_ status: Bool? = nil) -> String {
        let onOffStatus: Bool
        if let s = status { onOffStatus = s }
        else { onOffStatus = getState() }
        let onOff = onOffStatus ? "On" : "Off"
        return onOff
    }

    /// Unsubscribe and exit after 100 ms
    func unsubscribeAndExit() {
        unsubscribe()
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
            self.destroy()
            exit(EXIT_SUCCESS)
        }
    }
}
