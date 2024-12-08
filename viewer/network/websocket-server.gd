# From https://github.com/Faless/gd-websocket-nodes/blob/main/addons/godot-websocket-nodes/WebSocketServer.gd
extends Node
class_name WebSocketServer

signal message_received(peer_id: int, message: Variant)
signal client_connected(peer_id: int)
signal client_disconnected(peer_id: int)

@export_range(0.5, 10.0, 0.1) var handshake_timeout: float = 10.0

class PendingPeer:
    extends RefCounted
    var connect_time: int
    var tcp: StreamPeerTCP
    var connection: StreamPeer
    var ws: WebSocketPeer

    func _init(_tcp: StreamPeerTCP) -> void:
        tcp = _tcp
        connection = _tcp
        connect_time = Time.get_ticks_msec()

var _tcp_server: TCPServer 
var _pending_peers: Array[PendingPeer]
var _peers: Dictionary

func _init() -> void:
    _tcp_server = TCPServer.new()
    _pending_peers = []
    _peers = {} 

func listen(port: int) -> int:
    if _tcp_server.is_listening():
        push_error("TCP server is already listening")
        return -1
    return _tcp_server.listen(port)

func stop() -> void:
    _tcp_server.stop()
    _pending_peers.clear()
    _peers.clear()

func send(peer_id: int, message: Variant) -> int:
    var type := typeof(message)
    if peer_id <= 0:
        # 0 = broadcast / negative = exclude
        for id in _peers:
            if id == -peer_id:
                continue
            if type == TYPE_STRING:
                _peers[id].send_text(message)
            else:
                _peers[id].put_packet(message)
        return OK

    if peer_id not in _peers:
        push_error("Unknown peer id: %d" % peer_id)
        return -1

    var socket := _peers[peer_id] as WebSocketPeer
    if type == TYPE_STRING:
        return socket.send_text(message)
    return socket.send(var_to_bytes(message))

func get_message(peer_id: int) -> Variant:
    print("get message")
    if peer_id not in _peers:
        push_error("Unknown peer id: %d" % peer_id)
        return null
    
    var socket := _peers[peer_id] as WebSocketPeer
    if socket.get_available_packet_count() < 1:
        return null

    var packet := socket.get_packet()
    if socket.was_string_packet():
        return packet.get_string_from_utf8()
    return bytes_to_var(packet)

func has_message(peer_id: int) -> bool:
    if peer_id not in _peers:
        push_error("Unknown peer id: %d" % peer_id)
        return false

    return _peers[peer_id].get_available_packet_count() > 0

func _create_peer() -> WebSocketPeer:
    var ws := WebSocketPeer.new()
    ws.inbound_buffer_size = 2 << 24
    ws.outbound_buffer_size = 2 << 24
    return ws

func _connect_pending(p: PendingPeer) -> bool:
    if p.ws != null:
        p.ws.poll()

        var state := p.ws.get_ready_state()
        if state == WebSocketPeer.STATE_OPEN:
            var id := randi_range(2, 1 << 30)
            _peers[id] = p.ws
            client_connected.emit(id)
            return true
        elif state != WebSocketPeer.STATE_CONNECTING:
            return true
        return false
    elif p.tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED:
        return true
    else:
        p.ws = _create_peer()
        p.ws.accept_stream(p.tcp)
        return false

func poll() -> void:
    if not _tcp_server.is_listening():
        return

    while _tcp_server.is_connection_available():
        var conn := _tcp_server.take_connection()
        if conn == null:
            push_error("conn should not be null")
            return

        _pending_peers.append(PendingPeer.new(conn))

    var to_remove := []
    for p in _pending_peers:
        if not _connect_pending(p):
            if p.connect_time + (handshake_timeout * 1000) < Time.get_ticks_msec():
                print("TIMED OUT")
                to_remove.append(p)
            continue
        to_remove.append(p)

    for r in to_remove:
        _pending_peers.erase(r)
    to_remove.clear()

    for id in _peers:
        var p := _peers[id] as WebSocketPeer
        # p.get_available_packet_count()
        p.poll()
        if p.get_ready_state() != WebSocketPeer.STATE_OPEN:
            client_disconnected.emit(id)
            to_remove.append(id)
            continue
        while p.get_available_packet_count():
            message_received.emit(id, get_message(id))

    for r in to_remove:
        _peers.erase(r)

    to_remove.clear()

func _process(_delta: float) -> void:
    poll()
