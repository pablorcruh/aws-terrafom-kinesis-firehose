resource "aws_kinesis_firehose_delivery_stream" "extended_s3_stream" {
  name        = "terraform-kinesis-firehose-extended-s3-stream"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn    = aws_iam_role.firehose_role.arn
    buffer_size = 128
    bucket_arn  = aws_s3_bucket.kinesis_firehose_stream_bucket.arn

    dynamic_partitioning_configuration {
      enabled = "true"
    }

    # Example prefix using partitionKeyFromQuery, applicable to JQ processor
    prefix              = "data/enterprise_id=!{partitionKeyFromQuery:enterprise_id}/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/"
    error_output_prefix = "errors/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/!{firehose:error-output-type}/"


    processing_configuration {
      enabled = "true"

      processors {
        type = "MetadataExtraction"
        parameters {
          parameter_name  = "JsonParsingEngine"
          parameter_value = "JQ-1.6"
        }
        parameters {
          parameter_name  = "MetadataExtractionQuery"
          parameter_value = "{enterprise_id:.enterprise_id}"
        }
      }

    }

    data_format_conversion_configuration {
      input_format_configuration {
        deserializer {
          hive_json_ser_de {}
        }
      }

      output_format_configuration {
        serializer {
          parquet_ser_de {}
        }
      }

      schema_configuration {
        database_name = aws_glue_catalog_database.glue_catalog_database.name
        table_name    = aws_glue_catalog_table.glue_catalog_table.name
        role_arn      = aws_iam_role.firehose_role.arn
      }
    }
  }
}

resource "aws_s3_bucket" "kinesis_firehose_stream_bucket" {
  bucket        = var.bucket_name
  force_destroy = "true"
}


resource "aws_glue_catalog_database" "glue_catalog_database" {
  name = var.glue_catalog_database_name
}

resource "aws_glue_catalog_table" "glue_catalog_table" {
  name          = var.glue_catalog_table_name
  database_name = aws_glue_catalog_database.glue_catalog_database.name

  parameters = {
    "classification" = "parquet"
  }

  storage_descriptor {
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"
    location      = "s3://${aws_s3_bucket.kinesis_firehose_stream_bucket.bucket}/"

    ser_de_info {
      name                  = "JsonSerDe"
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"

      parameters = {
        "serialization.format" = 1
        "explicit.null"        = false
        "parquet.compression"  = "SNAPPY"
      }
    }

    dynamic "columns" {
      for_each = var.glue_catalog_table_columns
      content {
        name = columns.value["name"]
        type = columns.value["type"]
      }
    }
  }
}


resource "aws_s3_bucket_acl" "bucket_acl" {
  bucket = aws_s3_bucket.kinesis_firehose_stream_bucket.id
  acl    = "private"
}

resource "aws_iam_role" "firehose_role" {
  name = "firehose_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "firehose.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "kinesis_firehose_access_glue_policy" {
  name   = "kinesis_firehose_access_glue_policy"
  role   = aws_iam_role.firehose_role.name
  policy = data.aws_iam_policy_document.kinesis_firehose_access_glue_assume_policy.json
}

data "aws_iam_policy_document" "kinesis_firehose_access_glue_assume_policy" {
  statement {
    effect    = "Allow"
    actions   = ["glue:GetTableVersions"]
    resources = ["*"]
  }
}


