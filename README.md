# pointer_lock

A Flutter plug-in that makes it possible to lock the mouse pointer to its current position.
This is useful for widgets such as knobs, drag fields and zoom controls.

| Windows | macOS | Linux (x11) | Linux (Wayland) | Web |
|:-------:|:-----:|:-----------:|-----------------|:---:|
|   ✔️    |  ✔️   |     ✔️      | ✖               | ✖️  |

**Contributions to make it work on Web are very welcome! I didn't have time to look into 
it yet.**

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  pointer_lock:
    git:
      url: https://github.com/helgoboss/pointer_lock.git
      ref: main
```

## Usage

Call `PointerLock.startPointerLockSession` on the click of a mouse button and
listen to a stream of mouse move deltas. See [this example](example/lib/pointer_lock_area.dart).

## Platform-specific considerations

### Windows

On Windows, two modes are available: **capture** and **clip**. They differ in the implementation.

Mode **capture** is the recommended mode. It uses the `SetCapture` technique.

Mode **clip** uses the `ClipCursor` technique. This technique comes with the danger of 
stealing raw input focus from other parts of the application. This should be only used if you are
sure that the rest of your Windows application doesn't rely on raw input (`WM_INPUT` messages).