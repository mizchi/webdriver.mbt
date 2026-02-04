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
