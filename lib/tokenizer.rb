# encoding: UTF-8

class Tokenizer

   require "unicode_utils"

   # * remove leading and trailing whitespace
   # * change all characters to their lowercase representation
   # * remove all punctuation and control characters
   # * split the string into whitespace-separated tokens
   # * sort the tokens and remove duplicates
   # * join the tokens back together
   # * normalize extended western characters to their ASCII representation (for example "gödel" → "godel")

  TRANSLATION_PAIRS = [
    ["a",["\u00C0","\u00C1","\u00C2","\u00C3","\u00C4","\u00E0","\u00E1","\u00E2","\u00E3","\u00E4",
      "\u0100","\u0101","\u0102","\u0103","\u0104","\u0105"]],
    ["c",["\u00C7","\u00E7","\u0106","\u0107","\u0108","\u0109","\u010A","\u010B","\u010C","\u010D"]],
    ["d",["\u00D0","\u00F0","\u010E","\u010F","\u0110","\u0111"]],
    ["e",["\u00C8","\u00C9","\u00CA","\u00CB","\u00E8","\u00E9","\u00EA","\u00EB","\u0112","\u0113","\u0114","\u0115",
      "\u0116","\u0117","\u0118","\u0119","\u011A","\u011B"]],
    ["g",["\u011C","\u011D","\u011E","\u011F","\u0120","\u0121","\u0122","\u0123"]],
    ["h",["\u0124","\u0125","\u0126","\u0127"]],
    ["i",["\u00CC","\u00CD","\u00CE","\u00CF","\u00EC","\u00ED","\u00EE","\u00EF","\u0128","\u0129","\u012A","\u012B",
      "\u012C","\u012D","\u012E","\u012F","\u0130","\u0131"]],
    ["j",["\u0134","\u0135"]],
    ["k",["\u0136","\u0137","\u0138"]],
    ["l",["\u0139","\u013A","\u013B","\u013C","\u013D","\u013E","\u013F","\u0140","\u0141","\u0142"]],
    ["n",["\u00D1","\u00F1","\u0143","\u0144","\u0145","\u0146","\u0147","\u0148","\u0149","\u014A","\u014B"]],
    ["o",["\u00D2","\u00D3","\u00D4","\u00D5","\u00D6","\u00F2","\u00F3","\u00F4","\u00F5","\u00F6","\u014C",
      "\u014D","\u014E","\u014F","\u0150","\u0151"]],
    ["r",["\u0154","\u0155","\u0156","\u0157","\u0158","\u0159"]],
    ["s",["\u015A","\u015B","\u015C","\u015D","\u015E","\u015F","\u0160","\u0161","\u017F"]],
    ["t",["\u0162","\u0163","\u0164","\u0165","\u0166","\u0167"]],
    ["u",["\u00D9","\u00DA","\u00DB","\u00DC","\u00F9","\u00FA","\u00FB","\u00FC","\u0168","\u0169","\u016A","\u016B","\u016C",
      "\u016D","\u016E","\u016F","\u0170","\u0171","\u0172","\u0173"]],
    ["w",["\u0174","\u0175"]],
    ["y",["\u00DD","\u00FD","\u00FF","\u0176","\u0177","\u0178"]],
    ["z",["\u0179","\u017A","\u017B","\u017C","\u017D","\u017E"]]
  ]
  

  # Pairs to translation dictionary
  @@from_str = ""
  @@to_str = ""
  TRANSLATION_PAIRS.each do |to_char, keys|
    keys.each do |key|
      @@from_str << key
      @@to_str << to_char
    end
  end
  
  def self.tokenize(str, options = {})

    # Stripped downcase
    str = UnicodeUtils.downcase(str.strip_all)

    unless options[:dont_strip_postfixes]
      # Remove "v\" "med flere" "m.fl" "og-" & initials
      str = str.gsub(/\sv\/.*$/, '').gsub(/\sm\.\s?fl/i, '').gsub(/\sc\/o.*$/i, '').gsub(/\smed flere.*$/i, '').gsub(/(\s.\.)/, '')
    end

    # Translate to ascii
    str.tr!(@@from_str, @@to_str)

    # Remove control characters
    str.gsub!(/[^a-z0-9øæå\s]/, ' ')

    # Split & uniq
    tokens = str.split.map { |s| self.stem(s) }.uniq
  end


  # Stemming - http://snowball.tartarus.org/algorithms/norwegian/stemmer.html
  VALID_S_ENDINGS       = "bcdfghjlmnoprtvyz"
  STEMMABLE_SUFFIXES    =  %w( a e ede ande ende ane ene hetene en heten ar er 
                        heter as es edes endes enes hetenes ens hetens ers ets et het ast)
  @@suffix_regexp       = Regexp.compile("(#{STEMMABLE_SUFFIXES.join('|')})$")
  STEMMABLE_SUFFIXES_2  = %w(leg eleg ig eig lig elig els lov elov slov hetslov)
  @@suffix_regexp_2     = Regexp.compile("(#{STEMMABLE_SUFFIXES_2.join('|')})$")

  def self.stem(str)
    if str.length <= 4
      puts " Too short returning #{str}"
      return str
    end

    stem_match = str.match(/(.*?[aeiouyøæå][^aeiouyøæå])(.*)/)

    if stem_match.nil? || stem_match.length < 3
      puts "No stemming region found for #{str}"
      return str
    end

    stem_this = stem_match[-1]
    
    # Chop suffixes Mk.I
    stem_this.gsub!(@@suffix_regexp, '')

    # Trim 'S' for valid S-endings
    if stem_this.length >= 2 && stem_this[-1] == 's' && VALID_S_ENDINGS.include?(stem_this[-2])
      stem_this = stem_this[0..-1]
    end

    # Chop 'erte' or 'ert'
    stem_this.gsub!('(erte|ert)$', '')

    # Chop last t in 'dt' or 'vt'  
    stem_this.gsub!(/(d|v)t$/, '\1')

    # Chop suffixes Mk.II
    stem_this.gsub!(@@suffix_regexp_2, '')

    stem = stem_match[1] + stem_this
    puts "#{str} -> #{stem}"

    # bail if the stem is too short
    if stem.length <= 5
      puts " Stem too short - returning #{str}" unless str == stem
      return str
    end

    return stem
  end
  
  def self.test_stemmer
    test_against = %w(havnedistrikt havnedistriktene havnedistrikter havnedistriktet havnedistriktets havnedrift havnedriften havneeffektivitet havneeier havneeiere havneenheter havneforbund havneforbundets havneformål havneforvaltningen havnefunksjonene havnefunksjoner havnefylkene havnefylker havnehagen havneinfrastrukturen havneinnretningene havneinnretninger havneinteresser havnekapasitet havnekassa havnekasse havnekassemidler havnekassen havnekassene havnekassens havnelokalisering havneloven havnelovens havneløsning havneløsningene havneløsninger havnemessig havnemyndighetene havnemyndigheter)
    test_against.each do |str|
      puts self.stem str
    end
  end
  
end