///|
/// BiDi codec tests

///|
test "parse_incoming parses valid success response" {
  let parsed = parse_incoming(
    "{\"id\":1,\"type\":\"success\",\"result\":{\"ok\":true}}",
  )
  match parsed {
    Ok(Response(resp)) => {
      assert_eq(resp.id, 1)
      match resp.result {
        Some(Object(_)) => ()
        _ => assert_true(false)
      }
    }
    _ => assert_true(false)
  }
}

///|
test "parse_incoming rejects success response without result" {
  let parsed = parse_incoming("{\"id\":1,\"type\":\"success\"}")
  match parsed {
    Err(message) => assert_eq(message, "Missing result field")
    _ => assert_true(false)
  }
}

///|
test "parse_incoming rejects error response without error code" {
  let parsed = parse_incoming(
    "{\"id\":1,\"type\":\"error\",\"message\":\"boom\"}",
  )
  match parsed {
    Err(message) => assert_eq(message, "Missing error field")
    _ => assert_true(false)
  }
}

///|
test "parse_incoming rejects error response without message" {
  let parsed = parse_incoming(
    "{\"id\":1,\"type\":\"error\",\"error\":\"invalid argument\"}",
  )
  match parsed {
    Err(message) => assert_eq(message, "Missing message field")
    _ => assert_true(false)
  }
}

///|
test "parse_incoming rejects non-integer id" {
  let parsed = parse_incoming("{\"id\":1.5,\"type\":\"success\",\"result\":{}}")
  match parsed {
    Err(message) => assert_eq(message, "Invalid id field")
    _ => assert_true(false)
  }
}

///|
test "parse_incoming rejects event with non-object params" {
  let parsed = parse_incoming(
    "{\"type\":\"event\",\"method\":\"log.entryAdded\",\"params\":1}",
  )
  match parsed {
    Err(message) => assert_eq(message, "Invalid params field")
    _ => assert_true(false)
  }
}
