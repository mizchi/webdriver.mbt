///|
/// Transport types

///|
/// Custom transport hooks (sync)
pub struct CustomTransport {
  connect : () -> Result[Unit, TransportError]
  send : (String) -> Result[Unit, TransportError]
  recv : () -> Result[String, TransportError]
  close : () -> Result[Unit, TransportError]
}

///|
/// Create custom transport
pub fn CustomTransport::new(
  connect : () -> Result[Unit, TransportError],
  send : (String) -> Result[Unit, TransportError],
  recv : () -> Result[String, TransportError],
  close : () -> Result[Unit, TransportError],
) -> CustomTransport {
  { connect, send, recv, close }
}

///|
/// Transport (JS WebSocket / Custom / Unsupported)
pub enum Transport {
  JsWebSocket(JsWebSocketState)
  Custom(CustomTransport)
  Unsupported(TransportError)
}

///|
/// Create custom transport wrapper
pub fn Transport::custom(custom : CustomTransport) -> Transport {
  Custom(custom)
}

///|
/// Create unsupported transport
pub fn Transport::unsupported(message : String) -> Transport {
  Unsupported(NotSupported(message~))
}
