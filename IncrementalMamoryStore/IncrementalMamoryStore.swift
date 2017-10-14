//
//  IncrementalMamoryStore.swift
//  IncrementalMamoryStore
//
//  Created by Alexander Naumov on 08.10.2017.
//  Copyright © 2017 Alexander Naumov. All rights reserved.
//

import Foundation
import CoreData

class IncrementalMamoryStore: NSIncrementalStore {
    static var type: String {
        return String(describing: self)
    }
    
    internal static let uuid = UUID().uuidString
    
    private var _metadata: [String: Any] = [NSStoreUUIDKey: IncrementalMamoryStore.uuid, NSStoreTypeKey: IncrementalMamoryStore.type]
    
    override var metadata: [String : Any]! {
        get { return _metadata }
        set { _metadata = newValue }
    }
    
    override func loadMetadata() throws {}
    
    private var cache: [[String: Any]] = []
    
    override func execute(_ request: NSPersistentStoreRequest, with context: NSManagedObjectContext?) throws -> Any {
        switch request {
        case let fetchRequest as NSFetchRequest<NSFetchRequestResult>:
            switch fetchRequest.resultType {
            case .managedObjectResultType, .managedObjectIDResultType:
                var array = cache.filter { $0["entityName"] as! String == fetchRequest.entity!.name! }
                if let predicate = fetchRequest.predicate {
                    array = (array as NSArray).filtered(using: parse(predicate: predicate)) as! [[String: Any]]
                }
                if let sortDescriptors = fetchRequest.sortDescriptors  {
                    array = (array as NSArray).sortedArray(using: sortDescriptors) as! [[String: Any]]
                }
                return array.map { dict -> AnyObject in
                    let objectId = newObjectID(for: fetchRequest.entity!, referenceObject: dict["referenceId"]!)
                    return fetchRequest.resultType == .managedObjectIDResultType ? objectId : context!.object(with: objectId)
                }
            default:
                fatalError("Request Unsupported")
            }
        case let saveRequest as NSSaveChangesRequest:
            saveRequest.insertedObjects?.forEach { cache.append(dict(from: $0)) }
            saveRequest.updatedObjects?.forEach { object in
                if let index = cache.index(where: { $0["referenceId"] as! String == referenceObject(for: object.objectID) as! String }) {
                    cache.remove(at: index)
                    cache.insert(dict(from: object), at: index)
                }
            }
            saveRequest.deletedObjects?.forEach { object in
                if let index = cache.index(where: { $0["referenceId"] as! String == referenceObject(for: object.objectID) as! String }) {
                    cache.remove(at: index)
                }
            }
            return []
        default: break
        }
        return NSNull()
    }
    
    private func parse(predicate: NSPredicate) -> NSPredicate {
        let referenceId = { (object: Any) -> Any? in
            switch object {
            case let object as NSManagedObject:
                return self.referenceObject(for: object.objectID)
            case let array as [NSManagedObject]:
                return array.map { self.referenceObject(for: $0.objectID) }
            case let set as Set<NSManagedObject>:
                return set.map { self.referenceObject(for: $0.objectID) }
            case let objectId as NSManagedObjectID:
                return self.referenceObject(for: objectId)
            case let array as [NSManagedObjectID]:
                return array.map { self.referenceObject(for: $0) }
            case let set as Set<NSManagedObjectID>:
                return set.map { self.referenceObject(for: $0) }
            default:
                return nil
            }
        }
        guard let _predicate = predicate as? NSComparisonPredicate, _predicate.rightExpression.expressionType == .constantValue,
            let value = _predicate.rightExpression.constantValue.flatMap(referenceId) else { return predicate }
        return NSComparisonPredicate(
            leftExpression: _predicate.leftExpression.description == "SELF" ? NSExpression(forKeyPath: "referenceId") : _predicate.leftExpression,
            rightExpression: NSExpression(format: "%@", value as! CVarArg),
            modifier: _predicate.comparisonPredicateModifier,
            type: _predicate.predicateOperatorType,
            options: _predicate.options
        )
    }
    
    private func dict(from object: NSManagedObject) -> [String: Any] {
        var properties = object.entity.attributesByName.mapValues { (object.value(forKey: $0.name) ?? NSNull()) }
        let relationships = object.entity.relationshipsByName.mapValues { value -> Any in
            if let object = object.value(forKey: value.name) as? NSManagedObject {
                return referenceObject(for: object.objectID)
            } else if let objects = object.value(forKey: value.name) as? Set<NSManagedObject> {
                return Set(objects.map { referenceObject(for: $0.objectID) } as! [String])
            } else {
                return NSNull()
            }
        }
        relationships.forEach { properties[$0.key] = $0.value }
        properties["entityName"] = object.objectID.entity.name!
        properties["referenceId"] = referenceObject(for: object.objectID)
        return properties
    }
    
    override func obtainPermanentIDs(for array: [NSManagedObject]) throws -> [NSManagedObjectID] {
        return array.map { newObjectID(for: $0.entity, referenceObject: "ID-\(UUID().uuidString)") }
    }
    
    override func newValuesForObject(with objectID: NSManagedObjectID, with context: NSManagedObjectContext) throws -> NSIncrementalStoreNode {
        if let index = cache.index(where: { $0["referenceId"] as! String == referenceObject(for: objectID) as! String }) {
            let dict = cache[index]
            var properties =  objectID.entity.attributesByName.mapValues { dict[$0.name] ?? NSNull()}
            let relationships = try objectID.entity.relationshipsByName.filter { !$0.value.isToMany }.mapValues {
                try newValue(forRelationship: $0, forObjectWith: objectID, with: context)
            }
            relationships.forEach { properties[$0.key] = $0.value }
            return NSIncrementalStoreNode(objectID: objectID, withValues: properties, version: 1)
        } else {
            fatalError()
        }
    }
    
    override func newValue(forRelationship relationship: NSRelationshipDescription, forObjectWith objectID: NSManagedObjectID, with context: NSManagedObjectContext?) throws -> Any {
        if let index = cache.index(where: { $0["referenceId"] as! String == referenceObject(for: objectID) as! String }) {
            if let ids = cache[index][relationship.name] as? Set<String> {
                return ids.map { newObjectID(for: relationship.destinationEntity!, referenceObject: $0) }
            } else if let id = cache[index][relationship.name] as? String {
                return newObjectID(for: relationship.destinationEntity!, referenceObject: id)
            } else {
                return relationship.isToMany ? [] : NSNull()
            }
        } else {
            fatalError()
        }
    }
}
