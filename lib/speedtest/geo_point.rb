# frozen_string_literal: true

require 'haversine'

module Speedtest
  class GeoPoint
    attr_accessor :lat, :lon

    def initialize(lat, lon)
      @lat = Float(lat)
      @lon = Float(lon)
    end

    def to_s
      "[#{lat}, #{lon}]"
    end

    def distance(point)
      distance = Haversine.distance(point.lat, point.lon, lat, lon)
      distance.to_kilometers
    end
  end
end
