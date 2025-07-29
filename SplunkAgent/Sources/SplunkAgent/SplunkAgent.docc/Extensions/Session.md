# ``SplunkAgent/Session``

## Overview

The `Session` object provides access to information about the current user session, including its unique identifier and state.

## Topics

### Session State

- ``state``
  An object that holds the current session's state, including its unique identifier.

### Deprecated APIs

These APIs are deprecated and will be removed in a future version. Please migrate to the new APIs as indicated.

- ``currentSessionId``
  Use ``state``.`id` instead.
- ``sessionId(for:)``
  This method will be removed.

