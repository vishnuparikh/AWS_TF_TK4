//user and variables//

provider "aws" {
  region     = "ap-south-1"
  profile    = "vmp"
}



resource "aws_vpc" "vpc" {
  cidr_block = "192.168.0.0/16"
  instance_tenancy = "default"
  
  tags = {
    Name= "Terraform_VPC"
  }
}



resource "aws_subnet" "public_subnet" {
  vpc_id = "${aws_vpc.vpc.id}"
  cidr_block = "192.168.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = "ap-south-1a"
  tags = {
    Name = "public_subnet"
  }
}
resource "aws_subnet" "private_subnet" {
  vpc_id = "${aws_vpc.vpc.id}"
  cidr_block = "192.168.2.0/24"
  availability_zone = "ap-south-1b"
  tags = {
    Name = "private_subnet"
  }
}






resource "aws_internet_gateway" "InterNetGateWay" {
  vpc_id = "${aws_vpc.vpc.id}"
  tags = {
    Name = "InterNetGateWay"
  } 
}










resource "aws_route_table" "public_route" {
  vpc_id = "${aws_vpc.vpc.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.InterNetGateWay.id}"
  }
  
  tags = {
    Name = "public_route"
  }
}
resource "aws_route_table_association" "subnet_publicass" {
  subnet_id = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route.id
}





resource "aws_eip" "eip" {
  vpc = true
  depends_on = [ "aws_internet_gateway.InterNetGateWay" ]
}





resource "aws_nat_gateway" "NatGateWay" {
  allocation_id = "${aws_eip.eip.id}"
  subnet_id = aws_subnet.public_subnet.id
  depends_on = [ "aws_internet_gateway.InterNetGateWay" ]
}







resource "aws_route_table" "private_route" {
  vpc_id = "${aws_vpc.vpc.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_nat_gateway.NatGateWay.id}"
  }
  
  tags = {
    Name = "private_route"
  }
}
resource "aws_route_table_association" "subnet_privateass" {
  subnet_id = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_route.id
}




//creation of security group for wordpress and mysql//

resource "aws_security_group" "sg_wp" {
  name = "sg_wordpress"
  vpc_id = "${aws_vpc.vpc.id}"
  ingress {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }


  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }


 egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags ={
    
    Name= "security_group1"
  }

}
resource "aws_security_group" "sg_mysql" {
  name = "sg_MYSQL"
  description = "managed by terrafrom for mysql servers"
  vpc_id = "${aws_vpc.vpc.id}"
  ingress {
    protocol        = "tcp"
    from_port       = 3306
    to_port         = 3306
    cidr_blocks = ["0.0.0.0/0"]
    security_groups = ["${aws_security_group.sg_wp.id}"]
  }
   
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
  tags ={
    
    Name= "SG_MYSQL"
  }

}
resource "aws_security_group" "allow-ports-bastion" {
  name        = "allow-ports-bastion"
  description = "Allow ssh"
  vpc_id      = "${aws_vpc.vpc.id}"
  
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
  tags = {
    Name = "allow-ports-bastion"
  }
}





resource "aws_instance" "MYSQL_Instance2" {
  ami           = "ami-08706cb5f68222d09"
  instance_type = "t2.micro"
  subnet_id = "${aws_subnet.private_subnet.id}"
  vpc_security_group_ids = ["${aws_security_group.sg_mysql.id}"]
  key_name = "key1"
  tags = {
    Name = "mysql_OS"
  }
}





resource "aws_instance" "WP_Instance1" {
  ami           = "ami-000cbce3e1b899ebd"
  instance_type = "t2.micro"
  subnet_id = "${aws_subnet.public_subnet.id}"
  vpc_security_group_ids = ["${aws_security_group.sg_wp.id}"]
  key_name = "key1"
  tags = {
    Name = "wordpress_OS"
  }
}




resource "aws_instance" "bastion" {
  ami = "ami-08706cb5f68222d09"
  instance_type = "t2.micro"
  subnet_id = "${aws_subnet.public_subnet.id}"
  associate_public_ip_address = true
  key_name = "key1"
  vpc_security_group_ids = [ "${aws_security_group.allow-ports-bastion.id}" ]
  tags = {
    Name = "bastion-os"
  }
}