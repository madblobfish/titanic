require 'rubygems/package'
require 'stringio'
require 'sinatra'
require 'json'

# should not send keys available in a more specific dictionary

# pattern matching engine
# fqdn, toplevel, service, fullservice, stage, dc, dnszone
def parse_fqdn(fqdn)
  # removes dns zone, drops the server number and splits by -
  splits = fqdn.split('.', 2).first[0..-3].split('-')
  {
    fqdn: fqdn,
    hostname: fqdn.split('.', 2 ).first,
    toplevel: splits[0],
    stage: splits[1],
    dc: splits[-3..-1].join('_'),
    service: splits[2],
    fullservice: splits[2..-4].join('_'),
    dnszone: fqdn.split('.', 2).last
  }
end

# ignores digit parts inserts names from the pattern
def insert_pattern(name, pattern)
  pattern.split('-').map do |part|
    if part.to_i.to_s == part
      nil
    else
      name[part.to_sym]
    end
  end.compact.join('-')
end

def find_files_for_host(fqdn)
  name = parse_fqdn(fqdn)
  Dir['./secret/*'].map do |p|
    "#{p}/#{insert_pattern(name, File.basename(p))}.json"
  end.select do |p|
    File.exists?(p)
  end
end

get('/creds/{fqdn}') do
  out = StringIO.new
  Gem::Package::TarWriter.new(out) do |tar|
    find_files_for_host(params['fqdn']).each do |path|
      tar.add_file(path, 0400) do |io|
        io.write(File.read(path))
      end
    end
  end
  headers = {
    'Content-Disposition' => 'attachment; filename="creds.tar"',
    'Content-Type' => 'application/x-tar',
  }
  out.rewind
  [200, headers, out]
end

