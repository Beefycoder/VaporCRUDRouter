# CrudRouter

CrudRouter makes it as simple as possible to set up CRUD (Create, Read, Update, Delete) routes for any `Model`.

## Installation
Within your Package.swift

```swift
dependencies: [
    .package(url: "https://github.com/twof/VaporCRUDRouter.git", from: "1.0.0")
]
```
and

```swift
targets: [
    .target(name: "App", dependencies: ["CrudRouter"]),
]
```

## Usage
Within your router setup (`routes.swift` in the default Vapor API template)
```swift
router.crudRegister(for: Todo.self)
```
That's it!

That one line gets you the following routes.

```
GET /todo
GET /todo/:id
POST /todo
PUT /todo/:id
DELETE /todo/:id
```

Generated paths default to using lower snake case so for example, if you were to do

```swift
router.crudRegister(for: SchoolTeacher.self)
```
you'd get routes like

```
GET /school_teacher
GET /school_teacher/:id
POST /school_teacher
PUT /school_teacher/:id
DELETE /school_teacher/:id
```

#### Path Configuration
If you'd like to supply your own path rather than using the name of the supplied model, you can also do that

```swift
router.crudRegister("account", for: User.self)
```
results in

```
GET /account
GET /account/:id
POST /account
PUT /account/:id
DELETE /account/:id
```

#### Nested Relations
Say you had a model `User`, which was the parent of another model `Todo`. If you'd like routes to expose all `Todo`s that belong to a specific `User`, you can do something like this.

```swift
try router.crudRegister(for: User.self) { controller in
    try controller.crudRegister(forChildren: \.todos)
}
```

results in

```
GET /user
GET /user/:id
POST /user
PUT /user/:id
DELETE /user/:id

GET/user/:id/todo
GET /user/:id/todo/:id
POST/user/:id/todo
PUT/user/:id/todo/:id
DELETE/user/:id/todo/:id
```

within the supplied closure, you can also expose routes for related `Parent`s and `Sibling`s

```swift
try controller.crudRegister(forChildren: \.todos)
try controller.crudRegister(forParent: \.todos)
try controller.crudRegister(forSiblings: \.todos)
```

### Future features
- query parameter support
- PATCH support
- more fine grained response statuses
