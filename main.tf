terraform {
  experiments = [module_variable_optional_attrs]
}

resource "random_string" "sql_server_suffix" {
  for_each = { for vm in var.sql_vms_configuration : vm.name => vm }
  length           = 8
  special          = false
  upper            = false 
  lower            = true
  number           = true
}

resource "azurerm_public_ip" "sql_vm_public_ip" {
  for_each = { 
    for vm in var.sql_vms_configuration : vm.name => vm
    if vm.public_ip_enabled
  }
  name                = "${each.key}-${random_string.sql_server_suffix[each.key].id}-public-ip"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  domain_name_label   = "${each.key}-${random_string.sql_server_suffix[each.key].id}"

  lifecycle {
    ignore_changes = [
      # Ignore changes to tags, e.g. because a management agent
      # updates these based on some ruleset managed elsewhere.
      tags,
    ]
  }
}

resource "azurerm_network_interface" "sql_vm_nic" {
  for_each = { for vm in var.sql_vms_configuration : vm.name => vm }
  name                = "${each.key}-${random_string.sql_server_suffix[each.key].id}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "dbconfiguration1"
    subnet_id                     = each.value.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = each.value.public_ip_enabled ? azurerm_public_ip.sql_vm_public_ip[each.key].id : null
  }

  lifecycle {
    ignore_changes = [
      # Ignore changes to tags, e.g. because a management agent
      # updates these based on some ruleset managed elsewhere.
      tags,
    ]
  }
}

resource "azurerm_network_security_group" "sql_vm_nsg" {
  for_each = { for vm in var.sql_vms_configuration : vm.name => vm }
  name                = "${each.key}-${random_string.sql_server_suffix[each.key].id}-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  lifecycle {
    ignore_changes = [
      # Ignore changes to tags, e.g. because a management agent
      # updates these based on some ruleset managed elsewhere.
      tags,
    ]
  }
}

resource "azurerm_network_interface_security_group_association" "sql_vm_nic_nsg_asso" {
  for_each = { for vm in var.sql_vms_configuration : vm.name => vm }
  network_interface_id       = azurerm_network_interface.sql_vm_nic[each.key].id
  network_security_group_id  = azurerm_network_security_group.sql_vm_nsg[each.key].id
}

resource "azurerm_virtual_machine" "sql_vm" {
  for_each = { for vm in var.sql_vms_configuration : vm.name => vm }
  name                  = "${each.key}-${random_string.sql_server_suffix[each.key].id}-vm"
  location              = var.location
  resource_group_name   = var.resource_group_name
  network_interface_ids = [azurerm_network_interface.sql_vm_nic[each.key].id]
  vm_size               = each.value.vm_size

  storage_image_reference {
    publisher = each.value.image_publisher
    offer     = each.value.image_offer
    sku       = each.value.image_sku
    version   = each.value.image_version
  }

  storage_os_disk {
    name                      = "${each.key}-${random_string.sql_server_suffix[each.key].id}-os-disk"
    caching                   = each.value.storage_os_disk.caching                  
    create_option             = each.value.storage_os_disk.create_option            
    disk_size_gb              = each.value.storage_os_disk.disk_size_gb             
    image_uri                 = each.value.storage_os_disk.image_uri                
    os_type                   = each.value.storage_os_disk.os_type                  
    write_accelerator_enabled = each.value.storage_os_disk.write_accelerator_enabled
    managed_disk_id           = each.value.storage_os_disk.managed_disk_id          
    managed_disk_type         = each.value.storage_os_disk.managed_disk_type        
    vhd_uri                   = each.value.storage_os_disk.vhd_uri                  
  }

  dynamic storage_data_disk {
    for_each = each.value.storage_data_disks != null ? { 
      for i, v in each.value.storage_data_disks : tostring(i) => v  
    } : {}
    content {
      name                      = "storage-disk${storage_data_disk.key}"                       
      caching                   = storage_data_disk.value.caching                  
      create_option             = storage_data_disk.value.create_option            
      disk_size_gb              = storage_data_disk.value.disk_size_gb             
      lun                       = storage_data_disk.value.lun        
      write_accelerator_enabled = storage_data_disk.value.write_accelerator_enabled
      managed_disk_id           = storage_data_disk.value.managed_disk_id          
      managed_disk_type         = storage_data_disk.value.managed_disk_type        
      vhd_uri                   = storage_data_disk.value.vhd_uri 
    }                 
  }
  
  os_profile {
    computer_name  = "${each.key}-${random_string.sql_server_suffix[each.key].id}"
    admin_username = each.value.os_username
    admin_password = each.value.os_password
  }

  dynamic os_profile_linux_config {
    for_each = each.value.os_type == "linux" ? [1] : []
    content {
      disable_password_authentication = false
    }
  }

  dynamic os_profile_windows_config {
    for_each = each.value.os_type == "windows" ? [1] : []
    content {
      provision_vm_agent = true
    }
  }
  
  lifecycle {
    ignore_changes = [
      # Ignore changes to tags, e.g. because a management agent
      # updates these based on some ruleset managed elsewhere.
      tags,
    ]
  }
}

resource "azurerm_private_dns_zone" "custom_private_dz" {
  count               = length(var.sql_vms_configuration) > 0 ? 1 : 0 
  name                = var.private_dns_zone_name
  resource_group_name = var.resource_group_name

  lifecycle {
    ignore_changes = [
      # Ignore changes to tags, e.g. because a management agent
      # updates these based on some ruleset managed elsewhere.
      tags,
    ]
  }
}

data "azurerm_virtual_network" "vnet_data" {
  for_each = toset(var.sql_vms_configuration[*].vnet_name)
  name                = each.key
  resource_group_name = var.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "sql_vnet_link" {
  for_each = toset(var.sql_vms_configuration[*].vnet_name)
  name                  = each.key
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.custom_private_dz[0].name
  virtual_network_id    = data.azurerm_virtual_network.vnet_data[each.key].id

  lifecycle {
    ignore_changes = [
      # Ignore changes to tags, e.g. because a management agent
      # updates these based on some ruleset managed elsewhere.
      tags,
    ]
  }
}

resource "azurerm_private_dns_a_record" "sql_record" {
  for_each = { for vm in var.sql_vms_configuration : vm.name => vm }
  name                = "${each.key}-${random_string.sql_server_suffix[each.key].id}"
  zone_name           = azurerm_private_dns_zone.custom_private_dz[0].name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [azurerm_network_interface.sql_vm_nic[each.key].private_ip_address]

  lifecycle {
    ignore_changes = [
      # Ignore changes to tags, e.g. because a management agent
      # updates these based on some ruleset managed elsewhere.
      tags,
    ]
  }
}

resource "random_password" "sql_password" {
  for_each = toset([ for vm in var.sql_vms_configuration : vm.name ])
  length = 16
  special = true
  upper = true
  lower = true
  number = true
  override_special = "-_!#^~%@"
}

resource "azurerm_virtual_machine_extension" "sql_vm_extension" {
  for_each = toset([ 
    for vm in var.sql_vms_configuration : vm.name
    if vm.os_type == "linux"
  ])
  name                 = "sql-vm-extension"
  virtual_machine_id   = azurerm_virtual_machine.sql_vm[each.key].id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = <<SETTINGS
    {
        "script": "${base64encode(templatefile("${path.module}/sql-vm-init/init.sh", {
          sqlpassword="${random_password.sql_password[each.key].result}"
        }))}"
    }
SETTINGS

  lifecycle {
    ignore_changes = [
      # Ignore changes to tags, e.g. because a management agent
      # updates these based on some ruleset managed elsewhere.
      tags,
    ]
  }
}

resource "random_string" "storage_account_random_suffix" {
  count   = length(toset([
    for vm in var.sql_vms_configuration : vm.name
    if (vm.backup != null ? vm.backup.enabled : false) && vm.os_type == "windows"
  ])) > 0 ? 1 : 0 
  length  = 8
  special = false
  lower   = true
  upper   = false
}

resource "azurerm_storage_account" "sql_vms_backup" {
  count   = length(toset([
    for vm in var.sql_vms_configuration : vm.name
    if (vm.backup != null ? vm.backup.enabled : false) && vm.os_type == "windows"
  ])) > 0 ? 1 : 0 
  name                      = "sqlvmsbackup${random_string.storage_account_random_suffix[0].id}"
  resource_group_name       = var.resource_group_name
  location                  = var.location
  account_tier              = "Standard"
  account_replication_type  = "LRS"
  enable_https_traffic_only = true
  allow_blob_public_access  = false

  lifecycle {
    ignore_changes = [
      # Ignore changes to tags, e.g. because a management agent
      # updates these based on some ruleset managed elsewhere.
      tags,
    ]
  }
}

resource "azurerm_mssql_virtual_machine" "mssql_vm_manage" {
  for_each = { 
    for vm in var.sql_vms_configuration : vm.name => vm
    if (vm.backup != null ? vm.backup.enabled : false) && vm.os_type == "windows"
  }
  virtual_machine_id = azurerm_virtual_machine.sql_vm[each.key].id
  sql_license_type = each.value.backup.sql_license_type
  sql_connectivity_update_password = random_password.sql_password[each.key].result
  sql_connectivity_update_username = "sqladmin"

  auto_backup {
    manual_schedule {
      full_backup_frequency = each.value.backup.full_backup_frequency
      full_backup_start_hour = each.value.backup.full_backup_start_hour
      full_backup_window_in_hours = each.value.backup.full_backup_window_in_hours
      log_backup_frequency_in_minutes = each.value.backup.log_backup_frequency_in_minutes
    }

    retention_period_in_days = each.value.backup.retention_period_in_days
    storage_blob_endpoint = azurerm_storage_account.sql_vms_backup[0].primary_blob_endpoint
    storage_account_access_key = azurerm_storage_account.sql_vms_backup[0].primary_access_key
  }

  lifecycle {
    ignore_changes = [
      # Ignore changes to tags, e.g. because a management agent
      # updates these based on some ruleset managed elsewhere.
      tags,
    ]
  }
}