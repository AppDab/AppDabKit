struct AnyEncodable: Encodable {
    let encodeValue: (any Encoder) throws -> Void

    init(_ value: some Encodable) {
        encodeValue = { encoder in
            try value.encode(to: encoder)
        }
    }

    func encode(to encoder: any Encoder) throws {
        try encodeValue(encoder)
    }
}
