///|
/// WebDriver BiDi Types

///|
/// BiDi request message
pub struct BidiRequest {
  id : Int
  method_name : String
  params : Json?
} derive(Show)

///|
/// BiDi response message
pub struct BidiResponse {
  id : Int
  result : Json?
  error : BidiError?
} derive(Show)

///|
/// BiDi error payload
pub struct BidiError {
  error : String
  message : String
  stacktrace : String
} derive(Show)

///|
/// BiDi event message
pub struct BidiEvent {
  event_method : String
  params : Json
} derive(Show)

///|
/// Incoming BiDi message
pub enum BidiIncoming {
  Response(BidiResponse)
  Event(BidiEvent)
} derive(Show)

///|
/// Transport error
pub enum TransportError {
  NotSupported(message~ : String)
  NetworkError(message~ : String)
  Closed
} derive(Show)

///|
/// Client error
pub enum ClientError {
  Transport(TransportError)
  ParseError(message~ : String)
  InvalidArgument(message~ : String)
  ResponseError(error~ : BidiError)
} derive(Show)

///|
/// session.status result
pub struct SessionStatus {
  ready : Bool
  message : String?
} derive(Show)

///|
/// session.new result
pub struct SessionInfo {
  session_id : String
  capabilities : Json?
} derive(Show)

///|
/// browsingContext.navigate result
pub struct NavigationResult {
  navigation : String
  url : String
} derive(Show)

///|
/// browsingContext.locateNodes node reference
pub struct NodeReference {
  handle : String?
  shared_id : String?
} derive(Show)

///|
/// Result ownership for script.evaluate / callFunction
pub enum ResultOwnership {
  NoneOwnership
  Root
} derive(Show, Eq)

///|
pub fn ResultOwnership::to_string(self : ResultOwnership) -> String {
  match self {
    NoneOwnership => "none"
    Root => "root"
  }
}

///|
pub fn ResultOwnership::none() -> ResultOwnership {
  NoneOwnership
}

///|
pub fn ResultOwnership::root() -> ResultOwnership {
  Root
}

///|
/// Serialization options for script results
pub struct SerializationOptions {
  max_depth : Int?
  max_object_depth : Int?
  include_shadow_tree : String?
} derive(Show)

///|
pub fn SerializationOptions::new(
  max_depth? : Int,
  max_object_depth? : Int,
  include_shadow_tree? : String,
) -> SerializationOptions {
  { max_depth, max_object_depth, include_shadow_tree }
}

///|
pub fn SerializationOptions::to_json(self : SerializationOptions) -> Json {
  let obj : Map[String, Json] = {}
  match self.max_depth {
    Some(n) => obj["maxDepth"] = Json::number(n.to_double())
    None => ()
  }
  match self.max_object_depth {
    Some(n) => obj["maxObjectDepth"] = Json::number(n.to_double())
    None => ()
  }
  match self.include_shadow_tree {
    Some(s) => obj["includeShadowTree"] = Json::string(s)
    None => ()
  }
  Json::object(obj)
}

///|
/// Match type for innerText locator
pub enum InnerTextMatchType {
  Full
  Partial
} derive(Show, Eq)

///|
pub fn InnerTextMatchType::to_string(self : InnerTextMatchType) -> String {
  match self {
    Full => "full"
    Partial => "partial"
  }
}

///|
pub fn InnerTextMatchType::full() -> InnerTextMatchType {
  Full
}

///|
pub fn InnerTextMatchType::partial() -> InnerTextMatchType {
  Partial
}

///|
/// InnerText locator value
pub struct InnerTextLocator {
  text : String
  match_type : InnerTextMatchType
  ignore_case : Bool
} derive(Show)

///|
/// Accessibility locator value
pub struct AccessibilityLocator {
  role : String
  name : String?
  exact : Bool?
} derive(Show)

///|
/// Locator for browsingContext.locateNodes
pub enum Locator {
  Css(String)
  Xpath(String)
  InnerText(InnerTextLocator)
  Accessibility(AccessibilityLocator)
  Custom(type_name~ : String, value~ : Json)
} derive(Show)

///|
pub fn Locator::css(selector : String) -> Locator {
  Css(selector)
}

///|
pub fn Locator::xpath(expr : String) -> Locator {
  Xpath(expr)
}

///|
pub fn Locator::inner_text(
  text : String,
  match_type? : InnerTextMatchType = Partial,
  ignore_case? : Bool = false,
) -> Locator {
  InnerText({ text, match_type, ignore_case })
}

///|
pub fn Locator::accessibility(
  role : String,
  name? : String,
  exact? : Bool = false,
) -> Locator {
  Accessibility({ role, name, exact: Some(exact) })
}

///|
pub fn Locator::custom(type_name : String, value : Json) -> Locator {
  Custom(type_name~, value~)
}

///|
pub fn Locator::to_json(self : Locator) -> Json {
  let obj : Map[String, Json] = {}
  match self {
    Css(selector) => {
      obj["type"] = Json::string("css")
      obj["value"] = Json::string(selector)
    }
    Xpath(expr) => {
      obj["type"] = Json::string("xpath")
      obj["value"] = Json::string(expr)
    }
    InnerText(locator) => {
      obj["type"] = Json::string("innerText")
      let value : Map[String, Json] = {}
      value["value"] = Json::string(locator.text)
      value["matchType"] = Json::string(locator.match_type.to_string())
      value["ignoreCase"] = Json::boolean(locator.ignore_case)
      obj["value"] = Json::object(value)
    }
    Accessibility(locator) => {
      obj["type"] = Json::string("accessibility")
      let value : Map[String, Json] = {}
      value["role"] = Json::string(locator.role)
      match locator.name {
        Some(n) => value["name"] = Json::string(n)
        None => ()
      }
      match locator.exact {
        Some(exact) => value["exact"] = Json::boolean(exact)
        None => ()
      }
      obj["value"] = Json::object(value)
    }
    Custom(type_name~, value~) => {
      obj["type"] = Json::string(type_name)
      obj["value"] = value
    }
  }
  Json::object(obj)
}

///|
/// Pointer device type
pub enum PointerType {
  Mouse
  Pen
  Touch
} derive(Show, Eq)

///|
pub fn PointerType::to_string(self : PointerType) -> String {
  match self {
    Mouse => "mouse"
    Pen => "pen"
    Touch => "touch"
  }
}

///|
pub fn PointerType::mouse() -> PointerType {
  Mouse
}

///|
pub fn PointerType::pen() -> PointerType {
  Pen
}

///|
pub fn PointerType::touch() -> PointerType {
  Touch
}

///|
/// Action origin for pointer actions
pub enum ActionOrigin {
  Viewport
  Pointer
  ElementHandle(handle~ : String)
  ElementSharedId(shared_id~ : String)
} derive(Show)

///|
pub fn ActionOrigin::to_json(self : ActionOrigin) -> Json {
  match self {
    Viewport => Json::string("viewport")
    Pointer => Json::string("pointer")
    ElementHandle(handle~) =>
      Json::object({
        "type": Json::string("element"),
        "handle": Json::string(handle),
      })
    ElementSharedId(shared_id~) =>
      Json::object({
        "type": Json::string("element"),
        "sharedId": Json::string(shared_id),
      })
  }
}

///|
pub fn ActionOrigin::viewport() -> ActionOrigin {
  Viewport
}

///|
pub fn ActionOrigin::pointer() -> ActionOrigin {
  Pointer
}

///|
pub fn ActionOrigin::element_handle(handle : String) -> ActionOrigin {
  ElementHandle(handle~)
}

///|
pub fn ActionOrigin::element_shared_id(shared_id : String) -> ActionOrigin {
  ElementSharedId(shared_id~)
}

///|
/// Input action item
pub enum InputAction {
  Pause(duration~ : Int?)
  PointerMove(
    x~ : Double,
    y~ : Double,
    origin~ : ActionOrigin,
    duration~ : Int?
  )
  PointerDown(button~ : Int)
  PointerUp(button~ : Int)
  PointerCancel
  KeyDown(value~ : String)
  KeyUp(value~ : String)
} derive(Show)

///|
pub fn InputAction::pause(duration? : Int) -> InputAction {
  Pause(duration~)
}

///|
pub fn InputAction::pointer_move(
  x : Double,
  y : Double,
  origin? : ActionOrigin = Viewport,
  duration? : Int? = None,
) -> InputAction {
  PointerMove(x~, y~, origin~, duration~)
}

///|
pub fn InputAction::pointer_down(button : Int) -> InputAction {
  PointerDown(button~)
}

///|
pub fn InputAction::pointer_up(button : Int) -> InputAction {
  PointerUp(button~)
}

///|
pub fn InputAction::pointer_cancel() -> InputAction {
  PointerCancel
}

///|
pub fn InputAction::key_down(value : String) -> InputAction {
  KeyDown(value~)
}

///|
pub fn InputAction::key_up(value : String) -> InputAction {
  KeyUp(value~)
}

///|
pub fn InputAction::to_json(self : InputAction) -> Json {
  let obj : Map[String, Json] = {}
  match self {
    Pause(duration~) => {
      obj["type"] = Json::string("pause")
      match duration {
        Some(d) => obj["duration"] = Json::number(d.to_double())
        None => ()
      }
    }
    PointerMove(x~, y~, origin~, duration~) => {
      obj["type"] = Json::string("pointerMove")
      obj["x"] = Json::number(x)
      obj["y"] = Json::number(y)
      obj["origin"] = origin.to_json()
      match duration {
        Some(d) => obj["duration"] = Json::number(d.to_double())
        None => ()
      }
    }
    PointerDown(button~) => {
      obj["type"] = Json::string("pointerDown")
      obj["button"] = Json::number(button.to_double())
    }
    PointerUp(button~) => {
      obj["type"] = Json::string("pointerUp")
      obj["button"] = Json::number(button.to_double())
    }
    PointerCancel => obj["type"] = Json::string("pointerCancel")
    KeyDown(value~) => {
      obj["type"] = Json::string("keyDown")
      obj["value"] = Json::string(value)
    }
    KeyUp(value~) => {
      obj["type"] = Json::string("keyUp")
      obj["value"] = Json::string(value)
    }
  }
  Json::object(obj)
}

///|
/// Input source type
pub enum InputSourceType {
  Pointer
  Key
  NoneSource
} derive(Show, Eq)

///|
pub fn InputSourceType::to_string(self : InputSourceType) -> String {
  match self {
    Pointer => "pointer"
    Key => "key"
    NoneSource => "none"
  }
}

///|
/// Pointer parameters
pub struct PointerParameters {
  pointer_type : PointerType
} derive(Show)

///|
pub fn PointerParameters::to_json(self : PointerParameters) -> Json {
  Json::object({ "pointerType": Json::string(self.pointer_type.to_string()) })
}

///|
/// Action sequence for input.performActions
pub struct ActionSequence {
  id : String
  source_type : InputSourceType
  actions : Array[InputAction]
  parameters : PointerParameters?
} derive(Show)

///|
pub fn ActionSequence::pointer(
  id : String,
  pointer_type : PointerType,
  actions : Array[InputAction],
) -> ActionSequence {
  { id, source_type: Pointer, actions, parameters: Some({ pointer_type, }) }
}

///|
pub fn ActionSequence::key(
  id : String,
  actions : Array[InputAction],
) -> ActionSequence {
  { id, source_type: Key, actions, parameters: None }
}

///|
pub fn ActionSequence::none(
  id : String,
  actions : Array[InputAction],
) -> ActionSequence {
  { id, source_type: NoneSource, actions, parameters: None }
}

///|
pub fn ActionSequence::to_json(self : ActionSequence) -> Json {
  let obj : Map[String, Json] = {}
  obj["type"] = Json::string(self.source_type.to_string())
  obj["id"] = Json::string(self.id)
  let actions_json : Array[Json] = []
  for action in self.actions {
    actions_json.push(action.to_json())
  }
  obj["actions"] = Json::array(actions_json)
  match self.parameters {
    Some(params) => obj["parameters"] = params.to_json()
    None => ()
  }
  Json::object(obj)
}

///|
/// Remote value for script arguments
pub struct RemoteValue {
  json : Json
} derive(Show)

///|
pub fn RemoteValue::to_json(self : RemoteValue) -> Json {
  self.json
}

///|
pub fn RemoteValue::undefined() -> RemoteValue {
  { json: Json::object({ "type": Json::string("undefined") }) }
}

///|
pub fn RemoteValue::null() -> RemoteValue {
  { json: Json::object({ "type": Json::string("null") }) }
}

///|
pub fn RemoteValue::boolean(value : Bool) -> RemoteValue {
  {
    json: Json::object({
      "type": Json::string("boolean"),
      "value": Json::boolean(value),
    }),
  }
}

///|
pub fn RemoteValue::number(value : Double) -> RemoteValue {
  {
    json: Json::object({
      "type": Json::string("number"),
      "value": Json::number(value),
    }),
  }
}

///|
pub fn RemoteValue::string(value : String) -> RemoteValue {
  {
    json: Json::object({
      "type": Json::string("string"),
      "value": Json::string(value),
    }),
  }
}

///|
pub fn RemoteValue::handle(handle : String) -> RemoteValue {
  {
    json: Json::object({
      "type": Json::string("object"),
      "handle": Json::string(handle),
    }),
  }
}

///|
pub fn RemoteValue::shared_id(shared_id : String) -> RemoteValue {
  {
    json: Json::object({
      "type": Json::string("node"),
      "sharedId": Json::string(shared_id),
    }),
  }
}

///|
/// Network cache behavior wrapper
pub struct CacheBehavior {
  value : String
} derive(Show)

///|
pub fn CacheBehavior::new(value : String) -> CacheBehavior {
  { value, }
}

///|
pub fn CacheBehavior::default() -> CacheBehavior {
  { value: "default" }
}

///|
pub fn CacheBehavior::bypass() -> CacheBehavior {
  { value: "bypass" }
}

///|
pub fn CacheBehavior::to_string(self : CacheBehavior) -> String {
  self.value
}

///|
/// network.addDataCollector params
pub struct NetworkDataCollector {
  data_types : Array[String]
  contexts : Array[String]?
} derive(Show)

///|
pub fn NetworkDataCollector::new(
  data_types : Array[String],
  contexts? : Array[String],
) -> NetworkDataCollector {
  { data_types, contexts }
}

///|
pub fn NetworkDataCollector::to_json(self : NetworkDataCollector) -> Json {
  let obj : Map[String, Json] = {}
  let data_types : Array[Json] = []
  for item in self.data_types {
    data_types.push(Json::string(item))
  }
  obj["dataTypes"] = Json::array(data_types)
  match self.contexts {
    Some(ctxs) => {
      let items : Array[Json] = []
      for ctx in ctxs {
        items.push(Json::string(ctx))
      }
      obj["contexts"] = Json::array(items)
    }
    None => ()
  }
  Json::object(obj)
}
