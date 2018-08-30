require 'hocon'
require 'hocon/config_syntax'
require 'puppet/util/network_device'
require 'puppet/util/network_device/base'

module Puppet::Util::NetworkDevice::Cisco_nexus
  class Puppet::Util::NetworkDevice::Cisco_nexus::Device # rubocop:disable Style/ClassAndModuleCamelCase
    attr_accessor :facts, :url

    def config
      raise "Trying to load config from '#{@url.path}', but file does not exist." unless File.exist? @url.path
      @config ||= Hocon.load(@url.path, syntax: Hocon::ConfigSyntax::HOCON)
    end

    def initialize(url, _options={})
      require 'cisco_node_utils'
      @url = URI.parse(url)
      raise "Unexpected url '#{url}' found. Only file:// URLs for configuration supported at the moment." unless @url.scheme == 'file'

      Puppet.debug "Trying to connect to #{config['address']} as #{config['username']}"
      env = { host: config['address'], port: nil, username: config['username'], password: config['password'], cookie: nil }
      Cisco::Environment.add_env('default', env)
      @facts = parse_facts
    end

    def parse_facts
      facts = { 'operatingsystem' => 'nexus' }
      return_facts = {}
      facts['cisco_node_utils'] = CiscoNodeUtils::VERSION

      hash = {}
      platform = Cisco::Platform
      feature = Cisco::Feature

      hash['images'] = {}
      hash['images']['system_image'] = platform.system_image
      hash['images']['full_version'] = platform.image_version
      hash['images']['packages'] = platform.packages

      hash['hardware'] = {}
      hash['hardware']['type'] = platform.hardware_type
      hash['hardware']['cpu'] = platform.cpu
      hash['hardware']['memory'] = platform.memory
      hash['hardware']['board'] = platform.board
      hash['hardware']['last_reset'] = platform.last_reset
      hash['hardware']['reset_reason'] = platform.reset_reason

      hash['inventory'] = {}
      hash['inventory']['chassis'] = platform.chassis
      platform.slots.each do |slot, info|
        hash['inventory'][slot] = info
      end
      platform.power_supplies.each do |ps, info|
        hash['inventory'][ps] = info
      end
      platform.fans.each do |fan, info|
        hash['inventory'][fan] = info
      end

      hash['virtual_service'] = platform.virtual_services

      hash['feature_compatible_module_iflist'] = {}
      interface_list = feature.compatible_interfaces('fabricpath')
      hash['feature_compatible_module_iflist']['fabricpath'] = interface_list
      hash['hardware']['uptime'] = platform.uptime

      facts['cisco'] = hash

      # These are facts that facter was gathering
      facts['hostname'] = Cisco::NodeUtil.node.host_name
      facts['operatingsystemrelease'] = hash['images']['full_version']

      return_facts.merge(facts)
    end
  end
end
