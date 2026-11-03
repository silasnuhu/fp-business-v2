# iOS Plugin Patches

Local patches applied to the shared pub-cache copies of plugins. They are
re-applied automatically from the `Podfile` `pre_install` hook, so a
`flutter pub get` / `flutter pub cache repair` can't silently ship an unpatched
plugin.

## flutter_webrtc — EXC_BAD_ACCESS in `postEvent`

**Symptom**

```
EXC_BAD_ACCESS (SIGSEGV)  KERN_INVALID_ADDRESS at 0x0000000000000010
Thread 0 Crashed (com.apple.main-thread)
0  Runner.debug.dylib  __postEvent_block_invoke + 40
1  libdispatch.dylib   _dispatch_call_block_and_release
...                    _dispatch_main_queue_drain
```

Seen during logout, call teardown, backgrounding while a call is live, and app
termination.

**Root cause**

`FlutterWebRTCPlugin.m`:

```objc
void postEvent(FlutterEventSink _Nonnull sink, id _Nullable event) {
    dispatch_async(dispatch_get_main_queue(), ^{ sink(event); });
}
```

WebRTC delegate callbacks (ICE / peer-connection / data-channel state) fire on
background threads (`signaling_thread`, `network_thread`) and are hopped to the
main thread by `postEvent`. If the `FlutterEngine` / binary messenger is torn
down between scheduling and draining, the captured `FlutterEventSink` block's
messenger is freed, and invoking it dereferences freed memory (offset `0x10`)
on the main thread.

`@try/@catch` cannot catch this — it is a SIGSEGV, not an ObjC exception — and a
non-nil check on the block pointer doesn't detect a freed underlying sink.

**Fix** (`apply_flutter_webrtc_patch.sh`)

1. A file-static `_whoxaFlutterWebRTCPluginAttached` flag, set `YES` when the
   plugin is created and `NO` in `detachFromEngineForRegistrar:` and `dealloc`.
2. `postEvent` bails on a nil sink, captures the sink strongly, and on the main
   thread re-checks `whoxaFlutterWebRTCPluginIsAttached()` before invoking it —
   so a callback that lands after engine teardown becomes a no-op instead of a
   crash.
3. Header forward declaration relaxed to `_Nullable sink` to match.

The Dart side complements this by tearing down peer connections deterministically
before renderers/engine go away — see
`packages/peerdart/lib/src/negotiator.dart` (`cleanup()` closes and `dispose()`s
the RTCPeerConnection), `lib/featuers/call/peerjs_call_controller.dart`
(`dispose()` closes every MediaConnection and the Peer) and
`lib/featuers/call/call_manager.dart` (forces cleanup on
`AppLifecycleState.detached` / `paused` while in a call).

### Files

| File | Purpose |
| --- | --- |
| `apply_flutter_webrtc_patch.sh` | Idempotent patcher. Patches only the `flutter_webrtc` version resolved in `pubspec.lock`. Saves `*.orig` backups. |
| `flutter_webrtc/FlutterWebRTCPlugin.m.patch` | Human-readable reference of the hunks. Not machine-applied. |

Pinned version: **`flutter_webrtc 0.12.12+hotfix.1`**. The patch anchors are
version-specific; if the version bumps, the script prints a warning and (if the
anchors no longer match) fails loudly. Refresh the anchor strings in
`apply_flutter_webrtc_patch.sh` against the new source and update this file.

### Manual use

```bash
bash ios/patches/apply_flutter_webrtc_patch.sh   # idempotent; safe to re-run
```

Runs automatically on `pod install` (i.e. every `flutter run` / `flutter build`
that re-integrates pods).

### Revert

```bash
V=0.12.12+hotfix.1
for d in common/darwin ios macos; do
  f=~/.pub-cache/hosted/pub.dev/flutter_webrtc-$V/$d/Classes/FlutterWebRTCPlugin
  [ -f "$f.m.orig" ] && mv "$f.m.orig" "$f.m"
  [ -f "$f.h.orig" ] && mv "$f.h.orig" "$f.h"
done
```

## permission_handler_apple — iOS 18 contacts

`apply_patches.sh` copies `permission_handler_apple/ContactPermissionStrategy.m`
over the pinned plugin's copy for iOS 18 contact-permission support.

---

- Patches live in the shared pub-cache, so they persist until the cache entry is
  re-extracted — which the `pre_install` hook then repairs.
- `apply_patches.sh` runs both patches; `pre_install` runs only the WebRTC one.
