//
//  AdamantDialogService.swift
//  Adamant
//
//  Created by Anokhov Pavel on 07.01.2018.
//  Copyright © 2018 Adamant. All rights reserved.
//

import UIKit
import FTIndicator
import PMAlertController
import MessageUI

class AdamantDialogService: DialogService {
	// MARK: Dependencies
	var router: Router!
    
    var mailDelegate = MailDelegate()
	
	// Configure notifications
	init() {
		FTIndicator.setIndicatorStyle(.extraLight)
		FTNotificationIndicator.setDefaultDismissTime(4)
	}
}


// MARK: - Modal dialogs
extension AdamantDialogService {
	func present(_ viewController: UIViewController, animated: Bool, completion: (() -> Void)?) {
		if Thread.isMainThread {
			getTopmostViewController()?.present(viewController, animated: animated, completion: completion)
		} else {
			DispatchQueue.main.async { [weak self] in
				self?.getTopmostViewController()?.present(viewController, animated: animated, completion: completion)
			}
		}
	}
	
	func getTopmostViewController() -> UIViewController? {
		if var topController = UIApplication.shared.keyWindow?.rootViewController {
			if let tab = topController as? UITabBarController, let selected = tab.selectedViewController {
				topController = selected
			}
			
			if let nav = topController as? UINavigationController, let visible = nav.visibleViewController {
				return visible
			}
			
			while let presentedViewController = topController.presentedViewController {
				topController = presentedViewController
			}
			
			return topController
		}
		
		return nil
	}
}


// MARK: - Toast
extension AdamantDialogService {
	func showToastMessage(_ message: String) {
		FTIndicator.showToastMessage(message)
	}
	
	func dismissToast() {
		FTIndicator.dismissToast()
	}
}


// MARK: - Indicators
extension AdamantDialogService {
	func showProgress(withMessage message: String?, userInteractionEnable enabled: Bool) {
		FTIndicator.showProgress(withMessage: message, userInteractionEnable: enabled)
	}
	
	func dismissProgress() {
		if Thread.isMainThread {
			FTIndicator.dismissProgress()
		} else {
			DispatchQueue.main.async {
				FTIndicator.dismissProgress()
			}
		}
	}
	
	func showSuccess(withMessage message: String) {
		FTIndicator.showSuccess(withMessage: message)
	}
	
	func showWarning(withMessage message: String) {
		FTIndicator.showError(withMessage: message)
	}
	
	func showError(withMessage message: String, error: Error? = nil) {
		if Thread.isMainThread {
			FTIndicator.dismissProgress()
		} else {
			DispatchQueue.main.sync {
				FTIndicator.dismissProgress()
			}
		}
		
		let alertVC = PMAlertController(title: String.adamantLocalized.alert.error, description: message, image: #imageLiteral(resourceName: "error"), style: .alert)
        
        alertVC.gravityDismissAnimation = false
        alertVC.alertTitle.textColor = UIColor.adamantPrimary
        alertVC.alertDescription.textColor = .adamantSecondary
        alertVC.alertTitle.font = UIFont.adamantPrimary(size: 20)
        alertVC.alertDescription.font = UIFont.adamantPrimaryLight(size: 14)
        alertVC.headerViewHeightConstraint.constant = 50
        
        let supportBtn = PMAlertAction(title: AdamantResources.iosAppSupportEmail, style: .default) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
				guard let presenter = self else {
					return
				}
				
                let mailVC = MFMailComposeViewController()
                mailVC.mailComposeDelegate = self?.mailDelegate
                mailVC.setToRecipients([AdamantResources.iosAppSupportEmail])
                mailVC.setSubject(String.adamantLocalized.alert.emailErrorMessageTitle)
                
                let systemVersion = UIDevice.current.systemVersion
                let model = AdamantUtilities.deviceModelCode
                let deviceInfo = "Model: \(model)\n" + "iOS: \(systemVersion)\n" + "App version: \(AdamantUtilities.applicationVersion)"
				
				let body: String
				
				if let error = error {
					let errorDescription = String(describing: error)
					body = String(format: String.adamantLocalized.alert.emailErrorMessageBodyWithDescription, message, errorDescription, deviceInfo)
				} else {
					body = String(format: String.adamantLocalized.alert.emailErrorMessageBody, message, deviceInfo)
				}
				
                mailVC.setMessageBody(body, isHTML: false)
                
                presenter.present(mailVC, animated: true, completion: nil)
            }
        }
        
        supportBtn.titleLabel?.font = UIFont.adamantPrimary(size: 16)
        supportBtn.setTitleColor(UIColor(hex: "#00B6FF"), for: .normal)
        supportBtn.separator.isHidden = true
        
        alertVC.addAction(supportBtn)
        
        let okBtn = PMAlertAction(title: String.adamantLocalized.alert.ok, style: .default)
        
        okBtn.titleLabel?.font = UIFont.adamantPrimary(size: 16)
        okBtn.setTitleColor(UIColor.white, for: .normal)
        okBtn.backgroundColor = UIColor.adamantSecondary
        alertVC.addAction(okBtn)
        
        alertVC.alertActionStackView.axis = .vertical
        alertVC.alertActionStackView.spacing = 0
        alertVC.alertActionStackViewHeightConstraint.constant = 100
        
        self.present(alertVC, animated: true, completion: nil)
	}
    
    func showNoConnectionNotification() {
		FTIndicator.showNotification(with: #imageLiteral(resourceName: "error"), title: String.adamantLocalized.alert.noInternetNotificationTitle, message: String.adamantLocalized.alert.noInternetNotificationBoby, autoDismiss: false, tapHandler: nil, completion: nil)
    }
    
    func dissmisNoConnectionNotification() {
        FTIndicator.dismissNotification()
    }
    
    func showSyncingIndicator() {
        FTIndicator.showNotification(with: #imageLiteral(resourceName: "sync"), title: String.adamantLocalized.alert.syncingMessageTitle, message: String.adamantLocalized.alert.syncingMessageBoby, autoDismiss: false, tapHandler: nil, completion: nil)
    }
    
    func dissmisSyncingIndicator() {
        FTIndicator.dismissNotification()
    }
}


// MARK: - Notifications
extension AdamantDialogService {
	func showNotification(title: String?, message: String?, image: UIImage?, tapHandler: (() -> Void)?) {
		if let image = image {
			FTIndicator.showNotification(with: image, title: title, message: message, tapHandler: tapHandler)
		} else {
			FTIndicator.showNotification(withTitle: title, message: message, tapHandler: tapHandler)
		}
	}
	
	func dismissNotification() {
		FTIndicator.dismissNotification()
	}
}


// MAKR: - Activity controllers
extension AdamantDialogService {
	func presentShareAlertFor(string: String, types: [ShareType], excludedActivityTypes: [UIActivityType]?, animated: Bool, completion: (() -> Void)?) {
		let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
		
		for type in types {
			switch type {
			case .copyToPasteboard:
				alert.addAction(UIAlertAction(title: type.localized , style: .default) { [weak self] _ in
					UIPasteboard.general.string = string
					self?.showToastMessage(String.adamantLocalized.alert.copiedToPasteboardNotification)
				})
				
			case .share:
				alert.addAction(UIAlertAction(title: type.localized, style: .default) { [weak self] _ in
					let vc = UIActivityViewController(activityItems: [string], applicationActivities: nil)
					vc.excludedActivityTypes = excludedActivityTypes
					self?.present(vc, animated: true, completion: completion)
				})
				
			case .generateQr(let sharingTip):
				alert.addAction(UIAlertAction(title: type.localized, style: .default) { [weak self] _ in
					switch AdamantQRTools.generateQrFrom(string: string) {
					case .success(let qr):
						guard let vc = self?.router.get(scene: AdamantScene.Shared.shareQr) as? ShareQrViewController else {
							fatalError("Can't find ShareQrViewController")
						}
						
						vc.qrCode = qr
						vc.sharingTip = sharingTip
						vc.excludedActivityTypes = excludedActivityTypes
						self?.present(vc, animated: true, completion: completion)
						
					case .failure(error: let error):
						self?.showError(withMessage: error.localizedDescription, error: error)
					}
				})
				
			case .saveToPhotolibrary(let image):
				let action = UIAlertAction(title: type.localized, style: .default) { [weak self] _ in
					UIImageWriteToSavedPhotosAlbum(image, self, #selector(self?.image(_:didFinishSavingWithError:contextInfo:)), nil)
				}
				
				alert.addAction(action)
			}
		}
		
		alert.addAction(UIAlertAction(title: String.adamantLocalized.alert.cancel, style: .cancel, handler: nil))
		
		present(alert, animated: animated, completion: completion)
	}
	
	@objc private func image(_ image: UIImage, didFinishSavingWithError error: NSError?, contextInfo: UnsafeRawPointer) {
		if let error = error {
			showError(withMessage: error.localizedDescription)
		} else {
			showSuccess(withMessage: String.adamantLocalized.alert.done)
		}
	}
	
	func presentGoToSettingsAlert(title: String?, message: String?) {
		let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
		
		alert.addAction(UIAlertAction(title: String.adamantLocalized.alert.settings, style: .default) { _ in
			DispatchQueue.main.async {
				if let settingsURL = URL(string: UIApplicationOpenSettingsURLString) {
					UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
				}
			}
		})
		
		alert.addAction(UIAlertAction(title: String.adamantLocalized.alert.cancel, style: .cancel, handler: nil))
		
		if Thread.isMainThread {
			present(alert, animated: true, completion: nil)
		} else {
			DispatchQueue.main.async { [weak self] in
				self?.present(alert, animated: true, completion: nil)
			}
		}
	}
}

// MAKR: - Alerts
extension AdamantDialogService {
    func showAlert(title: String, message: String, actions: [PMAlertAction]?) {
        let alertVC = PMAlertController(title: title, description: message, image: nil, style: .alert)
        
        alertVC.gravityDismissAnimation = false
        alertVC.alertTitle.textColor = UIColor.adamantPrimary
        alertVC.alertDescription.textColor = .adamantSecondary
        alertVC.alertTitle.font = UIFont.adamantPrimary(size: 20)
        alertVC.alertDescription.font = UIFont.adamantPrimaryLight(size: 14)
        
        if let actions = actions {
            for action in actions {
                action.titleLabel?.font = UIFont.adamantPrimary(size: 16)
                action.setTitleColor(UIColor.adamantSecondary, for: .normal)
                alertVC.addAction(action)
            }
            
            let cancelAction = PMAlertAction(title: String.adamantLocalized.alert.cancel, style: .cancel)
            cancelAction.titleLabel?.font = UIFont.adamantPrimary(size: 16)
            cancelAction.setTitleColor(UIColor.white, for: .normal)
            cancelAction.backgroundColor = UIColor.adamantSecondary

            alertVC.addAction(cancelAction)
            
            alertVC.alertActionStackViewHeightConstraint.constant = CGFloat((actions.count + 1) * 50) + alertVC.alertActionStackView.spacing * CGFloat(actions.count)
        } else {
            let okBtn = PMAlertAction(title: String.adamantLocalized.alert.ok, style: .default)
            
            okBtn.titleLabel?.font = UIFont.adamantPrimary(size: 16)
            okBtn.setTitleColor(UIColor.white, for: .normal)
            okBtn.backgroundColor = UIColor.adamantSecondary
            alertVC.addAction(okBtn)
            
            alertVC.alertActionStackViewHeightConstraint.constant = 50
        }
        
        self.present(alertVC, animated: true, completion: nil)
    }
    
    func showSystemActionSheet(title: String, message: String, actions: [UIAlertAction]?) {
        guard let actions = actions, actions.count > 0 else {
            return
        }
        
        let alertVC = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        
        for action in actions {
            alertVC.addAction(action)
        }
        
        alertVC.addAction(UIAlertAction(title: String.adamantLocalized.alert.cancel, style: .cancel))
        
        self.present(alertVC, animated: true, completion: nil)
    }
}

class MailDelegate: NSObject, MFMailComposeViewControllerDelegate {
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil)
    }

}
