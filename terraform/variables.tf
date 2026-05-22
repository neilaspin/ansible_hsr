variable "aws_region" {
  default = "us-east-2"
}

variable "key_pair_name" {
  default = "<your-key-pair-name>"
}

variable "hana_media_bucket" {
  default = "<your-s3-bucket-name>"
}

variable "private_zone_name" {
  default = "hana.internal"
}
