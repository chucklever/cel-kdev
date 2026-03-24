# Handshake events (handshake.h)

| Event | Key Fields | Use |
|-------|-----------|-----|
| handshake_submit | req, sk | TLS handshake submitted |
| handshake_complete | req, sk, status | TLS handshake completed |
| handshake_notify_err | req, sk, err | Handshake notification error |
| handshake_cancel | req, sk | Handshake cancelled |
| tls_contenttype | sk, type | TLS record content type |
| tls_alert_send | sk, level, description | TLS alert sent |
| tls_alert_recv | sk, level, description | TLS alert received |

Pairable: handshake_submit -> handshake_complete (by req pointer,
measures full TLS negotiation time).
