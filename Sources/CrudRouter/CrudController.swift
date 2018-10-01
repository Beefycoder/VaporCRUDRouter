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

    init(path: [PathComponentsRepresentable]) {
        let path
            = path.count == 0
                ? [String(describing: ModelType.self).snakeCased()! as PathComponentsRepresentable]
                : path

        self.path = path
    }

    /// Returns a parent controller, which retrieves models that are parents of ModelType
    ///
    /// - Parameter relation: Keypath from origin model to a Parent relation, which goes from origin model to
    /// - Returns: relation controller, which retrieves models in relation to ModelType
    public func crudRouterCollection<ParentType>(forParent relation: KeyPath<ModelType, Parent<ModelType, ParentType>>, at path: [PathComponentsRepresentable]) -> CrudParentController<ModelType, ParentType> where
        ParentType: Model & Content,
        ModelType.Database == ParentType.Database,
        ParentType.ID: Parameter {
            let baseIdPath = self.path.appending(ModelType.ID.parameter)

            return CrudParentController(relation: relation, basePath: baseIdPath, path: path)
    }
}

extension CrudController: RouteCollection {
    public func boot(router: Router) throws {

        let basePath = path
        let baseIdPath = path.appending(ModelType.ID.parameter)

        router.get(baseIdPath, use: self.index)
        router.get(basePath, use: self.indexAll)
        router.post(basePath, use: self.create)
        router.put(baseIdPath, use: self.update)
        router.delete(baseIdPath, use: self.delete)
    }
}
