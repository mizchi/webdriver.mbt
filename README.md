# webdriver.mbt

MoonBit で WebDriver BiDi を喋るためのクライアントライブラリ。

## Package

- `mizchi/webdriver.mbt/bidi`

## Quick Start (JS)

```mbt
let transport = @bidi.Transport::websocket("ws://127.0.0.1:9222")
let client = @bidi.BidiClient::new(transport)
let status = await client.session_status()
```

## E2E (Headless Chromium)

```sh
pnpm install
pnpm exec playwright install chromium
moon test src/bidi/e2e_test.mbt --target js -v
```
