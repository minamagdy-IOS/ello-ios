//
//  SensitiveSettingsViewController.swift
//  Ello
//
//  Created by Tony DiPasquale on 3/24/15.
//  Copyright (c) 2015 Ello. All rights reserved.
//

import Foundation

private let SensitiveSettingsSubmitViewHeight: CGFloat = 128

public protocol SensitiveSettingsDelegate {
    func sensitiveSettingsDidUpdate()
}

private enum SensitiveSettingsRow: Int {
    case Username
    case Email
    case Password
    case Submit
    case Unknown
}

public class SensitiveSettingsViewController: UITableViewController {
    @IBOutlet weak public var usernameView: ElloTextFieldView!
    @IBOutlet weak public var emailView: ElloTextFieldView!
    @IBOutlet weak public var passwordView: ElloTextFieldView!
    @IBOutlet weak public var currentPasswordField: ElloTextField!

    public var currentUser: Profile?
    public var delegate: SensitiveSettingsDelegate?
    var validationCancel: Functional.BasicBlock?

    public var isUpdatable: Bool {
        return currentUser?.username != usernameView.textField.text
            || currentUser?.email != emailView.textField.text
            || !passwordView.textField.text.isEmpty
    }

    public var height: CGFloat {
        let cellHeights = usernameView.height + emailView.height + passwordView.height
        return cellHeights + (isUpdatable ? SensitiveSettingsSubmitViewHeight : 0)
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
    }

    private func setupViews() {
        usernameView.label.setLabelText(NSLocalizedString("Username", comment: "username key"))
        usernameView.textField.text = currentUser?.username
        usernameView.textFieldDidChange = { text in
            self.valueChanged()
            self.usernameView.setState(.Loading)
            self.validationCancel?()
            self.usernameView.setErrorMessage("");
            self.usernameView.setMessage("");
            self.updateView()

            self.validationCancel = Functional.cancelableDelay(0.5) {
                if text.isEmpty {
                    self.usernameView.setState(.Error)
                } else if text == self.currentUser?.username {
                    self.usernameView.setState(.None)
                } else {
                    AvailabilityService().usernameAvailability(text, success: { availability in
                        if text != self.usernameView.textField.text { return }
                        let state: ValidationState = availability.isUsernameAvailable ? .OK : .Error

                        if !availability.isUsernameAvailable {
                            let msg = NSLocalizedString("Username already exists.\nPlease try a new one.", comment: "username exists error message")
                            self.usernameView.setErrorMessage(msg)
                            if !availability.usernameSuggestions.isEmpty {
                                let suggestions = ", ".join(availability.usernameSuggestions)
                                let msg = String(format: NSLocalizedString("Here are some available usernames -\n%@", comment: "username suggestions message"), suggestions)
                                self.usernameView.setMessage(msg);
                            }
                        }
                        self.usernameView.setState(state)
                        self.updateView()
                    }, failure: { _, _ in
                        self.usernameView.setState(.None)
                        self.updateView()
                    })
                }
                self.updateView()
            }
        }

        emailView.label.setLabelText(NSLocalizedString("Email", comment: "email key"))
        emailView.textField.text = currentUser?.email
        emailView.textFieldDidChange = { text in
            self.valueChanged()
            self.emailView.setState(.Loading)
            self.validationCancel?()
            self.emailView.setErrorMessage("");
            self.updateView()

            self.validationCancel = Functional.cancelableDelay(0.5) {
                if text.isEmpty {
                    self.emailView.setState(.Error)
                } else if text == self.currentUser?.email {
                    self.emailView.setState(.None)
                } else if text.isValidEmail() {
                    AvailabilityService().emailAvailability(text, success: { availability in
                        if text != self.emailView.textField.text { return }
                        let state: ValidationState = availability.isEmailAvailable ? .OK : .Error

                        if !availability.isEmailAvailable {
                            let msg = NSLocalizedString("That email is invalid.\nPlease try again.", comment: "invalid email message")
                            self.emailView.setErrorMessage(msg)
                        }
                        self.emailView.setState(state)
                        self.updateView()
                    }, failure: { _, _ in
                        self.emailView.setState(.None)
                        self.updateView()
                    })
                } else {
                    self.emailView.setState(.Error)
                    let msg = NSLocalizedString("That email is invalid.\nPlease try again.", comment: "invalid email message")
                    self.emailView.setErrorMessage(msg)
                }
                self.updateView()
            }
        }

        passwordView.label.setLabelText(NSLocalizedString("Password", comment: "password key"))
        passwordView.textField.secureTextEntry = true
        passwordView.textFieldDidChange = { text in
            self.valueChanged()
            self.passwordView.setErrorMessage("")

            if text.isEmpty {
                self.passwordView.setState(.None)
            } else if text.isValidPassword() {
                self.passwordView.setState(.OK)
            } else {
                self.passwordView.setState(.Error)
                let msg = NSLocalizedString("Password must be at least 8\ncharacters long.", comment: "password length error message")
                self.passwordView.setErrorMessage(msg)
            }
            self.updateView()
        }
    }

    public func valueChanged() {
        delegate?.sensitiveSettingsDidUpdate()
    }

    func updateView() {
        self.tableView.beginUpdates()
        self.tableView.endUpdates()
        valueChanged()
    }

    override public func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        switch SensitiveSettingsRow(rawValue: indexPath.row) ?? .Unknown {
        case .Username: return usernameView.height
        case .Email: return emailView.height
        case .Password: return passwordView.height
        case .Submit: return SensitiveSettingsSubmitViewHeight
        case .Unknown: return 0
        }
    }
}

public extension SensitiveSettingsViewController {
    class func instantiateFromStoryboard() -> SensitiveSettingsViewController {
        return UIStoryboard(name: "Settings", bundle: NSBundle(forClass: AppDelegate.self)).instantiateViewControllerWithIdentifier("SensitiveSettingsViewController") as! SensitiveSettingsViewController
    }
}
