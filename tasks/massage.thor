# encoding: UTF-8

class Massage < Thor

#    To rerun clustering:
#    update parties set clustered = false where clustered = true;
#    update parties set tokenized = false where tokenized = true;
#    update parties set cluster_id = null where cluster_id is not null;
#    truncate tokens cascade;
#    delete from clusters;

  desc "massage_all", "Run all sanitizers" 
  def massage_all
    match_parties_to_people
    match_organizations
    geocode
    utm_convert
  end

  desc "match_organizations", "Cluster parties and match with organizations"
  def match_organizations
    require './environment'
    require './lib/tokenizer'
    require './tasks/cluster_finder'
    
    puts "TOKENIZING"
    while Party.all(:person => false, :tokenized => false).count > 0
      Party.transaction do 
        Party.all(:person => false, :tokenized => false, :limit => 10000).each_with_index do |party, i|
          print_progress(i)
          tokens = Tokenizer.tokenize(party.name)
          Token.register_tokens(tokens, party)
          party.tokenized = true
          party.save
        end
      end
    end

    # to make sure clustering is run from the top:
    repository(:default).adapter.execute("update parties set exchange_count = (select count(*) from exchanges where exchanges.sender_or_recipent_id = parties.id)")

    puts "CLUSTERING"
    Party.transaction do 
      while true do
        party = Party.first(:person => false, :clustered => false, :order => :exchange_count.desc)
        break if party.nil?
        ClusterFinder::Clusterer.run_for(party)
        party.clustered = true
        party.save
      end
    end

    repository(:default).adapter.execute("update parties set canonical_party_id = (select canonical_party_id from clusters where clusters.id = parties.cluster_id)")

    repository(:default).adapter.execute("update parties set canonical_party_name = (select clusters.canonical_name from clusters where clusters.id = parties.cluster_id)")
  end


  desc "sanitize_companies", "Sanitize names of organizations"
  def sanitize_companies
    require './environment'
    require "unicode_utils/downcase"

    delete_these = %w{ANS AS KS DA}

    while Company.all(:name_sanitized => nil, :limit => 10000).count > 0
      Company.transaction do 
        Company.all(:name_sanitized => nil, :limit => 10000).each_with_index do |company, i|
          print_progress(i)
          name = company.name

          # remove hyphens and punctuation
          name = name.gsub(/-|\./, ' ')

          # remove extraneous spaces
          name = name.gsub(/\s\s*/, ' ')

          # chop names
          ind = name.index(/[[:lower:]]/)
          if ind
            name = name[0..ind-2]
          end 

          # remove terms
          name = (name.split(' ') - delete_these).join(' ').strip_all

          # Downcase
          name = UnicodeUtils.downcase(name)

          company.name_sanitized = name
          company.save
        end
      end
    end
  end

  desc "match_parties_to_people", "qualify_people"
  def match_parties_to_people

    require './environment'
    require "unicode_utils/upcase"
    Party.transaction do
      # case workers are people
      repository(:default).adapter.execute("update parties set person = true where parties.id in (select case_worker_id from cases)")

      Party.all(:name_queried => false).reverse.each_with_index do |party, index|

        print_progress(index)

        # Remove "v\" "med flere" "m.fl" "og-" & initials
        person_name_array = party.name.gsub(/\sv\/.*$/, '').gsub(/\sm\.fl/, '').gsub(/\smed flere.*$/, '').gsub(/(\s.\.)/, '').split(' ')
        person_name_array.map! { |name| UnicodeUtils.upcase(name) }
        person_name_array -= ["OG"]
        person_last_name = person_name_array[-1].strip
        person_first_names = person_name_array[0..-2]

        print "\n'#{party.name}' - '#{person_name_array.join(',')}'"
        if ["ANS", "AS", "KS", "DA"].include? person_last_name
          print " !!! stopword "
          next
        end

        print "."
        if person_first_names.select { |first_name| Name.first(:conditions => ["first_name = ? or middle_name = ?", first_name, first_name]) }.empty?
          print " !!! no first names skip"
          next
        end

        print "."
        match_list = []
        person_first_names.each do |first_name|
          match_list << Name.first(:conditions => ["last_name = ? and (first_name like ? or middle_name like ?)", person_last_name, "%#{first_name}%", "%#{first_name}%"])
        end

        unless match_list.compact.empty?
          print "  *HUMAN*" 
          party.person = true
        else
          print "  !NO MATCH!" 
        end
      
        party.name_queried = true
        party.save!

      end
    end

    # Perhaps do this for every row checked. This is lazy & fast
    repository(:default).adapter.execute("update parties set name_queried = true where name_queried = false or name_queried is null")

    puts "\nphew\n\n"
  end

  desc "geocode [CASE]", "Geocode all or one specific case"
  def geocode(geocode_case = nil)
    require './environment'
    require './lib/geocode'
    
    norgesKart = NorgesKart.new(:knr => 301)

    puts "\nWe have #{Case.all(:location => nil).count} cases to geolocate. Go.\n\n"

    cases = nil
    cases = [Case.first(:document_id => geocode_case)] if geocode_case
    cases ||= Case.all(:location_utm => nil)

    cases.each do |c|
      if c.gnr.nil? || c.bnr.nil? || c.gnr == 0 || c.bnr == 0
        puts "We have a zero gnr/bnr for '#{c.document_id} #{c.title}' skip skip – (#{c.gnr.inspect}/#{c.bnr.inspect})"
      else
        print "Doing '#{c.document_id} (#{c.gnr.inspect}/#{c.bnr.inspect})' –"
        norgesKart.query(:gnr => c.gnr, :bnr => c.bnr)
        
        if norgesKart.easting && norgesKart.northing
          print "- #{norgesKart.easting}, #{norgesKart.northing}\n"
          point = GeoRuby::SimpleFeatures::Point.from_x_y(norgesKart.easting, norgesKart.northing, 32633)
          c.location_utm = point
          c.save!
        else
          print "- that didn't work out\n"
        end
      end
    end
  end

  desc "utm_convert", "Transform to lon/lats"
  def utm_convert
    'echo "update cases set location = ST_Transform(location_utm, 4326) where location_utm is not null and location is null" | psql -d planar_development'
  end

  private

  no_tasks do
    def index_brreg name
      county = 0
      escaped_name = URI.escape(name.encode("ISO-8859-1"))
      url = "https://w2.brreg.no/enhet/sok/treffliste.jsp?orgform=0&fylke=#{county}&kommune=0&navn=#{escaped_name}"

      while true
        begin
          doc = Nokogiri::HTML(open(url))
          break
        rescue Errno::ETIMEDOUT, Timeout::Error
          print " Getting a new IP – retrying"
        end
      end

      raise "Barfed on IP-nerfing" if doc.to_s.encode("UTF-8").include?('Det er gjort for mange søk fra den samme IP-adressen.')

      if doc.css('table:first-child table:last-child table:nth-child(3) td')[2].text.strip == "Ingen"
        print " No matches"
        return nil
      end

      table = doc.css('table:first-child table:last-child table:nth-child(5) tr')[1..-1]

      table.each do |row|
        name = row.css('td')[1].text
        company = Company.first(:name => name)
        if company
          print "¡"
        else
          print "! '#{name}'"
          postal_code, postal_name = row.css('td')[2].text.split(' ')
          org_nr = row.css('td')[0].text
          if postal_code == "UKJENT"
            postal_name = "UKJENT"
            postal_code = 0
          end
          c = Company.new(:name => name, :postal_name => postal_name, :postal_code => postal_code.to_i, :org_nr => org_nr.to_i)
          c.save
        end
      end  
    end

    def print_progress index
      puts "\n\n ********* #{index} \n\n" if index % 100 == 0
    end
  end
end