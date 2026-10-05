///|
// Keep the public Show representation stable without deprecated collection impls.
fn[T] show_optional(value : T?, render : (T) -> String) -> String {
  match value {
    None => "None"
    Some(value) => "Some(" + render(value) + ")"
  }
}

///|
fn[T] show_array(values : Array[T], render : (T) -> String) -> String {
  "[" + values.map(render).join(", ") + "]"
}

///|
fn show_json(value : Json) -> String {
  match value {
    Null => "Null"
    True => "True"
    False => "False"
    Number(value, ..) => "Number(" + Show::to_string(value) + ")"
    String(value) => "String(" + value + ")"
    Array(values) => "Array(" + show_array(values, show_json) + ")"
    Object(values) => {
      let fields : Array[String] = []
      for key, value in values {
        fields.push(key + ": " + show_json(value))
      }
      "Object({" + fields.join(", ") + "})"
    }
  }
}

///|
pub impl Show for BidiRequest with fn output(self, logger) {
  logger.write_string(
    "{" +
    "id: " +
    Show::to_string(self.id) +
    ", method_name: " +
    Show::to_string(self.method_name) +
    ", params: " +
    show_optional(self.params, value => show_json(value)) +
    "}",
  )
}

///|
pub impl Show for BidiResponse with fn output(self, logger) {
  logger.write_string(
    "{" +
    "id: " +
    Show::to_string(self.id) +
    ", result: " +
    show_optional(self.result, value => show_json(value)) +
    ", error: " +
    show_optional(self.error, value => Show::to_string(value)) +
    "}",
  )
}

///|
pub impl Show for BidiError with fn output(self, logger) {
  logger.write_string(
    "{" +
    "error: " +
    Show::to_string(self.error) +
    ", message: " +
    Show::to_string(self.message) +
    ", stacktrace: " +
    Show::to_string(self.stacktrace) +
    "}",
  )
}

///|
pub impl Show for BidiEvent with fn output(self, logger) {
  logger.write_string(
    "{" +
    "event_method: " +
    Show::to_string(self.event_method) +
    ", params: " +
    show_json(self.params) +
    "}",
  )
}

///|
pub impl Show for BidiIncoming with fn output(self, logger) {
  match self {
    Response(arg0) =>
      logger.write_string("Response(" + "" + Show::to_string(arg0) + ")")
    Event(arg0) =>
      logger.write_string("Event(" + "" + Show::to_string(arg0) + ")")
  }
}

///|
pub impl Show for TransportError with fn output(self, logger) {
  match self {
    NotSupported(message=arg0) =>
      logger.write_string(
        "NotSupported(" + "message=" + Show::to_string(arg0) + ")",
      )
    NetworkError(message=arg0) =>
      logger.write_string(
        "NetworkError(" + "message=" + Show::to_string(arg0) + ")",
      )
    Closed => logger.write_string("Closed")
  }
}

///|
pub impl Show for ClientError with fn output(self, logger) {
  match self {
    Transport(arg0) =>
      logger.write_string("Transport(" + "" + Show::to_string(arg0) + ")")
    ParseError(message=arg0) =>
      logger.write_string(
        "ParseError(" + "message=" + Show::to_string(arg0) + ")",
      )
    InvalidArgument(message=arg0) =>
      logger.write_string(
        "InvalidArgument(" + "message=" + Show::to_string(arg0) + ")",
      )
    ResponseError(error=arg0) =>
      logger.write_string(
        "ResponseError(" + "error=" + Show::to_string(arg0) + ")",
      )
  }
}

///|
pub impl Show for SessionStatus with fn output(self, logger) {
  logger.write_string(
    "{" +
    "ready: " +
    Show::to_string(self.ready) +
    ", message: " +
    show_optional(self.message, value => Show::to_string(value)) +
    "}",
  )
}

///|
pub impl Show for SessionInfo with fn output(self, logger) {
  logger.write_string(
    "{" +
    "session_id: " +
    Show::to_string(self.session_id) +
    ", capabilities: " +
    show_optional(self.capabilities, value => show_json(value)) +
    "}",
  )
}

///|
pub impl Show for NavigationResult with fn output(self, logger) {
  logger.write_string(
    "{" +
    "navigation: " +
    Show::to_string(self.navigation) +
    ", url: " +
    Show::to_string(self.url) +
    "}",
  )
}

///|
pub impl Show for NodeReference with fn output(self, logger) {
  logger.write_string(
    "{" +
    "handle: " +
    show_optional(self.handle, value => Show::to_string(value)) +
    ", shared_id: " +
    show_optional(self.shared_id, value => Show::to_string(value)) +
    "}",
  )
}

///|
pub impl Show for ResultOwnership with fn output(self, logger) {
  match self {
    NoneOwnership => logger.write_string("NoneOwnership")
    Root => logger.write_string("Root")
  }
}

///|
pub impl Show for SerializationOptions with fn output(self, logger) {
  logger.write_string(
    "{" +
    "max_depth: " +
    show_optional(self.max_depth, value => Show::to_string(value)) +
    ", max_object_depth: " +
    show_optional(self.max_object_depth, value => Show::to_string(value)) +
    ", include_shadow_tree: " +
    show_optional(self.include_shadow_tree, value => Show::to_string(value)) +
    "}",
  )
}

///|
pub impl Show for InnerTextMatchType with fn output(self, logger) {
  match self {
    Full => logger.write_string("Full")
    Partial => logger.write_string("Partial")
  }
}

///|
pub impl Show for InnerTextLocator with fn output(self, logger) {
  logger.write_string(
    "{" +
    "text: " +
    Show::to_string(self.text) +
    ", match_type: " +
    Show::to_string(self.match_type) +
    ", ignore_case: " +
    Show::to_string(self.ignore_case) +
    "}",
  )
}

///|
pub impl Show for AccessibilityLocator with fn output(self, logger) {
  logger.write_string(
    "{" +
    "role: " +
    Show::to_string(self.role) +
    ", name: " +
    show_optional(self.name, value => Show::to_string(value)) +
    ", exact: " +
    show_optional(self.exact, value => Show::to_string(value)) +
    "}",
  )
}

///|
pub impl Show for Locator with fn output(self, logger) {
  match self {
    Css(arg0) => logger.write_string("Css(" + "" + Show::to_string(arg0) + ")")
    Xpath(arg0) =>
      logger.write_string("Xpath(" + "" + Show::to_string(arg0) + ")")
    InnerText(arg0) =>
      logger.write_string("InnerText(" + "" + Show::to_string(arg0) + ")")
    Accessibility(arg0) =>
      logger.write_string("Accessibility(" + "" + Show::to_string(arg0) + ")")
    Custom(type_name=arg0, value=arg1) =>
      logger.write_string(
        "Custom(" +
        "type_name=" +
        Show::to_string(arg0) +
        ", value=" +
        show_json(arg1) +
        ")",
      )
  }
}

///|
pub impl Show for PointerType with fn output(self, logger) {
  match self {
    Mouse => logger.write_string("Mouse")
    Pen => logger.write_string("Pen")
    Touch => logger.write_string("Touch")
  }
}

///|
pub impl Show for ActionOrigin with fn output(self, logger) {
  match self {
    Viewport => logger.write_string("Viewport")
    Pointer => logger.write_string("Pointer")
    ElementHandle(handle=arg0) =>
      logger.write_string(
        "ElementHandle(" + "handle=" + Show::to_string(arg0) + ")",
      )
    ElementSharedId(shared_id=arg0) =>
      logger.write_string(
        "ElementSharedId(" + "shared_id=" + Show::to_string(arg0) + ")",
      )
  }
}

///|
pub impl Show for InputAction with fn output(self, logger) {
  match self {
    Pause(duration=arg0) =>
      logger.write_string(
        "Pause(" +
        "duration=" +
        show_optional(arg0, value => Show::to_string(value)) +
        ")",
      )
    PointerMove(x=arg0, y=arg1, origin=arg2, duration=arg3) =>
      logger.write_string(
        "PointerMove(" +
        "x=" +
        Show::to_string(arg0) +
        ", y=" +
        Show::to_string(arg1) +
        ", origin=" +
        Show::to_string(arg2) +
        ", duration=" +
        show_optional(arg3, value => Show::to_string(value)) +
        ")",
      )
    PointerDown(button=arg0) =>
      logger.write_string(
        "PointerDown(" + "button=" + Show::to_string(arg0) + ")",
      )
    PointerUp(button=arg0) =>
      logger.write_string(
        "PointerUp(" + "button=" + Show::to_string(arg0) + ")",
      )
    PointerCancel => logger.write_string("PointerCancel")
    KeyDown(value=arg0) =>
      logger.write_string("KeyDown(" + "value=" + Show::to_string(arg0) + ")")
    KeyUp(value=arg0) =>
      logger.write_string("KeyUp(" + "value=" + Show::to_string(arg0) + ")")
  }
}

///|
pub impl Show for InputSourceType with fn output(self, logger) {
  match self {
    Pointer => logger.write_string("Pointer")
    Key => logger.write_string("Key")
    NoneSource => logger.write_string("NoneSource")
  }
}

///|
pub impl Show for PointerParameters with fn output(self, logger) {
  logger.write_string(
    "{" + "pointer_type: " + Show::to_string(self.pointer_type) + "}",
  )
}

///|
pub impl Show for ActionSequence with fn output(self, logger) {
  logger.write_string(
    "{" +
    "id: " +
    Show::to_string(self.id) +
    ", source_type: " +
    Show::to_string(self.source_type) +
    ", actions: " +
    show_array(self.actions, value => Show::to_string(value)) +
    ", parameters: " +
    show_optional(self.parameters, value => Show::to_string(value)) +
    "}",
  )
}

///|
pub impl Show for RemoteValue with fn output(self, logger) {
  logger.write_string("{" + "json: " + show_json(self.json) + "}")
}

///|
pub impl Show for CacheBehavior with fn output(self, logger) {
  logger.write_string("{" + "value: " + Show::to_string(self.value) + "}")
}

///|
pub impl Show for NetworkDataCollector with fn output(self, logger) {
  logger.write_string(
    "{" +
    "data_types: " +
    show_array(self.data_types, value => Show::to_string(value)) +
    ", contexts: " +
    show_optional(self.contexts, value => {
      show_array(value, value => Show::to_string(value))
    }) +
    "}",
  )
}

///|
pub impl Show for BackendError with fn output(self, logger) {
  match self {
    InvalidArgument(message=arg0) =>
      logger.write_string(
        "InvalidArgument(" + "message=" + Show::to_string(arg0) + ")",
      )
    NotFound(message=arg0) =>
      logger.write_string(
        "NotFound(" + "message=" + Show::to_string(arg0) + ")",
      )
  }
}

///|
pub impl Show for BackendCapabilities with fn output(self, logger) {
  logger.write_string(
    "{" +
    "navigation: " +
    Show::to_string(self.navigation) +
    ", evaluate: " +
    Show::to_string(self.evaluate) +
    ", element_lookup: " +
    Show::to_string(self.element_lookup) +
    ", input_actions: " +
    Show::to_string(self.input_actions) +
    ", screenshot: " +
    Show::to_string(self.screenshot) +
    "}",
  )
}

///|
pub extend BackendError with Show::{to_string, output}

///|
pub extend BackendError with Eq::{not_equal, equal}

///|
pub extend BackendCapabilities with Show::{to_string, output}

///|
pub extend BackendCapabilities with Eq::{not_equal, equal}

///|
pub extend BidiRequest with Show::{to_string, output}

///|
pub extend BidiResponse with Show::{to_string, output}

///|
pub extend BidiError with Show::{to_string, output}

///|
pub extend BidiEvent with Show::{to_string, output}

///|
pub extend BidiIncoming with Show::{to_string, output}

///|
pub extend TransportError with Show::{to_string, output}

///|
pub extend ClientError with Show::{to_string, output}

///|
pub extend SessionStatus with Show::{to_string, output}

///|
pub extend SessionInfo with Show::{to_string, output}

///|
pub extend NavigationResult with Show::{to_string, output}

///|
pub extend NodeReference with Show::{to_string, output}

///|
pub extend ResultOwnership with Show::{output}

///|
pub extend ResultOwnership with Eq::{not_equal, equal}

///|
pub extend SerializationOptions with Show::{to_string, output}

///|
pub extend InnerTextMatchType with Show::{output}

///|
pub extend InnerTextMatchType with Eq::{not_equal, equal}

///|
pub extend InnerTextLocator with Show::{to_string, output}

///|
pub extend AccessibilityLocator with Show::{to_string, output}

///|
pub extend Locator with Show::{to_string, output}

///|
pub extend PointerType with Show::{output}

///|
pub extend PointerType with Eq::{not_equal, equal}

///|
pub extend ActionOrigin with Show::{to_string, output}

///|
pub extend InputAction with Show::{to_string, output}

///|
pub extend InputSourceType with Show::{output}

///|
pub extend InputSourceType with Eq::{not_equal, equal}

///|
pub extend PointerParameters with Show::{to_string, output}

///|
pub extend ActionSequence with Show::{to_string, output}

///|
pub extend RemoteValue with Show::{to_string, output}

///|
pub extend CacheBehavior with Show::{output}

///|
pub extend NetworkDataCollector with Show::{to_string, output}
