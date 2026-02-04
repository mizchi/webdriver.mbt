///|
/// Native transport (async/websocket)

///|
/// JS WebSocket state (native)
pub struct JsWebSocketState {
  url : String
  conn : Ref[@websocket.Conn?]
  closed : Ref[Bool]
}

///|
/// Create JS WebSocket state
fn JsWebSocketState::new(url : String) -> JsWebSocketState {
  { url, conn: { val: None }, closed: { val: false } }
}

///|
/// Create WebSocket transport
pub fn Transport::websocket(url : String) -> Transport {
  JsWebSocket(JsWebSocketState::new(url))
}

///|
/// Ensure native connection
async fn ensure_native_connected(
  state : JsWebSocketState,
) -> Result[@websocket.Conn, TransportError] {
  if state.closed.val {
    return Err(Closed)
  }
  match state.conn.val {
    Some(conn) => Ok(conn)
    None => {
      let conn = @websocket.Conn::connect(state.url) catch {
        err => return Err(NetworkError(message=err.to_string()))
      }
      state.conn.val = Some(conn)
      Ok(conn)
    }
  }
}

///|
/// Connect transport
pub async fn Transport::connect(
  self : Transport,
) -> Result[Unit, TransportError] {
  match self {
    JsWebSocket(state) =>
      match ensure_native_connected(state) {
        Ok(_) => Ok(())
        Err(e) => Err(e)
      }
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
  match self {
    JsWebSocket(state) =>
      match ensure_native_connected(state) {
        Ok(conn) =>
          try {
            conn.send_text(message)
            Ok(())
          } catch {
            err => Err(NetworkError(message=err.to_string()))
          }
        Err(e) => Err(e)
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
  match self {
    JsWebSocket(state) =>
      match ensure_native_connected(state) {
        Ok(conn) =>
          try {
            let msg = conn.recv()
            let text = msg.read_all().text()
            Ok(text)
          } catch {
            err => Err(NetworkError(message=err.to_string()))
          }
        Err(e) => Err(e)
      }
    Custom(custom) => (custom.recv)()
    Unsupported(err) => Err(err)
  }
}

///|
/// Close transport
pub fn Transport::close(self : Transport) -> Result[Unit, TransportError] {
  match self {
    JsWebSocket(state) => {
      match state.conn.val {
        Some(conn) => conn.close()
        None => ()
      }
      state.closed.val = true
      Ok(())
    }
    Custom(custom) => (custom.close)()
    Unsupported(err) => Err(err)
  }
}
