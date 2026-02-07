///|
/// Backend contract error
pub enum BackendError {
  InvalidArgument(message~ : String)
  NotFound(message~ : String)
} derive(Show, Eq)

///|
/// Backend capability flags
pub struct BackendCapabilities {
  navigation : Bool
  evaluate : Bool
  element_lookup : Bool
  input_actions : Bool
  screenshot : Bool
} derive(Show, Eq)

///|
/// Backend contract for protocol behavior
pub struct Backend {
  navigate : (String, String, String) -> Result[NavigationResult, BackendError]
  evaluate : (String, String, Bool) -> Result[Json, BackendError]
  locate_nodes : (String, Json, Int?) -> Result[
    Array[NodeReference],
    BackendError,
  ]
  perform_actions : (String?, Array[Json]) -> Result[Unit, BackendError]
  release_actions : (String?) -> Result[Unit, BackendError]
  capture_screenshot : (String, String?) -> Result[String, BackendError]
  capabilities : () -> BackendCapabilities
}

///|
/// Create backend contract object
pub fn Backend::new(
  navigate : (String, String, String) -> Result[NavigationResult, BackendError],
  evaluate : (String, String, Bool) -> Result[Json, BackendError],
  locate_nodes : (String, Json, Int?) -> Result[
    Array[NodeReference],
    BackendError,
  ],
  perform_actions : (String?, Array[Json]) -> Result[Unit, BackendError],
  release_actions : (String?) -> Result[Unit, BackendError],
  capture_screenshot : (String, String?) -> Result[String, BackendError],
  capabilities : () -> BackendCapabilities,
) -> Backend {
  {
    navigate,
    evaluate,
    locate_nodes,
    perform_actions,
    release_actions,
    capture_screenshot,
    capabilities,
  }
}

///|
/// In-memory backend state
pub struct InMemoryBackendState {
  mut next_navigation_id : Int
  contexts : Map[String, String]
  action_log : Array[String]
}

///|
/// Minimal in-memory backend
pub struct InMemoryBackend {
  state : Ref[InMemoryBackendState]
}

///|
/// Create in-memory backend
pub fn InMemoryBackend::new(
  initial_contexts? : Array[String],
) -> InMemoryBackend {
  let contexts : Map[String, String] = {}
  let context_ids = match initial_contexts {
    Some(values) => values
    None => ["ctx-1"]
  }
  for context_id in context_ids {
    contexts[context_id] = "about:blank"
  }
  { state: Ref::new({ next_navigation_id: 1, contexts, action_log: [] }) }
}

///|
/// Export in-memory backend as contract
pub fn InMemoryBackend::to_backend(self : InMemoryBackend) -> Backend {
  let navigate = fn(
    context_id : String,
    url : String,
    _wait : String,
  ) -> Result[NavigationResult, BackendError] {
    if context_id.is_empty() {
      return Err(InvalidArgument(message="context must not be empty"))
    }
    if url.is_empty() {
      return Err(InvalidArgument(message="url must not be empty"))
    }
    if not(self.state.val.contexts.contains(context_id)) {
      return Err(NotFound(message="context not found: " + context_id))
    }
    let nav_id = self.state.val.next_navigation_id
    self.state.val.next_navigation_id = nav_id + 1
    self.state.val.contexts[context_id] = url
    Ok({ navigation: "nav-" + nav_id.to_string(), url })
  }
  let evaluate = fn(
    context_id : String,
    expression : String,
    _await_promise : Bool,
  ) -> Result[Json, BackendError] {
    if not(self.state.val.contexts.contains(context_id)) {
      return Err(NotFound(message="context not found: " + context_id))
    }
    if expression == "1 + 1" {
      return Ok(
        Json::object({
          "type": Json::string("number"),
          "value": Json::number(2.0),
        }),
      )
    }
    if expression == "document.title" {
      return Ok(
        Json::object({
          "type": Json::string("string"),
          "value": Json::string("mock-title"),
        }),
      )
    }
    Ok(
      Json::object({
        "type": Json::string("string"),
        "value": Json::string(expression),
      }),
    )
  }
  let locate_nodes = fn(
    context_id : String,
    locator : Json,
    max_node_count : Int?,
  ) -> Result[Array[NodeReference], BackendError] {
    if not(self.state.val.contexts.contains(context_id)) {
      return Err(NotFound(message="context not found: " + context_id))
    }
    let node_count = match max_node_count {
      Some(count) =>
        if count <= 0 {
          return Err(
            InvalidArgument(message="maxNodeCount must be greater than 0"),
          )
        } else {
          count
        }
      None => 1
    }
    let locator_type = match get_json_string(locator, "type") {
      Some(value) => value
      None => return Err(InvalidArgument(message="locator.type is required"))
    }
    if locator_type == "css" || locator_type == "xpath" {
      match get_json_string(locator, "value") {
        Some(_) => ()
        None =>
          return Err(
            InvalidArgument(
              message="locator.value must be a string for " +
                locator_type +
                " locator",
            ),
          )
      }
    }
    let nodes : Array[NodeReference] = []
    for i in 0..<node_count {
      nodes.push({ handle: None, shared_id: Some("node-" + i.to_string()) })
    }
    Ok(nodes)
  }
  let perform_actions = fn(
    context_id : String?,
    actions : Array[Json],
  ) -> Result[Unit, BackendError] {
    if actions.length() == 0 {
      return Err(InvalidArgument(message="actions must not be empty"))
    }
    let context_label = match context_id {
      Some(id) => id
      None => "global"
    }
    self.state.val.action_log.push(
      "perform:" + context_label + ":" + actions.length().to_string(),
    )
    Ok(())
  }
  let release_actions = fn(context_id : String?) -> Result[Unit, BackendError] {
    let context_label = match context_id {
      Some(id) => id
      None => "global"
    }
    self.state.val.action_log.push("release:" + context_label)
    Ok(())
  }
  let capture_screenshot = fn(
    context_id : String,
    _format : String?,
  ) -> Result[String, BackendError] {
    if not(self.state.val.contexts.contains(context_id)) {
      return Err(NotFound(message="context not found: " + context_id))
    }
    Ok("mock-screenshot:" + context_id)
  }
  let capabilities = fn() -> BackendCapabilities {
    {
      navigation: true,
      evaluate: true,
      element_lookup: true,
      input_actions: true,
      screenshot: true,
    }
  }
  Backend::new(
    navigate, evaluate, locate_nodes, perform_actions, release_actions, capture_screenshot,
    capabilities,
  )
}

///|
/// Snapshot helper for in-memory contexts
pub fn InMemoryBackend::get_context_url(
  self : InMemoryBackend,
  context_id : String,
) -> String? {
  self.state.val.contexts.get(context_id)
}

///|
/// Snapshot helper for in-memory action history size
pub fn InMemoryBackend::action_log_length(self : InMemoryBackend) -> Int {
  self.state.val.action_log.length()
}

///|
fn get_json_string(json : Json, key : String) -> String? {
  match json {
    Object(map) =>
      match map.get(key) {
        Some(String(value)) => Some(value)
        _ => None
      }
    _ => None
  }
}
