# encoding: UTF-8

# cases with attachment with null length
# select distinct case_document_id from exchanges where document_id in (select distinct exchange_document_id from attachment_exchanges where attachment_id in (select id from attachments where length is null and file_type is not null));


# 2009037538 getting -- in case: 200813363  #10 levenschtein - 'Tennøe & Co Advokatfirma AS'/'Tennøe & Co. Advokatfirma AS' A! A! A! A! Good. Exchange 2009014654 was created by the case
# 2009014655 getting -- in case: 200901635 getting --  Byggesak 'Tilbygg bolig' 
# 2009014655 getting -- in case: 200901635  #1 A2088015 A2088017 
# 2009060629 getting -- in case: 200901635  #2 A2247914 A2247915 A2247916 A2247917 A! A! A! A! A! A! 
# 2009060670 getting -^X^C/Users/even/.rvm/rubies/ruby-1.9.2-head/lib/ruby/1.9.1/net/protocol.rb:137:in `select': Interrupt


class FailedExchangeError < Error; end
class ImplicitNetworkError < Error; end

class Scrape < Thor

  desc "nomnomemail", "Read their mail"
  def nomnomemail
    require './environment'
    require 'nokogiri'
    
    puts "Getting an metric tonne of emails (#{Email.all(:body => nil).count})"

    Email.all(:body => nil).reverse.each do |email|
    #[Email.first(:body => nil)].each do |email|
      next if [2296318, 2258298, 2258303].include?(email.file_id)
      print ".#{email.id}:#{email.url}"
      print "-"
      email.body = Nokogiri::HTML(open(email.url))
      print "-"
      begin
        email.save!
      rescue DataObjects::DataError
        email.body = email.body.force_encoding("ISO-8859-1").encode("utf-8")
        puts "\n\ntranscoding to UTF-8:\n#{email.body}\n"
        email.save!
      end
    end
  end

  FAILURES_ACCEPTED = 100

  desc "nomnomnom", "Run scraper"
  desc "run_year", "year to scrape"
  def nomnomnom(run_year = nil)
    require './environment'
    require 'nokogiri'
    require 'growl'

    year = run_year || 2011
    exchange_nr = 0
    consecutive_failures = 0
    retry_this = false

    puts "Good luck, really"

    # Remember: only this if running from a state where you're sure you don't have future exchange numbers
    # exchange_nr = Exchange.first(:order => :document_id.desc).document_id.to_s[4..-1].to_i

    begin
      recorded_exchange_nr = File.open("./tmp/exchange_#{year}", 'r') { |f| f.read }.to_i
      exchange_nr = recorded_exchange_nr
      puts "!!!! Starting on #{exchange_nr} !!!!"
    rescue
      puts "No recorded progress"
    end


    exchange_nr = 28458

    puts "!!!! Starting on #{exchange_nr} !!!!"

    while consecutive_failures < FAILURES_ACCEPTED
      padded_exchange_nr = exchange_nr.to_s.rjust(6, "0")
      exchange_id = "#{year}#{padded_exchange_nr}"
      begin
        while (0..3).include? Time.now.hour 
          puts "No working in this period! "
          sleep(600);
        end
        exchange = parse_exchange(exchange_id)
        File.open("./tmp/exchange_#{year}", 'w') {|f| f.write(exchange_nr) }
        raise FailedExchangeError unless exchange
        consecutive_failures = 0
      rescue OpenURI::HTTPError, Errno::ETIMEDOUT, Errno::ECONNREFUSED, Errno::ENETDOWN, SocketError, ImplicitNetworkError => e
        puts "\n\nNetwork Exception: #{e}\n"
        Growl.notify do |g|
          g.message = "Network exception #{e}!"
          g.name = "PlanAR"
        end
        sleep(60)
        retry_this = true
      rescue FailedExchangeError => e
        consecutive_failures += 1
      rescue DataMapper::SaveFailureError => e
        Growl.notify do |g|
          g.message = "Validation error #{e}!"
          g.name = "PlanAR"
        end
        puts e.resource.errors.inspect
        puts "\n\n******************\n\n"
        puts e.backtrace

        raise "Stop!"
      end

      # sleep(0.01)

      if retry_this
        retry_this = false
      else
        exchange_nr += 1
      end
    end

    Growl.notify do |g|
      g.message = "Woo. Ran to completion for cases in #{year}."
      g.name = "PlanAR"
    end

    # Destroy trailing invalids
    id = Exchange.first(:order => :document_id.desc).document_id
    InvalidExchange.all(:document_id.gt => id).destroy

    puts "\nRan to completion."
  end

  private

  no_tasks do
    def attempt_coding(address, bounds)
      matching_address = Address.where(:street_name => address)[0]
      if matching_address 
        print "A"
        return matching_address.to_array
      end
      res = Geokit::Geocoders::GoogleGeocoder.geocode("#{address}, norway", :bias => bounds)
      if res && res.success
        print "G"
        # TODO: check that we are in Oslo
        # curl "http://localhost:12000/reverse_lookup?ll=59.88,10.75"
        return [res.lng, res.lat]
      end
      return nil
    end

    def exchange_url(exchange_id)
      PBE_URL + EXCHANGE_PATH + exchange_id.to_s
    end

    def case_url(case_id)
      PBE_URL + CASE_PATH + case_id.to_s
    end

    def parse_exchange(exchange_id, force = false)
      exchange_id = exchange_id.to_i
      # sleep(0.01)
      print "\n#{exchange_id} "

      if exchange = Exchange.first(:document_id => exchange_id)
        print "already registered"
        return exchange
      end
        
      if err = InvalidExchange.id_is_invalid?(exchange_id) and !force
        print "exchange already found to be invalid - #{err}"
        return nil
      end

      print "getting -"
      doc = Nokogiri::HTML(open(exchange_url(exchange_id)))
      print "- "
      
      top_title = doc.css('.toptitle')

      if top_title.empty?
        if doc.css('body').text.strip == "Ingen data funnet."
          print "mais, n'existez pas!"
          InvalidExchange.create(:document_id => exchange_id, :error => "ID does not exist")
          return nil
        else
          raise ImplicitNetworkError, "Non conforming document - network junk?"
        end
      end
      
      case_id = doc.css('.toptitle').first.text.match(/(\d+)/)[0]

      print "in case: #{case_id} "

      c = Case.first(:document_id => case_id)

      if c.nil?
        Exchange.transaction do
          c = parse_case(case_id)
        end
        unless c
          print " * exchange does not have a valid case"
          InvalidExchange.create(:document_id => exchange_id, :error => "Not have a valid case")
          return nil
        end
      end

      if exchange = Exchange.first(:document_id => exchange_id)
        print "Good. Exchange #{exchange_id} was created by the case"
        return exchange
      end
      
      exchange = Exchange.new(:case => c, :document_id => exchange_id)

      exchange.position = doc.css('.toptitle').children[3].text.match(/\d+/)[0].to_i
      print " ##{exchange.position} "

      fields = doc.css('table')[0].css('td + td').map(&:text).map(&:strip_all)
      exchange.description = fields[0]
      if exchange.description.nil? || exchange.description.empty?
        print "*** EMPTY DESCRIPTION FOR EXCHANGE *** "
        exchange.description = "Ingen beskrivelse"
      end
      
      if fields[1] =~ /Inngående/
        exchange.incoming = true
      elsif fields[1] =~ /Utgående/
        exchange.incoming = false
      else
        raise "Neither incoming or outgoing?"
      end
      exchange.document_date = Date.parse(fields[6])
      exchange.journal_date = Date.parse(fields[8])
      exchange.classification = fields[3]
      exchange.paragraph = fields[5]
      recipients = fields[11].split(',').map(&:strip_all)
      principal_recipient = recipients.pop
      exchange.sender_or_recipent = Party.fuzzily_find_or_create_by_name(principal_recipient)

      cc_recipients = recipients - [principal_recipient]
      cc_recipients.each do |name|
        party = Party.fuzzily_find_or_create_by_name(name)
        if party
          exchange.cc << party
        else
          puts "\n no party for #{name} \n"
        end
      end


      exchange.save

      document_node = doc.css('table')[1]
      parse_attachments(document_node, exchange)

      return exchange
    end

    def parse_attachments(document_node, exchange)
      # Don't read this code
      document_node.css('tr').each do |document|
        title_cell = document.css('td')[2]
        unless title_cell.nil?
          title = title_cell.text.strip_all
          if title =~ /Unntatt publisering/ or title =~ /Ikke publisert/ or title =~ /Unntatt offentlighet/
            print "A! "
            exchange.attachments.create(:title => title, :published => false)
          else
            file_id = document.css('td')[2].css('a')[0].attributes["href"].text.match(/fileid=(\d+)/)[1]
            if attachment = Attachment.first(:file_id => file_id)
              exchange.attachments << attachment and exchange.attachments.save!
              print "A#{attachment.file_id} deja vu "
            else
              type_attribute = document.css('td img')[0].attributes["src"].text.gsub(/\.gif/, '')
              file_type = nil
              file_type = "pdf" if type_attribute =~ /pdf/
              file_type = "gif" if type_attribute =~ /gif/
              file_type = "txt" if type_attribute =~ /txt/
              file_type = "jpg" if type_attribute =~ /jpe?g/
              file_type = "html" if type_attribute =~ /html?/
              file_type = "zip" if type_attribute =~ /zip/
              file_type = "tiff" if type_attribute =~ /tiff?/
              file_type = "doc" if type_attribute =~ /doc/
              file_type = "xls" if type_attribute =~ /xls/
              file_type = "unknown" if type_attribute =~ /unknown/
              file_type ||= "undefined: #{type_attribute}"

              if ["gif", "jpg", "tiff"].include?(file_type)
                attachment = Image.new
              elsif file_type == "txt"
                attachment = Email.new
              elsif file_type == "html"
                attachment = HtmlAttchment.new
              else 
                attachment = Attachment.new
              end

              attachment.file_type = file_type
              attachment.file_id = file_id
              print "A#{attachment.file_id} "
              attachment.title = document.css('td')[2].css('a').text

              if document.css('td')[2].text.match(/(\d+)kB/)
                attachment.size = document.css('td')[2].text.match(/(\d+)kB/)[1]
              end

              attachment.published = true
              exchange.attachments << attachment
              attachment.save
              exchange.attachments.save
            end
          end
        else
          print " *** Exchange has no documents"
        end
      end
    end


    def parse_case case_id
      c = Case.first(:document_id => case_id)
      return c if c

      if err = InvalidCase.id_is_invalid?(case_id)
        print "Case already found to be invalid #{err}" 
        return nil
      end

      print "getting -"
      doc = Nokogiri::HTML(open(case_url(case_id)))
      print "- "
      kind = Case::VALID_KINDS.select { |k| doc.css('table td[class=detailHeading]')[0].text.include?(k) }.first

      if kind.nil?
        InvalidCase.create(:document_id => case_id, :error => "Non supported kind")
        return nil
      end

      c = Case.new(:kind => kind, :document_id => case_id)
      
      print " #{c.kind} "

      fields = doc.css('table td[class=detailHeading]+td')
      title_field = fields[0].text.strip_all

      misc = fields[1].text.strip_all.split(',')
      c.initiated_at = Date.parse(misc[0])
      if misc[1] =~ /endret/i
        date_string = misc[1].match(/\d.*$/)
        c.last_modified_at = Date.parse(misc[1]) if date_string
      elsif misc[1] =~ /avsluttet/i
        c.completed_at = Date.parse(misc[1])
      else
        raise "Strange field in misc #{misc[1]}"
      end
  
      if fields[2].text.strip_all.split(/,/)[0].nil?
        InvalidCase.create(:document_id => case_id, :error => "No gnr/bnr ident - skipping")
        return nil
      end
      
      c.gnr, c.bnr = fields[2].text.strip_all.split(/,/)[0].split('/')[0..1]


      c.district_id, c.district_name = fields[3].text.strip_all.split('-').map { |t| t.strip_all }
      address_field = fields[4].text.strip_all
    
      address = address_field.split('-')[0]
      
      c.address = address.strip_all if address

      # Remove case nr
      title_field = title_field.gsub(case_id.to_s,'').strip_all

      c.title = title_field.gsub(Regexp.new(Regexp.escape(address_field) + ".*?-", Regexp::IGNORECASE), '').strip_all
      c.title = "Sak uten navn" if c.title.empty?

      print "'#{c.title}' "

      if misc[2] =~ /Ansvarlig/i
        res = misc[2].strip_all.gsub(/Ansvarlig:\s?/i, '').split('/')
        if res.length == 3
          # Find case worker
          c.case_worker = Party.fuzzily_find_or_create_by_name(res[-1])
          c.processing_unit = res[0..1].join('/')
        elsif res.length == 1
          puts "**** no case worker - processing_unit " + c.processing_unit = res[0]
        end
      else
        puts "**** No responsible entity #{misc[2]} ****"
      end
  
      # Inquiries don't have these fields
      if kind != "Forespørsel"
        c.applicant = Party.fuzzily_find_or_create_by_name(fields[5].text.strip_all)
        c.developer = Party.fuzzily_find_or_create_by_name(fields[6].text.strip_all)
      end

      exchanges = doc.css('table')[2].css('tr')[1..-1].reverse
      c.recorded_number_of_exchanges = exchanges.length

      c.save

      if Case.all.count % 500 == 0
        Growl.notify do |g|
          g.message = "Case count at #{Case.all.count}"
          g.name = "PlanAR"
        end
      end

      exchanges.map { |node| parse_exchange(node.css('[href]')[0]['href'].match(/(\d+)/)[0], true) }

      return c
    end

    STOPWORDS = /ved\s|parkdrag|med flere|langs\s|borettslag|regjeringskvartalet|snødeponi|pukkverk|\sgård|idrettsplass|\søst/i

    desc "geocode", "Geocode well my brother"
    def geocode
      require './environment'
      require 'open-uri'
      require 'geokit'

      bounds = Geokit::Geocoders::GoogleGeocoder.geocode("oslo, norway", :bias => 'no').suggested_bounds

      cases = Case.where(:location.exists => false).all
    
      puts "#{cases.length} cases to geocode\n"
      cases.reverse.each_with_index do |c, i|
        address = c.address
        print "#{i} \"#{address}\":"
        loc = attempt_coding(address, bounds)

        if loc.nil? && (address =~ /\sOG\s/)
          parts = address.split(/\sOG\s/)
          loc = attempt_coding(parts[0], bounds)
          loc ||= attempt_coding(parts[1], bounds)
        end
      
        if loc.nil?
          address_strip = address.gsub(STOPWORDS, '')
          loc = attempt_coding(address_strip, bounds)
        end
      
        if loc
          c.location = loc
          c.save
        else
          print "***" if c.location.nil?
        end
        puts
      end
    end
  end
end