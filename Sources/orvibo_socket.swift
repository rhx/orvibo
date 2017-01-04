//
//  orvibo_socket.swift
//  orvibo
//
//  Created by Rene Hexel on 3/1/17.
//  Copyright © 2017 Rene Hexel. All rights reserved.
//
import Foundation
import COrvibo

#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

var sockets: [UnsafeMutablePointer<orvibo_socket>:Orvibo] = [:]

/// Stateful wrapper around orvibo_socket
public class Orvibo {
    /// Current stage of the socket
    ///
    /// - initial: not yet connected
    /// - discovering: discovering the given socket
    /// - discovered: socket was discovered
    /// - subscribing: subscribing to events
    /// - subscribed: subscribed to events
    /// - unsubscribing: unsubscribing from events
    ///
    public enum Stage {
        case initial
        case discovering
        case discovered
        case subscribing
        case subscribed
        case unsubscribing
        case destroyed
    }

    /// Reference to the underlying socket
    public let ptr: UnsafeMutablePointer<orvibo_socket>

    /// Current discovery/subscription stage of the socket
    public var stage: Stage = .initial

    /// Current state of the socket
    public var state: orvibo_state = ORVIBO_STATE_UNKNOWN

    /// Last known on/off status of the socket
    public var on: Bool {
        get { return state == ORVIBO_STATE_ON }
        set {
            let previousState = state
            state = newValue ? ORVIBO_STATE_ON : ORVIBO_STATE_OFF
            if state != previousState {
                let setState = newValue ? orvibo_socket_on : orvibo_socket_off
                _ = setState(ptr)
            }
        }
    }
    /// Get the status of the socket
    ///
    /// - Returns: `true` iff on
    @discardableResult
    public func getState() -> Bool {
        state = orvibo_socket_state(ptr)
        return on
    }

    /// Callback on socket discovery
    public func onDiscovery(_ callback: @escaping (Orvibo) -> Void = { _ in }) {
        notifyDiscovery = callback
    }
    var notifyDiscovery: (Orvibo) -> Void = { _ in }

    /// Callback on socket subscription
    public func onSubscription(_ callback: @escaping (Orvibo, Bool) -> Void = { _,_ in }) {
        notifySubscription = callback
    }
    var notifySubscription: (Orvibo, Bool) -> Void = { _,_ in }

    /// Callback on socket unsubscription
    public func onUnsubscription(_ callback: @escaping (Orvibo) -> Void = { _ in }) {
        notifyUnsubscription = callback
    }
    var notifyUnsubscription: (Orvibo) -> Void = { _ in }

    /// Set callback when switched on or off
    public func onStateChange(_ callback: @escaping (Orvibo, Bool) -> Void = { _,_ in }) {
        notifyStateChange = callback
    }
    var notifyStateChange: (Orvibo, Bool) -> Void = { _,_ in }

    /// IP address of the socket
    var ip: String { return String(cString: orvibo_socket_ip(ptr)) }

    /// Initialise from a given mac address
    public init?(_ mac: String) {
        guard let p = orvibo_socket_create(mac) else { return nil }
        ptr = p
        sockets[p] = self
        orvibo_start { (ptr: UnsafeMutablePointer<orvibo_socket>?, event: orvibo_event) in
            guard let ptr = ptr else {
                fputs("Spurious event from nil socket\n", stderr)
                return
            }
            guard let socket = sockets[ptr] else {
                fputs("\(String(cString: orvibo_event_string(event))) event from unassociated socket \(ptr)\n", stderr)
                return
            }
            switch event {
            case ORVIBO_EVENT_DISCOVER:
                let previousStage = socket.stage
                socket.stage = .discovered
                if previousStage == .discovering {
                    socket.notifyDiscovery(socket)
                }
            case ORVIBO_EVENT_SUBSCRIBE:
                socket.stage = .subscribed
                socket.getState()
                socket.notifySubscription(socket, socket.on)
            case ORVIBO_EVENT_UNSUBSCRIBE:
                socket.stage = .discovered
                socket.notifyUnsubscription(socket)
            case ORVIBO_EVENT_OFF:
                socket.state = ORVIBO_STATE_OFF
                socket.notifyStateChange(socket, false)
            case ORVIBO_EVENT_ON:
                socket.state = ORVIBO_STATE_ON
                socket.notifyStateChange(socket, true)
            default:
                fputs("Socket \(ptr) sent unknown event \(event): \(String(cString: orvibo_event_string(event)))\n", stderr)
                return
            }
        }
    }

    deinit {
        if stage != .destroyed {
            sockets[ptr] = nil
            orvibo_socket_destroy(ptr)
        }
    }

    /// Discover socket.
    /// Must be called prior to subscribing/unsubscribing and changing state.
    ///
    /// - Returns: `true` iff successfully broadcast
    @discardableResult
    public func discover() -> Bool {
        guard stage == .initial else { return false }
        stage = .discovering
        return orvibo_socket_discover(ptr)
    }

    /// Subscribe to socket.
    /// Must only be called when discovered.
    ///
    /// - Returns: `true` iff successfully broadcast
    @discardableResult
    public func subscribe() -> Bool {
        guard stage == .discovered else { return false }
        stage = .subscribing
        return orvibo_socket_subscribe(ptr)
    }

    /// Unsubscribe from socket.
    /// Must only be called when discovered.
    ///
    /// - Returns: `true` iff successfully broadcast
    @discardableResult
    public func unsubscribe() -> Bool {
        guard stage == .subscribed else { return false }
        stage = .unsubscribing
        return orvibo_socket_subscribe(ptr)
    }

    /// Destroy the reference to the given socket
    public func destroy() {
        guard stage != .destroyed else { return }
        stage = .destroyed
        sockets[ptr] = nil
        orvibo_socket_destroy(ptr)
    }
}
