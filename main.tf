provider "aws" {
	region = "ap-south-1"
	profile = "sky"
}

# -- Creating vpc

resource "aws_vpc" "task4-vpc" {
	cidr_block       = "192.168.0.0/16"
	instance_tenancy = "default"
	enable_dns_hostnames = "true"

	tags = {
  		Name = "task4-vpc"
  	}
}


# -- Creating internet-gateway

resource "aws_internet_gateway" "task4-igw" {
	vpc_id = "${aws_vpc.task4-vpc.id}"

	tags = {
  		Name = "task4-igw"
  	}
}


# -- Creating subnet

data "aws_availability_zones" "zones" {
	state = "available"
}


# -- Creating EIP

resource "aws_eip" "task4-eip" {
	vpc = "true"
}


# -- Creating public subnet

resource "aws_subnet" "public-subnet-1a" {
	availability_zone = "${data.aws_availability_zones.zones.names[0]}"
	cidr_block = "192.168.0.0/24"
	vpc_id = "${aws_vpc.task4-vpc.id}"
	map_public_ip_on_launch = "true"
 
	tags = {
		Name = "public-subnet-1a"
	}
}


# -- Creating private subnet

resource "aws_subnet" "private-subnet-1b" {
	availability_zone = "${data.aws_availability_zones.zones.names[1]}"
	cidr_block = "192.168.1.0/24"
	vpc_id = "${aws_vpc.task4-vpc.id}"

	tags = {
		Name = "private-subnet-1b"
	}
}


# -- Creating NAT gateway

resource "aws_nat_gateway" "task4-ngw" {
	allocation_id = "${aws_eip.task4-eip.id}"
	subnet_id = "${aws_subnet.public-subnet-1a.id}"
	
	tags = {
		Name = "task4-ngw"
	}
}


# -- Create route table for internet gateway

resource "aws_route_table" "task4-route-igw" {
	vpc_id = "${aws_vpc.task4-vpc.id}"

	route {
  		cidr_block = "0.0.0.0/0"
  		gateway_id = "${aws_internet_gateway.task4-igw.id}"
  	}
	
	tags = {
    		Name = "task4-route-igw"
  	}
}


# -- Create route table for nat gateway

resource "aws_route_table" "task4-route-ngw" {
  	depends_on = [ aws_nat_gateway.task4-ngw, 
		]
  	vpc_id = "${aws_vpc.task4-vpc.id}"

  	route {
    	cidr_block = "0.0.0.0/0"
    	gateway_id = "${aws_nat_gateway.task4-ngw.id}"
  	}

  	tags = {
    		Name = "task4-route-ngw"
  	}
}


# -- Subnet Association for internet gateway

resource "aws_route_table_association" "subnet-1a-asso" {
	subnet_id      = "${aws_subnet.public-subnet-1a.id}"
  	route_table_id = "${aws_route_table.task4-route-igw.id}"
}


# -- Subnet Association for nat gateway

resource "aws_route_table_association" "subnet-1b-asso" {
  	subnet_id      = "${aws_subnet.private-subnet-1b.id}"
  	route_table_id = "${aws_route_table.task4-route-ngw.id}"
}


# -- Creating Key Pairs for wordpress

resource "tls_private_key" "key1" {
	algorithm = "RSA"
	rsa_bits = 4096
}

resource "local_file" "key2" {
	content = "${tls_private_key.key1.private_key_pem}"
	filename = "wordpress_key.pem"
	file_permission = 0400
}

resource "aws_key_pair" "key3" {
	key_name = "wordpress_key"
	public_key = "${tls_private_key.key1.public_key_openssh}"
}


# -- Creating Key Pairs for mySql

resource "tls_private_key" "key4" {
	algorithm = "RSA"
	rsa_bits = 4096
}

resource "local_file" "key5" {
	content = "${tls_private_key.key4.private_key_pem}"
	filename = "mysql_key.pem"
	file_permission = 0400
}

resource "aws_key_pair" "key6" {
	key_name = "mysql_key"
	public_key = "${tls_private_key.key4.public_key_openssh}"
}


# -- Creating Key Pairs for bastion host

resource "tls_private_key" "key7" {
	algorithm = "RSA"
	rsa_bits = 4096
}

resource "local_file" "key8" {
	content = "${tls_private_key.key7.private_key_pem}"
	filename = "bastion_key.pem"
	file_permission = 0400
}

resource "aws_key_pair" "key9" {
	key_name = "bastion_key"
	public_key = "${tls_private_key.key7.public_key_openssh}"
}


# -- Creating Security Groups for wordpress

resource "aws_security_group" "sg-wp" {
	name        = "wordpress-sg"
  	description = "Allow TLS inbound traffic"
  	vpc_id      = "${aws_vpc.task4-vpc.id}"


  	ingress {
    		description = "SSH"
    		from_port   = 22
    		to_port     = 22
    		protocol    = "tcp"
    		cidr_blocks = [ "0.0.0.0/0" ]
  	}

  	ingress {
    		description = "HTTP"
    		from_port   = 80
    		to_port     = 80
    		protocol    = "tcp"
    		cidr_blocks = [ "0.0.0.0/0" ]
  	}

  	egress {
    		from_port   = 0
    		to_port     = 0
    		protocol    = "-1"
    		cidr_blocks = ["0.0.0.0/0"]
  	}

  	tags = {
    		Name = "wordpress-sg"
  	}
}


# -- Creating Security Groups for bastion host

resource "aws_security_group" "sg-bs" {
	name        = "bastion-sg"
  	description = "Allow TLS inbound traffic"
  	vpc_id      = "${aws_vpc.task4-vpc.id}"


  	ingress {
    		description = "SSH"
    		from_port   = 22
    		to_port     = 22
    		protocol    = "tcp"
    		cidr_blocks = [ "0.0.0.0/0" ]
  	}

  	egress {
    		from_port   = 0
    		to_port     = 0
    		protocol    = "-1"
    		cidr_blocks = ["0.0.0.0/0"]
  	}

  	tags = {
    		Name = "bastion-sg"
  	}
}


# -- Creating Security Groups for mySql for having connectivity with only wrodpress instance

resource "aws_security_group" "sg-db1" {
	depends_on = [
		aws_security_group.sg-wp,
  	]
	name        = "mySql-sg1"
  	description = "Allow TLS inbound traffic"
  	vpc_id      = "${aws_vpc.task4-vpc.id}"

  	ingress {
    		description = "MYSQL/Aurora"
    		from_port   = 3306
    		to_port     = 3306
    		protocol    = "tcp"
    		security_groups = [ "${aws_security_group.sg-wp.id}" ]
  	}

  	egress {
    		from_port   = 0
    		to_port     = 0
    		protocol    = "-1"
    		cidr_blocks = ["0.0.0.0/0"]
  	}

  	tags = {
    		Name = "mySql-sg1"
  	}
}


# -- Creating Security Groups for mySql for having connectivity with only bastion_host instance

resource "aws_security_group" "sg-db2" {
	depends_on = [
		aws_security_group.sg-bs,
  	]
	name        = "mySql-sg2"
  	description = "Allow TLS inbound traffic"
  	vpc_id      = "${aws_vpc.task4-vpc.id}"


  	ingress {
    		description = "SSH"
    		from_port   = 22
    		to_port     = 22
    		protocol    = "tcp"
    		security_groups = [ "${aws_security_group.sg-bs.id}" ]
  	}

  	egress {
    		from_port   = 0
    		to_port     = 0
    		protocol    = "-1"
    		cidr_blocks = ["0.0.0.0/0"]
  	}

  	tags = {
    		Name = "mySql-sg2"
  	}
}


# -- Creatig Ec2 instance for mySql

resource "aws_instance" "database_server" {
  	ami = "ami-08706cb5f68222d09"
	subnet_id = "${aws_subnet.private-subnet-1b.id}"
	availability_zone = "${data.aws_availability_zones.zones.names[1]}"
  	instance_type = "t2.micro"
	root_block_device {
		volume_type = "gp2"
		delete_on_termination = true
	}
  	key_name = "${aws_key_pair.key6.key_name}"
  	vpc_security_group_ids = [ "${aws_security_group.sg-db1.id}",
				   "${aws_security_group.sg-db2.id}" ]
	
	tags = {
		Name = "MySql"
	}
}


# -- Creating Ec2 instance for wordpress

resource "aws_instance" "web_server" {
	depends_on = [
		aws_instance.database_server,
  	]
		
  	ami = "ami-004a955bfb611bf13"
	subnet_id = "${aws_subnet.public-subnet-1a.id}"
	availability_zone = "${data.aws_availability_zones.zones.names[0]}"
  	instance_type = "t2.micro"
	root_block_device {
		volume_type = "gp2"
		delete_on_termination = true
	}
  	key_name = "${aws_key_pair.key3.key_name}"
  	vpc_security_group_ids = [ "${aws_security_group.sg-wp.id}" ]
	associate_public_ip_address = true
	
	tags = {
		Name = "Wordpress"
	}
}


# -- Creating Ec2 instance for bastion_host

resource "aws_instance" "bash_host" {
  	ami = "ami-0732b62d310b80e97"
	subnet_id = "${aws_subnet.public-subnet-1a.id}"
	availability_zone = "${data.aws_availability_zones.zones.names[0]}"
  	instance_type = "t2.micro"
	root_block_device {
		volume_type = "gp2"
		delete_on_termination = true
	}
  	key_name = "${aws_key_pair.key9.key_name}"
  	vpc_security_group_ids = [ "${aws_security_group.sg-bs.id}" ]
	associate_public_ip_address = true
	
	tags = {
		Name = "Bastion_host"
	}
}



	