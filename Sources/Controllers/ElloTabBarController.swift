//
//  ElloTabBarController.swift
//  Ello
//
//  Created by Sean Dougherty on 11/22/14.
//  Copyright (c) 2014 Ello. All rights reserved.
//

import UIKit
import SwiftyUserDefaults

public enum ElloTab: Int {
    case Discovery
    case Notifications
    case Stream
    case Profile
    case Post

    static let DefaultTab = ElloTab.Stream

    public var title: String {
        switch self {
            case Discovery:     return "Discovery"
            case Notifications: return "Notifications"
            case Stream:        return "Stream"
            case Profile:       return "Profile"
            case Post:          return "Omnibar"
        }
    }

    public var narrationDefaultKey: String { return "ElloTabBarControllerDidShowNarration\(title)" }

    public var narrationText: String {
        switch self {
            case Discovery:     return "Discover: Find friends and creators. View beautiful art & inspiring stories."
            case Notifications: return "Notifications: Stay up to date with real-time alerts."
            case Stream:        return "Streams: View posts by everyone you follow. Keep them organized in Friends & Noise."
            case Profile:       return "Your Profile: Everything you’ve posted in one place. Settings too!"
            case Post:          return "Post: Text, images, links & GIFs from one easy place."
        }
    }

}

public class ElloTabBarController: UIViewController, HasAppController {
    public let tabBar = ElloTabBar()
    private var systemLoggedOutObserver: NotificationObserver?
    private var streamLoadedObserver: NotificationObserver?

    private var newContentService = NewContentService()
    private var foregroundObserver: NotificationObserver?
    private var backgroundObserver: NotificationObserver?
    private var newNotificationsObserver: NotificationObserver?
    private var newStreamContentObserver: NotificationObserver?

    private var visibleViewController = UIViewController()
    var parentAppController: AppViewController?

    var notificationsDot: UIView?
    var streamsDot: UIView?

    private var _tabBarHidden = false
    public var tabBarHidden: Bool {
        get { return _tabBarHidden }
        set { setTabBarHidden(newValue, animated: false) }
    }

    public private(set) var previousTab: ElloTab = .DefaultTab
    public var selectedTab: ElloTab = .DefaultTab {
        willSet {
            if selectedTab != previousTab {
                previousTab = selectedTab
            }
        }
        didSet {
            updateVisibleViewController()
        }
    }

    public var selectedViewController: UIViewController {
        get { return childViewControllers[selectedTab.rawValue] as! UIViewController }
        set(controller) {
            let index = find(childViewControllers as! [UIViewController], controller)
            selectedTab = index.flatMap { ElloTab(rawValue: $0) } ?? .DefaultTab
        }
    }

    var currentUser : User?
    var profileResponseConfig: ResponseConfig?

    var narrationView = NarrationView()
    public var isShowingNarration = false
    public var shouldShowNarration: Bool {
        get { return !ElloTabBarController.didShowNarration(selectedTab) }
        set { ElloTabBarController.didShowNarration(selectedTab, !newValue) }
    }
}

public extension ElloTabBarController {

    class func didShowNarration(tab: ElloTab) -> Bool {
        return Defaults[tab.narrationDefaultKey].bool ?? false
    }

    class func didShowNarration(tab: ElloTab, _ value: Bool) {
        Defaults[tab.narrationDefaultKey] = value
    }

}

public extension ElloTabBarController {
    class func instantiateFromStoryboard() -> ElloTabBarController {
        return UIStoryboard.storyboardWithId(.ElloTabBar) as! ElloTabBarController
    }
}

// MARK: View Lifecycle
public extension ElloTabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.opaque = true
        view.addSubview(tabBar)
        tabBar.delegate = self
        modalTransitionStyle = .CrossDissolve

        let gesture = UITapGestureRecognizer(target: self, action: Selector("dismissNarrationView"))
        narrationView.userInteractionEnabled = true
        narrationView.addGestureRecognizer(gesture)

        updateTabBarItems()
        updateVisibleViewController()
        addDots()
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        updateNarrationTitle(animated: animated)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        positionTabBar()
        selectedViewController.view.frame = view.bounds
    }

    private func positionTabBar() {
        var upAmount = CGFloat(0)
        if !tabBarHidden || isShowingNarration {
            upAmount = tabBar.frame.height
        }
        tabBar.frame = view.bounds.fromBottom().withHeight(tabBar.frame.height).shiftUp(upAmount)
    }

    func setTabBarHidden(hidden: Bool, animated: Bool) {
        _tabBarHidden = hidden

        animate(animated: animated) {
            self.positionTabBar()
        }
    }
}

// listen for system logged out event
public extension ElloTabBarController {
    public func activateTabBar() {
        setupNotificationObservers()
        newContentService.startPolling()
    }

    public func deactivateTabBar() {
        removeNotificationObservers()
    }

    private func setupNotificationObservers() {

        let _ = Application.shared() // this is lame but we need Application to initialize to observe it's notifications

        systemLoggedOutObserver = NotificationObserver(notification: AuthenticationNotifications.invalidToken, block: systemLoggedOut)

        streamLoadedObserver = NotificationObserver(notification: StreamLoadedNotifications.streamLoaded) {
            [unowned self] streamKind in
            switch streamKind {
            case .Notifications(category: nil):
                self.notificationsDot?.hidden = true
            default: break
            }
        }

        foregroundObserver = NotificationObserver(notification: Application.Notifications.WillEnterForeground) {
            [unowned self] _ in
            self.newContentService.startPolling()
        }

        backgroundObserver = NotificationObserver(notification: Application.Notifications.DidEnterBackground) {
            [unowned self] _ in
            self.newContentService.stopPolling()
        }

        newNotificationsObserver = NotificationObserver(notification: NewContentNotifications.newNotifications) {
            [unowned self] _ in
            self.notificationsDot?.hidden = false
        }

        newStreamContentObserver = NotificationObserver(notification: NewContentNotifications.newStreamContent) {
            [unowned self] _ in
            self.streamsDot?.hidden = false
        }

    }

    private func removeNotificationObservers() {
        systemLoggedOutObserver?.removeObserver()
        streamLoadedObserver?.removeObserver()
        newNotificationsObserver?.removeObserver()
        backgroundObserver?.removeObserver()
        foregroundObserver?.removeObserver()
        newStreamContentObserver?.removeObserver()
    }

}

public extension ElloTabBarController {
    func setProfileData(currentUser: User) {
        self.currentUser = currentUser
        for controller in childViewControllers {
            if let controller = controller as? BaseElloViewController {
                controller.currentUser = currentUser
            }
            else if let controller = controller as? ElloNavigationController {
                controller.setProfileData(currentUser)
            }
        }
    }

    func systemLoggedOut(shouldAlert: Bool) {
        parentAppController?.forceLogOut(shouldAlert)
    }
}

// UITabBarDelegate
extension ElloTabBarController: UITabBarDelegate {
    public func tabBar(tabBar: UITabBar, didSelectItem item: UITabBarItem) {
        if let items = tabBar.items as? [UITabBarItem], index = find(items, item) {
            if index == selectedTab.rawValue {
                if let navigationViewController = selectedViewController as? UINavigationController
                    where navigationViewController.childViewControllers.count > 1
                {
                    navigationViewController.popToRootViewControllerAnimated(true)
                }
                else if let scrollView = findScrollView(selectedViewController.view) {
                    scrollView.setContentOffset(CGPoint(x: 0, y: -scrollView.contentInset.top), animated: true)
                }
            }
            else {
                selectedTab = ElloTab(rawValue:index) ?? .Stream
            }

            // hide the red dot on the stream tab icon
            if index == 2 {
                self.streamsDot?.hidden = true
            }
        }
    }

    public func findScrollView(view: UIView) -> UIScrollView? {
        if let found = view as? UIScrollView
            where found.scrollsToTop
        {
            return found
        }

        for subview in view.subviews as! [UIView] {
            if let found = findScrollView(subview) {
                return found
            }
        }

        return nil
    }
}

// MARK: Child View Controller handling
public extension ElloTabBarController {
    override func sizeForChildContentContainer(container: UIContentContainer, withParentContainerSize size: CGSize) -> CGSize {
        return view.frame.size
    }
}

private extension ElloTabBarController {

    func updateTabBarItems() {
        let controllers = childViewControllers as! [UIViewController]
        tabBar.items = controllers.map { controller in
            let tabBarItem = controller.tabBarItem
            if tabBarItem.selectedImage != nil && tabBarItem.selectedImage.renderingMode != .AlwaysOriginal {
                tabBarItem.selectedImage = tabBarItem.selectedImage.imageWithRenderingMode(.AlwaysOriginal)
            }
            return tabBarItem
        }
    }

    func updateVisibleViewController() {
        let currentViewController = visibleViewController
        let nextViewController = selectedViewController

        nextTick {
            if currentViewController.parentViewController != self {
                self.showViewController(nextViewController)
                self.prepareNarration()
            }
            else if currentViewController != nextViewController {
                self.transitionControllers(currentViewController, nextViewController)
            }
        }

        visibleViewController = nextViewController
    }

    func hideViewController(hideViewController: UIViewController) {
        if hideViewController.parentViewController == self {
            hideViewController.view.removeFromSuperview()
        }
    }

    func showViewController(showViewController: UIViewController) {
        tabBar.selectedItem = tabBar.items?[selectedTab.rawValue] as? UITabBarItem
        let controller = (showViewController as? UINavigationController)?.topViewController ?? showViewController
        view.insertSubview(showViewController.view, belowSubview: tabBar)
        showViewController.view.frame = tabBar.frame.fromBottom().growUp(view.frame.height - tabBar.frame.height)
        showViewController.view.autoresizingMask = .FlexibleHeight | .FlexibleWidth
    }

    func transitionControllers(hideViewController: UIViewController, _ showViewController: UIViewController) {
        transitionFromViewController(hideViewController,
            toViewController: showViewController,
            duration: 0,
            options: nil,
            animations: {
                self.hideViewController(hideViewController)
                self.showViewController(showViewController)
            },
            completion: { _ in
                self.prepareNarration()
            })
    }

}

extension ElloTabBarController {

    private func addDots() {
        notificationsDot = redDotAtIndex(1)
        streamsDot = redDotAtIndex(2)
    }

    private func addRedDotAtIndex(index: Int) -> UIView {
        let radius: CGFloat = 3
        let diameter = radius * 2
        let topMargin: CGFloat = 11
        let tabBarItemCount = CGFloat(tabBar.items?.count ?? 0)
        let halfItemWidth = CGRectGetWidth(view.bounds) / (tabBarItemCount * 2)
        let xOffset = halfItemWidth * CGFloat(index * 2 + 1)
        let item = tabBar.items?[index] as? UITabBarItem
        let imageHalfWidth: CGFloat = item?.selectedImage?.size.width ?? 0 / 2

        let redDot = UIView(frame: CGRect(x: xOffset + imageHalfWidth - 11, y: topMargin, width: diameter, height: diameter))
        redDot.backgroundColor = UIColor.redColor()
        redDot.layer.cornerRadius = radius
        redDot.hidden = true

        tabBar.addSubview(redDot)
        return redDot
    }

    private func prepareNarration() {
        if shouldShowNarration {
            if !isShowingNarration {
                animateInNarrationView()
            }
            updateNarrationTitle()
        }
        else if isShowingNarration {
            animateOutNarrationView()
        }
    }

    func dismissNarrationView() {
        shouldShowNarration = false
        animateOutNarrationView()
    }

    private func updateNarrationTitle(animated: Bool = true) {
        animate(animated: animated, options: .CurveEaseOut | .BeginFromCurrentState) {
            if let rect = self.tabBar.itemPositionsIn(self.narrationView).safeValue(self.selectedTab.rawValue) {
                self.narrationView.pointerX = rect.midX
            }
        }
        narrationView.text = NSLocalizedString(selectedTab.narrationText, comment: "\(selectedTab.title) narration text")
    }

    private func animateInStartFrame() -> CGRect {
        let upAmount = CGFloat(20)
        let narrationHeight = NarrationView.Size.height
        let pointerHeight = NarrationView.Size.pointer.height
        let bottomMargin = ElloTabBar.Size.height - NarrationView.Size.pointer.height
        return CGRect(
            x: 0,
            y: view.frame.height - bottomMargin - narrationHeight - upAmount,
            width: view.frame.width,
            height: narrationHeight
            )
    }

    private func animateInFinalFrame() -> CGRect {
        let narrationHeight = NarrationView.Size.height
        let pointerHeight = NarrationView.Size.pointer.height
        let bottomMargin = ElloTabBar.Size.height - NarrationView.Size.pointer.height
        return CGRect(
            x: 0,
            y: view.frame.height - bottomMargin - narrationHeight,
            width: view.frame.width,
            height: narrationHeight
            )
    }

    private func animateInNarrationView() {
        let narrationHeight = NarrationView.Size.height
        let pointerHeight = NarrationView.Size.pointer.height
        let bottomMargin = ElloTabBar.Size.height - NarrationView.Size.pointer.height

        narrationView.alpha = 0
        narrationView.frame = animateInStartFrame()
        view.addSubview(narrationView)
        updateNarrationTitle(animated: false)
        animate() {
            self.narrationView.alpha = 1
            self.narrationView.frame = self.animateInFinalFrame()
        }
        isShowingNarration = true
    }

    private func animateOutNarrationView() {
        animate() {
            self.narrationView.alpha = 0
            self.narrationView.frame = self.animateInStartFrame()
        }
        isShowingNarration = false
    }

}
