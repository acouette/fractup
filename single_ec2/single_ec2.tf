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

resource "aws_subnet" "fractal_public_subnet" {
  vpc_id = "${aws_vpc.fractal_vpc.id}"
  cidr_block = "10.0.1.0/24"
}

resource "aws_route_table_association" "a" {
  subnet_id      = "${aws_subnet.fractal_public_subnet.id}"
  route_table_id = "${aws_route_table.r.id}"
}

resource "aws_security_group" "fractal_worker_sg" {
  vpc_id = "${aws_vpc.fractal_vpc.id}"

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

}


resource "aws_instance" "fractal-worker" {
  ami           = "${data.aws_ami.fractal.id}"
  instance_type = "t2.medium"

  monitoring = "true" 

  vpc_security_group_ids = ["${aws_security_group.fractal_worker_sg.id}"]
  subnet_id = "${aws_subnet.fractal_public_subnet.id}"

  associate_public_ip_address = "true"

  tags = {
    Name = "SingleFractalWorker"
  }
}
