//
//  AppDelegate.swift
//  Adamant
//
//  Created by Anokhov Pavel on 05.01.2018.
//  Copyright © 2018 Adamant. All rights reserved.
//

import UIKit
import Swinject
import CryptoSwift
import CoreData


// MARK: - Constants
extension String.adamantLocalized {
	struct tabItems {
		static let account = NSLocalizedString("Tabs.Account", comment: "Main tab bar: Account page")
		static let chats = NSLocalizedString("Tabs.Chats", comment: "Main tab bar: Chats page")
		static let settings = NSLocalizedString("Tabs.Settings", comment: "Main tab bar: Settings page")
	}
}

extension StoreKey {
	struct application {
		static let deviceTokenHash = "app.deviceTokenHash"
		
		private init() {}
	}
}


// MARK: - Resources
struct AdamantResources {
	static let jsCore = Bundle.main.url(forResource: "adamant-core", withExtension: "js")!
	static let coreDataModel = Bundle.main.url(forResource: "ChatModels", withExtension: "momd")!
	
	static let servers = [
		"https://endless.adamant.im",
        "https://clown.adamant.im",
        "https://lake.adamant.im"
	]
	
	static let iosAppSupportEmail = "ios@adamant.im"
	
	private init() {}
}


// MARK: - Application
@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
	var window: UIWindow?
	var repeater: RepeaterService!
	var container: Container!
    
    var isChatsInitialSyncFinished = false
    var isTransfersInitialSyncFinished = false
	
	// MARK: Dependencies
	var accountService: AccountService!
	var notificationService: NotificationsService!
    var dialogService: DialogService!

	// MARK: - Lifecycle
	
	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
		// MARK: 1. Initiating Swinject
		container = Container()
		container.registerAdamantServices()
		accountService = container.resolve(AccountService.self)
		notificationService = container.resolve(NotificationsService.self)
        dialogService = container.resolve(DialogService.self)
		
		// MARK: 2. Init UI
		window = UIWindow(frame: UIScreen.main.bounds)
		window!.rootViewController = UITabBarController()
		window!.rootViewController?.view.backgroundColor = .white
		window!.makeKeyAndVisible()
		window!.tintColor = UIColor.adamantPrimary
		
		
		// MARK: 3. Show login
		
		guard let router = container.resolve(Router.self) else {
			fatalError("Failed to get Router")
		}
		
		let login = router.get(scene: AdamantScene.Login.login)
		window!.rootViewController?.present(login, animated: false, completion: nil)
		
		// MARK: 4. Async prepare pages
		if let tabbar = window?.rootViewController as? UITabBarController {
			let accountRoot = router.get(scene: AdamantScene.Account.account)
			let account = UINavigationController(rootViewController: accountRoot)
			account.tabBarItem.title = String.adamantLocalized.tabItems.account
			account.tabBarItem.image = #imageLiteral(resourceName: "wallet_tab")
			
			let chatListRoot = router.get(scene: AdamantScene.Chats.chatList)
			let chatList = UINavigationController(rootViewController: chatListRoot)
			chatList.tabBarItem.title = String.adamantLocalized.tabItems.chats
			chatList.tabBarItem.image = #imageLiteral(resourceName: "chats_tab")
			
			let settingsRoot = router.get(scene: AdamantScene.Settings.settings)
			let settings = UINavigationController(rootViewController: settingsRoot)
			settings.tabBarItem.title = String.adamantLocalized.tabItems.settings
			settings.tabBarItem.image = #imageLiteral(resourceName: "settings_tab")
			
			account.tabBarItem.badgeColor = UIColor.adamantPrimary
			chatList.tabBarItem.badgeColor = UIColor.adamantPrimary
			settings.tabBarItem.badgeColor = UIColor.adamantPrimary
			
			tabbar.setViewControllers([account, chatList, settings], animated: false)
		}
		
		// MARK: 5 Reachability & Autoupdate
		repeater = RepeaterService()
		
		// Configure reachability
		if let reachability = container.resolve(ReachabilityMonitor.self) {
			reachability.start()
			
			switch reachability.connection {
			case .cellular, .wifi:
                dialogService.dissmisNoConnectionNotification()
				break
				
			case .none:
                dialogService.showNoConnectionNotification()
				repeater.pauseAll()
			}
			
			NotificationCenter.default.addObserver(forName: Notification.Name.AdamantReachabilityMonitor.reachabilityChanged, object: reachability, queue: nil) { [weak self] notification in
				guard let connection = notification.userInfo?[AdamantUserInfoKey.ReachabilityMonitor.connection] as? AdamantConnection,
					let repeater = self?.repeater else {
						return
				}
				
				switch connection {
				case .cellular, .wifi:
                    self?.dialogService.dissmisNoConnectionNotification()
					repeater.resumeAll()
					
				case .none:
                    self?.dialogService.showNoConnectionNotification()
					repeater.pauseAll()
				}
			}
		}
		
		// Register repeater services
		if let chatsProvider = container.resolve(ChatsProvider.self),
			let transfersProvider = container.resolve(TransfersProvider.self),
			let accountService = container.resolve(AccountService.self) {
			repeater.registerForegroundCall(label: "chatsProvider", interval: 3, queue: .global(qos: .utility), callback: chatsProvider.update)
			repeater.registerForegroundCall(label: "transfersProvider", interval: 15, queue: .global(qos: .utility), callback: transfersProvider.update)
			repeater.registerForegroundCall(label: "accountService", interval: 15, queue: .global(qos: .utility), callback: accountService.update)
		} else {
			fatalError("Failed to get chatsProvider")
		}
		
		
		// MARK: 6. Logout reset
		NotificationCenter.default.addObserver(forName: Notification.Name.AdamantAccountService.userLoggedOut, object: nil, queue: OperationQueue.main) { [weak self] _ in
			// On logout, pop all navigators to root.
			guard let tbc = self?.window?.rootViewController as? UITabBarController, let vcs = tbc.viewControllers else {
				return
			}
			
			for case let nav as UINavigationController in vcs {
				nav.popToRootViewController(animated: false)
			}
		}
		
		// MARK: 7. Welcome messages
		NotificationCenter.default.addObserver(forName: Notification.Name.AdamantChatsProvider.initialSyncFinished, object: nil, queue: OperationQueue.main, using: handleWelcomeMessages)
        
        // MARK: 8. Initiona sync indicator
        NotificationCenter.default.addObserver(forName: Notification.Name.AdamantAccountService.userLoggedIn, object: nil, queue: OperationQueue.main, using: handleInitialSync)
        NotificationCenter.default.addObserver(forName: Notification.Name.AdamantChatsProvider.initialSyncFinished, object: nil, queue: OperationQueue.main, using: handleInitialSync)
        NotificationCenter.default.addObserver(forName: Notification.Name.AdamantTransfersProvider.initialSyncFinished, object: nil, queue: OperationQueue.main, using: handleInitialSync)
		
		return true
	}
	
	// MARK: Timers
	
	func applicationWillResignActive(_ application: UIApplication) {
		repeater.pauseAll()
	}
	
	func applicationDidEnterBackground(_ application: UIApplication) {
		repeater.pauseAll()
	}
	
	// MARK: Notifications
	
	func applicationDidBecomeActive(_ application: UIApplication) {
		if accountService.account != nil {
			notificationService.removeAllDeliveredNotifications()
		}
		
		if let connection = container.resolve(ReachabilityMonitor.self)?.connection {
			switch connection {
			case .wifi, .cellular:
				repeater.resumeAll()
				
			case .none:
				break
			}
		} else {
			repeater.resumeAll()
		}
	}
}

// MARK: - Remote notifications
extension AppDelegate {
	func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
		guard let address = accountService.account?.address, let keypair = accountService.keypair else {
			print("Trying to register with no user logged")
			UIApplication.shared.unregisterForRemoteNotifications()
			return
		}
		
		let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
		
		// Checking, if device token had not changed
		guard let securedStore = container.resolve(SecuredStore.self) else {
			fatalError("can't get secured store to get device token hash")
		}
		
		let tokenHash = token.md5()
		
		if let savedHash = securedStore.get(StoreKey.application.deviceTokenHash), tokenHash == savedHash {
			return
		} else {
			securedStore.set(tokenHash, for: StoreKey.application.deviceTokenHash)
		}
		
		// Storing new token in blockchain
		guard let apiService = container.resolve(ApiService.self) else {
			fatalError("can't get api service to register device token")
		}
		
		apiService.store(key: "deviceToken", value: token, type: StateType.keyValue, sender: address, keypair: keypair) { [weak self] result in
			switch result {
			case .success:
				return
				
			case .failure(let error):
				print("Failed to store device token: \(error)")
				self?.notificationService?.setNotificationsMode(.disabled, completion: nil)
			}
		}
	}
	
	func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
		if let service = container.resolve(DialogService.self) {
			service.showError(withMessage: String.localizedStringWithFormat(String.adamantLocalized.notifications.registerRemotesError, error.localizedDescription), error: error)
		}
	}
}


// MARK: - Background Fetch
extension AppDelegate {
	func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
		let container = Container()
		container.registerAdamantBackgroundFetchServices()
		
		guard let notificationsService = container.resolve(NotificationsService.self) else {
				UIApplication.shared.setMinimumBackgroundFetchInterval(UIApplicationBackgroundFetchIntervalNever)
				completionHandler(.failed)
				return
		}
		
		notificationsService.startBackgroundBatchNotifications()
		
		let services: [BackgroundFetchService] = [
			container.resolve(ChatsProvider.self) as! BackgroundFetchService,
			container.resolve(TransfersProvider.self) as! BackgroundFetchService
		]
		
		let group = DispatchGroup()
		let semaphore = DispatchSemaphore(value: 1)
		var results = [FetchResult]()
		
		for service in services {
			group.enter()
			service.fetchBackgroundData(notificationsService: notificationsService) { result in
				defer {
					group.leave()
				}
				
				semaphore.wait()
				results.append(result)
				semaphore.signal()
			}
		}
		
		group.notify(queue: DispatchQueue.global(qos: .utility)) {
			notificationsService.stopBackgroundBatchNotifications()
			
			for result in results {
				switch result {
				case .newData:
					completionHandler(.newData)
					return
					
				case .noData:
					break
					
				case .failed:
					completionHandler(.failed)
					return
				}
			}
			
			completionHandler(.noData)
		}
	}
}


// MARK: - Welcome messages
extension AppDelegate {
	private func handleWelcomeMessages(notification: Notification) {
		guard let stack = container.resolve(CoreDataStack.self), let chatProvider = container.resolve(ChatsProvider.self) else {
			fatalError("Whoa...")
		}
		
		let request = NSFetchRequest<MessageTransaction>(entityName: MessageTransaction.entityName)
		
		let unread: Bool
		if let count = try? stack.container.viewContext.count(for: request), count > 0 {
			unread = false
		} else {
			unread = true
		}
		
		if let welcome = AdamantContacts.adamantBountyWallet.messages["chats.welcome_message"] {
			chatProvider.fakeReceived(message: welcome,
									  senderId: AdamantContacts.adamantBountyWallet.name,
									  date: Date.adamantNullDate,
									  unread: unread,
									  silent: true,
									  completion: { _ in })
		}
		
		if let ico = AdamantContacts.adamantIco.messages["chats.ico_message"] {
			chatProvider.fakeReceived(message: ico,
									  senderId: AdamantContacts.adamantIco.name,
									  date: Date.adamantNullDate,
									  unread: unread,
									  silent: true,
									  completion: { _ in })
		}
	}
}

extension AppDelegate {
    private func handleInitialSync(notification: Notification) {
        
        switch notification.name {
        case Notification.Name.AdamantAccountService.userLoggedIn:
            self.isChatsInitialSyncFinished = false
            self.isTransfersInitialSyncFinished = false
            dialogService.showSyncingIndicator()
            break
        case Notification.Name.AdamantChatsProvider.initialSyncFinished:
            self.isChatsInitialSyncFinished = true
            print("Chats synced")
            break
        case Notification.Name.AdamantTransfersProvider.initialSyncFinished:
            self.isTransfersInitialSyncFinished = true
            print("Transfers synced")
            break
        default:
            return
        }
        
        if self.isChatsInitialSyncFinished && self.isTransfersInitialSyncFinished {
            print("Fully synced")
            dialogService.dissmisSyncingIndicator()
        }
    }
}
