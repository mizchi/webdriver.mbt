///|
/// BiDi client

///|
/// BiDi client state
pub struct BidiClient {
  transport : Transport
  mut next_id : Int
  mut connected : Bool
  mut has_subscription_filter : Bool
  pending : Map[Int, BidiResponse]
  event_handlers : Array[(BidiEvent) -> Unit]
  global_subscriptions : Map[String, Bool]
  context_subscriptions : Map[String, Map[String, Bool]]
}

///|
/// Create a new client
pub fn BidiClient::new(transport : Transport) -> BidiClient {
  {
    transport,
    next_id: 1,
    connected: false,
    has_subscription_filter: false,
    pending: {},
    event_handlers: [],
    global_subscriptions: {},
    context_subscriptions: {},
  }
}

///|
/// Register event handler
pub fn BidiClient::on_event(
  self : BidiClient,
  handler : (BidiEvent) -> Unit,
) -> Unit {
  self.event_handlers.push(handler)
}

///|
/// Register handler for a specific event method
pub fn BidiClient::on_event_method(
  self : BidiClient,
  event_method : String,
  handler : (BidiEvent) -> Unit,
) -> Unit {
  self.on_event(fn(evt : BidiEvent) {
    if evt.event_method == event_method {
      handler(evt)
    }
  })
}

///|
/// Register handler for session.* events
pub fn BidiClient::on_session_event(
  self : BidiClient,
  handler : (BidiEvent) -> Unit,
) -> Unit {
  self.on_event(fn(evt : BidiEvent) {
    if evt.event_method.has_prefix("session.") {
      handler(evt)
    }
  })
}

///|
/// Register handler for browser.* events
pub fn BidiClient::on_browser_event(
  self : BidiClient,
  handler : (BidiEvent) -> Unit,
) -> Unit {
  self.on_event(fn(evt : BidiEvent) {
    if evt.event_method.has_prefix("browser.") {
      handler(evt)
    }
  })
}

///|
/// Register handler for browsingContext.* events
pub fn BidiClient::on_browsing_context_event(
  self : BidiClient,
  handler : (BidiEvent) -> Unit,
) -> Unit {
  self.on_event(fn(evt : BidiEvent) {
    if evt.event_method.has_prefix("browsingContext.") {
      handler(evt)
    }
  })
}

///|
/// Register handler for script.* events
pub fn BidiClient::on_script_event(
  self : BidiClient,
  handler : (BidiEvent) -> Unit,
) -> Unit {
  self.on_event(fn(evt : BidiEvent) {
    if evt.event_method.has_prefix("script.") {
      handler(evt)
    }
  })
}

///|
/// Register handler for input.* events
pub fn BidiClient::on_input_event(
  self : BidiClient,
  handler : (BidiEvent) -> Unit,
) -> Unit {
  self.on_event(fn(evt : BidiEvent) {
    if evt.event_method.has_prefix("input.") {
      handler(evt)
    }
  })
}

///|
/// Register handler for network.* events
pub fn BidiClient::on_network_event(
  self : BidiClient,
  handler : (BidiEvent) -> Unit,
) -> Unit {
  self.on_event(fn(evt : BidiEvent) {
    if evt.event_method.has_prefix("network.") {
      handler(evt)
    }
  })
}

///|
/// Register handler for log.* events
pub fn BidiClient::on_log_event(
  self : BidiClient,
  handler : (BidiEvent) -> Unit,
) -> Unit {
  self.on_event(fn(evt : BidiEvent) {
    if evt.event_method.has_prefix("log.") {
      handler(evt)
    }
  })
}

///|
/// Register handler for log.entryAdded (optional level filter)
pub fn BidiClient::on_log_entry_added(
  self : BidiClient,
  level? : String,
  handler : (BidiEvent) -> Unit,
) -> Unit {
  self.on_log_event(fn(evt : BidiEvent) {
    if evt.event_method != "log.entryAdded" {
      return ()
    }
    match level {
      Some(expected) =>
        match get_string_field(evt.params, "level") {
          Some(actual) => if actual == expected { handler(evt) }
          None => ()
        }
      None => handler(evt)
    }
  })
}

///|
/// Connect transport
pub async fn BidiClient::connect(
  self : BidiClient,
) -> Result[Unit, ClientError] {
  if self.connected {
    return Ok(())
  }
  match self.transport.connect() {
    Ok(_) => {
      self.connected = true
      Ok(())
    }
    Err(e) => Err(Transport(e))
  }
}

///|
/// Close transport
pub fn BidiClient::close(self : BidiClient) -> Result[Unit, ClientError] {
  self.connected = false
  match self.transport.close() {
    Ok(_) => Ok(())
    Err(e) => Err(Transport(e))
  }
}

///|
/// Send raw request and await response
pub async fn BidiClient::send(
  self : BidiClient,
  method_name : String,
  params? : Json? = None,
) -> Result[Json, ClientError] {
  match self.connect() {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  let id = self.next_id
  self.next_id = self.next_id + 1
  let request : BidiRequest = { id, method_name, params }
  match self.transport.send(request.to_json()) {
    Ok(_) => ()
    Err(e) => return Err(Transport(e))
  }
  let response = self.wait_response(id)
  match response {
    Ok(resp) =>
      match resp.error {
        Some(err) => Err(ResponseError(error=err))
        None =>
          match resp.result {
            Some(result) => Ok(result)
            None => Ok(Json::object({}))
          }
      }
    Err(e) => Err(e)
  }
}

///|
/// Dispatch request through the domain router
pub async fn BidiClient::dispatch(
  self : BidiClient,
  domain : String,
  command : String,
  params? : Json? = None,
) -> Result[Json, ClientError] {
  if not(is_supported_domain_command(domain, command)) {
    return Err(unknown_command_error(domain, command))
  }
  self.send(domain + "." + command, params~)
}

///|
/// Session: status
pub async fn BidiClient::session_status(
  self : BidiClient,
) -> Result[SessionStatus, ClientError] {
  let result = self.dispatch("session", "status")
  match result {
    Ok(json) =>
      match get_bool_field(json, "ready") {
        Some(ready) => {
          let message = get_string_field(json, "message")
          Ok({ ready, message })
        }
        None => Err(ParseError(message="Missing ready field"))
      }
    Err(e) => Err(e)
  }
}

///|
/// Session: new
pub async fn BidiClient::session_new(
  self : BidiClient,
  capabilities? : Json? = None,
) -> Result[SessionInfo, ClientError] {
  match capabilities {
    Some(caps) =>
      match caps {
        Object(_) => ()
        _ =>
          return Err(
            invalid_argument_error("capabilities must be a JSON object"),
          )
      }
    None => ()
  }
  let result = match capabilities {
    Some(caps) => {
      let params : Map[String, Json] = {}
      params["capabilities"] = caps
      self.dispatch("session", "new", params=Some(Json::object(params)))
    }
    None => self.dispatch("session", "new")
  }
  match result {
    Ok(json) =>
      match get_string_field(json, "sessionId") {
        Some(session_id) => {
          let caps = get_object_field(json, "capabilities")
          Ok({ session_id, capabilities: caps })
        }
        None => Err(ParseError(message="Missing sessionId field"))
      }
    Err(e) => Err(e)
  }
}

///|
/// Session: subscribe
pub async fn BidiClient::session_subscribe(
  self : BidiClient,
  events : Array[String],
  contexts? : Array[String],
) -> Result[Unit, ClientError] {
  match validate_subscription_request(events, contexts) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  let json_events : Array[Json] = []
  for e in events {
    json_events.push(Json::string(e))
  }
  let params : Map[String, Json] = {}
  params["events"] = Json::array(json_events)
  match contexts {
    Some(context_ids) => {
      let json_contexts : Array[Json] = []
      for context_id in context_ids {
        json_contexts.push(Json::string(context_id))
      }
      params["contexts"] = Json::array(json_contexts)
    }
    None => ()
  }
  match
    self.dispatch("session", "subscribe", params=Some(Json::object(params))) {
    Ok(_) => {
      self.apply_subscribe(events, contexts)
      Ok(())
    }
    Err(e) => Err(e)
  }
}

///|
/// Session: unsubscribe
pub async fn BidiClient::session_unsubscribe(
  self : BidiClient,
  events : Array[String],
  contexts? : Array[String],
) -> Result[Unit, ClientError] {
  match validate_subscription_request(events, contexts) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  let json_events : Array[Json] = []
  for e in events {
    json_events.push(Json::string(e))
  }
  let params : Map[String, Json] = {}
  params["events"] = Json::array(json_events)
  match contexts {
    Some(context_ids) => {
      let json_contexts : Array[Json] = []
      for context_id in context_ids {
        json_contexts.push(Json::string(context_id))
      }
      params["contexts"] = Json::array(json_contexts)
    }
    None => ()
  }
  match
    self.dispatch("session", "unsubscribe", params=Some(Json::object(params))) {
    Ok(_) => {
      self.apply_unsubscribe(events, contexts)
      Ok(())
    }
    Err(e) => Err(e)
  }
}

///|
/// Session: end
pub async fn BidiClient::session_end(
  self : BidiClient,
) -> Result[Unit, ClientError] {
  match self.dispatch("session", "end") {
    Ok(_) => Ok(())
    Err(e) => Err(e)
  }
}

///|
/// browser.getUserContexts
pub async fn BidiClient::browser_get_user_contexts(
  self : BidiClient,
) -> Result[Array[String], ClientError] {
  let result = self.dispatch("browser", "getUserContexts")
  match result {
    Ok(json) =>
      match get_array_field(json, "userContexts") {
        Some(items) => {
          let contexts : Array[String] = []
          for item in items {
            match get_string_field(item, "userContext") {
              Some(id) => contexts.push(id)
              None => ()
            }
          }
          Ok(contexts)
        }
        None => Err(ParseError(message="Missing userContexts field"))
      }
    Err(e) => Err(e)
  }
}

///|
/// browser.createUserContext
pub async fn BidiClient::browser_create_user_context(
  self : BidiClient,
) -> Result[String, ClientError] {
  let result = self.dispatch("browser", "createUserContext")
  match result {
    Ok(json) =>
      match get_string_field(json, "userContext") {
        Some(id) => Ok(id)
        None => Err(ParseError(message="Missing userContext field"))
      }
    Err(e) => Err(e)
  }
}

///|
/// browser.removeUserContext
pub async fn BidiClient::browser_remove_user_context(
  self : BidiClient,
  user_context : String,
) -> Result[Unit, ClientError] {
  match validate_non_empty_string(user_context, "userContext") {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  let params : Map[String, Json] = {}
  params["userContext"] = Json::string(user_context)
  match
    self.dispatch(
      "browser",
      "removeUserContext",
      params=Some(Json::object(params)),
    ) {
    Ok(_) => Ok(())
    Err(e) => Err(e)
  }
}

///|
/// browser.close
pub async fn BidiClient::browser_close(
  self : BidiClient,
) -> Result[Unit, ClientError] {
  match self.dispatch("browser", "close") {
    Ok(_) => Ok(())
    Err(e) => Err(e)
  }
}

///|
/// browsingContext.create
pub async fn BidiClient::browsing_context_create(
  self : BidiClient,
  context_type : String,
  user_context? : String,
) -> Result[String, ClientError] {
  if context_type != "tab" && context_type != "window" {
    return Err(invalid_argument_error("type must be one of tab|window"))
  }
  match user_context {
    Some(value) =>
      match validate_non_empty_string(value, "userContext") {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
    None => ()
  }
  let params : Map[String, Json] = {}
  params["type"] = Json::string(context_type)
  match user_context {
    Some(u) => params["userContext"] = Json::string(u)
    None => ()
  }
  let result = self.dispatch(
    "browsingContext",
    "create",
    params=Some(Json::object(params)),
  )
  match result {
    Ok(json) =>
      match get_string_field(json, "context") {
        Some(ctx) => Ok(ctx)
        None => Err(ParseError(message="Missing context field"))
      }
    Err(e) => Err(e)
  }
}

///|
/// browsingContext.reload
pub async fn BidiClient::browsing_context_reload(
  self : BidiClient,
  context_id : String,
) -> Result[Unit, ClientError] {
  match validate_non_empty_string(context_id, "context") {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  let params : Map[String, Json] = {}
  params["context"] = Json::string(context_id)
  match
    self.dispatch(
      "browsingContext",
      "reload",
      params=Some(Json::object(params)),
    ) {
    Ok(_) => Ok(())
    Err(e) => Err(e)
  }
}

///|
/// browsingContext.close
pub async fn BidiClient::browsing_context_close(
  self : BidiClient,
  context_id : String,
) -> Result[Unit, ClientError] {
  match validate_non_empty_string(context_id, "context") {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  let params : Map[String, Json] = {}
  params["context"] = Json::string(context_id)
  match
    self.dispatch("browsingContext", "close", params=Some(Json::object(params))) {
    Ok(_) => Ok(())
    Err(e) => Err(e)
  }
}

///|
/// browsingContext.getTree
pub async fn BidiClient::browsing_context_get_tree(
  self : BidiClient,
  root? : String,
  max_depth? : Int,
) -> Result[Json, ClientError] {
  let params : Map[String, Json] = {}
  let mut has_params = false
  match root {
    Some(value) =>
      if value.is_empty() {
        return Err(invalid_argument_error("root must not be empty"))
      } else {
        params["root"] = Json::string(value)
        has_params = true
      }
    None => ()
  }
  match max_depth {
    Some(depth) =>
      if depth < 0 {
        return Err(invalid_argument_error("maxDepth must be non-negative"))
      } else {
        params["maxDepth"] = Json::number(depth.to_double())
        has_params = true
      }
    None => ()
  }
  if has_params {
    self.dispatch(
      "browsingContext",
      "getTree",
      params=Some(Json::object(params)),
    )
  } else {
    self.dispatch("browsingContext", "getTree")
  }
}

///|
/// browsingContext.navigate
pub async fn BidiClient::browsing_context_navigate(
  self : BidiClient,
  context_id : String,
  url : String,
  wait? : String = "complete",
) -> Result[NavigationResult, ClientError] {
  match validate_non_empty_string(context_id, "context") {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  match validate_non_empty_string(url, "url") {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  if not(is_valid_navigation_wait(wait)) {
    return Err(
      invalid_argument_error("wait must be one of none|interactive|complete"),
    )
  }
  let params : Map[String, Json] = {}
  params["context"] = Json::string(context_id)
  params["url"] = Json::string(url)
  params["wait"] = Json::string(wait)
  let result = self.dispatch(
    "browsingContext",
    "navigate",
    params=Some(Json::object(params)),
  )
  match result {
    Ok(json) => {
      let navigation = get_string_field(json, "navigation")
      let result_url = get_string_field(json, "url")
      match (navigation, result_url) {
        (Some(nav), Some(u)) => Ok({ navigation: nav, url: u })
        _ => Err(ParseError(message="Missing navigation/url field"))
      }
    }
    Err(e) => Err(e)
  }
}

///|
/// browsingContext.captureScreenshot
pub async fn BidiClient::browsing_context_capture_screenshot(
  self : BidiClient,
  context_id : String,
  origin? : String,
  format? : String,
  quality? : Int,
  clip? : Json,
) -> Result[String, ClientError] {
  match validate_non_empty_string(context_id, "context") {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  let params : Map[String, Json] = {}
  params["context"] = Json::string(context_id)
  match origin {
    Some(value) =>
      if value != "viewport" && value != "document" {
        return Err(
          invalid_argument_error("origin must be one of viewport|document"),
        )
      } else {
        params["origin"] = Json::string(value)
      }
    None => ()
  }
  match format {
    Some(value) =>
      if not(is_supported_screenshot_format(value)) {
        return Err(
          invalid_argument_error(
            "format must be one of image/png|image/jpeg|png|jpeg",
          ),
        )
      } else {
        params["format"] = Json::string(value)
      }
    None => ()
  }
  match quality {
    Some(value) =>
      if value < 0 || value > 100 {
        return Err(invalid_argument_error("quality must be between 0 and 100"))
      } else {
        params["quality"] = Json::number(value.to_double())
      }
    None => ()
  }
  match clip {
    Some(value) => params["clip"] = value
    None => ()
  }
  let result = self.dispatch(
    "browsingContext",
    "captureScreenshot",
    params=Some(Json::object(params)),
  )
  match result {
    Ok(json) =>
      match get_string_field(json, "data") {
        Some(data) => Ok(data)
        None => Err(ParseError(message="Missing data field"))
      }
    Err(e) => Err(e)
  }
}

///|
/// browsingContext.locateNodes
pub async fn BidiClient::browsing_context_locate_nodes(
  self : BidiClient,
  context_id : String,
  locator : Json,
  max_node_count? : Int,
  serialization_options? : SerializationOptions,
) -> Result[Json, ClientError] {
  self.locate_nodes_impl(
    context_id, locator, max_node_count, serialization_options,
  )
}

///|
/// browsingContext.locateNodes (typed)
pub async fn BidiClient::browsing_context_locate_nodes_typed(
  self : BidiClient,
  context_id : String,
  locator : Locator,
  max_node_count? : Int,
  serialization_options? : SerializationOptions,
) -> Result[Json, ClientError] {
  self.locate_nodes_impl(
    context_id,
    locator.to_json(),
    max_node_count,
    serialization_options,
  )
}

///|
/// browsingContext.locateNodes (typed refs)
pub async fn BidiClient::browsing_context_locate_nodes_typed_refs(
  self : BidiClient,
  context_id : String,
  locator : Locator,
  max_node_count? : Int,
  serialization_options? : SerializationOptions,
) -> Result[Array[NodeReference], ClientError] {
  let result = self.locate_nodes_impl(
    context_id,
    locator.to_json(),
    max_node_count,
    serialization_options,
  )
  match result {
    Ok(json) => parse_node_references(json)
    Err(e) => Err(e)
  }
}

///|
async fn BidiClient::locate_nodes_impl(
  self : BidiClient,
  context_id : String,
  locator : Json,
  max_node_count : Int?,
  serialization_options : SerializationOptions?,
) -> Result[Json, ClientError] {
  match validate_non_empty_string(context_id, "context") {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  match validate_locator(locator) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  let params : Map[String, Json] = {}
  params["context"] = Json::string(context_id)
  params["locator"] = locator
  match max_node_count {
    Some(count) =>
      if count <= 0 {
        return Err(
          invalid_argument_error("maxNodeCount must be greater than 0"),
        )
      } else {
        params["maxNodeCount"] = Json::number(count.to_double())
      }
    None => ()
  }
  match serialization_options {
    Some(opts) =>
      match validate_serialization_options(opts) {
        Ok(_) => params["serializationOptions"] = opts.to_json()
        Err(e) => return Err(e)
      }
    None => ()
  }
  self.dispatch(
    "browsingContext",
    "locateNodes",
    params=Some(Json::object(params)),
  )
}

///|
fn parse_node_references(
  result : Json,
) -> Result[Array[NodeReference], ClientError] {
  let nodes = match get_array_field(result, "nodes") {
    Some(values) => values
    None => return Err(ParseError(message="Missing nodes field"))
  }
  let references : Array[NodeReference] = []
  for node in nodes {
    let handle = get_string_field(node, "handle")
    let shared_id = get_string_field(node, "sharedId")
    if handle == None && shared_id == None {
      return Err(
        ParseError(message="Node reference must include handle or sharedId"),
      )
    }
    references.push({ handle, shared_id })
  }
  Ok(references)
}

///|
/// script.evaluate
pub async fn BidiClient::script_evaluate(
  self : BidiClient,
  expression : String,
  context_id : String,
  await_promise? : Bool = true,
  result_ownership? : ResultOwnership,
  serialization_options? : SerializationOptions,
  user_activation? : Bool,
) -> Result[Json, ClientError] {
  match validate_non_empty_string(expression, "expression") {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  match validate_non_empty_string(context_id, "context") {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  let params : Map[String, Json] = {}
  params["expression"] = Json::string(expression)
  params["target"] = Json::object({ "context": Json::string(context_id) })
  params["awaitPromise"] = Json::boolean(await_promise)
  match result_ownership {
    Some(ownership) =>
      params["resultOwnership"] = Json::string(ownership.to_string())
    None => ()
  }
  match serialization_options {
    Some(opts) =>
      match validate_serialization_options(opts) {
        Ok(_) => params["serializationOptions"] = opts.to_json()
        Err(e) => return Err(e)
      }
    None => ()
  }
  match user_activation {
    Some(active) => params["userActivation"] = Json::boolean(active)
    None => ()
  }
  self.dispatch("script", "evaluate", params=Some(Json::object(params)))
}

///|
/// script.callFunction
pub async fn BidiClient::script_call_function(
  self : BidiClient,
  function_declaration : String,
  context_id : String,
  arguments? : Array[Json] = [],
  await_promise? : Bool = true,
  result_ownership? : ResultOwnership,
  serialization_options? : SerializationOptions,
  user_activation? : Bool,
  this_value? : Json,
) -> Result[Json, ClientError] {
  self.call_function_impl(
    function_declaration, context_id, arguments, await_promise, result_ownership,
    serialization_options, user_activation, this_value,
  )
}

///|
/// script.callFunction (typed arguments)
pub async fn BidiClient::script_call_function_typed(
  self : BidiClient,
  function_declaration : String,
  context_id : String,
  arguments? : Array[RemoteValue] = [],
  await_promise? : Bool = true,
  result_ownership? : ResultOwnership,
  serialization_options? : SerializationOptions,
  user_activation? : Bool,
  this_value? : RemoteValue,
) -> Result[Json, ClientError] {
  let args_json : Array[Json] = []
  for arg in arguments {
    args_json.push(arg.to_json())
  }
  let this_value_json = match this_value {
    Some(value) => Some(value.to_json())
    None => None
  }
  self.call_function_impl(
    function_declaration, context_id, args_json, await_promise, result_ownership,
    serialization_options, user_activation, this_value_json,
  )
}

///|
async fn BidiClient::call_function_impl(
  self : BidiClient,
  function_declaration : String,
  context_id : String,
  arguments : Array[Json],
  await_promise : Bool,
  result_ownership : ResultOwnership?,
  serialization_options : SerializationOptions?,
  user_activation : Bool?,
  this_value : Json?,
) -> Result[Json, ClientError] {
  match validate_non_empty_string(function_declaration, "functionDeclaration") {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  match validate_non_empty_string(context_id, "context") {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  let params : Map[String, Json] = {}
  params["functionDeclaration"] = Json::string(function_declaration)
  params["target"] = Json::object({ "context": Json::string(context_id) })
  params["arguments"] = Json::array(arguments)
  params["awaitPromise"] = Json::boolean(await_promise)
  match result_ownership {
    Some(ownership) =>
      params["resultOwnership"] = Json::string(ownership.to_string())
    None => ()
  }
  match serialization_options {
    Some(opts) =>
      match validate_serialization_options(opts) {
        Ok(_) => params["serializationOptions"] = opts.to_json()
        Err(e) => return Err(e)
      }
    None => ()
  }
  match user_activation {
    Some(active) => params["userActivation"] = Json::boolean(active)
    None => ()
  }
  match this_value {
    Some(value) => params["this"] = value
    None => ()
  }
  self.dispatch("script", "callFunction", params=Some(Json::object(params)))
}

///|
/// script.addPreloadScript
pub async fn BidiClient::script_add_preload_script(
  self : BidiClient,
  function_declaration : String,
  arguments? : Array[RemoteValue] = [],
  contexts? : Array[String],
  user_contexts? : Array[String],
  sandbox? : String,
) -> Result[String, ClientError] {
  match validate_non_empty_string(function_declaration, "functionDeclaration") {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  let args_json : Array[Json] = []
  for arg in arguments {
    args_json.push(arg.to_json())
  }
  let params : Map[String, Json] = {}
  params["functionDeclaration"] = Json::string(function_declaration)
  params["arguments"] = Json::array(args_json)
  match contexts {
    Some(values) => {
      match validate_context_ids(values, "contexts") {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
      let items : Array[Json] = []
      for value in values {
        items.push(Json::string(value))
      }
      params["contexts"] = Json::array(items)
    }
    None => ()
  }
  match user_contexts {
    Some(values) => {
      match validate_context_ids(values, "userContexts") {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
      let items : Array[Json] = []
      for value in values {
        items.push(Json::string(value))
      }
      params["userContexts"] = Json::array(items)
    }
    None => ()
  }
  match sandbox {
    Some(value) =>
      if value.is_empty() {
        return Err(invalid_argument_error("sandbox must not be empty"))
      } else {
        params["sandbox"] = Json::string(value)
      }
    None => ()
  }
  let result = self.dispatch(
    "script",
    "addPreloadScript",
    params=Some(Json::object(params)),
  )
  match result {
    Ok(json) =>
      match get_string_field(json, "script") {
        Some(script_id) => Ok(script_id)
        None => Err(ParseError(message="Missing script field"))
      }
    Err(e) => Err(e)
  }
}

///|
/// script.removePreloadScript
pub async fn BidiClient::script_remove_preload_script(
  self : BidiClient,
  script_id : String,
) -> Result[Unit, ClientError] {
  match validate_non_empty_string(script_id, "script") {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  let params : Map[String, Json] = {}
  params["script"] = Json::string(script_id)
  match
    self.dispatch(
      "script",
      "removePreloadScript",
      params=Some(Json::object(params)),
    ) {
    Ok(_) => Ok(())
    Err(e) => Err(e)
  }
}

///|
/// script.disown
pub async fn BidiClient::script_disown(
  self : BidiClient,
  handles : Array[String],
  context_id? : String,
  sandbox? : String,
) -> Result[Unit, ClientError] {
  if handles.length() == 0 {
    return Err(invalid_argument_error("handles must not be empty"))
  }
  let target : Map[String, Json] = {}
  match context_id {
    Some(value) =>
      if value.is_empty() {
        return Err(invalid_argument_error("context must not be empty"))
      } else {
        target["context"] = Json::string(value)
      }
    None => return Err(invalid_argument_error("context is required"))
  }
  match sandbox {
    Some(value) =>
      if value.is_empty() {
        return Err(invalid_argument_error("sandbox must not be empty"))
      } else {
        target["sandbox"] = Json::string(value)
      }
    None => ()
  }
  let handle_values : Array[Json] = []
  for handle in handles {
    if handle.is_empty() {
      return Err(
        invalid_argument_error("handles must not contain empty values"),
      )
    }
    handle_values.push(Json::string(handle))
  }
  let params : Map[String, Json] = {}
  params["handles"] = Json::array(handle_values)
  params["target"] = Json::object(target)
  match self.dispatch("script", "disown", params=Some(Json::object(params))) {
    Ok(_) => Ok(())
    Err(e) => Err(e)
  }
}

///|
/// input.performActions
pub async fn BidiClient::input_perform_actions(
  self : BidiClient,
  actions : Array[Json],
  context_id? : String,
) -> Result[Unit, ClientError] {
  if actions.length() == 0 {
    return Err(invalid_argument_error("actions must not be empty"))
  }
  let params : Map[String, Json] = {}
  params["actions"] = Json::array(actions)
  match context_id {
    Some(ctx) =>
      if ctx.is_empty() {
        return Err(invalid_argument_error("context must not be empty"))
      } else {
        params["context"] = Json::string(ctx)
      }
    None => ()
  }
  match
    self.dispatch("input", "performActions", params=Some(Json::object(params))) {
    Ok(_) => Ok(())
    Err(e) => Err(e)
  }
}

///|
/// input.performActions (typed)
pub async fn BidiClient::input_perform_actions_typed(
  self : BidiClient,
  actions : Array[ActionSequence],
  context_id? : String,
) -> Result[Unit, ClientError] {
  let actions_json : Array[Json] = []
  for action in actions {
    actions_json.push(action.to_json())
  }
  match context_id {
    Some(ctx) => self.input_perform_actions(actions_json, context_id=ctx)
    None => self.input_perform_actions(actions_json)
  }
}

///|
/// input.releaseActions
pub async fn BidiClient::input_release_actions(
  self : BidiClient,
  context_id? : String,
) -> Result[Unit, ClientError] {
  let params : Map[String, Json] = {}
  match context_id {
    Some(ctx) =>
      if ctx.is_empty() {
        return Err(invalid_argument_error("context must not be empty"))
      } else {
        params["context"] = Json::string(ctx)
      }
    None => ()
  }
  match
    self.dispatch("input", "releaseActions", params=Some(Json::object(params))) {
    Ok(_) => Ok(())
    Err(e) => Err(e)
  }
}

///|
/// network.setCacheBehavior
pub async fn BidiClient::network_set_cache_behavior(
  self : BidiClient,
  cache_behavior : String,
  contexts? : Array[String],
) -> Result[Unit, ClientError] {
  if not(is_supported_cache_behavior(cache_behavior)) {
    return Err(
      invalid_argument_error("cacheBehavior must be one of default|bypass"),
    )
  }
  let params : Map[String, Json] = {}
  params["cacheBehavior"] = Json::string(cache_behavior)
  match contexts {
    Some(items) => {
      match validate_context_ids(items, "contexts") {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
      let json_contexts : Array[Json] = []
      for ctx in items {
        json_contexts.push(Json::string(ctx))
      }
      params["contexts"] = Json::array(json_contexts)
    }
    None => ()
  }
  match
    self.dispatch(
      "network",
      "setCacheBehavior",
      params=Some(Json::object(params)),
    ) {
    Ok(_) => Ok(())
    Err(e) => Err(e)
  }
}

///|
/// network.setCacheBehavior (typed)
pub async fn BidiClient::network_set_cache_behavior_typed(
  self : BidiClient,
  cache_behavior : CacheBehavior,
  contexts? : Array[String],
) -> Result[Unit, ClientError] {
  match contexts {
    Some(list) =>
      self.network_set_cache_behavior(cache_behavior.to_string(), contexts=list)
    None => self.network_set_cache_behavior(cache_behavior.to_string())
  }
}

///|
/// network.addDataCollector
pub async fn BidiClient::network_add_data_collector(
  self : BidiClient,
) -> Result[Unit, ClientError] {
  match self.dispatch("network", "addDataCollector") {
    Ok(_) => Ok(())
    Err(e) => Err(e)
  }
}

///|
/// network.addDataCollector (typed)
pub async fn BidiClient::network_add_data_collector_typed(
  self : BidiClient,
  collector : NetworkDataCollector,
) -> Result[Unit, ClientError] {
  if collector.data_types.length() == 0 {
    return Err(invalid_argument_error("dataTypes must not be empty"))
  }
  for data_type in collector.data_types {
    if not(is_supported_data_type(data_type)) {
      return Err(invalid_argument_error("Invalid data type: " + data_type))
    }
  }
  match collector.contexts {
    Some(contexts) =>
      match validate_context_ids(contexts, "contexts") {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
    None => ()
  }
  match
    self.dispatch(
      "network",
      "addDataCollector",
      params=Some(collector.to_json()),
    ) {
    Ok(_) => Ok(())
    Err(e) => Err(e)
  }
}

///|
/// Wait for response with matching id
async fn BidiClient::wait_response(
  self : BidiClient,
  id : Int,
) -> Result[BidiResponse, ClientError] {
  match self.pending.get(id) {
    Some(resp) => {
      self.pending.remove(id)
      return Ok(resp)
    }
    None => ()
  }
  let incoming = match self.transport.recv() {
    Ok(raw) =>
      match parse_incoming(raw) {
        Ok(msg) => msg
        Err(e) => return Err(ParseError(message=e))
      }
    Err(e) => return Err(Transport(e))
  }
  match incoming {
    Event(evt) => {
      self.dispatch_event(evt)
      self.wait_response(id)
    }
    Response(resp) =>
      if resp.id == id {
        Ok(resp)
      } else {
        self.pending[resp.id] = resp
        self.wait_response(id)
      }
  }
}

///|
/// Dispatch event to handlers
fn BidiClient::dispatch_event(self : BidiClient, evt : BidiEvent) -> Unit {
  if not(self.is_event_subscribed(evt)) {
    return ()
  }
  for handler in self.event_handlers {
    handler(evt)
  }
}

///|
fn BidiClient::is_event_subscribed(self : BidiClient, evt : BidiEvent) -> Bool {
  if not(self.has_subscription_filter) {
    return true
  }
  if self.global_subscriptions.contains(evt.event_method) {
    return true
  }
  match get_string_field(evt.params, "context") {
    Some(context_id) =>
      match self.context_subscriptions.get(context_id) {
        Some(events) => events.contains(evt.event_method)
        None => false
      }
    None => false
  }
}

///|
fn BidiClient::apply_subscribe(
  self : BidiClient,
  events : Array[String],
  contexts : Array[String]?,
) -> Unit {
  self.has_subscription_filter = true
  match contexts {
    Some(context_ids) =>
      for context_id in context_ids {
        let context_events = match self.context_subscriptions.get(context_id) {
          Some(existing) => existing
          None => {
            let created : Map[String, Bool] = {}
            self.context_subscriptions[context_id] = created
            created
          }
        }
        for event_name in events {
          context_events[event_name] = true
        }
      }
    None =>
      for event_name in events {
        self.global_subscriptions[event_name] = true
      }
  }
}

///|
fn BidiClient::apply_unsubscribe(
  self : BidiClient,
  events : Array[String],
  contexts : Array[String]?,
) -> Unit {
  match contexts {
    Some(context_ids) =>
      for context_id in context_ids {
        match self.context_subscriptions.get(context_id) {
          Some(context_events) => {
            for event_name in events {
              context_events.remove(event_name)
            }
            if context_events.is_empty() {
              self.context_subscriptions.remove(context_id)
            }
          }
          None => ()
        }
      }
    None =>
      for event_name in events {
        self.global_subscriptions.remove(event_name)
      }
  }
  self.has_subscription_filter = true
}

///|
fn is_valid_navigation_wait(wait : String) -> Bool {
  wait == "none" || wait == "interactive" || wait == "complete"
}

///|
fn is_supported_screenshot_format(format : String) -> Bool {
  format == "image/png" ||
  format == "image/jpeg" ||
  format == "png" ||
  format == "jpeg"
}

///|
fn is_supported_cache_behavior(cache_behavior : String) -> Bool {
  cache_behavior == "default" || cache_behavior == "bypass"
}

///|
fn is_supported_data_type(data_type : String) -> Bool {
  data_type == "request" || data_type == "response"
}

///|
fn validate_non_empty_string(
  value : String,
  field_name : String,
) -> Result[Unit, ClientError] {
  if value.is_empty() {
    Err(invalid_argument_error(field_name + " must not be empty"))
  } else {
    Ok(())
  }
}

///|
fn validate_serialization_options(
  options : SerializationOptions,
) -> Result[Unit, ClientError] {
  match options.max_depth {
    Some(depth) =>
      if depth < 0 {
        return Err(
          invalid_argument_error(
            "serializationOptions.maxDepth must be non-negative",
          ),
        )
      } else {
        ()
      }
    None => ()
  }
  match options.max_object_depth {
    Some(depth) =>
      if depth < 0 {
        return Err(
          invalid_argument_error(
            "serializationOptions.maxObjectDepth must be non-negative",
          ),
        )
      } else {
        ()
      }
    None => ()
  }
  match options.include_shadow_tree {
    Some(value) =>
      if value != "none" && value != "open" && value != "all" {
        return Err(
          invalid_argument_error(
            "serializationOptions.includeShadowTree must be one of none|open|all",
          ),
        )
      } else {
        ()
      }
    None => ()
  }
  Ok(())
}

///|
fn validate_locator(locator : Json) -> Result[Unit, ClientError] {
  let locator_type = match get_string_field(locator, "type") {
    Some(value) => value
    None => return Err(invalid_argument_error("locator.type is required"))
  }
  if locator_type == "css" || locator_type == "xpath" {
    match get_string_field(locator, "value") {
      Some(value) =>
        if value.is_empty() {
          Err(
            invalid_argument_error(
              "locator.value must be a non-empty string for " +
              locator_type +
              " locator",
            ),
          )
        } else {
          Ok(())
        }
      None =>
        Err(
          invalid_argument_error(
            "locator.value must be a non-empty string for " +
            locator_type +
            " locator",
          ),
        )
    }
  } else {
    Ok(())
  }
}

///|
fn invalid_argument_error(message : String) -> ClientError {
  InvalidArgument(message="invalid argument: " + message)
}

///|
fn unknown_command_error(domain : String, command : String) -> ClientError {
  InvalidArgument(message="unknown command: " + domain + "." + command)
}

///|
fn validate_subscription_request(
  events : Array[String],
  contexts : Array[String]?,
) -> Result[Unit, ClientError] {
  if events.length() == 0 {
    return Err(invalid_argument_error("events must not be empty"))
  }
  for event_name in events {
    if not(is_supported_event_name(event_name)) {
      return Err(invalid_argument_error("Invalid event name: " + event_name))
    }
  }
  match contexts {
    Some(context_ids) => validate_context_ids(context_ids, "contexts")
    None => Ok(())
  }
}

///|
fn validate_context_ids(
  context_ids : Array[String],
  field_name : String,
) -> Result[Unit, ClientError] {
  if context_ids.length() == 0 {
    return Err(invalid_argument_error(field_name + " must not be empty"))
  }
  for context_id in context_ids {
    if context_id.is_empty() {
      return Err(
        invalid_argument_error(field_name + " must not contain empty values"),
      )
    }
  }
  Ok(())
}

///|
fn is_supported_event_name(event_name : String) -> Bool {
  let domains = [
    "session", "browser", "browsingContext", "script", "input", "network", "log",
  ]
  for domain in domains {
    let prefix = domain + "."
    if event_name.has_prefix(prefix) && event_name.length() > prefix.length() {
      return true
    }
  }
  false
}

///|
fn is_supported_domain_command(domain : String, command : String) -> Bool {
  match domain {
    "session" =>
      command == "status" ||
      command == "new" ||
      command == "subscribe" ||
      command == "unsubscribe" ||
      command == "end"
    "browser" =>
      command == "getUserContexts" ||
      command == "createUserContext" ||
      command == "removeUserContext" ||
      command == "close"
    "browsingContext" =>
      command == "create" ||
      command == "reload" ||
      command == "close" ||
      command == "getTree" ||
      command == "navigate" ||
      command == "captureScreenshot" ||
      command == "locateNodes"
    "script" =>
      command == "evaluate" ||
      command == "callFunction" ||
      command == "addPreloadScript" ||
      command == "removePreloadScript" ||
      command == "disown"
    "input" => command == "performActions" || command == "releaseActions"
    "network" => command == "setCacheBehavior" || command == "addDataCollector"
    _ => false
  }
}
