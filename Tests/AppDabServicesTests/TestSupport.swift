import ConnectAccounts

let previewPrivateKey = """
-----BEGIN PRIVATE KEY-----
MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQghF6o5u7ft0FanWFm
LKQn9bjdI9x+EutHAjA0wDfDkgShRANCAATpj+9nvBg4ipcHGSY/xqrJi8VE2qNb
vZh9AwQzLqwcZOne8kuNMeyAtJAF1S4vNhCWqbvh1hd6nZydA8I7NHNA
-----END PRIVATE KEY-----
"""

func previewAPIKey() throws -> APIKey {
    try .init(
        name: "Preview",
        keyId: "AAAAAAAAAA",
        issuerId: "00000000-0000-0000-0000-000000000000",
        privateKey: previewPrivateKey
    )
}
