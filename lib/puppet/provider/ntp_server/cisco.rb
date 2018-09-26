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

Puppet::Type.type(:ntp_server).provide(:cisco) do
  desc 'The Cisco provider for ntp_server.'

  confine feature: :cisco_node_utils
  confine operatingsystem: :nexus
  defaultfor operatingsystem: :nexus

  mk_resource_methods

  NTP_SERVER_ALL_PROPS = [
    :key,
    :prefer,
    :maxpoll,
    :minpoll,
    :vrf,
  ]

  def initialize(value={})
    super(value)
    @ntpserver = Cisco::NtpServer.ntpservers[@property_hash[:name]]
    @property_flush = {}
    debug 'Created provider instance of ntp_server'
  end

  def self.properties_get(ntpserver_ip, v)
    debug "Checking instance, ntpserver #{ntpserver_ip}"

    current_state = {
      name:    ntpserver_ip,
      ensure:  :present,
      key:     v.key,
      prefer:  v.prefer.to_s,
      maxpoll: v.maxpoll,
      minpoll: v.minpoll,
      vrf:     v.vrf,
    }

    new(current_state)
  end # self.properties_get

  def self.instances
    ntpservers = []
    Cisco::NtpServer.ntpservers.each do |ntpserver_ip, v|
      ntpservers << properties_get(ntpserver_ip, v)
    end

    ntpservers
  end

  def self.prefetch(resources)
    ntpservers = instances

    resources.keys.each do |id|
      provider = ntpservers.find { |ntpserver| ntpserver.name == id }
      resources[id].provider = provider unless provider.nil?
    end
  end # self.prefetch

  def exists?
    @property_hash[:ensure] == :present
  end

  def create
    @property_flush[:ensure] = :present
  end

  def destroy
    @property_flush[:ensure] = :absent
  end

  def flush
    if @property_flush[:ensure] == :absent
      @ntpserver.destroy
      @ntpserver = nil
    else
      # Create/Update
      # NTP is a single line in the config and cannot be easily changed adhoc
      # Remove existing config and set intended state
      unless @ntpserver.nil?
        # retain previous value to rollback if set fails
        old_value = @ntpserver
        @ntpserver.destroy
      end
      # Create new instance with configured options
      opts = { 'name' => @resource[:name] }
      NTP_SERVER_ALL_PROPS.each do |prop|
        next unless @resource[prop]
        opts[prop.to_s] = @resource[prop].to_s
      end

      begin
        @ntpserver = Cisco::NtpServer.new(opts)
      rescue Cisco::CliError => e
        error "Unable to set new values: #{e.message}"
        old_value.create unless old_value.nil?
      end
    end
    # puts_config
  end
end # Puppet::Type

require_relative '../../../puppet_x/cisco/check'
unless PuppetX::Cisco::Check.use_old_netdev_type
  require 'puppet/resource_api'
  require 'puppet/resource_api/simple_provider'

  require_relative('../../util/network_device/cisco_nexus/device')

  begin
    require 'puppet_x/cisco/cmnutils'
  rescue LoadError # seen on master, not on agent
    # See longstanding Puppet issues #4248, #7316, #14073, #14149, etc. Ugh.
    require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..',
                                       'puppet_x', 'cisco', 'cmnutils.rb'))
  end

  # Implementation for the ntp_server type using the Resource API.
  class Puppet::Provider::NtpServer::CiscoNexus < Puppet::ResourceApi::SimpleProvider
    def get(context)
      instances = []
      for instance in Puppet::Type::Ntp_server::ProviderCisco.instances
        current_state = instance.instance_variable_get(:@property_hash)
        current_state[:ensure] = current_state[:ensure].to_s
        current_state[:key] = current_state[:key].to_i if current_state[:key]
        current_state[:maxpoll] = current_state[:maxpoll].to_i if current_state[:maxpoll]
        current_state[:minpoll] = current_state[:minpoll].to_i if current_state[:minpoll]
        current_state[:prefer] = PuppetX::Cisco::Utils.str_to_bool(current_state[:prefer]) if current_state[:prefer]
        instances << current_state
      end
      instances
    end

    def canonicalize(_context, resources)
      resources.each do |r|
        r[:key] = r[:key].to_i if r[:key]
        r[:maxpoll] = r[:maxpoll].to_i if r[:maxpoll]
        r[:minpoll] = r[:minpoll].to_i if r[:minpoll]
        r[:prefer] = PuppetX::Cisco::Utils.str_to_bool(r[:prefer]) if r[:prefer]
      end
    end

    def update(context, _id, should)
      is = get(context).find { |key| key[:name] == should[:name] }
      x = Puppet::Type::Ntp_server::ProviderCisco.new(is)
      x.instance_variable_set(:@resource, should)
      x.flush
    end

    def delete(context, id)
      is = get(context).find { |key| key[:name] == id }
      x = Puppet::Type::Ntp_server::ProviderCisco.new(is)
      x.instance_variable_set(:@resource, is)
      x.instance_variable_set(:@property_flush, { :ensure => :absent })
      x.flush
    end

    alias create update
  end
end
