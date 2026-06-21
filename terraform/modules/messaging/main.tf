resource "aws_sqs_queue" "donations" {
  name                      = "donations-events-queue"
  delay_seconds             = 0
  max_message_size          = 262144
  message_retention_seconds = 86400
  receive_wait_time_seconds = 10
}

resource "aws_dynamodb_table" "volunteers" {
  name           = "SolidaryTechVolunteers"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "volunteer_id"

  attribute {
    name = "volunteer_id"
    type = "S"
  }
}
