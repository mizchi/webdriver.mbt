///|
/// WASM transport (unsupported)

///|
/// JS WebSocket state (wasm)
pub struct JsWebSocketState {
  url : String
}

///|
/// Create JS WebSocket state
fn JsWebSocketState::new(url : String) -> JsWebSocketState {
  { url, }
}

///|
/// Create WebSocket transport
pub fn Transport::websocket(url : String) -> Transport {
  JsWebSocket(JsWebSocketState::new(url))
}

///|
fn wasm_not_supported() -> TransportError {
  let _ = NetworkError(message="")
  let _ = Closed
  NotSupported(message="websocket is not supported on wasm targets")
}

///|
async fn async_marker() -> Unit {
  let tasks : Array[async () -> Unit] = []
  let _ = @async.all(tasks[:])

}

///|
/// Connect transport
pub async fn Transport::connect(
  self : Transport,
) -> Result[Unit, TransportError] {
  async_marker()
  match self {
    JsWebSocket(_) => Err(wasm_not_supported())
    Custom(custom) => (custom.connect)()
    Unsupported(err) => Err(err)
  }
}

///|
/// Send message
pub async fn Transport::send(
  self : Transport,
  message : String,
) -> Result[Unit, TransportError] {
  async_marker()
  match self {
    JsWebSocket(_) => {
      let _ = message
      Err(wasm_not_supported())
    }
    Custom(custom) => (custom.send)(message)
    Unsupported(err) => Err(err)
  }
}

///|
/// Receive message
pub async fn Transport::recv(
  self : Transport,
) -> Result[String, TransportError] {
  async_marker()
  match self {
    JsWebSocket(_) => Err(wasm_not_supported())
    Custom(custom) => (custom.recv)()
    Unsupported(err) => Err(err)
  }
}

///|
/// Close transport
pub fn Transport::close(self : Transport) -> Result[Unit, TransportError] {
  match self {
    JsWebSocket(_) => Err(wasm_not_supported())
    Custom(custom) => (custom.close)()
    Unsupported(err) => Err(err)
  }
}
