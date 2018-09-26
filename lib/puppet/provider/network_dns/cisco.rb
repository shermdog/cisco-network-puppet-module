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

Puppet::Type.type(:network_dns).provide(:cisco) do
  desc 'The Cisco provider for network_dns.'

  confine feature: :cisco_node_utils
  confine operatingsystem: :nexus
  defaultfor operatingsystem: :nexus

  mk_resource_methods

  def initialize(value={})
    super(value)
    @domain = Cisco::DomainName.domainnames || {}
    @searches = Cisco::DnsDomain.dnsdomains || {}
    @servers = Cisco::NameServer.nameservers || {}
    @hostname = Cisco::HostName.hostname || {}
    @network_dns = value
    @property_flush = {}
  end

  def self.properties_get(vrf=nil)
    # VRF support should pass the vrf to these calls
    domain = Cisco::DomainName.domainnames
    searches = Cisco::DnsDomain.dnsdomains || {}
    servers = Cisco::NameServer.nameservers || {}
    hostname = Cisco::HostName.hostname || {}
    current_state = {
      name:     vrf.nil? ? 'settings' : vrf,
      ensure:   :present,
      domain:   domain.keys.first,
      hostname: hostname.keys.first,
      search:   searches.keys.sort,
      servers:  servers.keys.sort,
    }

    new(current_state)
  end

  def self.instances
    # VRF support should iterate over all VRFs here
    network_dns = []
    network_dns << properties_get

    network_dns
  end

  def self.prefetch(resources)
    network_dns = instances
    resources.keys.each do |name|
      provider = network_dns.find { |instance| instance.name == name }
      resources[name].provider = provider unless provider.nil?
    end
  end

  def exists?
    true
  end

  def create
    true
  end

  def destroy
    fail ArgumentError, 'This provider does not support ensure => absent'
  end

  def domain=(value)
    @domain[value].destroy if @domain[value]
    Cisco::DomainName.new(value)
  end

  def hostname=(value)
    @hostname[value].destroy if @hostname[value]
    Cisco::HostName.new(value)
  end

  def search=(value)
    to_remove = @property_hash[:search] - Array(value)
    to_create = Array(value) - @property_hash[:search]
    to_remove.each do |search|
      @searches[search].destroy
    end
    to_create.each do |search|
      Cisco::DnsDomain.new(search)
    end
  end

  def servers=(value)
    to_remove = @property_hash[:servers] - Array(value)
    to_create = Array(value) - @property_hash[:servers]
    to_remove.each do |server|
      @servers[server].destroy
    end
    to_create.each do |server|
      Cisco::NameServer.new(server)
    end
  end

  def validate
    # VRF support should lift this requirement
    fail ArgumentError, "This provider only supports a namevar of 'settings'" \
      unless @resource[:name].to_s == 'settings'
  end

  def flush
    validate
  end
end

require_relative '../../../puppet_x/cisco/check'
unless PuppetX::Cisco::Check.use_old_netdev_type
  require 'puppet/resource_api'
  require 'puppet/resource_api/simple_provider'

  require_relative('../../util/network_device/cisco_nexus/device')

  # Implementation for the network_dns type using the Resource API.
  class Puppet::Provider::NetworkDns::CiscoNexus < Puppet::ResourceApi::SimpleProvider
    def get(context)
      instances = []
      for instance in Puppet::Type::Network_dns::ProviderCisco.instances
        current_state = instance.instance_variable_get(:@property_hash)
        current_state[:ensure] = current_state[:ensure].to_s
        instances << current_state
      end
      instances
    end

    # def canonicalize(_context, resources)
    #   resources.each do |r|
    #     require 'pry'; binding.pry
    #   end
    # end

    # def create(context, _id, should)
    #   require 'pry'; binding.pry
    # end

    def update(context, _id, should)
      # x = Puppet::Type::Network_dns::ProviderCisco.new(should)
      # x.instance_variable_set(:@resource, should)
      # x.validate
      is = get(context).find { |key| key[:name] == should[:name] }
      x = Puppet::Type::Network_dns::ProviderCisco.new(is)
      x.instance_variable_set(:@resource, should)
      x.validate
      props = [:domain, :search, :servers]
      # require 'pry'; binding.pry
      for prop in props
        unless should[prop].nil?
          x.send("#{prop}=", should[prop]) if x.respond_to?("#{prop}=")
        end
      end
      # require 'pry'; binding.pry
    end

    def delete(context, _id)
      fail ArgumentError, 'This provider does not support ensure => absent'
    end

    alias create update
  end
end