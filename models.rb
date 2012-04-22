# encoding: UTF-8

# select parties.name, case_worker_id, count(*) as processed from cases join parties on parties.id = case_worker_id group by case_worker_id, parties.name order by processed desc;

class InvalidCase
  include DataMapper::Resource

  property :document_id,  Integer,  :required => true, :key => true
  property :error,        Text,     :required => true

  def self.id_is_invalid?(id)
    invalidCase = InvalidCase.first(:document_id => id)
    return invalidCase.error if invalidCase
    nil
  end
end

class InvalidExchange
  include DataMapper::Resource

  property :document_id,  Integer,  :required => true, :key => true
  property :error,        Text,     :required => true

  property :created_at,   DateTime
  property :updated_at,   DateTime

  def self.id_is_invalid?(id)
    invalidExchange = InvalidExchange.first(:document_id => id)
    return invalidExchange.error if invalidExchange
    nil
  end
end

class Case
  include DataMapper::Resource

  VALID_KINDS = ["Byggesak", "Forespørsel", "Måle-/delesak", "Plansaker"]

  property :document_id,        Integer,    :required => true, :key => true
  property :title,              Text,       :required => true

  property :kind,               String,     :required => true

  property :initiated_at,       Date,       :required => true
  property :completed_at,       Date
  property :last_modified_at,   Date

  property :address,            Text
  property :district_id,        Integer,    :required => true
  property :district_name,      Text,       :required => true

  property :gnr,                Integer
  property :bnr,                Integer

  property :location,           DMGeometry, :required => false
  property :location_utm,       DMGeometry, :required => false

  property :recorded_number_of_exchanges,   Integer, :required => true

  property :processing_unit,    Text

  property :created_at,         DateTime
  property :updated_at,         DateTime

  belongs_to :case_worker, :model => "Party", :required => false
  belongs_to :applicant,   :model => "Party", :required => false
  belongs_to :developer,   :model => "Party", :required => false
  has n,     :exchanges,   :constraint => :destroy

  def numerical_kind
    VALID_KINDS.index(kind)
  end

  def identifier
    return "C_#{document_id}"
  end

  def numerical_identifier
    return -document_id
  end

  def label
    title.gsub(/\/|\/|\(|\)|'|"/, '').gsub(/\r|\n/, '').strip_all
  end

  def involved_parties(options = {})
    result = exchanges.map(&:sender_or_recipent)
    result = (result + exchanges.cc).flatten unless options[:no_cc]

    result = result.flatten.compact.map(&:canonical)

    if options[:only_people]
      result = result.select do |p|
        p.person == true
      end
    end

    if options[:no_people]
      result = result.select do |p|
        p.person == false
      end
    end

    if options[:exchange_threshold]
      result = result.select do |p|
        p.aggregate_exchange_count > options[:exchange_threshold]
      end
    end

    result.concat(([case_worker] + [applicant] + [developer]).flatten.compact.map(&:canonical))
    
    return result
  end

  def year
    document_id.to_s[0..3]
  end

  def url
    "#{PBE_URL}#{CASE_PATH}#{document_id}"
  end

  def image_url
    a = exchanges.attachments.first(:type => 'Image', :file_id.not => nil)
    a.url unless a.nil?
  end
end

class Exchange
  include DataMapper::Resource

  property :document_id,            Integer,  :required => true, :key => true
  property :document_date,          Date,     :required => true
  property :journal_date,           Date,     :required => true
  property :position,               Integer,  :required => true
  property :description,            Text
  property :incoming,               Boolean,  :required => true

  property :classification,         Text
  property :paragraph,              Text

  property :created_at,             DateTime
  property :updated_at,             DateTime


  belongs_to  :case
  has n,      :attachments, :through => Resource, :constraint => :destroy
  belongs_to  :sender_or_recipent,   :model => "Party", :required => false

  has n, :carbon_copy_entries, :constraint => :destroy
  has n, :cc, 'Party', :through => :carbon_copy_entries, :via => :party

  def label
    title = description.gsub(/\/|\/|\(|\)|"|\./, '').gsub(/\r|\n/, '').strip_all
    title = "empty" if title.empty?
    title
  end

  def identifier
    return "E_#{document_id}"
  end

  after :save do
    if self.case.last_modified_at.nil? || document_date > self.case.last_modified_at
      self.case.last_modified_at = document_date
    end
  end

  def url
    "#{PBE_URL}#{EXCHANGE_PATH}#{document_id}"
  end

  def self.find_by_description_substring description
    Exchange.find(:all, :conditions => {:description => Regexp.new(Regexp.escape(description), Regexp::IGNORECASE)})
  end

  def self.find_by_attachment_email_substring substring
    Exchange.where('attachments.email_body' => Regexp.new(Regexp.escape('klage'), Regexp::IGNORECASE)).first
  end
end


class Attachment
  include DataMapper::Resource

  property :id,             Serial

  property  :title,         Text,       :required => true
  property  :file_id,       Integer
  property  :published,     Boolean,    :required => true
  property  :size,          Integer     # in kBytes, yikes
  property  :file_type,     String

  property :created_at,     DateTime
  property :updated_at,     DateTime

  property :type, Discriminator

  has n,    :exchanges, :through => Resource

#  some PDFs missing a size
#  validates_presence_of :size, :if => lambda { |t| !t.file_id.nil? && ["pdf", "gif", "txt", "jpg"].include?(t.file_type)  } 
  validates_presence_of :size, :if => lambda { |t| !t.file_id.nil? && ["gif", "txt", "jpg"].include?(t.file_type)  }

  def url
    "#{PBE_URL}#{ATTACHMENT_PATH}#{file_id}"
  end

  def is_image?
    ["gif", "jpg"].include? file_type
  end
end  

class Image < Attachment; end

class PDF < Attachment; end

class Email < Attachment
  property :body, Text
end

class HtmlAttchment < Attachment
  property :body, Text
end


class CarbonCopyEntry
  include DataMapper::Resource
  belongs_to :exchange,   :key => true
  belongs_to :party,      :key => true
end

class Party
  include DataMapper::Resource

  property  :id,                     Serial
  property  :name,                   Text
  property  :person,                 Boolean
  property  :brreg_queried,          Boolean
  property  :name_queried,           Boolean
  property  :tokenized,              Boolean
  property  :clustered,              Boolean
  property  :exchange_count,         Integer

  has n,    :cases_worked_on,    :model => "Case", :child_key => [:case_worker_id]
  has n,    :cases_applied_for,  :model => "Case", :child_key => [:applicant_id]
  has n,    :cases_developer_for,:model => "Case", :child_key => [:developer_id]
  has n,    :exchanges,          :model => "Exchange", :child_key => [:sender_or_recipent_id]
  has n,    :carbon_copy_entries
  has n,    :carbon_copied_in,   :model => "Exchange", :through => :carbon_copy_entries, :via => :exchange

  has n,      :tokens,             :through => Resource
  has n,      :party_tokens,       :order => [ :position.asc ]
  belongs_to  :cluster, :model => "Cluster", :required => false
  belongs_to  :canonical_party, :model => "Party", :required => false

  property    :canonical_party_name, Text

  validates_uniqueness_of :name

  def label
    title = canonical_name.gsub(/\/|\/|\(|\)|"|\./, '').gsub(/\r|\n/, '').strip_all
    title = "empty" if title.empty?
    title 
  end

  def numerical_identifier
    return id
  end

  def identifier
    return "P_#{canonical_party_id()}"
  end

  def canonical
    canonical_party || self
  end

  def canonical_id
    canonical_party_id || id
  end

  def canonical_name
    canonical_party_name || name
  end

  def aggregate_exchange_count
    return cluster.exchange_count if cluster
    exchange_count
  end

  def is_case_worker?
    cases_worked_on.count > 0
  end

  # Could be faster
  def participation_count
    return carbon_copy_entries.count + exchanges.count + cases_developer_for.count + cases_applied_for.count + cases_worked_on.count
  end

  def self.fuzzily_find_or_create_by_name(name, current_case = nil)
    return nil if name.nil? || name.empty?
    name = name.strip_all
    return nil if name == "."
    party = Party.first(:name => name)      
    return party if party
    print "'#{name}' "
    return Party.create(:name => name)
  end
end

class Name
  include DataMapper::Resource
  property :first_name,   Text, :key => true
  property :middle_name,  Text, :key => true
  property :last_name,    Text, :key => true
end

class Token
  include DataMapper::Resource
  property  :name,         Text, :key => true
  property  :occurrences,  Integer
  has n,    :parties,      :through => Resource

  def self.register_tokens(tokens, party)
    tokens.each_with_index do |str_token, i|
      token = Token.first_or_create(:name => str_token)

      puts token.inspect
      token.occurrences ||= 0
      token.occurrences += 1
      token.save
      PartyToken.create(:party => party, :token => token, :position => i)
    end
  end
end

class PartyToken
  include DataMapper::Resource
  belongs_to  :party,      :key => true
  belongs_to  :token,      :key => true
  property    :position,   Integer, :default => 0
end


class Cluster
  include DataMapper::Resource
  property    :id,              Serial
  property    :canonical_name,  Text
  property    :exchange_count,  Integer

  has n,      :parties, :child_key => [:cluster_id]
  belongs_to  :canonical_party,   :model => Party,  :required => false

  validates_uniqueness_of :canonical_party
  validates_uniqueness_of :canonical_name

  before :save do
    canonical_name = canonical_party.name if canonical_party
  end

end

