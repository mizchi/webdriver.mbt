///|
fn make_mock_transport_spec(
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
fn get_string_field(json : Json, key : String) -> String? {
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
fn get_bool_field(json : Json, key : String) -> Bool? {
  match json {
    Object(map) =>
      match map.get(key) {
        Some(True) => Some(true)
        Some(False) => Some(false)
        _ => None
      }
    _ => None
  }
}

///|
fn get_number_field(json : Json, key : String) -> Double? {
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
fn get_object_field(json : Json, key : String) -> Json? {
  match json {
    Object(map) =>
      match map.get(key) {
        Some(Object(_)) as obj => obj
        _ => None
      }
    _ => None
  }
}

///|
fn get_array_field(json : Json, key : String) -> Array[Json]? {
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
test "locator css to_json" {
  let json = Locator::css("#app").to_json()
  assert_eq(get_string_field(json, "type"), Some("css"))
  assert_eq(get_string_field(json, "value"), Some("#app"))
}

///|
test "locator innerText to_json" {
  let json = Locator::inner_text(
    "Hello",
    match_type=InnerTextMatchType::full(),
    ignore_case=true,
  ).to_json()
  assert_eq(get_string_field(json, "type"), Some("innerText"))
  let value = get_object_field(json, "value").unwrap()
  assert_eq(get_string_field(value, "value"), Some("Hello"))
  assert_eq(get_string_field(value, "matchType"), Some("full"))
  assert_eq(get_bool_field(value, "ignoreCase"), Some(true))
}

///|
test "input action sequence pointer to_json" {
  let actions : Array[InputAction] = [
    InputAction::pointer_move(10.0, 20.0, origin=ActionOrigin::viewport()),
    InputAction::pointer_down(0),
    InputAction::pointer_up(0),
  ]
  let seq = ActionSequence::pointer("mouse-1", PointerType::mouse(), actions)
  let json = seq.to_json()
  assert_eq(get_string_field(json, "type"), Some("pointer"))
  assert_eq(get_string_field(json, "id"), Some("mouse-1"))
  let params = get_object_field(json, "parameters").unwrap()
  assert_eq(get_string_field(params, "pointerType"), Some("mouse"))
  let list = get_array_field(json, "actions").unwrap()
  assert_eq(list.length(), 3)
  assert_eq(get_string_field(list[0], "type"), Some("pointerMove"))
  assert_eq(get_number_field(list[0], "x"), Some(10.0))
  assert_eq(get_number_field(list[0], "y"), Some(20.0))
}

///|
test "remote value handle/sharedId to_json" {
  let handle_json = RemoteValue::handle("h-1").to_json()
  assert_eq(get_string_field(handle_json, "handle"), Some("h-1"))
  let shared_json = RemoteValue::shared_id("s-1").to_json()
  assert_eq(get_string_field(shared_json, "sharedId"), Some("s-1"))
}

///|
async test "browsingContext.locateNodes typed builds params" {
  let sent : Ref[Array[String]] = Ref::new([])
  let recv_queue : Ref[Array[String]] = Ref::new([
    "{\"id\":1,\"type\":\"success\",\"result\":{}}",
  ])
  let client = BidiClient::new(make_mock_transport_spec(sent, recv_queue))
  let locator = Locator::css("div.item")
  let result = client.browsing_context_locate_nodes_typed(
    "ctx-1",
    locator,
    max_node_count=5,
  )
  match result {
    Ok(_) => ()
    Err(_) => assert_true(false)
  }
  let sent_json = @json.parse(sent.val[0]) catch {
    _ => return assert_true(false)
  }
  assert_eq(
    get_string_field(sent_json, "method"),
    Some("browsingContext.locateNodes"),
  )
  let params = get_object_field(sent_json, "params").unwrap()
  assert_eq(get_string_field(params, "context"), Some("ctx-1"))
  assert_eq(get_number_field(params, "maxNodeCount"), Some(5.0))
  let locator_json = get_object_field(params, "locator").unwrap()
  assert_eq(get_string_field(locator_json, "type"), Some("css"))
  assert_eq(get_string_field(locator_json, "value"), Some("div.item"))
}

///|
async test "input.performActions typed builds params" {
  let sent : Ref[Array[String]] = Ref::new([])
  let recv_queue : Ref[Array[String]] = Ref::new([
    "{\"id\":1,\"type\":\"success\",\"result\":{}}",
  ])
  let client = BidiClient::new(make_mock_transport_spec(sent, recv_queue))
  let actions : Array[InputAction] = [
    InputAction::pointer_move(1.0, 2.0, origin=ActionOrigin::viewport()),
    InputAction::pointer_down(0),
    InputAction::pointer_up(0),
  ]
  let seqs : Array[ActionSequence] = [
    ActionSequence::pointer("mouse-1", PointerType::mouse(), actions),
  ]
  let result = client.input_perform_actions_typed(seqs)
  match result {
    Ok(_) => ()
    Err(_) => assert_true(false)
  }
  let sent_json = @json.parse(sent.val[0]) catch {
    _ => return assert_true(false)
  }
  assert_eq(get_string_field(sent_json, "method"), Some("input.performActions"))
  let params = get_object_field(sent_json, "params").unwrap()
  let list = get_array_field(params, "actions").unwrap()
  assert_eq(list.length(), 1)
  assert_eq(get_string_field(list[0], "type"), Some("pointer"))
}

///|
async test "script.callFunction typed builds handle/sharedId args" {
  let sent : Ref[Array[String]] = Ref::new([])
  let recv_queue : Ref[Array[String]] = Ref::new([
    "{\"id\":1,\"type\":\"success\",\"result\":{}}",
  ])
  let client = BidiClient::new(make_mock_transport_spec(sent, recv_queue))
  let args : Array[RemoteValue] = [
    RemoteValue::handle("h-1"),
    RemoteValue::shared_id("s-1"),
  ]
  let result = client.script_call_function_typed(
    "(a, b) => a",
    "ctx-1",
    arguments=args,
  )
  match result {
    Ok(_) => ()
    Err(_) => assert_true(false)
  }
  let sent_json = @json.parse(sent.val[0]) catch {
    _ => return assert_true(false)
  }
  let params = get_object_field(sent_json, "params").unwrap()
  let list = get_array_field(params, "arguments").unwrap()
  assert_eq(get_string_field(list[0], "handle"), Some("h-1"))
  assert_eq(get_string_field(list[1], "sharedId"), Some("s-1"))
}

///|
async test "network.addDataCollector typed builds params" {
  let sent : Ref[Array[String]] = Ref::new([])
  let recv_queue : Ref[Array[String]] = Ref::new([
    "{\"id\":1,\"type\":\"success\",\"result\":{}}",
  ])
  let client = BidiClient::new(make_mock_transport_spec(sent, recv_queue))
  let collector = NetworkDataCollector::new(["request", "response"], contexts=[
    "ctx-1",
  ])
  let result = client.network_add_data_collector_typed(collector)
  match result {
    Ok(_) => ()
    Err(_) => assert_true(false)
  }
  let sent_json = @json.parse(sent.val[0]) catch {
    _ => return assert_true(false)
  }
  assert_eq(
    get_string_field(sent_json, "method"),
    Some("network.addDataCollector"),
  )
  let params = get_object_field(sent_json, "params").unwrap()
  let data_types = get_array_field(params, "dataTypes").unwrap()
  assert_eq(data_types.length(), 2)
  let contexts = get_array_field(params, "contexts").unwrap()
  assert_eq(contexts.length(), 1)
}

///|
async test "browsingContext.getTree supports root/maxDepth options" {
  let sent : Ref[Array[String]] = Ref::new([])
  let recv_queue : Ref[Array[String]] = Ref::new([
    "{\"id\":1,\"type\":\"success\",\"result\":{\"contexts\":[]}}",
  ])
  let client = BidiClient::new(make_mock_transport_spec(sent, recv_queue))
  let result = client.browsing_context_get_tree(root="ctx-root", max_depth=2)
  match result {
    Ok(_) => ()
    Err(_) => assert_true(false)
  }
  let sent_json = @json.parse(sent.val[0]) catch {
    _ => return assert_true(false)
  }
  assert_eq(
    get_string_field(sent_json, "method"),
    Some("browsingContext.getTree"),
  )
  let params = get_object_field(sent_json, "params").unwrap()
  assert_eq(get_string_field(params, "root"), Some("ctx-root"))
  assert_eq(get_number_field(params, "maxDepth"), Some(2.0))
}

///|
async test "browsingContext.navigate validates wait value" {
  let sent : Ref[Array[String]] = Ref::new([])
  let recv_queue : Ref[Array[String]] = Ref::new([])
  let client = BidiClient::new(make_mock_transport_spec(sent, recv_queue))
  let result = client.browsing_context_navigate(
    "ctx-1",
    "https://example.com",
    wait="not-valid",
  )
  match result {
    Err(InvalidArgument(message~)) =>
      assert_eq(message, "Invalid wait value: not-valid")
    _ => assert_true(false)
  }
  assert_eq(sent.val.length(), 0)
}

///|
async test "browsingContext.captureScreenshot builds params and parses data" {
  let sent : Ref[Array[String]] = Ref::new([])
  let recv_queue : Ref[Array[String]] = Ref::new([
    "{\"id\":1,\"type\":\"success\",\"result\":{\"data\":\"abcd\"}}",
  ])
  let client = BidiClient::new(make_mock_transport_spec(sent, recv_queue))
  let result = client.browsing_context_capture_screenshot(
    "ctx-1",
    format="image/jpeg",
    quality=80,
  )
  match result {
    Ok(data) => assert_eq(data, "abcd")
    Err(_) => assert_true(false)
  }
  let sent_json = @json.parse(sent.val[0]) catch {
    _ => return assert_true(false)
  }
  assert_eq(
    get_string_field(sent_json, "method"),
    Some("browsingContext.captureScreenshot"),
  )
  let params = get_object_field(sent_json, "params").unwrap()
  assert_eq(get_string_field(params, "context"), Some("ctx-1"))
  assert_eq(get_string_field(params, "format"), Some("image/jpeg"))
  assert_eq(get_number_field(params, "quality"), Some(80.0))
}

///|
async test "script.addPreloadScript builds params and parses script id" {
  let sent : Ref[Array[String]] = Ref::new([])
  let recv_queue : Ref[Array[String]] = Ref::new([
    "{\"id\":1,\"type\":\"success\",\"result\":{\"script\":\"script-1\"}}",
  ])
  let client = BidiClient::new(make_mock_transport_spec(sent, recv_queue))
  let result = client.script_add_preload_script(
    "(() => 1)",
    arguments=[RemoteValue::number(1.0)],
    contexts=["ctx-1"],
    user_contexts=["default"],
    sandbox="main",
  )
  match result {
    Ok(script_id) => assert_eq(script_id, "script-1")
    Err(_) => assert_true(false)
  }
  let sent_json = @json.parse(sent.val[0]) catch {
    _ => return assert_true(false)
  }
  assert_eq(
    get_string_field(sent_json, "method"),
    Some("script.addPreloadScript"),
  )
  let params = get_object_field(sent_json, "params").unwrap()
  assert_eq(get_string_field(params, "functionDeclaration"), Some("(() => 1)"))
  assert_eq(get_string_field(params, "sandbox"), Some("main"))
  let contexts = get_array_field(params, "contexts").unwrap()
  assert_eq(contexts.length(), 1)
  let user_contexts = get_array_field(params, "userContexts").unwrap()
  assert_eq(user_contexts.length(), 1)
  let arguments = get_array_field(params, "arguments").unwrap()
  assert_eq(arguments.length(), 1)
}

///|
async test "script.removePreloadScript builds params" {
  let sent : Ref[Array[String]] = Ref::new([])
  let recv_queue : Ref[Array[String]] = Ref::new([
    "{\"id\":1,\"type\":\"success\",\"result\":{}}",
  ])
  let client = BidiClient::new(make_mock_transport_spec(sent, recv_queue))
  let result = client.script_remove_preload_script("script-1")
  match result {
    Ok(_) => ()
    Err(_) => assert_true(false)
  }
  let sent_json = @json.parse(sent.val[0]) catch {
    _ => return assert_true(false)
  }
  assert_eq(
    get_string_field(sent_json, "method"),
    Some("script.removePreloadScript"),
  )
  let params = get_object_field(sent_json, "params").unwrap()
  assert_eq(get_string_field(params, "script"), Some("script-1"))
}

///|
async test "script.disown builds params" {
  let sent : Ref[Array[String]] = Ref::new([])
  let recv_queue : Ref[Array[String]] = Ref::new([
    "{\"id\":1,\"type\":\"success\",\"result\":{}}",
  ])
  let client = BidiClient::new(make_mock_transport_spec(sent, recv_queue))
  let result = client.script_disown(
    ["h-1", "h-2"],
    context_id="ctx-1",
    sandbox="main",
  )
  match result {
    Ok(_) => ()
    Err(_) => assert_true(false)
  }
  let sent_json = @json.parse(sent.val[0]) catch {
    _ => return assert_true(false)
  }
  assert_eq(get_string_field(sent_json, "method"), Some("script.disown"))
  let params = get_object_field(sent_json, "params").unwrap()
  let handles = get_array_field(params, "handles").unwrap()
  assert_eq(handles.length(), 2)
  let target = get_object_field(params, "target").unwrap()
  assert_eq(get_string_field(target, "context"), Some("ctx-1"))
  assert_eq(get_string_field(target, "sandbox"), Some("main"))
}
