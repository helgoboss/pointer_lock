# pointer_lock

A Flutter plug-in that makes it possible to lock the mouse pointer to its current position.
This is useful for widgets such as knobs, drag fields and zoom controls.

| Linux | macOS | Windows |
| :---: | :---: | :-----: |
|   ✖️   |   ✔️   |    ✔️    |

**Contributions to make it work on Linux are very welcome! I didn't have time to look into it yet.**

## Getting Started

**This plug-in is in an experimental state. API and behavior can change anytime. That's also
why it's not yet on pub.dev!**

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  window_manager:
    git:
      url: https://github.com/helgoboss/pointer_lock.git
      ref: main
```

### Usage

Since this is still in a state of flux, there's no good documentation yet. For the time being, 
read the `PointerLock` method docs and have a look into the [example app](example/lib/main.dart).