# encoding: utf-8
require "logstash/filters/base"
require "json"
require "logstash/namespace"
require 'faraday'


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

  # Replace the message with this value.

  config :ip, :validate => :string, :required => true
  config :key, :validate => :string, :required => false
  config :target, :validate => :string, :default => "greynoise"



  public
  def register
  end # def register

  public
  def filter(event)

    if @key.length >= 25
      url = "https://enterprise.api.greynoise.io/v2/noise/context/" + event.sprintf(ip)
      uri = URI.parse(URI.encode(url.strip))

      response = Faraday.get(uri, nil, 'User-Agent' => 'logstash-filter-greynoise', Key: event.sprintf(key))
    else
      url = "https://api.greynoise.io/v1/query/ip"
      response = Faraday.post url, { :ip => event.sprintf(ip) }, 'User-Agent' => 'logstash-filter-greynoise'

    end

    result = JSON.parse(response.body)

    event.set(@target, result)
    # filter_matched should go in the last line of our successful code
    filter_matched(event)

  end # def filter
end # class LogStash::Filters::Greynoise

