variable "bucket_name" {
  description = "Name of the S3 bucket. Must be Unique across AWS"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "glue_catalog_database_name" {
  description = "The Glue catalog database name"
  type        = string
}

variable "glue_catalog_table_name" {
  description = "The Glue catalog database table name"
  type        = string
}

variable "kinesis_firehose_stream_name" {
  description = "Stream name Firehose"
  type        = string
}

variable "glue_crawler" {
  description = "Crawler name"
  type        = string
}

variable "glue_catalog_table_columns" {
  description = "A list of table columns"
  type = map(object({
    name = string
    type = string
  }))
  default = {
    "type" = {
      name = "value_1"
      type = "value_2"
    }
  }
}
