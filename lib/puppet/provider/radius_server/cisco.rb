# October, 2015
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

require 'cisco_node_utils' if Puppet.features.cisco_node_utils?
begin
  require 'puppet_x/cisco/autogen'
rescue LoadError # seen on master, not on agent
  # See longstanding Puppet issues #4248, #7316, #14073, #14149, etc. Ugh.
  require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..',
                                     'puppet_x', 'cisco', 'autogen.rb'))
end

Puppet::Type.type(:radius_server).provide(:cisco) do
  desc 'The Cisco provider for radius_server.'

  confine feature: :cisco_node_utils
  defaultfor operatingsystem: [:nexus, :ios_xr]

  mk_resource_methods

  RADIUS_SERVER_PROPS = {
    auth_port:           :auth_port,
    acct_port:           :acct_port,
    timeout:             :timeout,
    retransmit_count:    :retransmit_count,
    accounting_only:     :accounting,
    authentication_only: :authentication,
  }

  UNSUPPORTED_PROPS = [:group, :deadtime, :vrf, :source_interface]

  def initialize(value={})
    super(value)
    @radius_server = Cisco::RadiusServer.radiusservers[@property_hash[:name]]
    @property_flush = {}
    debug 'Created provider instance of radius_server'
  end

  def self.get_properties(name, v)
    debug "Checking instance, SyslogServer #{name}"

    current_state = {
      ensure:           :present,
      name:             v.name,
      auth_port:        v.auth_port ? v.auth_port : v.auth_port_default,
      acct_port:        v.acct_port ? v.acct_port : v.acct_port_default,
      timeout:          v.timeout ? v.timeout : -1,
      retransmit_count: v.retransmit_count ? v.retransmit_count : -1,
      key:              v.key ? v.key : 'unset',
      key_format:       v.key_format ? v.key_format : -1,
    }

    unless Facter.value('operatingsystem').eql?('ios_xr')
      current_state[:accounting_only] = v.accounting ? :true : :false
      current_state[:authentication_only] = v.authentication ? :true : :false
    end

    new(current_state)
  end # self.get_properties

  def self.instances
    radiusservers = []
    Cisco::RadiusServer.radiusservers.each do |name, v|
      radiusservers << get_properties(name, v)
    end

    radiusservers
  end

  def self.prefetch(resources)
    radius_servers = instances

    resources.keys.each do |id|
      provider = radius_servers.find { |instance| instance.name == id }
      resources[id].provider = provider unless provider.nil?
    end
  end # self.prefetch

  def key
    res = @resource[:key]
    ph = @property_hash[:key]
    return ph if res.nil?
    return :default if res == :default &&
                       ph == @radius_server.default_key
    unless res.start_with?('"') && res.end_with?('"')
      ph = ph.gsub(/\A"|"\Z/, '')
    end
    ph
  end

  def munge_flush(val)
    if val.is_a?(String) && val.eql?('unset')
      nil
    elsif val.is_a?(Integer) && val.eql?(-1)
      nil
    elsif val.is_a?(Symbol) && val.eql?(:true)
      true
    elsif val.is_a?(Symbol) && val.eql?(:false)
      false
    elsif val.is_a?(Symbol)
      val.to_s
    else
      val
    end
  end

  def validate
    fail ArgumentError,
         "This provider does not support the 'hostname' property. The namevar should be set to the IP of the Radius Server" \
          if @resource[:hostname]

    if Facter.value('operatingsystem').eql?('ios_xr')
      UNSUPPORTED_PROPS << :accounting_only << :authentication_only
    end

    invalid = []
    UNSUPPORTED_PROPS.each do |prop|
      invalid << prop if @resource[prop]
    end

    fail ArgumentError, "This provider does not support the following properties: #{invalid}" unless invalid.empty?

    fail ArgumentError,
         "The 'key' property must be set when specifying 'key_format'." if @resource[:key_format] && !resource[:key]

    fail ArgumentError,
         "The 'accounting_only' and 'authentication_only' properties cannot both be set to false." if @resource[:accounting_only] == :false && \
                                                                                                      resource[:authentication_only] == :false
  end

  def exists?
    (@property_hash[:ensure] == :present)
  end

  def create
    @property_flush[:ensure] = :present
  end

  def create_new
    if Facter.value('operatingsystem').eql?('ios_xr')
      @radius_server = Cisco::RadiusServer.new(@resource[:name], true, @resource[:auth_port], @resource[:acct_port])
    else
      @radius_server = Cisco::RadiusServer.new(@resource[:name], true)
    end
  end

  def destroy
    @property_flush[:ensure] = :absent
  end

  def flush
    validate

    if @property_flush[:ensure] == :absent
      @radius_server.destroy
      @radius_server = nil
      @property_hash[:ensure] = :absent
    else
      # On IOS XR, if the port values change, the entity has to be re-created as the ports
      # form part of the uniquiness of the item on the device. This is opposed to using
      # the setters on other platforms for the changing of port values.
      if @property_hash.empty? ||
         (Facter.value('operatingsystem').eql?('ios_xr') &&
          (@resource[:auth_port] != @radius_server.auth_port.to_i ||
          @resource[:acct_port] != @radius_server.acct_port.to_i))

        # create a new Radius Server
        create_new
      end

      if Facter.value('operatingsystem').eql?('ios_xr')
        RADIUS_SERVER_PROPS.delete(:auth_port)
        RADIUS_SERVER_PROPS.delete(:acct_port)
      end

      RADIUS_SERVER_PROPS.each do |puppet_prop, cisco_prop|
        if @resource[puppet_prop] && @radius_server.respond_to?("#{cisco_prop}=")
          @radius_server.send("#{cisco_prop}=", munge_flush(@resource[puppet_prop]))
        end
      end

      # Handle key and keyformat setting
      if @resource[:key]
        @radius_server.send('key_set', munge_flush(@resource[:key]), munge_flush(@resource[:key_format]))
      end
    end
  end
end   # Puppet::Type
