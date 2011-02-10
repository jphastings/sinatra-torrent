require 'time'
require 'digest/sha1'
require 'bencode'

module Sinatra
  module Torrent
    @@downloads_directory = 'downloads'
    
    def self.downloads_directory=(d)
      if File.directory?(d)
        @@downloads_directory = d
      else
        # TODO: ERR error
        raise RuntimeError, "The downloads directory doesn't exist"
      end
    end
    
    def self.downloads_directory
      @@downloads_directory
    end
    
    def self.create(filename)
      d = {
        'metadata' => {
          'created by' => "sinatra-torrent (#{File.read(File.expand_path(File.join(__FILE__,'..','..','..','..','VERSION'))).strip}) (http://github.com/jphastings/sinatra-torrent)",
          'creation date' => Time.now.to_i,
          'info' => {
            'name' => File.basename(filename),
            'length' => File.size(filename),
            'piece length' => 2**10, # TODO: Choose reasonable piece size
            'pieces' => ''
          }
        }
      }

      begin
        file = open(filename,'r')

        begin
          d['metadata']['info']['pieces'] += Digest::SHA1.digest(file.read(d['metadata']['info']['piece length']))
        end until file.eof?
      ensure
        file.close
      end

      d['infohash'] = Digest::SHA1.hexdigest(d['metadata']['info'].bencode)

      return d
    end
  end
end