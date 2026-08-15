# TLS via ACM + nip.io (Bonus 5.2)

**Domain:** https://98-81-57-231.nip.io

**Approach:** ACM's standard DNS validation requires a CNAME record proving
domain ownership. Since nip.io is a shared public wildcard DNS service not
owned by this project, DNS validation isn't possible. Instead, a self-signed
certificate was generated locally and imported into ACM via
`aws acm import-certificate`, which produces a normal ACM ARN usable with
the ALB the same way as a CA-issued cert.

**Certificate ARN:** arn:aws:acm:us-east-1:930804195409:certificate/90de96b6-872a-45b5-ab8b-734fd6ed5701

**Verified:**
- HTTP (port 80) returns 301 redirect to HTTPS (port 443)
- HTTPS returns 200 OK, store loads correctly in browser
- Browser shows a certificate warning ("Not secure") because the cert is
  self-signed rather than CA-trusted — expected given the nip.io constraint

**Ingress annotations added:**
- alb.ingress.kubernetes.io/certificate-arn
- alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80},{"HTTPS":443}]'
- alb.ingress.kubernetes.io/ssl-redirect: '443'
