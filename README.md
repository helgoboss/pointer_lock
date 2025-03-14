# pointer_lock

A Flutter plug-in that makes it possible to lock the mouse pointer to its current position
and receive movement deltas while the pointer is locked.

| Windows | macOS | Linux (x11) | Linux (Wayland) |        Web        |
|:-------:|:-----:|:-----------:|-----------------|:-----------------:|
|   ✔️    |  ✔️   |     ✔️         | so so           | Experimental️ (*) |

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

## Use case 1: Lock pointer while dragging (via widget)

The idea is to lock the pointer when you press a mouse button and unlock it as soon as you release
it. This is useful for widgets such as knobs, drag fields and zoom controls.

This use case is so popular that we have a dedicated widget for it: `PointerLockDragArea`. 
See [drag_example.dart](example/lib/drag_example.dart) to learn more.

If the widget is too restrictive for you, use the stream approach below. The widget itself
is just a convenience. It also uses the stream under the hood.

## Use case 2: Lock and unlock pointer freely (via stream)

The idea is to lock the pointer on some arbitrary event, such as a key or button press,
and unlock it on another arbitrary event. This is useful for applications or games that
are mouse-controlled.

This is how it works:

1. Call `pointerLock.createSession()`.
2. When you are ready, listen to the resulting stream. This will lock the pointer.
3. Process pointer movement events emitted from the stream.
4. When you are done, cancel the stream. This will unlock the pointer

See [free_example.dart](example/lib/free_example.dart) to learn more.

## Platform-specific considerations

### Windows

On Windows, two modes are available: **capture** and **clip**. They differ in the implementation.

Mode **capture** is the recommended mode. It uses the `SetCapture` technique.

Mode **clip** uses the `ClipCursor` technique. This technique comes with the danger of 
stealing raw input focus from other parts of the application. This should be only used if you are
sure that the rest of your Windows application doesn't rely on raw input (`WM_INPUT` messages).

Use whatever works best for you!

### Linux

On Linux, things work okay in X11. The implementation is based on the GDK 
functions `gdk_pointer_grab` and `gdk_device_warp`.

On Wayland, I had varying experiences. On my Ubuntu VM running via UTM on macOS, it works. On my Zorin OS distro which runs on bare metal, the pointer easily escapes. This appeared to work better with the X11 functions `XGrabCursor` and `XWarpCursor` (which were replaced with GDK functions in commit 942a4c39). But with the X11 functions, I observed crashes in advanced usage scenarios ... maybe it's time to use the "pointer-constraints-unstable-v1" API on Wayland?

### Web (*)

Experimental web support has landed thanks to a contribution by @damywise.

Known issues:

- Successfully tested on Chrome only.
- On macOS, I observed a an issue in drag mode where releasing the mouse button without dragging
  would leave the pointer locked (#4).

**Further contributions to improve web support are very welcome!**

## Development

### Linux

#### Room for improvement

There's room for improvement for the Linux platform:

- For Wayland, we could use the Wayland-specific "pointer-constraints-unstable-v1" API in order
  to allow for a smoother pointer locking experience. A few experiments have been done already
  (see commit 9216f16aa188268e6 in which the experimental Wayland code was removed).
