provider "aws" {
  version = "~> 2.0"
  profile = "rudder-dev"
  region  = "us-east-1"
}

resource "aws_key_pair" "deployer" {
  key_name   = "${var.prefix}_rudder_deployer"
  public_key = "${file("${var.ec2.private_key_path}.pub")}"
}

resource "aws_security_group" "allow_ssh" {
  name        = "${var.prefix}_allow_ssh"
  description = "Allow SSH inbound traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "allow_server" {
  name        = "${var.prefix}_allow_server"
  description = "Allow SSH inbound traffic"

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "rudder" {
  ami                  = "${var.ec2.ami}"
  instance_type        = "${var.ec2.instance_type}"
  key_name             = "${aws_key_pair.deployer.key_name}"
  iam_instance_profile = "${aws_iam_instance_profile.ec2_profile.id}"

  tags = {
    Name = "rudder"
  }
  vpc_security_group_ids = [
    "${aws_security_group.allow_ssh.id}",
    "${aws_security_group.allow_server.id}"
  ]

  connection {
    host        = "${self.public_ip}"
    type        = "ssh"
    user        = "ubuntu"
    password    = ""
    private_key = "${file("${var.ec2.private_key_path}")}"
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p /home/ubuntu/rudder-server",
      "mkdir -p /home/ubuntu/rudder-transformer",
      "mkdir -p /home/ubuntu/s3",
      "chown -R ubuntu:ubuntu /home/ubuntu/s3",
      "chmod 777 /home/ubuntu/s3"
    ]
  }

  provisioner "file" {
    source      = "./rudder-server"
    destination = "/home/ubuntu/rudder-server/rudder-server"
  }

  provisioner "file" {
    source      = "./dataplane.env"
    destination = "/home/ubuntu/rudder-server/.env"
  }

  provisioner "file" {
    source      = "./config.toml"
    destination = "/home/ubuntu/rudder-server/config.toml"
  }

  provisioner "file" {
    source      = "./rudder-transformer.zip"
    destination = "/home/ubuntu/rudder-transformer/rudder-transformer.zip"
  }

  provisioner "file" {
    source      = "./rudder.service"
    destination = "/home/ubuntu/rudder.service"
  }
  provisioner "file" {
    source      = "./dest-transformer.service"
    destination = "/home/ubuntu/dest-transformer.service"
  }

  provisioner "file" {
    source      = "./install.sh"
    destination = "/home/ubuntu/install.sh"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo bash /home/ubuntu/install.sh",
      "sudo cp /home/ubuntu/*.service /etc/systemd/system/",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable rudder",
      "sudo systemctl enable dest-transformer",
      "cd /home/ubuntu/rudder-transformer",
      "unzip rudder-transformer.zip",
      "npm install",
      "chmod +x /home/ubuntu/rudder-server/rudder-server",
      "sudo systemctl restart dest-transformer",
      "sudo systemctl restart rudder"
    ]
  }
}
