import Vapor
import Fluent

public protocol CrudControllerProtocol {
    associatedtype ModelType: Model, Content where ModelType.ID: Parameter
    func indexAll(_ req: Request) throws -> Future<[ModelType]>
    func index(_ req: Request) throws -> Future<ModelType>
    func update(_ req: Request) throws -> Future<ModelType>
    func create(_ req: Request) throws -> Future<ModelType>
    func delete(_ req: Request) throws -> Future<HTTPStatus>
}

public extension CrudControllerProtocol {
    func indexAll(_ req: Request) throws -> Future<[ModelType]> {
        return ModelType.query(on: req).all().map { Array($0) }
    }

    func index(_ req: Request) throws -> Future<ModelType> {
        let id: ModelType.ID = try getId(from: req)
        return ModelType.find(id, on: req).unwrap(or: Abort(.notFound))
    }

    func create(_ req: Request) throws -> Future<ModelType> {
        return try req.content.decode(ModelType.self).flatMap { model in
            return model.save(on: req)
        }
    }

    func update(_ req: Request) throws -> Future<ModelType> {
        let id: ModelType.ID = try getId(from: req)
        return try req.content.decode(ModelType.self).flatMap { model in
            var temp = model
            temp.fluentID = id
            return temp.update(on: req)
        }
    }

    func delete(_ req: Request) throws -> Future<HTTPStatus> {
        let id: ModelType.ID = try getId(from: req)
        return ModelType
            .find(id, on: req)
            .unwrap(or: Abort(.notFound))
            .flatMap { model in
                return model.delete(on: req).transform(to: HTTPStatus.ok)
        }
    }
}

fileprivate extension CrudControllerProtocol {
    func getId<T: ID>(from req: Request) throws -> T {
        guard let id = try req.parameters.next(ModelType.ID.self) as? T else { fatalError() }

        return id
    }
}

public struct CrudController<ModelT: Model & Content>: CrudControllerProtocol where ModelT.ID: Parameter {
    public typealias ModelType = ModelT

    let path: [PathComponentsRepresentable]
    let router: Router
    let activeMethods: Set<RouterMethods>

    init(path: [PathComponentsRepresentable], router: Router, activeMethods: Set<RouterMethods>) {
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
        relationConfiguration: ((CrudParentController<ModelType, ParentType>) throws -> Void)?=nil
    ) throws where
        ParentType: Model & Content,
        ModelType.Database == ParentType.Database,
        ParentType.ID: Parameter {
            let baseIdPath = self.path.appending(ModelType.ID.parameter)

            let controller = CrudParentController(relation: relation, basePath: baseIdPath, path: path)

            try controller.boot(router: self.router)
    }
}


// MARK: ChildController methods
extension CrudController {
    public func crud<ChildType>(
        at path: PathComponentsRepresentable...,
        children relation: KeyPath<ModelType, Children<ModelType, ChildType>>,
        useMethods: [ChildrenRouterMethods] = [.read, .readAll, .create, .update, .delete],
        relationConfiguration: ((CrudChildrenController<ChildType, ModelType>) throws -> Void)?=nil
    ) throws where
        ChildType: Model & Content,
        ModelType.Database == ChildType.Database,
        ChildType.ID: Parameter {
            let baseIdPath = self.path.appending(ModelType.ID.parameter)

            let controller = CrudChildrenController(childrenRelation: relation, basePath: baseIdPath, path: path, activeMethods: Set(useMethods))

            try controller.boot(router: self.router)
    }
}

// MARK: SiblingController methods
public extension CrudController {
    public func crud<ChildType, ThroughType>(
        at path: PathComponentsRepresentable...,
        siblings relation: KeyPath<ModelType, Siblings<ModelType, ChildType, ThroughType>>,
        useMethods: [ModifiableSiblingRouterMethods] = [.read, .readAll, .create, .update, .delete],
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

            let controller = CrudSiblingsController(siblingRelation: relation, basePath: baseIdPath, path: path)

            try controller.boot(router: self.router)
    }

    public func crud<ChildType, ThroughType>(
        at path: PathComponentsRepresentable...,
        siblings relation: KeyPath<ModelType, Siblings<ModelType, ChildType, ThroughType>>,
        useMethods: [ModifiableSiblingRouterMethods] = [.read, .readAll, .create, .update, .delete],
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

            let controller = CrudSiblingsController(siblingRelation: relation, basePath: baseIdPath, path: path)

            try controller.boot(router: self.router)
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
