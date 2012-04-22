linkage_list = {}
links = []

while everyone_involved.length > 1
  everyone_involved[1..-1].each do |p| 
    link = [everyone_involved[0], p]
    key = link.map(&:canonical_id).sort.join("_")
    unless linkage_list[key]
      links << link
      linkage_list[key] = true
    end
  end
  everyone_involved.shift
end
