#### Webservers
## Security group
# Reference: https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_secgroup_v2
resource "openstack_networking_secgroup_v2" "iths-okyi-web-sg" {
  name        = "iths-okyi-web-sg"
  description = "Webserver SG"
}
## Rules
# Reference: https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_secgroup_rule_v2
resource "openstack_networking_secgroup_rule_v2" "web-allow-ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_group_id = openstack_networking_secgroup_v2.iths-okyi-bastion-sg.id
  security_group_id = openstack_networking_secgroup_v2.iths-okyi-web-sg.id
}
resource "openstack_networking_secgroup_rule_v2" "web-allow-http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 5000
  port_range_max    = 5000
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.iths-okyi-web-sg.id
}

## Server instance
resource "openstack_compute_instance_v2" "web" {
  name            = "iths-okyi-web"
  flavor_name       = "b.1c1gb"
  key_pair        = openstack_compute_keypair_v2.iths-okyi.name
  security_groups = [openstack_networking_secgroup_v2.iths-okyi-web-sg.name]
  # Disk
  block_device {
    uuid                  = data.openstack_images_image_v2.debian12.id
    source_type           = "image"
    volume_size           = 10
    boot_index            = 0
    destination_type      = "volume"
    delete_on_termination = true
  }
  # Attach our network to server instance
  network {
    name = openstack_networking_network_v2.iths-okyi-network.name
    fixed_ip_v4 = "10.0.69.55"
  }
  user_data = <<EOT
#cloud-config
ssh_authorized_keys:
  - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILZthDTUbwk77sJMrh4PSEw5d+mpXSvtrw14tkULlgCu workstation
package_update: true
package_upgrade: true
packages:
- python3-minimal
- ansible
- git
runcmd:
- git clone https://github.com/ddkrd/ansible-playbooks.git /home/debian/playbooks
- mkdir -p /home/debian/playbooks/templates
- mv -f /home/debian/playbooks/flaskapp.service.j2 /home/debian/playbooks/templates/flaskapp.service.j2
- ansible-playbook /home/debian/playbooks/flask_app.yml
final_message: "The system is finally up, after $UPTIME seconds"
EOT
}
## Floating IP
resource "openstack_networking_floatingip_v2" "web_lb_floatip" {
  pool = "ext-net"
}
 
## Load balancer
# Reference: https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/lb_loadbalancer_v2
resource "openstack_lb_loadbalancer_v2" "web_lb" {
  vip_subnet_id = openstack_networking_subnet_v2.iths-okyi-subnet.id 
}
## Load-balance-listener
# Reference: https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/lb_listener_v2
resource "openstack_lb_listener_v2" "web_lb_listener" {
  protocol        = "HTTP"
  protocol_port   = 80
  loadbalancer_id = openstack_lb_loadbalancer_v2.web_lb.id

  insert_headers = {
    X-Forwarded-For = "true"
  }
}
## Load-balance setting Round-Robin refers to the way the traffic is handled
## Creation of V2 LB-pool, attach the previously created listener
# Reference: https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/lb_pool_v2
resource "openstack_lb_pool_v2" "web_lb_pool" {
  protocol    = "HTTP"
  lb_method   = "ROUND_ROBIN"
  listener_id = openstack_lb_listener_v2.web_lb_listener.id
}

## V2 LB Member resource with attached to previously created LB pool
# Reference: https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/lb_member_v2
resource "openstack_lb_member_v2" "web_lb_members" {
  pool_id       = openstack_lb_pool_v2.web_lb_pool.id
  address       = "10.0.69.55"
  protocol_port = 5000
}

## Monitors the LB pool members with HTTP probes every 10 seconds. If three retries then consider -> down.
# Reference: https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/lb_monitor_v2
resource "openstack_lb_monitor_v2" "web_lb_monitor" {
  pool_id     = openstack_lb_pool_v2.web_lb_pool.id
  type        = "TCP"
  delay       = 10
  timeout     = 5
  max_retries = 5
  max_retries_down = 5
}

## Associates the floating ip we created earlier with a port
# Reference: https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_floatingip_associate_v2
resource "openstack_networking_floatingip_associate_v2" "web_lb_float_associate" {
  floating_ip = openstack_networking_floatingip_v2.web_lb_floatip.address
  port_id     = openstack_lb_loadbalancer_v2.web_lb.vip_port_id
}