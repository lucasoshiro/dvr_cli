#!/usr/bin/env ruby

require 'optparse'
require 'time'

RTSP_PORT = 554

BISECT_MIN = 10
BISECT_PLAYBACK = 2

Options = Struct.new(
  :host,
  :user,
  :password,
  :channel,
  :action,
  :start,
  :end,
  :time,
  :output,
  :interval
)

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

    opts.on "-tTIME", "--time=TIME", "Time" do |time|
      args.time = time
    end

    opts.on "-oOUTPUT", "--output=OUTPUT" do |output|
      args.output = output
    end

    opts.on "-iINTERVAL", "--interval=INTERVAL" do |interval|
      args.interval = interval
    end

    opts.on "-r", "--realtime" do
      args.action = :realtime
    end

    opts.on "-P", "--playback" do
      args.action = :playback
    end

    opts.on "-B", "--bisect" do
      args.action = :bisect
    end

    opts.on "-F", "--single-frame" do 
      args.action = :single_frame
    end

    opts.on "-D", "--dataset" do
      args.action = :dataset
    end
  end

  opt_parser.parse! argv
  return args
end

def format_rtsp_url options, endpoint, params
  [
    "rtsp://",
    "#{options.user}:#{options.password}@#{options.host}:#{RTSP_PORT}",
    "/cam/#{endpoint}?",
    [params.map {|k, v| "#{k}=#{v}"}].join('&')
  ].join
end

def open_vlc options, endpoint, params
  rtsp_url = format_rtsp_url options, endpoint, params
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

def get_frame options, endpoint, output, params
  rtsp_url = format_rtsp_url options, endpoint, params
  quiet = '-v quiet'

  `ffmpeg -y -i "#{rtsp_url}" -frames:v 1 #{quiet} -rtsp_transport tcp '#{output}'`
  $? == 0
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

    old = nil

    while old.nil?
      print 'old/new: '
      s = gets.strip

      old = s == 'old' ? true : s == 'new' ? false : nil
    end

    if old
      a = mid
    else
      b = mid
    end

    puts
  end

  puts "Bisection finished! Time: #{a}"
  
  vlc_playback options, mid - BISECT_PLAYBACK, mid + BISECT_PLAYBACK
end

def single_frame options
  endpoint = options.time.nil? ? :realmonitor : :playback
  time = options.time && Time.parse(options.time).strftime('%Y_%m_%d_%H_%M_%S')
  output = options.output || 'out.png'
  params = {channel: options.channel}.merge(
             options.time.nil? ? {subtype: 0} : {starttime: time}
           )
  get_frame options, endpoint, output, params
end

def dataset options
  interval = (options.interval || 60).to_i
  start_time = Time.parse options.start
  end_time = Time.parse options.end
  output = options.output || 'out'

  time = start_time

  `rm -rf #{output}` if Dir.exists? output
  Dir.mkdir output

  Dir.chdir output do
    while time <= end_time
      print time
      filename = time.strftime('%Y_%m_%d_%H_%M_%S') + '.png'
      params = {channel: options.channel, subtype: 0, starttime: time.strftime('%Y_%m_%d_%H_%M_%S')}

      result = get_frame options, :playback, filename, params

      puts(result ? ' OK' : ' FAIL')
      time += interval
    end
  end
end

options = parse_argv ARGV
send options.action, options
