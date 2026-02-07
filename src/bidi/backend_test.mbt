///|
fn backend_get_string_field(json : Json, key : String) -> String? {
  match json {
    Object(map) =>
      match map.get(key) {
        Some(String(value)) => Some(value)
        _ => None
      }
    _ => None
  }
}

///|
fn backend_get_number_field(json : Json, key : String) -> Double? {
  match json {
    Object(map) =>
      match map.get(key) {
        Some(Number(value, ..)) => Some(value)
        _ => None
      }
    _ => None
  }
}

///|
test "in-memory backend reports capabilities" {
  let backend_impl = InMemoryBackend::new()
  let backend = backend_impl.to_backend()
  let caps = (backend.capabilities)()
  assert_true(caps.navigation)
  assert_true(caps.evaluate)
  assert_true(caps.element_lookup)
  assert_true(caps.input_actions)
  assert_true(caps.screenshot)
}

///|
test "in-memory backend navigate and evaluate update state" {
  let backend_impl = InMemoryBackend::new(initial_contexts=["ctx-1"])
  let backend = backend_impl.to_backend()
  let navigate_result = (backend.navigate)(
    "ctx-1", "https://example.com", "complete",
  )
  match navigate_result {
    Ok(nav) => {
      assert_eq(nav.navigation, "nav-1")
      assert_eq(nav.url, "https://example.com")
    }
    Err(_) => assert_true(false)
  }
  assert_eq(backend_impl.get_context_url("ctx-1"), Some("https://example.com"))
  let evaluate_result = (backend.evaluate)("ctx-1", "1 + 1", true)
  match evaluate_result {
    Ok(value) => {
      assert_eq(backend_get_string_field(value, "type"), Some("number"))
      assert_eq(backend_get_number_field(value, "value"), Some(2.0))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "in-memory backend locate nodes returns typed node references" {
  let backend_impl = InMemoryBackend::new(initial_contexts=["ctx-1"])
  let backend = backend_impl.to_backend()
  let result = (backend.locate_nodes)(
    "ctx-1",
    Locator::css("body").to_json(),
    Some(2),
  )
  match result {
    Ok(nodes) => {
      assert_eq(nodes.length(), 2)
      assert_eq(nodes[0].shared_id, Some("node-0"))
      assert_eq(nodes[0].handle, None)
      assert_eq(nodes[1].shared_id, Some("node-1"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "in-memory backend input/screenshot and errors" {
  let backend_impl = InMemoryBackend::new(initial_contexts=["ctx-1"])
  let backend = backend_impl.to_backend()
  let actions = [Json::object({ "type": Json::string("key") })]
  let perform = (backend.perform_actions)(Some("ctx-1"), actions)
  match perform {
    Ok(_) => ()
    Err(_) => assert_true(false)
  }
  let release = (backend.release_actions)(Some("ctx-1"))
  match release {
    Ok(_) => ()
    Err(_) => assert_true(false)
  }
  assert_eq(backend_impl.action_log_length(), 2)
  let screenshot = (backend.capture_screenshot)("ctx-1", Some("image/png"))
  match screenshot {
    Ok(data) => assert_eq(data, "mock-screenshot:ctx-1")
    Err(_) => assert_true(false)
  }
  let missing_context = (backend.navigate)(
    "ctx-404", "https://example.com", "complete",
  )
  match missing_context {
    Err(NotFound(message~)) => assert_eq(message, "context not found: ctx-404")
    _ => assert_true(false)
  }
}
