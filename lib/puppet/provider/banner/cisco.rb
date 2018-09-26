# September, 2018
#
# Copyright (c) 2014-2018 Cisco and/or its affiliates.
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

Puppet::Type.type(:banner).provide(:cisco) do
  desc 'The Cisco provider for banner.'

  confine feature: :cisco_node_utils
  confine operatingsystem: :nexus
  defaultfor operatingsystem: :nexus

  mk_resource_methods

  BANNER_ALL_PROPS = [
    :motd
  ]

  PuppetX::Cisco::AutoGen.mk_puppet_methods(:non_bool, self, '@banner',
                                            BANNER_ALL_PROPS)

  def initialize(value={})
    super(value)
    @banner = Cisco::Banner.banners[@property_hash[:name]]
    @property_flush = {}
    debug 'Created provider instance of banner'
  end

  def self.properties_get(banner_name, v)
    debug "Checking instance, Banner #{banner_name}"

    current_state = {
      name:   'default',
      ensure: :present,
    }

    # Call node_utils getter for each property
    BANNER_ALL_PROPS.each do |prop|
      val = v.send(prop)
      current_state[prop] = val == v.default_motd ? 'default' : val
    end
    debug current_state
    new(current_state)
  end # self.properties_get

  def self.instances
    banners = []
    Cisco::Banner.banners.each do |banner_name, v|
      banners << properties_get(banner_name, v)
    end

    banners
  end

  def self.prefetch(resources)
    banners = instances

    resources.keys.each do |id|
      provider = banners.find { |banner| banner.name.to_s == id.to_s }
      resources[id].provider = provider unless provider.nil?
    end
  end # self.prefetch

  def exists?
    @property_hash[:ensure] == :present
  end

  def validate
    fail ArgumentError, "This provider only supports a namevar of 'default'" unless @resource[:name].to_s == 'default'
  end

  def flush
    validate
    BANNER_ALL_PROPS.each do |prop|
      next unless @resource[prop]
      next if @property_flush[prop].nil?
      # Call the AutoGen setters for the @banner node_utils object.
      @property_flush[prop] = nil if @property_flush[prop] == 'default'
      @banner.send("#{prop}=", @property_flush[prop]) if
        @banner.respond_to?("#{prop}=")
    end
  end
end # Puppet::Type

require_relative '../../../puppet_x/cisco/check'
unless PuppetX::Cisco::Check.use_old_netdev_type
  require 'puppet/resource_api'
  require 'puppet/resource_api/simple_provider'

  require_relative('../../util/network_device/cisco_nexus/device')

  # Implementation for the Banner type using the Resource API.
  # We cannot use SimpleProvider here as the type is not ensurable
  # Puppet will throw an error about 'Could not find a suitable provider' instead
  # of the actual error 'Could not evaluate: SimpleProvider cannot be used with a Type that is not ensurable'
  class Puppet::Provider::Banner::CiscoNexus
    def set(context, changes)
      changes.each do |name, change|
        context.updating(name) do
          update(context, change[:should])
        end
      end
    end

    def get(context)
      instances = []
      for instance in Puppet::Type::Banner::ProviderCisco.instances
        current_state = instance.instance_variable_get(:@property_hash)
        current_state.delete(:ensure)
        instances << current_state
      end
      instances
    end

    def update(context, should)
      is = get(context).find { |key| key[:name] == should[:name] }
      x = Puppet::Type::Banner::ProviderCisco.new(is)
      x.instance_variable_set(:@resource, should)
      x.instance_variable_set(:@property_flush, should)
      x.flush
    end
  end
end
