#!/usr/bin/env ruby

require 'optparse'

RTSP_PORT = 554

Options = Struct.new :host, :user, :password, :channel, :action

def parse_argv argv
  args = Options.new ""

  opt_parser = OptionParser.new do |opts|
    opts.banner = "Usage: example.rb [options]"

    opts.on "-HHOST", "--host=HOST", "Host" do |host|
      args.host = host
    end

    opts.on "-uUSER", "--user=USER", "User" do |user|
      args.user = user
    end

    opts.on "-pPASSWORD", "--password=PASSWORD", "Password" do |password|
      args.password = password
    end

    opts.on "-cCHANNEL", "--channel=CHANNEL", "Channel" do |channel|
      args.channel = channel
    end

    opts.on "-r", "--realtime" do |channel|
      args.action = :realtime
    end

    opts.on ""
  end

  opt_parser.parse! argv
  return args
end

def open_vlc options, endpoint, params
  rtsp_url = [
    "rtsp://",
    "#{options.user}:#{options.password}@#{options.host}:#{RTSP_PORT}",
    "/cam/#{endpoint}?",
    [params.map {|k, v| "#{k}=#{v}"}].join('&')
  ].join

  `vlc "#{rtsp_url}" &> /dev/null`
end

def realtime options
  open_vlc options,
           :realmonitor,
           channel: options.channel,
           subtype: 0
end

options = parse_argv ARGV
send options.action, options
