require 'rubygems'
require 'bundler/setup'
require 'logger'
require 'sinatra'
require 'data_mapper'
require 'dm-postgis'
require 'dm-validations'
require 'dm-constraints'
require 'dm-timestamps'
require 'haml'
require 'coffee_script'
require 'sass'
require 'yajl/json_gem'

set :root, File.dirname(__FILE__)
set :haml, :format => :html5
set :protection, :except => :frame_options

PBE_URL = "http://web102881.pbe.oslo.kommune.no"
CASE_PATH = "/saksinnsyn/casedet.asp?direct=Y&mode=all&caseno="
EXCHANGE_PATH = "/saksinnsyn/docdet.asp?jnr="
ATTACHMENT_PATH = "/saksinnsyn/showfile.asp?fileid="

DataMapper::Model.raise_on_save_failure = true

configure :development do
  PLANAR_URL = "http://hoko.bengler.no:3000"
  DataMapper.setup(:default, 'postgres://localhost/planar_dev')

  require 'memcached'
  require 'rack/cache'
  before do
    cache_control :public, :max_age => 172800
  end
  use Rack::Cache,
    :verbose     => true,
    :metastore   => 'memcached://localhost:11211/meta',
    :entitystore => 'memcached://localhost:11211/body'
end

configure :production do
  PLANAR_URL = "http://planar.bengler.no"
  DataMapper.setup(:default, 'postgres://localhost/planar_production')

  require 'memcached'
  require 'rack/cache'
  before do
    cache_control :public, :max_age => 172800
  end
  use Rack::Cache,
    :verbose     => true,
    :metastore   => 'memcached://localhost:11211/meta',
    :entitystore => 'memcached://localhost:11211/body'
end

require './models'
DataMapper.finalize

# Super aggro unicode compliant stripper
class String
  def strip_all
    s = self.gsub(/\A[[:space:]]*(.*?)[[:space:]]*\z/) { $1 }
    s.gsub("\u00A0", 32.chr)
  end
end
