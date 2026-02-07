///|
/// BiDi E2E tests (JS WebSocket)

///|
extern "js" fn ws_server_start(port : Int) -> @js_async.Promise[Int] =
  #| async (port) => {
  #|   const http = require('http');
  #|   const crypto = require('crypto');
  #|   const { chromium } = require('playwright');
  #|   if (typeof WebSocket === 'undefined') {
  #|     try { globalThis.WebSocket = require('undici').WebSocket; } catch (_) {}
  #|   }
  #|   const state = {
  #|     server: null,
  #|     browser: null,
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
  #|   const handleMessage = async (socket, msg) => {
  #|     let req = null;
  #|     try { req = JSON.parse(msg); } catch (_) { return; }
  #|     const id = req.id;
  #|     const method = req.method;
  #|     const params = req.params || {};
  #|     const respond = (result) => sendJson(socket, { id, type: 'success', result });
  #|     const findContext = () => {
  #|       const contextId = (params.target && params.target.context) || params.context || null;
  #|       if (!contextId) return null;
  #|       return state.contexts.get(contextId) || null;
  #|     };
  #|     if (method === 'session.status') {
  #|       respond({ ready: true, message: 'ok' });
  #|       return;
  #|     }
  #|     if (method === 'session.new') {
  #|       respond({ sessionId: 'sid-' + id, capabilities: { browserName: 'chromium' } });
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
  #|       for (const [cid, info] of state.contexts) {
  #|         try { await info.browserContext.close(); } catch (_) {}
  #|         state.contexts.delete(cid);
  #|       }
  #|       if (state.browser) {
  #|         try { await state.browser.close(); } catch (_) {}
  #|         state.browser = null;
  #|       }
  #|       respond({});
  #|       return;
  #|     }
  #|     if (method === 'browsingContext.create') {
  #|       const idStr = 'ctx-' + state.nextContextId++;
  #|       const userContext = params.userContext || 'default';
  #|       const browserContext = await state.browser.newContext();
  #|       const page = await browserContext.newPage();
  #|       state.contexts.set(idStr, { url: page.url(), userContext, browserContext, page });
  #|       respond({ context: idStr });
  #|       return;
  #|     }
  #|     if (method === 'browsingContext.reload') {
  #|       const info = findContext();
  #|       if (info) {
  #|         try { await info.page.reload({ waitUntil: 'load' }); } catch (_) {}
  #|         info.url = info.page.url();
  #|       }
  #|       respond({});
  #|       return;
  #|     }
  #|     if (method === 'browsingContext.close') {
  #|       const contextId = params.context || null;
  #|       if (contextId && state.contexts.has(contextId)) {
  #|         const info = state.contexts.get(contextId);
  #|         try { await info.browserContext.close(); } catch (_) {}
  #|         state.contexts.delete(contextId);
  #|       }
  #|       respond({});
  #|       return;
  #|     }
  #|     if (method === 'browsingContext.getTree') {
  #|       const contexts = [];
  #|       for (const [cid, info] of state.contexts.entries()) {
  #|         contexts.push({
  #|           context: cid,
  #|           url: info.page ? info.page.url() : info.url,
  #|           userContext: info.userContext,
  #|         });
  #|       }
  #|       respond({ contexts });
  #|       return;
  #|     }
  #|     if (method === 'browsingContext.navigate') {
  #|       const contextId = params.context || null;
  #|       const url = params.url || '';
  #|       const info = contextId ? state.contexts.get(contextId) : null;
  #|       if (info && info.page) {
  #|         const wait = params.wait || 'complete';
  #|         const waitUntil = wait === 'interactive' ? 'domcontentloaded' : 'load';
  #|         try { await info.page.goto(url, { waitUntil }); } catch (_) {}
  #|         info.url = info.page.url();
  #|       }
  #|       sendEvent(socket, 'browsingContext.load', { context: contextId });
  #|       respond({ navigation: 'nav-' + id, url: info ? info.url : url });
  #|       return;
  #|     }
  #|     if (method === 'browsingContext.captureScreenshot') {
  #|       const info = findContext();
  #|       let data = '';
  #|       if (info && info.page) {
  #|         const shot = await info.page.screenshot({ type: params.format === 'image/jpeg' ? 'jpeg' : 'png' });
  #|         data = shot.toString('base64');
  #|       }
  #|       respond({ data });
  #|       return;
  #|     }
  #|     if (method === 'browsingContext.locateNodes') {
  #|       const info = findContext();
  #|       let nodes = [];
  #|       const locator = params.locator || {};
  #|       if (info && info.page && locator.type === 'css' && typeof locator.value === 'string') {
  #|         let count = 0;
  #|         try { count = await info.page.$$eval(locator.value, (elements) => elements.length); } catch (_) {}
  #|         nodes = Array.from({ length: count }).map((_, i) => ({ sharedId: `node-${i}` }));
  #|       }
  #|       respond({ nodes });
  #|       return;
  #|     }
  #|     if (method === 'script.evaluate') {
  #|       const expr = params.expression || '';
  #|       const info = findContext();
  #|       let value = undefined;
  #|       if (info && info.page) {
  #|         try { value = await info.page.evaluate((source) => (0, eval)(source), expr); } catch (_) {}
  #|       } else {
  #|         try { value = (0, eval)(expr); } catch (_) {}
  #|       }
  #|       respond({ result: toRemoteValue(value) });
  #|       return;
  #|     }
  #|     if (method === 'script.callFunction') {
  #|       const decl = params.functionDeclaration || '';
  #|       const args = Array.isArray(params.arguments) ? params.arguments.map(fromRemoteValue) : [];
  #|       const info = findContext();
  #|       let value = undefined;
  #|       if (info && info.page) {
  #|         try {
  #|           value = await info.page.evaluate(
  #|             ({ declaration, values }) => {
  #|               let fn = null;
  #|               try { fn = (0, eval)(declaration); } catch (_) {}
  #|               try { return fn ? fn(...values) : undefined; } catch (_) { return undefined; }
  #|             },
  #|             { declaration: decl, values: args }
  #|           );
  #|         } catch (_) {}
  #|       } else {
  #|         let fn = null;
  #|         try { fn = (0, eval)(decl); } catch (_) {}
  #|         try { value = fn ? fn(...args) : undefined; } catch (_) {}
  #|       }
  #|       respond({ result: toRemoteValue(value) });
  #|       return;
  #|     }
  #|     if (method === 'script.addPreloadScript') {
  #|       respond({ script: 'preload-' + id });
  #|       return;
  #|     }
  #|     if (method === 'script.removePreloadScript') {
  #|       respond({});
  #|       return;
  #|     }
  #|     if (method === 'script.disown') {
  #|       respond({});
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
  #|       sendEvent(socket, 'network.beforeRequestSent', { request: { url: 'about:blank' } });
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
  #|       buf = decodeFrames(socket, Buffer.concat([buf, chunk]), (msg) => {
  #|         handleMessage(socket, msg).catch(() => {});
  #|       });
  #|     });
  #|     socket.on('close', () => {
  #|       state.sockets.delete(socket);
  #|     });
  #|   });
  #|   state.browser = await chromium.launch({ headless: true });
  #|   return await new Promise((resolve, reject) => {
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
  #| async () => {
  #|   const state = globalThis.__mbt_bidi_server;
  #|   if (!state || !state.server) return;
  #|   for (const sock of state.sockets) {
  #|     try { sock.end(); } catch (_) {}
  #|   }
  #|   await new Promise((resolve) => {
  #|     state.server.close(() => resolve());
  #|   });
  #|   if (state.browser) {
  #|     try { await state.browser.close(); } catch (_) {}
  #|   }
  #|   globalThis.__mbt_bidi_server = null;
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
  let page_url = "data:text/html,<title>mbt-e2e</title><body><h1 id='app'>ok</h1></body>"
  let nav = client.browsing_context_navigate(ctx, page_url)
  match nav {
    Ok(result) => assert_true(result.url.has_prefix("data:text/html,"))
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
        Some(nodes) => assert_true(nodes.length() >= 1)
        None => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
  let eval_result = client.script_evaluate("document.title", ctx)
  match eval_result {
    Ok(json) =>
      match e2e_get_object_field(json, "result") {
        Some(obj) =>
          match e2e_get_string_field(obj, "type") {
            Some("string") =>
              match e2e_get_string_field(obj, "value") {
                Some(v) => inspect(v, content="mbt-e2e")
                None => assert_true(false)
              }
            _ => assert_true(false)
          }
        None => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
  let screenshot = client.browsing_context_capture_screenshot(ctx)
  match screenshot {
    Ok(data) => assert_true(not(data.is_empty()))
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
