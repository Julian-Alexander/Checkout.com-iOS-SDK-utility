//
//  CheckoutcomiOSSDKUtility.swift
//
//
//  Created by Julian-Alexander on 03/08/2024.
//

import UIKit
import CheckoutCardManagement

class CheckoutcomiOSSDKUtility: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var newTokenTextField: UITextField! // Use this text field for both inputs
    @IBOutlet weak var resultLabel: UILabel!
    @IBOutlet weak var actionButton: UIButton!
    @IBOutlet weak var cardInfoTextView: UITextView!
    @IBOutlet weak var secureDisplayView: UIView!
    @IBOutlet weak var tableView: UITableView! // Outlet for the table view
    @IBOutlet weak var infoLabel: UILabel! // Outlet for the info label

    let cardManager: CheckoutCardManager
    var cards: [Card] = []
    var selectedCard: Card?
    var currentState: ButtonState = .login

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

        setupUI()
        updateButton(for: .login)

        tableView.dataSource = self
        tableView.delegate = self

        // Register a basic UITableViewCell for use with the table view
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "CardCell")

        // Add a header view with a label to the table view
        addTableHeaderView()
    }

    // Setup initial UI properties
    private func setupUI() {
        self.view.backgroundColor = .black
        resultLabel.textColor = .white
        cardInfoTextView.textColor = .white
        cardInfoTextView.backgroundColor = .black
        cardInfoTextView.isEditable = false // Make the text view read-only
        secureDisplayView.isHidden = true // Initially hide the secureDisplayView
        tableView.isHidden = true // Initially hide the table view
        tableView.backgroundColor = .black // Set table view background color to black
        newTokenTextField.placeholder = "Enter token here..."
        infoLabel.isHidden = true // Initially hide the info label
        infoLabel.textColor = .white
        infoLabel.backgroundColor = .black
        infoLabel.textAlignment = .center
        infoLabel.font = UIFont.systemFont(ofSize: 16)
        infoLabel.numberOfLines = 0 // Allow the label to use as many lines as necessary
    }

    // Add a header view with a label to the table view
    private func addTableHeaderView() {
        let headerLabel = UILabel()
        headerLabel.text = "Select a card from the list below:"
        headerLabel.textColor = .white
        headerLabel.textAlignment = .center
        headerLabel.backgroundColor = .black
        headerLabel.font = UIFont.systemFont(ofSize: 16)
        headerLabel.numberOfLines = 0 // Allow the label to use as many lines as necessary
        headerLabel.frame.size.height = 50

        // Adjust the width to match the table view
        headerLabel.frame.size.width = tableView.frame.size.width

        // Set the tableHeaderView
        tableView.tableHeaderView = headerLabel
    }

    // Update button state and action
    private func updateButton(for state: ButtonState) {
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
        guard let token = newTokenTextField.text, !token.isEmpty else {
            updateResultLabel(with: "Please enter a token.")
            print("No token entered")
            return
        }

        print("Logging in with token: \(token)")
        let success = cardManager.logInSession(token: token)
        if success {
            updateResultLabel(with: "Login successful!")
            print("Login successful with token: \(token)")
            fetchCards() // Fetch cards after successful login
        } else {
            updateResultLabel(with: "Login failed. Please check your token.")
            print("Login failed with token: \(token)")
        }
    }

    func fetchCards() {
        print("Fetching cards...")
        cardManager.getCards { [weak self] result in
            switch result {
            case .success(let cards):
                guard !cards.isEmpty else {
                    self?.updateResultLabel(with: "No cards available.")
                    print("No cards available")
                    return
                }

                self?.cards = cards
                DispatchQueue.main.async {
                    self?.newTokenTextField.text = "" // Clear the text field
                    self?.newTokenTextField.placeholder = "Enter new token here..."
                    self?.updateButton(for: .getPin) // Update button to Get PIN
                    self?.tableView.reloadData() // Reload table view with cards
                    self?.tableView.isHidden = false // Show the table view
                    self?.infoLabel.text = "You can only get a PIN from a physical card. If using a virtual card, you will get an 'invalidRequestInput' error"
                    self?.infoLabel.isHidden = false // Show the info label

                    // Adjust the height of the label based on its content
                    self?.infoLabel.sizeToFit()
                }

            case .failure(let error):
                self?.updateResultLabel(with: "Failed to fetch cards: \(error)")
                print("Failed to fetch cards: \(error)")
            }
        }
    }

    @objc func getPinButtonTapped() {
        print("Get PIN button tapped")
        guard let newToken = newTokenTextField.text, !newToken.isEmpty else {
            updateResultLabel(with: "Please enter a new token.")
            print("No new token entered")
            return
        }

        guard let selectedCard = selectedCard else {
            updateResultLabel(with: "No card selected.")
            print("No card selected")
            return
        }

        getPin(for: selectedCard, with: newToken)
    }

    func getPin(for card: Card, with token: String) {
        card.getPin(singleUseToken: token) { [weak self] result in
            switch result {
            case .success(let secureDisplay):
                DispatchQueue.main.async {
                    self?.updateResultLabel(with: "PIN fetched successfully")
                    self?.showSecureDisplay(secureDisplay) // Show the secureDisplay component
                }
                print("PIN fetched successfully")
            case .failure(let error):
                self?.updateResultLabel(with: "Failed to fetch PIN: \(error)")
                print("Failed to fetch PIN: \(error.localizedDescription)")
            }
        }
    }

    func showSecureDisplay(_ secureDisplay: UIView) {
        secureDisplayView.isHidden = false // Make the secureDisplayView visible
        secureDisplayView.addSubview(secureDisplay) // Add the secureDisplay component to the view

        // Center the secureDisplay component within the secureDisplayView
        secureDisplay.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            secureDisplay.centerXAnchor.constraint(equalTo: secureDisplayView.centerXAnchor),
            secureDisplay.centerYAnchor.constraint(equalTo: secureDisplayView.centerYAnchor),
            secureDisplay.widthAnchor.constraint(equalTo: secureDisplayView.widthAnchor, multiplier: 0.8),
            secureDisplay.heightAnchor.constraint(equalTo: secureDisplayView.heightAnchor, multiplier: 0.8)
        ])
    }

    // Helper method to update result label text on main thread
    private func updateResultLabel(with text: String) {
        DispatchQueue.main.async {
            self.resultLabel.text = text
        }
    }

    // UITableViewDataSource methods
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cards.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CardCell", for: indexPath)
        let card = cards[indexPath.row]
        cell.textLabel?.text = "Card ID: \(card.id), Last 4 Digits: \(card.panLast4Digits)"
        cell.textLabel?.textColor = .white // Set text color to white
        cell.backgroundColor = .black // Set cell background color to black
        return cell
    }

    // UITableViewDelegate methods
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedCard = cards[indexPath.row]
        displayCardInfoAsJSON(for: selectedCard)
    }

    // Display card info as JSON in the text view for the selected card
    private func displayCardInfoAsJSON(for card: Card?) {
        guard let card = card else { return }

        let cardInfo: [String: Any] = [
            "Card ID": card.id,
            "Cardholder Name": card.cardholderName,
            "Last 4 Digits": card.panLast4Digits,
            "Expiry Date": "\(card.expiryDate.month)/\(card.expiryDate.year)"
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: cardInfo, options: .prettyPrinted)
            let jsonString = String(data: jsonData, encoding: .utf8)
            updateCardInfoTextView(with: jsonString)
            print("Card Info JSON: \(jsonString ?? "")")
        } catch {
            print("Failed to convert card info to JSON: \(error.localizedDescription)")
        }
    }

    // Helper method to update card info text view on main thread
    private func updateCardInfoTextView(with text: String?) {
        DispatchQueue.main.async {
            self.cardInfoTextView.text = text
        }
    }
}
