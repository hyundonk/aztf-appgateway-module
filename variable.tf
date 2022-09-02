variable "location" {}
variable "resource_group_name" {}

variable "identity_id" {}

variable "name" {}

variable "min_capacity" {
  default = 2
}

variable "max_capacity" {
  default = 10
}

variable "subnet_id" {
}

variable "private_ip_address" {

}

variable "cookie_based_affinity" {
  default = "Enabled"
}

variable "hostname" {
}

variable "certificate_name" {

}

variable "certificate_secret_id" {

}

variable "backendpool_ipaddresses" {

}
 
variable "probe_path" {}

variable "listener_type" {
  # "basic", "multi-site"
  default = "multi-site"
}

variable "http_redirection" {
  default = false
}

variable "request_timeout" {
  default = 180
}

