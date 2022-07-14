import Config

config :pleroma, Pleroma.Web.Endpoint,
   url: [host: "social.$DOMAIN", scheme: "https", port: 443],
   http: [ip: {127, 0, 0, 1}, port: 4000]
   #secret_key_base: "",
   #signing_salt: ""

config :pleroma, :instance,
  name: "social.$DOMAIN",
  email: "$LUSER@$DOMAIN",
  notify_email: "$LUSER@$DOMAIN",
  limit: 5000,
  upload_limit: 1073741824,
  registrations_open: true

config :pleroma, :media_proxy,
  enabled: false,
  redirect_on_failure: true
  #base_url: "https://cache.pleroma.social"

config :pleroma, Pleroma.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "pleroma",
  database: "pleroma",
  socket_dir: "/run/postgresql",
  pool_size: 10

#config :web_push_encryption, :vapid_details,
  #subject: "",
  #public_key: "",
  #private_key: ""

config :pleroma, :database, rum_enabled: false
config :pleroma, :instance, static_dir: "/var/lib/pleroma/static"
config :pleroma, Pleroma.Uploaders.Local, uploads: "/var/lib/pleroma/uploads"

config :pleroma, :http_security,
  sts: true

#config :joken, default_signer: ""

config :pleroma, configurable_from_database: true
