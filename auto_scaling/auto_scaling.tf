# Create a new instance of the latest Ubuntu 14.04 on an
# t2.micro node with an AWS Tag naming it "HelloWorld"
provider "aws" {
  region = "eu-west-1"
}

data "aws_ami" "fractal" {
  most_recent = true

  filter {
    name   = "name"
    values = ["acouette-fractal-*"]
  }
  owners = ["737256533296"] # Canonical
}


resource "aws_vpc" "fractal_vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.fractal_vpc.id}"
}
resource "aws_route_table" "r" {
  vpc_id = "${aws_vpc.fractal_vpc.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }
}

resource "aws_subnet" "fractal_public_subnet_1" {
  vpc_id = "${aws_vpc.fractal_vpc.id}"
  cidr_block = "10.0.1.0/24"
  availability_zone_id = "euw1-az1"
}

resource "aws_subnet" "fractal_public_subnet_2" {
  vpc_id = "${aws_vpc.fractal_vpc.id}"
  cidr_block = "10.0.2.0/24"
  availability_zone_id = "euw1-az2"
}

resource "aws_subnet" "fractal_public_subnet_3" {
  vpc_id = "${aws_vpc.fractal_vpc.id}"
  cidr_block = "10.0.3.0/24"
  availability_zone_id = "euw1-az3"
}


resource "aws_route_table_association" "a" {
  subnet_id      = "${aws_subnet.fractal_public_subnet_1.id}"
  route_table_id = "${aws_route_table.r.id}"
}

resource "aws_route_table_association" "b" {
  subnet_id      = "${aws_subnet.fractal_public_subnet_2.id}"
  route_table_id = "${aws_route_table.r.id}"
}
resource "aws_route_table_association" "c" {
  subnet_id      = "${aws_subnet.fractal_public_subnet_3.id}"
  route_table_id = "${aws_route_table.r.id}"
}


resource "aws_security_group" "fractal_worker_sg" {
  vpc_id = "${aws_vpc.fractal_vpc.id}"

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 22 
    to_port     = 22
    protocol    = "tcp"
  }
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 8080
    to_port     = 8080 
    protocol    = "tcp"
  }
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 80 
    to_port     = 80 
    protocol    = "tcp"
  }

}

resource "aws_launch_template" "fractal_worker" {
  name_prefix   = "fractal"
  image_id      = "${data.aws_ami.fractal.id}"
  instance_type = "t2.small"
  monitoring {
    enabled = true
  }
  vpc_security_group_ids = ["${aws_security_group.fractal_worker_sg.id}"]
  tags = {
      Name = "fractal-worker"
  }
}


resource "aws_autoscaling_group" "fractal_worker" {
  vpc_zone_identifier = ["${aws_subnet.fractal_public_subnet_1.id}", "${aws_subnet.fractal_public_subnet_2.id}", "${aws_subnet.fractal_public_subnet_3.id}"]
  max_size           = 3 
  min_size           = 1
  desired_capacity   = 1
  health_check_type = "ELB"
  target_group_arns = ["${aws_lb_target_group.fractal_target_group.arn}"]
  default_cooldown = 30
  
  launch_template {
    id      = "${aws_launch_template.fractal_worker.id}"
    version = "$$Latest"
  }
}

resource "aws_autoscaling_policy" "fractal_as_target" {
  name                   = "fractal_target_cpu"
  policy_type = "TargetTrackingScaling"
  autoscaling_group_name = "${aws_autoscaling_group.fractal_worker.name}"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 50.0
  }
}


resource "aws_lb" "fractal_lb" {
  name               = "fractal-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.fractal_worker_sg.id}"]
  subnets            = ["${aws_subnet.fractal_public_subnet_1.id}", "${aws_subnet.fractal_public_subnet_2.id}", "${aws_subnet.fractal_public_subnet_3.id}"]

  enable_deletion_protection = false 


  tags = {
    Environment = "production"
  }
}

resource "aws_lb_listener" "fractup_listener" {
  load_balancer_arn = "${aws_lb.fractal_lb.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.fractal_target_group.arn}"
  }
}


resource "aws_lb_target_group" "fractal_target_group" {
  name     = "fractal-target-group"
  port     = 8080
  protocol = "HTTP"
  health_check {
    path = "/health"
  }
  vpc_id   = "${aws_vpc.fractal_vpc.id}"
}

