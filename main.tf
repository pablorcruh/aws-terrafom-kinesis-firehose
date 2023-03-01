#KINESIS DATA FIREHOSE DELIVERY STREAM
resource "aws_kinesis_firehose_delivery_stream" "extended_s3_stream" {
  name        = var.kinesis_firehose_stream_name
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn        = aws_iam_role.firehose_role.arn
    buffer_size     = 128
    buffer_interval = 900
    bucket_arn      = aws_s3_bucket.kinesis_firehose_stream_bucket.arn

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
          parameter_value = "{enterprise_id:.\"owner.enterprise.id\"}"
        }
      }

    }

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.kinesis_firehose_stream_logging_group.name
      log_stream_name = aws_cloudwatch_log_stream.kinesis_firehose_stream_logging_stream.name
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

# GLUE DATABASE
resource "aws_glue_catalog_database" "glue_catalog_database" {
  name = var.glue_catalog_database_name
}

# GLUE CATALOG TABLE
resource "aws_glue_catalog_table" "glue_catalog_table" {
  name          = var.glue_catalog_table_name
  database_name = aws_glue_catalog_database.glue_catalog_database.name

  parameters = {
    "classification" = "parquet"
  }

  partition_keys {
    name    = "owner.enterprise.id"
    type    = "string"
    comment = ""
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

    # TABLE SCHEMA
    columns {
      name    = "classifier.type"
      type    = "string"
      comment = "classifier details"
    }
    columns {
      name    = "classifier.version"
      type    = "string"
      comment = "classifier details"
    }
    columns {
      name    = "owner.enterprise.name"
      type    = "string"
      comment = "enterprise details"
    }
    columns {
      name    = "owner.agent.type"
      type    = "string"
      comment = "agent details"
    }
    columns {
      name    = "owner.user.id"
      type    = "string"
      comment = "station details"
    }
    columns {
      name    = "owner.user.name"
      type    = "string"
      comment = "station details"
    }
    columns {
      name    = "owner.user.name_short"
      type    = "string"
      comment = "station details"
    }
    columns {
      name    = "owner.area.id"
      type    = "string"
      comment = "area details"
    }
    columns {
      name    = "owner.area.name"
      type    = "string"
      comment = "area details"
    }
    columns {
      name    = "owner.area.name_short"
      type    = "string"
      comment = "area details"
    }
    columns {
      name    = "document.name"
      type    = "string"
      comment = "document details"
    }
    columns {
      name    = "document.path"
      type    = "string"
      comment = "document details"
    }
    columns {
      name    = "document.format"
      type    = "string"
      comment = "document details"
    }
    columns {
      name    = "document.modification_date"
      type    = "string"
      comment = "document details"
    }
    columns {
      name    = "document.metadata"
      type    = "string"
      comment = "document details"
    }
    columns {
      name    = "analysis.date_analysis"
      type    = "string"
      comment = "analysis details"
    }
    columns {
      name    = "analysis.classification.number"
      type    = "int"
      comment = "analysis details"
    }
    columns {
      name    = "analysis.classification.name"
      type    = "string"
      comment = "analysis details"
    }
    columns {
      name    = "analysis.personal_data"
      type    = "boolean"
      comment = "analysis details"
    }
    columns {
      name    = "analysis.credit_card"
      type    = "boolean"
      comment = "analysis details"
    }
    columns {
      name    = "analysis.ml_version"
      type    = "int"
      comment = "analysis details"
    }
    columns {
      name    = "analysis.metadata"
      type    = "string"
      comment = "analysis details"
    }

  }
}


# GLUE CRAWLER AND CONFIGURATION
resource "aws_glue_crawler" "kr-analysis_history-tb-crawler" {
  database_name = aws_glue_catalog_database.glue_catalog_database.name
  name          = var.glue_crawler
  role          = aws_iam_role.glue.arn

  catalog_target {
    database_name = aws_glue_catalog_database.glue_catalog_database.name
    tables        = [aws_glue_catalog_table.glue_catalog_table.name]
  }

  schema_change_policy {
    delete_behavior = "LOG"
  }

  configuration = <<EOF
{
  "Version":1.0,
  "Grouping": {
    "TableGroupingPolicy": "CombineCompatibleSchemas"
  }
}
EOF
}

# CLOUDWATCH LOG GROUP
resource "aws_cloudwatch_log_group" "kinesis_firehose_stream_logging_group" {
  name = "/aws/kinesisfirehose/${var.kinesis_firehose_stream_name}"
}

# CLOUDWATCH LOG STREAM
resource "aws_cloudwatch_log_stream" "kinesis_firehose_stream_logging_stream" {
  log_group_name = aws_cloudwatch_log_group.kinesis_firehose_stream_logging_group.name
  name           = "S3Delivery"
}

# TARGET S3 BUCKET
resource "aws_s3_bucket_acl" "bucket_acl" {
  bucket = aws_s3_bucket.kinesis_firehose_stream_bucket.id
  acl    = "private"
}


# IAM FIREHOSE ROLE
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


# KINESIS FIREHOSE POLICY
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

# IAM GLUE ROLE
resource "aws_iam_role" "glue" {
  name               = "AWSGlueServiceRoleDefault"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "glue.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# GLUE POLICY
data "aws_iam_policy_document" "access_glue_assume_policy" {
  statement {
    effect    = "Allow"
    actions   = ["glue:*"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "access_glue_policy" {
  name   = "access_glue_policy"
  role   = aws_iam_role.glue.name
  policy = data.aws_iam_policy_document.access_glue_assume_policy.json
}


