# Test Internal Zone Creation and HTTP Listener
data "aws_availability_zones" "available" {}

provider "aws" {
  version = "~> 1.2"
  region  = "us-west-2"
}

resource "random_string" "rstring" {
  length  = 8
  upper   = false
  special = false
}

resource "random_string" "sqs_rstring" {
  length  = 18
  upper   = false
  special = false
}

resource "aws_sqs_queue" "my_sqs" {
  name = "${random_string.sqs_rstring.result}-my-example-queue"
}

resource "aws_security_group" "test_sg" {
  name        = "${random_string.rstring.result}-test-sg-1"
  description = "Test SG Group"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

module "vpc" {
  source              = "git::https://github.com/rackspace-infrastructure-automation/aws-terraform-vpc_basenetwork//?ref=v0.0.6"
  az_count            = 2
  cidr_range          = "10.0.0.0/16"
  public_cidr_ranges  = ["10.0.1.0/24", "10.0.3.0/24"]
  private_cidr_ranges = ["10.0.2.0/24", "10.0.4.0/24"]
  vpc_name            = "${random_string.rstring.result}-test"
}

module "alb" {
  source          = "git::https://github.com/rackspace-infrastructure-automation/aws-terraform-alb//?ref=v0.0.8"

  # Required
  alb_name        = "${random_string.rstring.result}-test-alb"
  security_groups = "${list(aws_security_group.test_sg.id)}"
  subnets         = "${module.vpc.public_subnets}"

  vpc_id = "${module.vpc.vpc_id}"

  # Optional
  create_logging_bucket = false

  create_internal_zone_record = false
  internal_record_name        = "alb.mupo181ve1jco37.net"
  route_53_hosted_zone_id     = "Z34VQ0W1VUIFLH"

  alb_tags = {
    "RightSaid" = "Fred"
    "LeftSaid"  = "George"
  }

  http_listeners_count = 1

  http_listeners = [{
    port = 80

    protocol = "HTTP"
  }]

  https_listeners_count = 0
  https_listeners       = []

  target_groups_count = 2

  target_groups = [
    {
      "name"             = "Test-TG1"
      "backend_protocol" = "HTTP"
      "backend_port"     = 80
    },
    {
      "name"             = "Test-TG2"
      "backend_protocol" = "HTTP"
      "backend_port"     = 80
    },
  ]
}

module "test_sg" {
  source        = "git::https://github.com/rackspace-infrastructure-automation/aws-terraform-security_group?ref=v0.0.6"
  resource_name = "my_test_sg"
  vpc_id        = "${module.vpc.vpc_id}"
}

module "sns_sqs" {
  source     = "git::https://github.com/rackspace-infrastructure-automation/aws-terraform-sns//?ref=v0.0.2"
  topic_name = "${random_string.sqs_rstring.result}-my-example-topic"

  create_subscription_1 = true
  protocol_1            = "sqs"
  endpoint_1            = "${aws_sqs_queue.my_sqs.arn}"
}

module "asg" {
  source = "git::https://github.com/scafeman/aws-terraform-ec2_asg//?ref=v0.0.11"
 
  ec2_os              = "amazon"
  subnets             = ["${module.vpc.private_subnets}"]
#  image_id            = "${var.image_id}"
#  image_id            = "ami-0d2f82a622136a696"
  resource_name       = "my_asg"
  security_group_list = ["${module.test_sg.private_web_security_group_id}"]
}
