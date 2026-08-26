;; Guix manifest for chess-lisp-zero Tauri shell build.
;; Minimal reproducible environment for Linux structure/build checks.
;;
;; Usage:
;;   guix shell -m manifest.scm
;;   export SSL_CERT_DIR="$GUIX_ENVIRONMENT/etc/ssl/certs"
;;   cargo check

(specifications->manifest
 '("rust"
   "rust:cargo"
   "nss-certs"
   "pkg-config"
   "webkitgtk-for-gtk3"
   "gtk+"
   "libappindicator"))
