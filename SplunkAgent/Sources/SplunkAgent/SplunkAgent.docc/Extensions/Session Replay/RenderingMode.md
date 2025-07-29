# ``SplunkAgent/RenderingMode``

## Overview

The `RenderingMode` enum defines how the visual content of a user session is captured and rendered during session replay.

## Topics

### Cases

- ``native``
  The session is captured and rendered using native UI elements, providing the most accurate representation.
- ``wireframeOnly``
  Only a wireframe representation of the UI is captured and rendered, omitting detailed visual content.
- ``default``
  The default rendering mode, typically equivalent to `native` unless otherwise configured.

