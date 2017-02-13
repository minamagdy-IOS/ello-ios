////
///  FollowingViewController.swift
//

import SwiftyUserDefaults

class FollowingViewController: StreamableViewController {
    override func trackerName() -> String? { return "Stream" }
    override func trackerProps() -> [String: AnyObject]? { return ["kind": "Following"]}

    var navigationBar: ElloNavigationBar!
    fileprivate var loggedPromptEventForThisSession = false
    fileprivate var reloadStreamContentObserver: NotificationObserver?
    fileprivate var appBackgroundObserver: NotificationObserver?
    fileprivate var appForegroundObserver: NotificationObserver?

    override var tabBarItem: UITabBarItem? {
        get { return UITabBarItem.item(.circBig) }
        set { self.tabBarItem = newValue }
    }

    required init() {
        super.init(nibName: nil, bundle: nil)
        self.title = InterfaceString.Following.Title
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

        setupNavigationBar()
        setupNavigationItems(streamKind: .following)

        scrollLogic.navBarHeight = 44
        streamViewController.streamKind = .following
        ElloHUD.showLoadingHudInView(streamViewController.view)
        streamViewController.loadInitialPage()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        addTemporaryNotificationObservers()
        if !loggedPromptEventForThisSession {
            Rate.sharedRate.logEvent()
            loggedPromptEventForThisSession = true
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        removeNotificationObservers()
    }

    override func viewForStream() -> UIView {
        return view
    }

    override func didSetCurrentUser() {
        if isViewLoaded {
            streamViewController.currentUser = currentUser
        }
        super.didSetCurrentUser()
    }

    override func showNavBars() {
        super.showNavBars()
        positionNavBar(navigationBar, visible: true)
        updateInsets()
    }

    override func hideNavBars() {
        super.hideNavBars()
        positionNavBar(navigationBar, visible: false)
        updateInsets()
    }

    // MARK: - IBActions
    let drawerAnimator = DrawerAnimator()

    func hamburgerButtonTapped() {
        let drawer = DrawerViewController()
        drawer.currentUser = currentUser

        drawer.transitioningDelegate = drawerAnimator
        drawer.modalPresentationStyle = .custom

        self.present(drawer, animated: true, completion: nil)
    }

}

private extension FollowingViewController {

    func updateInsets() {
        updateInsets(navBar: navigationBar, streamController: streamViewController)
    }

    func setupNavigationBar() {
        navigationBar = ElloNavigationBar(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: ElloNavigationBar.Size.height))
        navigationBar.autoresizingMask = [.flexibleBottomMargin, .flexibleWidth]
        view.addSubview(navigationBar)

    }

    func setupNavigationItems(streamKind: StreamKind) {
        elloNavigationItem.leftBarButtonItem = UIBarButtonItem(image: InterfaceImage.burger.normalImage, style: .done, target: self, action: #selector(FollowingViewController.hamburgerButtonTapped))
        let searchItem = UIBarButtonItem.searchItem(controller: self)
        let gridListItem = UIBarButtonItem.gridListItem(delegate: streamViewController, isGridView: streamKind.isGridView)
        elloNavigationItem.rightBarButtonItems = [
            searchItem,
            gridListItem,
        ]
        navigationBar.items = [elloNavigationItem]
    }

    func addTemporaryNotificationObservers() {
        reloadStreamContentObserver = NotificationObserver(notification: NewContentNotifications.reloadStreamContent) { [weak self] _ in
            self?.streamViewController.loadInitialPage(reload: true)
        }
    }

    func removeTemporaryNotificationObservers() {
        reloadStreamContentObserver?.removeObserver()
    }

    func addNotificationObservers() {
        appBackgroundObserver = NotificationObserver(notification: Application.Notifications.DidEnterBackground) { [weak self] _ in
            self?.loggedPromptEventForThisSession = false
        }
    }

    func removeNotificationObservers() {
        appBackgroundObserver?.removeObserver()
    }
}
