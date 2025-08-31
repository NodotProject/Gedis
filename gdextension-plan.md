# Plan: Port Gedis to a C GDExtension wrapping hiredis

This plan converts the current GDScript, in-memory "redis-like" Gedis plugin into a native C GDExtension that wraps the hiredis C client library and talks to a real Redis server. The goal is to keep the existing GDScript API as compatible as possible for a drop-in replacement, while providing native performance and real Redis semantics.

## Objectives
- Provide a GDExtension written in C (not C++) that exposes a `Gedis` class with methods mirroring the current API.
- Internally, use hiredis (sync API to start; optional async later) to connect and execute Redis commands.
- Preserve API names and return types where practical; document behavior changes due to Redis’s string/binary model.
- Offer easy configuration (host/port/db/password/TLS) and automatic connection management.
- Ship as an addon that registers an autoloaded singleton named `Gedis` for minimal migration.
- Add first-class Pub/Sub support (PUBLISH, SUBSCRIBE/PSUBSCRIBE, UNSUBSCRIBE/PUNSUBSCRIBE) using a dedicated background thread and Godot signals for message delivery.

## Non-Goals (initial phase)
- Full async request/response for general commands (beyond what’s needed internally for Pub/Sub). MVP keeps command calls synchronous.
- Binary-safe Variant transport or arbitrary Variant persistence (see Type Conversion below).
- Redis Cluster, Sentinel, or TLS (TLS is nice-to-have if available via hiredis-tls; can be a later milestone).

## Public API Mapping
Mirror the current GDScript methods; call Redis equivalents under the hood.

- Strings/Numbers
  - set_value(key, value) -> SET key value
  - get_value(key, default=null) -> GET key; return default if nil
  - del(key) -> DEL key -> int (1 if deleted else 0)
  - exists(key) -> EXISTS key -> bool
  - incr(key, amount=1) -> INCRBY key amount -> int
  - decr(key, amount=1) -> DECRBY key amount -> int
  - keys(pattern="*") -> use SCAN with pattern; return Array[String]

- Hashes
  - hset(key, field, value) -> HSET key field value
  - hget(key, field, default=null) -> HGET key field (default if nil)
  - hdel(key, field) -> HDEL key field -> int
  - hgetall(key) -> HGETALL key -> Dictionary[String->String]

- Lists
  - lpush(key, value) -> LPUSH key value -> int length
  - rpush(key, value) -> RPUSH key value -> int length
  - lpop(key) -> LPOP key -> Variant (null if empty/missing)
  - rpop(key) -> RPOP key -> Variant
  - llen(key) -> LLEN key -> int

- Sets
  - sadd(key, member) -> SADD key member -> int (1 if added)
  - srem(key, member) -> SREM key member -> int (1 if removed)
  - smembers(key) -> SMEMBERS key -> Array[String]
  - sismember(key, member) -> SISMEMBER key member -> bool

- Expiry
  - expire(key, seconds) -> EXPIRE key seconds -> bool
  - ttl(key) -> TTL key -> int (-2 missing, -1 no ttl, or >=0)
  - persist(key) -> PERSIST key -> bool

- Admin
  - flushall() -> FLUSHALL (guarded behind a config flag to prevent accidents)

- Pub/Sub
  - publish(channel: String, message: Variant) -> PUBLISH channel message -> int (number of clients that received the message)
  - subscribe(channel_or_channels: String|Array[String]) -> SUBSCRIBE … -> int (count of active channel subscriptions)
  - psubscribe(pattern_or_patterns: String|Array[String]) -> PSUBSCRIBE … -> int (count of active pattern subscriptions)
  - unsubscribe(channel_or_channels: String|Array[String]=null) -> UNSUBSCRIBE … -> int (remaining channel subscriptions)
  - punsubscribe(pattern_or_patterns: String|Array[String]=null) -> PUNSUBSCRIBE … -> int (remaining pattern subscriptions)
  - is_pubsub_enabled() -> bool
  - get_pubsub_subscriptions() -> Dictionary with keys: channels: Array[String], patterns: Array[String]

Notes:
- Type checking is left to Redis; if an operation hits the wrong type, return an error through a Godot Error + message or throw a Godot error (see Error Handling).
- keys(pattern) will use SCAN to avoid blocking and return the collected set (bounded per call; configurable max iterations).
- Pub/Sub message delivery is via signals (see Class Design) and is independent from command responses.

## Type Conversion Strategy
Redis is byte/string-based; Godot Variants are typed.

- Outbound values: convert Variant -> String bytes using:
  - int/float/bool -> string via standard formatting
  - String -> UTF-8 bytes
  - PackedByteArray -> binary-safe pass-through (base64 if necessary; see below)
  - Dictionary/Array/other -> JSON-encode (configurable toggle: json_encode_outbound)
- Inbound values: convert Redis bulk strings -> Variant using:
  - Try integer parse if command is numeric (incr/decr/llen/ttl/etc.)
  - Otherwise return String (UTF-8); optionally attempt JSON parse (configurable: json_decode_inbound) and fall back to String
- Binary values:
  - MVP: treat as String (UTF-8) and document limitation; optional later: binary-safe mode returning PackedByteArray
- Pub/Sub payloads follow the same inbound/outbound conversion rules as above.

Defaults in v0.1: strings and integers only; JSON encode/decode optional via configuration. Document that the API is not a drop-in for complex Variant persistence.

## Class Design (GDExtension, C)
- Class name: `Gedis` (extends `Node`), registered via GDExtension C API.
- Properties (settable in Inspector or by script):
  - host: String (default "127.0.0.1")
  - port: int (default 6379)
  - db: int (default 0)
  - password: String (optional)
  - use_tls: bool (default false, later)
  - connect_on_ready: bool (default true)
  - allow_flushall: bool (default false)
  - scan_batch: int (default 1000)
  - json_encode_outbound: bool (default false)
  - json_decode_inbound: bool (default false)
  - pubsub_enabled: bool (default false) — if true, pub/sub thread can start when subscribing
  - pubsub_queue_max: int (default 1000) — max queued messages before applying policy
  - pubsub_queue_policy: String ("drop_oldest" | "drop_newest" | "block") — default "drop_oldest"
  - pubsub_reconnect_delay_ms: int (default 500) and max backoff (e.g., 5000)
- Lifecycle:
  - _ready(): if connect_on_ready, connect(); if db>0, SELECT db.
  - _process(delta): if pubsub is enabled, drain the pubsub queue and emit signals on the main thread.
  - _exit_tree(): stop pubsub thread, disconnect.
- Methods: as per API mapping, plus connect()/disconnect()/is_connected().
- Signals:
  - connected
  - disconnected
  - error(code: int, message: String)
  - pubsub_message(channel: String, payload: Variant)
  - pubsub_pmessage(pattern: String, channel: String, payload: Variant)
  - pubsub_subscribed(channel: String)
  - pubsub_unsubscribed(channel: String)
  - pubsub_psubscribed(pattern: String)
  - pubsub_punsubscribed(pattern: String)

## Connection Management
- Use hiredis synchronous API (redisContext*).
- Maintain two contexts:
  - command_ctx for regular commands.
  - pubsub_ctx for subscriptions, owned by a dedicated background thread.
- Connect with timeout (configurable, e.g., 2s). Authenticate and select DB if provided.
- Reconnect strategy:
  - For command_ctx: if a command detects a disconnected context, attempt one reconnect; if still failing, emit error and return a safe default (null/0/false) depending on method.
  - For pubsub_ctx: thread attempts exponential backoff reconnect; upon reconnection, reissue all active SUBSCRIBE/PSUBSCRIBE.

## Threading Model
- Commands: synchronous on the calling thread. Document that long operations should run off the main thread (users can use Godot’s Thread or call deferred).
- Pub/Sub: a dedicated internal thread blocks on redisGetReply() for pubsub_ctx and pushes events into a thread-safe queue. The main thread drains the queue in _process() and emits signals.
- Queue implementation: ring buffer protected by a mutex; when full, apply pubsub_queue_policy.

## Pub/Sub Implementation Details
- Subscribing:
  - Calling subscribe()/psubscribe() ensures pubsub_enabled and starts the pubsub thread if not running. The thread establishes pubsub_ctx.
  - Track sets of channels and patterns locally.
- Publishing:
  - publish() uses command_ctx (not pubsub_ctx) and returns the integer receivers count.
- Message reading loop:
  - Block on redisGetReply(pubsub_ctx). Parse replies:
    - ["message", channel, payload]
    - ["pmessage", pattern, channel, payload]
    - ["subscribe", channel, count], ["unsubscribe", channel, count]
    - ["psubscribe", pattern, count], ["punsubscribe", pattern, count]
  - Convert payload with inbound rules and enqueue events.
- Emitting:
  - In _process(), dequeue and emit the appropriate signals. Avoid emitting from the background thread.
- Shutdown:
  - Signal the thread to stop, issue UNSUBSCRIBE/PUNSUBSCRIBE (optional), free pubsub_ctx cleanly.
- Re-subscription after reconnect:
  - After pubsub_ctx reconnects and optional AUTH/SELECT, reissue all SUBSCRIBE/PSUBSCRIBE before resuming reads.

## Error Handling
- On Redis command error (type mismatch, etc.), emit `error` signal and return safe defaults:
  - get_value/hget/lpop/rpop/smembers -> null/[]
  - exists/sismember -> false
  - numeric returns -> 0 (or -2/-1 for ttl per Redis semantics)
- Provide `get_last_error()` method returning code + message for debugging.
- Pub/Sub specific:
  - pubsub thread failures (disconnects, timeouts) emit `error` with context and attempt reconnect automatically when enabled.
  - If pubsub queue overflows and policy drops messages, emit a one-shot warning via `error` signal including dropped count.

## Project Structure
- addons/Gedis_native/ (new)
  - src/
    - gedis.c (class implementation, method dispatch)
    - gedis.h
    - binding.c (GDExtension entry points and registration)
    - util.c/.h (conversion helpers Variant<->String/JSON, reply parsing)
    - redis_client.c/.h (hiredis wrapper: connect, exec, helpers)
    - pubsub.c/.h (pubsub thread, queue, subscription tracking)
  - thirdparty/
    - hiredis/ (as submodule or vendored source; minimal set for sync client)
  - SConstruct (build for platforms; see Build System)
  - config.gdextension (library definition)
  - gdextension_exports.json (platform mappings, optional)
  - plugin.cfg (Editor plugin metadata)
  - autoload.gd (tiny GDScript shim if needed, or register as autoload directly)
- Keep existing GDScript addon (addons/Gedis) for reference; the new addon supersedes it.

## Build System
- Use SCons (consistent with Godot ecosystem) to build a shared library per platform/arch.
- Dependencies:
  - hiredis built as static library from thirdparty and linked into the shared library.
  - No C++/godot-cpp; use GDExtension C headers from the Godot SDK (include via submodule or downloaded during build).
- Outputs:
  - bin/linux.x86_64/libgedis_native.so
  - bin/windows.x86_64/gedis_native.dll
  - bin/macos.universal/libgedis_native.dylib
- config.gdextension references the above per platform.

## Registration (GDExtension C)
- Provide `gdextension_initialize` and `gdextension_terminate` functions.
- Register class `Gedis` with properties and methods using the C interface (Godot 4.2+ provides C API headers: `godot/gdextension_interface.h`).
- Ensure Variant marshalling (StringName, Variant, Dictionary, Array) is handled via core API functions; wrap helpers in util.c.

## Security/Operational Safeguards
- `flushall()` requires `allow_flushall=true` or returns immediately with error signal.
- `keys()` implemented via SCAN to avoid blocking; cap iterations and batch size (configurable). Provide `keys_exact()` to use KEYS directly for tests/debugging.
- Timeouts for connect and commands (e.g., 2s connect, 2s command) to avoid lockups.
- Pub/Sub runs on a separate connection; document that subscribing to high-volume channels may overwhelm the queue. Provide queue size and policy controls.

## Testing Strategy
- Keep existing GUT tests conceptually, but adapt to expect real Redis semantics. Replace setup with a Redis server.
- Add a Docker Compose file for local Redis.
- Add CI workflow (optional) to spin up Redis service and run headless Godot tests.
- New tests:
  - connection/auth, reconnection, type errors, SCAN-based keys
  - publish/subscribe basics (single channel, multiple channels)
  - pattern subscriptions and correct routing
  - high-rate publish burst and queue overflow policies
  - pubsub reconnection: kill Redis, restart, ensure auto-resubscribe

## Migration Notes
- Most APIs are drop-in if values are strings/ints.
- Complex Variants now require JSON mode or manual serialization.
- Performance/behavior differences:
  - keys(pattern) no longer inspects in-memory store; uses SCAN and may be eventually consistent.
  - TTL is server-driven, not per-frame purging.
  - Pub/Sub delivers messages via signals emitted on the main thread; users should connect to pubsub_message/pubsub_pmessage.

## Milestones
1) Skeleton & Build
   - Set up addon structure, SCons, GDExtension C registration, stub `Gedis` with connect/disconnect/is_connected.
   - config.gdextension and plugin.cfg; autoload singleton registration.

2) Core Commands (Strings + Expiry)
   - set_value, get_value, del, exists, incr, decr, expire, ttl, persist, flushall (guarded).
   - Basic error handling, timeouts.

3) Collections
   - Hashes: hset, hget, hgetall, hdel
   - Lists: lpush, rpush, lpop, rpop, llen
   - Sets: sadd, srem, smembers, sismember

4) keys(pattern) via SCAN
   - Configurable scan batch, max iterations.

5) Pub/Sub
   - Pub/Sub thread, queue, signals, subscribe/psubscribe and unsubscribe APIs, publish()
   - Reconnect & resubscribe logic; queue overflow policies

6) Type options
   - Optional JSON encode/decode toggles.
   - PackedByteArray support (optional if trivial).

7) Polish & Docs
   - README updates, examples, API docs, limitations and configuration notes.
   - Error codes/messages; signals; allow_flushall guard.

8) Optional Enhancements
   - Async worker thread + queued commands and completion signals for general commands.
   - TLS support via hiredis-tls.
   - Pipelining helper methods (MULTI/EXEC or basic pipeline).
   - AUTH with username for Redis ACL.

## Example Usage (target)
GDScript stays familiar:

```
# Autoloaded singleton `Gedis`
Gedis.host = "localhost"
Gedis.port = 6379
Gedis.connect()

# Key-value
Gedis.set_value("score", 10)
var current = Gedis.get_value("score")
Gedis.incr("score")
Gedis.expire("score", 5)

# Pub/Sub
Gedis.pubsub_enabled = true
Gedis.subscribe(["game:lobby", "game:events*"]) # mixed channel and pattern? Prefer separate calls:
Gedis.subscribe(["game:lobby"]) 
Gedis.psubscribe(["game:events:*"])

# Connect signals (in a Node)
func _ready():
    Gedis.connect("pubsub_message", Callable(self, "_on_msg"))
    Gedis.connect("pubsub_pmessage", Callable(self, "_on_pmsg"))

func _on_msg(channel, payload):
    print("[", channel, "] ", payload)

func _on_pmsg(pattern, channel, payload):
    print("[", pattern, "] ", channel, ": ", payload)

# Publish
Gedis.publish("game:lobby", {"type":"join", "user":"alice"})
```

## Risks & Mitigations
- Pure C GDExtension is lower-level and more verbose than C++; mitigate with robust utility wrappers and disciplined error checking.
- Blocking behavior in MVP: document and provide async in a later milestone.
- Cross-platform build issues (TLS, sockets): start with sync hiredis without TLS; add TLS later.
- Pub/Sub thread safety and message loss under high load: provide queue sizing and policies, emit signals on main thread only, and document best practices.

## Deliverables
- Native library + addon under addons/Gedis_native
- Updated README with installation and usage
- gdextension-plan.md (this file)

## Progress Report — GDExtension (C) for Gedis

Date: 2025-08-30

This document records the current status of the Gedis GDExtension (C) work and provides concrete next steps to continue development.

### Completed

- Addon scaffold created under [addons/Gedis/](addons/Gedis/), including:
  - Build script: [addons/Gedis/SConstruct](addons/Gedis/SConstruct)
  - Sources: [addons/Gedis/src/init.c](addons/Gedis/src/init.c), [addons/Gedis/src/init.h](addons/Gedis/src/init.h)
  - Dumped engine API header: [addons/Gedis/src/gdextension_interface.h](addons/Gedis/src/gdextension_interface.h)
  - Descriptor: [addons/Gedis/Gedis.gdextension](addons/Gedis/Gedis.gdextension)

- Build on Linux (SCons):
  - Command: `cd "addons/Gedis" &amp;&amp; scons -Q`
  - Output: [addons/Gedis/bin/libgedis.so](addons/Gedis/bin/libgedis.so)
  - Symbol check confirmed export of `gedis_library_init`.

- Descriptor platform mappings updated:
  - Includes linux, linux.x86_64, linuxbsd, linuxbsd.x86_64 (debug/release and generic keys), all pointing to the current `.so`.

- Runtime verification (headless editor):
  - Command: `cd "." &amp;&amp; godot --editor --headless -v --quit`
  - Verified logs showed initialization and deinitialization messages emitted by the extension.
  - Confirms the extension loads and the initialization callback is invoked.

### How to Build

- From project root:
  - `cd "addons/Gedis" &amp;&amp; scons -Q`

Artifacts:
- Shared object: [addons/Gedis/bin/libgedis.so](addons/Gedis/bin/libgedis.so)

### How to Verify Load in Godot (Headless)

- From project root:
  - `godot --editor --headless -v --quit`

Expected output should include lines indicating that the extension initialized and deinitialized successfully.

### Next Steps (Milestones)

1) Implement a minimal native class to validate bindings
- Goal: Expose a simple class (e.g., GedisCore) with a trivial method (e.g., echo or add) callable from GDScript.
- Files to add:
  - [addons/Gedis/src/gedis_core.h](addons/Gedis/src/gedis_core.h)
  - [addons/Gedis/src/gedis_core.c](addons/Gedis/src/gedis_core.c)
- Registration:
  - Extend initialization to register the class and bind at least one method.
- Notes:
  - Continue to use the raw C GDExtension API; follow the official C example for function pointer setup and class registration.
  - SConstruct already uses `Glob('src/*.c')`, so new C files will be built automatically.

2) Add editor/runtime smoke tests in GDScript
- Create a small script under test/unit/ that instantiates the native class and calls the method.
- Example locations exist in [test/unit/](test/unit/).

3) Improve logging and diagnostics
- Add optional debug logging macros for consistent output from the native library.
- Consider printing the resolved engine version and API hash during CORE initialization for diagnostics.

4) Cross-platform preparation
- Extend [addons/Gedis/Gedis.gdextension](addons/Gedis/Gedis.gdextension) with Windows/macOS mappings when targeting those platforms.
- For Windows (MSVC/MinGW) and macOS (Clang), validate symbol export and PIC flags as needed; adjust [addons/Gedis/SConstruct](addons/Gedis/SConstruct) accordingly (e.g., `-fPIC` already set for Linux).

5) Release configuration
- Add separate release builds if desired (e.g., compiler flags for optimization, LTO).
- Ensure the descriptor’s `linux.*.release` entries are wired to the same binary or to optimized builds as needed.

6) CI automation (optional)
- Build matrix:
  - Linux GCC (debug/release)
- Checks:
  - `nm -D` (or `objdump -T`) contains `gedis_library_init`
  - Headless load check using `godot --headless -v --quit`
- Artifacts: Publish `libgedis.so` on each successful build.

### Troubleshooting Reference

- “GDExtension dynamic library not found: 'res://addons/Gedis/Gedis.gdextension'”
  - Ensure platform/arch keys in the descriptor match the current OS and architecture (for Linux Godot 4.5 betas, include both `linux*` and `linuxbsd*` keys).

- “expected '=', ',', ';', 'asm' or '__attribute__' before 'gedis_library_init'”
  - Define a fallback `GDE_EXPORT` in the local header and include it in sources before declaring exported symbols.

- Library builds but does not initialize at runtime
  - Confirm the exported symbol exists (`nm -D bin/libgedis.so | grep gedis_library_init`) and that the descriptor’s `entry_symbol` matches exactly.
  - Ensure the `.so` path used by the descriptor is correct and accessible.

### Notes

- The descriptor currently sets `compatibility_minimum = "4.4"` and has been verified to load on Godot 4.5 beta on Linux with the added platform keys.
- The legacy GDScript-only addon at [addons/gedis/](addons/gedis/) remains unmodified.
