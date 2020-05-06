// Selsyn: IEEE C37.118 Synchrophasor Measurement and Grid Stability Controller
// Synchrophasor Network Streaming and Command Dispatcher.

import net
import net.udp as udp
import .frame show Frame
import .data_frame show DataFrame PhasorFormat
import .config_frame show ConfigFrame
import .header_frame show HeaderFrame
import .command_frame show CommandFrame

/**
Manages IEEE C37.118 client sessions, command processing, and real-time frame transmission.
*/
class SynchrophasorStreamer:
  id-code      /int
  config-frame /ConfigFrame
  header-frame /HeaderFrame
  is-streaming /bool := false
  subscribers  /List := []  // List of net.SocketAddress

  frames-sent  /int := 0
  frames-dropped /int := 0

  constructor --id-code/int --config-frame/ConfigFrame --header-frame/HeaderFrame:
    this.id-code = id-code
    this.config-frame = config-frame
    this.header-frame = header-frame

  /** Register or add a subscriber client address. */
  add-subscriber address/net.SocketAddress -> none:
    subscribers.do: | sub/net.SocketAddress |
      if sub.ip == address.ip and sub.port == address.port:
        return
    subscribers.add address

  /** Remove a subscriber client address. */
  remove-subscriber address/net.SocketAddress -> none:
    new-list := []
    subscribers.do: | sub/net.SocketAddress |
      if not (sub.ip == address.ip and sub.port == address.port):
        new-list.add sub
    subscribers = new-list

  /** Handle an incoming command packet and return appropriate response frames (if any). */
  handle-command bytes/ByteArray client-addr/net.SocketAddress? -> List:
    cmd := CommandFrame.decode bytes
    responses := []

    if cmd.command-word == CommandFrame.CMD-START-TRANSMISSION:
      is-streaming = true
      if client-addr: add-subscriber client-addr

    else if cmd.command-word == CommandFrame.CMD-STOP-TRANSMISSION:
      is-streaming = false
      if client-addr: remove-subscriber client-addr

    else if cmd.command-word == CommandFrame.CMD-SEND-CFG2:
      responses.add config-frame.encode

    else if cmd.command-word == CommandFrame.CMD-SEND-CFG1:
      responses.add config-frame.encode

    else if cmd.command-word == CommandFrame.CMD-SEND-HDR:
      responses.add header-frame.encode

    return responses

  /** Broadcast a data frame to all registered subscribers via the given UDP socket. */
  broadcast-data socket/udp.Socket frame/DataFrame -> none:
    if not is-streaming or subscribers.is-empty:
      return

    bytes := frame.encode --phasor-format=PhasorFormat.RECTANGULAR
    subscribers.do: | addr/net.SocketAddress |
      try:
        datagram := udp.Datagram bytes addr
        socket.send datagram
        frames-sent++
      finally:
        // Prevent individual subscriber network error from breaking the streaming loop
