# Indigo Vaulting Stoat

A concise guide to TLS handshakes, certificate chains, and common misconfiguration pitfalls.

## TLS Handshake (1.3)

Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nunc porta vulputate tellus. Nunc rutrum turpis sed pede.

```
Client                          Server
  |------ ClientHello ----------->|
  |<----- ServerHello ------------|
  |<----- {Certificate} ----------|
  |<----- {CertificateVerify} ----|
  |<----- {Finished} -------------|
  |------ {Finished} ------------>|
  |====== Application Data ======|
```

TLS 1.3 completes in one round trip, down from two in TLS 1.2.

## Certificate Chain

A certificate is trusted if it chains to a root CA in the trust store:

```
Root CA (self-signed, in trust store)
  └── Intermediate CA
        └── Leaf certificate (your domain)
```

Serving the full chain — leaf + intermediates — is required. Browsers cache intermediates; other clients often do not.

## Common Pitfalls

| Issue | Symptom | Fix |
|-------|---------|-----|
| Missing intermediate | Works in browser, fails in curl | Serve full chain |
| Expired cert | Handshake failure | Renew; automate with ACME |
| Wrong CN/SANs | Name mismatch error | Include all hostnames in SANs |
| Weak cipher suites | Downgrade attacks | Disable RC4, 3DES, export ciphers |
| HSTS not set | Downgrade possible | Add `Strict-Transport-Security` header |

## Certificate Transparency

Pellentesque ut neque. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas.

All publicly trusted CAs must log certificates to CT logs. This enables detection of mis-issuance and allows domain owners to monitor for unexpected certificates via services like crt.sh.
