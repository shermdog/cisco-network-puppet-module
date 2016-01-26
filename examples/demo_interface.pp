# Manifest to demo cisco_interface provider
#
# Copyright (c) 2014-2016 Cisco and/or its affiliates.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

class ciscopuppet::demo_interface {
  if $operatingsystem == 'nexus' {
    cisco_interface { 'Ethernet1/1' :
      shutdown                       => true,
      switchport_mode                => disabled,
      description                    => 'managed by puppet',
      ipv4_address                   => '192.168.55.5',
      ipv4_netmask_length            => 24,
      ipv4_address_secondary         => '192.168.88.1',
      ipv4_netmask_length_secondary  => 24,
      ipv4_pim_sparse_mode           => false,
      mtu                            => 1600,
      speed                          => 100,
      duplex                         => 'full',
      vrf                            => 'test',
      ipv4_acl_in                    => 'v4acl1',
      ipv4_acl_out                   => 'v4acl2',
      ipv6_acl_in                    => 'v6acl1',
      ipv6_acl_out                   => 'v6acl2',
    }

    cisco_interface { 'Ethernet1/1.1':
      encapsulation_dot1q => 20,
    }

    cisco_interface { 'Ethernet1/2':
      description     => 'default',
      shutdown        => 'default',
      access_vlan     => 'default',
      switchport_mode => access,
      channel_group   => 200,
    }

    cisco_interface { 'Ethernet1/3':
      switchport_mode               => trunk,
      switchport_trunk_allowed_vlan => '20, 30',
      switchport_trunk_native_vlan  => 40,
    }

    cisco_interface { 'Vlan22':
      svi_autostate    => false,
      svi_management   => true,
      ipv4_arp_timeout => 300,
    }
    #  Requires F3 or newer linecards
    # cisco_interface { 'Ethernet9/1':
    #   switchport_mode                => trunk,
    #   switchport_vlan_mapping        => [[20, 21], [30, 31]]
    #   switchport_vlan_mapping_enable => false
    # }
  }
  elsif $operatingsystem == 'ios_xr' {
    cisco_interface { 'GigabitEthernet0/0/0/1' :
      shutdown            => true,
      description         => 'managed by puppet',
      ipv4_address        => '192.168.55.55',
      ipv4_netmask_length => 24,
      mtu                 => 1600,
      vrf                 => 'test',
    }

    cisco_interface { 'GigabitEthernet0/0/0/2':
      description     => 'default',
      shutdown        => 'default',
    }
  }
}
