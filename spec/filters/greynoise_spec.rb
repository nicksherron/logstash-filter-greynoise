# encoding: utf-8
require_relative '../spec_helper'
require "logstash/filters/greynoise"

describe LogStash::Filters::Greynoise do

  describe "defaults" do
    let(:config) do <<-CONFIG
      filter {
        greynoise {
          ip => "ip"
        }
      }
    CONFIG
    # end

    sample("ip" => "8.8.8.8") do
      insist { subject }.include?("greynoise")

      expected_fields = %w(greynoise.ip greynoise.seen)
      expected_fields.each do |f|
        insist { subject.get("greynoise") }.include?(f)
      end
    end
    end
  end
end
#
#
#     sample("message" => "some text") do
#       expect(subject).to include("message")
#       expect(subject.get('message')).to eq('Hello World')
#     end
#   end
# end
