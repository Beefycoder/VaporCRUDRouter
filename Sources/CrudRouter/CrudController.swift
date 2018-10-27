import Vapor
import Fluent

public struct CrudController<ModelT: Model & Content>: CrudControllerProtocol where ModelT.ID: Parameter {
    public typealias ModelType = ModelT

    let path: [PathComponentsRepresentable]
    let router: Router
    let activeMethods: Set<RouterMethod>

    init(path: [PathComponentsRepresentable], router: Router, activeMethods: Set<RouterMethod>) {
        let adjustedPath = path.adjustedPath(for: ModelType.self)

        self.path = adjustedPath
        self.router = router
        self.activeMethods = activeMethods
    }
}

extension CrudController {
    public func crud<ParentType>(
        at path: PathComponentsRepresentable...,
        parent relation: KeyPath<ModelType, Parent<ModelType, ParentType>>,
        _ either: OnlyExceptEither<ParentRouterMethod> = .only([.read, .update]),
        relationConfiguration: ((CrudParentController<ModelType, ParentType>) throws -> Void)?=nil
    ) throws where
        ParentType: Model & Content,
        ModelType.Database == ParentType.Database,
        ParentType.ID: Parameter {
            let baseIdPath = self.path.appending(ModelType.ID.parameter)
            let adjustedPath = path.adjustedPath(for: ParentType.self)

            let fullPath = baseIdPath.appending(adjustedPath)

            let allMethods: Set<ParentRouterMethod> = Set([.read, .update])
            let controller: CrudParentController<ModelType, ParentType>

            switch either {
            case .only(let methods):
                controller = CrudParentController(relation: relation, path: fullPath, router: self.router, activeMethods: Set(methods))
            case .except(let methods):
                controller = CrudParentController(relation: relation, path: fullPath, router: self.router, activeMethods: allMethods.subtracting(Set(methods)))
            }

            try controller.boot(router: self.router)

            try relationConfiguration?(controller)
    }
}


// MARK: ChildController methods
extension CrudController {
    public func crud<ChildType>(
        at path: PathComponentsRepresentable...,
        children relation: KeyPath<ModelType, Children<ModelType, ChildType>>,
        _ either: OnlyExceptEither<ChildrenRouterMethod> = .only([.read, .readAll, .create, .update, .delete]),
        relationConfiguration: ((CrudChildrenController<ChildType, ModelType>) throws -> Void)?=nil
    ) throws where
        ChildType: Model & Content,
        ModelType.Database == ChildType.Database,
        ChildType.ID: Parameter {
            let baseIdPath = self.path.appending(ModelType.ID.parameter)
            let adjustedPath = path.adjustedPath(for: ChildType.self)

            let fullPath = baseIdPath.appending(adjustedPath)

            let allMethods: Set<ChildrenRouterMethod> = Set([.read, .update])
            let controller: CrudChildrenController<ChildType, ModelType>

            switch either {
            case .only(let methods):
                controller = CrudChildrenController(childrenRelation: relation, path: fullPath, router: self.router, activeMethods: Set(methods))
            case .except(let methods):
                controller = CrudChildrenController(childrenRelation: relation, path: fullPath, router: self.router, activeMethods: allMethods.subtracting(Set(methods)))
            }

            try controller.boot(router: self.router)

            try relationConfiguration?(controller)
    }
}

// MARK: SiblingController methods
public extension CrudController {
    public func crud<ChildType, ThroughType>(
        at path: PathComponentsRepresentable...,
        siblings relation: KeyPath<ModelType, Siblings<ModelType, ChildType, ThroughType>>,
        _ either: OnlyExceptEither<ModifiableSiblingRouterMethod> = .only([.read, .readAll, .create, .update, .delete]),
        relationConfiguration: ((CrudSiblingsController<ChildType, ModelType, ThroughType>) throws -> Void)?=nil
    ) throws where
        ChildType: Content,
        ModelType.Database == ThroughType.Database,
        ChildType.ID: Parameter,
        ThroughType: ModifiablePivot,
        ThroughType.Database: JoinSupporting,
        ThroughType.Database == ChildType.Database,
        ThroughType.Left == ModelType,
        ThroughType.Right == ChildType {
            let baseIdPath = self.path.appending(ModelType.ID.parameter)
            let adjustedPath = path.adjustedPath(for: ChildType.self)

            let fullPath = baseIdPath.appending(adjustedPath)

            let allMethods: Set<ModifiableSiblingRouterMethod> = Set([.read, .readAll, .create, .update, .delete])
            let controller: CrudSiblingsController<ChildType, ModelType, ThroughType>

            switch either {
            case .only(let methods):
                controller = CrudSiblingsController(siblingRelation: relation, path: fullPath, router: self.router, activeMethods: Set(methods))
            case .except(let methods):
                controller = CrudSiblingsController(siblingRelation: relation, path: fullPath, router: self.router, activeMethods: allMethods.subtracting(Set(methods)))
            }

            try controller.boot(router: self.router)

            try relationConfiguration?(controller)
    }

    public func crud<ChildType, ThroughType>(
        at path: PathComponentsRepresentable...,
        siblings relation: KeyPath<ModelType, Siblings<ModelType, ChildType, ThroughType>>,
        _ either: OnlyExceptEither<ModifiableSiblingRouterMethod> = .only([.read, .readAll, .create, .update, .delete]),
        relationConfiguration: ((CrudSiblingsController<ChildType, ModelType, ThroughType>) throws -> Void)?=nil
    ) throws where
        ChildType: Content,
        ModelType.Database == ThroughType.Database,
        ChildType.ID: Parameter,
        ThroughType: ModifiablePivot,
        ThroughType.Database: JoinSupporting,
        ThroughType.Database == ChildType.Database,
        ThroughType.Right == ModelType,
        ThroughType.Left == ChildType {
            let baseIdPath = self.path.appending(ModelType.ID.parameter)
            let adjustedPath = path.adjustedPath(for: ChildType.self)

            let fullPath = baseIdPath.appending(adjustedPath)

            let allMethods: Set<ModifiableSiblingRouterMethod> = Set([.read, .readAll, .create, .update, .delete])
            let controller: CrudSiblingsController<ChildType, ModelType, ThroughType>

            switch either {
            case .only(let methods):
                controller = CrudSiblingsController(siblingRelation: relation, path: fullPath, router: self.router, activeMethods: Set(methods))
            case .except(let methods):
                controller = CrudSiblingsController(siblingRelation: relation, path: fullPath, router: self.router, activeMethods: allMethods.subtracting(Set(methods)))
            }

            try controller.boot(router: self.router)

            try relationConfiguration?(controller)
    }
}

extension CrudController: RouteCollection {
    public func boot(router: Router) throws {
        let basePath = self.path
        let baseIdPath = self.path.appending(ModelType.ID.parameter)

        self.activeMethods.forEach {
            $0.register(
                router: router,
                controller: self,
                path: basePath,
                idPath: baseIdPath
            )
        }
    }
}
