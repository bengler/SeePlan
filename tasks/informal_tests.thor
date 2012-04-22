# coding: UTF-8
class InformalTests < Thor

  desc "re_check", "Check title regexps. They are difficult"
  def re_check
    require './environment'
    titles = ['Normannsgata 41 - Forespørsel vedrørende byggetillatelse - Seksjon 4',
      'Hurdalsgata 41 - 32 - Forespørsel']
    address = ['NORMANNSGATA 41',
      'Hurdalsgata 41 - 32']
    titles.each_with_index do |title, i|
      puts title.gsub(Regexp.new(address[i] + ".*?-", Regexp::IGNORECASE), '').strip_all
    end
  end

  desc "sanity", "Sanity test mongoid model"
  def sanity
    require './environment'

    cw = Party.create!(:name => "Gunnulfsen")
    app = Party.create!(:name => "Even Westvang")
    developer = Party.create!(:name => "Bengler as")

    cc1 = Party.create!(:name => "Simen Skogsrud")
    cc2 = Party.create!(:name => "Otto Westvang")

    c = Case.create!(:document_id => 1, 
      :title => "foo", 
      :kind => "Heis", 
      :initiated_at => Time.now.to_date, 
      :address => "Normannsgata",
      :district_name => "Løkka",
      :district_id => "22",
      :gnr => 1,
      :bnr => 1,
      :case_worker => cw,
      :applicant => app,
      :developer => developer,
      :recorded_number_of_exchanges => 5)


    e = Exchange.new(:journal_date => Time.now.to_date, :document_date => Time.now.to_date, :description => "Klage", :sender_or_recipent => app, :position => 0, :incoming => true)
    e.document_id = 1
    e.cc << developer
    e.cc << cc1
    e.cc << cc2
    e.save!
    
    c.exchanges << e
    c.save!
    
    c = Case.first
    puts "Case applicant: #{c.applicant.name}"
    puts "Case worker: #{c.case_worker.name}"
    puts "Case exchange party: #{c.exchanges.first.sender_or_recipent.name}"
    puts "Case cc'ed on first exchange: #{c.exchanges.first.cc.inspect}"

    p = Party.first(:name => "Even Westvang")
    puts "Party: #{p.name}"
    puts "exchanges: #{p.exchanges.inspect}"
    puts "cced: #{p.carbon_copied_in.inspect}"
    puts "applicant: #{p.cases_applied_for.inspect}"

    p = Party.first(:name => "Simen Skogsrud")
    puts "Party: #{p.name}"
    puts "exchanges: #{p.exchanges.inspect}"
    puts "cced: #{p.carbon_copied_in.inspect}"
    puts "applicant: #{p.cases_applied_for.inspect}"
  end
end