locals {
  service_domain = join("/", keys(var.hostname))
  http_redirection_map = {
    for key, value in var.hostname : 
      key => value.http_redirection if value.http_redirection == true
  }
}


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
    for_each = local.http_redirection_map
    content {
      name                  = "http-rule-${redirect_configuration.key}"
      redirect_type         = "Permanent"
      target_listener_name  = "https-listener-${redirect_configuration.key}"
      include_path          = true
      include_query_string  = true
    }
  } 

  dynamic "backend_http_settings" {
    for_each = var.hostname
    content {
      name                  = "backend-${backend_http_settings.key}"
      port                  = 80
      protocol              = "Http"
      cookie_based_affinity = var.cookie_based_affinity
      request_timeout       = var.request_timeout

      connection_draining   {
        enabled = true
        drain_timeout_sec = 180
      }

      probe_name            = "http-probe-${backend_http_settings.key}"
    }
  }

  dynamic "http_listener" {
    for_each = var.hostname
    content {
      name                           = "http-listener-${http_listener.key}"
      frontend_ip_configuration_name = "private"
      frontend_port_name             = "http"
      protocol                       = "Http"

      host_name                      = var.listener_type == "basic" ? null : http_listener.key
    } 
  }

  dynamic "http_listener" {
    for_each = var.hostname
    content {
      name                            = "https-listener-${http_listener.key}"
      frontend_ip_configuration_name  = "private"
      frontend_port_name              = "https"
      protocol                        = "Https"
      require_sni                    = var.listener_type == "basic" ? false : true

      host_name                      = var.listener_type == "basic" ? null : http_listener.key
      ssl_certificate_name            = var.certificate_name
    } 
  }

  dynamic "request_routing_rule" {
    for_each = var.hostname
    content {
      name                        = "http-rule-${request_routing_rule.key}"
      rule_type                   = "Basic"
      http_listener_name          = "http-listener-${request_routing_rule.key}"

      redirect_configuration_name = request_routing_rule.value.http_redirection == true ? "http-rule-${request_routing_rule.key}" : null

      backend_address_pool_name   = request_routing_rule.value.http_redirection == true ? null : "backendpool"
      backend_http_settings_name  = request_routing_rule.value.http_redirection == true ? null : "backend-${request_routing_rule.key}"

      priority                    = 200 + request_routing_rule.value.rule_priority_increment
    }
  }

  dynamic "request_routing_rule" {
    for_each = var.hostname
    content {
      name                        = "https-rule-${request_routing_rule.key}"
      rule_type                   = "Basic"
      http_listener_name          = "https-listener-${request_routing_rule.key}"
      backend_address_pool_name   = "backendpool"
      backend_http_settings_name  = "backend-${request_routing_rule.key}"
      priority                    = 100 + request_routing_rule.value.rule_priority_increment
    }
  }

  ssl_certificate {
    key_vault_secret_id = var.certificate_secret_id
    name                = var.certificate_name
  }

  dynamic "probe" {
    for_each = var.hostname
    content {
      name                = "http-probe-${probe.key}"
      protocol            = "Http"
      path                = probe.value.probe_path
      host                = probe.key

      interval            = "5"
      timeout             = "2"
      unhealthy_threshold = "3"

      match {
        status_code = ["200"]
      }
    }
  }

  tags = {
    "Network"         = "AGW"
    "Service Domain"  = local.service_domain # var.hostname
  }
}


