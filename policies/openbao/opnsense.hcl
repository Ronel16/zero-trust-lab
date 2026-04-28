path "pki-int/issue/internal-services" {
  capabilities = ["create", "update"]
}
path "pki-int/ca/pem" {
  capabilities = ["read"]
}
path "pki-root/ca/pem" {
  capabilities = ["read"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}
