# encoding: UTF-8

require './environment'

get '/' do
  redirect 'http://vis.bengler.no/projects/seeplan', 301
end

get '/last_five' do
  @cases = Case.all(:order => :document_id.desc, :limit => 5)
  haml :last_five
end

get '/timelines/:cluster' do |cluster|
  @cluster = cluster
  if cluster == "bjorvika"
    @title = "The Bjørvika Development"
  elsif cluster == "eufemia"
    @title = "Dronning Eufemias Gate"
  else
    @title = "The Tjuvholmen Development"
  end
  haml :timelines
end

get '/timeline_data/:cluster' do |cluster|
  content_type 'application/json', :charset => 'utf-8'

  require 'benchmark'

  cases = nil
  json = nil
  party_count = nil
  parties = nil

  if cluster == "eufemia"
    points = [[[10.751238,59.909707], 
              [10.762224,59.906823],
              [10.761795,59.906457],
              [10.750895,59.909319]]]

    polygon = GeoRuby::SimpleFeatures::Polygon.from_coordinates(points, 4326)
    cases = Case.all(:conditions => 
     ["document_id in (select document_id from cases where ST_Within(cases.location, '#{polygon.as_hex_ewkb}'))"])

    cases += Case.all(:conditions => ["title ilike '%A7%A9%' or title ilike '%A14%' or 
      title ilike '%A25%' or title ilike '%E2%' or title ilike '%A30%' or title ilike '%A32%' or title ilike '%E4%' or 
      title ilike '%E5%' or title ilike '%B25%' or title ilike '%B10%B13%' or title ilike '%B24%' or title ilike '%B21%' or 
      title ilike '%B22%' or title ilike '%B1-B3%' or title ilike '%B7%'"])

  elsif cluster == "bjorvika"

    points = [[[10.746303,59.905145], 
              [10.743341,59.906006],
              [10.746174,59.908351],
              [10.748448,59.908523],
              [10.752397,59.911191],
              [10.757375,59.910395],
              [10.758319,59.911041],
              [10.761366,59.91061],
              [10.764027,59.909384],
              [10.766816,59.9082],
              [10.766816,59.906199],
              [10.766001,59.904026],
              [10.760808,59.902778],
              [10.759521,59.900668],
              [10.757117,59.899248],
              [10.750937,59.899592],
              [10.74626,59.905016]]]

    polygon = GeoRuby::SimpleFeatures::Polygon.from_coordinates(points, 4326)
    cases = Case.all(:conditions => 
     ["document_id in (select document_id from cases where ST_Within(cases.location, '#{polygon.as_hex_ewkb}'))"])
    cases += Case.all(:conditions => ["title ilike '%barcode%' or title ilike '%bjørvika%'"])
  else

points = [[[10.71815,59.907533],
      [10.718279,59.906178],
      [10.721927,59.905274], 
      [10.723686,59.906328], 
      [10.72403,59.908243], 
      [10.723386,59.909771], 
      [10.722828,59.909965], 
      [10.718579,59.908566], 
      [10.718386,59.907555]]] 

    polygon = GeoRuby::SimpleFeatures::Polygon.from_coordinates(points, 4326)

    cases = Case.all(:conditions => 
     ["document_id in (select document_id from cases where ST_Within(cases.location, '#{polygon.as_hex_ewkb}'))"])
    cases += Case.all(:conditions => ["title ilike '%tjuvholmen%' or title ilike '%fjordparken%'"])
  end

  party_count = {}

  cases.each do |c|
    everyone_involved = c.exchanges.sender_or_recipent.map(&:canonical_party).compact
    everyone_involved.each do |p|
      party_count[p] ||= 0
      party_count[p] += 1
    end
  end

  parties = []

  party_count.each do |key, value|
    parties << {
      :id => key.id,
      :name => key.name,
      :value => value
    } if value > 1
  end

  cases = cases.map do |c|
    { 
      :title => c.title.upcase,
      :doc => c.document_id,
      :initiated_at => c.initiated_at,
      :last_item => c.exchanges[-1].journal_date,
      :exchanges => c.exchanges.all(:order => :journal_date.asc).map do |e|
        {
          :incoming => e.incoming,
          :sor => (e.sender_or_recipent.nil? ? nil : e.sender_or_recipent.canonical_id),
          :journal_date => e.journal_date
        }
      end    
    }
  end

  Yajl::Encoder.encode({:cases => cases, :parties => parties})
end



get '/case/:id' do |id|
  @case = Case.first(:document_id => id).first
  haml :case
end

get "/planimator" do
  haml :planimator, :layout => false
end

get "/js/*.js" do
    filename = params[:splat].first
    coffee "coffee/#{filename}".to_sym
end

get '/stylesheet.css' do
  content_type 'text/css', :charset => 'utf-8'
  sass :stylesheet, :style => :compact
end

# Layar

get '/layar*' do
  content_type 'application/json', :charset => 'utf-8'
  centre = GeoRuby::SimpleFeatures::Point.from_coordinates([params["lon"].to_f, params["lat"].to_f], 4326)
  radius = params["radius"]
  years_ago = (params["CUSTOM_SLIDER"] || 10).to_i

  @cases = Case.all(:conditions => 
    ["document_id in (select document_id from cases where initiated_at > ? order by ST_distance(cases.location, '#{centre.as_hex_ewkb}') limit 50)", Date.new(2011 - years_ago, 1, 1)])

  res = {}
  res[:layer] = 'planar'
  res[:errorCode] = 0
  res[:errorString] = "ok"
  res[:refreshDistance] = 5

  res[:hotspots] = @cases.map do |c|
    { :id => c.document_id.to_s,
      :title => "#{c.year} #{c.title} %distance%",
      :line2 =>  c.address || "",
      :lat => c.location.y * 1000000,
      :lon => c.location.x * 1000000,
      :type => 0,
      :actions => [
          {:activityType => 36, :label => "Se saken", :uri => PBE_URL + CASE_PATH + c.document_id.to_s, :contentType => "text/html"}
        ],
      :distance => 0,
      :imageURL => c.image_url
    }
  end
  Yajl::Encoder.encode(res)
end

# Junaio

post '/channels/subscribe/' do
  # puts params.inspect
end

get '/pois/search/' do
  lat, lon, alt = params["l"].split(',').map { |s| s.to_f }
  perimeter = params["p"].to_i
  default_limit = params["m"].to_i

  puts "#{lon}, #{lat}"

  @cases = Case.near(location: [ lon, lat ]).limit(30)
  haml :search
end

# Finished abodes 2011

get '/finished/streetviews' do
  @cases = Case.all(:conditions => ["document_id in (select case_document_id from exchanges where document_date > '1 1 2011' and description ilike 'Ferdigattest %') and title ilike '%bolig%' and title not ilike '%bad%' and title not ilike '%våtrom%'", ], :location.not => nil, :limit => 500, :order => [:initiated_at.desc])
  haml "finished/streetviews".to_sym
end

get '/finished/mapped' do
  @cases = Case.all(:conditions => ["document_id in (select case_document_id from exchanges where document_date > '1 1 2011' and document_date < '1 1 2012' and description ilike 'Ferdigattest %') and title ilike '%bolig%' and title not ilike '%bad%' and title not ilike '%våtrom%'", ], :location.not => nil)

  @cases = @cases.map do |c|
    {
      :title => c.title,
      :id => c.document_id,
      :address => c.address,
      :url => c.url,
      :lat => c.location.y,
      :lon => c.location.x,
      :initiated_at => c.initiated_at,
      :finished_at => c.exchanges.last.document_date,
      :finished_name => c.exchanges.last.description
    }
  end

  haml "finished/mapped".to_sym
end

get '/finished/images' do
  @cases = Case.all(:conditions => ["document_id in (select case_document_id from exchanges where document_date > '1 1 2011' and description ilike 'Ferdigattest %') and title not ilike '%bad%' and title not ilike '%våtrom%'", ], :order => [:initiated_at.asc])
  @images = @cases.exchanges.attachments.all(:type => 'Image', :file_id.not => nil, :limit => 100)
  @image_urls = @images.map { |i| i.url }
  haml "finished/mapped".to_sym
end

helpers do
  def link_to(*args)
    case args.length
      when 1 then url = args[0]; text = url.gsub('http://','')
      when 2 then text, url = args
      when 3 then text, url, opts = args
    end
    opts ||= {}
    attributes = ""
    opts.each { |key,value| attributes << key.to_s << "=\"" << value << "\" "}
    "<a href=\"#{url}\" #{attributes}>#{text}</a>"
  end
end

