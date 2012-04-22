class Viz < Thor

  desc "csv_dump", "Dump cases to CSV"
  def csv_dump
    require './environment'
    require 'csv'
    print "…"
    filename = "./tmp/dump_#{Time.now.strftime('%d%m%y')}.csv"
    CSV.open(filename, "wb") do |csv|
      csv << ["id", "title", "location"]
      Case.all(:location.not => nil).each do |c|
        print "."
        csv << [c.document_id, c.title, "#{c.location.y},#{c.location.x}"] unless c.location.nil?
      end
    end
  end

  desc "chart", "dump to graphviz"
  def chart
    require "./environment"
    require './tasks/graph_dumper'
    GraphDumper::Dump.new().run
  end
end

