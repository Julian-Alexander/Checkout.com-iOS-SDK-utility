//
//  CheckoutcomiOSSDKUtility.swift
//
//
//  Created by Julian-Alexander on 03/08/2024.
//

import UIKit
import CheckoutCardManagement

class CheckoutcomiOSSDKUtility: UIViewController {

    @IBOutlet weak var tokenTextField: UITextField!
    @IBOutlet weak var resultLabel: UILabel!
    @IBOutlet weak var actionButton: UIButton! // Single button for all actions
    @IBOutlet weak var cardInfoTextView: UITextView!
    @IBOutlet weak var newTokenTextField: UITextField!
    @IBOutlet weak var secureDisplayView: UIView! // Outlet for the secureDisplay view

    let cardManager: CheckoutCardManager
    var cards: [Card] = []
    var currentState: ButtonState = .login // Initial state

    enum ButtonState {
        case login
        case getPin
    }

    required init?(coder: NSCoder) {
        let designSystem = CardManagementDesignSystem(font: .systemFont(ofSize: 22), textColor: .blue)
        cardManager = CheckoutCardManager(designSystem: designSystem, environment: .sandbox)
        super.init(coder: coder)
        print("ViewController initialized")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        print("ViewController loaded")

        self.view.backgroundColor = .black

        resultLabel.textColor = .white
        cardInfoTextView.textColor = .white
        cardInfoTextView.backgroundColor = .black
        cardInfoTextView.isEditable = false // Make the text view read-only
        newTokenTextField.isHidden = true
        secureDisplayView.isHidden = true // Initially hide the secureDisplayView

        // Set button title and action for the initial state
        updateButton(for: .login)

        // Set placeholders
        tokenTextField.placeholder = "Add token here..."
        newTokenTextField.placeholder = "Enter new token here..."
    }

    func updateButton(for state: ButtonState) {
        currentState = state
        switch state {
        case .login:
            actionButton.setTitle("Login", for: .normal)
            actionButton.removeTarget(nil, action: nil, for: .allEvents)
            actionButton.addTarget(self, action: #selector(loginButtonTapped), for: .touchUpInside)
        case .getPin:
            actionButton.setTitle("Get PIN", for: .normal)
            actionButton.removeTarget(nil, action: nil, for: .allEvents)
            actionButton.addTarget(self, action: #selector(getPinButtonTapped), for: .touchUpInside)
        }
    }

    @objc func loginButtonTapped() {
        print("Login button tapped")
        guard let token = tokenTextField.text, !token.isEmpty else {
            resultLabel.text = "Please enter a token."
            print("No token entered")
            return
        }

        print("Logging in with token: \(token)")
        let success = cardManager.logInSession(token: token)
        if success {
            resultLabel.text = "Login successful!"
            print("Login successful with token: \(token)")
            fetchCards() // Fetch cards after successful login
        } else {
            resultLabel.text = "Login failed. Please check your token."
            print("Login failed with token: \(token)")
        }
    }

    func fetchCards() {
        print("Fetching cards...")
        cardManager.getCards { [weak self] result in
            switch result {
            case .success(let cards):
                guard !cards.isEmpty else {
                    DispatchQueue.main.async {
                        self?.resultLabel.text = "No cards available."
                    }
                    print("No cards available")
                    return
                }

                self?.cards = cards
                self?.displayCardInfoAsJSON()
                DispatchQueue.main.async {
                    self?.tokenTextField.isHidden = true // Hide the tokenTextField after successful card fetch
                    self?.newTokenTextField.isHidden = false
                    self?.updateButton(for: .getPin) // Update button to Get PIN
                }

            case .failure(let error):
                DispatchQueue.main.async {
                    self?.resultLabel.text = "Failed to fetch cards: \(error)"
                }
                print("Failed to fetch cards: \(error)")
            }
        }
    }

    func displayCardInfoAsJSON() {
        guard let firstCard = cards.first else { return }

        // Format the expiry date
        let expiryDate = "\(firstCard.expiryDate.month)/\(firstCard.expiryDate.year)"

        // Ensure all properties are JSON-serializable
        let cardInfo: [String: Any] = [
            "Card ID": firstCard.id,
            "Cardholder Name": firstCard.cardholderName,
            "Last 4 Digits": firstCard.panLast4Digits,
            "Expiry Date": expiryDate
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: cardInfo, options: .prettyPrinted)
            let jsonString = String(data: jsonData, encoding: .utf8)
            DispatchQueue.main.async {
                self.cardInfoTextView.text = jsonString
            }
            print("Card Info JSON: \(jsonString ?? "")")
        } catch {
            print("Failed to convert card info to JSON: \(error.localizedDescription)")
        }
    }

    @objc func getPinButtonTapped() {
        print("Get PIN button tapped")
        guard let newToken = newTokenTextField.text, !newToken.isEmpty else {
            resultLabel.text = "Please enter a new token."
            print("No new token entered")
            return
        }

        guard let firstCard = cards.first else {
            resultLabel.text = "No card available."
            print("No card available")
            return
        }

        getPin(for: firstCard, with: newToken)
    }

    func getPin(for card: Card, with token: String) {
        card.getPin(singleUseToken: token) { [weak self] result in
            switch result {
            case .success(let secureDisplay):
                DispatchQueue.main.async {
                    self?.resultLabel.text = "PIN fetched successfully"
                    self?.showSecureDisplay(secureDisplay) // Show the secureDisplay component
                }
                print("PIN fetched successfully")
            case .failure(let error):
                DispatchQueue.main.async {
                    self?.resultLabel.text = "Failed to fetch PIN: \(error)"
                }
                print("Failed to fetch PIN: \(error.localizedDescription)")
            }
        }
    }

    func showSecureDisplay(_ secureDisplay: UIView) {
        secureDisplayView.isHidden = false // Make the secureDisplayView visible
        secureDisplayView.addSubview(secureDisplay) // Add the secureDisplay component to the view
        secureDisplay.frame = secureDisplayView.bounds // Set the frame to match the container view
    }
}
