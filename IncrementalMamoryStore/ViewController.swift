//
//  ViewController.swift
//  IncrementalMamoryStore
//
//  Created by Alexander Naumov on 08.10.2017.
//  Copyright © 2017 Alexander Naumov. All rights reserved.
//

import UIKit
import CoreData

class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(fetchUsers), name: .usersDidLoad, object: nil)
        fetchUsers()
    }
    @objc func fetchUsers() {
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        let context = CDContext.view
        context.perform {
            let result = try? context.fetch(request)
            result?.forEach {
                print("User name: \($0.name!)")
            }
        }
    }
}

