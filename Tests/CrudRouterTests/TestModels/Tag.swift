import FluentSQLite
import Vapor

struct Tag: SQLiteModel {
    var id: Int?
    var name: String
}

extension Tag {
    // all planets that have this tag
    var planets: Siblings<Tag, Planet, PlanetTag> {
        return siblings()
    }
}

extension Tag: Content { }
extension Tag: Migration { }
