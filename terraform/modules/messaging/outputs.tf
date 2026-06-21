output "sqs_url" {
  value = aws_sqs_queue.donations.id
}

output "dynamodb_table" {
  value = aws_dynamodb_table.volunteers.name
}
