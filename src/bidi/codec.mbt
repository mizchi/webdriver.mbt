///|
/// BiDi JSON codec

///|
/// Serialize request to JSON string
pub fn BidiRequest::to_json(self : BidiRequest) -> String {
  let obj : Map[String, Json] = {}
  obj["id"] = Json::number(self.id.to_double())
  obj["method"] = Json::string(self.method_name)
  match self.params {
    Some(p) => obj["params"] = p
    None => ()
  }
  Json::object(obj).stringify()
}

///|
/// Parse incoming message (response/event)
pub fn parse_incoming(json_str : String) -> Result[BidiIncoming, String] {
  let json = @json.parse(json_str) catch { _ => return Err("Invalid JSON") }
  match json {
    Object(map) =>
      match map.get("type") {
        Some(String("event")) => parse_event(map)
        Some(String("success")) => parse_response(map)
        Some(String("error")) => parse_response(map)
        Some(String(t)) => Err("Unknown message type: " + t)
        _ => Err("Missing type field")
      }
    _ => Err("Invalid JSON")
  }
}

///|
/// Parse response from JSON object map
fn parse_response(map : Map[String, Json]) -> Result[BidiIncoming, String] {
  let id = match map.get("id") {
    Some(Number(n, ..)) => n.to_int()
    _ => return Err("Missing id field")
  }
  let is_error = match map.get("type") {
    Some(String("error")) => true
    _ => false
  }
  if is_error {
    let error = match map.get("error") {
      Some(String(s)) => s
      _ => ""
    }
    let message = match map.get("message") {
      Some(String(s)) => s
      _ => ""
    }
    let stacktrace = match map.get("stacktrace") {
      Some(String(s)) => s
      _ => ""
    }
    let err : BidiError = { error, message, stacktrace }
    Ok(BidiIncoming::Response({ id, result: None, error: Some(err) }))
  } else {
    let result = map.get("result")
    Ok(BidiIncoming::Response({ id, result, error: None }))
  }
}

///|
/// Parse event from JSON object map
fn parse_event(map : Map[String, Json]) -> Result[BidiIncoming, String] {
  let method_name = match map.get("method") {
    Some(String(s)) => s
    _ => return Err("Missing method field")
  }
  let params = match map.get("params") {
    Some(p) => p
    None => Json::object({})
  }
  Ok(BidiIncoming::Event({ event_method: method_name, params }))
}

///|
/// JSON helper: get string field
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
/// JSON helper: get bool field
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
/// JSON helper: get object field
fn get_object_field(json : Json, key : String) -> Json? {
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
/// JSON helper: get array field
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
