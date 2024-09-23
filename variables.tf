variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "service_name" {
  type = string
}

variable "region" {
  type = string
}

variable "sqs_list" {
  type    = list(string)
  default = []
}

#variable "cidr_block" {
#  type = string
#}
