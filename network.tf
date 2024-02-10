
## Reference: https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_network_v2
## Network
resource "openstack_networking_network_v2" "iths-okyi-network" {
  name           = "iths-okyi-network"
}


## Reference: https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_subnet_v2
## Subnet
resource "openstack_networking_subnet_v2" "iths-okyi-subnet" {
  network_id = openstack_networking_network_v2.iths-okyi-network.id
  name = "iths-okyi-subnet"
  cidr       = "10.0.69.0/24"
  enable_dhcp = "true"
  dns_nameservers = ["8.8.8.8", "8.8.4.4"]
}
data "openstack_networking_network_v2" "external_network" {
  name = "ext-net"
}

## Reference: https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_router_v2
## Router
resource "openstack_networking_router_v2" "iths-okyi-router" {
  name                = "iths-okyi-router"
  external_network_id = data.openstack_networking_network_v2.external_network.id
}

## Reference: https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_subnet_v2
## Router interface
resource "openstack_networking_router_interface_v2" "iths-okyi-router-interface" {
  router_id = openstack_networking_router_v2.iths-okyi-router.id
  subnet_id = openstack_networking_subnet_v2.iths-okyi-subnet.id
}




