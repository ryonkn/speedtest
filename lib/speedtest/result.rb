# frozen_string_literal: true

module Speedtest
  class Result
    attr_accessor :server, :latency, :download_rate, :pretty_download_rate, :upload_rate, :pretty_upload_rate
    def initialize(server: nil, latency: nil, download_rate: nil, upload_rate: nil,
                   pretty_download_rate: nil, pretty_upload_rate: nil)
      @server = server
      @latency = latency
      @download_rate = download_rate
      @upload_rate = upload_rate
      @pretty_download_rate = pretty_download_rate
      @pretty_upload_rate = pretty_upload_rate
    end
  end
end
