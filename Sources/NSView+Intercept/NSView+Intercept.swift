import Foundation;
import Combine;
import AppKit;

public typealias NSViewInterceptor<T: NSView> = (_ view: T) -> Void;

// MARK: - ViewSpecifier<Substring>

public extension NSView.ViewSpecifier where T == Regex<Substring> {
    
    /// Specify views whose debug descriptions match the given regular expression.
    /// - Parameter like: The regular expression against which to test.
    static func views(like: Regex<Substring>) -> NSView.ViewSpecifier<T> {
        .init(rawValue: like);
    }
    
}


// MARK: - ViewSpecifier<String>

public extension NSView.ViewSpecifier where T == String {
    
    /// Specify views whose string-equivalent class names match the given string.
    /// - Parameter name: The string against which to test `NSView` class names.
    static func views(named name: String) -> NSView.ViewSpecifier<T> {
        .init(rawValue: name);
    }
    
    /// Specify all `NSTabBar` views (undocumented).
    static var tabBars: NSView.ViewSpecifier<T> {
        .init(rawValue: "NSTabBar")
    }

    /// Specify all `NSTitlebarView` views. (undocumented).
    static var titlebars: NSView.ViewSpecifier<T> {
        .init(rawValue: "NSTitlebarView")
    }
    
    /// Specify all `NSTitlebarContainerView` views (undocumented).
    static var titlebarContainers: NSView.ViewSpecifier<T> {
        .init(rawValue: "NSTitlebarContainerView")
    }
    
}

public extension NSView.ViewSpecifier where T == NSView.Type {
    
    /// Speciy every `NSView`.
    static var allViews: NSView.ViewSpecifier<T> {
        .init(rawValue: NSView.self);
    }
    
}

public extension NSView {
    
    private static var __interceptors: [String: (NSView) -> Void] = [:];
    
    /// Install the overrides necessary to intercept `NSView` instances.
    ///
    /// This should be called your application's `App.init()`.
    ///
    static func useIntercept() {
        Self.__swizzle();
    }
    
    struct ViewSpecifier<T>: RawRepresentable {
        public var rawValue: T;
        
        public init(rawValue: T) {
            self.rawValue = rawValue
        }
    }
    
    // MARK: - Specified Interceptor Enrollment
    
    /// Use the provided callback to intercept insertion of `NSView`
    /// instances whose conditions match the given specifier
    /// - Parameters:
    ///   - views: The specifier against which to match.
    ///   - callback: The callback which will receive the `NSView` instances.
    static func intercept(
        _ views: ViewSpecifier<Regex<Substring>>,
        using callback: @escaping NSViewInterceptor<NSView>
    ) {
        Self.install(interceptor: { (view: NSView) in
            if view.debugDescription.contains(views.rawValue) {
                callback(view);
            }
        }, withName: "debug-regex--\(views.rawValue)");
    }
    
    /// Use the provided callback to intercept insertion of `NSView`
    /// instances whose conditions match the given specifier
    /// - Parameters:
    ///   - views: The specifier against which to match.
    ///   - callback: The callback which will receive the `NSView` instances.
    static func intercept(
        _ views: ViewSpecifier<String>,
        using callback: @escaping NSViewInterceptor<NSView>
    ) {
        Self.install(interceptor: { (view: NSView) in
            if view.className.contains(views.rawValue) {
                callback(view);
            }
        }, withName: "class-string--\(views.rawValue)");
    }
    
    /// Use the provided callback to intercept insertion of `NSView`
    /// instances whose conditions match the given specifier.
    /// - Parameters:
    ///   - views: The specifier against which to match.
    ///   - callback: The callback which will receive the `NSView` instances.
    static func intercept<T: NSView>(
        _ views: ViewSpecifier<T.Type>,
        using callback: @escaping NSViewInterceptor<T>
    ) {
        Self.install(
            interceptor: callback,
            withName: "class-enum--\(views.rawValue)");
    }
    
    /// Use the provided callback to intercept insertion of `NSView`
    /// instances of the given `NSView` subclass.
    /// - Parameters:
    ///   - views: The subclass of `NSView` to intercept.
    ///   - callback: The callback which will receive the `NSView` instances.
    static func intercept<T: NSView>(
        _ views: T.Type,
        using callback: @escaping NSViewInterceptor<T>
    ) {
        Self.install(
            interceptor: callback,
            withName: "class--\(views)")
    }
    
    // MARK: - Specified Interceptor Withdrawal
    
    /// End interception of `NSView` instances whose conditions match the
    /// given specifier.
    /// - Parameter views: The specifier against which to match.
    static func avoid(
        _ views: ViewSpecifier<Regex<Substring>>
    ) {
        Self.uninstall(interceptor: "debug-regex--\(views.rawValue)")
    }
    
    /// End interception of `NSView` instances whose conditions match the
    /// given specifier.
    /// - Parameter views: The specifier against which to match.
    static func avoid(
        _ views: ViewSpecifier<String>
    ) {
        Self.uninstall(interceptor: "class-string--\(views.rawValue)")
    }
    
    /// End interception of `NSView` instances which are of the given
    /// subclass of `NSView`.
    /// - Parameter views: The subclass of `NSView` against which to match.
    static func avoid<T: NSView>(
        _ views: T.Type
    ) {
        Self.uninstall(interceptor: "class--\(views)")
    }
    
    // MARK: - Named Interceptor Control
    
    /// Install a callback which will evaluate an incoming
    /// `NSView` before first draw.
    /// - Parameters:
    ///   - interceptor: The callback which should receive the `NSView`.
    ///   - name: A name/key for addressing the callback's removal.
    static func install<T>(
        interceptor: @escaping NSViewInterceptor<T>,
        withName name: String
    ) {
        NSView.__interceptors.updateValue({ view in
            guard let view = view as? T else { return }
            interceptor(view)
        }, forKey: name);
    }
    
    /// Uninstall a callback which is currently evaluating
    /// incoming `NSView` instances.
    /// - Parameter name: The name/key of the callback to remove.
    static func uninstall(
        interceptor name: String
    ) {
        NSView.__interceptors.removeValue(
            forKey: name);
    }
    
    // MARK: - Draw Rejection
    
    /// Reject drawing for `NSView` instances whose conditions match the
    /// given specifier.
    /// - Parameter views: The specifier against which to test.
    static func rejectDraw(for views: ViewSpecifier<Regex<Substring>>) {
        Self.install(interceptor: { (view: NSView) in
            if view.debugDescription.contains(views.rawValue){
                view.onBeforeDraw(perform: { view in
                    view.removeFromSuperview();
                });
            }
        }, withName: "reject-regex--\(views.rawValue)");
    }
    
    /// Reject drawing for `NSView` instances whose conditions match the
    /// given specifier.
    /// - Parameter views: The specifier against which to test.
    static func rejectDraw(for views: ViewSpecifier<String>) {
        Self.install(interceptor: { (view: NSView) in
            if view.className.contains(views.rawValue) {
                view.onBeforeDraw(perform: { view in
                    view.removeFromSuperview();
                });
            }
        }, withName: "reject-string--\(views.rawValue)");
    }
    
    /// Reject drawing for `NSView` instances whose class is of the given
    /// `NSView` subclass.
    /// - Parameter views: The subclass of `NSView` to match.
    static func rejectDraw<T: NSView>(for views: T.Type) {
        Self.install(interceptor: { (view: T) in
            view.onBeforeDraw(perform: { view in
                view.removeFromSuperview();
            });
        }, withName: "reject-class--\(views)");
    }
    
    // MARK: - Draw Permission
    
    /// Permit drawing for `NSView` instances whose conditions match the
    /// given specifier, if such views are currently rejected.
    /// - Parameter views: The specifier whose rejection should clear.
    static func permitDraw(for views: ViewSpecifier<Regex<Substring>>) {
        Self.uninstall(interceptor: "reject-regex--\(views)");
    }
    
    /// Permit drawing for `NSView` instances whose conditions match the
    /// given specifier, if such views are currently rejected.
    /// - Parameter views: The specifier whose rejection should clear.
    static func permitDraw(for views: ViewSpecifier<String>) {
        Self.uninstall(interceptor: "reject-string--\(views)");
    }
    
    /// Permit drawing for `NSView` instances whose class is of the given
    /// `NSView` subclass.
    /// - Parameter views: The subclass of `NSView` whose rejection should clear.
    static func permitDraw<T: NSView>(for views: T.Type) {
        Self.uninstall(interceptor: "reject-class--\(views)");
    }
    
    // MARK: - Lifecycle Hooks
    
    typealias NSViewLifecycleCallback = (_ view: NSView) -> Void;
    typealias NSViewLifecycleHook = (callback: NSViewLifecycleCallback, once: Bool);
    
    private static var __hooks_beforeDraw: [NSView : NSViewLifecycleHook] = [:]
    
    /// Perform the given callback before this view draws.
    /// - Parameters:
    ///   - callback: The callback which should perform — receiving the view instance.
    ///   - once: Should the callback cancel after its first performance?
    func onBeforeDraw(
        perform callback: @escaping NSViewLifecycleCallback,
        once: Bool = false
    ) {
        NSView.__hooks_beforeDraw
            .updateValue((callback, once), forKey: self);
    }
    
    // TODO: Add hook for `NSView.viewWillMove(toWindow:)`
    // TODO: Add hook for `NSView.viewWillMove(toSuperview:)`
    
    // MARK: - Property Requirement
    
    private static var __subscriptions: [NSView: [String: [AnyCancellable]]] = [:];
    
    /// Force the `NSView` property described by the given key to always
    /// be the given value at the time of draw.
    /// - Parameters:
    ///   - property: The property whose value should be forced.
    ///   - value: The value which should be applied.
    func require<T: NSView, F>(
        _ property: WritableKeyPath<T, F>,
        is value: F
    ) {
        guard var view = self as? T else { return }
        
        view.ensureSubscript(for: "\(property)");
        
        view[keyPath: property] = value;
        
        view.publisher(for: property).sink(receiveValue: { _ in
            view[keyPath: property] = value;
        }).store(in: &Self.__subscriptions[view]!["\(property)"]!);
    }
    
    /// Use a callback to subscribe to and force the value of the `NSView`
    /// property described by the given key to be of some value assigned
    /// within the given callback.
    /// - Parameters:
    ///   - property: The property whose value should be tracked.
    ///   - callback: The callback — receiving the `NSView` instance and new property value.
    func require<T: NSView, F>(
        _ property: KeyPath<T, F>,
        using callback: @escaping (_ view: T, _ newValue: F) -> Void
    ) {
        guard let view = self as? T else { return }
        view.ensureSubscript(for: "\(property)");
        
        view.publisher(for: property).sink(receiveValue: { newValue in
            callback(view, newValue);
        }).store(in: &Self.__subscriptions[view]!["\(property)"]!);
    }
    
    /// Use a callback to subscribe to and force the value of the `NSView`
    /// property described by the given key to be of some value assigned
    /// within the given callback.
    /// - Parameters:
    ///   - property: The property whose value should be tracked.
    ///   - callback: The callback — receiving the `NSView` instance.
    ///   - now: Should the property be assigned immediately?
    func require<T: NSView, F>(
        _ property: KeyPath<T, F>,
        using callback: @escaping (_ view: T) -> Void,
        now: Bool = false
    ) {
        guard let view = self as? T else { return }
        view.ensureSubscript(for: "\(property)");
        
        if now {
            callback(view);
        }
        
        view.publisher(for: property).sink(receiveValue: { _ in
            callback(view);
        }).store(in: &Self.__subscriptions[view]!["\(property)"]!);
    }
    
    /// End enforcement of a property whose value has been required by
    /// `NSView.require(:using:)`.
    /// - Parameter property: The property whose value should be released.
    func release<T: NSView, F>(_ property: KeyPath<T, F>) {
        self.ensureSubscript(for: "\(property)");
    }
    
    private func ensureSubscript(for property: String) {
        if !Self.__subscriptions.keys.contains(self) {
            Self.__subscriptions[self] = [:];
        }
        
        if let shouldCancel = Self.__subscriptions[self]![property] {
            shouldCancel.last?.cancel();
        } else {
            Self.__subscriptions[self]![property] = [];
        }
    }
    
    
    // MARK: - Swizzles
    
    private static var __didSwizzle: Bool = false;
    
    private static func __swizzle(_ original: Selector, _ replacement: Selector) {
        
        let originalMethodSet = class_getInstanceMethod(self, original)
        let swizzledMethodSet = class_getInstanceMethod(self, replacement)
        
        method_exchangeImplementations(originalMethodSet!, swizzledMethodSet!)
    }
    
    private static func __swizzle() {
        if NSView.__didSwizzle {
            return;
        }
        
        NSView.__didSwizzle = true;
        
        NSView.__swizzle(
            #selector(NSView.addSubview(_:)),
            #selector(NSView.__add_subview(_:)));
        NSView.__swizzle(
            #selector(NSView.viewWillDraw),
            #selector(NSView.__view_will_draw));
    }
    
    @objc func __view_will_draw() {
        self.__view_will_draw();
        
        if let hook = Self.__hooks_beforeDraw[self] {
            hook.callback(self);
            if hook.once {
                Self.__hooks_beforeDraw.removeValue(forKey: self);
            }
        }
        
    }
    
    @objc func __add_subview(_ view: NSView) {
        self.__add_subview(view);
        
        for interceptor in Self.__interceptors.values {
            interceptor(view);
        }
    }
}

