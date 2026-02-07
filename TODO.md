# TODO (WebDriver BiDi spec layer)

Scope: protocol parsing + spec behavior, independent of any browser backend.

## Protocol core
- [x] Define BiDi request/response/event types and JSON codec.
- [ ] Central dispatch for `session`, `browser`, `browsingContext`, `script`, `input`, `network`, `log`.
- [ ] Validate params strictly and return spec error codes/messages.
- [ ] Event subscription system (global + per-context) and ordering guarantees.

## browsingContext
- [x] `getTree` with `root`/`maxDepth` handling.
- [x] `create`, `close`, `navigate` with `wait` semantics.
- [ ] `locateNodes` with selector strategies and return node references (handle/sharedId).
- [x] `captureScreenshot` (delegates to backend).

## script
- [x] `evaluate` / `callFunction` resultOwnership and serializationOptions.
- [x] support `handle` / `sharedId` references.
- [x] `addPreloadScript` / `removePreloadScript` and per-context application.
- [x] `disown` for releasing handles.

## input / network / log
- [x] `input.performActions` / `releaseActions` mapping (delegates to backend).
- [x] `network.addDataCollector`, `setCacheBehavior`, and event emission hooks.
- [x] `log.entryAdded` event emission and filtering.

## Backend contract
- [ ] Define a backend trait/interface for: navigation, evaluate, element lookup, input actions, screenshots, and capability reporting.
- [ ] Provide minimal in-memory/mock backend for unit tests.

## Tests
- [x] Unit tests for codec + validation.
- [ ] Protocol behavior tests (event ordering, errors, subscriptions).
