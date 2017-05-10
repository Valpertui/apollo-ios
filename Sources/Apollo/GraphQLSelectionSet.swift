public typealias Snapshot = [String: Any?]

public protocol GraphQLSelectionSet {
  static var selections: [Selection] { get }
  
  var snapshot: Snapshot { get }
  init(snapshot: Snapshot)
}

extension GraphQLSelectionSet {
  init(jsonObject: JSONObject, variables: GraphQLMap? = nil) throws {
    let executor = GraphQLExecutor { object, info in
      Promise(fulfilled: object[info.responseKeyForField])
    }
    self = try executor.execute(selections: Self.selections, on: jsonObject, withKey: "", variables: variables, accumulator: GraphQLSelectionSetMapper<Self>()).await()
  }
  
  func jsonObject(variables: GraphQLMap? = nil) throws -> JSONObject {
    let executor = GraphQLExecutor { object, info in
      Promise(fulfilled: object[info.responseKeyForField].jsonValue)
    }
    
    return try executor.execute(selections: Self.selections, on: snapshot.jsonObject, withKey: "", variables: variables, accumulator: GraphQLResponseGenerator()).await().jsonObject
  }
}

extension GraphQLSelectionSet {
  public init(_ selectionSet: GraphQLSelectionSet) throws {
    try self.init(jsonObject: try selectionSet.jsonObject())
  }
}

public protocol Selection {
}

public struct Field: Selection {
  let name: String
  let alias: String?
  let arguments: [String: GraphQLInputValue]?
  
  var responseKey: String {
    return alias ?? name
  }
  
  let type: GraphQLOutputType
  
  public init(_ name: String, alias: String? = nil, arguments: [String: GraphQLInputValue]? = nil, type: GraphQLOutputType) {
    self.name = name
    self.alias = alias
    
    self.arguments = arguments
    
    self.type = type
  }
  
  func cacheKey(with variables: [String: JSONEncodable]?) throws -> String {
    if let argumentValues = try arguments?.evaluate(with: variables), !argumentValues.isEmpty {
      let argumentsKey = orderIndependentKey(for: argumentValues)
      return "\(name)(\(argumentsKey))"
    } else {
      return name
    }
  }
}

private func orderIndependentKey(for object: JSONObject) -> String {
  return object.sorted { $0.key < $1.key }.map {
    if let object = $0.value as? JSONObject {
      return "[\($0.key):\(orderIndependentKey(for: object))]"
    } else {
      return "\($0.key):\($0.value)"
    }
  }.joined(separator: ",")
}

public struct FragmentSpread: Selection {
  let fragment: GraphQLFragment.Type
  
  public init(_ fragment: GraphQLFragment.Type) {
    self.fragment = fragment
  }
}
