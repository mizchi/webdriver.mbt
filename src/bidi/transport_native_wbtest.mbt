///|
async test "native Chrome pipe transport reports unsupported" {
  let transport = Transport::ChromePipe(ChromePipeState::new(true))
  assert_true(transport.connect() is Err(NotSupported(_)))
}
