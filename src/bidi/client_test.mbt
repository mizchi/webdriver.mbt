///|
/// BiDi client tests

///|
fn make_mock_transport(
  sent : Ref[Array[String]],
  recv_queue : Ref[Array[String]],
) -> Transport {
  let connect = fn() -> Result[Unit, TransportError] { Ok(()) }
  let send = fn(message : String) -> Result[Unit, TransportError] {
    sent.val.push(message)
    Ok(())
  }
  let recv = fn() -> Result[String, TransportError] {
    if recv_queue.val.length() == 0 {
      Ok("{\"id\":0,\"type\":\"success\",\"result\":{}}")
    } else {
      let head = recv_queue.val.remove(0)
      Ok(head)
    }
  }
  let close = fn() -> Result[Unit, TransportError] { Ok(()) }
  Transport::custom(CustomTransport::new(connect, send, recv, close))
}

///|
fn test_get_string_field(json : Json, key : String) -> String? {
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
fn test_get_int_field(json : Json, key : String) -> Int? {
  match json {
    Object(map) =>
      match map.get(key) {
        Some(Number(n, ..)) => Some(n.to_int())
        _ => None
      }
    _ => None
  }
}

///|
fn test_get_object_field(json : Json, key : String) -> Json? {
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
fn test_get_array_field(json : Json, key : String) -> Array[Json]? {
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
async test "session.status returns parsed result" {
  let sent : Ref[Array[String]] = { val: [] }
  let recv_queue : Ref[Array[String]] = {
    val: [
      "{\"id\":1,\"type\":\"success\",\"result\":{\"ready\":true,\"message\":\"ok\"}}",
    ],
  }
  let transport = make_mock_transport(sent, recv_queue)
  let client = BidiClient::new(transport)
  let status = client.session_status()
  match status {
    Ok(s) => {
      assert_true(s.ready)
      inspect(s.message, content="Some(\"ok\")")
    }
    Err(_) => assert_true(false)
  }
  let req_json = @json.parse(sent.val[0]) catch { _ => Json::null() }
  inspect(
    test_get_string_field(req_json, "method"),
    content="Some(\"session.status\")",
  )
  inspect(test_get_int_field(req_json, "id"), content="Some(1)")
}

///|
async test "event is dispatched while waiting for response" {
  let sent : Ref[Array[String]] = { val: [] }
  let recv_queue : Ref[Array[String]] = {
    val: [
      "{\"type\":\"event\",\"method\":\"log.entryAdded\",\"params\":{}}", "{\"id\":1,\"type\":\"success\",\"result\":{}}",
    ],
  }
  let transport = make_mock_transport(sent, recv_queue)
  let client = BidiClient::new(transport)
  let captured : Ref[String?] = { val: None }
  client.on_event(fn(evt : BidiEvent) { captured.val = Some(evt.event_method) })
  let _ = client.send("session.status")
  inspect(captured.val, content="Some(\"log.entryAdded\")")
}

///|
async test "browsingContext.create builds params" {
  let sent : Ref[Array[String]] = { val: [] }
  let recv_queue : Ref[Array[String]] = {
    val: ["{\"id\":1,\"type\":\"success\",\"result\":{\"context\":\"ctx-1\"}}"],
  }
  let transport = make_mock_transport(sent, recv_queue)
  let client = BidiClient::new(transport)
  let result = client.browsing_context_create("tab")
  inspect(result, content="Ok(\"ctx-1\")")
  let req_json = @json.parse(sent.val[0]) catch { _ => Json::null() }
  let params = test_get_object_field(req_json, "params").unwrap_or(
    Json::object({}),
  )
  inspect(test_get_string_field(params, "type"), content="Some(\"tab\")")
}

///|
async test "request id increments" {
  let sent : Ref[Array[String]] = { val: [] }
  let recv_queue : Ref[Array[String]] = {
    val: [
      "{\"id\":1,\"type\":\"success\",\"result\":{\"ready\":true}}", "{\"id\":2,\"type\":\"success\",\"result\":{}}",
    ],
  }
  let transport = make_mock_transport(sent, recv_queue)
  let client = BidiClient::new(transport)
  let _ = client.session_status()
  let _ = client.session_subscribe(["browsingContext.load"])
  let req0 = @json.parse(sent.val[0]) catch { _ => Json::null() }
  let req1 = @json.parse(sent.val[1]) catch { _ => Json::null() }
  inspect(test_get_int_field(req0, "id"), content="Some(1)")
  inspect(test_get_int_field(req1, "id"), content="Some(2)")
}

///|
async test "session.new parses sessionId" {
  let sent : Ref[Array[String]] = { val: [] }
  let recv_queue : Ref[Array[String]] = {
    val: [
      "{\"id\":1,\"type\":\"success\",\"result\":{\"sessionId\":\"sid-1\",\"capabilities\":{}}}",
    ],
  }
  let transport = make_mock_transport(sent, recv_queue)
  let client = BidiClient::new(transport)
  let result = client.session_new()
  match result {
    Ok(info) => {
      inspect(info.session_id, content="sid-1")
      match info.capabilities {
        Some(_) => assert_true(true)
        None => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
  let req_json = @json.parse(sent.val[0]) catch { _ => Json::null() }
  inspect(
    test_get_string_field(req_json, "method"),
    content="Some(\"session.new\")",
  )
}

///|
async test "session.unsubscribe builds params" {
  let sent : Ref[Array[String]] = { val: [] }
  let recv_queue : Ref[Array[String]] = {
    val: ["{\"id\":1,\"type\":\"success\",\"result\":{}}"],
  }
  let transport = make_mock_transport(sent, recv_queue)
  let client = BidiClient::new(transport)
  let _ = client.session_unsubscribe(["browsingContext.load"])
  let req_json = @json.parse(sent.val[0]) catch { _ => Json::null() }
  let params = test_get_object_field(req_json, "params").unwrap_or(
    Json::object({}),
  )
  let events = match test_get_array_field(params, "events") {
    Some(items) => items
    None => []
  }
  inspect(events.length(), content="1")
}

///|
async test "browsingContext.reload builds params" {
  let sent : Ref[Array[String]] = { val: [] }
  let recv_queue : Ref[Array[String]] = {
    val: ["{\"id\":1,\"type\":\"success\",\"result\":{}}"],
  }
  let transport = make_mock_transport(sent, recv_queue)
  let client = BidiClient::new(transport)
  let _ = client.browsing_context_reload("ctx-1")
  let req_json = @json.parse(sent.val[0]) catch { _ => Json::null() }
  let params = test_get_object_field(req_json, "params").unwrap_or(
    Json::object({}),
  )
  inspect(test_get_string_field(params, "context"), content="Some(\"ctx-1\")")
}

///|
async test "input.performActions builds params" {
  let sent : Ref[Array[String]] = { val: [] }
  let recv_queue : Ref[Array[String]] = {
    val: ["{\"id\":1,\"type\":\"success\",\"result\":{}}"],
  }
  let transport = make_mock_transport(sent, recv_queue)
  let client = BidiClient::new(transport)
  let actions : Array[Json] = [Json::object({ "type": Json::string("key") })]
  let _ = client.input_perform_actions(actions, context_id="ctx-1")
  let req_json = @json.parse(sent.val[0]) catch { _ => Json::null() }
  let params = test_get_object_field(req_json, "params").unwrap_or(
    Json::object({}),
  )
  let actions_json = match test_get_array_field(params, "actions") {
    Some(items) => items
    None => []
  }
  inspect(actions_json.length(), content="1")
  inspect(test_get_string_field(params, "context"), content="Some(\"ctx-1\")")
}

///|
async test "browser.getUserContexts parses list" {
  let sent : Ref[Array[String]] = { val: [] }
  let recv_queue : Ref[Array[String]] = {
    val: [
      "{\"id\":1,\"type\":\"success\",\"result\":{\"userContexts\":[{\"userContext\":\"default\"},{\"userContext\":\"user-1\"}]}}",
    ],
  }
  let transport = make_mock_transport(sent, recv_queue)
  let client = BidiClient::new(transport)
  let result = client.browser_get_user_contexts()
  match result {
    Ok(contexts) => {
      inspect(contexts.length(), content="2")
      inspect(contexts[0], content="default")
    }
    Err(_) => assert_true(false)
  }
}

///|
async test "network.setCacheBehavior builds params" {
  let sent : Ref[Array[String]] = { val: [] }
  let recv_queue : Ref[Array[String]] = {
    val: ["{\"id\":1,\"type\":\"success\",\"result\":{}}"],
  }
  let transport = make_mock_transport(sent, recv_queue)
  let client = BidiClient::new(transport)
  let _ = client.network_set_cache_behavior("default", contexts=[
    "ctx-1", "ctx-2",
  ])
  let req_json = @json.parse(sent.val[0]) catch { _ => Json::null() }
  let params = test_get_object_field(req_json, "params").unwrap_or(
    Json::object({}),
  )
  inspect(
    test_get_string_field(params, "cacheBehavior"),
    content="Some(\"default\")",
  )
  let contexts = match test_get_array_field(params, "contexts") {
    Some(items) => items
    None => []
  }
  inspect(contexts.length(), content="2")
}
