

resource "azurerm_public_ip" "appgateway" {
  name                              = "${var.name}-AGW-pup-ip"
  location                          = var.location
  resource_group_name               = var.resource_group_name

  allocation_method = "Static"
  sku = "Standard" 
}


resource "azurerm_application_gateway" "appgateway" {

  name  = "${var.name}-AGW"
  location                          = var.location
  resource_group_name               = var.resource_group_name
  
  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [var.identity_id]
  }

  autoscale_configuration {
    min_capacity = var.min_capacity
    max_capacity = var.max_capacity
  }

  gateway_ip_configuration {
    name = "ipconfig"
    subnet_id = var.subnet_id
  }

  frontend_port {
    name = "http"
    port = "80"
  }

  frontend_port {
    name = "https"
    port = "443"
  }


  frontend_ip_configuration {
    name = "public"
    public_ip_address_id = azurerm_public_ip.appgateway.id
  }

  frontend_ip_configuration {
    name                          = "private"
    subnet_id                     = var.subnet_id
    private_ip_address            = var.private_ip_address
    private_ip_address_allocation = "Static"
  }

  backend_address_pool {
      name = "backendpool"

      ip_addresses = var.backendpool_ipaddresses
  }

  dynamic "redirect_configuration" {
    for_each = var.http_redirection == true ? [1] : []
    content {
      name                  = "http-rule-${var.hostname}"
      redirect_type         = "Permanent"
      target_listener_name  = "https-listener-${var.hostname}"
      include_path          = true
      include_query_string  = true
    }
  } 

  backend_http_settings {
    name                  = "backend"
    port                  = 80
    protocol              = "Http"
    cookie_based_affinity = var.cookie_based_affinity
    request_timeout       = "180"

    connection_draining   {
      enabled = true
      drain_timeout_sec = 180
    }

    probe_name            = "http-probe-${var.hostname}"
  }

  http_listener {
    name                           = "http-listener-${var.hostname}"
    frontend_ip_configuration_name = "private"
    frontend_port_name             = "http"
    protocol                       = "Http"

    host_name                      = var.listener_type == "basic" ? null : var.hostname
  }

  http_listener {
    name                            = "https-listener-${var.hostname}"
    frontend_ip_configuration_name  = "private"
    frontend_port_name              = "https"
    protocol                        = "Https"

    host_name                      = var.listener_type == "basic" ? null : var.hostname
    ssl_certificate_name            = var.certificate_name
  }

  request_routing_rule {
    name                        = "http-rule-${var.hostname}"
    rule_type                   = "Basic"
    http_listener_name          = "http-listener-${var.hostname}"

    redirect_configuration_name = var.http_redirection == true ? "http-rule-${var.hostname}" : null

    backend_address_pool_name   = var.http_redirection == true ? null : "backendpool"
    backend_http_settings_name  = var.http_redirection == true ? null : "backend"

    priority                    = 200
  }

  request_routing_rule {
    name                        = "https-rule-${var.hostname}"
    rule_type                   = "Basic"
    http_listener_name          = "https-listener-${var.hostname}"
    backend_address_pool_name   = "backendpool"
    backend_http_settings_name  = "backend"
    priority                    = 100
  }

  ssl_certificate {
    key_vault_secret_id = var.certificate_secret_id
    name                = var.certificate_name
  }

  probe {
    name                = "http-probe-${var.hostname}"
    protocol            = "Http"
    path                = var.probe_path
    host                = var.hostname

    interval            = "5"
    timeout             = "2"
    unhealthy_threshold = "3"

    match {
      status_code = ["200"]
    }
  }

  tags = {
    "Network"         = "AGW"
    "Service Domain"  = var.hostname
  }
}


