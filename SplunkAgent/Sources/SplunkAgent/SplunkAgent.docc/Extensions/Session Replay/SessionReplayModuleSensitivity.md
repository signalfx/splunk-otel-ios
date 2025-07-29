# ``SplunkAgent/SessionReplayModuleSensitivity``

## Overview

The `SessionReplayModuleSensitivity` protocol defines the public API for managing the data sensitivity of UI view elements during session recording. Sensitive elements are hidden locally on the device and are not transferred or stored.

## Topics

### View Sensitivity

- ``subscript(view:)-6m50c``
  Retrieves or sets an element's sensitivity for a specific `UIView` instance.
- ``set(_:_:)-9243u``
  Sets element sensitivity for the specified `UIView` instance.

### Class Sensitivity

- ``subscript(viewClass:)-90i0a``
  Retrieves or sets sensitivity for all instances of a specific `UIView` class.
- ``set(_:_:)-1z1h5``
  Sets sensitivity for the specified `UIView` class.

