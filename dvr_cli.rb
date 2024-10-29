#!/usr/bin/env ruby

require 'optparse'
require 'time'

RTSP_PORT = 554

Options = Struct.new :host, :user, :password, :channel, :action, :start, :end

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

    opts.on "-sSTART", "--channel=START", "Start" do |start|
      args.start = start
    end

    opts.on "-eEND", "--channel=END", "End" do |end_|
      args.end = end_
    end

    opts.on "-r", "--realtime" do |channel|
      args.action = :realtime
    end

    opts.on "-P", "--playback" do |channel|
      args.action = :playback
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

def playback options
  start_time = Time.parse options.start
  end_time = Time.parse options.end

  open_vlc options,
           :playback,
           channel: options.channel,
           starttime: start_time.strftime('%Y_%m_%d_%H_%M_%S'),
           endtime: end_time.strftime('%Y_%m_%d_%H_%M_%S')
end

options = parse_argv ARGV
send options.action, options
