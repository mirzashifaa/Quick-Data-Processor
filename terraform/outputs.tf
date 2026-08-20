output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.qdp_users.id
}

output "cognito_client_id" {
  value = aws_cognito_user_pool_client.qdp_client.id
}

output "api_gateway_id" {
  value = aws_api_gateway_rest_api.qdp_api.id
}

output "sqs_queue_url" {
  value = aws_sqs_queue.data_processing_requests.url
}

output "sns_topic_arn" {
  value = aws_sns_topic.processing_notifications.arn
}
