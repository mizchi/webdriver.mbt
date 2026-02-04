///|
/// BiDi E2E tests (JS WebSocket)

///|
extern "js" fn ws_server_start(port : Int) -> @js_async.Promise[Int] =
  #| (port) => {
  #|   const http = require('http');
  #|   const crypto = require('crypto');
  #|   if (typeof WebSocket === 'undefined') {
  #|     try { globalThis.WebSocket = require('undici').WebSocket; } catch (_) {}
  #|   }
  #|   const state = {
  #|     server: null,
  #|     sockets: new Set(),
  #|     contexts: new Map(),
  #|     nextContextId: 1,
  #|     userContexts: new Set(['default']),
  #|     nextUserContextId: 1,
  #|     dataCollectors: new Set(),
  #|     nextCollectorId: 1,
  #|   };
  #|   const makeAccept = (key) => {
  #|     return crypto
  #|       .createHash('sha1')
  #|       .update(key + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11', 'binary')
  #|       .digest('base64');
  #|   };
  #|   const sendFrame = (socket, data) => {
  #|     const payload = Buffer.from(data, 'utf8');
  #|     const len = payload.length;
  #|     let header = null;
  #|     if (len < 126) {
  #|       header = Buffer.from([0x81, len]);
  #|     } else if (len < 65536) {
  #|       header = Buffer.from([0x81, 126, (len >> 8) & 0xff, len & 0xff]);
  #|     } else {
  #|       throw new Error('payload too large');
  #|     }
  #|     socket.write(Buffer.concat([header, payload]));
  #|   };
  #|   const sendJson = (socket, obj) => sendFrame(socket, JSON.stringify(obj));
  #|   const sendEvent = (socket, method, params) =>
  #|     sendJson(socket, { type: 'event', method, params });
  #|   const decodeFrames = (socket, buffer, onMessage) => {
  #|     let buf = buffer;
  #|     while (buf.length >= 2) {
  #|       const b1 = buf[0];
  #|       const b2 = buf[1];
  #|       const opcode = b1 & 0x0f;
  #|       let len = b2 & 0x7f;
  #|       let offset = 2;
  #|       if (len === 126) {
  #|         if (buf.length < 4) break;
  #|         len = buf.readUInt16BE(2);
  #|         offset = 4;
  #|       } else if (len === 127) {
  #|         // not supported
  #|         break;
  #|       }
  #|       const masked = (b2 & 0x80) !== 0;
  #|       let mask = null;
  #|       if (masked) {
  #|         if (buf.length < offset + 4) break;
  #|         mask = buf.slice(offset, offset + 4);
  #|         offset += 4;
  #|       }
  #|       if (buf.length < offset + len) break;
  #|       let payload = buf.slice(offset, offset + len);
  #|       if (masked && mask) {
  #|         const out = Buffer.alloc(payload.length);
  #|         for (let i = 0; i < payload.length; i++) {
  #|           out[i] = payload[i] ^ mask[i % 4];
  #|         }
  #|         payload = out;
  #|       }
  #|       buf = buf.slice(offset + len);
  #|       if (opcode === 1) {
  #|         onMessage(payload.toString('utf8'));
  #|       } else if (opcode === 8) {
  #|         socket.end();
  #|         break;
  #|       }
  #|     }
  #|     return buf;
  #|   };
  #|   const toRemoteValue = (value) => {
  #|     const t = typeof value;
  #|     if (t === 'number') return { type: 'number', value };
  #|     if (t === 'string') return { type: 'string', value };
  #|     if (t === 'boolean') return { type: 'boolean', value };
  #|     if (value === null) return { type: 'null' };
  #|     if (t === 'undefined') return { type: 'undefined' };
  #|     return { type: 'string', value: JSON.stringify(value) };
  #|   };
  #|   const fromRemoteValue = (arg) => {
  #|     if (!arg || typeof arg !== 'object') return undefined;
  #|     if (arg.type === 'number' || arg.type === 'string' || arg.type === 'boolean') return arg.value;
  #|     if (arg.type === 'null') return null;
  #|     return undefined;
  #|   };
  #|   const handleMessage = (socket, msg) => {
  #|     let req = null;
  #|     try { req = JSON.parse(msg); } catch (_) { return; }
  #|     const id = req.id;
  #|     const method = req.method;
  #|     const params = req.params || {};
  #|     const respond = (result) => sendJson(socket, { id, type: 'success', result });
  #|     if (method === 'session.status') {
  #|       respond({ ready: true, message: 'ok' });
  #|       return;
  #|     }
  #|     if (method === 'session.new') {
  #|       respond({ sessionId: 'sid-' + id, capabilities: { browserName: 'stub' } });
  #|       return;
  #|     }
  #|     if (method === 'session.subscribe') {
  #|       const first = Array.from(state.contexts.keys())[0] || null;
  #|       sendEvent(socket, 'browsingContext.load', { context: first });
  #|       respond({});
  #|       return;
  #|     }
  #|     if (method === 'session.unsubscribe') {
  #|       respond({});
  #|       return;
  #|     }
  #|     if (method === 'session.end') {
  #|       respond({});
  #|       return;
  #|     }
  #|     if (method === 'browser.getUserContexts') {
  #|       const userContexts = Array.from(state.userContexts).map((uc) => ({ userContext: uc }));
  #|       respond({ userContexts });
  #|       return;
  #|     }
  #|     if (method === 'browser.createUserContext') {
  #|       const idStr = 'user-' + state.nextUserContextId++;
  #|       state.userContexts.add(idStr);
  #|       respond({ userContext: idStr });
  #|       return;
  #|     }
  #|     if (method === 'browser.removeUserContext') {
  #|       if (params.userContext) {
  #|         state.userContexts.delete(params.userContext);
  #|       }
  #|       respond({});
  #|       return;
  #|     }
  #|     if (method === 'browser.close') {
  #|       respond({});
  #|       return;
  #|     }
  #|     if (method === 'browsingContext.create') {
  #|       const idStr = 'ctx-' + state.nextContextId++;
  #|       state.contexts.set(idStr, { url: 'about:blank', userContext: params.userContext || 'default' });
  #|       respond({ context: idStr });
  #|       return;
  #|     }
  #|     if (method === 'browsingContext.reload') {
  #|       respond({});
  #|       return;
  #|     }
  #|     if (method === 'browsingContext.close') {
  #|       if (params.context) {
  #|         state.contexts.delete(params.context);
  #|       }
  #|       respond({});
  #|       return;
  #|     }
  #|     if (method === 'browsingContext.getTree') {
  #|       const contexts = Array.from(state.contexts.entries()).map(([cid, info]) => ({
  #|         context: cid,
  #|         url: info.url,
  #|         userContext: info.userContext,
  #|       }));
  #|       respond({ contexts });
  #|       return;
  #|     }
  #|     if (method === 'browsingContext.navigate') {
  #|       const ctx = params.context;
  #|       const url = params.url || '';
  #|       if (ctx && state.contexts.has(ctx)) {
  #|         state.contexts.get(ctx).url = url;
  #|       }
  #|       respond({ navigation: 'nav-' + id, url });
  #|       return;
  #|     }
  #|     if (method === 'browsingContext.locateNodes') {
  #|       respond({ nodes: [] });
  #|       return;
  #|     }
  #|     if (method === 'script.evaluate') {
  #|       const expr = params.expression || '';
  #|       let value = undefined;
  #|       try { value = eval(expr); } catch (_) { value = undefined; }
  #|       respond({ result: toRemoteValue(value) });
  #|       return;
  #|     }
  #|     if (method === 'script.callFunction') {
  #|       const decl = params.functionDeclaration || '';
  #|       let fn = null;
  #|       try { fn = eval(decl); } catch (_) { fn = null; }
  #|       const args = Array.isArray(params.arguments) ? params.arguments.map(fromRemoteValue) : [];
  #|       let value = undefined;
  #|       try { value = fn ? fn(...args) : undefined; } catch (_) { value = undefined; }
  #|       respond({ result: toRemoteValue(value) });
  #|       return;
  #|     }
  #|     if (method === 'input.performActions') {
  #|       respond({});
  #|       return;
  #|     }
  #|     if (method === 'input.releaseActions') {
  #|       respond({});
  #|       return;
  #|     }
  #|     if (method === 'network.setCacheBehavior') {
  #|       respond({});
  #|       return;
  #|     }
  #|     if (method === 'network.addDataCollector') {
  #|       const idStr = 'collector-' + state.nextCollectorId++;
  #|       state.dataCollectors.add(idStr);
  #|       respond({ collector: idStr });
  #|       return;
  #|     }
  #|     respond({});
  #|   };
  #|   const server = http.createServer();
  #|   server.on('upgrade', (req, socket) => {
  #|     const key = req.headers['sec-websocket-key'];
  #|     if (!key) {
  #|       socket.destroy();
  #|       return;
  #|     }
  #|     const accept = makeAccept(key);
  #|     socket.write(
  #|       'HTTP/1.1 101 Switching Protocols\r\n' +
  #|       'Upgrade: websocket\r\n' +
  #|       'Connection: Upgrade\r\n' +
  #|       'Sec-WebSocket-Accept: ' + accept + '\r\n\r\n'
  #|     );
  #|     state.sockets.add(socket);
  #|     let buf = Buffer.alloc(0);
  #|     socket.on('data', (chunk) => {
  #|       buf = decodeFrames(socket, Buffer.concat([buf, chunk]), (msg) => handleMessage(socket, msg));
  #|     });
  #|     socket.on('close', () => {
  #|       state.sockets.delete(socket);
  #|     });
  #|   });
  #|   return new Promise((resolve, reject) => {
  #|     server.listen(port, '127.0.0.1', () => {
  #|       state.server = server;
  #|       globalThis.__mbt_bidi_server = state;
  #|       const addr = server.address();
  #|       resolve(addr.port);
  #|     });
  #|     server.on('error', reject);
  #|   });
  #| }

///|
extern "js" fn ws_server_stop() -> @js_async.Promise[Unit] =
  #| () => {
  #|   const state = globalThis.__mbt_bidi_server;
  #|   if (!state || !state.server) return Promise.resolve();
  #|   for (const sock of state.sockets) {
  #|     try { sock.end(); } catch (_) {}
  #|   }
  #|   return new Promise((resolve) => {
  #|     state.server.close(() => resolve());
  #|     globalThis.__mbt_bidi_server = null;
  #|   });
  #| }

///|
fn e2e_get_string_field(json : Json, key : String) -> String? {
  match json {
    Object(map) =>
      match map.get(key) {
        Some(String(s)) => Some(s)
        _ => None
      }
    _ => None
  }
}

///|
fn e2e_get_number_field(json : Json, key : String) -> Double? {
  match json {
    Object(map) =>
      match map.get(key) {
        Some(Number(n, ..)) => Some(n)
        _ => None
      }
    _ => None
  }
}

///|
fn e2e_get_object_field(json : Json, key : String) -> Json? {
  match json {
    Object(map) =>
      match map.get(key) {
        Some(Object(obj)) => Some(Json::object(obj))
        _ => None
      }
    _ => None
  }
}

///|
fn e2e_get_array_field(json : Json, key : String) -> Array[Json]? {
  match json {
    Object(map) =>
      match map.get(key) {
        Some(Array(items)) => Some(items)
        _ => None
      }
    _ => None
  }
}

///|
fn e2e_make_number_arg(value : Double) -> Json {
  Json::object({ "type": Json::string("number"), "value": Json::number(value) })
}

///|
async test "bidi e2e" {
  let port = @js_async.Promise::wait(ws_server_start(0))
  let url = "ws://127.0.0.1:" + port.to_string()
  let transport = Transport::websocket(url)
  let client = BidiClient::new(transport)
  let status = client.session_status()
  match status {
    Ok(s) => assert_true(s.ready)
    Err(_) => assert_true(false)
  }
  let session_info = client.session_new()
  match session_info {
    Ok(info) => assert_true(not(info.session_id.is_empty()))
    Err(_) => assert_true(false)
  }
  let user_context = match client.browser_create_user_context() {
    Ok(value) => value
    Err(_) => ""
  }
  assert_true(not(user_context.is_empty()))
  let contexts = client.browser_get_user_contexts()
  match contexts {
    Ok(list) => assert_true(list.length() >= 2)
    Err(_) => assert_true(false)
  }
  let ctx = match client.browsing_context_create("tab", user_context~) {
    Ok(v) => v
    Err(_) => ""
  }
  assert_true(not(ctx.is_empty()))
  let tree = client.browsing_context_get_tree()
  match tree {
    Ok(json) =>
      match e2e_get_array_field(json, "contexts") {
        Some(items) => assert_true(items.length() >= 1)
        None => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
  let nav = client.browsing_context_navigate(ctx, "https://example.com")
  match nav {
    Ok(result) => inspect(result.url, content="https://example.com")
    Err(_) => assert_true(false)
  }
  let _ = client.browsing_context_reload(ctx)
  let locate_nodes = client.browsing_context_locate_nodes(
    ctx,
    Json::object({ "type": Json::string("css"), "value": Json::string("body") }),
  )
  match locate_nodes {
    Ok(json) =>
      match e2e_get_array_field(json, "nodes") {
        Some(nodes) => assert_true(nodes.length() == 0)
        None => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
  let eval_result = client.script_evaluate("1 + 2", ctx)
  match eval_result {
    Ok(json) =>
      match e2e_get_object_field(json, "result") {
        Some(obj) =>
          match e2e_get_string_field(obj, "type") {
            Some("number") =>
              match e2e_get_number_field(obj, "value") {
                Some(v) => inspect(v.to_int(), content="3")
                None => assert_true(false)
              }
            _ => assert_true(false)
          }
        None => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
  let args : Array[Json] = [e2e_make_number_arg(6.0), e2e_make_number_arg(7.0)]
  let call_result = client.script_call_function(
    "(a, b) => a * b",
    ctx,
    arguments=args,
  )
  match call_result {
    Ok(json) =>
      match e2e_get_object_field(json, "result") {
        Some(obj) =>
          match e2e_get_string_field(obj, "type") {
            Some("number") =>
              match e2e_get_number_field(obj, "value") {
                Some(v) => inspect(v.to_int(), content="42")
                None => assert_true(false)
              }
            _ => assert_true(false)
          }
        None => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
  let events : Ref[Array[String]] = { val: [] }
  client.on_event(fn(evt : BidiEvent) { events.val.push(evt.event_method) })
  let _ = client.session_subscribe(["browsingContext.load"])
  assert_true(events.val.contains("browsingContext.load"))
  let _ = client.session_unsubscribe(["browsingContext.load"])
  let actions : Array[Json] = [
    Json::object({
      "type": Json::string("key"),
      "id": Json::string("keyboard"),
      "actions": Json::array([]),
    }),
  ]
  let _ = client.input_perform_actions(actions, context_id=ctx)
  let _ = client.input_release_actions(context_id=ctx)
  let _ = client.browsing_context_close(ctx)
  let _ = client.browser_remove_user_context(user_context)
  let _ = client.network_set_cache_behavior("default")
  let _ = client.network_add_data_collector()
  let _ = client.browser_close()
  let _ = client.session_end()
  client.close() |> ignore
  @js_async.Promise::wait(ws_server_stop())
}
