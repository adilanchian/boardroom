import Foundation
import SwiftUI

// Simple UserManager singleton to manage the current user
class UserManager {
    static let shared = UserManager()
    
    var currentUser: User?
    private var dataService: DataService?
    
    private init() {
        // Initialize with DataService
        dataService = DataService()
        currentUser = dataService?.currentUser
        
        // Set up notification center to update user when it changes in DataService
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userChanged),
            name: NSNotification.Name("UserChanged"),
            object: nil
        )
    }
    
    @objc private func userChanged(_ notification: Notification) {
        if let newUser = notification.object as? User {
            currentUser = newUser
        } else if let dataService = dataService {
            currentUser = dataService.currentUser
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
} 