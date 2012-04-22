require './environment'
require 'open-uri'
require 'nokogiri'
require 'ap'

require './lib/tokenizer.rb'
require './tasks/cluster_finder.rb'

def ou url=nil
  url ||= "http://web102881.pbe.oslo.kommune.no/saksinnsyn/docdet.asp?jnr=2009000001"
  Nokogiri::HTML(open(url))
end
