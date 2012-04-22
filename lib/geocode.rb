# -*- coding: utf-8 -*-
require 'rubygems'
require 'nokogiri'
require 'mechanize'

# Gjør spørringer mot norgeskart.no for å lokasjon for gårds- og bruksnummer
# i koordinatsystemet som benyttes av Google Maps
#
#   norgesKart = NorgesKart.new(:knr => 301)
#   norgesKart.query(:gnr => 57, :bnr => 381)
#   puts norgesKart.lat
#   puts norgesKart.lng
#
#   norgesKart.query(:gnr => 57, :bnr => 380)
#   puts norgesKart.lat
#   puts norgesKart.lng

class NorgesKart

  attr_accessor :knr, :gnr, :bnr, :easting, :northing

  def initialize(options={})
    options.each{|k,v|send("#{k}=",v)}
    @agent = Mechanize.new { |agent| agent.user_agent_alias = 'Mac Safari'}
    # Got to visit this page first to get cookie
    @agent.get("http://www.norgeskart.no/adaptive2/default.aspx?gui=1&lang=2")
  end

  def query(options={})
    options.each{|k,v|send("#{k}=",v)}

    page = @agent.get("http://www.norgeskart.no/adaptive2/default_searchResult.aspx?" +
                      "searchType=gard&fylkesnr=300&param1=#{@knr}&param2=#{@gnr}&param3=#{@bnr}&param4=0")
    link =  page.link_with(:text => "Vis i kart")
    if(link)then
      link.href.to_s =~ /\((\d*\.\d*),(\d*\.\d*)\)/
      x = $1.to_f
      y = $2.to_f
      @northing, @easting = y,x
    else
      @northing = nil
      @easting = nil
    end
  end

end
