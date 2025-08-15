env "local" {
  src = "file://database/schema.sql"
  url = getenv("RHEA_ATLAS_URL")
  dev = getenv("RHEA_ATLAS_DEV")
}
