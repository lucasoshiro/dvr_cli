#!/usr/bin/env ruby

require 'optparse'
require 'time'
require 'tmpdir'

RTSP_PORT = 554

BISECT_MIN = 10
BISECT_PLAYBACK = 2

N_JOBS = 8

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

    opts.on "-eEND", "--end=END", "End" do |end_|
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

    opts.on "-T", "--timelapse" do
      args.action = :timelapse
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

def call_ffmpeg inputs, output, params
  pattern_type = params.delete :pattern_type

  pattern_type_str = pattern_type.nil? ? '' : "-pattern_type #{pattern_type}"

  input_str = inputs.map do |i|
    "-i '#{i}'"
  end.join(' ')

  params_str = params.map do |k, v|
    v == true ? "-#{k}" : "-#{k} '#{v}'"
  end.join(' ')

  `ffmpeg #{pattern_type_str} #{input_str} #{params_str} #{output}`
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
  end_time = options.end.nil? ? (start_time + 3600) : Time.parse(options.end)

  vlc_playback options, start_time, end_time
end

def get_frame options, channels, endpoint, output, params
  rtsp_urls = channels.map do |channel|
    format_rtsp_url options, endpoint, channel: channel, **params
  end

  n_channels = rtsp_urls.length

  filter_complex_params = n_channels > 1 ? {filter_complex: "vstack=inputs=#{n_channels}"}: {}

  v = 'quiet'

  call_ffmpeg(
    rtsp_urls,
    output,
    y: true,
    **filter_complex_params,
    'frames:v' => 1,
    v: v,
    rtsp_transport: 'tcp'
  )
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
  params = options.time.nil? ? {subtype: 0} : {starttime: time}
  get_frame(
    options,
    options.channel.split(',').map {|ch| ch.to_i},
    endpoint,
    output,
    params
  )
end

def dataset options
  interval = (options.interval || 60).to_i
  start_time = Time.parse options.start
  end_time = Time.parse options.end
  output = options.output || 'out'

  `rm -rf #{output}` if Dir.exists? output
  Dir.mkdir output

  Dir.chdir output do
    (0...N_JOBS).map do |job|
      Thread.new do
        time = start_time + job * interval

        while time <= end_time
          filename = time.strftime('%Y_%m_%d_%H_%M_%S') + '.png'
          params = {subtype: 0, starttime: time.strftime('%Y_%m_%d_%H_%M_%S')}

          result = get_frame(
            options,
            options.channel.split(',').map {|ch| ch.to_i},
            :playback,
            filename, params
          )

          puts "#{time} #{(result ? ' OK' : ' FAIL')}"
          time += N_JOBS * interval
        end
      end
    end.each do |thread|
      thread.join
    end
  end
end

def timelapse options
  interval = (options.interval || 60).to_i
  start_time = Time.parse options.start
  end_time = Time.parse options.end
  output = options.output || 'out.mp4'

  tmp_dir = Dir.mktmpdir

  Dir.chdir tmp_dir do
    (0...N_JOBS).map do |job|
      i = job
      Thread.new do
        time = start_time + job * interval

        while time <= end_time
          filename = '%05d.png' % i
          params = {subtype: 0, starttime: time.strftime('%Y_%m_%d_%H_%M_%S')}

          result = get_frame(
            options,
            options.channel.split(',').map {|ch| ch.to_i},
            :playback,
            filename, params
          )

          puts "#{time} #{(result ? ' OK' : ' FAIL')}"
          time += N_JOBS * interval
          i += N_JOBS
        end
      end
    end.each do |thread|
      thread.join
    end
  end

  `rm -f #{output} 2> /dev/null`

  call_ffmpeg(
    ["#{tmp_dir}/*.png"],
    output,
    framerate: 30,
    pattern_type: "glob",
    "c:v" => "libx264",
    pix_fmt: "yuv420p"
  )
  
  `rm -rf #{tmp_dir}`
end

options = parse_argv ARGV
send options.action, options
