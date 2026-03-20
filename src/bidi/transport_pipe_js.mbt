///| Chrome BiDi Pipe Transport (JS target)
///|
///| Launches Chrome with --remote-debugging-pipe and communicates
///| via stdio fd 3 (write) and fd 4 (read) using null-delimited JSON.

///|
/// Launch Chrome with BiDi pipe and return a connected transport.
pub fn Transport::chrome_bidi_pipe(headless? : Bool = true) -> Transport {
  ChromePipe(ChromePipeState::new(headless))
}

///|
fn ensure_chrome_pipe_connected(
  state : ChromePipeState,
) -> Result[Int, TransportError] {
  if state.closed.val {
    return Err(Closed)
  }
  match state.proc_id.val {
    Some(id) => Ok(id)
    None => {
      let id = ffi_launch_chrome_pipe(state.headless)
      if id < 0 {
        Err(NetworkError(message="Failed to launch Chrome with BiDi pipe"))
      } else {
        state.proc_id.val = Some(id)
        Ok(id)
      }
    }
  }
}

// =============================================================================
// FFI: Chrome process management with BiDi pipe
// =============================================================================

///|
extern "js" fn ffi_launch_chrome_pipe(headless : Bool) -> Int =
  #| (headless) => {
  #|   const { spawnSync, spawn } = require('node:child_process');
  #|   const { existsSync } = require('node:fs');
  #|   const os = require('node:os');
  #|
  #|   const candidates = [
  #|     process.env.CHROME_PATH,
  #|     '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  #|     '/Applications/Chromium.app/Contents/MacOS/Chromium',
  #|     '/usr/bin/google-chrome',
  #|     '/usr/bin/google-chrome-stable',
  #|     '/usr/bin/chromium',
  #|     '/usr/bin/chromium-browser',
  #|     '/snap/bin/chromium',
  #|   ].filter(Boolean);
  #|
  #|   let chromePath = null;
  #|   for (const p of candidates) {
  #|     if (existsSync(p)) { chromePath = p; break; }
  #|   }
  #|   if (!chromePath) return -1;
  #|
  #|   const g = globalThis;
  #|   if (!g.__chrome_pipes) g.__chrome_pipes = { nextId: 1, procs: new Map() };
  #|
  #|   const id = g.__chrome_pipes.nextId++;
  #|   const args = [
  #|     headless ? '--headless=new' : '',
  #|     '--remote-debugging-pipe',
  #|     '--no-first-run',
  #|     '--no-default-browser-check',
  #|     '--disable-background-networking',
  #|     '--disable-default-apps',
  #|     '--disable-extensions',
  #|     '--disable-hang-monitor',
  #|     '--disable-popup-blocking',
  #|     '--disable-sync',
  #|     '--disable-translate',
  #|     '--metrics-recording-only',
  #|     '--safebrowsing-disable-auto-update',
  #|     '--user-data-dir=' + os.tmpdir() + '/mbt-bidi-' + process.pid + '-' + id,
  #|   ].filter(Boolean);
  #|
  #|   // Chrome with --remote-debugging-pipe uses fd 3 (write to Chrome) and fd 4 (read from Chrome)
  #|   const proc = spawn(chromePath, args, {
  #|     stdio: ['pipe', 'pipe', 'pipe', 'pipe', 'pipe'],
  #|   });
  #|
  #|   const writePipe = proc.stdio[3]; // We write commands here
  #|   const readPipe = proc.stdio[4];  // We read responses here
  #|
  #|   const queue = [];
  #|   const waiters = [];
  #|   let buf = '';
  #|
  #|   readPipe.setEncoding('utf8');
  #|   readPipe.on('data', (chunk) => {
  #|     buf += chunk;
  #|     // BiDi pipe uses \0 as message delimiter
  #|     let idx;
  #|     while ((idx = buf.indexOf('\0')) !== -1) {
  #|       const msg = buf.slice(0, idx);
  #|       buf = buf.slice(idx + 1);
  #|       if (msg.length > 0) {
  #|         if (waiters.length > 0) {
  #|           waiters.shift()(msg);
  #|         } else {
  #|           queue.push(msg);
  #|         }
  #|       }
  #|     }
  #|   });
  #|
  #|   readPipe.on('end', () => {
  #|     while (waiters.length > 0) waiters.shift()(null);
  #|   });
  #|
  #|   g.__chrome_pipes.procs.set(id, { proc, writePipe, readPipe, queue, waiters });
  #|   return id;
  #| }

///|
extern "js" fn ffi_chrome_pipe_send(id : Int, message : String) -> Unit =
  #| (id, message) => {
  #|   const entry = globalThis.__chrome_pipes?.procs.get(id);
  #|   if (!entry) throw new Error('Chrome pipe not found');
  #|   // BiDi pipe uses \0 as message delimiter
  #|   entry.writePipe.write(message + '\0');
  #| }

///|
extern "js" fn ffi_chrome_pipe_recv(id : Int) -> @js_async.Promise[String?] =
  #| (id) => {
  #|   const entry = globalThis.__chrome_pipes?.procs.get(id);
  #|   if (!entry) throw new Error('Chrome pipe not found');
  #|   if (entry.queue.length > 0) return Promise.resolve(entry.queue.shift());
  #|   return new Promise((resolve) => entry.waiters.push(resolve));
  #| }

///|
extern "js" fn ffi_chrome_pipe_close(id : Int) -> Unit =
  #| (id) => {
  #|   const entry = globalThis.__chrome_pipes?.procs.get(id);
  #|   if (!entry) return;
  #|   try { entry.proc.kill('SIGTERM'); } catch {}
  #|   globalThis.__chrome_pipes.procs.delete(id);
  #| }
