#!/usr/bin/env ruby

require 'optparse'
require 'time'

RTSP_PORT = 554

BISECT_MIN = 10
BISECT_PLAYBACK = 2

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

    opts.on "-sSTART", "--start=START", "Start" do |start|
      args.start = start
    end

    opts.on "-eEND", "--finish=END", "End" do |end_|
      args.end = end_
    end

    opts.on "-r", "--realtime" do |channel|
      args.action = :realtime
    end

    opts.on "-P", "--playback" do |channel|
      args.action = :playback
    end

    opts.on "-B", "--bisect" do |channel|
      args.action = :bisect
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

  `vlc "#{rtsp_url}" "vlc://quit" &> /dev/null`
end

def vlc_playback options, start_time, end_time
  open_vlc options,
           :playback,
           channel: options.channel,
           starttime: start_time.strftime('%Y_%m_%d_%H_%M_%S'),
           endtime: end_time.strftime('%Y_%m_%d_%H_%M_%S')
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

  vlc_playback options, start_time, end_time
end

def bisect options
  start_time = Time.parse options.start
  end_time = Time.parse options.end
  
  a = start_time
  b = end_time
  
  while (b - a) >= BISECT_MIN
    mid = a + (b - a) / 2

    puts "Showing #{mid}"

    vlc_playback options, mid, mid + BISECT_PLAYBACK

    good = nil

    while good.nil?
      print 'good/bad: '
      s = gets.strip

      good = s == 'good' ? true : s == 'bad' ? false : nil
    end

    if good
      a = mid
    else
      b = mid
    end

    puts
  end

  puts "Bisection finished! Time: #{a}"
  
  vlc_playback options, mid - BISECT_PLAYBACK, mid + BISECT_PLAYBACK
end

options = parse_argv ARGV
send options.action, options
