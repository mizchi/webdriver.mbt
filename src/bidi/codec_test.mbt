///|
/// BiDi codec tests

///|
test "parse_request parses command request" {
  match
    parse_request(
      "{\"id\":7,\"method\":\"session.status\",\"params\":{\"ready\":true}}",
    ) {
    Ok(request) => {
      inspect(request.id, content="7")
      inspect(request.method_name, content="session.status")
      match request.params {
        Some(Object(map)) =>
          match map.get("ready") {
            Some(True) => ()
            _ => fail("expected ready parameter")
          }
        _ => fail("expected params object")
      }
    }
    Err(err) => fail(err)
  }
}

///|
test "parse_request rejects invalid command request" {
  match parse_request("{\"id\":1.5,\"method\":\"session.status\"}") {
    Err(message) => inspect(message, content="Invalid id field")
    _ => fail("expected invalid id error")
  }
  match parse_request("{\"id\":1}") {
    Err(message) => inspect(message, content="Missing method field")
    _ => fail("expected missing method error")
  }
}

///|
test "codec serializes success error and event envelopes" {
  let result : Map[String, Json] = {}
  result["ready"] = Json::boolean(true)
  let success = success_response_to_json(1, Some(Json::object(result)))
  assert_true(success.contains("\"type\":\"success\""))
  assert_true(success.contains("\"id\":1"))
  assert_true(success.contains("\"ready\":true"))

  let error = error_response_to_json(2, "invalid argument", "bad input")
  assert_true(error.contains("\"type\":\"error\""))
  assert_true(error.contains("\"error\":\"invalid argument\""))
  assert_true(error.contains("\"message\":\"bad input\""))
  assert_true(error.contains("\"stacktrace\":\"\""))

  let params : Map[String, Json] = {}
  params["context"] = Json::string("ctx-1")
  let event = event_to_json(
    "browsingContext.contextCreated",
    Json::object(params),
  )
  assert_true(event.contains("\"type\":\"event\""))
  assert_true(event.contains("\"method\":\"browsingContext.contextCreated\""))
  assert_true(event.contains("\"context\":\"ctx-1\""))
}

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
