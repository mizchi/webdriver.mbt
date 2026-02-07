///|
/// BiDi client

///|
/// BiDi client state
pub struct BidiClient {
  transport : Transport
  mut next_id : Int
  mut connected : Bool
  pending : Map[Int, BidiResponse]
  event_handlers : Array[(BidiEvent) -> Unit]
}

///|
/// Create a new client
pub fn BidiClient::new(transport : Transport) -> BidiClient {
  { transport, next_id: 1, connected: false, pending: {}, event_handlers: [] }
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
/// Session: status
pub async fn BidiClient::session_status(
  self : BidiClient,
) -> Result[SessionStatus, ClientError] {
  let result = self.send("session.status")
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
  let result = match capabilities {
    Some(caps) => {
      let params : Map[String, Json] = {}
      params["capabilities"] = caps
      self.send("session.new", params=Some(Json::object(params)))
    }
    None => self.send("session.new")
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
) -> Result[Unit, ClientError] {
  let json_events : Array[Json] = []
  for e in events {
    json_events.push(Json::string(e))
  }
  let params : Map[String, Json] = {}
  params["events"] = Json::array(json_events)
  match self.send("session.subscribe", params=Some(Json::object(params))) {
    Ok(_) => Ok(())
    Err(e) => Err(e)
  }
}

///|
/// Session: unsubscribe
pub async fn BidiClient::session_unsubscribe(
  self : BidiClient,
  events : Array[String],
) -> Result[Unit, ClientError] {
  let json_events : Array[Json] = []
  for e in events {
    json_events.push(Json::string(e))
  }
  let params : Map[String, Json] = {}
  params["events"] = Json::array(json_events)
  match self.send("session.unsubscribe", params=Some(Json::object(params))) {
    Ok(_) => Ok(())
    Err(e) => Err(e)
  }
}

///|
/// Session: end
pub async fn BidiClient::session_end(
  self : BidiClient,
) -> Result[Unit, ClientError] {
  match self.send("session.end") {
    Ok(_) => Ok(())
    Err(e) => Err(e)
  }
}

///|
/// browser.getUserContexts
pub async fn BidiClient::browser_get_user_contexts(
  self : BidiClient,
) -> Result[Array[String], ClientError] {
  let result = self.send("browser.getUserContexts")
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
  let result = self.send("browser.createUserContext")
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
  let params : Map[String, Json] = {}
  params["userContext"] = Json::string(user_context)
  match
    self.send("browser.removeUserContext", params=Some(Json::object(params))) {
    Ok(_) => Ok(())
    Err(e) => Err(e)
  }
}

///|
/// browser.close
pub async fn BidiClient::browser_close(
  self : BidiClient,
) -> Result[Unit, ClientError] {
  match self.send("browser.close") {
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
  let params : Map[String, Json] = {}
  params["type"] = Json::string(context_type)
  match user_context {
    Some(u) => params["userContext"] = Json::string(u)
    None => ()
  }
  let result = self.send(
    "browsingContext.create",
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
  let params : Map[String, Json] = {}
  params["context"] = Json::string(context_id)
  match self.send("browsingContext.reload", params=Some(Json::object(params))) {
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
  let params : Map[String, Json] = {}
  params["context"] = Json::string(context_id)
  match self.send("browsingContext.close", params=Some(Json::object(params))) {
    Ok(_) => Ok(())
    Err(e) => Err(e)
  }
}

///|
/// browsingContext.getTree
pub async fn BidiClient::browsing_context_get_tree(
  self : BidiClient,
) -> Result[Json, ClientError] {
  self.send("browsingContext.getTree")
}

///|
/// browsingContext.navigate
pub async fn BidiClient::browsing_context_navigate(
  self : BidiClient,
  context_id : String,
  url : String,
  wait? : String = "complete",
) -> Result[NavigationResult, ClientError] {
  let params : Map[String, Json] = {}
  params["context"] = Json::string(context_id)
  params["url"] = Json::string(url)
  params["wait"] = Json::string(wait)
  let result = self.send(
    "browsingContext.navigate",
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
/// browsingContext.locateNodes
pub async fn BidiClient::browsing_context_locate_nodes(
  self : BidiClient,
  context_id : String,
  locator : Json,
  max_node_count? : Int,
  serialization_options? : SerializationOptions,
) -> Result[Json, ClientError] {
  let params : Map[String, Json] = {}
  params["context"] = Json::string(context_id)
  params["locator"] = locator
  match max_node_count {
    Some(count) => params["maxNodeCount"] = Json::number(count.to_double())
    None => ()
  }
  match serialization_options {
    Some(opts) => params["serializationOptions"] = opts.to_json()
    None => ()
  }
  self.send("browsingContext.locateNodes", params=Some(Json::object(params)))
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
  let params : Map[String, Json] = {}
  params["context"] = Json::string(context_id)
  params["locator"] = locator.to_json()
  match max_node_count {
    Some(count) => params["maxNodeCount"] = Json::number(count.to_double())
    None => ()
  }
  match serialization_options {
    Some(opts) => params["serializationOptions"] = opts.to_json()
    None => ()
  }
  self.send("browsingContext.locateNodes", params=Some(Json::object(params)))
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
    Some(opts) => params["serializationOptions"] = opts.to_json()
    None => ()
  }
  match user_activation {
    Some(active) => params["userActivation"] = Json::boolean(active)
    None => ()
  }
  self.send("script.evaluate", params=Some(Json::object(params)))
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
    Some(opts) => params["serializationOptions"] = opts.to_json()
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
  self.send("script.callFunction", params=Some(Json::object(params)))
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
  let params : Map[String, Json] = {}
  params["functionDeclaration"] = Json::string(function_declaration)
  params["target"] = Json::object({ "context": Json::string(context_id) })
  params["arguments"] = Json::array(args_json)
  params["awaitPromise"] = Json::boolean(await_promise)
  match result_ownership {
    Some(ownership) =>
      params["resultOwnership"] = Json::string(ownership.to_string())
    None => ()
  }
  match serialization_options {
    Some(opts) => params["serializationOptions"] = opts.to_json()
    None => ()
  }
  match user_activation {
    Some(active) => params["userActivation"] = Json::boolean(active)
    None => ()
  }
  match this_value {
    Some(value) => params["this"] = value.to_json()
    None => ()
  }
  self.send("script.callFunction", params=Some(Json::object(params)))
}

///|
/// input.performActions
pub async fn BidiClient::input_perform_actions(
  self : BidiClient,
  actions : Array[Json],
  context_id? : String,
) -> Result[Unit, ClientError] {
  let params : Map[String, Json] = {}
  params["actions"] = Json::array(actions)
  match context_id {
    Some(ctx) => params["context"] = Json::string(ctx)
    None => ()
  }
  match self.send("input.performActions", params=Some(Json::object(params))) {
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
    Some(ctx) => params["context"] = Json::string(ctx)
    None => ()
  }
  match self.send("input.releaseActions", params=Some(Json::object(params))) {
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
  let params : Map[String, Json] = {}
  params["cacheBehavior"] = Json::string(cache_behavior)
  match contexts {
    Some(items) => {
      let json_contexts : Array[Json] = []
      for ctx in items {
        json_contexts.push(Json::string(ctx))
      }
      params["contexts"] = Json::array(json_contexts)
    }
    None => ()
  }
  match
    self.send("network.setCacheBehavior", params=Some(Json::object(params))) {
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
  match self.send("network.addDataCollector") {
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
  match
    self.send("network.addDataCollector", params=Some(collector.to_json())) {
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
  for handler in self.event_handlers {
    handler(evt)
  }
}
