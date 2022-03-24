variable "PRIVATE_KEY_PATH" {
  default = "aws-key"
}

variable "PUBLIC_KEY_PATH" {
  default = "aws-key.pub"
}

variable "EC2_USER" {
  default = "ubuntu"
}

variable "vpc_cidr" {
    default = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
    default = "10.0.1.0/24"
}

variable "instance_type" {
    default = "t2.micro"
}

variable "instance_key" {
    default = "aws-key"
}