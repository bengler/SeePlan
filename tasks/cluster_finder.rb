# encoding: UTF-8

# Worst case: Kvartalet as v/Ole Gjefle

# v/ "person name" -> doesn't parse as people
# A S -> doesn't block as AS

module ClusterFinder
  

  class Clusterer
    @@always_delete = Token.all(:name => ['as', 'asa', 'da'])
    
    # @@deletable_tokens = Token.all(:limit => 90, :order => :occurrences.desc ).select { |s| !(s.name =~ /\d+/) }
    # @@deletable_tokens -= Token.all(:name => ['bydel', 'obos', 'eiendomsutvikling', 'vel'])

    @@cluster_exchange_count = {}

    def self.run_for(party)

      print "\n--\n\nClustering '#{party.name}' - "
      puts "#{party.tokens.map{|t| "#{t.name}(#{t.occurrences})"}.join(',')}"

      tokens = party.tokens
      return nil if tokens.empty?
      tokens_by_frequency = tokens.sort { |a,b| a.occurrences <=> b.occurrences} 

      most_frequent_token = tokens_by_frequency.shift

      matched_set = Party.all(Party.tokens.name => most_frequent_token.name, :clustered => false)      
      required_tokens = [most_frequent_token]

      while true
        print "Required tokens: '#{required_tokens.map(&:name).join(',')}' –– "
        print "Pruning: #{old_length = matched_set.length} - "
        matched_set = matched_set.select { |p| (required_tokens - p.tokens).length == 0 }
        puts "#{matched_set.length} (#{matched_set.length - old_length} pruned)\n\n"

        print_set(matched_set)

        # Error rate on mismatches on all tokens

        errors = matched_set.inject(0) { |result,element| result + (element.tokens - tokens).length }
        error_rate = errors.to_f / matched_set.length

        puts " * #{"|"*(error_rate / 0.25)} error rate: *#{error_rate}*"

        # Error rate on mismatches on uniqed tokens
        
        # all_tokens = matched_set.map { |p| p.tokens }.flatten.uniq
        # non_matching_tokens = all_tokens - tokens
        # error_rate = non_matching_tokens.length.to_f / matched_set.length

        # puts "\n#{non_matching_tokens.length} erronous tokens out of #{all_tokens.length} in cluster of #{matched_set.length}"
        # puts " * #{"|"*(error_rate / 0.25)} error rate: *#{error_rate}*"

        if error_rate > 0.5
          if tokens_by_frequency.length > 0
            required_tokens << tokens_by_frequency.shift
            puts "Adding a required token: #{required_tokens[-1]}"
          else
            puts "Could not get error rate under 1. Doing exact match."
            matched_set = matched_set.select { |p| p.tokens == tokens }
            print_set(matched_set)
            break
          end
        else
          puts "DONE"
          break
        end
      end

      if matched_set.length == 1
        puts "! Only 1 party in matched set"
        return nil
      end
      
      cluster_exchange_count = matched_set.inject(0) { |result, party| result + party.exchange_count }
      puts "! Counted #{cluster_exchange_count} exchanges in total. Saving…"
      cluster = Cluster.create(:canonical_party => party, 
        :canonical_name => party.name, :exchange_count => cluster_exchange_count)

      repository(:default).adapter.execute(
        "update parties set clustered = true, cluster_id = #{cluster.id} where id in (#{matched_set.map(&:id).join(',')})")
      matched_set
    end  

    def self.print_set parties
      print "-- Matches of #{parties.length} --"
      print " (only first 80 printed)" if parties.length > 80
      puts
      parties[0..79].each { |p| puts "#{p.name}: #{p.tokens.map(&:name).join(',')}" }
      puts "------------------------------"
    end

  end

  # Informal tests

  def self.clusterer_test
    puts "HM clustered"
    self.party_list_test_count(Clusterer.run_for(Party.first(:id => 114408)).map(&:id))
    puts "HM found through id-list"
    self.party_list_test_count(HM)

    puts "LPO clustered"
    self.party_list_test_count(Clusterer.run_for(Party.first(:id => 13813)).map(&:id))
    puts "LPO found through id-list"
    self.party_list_test_count(LPO)

    puts "Arcasa clustered"
    self.party_list_test_count(Clusterer.run_for(Party.first(:id => 112010)).map(&:id))
    puts "Arcasa found through id-list"
    self.party_list_test_count(ARCASA)
  end
  
  def self.party_list_test_count(list)
    sum = 0
    list.each do |id| 
      party = Party.first(:id => id)
      count = party.participation_count
      print "#{party.name} participates in #{count}"
      puts "– #{party.exchanges.count}"
      sum += count
    end
    puts "For a grand total of:#{sum}\n\n"
  end
  
    HM = [114408,12031,12033,6805,71426,71721,89220,98854,113495,113662,116051,122886,128048,129988,134249,135299,136441,17006,24060,24797,26518,28121,33833,33835,35160,35482,35483,36315,36623,39968,39969,40625,40628,42876,46058,57150,57251,57510,58806,65739,68289,68769,68770,69782,70256,70260,70750,70787,74243,80328,82788,82790,86806,86812,86813,88219,88949,89999,93662,93681,93685,95035,95522,96315,97040,97041,97045,101916,103195,156707,157038,106691,107264,109079,109400,109401,109402,109405,109838,110323,111015,111128,111130,111618,112044,113454,113810,114437,114441,114445,114447,114640,115257,115422,116052,116584,116927,122230,122235,122516,122548,122691,122717,122866,122868,122870,122883,122885,123555,123838,123840,125399,125405,85354,127087,127183,127187,127188,127189,127255,127951,127952,128711,69627,129068,129092,129746,129748,130188,71717,72713,131542,132257,132506,133083,74374,133734,19871,135573,135645,136244,136443,23977,12038,26448,136794,137069,137315,1063,138527,140860,140861,140862,141927,142822,143009,144138,144139,144142,145343,147487,147488,147491,147716,148089,148585,148961,148965,148972,148998,150722,151085,151087,151089,151129,151858,152224,152243,152530,155353,28535,12032,91422,93707,74246,152715,114794,94812,111129,114108,114113,114114,114116,123881,123882,123883,24870,24871,11397,36636,39943,42245,42411,117289,155894]
  
    ARCASA = [112010,10994,10996,245,247,10992,78425,82856,95013,96291,118933,122336,15142,15791,143017,17078,20501,21100,22595,25482,25484,33404,34252,37371,38396,40636,40876,47397,47398,47399,47996,57383,57384,57639,57640,57642,57643,57644,91881,57641,71612,71669,74629,74630,74631,78022,82191,82195,82769,85272,85983,88259,89152,91981,95722,96290,97265,98521,98526,156810,109349,111392,114350,115659,117294,122966,124324,83035,125058,63003,130588,132816,133399,134387,15022,21102,75379,136004,136023,48051,20424,138207,249,251,141113,143015,147221,151396,17111,8960,8963,8964,8968,8969,154356,154496,155128,65472,159922,109618,109619,109621,8958,88257,20514,118276,22501,25751,32508,139196,47396,50667,50668,137067]
  
    LPO = [120516,1812,4129,5929,6945,13813,79539,81292,85876,23798,27771,41422,23796,158412,71634,72105,76542,76549,76746,77020,89289,93729,94082,102304,102306,102307,102310,102312,102783,79439,79454,112286,113430,116649,120668,130424,73264,85874,74609,13806,18160,136197,137580,1805,1809,3332,60229,60228,3314,3316,3317,3318,3319,3320,146066,146889,6169,6170,63084,151553,154624,28259,28260,28270,28272]
  
end