data "local_file" "server-txt" {
  filename = "${path.module}/server.txt"
}

locals {
  instances = csvdecode(data.local_file.server-txt.content)
}

data "template_file" "combustionscript" {
  template = file("combustion/script.tpl")

  for_each = { for inst in local.instances : inst.servername => inst }

  vars = {
    servername = each.value.servername
  }
}

data "template_file" "networkconfig" {
  template = file("ignition/networkconfig.tpl")

  for_each = { for inst in local.instances : inst.servername => inst }

  vars = {
    ipaddress  = each.value.ipaddress
    gateway    = each.value.gateway
    dnsserver1 = each.value.dnsserver1
    dnsserver2 = each.value.dnsserver2
    domainname = each.value.domainname
  }
}

data "template_file" "ignition" {
  template = file("ignition/ignition.tpl")

  for_each = { for inst in local.instances : inst.servername => inst }

  vars = {
    servername       = each.value.servername
    domainname       = each.value.domainname
    networkconfig    = base64encode(data.template_file.networkconfig[each.key].rendered)
    combustionscript = base64encode(data.template_file.combustionscript[each.key].rendered)
    authorized_keys  = jsonencode(var.authorized_keys)
  }
}

resource "vsphere_virtual_machine" "server" {
  #depends_on = [vsphere_folder.folder]

  for_each = { for inst in local.instances : inst.servername => inst }

  #folder           = var.stack_name
  name                       = each.value.servername
  num_cpus                   = each.value.cpus
  memory                     = each.value.memory
  guest_id                   = var.guest_id
  firmware                   = var.firmware
  scsi_type                  = data.vsphere_virtual_machine.template.scsi_type
  resource_pool_id           = data.vsphere_resource_pool.pool.id
  datastore_id               = data.vsphere_datastore.datastore.id
  wait_for_guest_net_timeout = 20
  scsi_controller_count      = 1
  hv_mode                    = "hvAuto"
  ept_rvi_mode               = "automatic"

  clone {
    template_uuid = data.vsphere_virtual_machine.template.id
  }

  disk {
    label            = "disk0"
    size             = var.server_disk_size
    eagerly_scrub    = data.vsphere_virtual_machine.template.disks.0.eagerly_scrub
    thin_provisioned = data.vsphere_virtual_machine.template.disks.0.thin_provisioned
    unit_number      = 0
  }

  extra_config = {
    "guestinfo.combustion.script"             = base64gzip(data.template_file.combustionscript[each.key].rendered)
    "guestinfo.ignition.config.data"          = base64gzip(data.template_file.ignition[each.key].rendered)
    "guestinfo.ignition.config.data.encoding" = "gzip+base64"
  }

  enable_disk_uuid = true

  network_interface {
    network_id = data.vsphere_network.network.id
  }

  lifecycle {
        ignore_changes = [
                ept_rvi_mode,hv_mode
        ]
  }

}
