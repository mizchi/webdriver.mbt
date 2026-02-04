///|
/// JS WebSocket transport

///|
/// JS WebSocket state
pub struct JsWebSocketState {
  url : String
  socket_id : Ref[Int?]
  closed : Ref[Bool]
}

///|
/// Create JS WebSocket state
fn JsWebSocketState::new(url : String) -> JsWebSocketState {
  { url, socket_id: { val: None }, closed: { val: false } }
}

///|
///\n/// Open WebSocket and return id
extern "js" fn ws_open(url : String) -> @js_async.Promise[Int] =
  #| (url) => {
  #|   const g = globalThis;
  #|   if (!g.__mbt_ws) {
  #|     g.__mbt_ws = { nextId: 1, sockets: new Map() };
  #|   }
  #|   const id = g.__mbt_ws.nextId++;
  #|   const ws = new WebSocket(url);
  #|   const queue = [];
  #|   const waiters = [];
  #|   const entry = { ws, queue, waiters, closed: false };
  #|   g.__mbt_ws.sockets.set(id, entry);
  #|   ws.onmessage = (ev) => {
  #|     const msg = typeof ev.data === 'string' ? ev.data : (ev.data ? ev.data.toString() : '');
  #|     if (waiters.length > 0) {
  #|       waiters.shift()(msg);
  #|     } else {
  #|       queue.push(msg);
  #|     }
  #|   };
  #|   ws.onclose = () => {
  #|     entry.closed = true;
  #|     while (waiters.length > 0) {
  #|       waiters.shift()(null);
  #|     }
  #|   };
  #|   ws.onerror = () => {
  #|     // let recv waiters resolve with null on close
  #|   };
  #|   return new Promise((resolve, reject) => {
  #|     if (ws.readyState === 1) {
  #|       resolve(id);
  #|       return;
  #|     }
  #|     ws.addEventListener('open', () => resolve(id), { once: true });
  #|     ws.addEventListener('error', (e) => reject(e), { once: true });
  #|   });
  #| }

///|
/// Send WebSocket message
extern "js" fn ws_send(id : Int, message : String) =
  #| (id, message) => {
  #|   const g = globalThis;
  #|   const entry = g.__mbt_ws && g.__mbt_ws.sockets.get(id);
  #|   if (!entry) throw new Error('Socket not found');
  #|   if (entry.ws.readyState !== 1) throw new Error('Socket not open');
  #|   entry.ws.send(message);
  #| }

///|
/// Poll next message (resolves with null on close)
extern "js" fn ws_poll(id : Int) -> @js_async.Promise[String?] =
  #| (id) => {
  #|   const g = globalThis;
  #|   const entry = g.__mbt_ws && g.__mbt_ws.sockets.get(id);
  #|   if (!entry) throw new Error('Socket not found');
  #|   if (entry.queue.length > 0) return Promise.resolve(entry.queue.shift());
  #|   if (entry.closed) return Promise.resolve(null);
  #|   return new Promise((resolve) => {
  #|     entry.waiters.push(resolve);
  #|   });
  #| }

///|
/// Close WebSocket
extern "js" fn ws_close(id : Int) =
  #| (id) => {
  #|   const g = globalThis;
  #|   const entry = g.__mbt_ws && g.__mbt_ws.sockets.get(id);
  #|   if (!entry) return;
  #|   entry.closed = true;
  #|   try { entry.ws.close(); } catch (_) {}
  #|   g.__mbt_ws.sockets.delete(id);
  #| }

///|
/// Create JS WebSocket transport
pub fn Transport::websocket(url : String) -> Transport {
  JsWebSocket(JsWebSocketState::new(url))
}

///|
/// Ensure JS WebSocket is connected and return socket id
async fn ensure_js_connected(
  state : JsWebSocketState,
) -> Result[Int, TransportError] {
  if state.closed.val {
    return Err(Closed)
  }
  match state.socket_id.val {
    Some(id) => Ok(id)
    None => {
      let id = @js_async.Promise::wait(ws_open(state.url)) catch {
        err => return Err(NetworkError(message=err.to_string()))
      }
      state.socket_id.val = Some(id)
      Ok(id)
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
      match ensure_js_connected(state) {
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
      match ensure_js_connected(state) {
        Ok(id) => {
          ws_send(id, message)
          Ok(())
        }
        Err(e) => Err(e)
      }
    Custom(custom) => (custom.send)(message)
    Unsupported(err) => Err(err)
  }
}

///|
/// Receive next message
pub async fn Transport::recv(
  self : Transport,
) -> Result[String, TransportError] {
  match self {
    JsWebSocket(state) =>
      match ensure_js_connected(state) {
        Ok(id) => {
          let msg = @js_async.Promise::wait(ws_poll(id)) catch {
            err => return Err(NetworkError(message=err.to_string()))
          }
          match msg {
            Some(value) => Ok(value)
            None => {
              state.closed.val = true
              Err(Closed)
            }
          }
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
      match state.socket_id.val {
        Some(id) => ws_close(id)
        None => ()
      }
      state.closed.val = true
      Ok(())
    }
    Custom(custom) => (custom.close)()
    Unsupported(err) => Err(err)
  }
}
