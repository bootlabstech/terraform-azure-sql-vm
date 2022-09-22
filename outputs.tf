output "fqdns" {
    value = {
        for k, v in azurerm_public_ip.sql_vm_public_ip : k => v.fqdn
    }
}

output "internal_fqdns" {
    value = {
        for k, v in azurerm_private_dns_a_record.sql_record : k => v.fqdn
    }
}

output "sql_suffix" {
    value = {
        for k, v in random_string.sql_server_suffix : k => v.result
    }
}

output "sql_passwords" {
    value = {
        for k, v in random_password.sql_password : k => v.result
    }
}

output "vm_ids" {
    value = {
        for k, v in azurerm_virtual_machine.sql_vm : k => v.id
    }
}

output "password_keys" {
  value = [
    for v in var.sql_vms_configuration : "${v.name}-${random_string.sql_server_suffix[v.name].id}"
  ]
}
