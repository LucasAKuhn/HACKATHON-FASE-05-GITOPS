output "postgres_host" {
  value = split(":", aws_db_instance.postgres.endpoint)[0]
}
