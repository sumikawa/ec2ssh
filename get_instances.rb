#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
require 'aws-sdk'
require 'pp'
require 'inifile'
require 'optparse'
require 'yaml'

CONFIG = File.join(Dir.home, '.aws', 'config').freeze
CACHE = File.join(Dir.home, '.ec2ssh').freeze
CACHE_TTL = 3600
INSTANCE = Struct.new(:instance_id, :public_dns_name, :private_dns_name, :tags)

profile = 'default'
opts = {}
OptionParser.new do |opt|
  opt.banner = "Usage: #{opt.program_name} [options]"
  opt.on('-h', '--help', 'Show usage') { puts opt.help ; exit }
  opt.on('-f', '--flush', 'Flush cache') { opts[:ignore] = true }
  opt.on('-p PROFILE', '--profile PROFILE', 'Specify profile') { |v|
    profile = "profile #{v}"
    Aws.config[:credentials] = Aws::SharedCredentials.new(profile_name: profile)
  }
  opt.parse!(ARGV)
end

ini = IniFile.load(CONFIG)
region = ENV['REGION'] || ini[profile]['region']
Aws.config[:region] = region

instances = []
# load cache if fresh
if File.exist?(CACHE) && opts[:ignore].nil?
  mtime = File::Stat.new(CACHE).mtime
  if Time.now - mtime < CACHE_TTL
    cache = YAML.load_file(CACHE)
    instances = cache[profile][region] rescue nil
  end
end

if instances.empty?
  ec2 = Aws::EC2::Client.new
  instances = ec2.describe_instances(
    filters: [{ name: 'instance-state-name', values: ['running'] }]
  ).reservations.flat_map(&:instances).map! do |instance|
    INSTANCE.new(instance.instance_id,
                 instance.public_dns_name,
                 instance.private_dns_name,
                 instance.tags)
  end
  File.open(CACHE, 'w') { |f|
    cache = { profile => { region => instances } }
    YAML.dump(cache, f)
  }
end

instances.each do |instance|
  user = 'ec2-user'
  name = instance.instance_id
  dnsname = instance.public_dns_name || instance.private_dns_name
  instance.tags.each do |tag|
    name = tag.value if tag.key =~ /^name/i
    user = tag.value if tag.key =~ /^user/i
  end
  puts "\"#{name}\"\t#{user}@#{dnsname}\t#{instance.instance_id}"
end
