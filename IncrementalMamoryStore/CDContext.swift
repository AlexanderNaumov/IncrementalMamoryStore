//
//  CDContext.swift
//  IncrementalMamoryStore
//
//  Created by Alexander Naumov on 08.10.2017.
//  Copyright © 2017 Alexander Naumov. All rights reserved.
//

import Foundation
import CoreData

typealias CDContext = NSManagedObjectContext

extension CDContext {
    
    private class PersistentStoreCoordinator: NSPersistentStoreCoordinator {
        
        static let `default` = PersistentStoreCoordinator()
        
        lazy var viewContext: CDContext = {
            let context = CDContext(concurrencyType: .mainQueueConcurrencyType)
            context.persistentStoreCoordinator = self
            return context
        }()
        
        var backgroundContext: CDContext {
            let context = CDContext(concurrencyType: .privateQueueConcurrencyType)
            context.parent = viewContext
            return context
        }
        
        init() {
            let url = Bundle.main.url(forResource: "DataModel", withExtension: "momd")!
            super.init(managedObjectModel: NSManagedObjectModel(contentsOf: url)!)
            
            NSPersistentStoreCoordinator.registerStoreClass(BackendStore.self, forStoreType: BackendStore.type)
            do {
                try addPersistentStore(ofType: BackendStore.type, configurationName: nil, at: URL(fileURLWithPath: ""), options: nil)
            } catch {
                fatalError(error.localizedDescription)
            }
        }
    }
    
    static var view: CDContext {
        return PersistentStoreCoordinator.default.viewContext
    }
    
    static var background: CDContext {
        return PersistentStoreCoordinator.default.backgroundContext
    }
    
}
