data "aws_vpc" "selected" {
  default = true
}

data "aws_subnet_ids" "list" {
  vpc_id = "${data.aws_vpc.selected.id}"
}

data "aws_acm_certificate" "domain" {
  domain = "*.${var.main_route53_zone}"
}

data "aws_route53_zone" "rudder" {
  name = "${var.main_route53_zone}."
}


resource "aws_ami_from_instance" "rudder" {
  name               = "rudder-ami"
  source_instance_id = "${aws_instance.rudder.id}"
}

resource "aws_launch_template" "rudder" {
  name_prefix   = "${var.prefix}_rudder"
  image_id      = "${aws_ami_from_instance.rudder.id}"
  instance_type = "${var.ec2.instance_type}"
  vpc_security_group_ids = [
    "${aws_security_group.allow_ssh.id}",
    "${aws_security_group.allow_server.id}"
  ]
}

resource "aws_autoscaling_group" "rudder" {
  availability_zones = ["us-east-1b"]
  desired_capacity   = 1
  max_size           = 1
  min_size           = 1
  name_prefix        = "rudder-ha"
  target_group_arns  = ["${aws_alb_target_group.rudder_target_group.id}"]

  launch_template {
    id      = "${aws_launch_template.rudder.id}"
    version = "$Latest"
  }
}

resource "aws_security_group" "allow_https" {
  name        = "rudder_allow_https"
  description = "Allow load balancer traffic"

  ingress {
    from_port   = 443
    to_port     = 443
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

resource "aws_alb" "rudder_public" {
  name            = "rudder-backend-alb"
  security_groups = ["${aws_security_group.allow_https.id}"]
  subnets         = "${data.aws_subnet_ids.list.ids}"
}

resource "aws_alb_target_group" "rudder_target_group" {
  name     = "rudder-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = "${data.aws_vpc.selected.id}"
  health_check {
    path = "/health"
    port = 8080
  }
}

resource "aws_alb_listener" "rudder_load_balancer_listener" {
  load_balancer_arn = "${aws_alb.rudder_public.arn}"
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "${data.aws_acm_certificate.domain.arn}"
  default_action {
    target_group_arn = "${aws_alb_target_group.rudder_target_group.arn}"
    type             = "forward"
  }
}


resource "aws_alb_listener" "rudder_http_load_balancer_listener" {
  load_balancer_arn = "${aws_alb.rudder_public.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_route53_record" "load_balancer" {
  zone_id = "${data.aws_route53_zone.rudder.zone_id}"
  name    = "rudder.${var.main_route53_zone}"
  type    = "CNAME"
  ttl     = "300"
  records = ["${aws_alb.rudder_public.dns_name}"]
}

output "ami_id" {
  value = "${aws_ami_from_instance.rudder.id}"
}

output "rudder_server_url" {
  value = "${aws_route53_record.load_balancer.fqdn}"
}
