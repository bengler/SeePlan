class Db < Thor
  desc "dropandcreate", "Create database"
  def dropandcreate
    env = ENV['RACK_ENV'] || "development"
    `dropdb planar_#{env}`
    `createdb -O planar -T template_postgis planar_#{env}`
    `psql -d planar_#{env} -U postgres -f /opt/local/share/postgresql83/contrib/fuzzystrmatch.sql`
    File.open("./tmp/exchange", 'w') {|f| f.write("0") }
    require './environment'
    DataMapper.auto_migrate!
  end
end