# ``SplunkAgent/User``

## Overview

The `User` object provides access to user-related information and preferences for tracking within the Splunk RUM agent.

## Topics

### Identification

- ``identifier``
  A unique identifier for the current user.

### Tracking Preferences

- ``preferences``
  User-specific tracking preferences, including the tracking mode. (Assumes `preferences` is a public property of `User` that contains `trackingMode`).

