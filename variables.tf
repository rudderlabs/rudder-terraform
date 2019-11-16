
variable "region" {
  default = "us-east-1"
}

variable "prefix" {
  default = "rudder"
}

variable "ec2" {
  type = "map"

  default = {
    "ami"              = "ami-0cfee17793b08a293"
    "instance_type"    = "m4.2xlarge"
    "private_key_path" = "~/.ssh/id_rsa_tf"
  }
}
variable "s3_destination" {
  default = "rudder-client-s3-destination"
}

variable "main_route53_zone" {
  default = "dev.rudderlabs.com"
}
