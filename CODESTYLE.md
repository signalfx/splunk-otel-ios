# Introduction

The following document defines the development standards for the iOS platform. These rules are mandatory. Each team member knows them, understands, and follows them. Other rules that are not listed here should be enforced with the tools described [[here|Coding-style-tools]].  


# Purpose

Unify the code style of individual team members as much as possible so that the resulting code is readable, understandable, and clear to anyone on the team. 


# Code organization 

## Directory structure

Create groups of files that relate to each other. Keep the same organizational principles for all projects.

TODO: Define rules for code organization!


## File naming 

Use file names that are appropriate for their content or purpose. It is allowed to have more classes, structures, or types in one file if they are closely related. However, prefer multiple smaller files to one large file.

The following rules apply to file names:
- File names respect `PascalCasing`.
- We do not use abbreviations in filenames unless they are a general abbreviation (such as API or URL).
- We never abbreviate names like `ViewController` to `VC` and so on.
- To name the file with the extension content, we use a format such as: `UIView+RoundedColors`. Where the plus part corresponds to the meaning of the extension. 
- We never use common and meaningless names like `UIColor+Utils` or` UIView+Helpers`. 


## File layout

We use marks in each file. This rule also applies in cases where the file has only one method/function or variable block. We use marks with the dash for creating logical sections, and if you want to create subgroups, we use marks without the dash. Source code from one logical section (defined with `MARK:`) may not be included in another `MARK:` section.

**DO:**
```swift
import Foundation

struct SelectionItem {

    // MARK: - Public

    let label: String
    let value: Any
    var selected: Bool = false
}

struct SelectionData {

    // MARK: - Public

    let id: String?
    var items = [SelectionItem]()


    // MARK: - Selection helpers

    func selected() -> [SelectionItem] {
        return items.filter {
            $0.selected == true
        }
    }

    func selectedValues() -> [Any] {
        selected().map {
            $0.value
        }
    }
}

```


**DON'T:**
```swift
import Foundation

struct SelectionItm {
    let label: String
    let value: Any
    var selected: Bool = false
}

struct SelectionData {
    let id: String?
    var items = [SelectionItem]()
    func selected() -> [SelectionItm] {
        return items.filter {
            $0.selected == true
        }
    }
    func selectedValues() -> [Any] {
        selected().map {
            $0.value
        }
    }
}
```


If you are implementing methods from a delegate or protocol then always use a separate block with an extension.

**DO:**
```swift
class MainViewController: UIViewController {
	
    // MARK: - Outlets

    @IBOutlet private weak var detailView: UINavigationController!
    

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        detailView.presentationController?.delegate = self
    }
}

extension MainViewController: UIAdaptivePresentationControllerDelegate {

    // MARK: - UIAdaptivePresentationControllerDelegate methods

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        AppSettingsManager().save()
    }
}
```

**DON'T:**
```swift
class MainViewController: UIViewController, UIAdaptivePresentationControllerDelegate {
	
    // MARK: - Outlets

    @IBOutlet private weak var detailView: UINavigationController!
    

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        detailView.presentationController?.delegate = self
    }


    // MARK: - UIAdaptivePresentationControllerDelegate methods

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        AppSettingsManager().save()
    }
}
```

## File content order

All logical sections defined with `MARK:` should have the same order. The expected and predictable layout of the file greatly simplifies orientation in the file and its contents.

In general terms, we can define the following arrangement. The sections are arranged as they would be arranged consecutively in a single file if it contained all the options:

```swift
// MARK: - Inline types
- all internally defined types

// MARK: - Static constants
- constants defined on class or type

// MARK: - Constants
- instance constants

// MARK: - Private
- private or internal variables

// MARK: - Public
- all public variables

// MARK: - Initialization
- all inits or convenience inits

// MARK: - <Name that describing logical section>
- public methods or main logic
- it can be presented multiple times

// MARK: - <Name that describing logical section>
- private methods 
- it can be presented multiple times

Extensions with the same internal order.
```

If we implement a known protocol, we should name these sections as: 

```swift
// MARK: - <ProtocolName> variables

// MARK: - <ProtocolName> methods
```

# Code style

## Variable naming

Use clear and descriptive names. **Never** rely on "someone to understand." However, Swift is not Objective-C, so there is no need to describe everything in the variable name. 

**DO:**
```swift
var cellEstimateHight = 152
var shouldReloadData = false
var itemsPerPage = 10
var currentPage = 0
var hasData = true
```

**DON'T:**
```swift
var a = 152
var b = false
var c = 10
var p = 0
var hasDownloadedDataAndReadyToDisplayItToView = true
```

Always name the input variables with a clear and self-describing name.

**DO:**
```swift
func calculateHypotenuse(sideA: Double, sideB: Double) -> Double {
    return sqrt(sideA * sideA + sideB * sideB)
}
```

**DON'T:**
```swift
func calculate(a: Int, b: Int) -> Int {
    return sqrt(a*a + b*b)
}
```

### Follow case conventions

Names of types and protocols are `UpperCamelCase`. Everything else is `lowerCamelCase`.

Acronyms and initialisms that commonly appear as all upper case in American English should be uniformly up-cased or down-cased according to case conventions:

```swift
var utf8Bytes: [UTF8.CodeUnit]
var isRepresentableAsASCII = true
var userSMTPServer: SecureSMTPServer
```

Other acronyms should be treated as ordinary words:

```swift
var radarDetector: RadarScanner
var enjoysScubaDiving = true
```


## Method naming


### Avoid ambiguity

**Include all the words needed to avoid ambiguity** for a person reading code where the name is used.

**DO:**
```swift
extension List {
	public mutating func remove(at position: Index) -> Element
}

employees.remove(at: x)
```

**DON'T:**
```swift
extension List {
	public mutating func remove(_ position: Index) -> Element
}

employees.remove(x)  // unclear: are we removing x?
```


### Omit needless words.

Every word in a name should convey salient information at the use site.

**DO:**
```swift
public mutating func remove(_ member: Element) -> Element?

allViews.remove(cancelButton) // clearer
```

**DON'T:**
```swift
public mutating func removeElement(_ member: Element) -> Element?

allViews.removeElement(cancelButton)
```


### Type constraints

**Name variables, parameters, and associated types according to their roles,** rather than their type constraints.

**DO:**
```swift
var greeting = "Hello"

protocol ViewController {
    associatedtype ContentView : View
}

class ProductionLine {
    func restock(from supplier: WidgetFactory)
}
```

**DON'T:**
```swift
var string = "Hello"

protocol ViewController {
  associatedtype ViewType : View
}

class ProductionLine {
  func restock(from widgetFactory: WidgetFactory)
}
```


### Weak type informations

Compensate for weak type information to clarify a parameter’s role.

Especially when a parameter type is NSObject, Any, AnyObject, or a fundamental type such Int or String, type information and context at the point of use may not fully convey intent. In this example, the declaration may be clear, but the use site is vague.

To restore clarity, precede each weakly typed parameter with a noun describing its role:

**DO:**
```swift
func addObserver(_ observer: NSObject, forKeyPath path: String)

grid.addObserver(self, forKeyPath: graphics) // clear
```

**DON'T:**
```swift
func add(_ observer: NSObject, for keyPath: String)

grid.add(self, for: graphics) // vague
```


Prefer method and function names that make sentences form grammatical English phrases.

**Begin names of factory methods with** “make”, e.g. `x.makeIterator()`

**DO:**
```swift
x.insert(y, at: z)          “x, insert y at z”
x.subViews(havingColor: y)  “x's subviews having color y”
x.capitalizingNouns()       “x, capitalizing nouns”
```

**DON'T:**
```swift
x.insert(y, position: z)
x.subViews(color: y)
x.nounCapitalize()
```


## Statements format

### `guard` statement

Even for a guard with one check, always use the form that places `return` on a separate line. After each guard section is always empty line.

If possible, prefer use `guard` to `if` statement.

**DO:**
```swift
guard let inputData = inputData else {
    return nil
}

guard outputStream.isReady else {
    return .notReady
}
```

**DON'T:**
```swift
guard let inputData = inputData else { return nil }
if outputStream.isReady {
    return .notReady
}
```

Use a formating that places each check on a separate line under the guard keyword for a guard with multiple checks.

**DO:**
```swift
guard
    !user.session.isTooLongForAnotherRecord,
    !user.session.isTooLongStopped
else {
    user.session.openNew()
    return
}
```

**DON'T:**
```swift
guard !user.session.isTooLongForAnotherRecord, !user.session.isTooLongStopped else {
    user.session.openNew()
    return
}
```

If the individual checks are only two and very short, they can be placed side by side on one line.

**DO:**
```swift
guard downloaded, unpacked else {
    return
}
```
