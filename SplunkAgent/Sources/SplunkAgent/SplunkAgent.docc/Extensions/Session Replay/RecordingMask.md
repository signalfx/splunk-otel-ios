# ``SplunkAgent/RecordingMask``

## Overview

A `RecordingMask` defines a set of rectangular areas on the screen that should be masked (obscured) during session replay recording. This is used to protect sensitive information or UI elements from being captured.

## Topics

### Mask Elements

- ``elements``
  An array of ``SplunkAgent/MaskElement`` instances, each defining a rectangular area and its masking type.

### Mask Element (Nested Struct)

- ``MaskElement``
  A structure representing a single rectangular area to be masked.
  - ``rect``
    The `CGRect` defining the bounds of the masked area.
  - ``type``
    The ``SplunkAgent/MaskElement/MaskType`` specifying how the area should be masked (e.g., covering, erasing).

### Mask Type (Nested Enum)

- ``MaskType``
  An enum defining the type of masking to apply to a `MaskElement`.
  - ``erasing``
    The masked area will be completely erased (filled with a solid color) in the recording.
  - ``covering``
    The masked area will be covered with a semi-transparent overlay in the recording.

