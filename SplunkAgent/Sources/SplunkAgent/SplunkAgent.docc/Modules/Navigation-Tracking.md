# Navigation Tracking

The Navigation module reports screen transitions and attaches the current screen name to all generated spans.

| | |
|---|---|
| **Module** | `SplunkNavigation` |
| **Enabled by Default?** | No |
| **Public API?** | Yes |

This module can be configured to automatically track `UIViewController` transitions or be used to set screen names manually. The active screen name (or "unknown" if not set) is added as a `screen.name` attribute to all telemetry.

> Tip: You can access all related API via SplunkRum instance property: ``SplunkRum/navigation``

## Install-Time Configuration

You can configure the navigation module during agent installation by providing a ``SplunkNavigation/NavigationConfiguration`` object. Use it to enable automated tracking and optionally set a custom event processor.

```swift
import SplunkAgent
import SplunkNavigation // Required for the configuration type

let navConfig = NavigationConfiguration(
    isEnabled: true,
    enableAutomatedTracking: true,
    navigationEventProcessor: MyProcessor()
)

let agent = try SplunkRum.install(
    with: agentConfig,
    moduleConfigurations: [navConfig]
)
```

## Custom Event Processor

Implement ``SplunkNavigation/NavigationEventProcessor`` to customize how detected `UIViewController` transitions are named, enriched, or filtered. The processor is called once per automated navigation event; manual ``NavigationModule/track(screen:)`` calls bypass it.

- **Rename screens:** Return a ``SplunkNavigation/NavigationEvent`` with a custom name.
- **Add span attributes:** Include key-value pairs in the event's `attributes`. These are added to the `app.ui.navigation` span.
- **Suppress events:** Return `nil` to prevent the navigation event.

See ``SplunkNavigation/NavigationEventProcessor`` for code examples.

## Usage

Assuming `agent` is the ``SplunkRum`` instance you retained after installation.

### Automated Tracking

To enable automatic screen name tracking after installation:

```swift
agent?.navigation.preferences.enableAutomatedTracking = true
```

### Manual Tracking

You can manually set the screen name at any time. This is useful for SwiftUI apps or complex navigation flows.

```swift
agent?.navigation.track(screen: "ProductDetailView")
```

You can also attach custom attributes to the `app.ui.navigation` span:

```swift
agent?.navigation.track(
    screen: "ProductDetailView",
    attributes: ["product.id": "abc-123"]
)
```

### SwiftUI

In SwiftUI, use the `.trackScreen` view modifier instead of calling `track(screen:)` directly. The modifier reports the screen name each time the view appears.

```swift
struct ProductDetailView: View {
    var body: some View {
        VStack { ... }
            .trackScreen("ProductDetail")
    }
}
```

You can also pass attributes:

```swift
.trackScreen("ProductDetail", attributes: ["product.id": productId])
```