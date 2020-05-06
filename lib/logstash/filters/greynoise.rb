# encoding: utf-8
require 'logstash/filters/base'
require "json"
require "logstash/namespace"
require "ipaddr"
require "lru_redux"
require 'net/http'
require 'uri'


# This  filter will replace the contents of the default
# message field with whatever you specify in the configuration.
#
# It is only intended to be used as an .
class LogStash::Filters::Greynoise < LogStash::Filters::Base

  # Setting the config_name here is required. This is how you
  # configure this filter from your Logstash config.
  #
  #  filter {
  #   greynoise {
  #     ip => "ip"
  #   }
  #  }

  config_name "greynoise"

  # ip address to use for greynoise query
  config :ip, :validate => :string, :required => true

  # greynoise enterprise api key
  config :key, :validate => :string, :default => ""

  # target top level key of hash response
  config :target, :validate => :string, :default => "greynoise"

  # tag if ip address supplied is invalid
  config :tag_on_failure, :validate => :string, :default => '_greynoise_filter_invalid_ip'

  # set the size of cache for successful requests
  config :hit_cache_size, :validate => :number, :default => 0

  # how long to cache successful requests (in seconds)
  config :hit_cache_ttl, :validate => :number, :default => 60

  public

  def register
    if @hit_cache_size > 0
      @hit_cache = LruRedux::TTL::ThreadSafeCache.new(@hit_cache_size, @hit_cache_ttl)
    end

  end

  # def register

  private

  def get_free(target_ip)

    uri = URI.parse("https://api.greynoise.io/v1/query/ip")
    request = Net::HTTP::Post.new(uri)
    request["User-Agent"] = "logstash-filter-greynoise 0.1.7"
    request.set_form_data(
        "ip" => target_ip,
    )
    req_options = {
        use_ssl: uri.scheme == "https",
    }
    response = Net::HTTP.start(uri.hostname, uri.port, req_options) { |http|
      http.request(request)
    }
    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    else
      nil
    end
  end


  private

  def get_enterprise(target_ip, api_key)
    uri = URI.parse("https://enterprise.api.greynoise.io/v2/noise/context/" + target_ip)
    request = Net::HTTP::Get.new(uri)
    request["Key"] = api_key
    request["User-Agent"] = "logstash-filter-greynoise 0.1.7"
    req_options = {
        use_ssl: uri.scheme == "https",
    }
    response = Net::HTTP.start(uri.hostname, uri.port, req_options) { |http|
      http.request(request)
    }
    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    else
      nil
    end
  end

  public

  def filter(event)
    valid = nil
    begin
      IPAddr.new(event.sprintf(ip))
    rescue ArgumentError => e
      valid = e
    end

    if valid
      @logger.error("Invalid IP address, skipping", :ip => event.sprintf(ip), :event => event.to_hash)
      event.tag(@tag_on_failure)
    else
      if @hit_cache
        result = @hit_cache[event.sprintf(ip)]
        if result
          event.set(@target, result)
          filter_matched(event)
        else
          # check if api key exists and has len of 25 or more to prevent forbidden response
          if @key.length >= 25
            result = get_enterprise(event.sprintf(ip), event.sprintf(key))
            # if no key then use alpha(free) api
          else
            result = get_free(event.sprintf(ip))
          end
          unless result.nil?
            @hit_cache[event.sprintf(ip)] = result
            event.set(@target, result)
            # filter_matched should go in the last line of our successful code
            filter_matched(event)
          end
        end
      else
        if @key.length >= 25
          result = get_enterprise(event.sprintf(ip), event.sprintf(key))
        else
          result = get_free(event.sprintf(ip))
        end

        unless result.nil?
          event.set(@target, result)
          filter_matched(event)
        end
      end
    end
  end

  # def filter
end # def LogStash::Filters::Greynoise

