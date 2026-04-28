# policies/openbao/authentik.hcl
#
# OpenBao policy for the Authentik service account.
# Authentik needs to read secrets and issue certificates via the PKI engine.
#
# Reference: NIST SP 800-207 - Least Privilege (PE2)
# Mapping: CIS Controls v8 - Control 5.4 (Restrict Administrator Privileges)

# Read OIDC provider configuration secrets
path "secret/data/authentik/*" {
  capabilities = ["read"]
}

# Issue certificates from the intermediate CA for Authentik's HTTPS endpoint
path "pki-int/issue/internal-services" {
  capabilities = ["create", "update"]
}

# Read the CA certificate chain (for mTLS client verification)
path "pki-int/ca/pem" {
  capabilities = ["read"]
}

path "pki-root/ca/pem" {
  capabilities = ["read"]
}

# Renew own token
path "auth/token/renew-self" {
  capabilities = ["update"]
}

# Lookup own token metadata
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
