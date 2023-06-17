# NSView+Intercept

`NSView+Intercept` is like the big brother to [NSViewProxy](https://github.com/stephancasas/NSViewProxy), but instead of accessing `NSView` instances á la carte, you access them on a wholesale basis — enabling persistent behavior and style throughout your entire application. 

It works by exchanging the method implementations for `NSView.addSubview(:)` and `NSView.viewWillDraw()` with custom callback-invoking methods — allowing you to "hook" or intercept the lifecycle of `NSView` instances from anywhere in your macOS SwiftUI app.

## Install

Exchange of the described methods is performed by importing `NSView_Intercept` and calling `NSView.useIntercept()`. This should take place as early as possible in your application's lifecycle and can easily be added to its initializer:

```swift

import SwiftUI;
import NSView_Intercept;

@main
struct ExampleApp: App {
    
    init() {
        NSView.useIntercept();
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

## Usage

After calling `NSView.useIntercept()`, you can install and remove *interceptor callbacks* at any point in your application's lifecycle:

### Using ViewSpecifiers

`NSView+Intercept` includes a collection of `ViewSpecifiers` which help retrieve common segments the macOS SwiftUI user interface:

| Specifier | Description |
| :--- | : --- |
| `.allViews` | All `NSView` instances. |
| `.views(like:)` | Views whose debug descriptions match the given regular expression. |
| `.views(named:)` | Views whose string-equivalent class names match the given string. |
| `.tabBars` | All `NSTabBar` instances. |
| `.titlebars` | All `NSTitleBarView` instances. |
| `.titlebarContainers` | All `NSTitlebarContainerView` instances. |

#### Interception

Provide a `ViewSpecifier` and callback to `NSView.intercept(:using:)`. Every `NSView` instance whose conditions match that of the given specifier will be piped-through your given callback prior to first draw.

```swift
/// Hide the "toggle sidebar" button, **always**.
///
NSView.intercept(.views(like: /toggleSidebar/), using: { view in
   view.require(\.isHidden, is: true);
});
```

#### Avoidance

Provide a `ViewSpecifier` to `NSView.avoid(:)` to remove any callback logic added by `NSView.intercept(:using:)`.

> **Note** 📝
>
> This does not reverse any logic you may have applied using `NSView.require(:is:)`, `NSView.require(:using:)`, or `NSView.require(:using:now:)`. More details on that later...

```swift
NSView.avoid(.views(like: /toggleSidebar/));
```

#### Rejection

Provide a `ViewSpecifier` to `NSView.rejectDraw(for:)` to prevent the wholesale drawing of every `NSView` instance whose conditions match taht of the given specifier.

```swift
/// Refuse to draw the "New Tab" button.
///
NSView.rejectDraw(for: .views(named: "NSTabBarNewTabButton"));
```

#### Permission

Provide a `ViewSpecifier` to `NSView.permitDraw(for:)` to remove any draw restrictions added by `NSView.rejectDraw(for:)`.

```swift
NSView.permitDraw(for: .view(named: "NSTabBarNewTabButton"));
```

#### Advanced/Named Interception

Sometimes, you may wish to conditionally intercept views at various points throughout your application's lifecycle. Where necessary, you can use `NSView.install(interceptor:withName:)` to attach an interceptor callback which you can later remove using `NSView.uninstall(interceptor:)` — where `interceptor` is the name which was used during install.

When using this method to setup interception, *all* `NSView` instancess will be piped through your interceptor callback. You will need to provide your own filtering logic to ensure that any changes applied are applied only to the views you intend. Along with `NSView.intercept(.allViews, using: { view _ in })`, this function can be extremely useful for debugging your application's view hierarchy and understanding the order in which UI elements draw.

``` swift
/// It's recommended that you name your interceptor
/// callbacks using public constants. In this way,
/// you'll be able to install and cancel them with
/// less potential for ambiguity.
///
let kNSViewInterceptSidebarButton = "com.stephancasas.sidebar-button-intercept";

NSView.install(interceptor: { view in
    
    if view.debugDescription.contains(/\.toggleSidebar/) {
        view.isHidden = true;
    }
    
    /// There's a better way to do this... keep reading!
    /// 
    if view.debugDescription.contains(/NSToolbarTitleView/) {
        DispatchQueue.main.async(execute: {
            guard let toggleSidebar = view.superview?.subviews.first else {
                return;
            }
           view.setFrameOrigin(toggleSidebar.frame.origin); 
        });
    }
    
}, withName: kNSViewInterceptSidebarButton);

// ...

NSView.uninstall(interceptor: kNSViewInterceptSidebarButton);
```

#### Lifecycle Hooks

The example given above is intended to hide the *Toggle Sidebar* button, which is automatically drawn in the titlebar of a SwiftUI app whose outermost view is a `NavigationSplitView` (or any variant on that). The callback first hides the button, and then schedules the window's title to move to the toggle button's origin (so that there isn't an obviously empty space).

Using `DispatchQueue.main.async(execute:)` ensures that we don't accidentally access a view which has yet to draw, and is a common pattern I've run across in several answers online, but it has the unfortunate effect of flashing a single frame of unstyled content to your user. In this case, the title would appear briefly indented after which it would slide left.

`NSView+Intercept` provides a lifecycle hook you can leverage to avoid this issue entirely. By overriding `NSView.viewWillDraw()`, `NSView+Intercept` enables your ability to manipulate content the instant before it hits your users' eyes.

On any instance of `NSView`, call `onBeforeDraw(perform:)` or `onBeforeDraw(perform:once:)` to attach a callback which will invoke just prior to draw — receiving the `NSView` instance as the sole arg.

With this in-mind, we can improve our above intercept:

```swift
/// I'm using a `ViewSpecifier` here instead of the named
/// intercept, but the concept is the same.
///
NSView.intercept(.views(named: "NSToolbarTitleView"), using: { view in
    view.onBeforeDraw(perform: { view in
        guard let toggleSidebar = view.superview?.subviews.first else {
            return
        }
        view.setFrameOrigin(toggleSidebar.frame.origin)
    });
});
```

Now, intead of applying the change after the first draw has already occurred, we're applying it *just before* it occurs, and we won't have to worry about accessing a `nil` view.

#### Property Enforcement 

There's still *one more* problem in the example I've given above, but it isn't at all obvious. In many ways, SwiftUI can be a bit of a black box into which we have limited insights with respect to what happens when. This becomes a pervasive issue when we start customizing views in the ways we've reviewed thus far.

If you were to use the above example in your own app, things would work perfectly fine right up until the moment that your user shows the tab bar or performs some other titlebar-manipulating operation. The titlebar would snap back into its original position and would not return to the setting we coerced in the interceptor callback. It's difficult to say *why* this happens because there are many things which could be the cause (e.g. `NSLayoutConstraint`, redraw, etc.). The good news is that we don't necessarily need to know why it's happening — we just need a solution. In these respects, `NSView+Intercept` offers the instance methods `.require(:is:)`, `.require(:using:)`, and `.require(:using:now:)`.   

Using `KeyPath` notation, you can specify a property whose value you want to keep persistent on any `NSView` instance. This can be implemented using either a static value, or a callback. Once again, let's use this knowledge to improve our example from earlier: 

```swift
NSView.intercept(.views(like: /toggleSidebar/), using: { view in

    /// Simple properties with static values can
    /// can be set like this.
    ///
    view.require(\.isHidden, is: true);
    
});

NSView.intercept(.views(named: "NSToolbarTitleView"), using: { view in
    view.onBeforeDraw(perform: { view in
        guard let toggleSidebar = view.superview?.subviews.first else {
            return
        }
        
        /// Readonly properties like `NSView.frame`, which use specialized
        /// setters, can be handled by using a callback instead of a static
        /// value.
        /// 
        /// Using the `now: true`, will apply the logic immediately.  
        ///
        view.require(\.frame, using: { view in
            view.setFrameOrigin(toggleSidebar.frame.origin)
        }, now: true);
    });
});
``` 

Property enforcement is provided by leveraging the `Combine` framework to notify and execute logic when SwiftUI attempts to modify a property you don't want changed. If, at a later time, you no longer need to enforce the property value, you can release it by calling `.release(:)` on any `NSView` instance:

```swift
titleView.release(\.frame);
toggleSidebar.release(\.isHidden);
``` 


## Contributing

If you experience an issue, please raise one or feel free to open a PR. I can usually be reached via DM [on Twitter as @stephancasas](https://twitter.com/stephancasas), so please feel free to follow or get in touch if you'd like to see more of my work. 

## License

MIT
