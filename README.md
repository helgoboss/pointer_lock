# pointer_lock

A Flutter plug-in that makes it possible to lock the mouse pointer to its current position
and receive movement deltas while the pointer is locked.

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

On Linux, we currently only support X11/X.Org. On Wayland, the pointer locking will not really work!
I hope to add Wayland support soon. Until then, you can ask users of Linux distributions that 
default to Wayland, to log in using X11/X.Org instead.


## Development

### Linux

The Wayland files `linux/include/pointer-constraints-unstable-v1-client-protocol.h` and 
`linux/pointer-constraints-unstable-v1-client-protocol.h` have been generated like this:

```sh
wayland-scanner client-header /usr/share/wayland-protocols/unstable/pointer-constraints/pointer-constraints-unstable-v1.xml linux/include/pointer-constraints-unstable-v1-client-protocol.h
wayland-scanner private-code /usr/share/wayland-protocols/unstable/pointer-constraints/pointer-constraints-unstable-v1.xml linux/pointer-constraints-unstable-v1-client-protocol.c
```