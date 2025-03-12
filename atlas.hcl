env "local" {
  src = "file://schema.sql"
  url = getenv("SFS_ATLAS_URL")
  dev = getenv("SFS_ATLAS_DEV")
}
