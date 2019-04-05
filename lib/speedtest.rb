# frozen_string_literal: true

require 'httparty'

require_relative 'speedtest/result'
require_relative 'speedtest/geo_point'

module Speedtest
  class Test
    def initialize(download_runs: 4, upload_runs: 4, ping_runs: 4,
                   download_sizes: [750, 1500], upload_sizes: [197_190, 483_960],
                   debug: false)
      @download_runs = download_runs
      @upload_runs = upload_runs
      @ping_runs = ping_runs
      @download_sizes = download_sizes
      @upload_sizes = upload_sizes
      @debug = debug
    end

    def run
      server = pick_server
      @server_root = server[:url]
      log "Server #{@server_root}"

      latency = server[:latency]

      download_rate = download
      log "Download: #{pretty_speed download_rate}"

      upload_rate = upload
      log "Upload: #{pretty_speed upload_rate}"

      Result.new(server: @server_root, latency: latency,
                 download_rate: download_rate, pretty_download_rate: pretty_speed(download_rate),
                 pretty_upload_rate: pretty_speed(upload_rate), upload_rate: upload_rate)
    end

    private

    def pretty_speed(speed)
      units = %w[bps Kbps Mbps Gbps Tbps]
      i = 0
      while speed > 1000
        speed /= 1000
        i += 1
      end
      format("%.2f #{units[i]}", speed)
    end

    def log(msg)
      puts msg if @debug
    end

    def downloadthread(url)
      log "  downloading: #{url}"
      page = HTTParty.get(url)
      Thread.current['downloaded'] = page.body.length
    end

    def download
      log "\nstarting download tests:"
      threads = []

      start_time = Time.new
      @download_sizes.each do |size|
        1.upto(@download_runs) do |_i|
          threads << Thread.new do |_thread|
            downloadthread("#{@server_root}/speedtest/random#{size}x#{size}.jpg")
          end
        end
      end

      total_downloaded = 0
      threads.each do |t|
        t.join
        total_downloaded += t['downloaded']
      end

      total_time = Time.new - start_time
      log "Took #{total_time} seconds to download #{total_downloaded} bytes in #{threads.length} threads\n"

      total_downloaded * 8 / total_time
    end

    def uploadthread(url, content)
      page = HTTParty.post(url, body: { 'content' => content })
      Thread.current['uploaded'] = page.body.split('=')[1].to_i
    end

    def randomString(alphabet, size)
      1.upto(size).map { alphabet[rand(alphabet.length)] }.join
    end

    def upload
      log "\nstarting upload tests:"

      data = []
      @upload_sizes.each do |size|
        1.upto(@upload_runs) do
          data << randomString(('A'..'Z').to_a, size)
        end
      end

      threads = []
      start_time = Time.new
      threads = data.map do |data|
        Thread.new(data) do |content|
          log "  uploading size #{content.size}: #{@server_root}/speedtest/upload.php"
          uploadthread("#{@server_root}/speedtest/upload.php", content)
        end
      end

      total_uploaded = 0
      threads.each do |t|
        t.join
        total_uploaded += t['uploaded']
      end
      total_time = Time.new - start_time
      log "Took #{total_time} seconds to upload #{total_uploaded} bytes in #{threads.length} threads\n"

      # bytes to bits / time = bps
      total_uploaded * 8 / total_time
    end

    def pick_server
      page = HTTParty.get('http://www.speedtest.net/speedtest-config.php')
      ip, lat, lon = page.body.scan(/<client ip="([^"]*)" lat="([^"]*)" lon="([^"]*)"/)[0]
      orig = GeoPoint.new(lat, lon)
      log "Your IP: #{ip}\nYour coordinates: #{orig}\n"

      page = HTTParty.get('http://www.speedtest.net/speedtest-servers.php')
      sorted_servers = page.body.scan(/<server url="([^"]*)" lat="([^"]*)" lon="([^"]*)/).map do |x|
                         {
                           distance: orig.distance(GeoPoint.new(x[1], x[2])),
                           url: x[0].split(%r{(http://.*)/speedtest.*})[1]
                         }
                       end
                           .reject { |x| x[:url].nil? } # reject 'servers' without a domain
                           .sort_by { |x| x[:distance] }

      # sort the nearest 10 by download latency
      latency_sorted_servers = sorted_servers[0..9].map do |x|
                                 {
                                   latency: ping(x[:url]),
                                   url: x[:url],
                                   distance: x[:distance]
                                 }
                               end .sort_by { |x| x[:latency] }
      selected = latency_sorted_servers[0]
      log "Automatically selected server: #{selected[:url]} - #{selected[:latency]} ms - #{selected[:distance]} km"

      selected
    end

    def ping(server)
      times = []
      1.upto(@ping_runs) do
        start = Time.new
        begin
          page = HTTParty.get("#{server}/speedtest/latency.txt")
          times << Time.new - start
        rescue Timeout::Error
          times << 999_999
        rescue Net::HTTPNotFound
          times << 999_999
        end
      end
      times.sort
      times[1, @ping_runs].inject(:+) * 1000 / @ping_runs # average in milliseconds
    end
  end
end

if $PROGRAM_NAME == __FILE__
  x = Speedtest::Test.new(ARGV)
  x.run
end
