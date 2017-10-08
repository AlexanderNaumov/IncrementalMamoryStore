//
//  BackendStore.swift
//  IncrementalMamoryStore
//
//  Created by Alexander Naumov on 08.10.2017.
//  Copyright © 2017 Alexander Naumov. All rights reserved.
//

import Foundation
import CoreData

extension Notification.Name {
    static let usersDidLoad = Notification.Name("usersDidLoad")
}

class BackendStore: IncrementalMamoryStore {
    
    private var _metadata: [String : Any] = [NSStoreTypeKey: BackendStore.type, NSStoreUUIDKey: BackendStore.uuid]
    
    override var metadata: [String : Any]! {
        get { return _metadata }
        set { _metadata = newValue }
    }
    
    override func execute(_ request: NSPersistentStoreRequest, with context: NSManagedObjectContext?) throws -> Any {
        let result = try super.execute(request, with: context)
        if let fetchRequest = request as? NSFetchRequest<NSFetchRequestResult>,
            fetchRequest.entity!.name! == "User" && (result as? [Any])?.isEmpty ?? false {
            apiRequest { array in
                let context = CDContext.background
                context.perform {
                    array.forEach { dict in
                        let user = User(context: context)
                        user.name = dict["name"]
                    }
                    try? context.save()
                    try? CDContext.view.save()
                    NotificationCenter.default.post(name: .usersDidLoad, object: nil)
                }
            }
        }
        return result
    }
    
    private func apiRequest(completion: @escaping ([[String: String]]) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            completion([
                ["name": "User A"],
                ["name": "User B"],
                ["name": "User C"]
            ])
        }
    }
}
