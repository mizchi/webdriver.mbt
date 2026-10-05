///|
// Expected output was captured from the previous derived Show implementations.
test "public Show formatting remains compatible" {
  inspect(
    Show::to_string(BidiRequest::{
      id: 7,
      method_name: "example",
      params: Some(Json::object({ "key": ["value", 2, true, null] })),
    }),
    content="{id: 7, method_name: example, params: Some(Object({key: Array([String(value), Number(2), True, Null])}))}",
  )
  inspect(
    Show::to_string(BidiResponse::{
      id: 7,
      result: Some(Json::object({ "key": ["value", 2, true, null] })),
      error: Some(BidiError::{
        error: "example",
        message: "example",
        stacktrace: "example",
      }),
    }),
    content="{id: 7, result: Some(Object({key: Array([String(value), Number(2), True, Null])})), error: Some({error: example, message: example, stacktrace: example})}",
  )
  inspect(
    Show::to_string(BidiError::{
      error: "example",
      message: "example",
      stacktrace: "example",
    }),
    content="{error: example, message: example, stacktrace: example}",
  )
  inspect(
    Show::to_string(BidiEvent::{
      event_method: "example",
      params: Json::object({ "key": ["value", 2, true, null] }),
    }),
    content="{event_method: example, params: Object({key: Array([String(value), Number(2), True, Null])})}",
  )
  inspect(
    Show::to_string(
      BidiIncoming::Response(BidiResponse::{
        id: 7,
        result: Some(Json::object({ "key": ["value", 2, true, null] })),
        error: Some(BidiError::{
          error: "example",
          message: "example",
          stacktrace: "example",
        }),
      }),
    ),
    content="Response({id: 7, result: Some(Object({key: Array([String(value), Number(2), True, Null])})), error: Some({error: example, message: example, stacktrace: example})})",
  )
  inspect(
    Show::to_string(
      BidiIncoming::Event(BidiEvent::{
        event_method: "example",
        params: Json::object({ "key": ["value", 2, true, null] }),
      }),
    ),
    content="Event({event_method: example, params: Object({key: Array([String(value), Number(2), True, Null])})})",
  )
  inspect(
    Show::to_string(TransportError::NotSupported(message="example")),
    content="NotSupported(message=example)",
  )
  inspect(
    Show::to_string(TransportError::NetworkError(message="example")),
    content="NetworkError(message=example)",
  )
  inspect(Show::to_string(TransportError::Closed), content="Closed")
  inspect(
    Show::to_string(
      ClientError::Transport(TransportError::NotSupported(message="example")),
    ),
    content="Transport(NotSupported(message=example))",
  )
  inspect(
    Show::to_string(ClientError::ParseError(message="example")),
    content="ParseError(message=example)",
  )
  inspect(
    Show::to_string(ClientError::InvalidArgument(message="example")),
    content="InvalidArgument(message=example)",
  )
  inspect(
    Show::to_string(
      ClientError::ResponseError(error=BidiError::{
        error: "example",
        message: "example",
        stacktrace: "example",
      }),
    ),
    content="ResponseError(error={error: example, message: example, stacktrace: example})",
  )
  inspect(
    Show::to_string(SessionStatus::{ ready: true, message: Some("example"), }),
    content="{ready: true, message: Some(example)}",
  )
  inspect(
    Show::to_string(SessionInfo::{
      session_id: "example",
      capabilities: Some(Json::object({ "key": ["value", 2, true, null] })),
    }),
    content="{session_id: example, capabilities: Some(Object({key: Array([String(value), Number(2), True, Null])}))}",
  )
  inspect(
    Show::to_string(NavigationResult::{ navigation: "example", url: "example", }),
    content="{navigation: example, url: example}",
  )
  inspect(
    Show::to_string(NodeReference::{
      handle: Some("example"),
      shared_id: Some("example"),
    }),
    content="{handle: Some(example), shared_id: Some(example)}",
  )
  inspect(
    Show::to_string(ResultOwnership::NoneOwnership),
    content="NoneOwnership",
  )
  inspect(Show::to_string(ResultOwnership::Root), content="Root")
  inspect(
    Show::to_string(SerializationOptions::{
      max_depth: Some(7),
      max_object_depth: Some(7),
      include_shadow_tree: Some("example"),
    }),
    content="{max_depth: Some(7), max_object_depth: Some(7), include_shadow_tree: Some(example)}",
  )
  inspect(Show::to_string(InnerTextMatchType::Full), content="Full")
  inspect(Show::to_string(InnerTextMatchType::Partial), content="Partial")
  inspect(
    Show::to_string(InnerTextLocator::{
      text: "example",
      match_type: InnerTextMatchType::Full,
      ignore_case: true,
    }),
    content="{text: example, match_type: Full, ignore_case: true}",
  )
  inspect(
    Show::to_string(AccessibilityLocator::{
      role: "example",
      name: Some("example"),
      exact: Some(true),
    }),
    content="{role: example, name: Some(example), exact: Some(true)}",
  )
  inspect(Show::to_string(Locator::Css("example")), content="Css(example)")
  inspect(Show::to_string(Locator::Xpath("example")), content="Xpath(example)")
  inspect(
    Show::to_string(
      Locator::InnerText(InnerTextLocator::{
        text: "example",
        match_type: InnerTextMatchType::Full,
        ignore_case: true,
      }),
    ),
    content="InnerText({text: example, match_type: Full, ignore_case: true})",
  )
  inspect(
    Show::to_string(
      Locator::Accessibility(AccessibilityLocator::{
        role: "example",
        name: Some("example"),
        exact: Some(true),
      }),
    ),
    content="Accessibility({role: example, name: Some(example), exact: Some(true)})",
  )
  inspect(
    Show::to_string(
      Locator::Custom(
        type_name="example",
        value=Json::object({ "key": ["value", 2, true, null] }),
      ),
    ),
    content="Custom(type_name=example, value=Object({key: Array([String(value), Number(2), True, Null])}))",
  )
  inspect(Show::to_string(PointerType::Mouse), content="Mouse")
  inspect(Show::to_string(PointerType::Pen), content="Pen")
  inspect(Show::to_string(PointerType::Touch), content="Touch")
  inspect(Show::to_string(ActionOrigin::Viewport), content="Viewport")
  inspect(Show::to_string(ActionOrigin::Pointer), content="Pointer")
  inspect(
    Show::to_string(ActionOrigin::ElementHandle(handle="example")),
    content="ElementHandle(handle=example)",
  )
  inspect(
    Show::to_string(ActionOrigin::ElementSharedId(shared_id="example")),
    content="ElementSharedId(shared_id=example)",
  )
  inspect(
    Show::to_string(InputAction::Pause(duration=Some(7))),
    content="Pause(duration=Some(7))",
  )
  inspect(
    Show::to_string(
      InputAction::PointerMove(
        x=1.5,
        y=1.5,
        origin=ActionOrigin::Viewport,
        duration=Some(7),
      ),
    ),
    content="PointerMove(x=1.5, y=1.5, origin=Viewport, duration=Some(7))",
  )
  inspect(
    Show::to_string(InputAction::PointerDown(button=7)),
    content="PointerDown(button=7)",
  )
  inspect(
    Show::to_string(InputAction::PointerUp(button=7)),
    content="PointerUp(button=7)",
  )
  inspect(Show::to_string(InputAction::PointerCancel), content="PointerCancel")
  inspect(
    Show::to_string(InputAction::KeyDown(value="example")),
    content="KeyDown(value=example)",
  )
  inspect(
    Show::to_string(InputAction::KeyUp(value="example")),
    content="KeyUp(value=example)",
  )
  inspect(Show::to_string(InputSourceType::Pointer), content="Pointer")
  inspect(Show::to_string(InputSourceType::Key), content="Key")
  inspect(Show::to_string(InputSourceType::NoneSource), content="NoneSource")
  inspect(
    Show::to_string(PointerParameters::{ pointer_type: PointerType::Mouse, }),
    content="{pointer_type: Mouse}",
  )
  inspect(
    Show::to_string(ActionSequence::{
      id: "example",
      source_type: InputSourceType::Pointer,
      actions: [InputAction::Pause(duration=Some(7))],
      parameters: Some(PointerParameters::{ pointer_type: PointerType::Mouse, }),
    }),
    content="{id: example, source_type: Pointer, actions: [Pause(duration=Some(7))], parameters: Some({pointer_type: Mouse})}",
  )
  inspect(
    Show::to_string(RemoteValue::{
      json: Json::object({ "key": ["value", 2, true, null] }),
    }),
    content="{json: Object({key: Array([String(value), Number(2), True, Null])})}",
  )
  inspect(
    Show::to_string(CacheBehavior::{ value: "example", }),
    content="{value: example}",
  )
  inspect(
    Show::to_string(NetworkDataCollector::{
      data_types: ["example"],
      contexts: Some(["example"]),
    }),
    content="{data_types: [example], contexts: Some([example])}",
  )
  inspect(
    Show::to_string(BackendError::InvalidArgument(message="example")),
    content="InvalidArgument(message=example)",
  )
  inspect(
    Show::to_string(BackendError::NotFound(message="example")),
    content="NotFound(message=example)",
  )
  inspect(
    Show::to_string(BackendCapabilities::{
      navigation: true,
      evaluate: true,
      element_lookup: true,
      input_actions: true,
      screenshot: true,
    }),
    content="{navigation: true, evaluate: true, element_lookup: true, input_actions: true, screenshot: true}",
  )
}
