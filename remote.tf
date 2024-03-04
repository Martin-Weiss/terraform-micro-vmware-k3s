resource "null_resource" "copy-test-file" {

  depends_on = [vsphere_virtual_machine.server]
  for_each   = { for inst in local.instances : inst.servername => inst }

  connection {
    type     = "ssh"
    host     = vsphere_virtual_machine.server[each.key].guest_ip_addresses.0
    user     = var.username
    password = var.password
  }

  provisioner "file" {
    source      = "files/rootCA.suse.crt"
    destination = "/etc/pki/trust/anchors/rootCA.suse.crt"
  }

}

resource "null_resource" "update-ca-certificates" {

  depends_on = [null_resource.copy-test-file]
  for_each   = { for inst in local.instances : inst.servername => inst }

  provisioner "remote-exec" {
    connection {
      host     = vsphere_virtual_machine.server[each.key].guest_ip_addresses.0
      user     = var.username
      password = var.password
    }

    inline = ["update-ca-certificates"]
  }
}

resource "null_resource" "susemanager-registration" {

  depends_on = [null_resource.copy-test-file]
  for_each   = { for inst in local.instances : inst.servername => inst }

  provisioner "remote-exec" {
    connection {
      #host     = vsphere_virtual_machine.server[each.key].guest_ip_addresses.0
      host     = "192.168.0.69"
      user     = var.username
      password = var.password
    }
    # bootstrap SUSE Manager, change rebootmgr strategy and enable dbus in transactional update to allow reboot control via rebootmgr from transactional-update via salt
    inline = ["curl -Sks  https://susemanager.weiss.ddnss.de/pub/bootstrap/bootstrap.sh | sed 's/^ACTIVATION_KEYS=.*/ACTIVATION_KEYS=1-k3s-micro-55/g' | sed 's/^ORG_CA_CERT=.*/ORG_CA_CERT=RHN-ORG-TRUSTED-SSL-CERT/g' | sed 's/^ORG_CA_CERT_IS_RPM_YN=.*/ORG_CA_CERT_IS_RPM_YN=0/g' |bash; rebootmgrctl set-strategy instantly; echo 'BINDDIRS[1]=/run/dbus' >> /etc/tukit.conf"]
  }
}


resource "null_resource" "registration" {

  depends_on = [null_resource.update-ca-certificates]
  for_each   = { for inst in local.instances : inst.servername => inst }

  provisioner "remote-exec" {
    connection {
      host     = vsphere_virtual_machine.server[each.key].guest_ip_addresses.0
      user     = var.username
      password = var.password
    }

    inline = each.value.role == "all" ? [
      format("%s %s",
        rancher2_cluster_v2.cluster.cluster_registration_token[0]["insecure_node_command"],
        join(" ", formatlist("--%s", split(",", "etcd,controlplane,worker")))
      )
      ] : [
      format("%s %s",
        rancher2_cluster_v2.cluster.cluster_registration_token[0]["insecure_node_command"],
        join(" ", formatlist("--%s", split(",", "etcd,controlplane")))
      )
    ]
  }
}
