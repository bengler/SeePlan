# encoding: UTF-8

module GraphDumper

  # Remember read through name to canonical party name

  require 'builder'

  GRUNERLOKKA = [10.759263, 59.924367]
  KAMPEN = [10.781837, 59.911621]
  BJORVIKA = [10.759456, 59.907705]
  SIMEN = [10.785849, 59.895912]
  TJUVHOLMEN = [10.72154, 59.908286]

  class Dump
    def initialize(options = {})
      @described = {}
      @linked = {}
      @party_occurences = {}

      @output_module = nil

      if options[:output_to].nil? || options[:output_to] == :dot
        @output_module = Dot.new
      else
        @output_module = XGMML.new
      end
    end


    def run(options = {})

      # Unntatt offentlighet
      # cases = Case.all(:conditions => 
      #   ["document_id in (select distinct case_document_id from exchanges where classification = 'UO')"])


      # Ambassader
      parties = Party.all(:conditions => ["name ilike '%embassy%' or name ilike '%ambassade%'"])
      cases = Case.all(
        Case.exchanges.sender_or_recipent_id => parties.map(&:id), 
        :initiated_at.gt => Date.new(2005, 1, 1)).uniq

      # cases +=  Case.all(:applicant => parties, 
      #   :initiated_at.gt => Date.new(2005, 1, 1)).uniq


      # cases +=  Case.all(:developer => parties, 
      #   :initiated_at.gt => Date.new(2005, 1, 1)).uniq

      # Kampen
      # centre = GeoRuby::SimpleFeatures::Point.from_coordinates(KAMPEN, 4326)
      # cases = Case.all(:conditions => 
      #   ["document_id in (select document_id from cases where kind = 'Byggesak' and initiated_at > ? and ST_Distance_Sphere(cases.location, '#{centre.as_hex_ewkb}') < 300 order by ST_distance(cases.location, '#{centre.as_hex_ewkb}'))", Date.new(2004, 1, 1)])

      # Bjørvika
      # cases = Case.all(:conditions => 
      #   ["document_id in (select document_id from cases where title ilike '%barcode%' or title ilike '%bjørvika%' or document_id in (
      #     select document_id from exchanges where description ilike '%barcode%' or description ilike '%bjørvika%'))"])

      # Tjuvholmen 2004
      # cases = Case.all(:conditions => 
      #   ["document_id in (select document_id from cases where initiated_at < ? and title ilike '%tjuvholmen%' or document_id in (
      #     select document_id from exchanges where description ilike '%tjuvholmen%'))", Date.new(2004, 1, 1)])

      # Strings
      # cases = Case.all(:conditions => 
      #   ["title ilike '%Ekeberg skulptur%' or title ilike '%Skulpturpark på Ekeberg%'"])

      # Langemyhr
      # parties = Party.all(:cluster_id => [12568])
      # cases = Case.all(Case.exchanges.sender_or_recipent_id => parties.map(&:id))
      # cases += Case.all(:applicant => parties) | Case.all(:developer => parties)
      # cases.uniq!

      # Nunkun
      # parties = Party.all(:cluster_id => [10891])
      # cases = Case.all(Case.exchanges.sender_or_recipent_id => parties.map(&:id))
      # cases += Case.all(:applicant => parties) | Case.all(:developer => parties)
      # cases.uniq!

      # Civitas since 2005
      # parties = Party.all(:cluster_id => [10069,10187,11361])
      # cases = Case.all(
      #   Case.exchanges.sender_or_recipent_id => parties.map(&:id), 
      #   :initiated_at.gt => Date.new(2005, 1, 1)).uniq
      
      # cases = Case.all(:limit => 1000, :initiated_at.gt => Date.parse('2 jan 2008'))

      # Langemyhr
      # clusters = Cluster.all(:conditions => ["canonical_name ilike '%steinar mo%'"])[0..3].map(&:id)
      # parties = Party.all(:cluster_id => clusters)
      # cases = Case.all(Case.exchanges.sender_or_recipent_id => parties.map(&:id))
      # cases += Case.all(:applicant => parties) | Case.all(:developer => parties)

      cases.uniq!
      puts "Found #{cases.count} cases"
    

      cases.each do |c|
        puts "#{c.document_id}:#{c.initiated_at}:#{c.title}"

        everyone_involved = c.involved_parties()
        # everyone_involved = c.involved_parties(:no_people => true)

        # count nodes
        everyone_involved.each do |p|
          @party_occurences[p] ||= 0
          @party_occurences[p] += 1
        end

        everyone_involved.uniq!

        if everyone_involved.length > 0
          describe_node(c)
          everyone_involved.each { |p| link(c,p) }
        end

        # link all parties
        if options[:link_case_involved]
          while everyone_involved.length > 1
            describe_node(everyone_involved[0])
            everyone_involved[1..-1].each do |p| 
              describe(p)
              link(everyone_involved[0], p)
            end
            everyone_involved.shift
          end
        end
      end
      # end case iterator

      max_count = @party_occurences.values[0..-1].max
      @party_occurences.each_pair do |p,v|
        size = q((0.3 + ((2*v)/max_count)).to_s)
        options = {:attributes => {:height => size, :width => size}}
        describe_node(p, options)
        print "|"
      end
    
      path = File.expand_path(File.dirname(__FILE__)) + "/../tmp/"
      filename = "plan_#{Time.now.strftime('%d%m%y')}"
      @output_module.write(path + filename)
      puts"\nDone\n"
    end

    private

    def describe_node(n, options = {})
      unless @described[n.identifier]
        @described[n.identifier] = true

        attributes = options[:attributes]
        attributes ||= {}
        attributes[:label] = q(n.label)

        if n.is_a? Case
          attributes[:fixedsize] = "false"
          attributes[:shape] = "box"
          attributes[:color] = q("#404333")
          attributes[:style] = q("dotted")
        end

        if n.is_a? Party
          attributes[:color] = q("#FBA922")

          if n.is_case_worker?
            attributes[:color] = q("deepskyblue1")
          end
          if !n.person and !n.is_case_worker?
            attributes[:shape] = "house"
            attributes[:color] = q("#DD5F18")
          end
        end
        @output_module.describe_node(n, :attributes => attributes)
      end
    end

    def link(p1, p2)
      keys = [p1.identifier, p2.identifier].sort
      key = "#{keys[0]}_#{keys[1]}"
      unless @linked[key]
        @linked[key] = true

        attributes = {}
        nodes = [p1,p2]
        this_case = nodes.select { |e| e.is_a? Case }[0]
        this_party = nodes.select { |e| e.is_a? Party }[0]

        if this_case && this_party
          if this_case.developer == this_party
            attributes[:color] = q("#ff2020") 
            attributes[:style] = "bold" 
          elsif this_case.applicant == this_party
            attributes[:color] = "coral"
            attributes[:style] = "bold" 
          elsif this_case.case_worker == this_party
            attributes[:color] = "deepskyblue1"
            attributes[:style] = "bold" 
          end
        end

        @output_module.link(p1, p2, :attributes => attributes)
      end
    end

    def q(str)
      "\"#{str}\""
    end

                  # @s << "\"#{case_ident}\" #{node_style}\n"
                  # if c.case_worker
                  #   @s << "\"#{c.case_worker.canonical_name}\" [shape=ellipse, color=dodgerblue1, fillcolor=dodgerblue1]\n"
                  #   @s << "\"#{case_ident}\" -> \"#{c.case_worker.canonical_name}\" [color=dodgerblue1]\n"
                  # end
                  # if c.applicant
                  #   @s << "\"#{c.applicant.canonical_name}\" [shape=ellipse, color=firebrick, fillcolor=firebrick]\n"
                  #   @s << "\"#{case_ident}\" -> \"#{c.applicant.canonical_name}\" [color=firebrick]\n"
                  # end
                  # if c.developer
                  #   @s << "\"#{c.developer.canonical_name}\" [shape=ellipse, color=firebrick2, fillcolor=firebrick2]\n"
                  #   @s << "\"#{case_ident}\" -> \"#{c.developer.canonical_name}\" [color=firebrick2]\n"
                  # end
  end


  class XGMML
    def initialize
      @nodes = {}
      @edges = {}
    end

    def describe_node(n, options = {})
      @nodes[n.numerical_identifier] = { :node => n, :options => options }
    end
    
    def link(p1, p2, options = {})
      key = [p1.numerical_identifier, p2.numerical_identifier].sort.join("_")
      @edges[key] = { :source => p1, :target => p2, :options => options }
    end

    def write(filename)
      File.open("#{filename}.xgmml", "w+") { |f| f.write(result())}
      `cd /Applications/Cytoscape_v2.8.1/plugins`
      `java -Xmx512M -jar /Applications/Cytoscape_v2.8.1/cytoscape.jar -N #{filename}.xgmml`
    end

    private
    
    def result

      builder = Builder::XmlMarkup.new(:indent => 1)
      builder.instruct! :xml, :version => "1.0"
      attribs = {
        "xmlns:dc"      => "http://purl.org/dc/elements/1.1/",
        "xmlns:xlink"   => "http://www.w3.org/1999/xlink",
        "xmlns:rdf"     => "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
        "xmlns:cy"      => "http://www.cytoscape.org",
        "xmlns"         => "http://www.cs.rpi.edu/XGMML",
        :directed => "1",
        :label => "test"
      }

      builder.graph(attribs) do 
        @nodes.each_pair do |k, node_hash|
          node = node_hash[:node]
          builder.node(:id => node.numerical_identifier, :label => node.label, :name => node.class.to_s) do
            # if options[:attributes]
            #   options[:attributes].each_pair { |k, v| @builder.att(:name => k, :value => v) }
            # end
          end
        end
        
        @edges.each_pair do |k, edge_hash|
          source = edge_hash[:source]
          target = edge_hash[:target]
          builder.edge(:id => "#{source.identifier}_#{target.identifier}", :source => source.numerical_identifier, :target => target.numerical_identifier, :label => "#{source.identifier}_#{target.identifier}")
        end
      end
      builder.target!
    end
  end

  class Dot

    def initialize
      @s = header
    end

    def describe_node(n, options = {})
      @s << "#{n.identifier} [#{generate_attribute_string(options[:attributes])}] \n"
    end
    
    def link(p1, p2, options = {})
      @s << "#{p1.identifier} -- #{p2.identifier} [#{generate_attribute_string(options[:attributes])}]\n"
    end

    def write(filename)
      File.open("#{filename}.dot", "w+") { |f| f.write(result())}
      if system "neato -Tps2 -o#{filename}.ps #{filename}.dot"
        system "open #{filename}.ps" 
      else
        system "mate #{filename}.dot"
      end
    end

    private

      def result
        return @s << footer
      end

      def generate_attribute_string(attributes)
        return "" if attributes.nil?
        attribute_string = ""
        attributes.each_pair { |k, v| attribute_string << "#{k.to_s}=#{v} " }
        return attribute_string
      end

      def header
        <<-EOF 
          graph world { \n
          graph [outputorder=edgesfirst, margin="0", pad="2", label="PBE #{Time.now.to_date.to_s}", fontname="Helvetica", bgcolor="#2D3032", fontcolor="#ffffff" ];
          edge [color="#404333", len="7", weight="0.5"];
          node [fixedsize=true, overlap=scale, height="0.5", fontcolor="#ffffff", width="0.5", color="#dde8ff", style=filled, fontname="Helvetica"];
        EOF
      end

      def footer
        return '}'
      end
  end


end