#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
require 'aws-sdk'
require 'pp'
require 'inifile'
require 'optparse'
require 'yaml'

CACHE = "#{Dir.home}/.ec2ssh"

profile = 'default'
$opt = {}
OptionParser.new do |opt|
  opt.banner = "Usage: #{opt.program_name} [options]"
  opt.on('-h', '--help', 'Show usage') { puts opt.help ; exit }
  opt.on('-f', '--flush', 'Flush cache') { $opt[:ignore] = true }
  opt.on('-p PROFILE', '--profile PROFILE', 'Specify profile') { |v|
    profile = "profile #{v}"
    Aws.config[:credentials] = Aws::SharedCredentials.new(profile_name: profile)
  }
  opt.parse!(ARGV)
end

ini = IniFile.load(File.expand_path("~/.aws/config"))
region = ENV['REGION'] || ini[profile]['region']
Aws.config[:region] = region

instances = nil
# load cache if fresh
instances = nil
if File.exist?(CACHE) && $opt[:ignore].nil? then
  mtime = File::Stat.new(CACHE).mtime
  if Time.now - mtime < 3600 then
    cache = YAML.load_file(CACHE)
    instances = cache[profile][region] rescue nil
  end
end

if instances.nil? then
  ec2 = Aws::EC2::Client.new
  instances = ec2.describe_instances.reservations
  File::open(CACHE, "w") { |f|
    cache = {}
    cache[profile] = {}
    cache[profile][region] = instances
    YAML.dump(cache, f)
  }
end

if instances
  instances.each do |reservation|
    reservation.instances.each do |instance|
      next unless instance.state.name == "running"
      user = "ec2-user"
      name = instance.instance_id
      dnsname = instance.public_dns_name
      if dnsname == nil
        dnsname = instance.private_dns_name
      end
      instance.tags.each do |tag|
        name = tag.value if tag.key =~ /^name/i
        user = tag.value if tag.key =~ /^user/i
      end
      puts "\"#{name}\"\t#{user}@#{dnsname}\t#{instance.instance_id}"
    end
  end
end
