variable resource_group_name {
  type        = string
  description = "the resource group where the VMs will be created"
}

variable location {
  type        = string
  description = "the location where the resource group is present"
}

variable sql_vms_configuration {
  description = "the main input variable which has all the configuration regarding the sql vm to be created"
  type        = list(object({
    name               = string,
    public_ip_enabled  = bool,
    vnet_name          = string,
    subnet_id          = string,
    vm_size            = string,
    storage_os_disk    = object({
      create_option             = string,
      caching                   = optional(string),
      disk_size_gb              = optional(number),
      image_uri                 = optional(string), 
      os_type                   = optional(string),
      write_accelerator_enabled = optional(string),
      managed_disk_id           = optional(string),
      managed_disk_type         = optional(string),
      vhd_uri                   = optional(string),
    }),
    storage_data_disks  = optional(list(object({
      create_option             = string,
      caching                   = optional(string), 
      lun                       = string,
      disk_size_gb              = optional(number),
      write_accelerator_enabled = optional(string),
      managed_disk_id           = optional(string),
      managed_disk_type         = optional(string),
      vhd_uri                   = optional(string),
    }))),
    image_publisher    = string,
    image_offer        = string,
    image_sku          = string,
    image_version      = string,
    os_username        = string,
    os_password        = string,
    os_type            = string,
    backup = optional(object({
      enabled = bool,
      sql_license_type = string,
      full_backup_frequency = string,
      full_backup_start_hour = number,
      full_backup_window_in_hours = number,
      retention_period_in_days = number,
      log_backup_frequency_in_minutes = number
    }))
  }))
}

variable private_dns_zone_name {
  type        = string
  description = "name of the private dns zone"
}