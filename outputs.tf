output "stream" {
  description = "name stream"
  value       = aws_kinesis_firehose_delivery_stream.extended_s3_stream.name
}


output "arn" {
  description = "stream arn"
  value       = aws_kinesis_firehose_delivery_stream.extended_s3_stream.arn
}

output "bucket" {
  description = "bucket arn"
  value       = aws_s3_bucket.kinesis_firehose_stream_bucket.arn
}

output "catalog" {
  description = "Glue catalog database name"
  value       = aws_glue_catalog_database.glue_catalog_database.name
}

output "table" {
  description = "Glue catalog table name"
  value       = aws_glue_catalog_table.glue_catalog_table.name
}





