
variable "region" {
  default = "us-east-1"
}

variable "prefix" {
  default = "rudders"
}

variable "ec2" {
  type = "map"

  default = {
    "ami"              = "ami-0cfee17793b08a293"
    "instance_type"    = "t2.micro"
    "private_key_path" = "~/.ssh/id_rsa_tf"
  }
}
variable "s3_destination" {
  default = "sum-rudder-client-s3-destination"
}

variable "custom_vpc" {
  type = "map"

  default = {
    vpc_id    = ""
    subnet_id = ""
  }
}
