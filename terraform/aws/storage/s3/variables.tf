variable "client_name" {
  description = "The name of the client"
  type        = string
}

variable "s3_versioning" {
  description = "Enable versioning on the S3 bucket"
  type        = bool
  default     = false
}
