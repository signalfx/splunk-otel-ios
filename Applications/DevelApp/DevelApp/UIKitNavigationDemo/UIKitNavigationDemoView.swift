//
/*
Copyright 2026 Splunk Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

import SwiftUI
import UIKit

// MARK: - SwiftUI entry point

/// Wraps a UINavigationController to exercise automated UIKit navigation detection.
struct UIKitNavigationDemoView: UIViewControllerRepresentable {

    func makeUIViewController(context _: Context) -> UINavigationController {
        UINavigationController(rootViewController: UIKitRootViewController())
    }

    func updateUIViewController(_: UINavigationController, context _: Context) {}
}


// MARK: - Root view controller

/// Landing screen inside the UIKit navigation controller.
///
/// Provides buttons to push child controllers and present modals.
class UIKitRootViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "UIKit Nav Demo"
        view.backgroundColor = .systemBackground
        view.accessibilityIdentifier = "uikitRootView"

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        let pushButton = UIButton(type: .system)
        pushButton.setTitle("Push Detail", for: .normal)
        pushButton.accessibilityIdentifier = "pushDetailButton"
        pushButton.addTarget(self, action: #selector(pushDetail), for: .touchUpInside)

        let presentButton = UIButton(type: .system)
        presentButton.setTitle("Present Modal", for: .normal)
        presentButton.accessibilityIdentifier = "presentModalButton"
        presentButton.addTarget(self, action: #selector(presentModal), for: .touchUpInside)

        let pushSecondButton = UIButton(type: .system)
        pushSecondButton.setTitle("Push Second", for: .normal)
        pushSecondButton.accessibilityIdentifier = "pushSecondButton"
        pushSecondButton.addTarget(self, action: #selector(pushSecond), for: .touchUpInside)

        stack.addArrangedSubview(pushButton)
        stack.addArrangedSubview(presentButton)
        stack.addArrangedSubview(pushSecondButton)

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    @objc private func pushDetail() {
        let detailVC = UIKitDetailViewController()
        navigationController?.pushViewController(detailVC, animated: true)
    }

    @objc private func presentModal() {
        let modalVC = UIKitModalViewController()
        modalVC.modalPresentationStyle = .pageSheet
        present(modalVC, animated: true)
    }

    @objc private func pushSecond() {
        let secondVC = UIKitSecondViewController()
        navigationController?.pushViewController(secondVC, animated: true)
    }
}


// MARK: - Detail view controller (push target)

class UIKitDetailViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Detail Screen"
        view.backgroundColor = .systemBackground
        view.accessibilityIdentifier = "uikitDetailView"

        let label = UILabel()
        label.text = "Pushed via UINavigationController"
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}


// MARK: - Second view controller (push target for multi-level nav)

class UIKitSecondViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Second Screen"
        view.backgroundColor = .systemBackground
        view.accessibilityIdentifier = "uikitSecondView"

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = "Second pushed controller"
        label.textAlignment = .center

        let presentButton = UIButton(type: .system)
        presentButton.setTitle("Present Modal From Here", for: .normal)
        presentButton.accessibilityIdentifier = "presentModalFromSecondButton"
        presentButton.addTarget(self, action: #selector(presentModal), for: .touchUpInside)

        stack.addArrangedSubview(label)
        stack.addArrangedSubview(presentButton)

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    @objc private func presentModal() {
        let modalVC = UIKitModalViewController()
        modalVC.modalPresentationStyle = .pageSheet
        present(modalVC, animated: true)
    }
}


// MARK: - Modal view controller (presentation target)

class UIKitModalViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Modal Screen"
        view.backgroundColor = .systemGroupedBackground
        view.accessibilityIdentifier = "uikitModalView"

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = "Presented modally"
        label.textAlignment = .center

        let dismissButton = UIButton(type: .system)
        dismissButton.setTitle("Dismiss", for: .normal)
        dismissButton.accessibilityIdentifier = "dismissModalButton"
        dismissButton.addTarget(self, action: #selector(dismissModal), for: .touchUpInside)

        stack.addArrangedSubview(label)
        stack.addArrangedSubview(dismissButton)

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    @objc private func dismissModal() {
        dismiss(animated: true)
    }
}
