require 'timeout'
require 'time'
require 'digest/sha1'
require 'bencode'
require 'sinatra/base'

# This extension will serve up the contents of the specified folder as web seeded torrents.
# Both webseed versions are supported (shad0w's and GetRight's) and there is an inbuilt tracker
# with a modicum of intelligence, though an external tracker can be used if desired.

module Sinatra
  module Torrent
    
    # Options etc
    def self.registered(app)
      # Putting the annouce URL of a tracker in here will use that tracker rather than the inbuilt one
      app.set :external_tracker, nil
      # Directory which holds all the files which will be provided as torrents
      app.set :downloads_directory, File.dirname(__FILE__)+'downloads'
      # Mount point for the downloads directory
      app.set :downloads_mount, 'downloads'
      # Mount point for the torrents directory
      app.set :torrents_mount, 'torrents'
      # Load up a database adapter if one isn't already loaded
      require 'sinatra/torrent/activerecord' unless Kernel.const_defined?('SinatraTorrentDatabase')
      # Stores the instance of the database used to store tracker info.
      app.set :database_adapter, SinatraTorrentDatabase.new
      # The comment added into torrents
      app.set :torrent_comment, ''
      # Do we wish to track external torrents too? (untested)
      app.set :allow_external_torrents, false
      # The frequency with which we ask trackers to announce themselves. Once every x seconds
      app.set :announce_frequency, 30
      
# TORRENTS

      app.mime_type :torrent, 'application/x-bittorrent'

      # Serves up the torrents with appropriate announce URL
      app.get Regexp.new("^/torrents/.+\.torrent$") do
        # Does file exist?
        rel_location = File.expand_path(URI.decode(env['REQUEST_PATH'])[options.torrents_mount.length+1..-9])
        filename = File.join(options.downloads_directory, rel_location)
        halt(404, "That file doesn't exist! #{filename}") unless File.exists?(filename)
                        
        if true #!(d = options.database_adapter.torrent_by_path_and_timestamp(filename,File.mtime(filename)))
          
          d = {
            'metadata' => {
              # TODO: Version?
              'created by' => 'sinatra-torrent (0.0.1) (http://github.com/jphastings/sinatra-torrent)',
              'creation date' => Time.now.to_i,
              'info' => {
                'name' => File.basename(env['REQUEST_PATH'],'.torrent'),
                'length' => File.size(filename),
                'piece length' => 64 * 1024, # TODO: Choose reasonable piece size
                'pieces' => ''
              }
            }
          }
          
          begin
            file = open(filename,'r')
            
            Timeout::timeout(60) do
              begin
                d['metadata']['info']['pieces'] += Digest::SHA1.digest(file.read(d['metadata']['info']['piece length']))
              end until file.eof?
            end
          rescue Timeout::Error
            # TODO: Actually run it in the background!
            halt(503,"This torrent is taking too long to build, we're running it in the background. Please try again in a few minutes.")
          ensure
            file.close
          end
          
          d['infohash'] = Digest::SHA1.hexdigest(d['metadata']['info'].bencode)
          options.database_adapter.store_torrent(filename,File.mtime(filename),d['metadata'],d['infohash'])
        end
        
        # These are options which could change between database retrievals
        d['metadata'].merge!({
          'httpseeds' => ['http://'+env['HTTP_HOST'] +'/'+options.torrents_mount+'/webseed'],
          'url-list' => ['http://'+env['HTTP_HOST'] +'/'+ options.downloads_mount + rel_location+'?'+d['infohash']],
          'announce' => options.external_tracker || 'http://'+env['HTTP_HOST'] +'/'+options.torrents_mount+'/announce',
          'comment' => options.torrent_comment,
        })
        
        content_type :torrent, :charset => 'utf-8'
        d['metadata'].bencode
      end
      
# TRACKER
      
      # Tracker announce mount point
      app.get '/torrents/announce' do
        # Convert to a hex info_hash
        params['info_hash'] = Digest.hexencode(params['info_hash'] || '')
        halt(400,"A valid info-hash was not given") if params['info_hash'].match(/^[0-9a-f]{40}$/).nil?
        info = options.database_adapter.torrent_info(params['info_hash'])
        
        if (!options.allow_external_torrents and !options.database_adapter.torrent_by_infohash(params['info_hash']))
          return {
            'failure reason' => 'This tracker does not track that torrent'
          }.bencode
        end
        
        # TODO: Validation
        
        params['ip'] ||= env['REMOTE_ADDR']
        
        # Registers this peer's announcement
        options.database_adapter.announce(params)
        
        {
          'interval' => options.announce_frequency,
          #'tracker id' => 'bleugh', # TODO: Keep this?
          'complete' => info['complete'],
          'incomplete' => info['incomplete'],
          'peers' => options.database_adapter.peers_by_infohash(params['info_hash'],[params['peer_id']],(params['numwant'] || 50).to_i),
        }.bencode
      end
      
      # TODO: Scrape
      app.get '/torrents/scrape' do
        # TODO: Make it work!
      end

# DATA

      # BitTornado WebSeeding manager
      app.get '/torrents/webseed' do
        # Which file is the client looking for?
        halt(404, "Torrent not tracked") unless (options.database_adapter.torrent_by_infohash(params[:infohash]))
        
        # http://bittornado.com/docs/webseed-spec.txt
        
        # TODO: intelligent wait period
        halt(503,"15") if false # ask clients to wait 15 seconds before requesting again
      end
      
      # Provides the files for web download. Any query parameters are treated as a checksum for the file (via the torrent infohash)
      app.get "/downloads/:filename" do
        filename = File.join(options.downloads_directory,File.expand_path('/'+params[:filename]))
        halt(404) unless File.exists?(filename)
        
        # If there are query params then we assume it's specifying a specific version of the file by info_hash
        halt(409,"The file is no longer the same as the one specified in your torrent") if !env['QUERY_STRING'].empty? and (options.database_adapter.torrent_by_path_and_timestamp(filename,File.mtime(filename))['infohash'] rescue nil) != env['QUERY_STRING'] 
        send_file(filename)
      end
    end
  end
  
  register Torrent
end