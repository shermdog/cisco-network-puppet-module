#
# Puppet provider to manage upgrade of Cisco devices
#
# Copyright (c) 2017 Cisco and/or its affiliates.
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

require 'cisco_node_utils' if Puppet.features.cisco_node_utils?
begin
  require 'puppet_x/cisco/autogen'
rescue LoadError # seen on master, not on agent
  # See longstanding Puppet issues #4248, #7316, #14073, #14149, etc. Ugh.
  require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..',
                                     'puppet_x', 'cisco', 'autogen.rb'))
end

begin
  require 'puppet_x/cisco/cmnutils'
rescue LoadError # seen on master, not on agent
  # See longstanding Puppet issues #4248, #7316, #14073, #14149, etc. Ugh.
  require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..',
                                     'puppet_x', 'cisco', 'cmnutils.rb'))
end
Puppet::Type.type(:cisco_upgrade).provide(:cisco) do
  desc 'The Cisco Upgrade provider to upgrade Cisco devices.'

  confine feature: :cisco_node_utils
  defaultfor operatingsystem: :nexus

  mk_resource_methods

  UPGRADE_NON_BOOL_PROPS = [
    :version
  ]

  UPGRADE_ALL_PROPS = UPGRADE_NON_BOOL_PROPS

  PuppetX::Cisco::AutoGen.mk_puppet_methods(:non_bool, self, '@nu',
                                            UPGRADE_NON_BOOL_PROPS)

  def initialize(value={})
    super(value)
    @nu = Cisco::Upgrade
    @property_flush = {}
  end

  def self.instances
    inst = []
    upgrade = Cisco::Upgrade

    inst << new(
      name:    'image',
      version: upgrade.image_version)
  end

  def self.prefetch(resources)
    resources.values.first.provider = instances.first
  end

  def version=(new_version)
    return if new_version.nil?
    # Convert del_boot_image and force_upgrade from symbols
    # to Boolean Class
    fail 'The source_uri parameter must be set in the manifest' if
      @resource[:source_uri].nil?
    del_boot_image = (@resource[:delete_boot_image] == :true)
    force_upgrade = (@resource[:force_upgrade] == :true)
    @nu.upgrade(new_version, @resource[:source_uri][:image_name], @resource[:source_uri][:uri],
                del_boot_image, force_upgrade)
    @property_hash[:version] = new_version
  end
end
